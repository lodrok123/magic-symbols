extends "res://herramientas/escenario_base.gd"
## BLOQUE 2 de la revisión EoW (23/10): resaltado de lo que reacciona, muro agrietado y pulso de pantalla. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_bloque2_eow.gd -- [carpeta] [escena]
##   (por defecto res://docs/capturas/bloque2_eow y el Bosque)
##   1 · resaltado: se simula el modo lanzar con una página de FUEGO preparada; cuenta qué se resalta y lo fotografía.
##   2 · muro: uno junto al jugador, entero, tras un golpe de tierra y a media rotura (con un golpe más).
##   3 · pulso: el desenfoque radial en su punto más fuerte.

var _dir: String = "res://docs/capturas/bloque2_eow"


func _escenario() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		_dir = a[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var gi: FileAccess = FileAccess.open(_dir.path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	await cargar(a[1] if a.size() > 1 else RUTA_BOSQUE)
	if maqueta == null or jugador == null:
		return
	_ocultar_ui(root)
	await avanzar(20)
	var realce: Realce3D = maqueta.get_node_or_null("Realce3D") as Realce3D
	_ok("1 la escena monta el resaltado", realce != null)

	# 1 · Resaltado (modo lanzar simulado con una página de fuego, apuntando a lo más cercano que reacciona)
	if realce != null:
		var fuego: RuneData = load("res://nucleo/fire_rune.tres") as RuneData
		# Junto a los braseros de práctica del Bosque (si el mapa es otro, se queda donde está).
		if String(maqueta.get("nivel")) == "Bosque":
			colocar_jugador(Vector2i(2, 44))
			await avanzar(30)
		# Una página de verdad (fuego + flecha) y al modo lanzar por el camino normal (lo mismo que cerrar el libro).
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element("fuego")
		lanzador.place_sigil("flecha")
		lanzador.cooldown_left[0] = 0.0
		_foto("realce_antes")
		lanzador.cast_page(0)
		await avanzar(8)
		var mas_cerca: Area3D = null
		var dmin: float = INF
		for o in realce._puestos.keys():
			var d: float = (o as Area3D).global_position.distance_to(jugador.position)
			if d < dmin:
				dmin = d
				mas_cerca = o
		if mas_cerca != null:
			lanzador._punto_vivo = mas_cerca.global_position
		await avanzar(5)
		var areas: Array = maqueta.find_children("*", "Area3D", true, false)
		var con_capa: int = 0
		var con_metodo: int = 0
		for ar in areas:
			if ((ar as Area3D).collision_layer & Lanzador3D.CAPA_REACTIVO) != 0:
				con_capa += 1
			if ar.has_method("on_spell_hit"):
				con_metodo += 1
		realce._buscar()
		_aviso("1 estado del lanzador", "modo_lanzar %s · libro %s · realce procesa %s" % [lanzador.modo_lanzar, lanzador.libro_abierto(), realce.is_processing()])
		_aviso("1 áreas en la escena", "%d · con capa de reactivos %d · con on_spell_hit %d · tras _buscar %d" % [areas.size(), con_capa, con_metodo, realce._candidatos.size()])
		var info: Array = []
		for o in realce._candidatos:
			if not is_instance_valid(o):
				continue
			var dc: float = o.global_position.distance_to(jugador.position) / Terreno3D.casilla
			if dc <= 8.0:
				info.append("%s capa=%d d=%.1f reac=%s" % [o.name, o.collision_layer, dc, str(o.call("spell_reacts", fuego, Vector3.ZERO)) if o.has_method("spell_reacts") else "-"])
		_aviso("1 candidatos", "%d en total; cerca: %s" % [realce._candidatos.size(), " | ".join(info)])
		var n: int = realce._puestos.size()
		var nombres: Array = []
		for o in realce._puestos.keys():
			nombres.append("%s(%s)" % [(o as Node).name, str(o.get("tipo")) if "tipo" in o else (o as Object).get_class()])
		_ok("1 con fuego preparado se resalta algo cerca", n > 0, "%d: %s" % [n, ", ".join(nombres.slice(0, 8))])
		for o in realce._puestos.keys():
			var geos: Array = (o as Node).find_children("*", "GeometryInstance3D", true, false)
			var con: int = 0
			for g in geos:
				if (g as GeometryInstance3D).material_overlay == realce._puestos[o]:
					con += 1
			_aviso("1 mallas de %s" % (o as Node).name, "%d mallas · %d con el borde · script %s · padre %s (%s) · malla visible %s" % [geos.size(), con, (o as Node).get_script().resource_path if (o as Node).get_script() else "-", (o as Node).get_parent().name, (o as Node).get_parent().get_class(), str((geos[0] as GeometryInstance3D).is_visible_in_tree()) if geos.size() > 0 else "-"])
		_foto("realce_fuego")
		lanzador._salir_modo(false)
		await avanzar(3)
		_ok("1 al salir del modo lanzar se quita", realce._puestos.is_empty())

	# 2 · Muro agrietado a dos casillas del jugador
	var c0: Vector2i = celda_jugador()
	var cm: Vector2i = c0 + Vector2i(1, -1)
	var mu := MuroAgrietado3D.new()
	mu.preparar(cm, 2)
	(maqueta.get("_props") as Node).add_child(mu)
	await avanzar(10)
	_foto("muro_entero")
	var tierra: RuneData = load("res://nucleo/earth_rune.tres") as RuneData
	mu.on_spell_hit(tierra)
	await avanzar_s(0.4)
	_foto("muro_agrietado")
	mu.on_spell_hit(tierra)
	await avanzar_s(0.3)
	_foto("muro_rompiendose")
	await avanzar_s(1.0)
	_ok("2 el muro se rompe con dos golpes de tierra y libera la casilla", mu.roto_ya and not Terreno3D.bloqueada(cm))

	# 3 · Pulso de pantalla
	PulsoPantalla3D.lanzar_en(self, jugador.position, 1.0, 0.6)
	await avanzar(2)
	_foto("pulso")
	await avanzar_s(1.0)
	_ok("3 el pulso se borra solo", root.get_node_or_null("PulsoPantalla") == null)


func _foto(nombre: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(_dir.path_join(nombre + ".png"))
	print("foto " + nombre)


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer:
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
