extends SceneTree
## CAPTURAS ANTES / DESPUÉS de los albedos EoW (PLAN_EOW_VISUAL §1.2, `Albedos3D`). NECESITA VENTANA. Mismo patrón que `captura_v7.gd`.
##   godot --path . --script res://herramientas/captura_albedos.gd -- <bosque|lab> <antes|despues> <carpeta>
## «antes» = `albedos_eow = false` en la maqueta y `Albedos3D.poner_piezas(false)` (K = 1, VALOR = 1 en todas las familias); «despues» = el valor de serie.
## `bosque` = escenas/PruebaBosque01.tscn (cámara del juego = la que trae la maqueta, y vistas de cerca). `lab` = LabPlaytestEoW, sala 4 y una de cerca.
const S: float = 2.3
const VISTAS: Dictionary = {
	"bosque": {
		"escena": "res://escenas/PruebaBosque01.tscn",
		# nombre: [casilla x, casilla y, tamaño de cámara] (null = la cámara de juego tal cual la deja la maqueta)
		"vistas": {"juego": null, "claro": [14.0, 14.0, 10.0], "arboles": [24.0, 10.0, 7.0], "camino": [10.0, 20.0, 6.0]},
	},
	"lab": {
		"escena": "res://laboratorios/LabPlaytestEoW.tscn",
		"vistas": {"sala4": [28.0, 4.0, 8.0], "sala4_cerca": [28.0, 4.0, 4.5]},
	},
}


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <bosque|lab> <antes|despues> <carpeta>")
		quit(2)
		return
	var cual: String = a[0]
	var antes: bool = a[1] == "antes"
	var carpeta: String = a[2]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var esc: PackedScene = load(VISTAS[cual]["escena"])
	var m: Node3D = esc.instantiate()
	if antes:
		m.set("albedos_eow", false)
	root.add_child(m)
	for _i in 150:
		await process_frame
	_ocultar_ui(root)
	DirAccess.make_dir_recursive_absolute(carpeta)
	var vistas: Dictionary = VISTAS[cual]["vistas"]
	for k in vistas.keys():
		var v = vistas[k]
		if v != null:
			var foco := Vector3((float(v[0]) + 0.5) * S, Terreno3D.alto_suelo, (float(v[1]) + 0.5) * S)
			m.set("_jugador", null)
			m.set("_foco", foco)
			m.set("_tam_camara", float(v[2]))
			m.get("_camara").size = float(v[2])
			m.call("_colocar_camara")
		for _i in 40:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s_%s_%s.png" % [carpeta, cual, k, a[1]])
	quit()


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
