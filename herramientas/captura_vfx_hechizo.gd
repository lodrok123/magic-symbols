extends SceneTree

## MEDIDA Y CAPTURA (Pipeline, 20/10): lanza con el Lanzador3D y el HechizoVivo REALES las 4 recetas (esfera, flecha, barrera, pulso) × los 7 elementos y apunta,
## por celda, lo que sale por las señales y lo que dibuja cada receptor. No es una prueba (la prueba es `prueba_vfx_hechizo.gd`): sirve para mirar.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_vfx_hechizo.gd -- <prefijo> [modo] [elemento]
##   modo: `medir` (solo texto, vale --headless) · `captura` (además un PNG por celda y el montaje)
## Escribe `<prefijo>_<elemento>_<receta>.png` y la tabla por la salida estándar.
## Receptores que monta, como la maqueta: VfxEstado3D (por estado de la materia) y, si existe, VfxElemento3D (por elemento).

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 16
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass

const LADO: int = 16
const ORIGEN_C: Vector2i = Vector2i(5, 8)
const RECETAS: Dictionary = {"esfera": [], "flecha": ["flecha"], "barrera": ["barrera"], "pulso": ["pulso"]}
const ELEMENTOS: Dictionary = {"fuego": "fire", "agua": "water", "tierra": "earth", "viento": "wind", "rayo": "lightning", "hielo": "ice", "tiempo": "time"}

var _m: MundoFalso = null
var _l: Lanzador3D = null
var _jug: Jugador3D = null
var _vp: SubViewport = null
var _cam: Camera3D = null
var _senales: Array = []
var _nombres: Array = []
var _vivos: Array = []
var _estado: VfxEstado3D = null
var _elemento_vfx: Object = null
var _con_estado: bool = false


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var pref: String = a[0] if a.size() > 0 else "/tmp/cap/hechizo"
	var modo: String = a[1] if a.size() > 1 else "medir"
	var solo: String = a[2] if a.size() > 2 else ""
	_con_estado = a.size() > 3 and a[3] == "estado"
	var con_img: bool = modo == "captura"
	await process_frame
	if con_img:
		_vp = SubViewport.new()
		_vp.size = Vector2i(720, 440)
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(_vp)
	print("elemento | receta | señales (estado, x·y·z casillas, celdas, viaja, vida_total, props) | HechizoVivo hijos | vfx_hechizo | VfxEstado3D | VfxElemento3D")
	for el in ELEMENTOS:
		if solo != "" and el != solo:
			continue
		for nombre in RECETAS:
			await _celda(pref, el, nombre, con_img)
	quit()


func _montar() -> void:
	for n in [_l, _m, _jug]:
		if n != null and is_instance_valid(n):
			n.free()
	if _estado != null and is_instance_valid(_estado):
		_estado.free()
	if _elemento_vfx != null and is_instance_valid(_elemento_vfx):
		_elemento_vfx.free()
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
	var padre: Node = _vp if _vp != null else root
	padre.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(LADO):
		for x in range(LADO):
			if filas[y][x] == "#":
				_m._bloqueadas[Vector2i(x, y)] = true
	_jug = Jugador3D.new()
	_m.add_child(_jug)
	_jug.position = Lanzador3D.centro_de(Vector2i(13, 13), 1.0)
	_l = Lanzador3D.new()
	_l.mundo = _m
	_l.jugador = _jug
	_m.add_child(_l)
	_l.fx = _montar_fx()
	_senales.clear()
	_nombres.clear()
	_vivos.clear()
	_l.hechizo_v2.connect(func(estado: String, el: String, g: Dictionary, o: Vector3, d: Vector3, props: Dictionary) -> void: _senales.append([estado, el, g, o, d, props]))
	_l.vfx_hechizo.connect(func(nombre: String, p: Vector3, el: String) -> void: _nombres.append([nombre, p, el]))
	_l.child_entered_tree.connect(func(n: Node) -> void:
		if n is HechizoVivo:
			_vivos.append(weakref(n)))
	_estado = VfxEstado3D.conectar(_l, _m)
	_estado.encendido = _con_estado     # argumento 4 de la línea de órdenes: `estado` enciende VfxEstado3D (por defecto, apagado como en la maqueta)
	_estado.casilla = Terreno3D.casilla
	_estado.alto_nivel = Terreno3D.ALTO_NIVEL
	_estado.y_pies = func(c: Vector2i) -> float: return Terreno3D.y_pies(c)
	var cls: Variant = load("res://presentacion/vfx_elemento_3d.gd") if ResourceLoader.exists("res://presentacion/vfx_elemento_3d.gd") else null
	if cls != null:
		_elemento_vfx = cls.call("conectar", _l, _m)


func _montar_fx() -> Vfx3D:
	var fx := Vfx3D.new()
	_m.add_child(fx)
	return fx


