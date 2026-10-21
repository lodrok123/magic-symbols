extends SceneTree
## CAPTURAS ANTES / DESPUÉS de V7 (terrazas con el shader del suelo) de docs/PLAN_EOW_VISUAL.md. NECESITA VENTANA. Mismo patrón que `captura_v3v4.gd`.
##   godot --path . --script res://herramientas/captura_v7.gd -- <terra|lab> <antes|despues> <carpeta>
## «antes»   = `TerraFina3D.terrazas_shader_suelo = false` (terrazas de color por vértice y labio de vértices).
## «despues» = el valor de serie (shader del suelo en la tapa, material del costado en el muro, labio con el shader).
## `terra` = escenas/PruebaTerraFina.tscn (el nivel de verdad). `lab` = LabPlaytestEoW sala 4: el laboratorio dibuja sus terrazas como cubos, así que aquí
## se ocultan y se pone en su lugar la malla de `TerraFina3D._montar_terrazas` (la misma del juego) con las alturas de la sala.
const S: float = 2.3
const VISTAS: Dictionary = {
	"terra": {
		"escena": "res://escenas/PruebaTerraFina.tscn",
		# nombre: [casilla x, casilla y, tamaño de cámara, nivel de la y del foco, estados?]
		"vistas": {"general": [9.0, 11.0, 14.0, 1, false], "pared": [9.0, 8.5, 6.5, 2, false], "estados": [9.0, 8.0, 6.0, 2, true], "estados_cerca": [9.0, 8.0, 3.8, 2, true]},
	},
	"lab": {
		"escena": "res://laboratorios/LabPlaytestEoW.tscn",
		"vistas": {"sala4": [28.0, 4.0, 8.0, 1, false], "sala4_estados": [28.0, 4.0, 5.0, 1, true]},
	},
}


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 3:
		push_error("uso: -- <terra|lab> <antes|despues> <carpeta>")
		quit(2)
		return
	var cual: String = a[0]
	var antes: bool = a[1] == "antes"
	var carpeta: String = a[2]
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	TerraFina3D.terrazas_shader_suelo = not antes
	var esc: PackedScene = load(VISTAS[cual]["escena"])
	var m: Node3D = esc.instantiate()
	root.add_child(m)
	for _i in 150:
		await process_frame
	if cual == "lab":
		_terrazas_del_juego_en_el_lab(m)
		for _i in 60:        # el labio de los escalones lo rehace la maqueta al sondear alturas (cada 0,5 s)
			await process_frame
	_ocultar_ui(root)
	DirAccess.make_dir_recursive_absolute(carpeta)
	var vistas: Dictionary = VISTAS[cual]["vistas"]
	var puestos: bool = false
	for k in vistas.keys():
		var v: Array = vistas[k]
		var foco := Vector3((float(v[0]) + 0.5) * S, Terreno3D.alto_suelo + float(int(v[3])) * Terreno3D.ALTO_NIVEL, (float(v[1]) + 0.5) * S)
		m.set("_jugador", null)
		m.set("_foco", foco)
		m.set("_tam_camara", float(v[2]))
		m.get("_camara").size = float(v[2])
		m.call("_colocar_camara")
		if bool(v[4]) and not puestos:
			_poner_estados(m, Vector2i(int(v[0]), int(v[1])), cual)
			puestos = true
		for _i in 60:
			await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		var ruta: String = "%s/%s_%s_%s.png" % [carpeta, cual, k, "antes" if antes else "despues"]
		img.save_png(ruta)
		print("captura ", ruta)
	quit()


func _terrazas_del_juego_en_el_lab(m: Node3D) -> void:
	for h in (m.get("_props") as Node).get_children():
		if String(h.name).begins_with("Terraza_"):
			(h as Node3D).visible = false
	var tf := TerraFina3D.new()
	tf.m = m
	m.add_child(tf)
	tf.call("_montar_terrazas", m.get("_mapa"), S)


## Manchas irregulares sobre la terraza y el suelo de alrededor, en el estado del juego (lo que lee el shader nuevo).
func _poner_estados(m: Node, c: Vector2i, cual: String) -> void:
	var manchas: Array = [
		["quemada", c + Vector2i(-2, -1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]],
		["mojada", c + Vector2i(1, -1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 2)]],
		["helada", c + Vector2i(-1, 1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]]]
	if cual == "lab":
		manchas = [["quemada", c + Vector2i(-1, -1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]],
			["mojada", c + Vector2i(1, -1), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]]]
	for mancha in manchas:
		for o in mancha[2]:
			var q: Vector2i = (mancha[1] as Vector2i) + (o as Vector2i)
			Terreno3D.estados.poner(q, String(mancha[0]), true)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
