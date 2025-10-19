from flask import Flask, jsonify
from flask_cors import CORS
from app.db import test_connection
from app.logging_setup import setup_logging
import logging

def create_app():
    setup_logging()
    log = logging.getLogger("app")

    app = Flask(__name__)

    CORS(app, resources={r"/api/*": {"origins": "*"}}, supports_credentials=False)

    # Health
    @app.get("/health")
    def health():
        db_ok = test_connection()
        return jsonify({
            "status": "success" if db_ok else "error",
            "code": 200 if db_ok else 500,
            "data": {"db": "connected" if db_ok else "unreachable"},
            "message": "OK" if db_ok else "DB error"
        }), 200 if db_ok else 500

    from routes.auth import bp as auth_bp
    from routes.invoices import bp as invoices_bp
    from routes.usage import bp as usage_bp
    from routes.subscriptions import bp as subscriptions_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(invoices_bp)
    app.register_blueprint(usage_bp)
    app.register_blueprint(subscriptions_bp)

    
    @app.errorhandler(404)
    def not_found(_):
        return jsonify(status="error", code=404, data=None, message="Ruta no encontrada"), 404

    @app.errorhandler(Exception)
    def server_error(err):
        log.exception({"event": "unhandled_exception", "error": str(err)})
        return jsonify(status="error", code=500, data=None, message="Error interno del servidor"), 500

    log.info("Aplicación Flask iniciada y lista.")
    return app
