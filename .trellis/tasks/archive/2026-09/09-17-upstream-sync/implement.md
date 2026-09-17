# 实施清单

## 1. 分支与合并

- [ ] `git fetch upstream --tags` 确认待合并提交仍为 6 个
- [ ] `git checkout -b chore/upstream-sync`
- [ ] `git merge upstream/main`(预期无冲突;有冲突按 design 原则解决)
- [ ] 记录 merge commit hash

验证:`git log --oneline -3` 显示 merge commit;`git log --oneline main..upstream/main` 为空

## 2. 鸿蒙约束回归检查

- [ ] `grep -rn "TargetPlatform.ohos" app/lib packages` 无结果
- [ ] 检查合并带入的 `defaultTargetPlatform` switch 是否穷举(无 default)
- [ ] `grep -n "cfg(target_env" packages/localsend_isolates/rust/Cargo.toml` 确认 ohos
      features 仍含 `discovery`
- [ ] `actionlint .github/workflows/*.yml`(或至少本次变更涉及的工作流)

## 3. 全量测试(本地,提交前)

```bash
export PATH="$PWD/.fvm/flutter_3_41_9/bin:$PATH"
cd app && flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
cd ../packages/localsend_isolates && flutter pub get && flutter test
cd ../core && cargo clippy --features full --all-targets && cargo test --features full
cd ../.. && cargo check --package rust_lib_localsend_app --package localsend-cli --package server
```

- [ ] 以上全部通过;中文内容扫 U+FFFD

## 4. PR 与合并

- [ ] `git push origin HEAD:chore/upstream-sync`
- [ ] `gh pr create -R nicholyx/localsend --body-file /tmp/pr-body.md`(正文写 为什么/做了什么/取舍/测试)
- [ ] `gh pr checks <N> -R nicholyx/localsend` 全绿
- [ ] `gh pr merge <N> -R nicholyx/localsend --merge --delete-branch`

## 5. 出包与收尾

- [ ] `gh workflow run build_ohos_hap.yml -R nicholyx/localsend -f build_mode=debug`
- [ ] 轮询 run 状态;成功后验证 artifact 存在
- [ ] 在 Issue #3(真机 QA)留言新的 artifact 链接与验证重点(传输性能/新增语言)
- [ ] 更新 spec:若本次出现新的上游合并经验(冲突模式、验证盲点),写入 harmonyos 或 maintenance spec
- [ ] `task.py archive 09-17-upstream-sync`

## 回滚点

- 合并后测试失败 → 在分支上修复;无法修复则放弃 PR(不动 main)
- 已合并但 HAP 构建失败 → 单独修 CI(不影响 main 的代码正确性)
