extends "res://herramientas/catalogo_jugar.gd"
## 26/11 · COMPROBADOR AUTOMÁTICO de los puzles del catálogo (sobre todo los de agua). Coge cada plantilla de `herramientas/generador_mapas/catalogo/*.txt` que tenga líneas
## `; prueba`, la monta en un mapa generado A VARIOS ANCHOS, aplica cada solución con hechizos de verdad (`Lanzador3D`, como el juego), comprueba que se resuelve y MIDE cuánto
## tarda. Una plantilla nueva se valida escribiendo unas líneas en su .txt: no hay código nuevo. Cada prueba recarga el mapa (lo resuelto no se deshace).
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/comprobar_puzles_agua.gd            (todas las plantillas con pruebas)
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/comprobar_puzles_agua.gd -- puente_aliviadero   (solo esa; admite varias)
## Imprime una línea OK/FALLO por plantilla × solución × ancho con el TIEMPO medido y, al final, una tabla resumen plantilla × solución × ancho. Sale con código 1 si algo falla.
##
## FORMATO (líneas de comentario de la plantilla, que el generador ignora; documentado también en `catalogo_puzles.gd`):
##   ; prueba anchos 5 8 12
##       Solo con `estira x`: los anchos de sala a los que se prueba (el generador los fuerza con el parámetro `ancho_puzle`; no pueden bajar de `ancho_min`). Sin esta línea,
##       o con una plantilla de ancho fijo, se prueba una sola vez al ancho natural.
##   ; prueba mapa <clave>=<valor> …
##       Parámetros del mapa generado donde se prueba (p. ej. `ancho=70 alto=60 sala_min=4 sala_max=7 estilo=cueva`), para plantillas grandes que no caben en el mapa por defecto.
##   ; prueba <nombre>: <paso> | <paso> | …
##       Una prueba. `solucion A:`, `solucion B:` … deben RESOLVER; cualquier otro nombre (p. ej. `nada:`) suele llevar un `nunca` y debe NO resolver.
##       Los pasos se hacen en orden. Se pueden usar los comodines de la plantilla `$XC`, `$X1` y `$Y1`. Las casillas se escriben `x:y` (locales de la plantilla; sirven sumas y restas sencillas, p. ej. `$XC-1:3`).
##   Pasos:
##     golpe <elemento> <pieza|x:y> [con <glifo>[+<glifo>…]] [desde x:y] [, otro golpe …]
##         Lanza ese hechizo (por defecto con el glifo `flecha`) a la casilla de la pieza, en orden y separados por `,`. `desde` fija la casilla de tiro (la orilla de entrada);
##         sin él se usa la casilla pisable más cercana al blanco (mejor ponerlo: si no, puede elegir una orilla que la jugadora no alcanza). Con el glifo `barrera` (la
##         tierra levantada en el blanco) el hechizo sale en el punto, como en la Cueva Resonante.
##         REGLA DE TIRO: antes de cada golpe de FUEGO se mira que entre la casilla de tiro y el blanco no haya agua (la flecha de fuego se apaga al cruzar agua).
##         Si la hay, FALLO con explicación: es un error de diseño de la plantilla.
##     reposo <s>                       espera esos segundos (antes de todo ya se esperan 4 s para que el agua se asiente).
##     espera <condición>               espera a que se cumpla; el tiempo se mide desde el ÚLTIMO golpe.
##     nunca <condición>                comprueba que NO se cumple en ningún momento durante lo que dura `durante`.
##     max <s>                          tope para las `espera` (cuenta desde el último golpe). Si no se cumple a tiempo, FALLO (se sigue esperando hasta 3 × el tope solo para medir cuánto
##                                      tardaría de verdad y decirlo). Sin `max` el tope es de 60 s.
##     durante <s>                      lo que dura un `nunca`.
##     cruza x:y a x:y                  la jugadora anda DE VERDAD (WASD) de una casilla a otra: tiene que llegar y SIN nadar (un cruce a nado no vale).
##   Condiciones:
##     cuenca <pieza> <op> <u>          nivel de agua de las casillas de una pieza `cuenca` (sus `celdas`, o la suya), en u. Operadores: `bajo` / `sobre` (la MEDIA de sus casillas),
##                                      `todas_bajo` (TODAS por debajo: es la que dice si un cauce largo se pisa entero) y `alguna_sobre`. Con 0,25 u o más una casilla no se pisa.
##     alcanzable <pieza>               hay una casilla pisable a ≤ 2,7 u (el alcance de E) de la pieza (el cofre sobre la balsa que se mueve).
##     <pieza> [no] <estado>            el estado de una pieza por la tabla `CONDICIONES` de `escenas/puzle.gd`: `compuerta abierta`, `puente tendido`, `molino girando`, `balsa atracada`,
##                                      `nivel alcanzado`, `cofre abierto`, `cuerda rota`… `no` lo niega.
## EJEMPLOS:
##   ; prueba anchos 5 8 12
##   ; prueba solucion A: golpe fuego cuerda desde $XC-1:3 | espera puente tendido | max 6        (en las casillas valen sumas y restas sencillas: `$XC-1:3`)
##   ; prueba solucion B: golpe fuego tapon desde 1:3 | espera cuenca cauce todas_bajo 0.25 | max 20
##   ; prueba nada: golpe agua tapon desde 1:3 | nunca cuenca cauce bajo 0.25 | durante 15

