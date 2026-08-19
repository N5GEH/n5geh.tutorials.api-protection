#!/usr/bin/env bash
#
# Diagnose TLS/HTTPS certificate verification for the N5GEH API protection
# framework. It verifies that the CA configured via KONG_LUA_SSL_TRUSTED_CERTIFICATE
# is actually being used by Kong and that the Keycloak certificate served over
# HTTPS is signed by that CA.
#
# This helps troubleshoot the following OIDC introspection error:
#
#   "accessing introspection endpoint (...) failed:
#    21: unable to verify the first certificate"
#
# Usage:
#   ./scripts/check-tls.sh [keycloak-host] [keycloak-https-port]
#
# Defaults:
#   keycloak-host       127.0.0.1
#   keycloak-https-port 8543
# -----------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CERT_DIR="${CERT_DIR:-"$REPO_DIR/certs"}"
KONG_CONTAINER="${KONG_CONTAINER:-kong}"

HOST="${1:-${KEYCLOAK_HOSTNAME:-127.0.0.1}}"
PORT="${2:-${KEYCLOAK_HTTPS_PORT:-8543}}"

PASS=0
FAIL=0

ok()   { echo "  [OK]  $1"; PASS=$((PASS + 1)); }
bad()  { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  [WARN] $1"; }

section() { echo; echo "== $1 =="; }

docker_exec() {
  if command -v docker >/dev/null 2>&1 && docker inspect "$KONG_CONTAINER" >/dev/null 2>&1; then
    docker exec "$KONG_CONTAINER" "$@"
    return 0
  fi
  return 1
}

section "Local certificates"
if [[ -f "$CERT_DIR/rootCA.pem" ]]; then
  ok "rootCA.pem exists ($CERT_DIR/rootCA.pem)"
else
  bad "rootCA.pem missing - run ./scripts/generate-certs.sh"
fi

if [[ -f "$CERT_DIR/keycloak/keycloak.crt" ]]; then
  ok "keycloak.crt exists"
  if openssl verify -CAfile "$CERT_DIR/rootCA.pem" "$CERT_DIR/keycloak/keycloak.crt" >/dev/null 2>&1; then
    ok "keycloak.crt is signed by rootCA.pem"
  else
    bad "keycloak.crt is NOT signed by rootCA.pem"
  fi
else
  bad "keycloak.crt missing"
fi

section "Kong container"
if command -v docker >/dev/null 2>&1; then
  if docker inspect "$KONG_CONTAINER" >/dev/null 2>&1; then
    ok "Kong container '$KONG_CONTAINER' is running"

    if docker exec "$KONG_CONTAINER" printenv KONG_LUA_SSL_TRUSTED_CERTIFICATE 2>/dev/null; then
      echo "  KONG_LUA_SSL_TRUSTED_CERTIFICATE=$(docker exec "$KONG_CONTAINER" printenv KONG_LUA_SSL_TRUSTED_CERTIFICATE 2>/dev/null)"
    else
      bad "KONG_LUA_SSL_TRUSTED_CERTIFICATE is not set in the container"
    fi

    if docker exec "$KONG_CONTAINER" sh -c 'grep -n lua_ssl_trusted_certificate "$KONG_PREFIX/nginx-kong-inject.conf" 2>/dev/null || grep -rn lua_ssl_trusted_certificate /usr/local/kong/nginx-kong-inject.conf 2>/dev/null' 2>/dev/null; then
      ok "lua_ssl_trusted_certificate directive present in nginx-kong-inject.conf"
    else
      bad "lua_ssl_trusted_certificate directive NOT found in the generated nginx config"
    fi

    for ca in /usr/local/kong/.ca_combined /usr/local/kong/.ca_combined; do
      if docker exec "$KONG_CONTAINER" sh -c "test -f '$ca'" 2>/dev/null; then
        break
      fi
    done
    if docker exec "$KONG_CONTAINER" sh -c 'ls "$KONG_PREFIX"/.ca_combined 2>/dev/null || ls /usr/local/kong/.ca_combined 2>/dev/null' 2>/dev/null; then
      ok "combined CA file exists"
      docker exec "$KONG_CONTAINER" sh -c 'for f in "$KONG_PREFIX"/.ca_combined /usr/local/kong/.ca_combined; do [ -f "$f" ] && openssl crl2pkcs7 -nocrl -certfile "$f" 2>/dev/null | openssl pkcs7 -print_certs -noout 2>/dev/null | grep subject; done' 2>/dev/null
    else
      warn "combined CA file not found (Kong may not have been (re)started with the env var)"
    fi
  else
    warn "Kong container '$KONG_CONTAINER' not running - skipping container checks"
  fi
else
  warn "docker CLI not found - skipping container checks"
fi

section "Keycloak served certificate (https://$HOST:$PORT)"
if command -v openssl >/dev/null 2>&1; then
  if echo | openssl s_client -connect "$HOST:$PORT" -servername "$HOST" 2>/dev/null | openssl x509 -noout -subject >/dev/null 2>&1; then
    echo "  server subject: $(echo | openssl s_client -connect "$HOST:$PORT" -servername "$HOST" 2>/dev/null | openssl x509 -noout -subject)"
    if echo | openssl s_client -connect "$HOST:$PORT" -servername "$HOST" -CAfile "$CERT_DIR/rootCA.pem" 2>/dev/null | openssl verify -CAfile "$CERT_DIR/rootCA.pem" >/dev/null 2>&1; then
      ok "served certificate is signed by rootCA.pem"
    else
      bad "served certificate is NOT signed by rootCA.pem (or is self-signed / from another CA)"
    fi
  else
    warn "could not connect to https://$HOST:$PORT (is Keycloak up?)"
  fi
else
  warn "openssl CLI not found"
fi

echo
echo "Summary: $PASS passed, $FAIL failed"
echo
if [[ $FAIL -gt 0 ]]; then
  echo "Remediation:"
  echo "  - Recreate the Kong container after setting KONG_LUA_SSL_TRUSTED_CERTIFICATE"
  echo "    so Kong regenerates its nginx config and .ca_combined trust store."
  echo "  - Ensure the Keycloak HTTPS certificate is signed by certs/rootCA.pem"
  echo "    (regenerate with ./scripts/generate-certs.sh if needed)."
  echo "  - Raise KONG_LUA_SSL_VERIFY_DEPTH if the served chain has intermediates."
  echo "  - As a development fallback, set ssl_verify: \"no\" on the OIDC plugin."
  exit 1
fi

echo "TLS configuration looks correct."
