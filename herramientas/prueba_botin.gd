extends SceneTree
## F1 de PLAN_BASE_DATOS (29/10, Juego): el botín por tablas. Sin escena: `Botin` (pesos, `nada`, `independiente`, `tirada_forzada`, zona → tabla, cifras de ayer), `BotinObjeto3D` (modelo o
## esfera con aro, bolsa llena deja la pieza en el suelo, parte entra y el resto espera), `Botin.soltar` (oro = moneda de siempre), el envoltorio `BotinGoblin`, `tener.<objeto>` en las `si=`
## de Puzle3D, `da=tabla:<id>` y la llave gastada de `CofrePuzle`, las piezas nuevas de Reactivo3D (sacudible, helable, seto quemado), la colmena, el nido, la geoda y el cristal.
## Lo que necesita la escena de verdad (un limo que muere, lava que se enfría, la jugadora cogiendo del suelo) está en `escenario_botin.gd`.
##   godot --headless --path . --script res://herramientas/prueba_botin.gd

var _fallos: int = 0
var _x: float = 0.0
var _fx: Vfx3D = null
var _mundo: Node3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	# Un terreno llano de 64 × 12 casillas (sin maqueta): lo que pregunta `y_pies` al colocar piezas.
	var filas: PackedStringArray = []
	for _y in range(12):
		filas.append(".".repeat(64))
	Terreno3D.cargar_datos(filas, {})
	_mundo = Node3D.new()
	root.add_child(_mundo)
	_fx = Vfx3D.new()
	root.add_child(_fx)
	_tiradas()
	_zonas()
	_cifras_de_ayer()
	_textos()
	await _suelo()
	_expresiones()
	await _cofre()
	await _reactivos()
	await _piezas_nuevas()
	Terreno3D.olvidar_datos()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _lista_a_texto(l: Array) -> String:
	var r: PackedStringArray = []
	for it in l:
		r.append("%s×%d" % [String((it as Dictionary)["que"]), int((it as Dictionary)["n"])])
	return ",".join(r)


func _cuenta(l: Array, que: String) -> int:
	var n: int = 0
	for it in l:
		if String((it as Dictionary)["que"]) == que:
			n += int((it as Dictionary)["n"])
	return n


# ---------------------------------------------------------------------------------------------------------------------
func _tiradas() -> void:
	Botin.tirada_forzada = 0.0
	var a: Array = Botin.tirar("jarron_bosque")
	_ok("1 pesos: con la tirada más baja el jarrón del bosque sale vacío (`nada` es una fila)", a.is_empty(), _lista_a_texto(a))
	Botin.tirada_forzada = 0.6
	var b: Array = Botin.tirar("jarron_bosque")
	_ok("1 pesos: con 0,6 cae oro, en el rango 3..8 (con la tirada forzada, 3 + floor(0,6 × 6) = 6)", b.size() == 1 and String(b[0]["que"]) == "oro" and int(b[0]["n"]) == 6, _lista_a_texto(b))
	Botin.tirada_forzada = 0.95
	var c: Array = Botin.tirar("jarron_bosque")
	_ok("1 pesos: con 0,95 cae 1 poción", c.size() == 1 and String(c[0]["que"]) == "pocion" and int(c[0]["n"]) == 1, _lista_a_texto(c))
	Botin.tirada_forzada = 0.6
	var d: Array = Botin.tirar("jarron_bosque", 3)
	_ok("1 n_tiradas: tres tiradas iguales suman (18 de oro en una sola entrada)", d.size() == 1 and int(d[0]["n"]) == 18, _lista_a_texto(d))
	# independientes: el goblin da oro siempre y el colmillo con 60 %.
	Botin.tirada_forzada = 0.0
	var g1: Array = Botin.tirar("goblin")
	Botin.tirada_forzada = 0.59
	var g2: Array = Botin.tirar("goblin")
	Botin.tirada_forzada = 0.6
	var g3: Array = Botin.tirar("goblin")
	Botin.tirada_forzada = 0.99
	var g4: Array = Botin.tirar("goblin")
	_ok("1 independiente: tirada 0 → oro y colmillo", _cuenta(g1, "oro") == 10 and _cuenta(g1, "colmillo_goblin") == 1, _lista_a_texto(g1))
	_ok("1 independiente: 0,59 sigue dando colmillo (< 0,6), 0,6 y 0,99 no; el oro cae siempre", _cuenta(g2, "colmillo_goblin") == 1 and _cuenta(g3, "colmillo_goblin") == 0 and _cuenta(g4, "colmillo_goblin") == 0
		and _cuenta(g3, "oro") == 10 and _cuenta(g4, "oro") == 10, _lista_a_texto(g2) + " | " + _lista_a_texto(g3) + " | " + _lista_a_texto(g4))
	Botin.tirada_forzada = -1.0
	# frecuencias reales (semilla fija: la prueba no depende del azar del día)
	seed(20261029)
	var colmillos: int = 0
	var vacios: int = 0
	var n: int = 4000
	for _i in range(n):
		if _cuenta(Botin.tirar("goblin"), "colmillo_goblin") > 0:
			colmillos += 1
		if Botin.tirar("jarron_bosque").is_empty():
			vacios += 1
	var fc: float = float(colmillos) / float(n)
	var fv: float = float(vacios) / float(n)
	_ok("1 frecuencia del colmillo ≈ 0,6 (%.3f)" % fc, absf(fc - BotinGoblin.PROB_COLMILLO) < 0.04)
	_ok("1 frecuencia de jarrón vacío en el bosque ≈ 0,5 (%.3f)" % fv, absf(fv - 0.5) < 0.04)
	# tabla que no existe: nada, sin romper
	_ok("1 una tabla que no existe no da nada (y avisa)", Botin.tirar("tabla_que_no_existe").is_empty() and not Botin.existe("tabla_que_no_existe") and Botin.existe("limo"))
	# enemigos: limo (baba 1..2 o nada + oro), golem (polvo 1..2), elemental (savia siempre)
	Botin.tirada_forzada = 0.0
	var li: Array = Botin.tirar("limo")
	Botin.tirada_forzada = 0.99
	var li2: Array = Botin.tirar("limo")
	Botin.tirada_forzada = 0.99
	var go: Array = Botin.tirar("golem")
	var el: Array = Botin.tirar("elemental")
	Botin.tirada_forzada = -1.0
	_ok("1 limo: oro 5 siempre; baba con tirada baja, nada con tirada alta", _cuenta(li, "oro") == 5 and _cuenta(li, "baba_limo") == 1 and _cuenta(li2, "oro") == 5 and _cuenta(li2, "baba_limo") == 0, _lista_a_texto(li) + " | " + _lista_a_texto(li2))
	_ok("1 gólem: oro 40 y polvo de gólem 2 con la tirada alta", _cuenta(go, "oro") == 40 and _cuenta(go, "polvo_golem") == 2, _lista_a_texto(go))
	_ok("1 elemental: 150 de oro y savia siempre", _cuenta(el, "oro") == 150 and _cuenta(el, "savia_elemental") == 1, _lista_a_texto(el))
	Botin.tirada_forzada = 0.0
	var gesc: Array = Botin.tirar("goblin_escudo")
	Botin.tirada_forzada = -1.0
	_ok("1 goblin_escudo: los jirones del escudo", _cuenta(gesc, "jiron_escudo") == 1, _lista_a_texto(gesc))


