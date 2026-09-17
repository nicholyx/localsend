# 设计:上游同步与鸿蒙影响面

## 合并策略

- 分支 `chore/upstream-sync` 从 `main` 切出
- `git merge upstream/main`(merge commit,保留上游原始提交与作者信息;
  不用 rebase——fork 已有 44 个提交,rebase 会重写全部历史)
- 预检无冲突(`git merge-tree --write-tree main upstream/main` = 干净);
  若实际合并出现冲突,按"上游改动优先 + 保留鸿蒙专属分支逻辑"原则逐个解决,
  冲突文件必须重新跑该文件相关的验证

## 为什么"移植到鸿蒙"大部分是自动的

鸿蒙端复用同一份代码,只有平台层是分支:

```
app/ohos/**            ← 平台壳(与上游无关)
third_party/flutter/** ← vendored OHOS 插件(与上游无关)
packages/core/**       ← 上游代码,鸿蒙原样使用(本次 transfer.rs 命中)
app/lib/**             ← 上游代码,鸿蒙原样使用(本次 i18n 命中)
packages/localsend_isolates/rust/Cargo.toml  ← 唯一按 target 分支依赖的地方
```

因此本次"移植"= 合并 + **验证鸿蒙约束无回归** + 重新出包,而不是再写适配代码。

## 影响面与风险

| 变更 | 影响 | 验证手段 |
| --- | --- | --- |
| `transfer.rs` 通道容量 16→4 | 收发文件时的内存占用下降、预读减少;所有平台(含 ohos)行为一致 | 编译通过 + 单测;真机 QA(传输速度/内存) |
| 新增 `ky` locale | `app/assets/i18n/ky.json` + `app/lib/gen` 重新生成 | `i18n_test.dart`(locale 集合守卫)+ analyze |
| CI action bumps | 本 fork 有同名工作流(windows exe 用到 azure/*) | actionlint |
| macOS DMG 修复 | 无 | 无 |

## 鸿蒙专属检查点(spec 硬规则的回归面)

1. 合并后的 Dart 代码**不得**出现 `TargetPlatform.ohos`(标准 SDK 编译失败)
2. 上游若新增对 `defaultTargetPlatform` 的穷举 switch → 必须补 default
   (ohos fork 的枚举多了 `ohos` 值,否则 ArkTS/kernel 编译失败)
3. ohos target 的 core features 必须保持含 `discovery`
4. `app/lib/gen` 是生成物:合并后若有未提交的手工改动,以生成器输出为准

## 回滚

- 合并出问题:PR 不合并即可;已合并则 `git revert -m 1 <merge-commit>`
- HAP artifact 与 release 无关,回滚不影响任何已发布产物

## 决策记录

- 选择在 fork 的 `main` 上合并上游(而非把鸿蒙工作搬到上游分支):
  上游明确不接受 AI 生成贡献,本 fork 是独立维护线
- 选择保留 merge commit 而非 squash:上游提交历史对后续再同步有用
  (下次 `git log main..upstream/main` 能正确只列出真正的差异)
