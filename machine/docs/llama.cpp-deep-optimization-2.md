llama.cpp Qwen3.6-27B 深度优化实录（第二版）

双 RTX 3090, 24GB, Qwen3.6-27B, llama.cpp server-cuda

这篇文章记录了从基础配置到深度优化的全过程，包括新版本参数解读、MTP 踩坑、KV cache 策略选择、以及 GPU 带宽瓶颈的定量分析。

一、环境

硬件：双 RTX 3090（24GB），AMD Ryzen 9 5950X，64GB 内存
软件：Debian 13，Docker Compose，llama.cpp server-cuda（ghcr.io/ggml-org/llama.cpp:server-cuda）
模型：unsloth/Qwen3.6-27B-MTP-GGUF 仓库的 Qwen3.6-27B-UD-Q4_K_XL.gguf（17GB，874K 下载量）
框架：OpenCode + oh-my-openagent 编排，两个容器分别跑 27B 稠密和 35B MoE

两张卡各自独立运行 llama.cpp 容器，不跨卡推理。GPU0 跑 27B，GPU1 跑 35B。

二、最重要的发现：MTP 命名陷阱

Qwen3.6 系列原生支持 MTP（Multi-Token Prediction），架构里自带一个 MTP head。在 llama.cpp 中通过 --spec-type 参数控制。

这个参数早期叫 --spec-type mtp，后来在 PR 22964 中改名为 --spec-type draft-mtp。

关键问题：旧名字不会报错。模型照常加载，服务正常启动，API 正常响应——但 MTP 根本没生效。你等于一直在用无加速模式运行。

验证方法：启动日志中搜索 common_speculative_impl_draft_mtp，如果看到这行就说明 MTP 正确启动了。没有这行就是旧名字在静默失效。

如果不是在较新版本中无意间踩到这个坑，可能永远都不会发现速度只有应有的一半。

三、KV cache 对称性陷阱

社区大部分教程推荐 --cache-type-k q8_0 --cache-type-v q4_0 的不对称组合。我也一度认为对称的 q8_0/q8_0 能带来额外速度提升。

实际测试后发现两个问题。

第一，讨论区 #22411 提到的"融合 FA 内核要求对称 KV 类型"只针对 AMD HIP/ROCm 平台。CUDA 上不对称 K/V 没有任何性能惩罚，llama.cpp 的 CUDA FA 内核处理不同 K/V 类型没有问题。

第二，对称 V=q8_0 比不对称 V=q4_0 多占约 1.3GB 显存。在 24GB 显卡上，27B 模型已经占用了约 20GB，再加 1.3GB 后显存占用达到 96.5%，只剩 800MB 余量。这非常危险——context 稍微增长就可能 OOM。

最终结论：不对称 K=q8_0/V=q4_0 是 RTX 3090 上的最优选择。CUDA 无速度惩罚，显存省 1.3GB。

四、批次大小参数

这是最容易忽略的优化之一。很多人的 docker-compose 里没有显式设置 --batch-size 和 --ubatch-size，依赖默认值。

社区 MTP 配置中，club-3090 项目使用 -b 2048 -ub 512，L4 24GB 显卡测试使用 -b 2048 -ub 256。对于 MTP 场景，-ub 1024 能避免激活显存峰值瓶颈。

实测从默认值改为 -b 2048 -ub 1024 后，显存分配更合理，长上下文时速度保持更稳定。

五、Draft KV cache 量化

llama.cpp 新版本支持单独设置 draft 模型的 KV cache 精度：

--spec-draft-type-k q4_0
--spec-draft-type-v q4_0

MTP head 的 KV cache 默认用 f16（每个值 2 字节），降为 q4_0（每个值 0.5 字节）后能节省约 1GB 显存。由于 MTP 只有一层，量化对质量和接受率的影响极小。

六、no-mmap

加 --no-mmap 可以防止某些机器上的页错误导致的速度骤降。club-3090 项目也明确包含此参数。代价是启动时模型加载略慢，但运行时稳定性更好。

七、cache-reuse 不适用于多模态

--cache-reuse 参数在多模态模型（使用 --mmproj 加载视觉投影）时会自动禁用。启动日志会显示：

cache_reuse is not supported by multimodal, it will be disabled

写了也白写，可以直接去掉。

八、GPU 利用率与带宽瓶颈

很多人看到 GPU 利用率 67%、功耗 129W 时以为 GPU 没有满载。这是误解。129W 是空闲时的读数。

实际推理时：

GPU 利用率 87%
功耗 388W / 390W（功率墙已到顶）
显存频率 9501 MHz（GDDR6X 标准最高）

