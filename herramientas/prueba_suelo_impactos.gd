extends "res://herramientas/escenario_base.gd"
## IMPACTOS SOBRE EL SUELO → ESTADO (21/10, Juego). Los impactos de agua, hielo y fuego guardan «mojada», «helada» y «quemada» en `Terreno3D.estados` con la
## misma regla que la maqueta pinta en su imagen (`_impacto_en_suelo`), y la hierba que arde deja «quemada». Mundo REAL (el laboratorio de playtest de EoW: la
## maqueta, el jugador, el Lanzador3D, la simulación de agua, Puzle3D) y el impacto de verdad (`Lanzador3D.marcar_celda`, el mismo camino que un hechizo de área).
## Sin sala 5 ni puente: nadie copia nada, esto mide lo que hace el juego solo. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_suelo_impactos.gd
##
## Qué se mide:
##   1  agua → mojada · dos aguas → helada (y ya no mojada) · agua sobre helada → nada · fuego sobre helada → mojada · fuego sobre mojada → seca · fuego sobre seca → nada · hielo → helada
##   2  en cada paso la IMAGEN de la maqueta (canales G y B) dice lo mismo que el estado
##   3  la hierba que arde → quemada en cuanto el círculo quemado se ve; si el agua la apaga, el estado se quita con la imagen
##   4  el hielo del suelo caduca a los 20 s y la imagen y el estado se quedan igual (seca la escarcha y moja)
##   5  una regla de puzle `casilla(x,y).mojada` se cumple tras un impacto real
##   6  «helada» en suelo es ESCARCHA: no cambia pisable, y_pies, sobre_hielo, es_agua, se_nada, cabe, ni las rutas de Caminos3D; el hielo sobre agua sí sigue siendo hielo
##   7  filtros: un chorro, una acción sin suelo (burbuja) y una casilla en altura (agua/hielo) no escriben; el rayo/viento/tierra tampoco
##   8  barrido final: en TODAS las casillas de suelo del mapa la imagen y el estado coinciden (G, B)

const RUTA_LAB: String = "res://laboratorios/LabPlaytestEoW.tscn"

var lab: Node = null


func _escenario() -> void:
	await cargar(RUTA_LAB)
	lab = maqueta.get_node_or_null("Reglas")
	_ok("0 el laboratorio cuelga de la escena (y NO existe ya ningún puente de estados)", lab != null and not ("puente_estados_s5" in lab) and not lab.has_method("_puente_estados_sala_5"))
	if lab == null:
		return
	jugador.set("vida", 100.0)
	# La hierba va PRIMERO: un agua a 2 casillas o menos la deja «mojada» 8 s de reloj de pared (`_mojada` de la maqueta) y no prende, y la sala 5 es pequeña.
	await _hierba()
	await _combinaciones()
	await _caduca()
	await _regla_de_puzle()
	await _no_cambia_lo_fisico()
	_filtros()
	_barrido()


# ---------------------------------------------------------------------------------------------------------------------

func _e(c: Vector2i, estado: String) -> bool:
	return Terreno3D.estados.tiene(c, estado)


func _px(c: Vector2i) -> Color:
	return (maqueta.get("_img_estado") as Image).get_pixelv(c)


## Un impacto de verdad en el suelo de la casilla (Lanzador3D.marcar_celda → maqueta._al_impactar + al_impactar). Las dos cosas ocurren en el mismo fotograma.
func _impacto(elemento: String, c: Vector2i) -> void:
	lanzador.marcar_celda(elemento, c)
	await avanzar_s(0.3)


## ¿La imagen de la maqueta y el estado dicen lo mismo de esta casilla de SUELO? (G = mojada, B = helada.)
func _coinciden(c: Vector2i) -> bool:
	var p: Color = _px(c)
	return (p.g >= 0.5) == _e(c, "mojada") and (p.b >= 0.5) == _e(c, "helada")


