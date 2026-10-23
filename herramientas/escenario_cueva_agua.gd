extends "res://herramientas/escenario_base.gd"
## EL AGUA EN LA CUEVA (23/10): banco de pruebas para revisar lo pendiente del agua con la luz, el suelo y las paredes de la Cueva.
## Carga escenas/PruebaCuevaAgua.tscn (mapa CuevaAgua: cuatro salas, un caso por sala), juega cada caso por la vía del jugador y hace
## las fotos. NECESITA VENTANA (sin ella no se compilan los sombreados y las fotos salen vacías):
##   godot --path . --resolution 1280x720 --script res://herramientas/escenario_cueva_agua.gd -- [carpeta]   (por defecto res://docs/capturas/cueva_agua)
## A · charca quieta: sin corriente propia (las «goteras» blancas eran las franjas del río sobre agua parada). Fotos para mirar las
##     costuras de las cáusticas entre trocitos y la banda de la pared del foso.
## B · charca eléctrica: una descarga de la fuente. Foto para revisar los cuadros amarillos del agua electrificada.
## C · hielo: hielo + flecha sobre la charca; foto helada, a punto de fundirse y fundida.
## D · nexo: con el nexo seco la corriente no pasa; agua + flecha al nexo y la descarga llega al tótem.
## Lo que es contrato va con `_ok`; lo que solo se mira (lo pendiente) sale como AVISO con la foto que lo enseña.

const RUTA: String = "res://escenas/PruebaCuevaAgua.tscn"
const CHARCA_A := Vector2i(4, 3)
const CHARCA_B := Vector2i(12, 3)
const CHARCA_C := Vector2i(20, 3)
const NEXO_D := Vector2i(28, 3)
const FILA_PASO: int = 6               ## el pasillo bajo las charcas, desde donde se lanza
const FILA_FOTO: int = 5               ## la orilla: con la jugadora aquí la cámara (que la sigue) deja la charca en el centro

var _dir: String = "res://docs/capturas/cueva_agua"
var _z: Puzle3D = null
var _cam: Camera3D = null


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	await avanzar(30)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_cam = maqueta.get("_camara") as Camera3D

	# 1 · Montaje
	_ok("1 Puzle3D monta las cuatro piezas sin avisos", _z != null and _z.piezas().size() == 4 and _z.avisos.is_empty(),
		"%d piezas %s" % [_z.piezas().size(), str(_z.avisos)] if _z != null else "sin Puzle3D")
	var zonas: Zonas3D = maqueta.get_node_or_null("Zonas3D") as Zonas3D
	_ok("1 cuatro zonas de luz, sin avisos", zonas != null and zonas.zonas.size() == 4 and zonas.avisos.is_empty(), str(zonas.avisos) if zonas != null else "")
	var sim: AguaSim3D = Terreno3D.agua_sim
	_ok("1 hay simulación de agua y las cuatro charcas son agua",
		sim != null and Terreno3D.es_agua(CHARCA_A) and Terreno3D.es_agua(CHARCA_B) and Terreno3D.es_agua(CHARCA_C) and Terreno3D.es_agua(NEXO_D + Vector2i(1, 0)))
	if _z == null or sim == null:
		return

	await _sala_a()
	await _sala_b()
	await _sala_c()
	await _sala_d()


# --- A · charca quieta ---------------------------------------------------------------------------------------------------

func _sala_a() -> void:
	var agua: Node = maqueta.get_node_or_null("AguaFisica")
	var mat: ShaderMaterial = agua.get("_mat") as ShaderMaterial if agua != null else null
	var flujo: Variant = mat.get_shader_parameter("flujo_activo") if mat != null else null
	_ok("A sin corriente propia: el sombreado no lleva flow map (agua_corre = false)", mat != null and (flujo == null or float(flujo) < 0.5))
	await _mirar(CHARCA_A, 8.0, 2.0)
	var corr: float = Terreno3D.agua_sim.corriente_en(Terreno3D.centro_de(CHARCA_A, 0.0)).length()
	_ok("A el agua está quieta (corriente < 0,05 u/s)", corr < 0.05, "%.3f u/s" % corr)
	_foto("A_charca")
	await _mirar(CHARCA_A + Vector2i(0, -1), 4.0, 0.5)
	_foto("A_pared_foso_cerca")
	_aviso("A revisar: costuras rectas de las cáusticas entre trocitos y la banda marrón de la pared del foso", "A_charca.png, A_pared_foso_cerca.png")


# --- B · charca eléctrica ------------------------------------------------------------------------------------------------

