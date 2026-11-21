import pytest
from fastapi import HTTPException

from app.editorial import (
    clean_editorial_html,
    format_editorial_content,
    require_publisher,
    slug_base,
    unique_ids,
)


def test_listener_cannot_publish_but_editorial_roles_can():
    with pytest.raises(HTTPException) as error:
        require_publisher({"tip_usu": 1})
    assert error.value.status_code == 403

    for role_id in (2, 3, 4):
        require_publisher({"tip_usu": role_id})


def test_editorial_html_removes_unsafe_markup_and_links():
    content = clean_editorial_html(
        '<h2>Hola</h2><script>alert("x")</script>'
        '<a href="javascript:alert(1)">enlace</a>'
        '<strong>texto</strong>'
    )
    assert "<script" not in content
    assert "javascript:" not in content
    assert "<h2>Hola</h2>" in content
    assert "<strong>texto</strong>" in content


def test_plain_text_post_is_formatted_into_editorial_html():
    content = format_editorial_content(
        "THE CAR: Elegancia en el asiento trasero\n\n"
        "Un primer párrafo con la introducción.\n\n"
        "Una película sin pantalla\n\n"
        "Un segundo párrafo con más contexto.",
        "THE CAR: Elegancia en el asiento trasero",
    )
    assert content == (
        "<p>Un primer párrafo con la introducción.</p>"
        "<h2>Una película sin pantalla</h2>"
        "<p>Un segundo párrafo con más contexto.</p>"
    )


def test_existing_editorial_html_keeps_its_structure():
    content = format_editorial_content("<br><p>Introducción.</p><h2>Sección</h2>", "Título")
    assert content == "<p>Introducción.</p><h2>Sección</h2>"


def test_slug_and_relationship_ids_are_validated():
    assert slug_base("DON'T TAP THE GLASS: Una fiesta") == "don-t-tap-the-glass-una-fiesta"
    assert unique_ids([2, 9], "artist_ids") == [2, 9]
    with pytest.raises(HTTPException):
        unique_ids([2, 2], "artist_ids")