const REPOSO_INICIAL: float = 4.0
const MAX_DEFECTO: float = 60.0
const RADIO_TIRO: int = 4                              ## hasta dónde busca una casilla de tiro si no se da `desde`

var _resultados: Array = []
var _sin_sala: Dictionary = {}                         ## "plantilla/ancho" → por qué no se pudo montar (para no repetir la búsqueda)
var _n: int = 0


func _escenario() -> void:
	prefijo = "CatComp"
	_limpiar()
	var solo: PackedStringArray = OS.get_cmdline_user_args()
	var t0: float = Time.get_ticks_msec() * 0.001
	var cat: Dictionary = Catalogo.todos()
	var ids: Array = cat.keys()
	ids.sort()
	var hechas: int = 0
	for cid in ids:
		var e: Dictionary = cat[cid]
		if (e["pruebas"] as Array).is_empty() or (not solo.is_empty() and not solo.has(String(cid))):
			continue
		hechas += 1
		await _plantilla(String(cid), e)
	_ok("hay alguna plantilla con líneas `; prueba`%s" % ((" (filtro: %s)" % ", ".join(solo)) if not solo.is_empty() else ""), hechas > 0)
	_tabla()
	_limpiar()
	print("TIEMPO DE PARED: %.0f s" % (Time.get_ticks_msec() * 0.001 - t0))


func _plantilla(cid: String, e: Dictionary) -> void:
	var anchos: Array = [0]
	if String(e["estira"]) == "x" and not (e["anchos"] as Array).is_empty():
		anchos = []
		for a in (e["anchos"] as Array):
			if int(a) < int(e["ancho_min"]):
				_ok("%s: el ancho %d de `prueba anchos` es menor que `ancho_min` %d" % [cid, int(a), int(e["ancho_min"])], false)
			else:
				anchos.append(int(a))
	for ancho in anchos:
		for texto in (e["pruebas"] as Array):
			_n += 1
			_resultados.append(await _una(cid, e, int(ancho), String(texto), "P%d" % _n))


# ---------------------------------------------------------------------------------------------------------------------
#  Una prueba
# ---------------------------------------------------------------------------------------------------------------------

