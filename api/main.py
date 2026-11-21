from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException as StarletteHTTPException
from pathlib import Path
import os
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.utils import reset_media_base_url, select_media_base_url
from routers.posts import router as posts_router
from routers.reactions import router as reactions_router
from routers.catalog import router as catalog_router
from routers.auth import router as auth_router
from routers.commerce import router as commerce_router
from routers.checkout import router as checkout_router
from routers.payments import router as payments_router
from routers.profile import router as profile_router
from routers.library import router as library_router
from routers.editorial_management import router as editorial_management_router

app = FastAPI(
    title="SIDE B API",
    description="API REST para SIDE B Mobile",
    version="1.0.0"
)

class ImageFiles(StaticFiles):
    async def get_response(self, path, scope):
        if Path(path).suffix.lower() not in {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.avif'}:
            raise StarletteHTTPException(status_code=404)
        return await super().get_response(path, scope)


uploads_dir = Path(os.getenv('UPLOADS_DIR', '/var/www/html/side-b/uploads'))
if uploads_dir.is_dir():
    app.mount('/media/uploads', ImageFiles(directory=uploads_dir), name='uploads')


app.include_router(posts_router)
app.include_router(reactions_router)
app.include_router(catalog_router)
app.include_router(auth_router)
app.include_router(commerce_router)
app.include_router(checkout_router)
app.include_router(payments_router)
app.include_router(profile_router)
app.include_router(library_router)
app.include_router(editorial_management_router)


@app.middleware("http")
async def select_request_media_host(request: Request, call_next):
    """Serve media URLs through the same configured LAN IP as the API request."""
    token = select_media_base_url(request.url.hostname)
    try:
        return await call_next(request)
    finally:
        reset_media_base_url(token)

if settings.cors_origins:
    app.add_middleware(CORSMiddleware, allow_origins=list(settings.cors_origins), allow_credentials=False, allow_methods=["GET", "POST"], allow_headers=["Authorization", "Content-Type"])

@app.get("/")
def inicio():
    return {
        "proyecto": "SIDE B",
        "estado": "Funcionando"
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "SIDE B API"
    }
