# 上游同步:合并 localsend/main 并确认鸿蒙端不受影响

## 背景

本 fork(nicholyx/localsend)从上游 `25b3019c` 分叉后已积累 44 个自有提交(鸿蒙移植、
治理、Trellis)。上游在此期间新增 6 个提交,需要并入以保持与上游一致——这是 fork
的长期维护成本,越晚合并越难。

上游新增提交(2026-09-17 拉取):

| 提交 | 内容 | 对鸿蒙的影响 |
| --- | --- | --- |
| `e10e6250` | fix: reduce file stream read-ahead(`packages/core/src/model/transfer.rs`,通道容量 16→4) | **直接生效**:鸿蒙复用同一 core,影响收发文件时的内存/吞吐 |
| `3b62269a` | feat: add Kyrgyz translation (locale key `ky`) | **直接生效**:同一份 app 资源 |
| `230fb692` | i18n: regenerate | **直接生效**:`app/lib/gen/**` 生成代码 |
| `3e8d76a5` | fix(macos): DMG 分享扩展 | 鸿蒙无关,合并保持一致性 |
| `97898f41` / `325ff6bf` | CI action bump(azure/*) | 鸿蒙无关,合并保持一致性 |

冲突预检(`git merge-tree main upstream/main`)结果:**无冲突**。

## 期望(验收标准)

- [ ] 上游 6 个提交全部并入 `main`(经分支 + PR,merge commit 保留上游历史)
- [ ] `fvm dart format --set-exit-if-changed lib test` 通过
- [ ] `fvm flutter analyze` 0 issues;`fvm flutter test` 全过(app 与 localsend_isolates)
- [ ] 新增 `ky` locale 被 `app/test/unit/i18n_test.dart` 接受;`app/assets/i18n` 与
      `app/lib/gen` 一致(无需额外 codegen 即通过测试)
- [ ] Rust:`cargo clippy --features full`、`cargo test --features full`(core)通过;
      `cargo check`(plugin crate / server / cli)通过
- [ ] 鸿蒙约束无回归:Dart 侧无 `TargetPlatform.ohos` 引用;新增/改动的
      `defaultTargetPlatform` switch 均为 if-else 或带 default
- [ ] ohos target 的 core features 仍为 `["crypto", "discovery", "http", "multicast"]`
- [ ] PR 的 CI(`ci-summary`)全绿后合并
- [ ] 合并后触发 `Build HarmonyOS HAP` 并产出 artifact(供人工验证)
- [ ] 工作流文件通过 actionlint(`.github/workflows/`)

## 非目标

- 不开发新功能;不改动鸿蒙移植架构
- 不发布 release(测试包不进 release 是硬门禁)
- 不处理上游明确不接受的贡献路径(仅同步)

## 已知限制

- 上游 `3e8d76a5`(macOS DMG)与两个 CI bump 对鸿蒙无实际作用,但保留以保证
  未来合并成本不上升
- 真机行为(传输性能变化)只能由人工 QA 覆盖,见 `docs/HARMONYOS.md` QA checklist
