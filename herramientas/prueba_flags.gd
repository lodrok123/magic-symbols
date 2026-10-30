extends SceneTree
## C1 de PLAN_EOW (21/10, Juego): flags con nombre. `Flags` (poner, leer, señal, guardar y cargar) y su uso en `Puzle3D`
## (acción flag.poner/quitar, señal cuando=flag.<nombre>, condición si=flag.<nombre>), con un puzle de dos piezas enlazadas SOLO
## por una flag. Sin ventana, con el mundo falso de prueba_puzle.gd.
##   godot --headless --path . --script res://herramientas/prueba_flags.gd
## o, desde la raíz del repo:  tools\prueba_una.cmd prueba_flags

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

const RUTA: String = "user://prueba_flags.json"

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_api()
	_version2()
	_gramatica()
	await _puzle_enlazado()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _api() -> void:
	var f: Flags = Flags.nuevo()
	var vistos: Array = []
	f.flag_cambio.connect(func(n: String, v: Variant) -> void: vistos.append([n, v]))
	_ok("1 nombres: nivel.sala.hecho vale", Flags.nombre_valido("bosque1.s3.placa_norte"))
	_ok("1 nombres: con dos trozos, mayúsculas, espacios o vacío, no", not Flags.nombre_valido("bosque1.placa") and not Flags.nombre_valido("Bosque1.s3.x") and not Flags.nombre_valido("b.s.con espacio") and not Flags.nombre_valido("b..x"))
	_ok("1 al empezar no hay nada", not f.tiene("bosque1.s3.placa_norte") and f.nombres().is_empty())
	_ok("1 poner devuelve true y queda puesta", f.poner("bosque1.s3.placa_norte") and f.tiene("bosque1.s3.placa_norte") and f.valor("bosque1.s3.placa_norte") == true)
	_ok("1 avisa una vez con (nombre, true)", vistos == [["bosque1.s3.placa_norte", true]], str(vistos))
	_ok("1 ponerla otra vez no avisa", not f.poner("bosque1.s3.placa_norte") and vistos.size() == 1)
	f.poner("bosque1.s3.antorchas", 3)
	_ok("1 admite un entero (contador)", f.valor("bosque1.s3.antorchas") == 3 and f.tiene("bosque1.s3.antorchas"))
	_ok("1 un nombre mal escrito no se guarda", not f.poner("mal") and not f.tiene("mal"))
	_ok("1 quitar avisa con false", f.quitar("bosque1.s3.antorchas") and not f.tiene("bosque1.s3.antorchas") and vistos.back() == ["bosque1.s3.antorchas", false], str(vistos))
	_ok("1 poner 0 es quitar", f.poner("bosque1.s4.x", 2) and f.poner("bosque1.s4.x", 0) and not f.tiene("bosque1.s4.x"))
	f.poner("bosque1.s4.cofre_abierto")
	f.poner("pradera.s1.puente", 2)
	_ok("1 nombres() por prefijo de sala", f.nombres("bosque1.") == ["bosque1.s3.placa_norte", "bosque1.s4.cofre_abierto"], str(f.nombres("bosque1.")))
	# Guardar y cargar (JSON)
	_ok("2 guardar escribe el archivo", f.guardar(RUTA) and FileAccess.file_exists(RUTA))
	var g: Flags = Flags.nuevo()
	var vistos_g: Array = []
	g.flag_cambio.connect(func(n: String, v: Variant) -> void: vistos_g.append([n, v]))
	_ok("2 cargar devuelve true", g.cargar(RUTA))
	_ok("2 vuelven las mismas flags y con su tipo (el entero sigue siendo entero)", g.nombres() == f.nombres() and g.valor("pradera.s1.puente") is int and g.valor("pradera.s1.puente") == 2, str(g.a_dic()))
	_ok("2 cargar avisa de cada flag que llega", vistos_g.size() == 3, str(vistos_g))
	_ok("2 cargar un archivo que no existe devuelve false", not Flags.nuevo().cargar("user://no_existe_jamas_flags.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))


## VERSIÓN 2 (F2 de PLAN_BASE_DATOS, 29/10): una flag puede ser una cadena corta («abierto»); `a_dic` separa `estados` y `flags`;
## `desde_dic` lee las dos secciones y también el formato de la versión 1.
func _version2() -> void:
	var f: Flags = Flags.nuevo()
	var vistos: Array = []
	f.flag_cambio.connect(func(n: String, v: Variant) -> void: vistos.append([n, v]))
	_ok("7 poner con cadena: queda puesta y valor() da la cadena", f.poner("bosque1.s1.cofre_01", "abierto") and f.tiene("bosque1.s1.cofre_01") and f.valor("bosque1.s1.cofre_01") == "abierto")
	_ok("7 avisa con la cadena", vistos == [["bosque1.s1.cofre_01", "abierto"]], str(vistos))
	_ok("7 la misma cadena otra vez no avisa; otra cadena sí", not f.poner("bosque1.s1.cofre_01", "abierto") and f.poner("bosque1.s1.cofre_01", "vacio") and vistos.size() == 2)
	f.poner("bosque1.s1.cofre_01", "abierto")
	_ok("7 una cadena vacía quita la flag", f.poner("bosque1.s2.x", "roto") and f.poner("bosque1.s2.x", "") and not f.tiene("bosque1.s2.x"))
	f.poner("bosque1.s3.antorchas", 3)
	f.poner("bosque1.rotulo.claro_visto")
	var d: Dictionary = f.a_dic()
	_ok("7 a_dic separa estados y flags", d.keys().size() == 2 and d["estados"] == {"bosque1.s1.cofre_01": "abierto"} and d["flags"] == {"bosque1.s3.antorchas": 3, "bosque1.rotulo.claro_visto": true}, str(d))
	# Por JSON (los enteros vuelven como float) y a una instancia nueva.
	var g: Flags = Flags.nuevo()
	g.desde_dic(JSON.parse_string(JSON.stringify(d)))
	_ok("7 desde_dic devuelve cadena, entero (int) y true", g.valor("bosque1.s1.cofre_01") == "abierto" and g.valor("bosque1.s3.antorchas") is int and g.valor("bosque1.s3.antorchas") == 3 and g.valor("bosque1.rotulo.claro_visto") == true)
	# Formato de la versión 1: con «version» y «flags», y plano.
	var v1: Flags = Flags.nuevo()
	v1.desde_dic({"version": 1, "flags": {"bosque1.s3.placa": true, "pradera.s1.puente": 2.0}})
	_ok("7 lee el formato viejo {version, flags}", v1.tiene("bosque1.s3.placa") and v1.valor("pradera.s1.puente") is int)
	var plano: Flags = Flags.nuevo()
	plano.desde_dic({"bosque1.s3.placa": true, "bosque1.s1.cofre": "abierto", "mal": true})
	_ok("7 lee un diccionario plano y descarta nombres mal escritos", plano.nombres() == ["bosque1.s1.cofre", "bosque1.s3.placa"] and plano.valor("bosque1.s1.cofre") == "abierto", str(plano.nombres()))
	var vacio: Flags = Flags.nuevo()
	vacio.desde_dic({})
	_ok("7 desde_dic({}) deja todo vacío", vacio.nombres().is_empty())
	# Cargar avisa de lo que desaparece
	var h: Flags = Flags.nuevo()
	h.poner("a.b.c", "x")
	var av: Array = []
	h.flag_cambio.connect(func(n: String, v: Variant) -> void: av.append([n, v]))
	h.desde_dic({})
	_ok("7 desde_dic avisa de la que desaparece (false)", av == [["a.b.c", false]], str(av))


func _gramatica() -> void:
	var t: String = "\n".join([
		"; pieza b pulsador 1 1",
		"; pieza p puerta 2 2",
		"; puzle marca cuando=b.pulsado hace=flag.poner(bosque1.s3.placa)",
		"; puzle abre cuando=flag.bosque1.s3.placa hace=p.abrir",
		"; puzle cond cuando=b.pulsado si=flag.bosque1.s3.placa hace=p.cerrar y=flag.quitar(bosque1.s3.placa)",
	])
	var r: Dictionary = Puzle3D.parsear(t)
	_ok("3 las tres reglas con flags se leen sin avisos", (r["reglas"] as Array).size() == 3 and (r["avisos"] as Array).is_empty(), str(r["avisos"]))
	if (r["reglas"] as Array).size() == 3:
		var a: Dictionary = r["reglas"][0]["acciones"][0]
		_ok("3 hace=flag.poner(nombre) guarda el nombre", a["id"] == "flag" and a["accion"] == "poner" and a["nombre"] == "bosque1.s3.placa")
		_ok("3 cuando=flag.<nombre>", r["reglas"][1]["cuando_id"] == "flag" and r["reglas"][1]["cuando_flag"] == "bosque1.s3.placa")
		var e: Array = r["reglas"][2]["si_expr"]
		_ok("3 si=flag.<nombre>", e.size() == 1 and e[0][0]["tipo"] == "flag" and e[0][0]["nombre"] == "bosque1.s3.placa")
	# Líneas malas
	var malas: Dictionary = Puzle3D.parsear("\n".join([
		"; pieza flag pulsador 1 1",
		"; pieza b pulsador 1 1",
		"; puzle m1 cuando=b hace=flag.poner(sinsala)",
		"; puzle m2 cuando=flag.mal hace=b.pulsar",
		"; puzle m3 cuando=b si=flag.Mal.x.y hace=b.pulsar",
		"; puzle m4 cuando=b hace=flag.borrar(a.b.c)",
		"; puzle m5 cuando=b hace=flag.poner",
	]))
	var av: Array = malas["avisos"]
	_ok("4 «flag» es reservado como id de pieza", av.size() >= 1 and String(av[0]).contains("reservada"), str(av))
	_ok("4 cinco reglas malas, cinco avisos más, ninguna regla", av.size() == 6 and (malas["reglas"] as Array).is_empty(), str(av))


## Dos piezas que no se conocen: el pulsador PONE la flag y la puerta se abre al OÍRLA. Luego se recarga la partida.
func _puzle_enlazado() -> void:
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
	var z := Puzle3D.new()
	root.add_child(z)
	z.iniciar(m, "", "\n".join([
		"; pieza b pulsador 1 1 modo=magia",
		"; pieza p puerta 3 3",
		"; pieza q puerta 4 4",
		"; puzle marca cuando=b.pulsado hace=flag.poner(prueba.s1.placa)",
		"; puzle abre cuando=flag.prueba.s1.placa hace=p.abrir",
		"; puzle abre2 cuando=b.pulsado si=flag.prueba.s1.placa hace=q.abrir",
	]))
	await process_frame
	var b: Pulsador3D = z.nodo("b") as Pulsador3D
	var p: Puzle3D.PuertaPuzle = z.nodo("p") as Puzle3D.PuertaPuzle
	var q: Puzle3D.PuertaPuzle = z.nodo("q") as Puzle3D.PuertaPuzle
	_ok("5 montado sin avisos", z.avisos.is_empty() and b != null and p != null and q != null, str(z.avisos))
	_ok("5 antes de pulsar: puerta cerrada y sin flag", not p.abierta and not Flags.i().tiene("prueba.s1.placa"))
	b.pulsar()
	_ok("5 pulsar pone la flag", Flags.i().tiene("prueba.s1.placa"))
	_ok("5 la puerta se abre al oír la flag (sin enlace con el pulsador)", p.abierta and int(z.puzle("abre")["veces"]) == 1)
	# si=flag: el orden de las reglas hace que abre2 vea la flag ya puesta (marca va antes en el mismo disparo).
	_ok("5 si=flag se cumple cuando la flag está", q.abierta and int(z.puzle("abre2")["veces"]) == 1)
	# Guardar, otra partida, cargar: la flag vuelve y la regla que la escucha salta.
	Flags.i().guardar(RUTA)
	p.cerrar()
	Flags.nuevo()
	var z2 := Puzle3D.new()
	root.add_child(z2)
	z2.iniciar(m, "", "\n".join([
		"; pieza p2 puerta 5 5",
		"; puzle abre cuando=flag.prueba.s1.placa hace=p2.abrir",
	]))
	await process_frame
	var p2: Puzle3D.PuertaPuzle = z2.nodo("p2") as Puzle3D.PuertaPuzle
	_ok("6 partida nueva: puerta cerrada", p2 != null and not p2.abierta)
	Flags.i().cargar(RUTA)
	_ok("6 al cargar la partida la flag vuelve y la puerta se abre sola", Flags.i().tiene("prueba.s1.placa") and p2.abierta)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))
