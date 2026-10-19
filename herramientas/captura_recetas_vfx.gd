extends SceneTree

## SOLO CAPTURA (Pipeline, 19/10, entrada 189): las SEIS recetas reales del juego dibujadas por VfxEstado3D con las piezas del kit, para MIRAR cómo quedan (no prueba nada;
## la prueba es `prueba_vfx_v2.gd`), y, en otra imagen, el ARTE VALIDADO del kit (bola, impacto, muro y cúpula de fuego; bola y ola de agua) como referencia.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_recetas_vfx.gd -- <prefijo> [recetas|kit] [ancho alto]
## Escribe `<prefijo>_recetas_<momento>.png` / `<prefijo>_kit.png`. Recetas (los valores del Hechizo.construir real):
##   bola_fuego   plasma  proyectil vel 1,739 · persiste 3        flecha_hielo  sólido  3 copias · persiste 6 · grav 1 (proyectiles)
##   muro_tierra  sólido  semi (0,7 · 0,25 · 0,25) · persiste 8   barrera_agua  líquido semi (0,55 · 0,25 · 0,4) · solidez 1,5 · grav 0,5
##   pilar_rayo   energía semi (0,25 · 0,7 · 0,25) · persiste 0,2  onda_viento   gas     semi (0,4 · 0,25 · 0,25) · crece 0,5 · persiste 1,5
class FalsoLanzador:
	extends Node
	signal hechizo_v2(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary)
	signal vfx_hechizo(nombre: String, posicion: Vector3, elemento: String)

const CAS: float = 2.3
var _vp: SubViewport
var _vivos: Array = []

func _initialize() -> void:
	_correr()

func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var pref: String = a[0] if a.size() > 0 else "/tmp/cap"
	var modo: String = a[1] if a.size() > 1 else "recetas"
	var tam := Vector2i(int(a[2]) if a.size() > 3 else 1600, int(a[3]) if a.size() > 3 else 640)
	_vp = SubViewport.new()
	_vp.size = tam
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.18)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	_vp.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(140.0, 60.0)
	suelo.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.30, 0.38, 0.27)
	suelo.material_override = ms
	_vp.add_child(suelo)
	var cam := Camera3D.new()
	cam.fov = 46.0
	_vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 11.0, 26.0), Vector3(0.0, 1.6, 0.0), Vector3.UP)
	cam.current = true
	var mundo := Node3D.new()
	_vp.add_child(mundo)
	await process_frame
	await process_frame
	if modo == "kit":
		_kit(mundo)
		for m in [0.5]:
			await create_timer(float(m)).timeout
			_vp.get_texture().get_image().save_png("%s_kit.png" % pref)
			print("capturado ", pref, "_kit.png")
		quit()
		return
	var l := FalsoLanzador.new()
	mundo.add_child(l)
	var vfx: VfxEstado3D = VfxEstado3D.conectar(l, mundo)
	await process_frame
	var x0: float = -20.0
	var sep: float = 8.0
	# 1. bola de fuego: un proyectil que avanza hacia la cámara de lado (a lo largo de +Z)
	_proyectil(l, "plasma", "fuego", 5.0, Vector3(x0, 1.2, -6.0), 0.18)
	# 2. flecha de hielo ×3
	for i in 3:
		_proyectil(l, "solido", "hielo", 6.0, Vector3(x0 + sep + (float(i) - 1.0) * 2.0, 1.2, -6.0), 0.15)
	# 3.-6. volúmenes quietos
	var pos := Vector3(x0 + sep * 2.0, 0.0, 0.0)
	_v2(l, "solido", "tierra", {"x": 0.7, "y": 0.25, "z": 0.25, "niveles": 1}, pos, {}, 8.0)
	_v2(l, "liquido", "agua", {"x": 0.55, "y": 0.25, "z": 0.4, "niveles": 1, "gravedad": 0.5}, pos + Vector3(sep, 0.0, 0.0), {"solidez": 1.5}, 0.0)
	_v2(l, "energia", "rayo", {"x": 0.25, "y": 0.7, "z": 0.25, "niveles": 1}, pos + Vector3(sep * 2.0, 0.0, 0.0), {}, 0.2)
	_v2(l, "gas", "viento", {"x": 0.4, "y": 0.25, "z": 0.25, "niveles": 1}, pos + Vector3(sep * 3.0, 0.0, 0.0), {"crece": 0.5}, 1.5)
	get_root().get_tree().process_frame.connect(_mover)
	var previo: float = 0.0
	for m in [0.15, 0.45, 0.9, 1.6]:
		await create_timer(float(m) - previo).timeout
		previo = float(m)
		var ruta: String = "%s_recetas_%s.png" % [pref, ("%.2f" % m).replace(".", "")]
		_vp.get_texture().get_image().save_png(ruta)
		print("capturado ", ruta)
	quit()

