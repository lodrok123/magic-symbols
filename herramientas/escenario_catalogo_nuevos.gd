extends "res://herramientas/escenario_base.gd"
## CATÁLOGO 24/11: LAS PLANTILLAS NUEVAS, LAS SALAS DEL JEFE Y EL FILTRO DE RUNAS, EN EL JUEGO.
## Pablo: «puzles con la carretilla (a mano y con mecanismos)», «el catálogo es escaso», «salas de jefe para el gólem (cueva) y el elemental
## (bosque)» y «filtrar por las runas de la jugadora, con búsqueda a mano para lo que no se pueda resolver».
## 1. Cada plantilla nueva se pone a mano en un mapa de salas (kit «demo»: fuego, agua, tierra, flecha, línea, barrera, altura, ᚱ, suelo), se exporta,
##    se carga y se RESUELVE como la jugadora: hechizos de verdad (`lanzar_pagina_ya`) y empujones (`empujar`, lo que dispara el empuje andando). La
##    aguja se cambia con `cambiar` (lo que hace el golpe de un hechizo a su palanca: `on_spell_hit`).
## 2. Salas del jefe: cueva → gólem con dos limos, cerrojo y cofre legendario; bosque → elemental sin cerrojo. La de la cueva, en el juego: se
##    cierra al entrar y, caídos los tres (por código: aquí no se prueba el combate), se abre y aparece el cofre.
## 3. Filtro: con el kit «demo_inicio» (fuego, flecha, barrera) solo se reparten puzles que se resuelven con eso; uno puesto a mano que no, avisa.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_catalogo_nuevos.gd

const Generador = preload("res://herramientas/generador_mapas/generador_mazmorra.gd")
const Exportador = preload("res://herramientas/generador_mapas/exportador_mapa.gd")
const Catalogo = preload("res://herramientas/generador_mapas/catalogo_puzles.gd")
const NOMBRE: String = "ZzCatNuevos"
const T_TINTA_MAX_S: float = 6.0

var _pz: Puzle3D = null
var _pre: String = "cat1_"


func _escenario() -> void:
	Catalogo.recargar()
	var cat: Dictionary = Catalogo.todos()
	var nuevas: Array = ["vagoneta_pista", "vagoneta_curva", "vagoneta_boton", "vagoneta_aguja", "barril_muro", "balanza_rocas",
		"cristal_receptor", "prisma_rojo_azul", "pared_hueca_nicho", "estatuas_sellos", "presa_barril"]
	_ok("0 el catálogo tiene %d plantillas (22 o más)" % cat.size(), cat.size() >= 22)
	var sin_nec: Array = cat.keys().filter(func(c) -> bool: return not FileAccess.get_file_as_string(Catalogo.CARPETA + String(c) + ".txt").contains("; necesita"))
	_ok("0 todas dicen lo que necesitan (; necesita)", sin_nec.is_empty(), str(sin_nec))
	for cid in nuevas:
		if not await _cargar_con(cid):
			continue
		match cid:
			"vagoneta_pista": await _vagoneta_pista()
			"vagoneta_curva": await _vagoneta_curva()
			"vagoneta_boton": await _vagoneta_boton()
			"vagoneta_aguja": await _vagoneta_aguja()
			"barril_muro": await _barril_muro()
			"balanza_rocas": await _balanza()
			"cristal_receptor": await _cristal_receptor()
			"prisma_rojo_azul": await _prisma()
			"pared_hueca_nicho": await _pared_hueca()
			"estatuas_sellos": await _estatuas()
			"presa_barril": await _presa()
	await _jefes()
	_filtro()
	_borrar()


# --- cargar ------------------------------------------------------------------------------------------------------------

## Quita el nivel anterior antes de cargar otro (como prueba_rocas_empujables): sus bloques y vagonetas se dan de baja del registro de casillas.
func _descargar() -> void:
	if maqueta != null and is_instance_valid(maqueta):
		maqueta.get_parent().remove_child(maqueta)
		maqueta.queue_free()
		maqueta = null
		await avanzar(5)


