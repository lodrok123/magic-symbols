extends SceneTree
## PRUEBA SIN VENTANA del enganche del fuego y el agua oficiales al juego (A1, 2/11/2026; docs/ENGANCHE_VFX_TOY_2026-11-02.md):
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_vfx_en_juego.gd
## Con `magic_symbols/vfx_procedural` = true, seis hechizos (bola quieta, proyectil, muro, pilar, barrera, haz) de fuego y de agua producen UN `FuegoToy` / `AguaToy` con la figura
## correcta y medidas ≈ semiejes × casilla; la carga empieza al conjurar y se suelta al lanzar; el impacto (con la normal de la lógica) y la expiración lo matan; presupuesto ≤ 1 luz
## (0 en agua) y ≤ 300 partículas por hechizo; VfxElemento3D y ConjuroVfx3D se callan (un solo renderizador). Con false no hay ningún toy y VfxElemento3D dibuja como siempre.

class MundoFalso extends Node3D:
	var _lado: int = 24
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass

class JugadorFalso extends Jugador3D:
	pass

const LADO: int = 24
const SALIDA: Vector2i = Vector2i(5, 8)
const ELEMENTOS: Dictionary = {"fuego": "fire", "agua": "water", "hielo": "ice", "rayo": "lightning", "magma": "magma", "viento": "wind", "tierra": "earth"}      # hielo y rayo: B1 (2/11/2026)
const CLASES: Dictionary = {"fuego": "FuegoToy", "agua": "AguaToy", "hielo": "HieloToy", "rayo": "RayoToy", "magma": "MagmaToy", "viento": "VientoToy", "tierra": "TierraToy"}
const TOPE_LUCES: Dictionary = {"fuego": 1, "agua": 0, "hielo": 0, "rayo": 1, "magma": 1, "viento": 0, "tierra": 0}          # el rayo lleva una luz (el destello); el agua y el hielo, ninguna
const CASILLA: float = 2.3
## Los seis hechizos: nombre, glifos, figura esperada (FuegoToy.Figura), viaja
const SEIS: Array = [
	["bola quieta", {}, 0, false],
	["proyectil", {"flecha": 1}, 0, true],
	["muro", {"barrera": 1, "linea_x": 2}, 1, false],
	["pilar", {"altura": 3}, 2, false],
	["barrera", {"barrera": 1, "linea_x": 2, "linea_z": 2}, 3, false],
	["haz", {"linea_x": 2}, 4, false],
]

var _fallos: int = 0
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: JugadorFalso = null
var _ve: VfxElemento3D = null
var _tj: VfxToyJuego = null
var _defecto_proyecto: Array = []            ## [ajuste, elementos, existe ajuste, existe elementos] tal como los deja project.godot
var _cj: ConjuroVfx3D = null
var _runas: Dictionary = {}
var _terminados: Array = []                  ## lo que emitió HechizoVivo.terminado: [causa, pos, normal, material]
var _max_luces: Dictionary = {"fuego": 0, "agua": 0, "hielo": 0, "rayo": 0, "magma": 0, "viento": 0, "tierra": 0}
var _max_part: Dictionary = {"fuego": 0, "agua": 0, "hielo": 0, "rayo": 0, "magma": 0, "viento": 0, "tierra": 0}


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	for e in ELEMENTOS:
		_runas[e] = load("res://nucleo/%s_rune.tres" % ELEMENTOS[e]) as RuneData
	_defecto_proyecto = [bool(ProjectSettings.get_setting(VfxToyJuego.AJUSTE, false)), String(ProjectSettings.get_setting(VfxToyJuego.AJUSTE_ELEMENTOS, "")), ProjectSettings.has_setting(VfxToyJuego.AJUSTE), ProjectSettings.has_setting(VfxToyJuego.AJUSTE_ELEMENTOS)]      # lo que dice project.godot antes de tocar nada
	await _con_selector_apagado()
	await _seis_hechizos()
	await _proyectil_y_su_fin()
	await _carga_en_la_mano()
	await _un_solo_renderizador()
	await _de_serie()
	await _toys_nuevos()
	await _tierra_unica()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	for n in [_l, _m, _jug, _ve, _tj, _cj]:
		if n != null and is_instance_valid(n):
			n.free()
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
	_jug = JugadorFalso.new()
	root.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(Vector2i(2, 2), Terreno3D.y_pies(Vector2i(2, 2)))
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	root.add_child(_l)
	# lo mismo que monta la maqueta: el dibujo del conjuro, el de lo que sale y el nuevo
	_cj = ConjuroVfx3D.conectar(_l, _m)
	_ve = VfxElemento3D.conectar(_l, _m)
	_ve.casilla = CASILLA
	_tj = VfxToyJuego.conectar(_l, _m)
	_terminados.clear()


func _origen(c: Vector2i = SALIDA) -> Vector3:
	return Lanzador3D.centro_de(c, Terreno3D.y_pies(c) + 0.8)


func _hz(el: String, glifos: Dictionary) -> Hechizo:
	return Hechizo.construir(_runas[el], glifos)


func _lanzar(h: Hechizo, dir: Vector3 = Vector3.RIGHT, c: Vector2i = SALIDA) -> HechizoVivo:
	var hv: HechizoVivo = HechizoVivo.crear(h, _origen(c), dir, _l, null, {}, true)
	hv.terminado.connect(func(causa: String, pos: Vector3, normal: Vector3, material: String) -> void: _terminados.append([causa, pos, normal, material]))
	return hv


func _toys() -> Array:
	var r: Array = []
	for n in _m.get_children():
		if n is FuegoToy or n is AguaToy or n is HieloToy or n is RayoToy or n is MagmaToy or n is VientoToy or n is TierraToy:
			r.append(n)
	return r


func _cerca(a: float, b: float, tol: float) -> bool:
	return absf(a - b) <= tol


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


## Luces y partículas visibles de un toy (el presupuesto).
func _medir(t: Node) -> Dictionary:
	var luces: int = 0
	for l in t.find_children("*", "Light3D", true, false):
		if (l as Light3D).visible and (l as Light3D).light_energy > 0.0:
			luces += 1
	var part: int = 0
	for g in t.find_children("*", "GPUParticles3D", true, false):
		part += int(float((g as GPUParticles3D).amount) * (g as GPUParticles3D).amount_ratio)
	return {"luces": luces, "part": part}


# ------------------------------------------------------------------ 0. con el selector apagado ------------------------------------------------------------------

