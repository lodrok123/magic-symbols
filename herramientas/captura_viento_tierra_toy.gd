extends SceneTree

## CAPTURAS DEL VIENTO Y LA TIERRA «TOY» (6/11/2026; a imagen de captura_magma_toy.gd): saca los PNG en el LabVfxComparativa3D con el elemento puesto en «viento» y en «tierra»:
## viento_bola_vuelo (la ráfaga con su estela de jirones), viento_pilar (torbellino), viento_impacto (soplo en el suelo, N); tierra_bola (la roca en vuelo con terrones), tierra_muro_subiendo (F7 muro
## a mitad de la subida) y tierra_impacto (N: piedrecitas + nube de polvo). Para MIRARLO, no es una prueba. Necesita ventana (sin --headless) pero no espera clics:
##   godot --path . --script res://herramientas/captura_viento_tierra_toy.gd -- docs/capturas/viento_tierra_toy

const TAM: Vector2i = Vector2i(1600, 1000)

var _dir: String = "docs/capturas/viento_tierra_toy"
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
	await _seg(0.4)
	# ---- VIENTO ----
	_lab.call("poner_elemento", "viento")
	_lab.call("lanzar_proyectil", "fin")                                   # carga corta (0,35 s) y suelta a los 0,4 s; vuela 3,5 m
	await _seg(0.4 + 0.3)
	_camara(Vector3(2.3, 1.4, -1.2), Vector3(0.0, 0.7, -3.0))
	await _seg(0.02)
	_guardar("viento_bola_vuelo.png")
	await _seg(1.2)
	_lab.call("limpiar")
	await _seg(0.3)
	_lab.call("fuego_param", 2)                                            # pilar: torbellino
	_camara(Vector3(3.6, 2.6, 0.6), Vector3(0.0, 1.6, -3.0))
	await _seg(1.4)
	_guardar("viento_pilar.png")
	_lab.call("limpiar")
	await _seg(0.3)
	_camara(Vector3(2.2, 1.5, -1.4), Vector3(0.0, 0.25, -3.0))
	_lab.call("impacto_suelo")
	await _seg(0.22)
	_guardar("viento_impacto.png")
	await _seg(1.2)
	_lab.call("limpiar")
	await _seg(0.3)
	# ---- TIERRA ----
	_lab.call("poner_elemento", "tierra")
	_lab.call("lanzar_proyectil", "fin")
	await _seg(0.4 + 0.3)
	_camara(Vector3(2.3, 1.4, -1.2), Vector3(0.0, 0.7, -3.0))
	await _seg(0.02)
	_guardar("tierra_bola.png")
	await _seg(1.2)
	_lab.call("limpiar")
	await _seg(0.3)
	_lab.call("fuego_param", 1)                                            # muro: sube del suelo (nacer 0,55 s)
	_camara(Vector3(3.2, 2.0, 0.8), Vector3(0.0, 0.7, -3.0))
	await _seg(0.5)                                                        # el lab tarda ~0,25 s en dar la orden; hacia 0,5-0,65 s los bloques van a media altura con el polvo de la anticipación
	_guardar("tierra_muro_subiendo.png")
	await _seg(0.8)
	_guardar("tierra_muro_asentado.png")
	_lab.call("limpiar")
	await _seg(0.3)
	_camara(Vector3(2.2, 1.5, -1.4), Vector3(0.0, 0.25, -3.0))
	_lab.call("impacto_suelo")
	await _seg(0.25)
	_guardar("tierra_impacto.png")
	await _seg(0.5)
	_guardar("tierra_impacto_polvo_viejo.png")
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
