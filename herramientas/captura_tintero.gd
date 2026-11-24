extends "res://herramientas/escenario_base.gd"
## EL TINTERO DE ESCRIBA (24/11, lámina de Pablo): tres fragmentos en tres cofres, y al reunirlos la tinta máxima sube 20. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_tintero.gd -- [carpeta]
## Comprueba el contador del inventario (0/3, 2/3, reunido, completo), que la barra de la partida sube en el acto (100 → 120) y que el cuarto
## tintero deja la tinta en 180 (con los jefes llegará a 300). Fotos en res://docs/capturas/tintero (lleva .gdignore).

const ESPERA_MENU_S: float = 0.9

var _dir: String = "res://docs/capturas/tintero"
var _menu: MenuPestanas = null


func _foto(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join("%s.png" % nombre))
	if _menu != null and _menu._tintero != null:
		var r: Rect2 = _menu._tintero.get_global_rect().grow_individual(40.0, 30.0, 220.0, 20.0)
		var cerca: Image = img.get_region(Rect2i(r))
		cerca.resize(cerca.get_width() * 2, cerca.get_height() * 2, Image.INTERPOLATE_LANCZOS)
		cerca.save_png(_dir.path_join("%s_cerca.png" % nombre))
	print("foto " + nombre)


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Flags.nuevo()
	Estado.nuevo()
	_ok("la mejora existe: 4 tinteros de +20", Mejoras.existe("tinta_tintero") and Mejoras.tope("tinta_tintero") == 4 and is_equal_approx(Tinta.por_tintero(), 20.0))
	_ok("el fragmento es una pieza de mejora (3 por tintero)", Objetos.es_pieza("fragmento_tintero") and int(Objetos.efecto("fragmento_tintero").get("piezas", 0)) == 3)
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	await avanzar_s(1.2)
	# La barra de la jugadora (en una partida nueva no está registrada en `Partida.tinta`: la tinta se entera sola en `actualizar`).
	var tinta: Tinta = jugador.get("tinta") as Tinta
	_ok("la jugadora tiene su tinta (100 al empezar)", tinta != null and is_equal_approx(tinta.maxima, 100.0), str(tinta.maxima) if tinta != null else "sin tinta")
	if tinta == null:
		return
	_menu = lanzador.get("menu") as MenuPestanas
	_ok("el lanzador monta el menú con el tintero", _menu != null and _menu._tintero != null)
	if _menu == null or _menu._tintero == null:
		return
	reloj.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu.abrir()
	await avanzar_s(ESPERA_MENU_S)
	_ok("sin fragmentos: Tintero 0/3 · te faltan 3", _menu._tintero.texto() == "Tintero 0/3" and _menu._tintero.subtexto() == "Te faltan 3", _menu._tintero.texto())
	_foto("tintero_menu_0de3")
	Estado.i().agregar("fragmento_tintero", 2)
	await avanzar_s(0.6)
	_ok("con dos: Tintero 2/3 · te falta 1 (la tinta aún no sube)", _menu._tintero.texto() == "Tintero 2/3" and _menu._tintero.subtexto() == "Te falta 1" and is_equal_approx(tinta.maxima, 100.0))
	_foto("tintero_menu_2de3")
	Estado.i().agregar("fragmento_tintero", 1)
	await avanzar_s(0.12)
	_ok("el tercero reúne el tintero: el contador vuelve a 0/3 con un tintero reunido", _menu._tintero.fragmentos == 0 and _menu._tintero.tinteros == 1)
	_foto("tintero_menu_reunido")
	_menu.cerrar()
	await avanzar_s(0.4)
	# Con el menú abierto el juego está en pausa: la barra se entera al volver al juego (`Tinta.actualizar`).
	_ok("al volver al juego, la tinta máxima de la jugadora ha subido a 120", is_equal_approx(tinta.maxima, 120.0), "máxima %.0f" % tinta.maxima)
	_ok("lo ganado entra en la barra (no se queda a medias)", tinta.actual >= 119.0, "%.1f" % tinta.actual)
	Estado.i().agregar("fragmento_tintero", 9)
	await avanzar_s(0.2)
	_ok("los cuatro tinteros: tinta máxima 180 (los jefes ponen el resto hasta 300)", is_equal_approx(tinta.maxima, 180.0), "%.0f" % tinta.maxima)
	Estado.i().agregar("fragmento_tintero", 3)
	await avanzar_s(0.2)
	_ok("con la mejora en su tope, los fragmentos de más se quedan en la mochila y no suben nada", is_equal_approx(tinta.maxima, 180.0) and Estado.i().cuenta("fragmento_tintero") == 3)
	_menu.abrir()
	await avanzar_s(ESPERA_MENU_S)
	_ok("todos: tintero entero y «Tinta al máximo»", _menu._tintero.completo() and _menu._tintero.subtexto() == "Tinta al máximo")
	_foto("tintero_menu_completo")
	_menu.cerrar()
	await avanzar_s(0.3)
	_ok("capturas hechas", true)
