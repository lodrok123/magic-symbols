extends "res://herramientas/escenario_base.gd"
## CAPTURAS DEL BOSQUE 01 v01 (Juego, 24/10). NECESITA VENTANA:
##   godot --path . --resolution 1280x720 --script res://herramientas/captura_bosque_01_v01.gd -- [carpeta]   (por defecto res://docs/capturas/bosque_01_v01)
## Una cenital del mapa entero (cámara propia, ortogonal, mirando hacia abajo), cada región y sala con la cámara del juego, el campamento cerrado, el desafío de la barrera (la barrera ᛜ + flecha
## parando las flechas de los arqueros del paso), la boca de la Cueva con Marimanta, los NPC y la vuelta de la Cueva. Lo que se ve es lo que hay: se miran a ojo (no hay `_ok`).

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
const TAM_REGION: float = 12.0
const TAM_CERCA: float = 6.0
const TAM_CENITAL: float = 124.0
const CENTRO_MAPA: Vector2i = Vector2i(26, 22)
const ALTURA_CENITAL: float = 60.0
const T_ASENTAR: float = 2.5
const TAM_PASO: float = 17.0                  ## cámara del desafío de la barrera: la pasarela entera y los dos arqueros al fondo

var _dir: String = "res://docs/capturas/bosque_01_v01"
var reglas: Node = null


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
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	lanzador.tinta = null
	_ocultar_ui(root)
	await avanzar(30)
	reglas = maqueta.get_node_or_null("Reglas")
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	await _cenital()
	for r in [["linde", Vector2i(3, 10)], ["tala", Vector2i(9, 3)], ["prado", Vector2i(13, 15)], ["santuario", Vector2i(24, 15)], ["claro_norte", Vector2i(20, 3)], ["hierba_alta", Vector2i(31, 17)],
			["explanada", Vector2i(24, 30)], ["escondite_cerrado", Vector2i(14, 26)], ["camara_a", Vector2i(8, 36)], ["nicho_antorchas", Vector2i(19, 9)], ["nicho_hierba", Vector2i(18, 24)],
			["hondonada", Vector2i(40, 19)], ["atajo_cerrado", Vector2i(24, 24)]]:
		await _mirar(r[1] as Vector2i, TAM_REGION, T_ASENTAR)
		_foto("region_" + String(r[0]))
	await _gente()
	await _paso_batido()
	await _campamento()
	await _vuelta_de_la_cueva()


func _mirar(c: Vector2i, tam: float, s: float) -> void:
	colocar_jugador(c)
	maqueta.set("_tam_camara", tam)
	var cam: Camera3D = maqueta.get("_camara") as Camera3D
	if cam != null:
		cam.size = tam
	await avanzar_s(s)


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)


## Cámara propia, ortogonal y mirando hacia abajo, centrada en el mapa: el mapa entero de un vistazo.
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


func _npc(tipo: String) -> Dictionary:
	if reglas == null:
		return {}
	for g in (reglas.get("_gente") as Array):
		if String((g as Dictionary)["tipo"]) == tipo:
			return g
	return {}


func _gente() -> void:
	var gob: Dictionary = _npc("goblin_base")
	var elfo: Dictionary = _npc("elfo_base")
	var mari: Dictionary = _npc("marimanta")
	if not gob.is_empty():
		await _mirar(Vector2i(8, 4), TAM_CERCA, 4.0)
		_foto("npc_goblin_lenador_talando")
	if not elfo.is_empty():
		await _mirar(Vector2i(16, 15), TAM_CERCA, 1.0)
		await avanzar_s(0.5)
		_foto("npc_elfo_saludo")
	if not mari.is_empty():
		await _mirar(Vector2i(44, 19), TAM_CERCA, 1.0)
		_foto("boca_cueva_con_marimanta_1")
		await avanzar_s(6.0)
		_foto("boca_cueva_con_marimanta_2")
		await _mirar(Vector2i(41, 18), TAM_REGION, 1.5)
		_foto("boca_cueva_vista_general")


