# OpenClaw 多 Agent 系统优化分析报告

## 一、ultrawork-mode 源流分析

**重要发现**: ultrawork-mode 来自 **oh-my-opencode** (现 oh-my-openagent)，一个有 38k+ stars 的开源 Agent 框架。

---

## 二、oh-my-opencode 核心架构（关键参考）

### 2.1 Discipline Agents（四神）

| Agent          | 定位       | 模型                                | 特点                         |
| -------------- | ---------- | ----------------------------------- | ---------------------------- |
| **Sisyphus**   | 主协调者   | claude-opus-4-6 / kimi-k2.5 / glm-5 | 任务规划、委派、强制执行     |
| **Hephaestus** | 深度工作者 | gpt-5.3-codex                       | 自主研究+执行，端到端完成    |
| **Prometheus** | 战略规划者 | 同 Sisyphus                         | 面试式问题分析，生成详细计划 |
| **Oracle**     | 架构/调试  | (待配置)                            | 传统问题处理                 |

### 2.2 Agent Category 分类

Agent 不指定具体模型，而是指定**类别**：

| Category             | 用途              |
| -------------------- | ----------------- |
| `visual-engineering` | 前端、UI/UX、设计 |
| `deep`               | 自主研究+执行     |
| `quick`              | 单文件修改、typo  |
| `ultrabrain`         | 硬逻辑、架构决策  |

**关键**: Harness（框架）根据 Category 自动选择最佳模型。

### 2.3 关键创新特性

1. **Hash-Anchored Edit Tool (Hashline)**
   - 每行代码带内容哈希标识 (`11#VK|`)
   - 编辑时验证哈希，拒绝内容变化的编辑
   - 消除 stale-line 错误

2. **IntentGate**
   - 分析用户真实意图
   - 在分类或行动前进行意图识别

3. **Skill-Embedded MCPs**
   - Skill 自带 MCP 服务器
   - 按需启动，任务结束即销毁
   - 保持上下文干净

4. **/init-deep**
   - 自动生成层次化 AGENTS.md
   - 项目级 / 目录级 / 组件级

### 2.4 Ralph Loop
- 自我引用循环
- 任务 100% 完成前不停止
- "不达目的不罢休"的执行模式

### 1.1 核心分类

| Agent 类型    | 处理问题   | 特点                   |
| ------------- | ---------- | ---------------------- |
| **Oracle**    | 传统问题   | 架构、调试、复杂逻辑   |
| **Artistry**  | 非传统问题 | 需要创新方法、不同路径 |
| **Explore**   | 代码探索   | 快速定位、模式识别     |
| **Librarian** | 文档查找   | 权威文档、示例检索     |
| **Plan**      | 任务规划   | 并行任务图、依赖分析   |

### 1.2 关键机制

- **任务图生成**: Plan Agent 分析任务，创建并行执行图
- **专业化分工**: 根据问题类型匹配最合适的 Agent
- **验证协议**: 预定义成功标准、零容忍失败

---

## 三、OpenClaw 现有 Agent 架构

### 3.1 当前 Agent 列表

| Agent ID   | 角色          | 功能                 |
| ---------- | ------------- | -------------------- |
| main       | Commander     | 协调者，总指挥       |
| scout      | Scout         | 上下文分析、文件识别 |
| developer  | Developer     | 代码实现             |
| reviewer   | Reviewer      | 质量审查             |
| tester     | Tester        | 测试验证             |
| github-ops | GitHub Expert | GitHub 操作          |

### 3.2 当前架构特点

- **工作流角色分配**: Developer → Reviewer → Tester
- **静态委派**: Main Agent 决定委派给哪个子 Agent
- **功能导向**: 按"做什么"（开发、审查、测试）划分

---

## 四、oh-my-opencode vs OpenClaw 详细对比

| 维度              | oh-my-opencode                               | OpenClaw (当前)       | 借鉴可行性 |
| ----------------- | -------------------------------------------- | --------------------- | ---------- |
| **Agent 架构**    | 四神 (Sisyphus/Hephaestus/Prometheus/Oracle) | Commander + 5 workers | ⭐⭐⭐⭐⭐      |
| **Category 分类** | visual/deep/quick/ultrabrain                 | 无                    | ⭐⭐⭐⭐       |
| **任务规划**      | Prometheus 面试式分析                        | 手工                  | ⭐⭐⭐⭐⭐      |
| **模型选择**      | Category → 自动映射                          | 静态配置              | ⭐⭐⭐⭐       |
| **编辑工具**      | Hashline 哈希验证                            | 普通 Edit             | ⭐⭐⭐        |
| **意图识别**      | IntentGate                                   | 无                    | ⭐⭐⭐⭐       |
| **Skill + MCP**   | Skill 自带 MCP                               | 分离                  | ⭐⭐⭐⭐⭐      |
| **执行保证**      | Ralph Loop 100% 完成                         | 基础                  | ⭐⭐⭐⭐⭐      |
| **上下文管理**    | /init-deep 层次化                            | 手工                  | ⭐⭐⭐⭐       |

---

## 五、可借鉴的关键特性（按优先级）

### 5.1 高优先级（可直接借鉴）

