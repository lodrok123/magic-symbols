extends SceneTree

## CAPTURA (22/10, assets de elementos): saca PNG de los VFX de tierra, hielo y viento ANTES (primitivas / kit / atlas sencillo) y DESPUÉS (modelos de Meshy y atlas de viento)
## para MIRARLOS (no es una prueba: la prueba es `prueba_assets_elementos.gd`). Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_assets_elementos.gd -- docs/capturas/assets_elementos antes
##   godot --path . --script res://herramientas/captura_assets_elementos.gd -- docs/capturas/assets_elementos despues
## Escribe <cosa>_<modo>.png: tierra_proyectil, tierra_impacto, tierra_muro, hielo_proyectil, hielo_impacto, hielo_barrera, viento_hojas, viento_remolino; y, solo
## «despues», catalogo_tierra, catalogo_hielo, hielo_escarcha, hielo_placa_rota. Pasa el nombre de un solo caso como tercer argumento para sacar solo ese.

var _vp: SubViewport = null
var _mundo: Node3D = null
var _cam: Camera3D = null
var _dir: String = "docs/capturas/assets_elementos"
var _modo: String = "despues"
var _solo: String = ""
var _ve: VfxElemento3D = null


func _initialize() -> void:
	_correr()


func _quiero(nombre: String) -> bool:
	return _solo == "" or _solo == nombre


