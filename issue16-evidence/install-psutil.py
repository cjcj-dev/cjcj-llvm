import urllib.request,json,pathlib,hashlib,zipfile
root=pathlib.Path('/root/sym_cjcj_llvm_16_implement_r5788821149')
data=json.load(urllib.request.urlopen('https://pypi.org/pypi/psutil/5.9.8/json'))
wheel=next(x for x in data['urls'] if 'cp36-abi3-manylinux_2_12_x86_64' in x['filename'])
path=root/wheel['filename']
content=urllib.request.urlopen(wheel['url']).read()
assert hashlib.sha256(content).hexdigest()==wheel['digests']['sha256']
path.write_bytes(content)
with zipfile.ZipFile(path) as z:z.extractall(root/'python-deps')
(root/'psutil-wheel.json').write_text(json.dumps(wheel,indent=2)+'\n')
print(path.name,wheel['digests']['sha256'])
