extends "res://herramientas/escenario_base.gd"
## DAÑO Y TINTA POR POTENCIA (29/10, DANO_Y_TINTA; docs/DANO_Y_TINTA.md; nucleo/dano.gd). Comprueba:
##   · la tabla completa (3 potencias × 4 elementos) con valores EXACTOS y los cortes de potencia por nº de glifos,
##   · R (débil ×1,5, resiste ×0,75, gólem de pie 0, núcleo ×1,5), X (rayo y hielo sobre mojado) y G (gancho),
##   · la defensa con su suelo (incluido daño < DEF) y que el daño continuo no la pasa,
##   · la tinta por potencia, con y sin ᚱ continuo, sin doble conteo,
##   · que hielo y rayo conservan su daño base,
##   · que `Hechizo`, `Receta3D` y `Combate3D.decidir_golpe` dan los mismos números que `Dano`, y que la previsión (`PrevisionHechizo.prever`) dice lo MISMO que el golpe real contra un goblin.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_dano_tinta.gd

const E_FUEGO: Array = [13.2, 26.4, 44.0]
const E_AGUA: Array = [9.6, 19.2, 32.0]
const E_TIERRA: Array = [13.8, 27.6, 46.0]
const E_VIENTO: Array = [9.6, 19.2, 32.0]
const TINTAS: Array = [8.0, 18.0, 34.0]

var _creados: Array = []


