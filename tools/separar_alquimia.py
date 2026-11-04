"""Separa el GLB de Meshy de alquimia en objetos (componentes conectados soldando por posicion, agrupados por cercania de AABB).
Uso: python tools/separar_alquimia.py origen.glb carpeta_salida [margen [recortar [n:nombre,...]]]
Escribe obj_NN.glb (centrados en el centro de la base, de pie, con UV y textura compartida) e indice.json."""
import struct, json, sys, os
import numpy as np
import io
from PIL import Image

def cargar(ruta):
    d = open(ruta, 'rb').read()
    lj = struct.unpack('<I', d[12:16])[0]
    j = json.loads(d[20:20 + lj])
    off = 20 + lj + 8
    b = d[off:]
    def acc(i):
        a = j['accessors'][i]; v = j['bufferViews'][a['bufferView']]
        n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3}[a['type']]
        dt = {5125: '<u4', 5126: '<f4'}[a['componentType']]
        o = v.get('byteOffset', 0) + a.get('byteOffset', 0)
        return np.frombuffer(b, dtype=dt, count=a['count'] * n, offset=o).reshape(-1, n)
    p = j['meshes'][0]['primitives'][0]
    at = p['attributes']
    pos = acc(at['POSITION']).astype(np.float64); uv = acc(at['TEXCOORD_0']); nor = acc(at['NORMAL'])
    idx = acc(p['indices']).reshape(-1, 3)
    iv = j['bufferViews'][j['images'][0]['bufferView']]
    img = bytes(b[iv['byteOffset']:iv['byteOffset'] + iv['byteLength']])
    return pos, uv, nor, idx, img

def componentes(pos, idx):
    claves = np.round(pos / 1e-4).astype(np.int64)
    _, soldado = np.unique(claves, axis=0, return_inverse=True)
    soldado = soldado.reshape(-1)
    n = soldado.max() + 1
    padre = np.arange(n)
    def raiz(x):
        while padre[x] != x:
            padre[x] = padre[padre[x]]; x = padre[x]
        return x
    for t in idx:
        a, b_, c = (raiz(soldado[t[0]]), raiz(soldado[t[1]]), raiz(soldado[t[2]]))
        padre[b_] = a; padre[raiz(c)] = raiz(a)
    r = np.array([raiz(x) for x in range(n)])
    return r[soldado[idx[:, 0]]]  # componente por triangulo

def recortar(img_png, uv, margen=6, lado_max=1024):
    """Recorta la textura al rectangulo de UV que usa la pieza (mas un margen) y la reduce a lado_max como mucho. Devuelve (png, uv nuevas)."""
    im = Image.open(io.BytesIO(img_png)).convert('RGB')
    W, H = im.size
    x0 = max(0, int(np.floor(uv[:, 0].min() * W)) - margen); x1 = min(W, int(np.ceil(uv[:, 0].max() * W)) + margen)
    y0 = max(0, int(np.floor(uv[:, 1].min() * H)) - margen); y1 = min(H, int(np.ceil(uv[:, 1].max() * H)) + margen)
    rec = im.crop((x0, y0, x1, y1))
    w, h = rec.size
    nu = uv.astype(np.float64).copy()
    nu[:, 0] = (nu[:, 0] * W - x0) / w
    nu[:, 1] = (nu[:, 1] * H - y0) / h
    k = min(1.0, lado_max / max(w, h))
    if k < 1.0:
        rec = rec.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)
    b = io.BytesIO(); rec.save(b, 'PNG', optimize=True)
    return b.getvalue(), nu

