extends SceneTree
## La tinta (15/10, Juego): costes por forma, no gastar a medias, regeneración con espera y más lenta en combate, estados y pigmentos.
##   godot --headless --path . --script res://herramientas/prueba_tinta.gd

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _avanza(t: Tinta, s: float, combate: bool) -> void:
	for _i in range(int(round(s * 60.0))):
		t.actualizar(1.0 / 60.0, combate)


func _initialize() -> void:
	var t := Tinta.new()
	t.partida = Estado.new()          # E1: la prueba no depende del Estado global
	_ok("1 empieza llena (100)", is_equal_approx(t.actual, 100.0) and t.estado() == "normal")
	_ok("2 costes: flecha 10, barrera 25, círculo 35", Tinta.coste_de("proyectil") == 10.0 and Tinta.coste_de("corro") == 25.0 and Tinta.coste_de("onda") == 35.0)
	_ok("3 una forma sin tabla cuesta el defecto", Tinta.coste_de("inventada") == Tinta.COSTE_DEFECTO)
	_ok("4 gastar una flecha deja 90", t.gastar("proyectil") and is_equal_approx(t.actual, 90.0))
	_avanza(t, Tinta.ESPERA_TRAS_GASTAR - 0.2, false)
	_ok("5 durante la espera no recupera", is_equal_approx(t.actual, 90.0), "%.2f" % t.actual)
	_avanza(t, 0.2 + 1.0, false)
	_ok("6 pasada la espera recupera ~REGEN por segundo", absf(t.actual - (90.0 + Tinta.REGEN)) < 0.1, "%.2f" % t.actual)
	var u := Tinta.new()
	u.actual = 20.0
	u.frascos = 0                     # 24/10: con frasco de reserva un gasto que no llega lo rellena (ver prueba_hud_eow); estas comprobaciones miden la barra SIN reserva
	var avisos: Array = []
	u.insuficiente.connect(func(f: String, c: float, h: float) -> void: avisos.append([f, c, h]))
	_ok("7 sin tinta bastante NO gasta nada y avisa", not u.gastar("corro") and is_equal_approx(u.actual, 20.0) and avisos.size() == 1)
	_ok("7b puede_pagar coincide", not u.puede_pagar("corro") and u.puede_pagar("proyectil"))
	_ok("8 por debajo del 25 % es 'baja'", u.estado() == "baja")
	u.actual = 0.0
	_ok("9 con 0 es 'sin_tinta'", u.estado() == "sin_tinta")
	var a := Tinta.new()
	var b := Tinta.new()
	a.actual = 10.0
	b.actual = 10.0
	_avanza(a, 3.0, false)
	_avanza(b, 3.0, true)
	_ok("10 en combate recupera menos (1/3)", (b.actual - 10.0) < (a.actual - 10.0) * 0.5, "fuera %.2f · combate %.2f" % [a.actual - 10.0, b.actual - 10.0])
	_avanza(a, 120.0, false)
	_ok("11 nunca pasa del máximo", is_equal_approx(a.actual, 100.0) and a.estado() == "normal")
	_ok("12 pigmento base azul y sin zona", t.pigmento == "azul_arcano" and Tinta.pigmento_de_zona("") == "azul_arcano")
	_ok("13 el bosque da Resina Carmesí", Tinta.pigmento_de_zona("bosque") == "resina_carmesi")
	var c0: Color = t.color()
	t.poner_pigmento("verde_musgo")
	_ok("14 cambiar de pigmento cambia el color de la barra", not t.color().is_equal_approx(c0) and t.nombre_pigmento() == "Verde de Musgo")
	_ok("15 un pigmento que no existe se rechaza", not t.poner_pigmento("nada") and t.pigmento == "verde_musgo")
	var vistos: Dictionary = {}
	for _i in range(Tinta.PIGMENTOS.size()):
		vistos[t.siguiente_pigmento()] = true
	_ok("16 siguiente_pigmento recorre los cinco y vuelve", vistos.size() == Tinta.PIGMENTOS.size())
	await process_frame
	_e1_maxima()
	_e1_pigmentos()
	_e1_dano()
	print("FALLOS: %d" % _fallos)
	quit(_fallos)


