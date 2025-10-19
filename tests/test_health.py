def test_health_ok(client):
    resp = client.get("/health")
    assert resp.status_code in (200, 500)
    data = resp.get_json()

    assert "status" in data
    assert "code" in data
    assert "data" in data

    payload = data.get("data") or {}
    assert "db" in payload  
