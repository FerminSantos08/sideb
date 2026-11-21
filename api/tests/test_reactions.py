import pytest
from fastapi.testclient import TestClient
from main import app
from app.core.database import get_db
from app.dependencies import current_user
from routers import reactions


class Cursor:
    def __init__(self):
        self.calls = []
    def execute(self, query, params=()):
        self.calls.append((query, params))
    def fetchone(self):
        return {"reaction_id": "sample"}
    def fetchall(self):
        return [{"reaction_id": "sample", "total": 2}]
    def close(self):
        pass


class Connection:
    def __init__(self):
        self.handle = Cursor()
        self.commits = 0
    def cursor(self, **kwargs):
        return self.handle
    def commit(self):
        self.commits += 1
    def rollback(self):
        pass


@pytest.fixture
def isolated(monkeypatch):
    connection = Connection()
    original = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = lambda: connection
    monkeypatch.setattr(reactions, 'REACTIONS_ENABLED', False)
    monkeypatch.setattr(reactions, 'REACTION_TYPES', ())
    try:
        yield TestClient(app), connection
    finally:
        app.dependency_overrides.clear()
        app.dependency_overrides.update(original)


def test_disabled_catalog_does_not_touch_new_table(isolated):
    client, db = isolated
    assert client.get('/reactions/types').json() == {'enabled': False, 'max_types': 5, 'types': []}
    assert client.get('/posts/5/reactions').json() == {'enabled': False, 'total': 0, 'counts': {}}
    app.dependency_overrides[current_user] = lambda: {'id_usr': 7}
    assert client.put('/posts/5/reaction', json={'reaction_id': 'sample'}).status_code == 503
    assert client.delete('/posts/5/reaction').status_code == 503
    assert db.handle.calls == []
    assert db.commits == 0


def test_personal_routes_require_authentication(isolated):
    client, _ = isolated
    assert client.get('/posts/5/reaction').status_code == 401
    assert client.put('/posts/5/reaction', json={'reaction_id': 'sample'}).status_code == 401
    assert client.delete('/posts/5/reaction').status_code == 401


def test_catalog_limits_and_unique_stable_ids():
    with pytest.raises(ValueError):
        reactions.validate_types(tuple(reactions.ReactionType(f'type_{i}', 'Test', '*') for i in range(6)))
    with pytest.raises(ValueError):
        reactions.validate_types((reactions.ReactionType('same', 'A', '*'), reactions.ReactionType('same', 'B', '+')))
    with pytest.raises(ValueError):
        reactions.validate_types((reactions.ReactionType('bad id', 'Test', '*'),))


def test_enabled_contract_and_authenticated_writes(isolated, monkeypatch):
    client, db = isolated
    monkeypatch.setattr(reactions, 'REACTIONS_ENABLED', True)
    monkeypatch.setattr(reactions, 'REACTION_TYPES', (reactions.ReactionType('sample', 'Test only', '*'),))
    app.dependency_overrides[current_user] = lambda: {'id_usr': 7}
    assert client.get('/posts/5/reactions').json() == {'enabled': True, 'counts': {'sample': 2}, 'total': 2}
    assert client.get('/posts/5/reaction').json() == {'reaction_id': 'sample', 'mi_reaccion': 'sample'}
    assert client.put('/posts/5/reaction', json={'reaction_id': 'unknown'}).status_code == 422
    assert client.put('/posts/5/reaction', json={'reaction_id': 'sample'}).json() == {'reaction_id': 'sample'}
    query, params = db.handle.calls[-1]
    assert 'ON DUPLICATE KEY UPDATE' in query
    assert params == (5, 7, 'sample', 'sample')
    assert client.delete('/posts/5/reaction').status_code == 204
    assert db.handle.calls[-1][1] == (5, 7)
    assert db.commits == 2
