extends SceneTree
## A3 de docs/PLAN_EOW.md (21/10, Juego): CONTRATO MÍNIMO DE REACCIONES DE ENEMIGO + «CAE AL AGUA». Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_contrato_enemigo.gd
## Lo que comprueba:
##   1. Cada tipo de enemigo que crea Combate3D (guerrero, arquero, gatopedro y elemental de bosque) declara sus `reacciones_soportadas()` Y esa declaración es
##      verdad: cada una de las siete se PRUEBA con un golpe/empuje real, y lo declarado ha de coincidir con lo que ocurre (ni más ni menos).
##      Guerrero, arquero y gatopedro tienen las siete. El elemental NO tiene «mojado» (el agua lo cura) ni «aturdido» (pesa demasiado): decisión de diseño anterior
##      a A3 que se declara, no se finge.
##   2. Un enemigo empujado a una charca honda se hunde: muere sin botín (control: el que muere por daño sí lo suelta), emite `hundido`, avisa a Mundo3D con
##      «hundido» en la superficie y desaparece bajo el agua en ~1 s.
##   3. Sobre hielo no: lo sostiene. Si el hielo se derrite bajo sus pies, cae.
##   4. Un goblin que patrulla junto al agua, y uno que persigue al jugador al otro lado del río, NO se meten solos.

const DT: float = 1.0 / 60.0
const S: float = 2.3
const LADO: int = 14
const TIPOS: Array = ["guerrero", "arquero", "gatopedro", "elemental"]
## Casillas del charco honda (columnas 6-7, filas 3-8) y de la charca helada (columnas 10-11, filas 3-8).
const COL_AGUA: Array = [6, 7]
const COL_HIELO: Array = [10, 11]
const Y_FILAS: Array = [3, 4, 5, 6, 7, 8]

var _mundo: Mundo3D = null
var _jugador: Jugador3D = null
var _fallos: int = 0
var _avisos: Array = []          ## [punto, elemento, radio] de cada Mundo3D.impacto
var _hundidos: Array = []        ## enemigos que emitieron `hundido`


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	_montar()
	_contrato()
	await _hundirse_empujado()
	_hielo()
	await _hielo_derretido()
	_sin_meterse_solo()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			var borde: bool = x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1
			if borde:
				f += "#"
				bloq[Vector2i(x, y)] = true
			elif (COL_AGUA.has(x) or COL_HIELO.has(x)) and Y_FILAS.has(y):
				f += "~"
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	for x in COL_HIELO:
		for y in Y_FILAS:
			Terreno3D.poner_helada(Vector2i(x, y), true)
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	_mundo.impacto.connect(func(p: Vector3, el: String, r: float) -> void: _avisos.append([p, el, r]))
	_jugador = Jugador3D.new()
	_jugador.position = Vector3(1.5 * S, Terreno3D.alto_suelo, 12.5 * S)
	_jugador.pj = Pj3D.new()
	_mundo.add_child(_jugador.pj)


## Un enemigo del `tipo` en `p`, sin IA propia (se avanza a mano con `_pasos`) y quieto. Es el mismo montaje que prueba_contacto_fuego.
func _nuevo(tipo: String, p: Vector3, quieto: bool = true) -> Combate3D:
	var modelo := Pj3D.new()
	modelo.id = {"guerrero": "goblin_warrior", "arquero": "goblin_archer", "gatopedro": "lince", "elemental": "elemental_bosque"}[tipo]
	modelo.position = p
	_mundo.add_child(modelo)
	var g: Combate3D
	if tipo == "gatopedro":
		g = Gatopedro3D.equipar_gatopedro(modelo, _mundo, _jugador, null)
	else:
		g = Combate3D.equipar(modelo, _mundo, _jugador, null)
	g.set_physics_process(false)
	g.altura = 1.7 if tipo == "elemental" else 0.85
	g.quieto = quieto
	g.position = p
	g.casa = p
	g.hundido.connect(func(e: Combate3D) -> void: _hundidos.append(e))
	return g


func _quitar(g: Combate3D) -> void:
	if is_instance_valid(g):
		if is_instance_valid(g.pj):
			g.pj.free()
		g.free()


