extends Node3D

## LABORATORIO de RENDIMIENTO de las casas del pack «SH assets» (25/11/2026).
## Carga `arte/sh_assets/casa_sh_sin_optimizar.glb` (una casa montada con las piezas del pack TAL CUAL: 1,68 M triángulos,
## 391 objetos, 21 materiales; la genera tools/montar_casa_sh.py) y la repite en rejilla para ver cuánto cuesta.
## Luz, entorno, cámara (ortogonal a 30° sobre el suelo, tamaño 6) y materiales (Ocluso3D) como en el juego.
## Variantes (tecla T): sin optimizar · diezmada al 50 % (piezas sueltas) · diezmada al 50 % y unida en un objeto.
## Teclas:  1-6 número de casas (0 · 1 · 4 · 9 · 16 · 25) · T variante · V vista del juego / todas las casas a la vista
##          L LOD automático de Godot sí/no · O sombras del sol sí/no · flechas/WASD mover · rueda o +/- zoom
## Medición automática de las 3 variantes (necesita ventana; escribe docs/capturas/casas_sh/comparativa.txt y una captura
## de cada variante, y se cierra):
##   Godot --path E:\magic-symbols res://laboratorios/LabCasasSH.tscn -- --medir
## Los números dependen de la máquina: sirven para comparar en la MISMA máquina.

const VARIANTES: Array = [
	["sin optimizar", "res://arte/sh_assets/casa_sh_sin_optimizar.glb"],
	["diezmada 50%", "res://arte/sh_assets/casa_sh_d50.glb"],
	["diezmada 50% + unida", "res://arte/sh_assets/casa_sh_d50_unida.glb"],
]
const CANTIDADES_MEDIR: Array = [1, 9, 25]
const ESCALA: float = 0.68            ## la misma que se usó con Lost Cave (un carro de 1,8 m queda en 1,22 u)
const SEPARACION: float = 9.0         ## u entre centros de casa (la casa mide unos 5,4 × 2,7 u en planta)
const CANTIDADES: Array = [0, 1, 4, 9, 16, 25]
const ZOOM_JUEGO: float = 6.0         ## ZOOM_INICIAL de prueba_test2.gd
const LUZ_AMBIENTE: float = 0.6       ## como prueba_test2.gd
const LUZ_SOL: float = 1.0
const CARPETA_INFORME: String = "res://docs/capturas/casas_sh/"

var _casa: PackedScene
var _variante: int = 0
var _escenas: Dictionary = {}         ## variante -> PackedScene ya cargada
var _cam: Camera3D
var _sol: DirectionalLight3D
var _hud: Label
var _casas: Node3D
var _foco: Vector3 = Vector3.ZERO
var _zoom: float = ZOOM_JUEGO
var _n: int = 1
var _vista_todas: bool = false
var _mats: Dictionary = {}            ## material del glb -> material convertido (uno por material, compartido por todas las casas)
var _t_hud: float = 0.0
var _midiendo: bool = false


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
	_casas = Node3D.new()
	_casas.name = "Casas"
	add_child(_casas)
	for v in VARIANTES:
		if not ResourceLoader.exists(String(v[1])):
			_hud.text = "Falta %s\nGenérala con tools/montar_casa_sh.py (ver arte/sh_assets/LEEME.md)" % v[1]
			push_warning(_hud.text)
			return
	_cargar_variante(0)
	_poner_casas(1)
	if "--medir" in OS.get_cmdline_user_args():
		_medir.call_deferred()


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
	pl.size = Vector2(300, 300)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.42, 0.52, 0.34)
	sm.roughness = 1.0
	suelo.material_override = Ocluso3D.convertir(sm)
	add_child(suelo)


## Carga la variante (la primera vez) y devuelve cuántos ms tardó en cargar; 0 si ya estaba cargada.
func _cargar_variante(v: int) -> float:
	_variante = v
	var ms: float = 0.0
	if not _escenas.has(v):
		var t0: int = Time.get_ticks_usec()
		_escenas[v] = ResourceLoader.load(String(VARIANTES[v][1]), "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene   # carga real, sin caché
		ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_casa = _escenas[v]
	return ms


## Rejilla de n casas centrada en el origen, con la jugadora delante de la casa central como referencia de tamaño.
func _poner_casas(n: int) -> void:
	_n = n
	for c in _casas.get_children():
		c.queue_free()
	var lado: int = int(ceil(sqrt(float(n))))
	var inicio: float = -float(lado - 1) * SEPARACION * 0.5
	for i in range(n):
		var casa: Node3D = _casa.instantiate() as Node3D
		casa.scale = Vector3.ONE * ESCALA
		# en Blender la casa ocupa x 0..8 y fondo 0..4 m con la fachada a -Y: aquí queda centrada y mirando a +Z (a la cámara)
		casa.position = Vector3(inicio + (i % lado) * SEPARACION, 0.0, inicio + floorf(float(i) / float(lado)) * SEPARACION) + Vector3(-4.0, 0.0, 2.0) * ESCALA
		_casas.add_child(casa)
		_convertir(casa)
	var j := Pj3D.new()
	_casas.add_child(j)
	j.cargar("jugadora_base")
	j.set_alto(1.0)
	j.position = Vector3(0.0, 0.0, 2.2)
	_ajustar_vista()


func _convertir(raiz: Node) -> void:
	for mi in raiz.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in range(m.mesh.get_surface_count()):
			var orig: Material = m.mesh.surface_get_material(s)
			if orig == null:
				continue
			if not _mats.has(orig):
				_mats[orig] = Ocluso3D.convertir(orig)
			m.set_surface_override_material(s, _mats[orig])


func _ajustar_vista() -> void:
	_foco = Vector3.ZERO
	if _vista_todas:
		var lado: int = maxi(1, int(ceil(sqrt(float(_n)))))
		_zoom = float(lado) * SEPARACION + 4.0
	else:
		_zoom = ZOOM_JUEGO


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
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), _foco + Vector3(0.0, 1.0, 0.0) - dir * 150.0)
	_t_hud -= delta
	if _t_hud <= 0.0:
		_t_hud = 0.25
		_actualizar_hud()