func _zonas() -> void:
	_ok("2 tabla_de_zona: jarron + cueva = jarron_cueva", Botin.tabla_de_zona("jarron", "cueva") == "jarron_cueva")
	_ok("2 tabla_de_zona: una zona sin tabla usa la del bosque", Botin.tabla_de_zona("jarron", "zona_que_no_existe") == "jarron_bosque")
	_ok("2 tabla_de_zona: si la zona no la tiene, prueba la luz", Botin.tabla_de_zona("jarron", "nombre_raro", "cueva") == "jarron_cueva")
	_ok("2 tabla_de_zona: el `botin=` de la zona manda sobre su nombre y su luz", Botin.tabla_de_zona("jarron", "hondonada", "fuego", "campamento") == "jarron_campamento")
	_ok("2 tabla_de_zona: otra base (hierba) sin tabla de zona cae en `hierba_bosque`, que aún no existe", Botin.tabla_de_zona("hierba", "cueva") == "hierba_bosque" and not Botin.existe("hierba_bosque"))


func _cifras_de_ayer() -> void:
	# El oro de cada zona, igual que `BOTIN_ZONA` de ayer.
	var esperado: Dictionary = {"bosque": Vector2i(3, 8), "clasico": Vector2i(3, 8), "atardecer": Vector2i(4, 9), "agua": Vector2i(4, 10), "fuego": Vector2i(5, 11), "ruinas": Vector2i(6, 14),
		"hielo": Vector2i(5, 12), "cueva": Vector2i(5, 12), "santuario": Vector2i(8, 16), "campamento": Vector2i(6, 12)}
	var mal: Array = []
	for z in esperado:
		if Botin.rango("jarron_" + String(z), "oro") != esperado[z]:
			mal.append("%s %s" % [z, str(Botin.rango("jarron_" + String(z), "oro"))])
	_ok("3 el oro de los jarrones por zona es el de ayer", mal.is_empty(), str(mal))
	_ok("3 la poción: 1 en todas menos el santuario (2)", Botin.rango("jarron_bosque", "pocion") == Vector2i(1, 1) and Botin.rango("jarron_cueva", "pocion") == Vector2i(1, 1) and Botin.rango("jarron_santuario", "pocion") == Vector2i(2, 2))
	_ok("3 el perfil del bosque (50 nada · 40 oro · 10 poción) y el del campamento (40 · 45 · 15) como ayer",
		_pesos("jarron_bosque") == {"nada": 50.0, "oro": 40.0, "pocion": 10.0} and _pesos("jarron_campamento") == {"nada": 40.0, "oro": 45.0, "pocion": 15.0}, str(_pesos("jarron_bosque")) + str(_pesos("jarron_campamento")))
	_ok("3 la cueva y las ruinas añaden esquirla de cristal (lo que antes era el «mineral extra»)", Botin.rango("jarron_cueva", "esquirla_cristal") == Vector2i(1, 1) and Botin.rango("jarron_ruinas", "esquirla_cristal") == Vector2i(1, 1) and Botin.rango("jarron_bosque", "esquirla_cristal") == Vector2i.ZERO)
	# Enemigos: el oro de cada uno es el que traía su script; el colmillo, la probabilidad de BotinGoblin.
	_ok("3 oro de los enemigos = el de sus scripts (goblin %d · limo %d · chamán %d · gólem %d · elemental %d)" % [Combate3D.ORO_BOTIN, Limo3D.ORO_LIMO, Chaman3D.ORO_CHAMAN, Golem3D.ORO_GOLEM, Combate3D.ELEM_ORO],
		Botin.rango("goblin", "oro") == Vector2i(Combate3D.ORO_BOTIN, Combate3D.ORO_BOTIN) and Botin.rango("limo", "oro") == Vector2i(Limo3D.ORO_LIMO, Limo3D.ORO_LIMO)
		and Botin.rango("chaman", "oro") == Vector2i(Chaman3D.ORO_CHAMAN, Chaman3D.ORO_CHAMAN) and Botin.rango("golem", "oro") == Vector2i(Golem3D.ORO_GOLEM, Golem3D.ORO_GOLEM)
		and Botin.rango("elemental", "oro") == Vector2i(Combate3D.ELEM_ORO, Combate3D.ELEM_ORO))
	var fila_col: Dictionary = {}
	for f in BD.tabla("goblin"):
		if String(f["objeto"]) == BotinGoblin.MATERIAL:
			fila_col = f
	_ok("3 la fila del colmillo es independiente con la probabilidad de BotinGoblin.PROB_COLMILLO", not fila_col.is_empty() and String(fila_col["independiente"]) == "si" and is_equal_approx(float(fila_col["peso"]), BotinGoblin.PROB_COLMILLO))
	_ok("3 el combate tiene `tabla_botin` por enemigo: goblin por defecto; limo, chamán y gólem la suya", Combate3D.new().tabla_botin == "goblin")


