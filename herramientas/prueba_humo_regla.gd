extends SceneTree

## PRUEBA del HUMO POR REGLA (9/11/2026, presentacion/vfx/toy/humo_regla.gd). Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_humo_regla.gd
## Comprueba:
##   1. LA REGLA (funciones puras): una bocanada RÁPIDA apenas hace hollín y una LENTA mucho; contra el viento, lo que va con él es «lento»; el hollín se DESVANECE; el polvo solo sale con aire rápido (> 0,8 m/s)
##      y cerca del suelo (cae con la altura)
##   2. EL EMISOR: lo mismo con bocanadas de verdad; lo limpio no se dibuja (visible 0); el tono sube con el hollín; TOPES (bocanadas vivas y emisores) y que se libera solo
##   3. INTERRUPTORES: todos apagados por defecto; con todos apagados ningún efecto crea nada (ni nodos, ni emisores)
##   4. DÓNDE NACE: la bola EN VUELO no suelta nada y al CHOCAR sí (y el rebote y el barril no duplican); cima de muro y pilar (arriba, no en el pie); el haz solo con choque y en el choque; el barril un solo emisor;
##      vapor con agua sobre fuego; polvo en tierra y viento solo contra el SUELO (no en pared); el suelo ardiendo solo con fuego pleno
##   5. LAB: la tecla 8 enciende y apaga todas las capas
## Imprime FALLOS: n.

var _fallos: int = 0
var _raiz: Node3D = null


func _initialize() -> void:
	_correr()


func _ok(nombre: String, cond: bool, detalle: String = "") -> void:
	if cond:
		print("  OK   " + nombre)
	else:
		_fallos += 1
		print("  FALLO " + nombre + ("  (" + detalle + ")" if detalle != "" else ""))


func _esperar(s: float) -> void:
	await create_timer(s).timeout


func _correr() -> void:
	await process_frame
	_raiz = Node3D.new()
	root.add_child(_raiz)
	_defecto()
	_regla()
	_emisor()
	await _emisor_libera()
	await _nace_donde_debe()
	await _lab()
	print("FALLOS: %d" % _fallos)
	quit(0 if _fallos == 0 else 1)


## Todos los emisores vivos del árbol (HumoRegla).
func _hr() -> Array:
	var r: Array = []
	for n in root.find_children("*", "Node3D", true, false):
		if n is HumoRegla:
			r.append(n)
	return r


func _emi(n: Node) -> HumoRegla:
	return n.get_meta(&"humo_regla_emisor") as HumoRegla if n.has_meta(&"humo_regla_emisor") else null


func _limpiar() -> void:
	for c in _raiz.get_children():
		_raiz.remove_child(c)
		c.queue_free()


# ------------------------------------------------------------------ 3. interruptores ------------------------------------------------------------------

func _defecto() -> void:
	print("== interruptores de serie (impacto_bola, barril, suelo y vapor encendidas; el resto apagadas)")
	_ok("hay diez capas", HumoRegla.capas.size() == 10)
	var serie: Array = ["impacto_bola", "barril", "suelo", "vapor"]
	for k in ["impacto_bola", "muro", "pilar", "barril", "haz", "dragon", "suelo", "vapor", "polvo_tierra", "polvo_viento"]:
		_ok("capa «%s» de serie %s" % [k, "encendida" if k in serie else "apagada"], HumoRegla.capas.has(k) and bool(HumoRegla.capas[k]) == (k in serie))
	# el resto de la prueba parte de todo apagado
	HumoRegla.poner_todas(false)
	_ok("con poner_todas(false), todas apagadas", not HumoRegla.hay_alguna())
	_ok("las capas viejas de FuegoToy siguen apagadas y sin tocar", not FuegoToy.formas_extra["humo_cima_muro"] and not FuegoToy.formas_extra["humo_cima_pilar"] and FuegoToy.formas_extra.size() == 7)
	# con todo apagado, los enganches no crean nada
	var padre: Node3D = Node3D.new()
	_raiz.add_child(padre)
	_ok("apagado: vapor → null", HumoRegla.enganchar_vapor(padre, Vector3.ZERO) == null)
	_ok("apagado: suelo → null", HumoRegla.enganchar_suelo(padre, 0.5) == null)
	_ok("apagado: dragón → null", HumoRegla.enganchar_dragon(padre, Vector3.ZERO, Vector3.RIGHT) == null)
	_ok("apagado: ningún emisor en el árbol", _hr().is_empty())
	_limpiar()


