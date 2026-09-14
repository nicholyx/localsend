#!/usr/bin/env bash
# Generates a LOCAL self-signed debug signing material set for the HarmonyOS
# build using the hap-sign-tool shipped with the Command Line Tools.
#
# This allows the CI pipeline to produce a signed debug HAP without AGC
# (AppGallery Connect) material. Note: such a HAP is fine for emulators and
# OpenHarmony devices; on a retail HarmonyOS phone you may need proper AGC
# debug material (see docs/HARMONYOS.md, issue: "sign HAPs in CI").
#
# Outputs (into --out-dir):
#   signing.p12   key store containing all keys
#   signing.cer   app signing certificate chain (entity - sub CA - root)
#   signing.p7b   signed debug provisioning profile
#
# Usage: generate_ohos_debug_signing.sh --sign-tool <hap-sign-tool.jar> \
#          --bundle-name <name> --out-dir <dir>
set -euo pipefail

SIGN_TOOL=""
BUNDLE_NAME=""
OUT_DIR=""
KEY_PWD="localsend123"
STORE_PWD="localsend123"

while [ $# -gt 0 ]; do
  case "$1" in
    --sign-tool) SIGN_TOOL="$2"; shift 2 ;;
    --bundle-name) BUNDLE_NAME="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$SIGN_TOOL" ] || [ -z "$OUT_DIR" ]; then
  echo "Usage: $0 --sign-tool <jar> --bundle-name <name> --out-dir <dir>" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

JAVA="${JAVA_HOME:+$JAVA_HOME/bin/}java"

echo "== 1/5 root CA =="
"$JAVA" -jar "$SIGN_TOOL" generate-ca \
  -keyAlias "root" -keyAlg "ECC" -keySize "NIST-P-256" -signAlg "SHA256withECDSA" \
  -subject "C=CN,O=LocalSend,CN=LocalSend Debug Root CA" \
  -keystoreFile "signing.p12" -keystorePwd "$STORE_PWD" -keyPwd "$KEY_PWD" \
  -outFile "rootCA.cer" -validity 3650 > /dev/null

echo "== 2/5 sub CA =="
"$JAVA" -jar "$SIGN_TOOL" generate-ca \
  -keyAlias "subca" -keyAlg "ECC" -keySize "NIST-P-256" -signAlg "SHA256withECDSA" \
  -issuer "C=CN,O=LocalSend,CN=LocalSend Debug Root CA" -issuerKeyAlias "root" -issuerKeyPwd "$KEY_PWD" \
  -subject "C=CN,O=LocalSend,CN=LocalSend Debug Sub CA" \
  -keystoreFile "signing.p12" -keystorePwd "$STORE_PWD" -keyPwd "$KEY_PWD" \
  -outFile "subCA.cer" -validity 3650 > /dev/null

echo "== 3/5 app keypair + debug certificate =="
"$JAVA" -jar "$SIGN_TOOL" generate-keypair \
  -keyAlias "app" -keyAlg "ECC" -keySize "NIST-P-256" \
  -keystoreFile "signing.p12" -keystorePwd "$STORE_PWD" -keyPwd "$KEY_PWD" > /dev/null
"$JAVA" -jar "$SIGN_TOOL" generate-app-cert \
  -keyAlias "app" \
  -issuer "C=CN,O=LocalSend,CN=LocalSend Debug Sub CA" -issuerKeyAlias "subca" -issuerKeyPwd "$KEY_PWD" \
  -subject "C=CN,O=LocalSend,CN=LocalSend Debug Release" -signAlg "SHA256withECDSA" \
  -keystoreFile "signing.p12" -keystorePwd "$STORE_PWD" -keyPwd "$KEY_PWD" \
  -outForm "certChain" -rootCaCertFile "rootCA.cer" -subCaCertFile "subCA.cer" \
  -outFile "signing.cer" -validity 3650 > /dev/null

echo "== 4/5 profile keypair + signing certificate =="
"$JAVA" -jar "$SIGN_TOOL" generate-keypair \
  -keyAlias "profile" -keyAlg "ECC" -keySize "NIST-P-256" \
  -keystoreFile "signing.p12" -keystorePwd "$STORE_PWD" -keyPwd "$KEY_PWD" > /dev/null
"$JAVA" -jar "$SIGN_TOOL" generate-profile-cert \
  -keyAlias "profile" \
  -issuer "C=CN,O=LocalSend,CN=LocalSend Debug Sub CA" -issuerKeyAlias "subca" -issuerKeyPwd "$KEY_PWD" \
  -subject "C=CN,O=LocalSend,CN=LocalSend Debug Profile Release" -signAlg "SHA256withECDSA" \
  -keystoreFile "signing.p12" -keystorePwd "$STORE_PWD" -keyPwd "$KEY_PWD" \
  -outForm "certChain" -rootCaCertFile "rootCA.cer" -subCaCertFile "subCA.cer" \
  -outFile "profile.cer" -validity 3650 > /dev/null

echo "== 5/5 signed debug profile =="
python3 - "$BUNDLE_NAME" <<'PYEOF'
import json, sys, time, pathlib

bundle_name = sys.argv[1]
out = pathlib.Path("profile-template.json")
not_before = int(time.time()) - 3600
not_after = not_before + 10 * 365 * 24 * 3600
# The distribution-certificate must contain the entity certificate PEM of the
# app certificate chain (first block of signing.cer).
cer = pathlib.Path("signing.cer").read_text(encoding="utf-8")
entity_cert = cer[cer.index("-----BEGIN CERTIFICATE-----"):]
entity_cert = entity_cert[: entity_cert.index("-----END CERTIFICATE-----") + len("-----END CERTIFICATE-----\n")]
profile = {
    "version-name": "1.0.0",
    "version-code": 1,
    "app-distribution-type": "os_normal",
    "uuid": "b2a3f9c1-5f9e-465d-9508-a9e0134ffe18",
    "validity": {"not-before": not_before, "not-after": not_after},
    "type": "debug",
    "bundle-info": {
        "developer-id": "LocalSend",
        "distribution-certificate": entity_cert,
        "bundle-name": bundle_name,
        "apl": "normal",
        "app-feature": "hos_normal_app",
    },
    "acls": {"allowed-acls": [""]},
    "permissions": {"restricted-permissions": []},
    "issuer": "pki_internal",
}
out.write_text(json.dumps(profile, indent=2), encoding="utf-8")
print("profile template written")
PYEOF

"$JAVA" -jar "$SIGN_TOOL" sign-profile \
  -keyAlias "profile" -signAlg "SHA256withECDSA" -mode "localSign" \
  -profileCertFile "profile.cer" \
  -inFile "profile-template.json" \
  -keystoreFile "signing.p12" -keystorePwd "$STORE_PWD" -keyPwd "$KEY_PWD" \
  -outFile "signing.p7b" > /dev/null

rm -f rootCA.cer subCA.cer profile.cer profile-template.json
echo "done: signing.p12, signing.cer, signing.p7b in $OUT_DIR"
