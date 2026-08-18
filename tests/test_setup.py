"""End-to-end tests for the N5GEH platform and API protection framework.

These tests verify that:

1. The platform components (Kong admin API, Keycloak) are reachable.
2. Keycloak issues JWTs that encode the tenant (``fiware-service`` claim).
3. Kong rejects unauthenticated requests.
4. Kong enforces multi-tenancy (tenant header vs. token claim).
5. Kong enforces role-based access control (HTTP method vs. role).
"""

import requests


def test_kong_admin_api_reachable(config):
    response = requests.get(f"{config['kong_admin_url']}/status", timeout=30)
    assert response.status_code == 200
    assert response.json().get("database", {}).get("reachable") is True


def test_keycloak_reachable(config):
    url = f"{config['keycloak_url']}/realms/{config['realm']}/.well-known/openid-configuration"
    response = requests.get(url, timeout=30)
    assert response.status_code == 200
    assert "token_endpoint" in response.json()


def test_token_encodes_tenant(config, token_claims):
    claim = token_claims.get("fiware-service")
    values = claim if isinstance(claim, list) else [claim]
    assert config["tenant"] in values


def test_request_without_token_is_rejected(config):
    url = f"{config['kong_proxy_url']}/orion/v2/entities"
    response = requests.get(url, timeout=30)
    assert response.status_code == 401


def test_request_with_valid_token_is_allowed(config, access_token):
    url = f"{config['kong_proxy_url']}/orion/v2/entities"
    response = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "fiware-service": config["tenant"],
        },
        timeout=30,
    )
    assert response.status_code == 200


def test_multi_tenancy_rejects_wrong_tenant(config, access_token):
    url = f"{config['kong_proxy_url']}/orion/v2/entities"
    response = requests.get(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "fiware-service": "another-tenant",
        },
        timeout=30,
    )
    assert response.status_code == 403


def test_rbac_rejects_write_with_read_token(config, access_token):
    url = f"{config['kong_proxy_url']}/orion/v2/entities"
    response = requests.post(
        url,
        headers={
            "Authorization": f"Bearer {access_token}",
            "fiware-service": config["tenant"],
            "Content-Type": "application/json",
        },
        json={
            "id": "urn:ngsi-ld:test:001",
            "type": "Test",
            "temperature": {"type": "Number", "value": 21},
        },
        timeout=30,
    )
    assert response.status_code == 403
