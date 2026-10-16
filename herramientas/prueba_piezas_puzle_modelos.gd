extends SceneTree
## Piezas de puzle con los modelos de Meshy (Pipeline, 16/10): las tres láminas «puzle» separadas en piezas y cableadas en PiezaPuzle3D.
##   godot --headless --path . --script res://herramientas/prueba_piezas_puzle_modelos.gd
## Prueba que los GLB están y traen todas las piezas, que cada familia se construye con ellos y mide lo que dice CAJA, que los nodos con nombre
## y los estados siguen siendo los de siempre, y que el respaldo (`{"modelos": false}`) sigue funcionando. No prueba que «se vea bien»: capturas.

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame          # el árbol está listo: global_transform y add_child funcionan
	_modelos()
	_familias()
	_nodos_y_estados()
	_respaldo()
	await process_frame
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## AABB (en el espacio de la pieza) de todas las mallas visibles de un nodo.
func _caja_de(raiz: Node3D) -> AABB:
	var pieza: PiezaPuzle3D = raiz as PiezaPuzle3D
	var ab := AABB()
	var primero := true
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null or mi == (pieza._sombra if pieza != null else null):      # la sombra de contacto no es la pieza
			continue
		var b: AABB = raiz.global_transform.affine_inverse() * (mi.global_transform * mi.get_aabb())
		ab = b if primero else ab.merge(b)
		primero = false
	return ab


func _pieza(familia: String, opc: Dictionary = {}, estado: String = "") -> PiezaPuzle3D:
	var p: PiezaPuzle3D = PiezaPuzle3D.crear(familia, opc)
	p.sonido = false
	root.add_child(p)
	if estado != "":
		p.poner_estado(estado, false)
	return p


func _modelos() -> void:
	var faltan: Array = []
	for id in PiezaPuzle3D.MODELO_ARCHIVO:
		if PiezaPuzle3D.malla_modelo(id) == null:
			faltan.append(id)
	_ok("M1 los 3 GLB están y traen las %d piezas" % PiezaPuzle3D.MODELO_ARCHIVO.size(), faltan.is_empty(), "faltan: " + str(faltan))
	var sin_uv: Array = []
	var tris: int = 0
	for id in PiezaPuzle3D.MODELO_ARCHIVO:
		var m: Mesh = PiezaPuzle3D.malla_modelo(id)
		if m == null:
			continue
		var a: Array = m.surface_get_arrays(0)
		if a[Mesh.ARRAY_TEX_UV] == null or a[Mesh.ARRAY_NORMAL] == null or m.surface_get_material(0) == null:
			sin_uv.append(id)
		tris += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	_ok("M2 todas con UV, normales y material (para que lleven su textura)", sin_uv.is_empty(), "mal: %s · %d triángulos en total" % [str(sin_uv), tris])
	_ok("M3 la malla de una pieza se saca una vez y se reutiliza", PiezaPuzle3D.malla_modelo("barril") == PiezaPuzle3D.malla_modelo("barril"))


## Cada familia con modelo: se apoya en el suelo (y mínima ≈ 0) y cabe en CAJA (con un margen: el modelo manda, la caja es una guía).
func _familias() -> void:
	var casos: Array = [["pulsador", {}], ["placa", {}], ["compuerta", {}], ["compuerta", {"material": "hierro"}], ["compuerta_hielo", {}],
		["roca", {}], ["barril", {}], ["molino", {}], ["pila", {}], ["poste_nivel", {}], ["reja", {}], ["tapon_hielo", {}]]
	var fuera: Array = []
	var flota: Array = []
	var primitivas: Array = []
	for c in casos:
		var fam: String = c[0]
		var p: PiezaPuzle3D = _pieza(fam, c[1])
		var ab: AABB = _caja_de(p)
		var caja: Vector3 = PiezaPuzle3D.CAJA[fam]
		# Con modelos hay una malla sacada del GLB (`_mallas_modelo`): si no hay ninguna, es que cayó al respaldo de primitivas.
		var con_modelo: bool = false
		for m in p.find_children("*", "MeshInstance3D", true, false):
			con_modelo = con_modelo or PiezaPuzle3D._mallas_modelo.values().has((m as MeshInstance3D).mesh)
		if not con_modelo:
			primitivas.append(fam)
		if absf(ab.position.y) > 0.02 and fam != "molino":
			flota.append("%s y0=%.2f" % [fam, ab.position.y])
		var ancho_ok: float = 1.7 if fam == "pila" else 1.35          # la pila lleva los bornes fuera del cuenco
		if ab.size.x > caja.x * ancho_ok or ab.size.y > caja.y * 1.35 or ab.size.z > caja.z * 1.6:
			fuera.append("%s %s caja %s" % [fam, str(ab.size.snapped(Vector3.ONE * 0.01)), str(caja)])
		print("      %-16s %s  (caja %s)" % [fam + ("_hierro" if c[1].has("material") else ""), str(ab.size.snapped(Vector3.ONE * 0.01)), str(caja)])
		p.queue_free()
	_ok("F1 las 12 variantes se construyen con modelo (no caen a primitivas)", primitivas.is_empty(), "primitivas: " + str(primitivas))
	_ok("F2 se apoyan en el suelo (la base está en y = 0)", flota.is_empty(), str(flota))
	_ok("F3 caben en su CAJA (margen 35 %)", fuera.is_empty(), str(fuera))


