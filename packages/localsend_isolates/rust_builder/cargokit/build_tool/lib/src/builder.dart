/// This is copied from Cargokit (which is the official way to use it currently)
/// Details: https://fzyzcjy.github.io/flutter_rust_bridge/manual/integrate/builtin

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'android_environment.dart';
import 'cargo.dart';
import 'environment.dart';
import 'options.dart';
import 'rustup.dart';
import 'target.dart';
import 'util.dart';

final _log = Logger('builder');

enum BuildConfiguration {
  debug,
  release,
  profile,
}

extension on BuildConfiguration {
  bool get isDebug => this == BuildConfiguration.debug;
  String get rustName => switch (this) {
        BuildConfiguration.debug => 'debug',
        BuildConfiguration.release => 'release',
        BuildConfiguration.profile => 'release',
      };
}

class BuildException implements Exception {
  final String message;

  BuildException(this.message);

  @override
  String toString() {
    return 'BuildException: $message';
  }
}

class BuildEnvironment {
  final BuildConfiguration configuration;
  final CargokitCrateOptions crateOptions;
  final String targetTempDir;
  final String manifestDir;
  final CrateInfo crateInfo;

  final bool isAndroid;
  final String? androidSdkPath;
  final String? androidNdkVersion;
  final int? androidMinSdkVersion;
  final String? javaHome;

  BuildEnvironment({
    required this.configuration,
    required this.crateOptions,
    required this.targetTempDir,
    required this.manifestDir,
    required this.crateInfo,
    required this.isAndroid,
    this.androidSdkPath,
    this.androidNdkVersion,
    this.androidMinSdkVersion,
    this.javaHome,
  });

  static BuildConfiguration parseBuildConfiguration(String value) {
    // XCode configuration adds the flavor to configuration name.
    final firstSegment = value.split('-').first;
    final buildConfiguration = BuildConfiguration.values.firstWhereOrNull(
      (e) => e.name == firstSegment,
    );
    if (buildConfiguration == null) {
      _log.warning('Unknown build configuraiton $value, will assume release');
      return BuildConfiguration.release;
    }
    return buildConfiguration;
  }

  static BuildEnvironment fromEnvironment({
    required bool isAndroid,
  }) {
    final buildConfiguration =
        parseBuildConfiguration(Environment.configuration);
    final manifestDir = Environment.manifestDir;
    final crateOptions = CargokitCrateOptions.load(
      manifestDir: manifestDir,
    );
    final crateInfo = CrateInfo.load(manifestDir);
    return BuildEnvironment(
      configuration: buildConfiguration,
      crateOptions: crateOptions,
      targetTempDir: Environment.targetTempDir,
      manifestDir: manifestDir,
      crateInfo: crateInfo,
      isAndroid: isAndroid,
      androidSdkPath: isAndroid ? Environment.sdkPath : null,
      androidNdkVersion: isAndroid ? Environment.ndkVersion : null,
      androidMinSdkVersion:
          isAndroid ? int.parse(Environment.minSdkVersion) : null,
      javaHome: isAndroid ? Environment.javaHome : null,
    );
  }
}

class RustBuilder {
  final Target target;
  final BuildEnvironment environment;

  RustBuilder({
    required this.target,
    required this.environment,
  });

  void prepare(
    Rustup rustup,
  ) {
    final toolchain = _getToolchainVersion(environment.manifestDir, _toolchain);
    if (rustup.installedTargets(toolchain) == null) {
      rustup.installToolchain(toolchain);
    }
    if (toolchain == 'nightly') {
      rustup.installRustSrcForNightly();
    }
    if (!rustup.installedTargets(toolchain)!.contains(target.rust)) {
      rustup.installTarget(target.rust, toolchain: toolchain);
    }
  }

  void prepareForOhos() {
    // Rust aarch64-unknown-linux-ohos is Tier 2 and ships with the standard
    // toolchain, so no rustup target installation is required. The linker and
    // sysroot come from the OpenHarmony SDK via _ohosBuildEnvironment().
    _log.info(
      'Skipping rustup preparation for OHOS; using installed stable toolchain',
    );
  }

  CargoBuildOptions? get _buildOptions =>
      environment.crateOptions.cargo[environment.configuration];

  String get _toolchain => _buildOptions?.toolchain.name ?? 'stable';

