extends SceneTree
## C2 de PLAN_EOW (21/10, Juego): condiciones compuestas en `si=` de Puzle3D: «+» (Y), «|» (O), «!» (NO), `casilla(x,y).<estado>`,
## `flag.<nombre>` y la plantilla `$`. Parte 1: el parseo (sin mundo). Parte 2: una sala montada con el mundo falso de prueba_flags:
## «la puerta abre si las tres casillas están mojadas y el brasero apagado» (el «brasero» es un pulsador: `!br.activo`; montar uno
## real exige la maqueta, y lo que se prueba es la expresión, no el fuego). El estado de casilla se pone con `Terreno3D.estados.poner`.
##   godot --headless --path . --script res://herramientas/prueba_puzle_condiciones.gd
## o, desde la raíz del repo:  tools\prueba_una.cmd prueba_puzle_condiciones

class MundoFalso extends Node3D:
	const S: float = 2.3
	const ALTO: float = 2.3 * 0.45
	const ALTO_AGUA: float = 2.3 * 0.45 * 0.6
	var _lado: int = 8
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _props: Node3D = null
	var _mapa: PackedStringArray = [
		"########",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"#......#",
		"########",
	]
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_parseo()
	_plantilla()
	_errores()
	await _sala()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


const BASE: String = "; pieza b pulsador 1 1\n; pieza br pulsador 2 1\n; pieza k compuerta 3 1\n; pieza p puerta 4 1\n"


## Parsea una regla con `si=` y devuelve [si_expr, avisos, regla o null].
func _si(si: String) -> Array:
	var r: Dictionary = Puzle3D.parsear(BASE + "; puzle r cuando=b.pulsado si=%s hace=p.abrir" % si)
	var reglas: Array = r["reglas"]
	return [reglas[0]["si_expr"] if not reglas.is_empty() else null, r["avisos"], reglas[0] if not reglas.is_empty() else null]


func _parseo() -> void:
	# Un solo término: igual que antes, con si_id / si_cond.
	var u: Array = _si("k.abierta")
	_ok("1 un término: sin avisos, 1 grupo de 1", (u[1] as Array).is_empty() and u[0] != null and u[0].size() == 1 and u[0][0].size() == 1, str(u))
	_ok("1 compatible: si_id y si_cond como siempre", u[2]["si_id"] == "k" and u[2]["si_cond"] == "abierta")
	# Y
	var y: Array = _si("k.abierta+br.activo")
	_ok("2 Y: un grupo de dos términos", (y[1] as Array).is_empty() and y[0].size() == 1 and y[0][0].size() == 2 and y[0][0][1]["id"] == "br", str(y))
	_ok("2 Y: ya no es 'una sola condición' (si_id vacío)", y[2]["si_id"] == "")
	# O
	var o: Array = _si("k.abierta|br.activo")
	_ok("3 O: dos grupos de uno", (o[1] as Array).is_empty() and o[0].size() == 2 and o[0][0].size() == 1 and o[0][1].size() == 1, str(o))
	# NO
	var ne: Array = _si("!k.abierta")
	_ok("4 NO: término negado y 'si_id' vacío", (ne[1] as Array).is_empty() and ne[0][0][0]["neg"] == true and ne[2]["si_id"] == "", str(ne))
	_ok("4 sin «!» no está negado", u[0][0][0]["neg"] == false)
	# Precedencia: Y antes que O
	var m1: Array = _si("k.abierta+br.activo|b.activo")
	_ok("5 a+b|c = (a y b) o c", m1[0].size() == 2 and m1[0][0].size() == 2 and m1[0][1].size() == 1 and m1[0][1][0]["id"] == "b", str(m1))
	var m2: Array = _si("b.activo|k.abierta+br.activo")
	_ok("5 a|b+c = a o (b y c)", m2[0].size() == 2 and m2[0][0].size() == 1 and m2[0][1].size() == 2, str(m2))
	var m3: Array = _si("!k.abierta+!br.activo|!b.activo")
	_ok("5 negaciones dentro de la mezcla", m3[0][0][0]["neg"] and m3[0][0][1]["neg"] and m3[0][1][0]["neg"] and (m3[1] as Array).is_empty(), str(m3))
	# Casilla (la coma no separa)
	var c: Array = _si("casilla(3,4).mojada")
	_ok("6 casilla: celda, estado, un solo término", (c[1] as Array).is_empty() and c[0].size() == 1 and c[0][0].size() == 1 and c[0][0][0]["tipo"] == "casilla" and c[0][0][0]["celda"] == Vector2i(3, 4) and c[0][0][0]["estado"] == "mojada", str(c))
	var cc: Array = _si("casilla(1,1).mojada+casilla(2,2).helada|!casilla(3,3).agua")
	_ok("6 casillas combinadas con + y |", (cc[1] as Array).is_empty() and cc[0].size() == 2 and cc[0][0].size() == 2 and cc[0][1][0]["neg"] and cc[0][1][0]["estado"] == "agua", str(cc))
	for e in ["mojada", "helada", "quemada", "electrificada", "segada", "agua"]:
		var ce: Array = _si("casilla(0,0).%s" % e)
		_ok("6 estado %s vale" % e, (ce[1] as Array).is_empty() and ce[0] != null, str(ce[1]))
	var neg2: Array = _si("casilla(-1,2).mojada")
	_ok("6 casilla con coordenada negativa se lee", neg2[0] != null and neg2[0][0][0]["celda"] == Vector2i(-1, 2), str(neg2[1]))
	# Flag
	var f: Array = _si("flag.bosque1.s3.placa+!flag.bosque1.s3.cofre|k.abierta")
	_ok("7 flag mezclada con Y, NO y O", (f[1] as Array).is_empty() and f[0].size() == 2 and f[0][0][0]["tipo"] == "flag" and f[0][0][1]["neg"] and f[0][0][1]["nombre"] == "bosque1.s3.cofre", str(f))