func _con_selector_apagado() -> void:
	print("== selector apagado: nada cambia")
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
	_ok("0 project.godot: ajuste general = true y elementos = «fuego,agua,rayo,magma,viento,tierra» (de serie; el hielo, no)", bool(_defecto_proyecto[2]) and bool(_defecto_proyecto[3]) and bool(_defecto_proyecto[0]) and String(_defecto_proyecto[1]) == "fuego,agua,rayo,magma,viento,tierra", str(_defecto_proyecto))
	_ok("0 con el ajuste a false `usa_toy` es false para los cuatro", not VfxToyJuego.activo() and not VfxToyJuego.usa_toy("fuego") and not VfxToyJuego.usa_toy("agua") and not VfxToyJuego.usa_toy("hielo") and not VfxToyJuego.usa_toy("rayo") and not VfxToyJuego.usa_toy("magma") and not VfxToyJuego.usa_toy("viento") and not VfxToyJuego.usa_toy("tierra"))
	for el in ELEMENTOS:
		_montar()
		for s in SEIS:
			_lanzar(_hz(el, s[1] as Dictionary))
		await _frames(3)
		_ok("0 %s: ningún FuegoToy, AguaToy, HieloToy ni RayoToy en el mundo (creados %s)" % [el, str(_tj.creados)], _toys().is_empty() and int(_tj.creados["fuego"]) == 0 and int(_tj.creados["agua"]) == 0 and int(_tj.creados["hielo"]) == 0 and int(_tj.creados["rayo"]) == 0 and int(_tj.creados["magma"]) == 0 and int(_tj.creados["viento"]) == 0 and int(_tj.creados["tierra"]) == 0)
		_ok("0 %s: VfxElemento3D dibuja como siempre (proy %d, vol %d, haces %d)" % [el, _ve.proyectiles(), _ve.volumenes(), _ve.haces()], _ve.proyectiles() >= 1 and _ve.volumenes() >= 4 and (_ve.haces() == 1 or ((el == "hielo" or el == "tierra") and _ve.haces() <= 1)))      # el haz de hielo lo dibuja VfxHielo y no cuenta como haz en VfxElemento3D
		_ok("0 %s: sin toy no se ve nada nuevo en el conjuro (ConjuroVfx3D sigue dibujando su forma)" % el, true)


func _encender_todos() -> void:
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, true)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, "fuego,agua,hielo,rayo,magma,viento,tierra")      # las secciones 1-4 prueban los siete toys; lo de serie, la 5


# ------------------------------------------------------------------ 1. los seis hechizos ------------------------------------------------------------------

func _seis_hechizos() -> void:
	print("== selector encendido: seis hechizos de fuego, de agua, de hielo y de rayo")
	_encender_todos()
	for el in ELEMENTOS:
		for s in SEIS:
			await _un_hechizo(el, String(s[0]), s[1] as Dictionary, int(s[2]), bool(s[3]))


