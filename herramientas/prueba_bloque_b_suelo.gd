extends SceneTree
## Bloque B, lado del SUELO (6/11, docs/PROPUESTAS_COMBATE_2026-11-06.md §2 B3 y B4, tabla §6.3). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_bloque_b_suelo.gd
## B3: el viento LIMPIA (seca lo mojado, quita lo electrificado y lo quemado, no toca el hielo); la tierra deja ESCOMBRO (6 s, ralentiza ×0,7, sólido para proyectiles, nunca en el agua);
## el rayo sobre casilla mojada electrifica 6 s y sobre seca no deja nada; el calor (y el agua sobre lo quemado) dejan VAPOR 4 s.
## B4: MATERIAL por casilla (letra del mapa, pieza `; material`), la tabla elemento × material (`puede_prender`, arena que se seca el doble, tierra que no hace escombro en el agua)
## y que `ReaccionesSuelo3D.prever` diga lo mismo que `aplicar` en cada caso.

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _precalentando: bool = false
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	func _es_agua(l: String) -> bool:
		return l == "~"
	func _es_hierba(c: Vector2i) -> bool:
		return c.x >= 0 and c.y >= 0 and c.x < _lado and c.y < _lado and String(_mapa[c.y][c.x]) == "v"
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass
	func quitar_placa_hielo(_c: Vector2i) -> void:
		pass

const SECA := Vector2i(8, 8)        ## suelo desnudo, letra «.»
const SECA2 := Vector2i(9, 8)
const HIERBA := Vector2i(4, 4)      ## letra «v»
const AGUA := Vector2i(12, 12)      ## letra «~»
const ARENA := Vector2i(6, 6)       ## suelo al que la prueba pone material arena

var _fallos: int = 0
var _m: MundoFalso = null
var _e: EstadosSuelo3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	_viento()
	_tierra()
	_rayo()
	_vapor()
	_material()
	_tabla_material()
	_prever_igual_que_aplicar()
	_sin_mundo()
	Terreno3D.estados.limpiar()
	Terreno3D.estados.olvidar_materiales()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	for c in [HIERBA, Vector2i(5, 4), Vector2i(4, 5)]:
		filas[c.y] = filas[c.y].substr(0, c.x) + "v" + filas[c.y].substr(c.x + 1)
	for c in [AGUA, Vector2i(13, 12)]:
		filas[c.y] = filas[c.y].substr(0, c.x) + "~" + filas[c.y].substr(c.x + 1)
	_m = MundoFalso.new()
	_m._mapa = filas
	root.add_child(_m)
	Lanzador3D.configurar(_m)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#" or filas[y][x] == "~":
				_m._bloqueadas[Vector2i(x, y)] = true
	Terreno3D.alturas.clear()
	_e = Terreno3D.estados
	_e.limpiar()
	_e.olvidar_materiales()
	_e.hierba_en = Callable(_m, "_es_hierba")
	_e.poner_material(ARENA, "arena")
	_ok("0 montaje: SECA es suelo, HIERBA es hierba, AGUA es agua para el estado", ReaccionesSuelo3D.clase_de(SECA) == "suelo" and ReaccionesSuelo3D.clase_de(HIERBA) == "hierba" and ReaccionesSuelo3D.clase_de(AGUA) == "agua")


func _accion(elemento: String, c: Vector2i) -> Dictionary:
	return ReaccionesSuelo3D.aplicar(AccionElemental.nueva(elemento, Terreno3D.centro_de(c, 0.0)))


func _estados(c: Vector2i) -> Array:
	var r: Array = []
	for s in EstadosSuelo3D.TODOS:
		if _e.tiene(c, s):
			r.append(s)
	return r


