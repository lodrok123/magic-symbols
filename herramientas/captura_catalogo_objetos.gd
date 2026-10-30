extends SceneTree

## CAPTURA (30/10, Juego): saca PNG del MOSTRADOR DE OBJETOS 2D del catálogo de assets (`laboratorios/CatalogoAssets.tscn`, modo 3, tecla O):
## la rejilla entera de tarjetas con relieve, un primer plano de la primera fila (para ver el relieve) y la bolsa abierta con los primeros
## iconos dentro. Para MIRARLO, no es una prueba. Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_catalogo_objetos.gd -- docs/capturas/catalogo_objetos
## Escribe catalogo_objetos.png, catalogo_objetos_cerca.png y catalogo_objetos_bolsa.png.

const TAM: Vector2i = Vector2i(1600, 1000)
const FOTOGRAMAS: int = 12
const EN_BOLSA: int = 20            ## cuántos ids se meten en la bolsa para la tercera captura (los 20 huecos)

var _dir: String = "docs/capturas/catalogo_objetos"


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
	Estado.nuevo()
	var cat: Node3D = (load("res://laboratorios/CatalogoAssets.tscn") as PackedScene).instantiate() as Node3D
	cat.set("modo", 3)
	root.add_child(cat)
	await _esperar()
	_guardar("catalogo_objetos.png")

	# Primer plano de la primera fila, girada más, para ver el relieve.
	cat.set("giro", 40.0)
	for h in (cat.get("_raiz") as Node3D).get_children():
		if h is Node3D and not (h is Label3D):
			(h as Node3D).rotation_degrees.y = 40.0
	cat.set("_tam", 7.0)
	cat.set("_centro", Vector3(4.0, 0.9, 0.6))
	cat.set("inclinacion", 32.0)
	cat.call("_colocar_camara")
	await _esperar()
	_guardar("catalogo_objetos_cerca.png")

	# La bolsa con los primeros ids dentro.
	var ids: Array = cat.call("_iconos_objeto")
	var n: int = 0
	for id in ids:
		if n >= EN_BOLSA:
			break
		Estado.i().agregar(String(id), 1 + (n % 3))
		n += 1
	var bolsa: BolsaUI = cat.get("_bolsa")
	bolsa.alternar()
	await _esperar(30)
	_guardar("catalogo_objetos_bolsa.png")
	quit()


func _esperar(n: int = FOTOGRAMAS) -> void:
	for k in range(n):
		await process_frame


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	var ruta: String = _dir.path_join(nombre)
	img.save_png(ruta)
	print("captura: ", ruta, " ", img.get_size())