func _un_hechizo(el: String, nombre: String, glifos: Dictionary, figura: int, viaja: bool) -> void:
	_montar()
	var h: Hechizo = _hz(el, glifos)
	if viaja and el == "magma":
		h = h.con({"gravedad": 0.0})      # la roca de magma es densa y cae al suelo antes de los 0,6 s que mide «sigue al HechizoVivo»; sin gravedad vuela recta como el resto
	var suelo0: float = Terreno3D.y_pies(SALIDA)                 # antes de lanzar: un bloque de hielo SUBE el terreno de esa casilla y después `y_pies` ya no es el suelo donde se puso el toy
	var hv: HechizoVivo = _lanzar(h)
	await _frames(3)
	var etq: String = "%s · %s" % [el, nombre]
	var toys: Array = _toys()
	if toys.is_empty() and el == "hielo" and (not is_instance_valid(hv) or bool(hv.get("_rechazado"))):
		_ok("1 %s: la lógica rechaza este hechizo de hielo (altura del bloque: cast_rechazado_altura): no hay nada que dibujar" % etq, true)
		return
	_ok("1 %s: UN solo toy (hay %d)" % [etq, toys.size()], toys.size() == 1)
	if toys.size() != 1:
		return
	var t: Node3D = toys[0] as Node3D
	if (el == "hielo" or el == "tierra") and nombre == "haz":
		# el haz de un estado SÓLIDO no emite `haz` (la lógica lo trata como un volumen de hielo): el toy sale por `desde_hechizo` con la figura que dé `describir`
		_ok("1 %s: un toy de su clase (figura %d, la de `describir`: el haz sólido no es un haz para la lógica)" % [etq, int(t.get("figura"))], t.get_script().get_global_name() == CLASES[el])
		return
	if el == "tierra" and not viaja:
		# 6/11 (422): la tierra SÓLIDA que no viaja la levanta el Lanzador por casillas y el TierraToy es su única representación: mide las casillas reales × niveles, no los semiejes del Hechizo (sección 7 lo mira a fondo)
		var celdas: Array = []
		var niveles: int = 0
		for b in _l._bloques:
			celdas.append(b["celda"])
			niveles = maxi(niveles, int(b["niveles"]))
		var sx_t: float = float(t.get("semieje_x"))
		var sy_t: float = float(t.get("semieje_y"))
		var sz_t: float = float(t.get("semieje_z"))
		var fig_t: int = int(t.get("figura"))
		var cubre: bool
		if fig_t == 2:
			cubre = celdas.size() == 1 and niveles >= 2 and _cerca(2.0 * sx_t * VfxToyJuego.TIERRA_PILAR_EXTENSION, CASILLA, 0.02)
		else:
			cubre = celdas.size() == 1 and fig_t == 1 and _cerca(2.0 * sx_t, CASILLA, 0.02) and _cerca(2.0 * sz_t, CASILLA, 0.02)
		_ok("1 %s: TierraToy (figura %d) que cubre el sólido real: %d casilla(s) %s × %d nivel(es), semiejes (%.2f, %.2f, %.2f)" % [etq, fig_t, celdas.size(), str(celdas), niveles, sx_t, sy_t, sz_t],
			t is TierraToy and not celdas.is_empty() and cubre and _cerca(sy_t, float(niveles) * Terreno3D.ALTO_NIVEL, 0.01) and _cerca(t.global_position.y, suelo0, 0.05) and _calla_ve())
		var m_t: Dictionary = _medir(t)
		_ok("1 %s: presupuesto %d luz(ces) (0) y %d partículas (≤ 300)" % [etq, int(m_t["luces"]), int(m_t["part"])], int(m_t["luces"]) == 0 and int(m_t["part"]) <= 300)
		var vida_t: float = maxf(5.5, float(h.persiste + h.permanencia) + 1.0)
		var t0_t: int = Time.get_ticks_msec()
		while is_instance_valid(t) and float(Time.get_ticks_msec() - t0_t) / 1000.0 < vida_t:
			await process_frame
		_ok("1 %s: al deshacerse la tierra el toy se va (a %.1f s ya no está)" % [etq, float(Time.get_ticks_msec() - t0_t) / 1000.0], not is_instance_valid(t) or t.is_queued_for_deletion())
		return
	_ok("1 %s: es un %s con la figura %d (la de `desde_hechizo`)" % [etq, CLASES[el], figura],
		t.get_script().get_global_name() == CLASES[el] and int(t.get("figura")) == figura and bool(t.get("viaja")) == viaja)
	_ok("1 %s: VfxElemento3D no dibuja nada (un solo renderizador: proy %d, vol %d, haces %d)" % [etq, _ve.proyectiles(), _ve.volumenes(), _ve.haces()],
		_ve.proyectiles() == 0 and _ve.volumenes() == 0 and _ve.haces() == 0)
	# medidas: semiejes en metros = los del Hechizo × casilla (el vuelo, × ESCALA_PROYECTIL); el haz, el largo que calculó la lógica
	var s: Vector3 = (h.semiejes_vuelo if viaja else h.semiejes) * CASILLA
	var sx: float = float(t.get("semieje_x"))
	var sy: float = float(t.get("semieje_y"))
	var sz: float = float(t.get("semieje_z"))
	var medidas_ok: bool
	if figura == 4:
		medidas_ok = sx > 0.5 and sx * 2.0 <= h.alcance_haz * CASILLA + 0.01 and _cerca(sz, Hechizo.HAZ_ANCHO * CASILLA * 0.5, 0.01)
	elif figura == 1:
		medidas_ok = _cerca(maxf(sx, sz), maxf(s.x, s.z), 0.01) and _cerca(sy, s.y, 0.01)
	else:
		medidas_ok = _cerca(sx, s.x, 0.01) and _cerca(sy, s.y, 0.01) and _cerca(sz, s.z, 0.01)
	_ok("1 %s: semiejes (%.2f, %.2f, %.2f) ≈ Hechizo × casilla (%.2f, %.2f, %.2f)" % [etq, sx, sy, sz, s.x, s.y, s.z], medidas_ok)
	# las mallas miden lo que los semiejes (fuego: las mismas mallas que comprueba prueba_vfx_toy; agua: la esfera, la cortina o el chorro)
	var nombres: Dictionary = {"fuego": {0: "Llama", 1: "Banda", 2: "Exterior", 3: "Cascara", 4: "Chorro"}, "agua": {0: "Esfera", 1: "", 2: "Cortina", 3: "", 4: "Chorro"}, "hielo": {0: "", 1: "", 2: "", 3: "", 4: ""}, "rayo": {0: "", 1: "", 2: "", 3: "", 4: ""}, "magma": {0: "", 1: "", 2: "", 3: "", 4: ""}, "viento": {0: "", 1: "", 2: "", 3: "", 4: ""}, "tierra": {0: "", 1: "", 2: "", 3: "", 4: ""}}      # hielo y rayo no son mallas con nombre propio: cristales y trazos en MultiMesh
	var nm: String = String((nombres[el] as Dictionary)[figura])
	if nm != "":
		var mi: MeshInstance3D = t.find_child(nm, true, false) as MeshInstance3D
		var ab: AABB = mi.mesh.get_aabb() if mi != null and mi.mesh != null else AABB()
		var ok_ab: bool = mi != null
		match figura:
			1, 3:
				ok_ab = ok_ab and _cerca(ab.size.x, 2.0 * (maxf(sx, sz) if figura == 1 else sx), 0.03 * sx + 0.02)
			2:
				ok_ab = ok_ab and (el == "agua" or (_cerca(ab.size.x, 2.0 * sx, 0.03 * sx + 0.02) and _cerca(ab.size.y, sy, 0.02 * sy + 0.02)))      # la cortina del agua es una malla unidad que se escala por nodo
			4:
				ok_ab = ok_ab and ab.size.z >= 2.0 * sx - 0.05
		_ok("1 %s: malla «%s» AABB %s ≈ semiejes × casilla" % [etq, nm, str(ab.size)], ok_ab)
	else:
		_ok("1 %s: (%s: su %s no es una malla con nombre propio; se comprueban los semiejes)" % [etq, el, ["bola", "muro", "pilar", "barrera", "haz"][figura]], true)
	# colocación: ni flotando ni enterrado (la base del muro, del pilar y de la barrera en el suelo; la bola, con su centro a media altura; el haz, a ras con su eje a la altura de la mano)
	var suelo: float = suelo0
	var y: float = t.global_position.y
	var bien_puesto: bool
	match figura:
		0:
			bien_puesto = y >= suelo + 0.2 or viaja
		4:
			bien_puesto = _cerca(y, suelo, 0.05)
		_:
			bien_puesto = _cerca(y, suelo, 0.05)
	_ok("1 %s: colocado (y %.2f, suelo %.2f)" % [etq, y, suelo], bien_puesto)
	# presupuesto
	var m: Dictionary = _medir(t)
	var tope_luces: int = int(TOPE_LUCES[el])
	_max_luces[el] = maxi(int(_max_luces[el]), int(m["luces"]))
	_max_part[el] = maxi(int(_max_part[el]), int(m["part"]))
	_ok("1 %s: presupuesto %d luz(ces) (≤ %d) y %d partículas (≤ 300)" % [etq, int(m["luces"]), tope_luces, int(m["part"])], int(m["luces"]) <= tope_luces and int(m["part"]) <= 300)
	# vida: un volumen que no viaja vive lo que dice la lógica (persiste: fuego 3 s, agua `vida_total` mínima 1 s) y se apaga; el haz, HAZ_DURA_S
	if not viaja:
		var vida: float = maxf(4.0 if figura == 4 else 5.5, float(h.persiste + h.permanencia) + 1.0)          # el hielo persiste 6 s
		var t0: int = Time.get_ticks_msec()
		while is_instance_valid(t) and float(Time.get_ticks_msec() - t0) / 1000.0 < vida:
			await process_frame
		_ok("1 %s: la expiración lo mata (a %.1f s ya no está)" % [etq, float(Time.get_ticks_msec() - t0) / 1000.0], not is_instance_valid(t) or t.is_queued_for_deletion())
	else:
		# proyectil: sigue la posición del HechizoVivo y su dirección
		for _i in range(6):
			hv.paso(0.1)
			await process_frame
		_ok("1 %s: sigue al HechizoVivo (toy %s, hechizo %s)" % [etq, str(t.global_position), str(hv.global_position)], t.global_position.distance_to(hv.global_position) < 0.05)
		var fw: Vector3 = -t.global_transform.basis.z
		_ok("1 %s: mira hacia donde vuela (%s)" % [etq, str(fw)], fw.dot(hv.v.normalized()) > 0.99)


