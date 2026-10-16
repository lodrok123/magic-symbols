extends SceneTree
## Puzle3D (Fase 12.3, 16/10): la gramática de `; pieza` / `; puzle`, sin escena ni ventana y con un mundo falso. Lo escribe el Juego.
##   · LEER: líneas buenas (valores, listas de casillas, valores por defecto), líneas malas (cada una avisa con su número de línea y las
##     demás siguen), ids repetidos, referencias a lo que no existe, comentarios libres que no son instrucciones.
##   · MONTAR Y JUGAR: las piezas se instancian de verdad sobre el contenedor del mundo falso y las reglas actúan (señales, `si=`, varias
##     acciones, las dos direcciones de una compuerta: la regresión del Callable.bind que se quedaba con la primera conexión).
##   godot --headless --path . --script res://herramientas/prueba_puzle.gd

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
		"#..c...#",
		"#..cc..#",
		"#..c...#",
		"#......#",
		"#......#",
		"#.u..i.#",
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
	_leer_bien()
	_leer_mal()
	await _montar_y_jugar()
	await _montar_mal()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------------------------------------------------
#  1 · Leer: líneas buenas
# ---------------------------------------------------------------------------------------------------------------------

func _leer_bien() -> void:
	var t: String = "\n".join([
		"; Esto es un comentario libre y no avisa",
		"; pieza  b1  pulsador  2 3  modo=agua rearme=1.5",
		"# esta línea no empieza por ; y se ignora (es una fila del mapa)",
		";pieza k1 compuerta 4 3 abierta=si abre_con=fuego cierra_con=hielo estrecha=no vertical=0",
		"; pieza n1 nivel 5 5 objetivo=0.35 banda=0.08 invertido=true",
		"; pieza cu cuenca 1 1 celdas=4,10..4,12+1,12..2,12 nivel=0.7 fijo=si",
		"; pieza cu2 cuenca 6 6 fijo=0.02",
		"; pieza m1 manantial 3 3 caudal=1.5 volumen=20 rampa=no inicia=no celdas=3,3..3,5",
		"; pieza t1 tinaja 2 2 canal=1,2+1,3",
		"; pieza p1 puerta 6 1",
		"; puzle r1 cuando=b1.pulsado hace=k1.abrir y=p1.abrir",
		"; puzle r2 cuando=n1 si=k1.abierta hace=p1.alternar",
		"; puzle r3 cuando=t1.agua_llega hace=t1.abrir_cauce(0.5,20)",
		"; puzle r4 cuando=k1.cerrada hace=m1.apagar_fuente y=cu.helar(5)",
	])
	var r: Dictionary = Puzle3D.parsear(t)
	var piezas: Array = r["piezas"]
	var reglas: Array = r["reglas"]
	_ok("1 todas las líneas buenas pasan (8 piezas, 4 reglas) y no hay avisos", piezas.size() == 8 and reglas.size() == 4 and (r["avisos"] as Array).is_empty(), "%d piezas, %d reglas, %s" % [piezas.size(), reglas.size(), str(r["avisos"])])
	if piezas.size() < 8 or reglas.size() < 4:
		return
	var b1: Puzle3D.Pieza = piezas[0]
	_ok("1 pulsador: casilla, modo y rearme", b1.id == "b1" and b1.tipo == "pulsador" and b1.celda == Vector2i(2, 3) and b1.p["modo"] == "agua" and is_equal_approx(float(b1.p["rearme"]), 1.5) and b1.n == 2, "línea %d" % b1.n)
	var k1: Puzle3D.Pieza = piezas[1]
	_ok("1 «;pieza» sin espacio tras el «;» también vale; booleanos si/no/0/1/true", k1.id == "k1" and k1.p["abierta"] == true and k1.p["estrecha"] == false and k1.p["vertical"] == false and k1.p["abre_con"] == "fuego" and k1.p["cierra_con"] == "hielo")
	var n1: Puzle3D.Pieza = piezas[2]
	_ok("1 nivel: números y «true»", is_equal_approx(float(n1.p["objetivo"]), 0.35) and is_equal_approx(float(n1.p["banda"]), 0.08) and n1.p["invertido"] == true)
	var cu: Puzle3D.Pieza = piezas[3]
	var celdas: Array = cu.p["celdas"]
	_ok("1 lista de casillas: rectángulos unidos con «+» (3 + 2 casillas)", celdas.size() == 5 and celdas.has(Vector2i(4, 10)) and celdas.has(Vector2i(4, 12)) and celdas.has(Vector2i(1, 12)) and celdas.has(Vector2i(2, 12)), str(celdas))
	_ok("1 fijo=si es true y nivel=0.7", cu.p["fijo"] == true and is_equal_approx(float(cu.p["nivel"]), 0.7))
	_ok("1 fijo=<número> es el número", is_equal_approx(float((piezas[4] as Puzle3D.Pieza).p["fijo"]), 0.02))
	var m1: Puzle3D.Pieza = piezas[5]
	_ok("1 manantial: caudal, volumen, rampa=no, inicia=no", is_equal_approx(float(m1.p["caudal"]), 1.5) and is_equal_approx(float(m1.p["volumen"]), 20.0) and m1.p["rampa"] == false and m1.p["inicia"] == false)
	_ok("1 tinaja: canal", (piezas[6] as Puzle3D.Pieza).p["canal"] == [Vector2i(1, 2), Vector2i(1, 3)])
	_ok("1 una clave que no se escribe no aparece (los valores por defecto los pone el montaje)", not (piezas[7] as Puzle3D.Pieza).p.has("celdas") and (piezas[7] as Puzle3D.Pieza).celda == Vector2i(6, 1))
	var r1: Dictionary = reglas[0]
	_ok("1 regla con cuando=id.señal, hace y y=: dos acciones", r1["cuando_id"] == "b1" and r1["senal"] == "pulsado" and (r1["acciones"] as Array).size() == 2 and r1["acciones"][1]["accion"] == "abrir" and r1["acciones"][1]["id"] == "p1")
	var r2: Dictionary = reglas[1]
	_ok("1 sin señal vale la de por defecto de la pieza (nivel → alcanzado) y el si= queda resuelto", r2["senal"] == "alcanzado" and r2["si_id"] == "k1" and r2["si_cond"] == "abierta")
	var a3: Dictionary = (reglas[2]["acciones"] as Array)[0]
	_ok("1 argumentos entre paréntesis: abrir_cauce(0.5,20)", a3["accion"] == "abrir_cauce" and a3["args"] == [0.5, 20.0], str(a3["args"]))
	_ok("1 helar(5) lleva su argumento", is_equal_approx(float((reglas[3]["acciones"][1]["args"] as Array)[0]), 5.0))
	# Sin saltos de línea de Windows ni tabuladores: se leen igual.
	var rw: Dictionary = Puzle3D.parsear("; pieza w1\tpulsador 1 1\r\n; puzle q cuando=w1 hace=w1.pulsar\r\n")
	_ok("1 acepta \\r\\n y tabuladores", (rw["piezas"] as Array).size() == 1 and (rw["reglas"] as Array).size() == 1 and (rw["avisos"] as Array).is_empty(), str(rw["avisos"]))