# ------------------------------------------------------------------ 1. la regla ------------------------------------------------------------------

## Simula una bocanada que sale con T = 1 a `v` (rapidez relativa al aire, constante) durante `seg` s y devuelve [hollín final, hollín máximo].
func _simular(v: float, seg: float, rend: float = 1.3) -> Array:
	var t: float = 1.0
	var h: float = 0.0
	var mx: float = 0.0
	var dt: float = 1.0 / 60.0
	for i in int(seg / dt):
		var r: Vector2 = HumoRegla.paso_calor(t, h, v, dt, rend, HumoRegla.OLVIDO_HOLLIN)
		t = r.x
		h = r.y
		mx = maxf(mx, h)
	return [h, mx, t]


func _regla() -> void:
	print("== la regla")
	_ok("lento: muy rápido → 0", is_zero_approx(HumoRegla.lento_de(8.0)))
	_ok("lento: parado → 1", is_equal_approx(HumoRegla.lento_de(0.0), 1.0))
	_ok("lento baja con la velocidad", HumoRegla.lento_de(2.0) > HumoRegla.lento_de(3.0) and HumoRegla.lento_de(3.0) > HumoRegla.lento_de(4.5))
	var rapida: Array = _simular(8.0, 2.0)
	var lenta: Array = _simular(0.8, 2.0)
	var media: Array = _simular(3.2, 2.0)
	_ok("bocanada RÁPIDA → casi nada de hollín (máx < 0,15)", float(rapida[1]) < 0.15, str(rapida))
	_ok("bocanada LENTA → mucho hollín (máx > 0,5)", float(lenta[1]) > 0.5, str(lenta))
	_ok("rápida < media < lenta", float(rapida[1]) < float(media[1]) and float(media[1]) < float(lenta[1]), "%s %s %s" % [rapida[1], media[1], lenta[1]])
	_ok("la lenta se enfría más deprisa que la rápida (T a los 2 s)", float(lenta[2]) < float(rapida[2]), "%s vs %s" % [lenta[2], rapida[2]])
	# el calor perdido es lo que se vuelve hollín: sin enfriarse no hay hollín
	var r0: Vector2 = HumoRegla.paso_calor(0.0, 0.0, 0.0, 0.1, 1.3, 0.45)
	_ok("sin calor no hay hollín nuevo", is_zero_approx(r0.y))
	# el hollín se desvanece: con T = 0 (nada más que perder) decae como exp(-0,45 t)
	var h1: Vector2 = Vector2(0.0, 0.8)
	for i in 120:
		h1 = HumoRegla.paso_calor(h1.x, h1.y, 0.0, 1.0 / 60.0, 1.3, HumoRegla.OLVIDO_HOLLIN)
	_ok("el hollín se desvanece (2 s → ×exp(−0,9))", absf(h1.y - 0.8 * exp(-0.9)) < 0.01, str(h1.y))
	# viento: lo que va CON el viento es lento (rapidez relativa 0), aunque vaya a 8 m/s respecto al suelo
	var rel: float = (Vector3(8, 0, 0) - Vector3(8, 0, 0)).length()
	_ok("viento: igual al aire → lento", is_equal_approx(HumoRegla.lento_de(rel), 1.0))
	# polvo
	_ok("polvo: aire de 0,5 m/s → nada", is_zero_approx(HumoRegla.polvo_alzado(0.5, 0.0)))
	_ok("polvo: aire de 4 m/s a ras de suelo → algo", HumoRegla.polvo_alzado(4.0, 0.0) > 2.0)
	_ok("polvo: cae con la altura (1 m → ×0,04)", HumoRegla.polvo_alzado(4.0, 1.0) < HumoRegla.polvo_alzado(4.0, 0.0) * 0.06)
	_ok("polvo: más aire, más polvo", HumoRegla.polvo_alzado(6.0, 0.1) > HumoRegla.polvo_alzado(3.0, 0.1))
	_ok("visible: hollín 0 no se dibuja, hollín 0,5 sí", is_zero_approx(HumoRegla.visible_de(0.0)) and HumoRegla.visible_de(0.5) > 0.99)