func _una(cid: String, e: Dictionary, ancho: int, texto: String, etq: String) -> Dictionary:
	var i: int = texto.find(":")
	var cab: String = texto.substr(0, i).strip_edges() if i >= 0 else texto
	var r: Dictionary = {"cid": cid, "sol": cab.trim_prefix("solucion").strip_edges(), "ancho": ancho, "ok": false, "t": -1.0, "nota": "", "nunca": false}
	var clave: String = "%s/%d" % [cid, ancho]
	if _sin_sala.has(clave):
		return _fin(r, false, String(_sin_sala[clave]))
	if i < 0:
		return _fin(r, false, "la línea no tiene «nombre: pasos»: «%s»" % texto)
	var montado: bool = await _caso(cid, etq, "", 0, 0, ancho, e["mapa"])
	r["ancho"] = _tw if _tw > 0 else ancho
	if not montado or _z == null or not _z.avisos.is_empty():
		_sin_sala[clave] = _error_caso
		return _fin(r, false, _error_caso)
	if _o == Vector2i(-1, -1):
		return _fin(r, false, "no se pudo fijar dónde cae la plantilla (ninguna pieza con casilla numérica)")
	var cuerpo: String = texto.substr(i + 1).strip_edges().replace("$XC", str(int((_tw - 1) * 0.5))).replace("$X1", str(_tw - 1)).replace("$Y1", str(_th - 1))
	var plan: Dictionary = _parsear(cuerpo)
	if String(plan["err"]) != "":
		return _fin(r, false, "prueba mal escrita: " + String(plan["err"]))
	var segs: Array = plan["segs"]
	var tope: float = float(plan["max"])
	var durante: float = float(plan["durante"])
	r["nunca"] = segs.any(func(s: Dictionary) -> bool: return String(s["k"]) == "nunca")
	await avanzar_s(REPOSO_INICIAL)
	var t_golpe: float = reloj.t
	var t_fin: float = -1.0
	for s in segs:
		match String(s["k"]):
			"golpe":
				for g in (s["golpes"] as Array):
					var err: String = await _golpear(g as Dictionary)
					if err != "":
						return _fin(r, false, err)
					t_golpe = reloj.t
					await avanzar_s(0.3)
			"reposo":
				await avanzar_s(float(s["s"]))
			"espera":
				var cond: Dictionary = s["cond"]
				var resta: float = tope - (reloj.t - t_golpe)
				var t: float = await _hasta(func() -> bool: return _cumple(cond), maxf(resta, 0.0))
				if t < 0.0:
					var extra: float = await _hasta(func() -> bool: return _cumple(cond), 2.0 * tope)
					var cuando: String = ("se cumple a los %.1f s" % (reloj.t - t_golpe)) if extra >= 0.0 else ("no se cumple ni a los %.0f s" % (3.0 * tope))
					r["t"] = (reloj.t - t_golpe) if extra >= 0.0 else -1.0
					return _fin(r, false, "«%s» no se cumple en %.0f s (max); %s" % [cond["txt"], tope, cuando])
				t_fin = reloj.t - t_golpe
				r["t"] = t_fin
			"nunca":
				var cond: Dictionary = s["cond"]
				var vista: float = 0.0
				while vista < durante:
					if _cumple(cond):
						return _fin(r, false, "«%s» se cumple a los %.1f s del golpe, y no debería" % [cond["txt"], reloj.t - t_golpe])
					vista += await avanzar_s(0.1)
				r["t"] = durante
				t_fin = durante
			"cruza":
				colocar_jugador(s["a"] as Vector2i)
				await avanzar_s(0.3)
				var llego: bool = await _andar(s["b"] as Vector2i, 15.0)
				if not llego:
					return _fin(r, false, "la jugadora no llega andando de %s a %s (acaba en %s)" % [str(s["a"]), str(s["b"]), str(celda_jugador())])
				if _nado_s > 0.0:
					return _fin(r, false, "el cruce de %s a %s se hizo NADANDO (%.1f s): no vale" % [str(s["a"]), str(s["b"]), _nado_s])
	if t_fin < 0.0 and not segs.any(func(s: Dictionary) -> bool: return String(s["k"]) == "cruza"):
		return _fin(r, false, "la prueba no tiene ninguna `espera`, `nunca` ni `cruza`: no comprueba nada")
	r["t"] = t_fin
	var nota: String = ("sin cambio durante %.0f s" % durante) if bool(r["nunca"]) else ("%.1f s (max %.0f)" % [t_fin, tope] if t_fin >= 0.0 else "cruza andando sin nadar")
	return _fin(r, true, nota)


func _fin(r: Dictionary, ok: bool, nota: String) -> Dictionary:
	r["ok"] = ok
	r["nota"] = nota
	_ok("%s %s ancho %d:" % [r["cid"], r["sol"], int(r["ancho"])], ok, nota)
	return r


# ---------------------------------------------------------------------------------------------------------------------
#  Leer los pasos
# ---------------------------------------------------------------------------------------------------------------------

## Casilla local `x:y` → casilla del mapa. (-1, -1) en `ok` falso si está mal escrita.
func _casilla(t: String) -> Variant:
	var p: PackedStringArray = t.split(":")
	if p.size() == 2:
		var x: Variant = _entero(p[0])
		var y: Variant = _entero(p[1])
		if x != null and y != null:
			return _c(int(x), int(y))
	return null


## Un número o una suma/resta sencilla («5-1», que sale de `$XC-1`). null si no se entiende.
func _entero(s: String) -> Variant:
	if s.is_valid_int():
		return s.to_int()
	var ex: Expression = Expression.new()
	if s == "" or ex.parse(s) != OK:
		return null
	var v: Variant = ex.execute([], null, false)
	return int(v) if (v is int or v is float) and not ex.has_execute_failed() else null


