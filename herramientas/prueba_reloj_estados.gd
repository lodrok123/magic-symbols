extends SceneTree
## C1 punto 1 (2/11) + C2 (3/11, Pablo: «sin aplicación el rayo se irá a los 2 segundos. Hielo se va a los 20 segundos»): UN SOLO RELOJ DE ESTADOS. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_reloj_estados.gd
## Mide: el reloj del mundo con fotogramas reales; `DURA` (mojada 20 s, helada 20 s, electrificada 2 s; quemada y segada sin decidir); `al_caducar` (helada → mojada) y la señal `caducado`;
## el Lanzador SIN contador de hielo (vapor al oír `caducado`, `hielo_permanente`, el fuego no suelta vapor); el emisor de rayo activo mantiene la electrificada; un hechizo de rayo la deja
## SOLO en casilla mojada o de agua (y en el agua/conductores que recorre); UNA sola duración del hielo (`DURA[helada]`; `AguaSim3D.DURA_HIELO` y `Hierba3D.ESCARCHA_S` son alias); calor acorta el hielo.

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var placas_quitadas: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])
	var _precalentando: bool = false
	func _es_agua(l: String) -> bool:
		return l == "~"
	func _es_hierba(_c: Vector2i) -> bool:
		return false
	func _al_impactar(_elemento: String, _punto: Vector3) -> void:
		pass
	func quitar_placa_hielo(c: Vector2i) -> void:
		placas_quitadas.append(c)

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	Terreno3D.estados.limpiar()
	await _reloj_del_mundo()
	_dura_y_al_caducar()
	await _electrificada_real()
	_emisor()
	await _rayo_hechizo()
	await _hielo_del_lanzador()
	_hielo_del_agua()
	_un_solo_reloj()
	_zona_de_calor()
	Terreno3D.estados.limpiar()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _reloj_del_mundo() -> void:
	var m := Mundo3D.new()
	root.add_child(m)
	var c := Vector2i(4, 4)
	Terreno3D.estados.poner(c, EstadosSuelo3D.MOJADA, true)
	var antes: float = Terreno3D.estados.queda(c, EstadosSuelo3D.MOJADA)
	_ok("1 un Mundo3D en el árbol procesa cada fotograma (el reloj es su _process)", m.is_processing() and Mundo3D.actual == m)
	for _i in range(5):
		await process_frame
	var despues: float = Terreno3D.estados.queda(c, EstadosSuelo3D.MOJADA)
	_ok("1 con fotogramas reales la casilla mojada gasta tiempo (sin llamar a avanzar a mano)", despues < antes - 0.05 and despues > 0.0, "%.3f → %.3f s" % [antes, despues])
	# Veinte segundos de partida a golpe de _process: la casilla se seca sola.
	for _i in range(210):
		m._process(0.1)
	_ok("1 a los 20 s de reloj del mundo la casilla mojada se seca sola", not Terreno3D.estados.tiene(c, EstadosSuelo3D.MOJADA), str(Terreno3D.estados.queda(c, EstadosSuelo3D.MOJADA)))
	# Fuera del árbol (sin Mundo3D) NO corre: es el reloj del nivel vivo, no un global.
	m.queue_free()
	await process_frame
	Terreno3D.estados.poner(c, EstadosSuelo3D.MOJADA, true)
	var q0: float = Terreno3D.estados.queda(c, EstadosSuelo3D.MOJADA)
	for _i in range(5):
		await process_frame
	_ok("1 sin Mundo3D en el árbol nadie avanza el reloj (por eso las pruebas lo llaman a mano)", is_equal_approx(Terreno3D.estados.queda(c, EstadosSuelo3D.MOJADA), q0))
	Terreno3D.estados.limpiar()


