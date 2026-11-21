"""Publication reactions, independent from comment reactions."""
import os
import re
from dataclasses import asdict, dataclass

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.core.database import get_db
from app.dependencies import current_user

router = APIRouter(tags=["Reacciones"])
MAX_REACTION_TYPES = 5


@dataclass(frozen=True)
class ReactionType:
    id: str
    label: str
    symbol: str
    color: str = "#858C77"


REACTION_TYPES: tuple[ReactionType, ...] = (
    ReactionType("me_encanta", "Me encanta", "heart", "#C16A60"),
    ReactionType("temazo", "Temazo", "music-2", "#858C77"),
    ReactionType("lo_escucharia", "Lo escuché", "headphones", "#B89B72"),
    ReactionType("sorprendente", "Sorprendente", "sparkles", "#A18BB6"),
)
REACTIONS_ENABLED = os.getenv("REACTIONS_ENABLED", "false").lower() == "true"


def validate_types(types):
    if len(types) > MAX_REACTION_TYPES:
        raise ValueError("Se permiten hasta 5 tipos de reacción")
    ids = [item.id for item in types]
    if len(set(ids)) != len(ids):
        raise ValueError("Los identificadores de reacción deben ser únicos")
    for item in types:
        if not re.fullmatch(r"[a-z][a-z0-9_]{0,31}", item.id) or not item.label.strip() or not item.symbol.strip():
            raise ValueError("Cada reacción requiere id estable, nombre y símbolo")


validate_types(REACTION_TYPES)


def enabled():
    return REACTIONS_ENABLED and bool(REACTION_TYPES)


def require_enabled():
    if not enabled():
        raise HTTPException(status_code=503, detail="Las reacciones aún no están disponibles")


def require_post(cursor, post_id):
    cursor.execute("SELECT 1 FROM blog b JOIN blog_detalle d ON d.blog_id=b.id_blog WHERE b.id_blog=%s AND d.estado='publicado' AND d.fecha_publicacion<=NOW()", (post_id,))
    if not cursor.fetchone():
        raise HTTPException(status_code=404, detail="Publicación no encontrada")


class ReactionSelection(BaseModel):
    reaction_id: str = Field(min_length=1, max_length=32)


@router.get("/reactions/types")
def list_types():
    return {"enabled": enabled(), "max_types": MAX_REACTION_TYPES,
            "types": [asdict(item) for item in REACTION_TYPES] if enabled() else []}


@router.get("/posts/{post_id}/reactions")
def summary(post_id: int, connection=Depends(get_db)):
    if not enabled():
        return {"enabled": False, "total": 0, "counts": {}}
    cursor = connection.cursor(dictionary=True)
    try:
        require_post(cursor, post_id)
        cursor.execute("SELECT reaction_id,COUNT(*) AS total FROM post_reactions WHERE blog_id=%s GROUP BY reaction_id", (post_id,))
        stored = {row["reaction_id"]: row["total"] for row in cursor.fetchall()}
        counts = {item.id: stored.get(item.id, 0) for item in REACTION_TYPES}
        return {"enabled": True, "total": sum(counts.values()), "counts": counts}
    finally:
        cursor.close()


@router.get("/posts/{post_id}/reaction")
def my_reaction(post_id: int, user=Depends(current_user), connection=Depends(get_db)):
    require_enabled()
    cursor = connection.cursor(dictionary=True)
    try:
        require_post(cursor, post_id)
        cursor.execute("SELECT reaction_id FROM post_reactions WHERE blog_id=%s AND usr_id=%s", (post_id, user["id_usr"]))
        row = cursor.fetchone()
        selected = row["reaction_id"] if row else None
        return {"reaction_id": selected, "mi_reaccion": selected}
    finally:
        cursor.close()


@router.put("/posts/{post_id}/reaction")
def set_reaction(post_id: int, body: ReactionSelection, user=Depends(current_user), connection=Depends(get_db)):
    require_enabled()
    if body.reaction_id not in {item.id for item in REACTION_TYPES}:
        raise HTTPException(status_code=422, detail="Tipo de reacción no disponible")
    cursor = connection.cursor(dictionary=True)
    try:
        require_post(cursor, post_id)
        cursor.execute("""INSERT INTO post_reactions (blog_id,usr_id,reaction_id) VALUES (%s,%s,%s)
            ON DUPLICATE KEY UPDATE reaction_id=%s,updated_at=CURRENT_TIMESTAMP""",
            (post_id, user["id_usr"], body.reaction_id, body.reaction_id))
        connection.commit()
        return {"reaction_id": body.reaction_id}
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()


@router.delete("/posts/{post_id}/reaction", status_code=204)
def remove_reaction(post_id: int, user=Depends(current_user), connection=Depends(get_db)):
    require_enabled()
    cursor = connection.cursor(dictionary=True)
    try:
        require_post(cursor, post_id)
        cursor.execute("DELETE FROM post_reactions WHERE blog_id=%s AND usr_id=%s", (post_id, user["id_usr"]))
        connection.commit()
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
