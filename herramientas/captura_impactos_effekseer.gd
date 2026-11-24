extends SceneTree

## CAPTURA de la comparativa de impactos (25/11/2026, lab_impactos_effekseer.gd): para cada par (ahora | Effekseer traducido), fotos a los mismos instantes en la vista del JUEGO
## (ortogonal, 30°) y DE CERCA. Para MIRARLO, no es una prueba. Necesita ventana (sin --headless) y --fixed-fps 60 para que los instantes sean exactos:
##   godot --fixed-fps 60 --path . --script res://herramientas/captura_impactos_effekseer.gd -- output/effekseer_impactos_2026-11-25/capturas
## Escribe <id>_<vista>_<ms>.png. herramientas/hoja_impactos_effekseer.py las junta en una hoja por par.

const TAM: Vector2i = Vector2i(1600, 900)
const INSTANTES_MS: Array = [50, 100, 200, 350, 600, 1000]
const LabImpactosEffekseer = preload("res://laboratorios/lab_impactos_effekseer.gd")
const Recetas = preload("res://presentacion/vfx/toy/recetas_effekseer.gd")

var _dir: String = "output/effekseer_impactos_2026-11-25/capturas"


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
	var c: Node = LabImpactosEffekseer.tecla(lab, KEY_4, false)
	c.set("auto", false)
	for i in Recetas.RECETAS.size():
		var id: String = String(Recetas.RECETAS[i]["id"])
		for v in [0, 1]:
			c.call("poner_par", i)
			c.call("poner_vista", v)
			c.call("rotulos", false)
			for h in (c.get("_efectos") as Node).get_children():
				h.queue_free()
			await _esperar(8)
			c.call("lanzar_par")
			var hecho: int = 0
			for ms in INSTANTES_MS:
				var f: int = int(round(float(ms) / 1000.0 * 60.0))
				await _esperar(f - hecho)
				hecho = f
				_guardar("%s_%s_%04d.png" % [id, ["juego", "cerca"][v], ms])
	print("CAPTURAS en " + _dir)
	quit()


func _esperar(n: int) -> void:
	for k in range(maxi(n, 0)):
		await process_frame


func _guardar(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join(nombre))