func _viento() -> void:
	_e.limpiar()
	_ok("1 el viento 'sopla' en ACCION_DE", ReaccionesSuelo3D.ACCION_DE.get("viento", "") == "sopla")
	_e.poner(SECA, EstadosSuelo3D.MOJADA, true)
	_ok("1 prever viento sobre mojada = «seca»", String(ReaccionesSuelo3D.prever("viento", SECA).get("reaccion", "")) == "seca")
	_accion("viento", SECA)
	_ok("1 viento sobre MOJADA la seca", not _e.tiene(SECA, EstadosSuelo3D.MOJADA))
	_e.poner(SECA, EstadosSuelo3D.ELECTRIFICADA, true)
	_ok("1 prever viento sobre electrificada = «limpia»", String(ReaccionesSuelo3D.prever("viento", SECA).get("reaccion", "")) == "limpia")
	_accion("viento", SECA)
	_ok("1 viento sobre ELECTRIFICADA la quita", not _e.tiene(SECA, EstadosSuelo3D.ELECTRIFICADA))
	_e.poner(SECA, EstadosSuelo3D.QUEMADA, true)
	_accion("viento", SECA)
	_ok("1 viento sobre QUEMADA la quita", not _e.tiene(SECA, EstadosSuelo3D.QUEMADA))
	_e.poner(SECA, EstadosSuelo3D.MOJADA, true)
	_e.poner(SECA, EstadosSuelo3D.ELECTRIFICADA, true)
	_e.poner(SECA, EstadosSuelo3D.QUEMADA, true)
	_accion("viento", SECA)
	_ok("1 mojada + electrificada + quemada: de un soplo no queda ninguna %s" % str(_estados(SECA)), _estados(SECA).is_empty())
	_ok("1 viento sobre casilla limpia: no hace nada ni se previsualiza", not bool(_accion("viento", SECA).get("cambio", false)) and ReaccionesSuelo3D.prever("viento", SECA).is_empty())
	_e.aplicar(SECA, "frio")
	_e.poner(SECA, EstadosSuelo3D.ELECTRIFICADA, true)
	_ok("1 sobre HELADA el viento no previsualiza nada (el hielo pesa)", ReaccionesSuelo3D.prever("viento", SECA).is_empty())
	_accion("viento", SECA)
	_ok("1 viento sobre HELADA no la toca (ni lo electrificado de encima: el hielo pesa)", _e.tiene(SECA, EstadosSuelo3D.HELADA) and _e.tiene(SECA, EstadosSuelo3D.ELECTRIFICADA))
	# Por el camino del Lanzador (un impacto de viento del VFX).
	_e.limpiar()
	_e.poner(SECA2, EstadosSuelo3D.MOJADA, true)
	var l := Lanzador3D.new()
	l.mundo = _m
	root.add_child(l)
	l.al_impactar("viento", Terreno3D.centro_de(SECA2, Terreno3D.y_pies(SECA2)))
	_ok("1 y por `Lanzador3D.al_impactar(viento)` (el camino del juego) también", not _e.tiene(SECA2, EstadosSuelo3D.MOJADA))
	l.free()
	_e.limpiar()


