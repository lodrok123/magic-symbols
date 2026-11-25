extends Node3D

## LABORATORIO de los OBJETOS PEQUEÑOS del pack «SH assets» (25/11/2026): atrezo y vegetación, SIN OPTIMIZAR y SIN la casa.
## Carga los 64 `arte/sh_assets/atrezo/sh_*.glb` (los genera tools/exportar_atrezo_sh.py) con la luz, la cámara (ortogonal a 30°)
## y los materiales (Ocluso3D) del juego, a la misma escala que la casa.
## Teclas:  1-5 ir a una categoría del catálogo · P esparcir objetos mezclados (0 · 50 · 150 · 400 · 1000) · V vista juego / lejos
##          L LOD automático sí/no · O sombras sí/no · N nombres sí/no · flechas/WASD mover · rueda o +/- zoom
## Medición automática (necesita ventana; escribe docs/capturas/atrezo_sh/informe.txt y se cierra):
##   Godot --path E:\magic-symbols res://laboratorios/LabAtrezoSH.tscn -- --medir
##   1 · cada objeto por separado: 100 copias, todas a la vista, con y sin LOD.  2 · mezcla de objetos esparcidos como en un pueblo.
## Los números dependen de la máquina y los FPS varían bastante entre pasadas: triángulos y llamadas son exactos.

const CARPETA: String = "res://arte/sh_assets/atrezo/"
const ESCALA: float = 0.68            ## la misma que la casa (y que Lost Cave)
const ORDEN: Array = ["contenedor", "adorno", "ceramica", "piedra", "vegetacion"]
const ZOOM_JUEGO: float = 6.0
const LUZ_AMBIENTE: float = 0.6
const LUZ_SOL: float = 1.0
const COPIAS: int = 100               ## copias por objeto en la medición 1
const MEZCLAS: Array = [0, 50, 150, 400, 1000]
const DENSIDAD: float = 6.0           ## u² de suelo por objeto en la mezcla (un pueblo con bastante atrezo)
const INFORME: String = "res://docs/capturas/atrezo_sh/"

var _datos: Array = []                ## filas de atrezo_sh.json
var _escenas: Dictionary = {}         ## nombre -> PackedScene
var _mats: Dictionary = {}            ## material del glb -> convertido (compartido)
var _cam: Camera3D
var _sol: DirectionalLight3D
var _hud: Label
var _catalogo: Node3D
var _prueba: Node3D
var _rotulos: Array[Label3D] = []
var _filas: Dictionary = {}
var _foco: Vector3 = Vector3.ZERO
var _zoom: float = 14.0
var _mezcla: int = 0
var _lejos: bool = false
var _midiendo: bool = false
var _t_hud: float = 0.0


func _ready() -> void:
	Ocluso3D.preparar()
	_montar_luz()
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.far = 400.0
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
	_catalogo = Node3D.new()
	add_child(_catalogo)
	_prueba = Node3D.new()
	add_child(_prueba)
	if not _cargar_datos():
		return
	_montar_catalogo()
	_ir("contenedor")
	if "--medir" in OS.get_cmdline_user_args():
		_medir.call_deferred()


func _cargar_datos() -> bool:
	var f := FileAccess.open(CARPETA + "atrezo_sh.json", FileAccess.READ)
	if f == null:
		_hud.text = "Faltan los objetos: genera arte/sh_assets/atrezo con tools/exportar_atrezo_sh.py (ver arte/sh_assets/LEEME.md)"
		push_warning(_hud.text)
		return false
	_datos = JSON.parse_string(f.get_as_text())
	for d in _datos:
		_escenas[d["nombre"]] = load(CARPETA + "sh_%s.glb" % d["nombre"]) as PackedScene
	return true


func _montar_luz() -> void:
	var entorno := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.55, 0.62)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.94, 1.0)
	env.ambient_light_energy = LUZ_AMBIENTE
	entorno.environment = env
	Paleta3D.aplicar_ajuste(env)
	VfxKit3D.activar_glow(env)
	Posproceso3D.aplicar_entorno(env, get_viewport())
	add_child(entorno)
	_sol = DirectionalLight3D.new()
	_sol.rotation_degrees = Vector3(-55.0, 25.0, 0.0)
	_sol.light_color = Color(1.0, 0.96, 0.88)
	_sol.light_energy = LUZ_SOL
	_sol.shadow_enabled = true
	_sol.directional_shadow_max_distance = 30.0
	add_child(_sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(400, 400)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.42, 0.52, 0.34)
	sm.roughness = 1.0
	suelo.material_override = Ocluso3D.convertir(sm)
	add_child(suelo)


func _objeto(nombre: String) -> Node3D:
	var n: Node3D = (_escenas[nombre] as PackedScene).instantiate() as Node3D
	n.scale = Vector3.ONE * ESCALA
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in range(m.mesh.get_surface_count()):
			var orig: Material = m.mesh.surface_get_material(s)
			if orig == null:
				continue
			if not _mats.has(orig):
				_mats[orig] = Ocluso3D.convertir(orig)
			m.set_surface_override_material(s, _mats[orig])
	return n


