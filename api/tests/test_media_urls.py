from dataclasses import replace

from app.core.config import settings
from app import utils


def test_selects_matching_media_host_without_using_machine_configuration():
    configured = replace(settings, media_base_url='http://127.0.0.1:8000/media',
                         media_base_urls=('http://10.0.2.2:8000/media', 'http://10.13.0.116:8000/media'))
    assert configured.media_base_url_for_host('10.0.2.2') == 'http://10.0.2.2:8000/media'
    assert configured.media_base_url_for_host('unknown') == 'http://127.0.0.1:8000/media'


def test_media_urls_use_request_host_and_publication_folder(monkeypatch):
    configured = replace(settings, media_base_url='http://127.0.0.1:8000/media',
                         media_base_urls=('http://10.0.2.2:8000/media', 'http://10.13.0.116:8000/media'))
    monkeypatch.setattr(utils, 'settings', configured)
    token = utils.select_media_base_url('10.0.2.2')
    try:
        assert utils.media_url('uploads/artistas/artist.webp') == 'http://10.0.2.2:8000/media/uploads/artistas/artist.webp'
        assert utils.publication_image_url('cover.webp') == 'http://10.0.2.2:8000/media/uploads/publicaciones/cover.webp'
        assert utils.media_url('http://10.13.0.116:8000/media/uploads/artistas/artist.webp') == 'http://10.0.2.2:8000/media/uploads/artistas/artist.webp'
    finally:
        utils.reset_media_base_url(token)