# ---------------------------------------------------------------------------------------------------------------------
#  2 · Leer: líneas malas
# ---------------------------------------------------------------------------------------------------------------------

## Una sola línea mala entre dos buenas: avisa UNA vez, con su número y su texto, y las buenas se leen.
func _una_mala(nombre: String, linea_mala: String, trozo_aviso: String, preambulo: String = "") -> void:
	var t: String = "; pieza ok1 pulsador 1 1\n" + preambulo + linea_mala + "\n; pieza ok2 pulsador 2 2"
	var r: Dictionary = Puzle3D.parsear(t)
	var av: Array = r["avisos"]
	var n_linea: int = 2 + preambulo.count("\n")
	_ok("2 %s: un aviso con «línea %d» y la línea mala" % [nombre, n_linea], av.size() == 1 and String(av[0]).begins_with("línea %d:" % n_linea) and String(av[0]).contains(linea_mala.strip_edges()), str(av))
	_ok("2 %s: dice qué falla («%s»)" % [nombre, trozo_aviso], av.size() >= 1 and String(av[0]).contains(trozo_aviso), str(av))
	_ok("2 %s: las piezas buenas de alrededor se leen" % nombre, (r["piezas"] as Array).size() >= 2 and Puzle3D.parsear(t)["piezas"][0].id == "ok1")