## Catálogo: una fila por categoría (en -Z, lejos de la zona de pruebas), con su nombre y triángulos encima.
func _montar_catalogo() -> void:
	var z: float = -60.0
	for cat in ORDEN:
		_filas[cat] = z
		var x: float = 0.0
		var j := Pj3D.new()
		_catalogo.add_child(j)
		j.cargar("jugadora_base")
		j.set_alto(1.0)
		j.position = Vector3(-1.2, 0.0, z)
		var fondo: float = 0.0
		for d in _datos:
			if d["categoria"] != cat:
				continue
			var ancho: float = float(d["x"]) * ESCALA
			var n: Node3D = _objeto(d["nombre"])
			_catalogo.add_child(n)
			n.position = Vector3(x + ancho * 0.5, 0.0, z)
			var r := Label3D.new()
			r.text = "%s\n%d tris · %d piezas" % [d["nombre"], int(d["triangulos"]), int(d["piezas"])]
			r.font_size = 28
			r.pixel_size = 0.008
			r.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			r.no_depth_test = true
			r.outline_size = 8
			r.modulate = Color(1.0, 0.6, 0.5) if int(d["triangulos"]) > 20000 else Color.WHITE
			r.position = n.position + Vector3(0.0, float(d["z"]) * ESCALA + 0.35, 0.0)
			_catalogo.add_child(r)
			_rotulos.append(r)
			x += maxf(ancho, 0.6) + 0.5
			fondo = maxf(fondo, float(d["y"]) * ESCALA)
		z += fondo + 3.0


func _ir(cat: String) -> void:
	if _filas.has(cat):
		_foco = Vector3(7.0, 0.0, float(_filas[cat]))
		_zoom = 9.0


## n objetos mezclados al azar (todos los del pack con el mismo peso), en un cuadrado con DENSIDAD u² por objeto, centrado en el origen.
func _esparcir(n: int, solo: String = "") -> void:
	for c in _prueba.get_children():
		c.queue_free()
	_mezcla = n
	if n == 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	if solo != "":
		# medición 1: COPIAS de un objeto en rejilla, con hueco según su tamaño
		var d: Dictionary = _fila(solo)
		var paso: float = maxf(float(d["x"]), float(d["y"])) * ESCALA + 0.4
		var lado: int = int(ceil(sqrt(float(n))))
		for i in range(n):
			var o: Node3D = _objeto(solo)
			_prueba.add_child(o)
			o.position = Vector3((float(i % lado) - (lado - 1) * 0.5) * paso, 0.0, (floorf(float(i) / lado) - (lado - 1) * 0.5) * paso)
		_zoom = float(lado) * paso + 2.0
		_foco = Vector3.ZERO
		return
	var lado_u: float = sqrt(float(n) * DENSIDAD)
	for i in range(n):
		var d2: Dictionary = _datos[rng.randi_range(0, _datos.size() - 1)]
		var o2: Node3D = _objeto(d2["nombre"])
		_prueba.add_child(o2)
		o2.position = Vector3(rng.randf_range(-0.5, 0.5) * lado_u, 0.0, rng.randf_range(-0.5, 0.5) * lado_u)
		o2.rotation.y = rng.randf() * TAU
	_foco = Vector3.ZERO
	_zoom = lado_u + 2.0 if _lejos else ZOOM_JUEGO


func _fila(nombre: String) -> Dictionary:
	for d in _datos:
		if d["nombre"] == nombre:
			return d
	return {}


func _process(delta: float) -> void:
	if not _midiendo:
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
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _foco + Vector3(0.0, 0.5, 0.0) - dir * 150.0)
	_t_hud -= delta
	if _t_hud <= 0.0:
		_t_hud = 0.25
		_actualizar_hud()


func _unhandled_input(ev: InputEvent) -> void:
	if _midiendo or _datos.is_empty():
		return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(2.0, _zoom * 0.88)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(160.0, _zoom * 1.14)
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				_ir(ORDEN[ev.keycode - KEY_1])
			KEY_P:
				_esparcir(int(MEZCLAS[(MEZCLAS.find(_mezcla) + 1) % MEZCLAS.size()]))
			KEY_V:
				_lejos = not _lejos
				if _mezcla > 0:
					_zoom = sqrt(float(_mezcla) * DENSIDAD) + 2.0 if _lejos else ZOOM_JUEGO
					_foco = Vector3.ZERO
			KEY_L:
				get_viewport().mesh_lod_threshold = 0.0 if get_viewport().mesh_lod_threshold > 0.0 else 1.0
			KEY_O:
				_sol.shadow_enabled = not _sol.shadow_enabled
			KEY_N:
				for r in _rotulos:
					r.visible = not r.visible
			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
				_zoom = maxf(2.0, _zoom * 0.8)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom = minf(160.0, _zoom * 1.25)