## E1: máximo inicial 100, jefes y secretos suman lo suyo, tope 300, reparto 60/40. Con un Estado propio (no ensucia el de la partida).
func _e1_maxima() -> void:
	var e := Estado.new()
	var t := Tinta.new()
	t.partida = e
	t.maxima = t.maxima_calculada()
	t.actual = t.maxima
	_ok("E1.1 se empieza con 100 de máximo y la barra llena", is_equal_approx(t.maxima, 100.0) and is_equal_approx(t.actual, 100.0))
	_ok("E1.2 lo ganable es 200 y el reparto es 60/40 (120 jefes · 80 secretos)", is_equal_approx(Tinta.por_jefe() * Tinta.JEFES, 120.0) and is_equal_approx(Tinta.por_secreto() * Tinta.SECRETOS, 80.0) \
		and is_equal_approx(Tinta.MAXIMA_INICIAL + Tinta.por_jefe() * Tinta.JEFES + Tinta.por_secreto() * Tinta.SECRETOS, Tinta.MAXIMA_TOTAL) and is_equal_approx(Tinta.REPARTO_JEFES + Tinta.REPARTO_SECRETOS, 1.0))
	_ok("E1.3 cada jefe suma 30 (y entra en la barra)", t.ganar_jefe() and is_equal_approx(t.maxima, 130.0) and is_equal_approx(t.actual, 130.0) and e.nivel("tinta_jefe") == 1)
	_ok("E1.4 cada secreto suma 10", t.ganar_secreto() and is_equal_approx(t.maxima, 140.0) and e.nivel("tinta_secreto") == 1)
	var avisos: Array = [0]
	t.cambiada.connect(func() -> void: avisos[0] += 1)
	t.ganar_jefe()
	_ok("E1.5 ganar avisa para repintar", avisos[0] >= 1)
	for _i in range(20):
		t.ganar_jefe()
		t.ganar_secreto()
	_ok("E1.6 con todos los jefes y secretos el máximo es 300 y no pasa", is_equal_approx(t.maxima, 300.0) and e.nivel("tinta_jefe") == Tinta.JEFES and e.nivel("tinta_secreto") == Tinta.SECRETOS, "%.1f" % t.maxima)
	_ok("E1.7 ya no se puede ganar más (devuelve false)", not t.ganar_jefe() and not t.ganar_secreto())
	var tr := Tinta.new()
	tr.partida = e
	_ok("E1.8 una Tinta nueva (reaparecer, otra sala) recupera el máximo de la partida", is_equal_approx(tr.maxima_calculada(), 300.0))
	e.mejoras["tinta_jefe"] = 99
	_ok("E1.9 aunque se toquen los niveles a mano, el tope es 300", is_equal_approx(tr.maxima_calculada(), 300.0))
	var tc := Tinta.new()
	tc.partida = Estado.new()
	_ok("E1.10 las compras (oro, otras mejoras) no suben el máximo", is_equal_approx(tc.maxima_calculada(), 100.0))


