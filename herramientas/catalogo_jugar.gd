extends "res://herramientas/escenario_base.gd"
## 26/11 · LO COMÚN para JUGAR una plantilla del catálogo del generador (`herramientas/generador_mapas/catalogo/*.txt`) en un mapa generado de verdad.
## Lo heredan `escenario_catalogo_demo.gd` (los escenarios a mano de P1, P3 y P5) y `comprobar_puzles_agua.gd` (el comprobador automático por plantilla × ancho × solución).
## `_caso` genera un mapa con la plantilla puesta en una sala, lo exporta con un nombre temporal, lo carga y deja listos:
##   `_z` (el Puzle3D), `_o` (la casilla del mapa donde cae la esquina (0,0) de la plantilla) y `_tw` (el ancho de la plantilla ya estirada).
## No se ejecuta solo: es una base.

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const Catalogo = preload("res://herramientas/generador_mapas/catalogo_puzles.gd")
const UMBRAL_PISABLE: float = 0.25                     ## con menos agua que esto (u) el cauce se pisa
const MAX_SEMILLAS: int = 40                           ## cuántas semillas se prueban buscando una sala donde quepa la plantilla

## Mira cada fotograma si la jugadora nada: un cruce «andando» que en realidad es a nado no resuelve el puzle.
class VigiaNado extends Node:
	var jugador: Node = null
	var nado_s: float = 0.0
	func _process(delta: float) -> void:
		if jugador != null and is_instance_valid(jugador) and bool(jugador.get("nadando")):
			nado_s += delta

var prefijo: String = "CatDemo"                        ## prefijo del nombre del mapa temporal
var _vigia: VigiaNado = null
var _nombres: Array = []
var _m: Dictionary = {}
var _z: Puzle3D = null
var _o: Vector2i = Vector2i.ZERO                       ## la casilla del mapa donde cae la esquina (0,0) de la plantilla
var _tw: int = 0                                       ## ancho de la plantilla ya estirada
var _th: int = 0                                       ## alto de la plantilla
var _nado_s: float = 0.0                               ## los segundos que se pasó nadando el último `_andar`
var _sala_id: int = -1                                 ## la sala del mapa donde quedó la plantilla
var _error_caso: String = ""                           ## por qué falló el último `_caso` (para el comprobador)


# ---------------------------------------------------------------------------------------------------------------------
#  Armazón: generar, exportar, cargar
# ---------------------------------------------------------------------------------------------------------------------

func _limpiar() -> void:
	for n in _nombres:
		for ruta in [Exportador.ruta_mapa(String(n)), Exportador.ruta_escena(String(n))]:
			if FileAccess.file_exists(ruta):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	_nombres.clear()


## Las palabras de la línea `; pieza <id> …` del mapa generado (vacío si no está).
func _linea(id: String) -> PackedStringArray:
	for l in _m["lineas"]:
		var t: PackedStringArray = String(l).substr(1).strip_edges().split(" ", false)
		if t.size() >= 5 and t[0] == "pieza" and t[1] == id:
			return t
	return PackedStringArray()


## Lo mismo con el id LOCAL de la plantilla (sin el `cat<n>_` que le pone el generador).
func _linea_local(id: String) -> PackedStringArray:
	for l in _m["lineas"]:
		var t: PackedStringArray = String(l).substr(1).strip_edges().split(" ", false)
		if t.size() >= 5 and t[0] == "pieza" and t[1].begins_with("cat") and t[1].find("_") > 0 and t[1].substr(t[1].find("_") + 1) == id:
			return t
	return PackedStringArray()


## Una casilla de la plantilla (coordenadas locales) llevada al mapa.
func _c(x: int, y: int) -> Vector2i:
	return _o + Vector2i(x, y)


## La esquina de la plantilla sin ancla dada: la primera pieza de la plantilla con casilla numérica fija la traslación.
func _origen_generico(e: Dictionary) -> Vector2i:
	for l in (e["lineas"] as Array):
		var t: PackedStringArray = String(l).substr(1).strip_edges().replace("$XC", str(int((_tw - 1) * 0.5))).replace("$X1", str(_tw - 1)).replace("$Y1", str(_th - 1)).split(" ", false)
		if t.size() >= 5 and t[0] == "pieza" and t[3].is_valid_int() and t[4].is_valid_int():
			var mapeada: PackedStringArray = _linea_local(t[1])
			if mapeada.size() >= 5:
				return Vector2i(mapeada[3].to_int() - t[3].to_int(), mapeada[4].to_int() - t[4].to_int())
	return Vector2i(-1, -1)


