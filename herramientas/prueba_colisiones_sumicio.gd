extends SceneTree
## PRUEBA DE COLISIONES DE MONTE SUMICIO (14/11/2026, Pablo: «cuando horneas el nivel las colisiones son por casilla; ponlas TODAS por malla,
## hay muchos muros invisibles»). Headless:
##   E:\magic-symbols\tools\Godot_v4.7.2-stable_win64.exe --headless --path E:\magic-symbols --script res://herramientas/prueba_colisiones_sumicio.gd
## Comprueba con la misma regla que la jugadora (Jugador3D._puede_entrar: casilla con forma → choca con la forma; sin forma → la casilla entera):
##   1. manda la solidez por colisión real (Terreno3D.FuenteNodos) y cada edificio y árbol lleva su cuerpo medido sobre la malla;
##   2. NO hay muros invisibles: recorriendo la aldea cada 0,3 u, ningún punto choca sin que haya una malla de choque en él (se descuentan las
##      casillas fuera del mapa y los muros de los interiores, que no están en la aldea);
##   3. la valla cierra todo el círculo (cada 4°, salvo el vano de la cancela);
##   4. la cancela cierra el paso y, al abrirla, deja de cerrarlo (sin cuerpo y sin casilla bloqueada);
##   5. delante de cada puerta (pallozas y torre) se puede estar a la distancia a la que se cruza.

var _fallos := 0


func _ok(cond: bool, texto: String) -> void:
	print(("OK    " if cond else "FALLO ") + texto)
	if not cond:
		_fallos += 1


## ¿Choca el cuerpo de la jugadora en `p`? (la regla de Jugador3D._puede_entrar sin las alturas)
func _choca(p: Vector3) -> bool:
	var c := Terreno3D.celda_de(p)
	if Terreno3D.es_parcial(c, true):
		return Terreno3D.choca_huella(c, p)
	return Terreno3D.bloqueada(c)


