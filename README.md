# 🚀 Flow PDCA - AI 驱动的个人进化闭环工具

**Flow PDCA** 是一款基于 Apple 《人机交互指南 (HIG)》设计的效率工具。它将经典的 **PDCA** 管理循环与 **DeepSeek LLM** 及 **Apple HealthKit** 生理数据深度融合，旨在通过数据闭环实现用户的自我进化。

---

## 🏗️ 项目架构 (Project Architecture)

项目采用 **SwiftUI + SwiftData** 的原生响应式架构，严格遵循模块化解耦原则：



* **View 层**: 采用原子化组件拆分（如 `TaskRowView`, `GoalRow`），通过 `ViewModifier` 隔离复杂的样式渲染，确保编译器性能最优。
* **Data 层 (SwiftData)**: 使用 `@Model` 定义 `Goal` 与 `PDCATask` 的一对多关联，实现数据的持久化与云端同步。
* **Service 层**:
    * `AIService`: 封装 DeepSeek API，处理自然语言目标到结构化任务的转换。
    * `HealthManager`: 负责 HealthKit 的授权与实时步数、睡眠数据拉取。

---

## 📄 核心函数与逻辑文档 (Function Documentation)

### 1. AI 智能拆解逻辑 (`AIService.decomposeGoal`)
* **输入**: `title: String` (用户定义的模糊目标)
* **逻辑**: 通过 System Prompt 约束 AI 输出标准的 JSON 数组，要求其根据 PDCA 原则将目标拆解为 3-5 个原子任务。
* **输出**: `[String]` (任务标题数组)

### 2. 状态渲染逻辑 (`GoalRow.isAllCompleted`)
* **算法**: `tasks.count > 0 && tasks.allSatisfy { $0.isCompleted }`
* **UI 映射**: 当该逻辑返回 `true` 时，图标从 `target` 切换为 `checkmark`，并触发色值从 `blue` 到 `green` 的平滑过渡。

### 3. 性能优化逻辑 (`TaskCardStyleModifier`)
* **原理**: 将 8+ 个链式修饰符（Background, Material, Overlay 等）封装进 `ViewModifier`。
* **目的**: 物理阻断 SwiftUI 编译器的类型推导链条，解决 `Type-check in reasonable time` 报错。

---

## 📈 项目进度 (Project Roadmap)

- [x] **Phase 1: Plan (核心架构)** - 基础 UI、SwiftData 模型、DeepSeek API 接入。
- [x] **Phase 2: Do (执行模块)** - 任务打卡交互、Haptic 震动反馈、编译器性能调优。
- [x] **Phase 3: Data (健康监测)** - HealthKit 集成，实时展示生理状态指标。
- [ ] **Phase 4: Check (智能归因)** - AI 结合生理数据自动生成执行分析报告。 *(In Progress)*
- [ ] **Phase 5: Act (自适应调整)** - 根据复盘结果自动修正下周计划。

---

## 🛠️ 技术规格

| 模块 | 技术实现 |
| :--- | :--- |
| **持久化** | SwiftData (iOS 17+) |
| **AI 模型** | DeepSeek-V3 (via API) |
| **生理数据** | HealthKit (Steps, Sleep) |
| **设计风格** | Ultra Thin Material (iOS Native) |

---
*Developed by **youfei0719** - 2026 辞职自研项目*

## 🔄 更新日志 (最新)
- **重构 AI 交互逻辑**：废弃系统默认 Alert 弹窗，引入符合 Apple HIG 规范的原生自适应半屏卡片 (Half-Sheet)，并完美支持 Markdown 深度排版渲染。
- **升级 AI 破局大脑**：剥离单调的健康数据强绑定，引入“宏观目标关联”，聚焦项目痛点，提供深度的【核心阻力剖析】、【破局策略】和【下一步微动作】。
- **开放全网大模型生态**：新增高级动态配置面板，内置支持 DeepSeek、Kimi、通义千问等主流大模型，并自带 API 连通性测试防呆机制。
- **本地化与防丢失机制**：API Key 仅本地沙盒存储，绝不硬编码；AI 洞察数据实现数据库持久化，彻底解决“阅后即焚”的体验断层问题。
