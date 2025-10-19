from flask import Blueprint, request, jsonify
from app.db import get_user_by_email

bp = Blueprint("auth", __name__, url_prefix="/api/v1")

@bp.post("/login")
def login():
    try:
        body = request.get_json(silent=True) or {}
        email = (body.get("email") or "").strip()
        password = body.get("password")

        if not email or password is None:
            return _response("error", 400, None, "Email y password son requeridos")

        user = get_user_by_email(email)
        if not user:
            return _response("error", 401, None, "Credenciales inválidas")
        if not user["active"]:
            return _response("error", 403, None, "Usuario inactivo")

        if password != user["password"]:
            return _response("error", 401, None, "Credenciales inválidas")

        data = {
            "id": user["id"],
            "firstName": user["first_name"],
            "lastName": user["last_name"],
            "email": user["email"],
            "active": bool(user["active"]),
        }

        return _response("success", 200, data, "Login correcto")
    except Exception as e:
        return _response("error", 500, None, f"Error interno: {e}")


def _response(status, code, data, message):
    return jsonify({
        "status": status,
        "code": code,
        "data": data,
        "message": message
    }), code
