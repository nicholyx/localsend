# GitHub 维护规范

> 本仓库的 Issue / PR / 里程碑 / 发布闭环。这些规则原来只存在于
> `.claude/skills/maintain-loop` 与 `dev-cycle`(按触发加载),现沉淀到 spec
> 保证每次会话自动注入;skills 保留为操作视角,两边同步维护。

## 仓库现状速查(2026-09-15)

- 远端:`origin` = fork(nicholyx/localsend),`upstream` = 上游;**gh 一律
  `-R nicholyx/localsend`**(多远端下 gh 默认解析到上游);issues 已开启
- 分支保护:main 要求 `ci-summary`(enforce_admins=false,管理员直推会提示
  bypass,但正式改动一律走 PR)
- 已建:Roadmap Issue #6(路线图单一事实来源)、里程碑 `v1.18.3 — HarmonyOS port`、
  Issues #2(CI 签名)/ #3(真机 QA)/ #4(恢复 WebRTC)/ #5(降级功能补齐)、
  Projects 看板 #2、PR 模板(why/what/trade-offs/testing)
- 完整操作细节(网络重试、`--head`、body-file 等)见 `.claude/skills/maintain-loop`

## 盘点(每轮开始)

```bash
gh issue list --state open -R nicholyx/localsend --json number,title
gh api repos/nicholyx/localsend/milestones --jq '.[] | "\(.title): \(.open_issues) 待办"'
gh run list --branch main -R nicholyx/localsend --limit 5   # CI 是否绿
git status --short && git log --oneline -5                   # 本地与远端是否一致
```

## 规划

- 一个主题一个里程碑;一个任务一个 Issue:背景(真实痛点)/ 期望(验收 checkbox)/
  入手位置(文件)/ 难度,挂里程碑、打 `enhancement`/`bug`/`documentation`/`ohos` 标签
- **Roadmap Issue(#6)是路线图单一事实来源**:规划后写入「计划中」,完成后移入
  「已完成」并带链接
- Issue 入看板:`gh project item-add 2 --owner nicholyx --url <issue-url>`

## 实现

- **一个 Issue = 一个分支 = 一个 PR**;分支名 `feat/*`、`fix/*`、`docs/*`、`chore/*`
- 动手前先核实 Issue 前提;不成立就留言改写范围,不硬写
- 实现中发现的相邻缺陷起独立 Issue,不打散当前 PR
- **小批量提交**:完成一个小功能就提交;正文写「为什么」,不只写「改了什么」;
  Conventional Commits,标题即摘要

## 开发闭环(dev-cycle)

实现 → 全量测试 → 打包(artifact)→ 人工验证 → 确认后才发布:

1. **全量测试**(提交前本地必跑,细节见各语言 spec):format/analyze/test/clippy/cargo check
2. **打包**:走对应 `build_*.yml` 工作流出 artifact(鸿蒙是 `Build HarmonyOS HAP`,
   手动触发);**测试包绝不进 release、不打版本 tag**
3. **人工验证**:把 artifact 链接 + QA 清单(`docs/HARMONYOS.md`)交给使用者;
   发现的问题回第一步,修复后重新走测试与打包
4. **发布**:只有使用者明确说「包没问题,发 release」才走发布流程(见下)

### 红线(任何时候不得违反)

- 测试包不进 Release、不打版本 tag
- **人工验证是发布的硬门禁,没有例外**
- 凭证(签名 p12/cer/p7b、口令)只走 GitHub Secrets,不进代码、不进 Issue、不进日志

## CI 与合并

- CI 全绿才合并:`gh pr checks <N> -R nicholyx/localsend`;分支保护只盯
  `ci-summary` 汇总 check
- 合并方式:多提交的 PR 用 `--merge`(保留小批量提交),单提交 PR 用 `--squash`
- PR 正文写进临时文件(`--body-file`),不用嵌套 heredoc
- 分支不在 origin 时 `gh pr create` 加 `--head nicholyx:<branch>`
- `gh`/`git push` 失败重试 3-5 次;HTTPS 不通先试 SSH

## 发布

1. main 切 `chore/release-vX.Y.Z`,把 CHANGELOG 的 `[Unreleased]` 归档为
   `[X.Y.Z] - 日期`([Unreleased] 恢复空壳),提交 `chore(release): vX.Y.Z`
2. release PR 走完 CI;合并后打 tag 前先 `git ls-remote --tags origin vX.Y.Z`
   确认不存在(防抖动重推触发两次发布),再 `git tag -a && git push origin vX.Y.Z`
3. **发布产物要求:对应平台的测试包已经过人工验证(dev-cycle 第 4 步),没有
   人工验证的平台不出包**
4. 发布后:Roadmap 条目移入「已完成」,建下一版本里程碑
