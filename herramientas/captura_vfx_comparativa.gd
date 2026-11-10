extends SceneTree

## CAPTURA (1/11, Dirección, COMPARATIVA_VFX §1.4): saca PNG de los tres efectos de fuego del LabVfxComparativa3D a 2 m y a 10 m, la bola en vuelo y
## al caer, y la escena con diez muros con el fps en el panel. Para MIRARLO, no es una prueba. Necesita ventana (sin --headless):
##   godot --path . --script res://herramientas/captura_vfx_comparativa.gd -- docs/capturas/comparativa_vfx/godot
## Escribe bola_vuelo_cerca.png, bola_impacto_cerca.png, bola_impacto_lejos.png, muro_cerca.png, muro_lejos.png, columna_cerca.png, columna_lejos.png,
## diez_muros.png y juego_muro.png (la vista del juego).

const TAM: Vector2i = Vector2i(1600, 1000)
const ESPERA_NACER: int = 50          ## fotogramas tras lanzar antes de la primera captura (~0,8 s a 60 fps)

var _dir: String = "docs/capturas/comparativa_vfx/godot"
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
	await _esperar(20)

	# Muro: cerca, lejos y la vista del juego.
	_lab.call("efecto", "muro")
	await _esperar(ESPERA_NACER)
	_lab.call("poner_camara", 1)
	await _esperar(3)
	_guardar("muro_cerca.png")
	_lab.call("poner_camara", 2)
	await _esperar(3)
	_guardar("muro_lejos.png")
	_lab.call("poner_camara", 0)
	await _esperar(3)
	_guardar("juego_muro.png")
	_lab.call("limpiar")
	await _esperar(10)

	# Columna.
	_lab.call("efecto", "columna")
	await _esperar(ESPERA_NACER)
	_lab.call("poner_camara", 1)
	await _esperar(3)
	_guardar("columna_cerca.png")
	_lab.call("poner_camara", 2)
	await _esperar(3)
	_guardar("columna_lejos.png")
	_lab.call("limpiar")
	await _esperar(10)

	# Bola: en vuelo (0,3 s) y el impacto (cae a los 6 m: 0,75 s; la llamarada a 0,2 s de caer).
	_lab.call("poner_camara", 1)
	_lab.call("efecto", "bola")
	await _esperar(18)
	_guardar("bola_vuelo_cerca.png")
	await _esperar(40)
	_guardar("bola_impacto_cerca.png")
	_lab.call("poner_camara", 2)
	await _esperar(3)
	_guardar("bola_impacto_lejos.png")
	_lab.call("limpiar")
	await _esperar(10)

	# Diez muros con el fps en el panel.
	_lab.call("poner_camara", 2)
	_lab.call("diez_muros")
	await _esperar(90)
	_guardar("diez_muros.png")
	_lab.call("limpiar")
	await _esperar(10)

	# 7/11 (Pablo: «integra todo en un laboratorio para revisar todos los elementos»): LA PARRILLA, una foto por figura, con los siete elementos a la vez y la cámara de lejos.
	var figuras: Array = _lab.get_script().get_script_constant_map().get("FIGURAS_PARAM", [])
	_lab.call("poner_camara", 2)
	for i in figuras.size():
		_lab.call("parrilla", i)
		await _esperar(ESPERA_NACER)
		_guardar("parrilla_%s.png" % String(figuras[i][1]))
		await _esperar(3)
	_lab.call("limpiar")
	print("CAPTURAS en " + _dir)
	quit()


func _esperar(n: int) -> void:
	for k in range(n):
		await process_frame


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
	print("captura " + nombre)