func _estado_txt(c: Vector2i) -> String:
	var p: Color = _px(c)
	return "estado[mojada %s helada %s] imagen[G %.1f B %.1f]" % [str(_e(c, "mojada")), str(_e(c, "helada")), p.g, p.b]


# ---------------------------------------------------------------------------------------------------------------------
#  1 y 2 · las combinaciones de la tabla, con impactos reales
# ---------------------------------------------------------------------------------------------------------------------

func _combinaciones() -> void:
	var c: Vector2i = Vector2i(1, 13)      # suelo desnudo de la sala 5 (el mapa lo dice: ni agua ni hierba ni pieza)
	_ok("1.0 la casilla (1,13) es de SUELO para el estado y empieza seca", ReaccionesSuelo3D.clase_de(c) == "suelo" and not _e(c, "mojada") and not _e(c, "helada") and not _e(c, "quemada"))
	await _impacto("agua", c)
	_ok("1.1 agua sobre suelo → MOJADA (y la imagen coincide)", _e(c, "mojada") and not _e(c, "helada") and _coinciden(c), _estado_txt(c))
	await _impacto("agua", c)
	_ok("1.2 dos aguas → HELADA, ya no mojada (y la imagen coincide)", _e(c, "helada") and not _e(c, "mojada") and _coinciden(c), _estado_txt(c))
	_ok("1.2b esa helada es escarcha de suelo, no hielo sobre agua", Terreno3D.estados.es_escarcha(c) and Terreno3D.helada(c) and not Terreno3D.hielo_fisico(c))
	await _impacto("agua", c)
	_ok("1.3 agua sobre helada → nada (sigue helada, no se moja)", _e(c, "helada") and not _e(c, "mojada") and _coinciden(c), _estado_txt(c))
	await _impacto("fuego", c)
	_ok("1.4 fuego sobre helada → MOJADA (el hielo pasa a charco)", _e(c, "mojada") and not _e(c, "helada") and _coinciden(c) and not Terreno3D.estados.es_escarcha(c), _estado_txt(c))
	await _impacto("fuego", c)
	_ok("1.5 fuego sobre mojada → SECA (se evapora)", not _e(c, "mojada") and not _e(c, "helada") and _coinciden(c), _estado_txt(c))
	await _impacto("fuego", c)
	_ok("1.6 fuego sobre seca → nada (suelo desnudo no se quema)", not _e(c, "mojada") and not _e(c, "helada") and not _e(c, "quemada") and _coinciden(c), _estado_txt(c))
	await _impacto("hielo", c)
	_ok("1.7 hielo sobre seca → HELADA", _e(c, "helada") and not _e(c, "mojada") and _coinciden(c), _estado_txt(c))
	await _impacto("fuego", c)
	await _impacto("fuego", c)
	_ok("1.7b (limpiar) fuego dos veces: queda seca", not _e(c, "helada") and not _e(c, "mojada") and _coinciden(c), _estado_txt(c))
	await _impacto("agua", c)
	await _impacto("hielo", c)
	_ok("1.8 hielo sobre mojada → HELADA y ya no mojada", _e(c, "helada") and not _e(c, "mojada") and _coinciden(c), _estado_txt(c))
	await _impacto("fuego", c)
	await _impacto("fuego", c)
	var viento_antes: bool = _e(c, "mojada") or _e(c, "helada")
	await _impacto("viento", c)
	await _impacto("tierra", c)
	await _impacto("rayo", c)
	_ok("1.9 viento, tierra y rayo no tocan mojada ni helada", not viento_antes and not _e(c, "mojada") and not _e(c, "helada") and _coinciden(c), _estado_txt(c))
	# Una casilla BLOQUEADA no recibe nada (como en la maqueta): el brasero de la sala 5 (s5_br, letra T).
	var bl: Vector2i = Vector2i(4, 15)
	var antes_b: bool = _e(bl, "mojada")
	await _impacto("agua", bl)
	_ok("1.10 una casilla bloqueada (el brasero) no recibe estados de suelo", ReaccionesSuelo3D.clase_de(bl) != "suelo" and _e(bl, "mojada") == antes_b, _estado_txt(bl))
	# Y agua: el hielo sobre el agua sigue yendo por su camino (poner_helada), no por aquí.
	var rio: Vector2i = Vector2i(12, 3)
	_ok("1.11 la charca (letra ~) es de clase «agua»: aquí no se escribe nada", ReaccionesSuelo3D.clase_de(rio) == "agua")
	var n_antes: int = Terreno3D.estados.cuantas("mojada")
	await _impacto("agua", rio)
	_ok("1.12 un agua sobre la charca no deja «mojada» en el estado del suelo", Terreno3D.estados.cuantas("mojada") == n_antes and not _e(rio, "mojada"))


