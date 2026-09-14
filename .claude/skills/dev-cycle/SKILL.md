---
name: dev-cycle
description: LocalSend fork 的功能开发闭环——实现 → 全量测试 → 打包给人工验证 → 确认后发布。当有人说「继续开发」「打测试包」「出 release 包」「走开发流程」或任何新功能/修缺陷迭代时使用。
---

# 开发闭环(dev-cycle)

本仓库(nicholyx/localsend,上游 localsend/localsend 的 fork)每次功能开发都走
同一条流水线:**实现 → 全量测试 → 打包(artifact,不进 release)→ 人工验证 → 发布**。

## 第一步:实现

- 小批量提交:完成一个小功能就提交一次,Conventional Commits。
- 分支驱动:`feat/*`、`fix/*`、`docs/*`、`chore/*`,一个主题一个分支一个 PR。
- 平台相关约束见仓库 `AGENTS.md`(fvm、150 列、FOSS 标记、FRB codegen 等)。
- 鸿蒙相关改动必须同步检查 `docs/HARMONYOS.md` 的「Architecture」表是否仍然成立。

## 第二步:全量测试(提交前本地必跑)

```bash
fvm dart format --set-exit-if-changed lib test   # 在 app/,CI 会先删 lib/gen
fvm flutter analyze
fvm flutter test                                  # app/ 与 packages/localsend_isolates/ 各一次
cargo clippy --features full                      # packages/core
cargo check                                       # localsend_isolates/rust、server、cli
```

任何一条不过,不进入打包步骤。

## 第三步:打包给人工验证(不发布)

- **Android APK / 桌面包 / 鸿蒙 HAP** 走对应 `build_*.yml` 工作流
  (鸿蒙是 `Build HarmonyOS HAP`,手动触发,产物在 Actions run 的 Artifacts 里下载)。
- **测试包绝不发布到 Release**:artifact 只用于人工验证。签名材料齐时出 signed HAP,
  否则出 unsigned HAP(需本地签名后 `hdc install`,见 `docs/HARMONYOS.md`)。
- 打包后把 artifact 链接和「人工测试清单」(见 `docs/HARMONYOS.md` 的 QA checklist
  或对应平台清单)一起交给使用者,等待人工确认。

## 第四步:人工确认后发布

- 只有使用者明确说「包没问题,发 release」才走发布:
  CHANGELOG 归档 → release PR → tag 推送 → `release.yml` 自动出发布说明。
- 人工测试发现的问题回到第一步修复,修复后**重新走第二、三步**,不要直接发布。

## 红线

- 测试包不进 Release、不打版本 tag。
- 人工验证是发布的硬门禁,没有例外。
- 凭证(签名 p12/cer/p7b、口令)只走 GitHub Secrets,不进代码、不进日志。
