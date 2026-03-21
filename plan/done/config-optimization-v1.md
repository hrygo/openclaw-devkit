# OpenClaw 配置优化方案 (Optimization Strategy)

基于对 oh-my-opencode 与 OAC 架构的调研，本文针对 `openclaw.json` 提出以下优化方案，旨在提升系统的 **确定性**、**安全性** 与 **执行效率**。

---

## 1. 核心模型路由优化 (Category Mapping)

**目标**: 更好地利用不同模型的长处（推理 vs 编写）。

- **Plan**: 将 `main` 代理的模型更换为具备更强推理能力的模型（如 `qwen3.5-plus` 或增加特定推理模型），用于模仿 **Prometheus** 的面试式任务规划。
- **Action**: 优化 `agents.defaults.models` 的别名映射，确保子代理根据 `contextWindow` 自动选择。

## 2. 引入审批围栏 (Approval & Safety Gates)

**目标**: 借鉴 **OAC** 的 Approval Gates 机制。

- **Sandboxing 扩展**:
    - 目前仅 `developer` 开启了 Sandbox。
    - **建议**: 为 `tester` 代理开启 `sandbox: { mode: "all" }`，防止测试代码对容器环境产生非预期污染。
- **确认机制**:
    - 在关键代理（如 `developer`, `github-ops`）中显式指定工具的 `deny` 列表或引入 `interactive: true` 标识（通过 OpenClaw 插件支持）。

## 3. 面向 MVI 的上下文管理 (Context Optimization)

**目标**: 借鉴 **MVI (Minimal Visible Information)** 原则，减少 Token 消耗与幻觉。

- **Pruning 策略**:
    - 当前 `ttl: 1h` 较为保守。
    - **建议**: 引入基于 `compaction` 的摘要模式，开启 `session-memory` 钩子的摘要持久化。
- **Token 限制**:
    - 为 `scout` 等不需要产出大量代码的代理设置较低的 `maxTokens` (如 4k)，将额度留给 `developer`。

## 4. 代理架构角色增强 (Agent Role Refinement)

- **Scout → ContextScout**:
    - 赋予 `scout` 更多元数据读取权限，模仿 OAC 的模式发现能力。
- **Commander (Main)**:
    - 调整 `heartbeat`。将 `main` 的心跳缩短至 `10m`，包含更多 `includeReasoning` 细节，便于人类在 Slack/Feishu 端进行「进程监控」。

---

## 5. 具体建议修改项 (Diff Preview)

```json
{
  "agents": {
    "defaults": {
      "contextPruning": {
        "mode": "summary-window", // 切换到摘要窗口模式
        "windowSize": 20
      }
    },
    "list": [
      {
        "id": "tester",
        "sandbox": { "mode": "all", "scope": "agent" } // 增加测试沙箱
      },
      {
        "id": "github-ops",
        "tools": { "deny": ["gh-delete-repo"] } // 增加高危操作限制
      }
    ]
  }
}
```

---

**建议下一步**: 我可以为您直接应用这些优化，或者针对特定代理（如 `main`）进行精细化 Prompt 调整。 ping
