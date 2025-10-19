from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from app.config import Config

_engine: Engine | None = None

def get_engine() -> Engine:
    global _engine
    if _engine is None:
        _engine = create_engine(
            Config.db_url(),
            pool_pre_ping=True,
            pool_size=5,
            max_overflow=5,
        )
    return _engine


def test_connection() -> bool:
    try:
        engine = get_engine()
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception as e:
        print(f"Error al conectar con la base: {e}")
        return False


def get_user_by_email(email: str) -> dict | None:
    sql = text("""
        SELECT id, first_name, last_name, email, password, active
        FROM users
        WHERE email = :email
        LIMIT 1
    """)
    with get_engine().connect() as conn:
        row = conn.execute(sql, {"email": email}).mappings().first()
        return dict(row) if row else None


def fetch_subscriptions_by_email(email: str) -> list[dict]:
    """
    Lista de suscripciones ACTIVAS del usuario para las cards.
    Trae también product_name y product_type_code.
    """
    sql = text("""
        SELECT
            v.subscription_id,
            v.plan_id,
            v.plan_name,
            v.product_type_code,
            v.monthly_fee,
            v.balance_usd,
            v.status,
            v.last_update,
            v.speed_mbps,
            v.data_quota_mb,
            v.data_used_mb,
            v.minutes_quota,
            v.minutes_used,
            p.name AS product_name
        FROM v_dashboard_summary v
        JOIN plans pl   ON pl.id = v.plan_id
        JOIN products p ON p.id = pl.product_id
        WHERE v.email = :email
          AND v.status = 'ACTIVE'
        ORDER BY v.subscription_id
    """)
    with get_engine().connect() as conn:
        rows = conn.execute(sql, {"email": email}).mappings().all()
        return [dict(r) for r in rows]


def fetch_subscription_details(subscription_id: int) -> dict | None:
    """
    Detalle de una suscripción (se usa para 'Ver detalles').
    """
    sql = text("""
        SELECT
            v.subscription_id,
            v.plan_id,
            v.plan_name,
            v.product_type_code,
            v.monthly_fee,
            v.balance_usd,
            v.status,
            v.last_update,
            v.speed_mbps,
            v.data_quota_mb,
            v.data_used_mb,
            v.minutes_quota,
            v.minutes_used
        FROM v_dashboard_summary v
        WHERE v.subscription_id = :sid
        LIMIT 1
    """)
    with get_engine().connect() as conn:
        row = conn.execute(sql, {"sid": subscription_id}).mappings().first()
        return dict(row) if row else None


def fetch_addons_by_subscription(subscription_id: int) -> list[dict]:
    sql = text("""
        SELECT a.id, a.name, a.monthly_fee
        FROM subscription_addons sa
        JOIN addons a ON a.id = sa.addon_id
        WHERE sa.subscription_id = :sid
        ORDER BY a.name
    """)
    with get_engine().connect() as conn:
        rows = conn.execute(sql, {"sid": subscription_id}).mappings().all()
        return [dict(r) for r in rows]

def fetch_subscription_details(subscription_id: int) -> dict | None:
    sql = text("""
        SELECT
            v.subscription_id,
            v.plan_id,
            v.plan_name,
            v.product_type_code,
            p.name AS product_name,
            v.monthly_fee,
            v.balance_usd,
            v.status,
            v.last_update,
            v.speed_mbps,
            v.data_quota_mb,
            v.data_used_mb,
            v.minutes_quota,
            v.minutes_used
        FROM v_dashboard_summary v
        JOIN plans pl   ON pl.id = v.plan_id
        JOIN products p ON p.id = pl.product_id
        WHERE v.subscription_id = :sid
        LIMIT 1
    """)
    with get_engine().connect() as conn:
        row = conn.execute(sql, {"sid": subscription_id}).mappings().first()
        return dict(row) if row else None

from sqlalchemy import text

def fetch_invoices_by_email(email: str) -> list[dict]:
    sql = text("""
        SELECT i.id, i.subscription_id, i.amount, i.issue_date, i.due_date, i.status, i.notes,
               p.name AS product_name, v.plan_name, v.product_type_code
        FROM invoices i
        JOIN users u ON u.id=i.user_id
        JOIN user_subscriptions us ON us.id=i.subscription_id
        JOIN v_dashboard_summary v ON v.subscription_id=us.id
        JOIN plans pl ON pl.id=v.plan_id
        JOIN products p ON p.id=pl.product_id
        WHERE u.email=:email
        ORDER BY i.issue_date DESC, i.id DESC
    """)
    with get_engine().connect() as conn:
        rows = conn.execute(sql, {"email": email}).mappings().all()
        return [dict(r) for r in rows]
    
def fetch_usage_history(email: str, product_type: str | None = None) -> list[dict]:
    sql = text("""
        SELECT v.subscription_id, v.product_type_code, v.month_start,
               v.data_used_mb, v.minutes_used,
               vd.plan_name, pr.name AS product_name
        FROM v_usage_monthly v
        JOIN v_dashboard_summary vd ON vd.subscription_id=v.subscription_id
        JOIN plans pl ON pl.id=vd.plan_id
        JOIN products pr ON pr.id=pl.product_id
        JOIN users u ON u.id=vd.user_id
        WHERE u.email=:email
          AND (:ptype IS NULL OR v.product_type_code=:ptype)
        ORDER BY v.month_start ASC, v.subscription_id
    """)
    with get_engine().connect() as conn:
        rows = conn.execute(sql, {"email": email, "ptype": product_type}).mappings().all()
        return [dict(r) for r in rows]