# ---------------------------------------------------------------------------------------------------------------------
#  3 · la hierba que arde
# ---------------------------------------------------------------------------------------------------------------------

func _hierba() -> void:
	var h: Vector2i = LabPlaytestEoW3D.SALA5_FUEGO      # (6,14): hierba v
	colocar_jugador(Vector2i(4, 14))
	_ok("3.0 (6,14) es HIERBA para la maqueta y empieza sin quemar", ReaccionesSuelo3D.clase_de(h) == "hierba" and not _e(h, "quemada"))
	await _impacto("fuego", h)
	_ok("3.1 recién prendida la hierba aún no está «quemada» (el círculo quemado no se ve)", not _e(h, "quemada"), "imagen R %.2f" % _px(h).r)
	var t: float = 0.0
	while not _e(h, "quemada") and t < 14.0:
		await avanzar_s(0.25)
		t += 0.25
	_ok("3.2 la hierba que arde queda «quemada» en cuanto el círculo se ve (R ≥ 0,5)", _e(h, "quemada") and _px(h).r >= 0.5, "a los %.1f s · imagen R %.2f" % [t, _px(h).r])
	await avanzar_s(6.0)
	_ok("3.3 hecha cenizas sigue «quemada» (y la imagen también)", _e(h, "quemada") and _px(h).r >= 0.5, "imagen R %.2f" % _px(h).r)
	_ok("3.3b el fuego sobre hierba no escribe mojada ni helada", not _e(h, "mojada") and not _e(h, "helada"))
	# El agua apaga la ceniza: la maqueta deja la hierba FINA y borra el círculo quemado (R = 0). El estado no puede quedarse con «quemada».
	await _impacto("agua", h)
	await avanzar(3)
	var r_img: float = _px(h).r
	_ok("3.4 el agua apaga la hierba quemada: la imagen se borra y el estado «quemada» se quita con ella", r_img < 0.5 and not _e(h, "quemada"), "imagen R %.2f · quemada %s" % [r_img, str(_e(h, "quemada"))])
	_ok("3.5 y la hierba mojada por el agua NO deja «mojada» en el estado (la maqueta no pinta G en hierba: lo suyo es un reloj aparte)", not _e(h, "mojada") and _px(h).g < 0.5)


# ---------------------------------------------------------------------------------------------------------------------
#  4 · el hielo de suelo caduca
# ---------------------------------------------------------------------------------------------------------------------

func _caduca() -> void:
	var c: Vector2i = Vector2i(2, 14)
	await _impacto("hielo", c)
	_ok("4.1 hielo sobre suelo: helada en estado e imagen", _e(c, "helada") and _coinciden(c), _estado_txt(c))
	var hielo: Dictionary = lanzador.get("_hielo")
	_ok("4.2 el Lanzador apunta que ese hielo caduca (20 s)", hielo.has(c), str(hielo.keys()))
	if hielo.has(c):
		(hielo[c] as Dictionary)["resta"] = 0.3         # adelantamos el reloj: lo medido es qué pasa al caducar, no los 20 s
	await avanzar_s(1.0)
	_ok("4.3 al caducar, la imagen quita el hielo y moja la casilla, y el estado hace lo MISMO (sin helada, mojada)", not _e(c, "helada") and _e(c, "mojada") and _coinciden(c), _estado_txt(c))
	_ok("4.4 y ya no queda escarcha apuntada", not Terreno3D.estados.es_escarcha(c))


