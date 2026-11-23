extends "res://herramientas/escenario_base.gd"
## Camino real: preparar, cancelar y disparar. Con argumento, guarda capturas renderizadas.
var _capturas: String = ""

func preparar(glifos: Array, elemento: String = "fuego", colocado: bool = false) -> void:
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	(jugador as Jugador3D).tinta.actual = 100.0
	_ok("prepara %s" % str(glifos), lanzador._preparar_pagina(0))
	lanzador._entrar_modo_lanzar()
	lanzador._fijado = true
	lanzador._origen_fijo = jugador.position + (Vector3.RIGHT * Terreno3D.casilla if colocado else Vector3.ZERO)
	lanzador._origen_vivo = lanzador._origen_fijo
	lanzador._punto_vivo = lanzador._origen_fijo + Vector3.RIGHT * Terreno3D.casilla
	await avanzar(4)

## `con_rotulos` (22/11, HECHIZOS): deja a la vista los rótulos de la previsión (el «para… · no para…» de B9b); si no, se esconden para ver solo la silueta.
func foto(nombre: String, con_rotulos: bool = false) -> void:
	if _capturas == "":
		return
	_ocultar_ui(root)
	if is_instance_valid(lanzador._vista_reaccion):
		lanzador._vista_reaccion.visible = con_rotulos
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(_capturas.path_join(nombre + ".png"))
	print("CAPTURA ", nombre)

func _ocultar_ui(n: Node) -> void:
	if n is CanvasLayer:
		(n as CanvasLayer).visible = false
	elif n is CanvasItem:
		(n as CanvasItem).hide()
	for hijo in n.get_children():
		_ocultar_ui(hijo)

func _escenario() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_capturas = args[0]
		DirAccess.make_dir_recursive_absolute(_capturas)
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if lanzador == null or jugador == null:
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = 8
	for enemigo in get_nodes_in_group("combate3d"):
		enemigo.set("quieto", true)
		enemigo.position = Vector3(-500, 0, -500)
	colocar_jugador(Vector2i(6, 24))
	await avanzar(8)
	var solidez_antes: int = lanzador._solideces_v2.size()
	var zonas_antes: int = lanzador._zonas_v2.size()
	await preparar(["barrera"])
	var v: Node = lanzador._prevision_casteo
	if v == null:
		_ok("el lanzador creó la previsión", false)
		return
	_ok("barrera anuncia protección al apuntar", v != null and v.visible and v.get("tipo") == "proteccion")
	_ok("apuntar no consume tinta", is_equal_approx((jugador as Jugador3D).tinta.actual, 100.0))
	_ok("la burbuja prevista NO crea defensa ni zonas", solidez_antes == lanzador._solideces_v2.size() and zonas_antes == lanzador._zonas_v2.size())
	await foto("01_barrera_personal", true)
	lanzador._cancelar_modo()
	_ok("cancelar retira la silueta", not v.visible)
	await avanzar(2)
	for caso in [
		["02_flecha", ["flecha"], "fuego", "proyectil", false],
		["03_barrera_movil", ["barrera", "flecha"], "agua", "volumen_movil", false],
		["04_haz", ["linea_x"], "rayo", "haz", false],
		["05_suelo", ["suelo"], "hielo", "suelo", true],
		["06_orbita", ["retorno", "repeticion"], "fuego", "orbita", false],
		["07_muro", ["barrera", "linea_x", "linea_x", "linea_x"], "fuego", "proteccion", false],
	]:
		await preparar(caso[1], caso[2], caso[4])
		_ok("función de %s" % caso[0], v.visible and v.get("tipo") == caso[3], str(v.get("tipo")))
		await foto(caso[0])
		lanzador._cancelar_modo()
		await avanzar(2)
	# 22/11 (HECHIZOS): la protección de cada elemento de la demo, con el rótulo de lo que para. La de tierra en tu casilla es el ANILLO fino de COMBATE (A4); apuntada a otra casilla, un bloque.
	for caso in [
		["09_proteccion_agua", ["barrera"], "agua", "proteccion", false],
		["10_tierra_en_tu_casilla", ["barrera"], "tierra", "colocado", false],
		["11_tierra_colocada", ["barrera"], "tierra", "colocado", true],
	]:
		await preparar(caso[1], caso[2], caso[4])
		_ok("función de %s" % caso[0], v.visible and v.get("tipo") == caso[3], str(v.get("tipo")))
		await foto(caso[0], true)
		lanzador._cancelar_modo()
		await avanzar(2)
	await preparar(["flecha"])
	var datos: Dictionary = lanzador._preparado
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	_ok("el casteo real empieza", lanzador.lanzar_ahora(datos, jugador.position, Vector3.RIGHT, true))
	await avanzar(1)
	_ok("el contorno sigue durante la preparación del clip", v.visible and lanzador.conjurando)
	await foto("08_casteo_flecha")
	var t: float = 0.0
	while lanzador.conjurando and t < 5.0:
		t += await avanzar_s(0.05)
	_ok("al disparar desaparece el contorno", not v.visible and not lanzador.conjurando)
	_ok("el disparo conserva su cobro real", (jugador as Jugador3D).tinta.actual < 100.0)
	await preparar(["barrera"])
	Lanzador3D.PREVISION_CASTEO_ACTIVA = false
	await avanzar(2)
	_ok("se puede desactivar para comparar", not v.visible)
	Lanzador3D.PREVISION_CASTEO_ACTIVA = true
	lanzador._cancelar_modo()
	await avanzar(2)
	maqueta.queue_free()
	await avanzar(3)