func _pasos(g: Combate3D, n: int) -> void:
	for _i in range(n):
		if is_instance_valid(g):
			g._physics_process(DT)


func _suelo(cx: float, cz: float) -> Vector3:
	return Vector3((cx + 0.5) * S, Terreno3D.y_pies(Vector2i(int(cx), int(cz))), (cz + 0.5) * S)


func _h(archivo: String) -> Hechizo:
	return Hechizo.construir(load("res://nucleo/%s_rune.tres" % archivo), {})


# ---------------------------------------------------------------------------------------------------------------------
#  1. El contrato
# ---------------------------------------------------------------------------------------------------------------------

## ¿Reacciona de verdad este tipo a `r`? Se aplica la reacción en un enemigo nuevo y se mira el efecto; nada se da por supuesto.
func _reacciona(tipo: String, r: String) -> bool:
	var g := _nuevo(tipo, _suelo(2, 2))
	var res: bool = false
	match r:
		"quemado":
			g.golpe(_h("fire"), Vector3.ZERO)
			res = g.quemando > 0.0
		"mojado":
			g.golpe(_h("water"), Vector3.ZERO)
			res = g.mojado > 0.0
		"congelado":
			g.golpe(_h("ice"), Vector3.ZERO)
			res = g.congelado > 0.0
		"electrocutado":
			g.golpe(_h("lightning"), Vector3.ZERO)
			res = g.health < g.vida_max
		"aturdido":
			g.golpe(_h("lightning"), Vector3.ZERO)
			_pasos(g, 1)
			res = g.stun_timer > 0.0
		"empujado":
			var z0: float = g.position.z
			g.push(Vector3(0, 0, 1), 200.0, true)           # eje Z: el paseo del gatopedro es en X, no confunde
			_pasos(g, 40)
			res = g.position.z > z0 + 0.05
		"cae_al_agua":
			var p := Vector3(COL_AGUA[0] * S - 0.25, Terreno3D.alto_suelo, 5.5 * S)
			g.position = p
			g.push(Vector3(1, 0, 0), 1500.0, true)
			_pasos(g, 120)
			res = g.muerto and g.se_hundio
	_quitar(g)
	return res


func _contrato() -> void:
	for tipo in TIPOS:
		var g := _nuevo(tipo, _suelo(2, 2))
		var declaradas: PackedStringArray = g.reacciones_soportadas()
		_quitar(g)
		var nombres_ok: bool = true
		for d in declaradas:
			if not Combate3D.REACCIONES.has(d):
				nombres_ok = false
		_ok("1 %s: reacciones_soportadas() solo usa los siete nombres del contrato" % tipo, nombres_ok and declaradas.size() <= 7, str(declaradas))
		var coincide: bool = true
		var info: String = ""
		for r in Combate3D.REACCIONES:
			var de_verdad: bool = _reacciona(tipo, r)
			if de_verdad != declaradas.has(r):
				coincide = false
				info += " %s(declara %s, hace %s)" % [r, declaradas.has(r), de_verdad]
		_ok("1 %s: lo que declara es lo que hace, reacción por reacción" % tipo, coincide, info)
		if tipo == "elemental":
			_ok("1 elemental: declara cinco (sin mojado ni aturdido, decisión de diseño)", declaradas.size() == 5 and not declaradas.has("mojado") and not declaradas.has("aturdido"), str(declaradas))
		else:
			_ok("1 %s: tiene las siete" % tipo, declaradas.size() == 7, str(declaradas))


# ---------------------------------------------------------------------------------------------------------------------
#  2. Empujado a la charca honda
# ---------------------------------------------------------------------------------------------------------------------

func _oros() -> int:
	var n: int = 0
	for c in _mundo.get_children():
		if c.name.begins_with("Oro"):
			n += 1
	return n


