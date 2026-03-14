# OpenClaw + OpenViking 深度集成优化方案

基于 OpenViking 官方文档与 OpenClaw 现有架构，本方案旨在通过引入「分层上下文」与「VFS 虚拟文件系统」理念，全面提升 OpenClaw 的记忆能力与 Token 效率。

---

## 1. 核心架构升级：从「扁平」到「分层」

**目标**: 解决 `bootstrap` 或 `memory.md` 过大导致的 Token 浪费及模型注意力分散问题。

### 1.1 引入 L0/L1/L2 分层机制
- **L0 (Abstract)**: 代理初次选择时的「一句话概括」。
- **L1 (Overview)**: 任务规划阶段的「结构化引导」，模仿 oh-my-opencode 的 Prometheus 风格。
- **L2 (Details)**: 开发者在具体实现时才加载的「完整源码/文档」。

### 1.2 viking:// 协议支持
- 在 `scout` 代理中引入 `viking-ls` / `viking-find` 技能，允许代理像操作文件一样精确检索知识库，而不仅仅依赖模糊的语义匹配。

---

## 2. 集成实施方案 (Roadmap)

### 阶段一：基础架构对接 (Infrastructure)
1. **容器协同**: 在 `docker-compose.yml` 中新增 `openviking-server` 服务。
2. **环境变量**: 配置 `OPENVIKING_API` 指向本地服务，注入 `DOCKER_IMAGE_VIKING`。

### 阶段二：增强记忆插件 (Memory Plugin)
1. **自动摘要与提取**: 
   - 监听 `session_end` 钩子，自动调用 OpenViking 的内存自迭代接口。
   - 提取「任务经验」与「用户偏好」，自动更新到 `~/.openclaw/memories`。
2. **冷热数据分离**: 
   - 将 `SOUL.md` / `PROJECT.md` 等核心指令集存为 OpenViking 的 L1 层。
   - 历史长对话存为 L2 层，仅在需要时通过检索召回。

### 阶段三：代理能力重构 (Agent Refinement)
1. **Scout → ContextScout**: 提升 `scout` 对 OpenViking VFS 的读写权限，使其负责维护整个项目的「上下文健康度」。
2. **Main (Commander)**: 在生成计划阶段，强制先从 OpenViking 召回 L1 级别的「同类任务经验」。

---

## 3. 预期收益 (Expected Gains)

- **Token 节省**: 预计平均输入 Token 消耗降低 **80%+** (基于 OpenViking 官方测试)。
- **准确率提升**: 复杂长任务的上下文一致性提升 **40%**。
- **经验闭环**: 实现真正的跨项目、跨会话「专家经验累积」。

---

**建议下一步**: 我可以为您开始编写 `skills/openviking` 的原型代码，或更新 `docker-compose.yml` 引入服务镜像。 ping