func _pesos(tabla: String) -> Dictionary:
	var r: Dictionary = {}
	for f in BD.tabla(tabla):
		r[String(f["objeto"])] = float(f["peso"])
	return r


func _textos() -> void:
	Botin.tirada_forzada = 0.0
	var a: Array = Botin.desde_texto("panal:1-2")
	Botin.tirada_forzada = 0.99
	var b: Array = Botin.desde_texto("panal:1-2")
	Botin.tirada_forzada = -1.0
	_ok("4 desde_texto: panal:1-2 da 1 con la tirada baja y 2 con la alta", _cuenta(a, "panal") == 1 and _cuenta(b, "panal") == 2, _lista_a_texto(a) + " | " + _lista_a_texto(b))
	_ok("4 desde_texto: pluma:1, - y vacío", _cuenta(Botin.desde_texto("pluma:1"), "pluma") == 1 and Botin.desde_texto("-").is_empty() and Botin.desde_texto("").is_empty())
	Botin.tirada_forzada = 0.0
	_ok("4 desde_texto: tabla:<id> tira esa tabla", _cuenta(Botin.desde_texto("tabla:cofre_pequeno"), "oro") == 10)
	Botin.tirada_forzada = -1.0
	var rc: Dictionary = Botin.fila_reactivo("colmena", "viento")
	var rh: Dictionary = Botin.fila_reactivo("hierba", "golpe")
	var rt: Dictionary = Botin.fila_reactivo("telarana", "hielo")
	_ok("4 fila_reactivo: colmena+viento panal:1-2 · hierba+golpe 60 s · telaraña+hielo seda:1", String(rc.get("botin", "")) == "panal:1-2" and int(rh.get("cada_s", 0)) == 60 and String(rt.get("botin", "")) == "seda:1", str(rc) + str(rh))
	_ok("4 fila_reactivo: una vía que no existe es vacía", Botin.fila_reactivo("colmena", "rayo").is_empty())


