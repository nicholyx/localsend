#!/usr/bin/env python3
"""Configures HAP signing for the HarmonyOS build in CI.

Materializes the signing material (key store, certificate, provisioning
profile) passed by the build_ohos_hap.yml workflow and injects a
"signingConfigs" entry into app/ohos/build-profile.json5.

The material comes from an AGC (AppGallery Connect) debug certificate,
created once in DevEco Studio (File > Project Structure > Signing Configs).
See docs/HARMONYOS.md for the step-by-step guide.
"""

import argparse
import json
import pathlib
import shutil
import sys

BUILD_PROFILE = pathlib.Path(__file__).resolve().parents[2] / "app" / "ohos" / "build-profile.json5"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--p12", required=True, type=pathlib.Path, help="key store file (.p12)")
    parser.add_argument("--cert", required=True, type=pathlib.Path, help="certificate file (.cer)")
    parser.add_argument("--profile", required=True, type=pathlib.Path, help="provisioning profile (.p7b)")
    parser.add_argument("--key-alias", required=True)
    parser.add_argument("--key-password", required=True)
    parser.add_argument("--store-password", required=True)
    args = parser.parse_args()

    signing_dir = BUILD_PROFILE.parent / "signing"
    signing_dir.mkdir(parents=True, exist_ok=True)
    store = signing_dir / "signing.p12"
    cert = signing_dir / "signing.cer"
    profile = signing_dir / "signing.p7b"
    shutil.copyfile(args.p12, store)
    shutil.copyfile(args.cert, cert)
    shutil.copyfile(args.profile, profile)

    # The file is JSON5 with comments, so parse only the parts that matter:
    # assert the expected empty structure before patching, then splice the
    # signing config in textually.
    text = BUILD_PROFILE.read_text(encoding="utf-8")
    empty_configs = '"signingConfigs": []'
    if empty_configs not in text:
        print(f"ERROR: expected {empty_configs!r} in {BUILD_PROFILE}", file=sys.stderr)
        return 1

    signing_config = json.dumps(
        {
            "name": "ci",
            "material": {
                "certpath": str(cert),
                "keyAlias": args.key_alias,
                "keyPassword": args.key_password,
                "profile": str(profile),
                "signAlg": "SHA256withECDSA",
                "storeFile": str(store),
                "storePassword": args.store_password,
            },
        },
        indent=2,
    )
    # json.dumps emits double quotes, which is what json5 expects.
    text = text.replace(empty_configs, f'"signingConfigs": [{signing_config}]', 1)

    product_default = '"name": "default",\n        "signingConfig": "default",'
    if product_default not in text:
        print(f"ERROR: expected default product signingConfig in {BUILD_PROFILE}", file=sys.stderr)
        return 1
    text = text.replace(product_default, '"name": "default",\n        "signingConfig": "ci",', 1)

    BUILD_PROFILE.write_text(text, encoding="utf-8")
    print("Signing configuration written to", BUILD_PROFILE)
    return 0


if __name__ == "__main__":
    sys.exit(main())