func _tierra() -> void:
	_e.limpiar()
	var esc: String = EstadosSuelo3D.ESCOMBRO
	_ok("2 constantes: ESCOMBRO_S = 6,0 y DURA[escombro] la lee", is_equal_approx(EstadosSuelo3D.ESCOMBRO_S, 6.0) and is_equal_approx(float(EstadosSuelo3D.DURA[esc]), 6.0))
	_ok("2 prever tierra sobre suelo = «escombro»", String(ReaccionesSuelo3D.prever("tierra", SECA).get("reaccion", "")) == "escombro")
	var r: Dictionary = _accion("tierra", SECA)
	_ok("2 la tierra deja escombro en el suelo y avisa del cambio", _e.tiene(SECA, esc) and bool(r.get("cambio", false)))
	_ok("2 con 6,0 s", is_equal_approx(_e.queda(SECA, esc), 6.0), str(_e.queda(SECA, esc)))
	_ok("2 bloquea_proyectil(celda) = true y en una casilla limpia = false", _e.bloquea_proyectil(SECA) and not _e.bloquea_proyectil(SECA2))
	_ok("2 factor_velocidad(celda) = 0,7 y en la limpia = 1,0", is_equal_approx(_e.factor_velocidad(SECA), 0.7) and is_equal_approx(_e.factor_velocidad(SECA2), 1.0))
	_e.avanzar(5.9)
	_ok("2 a los 5,9 s sigue", _e.tiene(SECA, esc))
	_e.avanzar(0.2)
	_ok("2 a los 6,1 s se va y ya no bloquea ni frena", not _e.tiene(SECA, esc) and not _e.bloquea_proyectil(SECA) and is_equal_approx(_e.factor_velocidad(SECA), 1.0))
	# Otra pedrada lo renueva.
	_accion("tierra", SECA)
	_e.avanzar(4.0)
	_accion("tierra", SECA)
	_ok("2 otra pedrada renueva los 6 s", is_equal_approx(_e.queda(SECA, esc), 6.0))
	# Nunca en el agua.
	_ok("2 prever tierra sobre AGUA = nada", ReaccionesSuelo3D.prever("tierra", AGUA).is_empty())
	_accion("tierra", AGUA)
	_ok("2 la tierra NO deja escombro en el agua", not _e.tiene(AGUA, esc))
	# Sobre una casilla de suelo cuyo material es agua (pieza) tampoco.
	_e.poner_material(SECA2, "agua")
	_accion("tierra", SECA2)
	_ok("2 ni en una casilla de suelo con material agua (tierra × agua = nada)", not _e.tiene(SECA2, esc) and ReaccionesSuelo3D.prever("tierra", SECA2).is_empty())
	_e.poner_material(SECA2, "")
	# Sobre hierba sí (es solo un estado), con la altura >= 1 no (golpea el bloque).
	_accion("tierra", HIERBA)
	_ok("2 sobre HIERBA también deja escombro", _e.tiene(HIERBA, esc))
	Terreno3D.alturas[SECA2] = 1
	_accion("tierra", SECA2)
	_ok("2 con un bloque encima (altura 1) no deja nada", not _e.tiene(SECA2, esc))
	Terreno3D.alturas.clear()
	# Una casilla bloqueada (barrera de tierra ya levantada: sólida) no recibe escombro.
	var bloq := Vector2i(10, 8)
	_m._bloqueadas[bloq] = true
	_accion("tierra", bloq)
	_ok("2 una casilla ya SÓLIDA (barrera de tierra) no recibe escombro", not _e.tiene(bloq, esc))
	_m._bloqueadas.erase(bloq)
	# Por el camino del juego.
	var l := Lanzador3D.new()
	l.mundo = _m
	root.add_child(l)
	_e.limpiar()
	l.al_impactar("tierra", Terreno3D.centro_de(SECA, Terreno3D.y_pies(SECA)))
	_ok("2 y por `Lanzador3D.al_impactar(tierra)` (flecha de tierra que se para)", _e.tiene(SECA, esc))
	l.free()
	# Persistencia: sobrevive a guardar/cargar con su tiempo.
	var d: Dictionary = _e.a_dic()
	_e.limpiar()
	_e.desde_dic(d)
	_ok("2 el escombro se guarda y se carga", _e.tiene(SECA, esc) and _e.queda(SECA, esc) > 5.0)
	_e.limpiar()


func _rayo() -> void:
	_e.limpiar()
	var elec: String = EstadosSuelo3D.ELECTRIFICADA
	var l := Lanzador3D.new()
	l.mundo = _m
	root.add_child(l)
	_e.poner(SECA, EstadosSuelo3D.MOJADA, true)
	_ok("3 prever rayo sobre mojada = «electrifica»; sobre seca = nada", String(ReaccionesSuelo3D.prever("rayo", SECA).get("reaccion", "")) == "electrifica" and ReaccionesSuelo3D.prever("rayo", SECA2).is_empty())
	# Un HECHIZO de rayo (marcar_celda, lo que hace HechizoVivo en cada casilla del haz), no solo el emisor.
	l.marcar_celda("rayo", SECA)
	l.marcar_celda("rayo", SECA2)
	_ok("3 el hechizo de rayo electrifica la casilla MOJADA (6 s)", _e.tiene(SECA, elec) and is_equal_approx(_e.queda(SECA, elec), 6.0), str(_e.queda(SECA, elec)))
	_ok("3 y sobre la SECA no deja nada", not _e.tiene(SECA2, elec))
	_e.avanzar(6.1)
	_ok("3 a los 6 s caduca", not _e.tiene(SECA, elec))
	# El impacto de rayo del VFX (aplicar_accion) hace lo mismo por la tabla.
	_accion("rayo", SECA2)
	_ok("3 el impacto de rayo sobre seca (tabla) no deja nada", not _e.tiene(SECA2, elec))
	_accion("rayo", SECA)
	_ok("3 el impacto de rayo sobre mojada (tabla) electrifica con 6 s", _e.tiene(SECA, elec) and is_equal_approx(_e.queda(SECA, elec), 6.0))
	# La descarga NO acorta una electrificada que otro mantiene sin caducidad.
	_e.poner(SECA, elec, true, 1.0, 0.0)
	_accion("rayo", SECA)
	_ok("3 y no acorta la que mantiene otro sin caducidad (el canal de un puzle)", _e.queda(SECA, elec) == 0.0)
	l.free()
	_e.limpiar()


