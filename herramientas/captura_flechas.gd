extends "res://herramientas/prueba_sensacion_3.gd"
## FOTO DE LAS FLECHAS DE AVISO (29/10, lote 3): un goblin fuera de pantalla marca un ataque y su flecha sale en el borde. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_flechas.gd -- [carpeta]   (por defecto res://docs/capturas/flechas)

var _dir: String = "res://docs/capturas/flechas"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		return
	_vaciar_nivel()
	var j: Jugador3D = _jugadora(Vector2i(11, 33))
	await avanzar_s(1.0)
	var este: Combate3D = _goblin(Vector2i(11, 33))
	este.position = j.position + Vector3(13.0, 0.0, 0.0)
	var norte: Combate3D = _goblin(Vector2i(11, 33))
	norte.position = j.position + Vector3(-4.0, 0.0, -11.0)
	AvisoAtaque3D.circulo(maqueta, este.position, 1.5, 3.0, este)
	var a2: AvisoAtaque3D = AvisoAtaque3D.circulo(maqueta, norte.position, 1.5, 3.0, norte)
	await avanzar_s(1.0)
	await _foto("1_flechas")
	while is_instance_valid(a2) and a2.queda() > AvisoAtaque3D.VENTANA_ESQUIVA * 0.5:
		await avanzar(1)
	await _foto("2_en_ventana")
	print("FLECHAS %d · FOTOS en %s" % [int((_director() as Object).get("flechas")), ProjectSettings.globalize_path(_dir)])


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, nombre])
