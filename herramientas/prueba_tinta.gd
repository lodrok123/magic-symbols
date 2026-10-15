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
	print("FALLOS: %d" % _fallos)
	quit(_fallos)