# ---------------------------------------------------------------------------------------------------------------------
func _suelo() -> void:
	Estado.i().items = {}
	Estado.i().capacidad = Estado.CAPACIDAD_INICIAL
	# Modelo o esfera con aro
	var con: BotinObjeto3D = BotinObjeto3D.soltar(_mundo, null, "seta", 1, Vector3.ZERO)
	var sin: BotinObjeto3D = BotinObjeto3D.soltar(_mundo, null, "panal", 1, Vector3.ZERO)
	await process_frame
	_ok("5 BotinObjeto3D con pieza (seta → setas_rojas) enseña el modelo", con.con_modelo and con.get_node_or_null("modelo") != null and BotinObjeto3D.ruta_modelo("seta") != "")
	_ok("5 BotinObjeto3D sin pieza (panal) enseña una esfera con el aro de su calidad", not sin.con_modelo and sin.get_node_or_null("esfera") != null and sin.get_node("esfera").get_node_or_null("aro_calidad") != null and BotinObjeto3D.ruta_modelo("panal") == "")
	_ok("5 el nombre del nodo es Botin_<id> (las pruebas antiguas lo buscan así)", con.name == "Botin_seta")
	con.queue_free()
	sin.queue_free()
	# Bolsa llena: una hucha de un solo hueco con 9 pociones (la pila de la poción) no admite nada más.
	Estado.i().capacidad = 1
	Estado.i().items = {"pocion": 9}
	var b: BotinObjeto3D = BotinObjeto3D.soltar(_mundo, null, "baya", 2, Vector3.ZERO)
	await process_frame
	var cogio: bool = b.recoger()
	_ok("6 con la bolsa llena no se coge y la pieza se queda en el suelo", not cogio and not b.recogido and is_instance_valid(b) and Estado.i().cuenta("baya") == 0)
	_ok("6 y avisa de que está llena (una sola vez)", b.llena_avisada)
	Estado.i().items = {}
	b._espera = 0.0
	_ok("6 al hacerse sitio se coge", b.recoger() and Estado.i().cuenta("baya") == 2)
	# Parte entra, el resto se queda esperando.
	Estado.i().capacidad = 1
	Estado.i().items = {"baya": 8}                                  # pila de 9... ver Objetos.pila
	var pila: int = Objetos.pila("baya")
	Estado.i().items = {"baya": pila - 1}
	var p: BotinObjeto3D = BotinObjeto3D.soltar(_mundo, null, "baya", 3, Vector3.ZERO)
	await process_frame
	_ok("6 si cabe solo parte (1 de 3), entra esa y el resto espera en el suelo", p.recoger() and Estado.i().cuenta("baya") == pila and p.cantidad == 2 and not p.recogido, "pila %d, quedan %d" % [pila, p.cantidad])
	p.queue_free()
	Estado.i().capacidad = Estado.CAPACIDAD_INICIAL
	Estado.i().items = {}
	# Botin.soltar: oro = la moneda de siempre; lo demás, BotinObjeto3D; sin oro (n = 0) no se crea nada
	var nodos: Array = Botin.soltar(_mundo, Vector3.ZERO, [{"que": "oro", "n": 7}, {"que": "pocion", "n": 1}, {"que": "baya", "n": 0}])
	await process_frame
	_ok("7 Botin.soltar: el oro es Combate3D.Botin3D (no se duplica), la poción un BotinObjeto3D y lo de cantidad 0 no existe", nodos.size() == 2 and nodos[0] is Combate3D.Botin3D and nodos[1] is BotinObjeto3D and (nodos[0] as Combate3D.Botin3D).cantidad == 7, str(nodos))
	_ok("7 Botin.soltar sin mundo 3D no hace nada", Botin.soltar(null, Vector3.ZERO, [{"que": "oro", "n": 1}]).is_empty())
	for nd in nodos:
		(nd as Node).queue_free()
	# Envoltorio BotinGoblin
	Botin.tirada_forzada = -1.0
	BotinGoblin.tirada_forzada = 0.99
	_ok("8 BotinGoblin.tirada_forzada es la de Botin", Botin.tirada_forzada == 0.99)
	BotinGoblin.tirada_forzada = -1.0
	_ok("8 BotinGoblin.soltar con tirada perdedora no da nada y con la ganadora da el colmillo a la bolsa (compatibilidad)",
		BotinGoblin.soltar(_mundo, Vector3.ZERO, 0.99) == "" and Estado.i().cuenta("colmillo_goblin") == 0 and BotinGoblin.soltar(_mundo, Vector3.ZERO, 0.0) == "colmillo_goblin" and Estado.i().cuenta("colmillo_goblin") == 1)
	Estado.i().items = {}


# ---------------------------------------------------------------------------------------------------------------------
const BASE: String = "; pieza b pulsador 1 1\n; pieza k compuerta 3 1\n"


