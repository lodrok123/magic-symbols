extends SceneTree
## PRUEBA DE LOS ATUENDOS Y EL VESTUARIO (12/11, encargo de Pablo): `nucleo/atuendos.gd`, la pestaña Vestuario de `MenuPestanas`, la librera que vende el
## uniforme de Sumicio y el atuendo del lobo (`tiendas.tsv`) y la imagen de producto en `TiendaUI`. Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_vestuario.gd
## (1) la tabla: tres atuendos en orden, con sus prendas en ropa.json y su ranura; el de viaje es inicial, los otros se tienen al estar en la mochila.
## (2) la jugadora base carga con el atuendo de viaje puesto (ROPA_POR_DEFECTO) y `Atuendos.poner` cambia de uno a otro quitando lo anterior.
## (3) la librera vende los dos nuevos (una unidad), comprar uno lo deja en la mochila y entonces se tiene.
## (4) el menú: la pestaña Vestuario existe tras Inventario, ←→ eligen, Enter se pone el elegido (si se tiene) y lo dice la carta.
## (5) la partida guarda y devuelve lo puesto (ropa_puesta) con cualquier atuendo.

var _fallos: int = 0


func _initialize() -> void:
	await _probar()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	if not bien:
		_fallos += 1
	print(("OK    " if bien else "FALLO ") + nombre + ("  " + info if info != "" else ""))


