extends SceneTree
## Prueba de la variante EXPERIMENTAL «muro por geometría» (27/11/2026), sin ventana.
##   godot --headless --path . --script res://herramientas/prueba_muro_geometria.gd
## Con `Hechizo.MURO_POR_GEOMETRIA` apagado (el de serie) el juego es el de siempre. Encendido, una raya vertical (`linea_z`) sin `barrera` ni flecha hace un MURO (`muro_geo`) con la duración base de
## una barrera; el elemento decide la protección: el agua (líquido) bloquea (solidez 1,5), el fuego (plasma) solo quema lo que lo cruza (solidez 0). La tierra y el hielo (sólidos) no se tocan.

var fallos: int = 0
var comparaciones: int = 0
var _runes: Dictionary = {}


func _ok(cond: bool, msg: String) -> void:
	comparaciones += 1
	if not cond:
		fallos += 1
		if fallos <= 60:
			print("FALLO: ", msg)


func _casi(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _h(elemento: String, glifos: Dictionary) -> Hechizo:
	return Hechizo.construir(_runes[elemento] as RuneData, glifos)


## Lo que la prueba compara entre «apagado» y «encendido» cuando se espera que NO cambie nada.
func _foto(h: Hechizo) -> Array:
	return [h.muro_geo, h.es_muro, h.haz, h.solidez, h.permanencia, h.semieje_x, h.semieje_y, h.semieje_z, h.en_punto, h.viaja, h.figura(), h.forma, h.niveles, h.persiste, h.coste, h.geo()["muro"]]


func _initialize() -> void:
	await process_frame
	for e in ["fire", "water", "earth", "ice", "wind"]:
		_runes[e] = load("res://nucleo/%s_rune.tres" % e)
	Hechizo.MURO_POR_GEOMETRIA = false
	_apagado()
	_encendido()
	_no_aplica()
	_posicion()
	_idempotencia()
	_geometria_y_dibujo()
	_equivalencia_con_barrera()
	_sin_dano_propio()
	Hechizo.MURO_POR_GEOMETRIA = false
	print("%d comprobaciones · FALLOS: %d" % [comparaciones, fallos])
	quit(1 if fallos > 0 else 0)


func _apagado() -> void:
	_ok(not Hechizo.MURO_POR_GEOMETRIA, "el interruptor viene apagado de serie")
	var f: Hechizo = _h("fire", {"linea_z": 1})
	_ok(f.haz, "apagado: fuego + ᛁz es un haz")
	_ok(not f.muro_geo, "apagado: fuego + ᛁz no es muro_geo")
	_ok(not f.es_muro, "apagado: fuego + ᛁz no es muro")
	_ok(f.solidez <= 0.0 and f.permanencia <= 0.0, "apagado: fuego + ᛁz sin solidez ni permanencia")
	_ok(f.figura() == "haz", "apagado: figura «haz»")
	var a: Hechizo = _h("water", {"linea_z": 1})
	_ok(a.haz and not a.muro_geo and a.solidez <= 0.0, "apagado: agua + ᛁz es un haz")
	var x: Hechizo = _h("fire", {"linea_x": 1})
	_ok(x.haz and not x.muro_geo and not x.es_muro, "apagado: fuego + ᛁx es un haz")
	var b: Hechizo = _h("fire", {"barrera": 1, "linea_z": 2, "altura": 3})
	_ok(b.es_muro and not b.muro_geo and not b.haz and b.solidez > 0.0, "apagado: barrera + ᛁz sigue siendo muro por solidez")


func _encendido() -> void:
	Hechizo.MURO_POR_GEOMETRIA = true
	var f: Hechizo = _h("fire", {"linea_z": 1})
	_ok(f.muro_geo, "fuego + ᛁz: muro_geo")
	_ok(f.es_muro, "fuego + ᛁz: es_muro")
	_ok(not f.haz, "fuego + ᛁz: ya no es haz")
	_ok(f.solidez == 0.0, "fuego + ᛁz: solidez 0 (no bloquea, solo quema) · %s" % f.solidez)
	_ok(f.permanencia >= Sigils.BARRERA_DURA_BASE_S - 0.0001, "fuego + ᛁz: permanencia ≥ %s · %s" % [Sigils.BARRERA_DURA_BASE_S, f.permanencia])
	_ok(f.semieje_y >= Sigils.MURO_ALTO_MIN_V2 - 0.0001, "fuego + ᛁz: alto mínimo de muro · %s" % f.semieje_y)
	_ok(f.semieje_x >= Sigils.MURO_ANCHO_MIN_V2 - 0.0001, "fuego + ᛁz: ancho mínimo de muro · %s" % f.semieje_x)
	_ok(not f.en_punto, "fuego + ᛁz: no nace donde apuntas")
	_ok(f.figura() == "barrera", "fuego + ᛁz: figura «barrera» · %s" % f.figura())
	_ok(not f.viaja, "fuego + ᛁz: no viaja")
	_ok(bool(f.geo()["muro"]) and bool(f.geo()["muro_geo"]) and not bool(f.geo()["haz"]), "fuego + ᛁz: geo() dice muro y no haz")
	_ok(f.alcance_haz == 0.0, "fuego + ᛁz: alcance de haz 0")
	_ok(String(f.origen.get("permanencia", "")) != "", "fuego + ᛁz: la permanencia lleva origen")
	var a: Hechizo = _h("water", {"linea_z": 1})
	_ok(a.muro_geo and a.es_muro and not a.haz, "agua + ᛁz: muro_geo, muro, no haz")
	_ok(a.solidez > 0.0, "agua + ᛁz: solidez > 0 (bloquea) · %s" % a.solidez)
	_ok(_casi(a.solidez, 1.5), "agua + ᛁz: solidez 1,5 · %s" % a.solidez)
	_ok(a.permanencia >= Sigils.BARRERA_DURA_BASE_S - 0.0001, "agua + ᛁz: permanencia ≥ 6")
	_ok(a.semieje_y >= Sigils.MURO_ALTO_MIN_V2 - 0.0001 and not a.en_punto, "agua + ᛁz: alto mínimo y delante")
	_ok(a.figura() == "barrera", "agua + ᛁz: figura «barrera»")
	_ok(a.geo()["props"].has("solidez"), "agua + ᛁz: la solidez va en las propiedades (la materializa HechizoVivo)")
	# viento y rayo: no son sólidos; comportamiento por estado (gas / plasma), sin solidez
	var v: Hechizo = _h("wind", {"linea_z": 1})
	_ok(v.muro_geo == (v.estado_materia != "solido"), "viento + ᛁz: sigue la regla del estado (%s)" % v.estado_materia)
	_ok(v.solidez <= 0.0, "viento + ᛁz: sin solidez")
	# un muro más grande: más glifos de altura y anchura mandan sobre los mínimos
	var g: Hechizo = _h("fire", {"linea_z": 2, "altura": 3})
	_ok(g.muro_geo and g.es_muro and g.semieje_y >= f.semieje_y and g.semieje_x > f.semieje_x, "fuego + 2 ᛁz + 3 ᛏ: crece sobre los mínimos · x %s y %s (mínimos %s %s)" % [g.semieje_x, g.semieje_y, f.semieje_x, f.semieje_y])
	Hechizo.MURO_POR_GEOMETRIA = false


func _no_aplica() -> void:
	Hechizo.MURO_POR_GEOMETRIA = true
	var z: Hechizo = _h("fire", {"linea_x": 1})
	_ok(not z.muro_geo and z.haz and not z.es_muro, "fuego + ᛁx sigue siendo haz")
	_ok(z.figura() == "haz", "fuego + ᛁx: figura «haz»")
	var mixto: Hechizo = _h("fire", {"linea_z": 1, "linea_x": 2})
	_ok(not mixto.muro_geo and mixto.haz, "fuego + ᛁz + 2 ᛁx (más verticales): sigue siendo haz")
	var fl: Hechizo = _h("fire", {"linea_z": 1, "flecha": 1})
	_ok(not fl.muro_geo and fl.viaja, "fuego + ᛁz + flecha: no es muro_geo")
	var sin_nada: Hechizo = _h("fire", {})
	_ok(not sin_nada.muro_geo, "fuego sin glifos: no es muro_geo")
	var alta: Hechizo = _h("fire", {"altura": 2})
	_ok(not alta.muro_geo, "fuego + ᛏᛏ sin raya: no es muro_geo")
	var casos: Array = [["earth", {"linea_z": 1}], ["earth", {"linea_z": 2, "altura": 2}], ["ice", {"linea_z": 1}], ["fire", {"barrera": 1, "linea_z": 1}], ["water", {"barrera": 1, "linea_z": 2, "altura": 3}],
		["fire", {"barrera": 1, "linea_z": 2, "altura": 3}], ["fire", {"linea_x": 2}], ["fire", {"linea_z": 1, "flecha": 1}]]
	var encendido: Array = []
	for c in casos:
		encendido.append(_foto(_h(String(c[0]), c[1] as Dictionary)))
	Hechizo.MURO_POR_GEOMETRIA = false
	for i in casos.size():
		var apagado: Array = _foto(_h(String((casos[i] as Array)[0]), (casos[i] as Array)[1] as Dictionary))
		_ok(apagado == encendido[i], "idéntico con el interruptor apagado y encendido: %s" % str(casos[i]))
	Hechizo.MURO_POR_GEOMETRIA = true
	_ok(not _h("earth", {"linea_z": 1}).muro_geo, "tierra + ᛁz: no es muro_geo")
	_ok(not _h("ice", {"linea_z": 1}).muro_geo, "hielo + ᛁz: no es muro_geo")
	_ok(not _h("fire", {"barrera": 1, "linea_z": 1}).muro_geo, "fuego + barrera + ᛁz: no es muro_geo (manda la barrera)")
	Hechizo.MURO_POR_GEOMETRIA = false


func _posicion() -> void:
	Hechizo.MURO_POR_GEOMETRIA = true
	var f: Hechizo = _h("fire", {"linea_z": 1, "posicion": 1})
	_ok(f.en_punto, "fuego + ᛁz + posición: en_punto")
	_ok(f.muro_geo, "fuego + ᛁz + posición: sigue siendo muro_geo")
	_ok(not f.haz, "fuego + ᛁz + posición: no es haz")
	_ok(f.permanencia >= Sigils.BARRERA_DURA_BASE_S - 0.0001, "fuego + ᛁz + posición: duración base")
	_ok(f.figura() == "barrera", "fuego + ᛁz + posición: figura «barrera»")
	var a: Hechizo = _h("water", {"linea_z": 1, "posicion": 1})
	_ok(a.en_punto and a.muro_geo and a.solidez > 0.0, "agua + ᛁz + posición: en_punto, muro_geo y solidez")
	Hechizo.MURO_POR_GEOMETRIA = false


func _idempotencia() -> void:
	Hechizo.MURO_POR_GEOMETRIA = true
	for e in ["fire", "water"]:
		var h: Hechizo = _h(e, {"linea_z": 1})
		var perm: float = h.permanencia
		var sol: float = h.solidez
		h.con({})
		_ok(_casi(h.permanencia, perm), "%s: con({}) no duplica la duración base · %s -> %s" % [e, perm, h.permanencia])
		h.con({"copias": 1}).con({"copias": 1})
		_ok(_casi(h.permanencia, perm), "%s: con() repetido no duplica la duración base · %s" % [e, h.permanencia])
		_ok(_casi(h.solidez, sol), "%s: con() no cambia la solidez" % e)
		var c: Hechizo = h.copiar()
		_ok(_casi(c.permanencia, perm) and _casi(c.solidez, sol), "%s: copiar() conserva duración y solidez" % e)
		c.con({"copias": 1})
		_ok(_casi(c.permanencia, perm), "%s: copiar().con() no duplica la duración base · %s" % [e, c.permanencia])
		_ok(c.muro_geo == h.muro_geo and c.es_muro == h.es_muro, "%s: copiar() conserva muro_geo" % e)
	# un ᛉ de más suma sus 2 s encima de la base, una sola vez
	var p: Hechizo = _h("fire", {"linea_z": 1, "permanencia": 1})
	_ok(_casi(p.permanencia, Sigils.BARRERA_DURA_BASE_S + 2.0), "fuego + ᛁz + ᛉ: base + 2 s · %s" % p.permanencia)
	p.con({})
	_ok(_casi(p.permanencia, Sigils.BARRERA_DURA_BASE_S + 2.0), "fuego + ᛁz + ᛉ: con({}) no la repite · %s" % p.permanencia)
	Hechizo.MURO_POR_GEOMETRIA = false


## El dibujo (`FuegoToy.describir`, el que usan todos los elementos) y la geometría (`GeometriaV2`): un muro de fuego o de agua se dibuja como MURO y ocupa casillas DELANTE de la mano.
func _geometria_y_dibujo() -> void:
	Hechizo.MURO_POR_GEOMETRIA = true
	for e in ["fire", "water"]:
		var h: Hechizo = _h(e, {"linea_z": 2, "altura": 2})
		var d: Dictionary = FuegoToy.describir(h)
		_ok(int(d["figura"]) == int(FuegoToy.Figura.MURO), "%s + 2 ᛁz: se dibuja como MURO (figura %s)" % [e, d["figura"]])
		var g: Dictionary = h.geo()
		_ok(Lanzador3D.GeometriaV2.es_muro(g), "%s: GeometriaV2.es_muro" % e)
		_ok(Lanzador3D.GeometriaV2.adelanto(g) >= Lanzador3D.GeometriaV2.DISTANCIA_MURO - 0.0001, "%s: el centro se adelanta ≥ DISTANCIA_MURO · %s" % [e, Lanzador3D.GeometriaV2.adelanto(g)])
		var celdas: Array = Lanzador3D.GeometriaV2.celdas(g, Vector2(5.5, 5.5), Vector2.RIGHT, 1.0)
		_ok(not celdas.has(Vector2i(5, 5)) and celdas.has(Vector2i(6, 5)), "%s: el muro no ocupa la casilla de quien lanza" % e)
		_ok(celdas.size() >= 1, "%s: el muro ocupa casillas" % e)
	Hechizo.MURO_POR_GEOMETRIA = false
	var apagado: Dictionary = FuegoToy.describir(_h("fire", {"linea_z": 2, "altura": 2}))
	_ok(int(apagado["figura"]) == int(FuegoToy.Figura.HAZ), "apagado: fuego + 2 ᛁz se dibuja como HAZ")


## Ronda 2: las ᛁ verticales (`linea_z`) dan el ANCHO del muro: con el interruptor encendido, N `linea_z` sale con las medidas, la forma, el cast point, el coste y las casillas que daban N `linea_x` con barrera
## (interruptor apagado), salvo la solidez. `con()` y `copiar()` no vuelven a intercambiar los ejes.
func _equivalencia_con_barrera() -> void:
	var recetas: Array = [[{"linea_z": 2, "altura": 3}, {"barrera": 1, "linea_x": 2, "altura": 3}], [{"linea_z": 1}, {"barrera": 1, "linea_x": 1}],
		[{"linea_z": 2, "linea_x": 1, "altura": 2}, {"barrera": 1, "linea_x": 2, "linea_z": 1, "altura": 2}], [{"linea_z": 3, "altura": 1}, {"barrera": 1, "linea_x": 3, "altura": 1}]]
	for r in recetas:
		for e in ["fire", "water", "wind"]:
			var nuevo_g: Dictionary = (r as Array)[0]
			var viejo_g: Dictionary = (r as Array)[1]
			Hechizo.MURO_POR_GEOMETRIA = true
			var n: Hechizo = _h(e, nuevo_g)
			var cel_n: Array = Lanzador3D.GeometriaV2.celdas(n.geo(), Vector2(5.5, 5.5), Vector2.RIGHT, 1.0)
			var d_n: Dictionary = FuegoToy.describir(n)
			var n_muro: bool = n.es_muro
			var n_figura: String = n.figura()
			var n_geo: bool = n.muro_geo
			Hechizo.MURO_POR_GEOMETRIA = false
			var v: Hechizo = _h(e, viejo_g)
			var cel_v: Array = Lanzador3D.GeometriaV2.celdas(v.geo(), Vector2(5.5, 5.5), Vector2.RIGHT, 1.0)
			var d_v: Dictionary = FuegoToy.describir(v)
			var et: String = "%s %s vs %s" % [e, str(nuevo_g), str(viejo_g)]
			_ok(n_geo and not v.muro_geo, "%s: uno es muro_geo y el otro lleva barrera" % et)
			_ok(_casi(n.semieje_x, v.semieje_x) and _casi(n.semieje_y, v.semieje_y) and _casi(n.semieje_z, v.semieje_z), "%s: mismos semiejes (%s %s %s / %s %s %s)" % [et, n.semieje_x, n.semieje_y, n.semieje_z, v.semieje_x, v.semieje_y, v.semieje_z])
			_ok(_casi(n._glifos_x, v._glifos_x) and _casi(n._glifos_z, v._glifos_z), "%s: mismos _glifos_x/z (coste)" % et)
			_ok(n.niveles == v.niveles, "%s: mismos niveles" % et)
			_ok(n.forma == v.forma and n.cast_point == v.cast_point, "%s: misma forma y cast point (%s %s / %s %s)" % [et, n.forma, n.cast_point, v.forma, v.cast_point])
			# el tamaño relativo (`coste`) es el mismo salvo el recargo por la propiedad «solidez» que solo cuenta la barrera dibujada
			var props_n: int = n.propiedades_usadas().size()
			var props_v: int = v.propiedades_usadas().size()
			_ok(_casi(n.coste / (1.0 + Sigils.COSTE_PROP_V2 * float(props_n)), v.coste / (1.0 + Sigils.COSTE_PROP_V2 * float(props_v))), "%s: mismo volumen de coste (%s con %d props / %s con %d props)" % [et, n.coste, props_n, v.coste, props_v])
			_ok(cel_n == cel_v and not cel_n.is_empty(), "%s: mismas casillas %s / %s" % [et, str(cel_n), str(cel_v)])
			_ok(_casi(n.permanencia, v.permanencia), "%s: misma duración (%s / %s)" % [et, n.permanencia, v.permanencia])
			_ok(n_muro == v.es_muro and n_figura == v.figura(), "%s: mismo muro y misma figura" % et)
			_ok(int(d_n["figura"]) == int(d_v["figura"]) and _casi(float(d_n["x"]), float(d_v["x"])) and _casi(float(d_n["z"]), float(d_v["z"])) and _casi(float(d_n["y"]), float(d_v["y"])), "%s: mismo dibujo" % et)
	# `con()` y `copiar()` no vuelven a intercambiar
	Hechizo.MURO_POR_GEOMETRIA = true
	var h: Hechizo = _h("fire", {"linea_z": 2, "linea_x": 1, "altura": 3})
	var sx: float = h.semieje_x
	var sz: float = h.semieje_z
	h.con({}).con({"copias": 1})
	_ok(_casi(h.semieje_x, sx) and _casi(h.semieje_z, sz), "con() no vuelve a intercambiar los ejes (%s %s -> %s %s)" % [sx, sz, h.semieje_x, h.semieje_z])
	var c: Hechizo = h.copiar()
	_ok(_casi(c.semieje_x, sx) and _casi(c.semieje_z, sz) and _casi(c._glifos_x, h._glifos_x), "copiar() conserva los ejes")
	c.con({})
	_ok(_casi(c.semieje_x, sx) and _casi(c.semieje_z, sz) and _casi(c._glifos_x, h._glifos_x), "copiar().con() no intercambia")
	Hechizo.MURO_POR_GEOMETRIA = false


## Una jugadora de mentira: solo cuenta lo que le quita `dano_ambiental`.
class JugadoraFalsa extends Node3D:
	var quitado: float = 0.0

	func dano_ambiental(cantidad: float, _elemento: String = "") -> float:
		quitado += cantidad
		return cantidad


## Ronda 2: la zona de un muro `muro_geo` (fuego) no hiere a quien lo lanzó; la de siempre sí. Se pulsa la zona a mano (`HechizoVivo.pulso_plasma`) con un lanzador y una jugadora de mentira.
## OJO: que `_abrir_zona` pone `sin_dano_propio = h.muro_geo` no se ejercita aquí (haría falta la sala entera): se comprueba el flag en la zona y el muro_geo del hechizo por separado.
func _sin_dano_propio() -> void:
	var lanz := Lanzador3D.new()
	var j := JugadoraFalsa.new()
	var mundo := Node3D.new()
	root.add_child(mundo)
	mundo.add_child(lanz)
	mundo.add_child(j)
	lanz.jugador = j
	lanz.mundo = mundo
	j.position = Vector3(5.5, 0.0, 5.5)
	var celdas: Dictionary = {Lanzador3D.celda_de(j.global_position): true}
	for caso in [[false, true], [true, false]]:
		var z := Lanzador3D.ZonaV2.new()
		z.lanz = lanz
		z.elemento = "fuego"
		z.celdas = celdas
		z.dano_periodico = 5.0
		z.intervalo = 0.25
		z.edad = 2.0                                  # pasada la gracia
		z.sin_dano_propio = bool((caso as Array)[0])
		j.quitado = 0.0
		HechizoVivo.pulso_plasma(lanz, z)
		_ok((j.quitado > 0.0) == bool((caso as Array)[1]), "zona con sin_dano_propio=%s: la jugadora pierde %s (¿debía perder? %s)" % [str((caso as Array)[0]), j.quitado, str((caso as Array)[1])])
		z.free()
	Hechizo.MURO_POR_GEOMETRIA = true
	_ok(_h("fire", {"linea_z": 1}).muro_geo and not _h("fire", {"barrera": 1, "linea_z": 1}).muro_geo, "el flag sale de muro_geo: el muro de la variante sí, el de barrera no")
	Hechizo.MURO_POR_GEOMETRIA = false
	j.queue_free()
	lanz.queue_free()