func _expresiones() -> void:
	var r: Dictionary = Puzle3D.parsear(BASE + "; pieza c cofre 5 5 abre_si=tener.llave gasta=si da=tabla:cofre_pequeno\n; puzle r cuando=b.pulsado si=tener.llave+!tener.perla hace=k.abrir")
	var avisos: Array = r["avisos"]
	var reglas: Array = r["reglas"]
	var cofre: Variant = null
	for pz in r["piezas"]:
		if (pz as Puzle3D.Pieza).id == "c":
			cofre = pz
	_ok("9 tener.<objeto> se lee en una si= y en abre_si= sin avisos", avisos.is_empty() and not reglas.is_empty() and cofre != null, str(avisos))
	var expr: Array = reglas[0]["si_expr"] if not reglas.is_empty() else []
	var z := Puzle3D.new()
	Estado.i().items = {}
	var sin_llave: bool = z.cumple_expr(expr)
	Estado.i().items = {"llave": 1}
	var con_llave: bool = z.cumple_expr(expr)
	Estado.i().items = {"llave": 1, "perla": 1}
	var con_perla: bool = z.cumple_expr(expr)
	_ok("9 cumple_expr: tener.llave+!tener.perla — sin llave no, con llave sí, con llave y perla no", not sin_llave and con_llave and not con_perla, "%s %s %s" % [sin_llave, con_llave, con_perla])
	Estado.i().items = {}
	var mal: Dictionary = Puzle3D.parsear(BASE + "; puzle r cuando=b.pulsado si=tener.objeto_que_no_existe hace=k.abrir")
	_ok("9 tener.<objeto desconocido> es un aviso de línea y la regla no se monta", not (mal["avisos"] as Array).is_empty() and (mal["reglas"] as Array).is_empty(), str(mal["avisos"]))
	var tabla_mala: Dictionary = Puzle3D.parsear(BASE + "; pieza c cofre 5 5 da=tabla:no_existe")
	var mezcla: Dictionary = Puzle3D.parsear(BASE + "; pieza c cofre 5 5 da=oro:5+tabla:goblin")
	_ok("9 da=tabla:<id>: una tabla desconocida avisa; oro:5+tabla:goblin se lee como dos entradas", not (tabla_mala["avisos"] as Array).is_empty() and (mezcla["avisos"] as Array).is_empty()
		and ((mezcla["piezas"] as Array)[2] as Puzle3D.Pieza).p["da"].size() == 2 and String((((mezcla["piezas"] as Array)[2] as Puzle3D.Pieza).p["da"] as Array)[1].get("tabla", "")) == "goblin", str(tabla_mala["avisos"]) + str(mezcla["avisos"]))
	var reservada: Dictionary = Puzle3D.parsear("; pieza tener pulsador 1 1")
	_ok("9 «tener» es palabra reservada como «flag»", not (reservada["avisos"] as Array).is_empty())
	z.free()
	if cofre != null:
		_ok("9 el cofre guarda abre_si como expresión tener y gasta=si", ((cofre as Puzle3D.Pieza).exprs["abre_si"] as Array)[0][0]["tipo"] == "tener" and bool((cofre as Puzle3D.Pieza).p["gasta"]))


func _cofre() -> void:
	var z := Puzle3D.new()
	var r: Dictionary = Puzle3D.parsear(BASE + "; pieza c cofre 5 5 abre_si=tener.llave gasta=si da=tabla:cofre_pequeno")
	var pz: Puzle3D.Pieza = (r["piezas"] as Array)[2]
	var cf := Puzle3D.CofrePuzle.new()
	cf.expr_abre = pz.exprs["abre_si"]
	cf.puzle = z
	cf.gasta = true
	cf.da = pz.p["da"]
	cf.es_cerrado = true
	Estado.i().items = {}
	Estado.i().oro = 0
	var sin: bool = cf.abrir()
	_ok("10 sin llave el cofre sellado no se abre ni gasta nada", not sin and cf.es_cerrado and cf.gastado.is_empty())
	Estado.i().items = {"llave": 2}
	Botin.tirada_forzada = 0.0
	var con: bool = cf.abrir()
	Botin.tirada_forzada = -1.0
	_ok("10 con la llave se abre, la gasta (de 2 queda 1) y `gasta=si` lo anota", con and cf.es_abierto and Estado.i().cuenta("llave") == 1 and cf.gastado == ["llave"], str(Estado.i().items))
	_ok("10 da=tabla:cofre_pequeno: con la tirada baja dio 10 de oro (fila oro 10..20)", Estado.i().oro == 10 and _cuenta(cf.botin_dado, "oro") == 10, "oro %d %s" % [Estado.i().oro, _lista_a_texto(cf.botin_dado)])
	# gasta=no: la llave se queda
	var cf2 := Puzle3D.CofrePuzle.new()
	cf2.expr_abre = pz.exprs["abre_si"]
	cf2.puzle = z
	cf2.es_cerrado = true
	Estado.i().items = {"llave": 1}
	_ok("10 sin gasta=si el cofre se abre y la llave se queda en la bolsa", cf2.abrir() and Estado.i().cuenta("llave") == 1)
	Estado.i().items = {}
	Estado.i().oro = 0
	z.free()
	cf.free()
	cf2.free()


# ---------------------------------------------------------------------------------------------------------------------
func _runa(ruta: String) -> RuneData:
	return load(ruta) as RuneData


