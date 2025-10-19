import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
import pytest
from app import create_app

@pytest.fixture(scope="session")
def app():
    app = create_app()
    app.config.update(
        TESTING=True,
    )
    return app

@pytest.fixture()
def client(app):
    return app.test_client()