func _cargar_con(cid: String) -> bool:
	await _descargar()
	Flags.nuevo()
	Estado.nuevo()
	var par: Dictionary = {"algoritmo": "salas", "semilla": 3, "nombre": NOMBRE, "enemigos": 0.0, "puzles": 0, "barreras": 0, "salas_cerradas": 0, "kit": "demo",
		"ancho": 60, "alto": 50}
	var a_mano: Dictionary = {}
	for sala in Generador.new().generar(par)["salas"]:
		if String(sala["rol"]) != "inicio":
			var prueba: Dictionary = Generador.new().generar(par, {}, {}, {int(sala["id"]): cid})
			if (prueba["puzles"] as Dictionary).get(int(sala["id"]), "") == cid:
				a_mano = {int(sala["id"]): cid}
				break
	_ok("1 «%s» cabe en una sala" % cid, not a_mano.is_empty())
	if a_mano.is_empty():
		return false
	var m: Dictionary = Generador.new().generar(par, {}, {}, a_mano)
	_ok("1 «%s» se exporta" % cid, bool(Exportador.exportar(m)["ok"]), str(m["errores"]))
	await cargar(Exportador.ruta_escena(NOMBRE), true)
	if maqueta == null:
		return false
	_pz = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("1 «%s»: Puzle3D sin avisos" % cid, _pz != null and _pz.avisos.is_empty(), str(_pz.avisos) if _pz != null else "")
	await avanzar_s(0.5)
	return _pz != null


func _n(local: String) -> Node:
	return _pz.nodo(_pre + local)


func _c(local: String) -> Vector2i:
	var p = _pz.pieza(_pre + local)
	return p.celda if p != null else Vector2i(-1, -1)


func _esperar(cond: Callable, max_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()) and t < max_s:
		t += await avanzar_s(0.1)
	return bool(cond.call())


func _empujar(r, dir: Vector2i) -> bool:
	colocar_jugador(r.celda - dir)
	await avanzar(3)
	var cedio: bool = r.empujar(dir, true)
	await _esperar(func() -> bool: return not r.moviendo, 12.0)
	await avanzar(2)
	return cedio


## Lanza desde `desde` hacia `objetivo` (con `en_punto`, el hechizo nace en el punto apuntado: la barrera de tierra). Tinta llena; reintenta si el libro no está listo.
func _lanzar(elemento: String, glifos: Array, objetivo: Vector2i, desde: Vector2i, en_punto: bool = false) -> bool:
	colocar_jugador(desde)
	await avanzar_s(0.5)
	var t: float = 0.0
	while t <= T_TINTA_MAX_S:
		jugador.tinta.actual = jugador.tinta.maxima
		var yo: Vector3 = jugador.position
		var meta: Vector3 = Terreno3D.centro_de(objetivo, 0.0)
		var hacia: Vector3 = Vector3(meta.x - yo.x, 0.0, meta.z - yo.z)
		var origen: Vector3 = yo
		if en_punto:
			var tope: float = Lanzador3D.ALCANCE_ORIGEN * Terreno3D.casilla
			origen = yo + (hacia if hacia.length() <= tope else hacia.normalized() * tope)
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element(elemento)
		for g in glifos:
			lanzador.place_sigil(String(g))
		lanzador.cooldown_left[0] = 0.0
		if lanzador.lanzar_pagina_ya(0, origen, hacia.normalized()):
			await avanzar_s(1.2)
			return true
		t += await avanzar_s(0.5)
	return false


# --- vagonetas -----------------------------------------------------------------------------------------------------------

func _vagoneta_pista() -> void:
	var v: Vagoneta3D = _n("vag") as Vagoneta3D
	var placa = _n("placa")
	_ok("2 pista: hay vagoneta y placa", v != null and placa != null)
	if v == null:
		return
	_ok("2 pista [legible]: la vagoneta no sale de su vía (empujada a un lado no se mueve)", not v.puede_moverse(Vector2i(1, 0)) and not v.puede_moverse(Vector2i(-1, 0)))
	for i in 2:
		await _empujar(v, Vector2i(0, -1))
	_ok("2 pista: dos empujones hacia arriba y pesa en la placa (3)", v.celda == _c("placa") and placa.activo, "vagoneta en %s, placa en %s" % [str(v.celda), str(_c("placa"))])


