import os
from app import create_app
from app.config import Config
from dotenv import load_dotenv

if os.path.exists(".env.local"):
    load_dotenv(".env.local")

app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=Config.PORT, debug=True)
