extends SceneTree
## PRUEBA (21/10, decisión de Pablo tras el playtest): el proyectil de «flecha + elemento» mide `Hechizo.ESCALA_PROYECTIL` (0,5) de lo que medía. MEDIDO, no supuesto:
##   1. El Hechizo: `escala_vuelo` = ESCALA_PROYECTIL solo con `velocidad` > 0 (flecha, con o sin glifos de eje); los semiejes (coste, forma, rasterizado) NO cambian.
##   2. COLISIÓN: `HechizoVivo._radio_u` del proyectil = la mitad de lo de antes (para fuego, agua, tierra, rayo, hielo y viento) y un reactivo a una distancia que
##      antes acertaba (entre el radio nuevo y el viejo) ahora se esquiva, mientras que uno más cerca sigue recibiendo el golpe.
##   3. VISUAL: lo que se dibuja en vuelo (VfxElemento3D: la caja de las mallas del seguidor; VfxEstado3D: `semi`) mide la mitad de lo medido ANTES del cambio
##      (con ESCALA_PROYECTIL = 1.0) para los seis elementos; y el impacto (`Proyectil.esc`) NO se encoge.
##   4. NO CAMBIA: barrera, muro, columna, esfera quieta, corro y la explosión: sus semiejes y su `escala_vuelo` (1) son los de antes, y rasterizan las mismas casillas.
##   godot --headless --fixed-fps 60 --path . --script res://herramientas/prueba_tamano_proyectil.gd
## Los números «ANTES» se midieron con ESCALA_PROYECTIL = 1.0 (el código de antes del cambio); si Pablo ajusta el factor, la prueba espera `ANTES × ESCALA_PROYECTIL`.

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass

class ReactivoFalso extends Node3D:
	var golpes: int = 0
	func on_spell_hit(_rune: RuneData, _dir: Vector3 = Vector3.ZERO) -> void:
		golpes += 1

const DT: float = 1.0 / 60.0
const LADO: int = 20
const SALIDA: Vector2i = Vector2i(5, 8)
const ELEMENTOS: Array = ["fire", "water", "earth", "lightning", "ice", "wind"]
## Medido ANTES del cambio (ESCALA_PROYECTIL = 1.0, glifo flecha sin más): dimensión mayor de la caja de las mallas del dibujo del proyectil (u) en VfxElemento3D.
const ANTES_CAJA: Dictionary = {"fire": 4.39875, "water": 2.01079, "earth": 1.24853, "lightning": 4.18745, "ice": 4.18745, "wind": 3.04805}

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _vfx: VfxElemento3D = null
var _estado: VfxEstado3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	print("--- ESCALA_PROYECTIL = %.2f · casilla = %.2f u" % [Hechizo.ESCALA_PROYECTIL, Terreno3D.casilla])
	_hechizo()
	_colision()
	await _visual()
	_sin_cambios()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	var filas: PackedStringArray = []
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			f += "#" if (x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1) else "."
		filas.append(f)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_l = Lanzador3D.new()
	_l.mundo = _m
	root.add_child(_l)
	_vfx = VfxElemento3D.conectar(_l, _m)
	_estado = VfxEstado3D.conectar(_l, _m)
	_estado.encendido = true


func _rune(el: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % el) as RuneData


func _flecha(el: String, extra: Dictionary = {}) -> Hechizo:
	var glifos: Dictionary = {"flecha": 1}
	glifos.merge(extra)
	return Hechizo.construir(_rune(el), glifos)


func _origen(c: Vector2i = SALIDA) -> Vector3:
	return Lanzador3D.centro_de(c, Terreno3D.y_pies(c) + 0.8)


func _lanzar(h: Hechizo, c: Vector2i = SALIDA) -> HechizoVivo:
	return HechizoVivo.crear(h, _origen(c), Vector3.RIGHT, _l, null, {}, true)