func _mover() -> void:
	for hv in _vivos:
		if is_instance_valid(hv):
			(hv as Node3D).global_position += Vector3(0.0, 0.0, 5.0 / 60.0)
			(hv as HechizoVivo).v = Vector3(0.0, 0.0, 5.0)

func _proyectil(l: FalsoLanzador, estado: String, elemento: String, velocidad: float, pos: Vector3, semieje: float) -> void:
	var hv := HechizoVivo.new()
	hv.set_physics_process(false)
	hv.h = Hechizo.new()
	hv.h.velocidad = velocidad
	hv.h.semieje_x = semieje
	hv.h.semieje_y = semieje
	hv.h.semieje_z = semieje
	hv.estado = estado
	hv.elemento = elemento
	hv.activo = true
	hv.proyectil = true
	hv.v = Vector3(0.0, 0.0, velocidad)
	l.add_child(hv)
	hv.global_position = pos
	_vivos.append(hv)

func _v2(l: FalsoLanzador, estado: String, elemento: String, vol: Dictionary, pos: Vector3, props: Dictionary, persiste: float) -> void:
	var g: Dictionary = vol.duplicate()
	g["props"] = props
	g["suelo"] = 0.0
	g["persiste"] = persiste
	g["t_caida"] = (0.4 + 0.07 * float(g["y"])) if estado == "liquido" else 0.0
	g["eventos"] = [{"t": 0.0, "pos": Vector2(pos.x, pos.z), "dir": Vector2(0.0, 1.0)}]
	var celdas: Array = []
	if estado == "solido":
		var c0 := Vector2i(int(floorf(pos.x / CAS)), int(floorf(pos.z / CAS)))
		for dx in range(-1, 2):
			celdas.append(Vector2i(c0.x + dx, c0.y))
	g["celdas"] = celdas
	l.hechizo_v2.emit(estado, elemento, g, pos, Vector3(0.0, 0.0, 1.0), props)

## El arte validado del kit, tal cual lo usa el Vfx3D: fuego (bola, impacto, muro, cúpula) y agua (bola, ola).
func _kit(mundo: Node3D) -> void:
	VfxKit3D.precalentar(mundo)
	var x: float = -20.0
	VfxKit3D.elemento = "fuego"
	var cab := Node3D.new()
	cab.position = Vector3(x, 1.3, 0.0)
	mundo.add_child(cab)
	VfxKit3D.bola(cab, Vector3(0.0, 0.0, 1.0), 1.0, 1.0, 7.0)
	VfxKit3D.impacto(mundo, Vector3(x + 5.0, 0.0, 0.0), 0.0, 1.0, 5.0)
	VfxKit3D.muro(mundo, Vector3(x + 10.0, 1.0, 6.0), Vector3(x + 10.0, 0.0, 0.0), Vector3.RIGHT, 4.0, 3.0, 6.0, 1.0)
	VfxKit3D.cupula(mundo, Vector3(x + 16.0, 0.0, 0.0), 2.6, 6.0, 1.0)
	VfxKit3D.elemento = "agua"
	var cab2 := Node3D.new()
	cab2.position = Vector3(x + 22.0, 1.3, 0.0)
	mundo.add_child(cab2)
	VfxKit3D.bola(cab2, Vector3(0.0, 0.0, 1.0), 1.0, 1.0, 7.0)
	VfxKit3D.muro(mundo, Vector3(x + 27.0, 1.0, 6.0), Vector3(x + 28.0, 0.0, 0.0), Vector3.RIGHT, 4.0, 3.0, 6.0, 1.0)
	VfxKit3D.elemento = "fuego"
