extends "res://herramientas/escenario_base.gd"
## CAPTURAS ANTES/DESPUÉS de la hierba procedural y el detalle en bloques (6/11, Pablo: «quitar la planicie del nivel»). NECESITA VENTANA:
##   E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --path E:\magic-symbols --resolution 1280x720 --script res://herramientas/captura_hierba_bloques.gd -- <antes|despues> [carpeta]
## `antes` apaga `detalle_en_bloques` (la hierba de una malla y escala uniforme, los adornos parejos por todo el mapa); `despues` es el juego tal cual. Tres zonas del
## Bosque (PruebaBosque, desde las letras, como los escenarios) con la cámara del juego a 12 u: la llanura de arriba, la senda de hierba del oeste y el claro del este.
## Se miran a ojo (no hay `_ok`). Salen en docs/capturas/hierba_bloques/<zona>_<antes|despues>.png.

const TAM_REGION: float = 12.0
const ZONAS: Array = [["llanura", Vector2i(6, 22)], ["senda_oeste", Vector2i(2, 36)], ["claro_este", Vector2i(15, 39)], ["totems", Vector2i(8, 6)]]

var _dir: String = "res://docs/capturas/hierba_bloques"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0] if a.size() > 0 else "despues"
	if a.size() > 1 and a[1] != "":
		_dir = a[1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
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
		maqueta.call("ir_a", z[1] as Vector2i)
		maqueta.set("_tam_camara", TAM_REGION)
		var cam: Camera3D = maqueta.get("_camara") as Camera3D
		if cam != null:
			cam.size = TAM_REGION
		await avanzar_s(2.5)
		var ruta: String = ProjectSettings.globalize_path(_dir).path_join("%s_%s.png" % [z[0], modo])
		var err: int = root.get_viewport().get_texture().get_image().save_png(ruta)
		print("foto %s_%s %s" % [z[0], modo, "guardada" if err == OK else "ERROR %d" % err])
	var h: Hierba3D = maqueta.get("_hierba") as Hierba3D
	if h != null:
		print("hierba (%s): %s" % [modo, h.estadisticas()])


## Como `cargar` del armazón (desde las letras), con el interruptor puesto ANTES de `_ready`.
func _cargar_con(nuevo: bool) -> void:
	reloj = Reloj.new()
	root.add_child(reloj)
	maqueta = (load(RUTA_BOSQUE) as PackedScene).instantiate()
	maqueta.set("usar_escena", false)
	maqueta.set("detalle_en_bloques", nuevo)
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
