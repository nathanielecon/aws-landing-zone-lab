# 编排交接 ORCH-002（简体中文）

编排模型：Grok 4.5 High Fast  
范围：仅 `continuityops/`（禁止修改 `project-a/` 与 Project C）  
人类门禁：构建期间 **无**

## 两阶段 Ralphy

1. **Stage 1 构建编排**：由编排器创建完整 ContinuityOps 项目
2. **Stage 2 准确率循环**：项目完成后，多线程 judge/nixer/fixer 循环，直到均分 ≥ 9.5（单评 ≥ 9.0，must-have 全过）

## 当前状态

- 云项目文件夹已准备
- 构建门禁已关闭（不阻塞）
- 等待 Stage 1 实现流填充各 slice

## 工人约束

- 只改 `continuityops/`
- 交接与工人通信：简体中文
- 招聘向工件：英文
