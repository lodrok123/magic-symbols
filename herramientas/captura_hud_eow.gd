extends "res://herramientas/escenario_base.gd"
## EL HUD Y EL MENÚ ESTILO ECHOES OF WISDOM, A LA VISTA (24/10; presentacion/ui/hud_eow.gd y menu_pestanas.gd). NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_hud_eow.gd -- [carpeta]
## Carpeta por defecto: res://docs/capturas/hud_eow (lleva .gdignore). Fotos (la escena es el bosque):
##   hud_lleno · hud_gastando_frasco · hud_frascos_vacios · hud_balsamo_activo (pantalla entera y recorte de cada esquina)
##   menu_inventario (con el detalle de una poción) · menu_inventario_epico · menu_misiones · menu_proximamente

const OBJETOS_MENU: Array = [["seta", 3], ["lavanda", 4], ["helecho", 2], ["baya", 5], ["nucleo_eco", 1], ["geoda_resonante", 2], ["colmillo_goblin", 4],
	["seta_asada", 1], ["pocion", 3], ["tonico_tinta", 2], ["balsamo_protector", 1], ["infusion_brezo", 2]]
const RECORTE_ARRIBA: Rect2i = Rect2i(0, 60, 380, 150)
const ESPERA_MENU_S: float = 0.9

var _dir: String = "res://docs/capturas/hud_eow"


func _foto(nombre: String, recorte: Rect2i = Rect2i()) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if recorte.size != Vector2i.ZERO:
		img = img.get_region(recorte)
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	img.save_png(_dir.path_join("%s.png" % nombre))
	print("foto " + nombre, " ", img.get_size())


func _hud_fotos(base: String) -> void:
	var v: Vector2i = root.get_viewport().get_texture().get_size()
	_foto(base)
	_foto(base + "_arriba", RECORTE_ARRIBA)
	_foto(base + "_circulo", Rect2i(v.x - 200, v.y - 190, 200, 190))


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
	Estado.i().capacidad = 14
	for par in OBJETOS_MENU:
		Estado.i().agregar(String(par[0]), int(par[1]))
	Estado.i().oro = 137
	var M: Misiones = Misiones.nuevo()
	M.definir({"id": "a", "titulo": "Las cuatro tareas", "tipo": "principal", "texto": "El guardabosques pide ayuda con los goblins que rondan el camino. Habla con él cuando termines.",
		"origen": "Guardabosques", "objetivos": ["Pisar la baldosa", "Vencer a los goblins", "Hablar con el guardabosques"], "recompensa": {"oro": 50, "items": {"pocion": 2}}})
	M.definir({"id": "b", "titulo": "Una flor para la herbolaria", "tipo": "secundaria", "texto": "Busca una flor de rocío junto al río.", "objetivos": ["Coger la flor"]})
	M.activar("a")
	M.activar("b")
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	await avanzar_s(1.5)
	var hud: HudEoW = jugador.get("hud_eow") as HudEoW
	_ok("el jugador monta el HUD nuevo", hud != null)
	if hud == null:
		return
	var tinta: Tinta = jugador.get("tinta") as Tinta
	hud.consumibles.equipar("pocion")
	jugador.set("vida", 72.0)
	tinta.actual = 64.0
	await avanzar_s(0.8)
	_hud_fotos("hud_lleno")
	# Gastar un frasco: un lanzamiento de 25 con la barra casi vacía.
	tinta.actual = 6.0
	await avanzar(3)
	tinta.gastar("corro")
	await avanzar_s(0.12)
	_hud_fotos("hud_gastando_frasco")
	# Frascos vacíos y barra baja.
	await avanzar_s(0.8)
	tinta.frascos = 0
	tinta.actual = 18.0
	hud.consumibles.equipar("tonico_tinta")
	await avanzar_s(0.5)
	_hud_fotos("hud_frascos_vacios")
	# El bálsamo activo: anillo de tiempo alrededor del círculo.
	hud.consumibles.equipar("balsamo_protector")
	hud.consumibles.usar("balsamo_protector")
	await avanzar_s(5.0)
	_hud_fotos("hud_balsamo_activo")
	# --- El menú ---
	var menu: MenuPestanas = lanzador.get("menu") as MenuPestanas
	_ok("el lanzador monta el menú con pestañas", menu != null)
	if menu == null:
		return
	reloj.process_mode = Node.PROCESS_MODE_ALWAYS      # el menú pausa el árbol: el reloj del armazón tiene que seguir contando
	hud.consumibles.equipar("pocion")
	menu.abrir()
	await avanzar_s(ESPERA_MENU_S)
	for i in range(menu.pilas().size()):
		if String(menu.pilas()[i][0]) == "pocion":
			menu._elegir(i)
	await avanzar_s(0.3)
	_foto("menu_inventario")
	for i in range(menu.pilas().size()):
		if String(menu.pilas()[i][0]) == "nucleo_eco":
			menu._elegir(i)
	await avanzar_s(0.4)
	_foto("menu_inventario_epico")
	menu.cambiar_pestana(MenuPestanas.INDICE_MISIONES)
	await avanzar_s(0.3)
	_foto("menu_misiones")
	menu.cambiar_pestana(1)
	await avanzar_s(0.3)
	_foto("menu_proximamente")
	menu.cerrar()
	await avanzar_s(0.5)
	_ok("capturas hechas", true)