# ------------------------------------------------------------------ 2. el emisor ------------------------------------------------------------------

func _emisor() -> void:
	print("== el emisor")
	var base: Dictionary = {"n": 8, "arrastre": 0.0, "flota": 0.0, "sube": 0.0}
	var e: HumoRegla = HumoRegla.crear(HumoRegla.Materia.HUMO, _raiz, Vector3.ZERO, base)
	_ok("crea un emisor de humo", e != null and e.get_parent() == _raiz)
	var rap: int = e.soltar(Vector3.ZERO, Vector3(8, 0, 0))
	var len_: int = e.soltar(Vector3(0, 5, 0), Vector3(0.6, 0, 0))
	for i in 90:
		e.avanzar(1.0 / 60.0)
	var est: Array = e.estados()
	var er: Dictionary = {}
	var el: Dictionary = {}
	for d in est:
		if int(d["hueco"]) == rap:
			er = d
		if int(d["hueco"]) == len_:
			el = d
	_ok("la rápida sigue viva a 1,5 s y no se ve (hollín < 0,1, visible 0)", not er.is_empty() and float(er["hollin"]) < 0.1 and float(er["visible"]) < 0.5, str(er))
	_ok("la lenta se ve (hollín > 0,3, visible > 0,9)", not el.is_empty() and float(el["hollin"]) > 0.3 and float(el["visible"]) > 0.9, str(el))
	_ok("la lenta se mueve con su velocidad y la rápida con la suya", (er["pos"] as Vector3).x > 10.0 and (el["pos"] as Vector3).x < 1.5)
	# con arrastre y flotación (valores por defecto): sube mientras está caliente
	var e2: HumoRegla = HumoRegla.crear(HumoRegla.Materia.HUMO, _raiz, Vector3.ZERO, {"n": 4})
	e2.soltar(Vector3.ZERO, Vector3(0, 0.5, 0))
	for i in 60:
		e2.avanzar(1.0 / 60.0)
	var e2b: HumoRegla = HumoRegla.crear(HumoRegla.Materia.HUMO, _raiz, Vector3.ZERO, {"n": 4, "flota": 0.0, "sube": 0.0})
	e2b.soltar(Vector3.ZERO, Vector3(0, 0.5, 0))
	for i in 60:
		e2b.avanzar(1.0 / 60.0)
	_ok("el humo flota (sube más que sin flotación)", (e2.estados()[0]["pos"] as Vector3).y > (e2b.estados()[0]["pos"] as Vector3).y + 0.1, "%s vs %s" % [e2.estados()[0]["pos"], e2b.estados()[0]["pos"]])
	# viento: una bocanada que va con el aire, lenta respecto a él → hollín; deriva con él
	var e3: HumoRegla = HumoRegla.crear(HumoRegla.Materia.HUMO, _raiz, Vector3.ZERO, {"n": 4, "viento": Vector3(8, 0, 0), "arrastre": 0.0, "flota": 0.0, "sube": 0.0})
	e3.soltar(Vector3.ZERO, Vector3(8, 0, 0))
	for i in 90:
		e3.avanzar(1.0 / 60.0)
	_ok("con viento: la que va a la velocidad del aire (lenta respecto a él) hace hollín", float(e3.hollin_max()) > 0.4, str(e3.hollin_max()))
	# vapor y polvo: otras materias
	var ev: HumoRegla = HumoRegla.crear(HumoRegla.Materia.VAPOR, _raiz, Vector3.ZERO, {"n": 4})
	_ok("existe la materia VAPOR (paleta blanca)", ev != null and (ev.p["claro"] as Color).v > 0.9)
	var ep: HumoRegla = HumoRegla.crear(HumoRegla.Materia.POLVO, _raiz, Vector3.ZERO, {"n": 4})
	_ok("existe la materia POLVO (paleta terrosa)", ep != null and (ep.p["claro"] as Color).r > (ep.p["claro"] as Color).b)
	_limpiar()
	# polvo: aire lento no levanta; aire rápido sí; solo a ras de suelo
	var lento: HumoRegla = HumoRegla.crear(HumoRegla.Materia.POLVO, _raiz, Vector3.ZERO, {"n": 40})
	lento.anadir_aire(Vector3.ZERO, 0.5, 0.6, 0.6, 200.0)
	var rapido: HumoRegla = HumoRegla.crear(HumoRegla.Materia.POLVO, _raiz, Vector3.ZERO, {"n": 40})
	rapido.anadir_aire(Vector3.ZERO, 0.5, 5.0, 0.6, 200.0)
	for i in 36:
		lento.avanzar(1.0 / 60.0)
		rapido.avanzar(1.0 / 60.0)
	_ok("polvo: aire de 0,6 m/s no levanta nada", lento.emitidas == 0, str(lento.emitidas))
	_ok("polvo: aire de 5 m/s levanta", rapido.emitidas >= 4, str(rapido.emitidas))
	var alto: float = 0.0
	for d in rapido.estados():
		alto = maxf(alto, (d["pos"] as Vector3).y)
	_ok("polvo: nace a ras de suelo (< 0,5 m al principio)", alto < 0.5, str(alto))
	_limpiar()
	# topes
	var es: Array = []
	for i in HumoRegla.MAX_EMISORES + 3:
		var x: HumoRegla = HumoRegla.crear(HumoRegla.Materia.HUMO, _raiz, Vector3.ZERO, {"n": 24})
		if x != null:
			es.append(x)
			for k in 24:
				x.soltar(Vector3.ZERO, Vector3.ZERO)
	_ok("tope de emisores (%d)" % HumoRegla.MAX_EMISORES, es.size() <= HumoRegla.MAX_EMISORES and HumoRegla.emisores() <= HumoRegla.MAX_EMISORES, "%d" % es.size())
	_ok("tope de bocanadas vivas en toda la escena (%d)" % HumoRegla.MAX_VIVAS, HumoRegla.vivas_global() <= HumoRegla.MAX_VIVAS and HumoRegla.vivas_global() > HumoRegla.MAX_VIVAS - 30, str(HumoRegla.vivas_global()))
	_limpiar()