## E1: pigmento = aumento temporal sobre un sello. Rebaja de coste (con suelo de 1/3), duración y vuelta al base.
func _e1_pigmentos() -> void:
	var t := Tinta.new()
	t.partida = Estado.new()
	_ok("E1.11 sin pigmento el coste de cualquier elemento es el de partida", is_equal_approx(t.coste_efectivo(20.0, "tierra"), 20.0) and is_equal_approx(t.coste_efectivo(20.0), 20.0))
	t.activar_pigmento("ocre_tumulo")
	_ok("E1.12 rebaja de tierra: su coste baja a la mitad", is_equal_approx(t.coste_efectivo(20.0, "tierra"), 10.0), "%.2f" % t.coste_efectivo(20.0, "tierra"))
	_ok("E1.13 el coste de OTRO elemento no cambia", is_equal_approx(t.coste_efectivo(20.0, "fuego"), 20.0) and is_equal_approx(t.coste_efectivo(20.0, "agua"), 20.0))
	_ok("E1.14 gastar de verdad cobra el rebajado (y puede_pagar lo usa)", t.gastar("x", 20.0, "tierra") and is_equal_approx(t.actual, 90.0) and t.gastar("x", 20.0, "fuego") and is_equal_approx(t.actual, 70.0))
	var u := Tinta.new()
	u.partida = Estado.new()
	u.actual = 10.0
	u.frascos = 0                                        # sin reserva (24/10): se mide la barra sola
	u.activar_pigmento("ocre_tumulo")
	_ok("E1.15 con 10 de tinta paga un hechizo de 20 de tierra (cuesta 10) pero no uno de fuego", u.puede_pagar("x", 20.0, "tierra") and not u.puede_pagar("x", 20.0, "fuego"))
	_ok("E1.16 la regla del 1/3: una rebaja exagerada (×0,1) se queda en 1/3", is_equal_approx(Tinta.rebajar(30.0, 0.1), 10.0) and is_equal_approx(Tinta.rebajar(30.0, 0.0), 10.0) and is_equal_approx(Tinta.rebajar(30.0, 0.5), 15.0))
	var minimo_ok: bool = true
	for id in Tinta.PIGMENTOS:
		var p: Dictionary = Tinta.PIGMENTOS[id]
		if String(p["efecto"]) == "rebaja":
			t.activar_pigmento(String(id))
			minimo_ok = minimo_ok and t.coste_efectivo(30.0, String(p["elemento"])) >= 30.0 * Tinta.REBAJA_MINIMA - 1e-4
	_ok("E1.17 ningún pigmento real baja un coste de 1/3", minimo_ok)
	t.activar_pigmento("resina_carmesi")
	_ok("E1.18 un pigmento de DAÑO no abarata nada", is_equal_approx(t.coste_efectivo(20.0, "fuego"), 20.0))
	t.activar_pigmento("verde_musgo")
	_ok("E1.19 activar otro sustituye al anterior (viento rebaja, tierra ya no)", is_equal_approx(t.coste_efectivo(20.0, "viento"), 10.0) and is_equal_approx(t.coste_efectivo(20.0, "tierra"), 20.0))
	var fin: Array = [""]
	t.pigmento_acabado.connect(func(id: String) -> void: fin[0] = id)
	var ruido: Array = [0]
	t.cambiada.connect(func() -> void: ruido[0] += 1)
	t.activar_pigmento("ocre_tumulo")
	_avanza(t, Tinta.PIGMENTO_DURA - 1.0, true)
	_ok("E1.20 a falta de 1 s sigue activo", t.pigmento == "ocre_tumulo" and is_equal_approx(t.coste_efectivo(20.0, "tierra"), 10.0) and t.tiempo_pigmento() > 0.5, "%.2f" % t.tiempo_pigmento())
	ruido[0] = 0
	_avanza(t, 1.5, true)
	_ok("E1.21 a los %d s acaba: vuelve el azul, el coste, la señal y el repintado" % int(Tinta.PIGMENTO_DURA), t.pigmento == "azul_arcano" and is_equal_approx(t.coste_efectivo(20.0, "tierra"), 20.0) and fin[0] == "ocre_tumulo" and ruido[0] >= 1 and t.tiempo_pigmento() == 0.0)
	var v := Tinta.new()
	v.partida = Estado.new()
	v.activar_pigmento("ocre_tumulo")
	v.gastar("x", 10.0)                                  # la espera de tras gastar no congela el reloj del pigmento
	_avanza(v, 2.0, false)
	_ok("E1.22 el reloj corre aunque haya espera tras gastar", v.tiempo_pigmento() < Tinta.PIGMENTO_DURA - 1.5)
	v.activar_pigmento("azul_arcano")
	_avanza(v, 5.0, false)
	_ok("E1.23 el azul base no caduca ni avisa", v.pigmento == "azul_arcano" and v.tiempo_pigmento() == 0.0)
	var m := Tinta.new()
	m.partida = Estado.new()
	m.activar_pigmento("ocre_tumulo")
	m.rellenar()
	_ok("E1.24 todos los pigmentos de efecto tienen elemento, valor y duración", _pigmentos_bien())