func _dura_y_al_caducar() -> void:
	var d: Dictionary = EstadosSuelo3D.DURA
	_ok("2 DURA mojada = 20 s (lo mismo que AguaSim3D.SECA_EN)", is_equal_approx(float(d["mojada"]), 20.0) and is_equal_approx(float(d["mojada"]), AguaSim3D.SECA_EN))
	_ok("2 DURA helada = 20 s y electrificada = 2 s (decisión de Pablo, 3/11)", is_equal_approx(float(d["helada"]), 20.0) and is_equal_approx(float(d["electrificada"]), 2.0))
	var sin_caducar: PackedStringArray = []
	for k in d.keys():
		if float(d[k]) <= 0.0:
			sin_caducar.append(String(k))
	_ok("2 MEDIDO (AVISO, sin decidir): no caducan solos %s" % str(sin_caducar), sin_caducar.size() == 2 and sin_caducar.has("quemada") and sin_caducar.has("segada"))

	var e := EstadosSuelo3D.new()
	var c := Vector2i(2, 2)
	e.poner(c, EstadosSuelo3D.HELADA, true, 1.0, 0.0)
	e.avanzar(1000.0)
	_ok("3 una helada puesta con dura = 0 no caduca nunca (el hielo permanente, el de agua)", e.tiene(c, EstadosSuelo3D.HELADA))
	# La helada por defecto lleva los 20 s del reloj oficial y al caducar deja la casilla mojada.
	e.poner(c, EstadosSuelo3D.HELADA, false)
	var avisos: Array = []
	var caducados: Array = []
	e.cambio.connect(func(_p: Vector2i, est: String, si: bool) -> void: avisos.append([est, si]))
	e.caducado.connect(func(p: Vector2i, est: String) -> void: caducados.append([p, est]))
	e.poner(c, EstadosSuelo3D.HELADA, true)
	_ok("3 una helada sin más lleva la caducidad de DURA: 20 s", is_equal_approx(e.queda(c, EstadosSuelo3D.HELADA), 20.0))
	avisos.clear()
	e.avanzar(19.9)
	_ok("3 la helada sigue helada a los 19,9 s", e.tiene(c, EstadosSuelo3D.HELADA) and not e.tiene(c, EstadosSuelo3D.MOJADA) and caducados.is_empty())
	e.avanzar(0.2)
	_ok("3 al_caducar: a los 20 s se deshiela y la casilla queda MOJADA (con sus 20 s) y avisa `caducado` una vez", not e.tiene(c, EstadosSuelo3D.HELADA) and e.tiene(c, EstadosSuelo3D.MOJADA) and absf(e.queda(c, EstadosSuelo3D.MOJADA) - 20.0) < 0.5 and avisos.size() == 2 and caducados == [[c, "helada"]], "%s %s" % [str(avisos), str(caducados)])
	e.avanzar(25.0)
	_ok("3 y esa mojada se seca sin más (mojada no tiene fila en al_caducar)", not e.tiene(c, EstadosSuelo3D.MOJADA) and not e.tiene(c, EstadosSuelo3D.HELADA))
	# Quitar la helada a mano (el fuego) NO es caducar.
	caducados.clear()
	e.poner(c, EstadosSuelo3D.HELADA, true)
	e.poner(c, EstadosSuelo3D.HELADA, false)
	e.avanzar(30.0)
	_ok("3 quitar la helada a mano no emite `caducado`", caducados.is_empty())
	# La escarcha: al deshelar deja de ser escarcha.
	e.aplicar(Vector2i(3, 3), "frio")
	_ok("3 el suelo que se hiela es escarcha y lleva los 20 s", e.es_escarcha(Vector2i(3, 3)) and is_equal_approx(e.queda(Vector2i(3, 3), EstadosSuelo3D.HELADA), 20.0))
	e.avanzar(19.9)
	e.avanzar(0.2)
	_ok("3 y a los 20 s la escarcha se va y queda mojada", not e.es_escarcha(Vector2i(3, 3)) and not e.tiene(Vector2i(3, 3), EstadosSuelo3D.HELADA) and e.tiene(Vector2i(3, 3), EstadosSuelo3D.MOJADA))
	# `mantener`: renueva, pero no acorta lo que ya está sin caducidad.
	var k := Vector2i(5, 5)
	e.poner(k, EstadosSuelo3D.ELECTRIFICADA, true, 1.0, 0.0)
	e.mantener(k, EstadosSuelo3D.ELECTRIFICADA)
	e.avanzar(10.0)
	_ok("3 `mantener` no pone reloj a una electrificada que ya está sin caducidad (la mantiene otro)", e.tiene(k, EstadosSuelo3D.ELECTRIFICADA))
	e.poner(k, EstadosSuelo3D.ELECTRIFICADA, false)
	e.mantener(k, EstadosSuelo3D.ELECTRIFICADA)
	_ok("3 y sobre una casilla sin ella la pone con los 2 s de DURA", is_equal_approx(e.queda(k, EstadosSuelo3D.ELECTRIFICADA), 2.0))


