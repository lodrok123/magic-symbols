"""Genera la ficha de revisión a partir del inventario exportado por Blender."""
import json
from pathlib import Path
from html import escape

raiz = Path(__file__).resolve().parents[1]
qa = raiz / 'output/blender_interacciones_2026-11-25'
datos = json.loads((qa/'inventario_blender.json').read_text(encoding='utf-8'))
filas=[]
for d in datos:
    ident=d['id']
    uso='Integrado: rotura del objeto y restos persistentes.' if ident in ['caja_fragmentos','jarron_fragmentos','jarron_alto_fragmentos'] else 'Preparado para asignar tras revisión visual.'
    if ident=='bayas_separadas': uso='Integrado: arbusto normal; recoger oculta el nodo de frutos y rebrotar lo recupera.'
    if ident=='bayas_agotadas': uso='Variante independiente disponible. En partida se ocultan los frutos del modelo separado.'
    filas.append(f'''<article><h2>{escape(ident.replace('_',' '))}</h2>
<a href="../output/blender_interacciones_2026-11-25/{ident}.png"><img src="../output/blender_interacciones_2026-11-25/{ident}.png" alt="Original y derivado"></a>
<p>{escape(d['notas'])}</p><p>{escape(uso)}</p>
<p>{d['mallas']} mallas · {d['triangulos']:,} triángulos · <a href="../{d['blend']}">Editable .blend</a> · <a href="../{d['glb']}">GLB</a></p></article>''')
pagina='''<!doctype html><html lang="es"><meta charset="utf-8"><title>Tanda Blender · Interacciones</title>
<style>body{background:#19232d;color:#e6edf3;font:17px/1.5 system-ui;max-width:1400px;margin:40px auto;padding:0 25px}a{color:#8ed4ff}h1{font-size:36px}h2{text-transform:capitalize;font-size:23px}article{background:#23303b;padding:18px;border-radius:12px}img{width:100%;display:block}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(450px,1fr));gap:20px}p{margin:10px 0}.estado{padding:18px;background:#263d32;border-radius:10px}</style>
<h1>Interacciones · Tanda de Blender</h1><p>25/11/2026 · Blender 5.2.2 LTS · 12 variantes derivadas de los modelos del juego.</p>
<p class="estado">Integrados los fragmentos de cajas y jarrones y el arbusto con frutos separados. Actualización posterior: <a href="CONEXION_BLENDER_2026-11-25.html">el resto de variantes ya tiene conexiones con estados y actores del juego</a>. Las fichas siguientes conservan el estado de entrega de esta tanda de assets.</p>
<p><a href="../output/blender_interacciones_2026-11-25/lamina_blender.png">Abrir lámina completa</a> · <a href="../output/blender_interacciones_2026-11-25/inventario_blender.json">Inventario</a> · <a href="INTERACCIONES_CODIGO_2026-11-25.html">Tanda anterior por código</a></p>
<p>Comparativas capturadas en Godot: original a la izquierda y derivado a la derecha. Los fragmentos se muestran separados para ver sus cortes; se exportan recompuestos. Conservan UV exteriores y materiales interiores. Las vasijas abiertas reciben espesor de cerámica. La roca agrietada tiene separación real. El barril abierto original recibe una tapa nueva de cinco tablas y una bisagra animada.</p>
<p>Los originales se conservan. Los editables contienen texturas empaquetadas y están dentro de carpetas con .gdignore para evitar importaciones dobles. Los derivados de caja y barril Cosmos permanecen en arte/lostcave, con las mismas restricciones de distribución del original.</p>
<p><b>Validación:</b> 109 comprobaciones de assets e integración, sin fallos: 12 GLB importados, 12 editables existentes, geometría sin colisiones, ocho piezas por rotura, bisagra animada, escala recompuesta, fragmentos asentados y misma pose al nacer roto por flag. También pasan las baterías de feedback y recoger/lanzar. La galería se revisó después de corregir las caras interiores y construir una tapa completa.</p>
<p>Reproducción: ejecutar herramientas/exportar_fuentes_blender_interacciones.gd con Godot; después Blender --background --factory-startup --python herramientas/blender_interacciones.py; importar los GLB y ejecutar herramientas/captura_blender_interacciones.gd con Godot. El capturador también verifica geometría, editables, bisagra, escala de roturas, asentamiento, recarga y recolección.</p>
<div class="grid">'''+''.join(filas)+'''</div><p>La segmentación de bayas parte de regiones rojas de la textura y se hornea en geometría; no usa máscara cromática durante la partida. La unión original entre fruto y hoja puede dejar pequeñas marcas de corte en los puntos de contacto. Revisar estas zonas si se exige un primer plano extremo.</p></html>'''
(raiz/'docs/BLENDER_INTERACCIONES_2026-11-25.html').write_text(pagina,encoding='utf-8')
print('Informe Blender generado')
