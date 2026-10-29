extends "res://herramientas/prueba_sensacion_2.gd"
## FOTOS DE LA ESQUIVA PERFECTA (29/10): filtro violeta y copias del tiempo bruja, con la cámara del juego. NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_bruja.gd -- [carpeta]   (por defecto res://docs/capturas/bruja)
## La jugadora rueda dentro de un aviso en su ventana; se fotografía antes, al entrar, a media estela y al acabar.

var _dir: String = "res://docs/capturas/bruja"


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
	await _foto("0_antes")
	AvisoAtaque3D.circulo(maqueta, j.position, 1.5, 0.3, null)
	await avanzar(2)
	j._iniciar_voltereta(Vector3(-1, 0, 0))
	_ok("hay tiempo bruja", TiempoBruja.activa())
	await _foto_tras(0.2, "1_entra")
	await _foto_tras(0.3, "2_estela")
	await _foto_tras(0.4, "3_mitad")
	while TiempoBruja.activa():
		await avanzar(1)
	await _foto_tras(0.3, "4_despues")
	print("FOTOS en %s" % ProjectSettings.globalize_path(_dir))


## Espera `s` segundos REALES (con el mundo a 0,3 el reloj de juego va más lento) y fotografía.
func _foto_tras(s: float, nombre: String) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		await process_frame
	await _foto(nombre)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, nombre])