func _vagoneta_curva() -> void:
	var v: Vagoneta3D = _n("vag") as Vagoneta3D
	var cofre = _n("cofre")
	if v == null:
		_ok("2 curva: hay vagoneta", false)
		return
	_ok("2 curva: el cofre está oculto", cofre.es_oculto)
	for i in 2:
		await _empujar(v, Vector2i(0, -1))
	_ok("2 curva [legible]: en la curva no se puede seguir hacia arriba", not v.puede_moverse(Vector2i(0, -1)))
	await avanzar_s(3.5)
	_ok("2 curva: en la curva no se da por atascada (no vuelve a su sitio)", v.celda != v.origen, str(v.celda))
	for i in 3:
		await _empujar(v, Vector2i(-1, 0))
	_ok("2 curva: rodeada y empujada a la izquierda, llega a la placa y aparece el cofre",
		v.celda == _c("placa") and await _esperar(func() -> bool: return not cofre.es_oculto, 3.0), "vagoneta en %s" % str(v.celda))


func _vagoneta_boton() -> void:
	var v: Vagoneta3D = _n("vag") as Vagoneta3D
	var muro = _n("muro")
	var boton = _n("boton")
	if v == null or muro == null or boton == null:
		_ok("2 botón: piezas", false)
		return
	# A mano llega despacio y no rompe nada.
	await _empujar(v, Vector2i(0, -1))
	await _empujar(v, Vector2i(0, -1))
	_ok("2 botón [legible]: empujada a mano llega al muro pero no lo rompe", v.celda == _c("muro") + Vector2i(0, 1) and not muro.roto_ya, str(v.celda))
	# Se vuelve a su sitio (a mano, hacia abajo) y se lanza con el botón.
	await _empujar(v, Vector2i(0, 1))
	await _empujar(v, Vector2i(0, 1))
	var bc: Vector2i = _c("boton")
	_ok("2 botón: flecha de fuego al botón", await _lanzar("fuego", ["flecha"], bc, bc + Vector2i(0, 2)))     # una flecha llega a unas 2 casillas
	var roto: bool = await _esperar(func() -> bool: return muro.roto_ya, 15.0)      # 24/11: rueda a la velocidad del empuje (~2,3 s por casilla)
	_ok("2 botón: el botón LANZA la vagoneta, rueda sola, choca y rompe el muro", roto and v.choques >= 1, "choques %d, vagoneta en %s" % [v.choques, str(v.celda)])


func _vagoneta_aguja() -> void:
	var v: Vagoneta3D = _n("vag") as Vagoneta3D
	var ag: Aguja3D = _n("aguja") as Aguja3D
	var placa = _n("placa")
	var boton = _n("boton")
	if v == null or ag == null or placa == null or boton == null:
		_ok("2 aguja: piezas", false)
		return
	var bc: Vector2i = _c("boton")
	_ok("2 aguja: flecha de fuego al botón (la aguja está en el ramal de la izquierda)", await _lanzar("fuego", ["flecha"], bc, bc + Vector2i(2, 0)))
	await _esperar(func() -> bool: return v.choques >= 1, 25.0)
	_ok("2 aguja [legible]: por el ramal equivocado acaba en el callejón y la placa no se pisa", v.celda.x < _c("aguja").x and not placa.activo, str(v.celda))
	var vuelve: bool = await _esperar(func() -> bool: return v.celda == v.origen, 6.0)
	_ok("2 aguja: atascada en el callejón, a los 3 s vuelve a su sitio", vuelve, str(v.celda))
	ag.cambiar()                                    # lo que hace un golpe de hechizo a la palanca (on_spell_hit)
	_ok("2 aguja: cambiada al ramal de la derecha", ag.en_b)
	await avanzar_s(1.5)                            # el botón se rearma (rearme=1)
	_ok("2 aguja: otra flecha al botón", await _lanzar("fuego", ["flecha"], bc, bc + Vector2i(2, 0)))
	var llega: bool = await _esperar(func() -> bool: return placa.activo, 25.0)
	_ok("2 aguja: con la aguja puesta, la vagoneta sigue el ramal y la curva hasta la placa", llega, "vagoneta en %s, placa en %s" % [str(v.celda), str(_c("placa"))])


# --- el resto --------------------------------------------------------------------------------------------------------------

func _barril_muro() -> void:
	var muro = _n("muro")
	var bc: Vector2i = _c("barril")
	_ok("3 barril: flecha de fuego al barril desde la entrada", await _lanzar("fuego", ["flecha"], bc, bc + Vector2i(0, 2)))
	_ok("3 barril: explota y rompe el muro pegado", await _esperar(func() -> bool: return muro.roto_ya, 5.0))