## El id completo de una pieza de la plantilla en el mapa ("" si no existe).
func _id_pieza(local: String) -> String:
	var t: PackedStringArray = _linea_local(local)
	return t[1] if t.size() >= 5 else ""


## Las casillas (ya del mapa: las líneas generadas vienen trasladadas) de una pieza `cuenca`: sus `celdas` (listas `x,y`, rangos `x,y..x,y` unidos con `+`) o la suya.
func _celdas_pieza(local: String) -> Array:
	var t: PackedStringArray = _linea_local(local)
	var res: Array = []
	if t.size() < 5:
		return res
	for k in range(5, t.size()):
		if t[k].begins_with("celdas="):
			for parte in t[k].substr(7).split("+", false):
				var ab: PackedStringArray = parte.split("..")
				var a: PackedStringArray = ab[0].split(",")
				var b: PackedStringArray = (ab[1] if ab.size() > 1 else ab[0]).split(",")
				for y in range(a[1].to_int(), b[1].to_int() + 1):
					for x in range(a[0].to_int(), b[0].to_int() + 1):
						res.append(Vector2i(x, y))
			return res
	res.append(Vector2i(t[3].to_int(), t[4].to_int()))
	return res


func _parsear(cuerpo: String) -> Dictionary:
	var plan: Dictionary = {"err": "", "segs": [], "max": MAX_DEFECTO, "durante": 0.0}
	for parte in cuerpo.split("|"):
		var p: String = parte.strip_edges()
		if p == "":
			continue
		var t: PackedStringArray = p.split(" ", false)
		match t[0]:
			"golpe":
				var golpes: Array = []
				for gt in p.substr(5).split(","):
					var g: Dictionary = _parsear_golpe(gt.strip_edges())
					if String(g.get("err", "")) != "":
						plan["err"] = String(g["err"])
						return plan
					golpes.append(g)
				(plan["segs"] as Array).append({"k": "golpe", "golpes": golpes})
			"reposo":
				(plan["segs"] as Array).append({"k": "reposo", "s": t[1].to_float() if t.size() > 1 else 0.0})
			"max":
				plan["max"] = t[1].to_float() if t.size() > 1 else MAX_DEFECTO
			"durante":
				plan["durante"] = t[1].to_float() if t.size() > 1 else 0.0
			"espera", "nunca":
				var c: Dictionary = _parsear_cond(t.slice(1))
				if String(c.get("err", "")) != "":
					plan["err"] = String(c["err"])
					return plan
				(plan["segs"] as Array).append({"k": t[0], "cond": c})
			"cruza":
				var a: Variant = _casilla(t[1]) if t.size() > 1 else null
				var b: Variant = _casilla(t[3]) if t.size() > 3 else null
				if a == null or b == null or t[2] != "a":
					plan["err"] = "«%s»: se escribe `cruza x:y a x:y`" % p
					return plan
				(plan["segs"] as Array).append({"k": "cruza", "a": a, "b": b})
			_:
				plan["err"] = "paso desconocido «%s» (golpe, reposo, espera, nunca, max, durante, cruza)" % t[0]
				return plan
	if (plan["segs"] as Array).any(func(s: Dictionary) -> bool: return String(s["k"]) == "nunca") and float(plan["durante"]) <= 0.0:
		plan["err"] = "un `nunca` necesita `durante <s>`"
	return plan


func _parsear_golpe(txt: String) -> Dictionary:
	var t: PackedStringArray = txt.split(" ", false)
	if t.size() < 2:
		return {"err": "«%s»: se escribe `golpe <elemento> <pieza|x:y>`" % txt}
	var g: Dictionary = {"elem": t[0], "glifos": ["flecha"], "fijo": false, "desde": Vector2i.ZERO, "txt": txt}
	var celda: Vector2i = Vector2i.ZERO
	if t[1].contains(":"):
		var c: Variant = _casilla(t[1])
		if c == null:
			return {"err": "«%s»: casilla mal escrita" % txt}
		celda = c
	else:
		var lin: PackedStringArray = _linea_local(t[1])
		if lin.size() < 5:
			return {"err": "«%s»: la plantilla no tiene la pieza «%s»" % [txt, t[1]]}
		celda = Vector2i(lin[3].to_int(), lin[4].to_int())
	g["celda"] = celda
	var k: int = 2
	while k < t.size():
		if t[k] == "con" and k + 1 < t.size():
			g["glifos"] = Array(t[k + 1].split("+", false))
			k += 2
		elif t[k] == "desde" and k + 1 < t.size():
			var d: Variant = _casilla(t[k + 1])
			if d == null:
				return {"err": "«%s»: `desde` mal escrito" % txt}
			g["desde"] = d
			g["fijo"] = true
			k += 2
		else:
			return {"err": "«%s»: no entiendo «%s»" % [txt, t[k]]}
	return g


