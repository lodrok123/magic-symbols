extends "res://herramientas/escenario_base.gd"
## CAPTURAS ANTES/DESPUÉS de la hierba en matas (5/11, Pablo: «acumulaciones más densas» y adornos en los claros). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_hierba_matas.gd -- <antes|despues> [carpeta]
## `antes` apaga `hierba_en_matas` y `adornos_en_claros` (el reparto pareja de siempre); `despues` es el juego tal cual. Tres zonas del Bosque 02 con la cámara del juego
## (fija al norte, ortogonal, 12 u): la pradera alta, el claro de las setas y la orilla. Se miran a ojo (no hay `_ok`).

const RUTA: String = "res://escenas/PruebaBosque02.tscn"
const TAM_REGION: float = 12.0
const ZONAS: Array = [["pradera", Vector2i(21, 16)], ["claro_setas", Vector2i(26, 32)], ["orilla", Vector2i(19, 31)], ["linde", Vector2i(8, 33)]]

var _dir: String = "res://docs/capturas/hierba_matas"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0] if a.size() > 0 else "despues"
	if a.size() > 1 and a[1] != "":
		_dir = a[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	await _cargar_con(modo == "despues")
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	_ocultar_ui(root)
	await avanzar(30)
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	for z in ZONAS:
		colocar_jugador(z[1] as Vector2i)
		maqueta.set("_tam_camara", TAM_REGION)
		var cam: Camera3D = maqueta.get("_camara") as Camera3D
		if cam != null:
			cam.size = TAM_REGION
		await avanzar_s(2.5)
		root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(_dir).path_join("%s_%s.png" % [z[0], modo]))
		print("foto %s_%s" % [z[0], modo])


## Como `cargar` del armazón, pero con el nivel horneado (usar_escena) y los dos interruptores puestos ANTES de `_ready`.
func _cargar_con(nuevo: bool) -> void:
	reloj = Reloj.new()
	root.add_child(reloj)
	maqueta = (load(RUTA) as PackedScene).instantiate()
	maqueta.set("usar_escena", true)
	maqueta.set("hierba_en_matas", nuevo)
	maqueta.set("adornos_en_claros", nuevo)
	root.add_child(maqueta)
	var n: int = 0
	while n < 600 and (get_first_node_in_group("spellcaster") == null or Terreno3D.agua_sim == null):
		await process_frame
		n += 1
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null
	var pared: int = Time.get_ticks_msec()
	while jugador != null and not jugador.puede_lanzar() and Time.get_ticks_msec() - pared < 30000:
		await process_frame


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
