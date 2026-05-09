#!/usr/bin/env bash
# Creates a stable, self-signed code-signing identity in the login keychain
# so every rebuild of Free Mac Screen Recorder produces a signature with the
# same designated requirement. macOS TCC then preserves Screen Recording /
# Camera / Microphone permissions across rebuilds.
#
# This is a one-time setup. Re-running it is a no-op if the identity exists.
set -euo pipefail

CERT_NAME="Free Mac Screen Recorder Local"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
P12_PASSWORD="fmsr-local"

echo "==> Checking for existing identity '$CERT_NAME'..."
if security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$CERT_NAME"; then
    echo "✓ Identity already present in login keychain. Nothing to do."
    exit 0
fi

# Clean any half-imported artifacts from previous attempts.
security delete-certificate -c "$CERT_NAME" -t "$KEYCHAIN" 2>/dev/null || true

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo "==> Generating self-signed code-signing certificate..."
cat > openssl.cnf <<EOF
[req]
distinguished_name = req_dn
prompt = no
x509_extensions = v3_codesign

[req_dn]
CN = $CERT_NAME

[v3_codesign]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout key.pem -out cert.pem \
    -days 7300 \
    -config openssl.cnf \
    >/dev/null 2>&1

# -legacy: emit RC2/3DES PKCS#12 that macOS keychain accepts. OpenSSL 3.x
# defaults to AES which `security import` cannot read.
openssl pkcs12 -export -legacy \
    -out cert.p12 \
    -inkey key.pem -in cert.pem \
    -name "$CERT_NAME" \
    -passout "pass:${P12_PASSWORD}" \
    >/dev/null 2>&1

echo "==> Importing private key + cert into login keychain..."
# -A: allow any application to use without prompting (acceptable for a
#  local-only signing identity). Without this, codesign would hit the
#  Keychain Access ACL prompt every build.
security import cert.p12 \
    -k "$KEYCHAIN" \
    -P "$P12_PASSWORD" \
    -A \
    >/dev/null

echo "==> Adding user-domain trust setting for code signing..."
# Without this, `security find-identity -p codesigning` ignores the cert
# even though the key+cert are present.
security add-trusted-cert \
    -r trustAsRoot \
    -p codeSign \
    -k "$KEYCHAIN" \
    cert.pem \
    >/dev/null 2>&1 \
    || echo "  (could not auto-set trust; cert may still work for codesign)"

echo ""
echo "==> Verifying identity is usable for codesign..."
# Round-trip test: sign a tiny dummy binary to confirm codesign can find
# the key for this cert. `find-identity -p codesigning` is misleading on
# self-signed certs because it gates on user-trust settings; codesign
# itself does not care about trust, only that the key + cert pair exists.
DUMMY="$WORKDIR/_codesign_test"
printf '\x00' > "$DUMMY"
if codesign --force --sign "$CERT_NAME" "$DUMMY" 2>/dev/null; then
    echo "✓ Identity '$CERT_NAME' is usable for code signing."
else
    echo "✗ codesign could not use the identity. Open Keychain Access, find"
    echo "  '$CERT_NAME', double-click, expand Trust → set Code Signing to"
    echo "  'Always Trust', enter your password, then re-run this script."
    exit 1
fi
echo ""
echo "Next steps:"
echo "  1. Run ./Scripts/build-app.sh release     # signs with the stable identity"
echo "  2. Open the rebuilt .app                  # macOS will prompt for Screen Recording"
echo "  3. Grant permission in System Settings    # the entry will now persist"
echo "  4. Quit & relaunch                        # one-time required by TCC"
echo ""
echo "On first sign you may see a Keychain Access dialog asking to allow"
echo "codesign to access the new private key — click 'Always Allow'."