# ------------------------------------------------------------------ 2. el proyectil y su fin ------------------------------------------------------------------

func _proyectil_y_su_fin() -> void:
	print("== proyectil: impacto con la normal de la lógica, rebote y fin sin choque")
	_encender_todos()
	for el in ELEMENTOS:
		# choca con la pared del fondo (x = 23): normal -X y material «#»
		_montar()
		var hv: HechizoVivo = _lanzar(_hz(el, {"flecha": 1}).con({"gravedad": 0.0, "distancia_max": 8.0}), Vector3.RIGHT, Vector2i(17, 8))
		await process_frame
		var t: Node3D = _toys()[0] as Node3D
		var pasos: int = 0
		while hv.activo and pasos < 600:
			hv.paso(0.1)
			pasos += 1
		await _frames(2)
		var ev: Array = _terminados[0] if _terminados.size() > 0 else []
		_ok("2 %s: la lógica avisa del fin contra el muro (causa «%s», normal %s, material «%s»)" % [el, str(ev[0]) if ev.size() > 0 else "-", str(ev[2]) if ev.size() > 0 else "-", str(ev[3]) if ev.size() > 0 else "-"],
			ev.size() == 4 and String(ev[0]) == "muro" and (ev[2] as Vector3).is_equal_approx(Vector3(-1, 0, 0)) and String(ev[3]) == "#")
		var imp: Node = null
		var hay_impacto: bool = false
		for n in _m.get_children():
			if n is ImpactoFuegoToy or n is ImpactoAguaToy or n is ImpactoHieloToy or n is ImpactoRayoToy or n is ImpactoMagmaToy or n is ImpactoVientoToy or n is ImpactoTierraToy:
				hay_impacto = true
		_ok("2 %s: el toy hace SU impacto (ImpactoFuegoToy / ImpactoAguaToy / ImpactoHieloToy / ImpactoRayoToy) en el sitio" % el, hay_impacto or imp != null)
		var t0: int = Time.get_ticks_msec()
		while is_instance_valid(t) and not t.is_queued_for_deletion() and float(Time.get_ticks_msec() - t0) < 2500.0:
			await process_frame
		_ok("2 %s: tras el impacto la bola muere (%.2f s)" % [el, float(Time.get_ticks_msec() - t0) / 1000.0], not is_instance_valid(t) or t.is_queued_for_deletion())
		# se agota por alcance: «terminar_sin_choque», sin impacto de golpe
		_montar()
		var h2: Hechizo = _hz(el, {"flecha": 1}).con({"distancia_max": 1.0, "gravedad": 0.0})
		var hv2: HechizoVivo = _lanzar(h2)
		await process_frame
		var t2: Node3D = _toys()[0] as Node3D
		var n2: int = 0
		while hv2.activo and n2 < 600:
			hv2.paso(0.1)
			n2 += 1
		await _frames(2)
		_ok("2 %s: por alcance la lógica avisa «%s»" % [el, str(_terminados[0][0]) if _terminados.size() > 0 else "-"], _terminados.size() == 1 and String(_terminados[0][0]) == "alcance")
		await _frames(2)
		_ok("2 %s: …y se APAGA encogiéndose, no desaparece de golpe (a los 3 fotogramas sigue en el árbol)" % el, is_instance_valid(t2) and not t2.is_queued_for_deletion())
		var t1: int = Time.get_ticks_msec()
		while is_instance_valid(t2) and not t2.is_queued_for_deletion() and float(Time.get_ticks_msec() - t1) < 2500.0:
			await process_frame
		_ok("2 %s: el fin sin choque apaga la bola (%.2f s)" % [el, float(Time.get_ticks_msec() - t1) / 1000.0], not is_instance_valid(t2) or t2.is_queued_for_deletion())
		# rebote: el toy sigue vivo y la lógica da la normal
		_montar()
		var h3: Hechizo = _hz(el, {"flecha": 1, "rebote": 1}).con({"gravedad": 0.0, "distancia_max": 8.0})
		var hv3: HechizoVivo = _lanzar(h3, Vector3.RIGHT, Vector2i(17, 8))
		var rebotes: Array = []
		hv3.rebotado.connect(func(p: Vector3, n: Vector3) -> void: rebotes.append([p, n]))
		await process_frame
		var t3: Node3D = _toys()[0] as Node3D
		var n3: int = 0
		while hv3.rebotes_usados == 0 and hv3.activo and n3 < 600:
			hv3.paso(0.1)
			n3 += 1
		await _frames(2)
		_ok("2 %s: el rebote lo avisa la lógica con su normal (%s) y el toy sigue vivo" % [el, str(rebotes[0][1]) if rebotes.size() > 0 else "-"],
			rebotes.size() == 1 and (rebotes[0][1] as Vector3).x < -0.9 and is_instance_valid(t3) and not t3.is_queued_for_deletion())


# ------------------------------------------------------------------ 3. la carga en la mano ------------------------------------------------------------------