## Un emisor cerrado se libera solo cuando se va la última bocanada.
func _emisor_libera() -> void:
	var e: HumoRegla = HumoRegla.crear(HumoRegla.Materia.HUMO, _raiz, Vector3.ZERO, {"n": 4, "vida": 0.4})
	e.soltar(Vector3.ZERO, Vector3.ZERO, 1.0, 1.0, 1.0)
	e.cerrar()
	await _esperar(1.0)
	_ok("un emisor cerrado se libera solo al morir su última bocanada", not is_instance_valid(e) or e.is_queued_for_deletion())
	_limpiar()


# ------------------------------------------------------------------ 4. dónde nace ------------------------------------------------------------------

func _nace_donde_debe() -> void:
	print("== dónde nace cada capa")
	# --- impacto de la bola: en vuelo nada, al chocar sí ---
	HumoRegla.poner_todas(true)
	var bola: FuegoToy = FuegoToy.new()
	bola.definir(FuegoToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	_raiz.add_child(bola)
	bola.global_position = Vector3(0, 1, 0)
	bola.lanzar(-1.0)
	for i in 10:
		bola.global_position += Vector3(0.3, 0, 0)
		await process_frame
	_ok("bola EN VUELO (capas encendidas): ningún emisor", _hr().is_empty(), str(_hr().size()))
	var dest: Vector3 = bola.global_position
	var imp: Node3D = bola.impactar_en(dest, Vector3(-1, 0, 0), 0.4)
	await process_frame
	await process_frame
	_ok("al CHOCAR: se crea el impacto y UN emisor de humo", imp is ImpactoFuegoToy and _hr().size() == 1, str(_hr().size()))
	var h: HumoRegla = _hr()[0] if not _hr().is_empty() else null
	if h != null:
		await _esperar(0.3)
		_ok("el emisor está en el choque (hay bocanadas vivas junto al punto)", h.vivas() >= 8 and (h.estados()[0]["pos"] as Vector3).distance_to(dest) < 1.5)
		await _esperar(0.9)
		_ok("al principio no hay humo y luego se ve: el hollín crece al frenarse (> 0,3 en 0,9 s)", h.hollin_max() > 0.3, str(h.hollin_max()))
		var lejos: float = 0.0
		for d in h.estados():
			lejos = maxf(lejos, (d["pos"] as Vector3).distance_to(dest))
		_ok("las bocanadas salen hacia delante de la superficie y se frenan cerca (< 3 m)", lejos < 3.0, str(lejos))
	await _esperar(2.6)
	_ok("el emisor del choque se libera solo", _hr().is_empty(), str(_hr().size()))
	_limpiar()
	# el rebote y el FIN no sueltan
	var r1: Node3D = ImpactoFuegoToy.crear(ImpactoFuegoToy.Variante.REBOTE, Vector3.UP, 0.4)
	var r2: Node3D = ImpactoFuegoToy.crear(ImpactoFuegoToy.Variante.FIN, Vector3.UP, 0.4)
	_raiz.add_child(r1)
	_raiz.add_child(r2)
	await process_frame
	await process_frame
	_ok("el rebote y el FIN (se agota en el aire) no sueltan humo", _hr().is_empty(), str(_hr().size()))
	_limpiar()
	# con la capa apagada, el choque no crea nada
	HumoRegla.poner_todas(false)
	var b2: FuegoToy = FuegoToy.new()
	b2.definir(FuegoToy.Figura.BOLA, 0.4, 0.4, 0.4, true)
	_raiz.add_child(b2)
	b2.lanzar(-1.0)
	b2.impactar_en(Vector3(2, 0, 0), Vector3.UP, 0.4)
	await process_frame
	await process_frame
	_ok("capa apagada: el choque no crea ningún emisor", _hr().is_empty())
	_limpiar()

	# --- cima de muro y pilar ---
	for fig in [[FuegoToy.Figura.MURO, "muro", Vector3(3.45, 1.5, 0.3)], [FuegoToy.Figura.PILAR, "pilar", Vector3(0.5, 4.0, 0.5)]]:
		var clave: String = fig[1]
		var s: Vector3 = fig[2]
		HumoRegla.poner_todas(false)
		HumoRegla.capas[clave] = true
		var f: FuegoToy = FuegoToy.new()
		f.definir(fig[0], s.x, s.y, s.z, false)
		_raiz.add_child(f)
		f.global_position = Vector3(10, 0, 0)
		f.lanzar(-1.0)
		await _esperar(1.4)
		var hf: HumoRegla = _emi(f)
		_ok("%s: hay un emisor que sigue al toy" % clave, hf != null)
		if hf != null:
			_ok("%s: ha soltado bocanadas" % clave, hf.emitidas >= 2, str(hf.emitidas))
			var min_y: float = 99.0
			for d in hf.estados():
				min_y = minf(min_y, (d["pos"] as Vector3).y)
			_ok("%s: nacen en la parte alta de la llama (nada por debajo de 0,15 · alto)" % clave, min_y > s.y * 0.15, "min y %.2f de alto %.2f" % [min_y, s.y])
		HumoRegla.capas[clave] = false
		f.reconstruir()
		_ok("%s: apagada la capa y reconstruido, el emisor desaparece" % clave, not f.has_meta(&"humo_regla_emisor"))
		_limpiar()
		await process_frame
	# la capa «muro» no enciende el pilar
	HumoRegla.poner_todas(false)
	HumoRegla.capas["muro"] = true
	var fp: FuegoToy = FuegoToy.new()
	fp.definir(FuegoToy.Figura.PILAR, 0.5, 4.0, 0.5, false)
	_raiz.add_child(fp)
	fp.lanzar(-1.0)
	await process_frame
	_ok("la capa «muro» no se enciende en un pilar", not fp.has_meta(&"humo_regla_emisor"))
	_limpiar()

	# --- haz: solo con choque y en el choque ---
	HumoRegla.poner_todas(false)
	HumoRegla.capas["haz"] = true
	var hz_sin: FuegoToy = FuegoToy.new()
	hz_sin.definir(FuegoToy.Figura.HAZ, 1.5, 0.5, 0.15, false)
	_raiz.add_child(hz_sin)
	hz_sin.lanzar(-1.0)
	await process_frame
	_ok("haz SIN choque (la punta acaba al aire): sin emisor", not hz_sin.has_meta(&"humo_regla_emisor"))
	var hz: FuegoToy = FuegoToy.new()
	hz.definir(FuegoToy.Figura.HAZ, 1.5, 0.5, 0.15, false)
	hz.choques = [{"d": 2.0, "x": 0.0, "n": Vector3(0, 0, 1)}]
	_raiz.add_child(hz)
	hz.global_position = Vector3(0, 0, 20)
	hz.lanzar(-1.0)
	await _esperar(0.9)
	var hh: HumoRegla = _emi(hz)
	_ok("haz CON choque: un emisor", hh != null)
	if hh != null:
		var zs: Array = []
		for d in hh.estados():
			zs.append((d["pos"] as Vector3).z - 20.0)
		_ok("las bocanadas están junto al choque (z ≈ −2 ± 2)", not zs.is_empty() and zs.all(func(z: float) -> bool: return absf(z + 2.0) < 2.5), str(zs))
	_limpiar()

	# --- barril: UN emisor (los impactos internos no duplican) ---
	HumoRegla.poner_todas(true)
	var ex: ExplosionFuegoToy = ExplosionFuegoToy.crear(2.6)
	_raiz.add_child(ex)
	ex.global_position = Vector3(30, 0, 0)
	await process_frame
	await process_frame
	await process_frame
	_ok("barril: exactamente UN emisor aunque estén todas las capas (el impacto interno no suelta)", _hr().size() == 1, str(_hr().size()))
	HumoRegla.poner_todas(false)
	_limpiar()
	await process_frame
	var ex2: ExplosionFuegoToy = ExplosionFuegoToy.crear(2.6)
	_raiz.add_child(ex2)
	await process_frame
	await process_frame
	_ok("barril con la capa apagada: ninguno", _hr().is_empty())
	_limpiar()

	# --- dragón (el enganche) ---
	HumoRegla.poner_todas(false)
	_ok("dragón apagado: nada", HumoRegla.enganchar_dragon(_raiz, Vector3.ZERO, Vector3.RIGHT) == null)
	HumoRegla.capas["dragon"] = true
	var dr: HumoRegla = HumoRegla.enganchar_dragon(_raiz, Vector3(5, 1, 0), Vector3.RIGHT)
	if dr != null:
		dr.avanzar(0.2)
	_ok("dragón encendido: un emisor en la punta del chorro", dr != null and dr.vivas() >= 3 and (dr.estados()[0]["pos"] as Vector3).distance_to(Vector3(5, 1, 0)) < 1.0)
	HumoRegla.capas["dragon"] = false
	_limpiar()

	# --- suelo ardiendo: solo fuego pleno ---
	HumoRegla.capas["suelo"] = true
	var fx: Vfx3D = Vfx3D.new()
	_raiz.add_child(fx)
	var l_prende: Node3D = fx.llamas(Vector3.ZERO, 0.5, 0.5)
	var l_brasero: Node3D = fx.llamas(Vector3(3, 0, 0), 1.0, 0.3, 1)
	var l_hierba: Node3D = fx.llamas(Vector3(6, 0, 0), 1.0, 0.5)
	_ok("suelo: prendiendo (0,5) no suelta", l_prende.get_node_or_null("HumoReglaSuelo") == null)
	_ok("suelo: un brasero (una lengua) no suelta", l_brasero.get_node_or_null("HumoReglaSuelo") == null)
	_ok("suelo: la hierba ardiendo sí", l_hierba.get_node_or_null("HumoReglaSuelo") != null)
	HumoRegla.capas["suelo"] = false
	_limpiar()

	# --- vapor ---
	HumoRegla.poner_todas(false)
	var ia: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.GOLPE, Vector3.UP, 0.4)
	_raiz.add_child(ia)
	await process_frame
	await process_frame
	_ok("vapor apagado: el agua no levanta vapor", _hr().is_empty())
	_limpiar()
	HumoRegla.capas["vapor"] = true
	var ib: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.GOLPE, Vector3.UP, 0.4)
	_raiz.add_child(ib)
	await process_frame
	await process_frame
	_ok("vapor encendido pero agua sobre algo que NO arde: nada", _hr().is_empty())
	_limpiar()
	var ic: ImpactoAguaToy = ImpactoAguaToy.crear(ImpactoAguaToy.Variante.GOLPE, Vector3.UP, 0.4)
	ic.sobre_fuego = true
	_raiz.add_child(ic)
	await process_frame
	await process_frame
	var hv: Array = _hr()
	_ok("agua sobre fuego: un emisor de VAPOR", hv.size() == 1 and (hv[0] as HumoRegla).materia == HumoRegla.Materia.VAPOR, str(hv.size()))
	_limpiar()
	await process_frame
	var fv: Vfx3D = Vfx3D.new()
	_raiz.add_child(fv)
	fv.vapor(Vector3(2, 0, 2))
	_ok("Vfx3D.vapor (el vapor ya existente del juego) también suelta vapor por regla", _hr().size() == 1)
	_limpiar()
	await process_frame

	# --- polvo: solo contra el suelo ---
	for par in [["polvo_tierra", "tierra"], ["polvo_viento", "viento"]]:
		HumoRegla.poner_todas(false)
		HumoRegla.capas[par[0]] = true
		var sue: Node3D = ImpactoTierraToy.crear(ImpactoTierraToy.Variante.GOLPE, Vector3.UP, 0.4) if par[1] == "tierra" else ImpactoVientoToy.crear(ImpactoVientoToy.Variante.GOLPE, Vector3.UP, 0.4)
		var par_: Node3D = ImpactoTierraToy.crear(ImpactoTierraToy.Variante.GOLPE, Vector3(1, 0, 0), 0.4) if par[1] == "tierra" else ImpactoVientoToy.crear(ImpactoVientoToy.Variante.GOLPE, Vector3(1, 0, 0), 0.4)
		_raiz.add_child(par_)
		await process_frame
		await process_frame
		_ok("%s: contra una PARED no levanta polvo" % par[1], _hr().is_empty())
		_limpiar()
		await process_frame
		_raiz.add_child(sue)
		sue.global_position = Vector3(0, 0.5, 0)
		await process_frame
		await process_frame
		await _esperar(0.3)
		var hp: Array = _hr()
		_ok("%s: contra el SUELO, un emisor de POLVO" % par[1], hp.size() == 1 and (hp[0] as HumoRegla).materia == HumoRegla.Materia.POLVO, str(hp.size()))
		if hp.size() == 1:
			_ok("%s: el polvo ha salido (bocanadas) y a ras del suelo" % par[1], (hp[0] as HumoRegla).emitidas >= 3, str((hp[0] as HumoRegla).emitidas))
		_limpiar()
		await process_frame
	HumoRegla.poner_todas(false)