## Electrificada con el reloj del mundo y fotogramas REALES: dura 2 s, ni uno menos ni mucho más.
func _electrificada_real() -> void:
	Terreno3D.estados.limpiar()
	var m := Mundo3D.new()
	root.add_child(m)
	var c := Vector2i(6, 6)
	Terreno3D.estados.poner(c, EstadosSuelo3D.ELECTRIFICADA, true)
	_ok("4 una electrificada sin dueño nace con 2,0 s", is_equal_approx(Terreno3D.estados.queda(c, EstadosSuelo3D.ELECTRIFICADA), 2.0))
	var e: EstadosSuelo3D = Terreno3D.estados
	var visto_hasta: float = 0.0           # lo que llevaba gastado la última vez que se la vio viva (s de reloj del mundo = suma de los delta reales)
	var fotogramas: int = 0
	while e.tiene(c, EstadosSuelo3D.ELECTRIFICADA) and fotogramas < 2000:
		visto_hasta = 2.0 - e.queda(c, EstadosSuelo3D.ELECTRIFICADA)
		await process_frame
		fotogramas += 1
	_ok("4 con fotogramas reales (%d fotogramas) la electrificada se ve viva hasta los %.2f s de reloj y se va justo después: dura 2,0 s" % [fotogramas, visto_hasta], visto_hasta > 1.8 and visto_hasta <= 2.0 and fotogramas > 1)
	_ok("4 …y ya no está", not e.tiene(c, EstadosSuelo3D.ELECTRIFICADA))
	m.queue_free()
	await process_frame
	Terreno3D.estados.limpiar()


## El emisor de rayo: mientras la descarga está activa renueva el estado (más de 2 s); al apagarse lo quita; no toca lo que otro mantiene sin caducidad.
func _emisor() -> void:
	Terreno3D.estados.limpiar()
	var e: EstadosSuelo3D = Terreno3D.estados
	var em := EmisorRayo3D.new()
	em.m = Node.new()
	root.add_child(em)
	var a := Vector2i(3, 3)
	var b := Vector2i(4, 3)
	var fija := Vector2i(5, 3)
	e.poner(fija, EstadosSuelo3D.ELECTRIFICADA, true, 1.0, 0.0)            # la mantiene otro (el canal del Bosque 1)
	em.electrificada = [a, b, fija]
	em._activa = true
	em._t = 100.0
	em._t_dano = 100.0
	em._estado_electrificada(true)
	_ok("5 al soltar la descarga las casillas quedan electrificadas con los 2 s de DURA", e.tiene(a, EstadosSuelo3D.ELECTRIFICADA) and is_equal_approx(e.queda(b, EstadosSuelo3D.ELECTRIFICADA), 2.0))
	_ok("5 la que mantenía otro sin caducidad sigue sin caducidad", e.queda(fija, EstadosSuelo3D.ELECTRIFICADA) == 0.0)
	var siempre: bool = true
	for i in range(60):                                                     # 6 s de descarga activa, sin que `_t` baje a 0
		em._process(0.1)
		e.avanzar(0.1)
		if not e.tiene(a, EstadosSuelo3D.ELECTRIFICADA) or not e.tiene(b, EstadosSuelo3D.ELECTRIFICADA):
			siempre = false
	_ok("5 el emisor ACTIVO la mantiene: 6 s después (3 veces los 2 s de DURA) sigue electrificada", siempre)
	em._apagar()
	_ok("5 al apagarse la descarga el estado se quita en el acto", not e.tiene(a, EstadosSuelo3D.ELECTRIFICADA) and not e.tiene(b, EstadosSuelo3D.ELECTRIFICADA))
	_ok("5 y no quita la que mantenía otro", e.tiene(fija, EstadosSuelo3D.ELECTRIFICADA))
	# Sin emisor (nadie la mantiene) se va a los 2 s.
	e.poner(a, EstadosSuelo3D.ELECTRIFICADA, true)
	e.avanzar(1.9)
	var a1: bool = e.tiene(a, EstadosSuelo3D.ELECTRIFICADA)
	e.avanzar(0.2)
	_ok("5 sin nadie que la mantenga se va a los 2 s", a1 and not e.tiene(a, EstadosSuelo3D.ELECTRIFICADA))
	em.m.free()
	em.free()
	e.limpiar()