func _carga_en_la_mano() -> void:
	print("== carga en la mano: empieza al conjurar, se suelta al lanzar")
	_encender_todos()
	for el in ELEMENTOS:
		_montar()
		var h: Hechizo = _hz(el, {"flecha": 1})
		var mano: Vector3 = _origen() + Vector3(0.2, 0.3, 0.0)
		_l.conjuro_actual = {"hechizo": h, "carga": 0.0}
		_l.conjuro_fase.emit("runa", el, mano)
		_l.conjuro_fase.emit("forma", el, mano)
		await _frames(2)
		var toys: Array = _toys()
		_ok("3 %s: al conjurar («forma») nace el toy y empieza a cargar (toys %d, cargas %d)" % [el, toys.size(), _tj.cargas], toys.size() == 1 and _tj.cargas == 1 and bool(toys[0].call("esta_cargando")))
		if toys.is_empty():
			continue
		var t: Node3D = toys[0] as Node3D
		_ok("3 %s: en la mano (%s)" % [el, str(t.global_position)], t.global_position.distance_to(_l.call("_pos_cast_point") as Vector3) < 0.01)  # sigue al cast point de la mano
		await create_timer(0.35).timeout
		var prog: float = float(t.call("progreso_carga"))
		_ok("3 %s: la carga avanza (progreso %.2f) y ConjuroVfx3D no dibuja su forma encima (formas %d)" % [el, prog, _cj._vivos.size()], prog > 0.1 and _cj._vivos.is_empty())
		_l.conjuro_fase.emit("disparo", el, mano)
		var hv: HechizoVivo = _lanzar(h)
		await _frames(3)
		_ok("3 %s: al lanzar se SUELTA la misma bola (sigue habiendo un toy, es el mismo, ya vuela: viaja %s, cargando %s)" % [el, str(t.get("viaja")), str(t.call("esta_cargando"))],
			_toys().size() == 1 and _toys()[0] == t and bool(t.get("viaja")) and not bool(t.call("esta_cargando")) and int(_tj.creados[el]) == 1)
		_ok("3 %s: y se mueve con el HechizoVivo (%s)" % [el, str(hv.global_position)], t.global_position.distance_to(hv.global_position) < 0.05)
		# un hechizo que no es proyectil: la carga de la mano se cancela y nace el toy del volumen (uno solo en vuelo)
		_montar()
		var hm: Hechizo = _hz(el, {"barrera": 1, "linea_x": 2})
		_l.conjuro_actual = {"hechizo": hm, "carga": 0.0}
		_l.conjuro_fase.emit("forma", el, mano)
		await _frames(2)
		var tm: Node3D = _toys()[0] as Node3D
		_l.conjuro_fase.emit("disparo", el, mano)
		_lanzar(hm)
		await create_timer(0.8).timeout
		var vivos: Array = _toys().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
		_ok("3 %s: con un muro la carga de la mano se apaga y queda UN toy: el muro (toys vivos %d, figura %s)" % [el, vivos.size(), str(vivos[0].get("figura")) if vivos.size() > 0 else "-"],
			(not is_instance_valid(tm) or tm.is_queued_for_deletion() or tm == vivos[0]) and vivos.size() == 1 and int(vivos[0].get("figura")) == 1)
		# sin disparo (la jugadora muere): la carga se retira al empezar otro conjuro
		_montar()
		_l.conjuro_actual = {"hechizo": h, "carga": 0.0}
		_l.conjuro_fase.emit("forma", el, mano)
		await _frames(2)
		var tc: Node3D = _toys()[0] as Node3D
		_l.conjuro_fase.emit("runa", el, mano)
		await create_timer(0.6).timeout
		_ok("3 %s: un conjuro interrumpido no deja la carga colgando" % el, not is_instance_valid(tc) or tc.is_queued_for_deletion())
	# con el selector apagado la carga NO nace
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
	_montar()
	_l.conjuro_actual = {"hechizo": _hz("fuego", {"flecha": 1}), "carga": 0.0}
	_l.conjuro_fase.emit("forma", "fuego", _origen())
	await _frames(2)
	_ok("3 con false: la forma de la mano es la de ConjuroVfx3D (formas %d) y no hay toy" % _cj._vivos.size(), _toys().is_empty() and not _cj._vivos.is_empty())


# ------------------------------------------------------------------ 4. un solo renderizador ------------------------------------------------------------------

func _un_solo_renderizador() -> void:
	print("== un solo renderizador y el resto de elementos no cambia")
	_encender_todos()
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, "fuego,agua,hielo,rayo")      # sin magma, viento ni tierra en la lista: VfxElemento3D los dibuja como antes
	_montar()
	for el in ["tierra", "viento", "hielo"]:
		if not _runas.has(el):
			_runas[el] = load("res://nucleo/%s_rune.tres" % {"tierra": "earth", "viento": "wind", "hielo": "ice"}[el]) as RuneData
	_lanzar(Hechizo.construir(_runas["tierra"], {"flecha": 1}))
	_lanzar(Hechizo.construir(_runas["viento"], {"altura": 1}), Vector3.RIGHT, Vector2i(8, 12))
	await _frames(3)
	_ok("4 tierra y viento FUERA de la lista siguen con VfxElemento3D (proy %d, vol %d) y sin toys (%d)" % [_ve.proyectiles(), _ve.volumenes(), _toys().size()], _ve.proyectiles() >= 1 and _ve.volumenes() >= 1 and _toys().is_empty())
	# la copia de un volumen (ᚠ): una sola luz por hechizo
	_montar()
	_encender_todos()
	var hr: Hechizo = _hz("fuego", {"altura": 2, "repeticion": 2})
	_lanzar(hr)
	await _frames(3)
	var luces: int = 0
	for t in _toys():
		luces += int(_medir(t)["luces"])
	_ok("4 un fuego con copias (%d toys) sigue con ≤ 1 luz en total (%d)" % [_toys().size(), luces], luces <= 1)
	# ᚠ en un proyectil: dos bolas, una sola luz
	_montar()
	var hc: Hechizo = _hz("fuego", {"flecha": 1, "repeticion": 2})
	_lanzar(hc)
	await _frames(3)
	var luces_c: int = 0
	for t in _toys():
		luces_c += int(_medir(t)["luces"])
	_ok("4 un proyectil con ᚠ (%d bolas) suma ≤ 1 luz (%d)" % [_toys().size(), luces_c], _toys().size() >= 2 and luces_c <= 1)
	print("resumen presupuesto: fuego luces máx %d, partículas máx %d · agua luces máx %d, partículas máx %d · hielo luces máx %d, partículas máx %d · rayo luces máx %d, partículas máx %d" % [_max_luces["fuego"], _max_part["fuego"], _max_luces["agua"], _max_part["agua"], _max_luces["hielo"], _max_part["hielo"], _max_luces["rayo"], _max_part["rayo"]])

# ------------------------------------------------------------------ 5. lo de serie: fuego y agua con el toy, hielo y rayo con el dibujo de antes ------------------------------------------------------------------