func _errores() -> void:
	var malas: Array = ["k.abierta+", "+k.abierta", "k.abierta|", "k.abierta||br.activo", "k.abierta++br.activo", "!", "!!k.abierta", "k.abierta+!",
		"casilla(3.mojada", "casilla(a,4).mojada", "casilla(3,4)mojada", "casilla(3).mojada", "casilla(3,4,5).mojada", "casilla(3,4).",
		"casilla(3,4).fuego", "casilla(3,4).mojadaa", "zz.abierta", "k.abierta+zz.abierta", "k.volando", "k.abierta|flag.mal"]
	for s in malas:
		var r: Array = _si(String(s))
		_ok("8 mala «%s»: aviso y regla ignorada" % s, r[0] == null and not (r[1] as Array).is_empty(), str(r[1]))
	var av: Array = _si("casilla(3,4).fuego")[1]
	_ok("8 el aviso de estado desconocido dice los que valen", String(av[0]).contains("desconocido") and String(av[0]).contains("electrificada") and String(av[0]).contains("agua"), str(av))
	var av2: Array = _si("k.abierta+")[1]
	_ok("8 el aviso de «+» al final lo nombra", String(av2[0]).contains("sin condición"), str(av2))
	# Una mala no estropea las buenas del mismo archivo.
	var mix: Dictionary = Puzle3D.parsear(BASE + "; puzle buena cuando=b.pulsado si=k.abierta+br.activo hace=p.abrir\n; puzle mala cuando=b.pulsado si=k.abierta+ hace=p.abrir")
	_ok("8 la buena sigue y la mala sale", (mix["reglas"] as Array).size() == 1 and (mix["avisos"] as Array).size() == 1, str(mix["avisos"]))


