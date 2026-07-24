# octopus-skill 🐙

**一个脑子,多条腕。** 一个面向长周期智能体任务的精选提示词库,可编译到你用的任意
宿主 —— Claude Code、Grok、Cursor、Codex。方法论共享,每条*腕*把它适配到宿主原生的
形态(一个 loop,或一个 goal)。像章鱼一样:一套神经系统伸进不同环境,并变色适应每一处。

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
![Hosts: Claude Code · Grok · Cursor · Codex](https://img.shields.io/badge/hosts-Claude%20Code%20·%20Grok%20·%20Cursor%20·%20Codex-8A2BE2)

[English](README.md) · 简体中文

<img alt="图:执行者节点与清洁上下文的监督者节点,只通过持久文件通信" src="assets/graph.png" width="100%" />

## 为什么存在

用强模型写一段调好的、有主见的提示词,胜过临场手动驱动宿主 —— 对**可复用、长周期、
高风险**的活尤其如此(一次性小活直接打字就好,库的价值在复用)。真正耐用的不是某一个
机制,而是那套**纪律**:"done"意味着已验证而非只是写完、no test theater、不做投机式
搭建、对增长的强制收敛、以及硬性的 owner 红线。这套纪律与宿主无关。octopus 就是它唯一
存放的地方,再编译到各个宿主。

## 两条腕

| 腕 | 何时用 | 交付 |
|-----|----------|-------|
| **[`loop-graph`](skills/loop-graph)** | 你会用 `/loop` 驱动它(Claude Code、Grok、Cursor、shell);容易 scope 蔓延或假装"done"的多轮任务;多里程碑阶段;执行者与监督者跨宿主/模型拆分;有 owner 闸门 | 一个**执行者节点**(围绕单一真相源 ledger 干活)+ 一个**清洁上下文的监督者节点**,从外部复验、并通过单向 directives 文件纠偏 —— 两个 loop |
| **[`quest`](skills/quest)** | 你会把它交给一个自驱到完成的 goal 命令(Grok `/goal`、Codex task);单一、自包含的目标,执行者与审查在同一次运行里 | **一段 objective 提示词**,把纪律折进去,骑宿主自己的验证器 —— 无第二个 loop |

拿不准?判定规则写在每条腕 `SKILL.md` 的开头,宿主能力矩阵在
[`lib/host-dialects.md`](lib/host-dialects.md)。

## 哪个宿主,怎么跑

两条腕,一套纪律。**先按任务形态选腕**——再用那个宿主要的方式跑。大多数宿主两条都能跑,
宿主只负责"排除掉不可用的那条":

- **loop-graph** —— 多里程碑 / 有不可跳过的 gate / 执行者与监督者跨宿主拆分 / 有 owner
  闸门,或你想要一个**独立**验证器。两段提示词:一个**执行者** loop 围绕 ledger 干活,加
  一个清洁上下文的**监督者** loop,从外部复验、通过单向 directives 文件纠偏。*监督者永远
  是一个 `/loop`,绝不是 goal*—— 审计者必须从执行者上下文之外、按间隔醒来;goal 会冲刺到
  "done"。
- **quest** —— 一个**单一、自包含、能驱动到真正 done** 的目标。一段 objective 提示词,宿主
  自己的 harness 驱动它(在 Grok 上还负责验证)。没有第二个 loop。

权威语法与矩阵见 [`lib/host-dialects.md`](lib/host-dialects.md)。

两列就是两条腕;✅ / ⚠️ / ❌ 表示这个宿主能不能跑那条腕,格子里是**怎么跑**。

| 宿主 | **quest** —— 单一自包含目标 | **loop-graph** —— 多里程碑 / 有闸门 / 要验证器 |
|---|---|---|
| **Grok** | ✅ `/goal <objective>` —— **自带原生对抗式验证器** | ✅ 执行者 `/loop` + 监督者 `/loop` |
| **Codex** | ✅ `/goal`,或直接把 objective 作为任务发给它(自驱;无验证器) | ✅ **两个节点**都用带间隔 `/loop`(如 `/loop 4m`)—— **绝不用 `/goal`**(会把**停泊中**的节点活锁)|
| **Claude Code** | ⚠️ 一个自定步单 `/loop` —— 能跑,但**无独立验证器** | ✅ 执行者 `/loop`(自定步)+ 监督者 `/loop`(监督者*就是*验证器)|
| **Cursor** | ❌ 无 goal 原语 | ✅ 执行者 `/loop` + 监督者 `/loop` —— 每轮 < 20 分钟 |
| **shell / cron** | ❌ 无 goal 原语 | ✅ 两个 loop 都排期;ledger 到终态就 `break` |

一句话记牢:**任务形态决定用哪条腕;宿主只排除不可用的** —— ❌ 的宿主跑不了 quest(没有
goal)。**监督者永远是 `/loop`,绝不是 goal。**

## 脑(`lib/`)

- **[`methodology.md`](lib/methodology.md)** —— *为什么*每条规则存在,对应它防范的那个长
  周期智能体失败模式。想在不破坏方法的前提下调规则,先读它。
- **[`host-dialects.md`](lib/host-dialects.md)** —— 各宿主差异的单一 owner:loop/goal 的调用
  语法、自适应 vs 定间隔的行为、以及唤醒/通知/保活原语(Grok 的 `Stop`/`Notification` hook 等)。

## 安装

```sh
curl -fsSL https://raw.githubusercontent.com/levi-qiao/octopus-skill/main/install.sh | sh
```

装成单一 **`/octopus`** 技能,Claude Code 和 Codex 都可用 —— 伞入口会路由到正确的腕。
任何已有的 `/graphkit` 安装都不受影响。想从本地克隆安装,在仓库根目录跑 `./install.sh`。

## 治理 —— 让它是一个库,不是杂物抽屉

octopus 把自己的 anti-bloat 规则用在自己身上:**没有真实 consumer(一个真正跑过、验证过
它的 run)的提示词,不进库。** 精选、有主见,胜过大而全 —— 和执行者在一次 run 内守的是同
一条线。

## 致谢

`loop-graph` 腕来自真实运行与社区输入 —— 它最早是独立的 *graphkit* 技能,本仓库就是那个
项目演进而来(老 `graphkit` 链接会重定向到这里)。特别感谢
**[@BrightProgrammer7](https://github.com/BrightProgrammer7)** —— `migrate-blob-storage`
这个实战范例,以及那些打磨了里程碑闸门和节点/边词汇的设计讨论。

## 许可

见 [LICENSE](LICENSE)。