## 26/11: la presa. El embalse lleno, el vaso seco; flecha de fuego al barril: el muro (las dos casillas) salta, el agua pasa y aparece el cofre.
func _presa() -> void:
	var muro = _n("dique")
	var alto = _n("dique_alto")
	var nivel = _n("nivel")
	var cofre = _n("cofre")
	if muro == null or alto == null or nivel == null or cofre == null:
		_ok("3 presa: piezas", false)
		return
	var sim: AguaSim3D = Terreno3D.agua_sim
	var ce: Vector2i = _c("embalse")
	var cv: Vector2i = _c("vaso")
	await avanzar_s(2.0)
	_ok("3 presa: el embalse está lleno y el vaso seco; el muro aguanta", sim.profundidad_casilla(ce) > 0.6 and sim.profundidad_casilla(cv) < 0.05 and not muro.abierta,
		"embalse %.2f vaso %.2f" % [sim.profundidad_casilla(ce), sim.profundidad_casilla(cv)])
	_ok("3 presa [legible]: el muro se dibuja como muro de sillares (no el pedrusco)", muro.get("_muro") != null)
	var bc: Vector2i = _c("barril")
	_ok("3 presa: flecha de fuego al barril desde la entrada", await _lanzar("fuego", ["flecha"], bc, bc + Vector2i(0, 2)))
	_ok("3 presa: explota y el muro cae entero (sus dos casillas)", await _esperar(func() -> bool: return muro.abierta and alto.abierta, 5.0))
	_ok("3 presa: el agua pasa al vaso, sube el nivel y aparece el cofre", await _esperar(func() -> bool: return nivel.alcanzado and not cofre.es_oculto, 20.0),
		"embalse %.2f vaso %.2f" % [sim.profundidad_casilla(ce), sim.profundidad_casilla(cv)])


func _balanza() -> void:
	var rm = _n("rm")
	var rp = _n("rp")
	var cofre = _n("cofre")
	for i in 2:
		await _empujar(rm, Vector2i(0, -1))
		await _empujar(rp, Vector2i(0, -1))
	_ok("3 balanza: las dos rocas en sus placas y el cofre aún oculto", _n("pa").activo and _n("pb").activo and cofre.es_oculto)
	var pc: Vector2i = _c("pc")
	_ok("3 balanza: tierra + barrera sobre la tercera placa", await _lanzar("tierra", ["barrera"], pc, pc + Vector2i(-1, 1), true))
	_ok("3 balanza: con las tres placas pisadas aparece el cofre", await _esperar(func() -> bool: return not cofre.es_oculto, 4.0), "placa C %s" % _n("pc").activo)


func _cristal_receptor() -> void:
	var rec = _n("receptor")
	var cc: Vector2i = _c("cristal")
	# El agua, desde el este (por encima de la veta): la flecha de agua deja charco, y un charco en el camino de la de fuego la apagaría.
	_ok("3 cristal: flecha de agua al cristal", await _lanzar("agua", ["flecha"], cc, cc + Vector2i(2, 0)))
	await avanzar_s(1.5)
	_ok("3 cristal [legible]: con agua el receptor de fuego no se activa", not rec.activo)
	_ok("3 cristal: flecha de fuego al cristal", await _lanzar("fuego", ["flecha"], cc, cc + Vector2i(0, 2)))
	_ok("3 cristal: el pulso de fuego llega por la veta y activa el receptor", await _esperar(func() -> bool: return rec.activo, 4.0))


func _prisma() -> void:
	var prisma = _n("prisma")
	var rf = _n("rf")
	var ra = _n("ra")
	var cofre = _n("cofre")
	var cc: Vector2i = _c("cristal")
	prisma.girar()                                  # E: oeste → norte
	await avanzar_s(0.5)
	_ok("3 prisma: fuego al cristal", await _lanzar("fuego", ["flecha"], cc, cc + Vector2i(0, 2)))
	_ok("3 prisma: girado al norte, el fuego llega al receptor rojo", await _esperar(func() -> bool: return rf.activo, 4.0))
	prisma.girar()
	await avanzar_s(0.5)
	prisma.girar()
	await avanzar_s(0.5)
	_ok("3 prisma: agua al cristal", await _lanzar("agua", ["flecha"], cc, cc + Vector2i(0, 2)))
	_ok("3 prisma: girado al sur, el agua llega al azul y aparece el cofre épico", await _esperar(func() -> bool: return ra.activo and not cofre.es_oculto, 4.0))


