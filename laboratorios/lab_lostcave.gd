extends Node3D

## LABORATORIO del pack «Stylized Lost Cave» (24/11/2026): TODAS las piezas `arte/lostcave/piezas/lost_*.tscn` a su escala real, en filas por
## categoría (estructura, mina, atrezo, cristal, vegetación, calcas), con su nombre encima y la jugadora (1 u) al principio de cada fila.
## El material pasa por Ocluso3D.convertir, como al cargar una pieza en la maqueta: se ven como en el juego. Cámara ortogonal a 30° sobre el suelo.
## Teclas:  flechas / WASD mover · rueda o +/- zoom · 1-6 saltar a una categoría · L luz de día / cueva oscura (para ver lo que brilla)
##          N nombres sí/no
## Si no hay piezas: falta generarlas con  tools\preparar_lostcave.cmd  (no viajan en git; ver arte/lostcave/LEEME.md).

const T = preload("res://arte/lostcave/tabla_lostcave.gd")
const ORDEN: Array = ["estructura", "mina", "atrezo", "cristal", "vegetacion", "calca"]
const HUECO: float = 1.2          ## u entre pieza y pieza
const ANCHO_FILA: float = 70.0    ## u: más largo, la fila salta a otra
const ENTRE_FILAS: float = 4.0
const S: float = 2.3

var _cam: Camera3D
var _foco: Vector3 = Vector3.ZERO
var _zoom: float = 32.0
var _filas: Dictionary = {}       ## categoría -> z de su primera fila
var _sol: DirectionalLight3D
var _entorno: Environment
var _oscuro: bool = false
var _rotulos: Array[Label3D] = []
var _hud: Label


func _ready() -> void:
	Ocluso3D.preparar()
	_montar_luz()
	_montar_piezas()
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.far = 600.0
	_cam.current = true
	add_child(_cam)
	_hud = Label.new()
	_hud.position = Vector2(12, 10)
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	var capa := CanvasLayer.new()
	add_child(capa)
	capa.add_child(_hud)
	_ir("estructura")
	_actualizar_hud()


func _montar_luz() -> void:
	var e := WorldEnvironment.new()
	_entorno = Environment.new()
	_entorno.background_mode = Environment.BG_COLOR
	_entorno.background_color = Color(0.16, 0.17, 0.2)
	_entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_entorno.ambient_light_color = Color(0.75, 0.75, 0.8)
	_entorno.ambient_light_energy = 0.7
	_entorno.glow_enabled = true
	Paleta3D.aplicar_ajuste(_entorno)
	e.environment = _entorno
	add_child(e)
	_sol = DirectionalLight3D.new()
	_sol.rotation_degrees = Vector3(-50, 35, 0)
	_sol.light_energy = 1.1
	_sol.shadow_enabled = true
	add_child(_sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(400, 400)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.36, 0.31, 0.26)
	sm.roughness = 1.0
	suelo.material_override = sm
	suelo.position = Vector3(100, 0, -100)
	add_child(suelo)


func _montar_piezas() -> void:
	var por_cat: Dictionary = {}
	if not DirAccess.dir_exists_absolute(T.CARPETA_PIEZAS):
		push_warning("LabLostCave: no hay piezas en %s (genera con tools\\preparar_lostcave.cmd)" % T.CARPETA_PIEZAS)
		return
	var ficheros: PackedStringArray = DirAccess.get_files_at(T.CARPETA_PIEZAS)
	ficheros.sort()
	for f in ficheros:
		if f.begins_with(T.PREFIJO) and f.ends_with(".tscn"):
			var n: Node3D = (load(T.CARPETA_PIEZAS + f) as PackedScene).instantiate() as Node3D
			var cat: String = String(n.get_meta("categoria", "otra"))
			if not por_cat.has(cat):
				por_cat[cat] = []
			(por_cat[cat] as Array).append(n)
	var z: float = 0.0
	for cat in ORDEN:
		if not por_cat.has(cat):
			continue
		_filas[cat] = z
		var x: float = 0.0
		var fondo_fila: float = 0.0
		_jugadora(Vector3(-1.5, 0, z))
		for n in por_cat[cat]:
			var pieza: Node3D = n
			var caja: AABB = _caja(pieza)
			if x > 0.0 and x + caja.size.x > ANCHO_FILA:
				z -= fondo_fila + ENTRE_FILAS
				x = 0.0
				fondo_fila = 0.0
				_jugadora(Vector3(-1.5, 0, z))
			add_child(pieza)
			pieza.position = Vector3(x + caja.size.x * 0.5, 0.0, z)
			if cat == "calca":
				pieza.position.y = 1.2
				_pared(pieza.position)
			_convertir(pieza)
			_rotulo(pieza, caja)
			x += caja.size.x + HUECO
			fondo_fila = maxf(fondo_fila, caja.size.z)
		z -= fondo_fila + ENTRE_FILAS * 2.0


