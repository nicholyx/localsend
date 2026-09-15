# HarmonyOS 移植规范(核心)

> 覆盖 `app/ohos/**`、`third_party/flutter/**`、cargokit ohos 支持、CI 打包与签名。
> 全部规则来自 2026-09 鸿蒙移植与 27 轮 CI 调试的真实踩坑。移植总文档:
> [docs/HARMONYOS.md](../../docs/HARMONYOS.md)。

## 架构速览

| 部件 | 位置 |
| --- | --- |
| OHOS 应用壳(hvigor、entry ability、module 配置) | `app/ohos/` |
| 应用自有平台 channel(文件打开/package_info/wakelock) | `app/ohos/entry/src/main/ets/entryability/LocalsendOhosPlugin.ets` |
| vendored OHOS 插件实现 | `third_party/flutter/`(见其 README) |
| cargokit 对 `ohos-arm64` target 的支持 | `packages/localsend_isolates/rust_builder/` |
| CI 打包工作流 | `.github/workflows/build_ohos_hap.yml`(手动触发) |

- Rust 网络核心(HTTP 服务/客户端、组播发现)在 OHOS 上原样运行;仅 **WebRTC 被排除**
  (`webrtc` crate 编不过 `aarch64-unknown-linux-ohos`),Dart 侧 `webRTCEnabled = false`,
  `api/webrtc.rs` 提供同签名 stub
- 依赖方向不变:`app` → `localsend_isolates` → core;鸿蒙只加路径依赖与 target 分支

## 硬规则(违反必返工)

### 平台检测(Dart)

- 判断鸿蒙一律用 `Platform.operatingSystem == 'ohos'`(已封装为
  `checkPlatformIsOhos()`,`app/lib/util/native/platform_check.dart`)
- **禁止引用 `TargetPlatform.ohos`**:它只存在于 flutter-ohos fork,标准 SDK 编译失败;
  反过来,ohos fork 给枚举**加了 `ohos` 值**,所以对 `defaultTargetPlatform` 的
  **穷举 switch 在鸿蒙下编译报 not exhaustively matched** —— 新代码用 if-else 或
  补 `default:` 分支(需 `// ignore: unreachable_switch_default`,标准 SDK 下该
  default 不可达;出处:device_info_helper.dart / directories.dart / platform_strings.dart)

### Rust(ohos target)

- `packages/localsend_isolates/rust/Cargo.toml` 中 ohos target 的 core features
  固定为 `["crypto", "discovery", "http", "multicast"]` —— **漏 `discovery` 会
  unresolved import**(api/discovery.rs 依赖它);漏排查入口:cargo check --target
- `webrtc` 不进 feature;stub 必须与真实类型**字段完全一致**,否则 frb_generated.rs
  编译失败
- 本地无法完整交叉编译(ring 的 build script 需要 OHOS clang);验证手段是 CI 的
  `cargo check --target aarch64-unknown-linux-ohos`(需要 SDK clang/sysroot 环境变量,
  sysroot 在 `<clt>/sdk/default/openharmony/native/sysroot`)

### 版本三处同步

升级 Flutter 时,以下三处必须一致,否则 CI 失败:

1. `.fvmrc`(如 `3.41.9`)
2. `.github/workflows/ci.yml` 的 `FLUTTER_VERSION`
3. `.github/workflows/build_ohos_hap.yml` 的 `OHOS_FLUTTER_BRANCH`
   (`oh-3.41.9-dev`,flutter-ohos fork 的分支名跟随上游版本号;分支列表见
   gitcode.com/openharmony-tpc/flutter_flutter)

### vendored 插件(third_party/flutter/)

- 新增/更新插件:放进 `third_party/flutter/<name>`,在 `app/pubspec.yaml` 用
  `path:` 依赖注册(仅 ohos 平台生效,不影响其它平台),并在
  `third_party/flutter/README.md` 登记上游地址与许可证
- **LICENSE 必须带上**(曾补过 permission_handler_ohos 的 Apache-2.0);
  pubspec 里引用已删目录(assets/example)会导致 hvigor 报 unable to find directory
- pub 包因穷举 switch 在鸿蒙编不过时,vendor 一份打补丁 +
  `dependency_overrides` 接入(先例:flex_color_picker,default 分支纯增量)

### ArkTS(ets)

- Command Line Tools 26(API 26)的 ArkTS 严格空检查:nullable 值传给
  Object/string 参数会报错,守卫或 `as` 断言(先例:MessagesAsync.ets 的
  `wrapped.push(result as Object)`、PathProviderPlugin 的空 context 守卫)
- flutter_ohos har 自带的 WARN(`@ObjectLink`、duplicate component id)可忽略,
  不要去修 har 里的代码

### GitHub 操作

- `gh` 一律 `-R nicholyx/localsend`;推当前分支用 `git push origin HEAD`
- 分支保护要求 `ci-summary`(enforce_admins=false,管理员直推 main 会提示 bypass)

## CI 打包(build_ohos_hap.yml)

触发方式:`gh workflow run build_ohos_hap.yml -R nicholyx/localsend -f build_mode=debug`。
产物是 workflow artifact(**未签名**),供人工测试,**不进 release**。

链路要点(每条都踩过):

- Command Line Tools 用 **26.0.0.821**(6.1.0.830 的 API 20 与 flutter_ohos har
  的 autoFillManager 不兼容,ArkTS 编译失败);镜像 `xiaobingtech/commandline-tools-linux-x64-*`,
  用 **codeload 单请求 tar 包**下载 —— raw.githubusercontent 对 Actions 出口 IP 间歇 404;
  分卷 7z 内还包一层 zip,要解两层
- flutter-ohos SDK 必须**完整克隆含 tags**:浅克隆版本号变 `0.0.0-unknown`,
  pub 解析直接失败;`HOS_SDK_HOME` 指向 `<clt>/sdk/default`(校验逻辑:
  其子目录需含 `toolchains`,见 fork 的 ohos_sdk.dart);ohpm/hvigorw 在 `<clt>/bin`
- **未签名产出方式**:CI 里无法复现 hvigor SignHap 的签名状态(material 目录的
  ac/ce/fd 缓存约定,报错依次是 not a directory / empty directory / can not find fd,
  别再走 CI 内签名路线)。做法:`configure_ohos_signing.py` 给 signingConfigs 填
  占位条目(过 flutter 工具的非空检查)+ 把 product 的 `signingConfig` 引用摘掉 →
  hvigor 打出 `entry-default-unsigned.hap`;flutter 工具随后因找不到 signed 文件名
  报非零退出,工作流用 `continue-on-error: true` + 校验产物兜底(真构建失败仍会红)
- 签名安装:本地 DevEco Studio 自动签名,或 hap-sign-tool 对 unsigned HAP
  `sign-app`;AGC 证书就位后可配 `OHOS_SIGNING_*` secrets 恢复 CI 签名(见 issue #2)

## 人工 QA

每次出包后按 `docs/HARMONYOS.md` 的 QA checklist 跑一遍(发现、收发文件、
打开文件/文件夹、设置持久化、web send);测试包不进 release,人工验证通过
才允许按 dev-cycle 流程发版。
