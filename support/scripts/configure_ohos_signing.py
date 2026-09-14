#!/usr/bin/env python3
"""Prepares the HarmonyOS build for an UNSIGNED HAP.

hvigor's SignHap task requires DevEco-managed signing cache state that cannot
be reproduced headlessly, and the flutter-ohos tool refuses to build a debug
HAP while `signingConfigs` is empty. To produce an unsigned HAP in CI we
therefore:

1. fill `signingConfigs` with a placeholder entry (satisfies the non-empty
   check without real material), and
2. detach the placeholder from the product by removing the product's
   `signingConfig` reference, so hvigor packages the HAP unsigned.

The unsigned HAP (entry-default-unsigned.hap) is uploaded as a workflow
artifact and must be signed before installing on a device - either locally
in DevEco Studio, with hap-sign-tool, or by configuring the OHOS_SIGNING_*
repository secrets for the AGC-based flow (see docs/HARMONYOS.md).
"""

import json
import pathlib
import sys

BUILD_PROFILE = pathlib.Path(__file__).resolve().parents[2] / "app" / "ohos" / "build-profile.json5"


def main() -> int:
    text = BUILD_PROFILE.read_text(encoding="utf-8")

    # 1) Replace the empty signingConfigs with a placeholder entry.
    empty_configs = '"signingConfigs": []'
    if empty_configs not in text:
        print(f"ERROR: expected {empty_configs!r} in {BUILD_PROFILE}", file=sys.stderr)
        return 1
    placeholder = json.dumps(
        {
            "name": "unsigned-placeholder",
            "type": "HarmonyOS",
            "material": {
                "certpath": "",
                "keyAlias": "",
                "keyPassword": "",
                "profile": "",
                "signAlg": "SHA256withECDSA",
                "storeFile": "",
                "storePassword": "",
            },
        },
        indent=2,
    )
    text = text.replace(empty_configs, f'"signingConfigs": [{placeholder}]', 1)

    # 2) Detach the placeholder from the product so hvigor skips SignHap.
    product_default = '"name": "default",\n        "signingConfig": "default",'
    if product_default not in text:
        print(f"ERROR: expected default product signingConfig in {BUILD_PROFILE}", file=sys.stderr)
        return 1
    text = text.replace(product_default, '"name": "default",', 1)

    BUILD_PROFILE.write_text(text, encoding="utf-8")
    print("Unsigned build configured (placeholder signing config detached from product).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