func _parsear_cond(t: PackedStringArray) -> Dictionary:
	var txt: String = " ".join(t)
	if t.is_empty():
		return {"err": "una condición vacía"}
	if t[0] == "cuenca":
		if t.size() < 4 or not ["bajo", "sobre", "todas_bajo", "alguna_sobre"].has(t[2]):
			return {"err": "«%s»: se escribe `cuenca <pieza> bajo|sobre|todas_bajo|alguna_sobre <u>`" % txt}
		var celdas: Array = _celdas_pieza(t[1])
		if celdas.is_empty():
			return {"err": "«%s»: la plantilla no tiene la pieza «%s»" % [txt, t[1]]}
		return {"k": "cuenca", "celdas": celdas, "op": t[2], "v": t[3].to_float(), "txt": txt}
	if t[0] == "alcanzable":
		var id: String = _id_pieza(t[1]) if t.size() > 1 else ""
		if id == "":
			return {"err": "«%s»: la plantilla no tiene esa pieza" % txt}
		return {"k": "alcanzable", "id": id, "txt": txt}
	var idp: String = _id_pieza(t[0])
	if idp == "" or _z.pieza(idp) == null:
		return {"err": "«%s»: la plantilla no tiene la pieza «%s»" % [txt, t[0]]}
	var neg: bool = t.size() > 2 and t[1] == "no"
	var estado: String = t[2] if neg else (t[1] if t.size() > 1 else "")
	var tipo: String = _z.pieza(idp).tipo
	var tabla: Dictionary = (Puzle3D.CONDICIONES.get(tipo, {}) as Dictionary)
	if not tabla.has(estado):
		return {"err": "«%s»: una pieza «%s» no tiene el estado «%s» (tiene: %s)" % [txt, tipo, estado, ", ".join(tabla.keys())]}
	return {"k": "pieza", "id": idp, "estado": estado, "neg": neg, "txt": txt}


# ---------------------------------------------------------------------------------------------------------------------
#  Hacer y mirar
# ---------------------------------------------------------------------------------------------------------------------

func _cumple(c: Dictionary) -> bool:
	match String(c["k"]):
		"cuenca":
			var celdas: Array = c["celdas"]
			var suma: float = 0.0
			var mx: float = 0.0
			for cc in celdas:
				var d: float = _prof(cc as Vector2i)
				suma += d
				mx = maxf(mx, d)
			var v: float = float(c["v"])
			match String(c["op"]):
				"bajo":
					return suma / float(celdas.size()) < v
				"sobre":
					return suma / float(celdas.size()) > v
				"todas_bajo":
					return mx < v
				_:
					return mx > v
		"alcanzable":
			var nodo: Node3D = _z.nodo(String(c["id"])) as Node3D
			if nodo == null:
				return false
			var cel: Vector2i = Terreno3D.celda_de(nodo.global_position)
			var zona: Array = []
			for y in range(cel.y - 8, cel.y + 9):
				for x in range(cel.x - 8, cel.x + 9):
					zona.append(Vector2i(x, y))
			return float(_mas_cerca(nodo.global_position, zona)["d"]) <= Puzle3D.ALCANCE_COFRE
		_:
			return _z.cumple_expr([[{"tipo": "pieza", "id": c["id"], "cond": c["estado"], "neg": c["neg"]}]])


## Las casillas con agua entre dos casillas (sin contarlas).
func _agua_entre(a: Vector2i, b: Vector2i) -> Array:
	var res: Array = []
	var pasos: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for k in range(1, pasos):
		var c: Vector2i = Vector2i(roundi(a.x + (b.x - a.x) * float(k) / pasos), roundi(a.y + (b.y - a.y) * float(k) / pasos))
		if Terreno3D.es_agua(c):
			res.append(c)
	return res