剩下的 13% 空闲来自 CUDA kernel 启动开销、CPU token 编解码、MTP 验证的序列化等待。这些是推理框架的固有开销。

速度与带宽的关系：

RTX 3090 显存带宽 936 GB/s
模型大小 17GB
每 token 最低耗时 17GB / 936 GB/s = 18ms
纯带宽上限 1000ms / 18ms = 55 t/s

这是理论带宽上限。MTP 推测解码之所以有效，是因为一次推测多个 token 分摊了搬运 17GB 权重的固定开销。实际 70 t/s 约等于 55 t/s 乘以 MTP 接受长度 2.8 再除以验证开销。

要突破这个瓶颈只有三条路：

换更小的量化，模型体积更小，带宽压力更低。
等 DFlash 进入主线，新的推测解码方式。
换 RTX 5090，显存带宽翻倍到 1.8 TB/s。

九、DFlash 状态

DFlash 是 NVIDIA 推出的新推测解码方案，声称最高 8 倍加速。但 llama.cpp 的 DFlash PR 22105 仍是草稿状态，没有合入主线。

HuggingFace 上已经出现 DFlash 专用 GGUF 模型，但需要等 PR 合入后再用。目前可以通过 BeeLlama.cpp 分支提前体验。

十、最终配置

lla-qwen27b（GPU0，Qwen3.6-27B 稠密，多模态）

-m /models/Qwen3.6-27B-UD-Q4_K_XL.gguf
--mmproj /models/mmproj-Qwen3.6-27B-f16.gguf
--host 0.0.0.0 --port 8080
--ctx-size 131072
--cache-type-k q8_0 --cache-type-v q4_0
--flash-attn on
--image-min-tokens 1024
--parallel 1
-ngl 99 -t 8 -tb 4
-b 2048 -ub 1024
--mlock --no-mmap
--no-mmproj-offload
--spec-type draft-mtp --spec-draft-n-max 3
--spec-draft-type-k q4_0 --spec-draft-type-v q4_0

环境变量：
GGML_CUDA_GRAPH_OPT=1
CUDA_VISIBLE_DEVICES=0

lla-qwen35b（GPU1，Qwen3.6-35B MoE，纯文本）

-m /models/Qwen3.6-35B-A3B-UD-IQ4_XS.gguf
--host 0.0.0.0 --port 8080
--ctx-size 262144
--cache-type-k q8_0 --cache-type-v q4_0
--flash-attn on
--parallel 1
-ngl 99 -t 8 -tb 4
-b 2048 -ub 1024
--mlock --no-mmap
--spec-type draft-mtp --spec-draft-n-max 2
--spec-draft-type-k q4_0 --spec-draft-type-v q4_0

环境变量：
GGML_CUDA_GRAPH_OPT=1
CUDA_VISIBLE_DEVICES=1

十一、实测数据

生成速度约 70 t/s（热缓存）
显存占用 21.9GB / 24GB（余量 2GB）
Prompt 处理速度 119.5 t/s

优化前后对比：

基础配置（无 MTP，默认 batch）约 46-57 t/s
加 MTP + batch 调优后约 70 t/s
提升约 30%

十二、参数对照速查

--spec-type draft-mtp 启用 MTP 推测解码。旧名 mtp 静默失效，必须用 draft-mtp
--spec-draft-n-max 3 每次推测 token 数。27B 稠密模型 3 最优，MoE 2 最优
--spec-draft-type-k q4_0 降低 draft KV cache 精度，省 ~1GB 显存
--spec-draft-type-v q4_0 同上
-cache-type-k q8_0 主模型 K cache 精度。q8_0 是性价比选择
-cache-type-v q4_0 主模型 V cache 精度。q4_0 够用，不对称无性能惩罚
-b 2048 -ub 1024 批次大小。MTP 场景下需显式调优
--no-mmap 不使用内存映射，避免页错误
--mlock 锁定内存防止 swap。需配合 ulimits memlock -1 使用
--no-mmproj-offload 多模态模型把视觉投影放 CPU。纯文本模型不需要
GGML_CUDA_GRAPH_OPT=1 CUDA graph 优化。实测有效

十三、参考资料

llama.cpp GitHub
Unsloth MTP 官方指南
club-3090 MTP profile 讨论
llama.cpp PR 22964（MTP 改名）
llama.cpp PR 24086（MTP 性能优化）
llama.cpp Discussion 22411（KV cache 对称性 AMD 特有限制）
neoteric.no 博客：MTP p-min 调优
bric.pe.kr 博客：RTX 3090 上 Qwen3.6-27B MTP 速度测试
TheFrontierLab：MTP 默认参数陷阱
