#!/bin/bash
# Run one command with an imported P12; restore keychain state even on failure.
set -euo pipefail
set +x
for name in APPLE_CERTIFICATE_BASE64 APPLE_CERTIFICATE_PASSWORD; do
  [[ -n "${!name:-}" ]] || { printf 'Missing required secret: %s\n' "$name" >&2; exit 1; }
done
[[ $# -gt 0 ]] || { printf 'Usage: signing-keychain.sh COMMAND [ARGS...]\n' >&2; exit 1; }
umask 077
keychain_dir="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/rs-writer-signing.XXXXXX")"
export RS_WRITER_KEYCHAIN_PATH="$keychain_dir/signing.keychain-db"
original_keychains=()
security list-keychains -d user > "$keychain_dir/original-keychains"
while IFS= read -r keychain; do
  original_keychains+=("$keychain")
done < <(python3 -c 'import shlex,sys; print("\n".join(shlex.split(sys.stdin.read())))' < "$keychain_dir/original-keychains")
cleanup() {
  local status=$?
  trap - EXIT
  security list-keychains -d user -s ${original_keychains[@]+"${original_keychains[@]}"} >/dev/null 2>&1 || true
  security delete-keychain "$RS_WRITER_KEYCHAIN_PATH" >/dev/null 2>&1 || true
  rm -rf "$keychain_dir"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Allows the workflow's always() step to clean up after forced cancellation.
if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'RS_WRITER_KEYCHAIN_DIR=%s\n' "$keychain_dir" >> "$GITHUB_ENV"
fi
printf '%s' "$APPLE_CERTIFICATE_BASE64" | base64 --decode > "$keychain_dir/certificate.p12"
keychain_password="$(openssl rand -hex 32)"
security create-keychain -p "$keychain_password" "$RS_WRITER_KEYCHAIN_PATH"
security set-keychain-settings -lut 7200 "$RS_WRITER_KEYCHAIN_PATH"
security unlock-keychain -p "$keychain_password" "$RS_WRITER_KEYCHAIN_PATH"
security import "$keychain_dir/certificate.p12" -k "$RS_WRITER_KEYCHAIN_PATH" \
  -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
rm "$keychain_dir/certificate.p12"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "$keychain_password" "$RS_WRITER_KEYCHAIN_PATH" >/dev/null
security list-keychains -d user -s "$RS_WRITER_KEYCHAIN_PATH" ${original_keychains[@]+"${original_keychains[@]}"}
unset keychain_password APPLE_CERTIFICATE_BASE64 APPLE_CERTIFICATE_PASSWORD
"$@"