## ¿Hay una malla de choque (capa de lo sólido) donde estaría el cuerpo de la jugadora en `p`?
func _malla(p: Vector3) -> bool:
	var c := Terreno3D.celda_de(p)
	var q := PhysicsShapeQueryParameters3D.new()
	var bola := SphereShape3D.new()
	bola.radius = Terreno3D.FuenteSolidez.RADIO_CUERPO
	q.shape = bola
	q.collision_mask = Terreno3D.CAPA_SOLIDO
	q.transform = Transform3D(Basis(), Vector3(p.x, Terreno3D.FuenteNodos.suelo_de(c) + 0.6, p.z))
	return not root.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _initialize() -> void:
	var esc: Node = (load("res://escenas/PruebaMonteSumicio.tscn") as PackedScene).instantiate()
	root.add_child(esc)
	for i in 60:
		await physics_frame
	var maq: Node = esc.get_node("Maqueta")
	# 1
	_ok(Terreno3D.fuente is Terreno3D.FuenteNodos, "1.1 manda la solidez por colisión real (FuenteNodos)")
	var edificios: Array = maq.casas() + [maq.torre, maq.obrador]
	var con_cuerpo := 0
	for e in edificios:
		if (e as Node).get_node_or_null("Solido") != null:
			con_cuerpo += 1
	_ok(con_cuerpo == edificios.size(), "1.2 las 4 pallozas, la torre y el obrador llevan cuerpo medido sobre su malla (%d/%d)" % [con_cuerpo, edificios.size()])
	var arboles: Node = maq.get_node("Nivel_MonteSumicio/Piezas/Arboles")
	var arb_ok := 0
	for a in arboles.get_children():
		if a.get_node_or_null("Solido") != null:
			arb_ok += 1
	_ok(arb_ok == arboles.get_child_count(), "1.3 cada árbol choca con su tronco (%d/%d)" % [arb_ok, arboles.get_child_count()])
	# 2
	var an: Dictionary = maq._anillo
	var c3: Vector3 = an["centro"]
	var radio: float = an["radio"]
	var invisibles: Array = []
	var puntos := 0
	var x := c3.x - radio - 2.5
	while x <= c3.x + radio + 2.5:
		var z := c3.z - radio - 2.5
		while z <= c3.z + radio + 2.5:
			var p := Vector3(x, 0.0, z)
			var c := Terreno3D.celda_de(p)
			if Vector2(x - c3.x, z - c3.z).length() <= radio + 2.5 and Terreno3D.en_mapa(c) and not Terreno3D.es_vacio(c) and Terreno3D.letra_de(c) != "#":
				puntos += 1
				if _choca(p) and not _malla(p):
					invisibles.append(c)
			z += 0.3
		x += 0.3
	var celdas_inv := {}
	for c in invisibles:
		celdas_inv[c] = true
	_ok(invisibles.is_empty(), "2.1 sin muros invisibles en la aldea: %d de %d puntos chocan sin malla%s" % [invisibles.size(), puntos,
		(" (casillas %s)" % str(celdas_inv.keys().slice(0, 12))) if not invisibles.is_empty() else ""])
	# 3
	var ang0: float = an["puerta"]
	var medio_hueco: float = an["medio_hueco"]
	var abiertos: Array = []
	var a := 0.0
	while a < 360.0:
		var ang := deg_to_rad(a)
		if absf(angle_difference(ang, ang0)) > medio_hueco + 0.02:
			var p := Vector3(c3.x + sin(ang) * radio, 0.0, c3.z - cos(ang) * radio)
			if not _choca(p):
				abiertos.append(int(a))
		a += 4.0
	_ok(abiertos.is_empty(), "3.1 la valla cierra todo el círculo (abierta en %s)" % str(abiertos))
	# 4
	var cancela := maq.find_child("Cancela", true, false) as Node3D
	var vano := cancela.global_position
	_ok(maq.cancela_cierra() and _choca(vano), "4.1 la cancela cerrada no deja pasar")
	maq.abrir_porton(false)
	for i in 6:
		await physics_frame
	_ok(not maq.cancela_cierra() and not _choca(vano) and not _choca(vano + Vector3(0.5, 0, 0)) and not _choca(vano - Vector3(0.5, 0, 0)),
		"4.2 abierta, el vano queda libre (centro y ±0,5)")
	# 5
	var visita: Node = esc.get_node("Visita")
	for casa in maq.casas() + [maq.torre]:
		var hueco: Vector3 = (casa as Node3D).to_global(visita._hueco_puerta(casa))
		var fuera: Vector3 = (casa as Node3D).global_basis.z.normalized()
		var p: Vector3 = hueco + fuera * 0.5
		_ok(not _choca(p), "5.1 delante de la puerta de %s (a 0,5 de la hoja) se puede estar" % casa.name)
	# 6 · por dentro de las pallozas (14/11, 2.ª parte): sin muros invisibles, el muro redondo cierra y la puerta deja salir
	for sala in esc.get_node("Interiores").get_children():
		if sala.get("torre"):
			continue
		var o: Vector3 = (sala as Node3D).global_position
		var r: float = sala.RADIO_MURO * Terreno3D.casilla
		var inv := 0
		var total := 0
		var xx := -r
		while xx <= r:
			var zz := -r
			while zz <= r:
				if Vector2(xx, zz).length() < r - 0.45:
					var p := o + Vector3(xx, 0.0, zz)
					total += 1
					if _choca(p) and not _malla(p):
						inv += 1
				zz += 0.3
			xx += 0.3
		_ok(inv == 0, "6.1 %s por dentro: %d de %d puntos chocan sin malla" % [sala.name, inv, total])
		var abiertos2: Array = []
		var hueco: float = Terreno3D.casilla * 0.48
		var b := 0.0
		while b < 360.0:
			var ang := deg_to_rad(b)
			var p := o + Vector3(sin(ang), 0.0, -cos(ang)) * r
			if not (p.z - o.z > 0.0 and absf(p.x - o.x) < hueco + 0.6) and not _choca(p):
				abiertos2.append(int(b))
			b += 5.0
		_ok(abiertos2.is_empty(), "6.2 %s: el muro redondo cierra (abierto en %s)" % [sala.name, str(abiertos2)])
		_ok(not _choca(o + Vector3(0.0, 0.0, r - 0.3)) and not _choca(o + Vector3(0.0, 0.0, r)), "6.3 %s: por la puerta se sale" % sala.name)
		var nombres: Array = []
		for h in (sala as Node).get_children():
			if String(h.name).begins_with("Solido") and h is StaticBody3D:
				nombres.append(String(h.name))
		var pide: Array = ["SolidoMuro"] + (["SolidoCaja"] if sala.tienda else ["SolidoVaca", "SolidoCerdo", "SolidoBanco", "SolidoPesebre", "SolidoValla_cancela"])
		var faltan: Array = pide.filter(func(x): return not nombres.has(x))
		_ok(faltan.is_empty(), "6.4 %s: cuerpos por malla de muro, muebles, animales y valla (faltan %s; hay %d)" % [sala.name, str(faltan), nombres.size()])
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
