#!/usr/bin/env bash
#
# Generates a self-signed root CA and per-service leaf certificates required by
# the platform and API protection compose files.
#
#   * certs/rootCA.pem / rootCA.key   -> CA (mounted into Kong, Orion, EMQX)
#   * certs/kong/kong.{crt,key}       -> Kong TLS
#   * certs/keycloak/keycloak.{crt,key} -> Keycloak TLS
#   * certs/emqx.{crt,key}            -> EMQX TLS
#
# Usage:
#   ./scripts/generate-certs.sh
#
# The KEYCLOAK_HOSTNAME environment variable (see .env) is embedded into the
# certificate Subject Alternative Names so that the certificates are valid for
# the host you use to reach the services.
#
# TODO(security): This produces a SELF-SIGNED root CA for local development and
# tutorial purposes only. For production, replace certs/rootCA.pem and the leaf
# certificates with certificates issued by a trusted Certificate Authority and
# protect the private keys accordingly.
# -----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="${CERT_DIR:-"$SCRIPT_DIR/../certs"}"
HOSTNAME="${KEYCLOAK_HOSTNAME:-127.0.0.1}"

mkdir -p "$CERT_DIR/kong" "$CERT_DIR/keycloak"

echo "Using hostname '$HOSTNAME' for certificate SANs."

# Determine whether the hostname is an IP address to build the correct SAN entry.
SAN_ENTRY="DNS:$HOSTNAME"
if [[ "$HOSTNAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  SAN_ENTRY="IP:$HOSTNAME"
fi

# ---------------------------------------------------------------------------
# 1. Root CA
# ---------------------------------------------------------------------------
if [[ ! -f "$CERT_DIR/rootCA.pem" ]]; then
  # 1. Generate the private key
  openssl genrsa -out "$CERT_DIR/rootCA.key" 4096

  # 2. Generate a Certificate Signing Request (CSR)
  openssl req -new -key "$CERT_DIR/rootCA.key" \
    -out "$CERT_DIR/rootCA.csr" \
    -subj "/CN=N5GEH Tutorial Root CA"

  # 3. Create an explicit extensions file to avoid Ubuntu config duplication
  cat > "$CERT_DIR/rootCA.ext" <<EOF
basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign,cRLSign
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF

  # 4. Self-sign the CSR to create the Root CA
  openssl x509 -req -in "$CERT_DIR/rootCA.csr" \
    -signkey "$CERT_DIR/rootCA.key" \
    -days 3650 -sha256 \
    -out "$CERT_DIR/rootCA.pem" \
    -extfile "$CERT_DIR/rootCA.ext"

  # Cleanup temporary files
  rm -f "$CERT_DIR/rootCA.csr" "$CERT_DIR/rootCA.ext"

  echo "Generated root CA."
else
  echo "Root CA already exists, skipping."
fi

# ---------------------------------------------------------------------------
# 2. Leaf certificates
# ---------------------------------------------------------------------------
issue_cert() {
  local name="$1"
  local out_dir="$2"
  shift 2
  local sans=("$@")

  local san_list="DNS:localhost,IP:127.0.0.1,DNS:$name,$SAN_ENTRY"
  for s in "${sans[@]}"; do
    san_list="$san_list,$s"
  done

  openssl req -new -newkey rsa:2048 -sha256 -nodes \
    -keyout "$out_dir/$name.key" \
    -out "$out_dir/$name.csr" \
    -subj "/CN=$name"

  cat > "$out_dir/$name.ext" <<EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=$san_list
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
EOF

  openssl x509 -req -in "$out_dir/$name.csr" \
    -CA "$CERT_DIR/rootCA.pem" -CAkey "$CERT_DIR/rootCA.key" \
    -CAcreateserial -days 825 -sha256 \
    -out "$out_dir/$name.crt" \
    -extfile "$out_dir/$name.ext"

  rm -f "$out_dir/$name.csr" "$out_dir/$name.ext"
  echo "Generated certificate for '$name'."
}

issue_cert "kong" "$CERT_DIR/kong" "DNS:keycloak"
issue_cert "keycloak" "$CERT_DIR/keycloak" "DNS:kong"
issue_cert "emqx" "$CERT_DIR"

# Convenience alias so consumers expecting a .crt extension can reference the CA.
ln -sf "rootCA.pem" "$CERT_DIR/rootCA.crt"

echo
echo "Certificates generated in $CERT_DIR"
echo "TODO(security): replace the self-signed CA with a trusted CA for production."