func _vapor() -> void:
	_e.limpiar()
	var v: String = EstadosSuelo3D.VAPOR
	_ok("4 VAPOR_S = 4,0 y DURA[vapor] la lee", is_equal_approx(EstadosSuelo3D.VAPOR_S, 4.0) and is_equal_approx(float(EstadosSuelo3D.DURA[v]), 4.0))
	_ok("4 sin calor no hay vapor", not _e.hay_vapor(SECA))
	_e.aplicar(SECA, "agua")
	_ok("4 mojar no deja vapor", not _e.hay_vapor(SECA))
	var r: Dictionary = _e.aplicar(SECA, "calor")
	_ok("4 el calor sobre MOJADA la seca y deja vapor 4 s (el efecto visual sigue siendo «vapor»)", not _e.tiene(SECA, EstadosSuelo3D.MOJADA) and _e.hay_vapor(SECA) and is_equal_approx(_e.queda(SECA, v), 4.0) and String(r["efecto"]) == "vapor", str(r))
	_e.avanzar(3.9)
	_ok("4 a los 3,9 s sigue", _e.hay_vapor(SECA))
	_e.avanzar(0.2)
	_ok("4 a los 4,1 s se va", not _e.hay_vapor(SECA))
	_e.aplicar(SECA2, "frio")
	_e.aplicar(SECA2, "calor")
	_ok("4 el calor sobre HELADA (deshiela a charco) también deja vapor", _e.tiene(SECA2, EstadosSuelo3D.MOJADA) and _e.hay_vapor(SECA2))
	_e.poner(SECA, EstadosSuelo3D.QUEMADA, true)
	_e.aplicar(SECA, "agua")
	_ok("4 el agua sobre QUEMADA deja vapor (y moja; la quemada se queda para su reloj)", _e.hay_vapor(SECA) and _e.tiene(SECA, EstadosSuelo3D.MOJADA) and _e.tiene(SECA, EstadosSuelo3D.QUEMADA))
	_ok("4 la previsión del agua sobre otra quemada lo rotula «vapor» (rótulo «Vapor»)", String(PrevisionReaccion3D.ESTILO["vapor"][0]) == "Vapor")
	_e.limpiar()
	_e.poner(SECA, EstadosSuelo3D.QUEMADA, true)
	_ok("4 prever agua sobre quemada = «vapor»", String(ReaccionesSuelo3D.prever("agua", SECA).get("reaccion", "")) == "vapor")
	_e.limpiar()
	_e.aplicar(SECA, "calor")
	_ok("4 el calor sobre suelo seco no deja vapor", not _e.hay_vapor(SECA))
	_ok("4 los rótulos nuevos existen: Seca, Limpia, Escombro, Vapor", String(PrevisionReaccion3D.ESTILO["seca"][0]) == "Seca" and String(PrevisionReaccion3D.ESTILO["limpia"][0]) == "Limpia" and String(PrevisionReaccion3D.ESTILO["escombro"][0]) == "Escombro" and String(PrevisionReaccion3D.ESTILO["vapor"][0]) == "Vapor")
	_e.limpiar()


