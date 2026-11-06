extends SceneTree

## CAPTURAS DEL MAGMA «TOY» (6/11/2026; a imagen de captura_vfx_toy.gd): saca los PNG del MagmaToy en el LabVfxComparativa3D con el elemento puesto en «magma»:
## bola_cargando (la roca gris calentándose en la mano), bola_vuelo (rodando, con la estela de brasas), impacto_pared_mitad (G: choca con la pared), impacto_suelo_mitad (N: esquirlas en el aire),
## crater_enfriando (a 1,2 s: rojo), crater_gris (a 2,4 s). Para MIRARLO, no es una prueba. Necesita ventana (sin --headless) pero no espera clics:
##   godot --path . --script res://herramientas/captura_magma_toy.gd -- docs/capturas/magma_toy

const TAM: Vector2i = Vector2i(1600, 1000)

var _dir: String = "docs/capturas/magma_toy"
var _lab: Node3D = null


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
	root.get_window().size = TAM
	root.get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_lab = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(_lab)
	_lab.set("_panel_visible", false)
	_lab.call("poner_elemento", "magma")
	await _seg(0.4)
	# G: carga, vuelo y choque con la pared (la mano está en (0, 0,7, -0,5); la pared a 6 m)
	_camara(Vector3(1.5, 1.25, 0.7), Vector3(0.0, 0.75, -0.5))
	_lab.call("carga_completa")
	await _seg(0.75)
	_guardar("bola_cargando.png")
	await _seg(1.8 - 0.75 + 0.33)
	_camara(Vector3(2.3, 1.4, -1.6), Vector3(0.0, 0.7, -3.4))
	await _seg(0.02)
	_guardar("bola_vuelo.png")
	await _seg(0.69 - 0.33 + 0.16)
	_camara(Vector3(2.4, 1.5, -3.9), Vector3(0.0, 0.6, -6.0))
	await _seg(0.02)
	_guardar("impacto_pared_mitad.png")
	await _seg(1.2)
	_lab.call("limpiar")
	await _seg(0.3)
	# N: impacto en el suelo a 3 m delante: esquirlas, cráter y pétalos
	_camara(Vector3(2.2, 1.6, -1.4), Vector3(0.0, 0.25, -3.0))
	_lab.call("impacto_suelo")
	await _seg(0.2)
	_guardar("impacto_suelo_mitad.png")
	await _seg(1.0)
	_guardar("crater_enfriando.png")
	await _seg(1.2)
	_guardar("crater_gris.png")
	_lab.call("limpiar")
	await _seg(0.3)
	# F7 muro de magma (versión sencilla)
	_lab.call("fuego_param", 1)
	_camara(Vector3(3.0, 2.0, 1.5), Vector3(0.0, 0.8, -3.0))
	await _seg(1.2)
	_guardar("muro_magma.png")
	print("CAPTURAS en " + _dir)
	quit()


func _camara(desde: Vector3, mira: Vector3) -> void:
	_lab.set("camara_fija", {"desde": desde, "mira": mira})
	_lab.call("poner_camara", 1)


func _seg(s: float) -> void:
	await create_timer(s).timeout


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
	print("captura " + nombre)