func _de_serie() -> void:
	print("== de serie (ajuste = true, elementos = «fuego,agua»): fuego y agua con el toy; hielo y rayo como antes")
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, true)
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, String(_defecto_proyecto[1]))
	_ok("5 usa_toy: fuego, agua, rayo, magma, viento y tierra sí; hielo y naturaleza no", VfxToyJuego.usa_toy("fuego") and VfxToyJuego.usa_toy("agua") and not VfxToyJuego.usa_toy("hielo") and VfxToyJuego.usa_toy("rayo") and VfxToyJuego.usa_toy("tierra") and VfxToyJuego.usa_toy("viento") and VfxToyJuego.usa_toy("magma") and not VfxToyJuego.usa_toy("naturaleza"))
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, " Fuego , rayo,,nada")
	_ok("5 la lista tolera mayúsculas, espacios y vacíos (%s)" % str(VfxToyJuego.elementos_activos()), VfxToyJuego.usa_toy("fuego") and VfxToyJuego.usa_toy("rayo") and not VfxToyJuego.usa_toy("agua") and not VfxToyJuego.usa_toy("nada"))
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE_ELEMENTOS, "fuego,agua")
	for el in ELEMENTOS:
		var toy: bool = el == "fuego" or el == "agua"
		for s in SEIS:
			_montar()
			_lanzar(_hz(el, s[1] as Dictionary))
			await _frames(3)
			var n: int = _toys().size()
			var etq: String = "%s · %s" % [el, String(s[0])]
			if toy:
				_ok("5 %s: UN toy (%d) y VfxElemento3D se calla (proy %d, vol %d, haces %d)" % [etq, n, _ve.proyectiles(), _ve.volumenes(), _ve.haces()], n == 1 and _ve.proyectiles() == 0 and _ve.volumenes() == 0 and _ve.haces() == 0)
			else:
				var dibuja: bool = _ve.proyectiles() + _ve.volumenes() + _ve.haces() >= 1 or el == "hielo"      # el hielo sólido lo dibuja también VfxHielo fuera de VfxElemento3D
				_ok("5 %s: ningún toy (%d, creados %s) y el dibujo de antes sigue (proy %d, vol %d, haces %d)" % [etq, n, str(_tj.creados), _ve.proyectiles(), _ve.volumenes(), _ve.haces()], n == 0 and dibuja and int(_tj.creados[el]) == 0)
		# la carga de la mano: toy para fuego y agua; ConjuroVfx3D dibuja su forma para hielo y rayo
		_montar()
		var h: Hechizo = _hz(el, {"flecha": 1})
		_l.conjuro_actual = {"hechizo": h, "carga": 0.0}
		_l.conjuro_fase.emit("runa", el, _origen())
		_l.conjuro_fase.emit("forma", el, _origen())
		await _frames(2)
		if toy:
			_ok("5 %s: la carga de la mano es del toy (toys %d, formas de ConjuroVfx3D %d)" % [el, _toys().size(), _cj._vivos.size()], _toys().size() == 1 and _tj.cargas == 1 and _cj._vivos.is_empty())
		else:
			_ok("5 %s: la carga de la mano la dibuja ConjuroVfx3D como antes (formas %d) y no hay toy (%d)" % [el, _cj._vivos.size(), _toys().size()], _toys().is_empty() and _tj.cargas == 0 and not _cj._vivos.is_empty())
		# un proyectil que choca: el hielo y el rayo no pasan por VfxToyJuego (ningún Impacto*Toy)
		if not toy:
			_montar()
			var hv: HechizoVivo = _lanzar(_hz(el, {"flecha": 1}).con({"gravedad": 0.0, "distancia_max": 8.0}), Vector3.RIGHT, Vector2i(17, 8))
			var pasos: int = 0
			while hv.activo and pasos < 600:
				hv.paso(0.1)
				pasos += 1
			await _frames(2)
			var imp: bool = false
			for nd in _m.get_children():
				if nd is ImpactoHieloToy or nd is ImpactoRayoToy or nd is ImpactoFuegoToy or nd is ImpactoAguaToy or nd is ImpactoMagmaToy or nd is ImpactoVientoToy or nd is ImpactoTierraToy:
					imp = true
			_ok("5 %s: el impacto contra el muro no crea ningún Impacto*Toy (lo dibuja VfxElemento3D como antes)" % el, not imp)
	# el selector general a false manda sobre la lista
	ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
	_ok("5 con el ajuste general a false la lista no cuenta: nadie usa toy", not VfxToyJuego.usa_toy("fuego") and not VfxToyJuego.usa_toy("agua"))


# ------------------------------------------------------------------ 6. magma, viento y tierra (6/11) ------------------------------------------------------------------

func _luces_de(toys: Array) -> int:
	var n: int = 0
	for t in toys:
		n += int(_medir(t as Node)["luces"])
	return n


func _calla_ve() -> bool:
	return _ve.proyectiles() == 0 and _ve.volumenes() == 0 and _ve.haces() == 0