  /// Returns the path of directory containing build artifacts.
  Future<String> build() async {
    final extraArgs = _buildOptions?.flags ?? [];
    final manifestPath = path.join(environment.manifestDir, 'Cargo.toml');
    runCommand(
      'rustup',
      [
        'run',
        _getToolchainVersion(environment.manifestDir, _toolchain),
        'cargo',
        'build',
        ...extraArgs,
        '--manifest-path',
        manifestPath,
        '-p',
        environment.crateInfo.packageName,
        if (!environment.configuration.isDebug) '--release',
        '--target',
        target.rust,
        '--target-dir',
        environment.targetTempDir,
      ],
      environment: await _buildEnvironment(),
    );
    return path.join(
      environment.targetTempDir,
      target.rust,
      environment.configuration.rustName,
    );
  }

  Map<String, String> _ohosBuildEnvironment() {
    final sdkRoot = Environment.ohosNativeSdk;
    if (sdkRoot == null) {
      throw BuildException(
        'CARGOKIT_OHOS_NATIVE_SDK is not set. '
        'OHOS native build requires an SDK path from CMAKE_SYSROOT.',
      );
    }

    final clang = path.join(sdkRoot, 'llvm', 'bin', 'clang');
    final sysroot = path.join(sdkRoot, 'sysroot');
    if (!File(clang).existsSync()) {
      throw BuildException('OHOS clang not found at: $clang');
    }

    return {
      'RUSTUP_TOOLCHAIN': _getToolchainVersion(environment.manifestDir, _toolchain),
      'CC_aarch64-unknown-linux-ohos': clang,
      'CC_aarch64_unknown_linux_ohos': clang,
      'CFLAGS_aarch64-unknown-linux-ohos':
          '--sysroot=$sysroot --target=aarch64-unknown-linux-ohos',
      'CFLAGS_aarch64_unknown_linux_ohos':
          '--sysroot=$sysroot --target=aarch64-unknown-linux-ohos',
      'CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_LINKER': clang,
      // Target-scoped so that host artifacts (build scripts, proc macros)
      // are compiled and linked for the build host without OHOS flags.
      'CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_RUSTFLAGS':
          '-C link-arg=--target=aarch64-unknown-linux-ohos -C link-arg=--sysroot=$sysroot',
    };
  }

  Future<Map<String, String>> _buildEnvironment() async {
    if (target.ohos != null) {
      return _ohosBuildEnvironment();
    }

    if (target.android == null) {
      return {};
    } else {
      final sdkPath = environment.androidSdkPath;
      final ndkVersion = environment.androidNdkVersion;
      final minSdkVersion = environment.androidMinSdkVersion;
      if (sdkPath == null) {
        throw BuildException('androidSdkPath is not set');
      }
      if (ndkVersion == null) {
        throw BuildException('androidNdkVersion is not set');
      }
      if (minSdkVersion == null) {
        throw BuildException('androidMinSdkVersion is not set');
      }
      final env = AndroidEnvironment(
        sdkPath: sdkPath,
        ndkVersion: ndkVersion,
        minSdkVersion: minSdkVersion,
        targetTempDir: environment.targetTempDir,
        target: target,
      );
      if (!env.ndkIsInstalled() && environment.javaHome != null) {
        env.installNdk(javaHome: environment.javaHome!);
      }
      return env.buildEnvironment();
    }
  }
}

/// Regex for 'channel = "1.82.0"' capturing the version number
final _toolchainVersionPattern = RegExp(r'^channel\s*=\s*"([^"]+)"$');

/// Returns the toolchain version preferring the one from the rust-toolchain.toml
/// found next to or above the crate's manifest directory.
String _getToolchainVersion(String manifestDir, String fallback) {
  var dir = Directory(manifestDir);
  for (var i = 0; i < 3; i++) {
    final toolchainFile = File(path.join(dir.path, 'rust-toolchain.toml'));
    if (toolchainFile.existsSync()) {
      final content = toolchainFile.readAsStringSync();
      for (final line in content.split('\n')) {
        final match = _toolchainVersionPattern.firstMatch(line.trim());
        if (match != null) {
          return match.group(1)!;
        }
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      break;
    }
    dir = parent;
  }
  return fallback;
}