func _nuevo(tipo: String, retoques: Array = []) -> Reactivo3D:
	var r := Reactivo3D.new()
	var p := PackedStringArray()
	for t in retoques:
		p.append(String(t))
	r.papeles = p
	r.preparar(tipo, Vector2i(int(_x / 10.0) + 20, 3), "", _fx, null)
	r.position = Vector3(_x, 0.0, 0.0)
	_x += 10.0
	_mundo.add_child(r)
	return r


func _reactivos() -> void:
	var hielo: RuneData = _runa("res://nucleo/ice_rune.tres")
	var fuego: RuneData = _runa("res://nucleo/fire_rune.tres")
	# --- telaraña helable ---
	var tela: Reactivo3D = _nuevo("telarana")
	_ok("11 telaraña: con el hielo se hiela (previsión «hiela»), antes el frío no le hacía nada", tela.reaccion_a(hielo) == "hiela" and tela.spell_reacts(hielo))
	Terreno3D.bloquear_celda(tela.celda)
	tela.on_spell_hit(hielo)
	_ok("11 helada: ya no arde (el fuego no le hace nada) y no bloquea su casilla", tela.helada and not tela.can_burn() and tela.reaccion_a(fuego) == "" and not tela.spell_reacts(fuego) and not Terreno3D.bloqueada(tela.celda))
	Estado.i().items = {}
	_ok("11 se recoge con E (recoger_helado): da 1 de seda y desaparece", tela.recoger_helado() and Estado.i().cuenta("seda") == 1 and tela.cogida and not tela.recoger_helado(), str(Estado.i().items))
	# helada sin recoger con la bolsa llena
	var tela2: Reactivo3D = _nuevo("telarana")
	tela2.on_spell_hit(hielo)
	Estado.i().capacidad = 1
	Estado.i().items = {"pocion": 9}
	_ok("11 con la bolsa llena no se recoge y sigue helada", not tela2.recoger_helado() and tela2.helada and not tela2.cogida)
	Estado.i().capacidad = Estado.CAPACIDAD_INICIAL
	Estado.i().items = {}
	# una telaraña que ya arde no se hiela
	var tela3: Reactivo3D = _nuevo("telarana")
	tela3.ignite()
	_ok("11 una telaraña que arde no se hiela (solo la sana)", tela3.reaccion_a(hielo) != "hiela" or tela3.estado != Reactivo3D.EstadoObj.SANO)
	# --- árbol sacudible ---
	var arbol: Reactivo3D = _nuevo("arbol")
	_ok("12 árbol: papel sacudible y en el grupo del golpe F", arbol.tiene_papel(Reactivo3D.P_SACUDIBLE) and arbol.is_in_group(Reactivo3D.GRUPO_SACUDIBLE))
	Botin.tirada_forzada = 0.5                                       # tronco_golpe: nada 40 · resina 40 · corteza 20 → 0,5 = resina
	var l1: Array = arbol.sacudir(1000.0)
	var l2: Array = arbol.sacudir(1010.0)
	var l3: Array = arbol.sacudir(1031.0)
	Botin.tirada_forzada = -1.0
	_ok("12 sacudir suelta la tabla `tronco_golpe` (resina con 0,5), no vuelve a dar a los 10 s y sí a los 31", _cuenta(l1, "resina") == 1 and l2.is_empty() and _cuenta(l3, "resina") == 1 and arbol.sacudidas == 2, _lista_a_texto(l1) + "|" + _lista_a_texto(l2) + "|" + _lista_a_texto(l3))
	var otro: Reactivo3D = _nuevo("seto")
	_ok("12 sin el papel sacudible no suelta nada", otro.sacudir(5000.0).is_empty())
	var con_papel: Reactivo3D = _nuevo("seto", ["+sacudible"])
	_ok("12 `+sacudible` se lo da a cualquier pieza", con_papel.tiene_papel(Reactivo3D.P_SACUDIBLE))
	# --- seto quemado ---
	var seto: Reactivo3D = _nuevo("seto")
	Botin.tirada_forzada = 0.9                                       # seto_quemado: nada 70 · carbón 30 → 0,9 = carbón
	seto.ignite()
	seto._consumir()
	Botin.tirada_forzada = -1.0
	_ok("13 al consumirse un seto cae la tabla `seto_quemado` (carbón con 0,9)", _cuenta(seto.soltado, "carbon") == 1, _lista_a_texto(seto.soltado))
	var seto2: Reactivo3D = _nuevo("tronco")
	Botin.tirada_forzada = 0.0
	seto2.ignite()
	seto2._consumir()
	Botin.tirada_forzada = -1.0
	_ok("13 con la tirada baja el seto quemado no deja nada", seto2.soltado.is_empty())
	var tela4: Reactivo3D = _nuevo("telarana")
	Botin.tirada_forzada = 0.9
	tela4.ignite()
	tela4._consumir()
	Botin.tirada_forzada = -1.0
	_ok("13 la telaraña quemada no deja carbón (su botín es la seda helada)", tela4.soltado.is_empty())
	await process_frame