# ---------------------------------------------------------------------------------------------------------------------
func _hechizo() -> void:
	print("--- 1. el Hechizo: la escala solo toca al que viaja como proyectil")
	var cas: float = Terreno3D.casilla
	for el in ELEMENTOS:
		var h: Hechizo = _flecha(el)
		_ok("%s + flecha: velocidad %.2f m/s > 0 → escala_vuelo %.2f" % [el, h.velocidad, h.escala_vuelo], h.velocidad > 0.0 and absf(h.escala_vuelo - Hechizo.ESCALA_PROYECTIL) < 1e-6)
		_ok("%s + flecha: los semiejes siguen en RADIO_BASE_V2 (%.3f) y los de vuelo son ×%.2f" % [el, h.semieje_x, Hechizo.ESCALA_PROYECTIL],
			absf(h.semieje_x - Sigils.RADIO_BASE_V2) < 1e-9 and absf(h.semiejes_vuelo.x - Sigils.RADIO_BASE_V2 * Hechizo.ESCALA_PROYECTIL) < 1e-9)
	var largo: Hechizo = _flecha("fire", {"linea_x": 1, "linea_z": 1})
	_ok("flecha + línea X + línea Z: también se escala (x %.2f → %.2f, z %.2f → %.2f), los semiejes de los glifos no cambian" % [largo.semieje_x, largo.semiejes_vuelo.x, largo.semieje_z, largo.semiejes_vuelo.z],
		largo.semieje_x > Sigils.RADIO_BASE_V2 and absf(largo.semiejes_vuelo.x - largo.semieje_x * Hechizo.ESCALA_PROYECTIL) < 1e-5 and absf(largo.semiejes_vuelo.z - largo.semieje_z * Hechizo.ESCALA_PROYECTIL) < 1e-5)
	var quieto: Hechizo = Hechizo.construir(_rune("fire"), {})
	_ok("esfera sin flecha (quieta): escala_vuelo 1 y semiejes_vuelo = semiejes", quieto.velocidad == 0.0 and quieto.escala_vuelo == 1.0 and quieto.semiejes_vuelo == quieto.semiejes)
	_ok("la forma de la flecha sigue siendo «%s» y su coste %.3f sale de los glifos (no de la escala)" % [_flecha("fire").forma, _flecha("fire").coste], _flecha("fire").forma == "x_mano" and absf(_flecha("fire").coste - 1.0 * (1.0 + Sigils.COSTE_PROP_V2)) < 1e-6)
	_ok("sin cambiar RADIO_BASE_V2: sigue en 0,25 m-casilla (≈ %.2f u de radio sin escalar, %.2f u escalado)" % [Sigils.RADIO_BASE_V2 * cas, Sigils.RADIO_BASE_V2 * cas * Hechizo.ESCALA_PROYECTIL], absf(Sigils.RADIO_BASE_V2 - 0.25) < 1e-9)


# ---------------------------------------------------------------------------------------------------------------------
func _colision() -> void:
	print("--- 2. colisión: radio de acierto del proyectil")
	var cas: float = Terreno3D.casilla
	for el in ELEMENTOS:
		var v: HechizoVivo = _lanzar(_flecha(el))
		var antes: float = Sigils.RADIO_BASE_V2 * cas
		_ok("%s: _radio_u %.3f u (antes %.3f): mide ×%.2f" % [el, v._radio_u, antes, v._radio_u / antes], v.proyectil and absf(v._radio_u - antes * Hechizo.ESCALA_PROYECTIL) < 1e-6)
		v.queue_free()
	# un reactivo a una distancia lateral entre el radio nuevo y el viejo: antes acertaba, ahora no; uno más cerca sigue acertando
	var viejo: float = Sigils.RADIO_BASE_V2 * cas + HechizoVivo.RADIO_ENEMIGO_U
	var nuevo: float = Sigils.RADIO_BASE_V2 * cas * Hechizo.ESCALA_PROYECTIL + HechizoVivo.RADIO_ENEMIGO_U
	var lateral_medio: float = (viejo + nuevo) * 0.5
	var pares: Array = [["justo dentro del alcance nuevo", nuevo * 0.8, true]]
	if Hechizo.ESCALA_PROYECTIL < 0.999:             # con factor 1 no hay «entre» (los dos alcances coinciden)
		pares.append(["entre el alcance nuevo y el viejo", lateral_medio, false])
	for par in pares:
		var re := ReactivoFalso.new()
		re.add_to_group("reactivo3d")
		_m.add_child(re)
		var o: Vector3 = _origen()
		var h: Hechizo = _flecha("fire")
		var v: HechizoVivo = _lanzar(h)
		re.global_position = Vector3(o.x + 1.5 * cas, v.p.y - HechizoVivo.CENTRO_ENEMIGO_U, o.z + float(par[1]))
		var pasos: int = 0
		# Se avanza SOLO hasta pasar al reactivo: al final de su alcance el fuego deja su campo de llamas y su explosión (áreas que NO se encogen) y alcanzarían al reactivo igual.
		while v.activo and pasos < 1500 and v.p.x < re.global_position.x + 1.0:
			v.paso(DT)
			pasos += 1
		_ok("reactivo %s (a %.2f u del camino; alcance nuevo %.2f, viejo %.2f): %s" % [par[0], float(par[1]), nuevo, viejo, "recibe el golpe" if re.golpes > 0 else "se esquiva"], (re.golpes > 0) == bool(par[2]))
		re.free()            # free y no queue_free: el siguiente caso no debe ver a este reactivo (la explosión del fuego, que NO se encoge, lo alcanzaría)
		v.free()


# ---------------------------------------------------------------------------------------------------------------------
## Dimensión mayor de la caja (en el espacio del seguidor) de todas las mallas del dibujo.
func _caja(raiz: Node3D) -> float:
	var inv: Transform3D = raiz.global_transform.affine_inverse()
	var caja := AABB()
	var primero: bool = true
	for n in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var a: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
		caja = a if primero else caja.merge(a)
		primero = false
	var s: Vector3 = caja.size
	return maxf(s.x, maxf(s.y, s.z))