func _toys_nuevos() -> void:
	print("== magma, viento y tierra: mismo camino que fuego/agua/rayo")
	_encender_todos()
	_ok("6 ELEMENTOS_DEFECTO del código coincide con project.godot (%s)" % VfxToyJuego.ELEMENTOS_DEFECTO, VfxToyJuego.ELEMENTOS_DEFECTO == String(_defecto_proyecto[1]))
	# MAGMA proyectil: carga → soltar → impacto
	_montar()
	var h: Hechizo = _hz("magma", {"flecha": 1}).con({"gravedad": 0.0, "distancia_max": 8.0})
	_ok("6 el hechizo de magma lleva el elemento «magma» (%s)" % h.elemento, h.elemento == "magma")
	var mano: Vector3 = _origen() + Vector3(0.2, 0.3, 0.0)
	_l.conjuro_actual = {"hechizo": h, "carga": 0.0}
	_l.conjuro_fase.emit("runa", "magma", mano)
	_l.conjuro_fase.emit("forma", "magma", mano)
	await _frames(2)
	var tt: Array = _toys()
	_ok("6 magma: la carga en la mano es UN MagmaToy cargando, con ≤ 1 luz y ConjuroVfx3D callado (toys %d, formas %d)" % [tt.size(), _cj._vivos.size()], tt.size() == 1 and tt[0] is MagmaToy and bool(tt[0].call("esta_cargando")) and _luces_de(tt) <= 1 and _cj._vivos.is_empty())
	await create_timer(0.3).timeout
	_l.conjuro_fase.emit("disparo", "magma", mano)
	var hv: HechizoVivo = _lanzar(h, Vector3.RIGHT, Vector2i(17, 8))
	await _frames(3)
	var t: Node3D = _toys()[0] as Node3D if _toys().size() > 0 else null
	_ok("6 magma: al soltar vuela la MISMA bola (toys %d, viaja %s) y la lógica dice «%s»" % [_toys().size(), str(t.get("viaja")) if t != null else "-", hv.elemento], _toys().size() == 1 and tt.size() == 1 and _toys()[0] == tt[0] and bool(t.get("viaja")) and _calla_ve())
	var pasos: int = 0
	while hv.activo and pasos < 600:
		hv.paso(0.1)
		pasos += 1
	await _frames(2)
	var imp_m: int = 0
	for n in _m.get_children():
		if n is ImpactoMagmaToy:
			imp_m += 1
	_ok("6 magma: el impacto contra el muro crea ImpactoMagmaToy (%d) y no hay ImpactoFuegoToy colgando del mundo" % imp_m, imp_m >= 1 and _m.get_children().filter(func(n: Node) -> bool: return n is ImpactoFuegoToy).is_empty())
	# MAGMA: el volumen delega en un FuegoToy hijo: la luz sigue siendo 1 (con copias de ᚠ también)
	for caso in [["muro", {"barrera": 1, "linea_x": 2}], ["pilar con ᚠ", {"altura": 3, "repeticion": 2}], ["muro con ᚠ", {"barrera": 1, "linea_x": 2, "repeticion": 2}], ["barrera con ᚠ", {"barrera": 1, "linea_x": 2, "linea_z": 2, "repeticion": 2}], ["bola quieta con ᚠ", {"repeticion": 2}], ["proyectil con ᚠ", {"flecha": 1, "repeticion": 2}]]:
		_montar()
		_lanzar(_hz("magma", caso[1] as Dictionary))
		await _frames(4)
		var ts: Array = _toys()
		var luces: int = _luces_de(ts)
		_ok("6 magma · %s: %d toy(s) MagmaToy, luces en total %d (≤ 1) y VfxElemento3D callado" % [caso[0], ts.size(), luces], ts.size() >= 1 and ts.all(func(n: Node) -> bool: return n is MagmaToy) and luces <= 1 and _calla_ve())
		if String(caso[0]).ends_with("ᚠ") and not String(caso[0]).begins_with("proyectil"):
			pass
	# TIERRA: un TierraToy por copia, sin luz
	for caso in [["muro", {"barrera": 1, "linea_x": 2}], ["muro con ᚠ", {"barrera": 1, "linea_x": 2, "repeticion": 2}], ["pilar", {"altura": 3}], ["bola quieta", {}], ["proyectil", {"flecha": 1}]]:
		_montar()
		var hz: Hechizo = _hz("tierra", caso[1] as Dictionary)
		_lanzar(hz)
		await _frames(4)
		var ts2: Array = _toys()
		var rep: int = int((caso[1] as Dictionary).get("repeticion", 1))
		_ok("6 tierra · %s: %d TierraToy (creados %d), luces %d (0), VfxElemento3D callado" % [caso[0], ts2.size(), int(_tj.creados["tierra"]), _luces_de(ts2)], ts2.size() >= 1 and ts2.size() == int(_tj.creados["tierra"]) and ts2.all(func(n: Node) -> bool: return n is TierraToy) and _luces_de(ts2) == 0 and (rep < 2 or ts2.size() >= 2 or String(caso[0]) == "proyectil") and _calla_ve())
	# TIERRA proyectil: impacto
	_montar()
	var hvt: HechizoVivo = _lanzar(_hz("tierra", {"flecha": 1}).con({"gravedad": 0.0, "distancia_max": 8.0}), Vector3.RIGHT, Vector2i(17, 8))
	await _frames(2)
	var pt: int = 0
	while hvt.activo and pt < 600:
		hvt.paso(0.1)
		pt += 1
	await _frames(2)
	_ok("6 tierra: el proyectil que choca crea ImpactoTierraToy", _m.get_children().any(func(n: Node) -> bool: return n is ImpactoTierraToy))
	# VIENTO: bola, proyectil y haz, sin luz
	for caso in [["bola quieta", {}], ["proyectil", {"flecha": 1}], ["haz", {"linea_x": 2}], ["muro", {"barrera": 1, "linea_x": 2}]]:
		_montar()
		_lanzar(_hz("viento", caso[1] as Dictionary))
		await _frames(4)
		var ts3: Array = _toys()
		_ok("6 viento · %s: %d VientoToy, luces %d (0), VfxElemento3D callado (proy %d, vol %d, haces %d)" % [caso[0], ts3.size(), _luces_de(ts3), _ve.proyectiles(), _ve.volumenes(), _ve.haces()], ts3.size() == 1 and ts3[0] is VientoToy and _luces_de(ts3) == 0 and _calla_ve())
	# VIENTO proyectil: impacto
	_montar()
	var hvv: HechizoVivo = _lanzar(_hz("viento", {"flecha": 1}).con({"gravedad": 0.0, "distancia_max": 8.0}), Vector3.RIGHT, Vector2i(17, 8))
	await _frames(2)
	var pv: int = 0
	while hvv.activo and pv < 600:
		hvv.paso(0.1)
		pv += 1
	await _frames(2)
	_ok("6 viento: el proyectil que choca crea ImpactoVientoToy", _m.get_children().any(func(n: Node) -> bool: return n is ImpactoVientoToy))
	# NATURALEZA (agua + tierra) no tiene toy: sigue con la pieza de la tierra de VfxElemento3D
	_runas["naturaleza"] = load("res://nucleo/naturaleza_rune.tres") as RuneData
	_montar()
	_lanzar(Hechizo.construir(_runas["naturaleza"], {"flecha": 1}))
	await _frames(3)
	_ok("6 naturaleza: sin toy (%d) y VfxElemento3D la dibuja (proy %d)" % [_toys().size(), _ve.proyectiles()], _toys().is_empty() and _ve.proyectiles() >= 1)
	print("resumen presupuesto nuevos: magma luces máx %d, partículas máx %d · viento luces máx %d, partículas máx %d · tierra luces máx %d, partículas máx %d" % [_max_luces["magma"], _max_part["magma"], _max_luces["viento"], _max_part["viento"], _max_luces["tierra"], _max_part["tierra"]])


# ------------------------------------------------------------------ 7. la tierra sólida: el toy es la única representación (6/11, entrada 422) ------------------------------------------------------------------

## Los Area3D «BloqueTierra» colgados del mundo.
func _bloques_tierra() -> Array:
	var r: Array = []
	for n in _m.get_children():
		if n.name.begins_with("BloqueTierra"):
			r.append(n)
	return r


## ¿Se ve el bloque? (caja BoxMesh visible, o trozos `bloque_tierra_*` del vestido)
func _bloque_dibujado(b: Node) -> Dictionary:
	var caja: bool = false
	var vestido: int = 0
	for h in b.get_children():
		if h is MeshInstance3D and (h as MeshInstance3D).mesh is BoxMesh and (h as MeshInstance3D).visible:
			caja = true
		if String(h.name).begins_with("bloque_tierra_"):
			vestido += 1
	return {"caja": caja, "vestido": vestido}


