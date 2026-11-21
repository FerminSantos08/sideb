import subprocess
import pytest
from fastapi import HTTPException
from app.editorial_covers import store_cover,consumed_cover
from app.schemas import PostCreate

class Connection:
    def __init__(self,fail=False):self.fail=fail;self.committed=False;self.rolled_back=False
    def cursor(self):return self
    def execute(self,sql,params):
        if self.fail:raise RuntimeError('database unavailable')
        self.params=params
    def commit(self):self.committed=True
    def rollback(self):self.rolled_back=True
    def close(self):pass

def test_cover_is_reencoded_and_staged_before_commit(tmp_path,monkeypatch):
    monkeypatch.setenv('UPLOADS_DIR',str(tmp_path))
    png=subprocess.run(['php','-r','$im=imagecreatetruecolor(2400,1200);imagepng($im);'],capture_output=True,check=True).stdout
    connection=Connection()
    result=store_cover(png,{'id_usr':1},connection)
    assert connection.committed and len(result['token'])==32
    image=next((tmp_path/'publicaciones').glob('*.webp'))
    dimensions=subprocess.run(['php','-r','$s=getimagesize($argv[1]);echo $s[0].",".$s[1].",".$s["mime"];',str(image)],capture_output=True,text=True,check=True).stdout
    assert dimensions=='1920,960,image/webp'
    assert connection.params[2]==image.name
    failed=Connection(fail=True)
    with pytest.raises(RuntimeError):store_cover(png,{'id_usr':1},failed)
    assert failed.rolled_back and len(list((tmp_path/'publicaciones').glob('*.webp')))==1

def test_invalid_cover_is_rejected_and_leaves_no_asset(tmp_path,monkeypatch):
    monkeypatch.setenv('UPLOADS_DIR',str(tmp_path))
    connection=Connection()
    with pytest.raises(HTTPException) as error:store_cover(b'<?php echo 1; ?>',{'id_usr':1},connection)
    assert error.value.status_code==422 and connection.rolled_back
    assert list((tmp_path/'publicaciones').glob('*'))==[]

def test_consumed_cover_rejects_changed_payload_or_target():
    from app.editorial_covers import request_hash
    body=PostCreate(title='Prueba',content='Contenido',state='borrador')
    row={'blog_id':7,'request_hash':request_hash(body)}
    assert consumed_cover(row,body,7)
    with pytest.raises(HTTPException):consumed_cover(row,body,8)
    with pytest.raises(HTTPException):consumed_cover(row,body.model_copy(update={'title':'Cambio'}),7)
