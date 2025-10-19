import os


class Config:
    PORT = int(os.getenv("PORT", "5000"))

    DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
    DB_PORT = os.getenv("DB_PORT", "3307")
    DB_NAME = os.getenv("DB_NAME", "telecomun_db")
    DB_USER = os.getenv("DB_USER", "admin")
    DB_PASS = os.getenv("DB_PASS", "admin")

    @staticmethod
    def db_url() -> str:
        return (
            f"mysql+pymysql://{Config.DB_USER}:{Config.DB_PASS}"
            f"@{Config.DB_HOST}:{Config.DB_PORT}/{Config.DB_NAME}"
        )