| 特性                    | 说明                                | 实现难度 |
| ----------------------- | ----------------------------------- | -------- |
| **Agent Category 映射** | 问题类型 → Agent 映射，自动模型选择 | 中       |
| **Prometheus 规划**     | 面试式问题分析 + 详细计划生成       | 高       |
| **Ralph Loop**          | 不停止执行直到 100% 完成            | 中       |

### 5.2 中优先级（需适配）

| 特性                    | 说明                      | 实现难度 |
| ----------------------- | ------------------------- | -------- |
| **Skill-Embedded MCPs** | Skill 携带自己的 MCP 配置 | 高       |
| **IntentGate**          | 意图分析 + 误解预防       | 高       |
| **Hashline 编辑**       | 哈希验证的编辑工具        | 中       |

### 5.3 低优先级（可选）

| 特性           | 说明               | 实现难度 |
| -------------- | ------------------ | -------- |
| **/init-deep** | 自动生成 AGENTS.md | 低       |

---

## 六、优化方案（基于 oh-my-opencode 调研）

### 6.1 推荐方案：渐进式对齐 oh-my-opencode

**核心理念对齐**：
- 从"工作流角色" → "问题类型 + 动态路由"
- 引入 Category 分类系统
- 增加执行保证机制

**阶段一：Agent 重命名 + Category 映射**
- 保持现有功能，逐步引入 Category 概念
- 新增 `problem-classifier` (可复用 scout)

**阶段二：引入 Prometheus 风格规划**
- 复杂任务先分析 + 生成计划
- 用户确认后再执行

**阶段三：Ralph Loop 执行保证**
- 任务自动继续直到完成
- 失败自动重试 + 升级

---

## 七、实施风险与回滚

**风险**：
- 破坏现有工作流
- 模型调用成本增加
- 调试复杂度提升

**回滚方案**：
- 保留原有 Agent 配置
- 使用配置文件切换新旧模式

---

## 八、验证计划

### 8.1 功能测试
- 问题分类准确性
- Plan Agent 任务分解质量
- 动态路由正确性

### 8.2 回归测试
- 现有工作流不受影响
- 原有 Agent 功能正常

---

## 九、总结

oh-my-opencode 是目前最成熟的 open-code 框架之一，其核心创新在于：

1. **Agent 专业化**: Sisyphus 编排 + Hephaestus 执行 + Prometheus 规划 + Oracle 决策
2. **Category 驱动**: 问题类型自动映射到最佳模型
3. **执行保证**: Ralph Loop 确保任务完成
4. **工程化工具**: Hashline、IntentGate 等消除常见错误

**OpenClaw 可逐步借鉴这些特性，从 Category 映射开始，渐进式对齐。**

---


---

## 十、深度分析：OAC (OpenAgentsControl) 的参考价值

除了 oh-my-opencode，**OpenAgentsControl (OAC)** 提供了另一种极具参考意义的路径：**从「完全自主」转向「人类引导的确定性」**。

### 10.1 OAC 核心理念：Plan-First & Approval Gates

| 特性                          | OAC ( darrenhinde/OpenAgentsControl )          | 借鉴建议                                   |
| ----------------------------- | ---------------------------------------------- | ------------------------------------------ |
| **审批门控 (Approval Gates)** | 每个关键步骤（分析、计划、执行）都需要人类确认 | ⭐⭐⭐⭐⭐ 为 OpenClaw 增加 `confirm_gate` 插件 |
| **Context-Aware**             | 自动探索并加载用户的「编码品味」和项目规范     | ⭐⭐⭐⭐ 优化 Scout 自动生成 CLAUDE.md         |
| **MVI 原则**                  | 最小可见信息加载，极大减少 Token 消耗          | ⭐⭐⭐⭐⭐ 优化上下文窗口算法                   |
| **7 个专业子 Agent**          | 针对 OpenCode 优化的角色分工                   | ⭐⭐⭐⭐ 对齐 OAC 的 Prompt 角色定义           |

### 10.2 oh-my-opencode vs OAC：两条路径的抉择

| 维度         | oh-my-opencode (自由派)        | OAC (保守派)                     |
| ------------ | ------------------------------ | -------------------------------- |
| **核心目标** | 极速、完全自主、并行处理       | 确定性、规范遵循、人类引导       |
| **适用场景** | 快速原型、大规模重构、代码探索 | 生产环境、团队协作、严格规范项目 |
| **用户参与** | 偶尔纠偏                       | 全程深度引导                     |

### 10.3 OpenClaw 的混合方案建议

建议 OpenClaw 不在两者中二选一，而是实现一个**可配置的控制平面 (Control Plane)**：

1. **引入「审批层 (Gatekeeper)」**：在 `openclaw.json` 中配置 `sandboxing.approval_required: true`，对敏感操作引入 OAC 风格的审批。
2. **借鉴「规划层 (Architect)」**：采用 Prometheus (oh-my-opencode) 的两段式设计——先进行「面试式」的需求澄清，再生成任务图。
3. **优化「上下文层 (Context)」**：结合 OAC 的 MVI 思想，实现动态上下文裁剪，解决长会话下的成本和幻觉问题。

---

## 十一、最终建议

OpenClaw 应定位为**「拥有 oh-my-opencode 的自主动力，且具备 OAC 的安全围栏」**。下一步行动：
- [ ] 深入研究 OAC 的 `ContextScout` 实现逻辑。
- [ ] 实验 oh-my-opencode 的层次化 `AGENTS.md` 管理模式。

---

**报告结束。**
