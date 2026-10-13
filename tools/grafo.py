# grafo.py — grafo de dependencias del proyecto Godot y lista de lo que ninguna escena alcanza. Lo escribe el Juego.
# Uso, desde la raíz del repo:   python tools\grafo.py        (escribe tools\grafo_dependencias.json y resume por pantalla)
# Raíces: las escenas de escenas/ y laboratorios/ (lo que se juega y se prueba) y las pruebas sin ventana de herramientas/.
# Una arista por cada res://… en escenas y recursos, por cada preload/load/extends "…", y por cada uso de un class_name.
import os, re, json, sys, collections
R = sys.argv[1] if len(sys.argv) > 1 else '.'
EXCL = ('.godot', '_a_eliminar', '.git', 'docs', 'tools', 'art', 'audio', 'arte')
files = {}
for dp, dn, fn in os.walk(R):
    dn[:] = [d for d in dn if d not in EXCL]
    for f in fn:
        p = os.path.join(dp, f); rel = os.path.relpath(p, R).replace('\\', '/')
        if rel.rsplit('.', 1)[-1] in ('gd', 'tscn', 'tres', 'godot'):
            try: files[rel] = open(p, encoding='utf-8', errors='replace').read()
            except Exception: pass
cls = {}
for rel, t in files.items():
    if rel.endswith('.gd'):
        m = re.search(r'^class_name\s+(\w+)', t, re.M)
        if m: cls[m.group(1)] = rel
deps = collections.defaultdict(set)
for rel, t in files.items():
    for m in re.finditer(r'res://([\w\-/\. ]+)', t):
        p = m.group(1).strip()
        if p in files: deps[rel].add(p)
    for c, f in cls.items():
        if f != rel and re.search(r'\b' + c + r'\b', t): deps[rel].add(f)
def alcanza(roots):
    vis, pila = set(), list(roots)
    while pila:
        x = pila.pop()
        if x in vis: continue
        vis.add(x); pila += list(deps.get(x, ()))
    return vis
raices = [f for f in files if (f.startswith(('escenas/', 'laboratorios/')) and f.endswith('.tscn')) or (f.startswith('herramientas/prueba_') and f.endswith('.gd'))]
vivos = alcanza(raices)
muertos = sorted(f for f in files if f not in vivos and f != 'project.godot' and not f.startswith('mundo/datos_nivel/'))
os.makedirs(os.path.join(R, 'tools'), exist_ok=True)
json.dump({'raices': raices, 'clases': cls, 'deps': {k: sorted(v) for k, v in deps.items()}, 'vivos': sorted(vivos), 'muertos': muertos},
          open(os.path.join(R, 'tools', 'grafo_dependencias.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
print('archivos de código:', len(files), '| raíces:', len(raices), '| alcanzables:', len(vivos))
print('NO alcanzables desde ninguna escena ni prueba (candidatos a borrar):', len(muertos))
for f in muertos: print('  ', f)
