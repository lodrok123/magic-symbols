"""Baja las imagenes embebidas de un GLB a `lado` px SIN tocar nada mas (indices de bufferViews/accessors intactos:
vale para personajes con esqueleto y animaciones). Reescribe el buffer en el mismo orden de bufferViews."""
import sys, io, json, struct
from PIL import Image
def reducir(src, dst, lado):
    b = open(src, 'rb').read()
    jl = struct.unpack('<I', b[12:16])[0]; j = json.loads(b[20:20 + jl]); off = 20 + jl + 8
    buf = b[off:off + j['buffers'][0]['byteLength']]
    img_bv = {im['bufferView']: im for im in j.get('images', [])}
    nb = bytearray()
    for i, bv in enumerate(j['bufferViews']):
        o = bv.get('byteOffset', 0); data = bytes(buf[o:o + bv['byteLength']])
        if i in img_bv:
            im = Image.open(io.BytesIO(data))
            if max(im.size) > lado:
                im = im.resize((lado, lado), Image.LANCZOS)
                out = io.BytesIO()
                if img_bv[i].get('mimeType') == 'image/png': im.save(out, 'PNG', optimize=True)
                else: im.convert('RGB').save(out, 'JPEG', quality=90)
                data = out.getvalue()
        while len(nb) % 4: nb.append(0)
        bv['byteOffset'] = len(nb); bv['byteLength'] = len(data); nb += data
    while len(nb) % 4: nb.append(0)
    j['buffers'][0]['byteLength'] = len(nb)
    js = json.dumps(j, separators=(',', ':')).encode()
    while len(js) % 4: js += b' '
    total = 12 + 8 + len(js) + 8 + len(nb)
    with open(dst, 'wb') as f:
        f.write(struct.pack('<4sII', b'glTF', 2, total)); f.write(struct.pack('<I4s', len(js), b'JSON')); f.write(js)
        f.write(struct.pack('<I4s', len(nb), b'BIN\0')); f.write(nb)
    print(src, len(b) // 1024, 'KB ->', total // 1024, 'KB')
if __name__ == '__main__':
    reducir(sys.argv[1], sys.argv[2], int(sys.argv[3]))
