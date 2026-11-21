import base64
import pytest
from test_library_editorial import isolated_editorial,edit_body

import subprocess
PNG=subprocess.run(['php','-r','$im=imagecreatetruecolor(800,600);imagepng($im);'],capture_output=True,check=True).stdout

@pytest.fixture
def features(isolated_editorial,tmp_path,monkeypatch):
    client,c,q,user,id=isolated_editorial
    for table in ('editorial_cover_upload','wishlist_item','producto'):
        q.execute('SHOW CREATE TABLE '+table);ddl=q.fetchone()['Create Table']
        ddl='\n'.join(line for line in ddl.splitlines() if not line.lstrip().startswith('CONSTRAINT'))
        q.execute(ddl.replace('CREATE TABLE','CREATE TEMPORARY TABLE',1).replace(',\n)','\n)'))
    c.commit();monkeypatch.setenv('UPLOADS_DIR',str(tmp_path))
    return client,c,q,user,id,tmp_path

def upload(client):
    r=client.post('/editorial/covers',content=PNG)
    assert r.status_code==200,r.text
    return r.json()['token']

def test_cover_is_staged_then_saved_atomically_and_retries_are_safe(features):
    client,c,q,user,id,root=features
    before=client.get(f'/editorial/posts/{id}').json()
    token=upload(client)
    assert client.get(f'/editorial/posts/{id}').json()['revision']==before['revision']
    assert len(list((root/'publicaciones').glob('*.webp')))==1
    body=edit_body(before,cover_token=token)
    saved=client.put(f'/editorial/posts/{id}',json=body)
    assert saved.status_code==200,saved.text
    assert '.webp' in saved.json()['post']['imagen']
    assert client.put(f'/editorial/posts/{id}',json=body).json()==saved.json()
    q.execute('SELECT img FROM blog WHERE id_blog=%s',(id,));filename=q.fetchone()['img']
    assert '/' not in filename and (root/'publicaciones'/filename).exists();c.rollback()
    next_edit=edit_body(saved.json(),title='Otra sesión')
    assert client.put(f'/editorial/posts/{id}',json=next_edit).status_code==200
    assert client.put(f'/editorial/posts/{id}',json=body).status_code==409

def test_invalid_foreign_expired_and_stale_cover_do_not_overwrite(features):
    client,c,q,user,id,_=features
    assert client.post('/editorial/covers',content=b'not an image').status_code==422
    assert client.post('/editorial/covers',content=b'x'*(5*1024*1024+1)).status_code==413
    token=upload(client);snapshot=client.get(f'/editorial/posts/{id}').json()
    q.execute('UPDATE editorial_cover_upload SET usr_id=%s WHERE token=%s',(user['id_usr']+99999,token));c.commit()
    assert client.put(f'/editorial/posts/{id}',json=edit_body(snapshot,cover_token=token)).status_code==404
    q.execute('UPDATE editorial_cover_upload SET usr_id=%s,expires_at=NOW()-INTERVAL 1 SECOND WHERE token=%s',(user['id_usr'],token));c.commit()
    assert client.put(f'/editorial/posts/{id}',json=edit_body(snapshot,cover_token=token)).status_code==410
    token=upload(client)
    q.execute("UPDATE blog SET titulo='Web actualizó' WHERE id_blog=%s",(id,));c.commit()
    assert client.put(f'/editorial/posts/{id}',json=edit_body(snapshot,cover_token=token)).status_code==409
    q.execute('SELECT blog_id FROM editorial_cover_upload WHERE token=%s',(token,));assert q.fetchone()['blog_id'] is None;c.rollback()
    user['tip_usu']=1
    assert client.post('/editorial/covers',content=PNG).status_code==403

def test_create_with_cover_retry_does_not_duplicate(features):
    client,c,q,_,_,_=features
    body={'title':'Nueva portada','content':'Contenido suficiente para publicar.','state':'borrador','cover_token':upload(client)}
    first=client.post('/posts',json=body);assert first.status_code==201,first.text
    retry=client.post('/posts',json=body);assert retry.status_code==201,retry.text
    assert retry.json()['post']['id']==first.json()['post']['id']
    q.execute('SELECT COUNT(*) n FROM blog');assert q.fetchone()['n']==2

def test_wishlist_is_private_idempotent_and_hides_inactive_products(features):
    client,c,q,user,_,_=features
    q.execute('SELECT id_categoria FROM categoria_producto LIMIT 1');category=q.fetchone()['id_categoria']
    q.execute("INSERT INTO producto(nombre,precio,stock,categoria_id,activo) VALUES ('Prueba wishlist',100,0,%s,TRUE)",(category,));id=q.lastrowid;c.commit()
    for _ in range(2):assert client.post('/wishlist/items',json={'product_id':id}).status_code==201
    saved=client.get('/wishlist').json();assert saved['saved_ids']==[id] and saved['items'][0]['stock']==0
    assert client.post('/cart/items',json={'product_id':id,'quantity':1}).status_code==409
    user['id_usr']+=99999
    assert client.get('/wishlist').json()=={'items':[],'saved_ids':[]}
    assert client.delete(f'/wishlist/items/{id}').status_code==204
    user['id_usr']-=99999
    q.execute('UPDATE producto SET activo=FALSE WHERE id_producto=%s',(id,));c.commit()
    assert client.get('/wishlist').json()=={'items':[],'saved_ids':[id]}
    assert client.delete(f'/wishlist/items/{id}').status_code==204
    assert client.get('/wishlist').json()['saved_ids']==[]