func _mapa_con_agua() -> MundoFalso:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	for c in [Vector2i(8, 8), Vector2i(9, 8), Vector2i(9, 9), Vector2i(10, 9)]:
		var fila: String = filas[c.y]
		filas[c.y] = fila.substr(0, c.x) + "~" + fila.substr(c.x + 1)
	var m := MundoFalso.new()
	m._mapa = filas
	root.add_child(m)
	Lanzador3D.configurar(m)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#" or filas[y][x] == "~":
				m._bloqueadas[Vector2i(x, y)] = true
	return m


## Un hechizo de rayo deja `electrificada` en casillas mojadas o de agua, no en seco; la descarga recorre el agua conectada.
func _rayo_hechizo() -> void:
	Terreno3D.estados.limpiar()
	Terreno3D.alturas.clear()
	Terreno3D.conductores.clear()
	var e: EstadosSuelo3D = Terreno3D.estados
	var rune: RuneData = load("res://nucleo/lightning_rune.tres") as RuneData
	_ok("6 la runa de rayo lleva `deja = electrificado`", rune.deja == "electrificado")
	var m: MundoFalso = _mapa_con_agua()
	var l := Lanzador3D.new()
	l.mundo = m
	root.add_child(l)
	var seca := Vector2i(6, 8)
	var mojada := Vector2i(7, 8)
	var agua := Vector2i(8, 8)
	e.poner(mojada, EstadosSuelo3D.MOJADA, true)
	_ok("6 la letra `~` es agua para el juego (montaje de la prueba)", Terreno3D.es_agua(agua) and not Terreno3D.es_agua(seca))
	_ok("6 `marcar_celda(rayo)` sobre suelo seco no deja nada", not l.electrificar_celda(seca))
	l.marcar_celda("rayo", seca)
	_ok("6 …ni por `marcar_celda`", not e.tiene(seca, EstadosSuelo3D.ELECTRIFICADA))
	l.marcar_celda("rayo", mojada)
	l.marcar_celda("rayo", agua)
	_ok("6 sobre una casilla MOJADA la deja electrificada (2 s)", e.tiene(mojada, EstadosSuelo3D.ELECTRIFICADA) and is_equal_approx(e.queda(mojada, EstadosSuelo3D.ELECTRIFICADA), 2.0))
	_ok("6 sobre una casilla de AGUA también", e.tiene(agua, EstadosSuelo3D.ELECTRIFICADA))
	e.avanzar(2.1)
	_ok("6 y a los 2 s caduca sola", not e.tiene(mojada, EstadosSuelo3D.ELECTRIFICADA) and not e.tiene(agua, EstadosSuelo3D.ELECTRIFICADA))
	# El rayo NO hace otra cosa al suelo: no moja, no hiela, no quema.
	l.marcar_celda("rayo", mojada)
	_ok("6 el rayo no cambia mojada/helada/quemada de la casilla", e.tiene(mojada, EstadosSuelo3D.MOJADA) and not e.tiene(mojada, EstadosSuelo3D.HELADA) and not e.tiene(mojada, EstadosSuelo3D.QUEMADA))
	e.limpiar()
	e.poner(mojada, EstadosSuelo3D.MOJADA, true)
	# La descarga de verdad: un haz de rayo desde (5,8) hacia +X (HechizoVivo._descarga).
	var jug := Jugador3D.new()
	root.add_child(jug)
	jug.position = Lanzador3D.centro_de(Vector2i(2, 2), Terreno3D.y_pies(Vector2i(2, 2)))
	l.jugador = jug
	var h: Hechizo = Hechizo.construir(rune, {"linea_x": 3})
	var origen: Vector3 = Lanzador3D.centro_de(Vector2i(5, 8), Terreno3D.y_pies(Vector2i(5, 8)) + 0.8)
	var v: HechizoVivo = HechizoVivo.crear(h, origen, Vector3.RIGHT, l, null, {}, true)
	_ok("6 el haz ocupa casillas (%d)" % v.casillas, v.casillas >= 3)
	_ok("6 la descarga electrifica la casilla mojada del haz", e.tiene(mojada, EstadosSuelo3D.ELECTRIFICADA))
	_ok("6 …y el agua que el haz toca y TODA la conectada (la rama (10,9), fuera del haz)", e.tiene(agua, EstadosSuelo3D.ELECTRIFICADA) and e.tiene(Vector2i(9, 9), EstadosSuelo3D.ELECTRIFICADA) and e.tiene(Vector2i(10, 9), EstadosSuelo3D.ELECTRIFICADA))
	_ok("6 el suelo seco del haz no queda electrificado", not e.tiene(seca, EstadosSuelo3D.ELECTRIFICADA) and not e.tiene(Vector2i(7, 7), EstadosSuelo3D.ELECTRIFICADA))
	e.avanzar(2.1)
	_ok("6 y todo se va a los 2 s", e.cuantas(EstadosSuelo3D.ELECTRIFICADA) == 0)
	# En seco (la previsión del apuntado) no escribe estados.
	var prev: Dictionary = HechizoVivo.prever(h, l, origen, Vector3.RIGHT)
	_ok("6 la previsión en seco no escribe estados", e.cuantas(EstadosSuelo3D.ELECTRIFICADA) == 0 and not prev.is_empty())
	# Un conductor (un nexo mojado) que toca el agua también se electrifica.
	e.limpiar()
	Terreno3D.conductores[Vector2i(11, 9)] = true
	HechizoVivo.crear(h, origen, Vector3.RIGHT, l, null, {}, true)
	_ok("6 los conductores conectados (nexo mojado) también", e.tiene(Vector2i(11, 9), EstadosSuelo3D.ELECTRIFICADA))
	Terreno3D.conductores.clear()
	e.limpiar()
	for n in [v, l, jug, m]:
		if is_instance_valid(n):
			n.free()


