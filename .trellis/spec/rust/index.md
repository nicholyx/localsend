# Rust 规范

> 覆盖 `packages/core`、`packages/localsend_isolates/rust`、`cli`、`server`。
> 四个 crate 是一个 Cargo workspace(根目录共享 `Cargo.lock` 与 `target/`,
  `[profile.*]` 只能放根 `Cargo.toml`)。

## 构建与检查

```bash
cargo test --features full    # 在 packages/core —— 必须 --features full
cargo clippy --features full
cargo check                   # packages/localsend_isolates/rust、server、cli
```

- **core 裸 `cargo check`/`build` 失败是既有设计**(模块无条件声明、依赖可选),
  不是回归;验证 core 永远带 `--features full`
- 工具链版本来自 `rust-toolchain.toml`(根与 packages/localsend_isolates 各一份,
  CI 校验两者一致);本机 cargo 低于该版本时,rust-toolchain 会自动安装

## core 的 feature 门控

- features:`crypto`、`discovery`、`http`、`multicast`、`webrtc`、`webrtc-signaling`、
  `full`;`pub mod discovery` 由 `discovery` 门控,**不要与 `multicast` 混淆**
  (踩坑:ohos target 漏配 discovery → api/discovery.rs unresolved import)
- `webrtc` feature 依赖 `webrtc` crate(经 `nix`),目前编不过
  `aarch64-unknown-linux-ohos`;OHOS 上保持排除,Dart 侧 `webRTCEnabled = false`
- Android 专属路径(SAF fd 等)用 `#[cfg(target_os = "android")]`,ohos 会走
  not(android) 分支返回错误 —— 新增文件内容来源时照此模式

## flutter_rust_bridge(FRB)

- codegen 在 `packages/localsend_isolates/` 下跑
  `flutter_rust_bridge_codegen generate`;生成物 `frb_generated.rs`/`frb_generated.dart`
  是按**完整 API**(含 webrtc 真实类型)生成的 —— ohos 的 stub 类型必须与真实类型
  字段一致,codegen 才能在两个 target 下都编译
- 修改 api 签名后必须重新 codegen 并提交生成物;顺带被 80 列重排的
  `app/test/mocks.mocks.dart` 要还原

## 依赖

- 新依赖优先复用 workspace 已有的;`Cargo.lock` 在仓库根,提交时一并提交
- 版本三处同步(Flutter 版本)与 ohos target features 的完整规则见
  [harmonyos/index.md](../harmonyos/index.md)