func _actualizar_hud() -> void:
	if _datos.is_empty():
		return
	_hud.text = "Atrezo SH SIN OPTIMIZAR · mezcla %d · vista %s · LOD %s · sombras %s\n" % [_mezcla, "lejos" if _lejos else "juego",
		"sí" if get_viewport().mesh_lod_threshold > 0.0 else "NO", "sí" if _sol.shadow_enabled else "no"] + \
		"FPS %d · llamadas de dibujo %d · triángulos dibujados %d · objetos %d\n" % [Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)] + \
		"1 contenedores · 2 adornos · 3 cerámica · 4 piedra · 5 vegetación · P esparcir · V vista · L LOD · O sombras · N nombres"


# ---------------------------------------------------------------- medición automática

func _medir() -> void:
	_midiendo = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(INFORME))
	var gi := FileAccess.open(INFORME + ".gdignore", FileAccess.WRITE)
	if gi != null:
		gi.close()
	var vp: Viewport = get_viewport()
	# capturas del catálogo (una por categoría), antes de medir
	for cat in ORDEN:
		_ir(cat)
		await _esperar(0.8)
		vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(INFORME + "catalogo_%s.png" % cat))
	_catalogo.visible = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var L: PackedStringArray = []
	L.append("ATREZO SH SIN OPTIMIZAR (sin la casa) · %s · %s · ventana %s · %s" % [Time.get_datetime_string_from_system(),
		RenderingServer.get_video_adapter_name(), str(vp.get_visible_rect().size), RenderingServer.get_current_rendering_method()])
	# 0 · base: escena vacía
	_esparcir(0)
	_foco = Vector3.ZERO
	_zoom = ZOOM_JUEGO
	await _esperar(1.5)
	var b: Array = await _tomar(2.5)
	L.append("BASE (solo suelo) | FPS %.1f | ms %.2f | llamadas %d | triángulos %d" % [b[0], b[1], b[3], b[4]])
	# 1 · cada objeto por separado
	L.append("")
	L.append("1 · CADA OBJETO: %d copias todas a la vista" % COPIAS)
	L.append("objeto | categoría | tris 1 copia | LOD | FPS medio | ms medio | ms p95 | llamadas | triángulos dibujados | objetos")
	for d in _datos:
		_esparcir(COPIAS, d["nombre"])
		for lod in [true, false]:
			vp.mesh_lod_threshold = 1.0 if lod else 0.0
			await _esperar(0.7)
			var r: Array = await _tomar(2.0)
			L.append("%s | %s | %d | %s | %.1f | %.2f | %.2f | %d | %d | %d" % [d["nombre"], d["categoria"], int(d["triangulos"]),
				"sí" if lod else "no", r[0], r[1], r[2], r[3], r[4], r[5]])
			print(L[-1])
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(INFORME + "ultimo_objeto_100.png"))
	# 2 · mezcla esparcida como en un pueblo
	L.append("")
	L.append("2 · MEZCLA: objetos al azar, %.0f u² de suelo por objeto" % DENSIDAD)
	L.append("objetos | vista | LOD | FPS medio | ms medio | ms p95 | llamadas | triángulos dibujados | objetos dibujados")
	for n in MEZCLAS.slice(1):
		for lejos in [false, true]:
			_lejos = lejos
			_esparcir(int(n))
			for lod in [true, false]:
				vp.mesh_lod_threshold = 1.0 if lod else 0.0
				await _esperar(1.0)
				var r2: Array = await _tomar(3.0)
				L.append("%d | %s | %s | %.1f | %.2f | %.2f | %d | %d | %d" % [n, "lejos" if lejos else "juego", "sí" if lod else "no",
					r2[0], r2[1], r2[2], r2[3], r2[4], r2[5]])
				print(L[-1])
				if lod:
					vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(INFORME + "mezcla_%04d_%s.png" % [n, "lejos" if lejos else "juego"]))
	var f := FileAccess.open(INFORME + "informe.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(L) + "\n")
		f.close()
	print("informe: " + ProjectSettings.globalize_path(INFORME + "informe.txt"))
	get_tree().quit()


func _esperar(s: float) -> void:
	var fin: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		await get_tree().process_frame


## [FPS medio, ms medio, ms p95, llamadas, triángulos, objetos] durante s segundos.
func _tomar(s: float) -> Array:
	var tiempos: Array = []
	var llamadas: float = 0.0
	var tris: float = 0.0
	var objetos: float = 0.0
	var inicio: int = Time.get_ticks_usec()
	var previo: int = inicio
	while Time.get_ticks_usec() - inicio < int(s * 1000000.0):
		await get_tree().process_frame
		var ahora: int = Time.get_ticks_usec()
		tiempos.append(float(ahora - previo) / 1000.0)
		previo = ahora
		llamadas += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		tris += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		objetos += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var k: float = float(maxi(tiempos.size(), 1))
	var medio: float = 0.0
	for t in tiempos:
		medio += t
	medio /= k
	tiempos.sort()
	var p95: float = float(tiempos[int(tiempos.size() * 0.95)]) if not tiempos.is_empty() else 0.0
	return [1000.0 / maxf(medio, 0.001), medio, p95, int(llamadas / k), int(tris / k), int(objetos / k)]
