import html
import re
import unicodedata
from html.parser import HTMLParser
from urllib.parse import urlparse

from fastapi import HTTPException, status


PUBLISHER_ROLE_IDS = frozenset((2, 3, 4))
POST_STATES = frozenset(("borrador", "revision", "publicado", "archivado"))
_ALLOWED_TAGS = frozenset(
    ("p", "br", "strong", "b", "em", "i", "h2", "h3", "blockquote", "ul", "ol", "li", "a"),
)


def require_publisher(user: dict) -> None:
    if user["tip_usu"] not in PUBLISHER_ROLE_IDS:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu cuenta no tiene permiso para crear publicaciones",
        )


def slug_base(title: str) -> str:
    normalized = unicodedata.normalize("NFKD", title)
    ascii_title = normalized.encode("ascii", "ignore").decode("ascii")
    value = re.sub(r"[^a-zA-Z0-9]+", "-", ascii_title.lower()).strip("-")
    return value[:210] or "publicacion"


def unique_slug(cursor, title: str) -> str:
    base = slug_base(title)
    candidate = base
    number = 2
    while True:
        cursor.execute("SELECT 1 FROM blog WHERE slug=%s LIMIT 1", (candidate,))
        if cursor.fetchone() is None:
            return candidate
        suffix = f"-{number}"
        candidate = f"{base[:220 - len(suffix)]}{suffix}"
        number += 1


class _EditorialHtmlSanitizer(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        if tag not in _ALLOWED_TAGS:
            return
        if tag == "br":
            self.parts.append("<br>")
            return
        if tag == "a":
            href = next((value for name, value in attrs if name.lower() == "href"), None)
            if href and _safe_link(href):
                self.parts.append(f'<a href="{html.escape(href, quote=True)}">')
                return
            self.parts.append("<a>")
            return
        self.parts.append(f"<{tag}>")

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() in _ALLOWED_TAGS and tag.lower() != "br":
            self.parts.append(f"</{tag.lower()}>")

    def handle_data(self, data: str) -> None:
        self.parts.append(html.escape(data))


def _safe_link(value: str) -> bool:
    parsed = urlparse(value.strip())
    return parsed.scheme.lower() in {"http", "https", "mailto"}


def clean_editorial_html(value: str) -> str:
    parser = _EditorialHtmlSanitizer()
    parser.feed(value.strip())
    parser.close()
    return "".join(parser.parts).strip()


def format_editorial_content(value: str, title: str) -> str:
    """Return safe, consistently structured editorial HTML.

    Rich HTML from the web editor keeps its structure. Plain text, such as
    content sent by the mobile client, is converted into paragraphs. Short
    standalone lines without ending punctuation become section headings.
    """
    content = clean_editorial_html(value)
    content = re.sub(r"^(?:\s|<br>)+", "", content)
    if not content:
        return ""

    block_tags = r"<(?:p|h2|h3|blockquote|ul|ol|li)(?:\s|>)"
    if re.search(block_tags, content, flags=re.IGNORECASE):
        return content

    blocks = [
        block.strip()
        for block in re.split(r"(?:\s*\n\s*){2,}|(?:\s*<br>\s*){2,}", content)
        if visible_text(block)
    ]
    if blocks and _same_visible_text(blocks[0], title):
        blocks.pop(0)

    formatted: list[str] = []
    for block in blocks:
        if _is_section_heading(visible_text(block)):
            formatted.append(f"<h2>{block}</h2>")
        else:
            formatted.append(f"<p>{block}</p>")
    return "".join(formatted)


def _same_visible_text(value: str, expected: str) -> bool:
    return " ".join(visible_text(value).casefold().split()) == " ".join(
        expected.casefold().split()
    )


def _is_section_heading(value: str) -> bool:
    return 3 <= len(value) <= 90 and not value.rstrip().endswith((".", "!", "?", "…", ":", ";"))


def visible_text(value: str) -> str:
    return html.unescape(re.sub(r"<[^>]*>", "", value)).strip()


def unique_ids(values: list[int], field_name: str) -> list[int]:
    if any(value <= 0 for value in values) or len(values) != len(set(values)):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail=f"{field_name} contiene identificadores invalidos o repetidos",
        )
    return values
