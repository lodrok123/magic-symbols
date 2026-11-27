"""VALIDACIÓN EN PLAYTEST DE LOS PUZLES DEL CATÁLOGO (24/11/2026) entre la hoja maestra y las plantillas del generador.

La hoja maestra (docs/BD_INTERACTUABLES.xlsx, pestaña Puzzles) es donde Pablo decide; el generador lee el estado de cada plantilla
(herramientas/generador_mapas/catalogo/<id>.txt, línea `; validacion`). Este script los mantiene iguales.

  python tools/validacion_puzles.py alta
      Da de alta (o pone al día) una fila `cat_<id>` por plantilla del catálogo, más las salas del jefe y el campamento: nombre, estado,
      propuesta (en qué nivel de playtest y sala está), elementos necesarios, ubicación. NO toca decision_pablo ni nota_pablo.
  python tools/validacion_puzles.py sincronizar
      Lleva lo que Pablo ha puesto en la hoja a las plantillas:
        decision_pablo Aceptar / Aplicada  -> `; validacion aceptado`
        decision_pablo Rechazar            -> `; validacion rechazado`
        nota_pablo con texto y sin aceptar -> `; validacion ajustes` + `; nota_playtest <nota>`
        lo demás                           -> `; validacion pendiente`
Con la hoja abierta en Excel no se puede guardar: ciérrala antes.
"""
import os, re, sys
import openpyxl
from copy import copy

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOJA = os.path.join(RAIZ, "docs", "BD_INTERACTUABLES.xlsx")
CATALOGO = os.path.join(RAIZ, "herramientas", "generador_mapas", "catalogo")
MAPAS = os.path.join(RAIZ, "mundo", "datos_nivel", "mapas")
RUNAS_DEMO = {"fuego", "agua", "tierra", "flecha", "linea", "barrera", "altura", "raido", "suelo"}
EXTRA = {  # salas de enemigos que se piden como un puzle más
	"jefe_golem": ("Sala del jefe: gólem (cueva)", "PtJefeCueva"),
	"jefe_elemental": ("Sala del jefe: elemental del bosque", "PtJefeBosque"),
	"campamento": ("Campamento goblin (sala de enemigos)", "PtJefeCueva, PtJefeBosque"),
}


def plantillas():
	res = {}
	for f in sorted(os.listdir(CATALOGO)):
		if not f.endswith(".txt"):
			continue
		e = {"id": f[:-4], "titulo": f[:-4], "tipo": "premio", "necesita": "", "validacion": "pendiente", "ruta": os.path.join(CATALOGO, f)}
		for l in open(e["ruta"], encoding="utf8"):
			m = re.match(r";\s*(catalogo|titulo|tipo|necesita|validacion|solo_mano)\s+(.*)", l.rstrip("\n"))
			if m:
				e[m.group(1) if m.group(1) != "catalogo" else "id"] = m.group(2).strip()
		# Los muestrarios de piezas (`; solo_mano si`) no son puzles: no se validan en playtest.
		if e.get("solo_mano", "") == "si":
			continue
		res[e["id"]] = e
	return res


def donde_playtest():
	"""puzle -> (mapa, orden) leyendo las zonas `nombre=pt_<id> rotulo=<n>._…` de los mapas Pt*."""
	res = {}
	for f in os.listdir(MAPAS):
		if not f.startswith("Pt") or not f.endswith(".txt"):
			continue
		for l in open(os.path.join(MAPAS, f), encoding="utf8"):
			m = re.search(r"nombre=pt_(\w+) rotulo=(\d+)\.", l)
			if m:
				res[m.group(1)] = (f[:-4], int(m.group(2)))
	return res


def se_juega_en_demo(necesita):
	if necesita in ("", "-"):
		return True
	return any(set(r.strip() for r in alt.split("+")) <= RUNAS_DEMO for alt in necesita.split("|"))


def columnas(ws):
	return {str(c.value): i for i, c in enumerate(ws[1]) if c.value is not None}


