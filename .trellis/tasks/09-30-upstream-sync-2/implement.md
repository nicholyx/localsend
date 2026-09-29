# 实施清单(第二轮上游同步)

> 网络前提:HTTPS 到 github.com 不通(代理失效),一律走 SSH:
> `git fetch git@github.com:localsend/localsend.git main:refs/remotes/upstream/main --tags`
> gh CLI 若报 EOF 则重试(参考 spec/maintenance/upstream-sync.md 的网络重试模式)

## 1. 分支与合并

- [ ] `git checkout -b chore/upstream-sync-2`(从最新 main)
- [ ] `git merge upstream/main --no-edit` → **预期 1 处冲突**:
      `app/lib/util/native/directories.dart`
- [ ] 按 `design.md` 的解法解冲突:保留 if/else + 采纳 `resolveSymbolicLinks()` +
      采纳 `FileSystemException` import
- [ ] `git add` 冲突文件 → 完成 merge commit
- [ ] 校验:`git log --oneline main..upstream/main` 为空;`git show --stat` 确认 9 提交并入

## 2. 鸿蒙约束回归

- [ ] `grep -rn "TargetPlatform\.ohos" app/lib packages` → 仅注释
- [ ] `grep -n "switch (defaultTargetPlatform)" app/lib/util/native/directories.dart` → 无结果
- [ ] `grep -n -A1 'cfg(target_env = "ohos")' packages/localsend_isolates/rust/Cargo.toml`
      → features 仍含 `discovery`
- [ ] `actionlint .github/workflows/*.yml`(或本次变更涉及的工作流)

## 3. 全量测试(本地)

```bash
export PATH="$PWD/.fvm/flutter_3_41_9/bin:$PATH"
cd app && flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
cd ../packages/localsend_isolates && flutter test
cd ../core && RUSTUP_TOOLCHAIN=1.97.1-aarch64-apple-darwin cargo test --features full
cd ../.. && cargo check --package rust_lib_localsend_app --package localsend-cli --package server
cd app && dart run slang && git status --short   # 期望:无输出(零漂移)
```

- [ ] 全部通过;`event_backpressure` 若失败 → 按 spec 的干净 worktree 法判既有(#10)
- [ ] 中文内容扫 U+FFFD

## 4. PR 与合并

- [ ] `git push origin HEAD:chore/upstream-sync-2`
- [ ] `gh pr create -R nicholyx/localsend --base main --body-file /tmp/pr-body.md`
      (为什么/做了什么/取舍/测试;写明冲突解法与"IP 限流对鸿蒙自动生效")
- [ ] CI 全绿(`gh pr checks <N>`)→ `gh pr merge <N> --merge --delete-branch`

## 5. 出包与收尾

- [ ] `gh workflow run build_ohos_hap.yml -R nicholyx/localsend -f build_mode=debug`
- [ ] 轮询;成功后验证 artifact 并**下载到本地**供人工验证
- [ ] Issue #3 留言:新 artifact + 本轮验证重点(接收端 IP 限流行为、不可读文件
      传输失败提示、保存路径显示、重命名零填充、Kyrgyz 语言)
- [ ] 更新 spec:把"上游同样修了 fork 的缺口时零冲突/同义冲突"补进
      `spec/maintenance/upstream-sync.md` 踩坑
- [ ] `add_session.py` 记录 + `task.py archive 09-30-upstream-sync-2`

## 回滚点

- 冲突解错 → 重解或放弃 PR
- 测试失败 → 分支上修复;既有失败先判别(#10 模式)
- HAP 构建失败 → 修 CI(不影响 main 代码正确性)
