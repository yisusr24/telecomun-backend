from flask import Blueprint, request, jsonify, g
from app.db import (
    fetch_subscriptions_by_email,
    fetch_subscription_details,
    fetch_addons_by_subscription,
)
import logging
import time
import uuid

bp = Blueprint("subscriptions", __name__, url_prefix="/api/v1")
log = logging.getLogger("app.api")

@bp.before_app_request
def _before_request_log():
    g.req_id = str(uuid.uuid4())
    g.t0 = time.time()
    try:
        json_payload = request.get_json(silent=True)
    except Exception:
        json_payload = None
    payload_preview = json_payload if isinstance(json_payload, (dict, list)) else None
    log.info({
        "event": "request_start",
        "req_id": g.req_id,
        "method": request.method,
        "path": request.path,
        "query": request.query_string.decode("utf-8", "ignore"),
        "remote_addr": request.remote_addr,
        "user_agent": request.headers.get("User-Agent"),
        "payload": payload_preview
    })

@bp.after_app_request
def _after_request_log(response):
    dt_ms = int((time.time() - getattr(g, "t0", time.time())) * 1000)
    try:
        resp_json = response.get_json(silent=True)
    except Exception:
        resp_json = None
    log.info({
        "event": "request_end",
        "req_id": getattr(g, "req_id", None),
        "method": request.method,
        "path": request.path,
        "status_code": response.status_code,
        "duration_ms": dt_ms,
        "response_preview": (
            resp_json if isinstance(resp_json, (dict, list)) else None
        )
    })
    return response

def _response(status, code, data, message):
    return jsonify({
        "status": status,
        "code": code,
        "data": data,
        "message": message
    }), code

@bp.post("/subscriptions/list")
def subscriptions_list():
    try:
        body = request.get_json(silent=True) or {}
        email = (body.get("email") or "").strip()
        if not email:
            return _response("error", 400, None, "Debe enviar 'email' en el cuerpo")

        rows = fetch_subscriptions_by_email(email)
        if not rows:
            return _response("error", 404, None, "No se encontraron suscripciones activas para este usuario")

        subs = []
        for r in rows:
            item = {
                "subscriptionId": r["subscription_id"],
                "productType": r["product_type_code"],    
                "productName": r["product_name"],
                "planName": r["plan_name"],
                "monthlyFee": float(r["monthly_fee"]) if r["monthly_fee"] is not None else None,
                "saldo": float(r["balance_usd"]) if r["balance_usd"] is not None else 0.0,
                "estado": r["status"],
                "ultimaActualizacion": r["last_update"].isoformat() if r["last_update"] else None
            }

            if r["product_type_code"] == "INTERNET":
                item["speedMbps"] = r["speed_mbps"]

            if r["product_type_code"] == "PHONE":
                cuota = r["minutes_quota"]
                usados = r["minutes_used"]
                pct = round((usados / cuota) * 100, 2) if usados is not None and cuota not in (None, 0) else None
                item["consumo"] = {
                    "minutos": {"usados": usados, "cuota": cuota, "porcentaje": pct}
                }

            if r["product_type_code"] == "TV":
                addons_rows = fetch_addons_by_subscription(r["subscription_id"]) or []
                item["addons"] = [a["name"] for a in addons_rows] if addons_rows else []

            subs.append(item)

        return _response("success", 200, subs, "Suscripciones activas del usuario")
    except Exception as e:
        log.exception({"event": "request_error", "req_id": getattr(g, "req_id", None), "error": str(e)})
        return _response("error", 500, None, "Error interno")


@bp.post("/subscriptions/detail")
def subscription_detail():
    try:
        body = request.get_json(silent=True) or {}
        sid = body.get("subscriptionId")
        if not isinstance(sid, int):
            return _response("error", 400, None, "Debe enviar 'subscriptionId' (number) en el cuerpo")

        r = fetch_subscription_details(sid)
        if not r:
            return _response("error", 404, None, "Suscripción no encontrada")

        base = {
            "subscriptionId": r["subscription_id"],
            "productType": r["product_type_code"],
            "productName": r["product_name"],
            "planName": r["plan_name"],
            "monthlyFee": float(r["monthly_fee"]) if r["monthly_fee"] is not None else None,
            "saldo": float(r["balance_usd"]) if r["balance_usd"] is not None else 0.0,
            "estado": r["status"],
            "ultimaActualizacion": r["last_update"].isoformat() if r["last_update"] else None
        }

        t = r["product_type_code"]
        if t == "INTERNET":
            data_percent = (
                round((r["data_used_mb"] / r["data_quota_mb"]) * 100, 2)
                if r["data_quota_mb"] not in (None, 0) and r["data_used_mb"] is not None
                else None
            )
            base["internet"] = {
                "speedMbps": r["speed_mbps"],
                "dataQuotaMb": r["data_quota_mb"],
                "dataUsedMb": r["data_used_mb"],
                "dataPercent": data_percent
            }
        elif t == "PHONE":
            min_percent = (
                round((r["minutes_used"] / r["minutes_quota"]) * 100, 2)
                if r["minutes_quota"] not in (None, 0) and r["minutes_used"] is not None
                else None
            )
            base["phone"] = {
                "minutesQuota": r["minutes_quota"],
                "minutesUsed": r["minutes_used"],
                "minutesPercent": min_percent
            }
        elif t == "TV":
            addons = fetch_addons_by_subscription(sid) or []
            base["tv"] = {
                "addons": [{"name": a["name"], "monthlyFee": float(a["monthly_fee"])} for a in addons]
            }

        return _response("success", 200, base, "Detalle de suscripción")
    except Exception as e:
        log.exception({"event": "request_error", "req_id": getattr(g, "req_id", None), "error": str(e)})
        return _response("error", 500, None, "Error interno")