func _pigmentos_bien() -> bool:
	var elementos: Array = ["fuego", "agua", "tierra", "rayo", "hielo", "viento"]
	for id in Tinta.PIGMENTOS:
		var p: Dictionary = Tinta.PIGMENTOS[id]
		if String(id) == Tinta.PIGMENTO_BASE:
			if String(p["efecto"]) != "":
				return false
			continue
		if String(p["efecto"]) == "sin_recargo":         # F3: el Azul de Eco no es de ningún sello; quita el recargo de un glifo
			if String(p.get("glifo", "")) == "" or float(p["dura"]) <= 0.0:
				return false
			continue
		if not elementos.has(String(p["elemento"])) or not ["rebaja", "dano"].has(String(p["efecto"])) or float(p["valor"]) <= 0.0 or float(p["dura"]) <= 0.0:
			return false
	return true


## E1: el daño. Camino real: `Lanzador3D._disparar` construye el Hechizo y le aplica el pigmento; ese Hechizo golpea a un goblin de verdad.
class EspiaLanzador extends Lanzador3D:
	var ultimo: Hechizo = null
	func lanzar_hechizo(h: Hechizo, _origen: Vector3, _dir: Vector3) -> int:
		ultimo = h
		return 0

class MundoFalso extends Node3D:
	var _lado: int = 20
	var _helada: Dictionary = {}
	var _bloqueadas: Dictionary = {}
	var _mapa: PackedStringArray = []
	var _goblins: Array = []
	func _letra(c: Vector2i) -> String:
		return String(_mapa[c.y][c.x])