func _paso_batido() -> void:
	for n in get_nodes_in_group("combate3d"):
		var cb: Combate3D = n as Combate3D
		if cb.fijo:
			cb.quieto = false
	for n in get_nodes_in_group("combate3d"):
		var cq: Combate3D = n as Combate3D
		if cq.fijo:
			cq.quieto = true            # la primera foto es ANTES de que vean a la jugadora
	await _mirar(Vector2i(8, 5), TAM_PASO, 1.5)
	_foto("desafio_barrera_1_antes")
	for n in get_nodes_in_group("combate3d"):
		var cq2: Combate3D = n as Combate3D
		if cq2.fijo:
			cq2.quieto = false
	colocar_jugador(Vector2i(8, 7))                      # la cámara con la pasarela entera y los arqueros al fondo
	maqueta.set("_tam_camara", TAM_PASO)
	(maqueta.get("_camara") as Camera3D).size = TAM_PASO
	await avanzar_s(3.5)
	_foto("desafio_barrera_2_arqueros_disparan")
	lanzar("tierra", ["barrera", "flecha"], Vector3(0.0, 0.0, 1.0))
	await avanzar_s(2.2)
	_foto("desafio_barrera_3_barrera_plantada")
	await avanzar_s(2.5)
	_foto("desafio_barrera_4_flechas_paradas")
	for n in get_nodes_in_group("combate3d"):
		var cb2: Combate3D = n as Combate3D
		if cb2.fijo:
			cb2.muerto = true
			cb2.quieto = true


func _campamento() -> void:
	await _mirar(Vector2i(31, 5), 9.0, 1.5)
	_foto("campamento_1_puerta_goblin")
	for r in (maqueta.get("_reactivos") as Array):
		if is_instance_valid(r) and String(r.tipo) == "puerta_goblin":
			r.on_spell_hit(_fuego(), Vector3.ZERO)
	await avanzar_s(3.0)
	_foto("campamento_2_ardiendo")
	var t0: float = reloj.t
	while Terreno3D.bloqueada(Vector2i(33, 5)) and reloj.t - t0 < 20.0:
		await avanzar_s(0.25)
	colocar_jugador(Vector2i(37, 5))
	maqueta.set("_tam_camara", 13.0)
	await avanzar_s(3.0)
	_foto("campamento_3_cerrado_con_los_cuatro_goblins")
	for n in get_nodes_in_group("combate3d"):
		var cb: Combate3D = n as Combate3D
		if Rect2i(35, 1, 12, 10).has_point(Terreno3D.celda_de(cb.casa)):
			cb.muerto = true
	await avanzar_s(Cofre3D.T_APARECE_DISOLVER + 3.0)
	_foto("campamento_4_abierto_con_el_cofre_de_la_llave")


func _fuego() -> RuneData:
	var r := RuneData.new()
	var tags: Array[String] = ["fuego", "calor"]
	r.tags = tags
	return r


func _esperar_viaje() -> void:
	var pared: int = Time.get_ticks_msec()
	while not Niveles.en_curso and Time.get_ticks_msec() - pared < 4000:
		await process_frame
	while Niveles.en_curso and Time.get_ticks_msec() - pared < 90000:
		await process_frame
	await avanzar_s(1.5)
	maqueta = current_scene if current_scene != null else maqueta
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null
	reglas = maqueta.get_node_or_null("Reglas")
	_ocultar_ui(root)


func _vuelta_de_la_cueva() -> void:
	# Con algo resuelto (tótems, puerta X) para que la vuelta lo enseñe conservado.
	Flags.i().poner("bosque01v1.totem.fuego_1")
	Flags.i().poner("bosque01v1.totem.fuego_2")
	Flags.i().poner("bosque01v1.totem.fuego_3")
	Flags.i().poner("bosque01v1.puerta_x.abierta")
	colocar_jugador(Vector2i(46, 18))
	await _esperar_viaje()
	maqueta.set("_tam_camara", TAM_CERCA)
	await avanzar_s(1.0)
	_foto("cueva_llegada_desde_el_bosque")
	colocar_jugador(Vector2i(4, 18))
	await _esperar_viaje()
	maqueta.set("_tam_camara", 8.0)
	await avanzar_s(2.0)
	_foto("vuelta_de_la_cueva_en_la_boca")
	await _mirar(Vector2i(22, 15), 12.0, 3.0)
	_foto("vuelta_de_la_cueva_totems_y_puerta_conservados")
