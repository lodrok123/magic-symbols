extends "res://herramientas/escenario_base.gd"
## EL ATUENDO EN EL JUEGO DE VERDAD (12/11, Pablo: «sigue funcionando mal, se ven mallas estiradas, agujeros»): carga el bosque, mete el atuendo en la mochila,
## se lo pone por `Atuendos.poner` (lo mismo que hace la pestaña Vestuario) y fotografía la pantalla entera y un recorte ampliado de la jugadora quieta,
## andando y lanzando. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_atuendo_juego.gd -- [<atuendo>] [<carpeta>]
## Carpeta por defecto: res://docs/capturas/vestuario/<atuendo>_juego.

const AMPLIA: int = 4
const RECORTE: Vector2i = Vector2i(180, 220)

var _dir: String = ""


func _foto(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join("%s.png" % nombre))
	var pj: Node3D = jugador.get("pj") as Node3D
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	if pj != null and cam != null:
		var p: Vector2 = cam.unproject_position(pj.global_position + Vector3(0, 0.5, 0))
		var r := Rect2i(Vector2i(p) - RECORTE / 2, RECORTE).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var c: Image = img.get_region(r)
		c.resize(c.get_width() * AMPLIA, c.get_height() * AMPLIA, Image.INTERPOLATE_LANCZOS)
		c.save_png(_dir.path_join("%s_cerca.png" % nombre))
	print("foto " + nombre)


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	var atuendo: String = a[0] if a.size() > 0 and a[0] != "" else "atuendo_lobo"
	_dir = a[1] if a.size() > 1 and a[1] != "" else "res://docs/capturas/vestuario/%s_juego" % atuendo
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	Estado.i().agregar(atuendo)
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	await avanzar_s(1.0)
	var pj: Node = jugador.get("pj") as Node
	_ok("la jugadora se pone el atuendo por Atuendos.poner (como la pestaña Vestuario)", Atuendos.poner(pj, atuendo), str(pj.call("ropa_puesta")))
	_ok("las zonas tapadas", true, str(Ropa3D.zonas_apagadas(pj.get("_modelo") as Node3D)))
	# La jugadora nace entre los abetos (la silueta tapa la ropa): unas casillas hacia la cámara, al claro.
	var c: Vector2i = celda_jugador()
	for d in [Vector2i(0, 3), Vector2i(3, 3), Vector2i(-3, 3), Vector2i(0, 5)]:
		colocar_jugador(c + d)
		await avanzar_s(1.0)
		_foto("juego_idle_%d_%d" % [d.x, d.y])
	colocar_jugador(c + Vector2i(0, 3))
	await avanzar_s(1.2)
	_foto("juego_idle")
	_tecla(KEY_D, true)
	await avanzar_s(0.45)
	_foto("juego_andar_1")
	await avanzar_s(0.3)
	_foto("juego_andar_2")
	_tecla(KEY_D, false)
	_tecla(KEY_S, true)
	await avanzar_s(0.5)
	_foto("juego_andar_frente")
	_tecla(KEY_S, false)
	await avanzar_s(0.6)
	_foto("juego_idle_2")