func _pared_hueca() -> void:
	var hueca = _n("hueca")
	var vc: Vector2i = _c("veta") + Vector2i(0, 1)
	_ok("3 pared hueca: fuego + ᚱ sobre la veta", await _lanzar("fuego", ["raido"], vc, vc + Vector2i(0, 1)))
	_ok("3 pared hueca: el pulso corre por la veta y la abre", await _esperar(func() -> bool: return hueca.abierta, 5.0))


func _estatuas() -> void:
	var est = _n("estatuas")
	var cofre = _n("cofre")
	var c0: Vector2i = _c("estatuas")
	var orden: Array = [["fuego", c0, ["raido"]], ["agua", c0 + Vector2i(3, 0), ["raido"]], ["tierra", c0 + Vector2i(6, 0), ["raido", "flecha"]]]
	for i in orden.size():
		_ok("3 estatuas: %s + ᚱ a la estatua %d" % [orden[i][0], i + 1], await _lanzar(String(orden[i][0]), orden[i][2], orden[i][1], (orden[i][1] as Vector2i) + Vector2i(0, 1)))
		_ok("3 estatuas: se enciende la %d" % (i + 1), await _esperar(func() -> bool: return est.paso >= i + 1, 4.0), "paso %d" % est.paso)
		await avanzar_s(0.8)
	_ok("3 estatuas: completas, aparece el cofre épico", await _esperar(func() -> bool: return not cofre.es_oculto, 4.0))


# --- salas del jefe ----------------------------------------------------------------------------------------------------------

func _jefes() -> void:
	await _descargar()
	Flags.nuevo()
	Estado.nuevo()
	var base: Dictionary = {"semilla": 5, "nombre": NOMBRE, "enemigos": 0.0, "puzles": 0, "barreras": 0, "salas_cerradas": 0, "sala_jefe": "auto", "kit": "demo"}
	var cueva: Dictionary = base.duplicate()
	cueva.merge({"algoritmo": "salas", "estilo": "cueva", "ancho": 50, "alto": 40})
	var m: Dictionary = Generador.new().generar(cueva)
	var txt: String = "\n".join(m["lineas"])
	_ok("4 jefe en cueva: gólem, dos limos, vigía, cerrojo y cofre legendario", txt.contains("jefe1_golem golem") and txt.contains("jefe1_limo_2 limo") and txt.contains("jefe1_vigia vigia")
		and txt.contains("jefe1_cerrojo cerrojo") and txt.contains("jefe1_cofre cofre") and txt.contains("modelo=legendario"), "\n".join(m["avisos"]))
	var bosque: Dictionary = base.duplicate()
	bosque.merge({"algoritmo": "bosque", "estilo": "bosque", "ancho": 50, "alto": 40, "claros": 6, "tamano_claro": 5})
	var mb: Dictionary = Generador.new().generar(bosque)
	var txb: String = "\n".join(mb["lineas"])
	var hay_g: bool = false
	for f in mb["filas"]:
		hay_g = hay_g or String(f).contains("G")
	_ok("4 jefe en bosque: el elemental (G), vigía y cofre legendario, sin cerrojo", hay_g and txb.contains("jefe1_vigia vigia") and txb.contains("jefe1_cofre cofre") and not txb.contains("jefe1_cerrojo"),
		"\n".join(mb["avisos"]))
	# La de la cueva, en el juego.
	_ok("4 jefe: se exporta", bool(Exportador.exportar(m)["ok"]))
	_ok("4 jefe: la escena lleva el kit elegido (demo)", FileAccess.get_file_as_string(Exportador.ruta_escena(NOMBRE)).contains("kit = \"demo\""))
	await cargar(Exportador.ruta_escena(NOMBRE), true)
	if maqueta == null:
		return
	_pz = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("4 jefe: Puzle3D sin avisos", _pz != null and _pz.avisos.is_empty(), str(_pz.avisos) if _pz != null else "")
	await avanzar_s(0.5)
	var cerrojo = _pz.nodo("jefe1_cerrojo")
	var cofre = _pz.nodo("jefe1_cofre")
	var golem = _pz.nodo("jefe1_golem")
	_ok("4 jefe: el gólem está y el cofre legendario, oculto", golem is Golem3D and cofre != null and cofre.es_oculto)
	if golem == null or cerrojo == null:
		return
	colocar_jugador(Terreno3D.celda_de((golem as Node3D).global_position) + Vector2i(0, 2))
	await _esperar(func() -> bool: return cerrojo.cerrado, 3.0)
	_ok("4 jefe: al entrar se cierra la sala", cerrojo.cerrado)
	for n in maqueta.find_children("*", "", true, false):
		if n is Combate3D and not (n as Combate3D).muerto:
			n.call("_morir")                        # por código: el combate no es lo que se prueba
	_ok("4 jefe: vencidos, se abre y aparece el cofre legendario", await _esperar(func() -> bool: return not cerrojo.cerrado and not cofre.es_oculto, 8.0))