func _suelo_y_camara() -> void:
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 40.0)
	suelo.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.32, 0.40, 0.28)
	suelo.material_override = ms
	suelo.position = Vector3(Lanzador3D.centro_de(ORIGEN_C, 0.0).x + 6.0, 0.0, Lanzador3D.centro_de(ORIGEN_C, 0.0).z)
	_m.add_child(suelo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	_m.add_child(sol)
	_cam = Camera3D.new()
	_cam.fov = 48.0
	_m.add_child(_cam)
	var o: Vector3 = Lanzador3D.centro_de(ORIGEN_C, 0.0)
	_cam.look_at_from_position(Vector3(o.x + 4.5, 6.5, o.z + 9.5), Vector3(o.x + 4.5, 0.9, o.z), Vector3.UP)
	_cam.current = true
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_m.add_child(we)


func _receta(glifos: Array) -> Lanzador3D.Receta3D:
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for gl in glifos:
		r.apply(String(gl))
	return r


func _celda(pref: String, el: String, nombre: String, con_img: bool) -> void:
	_montar()
	if con_img:
		_suelo_y_camara()
	await process_frame
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % ELEMENTOS[el])
	var origen: Vector3 = Lanzador3D.centro_de(ORIGEN_C, 0.0)
	var n: int = _l._materializar(_receta(RECETAS[nombre]), rune, origen, Vector3.RIGHT)
	var pico_luces: int = 0
	var pico_part: int = 0
	var pico_dib: int = 0
	var pico_proy: int = 0
	var t_img: Array = [0.3, 1.1]
	var k: int = 0
	var t0: float = Time.get_ticks_msec() / 1000.0
	while Time.get_ticks_msec() / 1000.0 - t0 < 1.3:
		await process_frame
		var luces: int = 0
		var part: int = 0
		var pila: Array = [_m]
		while not pila.is_empty():
			var nd: Node = pila.pop_back()
			if nd is Light3D and (nd as Light3D).visible and not (nd is DirectionalLight3D):
				luces += 1
			if nd is GPUParticles3D and (nd as GPUParticles3D).emitting:
				part += (nd as GPUParticles3D).amount
			if nd is MultiMeshInstance3D:
				part += (nd as MultiMeshInstance3D).multimesh.instance_count
			pila.append_array(nd.get_children())
		pico_luces = maxi(pico_luces, luces)
		pico_dib = maxi(pico_dib, _estado.activos())
		pico_proy = maxi(pico_proy, _estado.proyectiles())
		pico_part = maxi(pico_part, part)
		if con_img and k < t_img.size() and Time.get_ticks_msec() / 1000.0 - t0 >= float(t_img[k]):
			if OS.get_environment("VOLCAR") != "":
				_volcar(_m, 0)
			_vp.get_texture().get_image().save_png("%s_%s_%s_%d.png" % [pref, el, nombre, k])
			k += 1
	var sen: String = "ninguna"
	if not _senales.is_empty():
		var s: Array = _senales[0]
		var g: Dictionary = s[2]
		sen = "%dx %s/%s %.2f·%.2f·%.2f celdas %d viaja %s vida %.2f props %s" % [_senales.size(), s[0], s[1], float(g["x"]), float(g["y"]), float(g["z"]), (g["celdas"] as Array).size(), str(g.get("viaja", false)), float(g.get("vida_total", 0.0)), str((s[5] as Dictionary).keys())]
	var hv: String = "0"
	if not _vivos.is_empty():
		var h0: Variant = _vivos[0].get_ref()
		if h0 != null and is_instance_valid(h0):
			hv = "%d (velocidad %.1f)" % [_vivos.size(), (h0 as HechizoVivo).h.velocidad]
		else:
			hv = "%d (ya liberado)" % _vivos.size()
	var nom: String = str(_nombres.size()) if _nombres.is_empty() else str(_nombres.map(func(x: Array) -> String: return String(x[0])))
	var est: String = "pico %d dibujos · %d proy" % [pico_dib, pico_proy]
	var elv: String = "sin receptor"
	if _elemento_vfx != null and is_instance_valid(_elemento_vfx):
		elv = str(_elemento_vfx.call("resumen"))
	print("%s | %s | casillas %d | %s | %s | %s | %s | %s | pico %d luces %d partículas" % [el, nombre, n, sen, hv, nom, est, elv, pico_luces, pico_part])


func _volcar(n: Node, nivel: int) -> void:
	if nivel > 0 or n.name == "VfxElemento":
		pass
	for c in n.get_children():
		if c.name == "VfxElemento" or c.name == "VfxElementoProyectil":
			_arbol(c, 0)
		else:
			_volcar(c, nivel + 1)


func _arbol(n: Node, d: int) -> void:
	var extra: String = ""
	if n is Node3D:
		extra = " pos=%s vis=%s" % [str((n as Node3D).global_position), str((n as Node3D).visible)]
	if n is GeometryInstance3D:
		extra += " mat=%s" % str((n as GeometryInstance3D).material_override)
	print("  ".repeat(d), n.name, " (", n.get_class(), ")", extra)
	if d < 3:
		for c in n.get_children():
			_arbol(c, d + 1)