func _caja(pieza: Node3D) -> AABB:
	if pieza.has_node("modelo/malla"):
		var m: MeshInstance3D = pieza.get_node("modelo/malla") as MeshInstance3D
		return m.transform * m.mesh.get_aabb()
	return AABB(Vector3(-T.CALCA_LADO * 0.5, 0, -0.1), Vector3(T.CALCA_LADO, T.CALCA_LADO, 0.2))


func _convertir(pieza: Node3D) -> void:
	for mi in pieza.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in range(m.mesh.get_surface_count()):
			var mat: Material = m.get_surface_override_material(s)
			if mat != null:
				m.set_surface_override_material(s, Ocluso3D.convertir(mat.duplicate() as Material))


func _rotulo(pieza: Node3D, caja: AABB) -> void:
	var r := Label3D.new()
	r.text = "%s\n%.1f x %.1f cas · %d tris" % [String(pieza.name).trim_prefix(T.PREFIJO), maxf(caja.size.x, caja.size.z) / S, caja.size.y / S,
		int(pieza.get_meta("triangulos", 0))]
	r.font_size = 32
	r.pixel_size = 0.014
	r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	r.no_depth_test = true
	r.outline_size = 8
	r.position = pieza.position + Vector3(0, caja.size.y + 0.4 + (1.2 if pieza.get_meta("categoria", "") == "calca" else 0.0), 0)
	add_child(r)
	_rotulos.append(r)


func _jugadora(pos: Vector3) -> void:
	var j := Pj3D.new()
	add_child(j)
	j.cargar("jugadora_base")
	j.set_alto(1.0)
	j.position = pos


func _pared(pos: Vector3) -> void:
	var p := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(2.4, 3.0, 0.2)
	p.mesh = bx
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.55, 0.53, 0.5)
	p.material_override = pm
	p.position = Vector3(pos.x, 1.5, pos.z - 0.2)
	add_child(p)


func _ir(cat: String) -> void:
	if _filas.has(cat):
		_foco = Vector3(ANCHO_FILA * 0.35, 0.0, float(_filas[cat]) - 2.0)


func _process(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		v.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		v.z -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		v.z += 1
	_foco += v * delta * _zoom * 0.9
	_cam.size = _zoom
	var e: float = deg_to_rad(30.0)
	var dir: Vector3 = -Vector3(0.0, sin(e), cos(e))
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _foco - dir * 200.0)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(4.0, _zoom * 0.88)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(160.0, _zoom * 1.14)
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
				_zoom = maxf(4.0, _zoom * 0.8)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom = minf(160.0, _zoom * 1.25)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				_ir(ORDEN[ev.keycode - KEY_1])
			KEY_L:
				_oscuro = not _oscuro
				_sol.light_energy = 0.15 if _oscuro else 1.1
				_entorno.ambient_light_energy = 0.12 if _oscuro else 0.7
			KEY_N:
				for r in _rotulos:
					r.visible = not r.visible
		_actualizar_hud()


func _actualizar_hud() -> void:
	_hud.text = "Stylized Lost Cave · 1 estructura · 2 mina · 3 atrezo · 4 cristal · 5 vegetación · 6 calcas\n" + \
		"flechas/WASD mover · rueda o +/- zoom · L luz %s · N nombres" % ("cueva" if _oscuro else "día")