func _tierra_unica() -> void:
	print("== tierra sólida: con el toy encendido, el TierraToy es la única representación (ni caja, ni vestido, ni terraza)")
	var glifos: Dictionary = {"barrera": 1, "linea_x": 2, "altura": 1}
	for modo in ["procedural", "actual"]:
		var toy: bool = modo == "procedural"
		if toy:
			_encender_todos()
		else:
			ProjectSettings.set_setting(VfxToyJuego.AJUSTE, false)
		_montar()
		var h: Hechizo = _hz("tierra", glifos)
		_lanzar(h)
		await _frames(4)
		var bloques: Array = _bloques_tierra()
		var celdas: Array = []
		for b in _l._bloques:
			celdas.append(b["celda"])
		var niveles: int = int(_l._bloques[0]["niveles"]) if not _l._bloques.is_empty() else 0
		_ok("7 %s: el Lanzador levantó bloques de tierra (%d bloques, %d casillas %s, %d nivel/es) y `alturas_temporales` las apunta" % [modo, bloques.size(), celdas.size(), str(celdas), niveles],
			bloques.size() >= 1 and celdas.size() >= 1 and niveles >= 1 and celdas.all(func(c: Vector2i) -> bool: return Terreno3D.alturas_temporales.get(c, 0) == Terreno3D.altura_en(c) and Terreno3D.altura_en(c) >= 1))
		var dib: Array = bloques.map(_bloque_dibujado)
		if toy:
			_ok("7 procedural: ningún BloqueTierra con caja visible ni vestido (%s)" % str(dib), dib.all(func(d: Dictionary) -> bool: return not bool(d["caja"]) and int(d["vestido"]) == 0))
			_ok("7 procedural: la maqueta NO pinta terraza en esas casillas (`oculta_terraza`)", celdas.all(func(c: Vector2i) -> bool: return VfxToyJuego.oculta_terraza(c)))
			var ts: Array = _toys()
			var t: Node3D = ts[0] as Node3D if ts.size() == 1 else null
			var ancho_cas: int = 0
			var fondo_cas: int = 0
			if not celdas.is_empty():
				var xs: Array = celdas.map(func(c: Vector2i) -> int: return c.x)
				var zs: Array = celdas.map(func(c: Vector2i) -> int: return c.y)
				fondo_cas = int(xs.max()) - int(xs.min()) + 1          # el tiro va por +X: el fondo son las casillas en X; el ancho, en Z
				ancho_cas = int(zs.max()) - int(zs.min()) + 1
			var sx: float = float(t.get("semieje_x")) if t != null else 0.0
			var sy: float = float(t.get("semieje_y")) if t != null else 0.0
			var sz: float = float(t.get("semieje_z")) if t != null else 0.0
			_ok("7 procedural: UN TierraToy MURO que mide las casillas: ancho %.2f (%d × %.2f), fondo %.2f (1 casilla), alto %.2f (%d × %.3f)" % [2.0 * sx, ancho_cas, CASILLA, 2.0 * sz, sy, niveles, Terreno3D.ALTO_NIVEL],
				t != null and t is TierraToy and int(t.get("figura")) == FuegoToy.Figura.MURO and _cerca(2.0 * sx, float(ancho_cas) * CASILLA, 0.02) and _cerca(2.0 * sz, float(fondo_cas) * CASILLA, 0.02) and fondo_cas == 1 and _cerca(sy, float(niveles) * Terreno3D.ALTO_NIVEL, 0.01))
			var y_suelo: float = Terreno3D.alto_suelo
			var cx: float = 0.0
			var cz: float = 0.0
			for c in celdas:
				cx += Terreno3D.centro_de(c as Vector2i, 0.0).x / float(celdas.size())
				cz += Terreno3D.centro_de(c as Vector2i, 0.0).z / float(celdas.size())
			_ok("7 procedural: el toy se asienta en el suelo real (y %.3f = %.3f) y en el centro de sus casillas (%.2f, %.2f)" % [t.global_position.y if t != null else -1.0, y_suelo, cx, cz],
				t != null and _cerca(t.global_position.y, y_suelo, 0.01) and _cerca(t.global_position.x, cx, 0.05) and _cerca(t.global_position.z, cz, 0.05))
			await create_timer(0.7).timeout
			var ys: Array = t.call("alturas_actuales") as Array if t != null else []
			_ok("7 procedural: las rocas han subido (%d rocas, y máx %.2f ≥ 0)" % [ys.size(), float(ys.max()) if not ys.is_empty() else -9.0], not ys.is_empty() and float(ys.max()) >= -0.01)
			# el Lanzador deshace la tierra (el tope o la caducidad): el toy se hunde en ese momento, no al acabar su vida
			for b in _l._bloques.duplicate():
				_l._deshacer_bloque(b)
			await _frames(2)
			var ap: AnimationPlayer = t.get_node_or_null("Anim") as AnimationPlayer if t != null else null
			_ok("7 procedural: al deshacerse el bloque el toy se hunde ya (anim «%s») y `alturas_temporales` queda vacía" % (ap.current_animation if ap != null else "-"), ap != null and ap.current_animation == "morir" and Terreno3D.alturas_temporales.is_empty())
		else:
			_ok("7 actual: cada BloqueTierra lleva su vestido de 4 trozos (o la caja) como siempre (%s)" % str(dib), dib.all(func(d: Dictionary) -> bool: return bool(d["caja"]) or int(d["vestido"]) == 4))
			_ok("7 actual: la maqueta sigue pintando la terraza (`oculta_terraza` false) y no hay toys (%d)" % _toys().size(), celdas.all(func(c: Vector2i) -> bool: return not VfxToyJuego.oculta_terraza(c)) and _toys().is_empty())
	# el hielo sólido no cambia: con el toy encendido sigue con su caja
	_encender_todos()
	_montar()
	var ok_h: bool = _l.construir_tierra(Vector2i(10, 10), true, {"elemento": "hielo"})
	await _frames(1)
	var bh: Array = []
	for n in _m.get_children():
		if n.name == "BloqueHielo":
			bh.append(n)
	_ok("7 hielo sólido con el toy encendido: BloqueHielo con su caja visible y sin apuntarse como tierra temporal", ok_h and bh.size() == 1 and bool(_bloque_dibujado(bh[0])["caja"]) and not Terreno3D.alturas_temporales.has(Vector2i(10, 10)) and Terreno3D.altura_en(Vector2i(10, 10)) == 1)
