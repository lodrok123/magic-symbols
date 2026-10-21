extends SceneTree

## CAPTURA (22/10): remolino y tornado de viento ANTES (`remolino_mascara = false`) y DESPUÉS (true) con la CÁMARA DEL JUEGO (ortogonal, 60° de inclinación, zoom 6).
## Necesita ventana (sin --headless):
##   godot --path . --fixed-fps 30 --script res://herramientas/captura_viento_mascara.gd -- docs/capturas/viento_mascara
## Escribe remolino_<antes|despues>_<t>.png y tornado_<antes|despues>.png

var _vp: SubViewport = null
var _mundo: Node3D = null
var _cam: Camera3D = null
var _dir: String = "docs/capturas/viento_mascara"


func _initialize() -> void:
	_correr()


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1000, 620)
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = 6.0
	_vp.add_child(_cam)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55, 25, 0)
	luz.shadow_enabled = true
	_vp.add_child(luz)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.6, 0.68)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	var we := WorldEnvironment.new()
	we.environment = e
	_vp.add_child(we)
	_mundo = Node3D.new()
	_vp.add_child(_mundo)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 30)
	suelo.mesh = pm
	var ms := StandardMaterial3D.new()
	ms.albedo_color = Color(0.45, 0.62, 0.34)
	suelo.material_override = ms
	_mundo.add_child(suelo)
	VfxViento.usar_atlas = true
	await _esperar(0.3)
	for modo in ["antes", "despues"]:
		VfxViento.remolino_mascara = (modo == "despues")
		_camara(Vector3(0.0, 1.0, 0.0))
		seed(7)
		_con_viento(func() -> void: VfxViento.remolino(_mundo, Vector3.ZERO, 1.5, 0.0))
		var previo: float = 0.0
		for t in [0.3, 0.55]:
			await _esperar(t - previo)
			previo = t
			await _foto("remolino_%s_%.2f" % [modo, t])
		await _esperar(1.0)
		seed(7)
		var pie := Node3D.new()
		_mundo.add_child(pie)
		_con_viento(func() -> void: VfxViento.torbellino(pie, Vector3.UP, 0.8, 2.0, 6.0))
		await _esperar(1.2)
		await _foto("tornado_%s" % modo)
		await _esperar(0.2)
		pie.queue_free()
		await _esperar(0.3)
	quit()


func _con_viento(f: Callable) -> void:
	var antes: String = VfxKit3D.elemento
	VfxKit3D.elemento = "viento"
	f.call()
	VfxKit3D.elemento = antes


## Cámara del juego: ortogonal, 6 u (ZOOM_INICIAL), 60° de inclinación (INCLINACION de prueba_test2.gd).
func _camara(mira: Vector3) -> void:
	var dir: Vector3 = Vector3(0.0, -sin(deg_to_rad(60.0)), -cos(deg_to_rad(60.0)))
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), mira - dir * 40.0)
	_cam.current = true


func _esperar(s: float) -> void:
	await create_timer(maxf(s, 0.02)).timeout
	await process_frame


func _foto(nombre: String) -> void:
	await process_frame
	var ruta: String = "%s/%s.png" % [_dir, nombre]
	_vp.get_texture().get_image().save_png(ruta)
	print("guardado ", ruta)
