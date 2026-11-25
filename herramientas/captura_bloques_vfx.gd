extends SceneTree

## CAPTURA de la galería de efectos «bloques» (25/11/2026, laboratorios/lab_bloques_vfx.gd): por grupo y vista, fotos a unos instantes tras relanzar los de un disparo.
## Para MIRARLO, no es una prueba. Necesita ventana (sin --headless) y --fixed-fps 60:
##   godot --fixed-fps 60 --path . --script res://herramientas/captura_bloques_vfx.gd -- output/bloques_vfx_2026-11-25
## Escribe g<grupo>_<vista>_<ms>.png.

const TAM: Vector2i = Vector2i(1600, 900)
const INSTANTES_MS: Array = [120, 350, 800]
const LabBloquesVfx = preload("res://laboratorios/lab_bloques_vfx.gd")

var _dir: String = "output/bloques_vfx_2026-11-25"


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
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await _esperar(20)
	var g: Node = LabBloquesVfx.tecla(lab, KEY_9, false)
	g.set("auto", false)
	for gi in LabBloquesVfx.GRUPOS.size():
		for v in [0, 1]:
			g.call("poner_grupo", gi)
			g.call("poner_vista", v)
			g.call("rotulos", v == 0)
			await _esperar(90)                       # que los continuos lleguen a su régimen
			g.call("relanzar")
			var hecho: int = 0
			for ms in INSTANTES_MS:
				var f: int = int(round(float(ms) / 1000.0 * 60.0))
				await _esperar(f - hecho)
				hecho = f
				_guardar("g%d_%s_%04d.png" % [gi + 1, ["juego", "cerca"][v], ms])
	print("CAPTURAS en " + _dir)
	quit()


func _esperar(n: int) -> void:
	for k in range(maxi(n, 0)):
		await process_frame


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