func _sala_b() -> void:
	var em: Node = _z.nodo("fuente_b")
	_ok("B hay fuente eléctrica", em != null)
	if em == null:
		return
	await _mirar(CHARCA_B, 8.0, 0.5)
	var r: Dictionary = {"n": 0}
	await avanzar_vigilando(EmisorRayo3D.PERIODO + 2.0, 0.1, func(_t: float) -> void:
		if int(r["n"]) == 0 and not (em.get("electrificada") as Array).is_empty():
			r["n"] = (em.get("electrificada") as Array).size()
			_foto("B_descarga")
	)
	_ok("B la fuente descarga por la charca", int(r["n"]) > 0, "%d casillas" % int(r["n"]))
	_aviso("B revisar: aspecto del agua electrificada (cuadros amarillos por casilla)", "B_descarga.png")


# --- C · hielo -----------------------------------------------------------------------------------------------------------

func _sala_c() -> void:
	var sim: AguaSim3D = Terreno3D.agua_sim
	var desde := Vector2i(CHARCA_C.x, FILA_PASO)
	await _mirar(CHARCA_C, 8.0, 0.5)
	colocar_jugador(desde)
	_ok("C sale hielo + flecha hacia la charca", lanzar_a_celda("hielo", ["flecha", "flecha"], CHARCA_C, desde))
	var t0: float = reloj.t
	var t_hielo: Dictionary = {"t": -1.0}
	await avanzar_vigilando(4.0, 0.1, func(t: float) -> void:
		if float(t_hielo["t"]) < 0.0 and sim.casilla_helada(CHARCA_C):
			t_hielo["t"] = t
	)
	var heladas: Array = []
	for y in range(1, 6):
		for x in range(17, 24):
			if sim.casilla_helada(Vector2i(x, y)):
				heladas.append(Vector2i(x, y))
	_ok("C la charca se hiela", sim.casilla_helada(CHARCA_C) and Terreno3D.helada(CHARCA_C), "a los %.1f s · heladas %s" % [float(t_hielo["t"]), str(heladas)])
	colocar_jugador(Vector2i(CHARCA_C.x, FILA_FOTO))
	await avanzar_s(0.3)
	_foto("C_helada")
	await avanzar_s(Lanzador3D.DURACION_HIELO - (reloj.t - t0) - 1.0)
	_foto("C_a_punto_de_fundirse")
	await avanzar_s(3.0)
	_ok("C pasado su tiempo el hielo se funde y vuelve a ser agua", not sim.casilla_helada(CHARCA_C) and Terreno3D.es_agua(CHARCA_C),
		"t = %.1f s" % (reloj.t - t0))
	await avanzar_s(1.0)
	_foto("C_fundida")


# --- D · nexo entre dos pozos --------------------------------------------------------------------------------------------

func _sala_d() -> void:
	var nexo: Node = _z.nodo("nexo_d")
	var totem: Node = _z.nodo("totem_d")
	_ok("D hay fuente, nexo y tótem", _z.nodo("fuente_d") != null and nexo != null and totem != null)
	if nexo == null or totem == null:
		return
	var r: Dictionary = {"activado": false}
	if totem.has_signal("activado"):
		totem.connect("activado", func(_a: Variant = null, _b: Variant = null) -> void: r["activado"] = true)
	await _mirar(NEXO_D, 8.0, 0.5)
	await avanzar_s(EmisorRayo3D.PERIODO + 2.0)
	_ok("D con el nexo seco la corriente no llega al tótem", not bool(nexo.get("conduce")) and not bool(r["activado"]))
	_foto("D_nexo_seco")
	var desde := Vector2i(NEXO_D.x, FILA_PASO)
	colocar_jugador(desde)
	_ok("D sale agua + flecha hacia el nexo", lanzar_a_celda("agua", ["flecha", "flecha"], NEXO_D, desde))
	await avanzar_s(2.0)
	_ok("D el nexo mojado conduce", bool(nexo.get("conduce")) and Terreno3D.conduce(NEXO_D))
	colocar_jugador(Vector2i(NEXO_D.x, FILA_FOTO))
	var foto: Dictionary = {"hecha": false}
	var em: Node = _z.nodo("fuente_d")
	await avanzar_vigilando(EmisorRayo3D.PERIODO + 4.0, 0.1, func(_t: float) -> void:
		if not bool(foto["hecha"]) and em != null and not (em.get("electrificada") as Array).is_empty():
			foto["hecha"] = true
			_foto("D_descarga_por_el_nexo")
	)
	_ok("D la descarga cruza el nexo y activa el tótem", bool(r["activado"]))


# --- Utilidades ----------------------------------------------------------------------------------------------------------

## Pone a la jugadora en el pasillo bajo la casilla y abre la cámara a `tam`, y deja pasar `espera` s (la luz de zona tarda 1,5 s).
func _mirar(c: Vector2i, tam: float, espera: float) -> void:
	colocar_jugador(Vector2i(c.x, FILA_FOTO))
	maqueta.set("_tam_camara", tam)
	if _cam != null:
		_cam.size = tam
	maqueta.set("_foco", Terreno3D.centro_de(c, 0.5))
	await avanzar_s(espera)


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D):
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