## Genera un mapa con la plantilla `cid` puesta a mano en la primera sala libre donde cabe (salas, semillas 1…), lo exporta con un nombre temporal, recarga el juego y
## deja listos `_z`, `_o` y `_tw`. `ancla` es la pieza local que fija la esquina de la plantilla y (dx, dy) su casilla local (sin ancla, la fija la primera pieza de la plantilla).
## `ancho` > 0 fuerza el ancho de una plantilla `estira x` (parámetro `ancho_puzle` del generador); `extra` suma parámetros al mapa.
func _caso(cid: String, etiqueta: String, ancla: String, dx: int, dy: int, ancho: int = 0, extra: Dictionary = {}) -> bool:
	Flags.nuevo()
	Estado.nuevo()
	_error_caso = ""
	var nombre: String = prefijo + etiqueta
	_nombres.append(nombre)
	_m = {}
	_sala_id = -1
	for semilla in range(1, MAX_SEMILLAS + 1):
		var par: Dictionary = {"algoritmo": "salas", "semilla": semilla, "enemigos": 0.0, "nombre": nombre}
		if ancho > 0:
			par["ancho_puzle"] = ancho
		par.merge(extra, true)
		var base: Dictionary = Generador.new().generar(par)
		for sala in base["salas"]:
			if String(sala["rol"]) == "inicio":
				continue
			var m: Dictionary = Generador.new().generar(par, {}, {}, {int(sala["id"]): cid})
			if (m["puzles"] as Dictionary).get(int(sala["id"]), "") == cid and (m["errores"] as Array).is_empty():
				_m = m
				_sala_id = int(sala["id"])
				break
		if not _m.is_empty():
			break
	_ok("%s: el generador pone «%s» en una sala%s" % [etiqueta, cid, (" (ancho %d)" % ancho) if ancho > 0 else ""], not _m.is_empty())
	if _m.is_empty():
		_error_caso = "el generador no encuentra sala donde quepa «%s»%s en %d semillas" % [cid, (" a ancho %d" % ancho) if ancho > 0 else "", MAX_SEMILLAS]
		return false
	var e: Dictionary = Catalogo.todos()[cid]
	_th = int(e["alto"])
	_tw = int(e["ancho"])
	if String(e["estira"]) == "x":
		if ancho > 0:
			_tw = ancho
		else:
			for s in _m["salas"]:
				if int(s["id"]) == _sala_id:
					_tw = (s["rect"] as Rect2i).size.x
	if ancla != "":
		var a: PackedStringArray = _linea("cat1_" + ancla)
		_o = Vector2i(a[3].to_int() - dx, a[4].to_int() - dy)
	else:
		_o = _origen_generico(e)
	var res: Dictionary = Exportador.exportar(_m, true)
	_ok("%s: se exporta el mapa temporal %s" % [etiqueta, nombre], bool(res.get("ok", false)), str(res.get("error", "")))
	if not bool(res.get("ok", false)):
		_error_caso = "no se exporta el mapa: " + str(res.get("error", ""))
		return false
	if maqueta != null:
		maqueta.queue_free()
		maqueta = null
		await avanzar(8)
	await cargar(Exportador.ruta_escena(nombre), true)
	if maqueta == null:
		_error_caso = "no carga la escena"
		return false
	await avanzar(20)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("%s: el nivel monta sus piezas sin avisos" % etiqueta, _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "sin Puzle3D")
	if _z == null:
		_error_caso = "el nivel no trae Puzle3D"
	elif not _z.avisos.is_empty():
		_error_caso = "el Puzle3D avisa: " + str(_z.avisos)
	lanzador.tinta = null
	return _z != null


# ---------------------------------------------------------------------------------------------------------------------
#  Medidas
# ---------------------------------------------------------------------------------------------------------------------

