extends SceneTree

## CAPTURA (Pipeline, 21/10): saca PNG de los VFX de tierra y viento (`VfxTierra`, `VfxViento`) para MIRARLOS (no es una prueba: la prueba es
## `prueba_vfx_tierra_viento.gd`). Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_vfx_tierra_viento.gd -- docs/capturas/vfx_tierra_viento
## Escribe: piezas.png (el catálogo de piezas), tierra_vuelo.png, tierra_impacto_<t>.png, tierra_muro_<t>.png, viento_vuelo.png, viento_remolino_<t>.png, viento_torbellino.png

var _vp: SubViewport = null
var _mundo: Node3D = null
var _cam: Camera3D = null
var _dir: String = "docs/capturas/vfx_tierra_viento"


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
	_vp.size = Vector2i(1100, 620)
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_cam = Camera3D.new()
	_vp.add_child(_cam)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-50, 25, 0)
	luz.shadow_enabled = true
	_vp.add_child(luz)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.78, 0.88)
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
	await _esperar(0.3)

	# 1. catálogo de piezas
	_poner_camara(Vector3(0.9, 1.6, 4.4), Vector3(0.9, 0.35, 0.0))
	var x: float = -1.7
	for id in VfxTierra.ids():
		var p: MeshInstance3D = VfxTierra.pieza(id)
		var c: Node3D = Node3D.new()
		_mundo.add_child(c)
		c.add_child(p)
		var med: Vector3 = VfxTierra.MEDIDA[id]
		c.position = Vector3(x, (med.y * 0.5 + 0.02) if not (id.begins_with("bloque_") or id.begins_with("pincho_")) else 0.0, 0.0)
		c.rotation.y = 0.5
		x += 0.28 if id.begins_with("cascote") else (0.55 if id.begins_with("terron") else 1.05)
	await _esperar(0.4)
	await _foto("piezas")
	_limpiar()

	# 2. tierra en vuelo
	_poner_camara(Vector3(0.5, 1.4, 3.6), Vector3(0.5, 0.9, 0.0))
	var seg := Node3D.new()
	_mundo.add_child(seg)
	seg.position = Vector3(0.5, 1.0, 0.0)
	_con("tierra", func() -> void: VfxTierra.proyectil(seg, Vector3.RIGHT, 0.5))
	await _esperar(0.5)
	await _foto("tierra_vuelo")
	_limpiar()

	# 3. impacto de tierra
	_poner_camara(Vector3(0.0, 2.2, 5.0), Vector3(0.0, 0.3, 0.0))
	_con("tierra", func() -> void: VfxTierra.impacto(_mundo, Vector3(0.0, 1.0, 0.0), 1.5, 0.0, 5))
	for t in [0.3, 0.8, 1.6]:
		await _esperar(t if t == 0.3 else (0.5 if t == 0.8 else 0.8))
		await _foto("tierra_impacto_%.1f" % t)
	await _esperar(2.0)
	_limpiar()

	# 4. muro de tierra (barrera) emergiendo
	_poner_camara(Vector3(0.0, 3.4, 6.2), Vector3(0.0, 0.5, 0.0))
	_con("tierra", func() -> void: VfxTierra.emerger(_mundo, Vector3.ZERO, 0.8, 1.0, 8.0, "barrera", 1.5))
	var previo: float = 0.0
	for t in [0.2, 0.45, 1.2]:
		await _esperar(t - previo)
		previo = t
		await _foto("tierra_muro_%.2f" % t)
	_limpiar()

	# 5. viento en vuelo
	_poner_camara(Vector3(-0.2, 1.6, 4.2), Vector3(-0.2, 1.0, 0.0))
	var sv := Node3D.new()
	_mundo.add_child(sv)
	sv.position = Vector3(0.9, 1.0, 0.0)
	_con("viento", func() -> void: VfxViento.proyectil(sv, Vector3.RIGHT, 0.5))
	await _esperar(0.4)
	await _foto("viento_vuelo")
	_limpiar()

	# 6. remolino de impacto
	_poner_camara(Vector3(0.0, 2.4, 5.0), Vector3(0.0, 0.9, 0.0))
	_con("viento", func() -> void: VfxViento.remolino(_mundo, Vector3(0.0, 1.0, 0.0), 1.5, 0.0))
	previo = 0.0
	for t in [0.25, 0.6]:
		await _esperar(t - previo)
		previo = t
		await _foto("viento_remolino_%.2f" % t)
	await _esperar(1.0)
	_limpiar()

	# 7. torbellino
	_poner_camara(Vector3(0.0, 2.6, 5.4), Vector3(0.0, 1.0, 0.0))
	var pie := Node3D.new()
	_mundo.add_child(pie)
	_con("viento", func() -> void: VfxViento.torbellino(pie, Vector3.UP, 0.8, 2.0, 6.0))
	await _esperar(1.0)
	await _foto("viento_torbellino")
	quit()


## Pone `VfxKit3D.elemento` a `el` mientras dura `f` (las partículas del kit toman su color de ahí).
func _con(el: String, f: Callable) -> void:
	var antes: String = VfxKit3D.elemento
	VfxKit3D.elemento = el
	f.call()
	VfxKit3D.elemento = antes


func _poner_camara(pos: Vector3, mira: Vector3) -> void:
	_cam.look_at_from_position(pos, mira)
	_cam.current = true


func _esperar(s: float) -> void:
	await create_timer(maxf(s, 0.02)).timeout
	await process_frame


func _foto(nombre: String) -> void:
	await process_frame
	var ruta: String = "%s/%s.png" % [_dir, nombre]
	_vp.get_texture().get_image().save_png(ruta)
	print("guardado ", ruta)


func _limpiar() -> void:
	for c in _mundo.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh:
			continue
		c.queue_free()
