extends SceneTree
## Fotos del LIMO elemental (E1, prototipo visual, 27/10). NECESITA VENTANA:
##   Godot --path . --resolution 1280x720 --script res://herramientas/captura_limo.gd -- [carpeta]   (por defecto res://docs/capturas/limo)

var _dir: String = "res://docs/capturas/limo"
var _e: Node3D = null


func _initialize() -> void:
	await process_frame
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	_e = (load("res://escenas/PruebaLimo.tscn") as PackedScene).instantiate()
	root.add_child(_e)
	await _esperar(1.0)
	await _foto("fila_juego")
	var l: Array = _e.limos
	# Primeros planos frontales (cámara baja, mismo ortogonal).
	_e.enfocar(l[0].global_position + Vector3(0, 0.3, 0), 1.5, 82.0)
	await _esperar(0.3)
	await _foto("cerca_neutro")
	_e.enfocar(l[1].global_position + Vector3(0, 0.3, 0), 1.5, 82.0)
	await _esperar(0.2)
	await _foto("cerca_fuego")
	_e.enfocar(l[4].global_position + Vector3(0, 0.3, 0), 1.5, 82.0)
	await _esperar(0.2)
	await _foto("congelado")
	_e.enfocar(_e.grande.global_position + Vector3(0, 0.45, 0), 2.4, 82.0)
	await _esperar(0.3)
	await _foto("grande")
	# Salto, con la cámara del juego cerrada sobre el limo de pruebas.
	var p: LimoVisual3D = _e.principal
	p.cargar("agua")
	_e.enfocar(p.global_position + Vector3(1.1, 0.7, 0), 3.2, 60.0)
	await _esperar(0.6)
	p.saltar(Vector3.RIGHT)
	await _esperar(0.18 + 0.5 * 0.4)
	await _foto("salto")
	await _esperar(1.2)
	# Crecer: el mismo elemento otra vez; foto en el pico del rebote (~0,35 s).
	p.position = Vector3(0, 0, 1.6)
	p.cargar("fuego")
	_e.enfocar(p.global_position + Vector3(0, 0.5, 0), 3.4, 60.0)
	await _esperar(0.7)
	p.cargar("fuego")
	await _esperar(0.3)
	await _foto("crecer")
	await _esperar(1.5)
	print("tamano ", p.tamano)
	# División a mitad (grande → dos normales).
	p.dividir()
	await _esperar(0.32 + 0.07)
	_e.enfocar(p.global_position + Vector3(0, 0.3, 0), 4.2, 60.0)
	await process_frame
	await _foto("dividir")
	print("fotos hechas")
	quit(0)


func _esperar(s: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < s * 1000.0:
		await process_frame


func _foto(nombre: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)