func _hundirse_empujado() -> void:
	# Control del botín: uno que muere por daño sí suelta oro (si no, «sin botín» no probaría nada).
	var ctrl := _nuevo("guerrero", _suelo(3, 10))
	ctrl.receive_damage(10000.0)
	_ok("2 control: muerto por daño suelta oro", ctrl.muerto and not ctrl.se_hundio and _oros() == 1, "oros %d" % _oros())
	var oros_antes: int = _oros()

	# Un goblin junto a la orilla, empujado hacia el agua por un viento fuerte.
	_avisos.clear()
	_hundidos.clear()
	var g := _nuevo("guerrero", Vector3(COL_AGUA[0] * S - 0.25, Terreno3D.alto_suelo, 5.5 * S))
	var y0: float = g.pj.position.y
	g.push(Vector3(1, 0, 0), 1500.0, true)
	_pasos(g, 120)
	_ok("2 un goblin empujado a una charca honda se hunde (muerto y ahogado)", g.muerto and g.se_hundio)
	_ok("2 emite la señal hundido(enemigo) una vez", _hundidos.size() == 1 and _hundidos[0] == g, "n=%d" % _hundidos.size())
	# Se hundió DENTRO de la física (`_ajustar_al_suelo` dentro de `_physics_process`, no `_morir(true)` a mano): `_animar()` no puede pisar el clip de ahogarse con `idle`.
	# Solo se exige si este modelo trae el clip (sin él, la pose de muerte de siempre).
	if g.pj.duracion(Combate3D.CLIP_AHOGARSE) > 0.0:
		_ok("2 hundido por la física, el modelo queda en el clip de ahogarse y no en idle", String(g.pj.animacion_actual).contains(Combate3D.CLIP_AHOGARSE), "anim «%s»" % g.pj.animacion_actual)
	else:
		print("AVISO 2 este modelo no trae el clip %s: no se comprueba el estado de animación" % Combate3D.CLIP_AHOGARSE)
	var aviso_ok: bool = false
	for a in _avisos:
		if a[1] == "hundido" and Terreno3D.es_agua(Terreno3D.celda_de(a[0])) and absf(a[0].y - Terreno3D.alto_agua) < 0.01 and a[2] > 0.0:
			aviso_ok = true
	_ok("2 avisa a Mundo3D «hundido» en la superficie del agua con radio", aviso_ok, str(_avisos))
	_ok("2 sin botín: no suelta oro", _oros() == oros_antes, "oros %d" % _oros())
	_ok("2 sale del grupo de combate (ya no es objetivo)", not g.is_in_group("combate3d"))
	await create_timer(0.5).timeout
	_ok("2 a los 0,5 s el modelo ya está bajando", is_instance_valid(g.pj) and g.pj.position.y < y0 - 0.05, "y %.2f → %.2f" % [y0, g.pj.position.y if is_instance_valid(g.pj) else -99.0])
	await create_timer(1.3).timeout
	_ok("2 a los ~1,8 s ha desaparecido bajo el agua (liberado)", not is_instance_valid(g))

	# Un goblin que no llega al agua (empujón corto) no se hunde.
	var corto := _nuevo("guerrero", Vector3(COL_AGUA[0] * S - 1.5, Terreno3D.alto_suelo, 5.5 * S))
	corto.push(Vector3(1, 0, 0), 100.0, true)
	_pasos(corto, 120)
	_ok("2 un empujón que no alcanza el agua no hunde", not corto.muerto, "x %.2f (orilla %.2f)" % [corto.position.x, COL_AGUA[0] * S])
	_quitar(corto)

	# Un empuje que lo lleva por una casilla de agua no helada pero fuera del mapa honda no aplica aquí; sí el arquero y el gatopedro (ya probados en 1).
	# Mundo3D y daño: morir ahogado cuenta como enemigo caído para las misiones.
	var cuenta: Array = [0]
	var cb := func(_p: Vector2, _n: String) -> void: cuenta[0] += 1
	Estado.i().enemigo_muerto.connect(cb)
	var g2 := _nuevo("arquero", Vector3(COL_AGUA[0] * S - 0.25, Terreno3D.alto_suelo, 6.5 * S))
	g2.push(Vector3(1, 0, 0), 1500.0, true)
	_pasos(g2, 120)
	Estado.i().enemigo_muerto.disconnect(cb)
	_ok("2 el ahogado cuenta como enemigo caído (Estado.enemigo_muerto, para misiones como la de Terra Fina)", g2.se_hundio and cuenta[0] == 1, "señales %d" % cuenta[0])
	await create_timer(1.5).timeout


