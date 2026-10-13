import os,re,json,collections
R='repo'
files={}
for dp,dn,fn in os.walk(R):
    for f in fn:
        p=os.path.join(dp,f); rel=os.path.relpath(p,R).replace('\\','/')
        if rel.split('.')[-1] in ('gd','tscn','tres','godot','json'):
            try: files[rel]=open(p,encoding='utf-8',errors='replace').read()
            except: pass
# class_name
cls={}
for rel,t in files.items():
    if rel.endswith('.gd'):
        m=re.search(r'^class_name\s+(\w+)',t,re.M)
        if m: cls[m.group(1)]=rel
# también clases internas? no.
deps=collections.defaultdict(set)
for rel,t in files.items():
    for m in re.finditer(r'res://([\w\-/\. ]+)',t):
        p=m.group(1).strip()
        if p in files or os.path.exists(os.path.join(R,p)): deps[rel].add(p)
    if rel.endswith('.gd') or rel.endswith('.tscn'):
        for c,f in cls.items():
            if f!=rel and re.search(r'\b'+c+r'\b',t): deps[rel].add(f)
    # extends "x.gd" relativo
    for m in re.finditer(r'(?:extends|preload|load)\s*\(?\s*"([\w\-/\.]+\.(?:gd|tscn|tres))"',t):
        p=m.group(1)
        if not p.startswith('res://'):
            cand=os.path.normpath(os.path.join(os.path.dirname(rel),p)).replace('\\','/')
            if cand in files: deps[rel].add(cand)
def alcanza(roots):
    vis=set(); pila=list(roots)
    while pila:
        x=pila.pop()
        if x in vis: continue
        vis.add(x); pila+=list(deps.get(x,()))
    return vis
raices3d=[f for f in files if f.startswith('poc_25d/') and f.endswith('.tscn') and '/niveles/' not in f and '/piezas/' not in f]
r3=alcanza(raices3d)
r2=alcanza(['Mundo.tscn'])
todos=alcanza([f for f in files if f.endswith('.tscn')])
json.dump({'cls':cls,'deps':{k:sorted(v) for k,v in deps.items()},'r3':sorted(r3),'r2':sorted(r2),'raices3d':raices3d},open('grafo.json','w'),indent=1)
print('raices 3D',raices3d)
print('\n== alcanzable desde 3D pero FUERA de poc_25d (herencia 2D que el 3D usa):')
for f in sorted(r3):
    if not f.startswith('poc_25d/'): print(' ',f, '<-', sorted(k for k,v in deps.items() if f in v and k.startswith('poc_25d/'))[:4])
print('\n== .gd/.tscn/.tres NO alcanzables desde ninguna escena 3D:')
for f in sorted(files):
    if f not in r3 and f.split('.')[-1] in ('gd','tscn','tres'): print(' ',f, '(2D main)' if f in r2 else '(ni 2D)')
