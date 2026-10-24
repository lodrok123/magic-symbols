extends SceneTree

## CAPTURA (24/10, decisión de Pablo «ejes con base 0,10 y cada glifo suma 0,10»): saca un PNG de cada tamaño que cambia, ANTES (base 0,25 y +0,15 por glifo, los valores
## de hasta el 24/10) y DESPUÉS (los actuales de `Sigils`), junto a la jugadora (Pj3D «jugadora_base», 1 u de alto) para ver la escala. Lanza con el Lanzador3D, el HechizoVivo y
## el VfxElemento3D REALES (el que dibuja en el juego). No es una prueba. Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_radio_base.gd -- docs/capturas/radio_base [elemento]
## «Antes» no existe ya en el código: se reproduce construyendo el Hechizo de hoy y poniéndole los semiejes viejos (`ANTES_BASE` + `ANTES_PASO` por glifo) y los mínimos de dibujo
## viejos (`ANTES_FACTOR_BOLA_MIN`, `ANTES_ESCALA_VOL_MIN`). Escribe <caso>_antes.png y <caso>_despues.png y una tabla con los tamaños medidos por la salida estándar.

const TAM: Vector2i = Vector2i(1280, 720)
const ANTES_BASE: float = 0.25
const ANTES_PASO: float = 0.15
const ANTES_FACTOR_BOLA_MIN: float = 0.5
const ANTES_ESCALA_VOL_MIN: float = 0.6
const CAM_TAM_U: float = 5.0                 ## alto de la vista ortogonal en u (la jugadora mide 1 u)
const CAM_PITCH_GRADOS: float = 30.0         ## la cámara del juego mira 30° por debajo de la horizontal
const T_VOLUMEN_S: float = 0.15              ## cuándo se fotografía lo quieto (el impacto del fuego dura un fogonazo; a los 0,7 s ya no queda nada)
const T_FLECHA_S: float = 1.0                ## cuándo se fotografía el proyectil (ya creció del todo: PROYECTIL_CRECE_S 0,6)
const T_HAZ_S: float = 0.5
const LADO: int = 16
const ORIGEN_C: Vector2i = Vector2i(5, 8)
const ALTO_MANO_U: float = 0.8
## Casos: [nombre, glifos, qué foto (volumen | flecha | haz)]
const CASOS: Array = [
	["bola_sin_glifos", {}, "volumen"],
	["bola_altura1", {"altura": 1}, "volumen"],
	["bola_altura3", {"altura": 3}, "volumen"],
	["flecha_sin_glifos", {"flecha": 1}, "flecha"],
	["flecha_i1", {"flecha": 1, "linea_z": 1}, "flecha"],
	["flecha_i3", {"flecha": 1, "linea_z": 3}, "flecha"],
	["haz_i1", {"linea_z": 1}, "haz"],
	["haz_i3", {"linea_z": 3}, "haz"],
	["muro_barrera_i2", {"barrera": 1, "linea_x": 2}, "volumen"],
]

class MundoFalso extends Node3D:
	var _lado: int = 16
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass

var _vp: SubViewport = null
var _m: MundoFalso = null
var _l: Lanzador3D = null
var _vfx: VfxElemento3D = null
var _cam: Camera3D = null
var _dir: String = "docs/capturas/radio_base"
var _solo: String = "fire"


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if a.size() > 1:
		_solo = a[1]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	var nuevo_factor: float = VfxElemento3D.FACTOR_BOLA_MIN
	var nuevo_escala: float = VfxElemento3D.ESCALA_VOL_MIN
	print("caso | momento | semiejes x·y·z (casillas) | en u (casilla %.2f) | radio de golpe en vuelo u | casillas rasterizadas" % Terreno3D.casilla)
	for antes in [true, false]:
		VfxElemento3D.FACTOR_BOLA_MIN = ANTES_FACTOR_BOLA_MIN if antes else nuevo_factor
		VfxElemento3D.ESCALA_VOL_MIN = ANTES_ESCALA_VOL_MIN if antes else nuevo_escala
		for c in CASOS:
			await _caso(c, antes)
	VfxElemento3D.FACTOR_BOLA_MIN = nuevo_factor
	VfxElemento3D.ESCALA_VOL_MIN = nuevo_escala
	print("capturas en ", _dir)
	quit()