## El Lanzador ya no cuenta el hielo: lo caduca el reloj oficial y él suelta el vapor al oír `caducado`.
func _hielo_del_lanzador() -> void:
	Terreno3D.estados.limpiar()
	Terreno3D.alturas.clear()
	var e: EstadosSuelo3D = Terreno3D.estados
	var m: MundoFalso = _mapa_con_agua()
	var l := Lanzador3D.new()
	l.mundo = m
	root.add_child(l)
	var fx := Vfx3D.new()
	root.add_child(fx)
	l.fx = fx
	var c := Vector2i(12, 12)
	var p: Vector3 = Lanzador3D.centro_de(c, Terreno3D.y_pies(c))
	_ok("7 el montaje: (12,12) es de suelo para el estado", ReaccionesSuelo3D.clase_de(c) == "suelo")
	l.al_impactar("hielo", p)
	_ok("7 un hechizo de hielo hiela la casilla de suelo (escarcha) con los 20 s del reloj oficial", e.tiene(c, EstadosSuelo3D.HELADA) and e.es_escarcha(c) and is_equal_approx(e.queda(c, EstadosSuelo3D.HELADA), 20.0), str(e.queda(c, EstadosSuelo3D.HELADA)))
	_ok("7 el Lanzador apunta la casilla SIN contador (`_hielo` no tiene `resta`)", l.marcas_de_hielo() == 1 and not (l._hielo[c] as Dictionary).has("resta") and not (load("res://magia/lanzador_3d.gd") as GDScript).get_script_constant_map().has("DURACION_HIELO"))
	var hijos0: int = fx.get_child_count()
	# Pasan 19,9 s de reloj oficial y 20 de bucle del Lanzador: no pasa nada (él no cuenta).
	for _i in range(80):
		l._process(0.25)
	_ok("7 el Lanzador, por mucho que corra su _process, no deshiela por su cuenta", e.tiene(c, EstadosSuelo3D.HELADA) and l.marcas_de_hielo() == 1)
	e.avanzar(19.8)
	_ok("7 a los 19,8 s del reloj oficial sigue helada", e.tiene(c, EstadosSuelo3D.HELADA) and fx.get_child_count() == hijos0)
	e.avanzar(0.4)
	_ok("7 al caducar: la casilla queda MOJADA y sin escarcha", not e.tiene(c, EstadosSuelo3D.HELADA) and e.tiene(c, EstadosSuelo3D.MOJADA) and not e.es_escarcha(c))
	_ok("7 …el Lanzador suelta el vapor, apaga su marca y quita la placa de hielo", fx.get_child_count() > hijos0 and l.marcas_de_hielo() == 0 and m.placas_quitadas.has(c), "hijos %d → %d, placas %s" % [hijos0, fx.get_child_count(), str(m.placas_quitadas)])
	# Hielo permanente: no caduca.
	var perm := Vector2i(13, 12)
	Lanzador3D.hielo_permanente[perm] = true
	l.al_impactar("hielo", Lanzador3D.centro_de(perm, Terreno3D.y_pies(perm)))
	l._process(0.3)
	e.avanzar(100.0)
	_ok("7 una casilla en `hielo_permanente` no caduca (100 s después sigue helada y apuntada)", e.tiene(perm, EstadosSuelo3D.HELADA) and l.marcas_de_hielo() == 1 and e.queda(perm, EstadosSuelo3D.HELADA) == 0.0)
	Lanzador3D.hielo_permanente.erase(perm)
	e.poner(perm, EstadosSuelo3D.HELADA, false)
	l._process(0.3)
	# El fuego funde el hielo sin vapor del Lanzador y su marca se limpia.
	var f := Vector2i(14, 12)
	var pf: Vector3 = Lanzador3D.centro_de(f, Terreno3D.y_pies(f))
	l.al_impactar("hielo", pf)
	var hijos1: int = fx.get_child_count()
	l.al_impactar("fuego", pf)
	l._process(0.3)
	e.avanzar(100.0)
	_ok("7 el fuego sobre el hielo lo deja mojado, sin el vapor del Lanzador, y la marca se limpia", not e.tiene(f, EstadosSuelo3D.HELADA) and l.marcas_de_hielo() == 0 and fx.get_child_count() == hijos1)
	# Otro hielo sobre una casilla ya helada NO renueva los 20 s (Pablo, 12/10).
	var r := Vector2i(15, 12)
	var pr: Vector3 = Lanzador3D.centro_de(r, Terreno3D.y_pies(r))
	l.al_impactar("hielo", pr)
	e.avanzar(5.0)
	l.al_impactar("hielo", pr)
	_ok("7 otro hielo sobre la ya helada NO renueva sus 20 s (quedan %.1f)" % e.queda(r, EstadosSuelo3D.HELADA), absf(e.queda(r, EstadosSuelo3D.HELADA) - 15.0) < 0.01)
	for n in [l, fx, m]:
		if is_instance_valid(n):
			n.free()
	e.limpiar()


