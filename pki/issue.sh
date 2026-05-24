#!/usr/bin/env bash
# Tiny mTLS PKI for the term web terminal stack.
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
DAYS_CA=3650
DAYS_CLIENT=825   # 27 months; under the Apple+Chrome 825-day ceiling
DAYS_SERVER=3650  # server CA is ours; no browser 825-day ceiling applies

decrypt_ca_key() {
  age -d -i "$HOME/.config/sops/age/keys.txt" "$CA_KEY_ENC"
}

cmd_ca() {
  [ ! -f "$CA_CRT" ] || { echo "$CA_CRT already exists; refusing to overwrite" >&2; exit 1; }
  tmp=$(mktemp -d); trap "rm -rf '$tmp'" EXIT
  openssl genpkey -algorithm ed25519 -out "$tmp/ca.key"
  openssl req -x509 -new -key "$tmp/ca.key" -days "$DAYS_CA" \
    -subj "/CN=zimbatm term mTLS CA" -out "$CA_CRT"
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
  openssl genpkey -algorithm ed25519 -out "$tmp/c.key"
  openssl req -new -key "$tmp/c.key" -subj "/CN=$name" -out "$tmp/c.csr"
  openssl x509 -req -in "$tmp/c.csr" -CA "$CA_CRT" -CAkey "$tmp/ca.key" \
    -CAcreateserial -days "$DAYS_CLIENT" -sha256 -out "$tmp/c.crt"
  # Generate p12 with a random password — printed once, not stored.
  pw=$(openssl rand -base64 18)
  openssl pkcs12 -export -inkey "$tmp/c.key" -in "$tmp/c.crt" \
    -certfile "$CA_CRT" -name "$name" -out "$out" -passout "pass:$pw"
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
  openssl genpkey -algorithm ed25519 -out "$tmp/s.key"
  cat > "$tmp/ext.cnf" <<EOF
subjectAltName = DNS:${fqdn}
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
EOF
  openssl req -new -key "$tmp/s.key" -subj "/CN=${fqdn}" -out "$tmp/s.csr"
  openssl x509 -req -in "$tmp/s.csr" -CA "$CA_CRT" -CAkey "$tmp/ca.key" \
    -CAcreateserial -days "$DAYS_SERVER" -sha256 \
    -extfile "$tmp/ext.cnf" -out "$crt_out"
  age -e -r "$ZIMBATM_AGE_RECIPIENT" -r "$host_pubkey" -o "$key_out_enc" "$tmp/s.key"
  echo "wrote $crt_out + $key_out_enc"
  echo "remember to add to secrets/secrets.nix:"
  echo "  \"${fqdn}-server-key.age\".publicKeys = [ zimbatm <host> ];"
}

case "${1:-}" in
  ca)     shift; cmd_ca "$@" ;;
  client) shift; cmd_client "$@" ;;
  server) shift; cmd_server "$@" ;;
  *) echo "usage: $0 {ca | client <name> | server <fqdn> <host-pubkey>}" >&2; exit 1 ;;
esac
