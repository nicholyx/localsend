# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "rust_lib_localsend_app")
project(${PROJECT_NAME} LANGUAGES CXX)

# The OHOS (HarmonyOS) hvigor build does not provide FLUTTER_TARGET_PLATFORM,
# so tell cargokit explicitly which target it is building for. This maps to
# the Rust target aarch64-unknown-linux-ohos inside cargokit's target table.
set(FLUTTER_TARGET_PLATFORM "ohos-arm64")

include("../../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../../../rust rust_lib_localsend_app "")

# List of absolute paths to libraries that should be bundled with the plugin.
# The .so produced by cargokit is copied to ../libs/arm64-v8a/ by
# cargokit.cmake (OHOS branch), which is the standard location for prebuilt
# native libraries of an OHOS HAR and gets packaged into the final HAP.
set(rust_lib_localsend_app_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