func _material() -> void:
	_e.limpiar()
	var e := EstadosSuelo3D.new()      # sin `hierba_en`: solo la letra del mapa y lo fijado
	_ok("5 MATERIALES son hierba, roca, tierra, madera, agua, arena", EstadosSuelo3D.MATERIALES == PackedStringArray(["hierba", "roca", "tierra", "madera", "agua", "arena"]))
	_ok("5 por LETRA: «v» hierba, «~» agua, «#» roca, «.» tierra, «b» madera", e.material_de(HIERBA) == "hierba" and e.material_de(AGUA) == "agua" and e.material_de(Vector2i(0, 0)) == "roca" and e.material_de(SECA) == "tierra")
	_ok("5 la maqueta (`hierba_en`) manda sobre la letra: una casilla que ella llama hierba lo es", _e.material_de(HIERBA) == "hierba" and _e.material_de(SECA) == "tierra")
	_ok("5 por PIEZA/parámetro: `poner_material` sobrescribe la letra (ARENA)", _e.material_de(ARENA) == "arena" and e.material_de(ARENA) == "tierra")
	_ok("5 un material que no existe se rechaza y no cambia nada", not e.poner_material(SECA, "oro") and e.material_de(SECA) == "tierra")
	# La pieza del mapa.
	var texto: String = "; zona 1,1..3,3 normal\n; material 7 7 roca\n; material 2,10..4,10 madera\n; material 9 9 oro\n; material x y roca\n..."
	var n: int = e.leer_materiales(texto)
	_ok("5 la pieza `; material x y mat` y la de rectángulo se leen (4 casillas) y las malas se saltan", n == 4 and e.material_de(Vector2i(7, 7)) == "roca" and e.material_de(Vector2i(3, 10)) == "madera" and e.material_de(Vector2i(9, 9)) == "tierra", str(n))
	e.poner_material(Vector2i(7, 7), "")
	_ok("5 vaciar el material de una casilla vuelve a la letra", e.material_de(Vector2i(7, 7)) == "tierra")
	# Por la ruta del juego: EstadoZona3D.leer_texto la lee junto a las zonas.
	_e.olvidar_materiales()
	var ez := EstadoZona3D.new()
	ez.leer_texto("; material 6 6 arena\n; material 7 7 madera\n")
	_ok("5 `EstadoZona3D.leer_texto` (el cargador del nivel) alimenta la capa de materiales", _e.material_de(ARENA) == "arena" and _e.material_de(Vector2i(7, 7)) == "madera")
	ez.free()
	# `limpiar` (que corre al cargar una partida) no borra los materiales del mapa; el cambio de nivel sí.
	_e.limpiar()
	_ok("5 `limpiar` (cargar partida) NO borra los materiales del mapa", _e.material_de(ARENA) == "arena")
	_e.olvidar_materiales()
	_ok("5 `olvidar_materiales` (cambio de nivel) sí", _e.material_de(ARENA) == "tierra")
	_e.poner_material(ARENA, "arena")


func _tabla_material() -> void:
	_e.limpiar()
	_e.poner_material(Vector2i(7, 7), "madera")
	_e.poner_material(Vector2i(7, 9), "roca")
	var hierba_ok: bool = true
	var otras_no: bool = true
	for y in range(20):
		for x in range(20):
			var c := Vector2i(x, y)
			if _m._es_hierba(c) and not _e.puede_prender(c):
				hierba_ok = false
			if not _m._es_hierba(c) and String(_m._mapa[y][x]) == "." and not _e.material_de(c) == "madera" and _e.puede_prender(c):
				otras_no = false
	_ok("6 fuego × hierba = prende (todas las casillas que la maqueta llama hierba, como hoy)", hierba_ok)
	_ok("6 fuego × tierra/roca/arena = no prende", otras_no and not _e.puede_prender(SECA) and not _e.puede_prender(Vector2i(7, 9)) and not _e.puede_prender(ARENA))
	_ok("6 fuego × agua = no prende", not _e.puede_prender(AGUA))
	_ok("6 fuego × madera = prende SIN propagarse; la hierba prende y propaga", _e.puede_prender(Vector2i(7, 7)) and not _e.propaga_fuego(Vector2i(7, 7)) and _e.propaga_fuego(HIERBA) and not _e.propaga_fuego(SECA))
	# El fuego sobre roca/tierra/arena no la quema (ni deja quemada), pero sí seca el charco y deshiela como siempre.
	_e.aplicar(SECA, "agua")
	_e.aplicar(SECA, "calor")
	_ok("6 fuego × tierra: no deja quemada, y el calor sigue secando el charco (lo de siempre)", not _e.tiene(SECA, EstadosSuelo3D.QUEMADA) and not _e.tiene(SECA, EstadosSuelo3D.MOJADA))
	# Agua × arena: se seca el doble de rápido (DURA/2).
	_e.limpiar()
	_e.aplicar(ARENA, "agua")
	_e.aplicar(SECA, "agua")
	_ok("6 agua × arena: la mojada dura DURA/2 (%.1f s) y en tierra DURA (%.1f s)" % [_e.queda(ARENA, EstadosSuelo3D.MOJADA), _e.queda(SECA, EstadosSuelo3D.MOJADA)], is_equal_approx(_e.queda(ARENA, EstadosSuelo3D.MOJADA), float(EstadosSuelo3D.DURA["mojada"]) / 2.0) and is_equal_approx(_e.queda(SECA, EstadosSuelo3D.MOJADA), float(EstadosSuelo3D.DURA["mojada"])))
	_e.avanzar(10.1)
	_ok("6 …a los 10,1 s la arena ya está seca y la tierra sigue mojada", not _e.tiene(ARENA, EstadosSuelo3D.MOJADA) and _e.tiene(SECA, EstadosSuelo3D.MOJADA))
	# Hielo × agua: hiela (dato de la tabla; lo ejecuta la simulación del agua).
	_ok("6 hielo × agua = hiela (la tabla lo dice)", bool(EstadosSuelo3D.reaccion("hielo", "agua", "hiela", false)))
	_ok("6 tierra × agua = no actúa (la tabla)", not bool(EstadosSuelo3D.reaccion("tierra", "agua", "actua", true)))
	_e.limpiar()