# ---------------------------------------------------------------------------------------------------------------------
#  3. Hielo
# ---------------------------------------------------------------------------------------------------------------------

func _hielo() -> void:
	_hundidos.clear()
	var g := _nuevo("guerrero", Vector3(COL_HIELO[0] * S - 0.25, Terreno3D.alto_suelo, 5.5 * S))
	g.push(Vector3(1, 0, 0), 1500.0, true)
	_pasos(g, 120)
	var c: Vector2i = Terreno3D.celda_de(g.position)
	_ok("3 empujado sobre una charca helada, no se hunde: el hielo lo sostiene", not g.muerto and _hundidos.is_empty())
	_ok("3 y acaba encima del hielo", COL_HIELO.has(c.x) and Terreno3D.helada(c), str(c))
	_quitar(g)


func _hielo_derretido() -> void:
	_hundidos.clear()
	var c := Vector2i(COL_HIELO[1], 7)
	var g := _nuevo("guerrero", Terreno3D.centro_de(c, Terreno3D.y_pies(c)))
	_pasos(g, 10)
	_ok("3b de pie sobre el hielo está a salvo", not g.muerto)
	Terreno3D.poner_helada(c, false)
	_pasos(g, 5)
	_ok("3b si el hielo se derrite bajo sus pies, cae al agua honda y se hunde", g.muerto and g.se_hundio and _hundidos.size() == 1)
	await create_timer(1.5).timeout


# ---------------------------------------------------------------------------------------------------------------------
#  4. Andando por su cuenta no se mete
# ---------------------------------------------------------------------------------------------------------------------

func _sin_meterse_solo() -> void:
	# Patrulla junto a la orilla: su ida y vuelta (DISTANCIA_PATRULLA 2 u) cruzaría el agua si pudiera.
	var p := Vector3(COL_AGUA[0] * S - 0.6, Terreno3D.alto_suelo, 4.5 * S)
	var patrulla := _nuevo("guerrero", p, false)
	var gato := _nuevo("gatopedro", Vector3(COL_AGUA[0] * S - 0.1, Terreno3D.alto_suelo, 8.5 * S), false)
	var metido: bool = false
	var max_x: float = -INF
	for _i in range(900):                       # 15 s
		_pasos(patrulla, 1)
		_pasos(gato, 1)
		for e in [patrulla, gato]:
			var en_agua: bool = Terreno3D.es_agua(Terreno3D.celda_de((e as Combate3D).position))
			metido = metido or en_agua or (e as Combate3D).muerto
		max_x = maxf(max_x, patrulla.position.x)
	_ok("4 el goblin que patrulla junto al río (y el gatopedro que pasea) no se mete solo", not metido, "x máx %.2f, orilla %.2f" % [max_x, COL_AGUA[0] * S])
	_ok("4 y sí llegó a la orilla (la prueba toca el agua de verdad)", max_x > COL_AGUA[0] * S - 0.3, "x máx %.2f" % max_x)
	_quitar(patrulla)
	_quitar(gato)

	# Persigue al jugador al otro lado del río: se queda en la orilla.
	# El río mide 4,6 u de ancho y el goblin ve a 5,75 u: él en la orilla (x 13,5) y el jugador a 5,5 u, en la otra orilla (x 19,0).
	var cazador := _nuevo("guerrero", Vector3(COL_AGUA[0] * S - 0.3, Terreno3D.alto_suelo, 7.5 * S), false)
	var pos_jugador := _jugador.position
	_jugador.position = Vector3(19.0, Terreno3D.alto_suelo, 7.5 * S)
	var metido2: bool = false
	for _i in range(600):
		_pasos(cazador, 1)
		metido2 = metido2 or Terreno3D.es_agua(Terreno3D.celda_de(cazador.position)) or cazador.muerto
	_ok("4 el goblin que persigue al jugador al otro lado del río no cruza ni se hunde", not metido2 and cazador.objetivo != null, "x %.2f estado %s" % [cazador.position.x, cazador.estado])
	_jugador.position = pos_jugador
	_quitar(cazador)
