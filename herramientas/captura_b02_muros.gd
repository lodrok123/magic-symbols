extends "res://herramientas/escenario_base.gd"
## CAPTURAS DE LOS MUROS GOBLIN DEL BOSQUE 02 (5/11). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_b02_muros.gd -- <prefijo> [carpeta]
## El campamento goblin con la cámara del juego (norte arriba) a varios zooms, cada muro/puerta/torre de cerca y el arco de la boca de la Cueva. Se miran a ojo.

const RUTA: String = "res://escenas/PruebaBosque02.tscn"
const T_ASENTAR: float = 2.0

var _dir: String = "res://docs/capturas/b02_muros"
var _pre: String = "x"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_pre = a[0]
	if a.size() > 1:
		_dir = a[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	_ocultar_ui(root)
	await avanzar(30)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	for r in [["campamento", Vector2i(31, 15), 12.0], ["campamento_cerca", Vector2i(30, 15), 7.0], ["puerta", Vector2i(28, 16), 5.0], ["torre_este", Vector2i(34, 13), 5.0],
			["torre_oeste", Vector2i(30, 19), 5.0], ["muro_norte", Vector2i(28, 13), 5.0], ["muro_sur", Vector2i(28, 19), 5.0], ["arco_boca", Vector2i(32, 24), 8.0]]:
		colocar_jugador(r[1] as Vector2i)
		maqueta.set("_tam_camara", float(r[2]))
		var cam: Camera3D = maqueta.get("_camara") as Camera3D
		if cam != null:
			cam.size = float(r[2])
		await avanzar_s(T_ASENTAR)
		_foto("%s_%s" % [_pre, String(r[0])])


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_dir).path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