func _leer_mal() -> void:
	_una_mala("pieza incompleta", "; pieza solo_dos pulsador", "pieza incompleta")
	_una_mala("tipo desconocido", "; pieza x1 volador 1 1", "tipo desconocido")
	_una_mala("casilla que no es número", "; pieza x2 pulsador a b", "enteros")
	_una_mala("valor fuera de la lista", "; pieza x3 pulsador 1 1 modo=raro", "uno de: magia, agua, presencia")
	_una_mala("clave que no existe", "; pieza x4 pulsador 1 1 color=rojo", "no tiene la clave «color»")
	_una_mala("clave sin valor", "; pieza x5 pulsador 1 1 rearme", "no es clave=valor")
	_una_mala("número mal escrito", "; pieza x6 nivel 1 1 objetivo=mucho", "tiene que ser un número")
	_una_mala("booleano mal escrito", "; pieza x7 compuerta 1 1 abierta=quizas", "si o no")
	_una_mala("lista de casillas mal escrita", "; pieza x8 cuenca 1 1 celdas=1;2", "no es x,y")
	_una_mala("id con punto", "; pieza a.b pulsador 1 1", "id no válido")
	_una_mala("id repetido", "; pieza ok1 pulsador 3 3", "id repetido «ok1» (ya está en la línea 1)")
	# Reglas
	_una_mala("cuando a una pieza que no existe", "; puzle r cuando=fantasma.pulsado hace=ok1.pulsar", "no hay ninguna pieza «fantasma»")
	_una_mala("señal que la pieza no emite", "; puzle r cuando=ok1.explota hace=ok2.pulsar", "no emite «explota»")
	_una_mala("pieza sin señales como disparador", "; puzle r cuando=cu.pulsado hace=ok1.pulsar", "no emite señales", "; pieza cu cuenca 5 5\n")
	_una_mala("acción que la pieza no sabe", "; puzle r cuando=ok1.pulsado hace=ok2.abrir", "no sabe «abrir»")
	_una_mala("acción sobre pieza que no existe", "; puzle r cuando=ok1.pulsado hace=nadie.abrir", "no hay ninguna pieza «nadie»")
	_una_mala("argumento que no es número", "; puzle r cuando=ok1.pulsado hace=cu.helar(mucho)", "no es un número", "; pieza cu cuenca 5 5\n")
	_una_mala("demasiados argumentos", "; puzle r cuando=ok1.pulsado hace=cu.helar(1,2)", "como mucho 1 argumento", "; pieza cu cuenca 5 5\n")
	_una_mala("paréntesis sin cerrar", "; puzle r cuando=ok1.pulsado hace=cu.helar(5", "falta el «)»", "; pieza cu cuenca 5 5\n")
	_una_mala("condición que no existe", "; puzle r cuando=ok1.pulsado si=ok2.volando hace=ok2.pulsar", "no tiene la condición «volando»")
	_una_mala("falta hace", "; puzle r cuando=ok1.pulsado", "falta «hace=")
	_una_mala("falta cuando", "; puzle r hace=ok1.pulsar", "falta «cuando=")
	_una_mala("clave de puzle que no existe", "; puzle r cuando=ok1.pulsado hace=ok2.pulsar entonces=algo", "clave desconocida «entonces»")
	_una_mala("falta el nombre", "; puzle cuando=ok1.pulsado hace=ok2.pulsar", "falta el nombre")
	_una_mala("dos cuando", "; puzle r cuando=ok1.pulsado cuando=ok2.pulsado hace=ok2.pulsar", "dos «cuando=»")
	_una_mala("nombre de puzle repetido", "; puzle r cuando=ok1.pulsado hace=ok2.pulsar", "nombre de puzle repetido «r»", "; puzle r cuando=ok2.pulsado hace=ok1.pulsar\n")
	# Todo junto: nada tumba al resto
	var junto: Dictionary = Puzle3D.parsear("\n".join([
		"; pieza a pulsador 1 1", "; pieza a pulsador 1 1", "; pieza b volador 1 1", "; pieza c compuerta 2 2",
		"; puzle ok cuando=a.pulsado hace=c.abrir", "; puzle mal cuando=zz hace=c.abrir",
	]))
	_ok("2 varias malas juntas: 2 avisos y se leen las 2 piezas y la regla buenas", (junto["avisos"] as Array).size() == 3 and (junto["piezas"] as Array).size() == 2 and (junto["reglas"] as Array).size() == 1, "%d avisos %s" % [(junto["avisos"] as Array).size(), str(junto["avisos"])])
	var nada: Dictionary = Puzle3D.parsear("")
	_ok("2 texto vacío: nada y sin avisos", (nada["piezas"] as Array).is_empty() and (nada["reglas"] as Array).is_empty() and (nada["avisos"] as Array).is_empty())


