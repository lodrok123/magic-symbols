extends "res://herramientas/escenario_base.gd"
## MATERIALES DE LA CUEVA, A LA VISTA (23/10; docs/MATERIALES_CUEVA.md). NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_materiales_cueva.gd -- [carpeta]   (por defecto res://docs/capturas/materiales_cueva)
## Fotos: el alga sin hielo (no está) y con la charca helada (aparece) · el aviso común al cogerla · el aviso épico (borde morado) y su destello ·
## el color del aviso legendario (no hay objeto legendario en DATOS: lo pone la secuencia del cofre; aquí solo se enseña el color de la calidad) ·
## el basalto sin enfriar (no está) y sobre la roca recién enfriada (aparece).

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const CHARCA: Rect2i = Rect2i(20, 13, 5, 4)
const ZOOM_CAMARA: float = 7.0

var _dir: String = "res://docs/capturas/materiales_cueva"


func _helar_charca(si: bool) -> void:
	for y in range(CHARCA.position.y, CHARCA.end.y):
		for x in range(CHARCA.position.x, CHARCA.end.x):
			Terreno3D.agua_sim.helar_casilla(Vector2i(x, y), si)
			Terreno3D.poner_helada(Vector2i(x, y), si)


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _zoom() -> void:
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	maqueta.set("_tam_camara", ZOOM_CAMARA)
	if cam != null:
		cam.size = ZOOM_CAMARA


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
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(30)
	var z: Puzle3D = maqueta.get_node_or_null("Puzles") as Puzle3D
	if z == null:
		return
	# --- Alga ---
	colocar_jugador(Vector2i(22, 17))
	_zoom()
	await avanzar_s(2.5)
	_foto("1_alga_sin_hielo")
	var alga: Recolectable3D = z.nodo("alga_c5a") as Recolectable3D
	_ok("1 sin hielo el alga no se ve", alga != null and not alga.visible_en_mundo())
	_helar_charca(true)
	await avanzar_s(1.2)
	_foto("2_alga_con_charca_helada")
	_ok("2 con la charca helada el alga se ve", alga != null and alga.visible_en_mundo())
	alga.recoger()
	await avanzar_s(0.35)
	_foto("3_aviso_comun_alga")
	await avanzar_s(2.0)
	# --- Épico ---
	AvisoObjeto.mostrar(lanzador, "nucleo_eco", 1)
	await avanzar_s(0.12)
	_foto("4_aviso_epico_destello")
	await avanzar_s(1.2)
	_foto("5_aviso_epico_dura_mas")
	await avanzar_s(3.5)
	# --- Legendario (solo el color: el objeto es el glifo, que da la secuencia del cofre) ---
	AvisoObjeto.mostrar_texto(lanzador, "Glifo de resonancia (+1)", Objetos.CALIDAD_LEGENDARIO)
	await avanzar_s(0.3)
	_foto("6_aviso_legendario_color")
	await avanzar_s(5.0)
	_helar_charca(false)
	# --- Basalto ---
	var lava: Lava3D = z.nodo("rio") as Lava3D
	colocar_jugador(Vector2i(12, 4))
	await avanzar_s(2.5)
	_foto("7_basalto_lava_sin_enfriar")
	lava.enfriar_en(Vector2i(13, 3))
	await avanzar_s(0.8)
	_foto("8_basalto_sobre_roca_enfriada")
	var bas: Recolectable3D = z.nodo("basalto_c3a") as Recolectable3D
	_ok("8 sobre la roca enfriada el basalto se ve", bas != null and bas.visible_en_mundo())
	bas.recoger()
	await avanzar_s(0.35)
	_foto("9_aviso_comun_basalto")