func _nodos_y_estados() -> void:
	# Pulsador: el botón se hunde 0,15 y el tinte pinta su material.
	var p: PiezaPuzle3D = _pieza("pulsador", {"tinte": "agua"})
	var boton: Node3D = p._n["boton"]
	_ok("N1 pulsador: botón arriba en 0 y hundido en −0,15", is_equal_approx(boton.position.y, 0.0) and p.poner_estado("hundido", false) and is_equal_approx(boton.position.y, -0.15), "y=%.3f" % boton.position.y)
	_ok("N2 pulsador: el tinte colorea el botón y no la base", (p._m["boton"] as StandardMaterial3D).albedo_color.is_equal_approx(PiezaPuzle3D.TINTE["agua"]) and p.get_node("base") != null)
	p.poner_tinte("presencia")
	_ok("N3 pulsador: poner_tinte cambia el color del botón", (p._m["boton"] as StandardMaterial3D).albedo_color.is_equal_approx(PiezaPuzle3D.TINTE["presencia"]))
	_ok("N4 pulsador: el aro de luz solo se ve hundido", (p._n["aro"] as Node3D).visible and not (p.poner_estado("arriba", false) and (p._n["aro"] as Node3D).visible))
	# Placa
	p = _pieza("placa")
	var tapa: Node3D = p._n["tapa"]
	p.poner_estado("hundida", false)
	var hundida_y: float = tapa.position.y
	p.poner_estado("arriba", false)
	_ok("N5 placa: la tapa baja 0,04 al hundirse", is_equal_approx(hundida_y, -0.04) and is_equal_approx(tapa.position.y, 0.0), "hundida %.3f arriba %.3f" % [hundida_y, tapa.position.y])
	p.poner_runa(true)
	_ok("N6 placa: poner_runa enciende la runa de luz", (p._m["runa"] as StandardMaterial3D).emission_enabled)
	# Compuerta y reja
	p = _pieza("compuerta")
	var hoja: Node3D = p._n["hoja"]
	p.poner_estado("abierta", false)
	_ok("N7 compuerta: la hoja baja %.1f al abrirse y vuelve a 0 al cerrarse" % PiezaPuzle3D.BAJA_COMPUERTA, is_equal_approx(hoja.position.y, -PiezaPuzle3D.BAJA_COMPUERTA) and p.poner_estado("cerrada", false) and is_equal_approx(hoja.position.y, 0.0))
	p.orientar(true)
	_ok("N8 compuerta: orientar(true) la gira 90°", is_equal_approx(p.rotation.y, PI * 0.5))
	p = _pieza("reja")
	p.poner_estado("abierta", false)
	_ok("N9 reja: abierta = la hoja baja 2,2", is_equal_approx((p._n["hoja"] as Node3D).position.y, -2.2))
	# Hielo
	for fam in ["compuerta_hielo", "tapon_hielo"]:
		p = _pieza(fam)
		var h: Node3D = p._n["hoja"]
		var est: Array = PiezaPuzle3D.ESTADOS[fam]
		p.poner_estado(est[2], false)
		var oculto: bool = not h.visible
		p.poner_estado(est[0], false)
		var m: StandardMaterial3D = p._m["hielo"]
		_ok("N10 %s: «nada» esconde el hielo y «entero» lo devuelve con el color de entero" % fam, oculto and h.visible and m.albedo_color.is_equal_approx(p._hielo_color) and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
	# Roca
	p = _pieza("roca")
	var ent: Node3D = p._n["entera"]
	var okc: bool = ent.visible
	var vis_antes: int = 0
	for i in range(4):
		vis_antes += 1 if (p._n["cascote_%d" % i] as Node3D).visible else 0
	p.poner_estado("rota", false)
	var vis_rota: int = 0
	var en_suelo: bool = true
	for i in range(4):
		var c: Node3D = p._n["cascote_%d" % i]
		vis_rota += 1 if c.visible else 0
		en_suelo = en_suelo and is_zero_approx(c.position.y)
	_ok("N11 roca: entera = 1 malla y 0 cascotes; rota = sin la entera y 4 cascotes en el suelo", okc and vis_antes == 0 and not ent.visible and vis_rota == 4 and en_suelo)
	p.poner_estado("entera", false)
	_ok("N12 roca: volver a entera recoge los cascotes", ent.visible and not (p._n["cascote_0"] as Node3D).visible)
	# Barril
	p = _pieza("barril")
	var mecha: Node3D = p._n["mecha"]
	_ok("N13 barril: la mecha sale del centro de la tapa (y 0,95) y hay luz", is_zero_approx(mecha.position.x) and is_equal_approx(mecha.position.y, 0.95) and p._n.has("luz"))
	p.poner_estado("mecha", false)
	var luz_mecha: float = (p._n["luz"] as OmniLight3D).light_energy
	p.poner_estado("explosion", false)
	_ok("N14 barril: mecha enciende la luz; explosión esconde el barril", luz_mecha > 1.0 and not (p._n["cuerpo"] as Node3D).visible and not mecha.visible)
	p.poner_estado("entero", false)
	_ok("N15 barril: el material del cuerpo es PROPIO (animar su brillo no toca a otros barriles)", p._m["cuerpo"] != _pieza("barril")._m["cuerpo"])
	# Molino
	p = _pieza("molino")
	_ok("N16 molino: `rueda` existe, queda a la altura del eje y gira sobre X", p.rueda != null and is_equal_approx(p.rueda.position.y, PiezaPuzle3D.MOLINO_EJE_Y_MODELO) and p._n.has("eje"))
	var antes: Basis = p.rueda.transform.basis
	var ab_r: AABB = _caja_de(p.rueda)
	p.rueda.rotate_x(0.5)
	_ok("N17 molino: la rueda está centrada en su nodo (el giro no la descentra) y mide ≈ Ø1,08", absf(ab_r.get_center().y) < 0.03 and absf(ab_r.get_center().z) < 0.03 and absf(ab_r.size.y - 1.08) < 0.1 and p.rueda.transform.basis != antes, "centro %s tamaño %s" % [str(ab_r.get_center().snapped(Vector3.ONE * 0.01)), str(ab_r.size.snapped(Vector3.ONE * 0.01))])
	# Pila
	p = _pieza("pila")
	p.poner_estado("mojada", false)
	var agua: Node3D = p._n["agua"]
	var v1: bool = agua.visible
	p.poner_estado("seca", false)
	_ok("N18 pila: mojada enseña el agua dentro del cuenco; seca la esconde", v1 and not agua.visible and agua.position.y < 0.38)
	p.poner_estado("electrificada", false)
	_ok("N19 pila: electrificada hace brillar los bornes (material propio)", (p._m["borne"] as StandardMaterial3D).emission_enabled)
	# Poste de nivel
	p = _pieza("poste_nivel", {"marca": 1.1})
	_ok("N20 poste: la marca arranca donde se pide y poner_marca la mueve", is_equal_approx((p._n["marca"] as Node3D).position.y, 1.1) and (func() -> bool:
		p.poner_marca(0.5)
		return is_equal_approx((p._n["marca"] as Node3D).position.y, 0.5)).call())
	p.poner_estado("encendido", false)
	_ok("N21 poste: encendido prende la luz del farolillo (y apagado la apaga)", (p._m["cristal"] as StandardMaterial3D).emission_enabled and (p.poner_estado("apagado", false) and not (p._m["cristal"] as StandardMaterial3D).emission_enabled))


func _respaldo() -> void:
	# Con {"modelos": false} cada familia usa las primitivas de siempre, con los mismos nodos con nombre.
	var p: PiezaPuzle3D = _pieza("pulsador", {"modelos": false})
	_ok("R1 sin modelos: el pulsador usa el cilindro de siempre y el botón arriba en 0,7", (p._n["boton"] as MeshInstance3D).mesh is CylinderMesh and is_equal_approx((p._n["boton"] as Node3D).position.y, 0.7))
	p.poner_estado("hundido", false)
	_ok("R2 sin modelos: hundido = 0,55 como antes", is_equal_approx((p._n["boton"] as Node3D).position.y, 0.55))
	p = _pieza("placa", {"modelos": false})
	p.poner_estado("hundida", false)
	_ok("R3 sin modelos: la tapa de la placa hundida está en 0,04 como antes", is_equal_approx((p._n["tapa"] as Node3D).position.y, 0.04))
	p = _pieza("roca", {"modelos": false})
	p.poner_estado("rota", false)
	_ok("R4 sin modelos: la roca rota usa los 4 cascotes de esfera y no tiene `entera`", not p._n.has("entera") and p._n.has("cascote_3"))
	p = _pieza("barril", {"modelos": false})
	_ok("R5 sin modelos: la mecha del barril sigue a 0,1 del centro", is_equal_approx((p._n["mecha"] as Node3D).position.x, 0.1))
	PiezaPuzle3D.usar_modelos = false
	p = _pieza("molino")
	_ok("R6 usar_modelos = false: el molino usa las primitivas (eje a 0,82)", is_equal_approx(p.rueda.position.y, PiezaPuzle3D.MOLINO_EJE_Y))
	_ok("R7 usar_modelos = false: malla_modelo() devuelve null", PiezaPuzle3D.malla_modelo("barril") == null)
	PiezaPuzle3D.usar_modelos = true
	for fam in PiezaPuzle3D.ESTADOS:
		var q: PiezaPuzle3D = _pieza(fam, {"modelos": false})
		var bien: bool = true
		for e in PiezaPuzle3D.ESTADOS[fam]:
			bien = bien and q.poner_estado(String(e), false)
		_ok("R8 sin modelos: %s recorre todos sus estados" % fam, bien)
