extends SceneTree
## CAPTURA de la herramienta del generador de mapas (24/11/2026): la pestaña «Puzles» con las runas de la jugadora y el buscador, y la vista
## con una vagoneta y una sala del jefe. Para mirarlo; necesita ventana:
##   godot --path . --script res://herramientas/captura_generador_puzles.gd
## Escribe docs/capturas/generador_puzles_runas.png y docs/capturas/generador_jefe_vagoneta.png.

const ESCENA: String = "res://herramientas/generador_mapas/GeneradorMapas.tscn"


func _initialize() -> void:
	_hacer.call_deferred()


func _hacer() -> void:
	root.get_window().size = Vector2i(1800, 1000)
	var ui: Node = (load(ESCENA) as PackedScene).instantiate()
	root.add_child(ui)
	await _frames(20)
	var par: Dictionary = ui.get("_par")
	par["kit"] = "demo_inicio"
	par["sala_jefe"] = "auto"
	par["puzles"] = 4
	ui.set("_par", par)
	ui.set("_sucio", true)
	await _frames(30)
	var pestanas: TabContainer = ui.find_children("*", "TabContainer", true, false)[0] as TabContainer
	for i in pestanas.get_tab_count():
		if pestanas.get_tab_title(i) == "Puzles":
			pestanas.current_tab = i
	await _frames(20)
	_guardar("res://docs/capturas/generador_puzles_runas.png")
	ui.set("_pz_busca", "vagoneta")
	ui.set("_pz_todos", true)
	ui.call("_refrescar_puzles")
	await _frames(10)
	_guardar("res://docs/capturas/generador_jefe_vagoneta.png")
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _guardar(ruta: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(ruta))
	print("captura: ", ruta)
