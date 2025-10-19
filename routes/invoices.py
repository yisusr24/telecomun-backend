from flask import Blueprint, request, jsonify, g
import logging
from app.db import fetch_invoices_by_email

bp = Blueprint("invoices", __name__, url_prefix="/api/v1")
log = logging.getLogger("app.api")

def _resp(s, c, d, m): return jsonify({"status":s,"code":c,"data":d,"message":m}), c

@bp.post("/invoices/list")
def invoices_list():
    body = request.get_json(silent=True) or {}
    email = (body.get("email") or "").strip()
    if not email: return _resp("error", 400, None, "Debe enviar 'email'")
    try:
        rows = fetch_invoices_by_email(email)
        data = [{
            "invoiceId": r["id"],
            "subscriptionId": r["subscription_id"],
            "productType": r["product_type_code"],
            "productName": r["product_name"],
            "planName": r["plan_name"],
            "amount": float(r["amount"]),
            "issueDate": r["issue_date"].isoformat(),
            "dueDate": r["due_date"].isoformat(),
            "status": r["status"],
            "notes": r["notes"]
        } for r in rows]
        return _resp("success", 200, data, "Facturas del usuario")
    except Exception as e:
        log.exception({"event":"invoices_list_error","error":str(e)}); return _resp("error",500,None,"Error interno")
