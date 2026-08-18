"""Shared fixtures and configuration for the API protection test suite.

The tests assume the platform (``platform_v2.yaml``) and the API protection
framework (``api_protection.yaml``) are running. See the root README for the
full setup instructions.
"""

import base64
import json
import os
from pathlib import Path

import pytest
import requests

ROOT = Path(__file__).resolve().parents[1]


def _load_dotenv(path: Path) -> None:
    """Minimal .env loader that does not override already-set variables."""
    if not path.exists():
        return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        os.environ.setdefault(key, value)


# Load user configuration first, then fall back to the documented defaults.
_load_dotenv(ROOT / ".env")
_load_dotenv(ROOT / ".env.example")


def _env(name: str, default: str) -> str:
    return os.environ.get(name, default)


@pytest.fixture(scope="session")
def config() -> dict:
    kong_admin_port = _env("KONG_ADMIN_PORT", "8001")
    kong_proxy_port = _env("KONG_PROXY_PORT", "8000")
    keycloak_port = _env("KEYCLOAK_HTTP_PORT", "8180")

    return {
        "kong_admin_url": _env("KONG_ADMIN_URL", f"http://127.0.0.1:{kong_admin_port}"),
        "kong_proxy_url": _env("KONG_PROXY_URL", f"http://127.0.0.1:{kong_proxy_port}"),
        "keycloak_url": _env("KEYCLOAK_URL", f"http://127.0.0.1:{keycloak_port}"),
        "realm": _env("KEYCLOAK_REALM", "kong"),
        "client_id": _env("OIDC_CLIENT_ID", "kong"),
        "client_secret": _env("OIDC_CLIENT_SECRET", "kong-client-secret"),
        "username": _env("TEST_USERNAME", "testuser"),
        "password": _env("TEST_PASSWORD", "testpassword"),
        "tenant": _env("TEST_TENANT", "ebcdev1"),
    }


@pytest.fixture(scope="session")
def access_token(config: dict) -> str:
    """Obtain a JWT from Keycloak using the resource-owner password grant."""
    url = (
        f"{config['keycloak_url']}/realms/{config['realm']}"
        "/protocol/openid-connect/token"
    )
    response = requests.post(
        url,
        data={
            "grant_type": "password",
            "client_id": config["client_id"],
            "client_secret": config["client_secret"],
            "username": config["username"],
            "password": config["password"],
            "scope": "openid",
        },
        timeout=30,
    )
    assert response.status_code == 200, (
        f"Could not obtain token from Keycloak: "
        f"{response.status_code} {response.text}"
    )
    return response.json()["access_token"]


@pytest.fixture(scope="session")
def token_claims(access_token: str) -> dict:
    """Decode the JWT payload (without verifying the signature)."""
    payload = access_token.split(".")[1]
    padding = "=" * (-len(payload) % 4)
    decoded = base64.urlsafe_b64decode(payload + padding)
    return json.loads(decoded)