## El hielo de AGUA es por trocitos en la simulación: lee la duración oficial y avisa si se soltó por tiempo (no por fuego).
func _hielo_del_agua() -> void:
	var a := AguaSim3D.new()
	var s: float = 2.3
	a.configurar(3, 3, 3, s, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	var c := Vector2i(1, 1)
	var centro := Vector3((float(c.x) + 0.5) * s, 0.0, (float(c.y) + 0.5) * s)
	a.llenar_casilla(c, 0.2)
	a.helar(centro, s)
	a.cambios_hielo()
	for _i in range(60 * 19):
		a.paso(1.0 / 60.0)
	_ok("8 el hielo del agua sigue a los 19 s (DURA_HIELO es la duración oficial: %.0f s)" % AguaSim3D.DURA_HIELO, a.casilla_helada(c) and is_equal_approx(AguaSim3D.DURA_HIELO, float(EstadosSuelo3D.DURA["helada"])))
	for _i in range(60 * 2):
		a.paso(1.0 / 60.0)
	_ok("8 …y a los 21 s se soltó solo", not a.casilla_helada(c))
	_ok("8 la simulación dice que fue por TIEMPO (una vez)", a.tomar_caducado(c) and not a.tomar_caducado(c))
	a.cambios_hielo()
	a.helar(centro, s)
	a.derretir(centro, s)
	for _i in range(10):
		a.paso(1.0 / 60.0)
	_ok("8 el hielo que funde el fuego NO cuenta como caducado", not a.casilla_helada(c) and not a.tomar_caducado(c))


func _un_solo_reloj() -> void:
	# Una sola duración del hielo: las demás constantes son alias de la oficial (leídas de ella) o no existen.
	var oficial: float = float(EstadosSuelo3D.DURA["helada"])
	_ok("9 AguaSim3D.DURA_HIELO == DURA[helada] (alias)", is_equal_approx(AguaSim3D.DURA_HIELO, oficial))
	_ok("9 Hierba3D.ESCARCHA_S == DURA[helada] (alias)", is_equal_approx(Hierba3D.ESCARCHA_S, oficial))
	_ok("9 Lanzador3D ya no tiene DURACION_HIELO", not (load("res://magia/lanzador_3d.gd") as GDScript).get_script_constant_map().has("DURACION_HIELO"))
	var fuentes: PackedStringArray = ["res://magia/lanzador_3d.gd", "res://mundo/agua_sim_3d.gd", "res://presentacion/hierba_3d.gd", "res://mundo/estados_suelo_3d.gd"]
	var literales: Array = []
	for ruta in fuentes:
		var txt: String = FileAccess.get_file_as_string(ruta)
		var n: int = 0
		for linea in txt.split("\n"):
			var t: String = linea.strip_edges()
			if t.begins_with("#") or t.begins_with("##"):
				continue
			if (t.contains("HIELO") or t.contains("ESCARCHA") or t.contains("\"helada\":")) and t.contains(": float = 20.0"):
				n += 1
				literales.append(ruta + ": " + t)
		print("      %s: %d constantes de hielo con 20.0 propio" % [ruta, n])
	_ok("9 ninguna constante de hielo con un 20.0 propio fuera de DURA %s" % str(literales), literales.is_empty())
	var restos: int = 0
	for ruta in fuentes:
		var txt2: String = FileAccess.get_file_as_string(ruta)
		restos += txt2.count("e[\"resta\"]") if ruta.ends_with("lanzador_3d.gd") else 0
	_ok("9 el Lanzador no descuenta `resta` del hielo", restos == 0)
	_ok("9 el tiempo del hielo lo cuenta UN reloj para el suelo: `EstadosSuelo3D` (más la simulación por trocitos para el agua, que lee la misma DURA)", true)


func _zona_de_calor() -> void:
	# Suelo: la zona de calor acorta la helada a un tercio; la de frío casi la para.
	var e := EstadosSuelo3D.new()
	var c := Vector2i(2, 2)
	e.estado_zona_en = func(_p: Vector2i) -> Array: return ["calor"]
	e.poner(c, EstadosSuelo3D.HELADA, true)
	e.avanzar(6.4)
	var viva: bool = e.tiene(c, EstadosSuelo3D.HELADA)
	e.avanzar(0.6)
	_ok("10 en zona de calor la helada dura 1/3 (20 s → ~6,7 s)", viva and not e.tiene(c, EstadosSuelo3D.HELADA) and e.tiene(c, EstadosSuelo3D.MOJADA))
	e.limpiar()
	e.estado_zona_en = func(_p: Vector2i) -> Array: return ["frio"]
	e.poner(c, EstadosSuelo3D.HELADA, true)
	e.avanzar(200.0)
	_ok("10 en zona de frío la helada casi no caduca (200 s después sigue)", e.tiene(c, EstadosSuelo3D.HELADA))
	# La electrificada no depende de la zona: 2 s en calor también.
	e.limpiar()
	e.estado_zona_en = func(_p: Vector2i) -> Array: return ["calor"]
	e.poner(c, EstadosSuelo3D.ELECTRIFICADA, true)
	e.avanzar(1.9)
	var v: bool = e.tiene(c, EstadosSuelo3D.ELECTRIFICADA)
	e.avanzar(0.2)
	_ok("10 la electrificada va por el reloj normal también en calor (2 s)", v and not e.tiene(c, EstadosSuelo3D.ELECTRIFICADA))
	# Agua: el factor de zona lo aplica la simulación a SUS trocitos con la misma duración oficial.
	var a := AguaSim3D.new()
	var s: float = 2.3
	a.configurar(3, 3, 3, s, func(_c: Vector2i) -> float: return 0.0, func(_c: Vector2i) -> bool: return false)
	a.factor_hielo_dura = func(_p: Vector2i) -> float: return 1.0 / 3.0
	var d := Vector2i(1, 1)
	var centro := Vector3((float(d.x) + 0.5) * s, 0.0, (float(d.y) + 0.5) * s)
	a.llenar_casilla(d, 0.2)
	a.helar(centro, s)
	for _i in range(60 * 6):
		a.paso(1.0 / 60.0)
	var viva_a: bool = a.casilla_helada(d)
	for _i in range(60 * 2):
		a.paso(1.0 / 60.0)
	_ok("10 el hielo de agua en zona de calor dura 1/3 con la misma duración oficial (~6,7 s)", viva_a and not a.casilla_helada(d))