func _visual() -> void:
	print("--- 3. visual: lo que se dibuja en vuelo")
	var cas: float = Terreno3D.casilla
	var medidas: Dictionary = {}
	for el in ELEMENTOS:
		var v: HechizoVivo = _lanzar(_flecha(el))
		await process_frame
		await process_frame
		var seg: VfxElemento3D.Proyectil = v.get_node_or_null("VfxElementoProyectil") as VfxElemento3D.Proyectil
		_ok("%s: el proyectil tiene su seguidor de VfxElemento3D" % el, seg != null)
		if seg != null:
			seg._process(VfxElemento3D.PROYECTIL_CRECE_S + 0.1)         # ya creció del todo
			var caja: float = _caja(seg)
			medidas[el] = caja
			var antes: float = float(ANTES_CAJA[el])
			print("     %s: caja del dibujo %.3f u (antes %.3f)" % [el, caja, antes])
			if antes > 0.0:
				_ok("%s: el dibujo mide ×%.3f de lo de antes (esperado ×%.2f)" % [el, caja / antes, Hechizo.ESCALA_PROYECTIL], absf(caja - antes * Hechizo.ESCALA_PROYECTIL) < (0.2 if el in ["earth", "wind"] else 0.03) * antes + 0.005)         # tierra (terrones al azar) y viento (anillos que se animan) cambian ±10-15 % de caja según el fotograma; el resto es exacto
			var esc_antes: float = clampf(Sigils.RADIO_BASE_V2 * cas / 0.45, VfxElemento3D.ESCALA_VOL_MIN, VfxElemento3D.ESCALA_VOL_MAX)
			_ok("%s: el impacto (Proyectil.esc = %.3f) no se encoge (era %.3f)" % [el, seg.esc, esc_antes], absf(seg.esc - esc_antes) < 1e-6)
		# VfxEstado3D (el otro dibujo del proyectil): `semi` es el semieje en u
		var ef: Node = null
		for c in v.get_children():
			if c is VfxEstado3D.EfectoHechizo:
				ef = c
		if ef != null:
			var semi: Vector3 = (ef as VfxEstado3D.EfectoHechizo).semi
			var piso: float = 0.1 * cas
			var esperado: float = maxf(Sigils.RADIO_BASE_V2 * Hechizo.ESCALA_PROYECTIL, 0.1) * cas
			_ok("%s: VfxEstado3D dibuja con semieje %.3f u (antes %.3f; piso %.2f)" % [el, semi.x, Sigils.RADIO_BASE_V2 * cas, piso], absf(semi.x - esperado) < 1e-4)
		v.queue_free()
	print("     (para fijar ANTES_CAJA con ESCALA_PROYECTIL = 1.0): %s" % str(medidas))


# ---------------------------------------------------------------------------------------------------------------------
func _sin_cambios() -> void:
	print("--- 4. lo que NO cambia")
	var base: float = Sigils.RADIO_BASE_V2
	var casos: Array = [
		["barrera", "earth", {"barrera": 1}], ["barrera de agua", "water", {"barrera": 1}], ["muro (barrera + línea X)", "earth", {"barrera": 1, "linea_x": 2}],
		["columna (altura)", "earth", {"altura": 2}], ["corro / pulso", "fire", {"pulso": 1}], ["esfera quieta", "fire", {}], ["línea X quieta", "water", {"linea_x": 2}]]
	for c in casos:
		var h: Hechizo = Hechizo.construir(_rune(String(c[1])), c[2] as Dictionary)
		var q: Hechizo = h.copiar()
		var celdas: Array = Lanzador3D.GeometriaV2.celdas(h.geo(), Vector2(11.5, 9.5), Vector2.RIGHT, Terreno3D.casilla)
		_ok("%s: velocidad %.2f, escala_vuelo %.2f, semiejes (%.3f, %.3f, %.3f), %d casillas" % [c[0], h.velocidad, h.escala_vuelo, h.semieje_x, h.semieje_y, h.semieje_z, celdas.size()],
			h.velocidad == 0.0 and h.escala_vuelo == 1.0 and h.semiejes_vuelo == h.semiejes and q.semiejes == h.semiejes and h.semieje_x >= base - 1e-9)
	# una esfera quieta rasteriza las mismas casillas con la escala que sin ella (la escala no entra en `geo()` ni en el rasterizado)
	var esfera: Hechizo = Hechizo.construir(_rune("fire"), {})
	var flecha: Hechizo = _flecha("fire")
	_ok("`geo()` de la flecha sigue con los semiejes de siempre (x %.3f, y %.3f, z %.3f): la explosión y las zonas no lo notan" % [flecha.geo()["x"], flecha.geo()["y"], flecha.geo()["z"]],
		absf(float(flecha.geo()["x"]) - base) < 1e-9 and absf(float(flecha.geo()["z"]) - base) < 1e-9 and absf(float(esfera.geo()["x"]) - base) < 1e-9)