# --- filtro de runas ---------------------------------------------------------------------------------------------------------

func _filtro() -> void:
	var cat: Dictionary = Catalogo.todos()
	var par: Dictionary = {"algoritmo": "salas", "semilla": 7, "nombre": NOMBRE, "enemigos": 0.0, "puzles": 12, "barreras": 3, "salas_cerradas": 0, "kit": "demo_inicio",
		"ancho": 70, "alto": 60}
	var runas: Array = Generator_runas(par)
	var m: Dictionary = Generador.new().generar(par)
	var malos: Array = []
	for sid in m["puzles"]:
		var cid: String = String(m["puzles"][sid])
		if cat.has(cid) and not Catalogo.se_puede(cat[cid], runas):
			malos.append(cid)
	_ok("5 filtro: con el kit demo_inicio (%s) todos los repartidos se resuelven con él" % ", ".join(PackedStringArray(runas)), malos.is_empty() and not (m["puzles"] as Dictionary).is_empty(),
		"puestos %s · malos %s" % [str((m["puzles"] as Dictionary).values()), str(malos)])
	# Mapas oficiales: «Solo puzles aceptados». Con ninguna plantilla aceptada no se reparte ninguna (y lo dice); con una aceptada, solo esa.
	var oficial: Dictionary = par.duplicate()
	oficial["solo_aceptados"] = true
	var aceptadas: Array = cat.keys().filter(func(c) -> bool: return Catalogo.aceptado(cat[c]))
	var mo: Dictionary = Generador.new().generar(oficial)
	var no_acept: Array = (mo["puzles"] as Dictionary).values().filter(func(c) -> bool: return cat.has(c) and not Catalogo.aceptado(cat[c]))
	_ok("5 solo aceptados: no reparte ningún puzle sin aceptar (%d aceptados en el catálogo)" % aceptadas.size(), no_acept.is_empty(), str(no_acept))
	_ok("5 solo aceptados: sin aceptados, lo avisa", not aceptadas.is_empty() or "\n".join(mo["avisos"]).contains("está aceptado"), "\n".join(mo["avisos"]))
	var otra: Dictionary = par.duplicate()
	otra["runas"] = "fuego,agua,tierra,flecha,barrera,raido"
	_ok("5 filtro: runas a mano (sin kit) también filtran", Generador.runas_de(otra).has("raido") and not Generador.runas_de(otra).has("hielo"))
	# Búsqueda a mano: uno que no se puede resolver, puesto en una sala, se pone pero avisa.
	var par0: Dictionary = par.duplicate()
	par0["puzles"] = 0
	par0["barreras"] = 0
	var m2: Dictionary = {}
	var sala_libre: int = -1
	for s in Generador.new().generar(par0)["salas"]:
		if String(s["rol"]) != "":
			continue
		var prueba: Dictionary = Generador.new().generar(par0, {}, {}, {int(s["id"]): "estatuas_sellos"})
		if (prueba["puzles"] as Dictionary).get(int(s["id"]), "") == "estatuas_sellos":
			m2 = prueba
			sala_libre = int(s["id"])
			break
	_ok("5 filtro: a mano, un puzle que pide runas que no hay se pone y AVISA", sala_libre >= 0 and "\n".join(m2["avisos"]).contains("NO se puede resolver"),
		"\n".join(m2["avisos"]) if not m2.is_empty() else "no cupo en ninguna sala")


func Generator_runas(par: Dictionary) -> Array:
	return Generador.runas_de(par)


func _borrar() -> void:
	for r in [Exportador.ruta_mapa(NOMBRE), Exportador.ruta_escena(NOMBRE)]:
		if FileAccess.file_exists(r):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(r))