func _prof(c: Vector2i) -> float:
	return Terreno3D.agua_sim.profundidad_casilla(c)


## Lo que la jugadora puede pisar: ni agua ni foso con agua (`es_agua`) y suelo alcanzable sin nadar.
func _pisa(c: Vector2i) -> bool:
	return not Terreno3D.es_agua(c) and Terreno3D.pisable(c, 0, true, 1, false)


func _todas(celdas: Array, cond: Callable) -> bool:
	for c in celdas:
		if not bool(cond.call(c)):
			return false
	return true


func _rect(x0: int, y0: int, x1: int, y1: int) -> Array:
	var r: Array = []
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			r.append(_c(x, y))
	return r


## Espera (tiempo de simulación) a que se cumpla `cond`; devuelve los segundos que tardó o -1 si no llegó en `max_s`.
func _hasta(cond: Callable, max_s: float) -> float:
	var t: float = 0.0
	while not bool(cond.call()):
		if t >= max_s:
			return -1.0
		t += await avanzar_s(0.1)
	return t


func _dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Distancia (u) de `p` a la casilla pisable más cercana de `zona`.
func _mas_cerca(p: Vector3, zona: Array) -> Dictionary:
	var mejor: float = INF
	var donde: Vector2i = Vector2i(-1, -1)
	for c in zona:
		if _pisa(c as Vector2i):
			var d: float = _dist(Terreno3D.centro_de(c as Vector2i, 0.0), p)
			if d < mejor:
				mejor = d
				donde = c
	return {"d": mejor, "c": donde}


## E de verdad: la tecla `interactuar` (CofrePuzle comprueba el alcance de 2,7 u). Espera a que acabe de abrirse.
func _pulsar_e_cofre(cofre: Variant, max_s: float = 6.0) -> bool:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s and not bool(cofre.get("es_abierto")):
		_tecla(KEY_E, true)
		await avanzar(2)
		_tecla(KEY_E, false)
		await avanzar_s(0.3)
	return bool(cofre.get("es_abierto"))


## Anda de verdad (WASD) a `c` y dice si llegó. Los segundos que se pasó nadando quedan en `_nado_s`.
func _andar(c: Vector2i, max_s: float = 15.0) -> bool:
	if _vigia == null or not is_instance_valid(_vigia):
		_vigia = VigiaNado.new()
		root.add_child(_vigia)
	_vigia.jugador = jugador
	_vigia.nado_s = 0.0
	var llego: bool = await mover_hacia(c, max_s, 0.1)
	_nado_s = _vigia.nado_s
	return llego


## Diagnóstico: letra, agua, profundidad y si se pisa, de cada casilla.
func _diag(etiqueta: String, celdas: Array) -> void:
	var t: PackedStringArray = PackedStringArray()
	for c in celdas:
		var cc: Vector2i = c
		t.append("%s:%s%s %.2f%s" % [str(cc), Terreno3D.letra_de(cc), " agua" if Terreno3D.es_agua(cc) else "", _prof(cc), " PISA" if _pisa(cc) else ""])
	print("      [diag %s] %s" % [etiqueta, " | ".join(t)])


func _max(celdas: Array) -> float:
	var m: float = 0.0
	for c in celdas:
		m = maxf(m, _prof(c as Vector2i))
	return m


## Como `_lanzar` de la Cueva Resonante: lo que nace donde se apunta (la barrera de tierra) sale en el punto del suelo, dentro del anillo de 3 casillas de la jugadora.
func _lanzar_en_punto(elemento: String, glifos: Array, objetivo: Vector2i, desde: Vector2i) -> bool:
	colocar_jugador(desde)
	await avanzar_s(0.3)
	var yo: Vector3 = jugador.position
	var meta: Vector3 = Terreno3D.centro_de(objetivo, 0.0)
	var hacia: Vector3 = Vector3(meta.x - yo.x, 0.0, meta.z - yo.z)
	var tope: float = Lanzador3D.ALCANCE_ORIGEN * Terreno3D.casilla
	var origen: Vector3 = yo + (hacia if hacia.length() <= tope else hacia.normalized() * tope)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	return lanzador.lanzar_pagina_ya(0, origen, hacia.normalized())
