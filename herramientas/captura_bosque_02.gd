extends "res://herramientas/escenario_base.gd"
## CAPTURAS DEL BOSQUE 02 (Juego, 3/11). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_bosque_02.gd -- [carpeta]   (por defecto res://docs/capturas/bosque_02)
## Una cenital del mapa entero (cámara propia, ortogonal, mirando hacia abajo) y cada región con la cámara del juego. Lo que se ve es lo que hay: se miran a ojo (no hay `_ok`).

const RUTA: String = "res://escenas/PruebaBosque02.tscn"
const TAM_REGION: float = 12.0
const TAM_CENITAL: float = 100.0
const CENTRO_MAPA: Vector2i = Vector2i(20, 26)      ## 13/11: el mapa mide 40 × 52 (12 filas nuevas al norte)
const ALTURA_CENITAL: float = 60.0
const T_ASENTAR: float = 2.5

var _dir: String = "res://docs/capturas/bosque_02"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
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
	await _cenital()
	for r in [["linde", Vector2i(8, 44)], ["tronco", Vector2i(14, 43)], ["orilla", Vector2i(19, 43)], ["pasillo", Vector2i(24, 36)], ["boca", Vector2i(32, 36)], ["pradera", Vector2i(21, 28)],
			["campamento", Vector2i(32, 27)], ["ruinas_este", Vector2i(19, 20)], ["plaza_oeste", Vector2i(8, 20)], ["estanque", Vector2i(29, 20)], ["santuario", Vector2i(8, 28)],
			["escondite", Vector2i(8, 35)], ["esquina_noroeste", Vector2i(5, 17)], ["esquina_sureste", Vector2i(34, 46)], ["sendero_sumicio", Vector2i(24, 4)]]:
		colocar_jugador(r[1] as Vector2i)
		maqueta.set("_tam_camara", TAM_REGION)
		var cam: Camera3D = maqueta.get("_camara") as Camera3D
		if cam != null:
			cam.size = TAM_REGION
		await avanzar_s(T_ASENTAR)
		_foto("region_" + String(r[0]))


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)


func _cenital() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = TAM_CENITAL
	var centro: Vector3 = Terreno3D.centro_de(CENTRO_MAPA, 0.0)
	maqueta.add_child(cam)
	cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3(0.0, 0.0, -1.0)), centro + Vector3(0.0, ALTURA_CENITAL, 0.0))
	cam.far = ALTURA_CENITAL * 3.0
	cam.current = true
	await avanzar_s(1.5)
	_foto("cenital_mapa_entero")
	cam.current = false
	cam.queue_free()
	await avanzar(3)