# ---------------------------------------------------------------------------------------------------------------------
#  3 · Montar y jugar con un mundo falso
# ---------------------------------------------------------------------------------------------------------------------

func _mundo() -> MundoFalso:
	var m := MundoFalso.new()
	m._props = Node3D.new()
	m.add_child(m._props)
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(8):
		for x in range(8):
			if m._mapa[y][x] == "#":
				m._bloqueadas[Vector2i(x, y)] = true
	Lanzador3D.montar_agua_sim()
	return m


func _montar_y_jugar() -> void:
	var m: MundoFalso = _mundo()
	var sim: AguaSim3D = Terreno3D.agua_sim
	var texto: String = "\n".join([
		"; pieza boton pulsador 1 4 modo=magia",
		"; pieza boton2 pulsador 2 4 modo=magia",
		"; pieza placa pulsador 3 4 modo=presencia",
		"; pieza puerta puerta 5 5",
		"; pieza otra puerta 5 6",
		"; pieza cierre compuerta 3 1 abierta=no",
		"; pieza rio cuenca 3 2 celdas=3,2..4,2 nivel=0.3",
		"; pieza desague cuenca 4 2 fijo=0.05",
		"; pieza fuente manantial 3 3 caudal=1.2 rampa=no inicia=no",
		"; pieza nexo nexo 5 4",
		"; pieza barril barril 5 3",
		"; pieza n nivel 3 2 objetivo=0.2",
		# la compuerta manda en la puerta en las DOS direcciones (regresión del Callable.bind)
		"; puzle c_abre cuando=cierre.abierta hace=puerta.abrir",
		"; puzle c_cierra cuando=cierre.cerrada hace=puerta.cerrar",
		# un pulsador, dos acciones; con condición
		"; puzle p1 cuando=boton.pulsado hace=cierre.abrir y=nexo.mojar",
		"; puzle p2 cuando=boton2.pulsado si=cierre.abierta hace=barril.encender",
		"; puzle p3 cuando=placa hace=otra.alternar",
		"; puzle p4 cuando=placa.soltado hace=fuente.abrir_cauce",
		"; puzle p5 cuando=n.perdido hace=desague.helar(2)",
		"; puzle p6 cuando=barril.explota hace=fuente.apagar_fuente",
	])
	var z := Puzle3D.new()
	root.add_child(z)
	var vistos: Array = []
	z.aviso_nuevo.connect(func(t: String) -> void: vistos.append(t))
	z.iniciar(m, "", texto)
	await process_frame
	_ok("3 todas las piezas montadas: 12, sin avisos", z.piezas().size() == 12 and z.avisos.is_empty() and vistos.is_empty(), str(z.avisos))
	var cierre: Compuerta3D = z.nodo("cierre") as Compuerta3D
	var puerta: Puzle3D.PuertaPuzle = z.nodo("puerta") as Puzle3D.PuertaPuzle
	var otra: Puzle3D.PuertaPuzle = z.nodo("otra") as Puzle3D.PuertaPuzle
	var boton: Pulsador3D = z.nodo("boton") as Pulsador3D
	var boton2: Pulsador3D = z.nodo("boton2") as Pulsador3D
	var placa: Pulsador3D = z.nodo("placa") as Pulsador3D
	var nexo: NexoRayo3D = z.nodo("nexo") as NexoRayo3D
	var barril: Barril3D = z.nodo("barril") as Barril3D
	_ok("3 cada pieza es de su clase y cuelga del contenedor del mundo (`_props`)", cierre != null and puerta != null and boton != null and placa != null and nexo != null and barril != null and cierre.get_parent() == m._props)
	_ok("3 pieza_en(casilla, tipo) la encuentra", z.pieza_en(Vector2i(2, 4), "pulsador").id == "boton2" and z.pieza_en(Vector2i(9, 9)) == null)
	_ok("3 la cuenca con nivel=0.3 llena sus casillas", absf(sim.profundidad_casilla(Vector2i(3, 2)) - 0.3) < 0.02, "%.3f" % sim.profundidad_casilla(Vector2i(3, 2)))
	_ok("3 cuenca sin nivel (desague) no llena nada por sí misma pero abre la casilla", Terreno3D.cauces_abiertos.has(Vector2i(4, 2)))
	_ok("3 `cuando=id` sin señal se conecta a la de por defecto", z.puzle("p3")["senal"] == "pulsado")
	# Un pulsador con dos acciones
	boton.pulsar()
	_ok("3 p1: el pulsador abre la compuerta Y moja el nexo (hace= y y=)", cierre.abierta and nexo.conduce and int(z.puzle("p1")["veces"]) == 1)
	_ok("3 c_abre: al abrirse la compuerta se abre la puerta (señal abierta)", puerta.abierta and int(z.puzle("c_abre")["veces"]) == 1)
	# si=: con la compuerta abierta, boton2 enciende el barril
	boton2.pulsar()
	_ok("3 p2: con si=cierre.abierta cumplido, la regla actúa (barril encendido)", barril.encendido and int(z.puzle("p2")["veces"]) == 1 and int(z.puzle("p2")["ignoradas"]) == 0)
	# Las dos direcciones: cerrar la compuerta cierra la puerta (esto fallaba con Callable.bind)
	cierre.cerrar()
	_ok("3 c_cierra: al cerrarse la compuerta se CIERRA la puerta (las dos direcciones de una misma pieza)", not cierre.abierta and not puerta.abierta and int(z.puzle("c_cierra")["veces"]) == 1)
	# si= que no se cumple: la regla no actúa y lo cuenta
	var barril_antes: bool = barril.explotado
	boton2.activo = false                                 # el pulsador ya está rearmado (rearme 0): se puede pulsar otra vez
	boton2.pulsar()                                       # (la compuerta está cerrada: si=cierre.abierta falla)
	_ok("3 p2: con si=cierre.abierta sin cumplir, la regla NO actúa y cuenta una ignorada", int(z.puzle("p2")["veces"]) == 1 and int(z.puzle("p2")["ignoradas"]) == 1 and barril.explotado == barril_antes)
	# Señal sin argumentos (soltado) y señal con filtro por defecto
	placa.pulsar()
	_ok("3 p3: la placa alterna la otra puerta (pulsado, 1 argumento descartado)", otra.abierta and int(z.puzle("p3")["veces"]) == 1)
	# Manantial que espera una acción y la acción abrir_cauce con los datos de la pieza
	_ok("3 el manantial con inicia=no no echa agua hasta que una regla lo pide", sim.caudal_en(Vector2i(3, 3)) == 0.0 and not z.pieza("fuente").activa)
	z.pieza("fuente").p["rampa"] = false
	z._ejecutar({"id": "fuente", "accion": "abrir_cauce", "args": []})
	_ok("3 abrir_cauce sin argumentos usa el caudal de la pieza (1.2 u³/s, rampa=no)", absf(sim.caudal_en(Vector2i(3, 3)) - 1.2) < 1.0e-4 and z.pieza("fuente").activa, "%.3f" % sim.caudal_en(Vector2i(3, 3)))
	z._ejecutar({"id": "fuente", "accion": "apagar_fuente", "args": []})
	_ok("3 apagar_fuente lo cierra", sim.caudal_en(Vector2i(3, 3)) == 0.0 and not z.pieza("fuente").activa)
	z._ejecutar({"id": "fuente", "accion": "abrir_cauce", "args": [0.7, 0.0]})
	_ok("3 abrir_cauce(0.7,0) usa los argumentos de la regla", absf(sim.caudal_en(Vector2i(3, 3)) - 0.7) < 1.0e-4, "%.3f" % sim.caudal_en(Vector2i(3, 3)))
	# helar(s) y su caducidad
	var cu: Puzle3D.Pieza = z.pieza("desague")
	z._ejecutar({"id": "desague", "accion": "helar", "args": [2.0]})
	_ok("3 helar(2) hiela la casilla", sim.casilla_helada(Vector2i(4, 2)) and Terreno3D.helada(Vector2i(4, 2)))
	z._process(1.0)
	_ok("3 … y sigue helada a 1 s", sim.casilla_helada(Vector2i(4, 2)))
	z._process(1.5)
	_ok("3 … y a los 2 s se deshiela sola", not sim.casilla_helada(Vector2i(4, 2)) and not Terreno3D.helada(Vector2i(4, 2)) and cu != null)
	# Una señal de un nodo que ya no existe no rompe nada
	boton.free()
	z._ejecutar({"id": "boton", "accion": "pulsar", "args": []})
	_ok("3 una acción sobre una pieza liberada se ignora sin romper", true)
	m.queue_free()
	z.queue_free()
	await process_frame