# ------------------------------------------------------------------ 5. lab ------------------------------------------------------------------

func _lab() -> void:
	print("== lab: la tecla 8")
	var src: String = FileAccess.get_file_as_string("res://laboratorios/lab_vfx_comparativa_3d.gd")
	_ok("el lab tiene la tecla 8", src.find("KEY_8: alternar_humo_regla()") >= 0)
	HumoRegla.poner_todas(false)
	var lab: Node3D = (load("res://laboratorios/LabVfxComparativa3D.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	_ok("el lab arranca con el humo por regla apagado", not HumoRegla.hay_alguna())
	lab.call("alternar_humo_regla")
	var todas: bool = true
	for k in HumoRegla.capas:
		todas = todas and bool(HumoRegla.capas[k])
	_ok("8 enciende TODAS las capas", todas)
	lab.call("alternar_humo_regla")
	_ok("8 otra vez las apaga todas", not HumoRegla.hay_alguna())
	# con la tecla encendida, F7 muro suelta humo y B con agua levanta vapor
	lab.call("alternar_humo_regla")
	var m: Node3D = lab.call("fuego_param", 1)
	await _esperar(1.0)
	_ok("lab con 8: el muro de F7 lleva su humo por regla", m.has_meta(&"humo_regla_emisor"))
	lab.call("poner_elemento", "agua")
	var ia: Node3D = lab.call("impacto_pared")
	_ok("lab con 8: el impacto de agua se marca sobre fuego", ia is ImpactoAguaToy and (ia as ImpactoAguaToy).sobre_fuego)
	lab.call("alternar_humo_regla")
	lab.call("limpiar")
	lab.queue_free()
	await process_frame
	HumoRegla.poner_todas(false)