func _plantilla() -> void:
	var t: String = "; pieza g pulsador 5 6 modo=magia rearme=0.5\n; pieza q puerta 1 1\n"
	var r: Dictionary = Puzle3D.parsear(t + "; puzle a cuando=g.pulsado si=!casilla($x,$y).mojada+casilla($x,$y).helada hace=q.abrir")
	_ok("9 $x $y: sustituidos por la casilla del disparador", (r["avisos"] as Array).is_empty() and not (r["reglas"] as Array).is_empty()
		and r["reglas"][0]["si_expr"][0][0]["celda"] == Vector2i(5, 6) and r["reglas"][0]["si_expr"][0][1]["celda"] == Vector2i(5, 6), str(r["avisos"]))
	var r2: Dictionary = Puzle3D.parsear(t + "; puzle a cuando=g.pulsado si=$id.activo hace=q.abrir")
	_ok("9 $id: el id del disparador (g.activo)", (r2["avisos"] as Array).is_empty() and not (r2["reglas"] as Array).is_empty() and r2["reglas"][0]["si_expr"][0][0]["id"] == "g", str(r2["avisos"]))
	# $1 $2 = claves en orden escrito (modo, rearme)
	var r3: Dictionary = Puzle3D.parsear(t + "; puzle a cuando=g.pulsado hace=tin.abrir_cauce($2)\n; pieza tin tinaja 3 3")
	_ok("9 $2: segunda clave (rearme=0.5) llega como argumento numérico", (r3["avisos"] as Array).is_empty() and not (r3["reglas"] as Array).is_empty()
		and r3["reglas"][0]["acciones"][0]["args"] == [0.5], str(r3["avisos"]))
	var r4: Dictionary = Puzle3D.parsear("; pieza br2 brasero 2 2 rele=otro\n; pieza otro brasero 3 3\n; pieza q puerta 1 1\n; puzle a cuando=br2.encendido hace=$1.apagar y=q.abrir")
	_ok("9 $1 = id de otra pieza (rele=otro): hace=otro.apagar", (r4["avisos"] as Array).is_empty() and not (r4["reglas"] as Array).is_empty()
		and r4["reglas"][0]["acciones"][0]["id"] == "otro" and r4["reglas"][0]["acciones"][0]["accion"] == "apagar" and r4["reglas"][0]["acciones"].size() == 2, str(r4["avisos"]))
	# Errores de plantilla
	var e1: Dictionary = Puzle3D.parsear(t + "; puzle a cuando=g.pulsado hace=$7.abrir")
	_ok("10 $7 sin siete claves: aviso y regla ignorada", (e1["reglas"] as Array).is_empty() and (e1["avisos"] as Array).size() == 1 and String(e1["avisos"][0]).contains("$7"), str(e1["avisos"]))
	var e2: Dictionary = Puzle3D.parsear(t + "; puzle a cuando=g.pulsado hace=$zeta.abrir")
	_ok("10 $zeta desconocido: aviso", (e2["reglas"] as Array).is_empty() and (e2["avisos"] as Array).size() == 1, str(e2["avisos"]))
	var e3: Dictionary = Puzle3D.parsear(t + "; puzle a cuando=flag.pr.s1.x hace=$id.abrir")
	_ok("10 $ con cuando=flag: aviso (no hay pieza)", (e3["reglas"] as Array).is_empty() and (e3["avisos"] as Array).size() == 1, str(e3["avisos"]))
	var s0: Dictionary = Puzle3D.parsear(t + "; puzle a cuando=g.pulsado hace=q.abrir")
	_ok("10 sin «$» todo queda igual", (s0["avisos"] as Array).is_empty() and (s0["reglas"] as Array).size() == 1)