## La casilla pisable más cercana al blanco; con fuego prefiere la que no tiene agua por medio.
func _origen_auto(objetivo: Vector2i, fuego: bool) -> Vector2i:
	var cand: Array = []
	for dy in range(-RADIO_TIRO, RADIO_TIRO + 1):
		for dx in range(-RADIO_TIRO, RADIO_TIRO + 1):
			var c: Vector2i = objetivo + Vector2i(dx, dy)
			if c != objetivo and _pisa(c):
				cand.append(c)
	cand.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a - objetivo).length_squared() < Vector2(b - objetivo).length_squared())
	if cand.is_empty():
		return Vector2i(-1, -1)
	if fuego:
		for c in cand:
			if _agua_entre(c as Vector2i, objetivo).is_empty():
				return c
	return cand[0]


## Un golpe de hechizo real. Devuelve "" si salió o el motivo si no se pudo (error de diseño incluido).
func _golpear(g: Dictionary) -> String:
	var objetivo: Vector2i = g["celda"]
	var elem: String = String(g["elem"])
	var desde: Vector2i = (g["desde"] as Vector2i) if bool(g["fijo"]) else _origen_auto(objetivo, elem == "fuego")
	if desde == Vector2i(-1, -1):
		return "golpe «%s»: no hay ninguna casilla pisable a %d casillas del blanco %s desde la que lanzar" % [g["txt"], RADIO_TIRO, str(objetivo)]
	if not _pisa(desde):
		return "golpe «%s»: la casilla de tiro %s no se pisa (letra «%s», agua %.2f u, origen de la plantilla %s)" % [g["txt"], str(desde), Terreno3D.letra_de(desde), _prof(desde), str(_o)]
	if elem == "fuego":
		var medio: Array = _agua_entre(desde, objetivo)
		if not medio.is_empty():
			return "ERROR DE DISEÑO DE LA PLANTILLA en «%s»: entre la orilla de tiro %s y el blanco %s hay agua (%s) y la flecha de fuego se apaga al cruzar agua" % [g["txt"], str(desde), str(objetivo), str(medio)]
	var glifos: Array = g["glifos"]
	var salio: bool = false
	if glifos.has("barrera"):
		salio = await _lanzar_en_punto(elem, glifos, objetivo, desde)
	else:
		salio = lanzar_a_celda(elem, glifos, objetivo, desde)
	return "" if salio else "golpe «%s»: el hechizo no sale (desde %s al blanco %s)" % [g["txt"], str(desde), str(objetivo)]


# ---------------------------------------------------------------------------------------------------------------------
#  Resumen
# ---------------------------------------------------------------------------------------------------------------------

func _celda_tabla(r: Dictionary) -> String:
	if not bool(r["ok"]):
		return "FALLO" + ((" (%.1f s)" % float(r["t"])) if float(r["t"]) >= 0.0 else "")
	if bool(r["nunca"]):
		return "no resuelve"
	return "%.1f s" % float(r["t"]) if float(r["t"]) >= 0.0 else "ok"


func _tabla() -> void:
	print("")
	print("== RESUMEN: tiempo hasta resolver (desde el último golpe) por plantilla × solución × ancho · «no resuelve» = el golpe equivocado no resuelve, como debe ==")
	var cids: Array = []
	for r in _resultados:
		if not cids.has(r["cid"]):
			cids.append(r["cid"])
	for cid in cids:
		var anchos: Array = []
		var sols: Array = []
		for r in _resultados:
			if r["cid"] == cid:
				if not anchos.has(int(r["ancho"])):
					anchos.append(int(r["ancho"]))
				if not sols.has(r["sol"]):
					sols.append(r["sol"])
		anchos.sort()
		var cab: String = ("%s" % cid).rpad(22) + "solución".rpad(14)
		for a in anchos:
			cab += ("ancho %d" % int(a)).rpad(16)
		print(cab)
		for s in sols:
			var fila: String = "".rpad(22) + String(s).rpad(14)
			for a in anchos:
				var v: String = "-"
				for r in _resultados:
					if r["cid"] == cid and r["sol"] == s and int(r["ancho"]) == int(a):
						v = _celda_tabla(r)
				fila += v.rpad(16)
			print(fila)
	var mal: int = 0
	for r in _resultados:
		if not bool(r["ok"]):
			mal += 1
	print("%d pruebas, %d con FALLO" % [_resultados.size(), mal])
