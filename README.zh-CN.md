<div align="center">

# graphkit

**把长周期编码任务跑成一张智能体节点图，而不是一个会漂移的循环。**

一个 [Claude Code](https://claude.com/claude-code) 技能：把"让这个项目达到生产标准"这类模糊目标，拆成一个干活的执行节点和一个站在执行方上下文之外的监督节点，在漂移累积之前纠偏。

graphkit 是 **graph engineering（图工程）** 的一次具体落地——从调教单个智能体循环，转向把分工明确的智能体角色接成一张图。目前是两个角色，后续会增加。

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
![Claude Code Skill](https://img.shields.io/badge/Claude%20Code-Skill-8A2BE2)

[English](README.md) · 简体中文

</div>

---

## 问题

给智能体一个又大又模糊的目标——"把这个仓库做到生产质量""把精度提到基线以上""完成迁移"——跑上几十轮它就开始漂移：

- 范围蔓延：没人要的新抽象、v2 端点、"灵活"配置；
- 假装完成：没有生产调用面的测试、能编译却什么也不做的功能；
- 悄悄降标：改了冻结契约、让指标回退；
- 丢失主线：没有唯一真相，第 30 轮和第 5 轮自相矛盾。

智能体自己发现不了这些：它推理所依据的历史，正是产生漂移的那段历史，所以它会报告自己"仍在规格内"。结果还是要人逐轮盯。

## 从 loop engineering 到 graph engineering

Loop engineering 试图在循环内部解决——更好的提示词、更多提醒、更大的上下文窗口。它有天花板，因为腐蚀循环判断力的正是它自己的历史。

Graph engineering 把结构移到模型之外：一张由分工明确的智能体角色组成的小图，每个角色从干净上下文启动，只通过持久、可检视的状态相连。graphkit 把它落在"长周期编码"这一个场景上，从最小可用的图起步：

- **执行节点**——干活，一轮只做一项，对着唯一台账推进。
- **监督节点**——每个 tick 从干净上下文启动，只读台账和 git 树，像外部评审一样审视这次运行。它能看到执行方看不到的漂移，因为抄近路的那段上下文它从未参与。

这张图会长出更多角色——见[路线图](#路线图更多节点角色)。

节点之间只通过可检视的状态通信——一份台账、一棵 git 树、一个单向 directives 文件——纪律由接线保证：

- **唯一记分板。** `ledger.md` 是唯一真相。代码、文档、台账冲突时，先修台账。
- **一轮只做一项**，当轮验证，再记入台账。不批处理，不延后测试。
- **强制收敛。** 每第 5 轮零新功能，只删死代码、收紧接口（净行数 ≤ 0）。单轮净增超 400 行，下一轮强制收敛。
- **发现即登记。** 中途发现的缺口一律登记，不静默修、不忽略。
- **红线即停。** 未授权不 push、不对他人改动做破坏性 git、密钥不入提交、冻结契约保持冻结、指标不回退。
- **单向纠偏。** 监督节点纠正漂移和低效方法（比如没跑小样本 pilot 就全量跑），只通过 directives 文件下达，不编辑台账，也不共享执行方的上下文。它默认自行裁决，只有一小份 owner-only 清单会升级到你。
- **预置裁决授权。** 处在目标关键路径上的 owner-only 决策（比如目标本身就是瘦身 schema，那每轮都会碰到删表），要在访谈阶段就先和 owner 敲定成一条**常驻授权（standing authorization）**——给出一条客观、可核验的证据门槛，循环在满足门槛时自主执行（owner 事后复核），而不是把自己该干的活降级成「提案待签核」然后卡住。只有真正需要逐案判断、无法预先写成门槛的决策才升级给你。

没有 LangGraph、没有 Python 运行时、没有编排服务：节点和边就是任何编码智能体都能执行的 Markdown 文件。

## 工作原理

```mermaid
flowchart LR
    U([你]) -->|"/graphkit"| I[面试:<br/>目标 · 门禁 · 红线]
    I --> G[生成这张图]
    G --> EX[executor.md]
    G --> LG[ledger.md]
    G --> DIR[directives.md]
    G --> OPS[ops.md]
    G --> SV[supervisor.md]
    EX -->|全新上下文| EXE((执行节点))
    EXE <-->|读 / 重写| LG
    SV -->|干净上下文, 每 30 分钟| SUP((监督节点))
    SUP -->|只读| LG
    SUP -->|纠偏| DIR
    DIR -->|每轮读取| EXE
    SUP -->|checkpoint 提交| GIT[(git)]
    SUP -->|须人类决策的缺口| U
```

执行节点对着台账推进；监督节点从外部审视、提交干净的 checkpoint、经 directives 边注入纠偏。两者不共享上下文，也不写同一个文件。

## 一个强模型，廉价地执行

因为节点不共享上下文，每个节点可以跑在不同的模型上。纪律本身让廉价执行方变得安全：范围锁死在一轮一项，规则写在台账和 directives 里而非它的上下文里，还有强模型复核结果。

| 节点 | 频率 | 模型 | 原因 |
| --- | --- | --- | --- |
| 搭图（`/graphkit` 面试） | 一次 | 你最强的模型 | 设计门禁、红线、里程碑靠判断力 |
| 执行节点 | 每轮 | 廉价/快的 agent——低价档、本地模型、开源 coder | 它只是照显式台账一步步走 |
| 监督节点 | 每 ~30 分钟 | 强模型 | 冷读判漂移最难，但触发频率低 |

执行方的提示词是指向纯 Markdown 的纯 Markdown，粘进哪家便宜的 agent 都行。贵的推理集中在搭图和偶尔的巡检，不花在每一轮上。

## host 与 loop

*node* 是角色——执行节点、监督节点。*host* 就是一个**按时间间隔反复唤起 node 的 loop**：Claude Code `/loop`、Cursor 后台 agent 的 follow-up 循环、或任意 agent CLI 套在 shell `while` 里。node 在两次迭代之间不留记忆——台账就是记忆——所以会话中断后从台账续跑，什么都不会丢。host 可以互换，图不变。两条规则防止 host 变成第二块记分板：

- **台账是活文件，不是 host 里的文字。** 交给 loop 一个指向 run 文件的瘦指针，它每轮重新读取——绝不把台账折进 host 自己的提示词文字里，那样会变陈旧。host 的进度 UI 只是台账的**镜子**，永不替代它，冲突一律以台账为准。
- **监督节点永远是自己独立的 loop、独立干净上下文**——一个单独的排期或 cron tick，绝不是执行方 loop 里的 subagent。那个 subagent 会共享整套方法刻意保持干净的上下文。

两个 loop 在跑完时都会**自己停下**——执行方在台账到达 `exit-ready`/`closed` 时停，监督方在没有东西可提交时停——所以跑完的 run 绝不会整夜空转烧 token。`/graphkit` 会把启动命令直接打印在对话里；"一台廉价执行方 loop + 另一台强监督方 loop"是头等用法，不是什么特殊集成。

## 快速开始

1. **安装：**

   ```bash
   curl -fsSL https://raw.githubusercontent.com/levi-qiao/graphkit/main/install.sh | sh
   ```

   <sub>或手动：`git clone https://github.com/levi-qiao/graphkit ~/.claude/skills/graphkit`</sub>

2. **在 Claude Code 里运行 `/graphkit`**，回答面试：仓库与分支、目标及验证方式、里程碑、门禁命令、红线、提交授权、监督间隔。文件生成到你仓库里全新的 `.graphkit/<日期-slug>/` 目录——一次 run 一个目录，新 run 不改旧 run 的文件。（[每个文件的作用 →](#每次-run-生成的文件)）

3. **启动执行方 loop：** 用 `/graphkit` 直接打印在对话里的命令启动——一个指向 `executor.md` 的瘦指针，跑在你 host 的 loop 上（Claude Code `/loop`、Cursor agent、或 shell 里的 agent CLI）。会话挂了从台账续跑，跑到 `exit-ready` 时**自己结束 loop**——不整夜空转，也不用你每轮去戳。

4. **启动监督方 loop**（可选，推荐）：第二个 loop，按你的间隔在干净上下文里跑 `supervisor.md`——Claude Code 里走 cron，否则每个间隔开一个全新会话。run 跑完它会自己停下，绝不整夜空转。

没有 Claude Code，就手动填写 `templates/`——方法本身不依赖运行时。

## 仓库结构

这些文件只读、不用改：

| 路径 | 说明 |
| --- | --- |
| [`SKILL.md`](SKILL.md) | 技能入口：`/graphkit` 背后的面试与生成流程。 |
| [`templates/`](templates/) | 节点与边的模板，技能按 run 填充；脱离 Claude Code 也可手动使用。 |
| [`docs/methodology.md`](docs/methodology.md) | 设计依据：每条规则及其防范的失败模式。 |
| [`examples/add-tests-to-cli/`](examples/add-tests-to-cli/) | 一次完整的样例 run——executor 与台账跑到第 3 轮的样子。建议先读。 |
| [`examples/migrate-blob-storage/`](examples/migrate-blob-storage/) | 更长的样例 run——里程碑、先试点再全量的回填、一次收敛轮，以及一条识破"自报证据"的监督指令。 |

## 每次 run 生成的文件

每次 run 在你的仓库里生成一个 `.graphkit/<日期-slug>/`：

| 文件 | 谁写 | 作用 |
| --- | --- | --- |
| `executor.md` | 生成一次 | 执行节点的提示词——loop 瘦指针指向它。内含 loop 的自停逻辑。 |
| `ledger.md` | 执行节点，每轮 | 唯一真相：目标、门禁、每轮日志、未决缺口。看它跟进度。 |
| `directives.md` | 监督节点，单向 | 纠偏指令，执行节点每轮读取。你也可以自己追加。 |
| `ops.md` | 各节点，只追加 | 环境、构建、数据的持久事实。 |
| `supervisor.md` | 生成一次 | 监督节点的提示词；Claude Code 里自动排期，run 跑完自己停 loop。 |

## 适用场景

任务跨很多轮、成功可验证（测试、门禁、指标）、且确有漂移风险时用它。一次性小改，或每一步都需要人判断成败的工作，不必用。

## 常见问题

**为什么是"图"，不是"带监控的循环"？** 关键性质在于：监督方是一个拥有独立干净上下文的节点，只经可检视的边与执行方相连。是这层隔离——而非定时调度——让它能抓到执行方抓不到的漂移。多智能体框架把运行建模成图也是同一个原因；graphkit 用 Markdown 而非运行时实现了它。

**必须配 Claude Code 吗？** 技能封装与监督调度是 Claude Code 特性，但节点与边都是纯 Markdown，方法与具体智能体无关。推荐的用法本来就是混搭：用强模型搭一次图，执行节点交给最便宜的 agent。

**固定第 5 轮收敛会不会太武断？** 那是默认值；面试里可调间隔与净行数上限。重要的是存在强制收敛机制，而非具体数字。

**节点能自己 commit / push 吗？** 仅当你在面试里授权。安全默认：执行方只实现和验证，提交是单独的授权步骤（常由监督节点执行），push 永不自动。

## 路线图：更多节点角色

执行 + 监督只是最小可用的图。一个角色就是一份 Markdown 节点加一条可检视的边——没有框架、没有运行时——所以这张图可以一次一个文件地生长。计划中的角色：红队评审（对抗性核查"已完成"的断言）、侦察调研（在关键路径外探索方案、汇报进台账）、测试裁判（独占门禁，执行方无法给自己判卷）。欢迎从这些角色开始贡献。

## 贡献

欢迎 Issue 与 PR，见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

[MIT](LICENSE) © 2026 levi-qiao
