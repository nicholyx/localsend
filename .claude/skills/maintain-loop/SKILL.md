---
name: maintain-loop
description: LocalSend fork 的维护闭环——盘点、规划、实现、CI、发布的循环,以及本仓库的踩坑硬规则。当需要盘点未完成事项、规划下一个里程碑、走 Issue/PR 流程,或有人说「继续」「走维护流程」「按开源流程开发」时使用。
---

# 维护闭环(maintain-loop)

本仓库(nicholyx/localsend)按真实开源项目方式维护:小批量提交、分支 PR 驱动、
CI 门禁、Issue 追踪、里程碑与版本发布。功能开发的「实现→测试→打包→人工验证」
细节见 `dev-cycle` skill;本 skill 管 GitHub 侧闭环。

注意:上游 localsend/localsend 不接受 AI 生成的贡献;本仓库是自己的 fork,
不受此约束,但保持上游风格的提交规范(Conventional Commits、英文提交信息)。

## 一、盘点现状(每轮开始或被问「还剩什么没做」)

```bash
gh issue list --state open --json number,title
gh api repos/nicholyx/localsend/milestones --jq '.[] | "\(.title): 完成 \(.closed_issues) / 待办 \(.open_issues)"'
gh run list --branch main --limit 5          # CI 是否绿
git status --short && git log --oneline -5   # 本地与远端是否一致
```

## 二、规划

1. 建里程碑:`gh api repos/nicholyx/localsend/milestones -f title="vX.Y.Z" -f state=open -f description="主题"`
2. 每个任务一个 Issue:背景(真实痛点)/ 期望(验收标准 checkbox)/ 入手位置(文件、函数)/
   难度。`--milestone`,打 `enhancement` / `bug` / `documentation` 标签。
3. Roadmap Issue 是路线图单一事实来源:规划后把条目写进「计划中」,完成后移入
   「已完成」并带上 Issue 链接。

## 三、实现

- 一个 Issue = 一个分支 = 一个 PR;分支名 `feat/*`、`fix/*`、`docs/*`、`chore/*`。
- 动手前先核实 Issue 的前提是否成立(不成立就留言改写范围,不硬写)。
- 实现中发现的相邻缺陷先起独立 Issue,不打散当前 PR。
- 提交信息正文写「为什么」,不只写「改了什么」。

### 本仓库的硬规则(踩坑沉淀,违反必返工)

- 一律 `fvm flutter` / `fvm dart`,裸 `flutter`/`dart` 与 `.fvmrc` 不匹配。
- 格式化 150 列;80 列重排生成代码会制造纯噪音 diff,改完用 `fvm dart format` 收尾。
- `packages/core` 必须带 `--features full` 构建测试;裸 `cargo check` 失败是既有的
  feature 门控设计,不是回归。
- FRB codegen(`flutter_rust_bridge_codegen generate`)会顺手把 `app/test/mocks.mocks.dart`
  重排成 80 列——diff 里出现就还原它。
- FOSS 标记(`# [FOSS_REMOVE]`、`// [FOSS_REMOVE_START/END]`)不得破坏。
- `app/pubspec.yaml` 版本 = Inno Setup 版本 = CLI 版本,CI 的 packaging job 会查。
- 改 `app/ohos/` 或 Flutter 版本时,保持 `.fvmrc`、CI 的 `FLUTTER_VERSION`、
  `build_ohos_hap.yml` 的 `OHOS_FLUTTER_BRANCH` 三者一致(鸿蒙分支跟随上游版本号)。
- YAML 工作流的结构级修改(插入 `with:` 块等)逐个手工 Edit,不用批量脚本。
- 中文内容编辑后全仓扫 U+FFFD;排错文档保留报错原文。

## 四、CI 与合并

- CI 全绿才合并:`gh pr checks <N>` / `gh pr view --json statusCheckRollup`。
- 合并用 `gh pr merge <N> --merge`(保留小批量提交)或 `--squash`(单提交 PR)。
- 网络抖动是常态:`gh` / `git push` 失败重试 3-5 次;HTTPS 不通先试 SSH。
- `gh pr create` 报「push the current branch」但分支明明推过:分支不在 `origin` 时
  用 `--head <owner>:<branch>`。
- PR/Issue 正文写进临时文件(`--body-file /tmp/pr-body.md`),不用嵌套 heredoc。

## 五、发布

1. 从 main 切 `chore/release-vX.Y.Z`,把 CHANGELOG 的 `[Unreleased]` 归档为
   `[X.Y.Z] - 日期`([Unreleased] 恢复空壳),提交 `chore(release): vX.Y.Z`。
2. release PR 走完 CI,squash 合并。
3. 打 tag 前先 `git ls-remote --tags origin vX.Y.Z` 确认不存在(防抖动重推触发
   两次发布),再 `git tag -a vX.Y.Z && git push origin vX.Y.Z`。
4. 发布产物要求:对应平台的测试包已经过人工验证(见 `dev-cycle`),没有人工验证
   的平台不出包。

## 六、发布后

- Roadmap Issue 条目移入「已完成」;建下一版本里程碑;看板同步。
