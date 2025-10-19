from flask import Blueprint, request, jsonify
import logging
from app.db import fetch_usage_history

bp = Blueprint("usage", __name__, url_prefix="/api/v1")
log = logging.getLogger("app.api")

def _resp(s,c,d,m): return jsonify({"status":s,"code":c,"data":d,"message":m}), c

@bp.post("/usage/history")
def usage_history():
    body = request.get_json(silent=True) or {}
    email = (body.get("email") or "").strip()
    ptype = body.get("productType")  
    if not email:
        return _resp("error",400,None,"Debe enviar 'email'")
    try:
        rows = fetch_usage_history(email, ptype if ptype in ("INTERNET","PHONE") else None)

        agg = {}
        for r in rows:
            month = r["month_start"]
            entry = agg.setdefault(month, {"month": month, "internetMb": 0, "phoneMinutes": 0})
            if r["product_type_code"] == "INTERNET":
                entry["internetMb"] += int(r["data_used_mb"] or 0)
            elif r["product_type_code"] == "PHONE":
                entry["phoneMinutes"] += int(r["minutes_used"] or 0)

        data = [agg[k] for k in sorted(agg.keys())]
        return _resp("success",200,data,"Histórico mensual de consumo")
    except Exception as e:
        log.exception({"event":"usage_history_error","error":str(e)})
        return _resp("error",500,None,"Error interno")
