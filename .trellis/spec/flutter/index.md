# Flutter / Dart 规范

> 覆盖 `app/lib/**`、`app/test/**`、`packages/localsend_isolates/lib/**`。
> 鸿蒙平台相关规则见 [harmonyos/index.md](../harmonyos/index.md)。

## 工具链

- **一律 `fvm flutter` / `fvm dart`**,版本以 `.fvmrc` 为准;本机若无 fvm,SDK 在
  仓库 `.fvm/flutter_3_41_9/bin`(首次运行会补下载 Dart SDK)
- 格式化 **150 列**(`analysis_options.yaml` 的 `page_width: 150`,
  `trailing_commas: preserve`);任何把生成代码重排成 80 列的,用
  `fvm dart format` 收尾,diff 里出现 80 列重排就是噪音

## 命令

```bash
fvm flutter pub get
fvm dart run build_runner build   # dart_mappable、freezed、flutter_gen、mockito
fvm dart run slang                # i18n codegen(slang_build_runner 在 build.yaml 里禁用)
fvm flutter analyze
fvm flutter test                  # app/ 与 packages/localsend_isolates/ 各自跑
```

- 模型用 dart_mappable(`@MappableClass`);`fromJson`/`toJson` 是 Map 转换,
  `deserialize`/`serialize` 是字符串转换(两个 build.yaml 里配置过)
- 状态管理是 Refena(不是 Riverpod);provider 在 `app/lib/provider/`,
  isolate 相关的用 `ReduxProvider` + action 类

## i18n(slang)

- 源文件 `app/assets/i18n/`(`<locale>.json` + `_missing_translations_<locale>.json`),
  生成物在 `app/lib/gen/`;`@` 前缀字段是 Weblate 元数据,应用不读
- `app/test/unit/i18n_test.dart` 守护 locale 集合,加语言要同步

## 平台相关

- 平台能力判断统一走 `app/lib/util/native/platform_check.dart`;
  鸿蒙检测见 harmonyos spec(`checkPlatformIsOhos`)
- 方法 channel:Android 走 `android_channel.dart`,鸿蒙走 `ohos_channel.dart`,
  原生端在 `LocalsendOhosPlugin.ets` —— 改协议时两端同步
- FOSS 剥离脚本依赖 `# [FOSS_REMOVE]` 与 `// [FOSS_REMOVE_START/END]` 标记,
  动 `lib/config/init.dart`、`lib/pages/donation/*`、`lib/provider/purchase_provider.dart`
  时不得破坏
- FRB codegen(`flutter_rust_bridge_codegen generate`,在
  `packages/localsend_isolates/` 下跑)会顺手把 `app/test/mocks.mocks.dart`
  重排成 80 列 —— diff 里出现就还原该文件

## 测试基线

- CI 的 `test` job 跑 `flutter analyze` + 两个包的 `flutter test`;
  提交前本地全跑,任何一条不过不打包(dev-cycle)
