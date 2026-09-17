# 上游同步规范(upstream sync)

> 本 fork(nicholyx/localsend)是长期维护线,上游 `localsend/localsend` 不接受 AI 生成
> 的贡献,因此上游更新必须定期并入。首次完整实践:2026-09-17(PR #9,6 个上游提交)。
> 本文件是**可执行流程 + 校验矩阵**,照着做即可。

## 1. 触发场景

- 上游有新提交,且其中包含与鸿蒙端相关的修复(本 fork 复用同一 `packages/core` 与
  `app/lib`,合并即"移植");或距上次同步已有一段时间(越晚合越难)

## 2. 命令契约

```bash
git fetch upstream --tags
git rev-list --left-right --count main...upstream/main   # 分叉计数(左=本地独有,右=上游待并入)
git log --oneline main..upstream/main                    # 待并入提交清单(逐条评估影响面)
git merge-tree --write-tree --name-only main upstream/main   # 冲突预检:只输出 tree OID = 干净
git checkout -b chore/upstream-sync
git merge upstream/main --no-edit                        # 保留上游提交与作者信息
```

合并完成后 `git log --oneline main..upstream/main` 必须为空。

## 3. 约定(设计决策)

- **merge,不 rebase**:fork 有 40+ 自有提交,rebase 会重写已发布历史;merge commit 让
  下次同步时 `main..upstream/main` 仍然只列出真正的差异
- **连带合入与鸿蒙无关的提交**(macOS/CI bump):有意的——cherry-pick 挑拣会让下次
  同步难以判断哪些已合
- **冲突解决原则**:上游改动优先 + 保留 fork 专属逻辑(`app/ohos/**`、`third_party/**`、
  CI 工作流、Trellis);出现冲突的文件必须重跑与其相关的验证
- **不在同步 PR 里修既有问题**:发现的既有缺陷单开 Issue(先例:Issue #10)

## 4. 校验与错误矩阵

| 条件 | 含义 | 动作 |
| --- | --- | --- |
| `flutter analyze` 报 `non_exhaustive_switch_expression`(如 `AppLocale`) | 上游新增了 locale | 在 `app/lib/util/i18n.dart` 的 `getLocaleName()` **补显式 case**(见踩坑 1) |
| `i18n_test.dart` 的 "All locales should be supported by Flutter" 失败 | 新 locale 不在 Flutter 的 `kMaterialSupportedLanguages` | 评估是否可保留该 locale,并与上游对齐 |
| `cargo test --features full` 个别用例失败 | 可能是环境敏感/既有 | 用干净 worktree 在 `main` 上复现判别(见踩坑 3) |
| `dart run slang` 后 `git status` 有变化 | `app/lib/gen` 与 assets 漂移 | 提交重生成结果;不要手工改 gen |
| 上游动了 `packages/localsend_isolates/rust/**` 或 `app/ohos/**` | 直接触碰鸿蒙移植层 | 按 `spec/harmonyos/` 全量回归 |

## 5. 好 / 基准 / 坏

- **Good**:预检无冲突 → merge → 第 6 节全量验证 → PR 绿 → merge → 出 HAP 供人工 QA
- **Base**:预检有冲突 → 按第 3 节原则解冲突 → 重跑冲突文件相关验证 → 同 Good
- **Bad**:直接 `git pull upstream main` 到工作区,不预检、不建 PR、不跑鸿蒙回归
  (漏掉编译期错误会在 CI 才炸,且没有 PR 记录可回溯)

## 6. 必跑验证(收尾门禁)

```bash
# Dart(app/)
dart format --set-exit-if-changed lib test && flutter analyze && flutter test
# Dart(packages/localsend_isolates/)
flutter test
# Rust
cargo test --features full                      # packages/core(失败先判既有,见踩坑 3)
cargo check --package rust_lib_localsend_app --package localsend-cli --package server
# 生成物零漂移
cd app && dart run slang && git status --short   # 期望:无输出
# 鸿蒙回归
grep -rn "TargetPlatform\.ohos" app/lib packages   # 期望:仅注释
grep -n -A1 'cfg(target_env = "ohos")' packages/localsend_isolates/rust/Cargo.toml
actionlint .github/workflows/*.yml               # 期望:无新增
```

最后:PR CI(`ci-summary`)全绿 → `gh pr merge <N> -R nicholyx/localsend --merge --delete-branch`
→ `gh workflow run build_ohos_hap.yml -R nicholyx/localsend -f build_mode=debug` →
在 Issue #3 留言 artifact 与本轮验证重点。

## 7. 错误 vs 正确

#### Wrong
```bash
# 只跑 flutter test 就合并:漏掉 analyze 的穷举 switch 错误与 Rust 侧回归
git checkout main && git merge upstream/main && git push
```

#### Correct
```bash
git merge-tree --write-tree --name-only main upstream/main   # 预检
git checkout -b chore/upstream-sync && git merge upstream/main --no-edit
# 第 6 节全量验证 → 分支 PR → CI 绿 → merge → 出 HAP
```

## 踩坑记录(带出处)

### 1. 上游新增语言会破坏 `AppLocale` 穷举 switch

- **症状**(2026-09-17,PR #9):上游 `3b62269a` 加入 `ky` 翻译并重新生成 locale 枚举后,
  `app/lib/util/i18n.dart` 的 `getLocaleName()` 少一个 case → `flutter analyze` 直接失败
  (`non_exhaustive_switch_expression`)。**上游自身同样缺这个 case**——不要假设上游是绿的
- **修复**:补 `AppLocale.ky => 'Кыргызча',`(位置按语言代码字典序,插在 `ko` 与 `lo` 之间)
- **反例警告**:不要用 `default:` 兜底。语言名表是显式清单,default 会把漏掉的 locale
  静默显示成错误名字
- **与 harmonyos spec 的规则区分**:`TargetPlatform` 这类**平台枚举**因为 fork 多一个
  `ohos` 值,才必须用 `default`/if-else;`AppLocale` 这类**业务枚举**要显式补 case

### 2. 生成物一致性靠"零漂移"验证,不靠肉眼

`app/lib/gen/**` 是 slang 生成物。合并带入生成物后,必须 `cd app && dart run slang &&
git status --short` 确认无变化(零漂移)。手工编辑 gen 会被下次 codegen 覆盖,且掩盖
assets 与 gen 的不一致。

### 3. 判别"既有失败"与"本次回归"

本机(macOS)`cargo test --features full` 中 `event_backpressure::subnet_scan_finishes_when_
events_are_not_consumed` 稳定失败(环境敏感;Linux CI 通过)。判别方法:

```bash
git worktree add /tmp/ls-main main
cd /tmp/ls-main/packages/core && cargo test --features full --test event_backpressure
git worktree remove --force /tmp/ls-main
```

若在干净 `main` 上同样失败 → 既有问题,登记 Issue(先例:#10),不要塞进同步 PR。

### 4. GitHub 侧

gh 一律 `-R nicholyx/localsend`(多远端下默认解析到上游);推当前分支用
`git push origin HEAD`。详见 [index.md](index.md)。