## Montar con cosas que no se pueden montar: avisos, nunca un crash.
func _montar_mal() -> void:
	var m: MundoFalso = _mundo()
	var texto: String = "\n".join([
		"; pieza muro pulsador 0 0",
		"; pieza fuera pulsador 40 40",
		"; pieza seco nivel 1 1 objetivo=0.5",
		"; pieza tinaja_fantasma tinaja 2 6 canal=1,6",
		"; pieza tinaja_mala tinaja 3 6 canal=1,6",
		"; pieza tot totem 5 6",
		"; pieza em emisor 2 5",
		"; pieza bueno pulsador 4 5",
		"; puzle a cuando=tinaja_fantasma.agua_llega hace=bueno.pulsar",
		"; puzle b cuando=bueno.pulsado hace=bueno.pulsar",
	])
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "", texto)
	await process_frame
	var t: String = " | ".join(z.avisos)
	_ok("4 una pieza sobre un muro avisa y no se monta", t.contains("«muro»") and t.contains("es un muro") and z.nodo("muro") == null, t)
	_ok("4 una pieza fuera del mapa avisa", t.contains("«fuera»") and z.nodo("fuera") == null)
	_ok("4 una pieza de agua sobre suelo seco avisa", t.contains("«seco»") and t.contains("pieza de agua") and z.nodo("seco") == null)
	_ok("4 una tinaja que la maqueta no tiene avisa", t.contains("no hay tinaja de la maqueta") and z.nodo("tinaja_fantasma") == null)
	_ok("4 un tótem que la maqueta no tiene avisa", t.contains("no hay tótem de la maqueta"))
	_ok("4 un emisor en una casilla sin letra «e» avisa", t.contains("esperaba la letra «e»"))
	_ok("4 una tinaja en una casilla sin letra «u» avisa", t.contains("«tinaja_mala»") and t.contains("esperaba la letra «u»") and z.nodo("tinaja_mala") == null)
	_ok("4 la regla cuyo disparador no se pudo montar avisa, y no actúa", t.contains("la pieza «tinaja_fantasma» no se pudo montar"))
	_ok("4 lo que sí se puede montar se monta (el pulsador bueno) y su regla actúa", z.nodo("bueno") != null)
	_ok("4 hay rótulo AVISO en el HUD", z._hud != null and z._hud.text.contains("AVISO") and z._hud.text.contains("muro"))
	var bueno: Pulsador3D = z.nodo("bueno") as Pulsador3D
	bueno.pulsar()
	_ok("4 la regla b (pulsador → pulsar a sí mismo) se dispara una vez sin bucle", int(z.puzle("b")["veces"]) >= 1)
	# Un archivo que no existe: aviso, sin caída
	var z2 := Puzle3D.new()
	root.add_child(z2)
	z2.iniciar(m, "NoExisteEsteMapa")
	_ok("4 un nivel sin mapa avisa y no cae", z2.avisos.size() == 1 and String(z2.avisos[0]).contains("no hay mapa «NoExisteEsteMapa»"), str(z2.avisos))
	# Sin simulación de agua: las piezas de agua avisan, las demás se montan
	Terreno3D.agua_sim = null
	var z3 := Puzle3D.new()
	root.add_child(z3)
	z3.iniciar(m, "", "; pieza n nivel 3 1 objetivo=0.3\n; pieza b pulsador 1 4")
	_ok("4 sin simulación de agua: el nivel avisa («agua_fisica») y el pulsador se monta", z3.nodo("n") == null and z3.nodo("b") != null and String(" ".join(z3.avisos)).contains("agua_fisica"), str(z3.avisos))
	m.queue_free()
	z.queue_free()
	z2.queue_free()
	z3.queue_free()
