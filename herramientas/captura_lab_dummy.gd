extends SceneTree

## CAPTURA DEL DUMMY DE ESTADOS DEL LAB (18/11/2026): el lab con su panel y el dummy tras aplicarle agua y hielo (mojado → congelado más largo). Necesita ventana. No es una prueba:
##   godot --path . --script res://herramientas/captura_lab_dummy.gd -- docs/capturas/lab_dummy_2026-11-18

const TAM: Vector2i = Vector2i(1400, 800)

var _dir: String = "docs/capturas/lab_dummy_2026-11-18"


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
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	lab.call("poner_camara", 0)
	await create_timer(0.8).timeout
	var pasos: Array = [["agua", "1_agua"], ["hielo", "2_agua_hielo"], ["rayo", "3_roto_por_rayo"], ["fuego", "4_fuego"]]
	for p in pasos:
		lab.call("poner_elemento", p[0])
		lab.call("dummy_aplicar", "")
		await create_timer(0.9).timeout
		root.get_viewport().get_texture().get_image().save_png(_dir.path_join("dummy_%s.png" % p[1]))
	print("CAPTURAS en " + _dir)
	quit()