## En cada combinación elemento × estado inicial × material, `prever` dice algo si y solo si `aplicar` cambia algo.
func _prever_igual_que_aplicar() -> void:
	_e.limpiar()
	var elementos: Array = ["agua", "hielo", "fuego", "viento", "tierra", "rayo"]
	var iniciales: Array = [[], ["mojada"], ["helada"], ["electrificada"], ["quemada"], ["mojada", "electrificada"], ["mojada", "quemada"], ["escombro"], ["vapor"], ["mojada", "electrificada", "quemada"]]
	var celdas: Array = [SECA, ARENA, HIERBA, AGUA, Vector2i(7, 7), Vector2i(7, 9)]
	_e.poner_material(Vector2i(7, 7), "madera")
	_e.poner_material(Vector2i(7, 9), "roca")
	var casos: int = 0
	var distintos: PackedStringArray = []
	var nombres: Dictionary = {}
	for c in celdas:
		for el in elementos:
			for ini in iniciales:
				_e.limpiar()
				for s in ini:
					if s == "helada":
						_e.aplicar(c, "frio")                 # la escarcha de verdad, como la deja un hechizo
						_e.poner(c, EstadosSuelo3D.MOJADA, false)
					else:
						_e.poner(c, String(s), true)
				var antes: Array = _estados(c)
				var prev: Dictionary = ReaccionesSuelo3D.prever(String(el), c)
				_accion(String(el), c)
				var despues: Array = _estados(c)
				var cambio: bool = antes != despues
				var dice: bool = not prev.is_empty()
				casos += 1
				if dice != cambio:
					# La hierba tiene su propia previsión (autómata de la maqueta, sin MaquetaReal aquí), y el agua honda la de la simulación: solo comparan los casos del suelo.
					if ReaccionesSuelo3D.clase_de(c) in ["suelo"] or (ReaccionesSuelo3D.clase_de(c) == "hierba" and el == "tierra"):
						distintos.append("%s × %s %s sobre %s: prever=%s, aplicar %s → %s" % [el, str(c), str(ini), _e.material_de(c), str(prev.get("reaccion", "-")), str(antes), str(despues)])
				elif dice:
					nombres[String(prev["reaccion"])] = true
	_ok("7 prever == aplicar en %d combinaciones (suelo, y escombro en hierba): sin diferencias %s" % [casos, str(distintos)], distintos.is_empty())
	_ok("7 y la previsión llegó a decir todos los rótulos nuevos %s" % str(nombres.keys()), nombres.has("seca") and nombres.has("limpia") and nombres.has("escombro") and nombres.has("vapor") and nombres.has("electrifica") and nombres.has("moja") and nombres.has("hiela") and nombres.has("derrite"))
	# El material cuenta en la previsión: el mismo aplicar sobre arena y sobre tierra sigue diciendo «moja».
	_e.limpiar()
	_ok("7 la previsión sobre arena dice «moja» igual que sobre tierra (la diferencia es cuánto dura)", String(ReaccionesSuelo3D.prever("agua", ARENA).get("reaccion", "")) == "moja")
	_e.limpiar()
	_e.olvidar_materiales()
	_e.poner_material(ARENA, "arena")


func _sin_mundo() -> void:
	# Un `EstadosSuelo3D` suelto (como el de las pruebas) sigue funcionando: tierra por defecto, ni prende ni escombra en agua.
	var e := EstadosSuelo3D.new()
	var c := Vector2i(3, 3)
	_ok("8 sin hierba conectada, un EstadosSuelo3D suelto da material tierra y no prende", e.material_de(c) == "tierra" and not e.puede_prender(c))
	_ok("8 sin acción conocida («tierra» a secas) no hace nada, como siempre", not bool(e.aplicar(c, "tierra")["cambio"]))
	e.aplicar(c, "escombro")
	_ok("8 y la acción «escombro» sí lo deja", e.tiene(c, EstadosSuelo3D.ESCOMBRO))