func _c(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func _rune(elem: String) -> RuneData:
	var en: Dictionary = {"fuego": "fire", "agua": "water", "tierra": "earth", "viento": "wind", "hielo": "ice", "rayo": "lightning", "ice": "ice", "lightning": "lightning"}
	return load("res://nucleo/%s_rune.tres" % String(en.get(elem, elem))) as RuneData


## Un Hechizo del elemento con `n` glifos de relleno (flechas): solo cuenta el nº.
func _hechizo(elem: String, n: int) -> Hechizo:
	var cont: Dictionary = {}
	if n > 0:
		cont["flecha"] = n
	return Hechizo.construir(_rune(elem), cont)


func _goblin_sin_escena() -> Combate3D:
	return Combate3D.new()      # sin entrar en el árbol: `decidir_golpe` es una cuenta pura sobre sus campos


func _escenario() -> void:
	_pura_tabla()
	_pura_cortes()
	_pura_formula()
	_pura_tinta()
	_pura_hechizo()
	_pura_enemigos()
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null or lanzador == null:
		_ok("la escena carga", false)
		return
	Repertoire.activate_all()
	Repertoire.max_sigils_per_page = maxi(Repertoire.max_sigils_per_page, 8)
	await avanzar(30)
	await _previsto_igual_a_real()
	for n in _creados:
		if is_instance_valid(n):
			(n as Node).queue_free()


# --- 1 · la tabla -----------------------------------------------------------------------------------------------------

func _pura_tabla() -> void:
	var tabla: Dictionary = {"fuego": E_FUEGO, "agua": E_AGUA, "tierra": E_TIERRA, "viento": E_VIENTO}
	var glifos_de_nivel: Array = [1, 2, 4]            # un glifo es ligera, dos media, cuatro alta
	for el in tabla:
		for i in range(3):
			var esperado: float = float((tabla[el] as Array)[i])
			_ok("1 tabla %s %s = %.1f" % [el, Dano.NOMBRES[i], esperado], _c(Dano.base_elemental(int(glifos_de_nivel[i]), el), esperado), str(Dano.base_elemental(int(glifos_de_nivel[i]), el)))
	_ok("1 B: ligera 12 · media 24 · alta 40", Dano.base(1) == 12.0 and Dano.base(2) == 24.0 and Dano.base(4) == 40.0)
	_ok("1 E: fuego 1,10 · agua 0,80 · tierra 1,15 · viento 0,80", Dano.mult_elemento("fuego") == 1.10 and Dano.mult_elemento("agua") == 0.80 and Dano.mult_elemento("tierra") == 1.15 and Dano.mult_elemento("viento") == 0.80)
	_ok("1 hielo y rayo no tienen tabla (aparcados)", not Dano.tiene_tabla("hielo") and not Dano.tiene_tabla("rayo") and Dano.tiene_tabla("fuego"))


func _pura_cortes() -> void:
	var esperado: Array = [0, 0, 1, 1, 2, 2, 2]      # 0..6 glifos
	for n in range(7):
		_ok("2 corte: %d glifos → %s" % [n, Dano.NOMBRES[int(esperado[n])]], Dano.nivel(n) == int(esperado[n]))
	_ok("2 el libro admite 6 glifos y 6 es alta", Hechizo.MAX_GLIFOS == 6 and Dano.nivel(Hechizo.MAX_GLIFOS) == Dano.ALTA)
	# el nivel que sale del Hechizo y de la Receta3D es el mismo y cuenta glifos, no el elemento
	var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	for g in ["flecha", "barrera", "linea_x"]:
		r.apply(g)
	_ok("2 la receta cuenta 3 glifos (media)", r.n_glifos() == 3 and Dano.nivel(r.n_glifos()) == Dano.MEDIA)
	var h: Hechizo = r.hechizo(_rune("fuego"))
	_ok("2 el Hechizo cuenta lo mismo que la receta (n_glifos %d, nivel %d)" % [h.n_glifos, h.nivel_potencia], h.n_glifos == 3 and h.nivel_potencia == Dano.MEDIA)
	var r0 := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	_ok("2 sin glifos: 0 glifos, ligera", r0.n_glifos() == 0 and Dano.nivel(0) == Dano.LIGERA)
	r0.apply("amplificar")       # aparcado: la receta no lo cuenta
	_ok("2 un glifo aparcado (amplificar) NO cuenta para la potencia", r0.n_glifos() == 0)


# --- 3 · la fórmula ---------------------------------------------------------------------------------------------------

func _pura_formula() -> void:
	# R, X, G
	_ok("3 débil ×1,5 y resiste ×0,75 (Dano y Combate3D)", Dano.MULT_DEBIL == 1.5 and Dano.MULT_RESISTE == 0.75 and Combate3D.MULT_DEBIL == 1.5 and Combate3D.MULT_RESISTE == 0.75)
	_ok("3 fuego media (26,4) débil sin defensa = 39,6", _c(Dano.calcular(2, "fuego", 1.0, 1.0, 1.5, 0.0), 39.6))
	_ok("3 fuego media resiste sin defensa = 19,8", _c(Dano.calcular(2, "fuego", 1.0, 1.0, 0.75, 0.0), 19.8))
	_ok("3 G multiplica (G = 2: 52,8)", _c(Dano.calcular(2, "fuego", 2.0, 1.0, 1.0, 0.0), 52.8))
	_ok("3 X multiplica (X = 1,5: 39,6)", _c(Dano.calcular(2, "fuego", 1.0, 1.5, 1.0, 0.0), 39.6))
	_ok("3 la suma de la reacción entra ANTES de R: (26,4 + 15) × 1,5 = 62,1", _c(Dano.calcular(2, "fuego", 1.0, 1.0, 1.5, 0.0, -1.0, 15.0), 62.1))
	_ok("3 R = 0 (gólem de pie): daño 0 aunque la defensa sea 0", Dano.calcular(4, "tierra", 1.0, 1.0, 0.0, 0.0) == 0.0)
	_ok("3 núcleo expuesto ×1,5 y defensa 10: fuego media 26,4 × 1,5 − 10 = 29,6", _c(Dano.calcular(2, "fuego", 1.0, 1.0, 1.5, 10.0), 29.6))
	# defensa y su suelo
	_ok("3 defensa: 26,4 − 2 = 24,4", _c(Dano.calcular(2, "fuego", 1.0, 1.0, 1.0, 2.0), 24.4))
	_ok("3 defensa mayor que el daño: queda el suelo (13,2 con DEF 20 → 2,64)", _c(Dano.calcular(1, "fuego", 1.0, 1.0, 1.0, 20.0), 2.64))
	_ok("3 el suelo no sube un daño que la defensa deja por encima (13,2 − 2 = 11,2 > 2,64)", _c(Dano.calcular(1, "fuego", 1.0, 1.0, 1.0, 2.0), 11.2))
	_ok("3 SUELO_DEF = 0,2", Dano.SUELO_DEF == 0.2)
	_ok("3 el golpe cuerpo a cuerpo F = 5: DEF 2 → 3 · DEF 5 → 1 (suelo) · DEF 10 → 1", _c(Dano.tras_defensa(5.0, 2.0), 3.0) and _c(Dano.tras_defensa(5.0, 5.0), 1.0) and _c(Dano.tras_defensa(5.0, 10.0), 1.0))
	_ok("3 un daño de 0 se queda en 0", Dano.tras_defensa(0.0, 5.0) == 0.0)
	# continuo
	_ok("3 el daño continuo pasa por R pero no por DEF (3 × 1,5 = 4,5 aunque la defensa sea 10)", _c(Dano.continuo(3.0, 1.5), 4.5))
	# hielo y rayo
	_ok("3 hielo y rayo conservan su daño: base 20 y 55 (sin tabla)", Dano.base_elemental(4, "hielo", 20.0) == 20.0 and Dano.base_elemental(1, "rayo", 55.0) == 55.0)
	_ok("3 hielo con R y DEF: 20 × 1,5 − 2 = 28 · rayo 55 resiste: 41,25 − 2 = 39,25", _c(Dano.calcular(1, "hielo", 1.0, 1.0, 1.5, 2.0, 20.0), 28.0) and _c(Dano.calcular(1, "rayo", 1.0, 1.0, 0.75, 2.0, 55.0), 39.25))
	_ok("3 la propuesta (rayo ×1,00, hielo ×0,90) está anotada pero NO aplicada", Dano.PROPUESTA_RAYO == 1.0 and Dano.PROPUESTA_HIELO == 0.9 and not Dano.MULT_ELEMENTO.has("hielo") and not Dano.MULT_ELEMENTO.has("rayo"))
	_ok("3 las .tres de hielo (20) y rayo (55) siguen igual", _c(_rune("ice").damage, 20.0) and _c(_rune("lightning").damage, 55.0))


# --- 4 · la tinta -----------------------------------------------------------------------------------------------------

func _pura_tinta() -> void:
	for i in range(3):
		_ok("4 tinta base %s = %.0f" % [Dano.NOMBRES[i], float(TINTAS[i])], Dano.tinta([1, 2, 4][i]) == float(TINTAS[i]))
	_ok("4 tinta con recargo continuo (ᚱ, +25 %): media 18 → 22,5 · alta 34 → 42,5", _c(Dano.tinta(2, Sigils.COSTE_CONTINUO_V2), 22.5) and _c(Dano.tinta(4, Sigils.COSTE_CONTINUO_V2), 42.5))
	_ok("4 los glifos solo entran por T_base: 2 y 3 glifos cuestan lo mismo, 4 y 6 también (sin doble conteo)", Dano.tinta(2) == Dano.tinta(3) and Dano.tinta(4) == Dano.tinta(6))
	# eficiencia daño/tinta (fuego medio): 24/18 ≈ 1,33; ligera 12/8 = 1,5; alta 40/34 ≈ 1,18
	_ok("4 eficiencia B/T: 1,5 · 1,33 · 1,18", _c(12.0 / 8.0, 1.5) and absf(24.0 / 18.0 - 1.3333) < 0.001 and absf(40.0 / 34.0 - 1.1765) < 0.001)
	# con la receta real: barrera + ᚱ (continuo) cuesta más que barrera + barrera (mismo nº de glifos)
	var con_r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	con_r.apply("barrera")
	con_r.apply("raido")
	var sin_r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	sin_r.apply("barrera")
	sin_r.apply("barrera")
	_ok("4 receta barrera + ᚱ (continuo): 2 glifos → 18 × 1,25 = 22,5", _c(con_r.coste_tinta(), 22.5), str(con_r.coste_tinta()))
	_ok("4 receta barrera + barrera (2 glifos, sin ᚱ): 18", _c(sin_r.coste_tinta(), 18.0), str(sin_r.coste_tinta()))
	var solo_r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	solo_r.apply("raido")
	_ok("4 ᚱ sin barrera ni permanencia no es continuo: 1 glifo = ligera 8", _c(solo_r.coste_tinta(), 8.0), str(solo_r.coste_tinta()))
	var vacia := Lanzador3D.Receta3D.new(Vector2.RIGHT)
	_ok("4 sin glifos cuesta la ligera (8)", _c(vacia.coste_tinta(), 8.0))
	# el Hechizo y la receta dan lo mismo
	var h_r: Hechizo = con_r.hechizo(_rune("agua"))
	_ok("4 Hechizo.coste_tinta = Receta3D.coste_tinta (%.2f)" % h_r.coste_tinta, _c(h_r.coste_tinta, con_r.coste_tinta()))
	var h_s: Hechizo = sin_r.hechizo(_rune("agua"))
	_ok("4 Hechizo sin ᚱ: 18", _c(h_s.coste_tinta, 18.0))
	# el coste ya no depende del volumen: 4 glifos de eje (volumen grande) y 4 flechas cuestan igual
	var grande: Hechizo = Hechizo.construir(_rune("fuego"), {"linea_x": 4})
	var chica: Hechizo = Hechizo.construir(_rune("fuego"), {"flecha": 4})
	_ok("4 el volumen ya no cuesta: 4 glifos (anchos o flechas) = 34", _c(grande.coste_tinta, 34.0) and _c(chica.coste_tinta, 34.0), "%s / %s" % [grande.coste_tinta, chica.coste_tinta])
	_ok("4 la tinta no depende del elemento", _c(Hechizo.construir(_rune("rayo"), {"flecha": 2}).coste_tinta, 18.0) and _c(Hechizo.construir(_rune("tierra"), {"flecha": 2}).coste_tinta, 18.0))
	_ok("4 la barra sigue en 100 y +20 por reacción", Tinta.MAXIMA_INICIAL == 100.0 and Tinta.TINTA_POR_REACCION == 20.0)
	_ok("4 ya no hay coste por volumen en Tinta", not ("coste_receta" in Tinta.new().get_method_list().map(func(m): return m["name"])))


# --- 5 · el Hechizo ---------------------------------------------------------------------------------------------------

func _pura_hechizo() -> void:
	var glifos_de_nivel: Array = [1, 2, 4]
	var fallos: int = 0
	for el in ["fuego", "agua", "tierra", "viento"]:
		for i in range(3):
			var h: Hechizo = _hechizo(el, int(glifos_de_nivel[i]))
			if not _c(h.dano, Dano.base_elemental(int(glifos_de_nivel[i]), el)):
				fallos += 1
	_ok("5 Hechizo.dano = B × E en los 12 casos", fallos == 0, "%d mal" % fallos)
	_ok("5 hielo conserva 20 y rayo 55 con cualquier nº de glifos", _c(_hechizo("hielo", 0).dano, 20.0) and _c(_hechizo("hielo", 5).dano, 20.0) and _c(_hechizo("rayo", 1).dano, 55.0) and _c(_hechizo("rayo", 6).dano, 55.0))
	_ok("5 G (Hechizo.potencia) vale 1,0: ningún glifo toca el daño del impacto", _c(_hechizo("fuego", 4).potencia, 1.0))
	_ok("5 la tierra ya no suma +18 por su cuenta (ligera 13,8)", _c(_hechizo("tierra", 1).dano, 13.8))
	var h_lab: Hechizo = _hechizo("fuego", 2).con({"dano": 100.0})
	_ok("5 el laboratorio sigue pudiendo fijar el daño (con({dano}) = 100)", _c(h_lab.dano, 100.0))
	var h_c: Hechizo = _hechizo("agua", 4).copiar()
	_ok("5 copiar() conserva daño, glifos y tinta", _c(h_c.dano, 32.0) and h_c.n_glifos == 4 and _c(h_c.coste_tinta, 34.0))


# --- 6 · los enemigos -------------------------------------------------------------------------------------------------

func _pura_enemigos() -> void:
	var g: Combate3D = _goblin_sin_escena()
	g.debil = ""
	g.resiste = ""
	_ok("6 DEF: goblin 2 (atributo exportable)", g.defensa == 2.0 and Dano.DEF_GOBLIN == 2.0)
	_ok("6 DEF: limo 0 · chamán 0 · escudo 5 · elemental 6 · gólem 10", Dano.DEF_LIMO == 0.0 and Dano.DEF_CHAMAN == 0.0 and Dano.DEF_ESCUDO == 5.0 and Dano.DEF_ELEMENTAL == 6.0 and Dano.DEF_GOLEM == 10.0)
	_ok("6 vidas: goblin 50 · limo 30 · chamán 30 · gólem 70 · elemental 500 · gatopedro 45", Combate3D.VIDA_MAXIMA == 50.0 and Limo3D.VIDA == 30.0 and Chaman3D.VIDA == 30.0 and Golem3D.VIDA == 70.0 and Combate3D.ELEM_VIDA == 500.0 and Gatopedro3D.VIDA == 45.0)
	var h: Hechizo = _hechizo("fuego", 2)
	var d: Dictionary = g.decidir_golpe(h)
	_ok("6 fuego media a goblin normal: 26,4 − 2 = 24,4 (dano %.2f)" % float(d["dano"]), _c(float(d["dano"]), 24.4) and _c(float(d["bruto"]), 26.4) and float(d["mult"]) == 1.0)
	g.debil = "fuego"
	_ok("6 débil: 26,4 × 1,5 − 2 = 37,6", _c(float(g.decidir_golpe(h)["dano"]), 37.6))
	g.debil = ""
	g.resiste = "fuego"
	_ok("6 resiste: 26,4 × 0,75 − 2 = 17,8", _c(float(g.decidir_golpe(h)["dano"]), 17.8))
	g.resiste = ""
	# X: rayo y hielo sobre mojado se mueven a X sin cambiar su efecto
	g.mojado = 5.0
	var hr: Hechizo = _hechizo("rayo", 1)
	var dr: Dictionary = g.decidir_golpe(hr)
	_ok("6 rayo sobre mojado: X ×1,5 → 55 × 1,5 − 2 = 80,5 y salta el arco", _c(float(dr["dano"]), 80.5) and bool(dr["arco"]) and _c(float(dr["base"]), 82.5))
	var hh: Hechizo = _hechizo("hielo", 1)
	var dh: Dictionary = g.decidir_golpe(hh)
	_ok("6 hielo sobre mojado: (20 + 15) − 2 = 33", _c(float(dh["dano"]), 33.0))
	g.mojado = 0.0
	_ok("6 rayo seco: 55 − 2 = 53 · hielo seco: 20 − 2 = 18 (pasan por la defensa)", _c(float(g.decidir_golpe(hr)["dano"]), 53.0) and _c(float(g.decidir_golpe(hh)["dano"]), 18.0))
	# golpes para matar (tabla del doc) contra el goblin de 50
	_ok("6 un goblin (50, DEF 2) cae con 5 fuegos ligeros (11,2 × 5 = 56) y no con 4", Dano.golpes_para_matar(50.0, float(g.decidir_golpe(_hechizo("fuego", 1))["dano"])) == 5)
	_ok("6 con 2 fuegos medios deja 1,2 de vida (la quemadura lo remata): 2 × 24,4 = 48,8", _c(2.0 * 24.4, 48.8) and Dano.golpes_para_matar(50.0, 24.4) == 3)
	# limo y chamán sin defensa
	_ok("6 limo: defensa 0 por defecto del tipo (se fija en _ready)", Dano.DEF_LIMO == 0.0)
	# gólem
	var gol: Golem3D = Golem3D.new()
	gol.defensa = Dano.DEF_GOLEM
	var dg: Dictionary = gol.decidir_golpe(h)
	_ok("6 gólem de pie: R = 0, daño 0", float(dg["mult"]) == 0.0 and float(dg["dano"]) == 0.0)
	gol.free()
	g.free()


# --- 7 · la previsión dice lo que pasa ---------------------------------------------------------------------------------

func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _goblin(c: Vector2i) -> Combate3D:
	var p: Vector3 = _pos(c)
	var modelo: Pj3D = maqueta.call("_personaje", ["goblin_warrior_chibi"], p)
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, jugador as Jugador3D, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = Vector3(1, 0, 0)
	g.debil = ""
	g.resiste = ""
	_creados.append(g)
	_creados.append(modelo)
	return g


func _preparar(c: Vector2i, elemento: String, glifos: Array) -> Dictionary:
	colocar_jugador(c)
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	lanzador.cooldown_left[0] = 0.0
	if lanzador.tinta != null:
		lanzador.tinta.rellenar_barra()
	lanzador.cast_page(0)
	return lanzador._preparado


func _previsto_igual_a_real() -> void:
	var oeste := Vector3(-1, 0, 0)
	# agua (sin quemadura ni zona que hiera después) con 2 glifos: media = 19,2; goblin DEF 2 → 17,2
	var g: Combate3D = _goblin(Vector2i(9, 31))
	g.health = 50.0
	g.vida_max = 50.0
	var datos: Dictionary = _preparar(Vector2i(11, 31), "agua", ["flecha", "linea_x"])
	_ok("7 la página con agua + 2 glifos se prepara", not datos.is_empty())
	if datos.is_empty():
		return
	var h: Hechizo = lanzador.hechizo_de(datos)
	_ok("7 el Hechizo de la página es de potencia media (2 glifos) y tiene 19,2", h != null and h.nivel_potencia == Dano.MEDIA and _c(h.dano, 19.2))
	var prev: Array[Dictionary] = PrevisionHechizo.prever(lanzador, datos, jugador.position, oeste)
	var previsto: float = -1.0
	for e in prev:
		if String(e["que"]) == "enemigo" and e["nodo"] == g:
			previsto = float((e["extra"] as Dictionary)["dano"])
	_ok("7 la previsión del indicador da 17,2 contra el goblin (agua media − DEF 2): %.2f" % previsto, _c(previsto, 17.2))
	var dec: Dictionary = g.decidir_golpe(h)
	_ok("7 la previsión = decidir_golpe = Dano.calcular (%.2f)" % float(dec["dano"]), _c(previsto, float(dec["dano"])) and _c(previsto, Dano.calcular(2, "agua", 1.0, 1.0, 1.0, 2.0)))
	var tinta0: float = lanzador.tinta.actual
	var salio: bool = lanzador.lanzar_ahora(datos, jugador.position, oeste)
	var gastada: float = tinta0 - lanzador.tinta.actual
	_ok("7 el hechizo sale", salio)
	_ok("7 cuesta 18 de tinta (media): gastó %.2f" % gastada, _c(gastada, 18.0))
	await avanzar_s(2.2)
	var recibido: float = 50.0 - g.health
	_ok("7 el golpe real quita lo previsto (%.2f vs %.2f)" % [recibido, previsto], _c(recibido, previsto))
	# ligera: fuego con 1 glifo, goblin distinto — el mismo número en previsión y en golpe directo
	var g2: Combate3D = _goblin(Vector2i(9, 33))
	g2.health = 50.0
	g2.vida_max = 50.0
	var d2: Dictionary = _preparar(Vector2i(11, 33), "tierra", ["flecha"])
	var h2: Hechizo = lanzador.hechizo_de(d2)
	var prev2: Array[Dictionary] = PrevisionHechizo.prever(lanzador, d2, jugador.position, oeste)
	var p2: float = -1.0
	for e in prev2:
		if String(e["que"]) == "enemigo" and e["nodo"] == g2:
			p2 = float((e["extra"] as Dictionary)["dano"])
	_ok("7 tierra ligera: 13,8 − 2 = 11,8 previsto (%.2f)" % p2, h2 != null and _c(h2.dano, 13.8) and _c(p2, 11.8))
	lanzador._salir_modo(true)
	lanzador._preparado = {}
	var vida0: float = g2.health
	g2.golpe(h2, oeste)
	_ok("7 y el golpe directo (Combate3D.golpe) quita lo mismo (%.2f)" % (vida0 - g2.health), _c(vida0 - g2.health, p2))
