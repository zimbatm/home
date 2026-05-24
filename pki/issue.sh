#!/usr/bin/env bash
# Tiny mTLS PKI for the term web terminal stack, backed by smallstep `step`.
# step's defaults (ECDSA P-256, PBE-SHA1-3DES p12 packaging) are NSS- and
# Keychain-compatible out of the box — avoiding the openssl-3 / NSS traps.
#
#   ./pki/issue.sh ca                       # one-time: create term-ca.{crt,key.age}
#   ./pki/issue.sh client <name>            # issue ./pki/clients/<name>.p12
#   ./pki/issue.sh server <fqdn> <host-pubkey>
#                                           # issue ./pki/<fqdn>.crt + secrets/<fqdn>-server-key.age
#
# CA cert is committed (public); CA key is age-encrypted to zimbatm only.
# Server keys are encrypted to zimbatm + the target host's ssh-ed25519 pubkey.
set -euo pipefail
cd "$(dirname "$0")"

ZIMBATM_AGE_RECIPIENT="age1tk655t40a4zx7ry0mzj57vmw4xpr7sa0c8qnckmclj5gzjls4yzsk7weg0"
CA_CRT="term-ca.crt"
CA_KEY_ENC="term-ca.key.age"
DAYS_CA="87600h"        # 10y
DAYS_CLIENT="19800h"    # ~27 months; under Apple+Chrome 825-day ceiling
DAYS_SERVER="87600h"    # 10y; ours, no public ceiling

decrypt_ca_key() {
  age -d -i "$HOME/.config/sops/age/keys.txt" "$CA_KEY_ENC"
}

# step requires both --no-password and --insecure to skip key encryption;
# we re-encrypt the key ourselves with age (CA) or agenix (server).
STEP_LEAF_FLAGS=(--kty EC --crv P-256 --insecure --no-password --force)

cmd_ca() {
  [ ! -f "$CA_CRT" ] || { echo "$CA_CRT already exists; refusing to overwrite" >&2; exit 1; }
  tmp=$(mktemp -d); trap "rm -rf '$tmp'" EXIT
  step certificate create "zimbatm term mTLS CA" "$CA_CRT" "$tmp/ca.key" \
    --profile root-ca --kty EC --crv P-256 --not-after "$DAYS_CA" \
    --insecure --no-password --force >/dev/null
  age -e -r "$ZIMBATM_AGE_RECIPIENT" -o "$CA_KEY_ENC" "$tmp/ca.key"
  echo "wrote $CA_CRT + $CA_KEY_ENC"
}

cmd_client() {
  name="${1:?usage: $0 client <name>}"
  [ -f "$CA_CRT" ] && [ -f "$CA_KEY_ENC" ] || { echo "run '$0 ca' first" >&2; exit 1; }
  mkdir -p clients
  out="clients/$name.p12"
  [ ! -f "$out" ] || { echo "$out exists; pick a different name" >&2; exit 1; }
  tmp=$(mktemp -d); trap "rm -rf '$tmp'" EXIT
  decrypt_ca_key > "$tmp/ca.key"
  step certificate create "$name" "$tmp/c.crt" "$tmp/c.key" \
    --profile leaf --ca "$CA_CRT" --ca-key "$tmp/ca.key" \
    --not-after "$DAYS_CLIENT" "${STEP_LEAF_FLAGS[@]}" >/dev/null
  pw=$(openssl rand -base64 18)
  echo -n "$pw" > "$tmp/pw"
  step certificate p12 "$out" "$tmp/c.crt" "$tmp/c.key" --password-file "$tmp/pw" --force >/dev/null
  echo "wrote $out"
  echo "p12 password: $pw"
  echo "(save it now — not stored anywhere else)"
}

cmd_server() {
  fqdn="${1:?usage: $0 server <fqdn> <host-pubkey>}"
  host_pubkey="${2:?usage: $0 server <fqdn> <host-pubkey>}"
  [ -f "$CA_CRT" ] && [ -f "$CA_KEY_ENC" ] || { echo "run '$0 ca' first" >&2; exit 1; }
  crt_out="${fqdn}.crt"
  key_out_enc="../secrets/${fqdn}-server-key.age"
  tmp=$(mktemp -d); trap "rm -rf '$tmp'" EXIT
  decrypt_ca_key > "$tmp/ca.key"
  step certificate create "$fqdn" "$crt_out" "$tmp/s.key" \
    --profile leaf --ca "$CA_CRT" --ca-key "$tmp/ca.key" \
    --not-after "$DAYS_SERVER" --san "$fqdn" "${STEP_LEAF_FLAGS[@]}" >/dev/null
  age -e -r "$ZIMBATM_AGE_RECIPIENT" -r "$host_pubkey" -o "$key_out_enc" "$tmp/s.key"
  echo "wrote $crt_out + $key_out_enc"
}

case "${1:-}" in
  ca)     shift; cmd_ca "$@" ;;
  client) shift; cmd_client "$@" ;;
  server) shift; cmd_server "$@" ;;
  *) echo "usage: $0 {ca | client <name> | server <fqdn> <host-pubkey>}" >&2; exit 1 ;;
esac
