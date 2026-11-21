"""Run with RUN_MYSQL_REACTION_TESTS=1. Writes stay in a connection-local temp table."""
import os
import pytest
from fastapi.testclient import TestClient
from main import app
from app.core.database import get_db, get_db_connection
from app.dependencies import current_user
from routers import reactions


@pytest.mark.skipif(os.getenv('RUN_MYSQL_REACTION_TESTS') != '1', reason='Explicit opt-in for MySQL temporary-table integration')
def test_mysql_persistence_replacement_removal_and_multiple_users(monkeypatch):
    connection = get_db_connection()
    cursor = connection.cursor(dictionary=True)
    original = app.dependency_overrides.copy()
    try:
        cursor.execute("SELECT b.id_blog FROM blog b JOIN blog_detalle d ON d.blog_id=b.id_blog WHERE d.estado='publicado' AND d.fecha_publicacion<=NOW() LIMIT 1")
        post = cursor.fetchone()
        assert post, 'A published article is required'
        post_id = post['id_blog']
        cursor.execute('SHOW CREATE TABLE post_reactions')
        ddl = cursor.fetchone()['Create Table']
        ddl = '\n'.join(line for line in ddl.splitlines() if not line.lstrip().startswith('CONSTRAINT'))
        ddl = ddl.replace('CREATE TABLE', 'CREATE TEMPORARY TABLE', 1).replace(',\n)', '\n)')
        cursor.execute(ddl)
        app.dependency_overrides[get_db] = lambda: connection
        user = {'id_usr': 990001}
        app.dependency_overrides[current_user] = lambda: user
        monkeypatch.setattr(reactions, 'REACTIONS_ENABLED', True)
        client = TestClient(app)
        route = f'/posts/{post_id}/reaction'
        totals = f'/posts/{post_id}/reactions'
        assert client.put(route, json={'reaction_id': 'me_encanta'}).status_code == 200
        assert client.put(route, json={'reaction_id': 'me_encanta'}).status_code == 200
        assert client.get(totals).json()['total'] == 1
        assert client.get(route).json()['mi_reaccion'] == 'me_encanta'
        user['id_usr'] = 990002
        assert client.put(route, json={'reaction_id': 'temazo'}).status_code == 200
        user['id_usr'] = 990001
        assert client.put(route, json={'reaction_id': 'lo_escucharia'}).status_code == 200
        counts = client.get(totals).json()
        assert counts['total'] == 2
        assert counts['counts'] == {'me_encanta': 0, 'temazo': 1, 'lo_escucharia': 1, 'sorprendente': 0}
        assert client.get(route).json()['reaction_id'] == 'lo_escucharia'
        assert client.put(route, json={'reaction_id': 'not_real'}).status_code == 422
        assert client.put('/posts/999999999/reaction', json={'reaction_id': 'temazo'}).status_code == 404
        assert client.delete(route).status_code == 204
        assert client.delete(route).status_code == 204
        assert client.get(route).json()['mi_reaccion'] is None
        assert client.get(totals).json()['total'] == 1
        user['id_usr'] = 990002
        assert client.get(route).json()['mi_reaccion'] == 'temazo'
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(original)
        cursor.close()
        connection.close()