func _montar() -> void:
	for n in [_vfx, _l, _m, _vp]:
		if n != null and is_instance_valid(n):
			n.free()
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	_vp = SubViewport.new()
	_vp.size = TAM
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var filas: PackedStringArray = []
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			f += "#" if (x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1) else "."
		filas.append(f)
	_m = MundoFalso.new()
	_m._mapa = filas
	_vp.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_l = Lanzador3D.new()
	_l.mundo = _m
	_m.add_child(_l)
	_l.fx = Vfx3D.new()
	_m.add_child(_l.fx)
	_vfx = VfxElemento3D.conectar(_l, _m)
	_vfx.casilla = Terreno3D.casilla
	# Suelo, luz y entorno como la maqueta
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 40.0)
	suelo.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.45, 0.62, 0.34)
	suelo.material_override = ms
	var o: Vector3 = Lanzador3D.centro_de(ORIGEN_C, 0.0)
	suelo.position = Vector3(o.x + 6.0, 0.0, o.z)
	_m.add_child(suelo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	sol.light_color = Color(1.0, 0.96, 0.88)
	sol.shadow_enabled = true
	_m.add_child(sol)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.81, 0.91, 0.94)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.94, 1.0)
	e.ambient_light_energy = 0.6
	VfxKit3D.activar_glow(e)
	var we := WorldEnvironment.new()
	we.environment = e
	_m.add_child(we)
	_cam = Camera3D.new()
	_m.add_child(_cam)
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = CAM_TAM_U
	_cam.near = 0.1
	_cam.far = 300.0
	var elev: float = deg_to_rad(CAM_PITCH_GRADOS)
	var d: Vector3 = -Vector3(0.0, sin(elev), cos(elev))
	var mira: Vector3 = Vector3(o.x + 1.6, 0.4, o.z)
	_cam.transform = Transform3D(Basis.looking_at(d, Vector3.UP), mira - d * 40.0)
	_cam.current = true
	# La jugadora, mirando a +X, un poco detrás de la mano
	var pj := Pj3D.new()
	_m.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(1.0)
	pj.position = Vector3(o.x - 0.35, 0.0, o.z)
	pj.rotation.y = PI * 0.5


func _caso(c: Array, antes: bool) -> void:
	var nombre: String = String(c[0])
	var glifos: Dictionary = c[1] as Dictionary
	var tipo: String = String(c[2])
	_montar()
	await _esperar(0.3)
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % _solo) as RuneData
	var h: Hechizo = Hechizo.construir(rune, glifos)
	if antes:
		var tope_h: float = Sigils.TOPE_EJE_HORIZONTAL_V2
		h.semieje_x = minf(ANTES_BASE + ANTES_PASO * float(int(glifos.get("linea_x", 0))), tope_h)
		h.semieje_z = minf(ANTES_BASE + ANTES_PASO * float(int(glifos.get("linea_z", 0))), tope_h)
		h.semieje_y = minf(ANTES_BASE + ANTES_PASO * float(int(glifos.get("altura", 0))), Sigils.TOPE_EJE_ALTURA_V2)
	var o: Vector3 = Lanzador3D.centro_de(ORIGEN_C, Terreno3D.y_pies(ORIGEN_C) + ALTO_MANO_U)
	var casillas: int = _l.lanzar_hechizo(h, o, Vector3.RIGHT)
	var cas: float = Terreno3D.casilla
	var radio_golpe: String = "-"
	for n in _l.get_children():
		if n is HechizoVivo and (n as HechizoVivo).proyectil:
			radio_golpe = "%.3f" % (n as HechizoVivo)._radio_u
	print("%s %s | %s | %.2f·%.2f·%.2f | %.3f·%.3f·%.3f | %s | %d" % [nombre, "ANTES" if antes else "DESPUES", tipo, h.semieje_x, h.semieje_y, h.semieje_z,
		h.semieje_x * cas, h.semieje_y * cas, h.semieje_z * cas, radio_golpe, casillas])
	var t: float = T_VOLUMEN_S if tipo == "volumen" else (T_FLECHA_S if tipo == "flecha" else T_HAZ_S)
	await _esperar(t)
	var ruta: String = "%s/%s_%s.png" % [_dir, nombre, "antes" if antes else "despues"]
	_vp.get_texture().get_image().save_png(ruta)
	print("guardado ", ruta)


func _esperar(s: float) -> void:
	await create_timer(maxf(s, 0.02)).timeout
	await process_frame