# ---------------------------------------------------------------------------------------------------------------------
#  5 · una regla de puzle con un impacto real
# ---------------------------------------------------------------------------------------------------------------------

func _regla_de_puzle() -> void:
	var z: Puzle3D = lab.puzle_nodo()
	var regla: Dictionary = z.puzle("s5_abre_c")
	var expr: Array = regla.get("si_expr", [])
	var casilla: Vector2i = Vector2i(5, 11)
	_ok("5.0 la regla `casilla($x,$y).mojada` de la placa C existe y apunta a (5,11)", not expr.is_empty() and expr[0][0]["celda"] == casilla)
	if expr.is_empty():
		return
	Terreno3D.estados.poner(casilla, "mojada", false)
	_ok("5.1 antes del impacto la condición NO se cumple", not z.cumple_expr(expr))
	await _impacto("agua", casilla)
	_ok("5.2 tras UN agua de verdad sobre la casilla la condición `casilla(5,11).mojada` SE CUMPLE (sin puente)", z.cumple_expr(expr), _estado_txt(casilla))
	await _impacto("agua", casilla)
	_ok("5.3 con el segundo agua (hiela) deja de cumplirse, como en la sala 5", not z.cumple_expr(expr) and _e(casilla, "helada"))
	var expr_b: Array = z.puzle("s5_abre_b").get("si_expr", [])
	var hielo: Vector2i = LabPlaytestEoW3D.SALA5_HIELO
	var seca: Vector2i = LabPlaytestEoW3D.SALA5_SECA
	Terreno3D.estados.poner(hielo, "helada", false)
	Terreno3D.estados.poner(hielo, "mojada", false)
	Terreno3D.estados.poner(seca, "mojada", false)
	await _impacto("hielo", hielo)
	_ok("5.4 la puerta B (hielo O fuego, y el centro seco) se cumple con el HIELO de verdad", z.cumple_expr(expr_b), _estado_txt(hielo))


# ---------------------------------------------------------------------------------------------------------------------
#  6 · «helada» en suelo no cambia lo físico
# ---------------------------------------------------------------------------------------------------------------------

## Todo lo que depende de que una casilla sea «hielo sobre agua», medido ANTES y DESPUÉS de helar un tramo de suelo de la sala 5 con dos aguas de verdad.
func _fisica(c: Vector2i) -> Dictionary:
	return {"pisable": Terreno3D.pisable(c, 0, false, 0, false), "pisable_sube": Terreno3D.pisable(c, 0, true, 1, true), "y_pies": snappedf(Terreno3D.y_pies(c), 0.0001),
		"sobre_hielo": Terreno3D.sobre_hielo(Terreno3D.centro_de(c, 0.0)), "cubre": Terreno3D.cubre_hielo(c), "es_agua": Terreno3D.es_agua(c), "se_nada": Terreno3D.se_nada(c),
		"conduce": Terreno3D.conduce(c), "cabe": Terreno3D.cabe([c], 0, 1, false), "ocupado": Terreno3D.ocupado(c, 0), "transitable": Caminos3D.transitable(c)}