func _probar() -> void:
	Estado.nuevo()
	Flags.nuevo()
	# 1 · la tabla
	var ids: Array = Atuendos.ids()
	_ok("1 tres atuendos en el orden de la tabla", ids == ["atuendo_verde", "atuendo_sumicio", "atuendo_lobo"], str(ids))
	var malas: Array = []
	var ranuras: Dictionary = {}
	for id in ids:
		var rs: Array = []
		for p in Atuendos.prendas(String(id)):
			if not Ropa3D.existe(String(p)):
				malas.append("%s: %s no está en ropa.json" % [id, p])
			if not ResourceLoader.exists(Ropa3D.CARPETA_MODELOS + String(Ropa3D.datos_de(String(p)).get("glb", p)) + ".glb"):
				malas.append("%s: falta el .glb de %s" % [id, p])
			var r: String = Ropa3D.ranura_de(String(p))
			if r == "" or rs.has(r):
				malas.append("%s: %s sin ranura o repetida (%s)" % [id, p, r])
			rs.append(r)
		ranuras[id] = rs
	_ok("1 cada atuendo tiene sus prendas conocidas, con .glb y ranuras distintas (el del loberno son 2: la túnica es una pieza)", malas.is_empty()
		and ranuras["atuendo_verde"].size() == 3 and ranuras["atuendo_lobo"].size() == 2, str(malas))
	_ok("1 el de viaje es inicial (se tiene sin objeto); los otros no", Atuendos.inicial("atuendo_verde") and not Atuendos.inicial("atuendo_sumicio")
		and Atuendos.tiene("atuendo_verde") and not Atuendos.tiene("atuendo_sumicio") and not Atuendos.tiene("atuendo_lobo"))
	_ok("1 un objeto que no es atuendo no lo es", not Atuendos.es_atuendo("capa") and not Atuendos.tiene("capa") and Atuendos.prendas("capa").is_empty())
	_ok("1 cada atuendo tiene descripción propia e icono", TextosObjetos.descripcion("atuendo_lobo") != "" and TextosObjetos.descripcion("atuendo_sumicio") != ""
		and Objetos.tiene_icono("atuendo_verde") and Objetos.tiene_icono("atuendo_sumicio") and Objetos.tiene_icono("atuendo_lobo"))
	# 2 · la jugadora
	var pj := Pj3D.new()
	root.add_child(pj)
	var cargo: bool = pj.cargar("jugadora_base")
	_ok("2 la jugadora base carga con el atuendo de viaje puesto", cargo and Atuendos.puesto(pj) == "atuendo_verde", str(pj.ropa_puesta()))
	_ok("2 no se pone un atuendo que no se tiene", not Atuendos.poner(pj, "atuendo_sumicio") and Atuendos.puesto(pj) == "atuendo_verde")
	Estado.i().agregar("atuendo_sumicio")
	_ok("2 con el objeto en la mochila, se tiene", Atuendos.tiene("atuendo_sumicio"))
	var puso: bool = Atuendos.poner(pj, "atuendo_sumicio")
	var puestas: Array = pj.ropa_puesta()
	_ok("2 ponerse el uniforme quita lo verde y pone capa, capucha y bombachos", puso and Atuendos.puesto(pj) == "atuendo_sumicio" and puestas.size() == 3
		and puestas.has("capa") and puestas.has("piernas") and not puestas.has("tunica") and not puestas.has("capa_verde"), str(puestas))
	Estado.i().agregar("atuendo_lobo")
	puso = Atuendos.poner(pj, "atuendo_lobo")
	puestas = pj.ropa_puesta()
	_ok("2 ponerse el del loberno: túnica y mallas, nada del uniforme", puso and Atuendos.puesto(pj) == "atuendo_lobo" and puestas.size() == 2
		and puestas.has("tunica_lobo") and puestas.has("piernas_lobo") and not puestas.has("capa"), str(puestas))
	_ok("2 las zonas tapadas con el lobo: chaleco, cinturón, piernas y botas (el pelo, no)", Ropa3D.zonas_apagadas(pj.get("_modelo") as Node3D).has("piernas") and Ropa3D.zonas_apagadas(pj.get("_modelo") as Node3D).has("chaleco")
		and not Ropa3D.zonas_apagadas(pj.get("_modelo") as Node3D).has("pelo"), str(Ropa3D.zonas_apagadas(pj.get("_modelo") as Node3D)))
	puso = Atuendos.poner(pj, "atuendo_verde")
	_ok("2 y de vuelta al de viaje", puso and Atuendos.puesto(pj) == "atuendo_verde" and pj.ropa_puesta().size() == 3)
	# 3 · la librera
	Estado.nuevo()
	Flags.nuevo()
	var oferta: Array = []
	for o in Tiendas.oferta("librera"):
		oferta.append(String(o["objeto"]))
	_ok("3 la librera vende el uniforme y el atuendo del lobo, una unidad cada uno", oferta.has("atuendo_sumicio") and oferta.has("atuendo_lobo")
		and Tiendas.quedan("librera", "atuendo_sumicio") == 1 and Tiendas.quedan("librera", "atuendo_lobo") == 1, str(oferta))
	Estado.i().oro = 200
	var compro: bool = Tiendas.comprar("librera", "atuendo_sumicio")
	_ok("3 comprar el uniforme: va a la mochila, se tiene, cuesta 120 y se agota", compro and Atuendos.tiene("atuendo_sumicio") and Estado.i().oro == 80
		and Tiendas.quedan("librera", "atuendo_sumicio") == 0 and not Atuendos.tiene("atuendo_lobo"))
	_ok("3 sin oro para el del lobo: no se compra", not Tiendas.comprar("librera", "atuendo_lobo") and not Atuendos.tiene("atuendo_lobo"))
	# 4 · el menú
	var m := MenuPestanas.new()
	root.add_child(m)
	await process_frame
	_ok("4 la pestaña Vestuario va tras Inventario y es funcional", String(MenuPestanas.PESTANAS[MenuPestanas.INDICE_VESTUARIO]["id"]) == "vestuario"
		and m.funcional(MenuPestanas.INDICE_VESTUARIO) and String(MenuPestanas.PESTANAS[MenuPestanas.INDICE_MISIONES]["id"]) == "misiones"
		and String(MenuPestanas.PESTANAS[MenuPestanas.INDICE_ESTADISTICAS]["id"]) == "estadisticas")
	m.abrir(MenuPestanas.INDICE_VESTUARIO)
	await process_frame
	_ok("4 abre en Vestuario con el de viaje elegido y su página visible", m.abierta and m.pestana == MenuPestanas.INDICE_VESTUARIO and m.atuendo_elegido() == "atuendo_verde"
		and m._pag_vest.visible and not m._pag_inv.visible)
	m.mover(Vector2.RIGHT)
	_ok("4 → elige el uniforme; ← vuelve; no pasa del último", m.atuendo_elegido() == "atuendo_sumicio")
	m.mover(Vector2.RIGHT)
	m.mover(Vector2.RIGHT)
	_ok("4 → → se queda en el último (lobo)", m.atuendo_elegido() == "atuendo_lobo")
	m.mover(Vector2.LEFT)
	_ok("4 ← vuelve al uniforme", m.atuendo_elegido() == "atuendo_sumicio")
	# sin jugadora en el árbol (ni lanzador) no se puede poner: «no puedes», sin petar
	_ok("4 sin jugadora en el árbol, Enter no peta y no pone nada", not m.ponerse_atuendo("atuendo_sumicio"))
	_ok("4 la pista de la pestaña dice qué hace Enter", m.pista().contains("ponerse"))
	m.cerrar()
	m.queue_free()
	# 5 · la partida guarda lo puesto con cualquier atuendo
	Atuendos.poner(pj, "atuendo_sumicio")
	var d: Dictionary = {"ropa_puesta": pj.ropa_puesta()}
	_ok("5 lo puesto que guarda la partida es el uniforme entero", (d["ropa_puesta"] as Array).size() == 3 and (d["ropa_puesta"] as Array).has("capucha"))
	# 12/11 (Pablo: «se ven mallas estiradas, agujeros»): poner una prenda quita la que ocupaba su ranura (al cargar una partida con el loberno, la túnica del
	# lobo se ponía encima de la de viaje) y el cargado de la partida quita antes todo lo de serie.
	var pj2 := Pj3D.new()
	root.add_child(pj2)
	pj2.cargar("jugadora_base")
	pj2.poner_ropa("tunica_lobo")
	pj2.poner_ropa("piernas_lobo")
	var p2: Array = pj2.ropa_puesta()
	_ok("5 poner la túnica del lobo sobre la de viaje la sustituye (una prenda por ranura)", not p2.has("tunica") and p2.has("tunica_lobo") and p2.has("capa_verde"), str(p2))
	pj2.queue_free()
	pj.queue_free()
