import os
import sys
from pathlib import Path

os.environ.setdefault("JWT_SECRET", "test-secret-with-more-than-thirty-two-characters")
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi.testclient import TestClient
from main import app
from app.core.security import hash_password, verify_password

client = TestClient(app)


def test_health_and_openapi_are_available():
    assert client.get("/health").status_code == 200
    schema = client.get("/openapi.json")
    assert schema.status_code == 200
    assert "/posts" in schema.json()["paths"]


def test_public_catalog_endpoints_use_existing_database():
    assert client.get("/posts").status_code == 200
    assert client.get("/artists").status_code == 200
    assert client.get("/products").status_code == 200
    assert client.get("/categories").status_code == 200


def test_artist_detail_includes_albums_and_related_posts():
    response = client.get("/artists/10")
    assert response.status_code == 200
    artist = response.json()
    assert "albums" in artist
    assert "posts" in artist
    for post in artist["posts"]:
        assert {"id", "titulo", "slug", "imagen"} <= post.keys()


def test_missing_resources_and_invalid_input_are_rejected():
    assert client.get("/posts/999999999").status_code == 404
    assert client.get("/artists/999999999").status_code == 404
    assert client.post("/auth/login", json={"email": "not-an-email", "password": "x"}).status_code == 422
    assert client.get("/auth/me").status_code == 401


def test_php_compatible_bcrypt_password_verification():
    password_hash = hash_password("correct horse battery staple")
    assert verify_password("correct horse battery staple", password_hash)
    assert not verify_password("incorrect", password_hash)


def test_media_route_does_not_expose_non_images_or_parent_files():
    assert client.get('/media/uploads/artistas/example.php').status_code == 404
    assert client.get('/media/uploads/artistas/example.credits.json').status_code == 404
    assert client.get('/media/uploads/%2e%2e/.env').status_code == 404