def escribir(ruta, pos, uv, nor, idx, img):
    pos = pos.astype('<f4'); uv = uv.astype('<f4'); nor = nor.astype('<f4'); idx = idx.astype('<u4')
    trozos = [idx.tobytes(), pos.tobytes(), uv.tobytes(), nor.tobytes(), img]
    vistas = []; bin_ = b''
    for t in trozos:
        vistas.append({'buffer': 0, 'byteOffset': len(bin_), 'byteLength': len(t)})
        bin_ += t + b'\0' * ((4 - len(t) % 4) % 4)
    j = {'asset': {'version': '2.0', 'generator': 'separar_alquimia.py'}, 'scene': 0, 'scenes': [{'nodes': [0]}],
         'nodes': [{'name': os.path.basename(ruta)[:-4], 'mesh': 0}],
         'meshes': [{'primitives': [{'attributes': {'POSITION': 1, 'TEXCOORD_0': 2, 'NORMAL': 3}, 'indices': 0, 'material': 0}]}],
         'materials': [{'pbrMetallicRoughness': {'baseColorTexture': {'index': 0}, 'roughnessFactor': 1.0, 'metallicFactor': 0.0}, 'doubleSided': True}],
         'textures': [{'source': 0}], 'images': [{'bufferView': 4, 'mimeType': 'image/png'}],
         'accessors': [
            {'bufferView': 0, 'componentType': 5125, 'count': int(idx.size), 'type': 'SCALAR'},
            {'bufferView': 1, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3', 'min': pos.min(0).tolist(), 'max': pos.max(0).tolist()},
            {'bufferView': 2, 'componentType': 5126, 'count': len(pos), 'type': 'VEC2'},
            {'bufferView': 3, 'componentType': 5126, 'count': len(pos), 'type': 'VEC3'}],
         'bufferViews': vistas, 'buffers': [{'byteLength': len(bin_)}]}
    js = json.dumps(j).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
    tot = 12 + 8 + len(js) + 8 + len(bin_)
    open(ruta, 'wb').write(struct.pack('<III', 0x46546C67, 2, tot) + struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bin_), 0x004E4942) + bin_)

def main():
    origen, salida = sys.argv[1], sys.argv[2]
    os.makedirs(salida, exist_ok=True)
    pos, uv, nor, idx, img = cargar(origen)
    comp = componentes(pos, idx)
    ids = np.unique(comp)
    info = []
    for c in ids:
        t = idx[comp == c]; vs = np.unique(t)
        p = pos[vs]
        info.append({'c': int(c), 'tris': len(t), 'mn': p.min(0), 'mx': p.max(0)})
    print('componentes:', len(info))
    # agrupar: un componente pequeno se une al grupo cuyo AABB (con margen) lo toque/contenga
    info.sort(key=lambda x: -x['tris'])
    grupos = []
    MARGEN = float(sys.argv[3]) if len(sys.argv) > 3 else 0.01
    for e in info:
        destino = None
        for g in grupos:
            if np.all(e['mn'] <= g['mx'] + MARGEN) and np.all(e['mx'] >= g['mn'] - MARGEN):
                destino = g; break
        if destino is None:
            grupos.append({'cs': [e['c']], 'tris': e['tris'], 'mn': e['mn'].copy(), 'mx': e['mx'].copy()})
        else:
            destino['cs'].append(e['c']); destino['tris'] += e['tris']
            destino['mn'] = np.minimum(destino['mn'], e['mn']); destino['mx'] = np.maximum(destino['mx'], e['mx'])
    # ordenar por x, luego z para numeracion estable
    grupos.sort(key=lambda g: (round(float(g['mn'][0] + g['mx'][0]) / 2, 1), float(g['mn'][2] + g['mx'][2]) / 2))
    out = []
    for n, g in enumerate(grupos):
        m = np.isin(comp, g['cs'])
        t = idx[m]; vs, inv = np.unique(t, return_inverse=True)
        p = pos[vs].copy(); mn = p.min(0); mx = p.max(0)
        centro = np.array([(mn[0] + mx[0]) / 2, mn[1], (mn[2] + mx[2]) / 2])
        p -= centro
        if len(sys.argv) > 4:
            img2, uv2 = recortar(img, uv[vs])
            escribir(os.path.join(salida, 'obj_%02d.glb' % n), p, uv2, nor[vs], inv.reshape(-1, 3), img2)
        else:
            escribir(os.path.join(salida, 'obj_%02d.glb' % n), p, uv[vs], nor[vs], inv.reshape(-1, 3), img)
        if len(sys.argv) > 5:   # "1:pocion_alq_0,3:pocion_alq_1": ademas escribe esos objetos con ese nombre (el nombre del nodo raiz es el del archivo)
            for par in sys.argv[5].split(','):
                k, nom = par.split(':')
                if int(k) == n:
                    escribir(os.path.join(salida, nom + '.glb'), p, uv2, nor[vs], inv.reshape(-1, 3), img2)
        out.append({'n': n, 'tris': int(len(t)), 'comps': len(g['cs']), 'tam': (mx - mn).round(3).tolist(), 'centro': ((mn + mx) / 2).round(3).tolist()})
        print(out[-1])
    json.dump(out, open(os.path.join(salida, 'indice.json'), 'w'))
main()