func _piezas_nuevas() -> void:
	var viento: RuneData = _runa("res://nucleo/wind_rune.tres")
	var fuego: RuneData = _runa("res://nucleo/fire_rune.tres")
	var agua: RuneData = _runa("res://nucleo/water_rune.tres")
	# --- colmena ---
	var cm := Colmena3D.new()
	cm.name = "colmena_p1"
	cm.preparar(Vector2i(30, 3), "PruebaBotin")
	_mundo.add_child(cm)
	Flags.i().quitar(cm.flag())
	_ok("14 la colmena reacciona al viento y al fuego, no al agua", cm.spell_reacts(viento) and cm.spell_reacts(fuego) and not cm.spell_reacts(agua) and cm.colgada)
	Botin.tirada_forzada = 0.99
	cm.on_spell_hit(viento)
	Botin.tirada_forzada = -1.0
	_ok("14 con viento cae el panal (1–2; 2 con la tirada alta), queda vacía y apunta la flag", _cuenta(cm.soltado, "panal") == 2 and cm.estado == "vacia" and not cm.colgada and Flags.i().tiene(cm.flag()), _lista_a_texto(cm.soltado))
	_ok("14 la flag tiene el nombre <nivel>.colmena.<id>", cm.flag() == "pruebabotin.colmena.colmena_p1")
	_ok("14 una vez caído, ni el viento ni el fuego repiten", cm.caer_panal().is_empty() and not cm.arder() and not cm.spell_reacts(viento))
	var cm2 := Colmena3D.new()
	cm2.name = "colmena_p2"
	cm2.preparar(Vector2i(31, 3), "PruebaBotin")
	_mundo.add_child(cm2)
	Flags.i().quitar(cm2.flag())
	cm2.on_spell_hit(fuego)
	_ok("14 con fuego arde: nube de veneno y NADA de panal; también gasta la flag", cm2.estado == "ardiendo" and cm2.soltado.is_empty() and Flags.i().tiene(cm2.flag()) and cm2.get_node_or_null("nube_veneno") != null)
	await create_timer(0.1).timeout
	cm2._t_nube = 0.05
	await create_timer(0.3).timeout
	_ok("14 a los 3 s (aquí acelerados) la nube se acaba y la colmena queda quemada", cm2.estado == "quemada" and cm2.get_node_or_null("nube_veneno") == null)
	var cm3 := Colmena3D.new()
	cm3.name = "colmena_p1"
	cm3.preparar(Vector2i(32, 3), "PruebaBotin")
	var otro_nivel := Node3D.new()                                   # mismo nombre bajo otro padre: como al recargar el nivel
	root.add_child(otro_nivel)
	otro_nivel.add_child(cm3)
	_ok("14 otra colmena con la flag ya puesta nace vacía (no se repite al recargar el nivel)", cm3.estado == "vacia" and not cm3.spell_reacts(viento))
	Flags.i().quitar(cm.flag())
	Flags.i().quitar(cm2.flag())
	# --- nido ---
	var ni := Nido3D.new()
	ni.name = "nido_p1"
	ni.preparar(Vector2i(33, 3))
	_mundo.add_child(ni)
	var p1: Array = ni.sacudir(2000.0)
	var p2: Array = ni.sacudir(2020.0)
	var p3: Array = ni.sacudir(2046.0)
	_ok("15 nido: el viento suelta una pluma, no otra a los 20 s y sí a los 46 (cada 45 s)", _cuenta(p1, "pluma") == 1 and p2.is_empty() and _cuenta(p3, "pluma") == 1 and ni.sacudidas == 2)
	_ok("15 el nido solo reacciona al viento", ni.spell_reacts(viento) and not ni.spell_reacts(fuego) and not ni.spell_reacts(agua))
	# --- hierba segada ---
	Botin.olvidar_hierba()
	Terreno3D.estados.limpiar()
	Botin.tirada_forzada = 0.9                                       # hierba_segada: nada 85 · baya 10 · flor 5 → 0,9 = baya
	var h1: Array = Botin.al_segar(_mundo, Vector2i(4, 4), 100.0)
	var h2: Array = Botin.al_segar(_mundo, Vector2i(4, 4), 130.0)
	var h3: Array = Botin.al_segar(_mundo, Vector2i(4, 4), 161.0)
	var h4: Array = Botin.al_segar(_mundo, Vector2i(5, 4), 101.0)
	Botin.tirada_forzada = -1.0
	_ok("16 hierba segada: da la tabla (baya con 0,9), una vez por casilla cada 60 s, y otra casilla es independiente", _cuenta(h1, "baya") == 1 and h2.is_empty() and _cuenta(h3, "baya") == 1 and _cuenta(h4, "baya") == 1, _lista_a_texto(h1))
	Terreno3D.estados.poner(Vector2i(6, 4), "quemada", true)
	Botin.tirada_forzada = 0.9
	var h5: Array = Botin.al_segar(_mundo, Vector2i(6, 4), 300.0)
	Botin.tirada_forzada = -1.0
	Terreno3D.estados.limpiar()
	_ok("16 la hierba que se quemó antes de segarse no da nada", h5.is_empty())
	Botin.olvidar_hierba()
	# --- geoda y cristal ---
	var ge := GeodaPulso3D.new()
	ge.preparar(Vector2i(34, 3), "", 1.0, null, 0.0)
	_mundo.add_child(ge)
	Botin.tirada_forzada = 0.99
	ge._explotar()
	Botin.tirada_forzada = -1.0
	_ok("17 la geoda al explotar deja ceniza_geoda 1–2 (2 con la tirada alta)", _cuenta(ge.ceniza, "ceniza_geoda") == 2, _lista_a_texto(ge.ceniza))
	var cr := CristalPulso3D.new()
	cr.name = "cristal_p1"
	cr.preparar(Vector2i(35, 3), 0.0, 4, null)
	_mundo.add_child(cr)
	Estado.i().items = {}
	var rayo: RuneData = _runa("res://nucleo/lightning_rune.tres")
	cr.on_spell_hit(rayo)
	_ok("17 un rayo carga el cristal 20 s", cr.cargado_s > 19.0)
	cr._enfriando = 0.0
	cr.on_spell_hit(rayo)
	_ok("17 la esquirla que suelta cargado es `cristal_cargado` y consume la carga", cr.esquirla_dada and cr.esquirla_objeto == "cristal_cargado" and Estado.i().cuenta("cristal_cargado") == 1 and cr.cargado_s == 0.0, str(Estado.i().items))
	var cr2 := CristalPulso3D.new()
	cr2.name = "cristal_p2"
	cr2.preparar(Vector2i(36, 3), 0.0, 4, null)
	_mundo.add_child(cr2)
	cr2.on_spell_hit(viento)
	cr2._enfriando = 0.0
	cr2.on_spell_hit(viento)
	_ok("17 sin rayo, la esquirla es la de siempre", cr2.esquirla_objeto == "esquirla_cristal" and Estado.i().cuenta("esquirla_cristal") == 1)
	Estado.i().items = {}
	# --- lava: basalto u obsidiana ---
	var lv := Lava3D.new()
	lv.name = "lava_p"
	lv.preparar([Vector2i(40, 3), Vector2i(41, 3), Vector2i(43, 3)], 0.0)
	_mundo.add_child(lv)
	lv.enfriar_en(Vector2i(40, 3), Lava3D.VIA_HIELO)
	lv.enfriar_en(Vector2i(43, 3), Lava3D.VIA_AGUA)
	_ok("18 lava: la roca recuerda con qué se enfrió (hielo → obsidiana, agua → basalto)", lv.via_de_roca(Vector2i(40, 3)) == Lava3D.VIA_HIELO and lv.via_de_roca(Vector2i(41, 3)) == Lava3D.VIA_HIELO and lv.via_de_roca(Vector2i(43, 3)) == Lava3D.VIA_AGUA and lv.via_de_roca(Vector2i(44, 3)) == "")
	var b1 := Recolectable3D.new()
	b1.name = "basalto_p1"
	b1.preparar(Vector2i(40, 3), "", 0.0, null, "basalto")
	_mundo.add_child(b1)
	var b2 := Recolectable3D.new()
	b2.name = "basalto_p2"
	b2.preparar(Vector2i(43, 3), "", 0.0, null, "basalto")
	_mundo.add_child(b2)
	b1.recoger()
	b2.recoger()
	_ok("18 el basalto sobre roca de hielo se coge como obsidiana; sobre roca de agua, basalto", Estado.i().cuenta("obsidiana") == 1 and Estado.i().cuenta("basalto") == 1, str(Estado.i().items))
	Estado.i().items = {}
	# --- plantas nuevas ---
	var pl: Array = []
	for planta in ["musgo", "helecho_cueva", "seta_palida"]:
		var rc := Recolectable3D.new()
		rc.name = "planta_" + planta
		rc.preparar(Vector2i(50, 3), "", 0.0, null, planta)
		_mundo.add_child(rc)
		pl.append([planta, rc.objeto, rc.recoger(), Estado.i().cuenta(rc.objeto), rc._id_visual()])
	_ok("19 plantas nuevas: musgo → musgo_cueva, helecho_cueva y seta_palida se cogen y usan el `modelo` de su columna", str(pl) == '[["musgo", "musgo_cueva", true, 1, "musgo_colgante"], ["helecho_cueva", "helecho_cueva", true, 1, "helechos_cueva"], ["seta_palida", "seta_palida", true, 1, "setas_marrones"]]', str(pl))
	Estado.i().items = {}
	await process_frame
