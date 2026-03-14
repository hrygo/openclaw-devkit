# OpenClaw 与 OpenViking 接入方案调研报告

## 1. 背景概述

**OpenViking** 是由字节跳动火山引擎 (Volcengine) 开源的、专为 AI Agent 设计的**上下文数据库 (Context Database)**。它通过分层文件系统（Hierarchical VFS）的概念统一管理记忆、资源和技能。

将 OpenViking 接入 **OpenClaw**，可以显著提升智能体的「长期记忆」能力（跨会话经验沉淀）和「上下文效率」（通过 L0/L1/L2 分层加载节省 Token）。

---

## 2. OpenViking 核心优势

*   **分层上下文加载 (Tiered Loading)**: 
    *   **L0**: 摘要（~100 Tokens）
    *   **L1**: 详细概述（~2k Tokens）
    *   **L2**: 完整内容。
    *   *对 OpenClaw 的意义*: 解决 `bootstrap` 文件过大导致的 Token 浪费，实现动态按需加载。
*   **上下文自迭代 (Context Self-Iteration)**: 
    *   自动从对话中提取用户偏好、任务经验并压缩存储。
    *   *对 OpenClaw 的意义*: 自动化 `memory.md` 的维护，无需人工干预。
*   **统一资源定位 (URI-based VFS)**: 
    *   将所有上下文抽象为 `user/` 或 `agent/` 目录下的资源。

---

## 3. 集成方案设想

### 3.1 方案 A：技能插件化 (Skills-based)
将 OpenViking 的 API 封装为 OpenClaw 的 **Skill**。
*   **实现方法**: 创建一个新的 Skill 文件夹 `skills/openviking`，包含一个调用 OpenViking HTTP 接口的脚本。
*   **功能**: 
    *   `memo_save`: 将当前对话的关键信息存入 OpenViking。
    *   `memo_recall`: 通过 OpenViking 的检索能力寻找历史经验。
*   **优点**: 实现简单，不侵入 OpenClaw 核心代码。

### 3.2 方案 B：生命周期钩子接入 (Lifecycle Hooks)
利用 OpenClaw 的插件系统，在会话生命周期中自动触发。
*   **实现方法**: 编写一个 OpenClaw 插件，监听 `agent_end` 钩子。
*   **工作流**:
    1.  每当对话结束，OpenClaw 触发 `agent_end`。
    2.  插件将本次 Transcript 发送给 OpenViking 进行记忆提取。
    3.  OpenViking 更新长效记忆并在下次 `before_prompt_build` 时注入 L1 级别的摘要。

### 3.3 方案 C：存储层映射 (Storage Mapping)
将 OpenClaw 的 `workspace` 挂载到 OpenViking 的 VFS 之下。
*   **实现方法**: 配置 OpenViking 监控 OpenClaw 的工作目录。
*   **优点**: 自动实现 `AGENTS.md` 和 `SOUL.md` 的向量化检索和分层管理。

---

## 4. 实施路线图建议

1.  **环境部署**: 
    *   使用 Docker Compose 在开发者镜像中部署 OpenViking 容器。
    *   端口映射：`1933:1933`。
2.  **API 连通**: 
    *   在 `.env` 中添加 `OPENVIKING_ENDPOINT`。
3.  **开发 `viking-recall` 技能**: 
    *   允许 Maintainer 角色调用此技能进行深度的跨项目记忆检索。
4.  **配置自迭代**:
    *   开启 OpenViking 的 `add-memory` 自动提取任务。

---

## 5. 结论

OpenViking 的理念与 OpenClaw 指令化管理的思路高度契合。通过将其作为 OpenClaw 的后备记忆库，可以使您配置的「虚拟研发部」具备真正的**职场经验累积能力**，从「单次任务执行者」进化为「持续学习的专家系统」。