func _e1_dano() -> void:
	var filas: PackedStringArray = []
	for y in range(20):
		var f: String = ""
		for x in range(20):
			f += "#" if (x == 0 or y == 0 or x == 19 or y == 19) else "."
		filas.append(f)
	var mundo := MundoFalso.new()
	mundo._mapa = filas
	root.add_child(mundo)
	Lanzador3D.configurar(mundo)
	for y in range(20):
		for x in range(20):
			if filas[y][x] == "#":
				mundo._bloqueadas[Vector2i(x, y)] = true
	var lanz := EspiaLanzador.new()
	var t := Tinta.new()
	t.partida = Estado.new()
	lanz.tinta = t
	var runas: Dictionary = {"fuego": "fire", "rayo": "lightning", "tierra": "earth"}
	var sin: Dictionary = {}
	for el in runas:
		sin[el] = _golpe_real(lanz, mundo, String(runas[el]), el)
	_ok("E1.25 sin pigmento los tres golpean (>0)", float(sin["fuego"][0]) > 0.0 and float(sin["rayo"][0]) > 0.0 and float(sin["tierra"][0]) > 0.0, str(sin))
	t.activar_pigmento("resina_carmesi")                  # fuego, daño ×1,5
	var f_con: Array = _golpe_real(lanz, mundo, "fire", "fuego")
	var r_con: Array = _golpe_real(lanz, mundo, "lightning", "rayo")
	var e_con: Array = _golpe_real(lanz, mundo, "earth", "tierra")
	_ok("E1.26 carmesí: el Hechizo de fuego sale con el daño ×1,5", absf(float(f_con[1]) - float(sin["fuego"][1]) * 1.5) < 0.01, "%.2f vs %.2f" % [f_con[1], sin["fuego"][1]])
	# 29/10, DANO_Y_TINTA: el pigmento multiplica el daño BASE del Hechizo (B·E) y la defensa del goblin (2) se resta DESPUÉS, así que lo que quita el golpe real ya no es «×1,5 del de antes»: es Dano.aplicar(daño del Hechizo con pigmento, R, DEF). El goblin resiste el fuego (×0,75).
	_ok("E1.27 carmesí: el golpe REAL a un goblin quita lo que dice Dano.aplicar con el daño ×1,5", absf(float(f_con[0]) - Dano.aplicar(float(f_con[1]), 1.0, 1.0, Combate3D.MULT_RESISTE, Dano.DEF_GOBLIN)) < 0.05 and float(f_con[0]) > float(sin["fuego"][0]), "%.2f vs %.2f" % [f_con[0], sin["fuego"][0]])
	_ok("E1.28 carmesí: rayo y tierra NO cambian", absf(float(r_con[0]) - float(sin["rayo"][0])) < 0.01 and absf(float(e_con[0]) - float(sin["tierra"][0])) < 0.01)
	t.activar_pigmento("ocre_tumulo")                     # rebaja: no toca el daño
	var f_reb: Array = _golpe_real(lanz, mundo, "fire", "fuego")
	var e_reb: Array = _golpe_real(lanz, mundo, "earth", "tierra")
	_ok("E1.29 un pigmento de rebaja no cambia el daño de nadie", absf(float(f_reb[0]) - float(sin["fuego"][0])) < 0.01 and absf(float(e_reb[0]) - float(sin["tierra"][0])) < 0.01)
	t.activar_pigmento("ambar_volcanico")                 # rayo ×1,5
	var r_amb: Array = _golpe_real(lanz, mundo, "lightning", "rayo")
	var f_amb: Array = _golpe_real(lanz, mundo, "fire", "fuego")
	_ok("E1.30 ámbar: rayo ×1,5 (en el daño del Hechizo; la defensa se resta después, 29/10) y el fuego vuelve a lo normal", absf(float(r_amb[0]) - Dano.aplicar(float(r_amb[1]), 1.0, 1.0, 1.0, Dano.DEF_GOBLIN)) < 0.05 and absf(float(r_amb[1]) - float(sin["rayo"][1]) * 1.5) < 0.01 and absf(float(f_amb[0]) - float(sin["fuego"][0])) < 0.01, "%.2f vs %.2f" % [r_amb[0], sin["rayo"][0]])
	_avanza(t, Tinta.PIGMENTO_DURA + 1.0, false)
	var r_fin: Array = _golpe_real(lanz, mundo, "lightning", "rayo")
	_ok("E1.31 al acabar el pigmento, el daño vuelve al base", absf(float(r_fin[0]) - float(sin["rayo"][0])) < 0.01)
	lanz.tinta = null
	var r_nul: Array = _golpe_real(lanz, mundo, "lightning", "rayo")
	_ok("E1.32 sin tinta (laboratorios, pruebas) no hay bonus ni fallo", absf(float(r_nul[0]) - float(sin["rayo"][0])) < 0.01)
	lanz.free()
	mundo.queue_free()


## Dispara de verdad (`_disparar`), toma el Hechizo resultante y se lo da a un goblin nuevo. Devuelve [vida que le quita, daño del Hechizo].
func _golpe_real(lanz: EspiaLanzador, mundo: Node3D, fichero: String, elemento: String) -> Array:
	var rune: RuneData = load("res://nucleo/%s_rune.tres" % fichero)
	var receta := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	var datos: Dictionary = {"receta": receta, "rune": rune, "indice": 0, "elemento_nombre": elemento, "glifos": [], "calidad": 1.0}
	lanz.ultimo = null
	lanz._disparar(datos, Vector3.ZERO, Vector3(1, 0, 0), 0.0)
	var h: Hechizo = lanz.ultimo
	var j := Jugador3D.new()
	j.position = Vector3(18 * 2.3, 1.0, 18 * 2.3)
	var modelo := Pj3D.new()
	modelo.position = Vector3(10 * 2.3, 2.3 * 0.45, 10 * 2.3)
	mundo.add_child(modelo)
	var g: Combate3D = Combate3D.equipar(modelo, mundo, j, null)
	g.set_physics_process(false)
	g.altura = 0.85
	var v0: float = g.health
	g.golpe(h, Vector3(1, 0, 0))
	var quitado: float = v0 - g.health
	var dano_h: float = h.dano
	g.queue_free()
	return [quitado, dano_h]