func _sala() -> void:
	Flags.nuevo()
	var m := MundoFalso.new()
	m._props = Node3D.new()
	m.add_child(m._props)
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(8):
		for x in range(8):
			if m._mapa[y][x] == "#":
				m._bloqueadas[Vector2i(x, y)] = true
	var cs: Array = [Vector2i(2, 5), Vector2i(3, 5), Vector2i(4, 5)]
	for c in cs:
		Terreno3D.estados.poner(c, "mojada", false)
	var z := Puzle3D.new()
	root.add_child(z)
	# Un pulsador distinto por intento (cada uno es de un solo uso), todos con la MISMA condición.
	var cond: String = "casilla(2,5).mojada+casilla(3,5).mojada+casilla(4,5).mojada+!br.activo"
	var txt: Array = ["; pieza br pulsador 6 1 modo=magia"]
	for i in range(1, 6):
		txt.append("; pieza g%d pulsador %d 1 modo=magia" % [i, i])
		txt.append("; pieza p%d puerta %d 3" % [i, i])
		txt.append("; puzle abre%d cuando=g%d.pulsado si=%s hace=p%d.abrir" % [i, i, cond, i])
	# Con plantilla: la casilla del propio pulsador (la 6,6) y su id.
	txt.append("; pieza gt pulsador 6 6 modo=magia")
	txt.append("; pieza pt puerta 1 6")
	txt.append("; puzle plantilla cuando=gt.pulsado si=casilla($x,$y).mojada hace=pt.abrir")
	txt.append("; pieza gu pulsador 5 6 modo=magia")
	txt.append("; pieza pu puerta 2 6")
	txt.append("; puzle plantilla2 cuando=gu.pulsado si=casilla($x,$y).mojada hace=pu.abrir")
	z.iniciar(m, "", "\n".join(txt))
	await process_frame
	_ok("11 sala montada sin avisos", z.avisos.is_empty(), str(z.avisos))
	var P: Callable = func(i: int) -> Puzle3D.PuertaPuzle: return z.nodo("p%d" % i) as Puzle3D.PuertaPuzle
	# Intento 1: ninguna casilla mojada.
	(z.nodo("g1") as Pulsador3D).pulsar()
	_ok("12 ninguna casilla mojada: la puerta NO abre (regla ignorada, no disparada)", not P.call(1).abierta and int(z.puzle("abre1")["ignoradas"]) == 1 and int(z.puzle("abre1")["veces"]) == 0)
	# Intento 2: solo dos casillas mojadas.
	Terreno3D.estados.poner(cs[0], "mojada", true)
	Terreno3D.estados.poner(cs[1], "mojada", true)
	(z.nodo("g2") as Pulsador3D).pulsar()
	_ok("13 dos de tres mojadas: NO abre", not P.call(2).abierta)
	# Intento 3: las tres mojadas y el «brasero» apagado.
	Terreno3D.estados.poner(cs[2], "mojada", true)
	(z.nodo("g3") as Pulsador3D).pulsar()
	_ok("14 tres mojadas y brasero apagado: ABRE", P.call(3).abierta and int(z.puzle("abre3")["veces"]) == 1)
	# Intento 4: las tres mojadas pero el «brasero» encendido.
	(z.nodo("br") as Pulsador3D).pulsar()
	(z.nodo("g4") as Pulsador3D).pulsar()
	_ok("15 tres mojadas pero brasero encendido: NO abre", not P.call(4).abierta and int(z.puzle("abre4")["ignoradas"]) == 1)
	# Una casilla se seca: otra vez no abre aunque el brasero... (sigue encendido; probamos la parte de casillas con una regla sin brasero)
	Terreno3D.estados.poner(cs[1], "mojada", false)
	(z.nodo("g5") as Pulsador3D).pulsar()
	_ok("16 una casilla se secó: NO abre", not P.call(5).abierta)
	# Plantilla: $x,$y = casilla (6,6) del propio pulsador
	Terreno3D.estados.poner(Vector2i(6, 6), "mojada", true)
	(z.nodo("gt") as Pulsador3D).pulsar()
	(z.nodo("gu") as Pulsador3D).pulsar()
	_ok("17 plantilla: su casilla (6,6) mojada, abre", (z.nodo("pt") as Puzle3D.PuertaPuzle).abierta)
	_ok("17 plantilla: su casilla (5,6) seca, no abre", not (z.nodo("pu") as Puzle3D.PuertaPuzle).abierta)
	Terreno3D.estados.poner(Vector2i(6, 6), "mojada", false)
	# cumple_expr directo sobre agua / helada / O / NO, con el estado puesto a mano.
	var c6: Vector2i = Vector2i(6, 6)
	var e_h: Array = Puzle3D.parsear(BASE + "; puzle r cuando=b.pulsado si=casilla(6,6).helada|casilla(6,6).quemada hace=p.abrir")["reglas"][0]["si_expr"]
	_ok("18 O de dos casillas: ninguna, falso", not z.cumple_expr(e_h))
	Terreno3D.estados.poner(c6, "quemada", true)
	_ok("18 O: una basta", z.cumple_expr(e_h))
	var e_n: Array = Puzle3D.parsear(BASE + "; puzle r cuando=b.pulsado si=!casilla(6,6).quemada hace=p.abrir")["reglas"][0]["si_expr"]
	_ok("18 NO: quemada → falso", not z.cumple_expr(e_n))
	Terreno3D.estados.poner(c6, "quemada", false)
	_ok("18 NO: ya no quemada → cierto", z.cumple_expr(e_n))
	var e_a: Array = Puzle3D.parsear(BASE + "; puzle r cuando=b.pulsado si=casilla(6,6).agua hace=p.abrir")["reglas"][0]["si_expr"]
	_ok("18 agua: sin simulación de agua, falso (Terreno3D.es_agua)", not z.cumple_expr(e_a) and Terreno3D.es_agua(c6) == z.cumple_expr(e_a))
	# flag en la expresión
	var e_f: Array = Puzle3D.parsear(BASE + "; puzle r cuando=b.pulsado si=flag.prueba.s1.x+!casilla(6,6).mojada hace=p.abrir")["reglas"][0]["si_expr"]
	_ok("19 flag+NO casilla: sin flag, falso", not z.cumple_expr(e_f))
	Flags.i().poner("prueba.s1.x")
	_ok("19 con la flag y sin mojar, cierto", z.cumple_expr(e_f))
	Terreno3D.estados.poner(c6, "mojada", true)
	_ok("19 mojada la casilla, falso", not z.cumple_expr(e_f))
	Terreno3D.estados.poner(c6, "mojada", false)
	for c in cs:
		Terreno3D.estados.poner(c, "mojada", false)