func _unhandled_input(ev: InputEvent) -> void:
	if _midiendo or _casa == null:
		return
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = maxf(2.0, _zoom * 0.88)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = minf(120.0, _zoom * 1.14)
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				_poner_casas(int(CANTIDADES[ev.keycode - KEY_1]))
			KEY_T:
				_cargar_variante((_variante + 1) % VARIANTES.size())
				_poner_casas(_n)
			KEY_V:
				_vista_todas = not _vista_todas
				_ajustar_vista()
			KEY_L:
				get_viewport().mesh_lod_threshold = 0.0 if get_viewport().mesh_lod_threshold > 0.0 else 1.0
			KEY_O:
				_sol.shadow_enabled = not _sol.shadow_enabled
			KEY_PLUS, KEY_KP_ADD, KEY_EQUAL:
				_zoom = maxf(2.0, _zoom * 0.8)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom = minf(120.0, _zoom * 1.25)


func _actualizar_hud() -> void:
	if _casa == null:
		return
	var mb: float = 1024.0 * 1024.0
	_hud.text = "Casas SH: %s · %d casa(s) · vista %s · LOD %s · sombras %s\n" % [String(VARIANTES[_variante][0]).to_upper(), _n, "todas" if _vista_todas else "juego",
		"sí" if get_viewport().mesh_lod_threshold > 0.0 else "NO", "sí" if _sol.shadow_enabled else "no"] + \
		"FPS %d · llamadas de dibujo %d · triángulos dibujados %d · objetos %d · VRAM %.0f MB\n" % [Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / mb] + \
		"1-6 casas (0/1/4/9/16/25) · T variante · V vista · L LOD · O sombras · WASD mover · rueda zoom"


# ---------------------------------------------------------------- medición automática

func _medir() -> void:
	_midiendo = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CARPETA_INFORME))
	var gi := FileAccess.open(CARPETA_INFORME + ".gdignore", FileAccess.WRITE)
	if gi != null:
		gi.close()
	var lineas: PackedStringArray = []
	var vp: Viewport = get_viewport()
	lineas.append("CASAS SH: COMPARATIVA DE VARIANTES · %s · %s · ventana %s · %s" % [Time.get_datetime_string_from_system(),
		RenderingServer.get_video_adapter_name(), str(vp.get_visible_rect().size), RenderingServer.get_current_rendering_method()])
	print(lineas[0])
	# 1 · carga: ms que tarda load() la primera vez (el .glb ya importado por Godot)
	lineas.append("")
	lineas.append("variante | carga ms")
	for v in range(VARIANTES.size()):
		_escenas.erase(v)
		var ms: float = _cargar_variante(v)
		lineas.append("%s | %.0f" % [VARIANTES[v][0], ms])
		print(lineas[-1])
	# 2 · rendimiento
	lineas.append("")
	lineas.append("variante | casas | vista | LOD | FPS medio | ms medio | ms p95 | llamadas | triángulos dibujados | objetos | VRAM MB")
	for v in range(VARIANTES.size()):
		_cargar_variante(v)
		for n in CANTIDADES_MEDIR:
			_poner_casas(int(n))
			for vista in [false, true]:
				if int(n) <= 1 and vista:
					continue          # con 1 casa las dos vistas son casi la misma
				_vista_todas = vista
				_ajustar_vista()
				for lod in [true, false]:
					vp.mesh_lod_threshold = 1.0 if lod else 0.0
					await _esperar(1.2)
					var r: Array = await _tomar(3.0)
					var fila: String = "%s | %d | %s | %s | %.1f | %.2f | %.2f | %d | %d | %d | %.0f" % [VARIANTES[v][0], n, "todas" if vista else "juego",
						"sí" if lod else "no", r[0], r[1], r[2], r[3], r[4], r[5], r[6]]
					lineas.append(fila)
					print(fila)
					if lod and int(n) == 1:
						vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(CARPETA_INFORME + "variante_%d_1casa.png" % v))
	var f := FileAccess.open(CARPETA_INFORME + "comparativa.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lineas) + "\n")
		f.close()
	print("informe: " + ProjectSettings.globalize_path(CARPETA_INFORME + "comparativa.txt"))
	get_tree().quit()


func _esperar(s: float) -> void:
	var fin: int = Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < fin:
		await get_tree().process_frame


## [FPS medio, ms medio, ms p95, llamadas, triángulos, objetos, VRAM MB] durante s segundos.
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
	return [1000.0 / maxf(medio, 0.001), medio, p95, int(llamadas / k), int(tris / k), int(objetos / k),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / (1024.0 * 1024.0)]
