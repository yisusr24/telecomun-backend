def test_subscriptions_missing_email(client):
    resp = client.post("/api/v1/subscriptions/list", json={})
    assert resp.status_code == 400
    data = resp.get_json()
    assert data["status"] == "error"
    assert "email" in data["message"].lower()

def test_subscriptions_not_found(client, monkeypatch):
    import app.db as db

    def fake_fetch_subs(email: str):
        return []  

    monkeypatch.setattr(db, "fetch_subscriptions_by_email", fake_fetch_subs)

    resp = client.post("/api/v1/subscriptions/list", json={"email": "nadie@example.com"})
    assert resp.status_code == 404
    data = resp.get_json()
    assert data["status"] == "error"

def test_subscriptions_ok(client, monkeypatch):
    import routes.subscriptions as subs

    row = {
        "subscription_id": "SUB-001",
        "product_type_code": "INTERNET",
        "product_name": "XTRIM INTERNET",
        "plan_id": "PLAN-100",
        "plan_name": "Plan Internet 100",
        "monthly_fee": 20.00,
        "balance_usd": 5.50,
        "status": "A",
        "last_update": None,
        "speed_mbps": 100,
        "minutes_quota": None,
        "minutes_used": None
    }

    def fake_fetch_subs(email: str):
        assert email == "juan.perez@example.com"
        return [row]

    monkeypatch.setattr(subs, "fetch_subscriptions_by_email", fake_fetch_subs)

    resp = client.post("/api/v1/subscriptions/list", json={"email": "juan.perez@example.com"})
    assert resp.status_code == 200
    data = resp.get_json()

    assert data["status"] == "success"
    assert isinstance(data["data"], list)
    assert len(data["data"]) == 1

    sub = data["data"][0]
    assert "subscriptionId" in sub
    assert "productType" in sub
    assert "planName" in sub
    assert "monthlyFee" in sub
    assert "saldo" in sub