func _no_cambia_lo_fisico() -> void:
	# Un tramo de suelo desnudo de la sala 5 (fila y=13): (1,13) a (3,13). Ruta de una punta a otra de la fila antes de helar.
	var tramo: Array = [Vector2i(1, 13), Vector2i(2, 13), Vector2i(3, 13)]
	for c in tramo:
		Terreno3D.estados.poner(c as Vector2i, "mojada", false)
		Terreno3D.estados.poner(c as Vector2i, "helada", false)
	await avanzar(3)
	var a: Vector2i = Vector2i(1, 13)
	var b: Vector2i = Vector2i(3, 13)
	var antes: Array = []
	for c in tramo:
		antes.append(_fisica(c as Vector2i))
	var ruta_antes: Array[Vector2i] = Caminos3D.camino(a, b)
	var cruce_antes: Array[Vector2i] = Caminos3D.camino(Vector2i(1, 12), Vector2i(3, 14))
	for c in tramo:
		await _impacto("agua", c as Vector2i)
		await _impacto("agua", c as Vector2i)
	var heladas: bool = tramo.all(func(c): return _e(c as Vector2i, "helada") and Terreno3D.estados.es_escarcha(c as Vector2i))
	_ok("6.1 el tramo (1..3,13) queda HELADO de verdad (dos aguas, sin mojada)", heladas and tramo.all(func(c): return not _e(c as Vector2i, "mojada")))
	var iguales: bool = true
	for i in range(tramo.size()):
		var d: Dictionary = _fisica(tramo[i] as Vector2i)
		for k in d:
			if d[k] != (antes[i] as Dictionary)[k]:
				iguales = false
				print("      DIFERENCIA en %s: %s antes %s · ahora %s" % [str(tramo[i]), k, str((antes[i] as Dictionary)[k]), str(d[k])])
	_ok("6.2 helada en SUELO no cambia pisable, y_pies, sobre_hielo, cubre_hielo, es_agua, se_nada, conduce, cabe, ocupado ni transitable", iguales)
	_ok("6.3 las rutas de Caminos3D son las mismas (recta y en diagonal)", Caminos3D.camino(a, b) == ruta_antes and Caminos3D.camino(Vector2i(1, 12), Vector2i(3, 14)) == cruce_antes and not ruta_antes.is_empty(),
		"antes %d pasos · ahora %d" % [ruta_antes.size(), Caminos3D.camino(a, b).size()])
	_ok("6.4 el jugador sigue pisando a su altura de siempre en esa casilla helada (no se hunde a la del agua)", absf(Terreno3D.y_pies(a) - Terreno3D.alto_suelo) < 0.001, "y_pies %.3f · suelo %.3f" % [Terreno3D.y_pies(a), Terreno3D.alto_suelo])
	# El hielo sobre AGUA de verdad sigue siendo hielo: se pisa, resbala, no es agua, cambia y_pies.
	var rio: Vector2i = Vector2i(12, 3)
	var fis_agua: Dictionary = _fisica(rio)
	Terreno3D.poner_helada(rio, true)
	var fis_hielo: Dictionary = _fisica(rio)
	_ok("6.5 el hielo sobre AGUA sigue siendo hielo: se pisa, resbala y deja de ser agua", not bool(fis_agua["pisable"]) and bool(fis_hielo["pisable"]) and bool(fis_hielo["sobre_hielo"]) and bool(fis_agua["es_agua"]) and not bool(fis_hielo["es_agua"]) and Terreno3D.hielo_fisico(rio),
		"agua %s · hielo %s" % [str(fis_agua), str(fis_hielo)])
	Terreno3D.poner_helada(rio, false)
	# Una escarcha que luego congela el agua de verdad (poner_helada) pasa a ser hielo físico y avisa.
	var avisos: Array = []
	var oyente: Callable = func(cc: Vector2i, est: String, si: bool) -> void: avisos.append([cc, est, si])
	Terreno3D.estados.cambio.connect(oyente)
	var e1: Vector2i = tramo[0]
	Terreno3D.poner_helada(e1, true)
	Terreno3D.estados.cambio.disconnect(oyente)
	_ok("6.6 si el agua congela una casilla que ya era escarcha, deja de serlo (hielo físico) y se avisa para que Caminos3D y la maqueta lo vean", Terreno3D.hielo_fisico(e1) and not Terreno3D.estados.es_escarcha(e1) and avisos == [[e1, "helada", true]], str(avisos))
	for c in tramo:
		Terreno3D.estados.poner(c as Vector2i, "helada", false)
	await avanzar(3)
	# Con fuego se deshace la escarcha de verdad: la imagen y el estado vuelven a coincidir y no queda escarcha apuntada.
	_ok("6.7 al quitar la helada se borra también la marca de escarcha", tramo.all(func(c): return not Terreno3D.estados.es_escarcha(c as Vector2i)))