def alta():
	wb = openpyxl.load_workbook(HOJA)
	ws = wb["Puzzles"]
	col = columnas(ws)
	filas = {str(ws.cell(r, 1).value): r for r in range(2, ws.max_row + 1) if ws.cell(r, 1).value}
	donde = donde_playtest()
	datos = []
	for cid, e in plantillas().items():
		lugar = donde.get(cid)
		datos.append(("cat_" + cid, e["titulo"], e["necesita"] if e["necesita"] not in ("", "-") else "empujar",
			"Validar en playtest: %s · sala %d (docs/PLAYTEST_PUZLES.md)" % lugar if lugar else "Sin nivel de playtest",
			"escenas/Prueba%s.tscn" % lugar[0] if lugar else "", "si" if se_juega_en_demo(e["necesita"]) else "no",
			"CAT %s (herramientas/generador_mapas/catalogo/%s.txt) · tipo %s" % (cid, cid, e["tipo"])))
	for cid, (titulo, mapa) in EXTRA.items():
		datos.append(("cat_" + cid, titulo, "combate", "Validar en playtest: %s (docs/PLAYTEST_PUZLES.md)" % mapa, "escenas/Prueba%s.tscn" % mapa.split(",")[0],
			"si", "generador_mazmorra.gd (%s)" % ("JEFES" if cid.startswith("jefe") else "CAMPAMENTO")))
	modelo = ws.max_row
	nuevas = 0
	for (fid, nombre, nec, propuesta, ubic, demo, doc) in datos:
		r = filas.get(fid)
		if r is None:
			ws.append([None] * ws.max_column)
			r = ws.max_row
			for c in range(1, ws.max_column + 1):
				ws.cell(r, c)._style = copy(ws.cell(modelo, c)._style)
			ws.cell(r, col["id"] + 1).value = fid
			ws.cell(r, col["estado"] + 1).value = "Prototipo"
			nuevas += 1
		ws.cell(r, col["nombre"] + 1).value = nombre
		ws.cell(r, col["propuesta_claude"] + 1).value = propuesta
		ws.cell(r, col["elementos_necesarios"] + 1).value = nec
		ws.cell(r, col["ubicacion"] + 1).value = ubic
		ws.cell(r, col["en_demo"] + 1).value = demo
		ws.cell(r, col["codigo_doc"] + 1).value = doc
		# verificado: valores del desplegable (No (deducido) · Claude (probado) · Pablo (visto)). Las plantillas las resuelve una prueba en el juego
		# (escenario_catalogo_puzles, escenario_catalogo_nuevos); el playtest de Pablo lo sube a «Pablo (visto)».
		if str(ws.cell(r, col["verificado"] + 1).value or "") in ("", "None") or str(ws.cell(r, col["verificado"] + 1).value).startswith("Prueba"):
			ws.cell(r, col["verificado"] + 1).value = "Claude (probado)"
	wb.save(HOJA)
	print("Puzzles: %d filas cat_* (%d nuevas)" % (len(datos), nuevas))


def sincronizar():
	wb = openpyxl.load_workbook(HOJA, read_only=True)
	ws = wb["Puzzles"]
	filas = list(ws.iter_rows(values_only=True))
	col = {str(v): i for i, v in enumerate(filas[0]) if v is not None}
	cat = plantillas()
	cambios = 0
	for f in filas[1:]:
		fid = str(f[col["id"]] or "")
		if not fid.startswith("cat_") or fid[4:] not in cat:
			continue
		e = cat[fid[4:]]
		decision = str(f[col["decision_pablo"]] or "").strip().lower()
		nota = str(f[col["nota_pablo"]] or "").strip()
		if decision in ("aceptar", "aplicada"):
			estado = "aceptado"
		elif decision == "rechazar":
			estado = "rechazado"
		elif nota:
			estado = "ajustes"
		else:
			estado = "pendiente"
		lineas = open(e["ruta"], encoding="utf8").read().split("\n")
		nuevas = [l for l in lineas if not l.startswith("; nota_playtest")]
		nuevas = ["; validacion " + estado if l.startswith("; validacion") else l for l in nuevas]
		if nota:
			i = next(k for k, l in enumerate(nuevas) if l.startswith("; validacion"))
			for k, trozo in enumerate(nota.splitlines()):
				if trozo.strip():
					nuevas.insert(i + 1 + k, "; nota_playtest " + trozo.strip())
		if nuevas != lineas:
			open(e["ruta"], "w", encoding="utf8", newline="\n").write("\n".join(nuevas))
			cambios += 1
			print("%s -> %s%s" % (fid[4:], estado, (" · " + nota) if nota else ""))
	print("%d plantillas cambiadas" % cambios)


if __name__ == "__main__":
	{"alta": alta, "sincronizar": sincronizar}.get(sys.argv[1] if len(sys.argv) > 1 else "", lambda: print(__doc__))()