func _correr() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	if a.size() > 1:
		_modo = a[1]
	if a.size() > 2:
		_solo = a[2]
	var nuevo: bool = _modo != "antes"
	VfxTierra.usar_modelos = nuevo
	VfxHielo.usar_modelos = nuevo
	VfxViento.usar_atlas = nuevo
	if not _dir.is_absolute_path():
		_dir = ProjectSettings.globalize_path("res://" + _dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1000, 620)
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
	e.background_color = Color(0.50, 0.60, 0.68)
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
	_ve = VfxElemento3D.new()
	_mundo.add_child(_ve)
	await _esperar(0.3)

	if nuevo and _quiero("catalogo"):
		_poner_camara(Vector3(0.9, 1.6, 4.4), Vector3(0.9, 0.35, 0.0))
		var x: float = -1.7
		for id in VfxTierra.ids():
			var p: MeshInstance3D = VfxTierra.pieza(id)
			var c := Node3D.new()
			_mundo.add_child(c)
			c.add_child(p)
			var med: Vector3 = VfxTierra.MEDIDA[id]
			c.position = Vector3(x, (med.y * 0.5 + 0.02) if not (id.begins_with("bloque_") or id.begins_with("pincho_")) else 0.0, 0.0)
			c.rotation.y = 0.5
			x += 0.28 if id.begins_with("cascote") else (0.55 if id.begins_with("terron") else 1.05)
		await _esperar(0.4)
		await _foto("catalogo_tierra")
		_limpiar()
		_poner_camara(Vector3(1.2, 1.5, 4.2), Vector3(1.2, 0.5, 0.0))
		x = -0.8
		for id in ["esquirla_hielo", "pincho_escarcha_0", "pincho_escarcha_1", "racimo_hielo_p", "racimo_hielo_m", "racimo_hielo_g"]:
			var p: MeshInstance3D = VfxHielo.pieza(id)
			var c := Node3D.new()
			_mundo.add_child(c)
			c.add_child(p)
			var med: Vector3 = VfxHielo.MEDIDA[id]
			c.position = Vector3(x, (med.y * 0.5 + 0.02) if id == "esquirla_hielo" else 0.0, 0.0)
			c.rotation.y = 0.5
			if id == "esquirla_hielo":
				c.rotation = Vector3(0.0, PI * 0.5, 0.0)       # de lado, vista por el costado: se ve el largo y de qué lado queda la punta (+Z → hacia la izquierda de la imagen)
			x += 0.55 if id == "esquirla_hielo" else (0.3 if id.begins_with("pincho") else (0.6 if id.ends_with("_p") else (0.9 if id.ends_with("_m") else 1.2)))
		await _esperar(0.4)
		await _foto("catalogo_hielo")
		_limpiar()

	if _quiero("tierra_proyectil"):
		_poner_camara(Vector3(0.5, 1.4, 3.6), Vector3(0.5, 0.9, 0.0))
		var seg := Node3D.new()
		_mundo.add_child(seg)
		seg.position = Vector3(0.5, 1.0, 0.0)
		_ve._con_elemento("tierra", _ve._pieza_proyectil.bind("tierra", seg, Vector3.RIGHT, 0.5, 6.0))
		await _esperar(0.5)
		await _foto("tierra_proyectil_" + _modo)
		_limpiar()

	if _quiero("tierra_impacto"):
		_poner_camara(Vector3(0.0, 2.2, 5.0), Vector3(0.0, 0.3, 0.0))
		_ve._con_elemento("tierra", func() -> void: VfxTierra.impacto(_mundo, Vector3(0.0, 1.0, 0.0), 1.5, 0.0, 5))
		await _esperar(0.9)
		await _foto("tierra_impacto_" + _modo)
		await _esperar(2.4)
		_limpiar()

	if _quiero("tierra_muro"):
		_poner_camara(Vector3(0.0, 3.4, 6.2), Vector3(0.0, 0.5, 0.0))
		_ve._con_elemento("tierra", _ve._pieza_volumen.bind("tierra", _mundo, "barrera", Vector3.ZERO, Vector3.RIGHT, 0.8, 1.0, 8.0, false))
		await _esperar(1.3)
		await _foto("tierra_muro_" + _modo)
		_limpiar()

	if _quiero("hielo_proyectil"):
		_poner_camara(Vector3(0.5, 1.4, 3.0), Vector3(0.5, 1.0, 0.0))
		var seg := Node3D.new()
		_mundo.add_child(seg)
		seg.position = Vector3(0.5, 1.0, 0.0)
		_ve._con_elemento("hielo", _ve._pieza_proyectil.bind("hielo", seg, Vector3.RIGHT, 0.5, 6.0))
		await _esperar(0.5)
		await _foto("hielo_proyectil_" + _modo)
		_limpiar()

	if _quiero("hielo_impacto"):
		_poner_camara(Vector3(0.0, 1.8, 4.2), Vector3(0.0, 0.5, 0.0))
		if _modo == "antes":
			_ve._con_elemento("hielo", _ve._pieza_volumen.bind("hielo", _mundo, "esfera", Vector3.ZERO, Vector3.RIGHT, 0.5, 1.0, 3.0, false))
		else:
			_ve._con_elemento("hielo", func() -> void: VfxHielo.impacto(_mundo, Vector3(0.0, 1.0, 0.0), 1.5, 0.0))
		await _esperar(0.9)
		await _foto("hielo_impacto_" + _modo)
		await _esperar(2.4)
		_limpiar()

	if _quiero("hielo_barrera"):
		_poner_camara(Vector3(0.0, 3.2, 6.0), Vector3(0.0, 0.7, 0.0))
		_ve._con_elemento("hielo", _ve._pieza_volumen.bind("hielo", _mundo, "barrera", Vector3.ZERO, Vector3.RIGHT, 0.8, 1.4, 8.0, false))
		await _esperar(1.3)
		await _foto("hielo_barrera_" + _modo)
		_limpiar()

	if nuevo and _quiero("hielo_escarcha"):
		_poner_camara(Vector3(0.0, 1.6, 3.6), Vector3(0.0, 0.3, 0.0))
		VfxHielo.escarcha_modelos(_mundo, Vector3.ZERO, 1.2, 0.0)
		await _esperar(0.7)
		await _foto("hielo_escarcha_" + _modo)
		await _esperar(2.4)
		_limpiar()

	if nuevo and _quiero("hielo_placa_rota"):
		_poner_camara(Vector3(0.0, 3.6, 3.8), Vector3(0.0, 0.0, 0.0))
		VfxHielo.placa_rota(_mundo, Vector3(0.0, 0.02, 0.0), 1.0)
		await _esperar(0.75)
		await _foto("hielo_placa_rota_" + _modo)
		await _esperar(2.4)
		_limpiar()

	if _quiero("viento_hojas"):
		_poner_camara(Vector3(-0.2, 1.6, 4.2), Vector3(-0.2, 1.0, 0.0))
		var sv := Node3D.new()
		_mundo.add_child(sv)
		sv.position = Vector3(0.9, 1.0, 0.0)
		_ve._con_elemento("viento", _ve._pieza_proyectil.bind("viento", sv, Vector3.RIGHT, 0.5, 6.0))
		await _esperar(0.4)
		await _foto("viento_hojas_" + _modo)
		_limpiar()

	if _quiero("viento_remolino"):
		_poner_camara(Vector3(0.0, 2.4, 5.0), Vector3(0.0, 0.9, 0.0))
		_ve._con_elemento("viento", func() -> void: VfxViento.remolino(_mundo, Vector3(0.0, 1.0, 0.0), 1.5, 0.0))
		await _esperar(0.55)
		await _foto("viento_remolino_" + _modo)
		await _esperar(1.0)
		_limpiar()

	if _quiero("viento_torbellino"):
		_poner_camara(Vector3(0.0, 2.6, 5.4), Vector3(0.0, 1.0, 0.0))
		var pie := Node3D.new()
		_mundo.add_child(pie)
		_ve._con_elemento("viento", func() -> void: VfxViento.torbellino(pie, Vector3.UP, 0.8, 2.0, 6.0))
		await _esperar(1.0)
		await _foto("viento_torbellino_" + _modo)
	quit()


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
		if c == _ve or (c is MeshInstance3D and (c as MeshInstance3D).mesh is PlaneMesh):
			continue
		c.queue_free()
