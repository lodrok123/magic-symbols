extends "res://herramientas/escenario_base.gd"
## LA SAVIA EN EL INVENTARIO, A LA VISTA (24/11): la gota partida en tres bajo la rejilla del menú (fragmentos que llevas y los que faltan). NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_savia.gd -- [carpeta]
## Carpeta por defecto: res://docs/capturas/savia (lleva .gdignore). Fotos: savia_menu_0de3, savia_menu_2de3, savia_menu_reunida, savia_menu_completa (+ _cerca de cada una).

const ESPERA_MENU_S: float = 0.9

var _dir: String = "res://docs/capturas/savia"
var _menu: MenuPestanas = null


func _foto(nombre: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_dir.path_join("%s.png" % nombre))
	if _menu != null and _menu._savia != null:
		var r: Rect2 = _menu._savia.get_global_rect().grow_individual(120.0, 30.0, 200.0, 20.0)
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
	for par in [["seta", 3], ["baya", 5], ["pocion", 2], ["resina", 2]]:
		Estado.i().agregar(String(par[0]), int(par[1]))
	Estado.i().oro = 85
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	await avanzar_s(1.2)
	_menu = lanzador.get("menu") as MenuPestanas
	_ok("el lanzador monta el menú", _menu != null)
	if _menu == null:
		return
	reloj.process_mode = Node.PROCESS_MODE_ALWAYS
	_menu.abrir()
	await avanzar_s(ESPERA_MENU_S)
	_ok("sin fragmentos: Savia 0/3 · te faltan 3", _menu._savia.texto() == "Savia 0/3" and _menu._savia.subtexto() == "Te faltan 3", _menu._savia.texto() + " · " + _menu._savia.subtexto())
	_foto("savia_menu_0de3")
	Estado.i().agregar("fragmento_savia", 2)
	await avanzar_s(0.6)
	_ok("con dos: Savia 2/3 · te falta 1", _menu._savia.texto() == "Savia 2/3" and _menu._savia.subtexto() == "Te falta 1", _menu._savia.texto() + " · " + _menu._savia.subtexto())
	_foto("savia_menu_2de3")
	Estado.i().agregar("fragmento_savia", 1)
	await avanzar_s(0.12)
	_ok("el tercero reúne la savia: vuelve a 0/3 y la vida máxima sube", _menu._savia.fragmentos == 0 and _menu._savia.savias == 1 and is_equal_approx(Estado.i().vida_max, 120.0))
	_foto("savia_menu_reunida")
	_menu.cerrar()
	await avanzar_s(0.4)
	Estado.i().mejoras["vida_max"] = Mejoras.tope("vida_max")
	Mejoras.aplicar_todas(Estado.i())
	_menu.abrir()
	await avanzar_s(ESPERA_MENU_S)
	_ok("todas las savias: gota entera y «Vida al máximo»", _menu._savia.completa() and _menu._savia.subtexto() == "Vida al máximo")
	_foto("savia_menu_completa")
	_menu.cerrar()
	await avanzar_s(0.3)
	_ok("capturas hechas", true)