# ---------------------------------------------------------------------------------------------------------------------
#  7 · filtros
# ---------------------------------------------------------------------------------------------------------------------

func _filtros() -> void:
	var c: Vector2i = Vector2i(7, 13)
	Terreno3D.estados.poner(c, "mojada", false)
	Terreno3D.estados.poner(c, "helada", false)
	var p: Vector3 = Terreno3D.centro_de(c, 0.0)
	var chorro: AccionElemental = AccionElemental.nueva("agua", p, 0.0, 1.0, 2.0)
	Mundo3D.aplicar_accion(chorro)
	_ok("7.1 un chorro que dura (duracion > 0) no es un impacto: no moja el suelo", not _e(c, "mojada"))
	var burbuja: AccionElemental = AccionElemental.nueva("agua", p)
	burbuja.toca_suelo = false
	Mundo3D.aplicar_accion(burbuja)
	_ok("7.2 una acción con toca_suelo = false (el charco de una burbuja) no deja estado", not _e(c, "mojada"))
	var normal: AccionElemental = AccionElemental.nueva("agua", p)
	Mundo3D.aplicar_accion(normal)
	_ok("7.3 la misma acción con toca_suelo (por defecto) sí: UN punto de entrada, Mundo3D.aplicar_accion", _e(c, "mojada"))
	Terreno3D.estados.poner(c, "mojada", false)
	Terreno3D.alturas[c] = 1
	Mundo3D.aplicar_accion(AccionElemental.nueva("agua", p))
	Mundo3D.aplicar_accion(AccionElemental.nueva("hielo", p))
	var arriba_agua_hielo: bool = _e(c, "mojada") or _e(c, "helada")
	Terreno3D.estados.poner(c, "mojada", true)
	Mundo3D.aplicar_accion(AccionElemental.nueva("fuego", p))
	var fuego_llega: bool = not _e(c, "mojada")
	Terreno3D.alturas.erase(c)
	_ok("7.4 en una casilla elevada (altura ≥ 1) el agua y el hielo no llegan al suelo (H4) pero el fuego sí", not arriba_agua_hielo and fuego_llega)
	var fuera: AccionElemental = AccionElemental.nueva("agua", Vector3(-50.0, 0.0, -50.0))
	Mundo3D.aplicar_accion(fuera)
	_ok("7.5 un impacto fuera del mapa no revienta ni escribe", true)


# ---------------------------------------------------------------------------------------------------------------------
#  8 · el barrido final
# ---------------------------------------------------------------------------------------------------------------------

func _barrido() -> void:
	var img: Image = maqueta.get("_img_estado") as Image
	var n: int = 0
	var mal: Array = []
	for y in range(Terreno3D.lado_del_mapa()):
		for x in range(Terreno3D.lado_del_mapa()):
			var c := Vector2i(x, y)
			if ReaccionesSuelo3D.clase_de(c) != "suelo":
				continue
			n += 1
			if not _coinciden(c):
				mal.append("%s %s" % [str(c), _estado_txt(c)])
	_ok("8.1 en las %d casillas de suelo del mapa la imagen (G, B) y el estado (mojada, helada) coinciden" % n, mal.is_empty() and n > 100, str(mal.slice(0, 5)))
	var rojas: Array = []
	for c in Terreno3D.estados.celdas("quemada"):
		if img.get_pixelv(c as Vector2i).r < 0.5:
			rojas.append(c)
	_ok("8.2 ninguna casilla «quemada» del estado tiene la imagen sin quemar (R < 0,5)", rojas.is_empty(), str(rojas))
