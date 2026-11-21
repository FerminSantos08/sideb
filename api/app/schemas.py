from typing import Literal

from pydantic import BaseModel, EmailStr, Field

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)
class RegisterRequest(BaseModel):
    username: str = Field(min_length=3, max_length=100)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
class CommentCreate(BaseModel):
    comentario: str = Field(min_length=1, max_length=500)
class CartItemCreate(BaseModel):
    product_id: int = Field(gt=0)
    quantity: int = Field(default=1, ge=1, le=99)
class CartItemUpdate(BaseModel):
    quantity: int = Field(ge=1, le=99)
class WishlistItemCreate(BaseModel):
    product_id: int = Field(gt=0)


class PostCreate(BaseModel):
    cover_token: str | None = Field(default=None, pattern=r'^[a-f0-9]{32}$')
    title: str = Field(min_length=3, max_length=200)
    description: str | None = Field(default=None, max_length=500)
    content: str = Field(
        min_length=1,
        max_length=100000,
        description=(
            "HTML editorial seguro o texto plano. El texto plano se guarda "
            "como párrafos; las líneas breves separadas por una línea vacía "
            "se convierten en subtítulos."
        ),
    )
    tags: str | None = Field(default=None, max_length=255)
    state: Literal["borrador", "revision", "publicado", "archivado"] = "borrador"
    artist_ids: list[int] = Field(default_factory=list, max_length=100)
    album_ids: list[int] = Field(default_factory=list, max_length=100)
