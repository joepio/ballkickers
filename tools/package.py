"""Package only redistributable game files; never local registration/backups."""
from pathlib import Path
import hashlib
import zipfile
root=Path(__file__).resolve().parents[1]
build=root/'build'
output=build/'ballkickers-windows.zip'
files={'Ballkickers.exe':build/'Ballkickers.exe', 'Ballkickers.pck':build/'Ballkickers.pck',
       'README.md':root/'README.md', 'LICENSE':root/'LICENSE'}
for path in sorted((root/'third_party').glob('*.txt')): files['licenses/'+path.name]=path
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for name,path in files.items():
        info=zipfile.ZipInfo(name,date_time=(2026,9,28,0,0,0))
        info.compress_type=zipfile.ZIP_DEFLATED
        info.external_attr=0o100644<<16
        archive.writestr(info,path.read_bytes())
digest=hashlib.sha256(output.read_bytes()).hexdigest()
(build/'SHA256SUMS.txt').write_text(f'{digest}  {output.name}\n',encoding='utf-8')
print(f'{output.name}: {output.stat().st_size} bytes; SHA256 {digest}')
