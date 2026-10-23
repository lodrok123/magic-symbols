extends SceneTree
## PULSO3D SOLO (23/10, FASE 1 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §3), sin escena ni ventana y con una rejilla falsa de conductores:
##   · la BÚSQUEDA compartida con la fuente eléctrica (`EmisorRayo3D.ola`): pasos, alcance, 4 vecinas sin diagonales, y que `agua_conectada` sigue dando lo de siempre;
##   · ALCANCE: nada pasa del paso `alcance`;
##   · RETRASO por casilla: el paso p se dispara cuando el reloj del pulso llega a p × SEG_POR_CASILLA, ni antes ni mucho después;
##   · CORTE sin conductor: en el aire solo toca la casilla de al lado (1 casilla);
##   · COLOR: sin elemento el pulso es `COLOR_BASE` (azulado claro, #9ED9FF); con elemento, el color de su runa (se comprueba contra `nucleo/*_rune.tres`);
##   · SIN REENTRADAS: una casilla se alcanza una vez aunque haya un anillo de conductores, un receptor entre dos casillas del frente recibe UN aviso, el emisor no se avisa a sí mismo;
##   · AVISO a lo que toca (receptor junto a la veta) en el paso que le corresponde, y el nodo se libera al terminar.
## FASE 2 (23/10; PLAN §2 y §10 bis; GLIFOS_RECETA §2.2 y §2.4 bis), sin escena:
##   · RECETA con ᚱ (id `raido`): `resuena` +4 por glifo con tope 12, es una propiedad que encarece, no cambia el volumen ni la forma, y el pulso del jugador usa el MISMO color/señal;
##   · MOMENTO DE EJECUCIÓN: cada glifo lo declara como dato; ᚱ es final con flecha, continuo con barrera/permanencia/sólido, inicio en el resto (haz incluido); el orden dentro de un momento es
##     el del dato (`paso`), nunca el de dibujo; la tabla es válida (momentos conocidos, pasos, acciones del catálogo); el recargo del continuo es el mismo en la receta y en el Hechizo;
##   · ᚷ «crecer»: el nombre que ve el jugador cambia, y su id, runa, parámetro y efecto NO.
##   godot --headless --path . --script res://herramientas/prueba_pulso.gd

## Un receptor de mentira: tiene `celda` y `on_pulso`, y cuenta los avisos.
class Receptor extends Node:
	var celda: Vector2i = Vector2i.ZERO
	var avisos: int = 0
	var edad_aviso: float = -1.0
	var elemento_visto: String = ""
	func on_pulso(p: Pulso3D) -> void:
		avisos += 1
		edad_aviso = p.edad()
		elemento_visto = p.elemento

var _fallos: int = 0
var _conduce: Dictionary = {}                  ## la rejilla falsa: casilla -> true


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _f(c: Vector2i) -> bool:
	return _conduce.has(c)


## Hace avanzar un pulso `segundos` en pasos de 10 ms (como fotogramas), para que su reloj marque la hora real de cada aviso.
func _avanzar_a_mano(p: Pulso3D, segundos: float) -> void:
	var t: float = 0.0
	while t < segundos and is_instance_valid(p):
		p.avanzar(0.01)
		t += 0.01


func _linea(desde: Vector2i, hasta: Vector2i) -> void:
	for y in range(mini(desde.y, hasta.y), maxi(desde.y, hasta.y) + 1):
		for x in range(mini(desde.x, hasta.x), maxi(desde.x, hasta.x) + 1):
			_conduce[Vector2i(x, y)] = true


func _initialize() -> void:
	await process_frame
	_busqueda()
	await _pulso_alcance_y_retraso()
	await _pulso_corte_en_el_aire()
	_colores()
	await _pulso_sin_reentradas()
	await _pulso_avisa_y_acaba()
	_receta_pulso()
	_momento_de_ejecucion()
	_crecer_y_nombres()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# ---------------------------------------------------------------------------------------------------------------------

func _busqueda() -> void:
	_conduce.clear()
	_linea(Vector2i(1, 0), Vector2i(5, 0))
	_linea(Vector2i(3, 1), Vector2i(3, 3))               # una rama hacia abajo
	_conduce[Vector2i(6, 1)] = true                       # solo en diagonal de (5,0): NO se une (4 vecinas)
	var ola: Dictionary = EmisorRayo3D.ola([Vector2i(0, 0)], _f, 99)
	_ok("1 la búsqueda da los pasos de cada casilla (1..5 por la línea; la rama baja desde el paso 3: 4, 5 y 6)", ola.get(Vector2i(1, 0)) == 1 and ola.get(Vector2i(5, 0)) == 5 and ola.get(Vector2i(3, 1)) == 4 and ola.get(Vector2i(3, 3)) == 6, str(ola))
	_ok("1 una casilla que solo toca por la diagonal no entra (4 vecinas)", not ola.has(Vector2i(6, 1)))
	_ok("1 el origen que NO conduce no cuenta como conductor", not ola.has(Vector2i(0, 0)))
	var corta: Dictionary = EmisorRayo3D.ola([Vector2i(0, 0)], _f, 3)
	_ok("1 con alcance 3 no pasa del paso 3", corta.size() == 3 and not corta.has(Vector2i(4, 0)) and corta.has(Vector2i(3, 0)), str(corta.keys()))
	var con_origen: Dictionary = EmisorRayo3D.ola([Vector2i(0, 0)], _f, 3, true)
	_ok("1 con `origen_siempre` el origen entra en el paso 0 (el pulso nace en su emisor)", con_origen.get(Vector2i(0, 0)) == 0 and con_origen.size() == 4)
	# La fuente eléctrica sigue pidiendo lo mismo (`agua_conectada` ahora llama a `ola`): conjunto y orden por anillos.
	var agua: Array = EmisorRayo3D.agua_conectada(Vector2i(0, 0), _f)
	_ok("1 `agua_conectada` sigue dando el conjunto conectado de siempre (8 casillas, sin la diagonal)", agua.size() == 8 and not agua.has(Vector2i(6, 1)) and agua.has(Vector2i(3, 3)), str(agua))
	# Origen que ya es agua: entra él también.
	var desde_agua: Array = EmisorRayo3D.agua_conectada(Vector2i(1, 0), _f)
	_ok("1 si el origen conduce, entra él y lo conectado (sin la diagonal)", desde_agua.size() == 8 and desde_agua[0] == Vector2i(1, 0), str(desde_agua))


## Lanza un pulso con la rejilla falsa, sin dibujo. `_conduce` ya preparada.
func _lanzar(origen: Vector2i, elemento: String, alcance: int, receptores: Array = []) -> Pulso3D:
	var p := Pulso3D.new()
	p.dibujar = false
	p.preparar([origen], elemento, alcance, null, _f)
	for r in receptores:
		root.add_child(r)
		r.add_to_group(Pulso3D.GRUPO_PULSABLE)
	root.add_child(p)
	return p


func _pulso_alcance_y_retraso() -> void:
	_conduce.clear()
	_linea(Vector2i(1, 0), Vector2i(9, 0))
	var p: Pulso3D = _lanzar(Vector2i(0, 0), "", 5)
	_ok("2 alcance 5 sobre una línea de 9: alcanza el origen y 5 casillas (6)", p.alcanzadas.size() == 6 and p.alcanzadas.has(Vector2i(5, 0)) and not p.alcanzadas.has(Vector2i(6, 0)), str(p.alcanzadas.keys()))
	var edades: Dictionary = {}                    ## paso -> edad del reloj del pulso cuando se disparó
	p.alcanzo.connect(func(_c: Vector2i, paso: int) -> void: edades[paso] = p.edad())
	var t: float = 0.0
	var dt: float = 0.01
	while t < 0.75:
		p.avanzar(dt)
		t += dt
	var bien: bool = edades.size() == 6
	var peor: float = 0.0
	for paso in edades:
		var esperado: float = float(paso) * Pulso3D.SEG_POR_CASILLA
		var retraso: float = float(edades[paso]) - esperado
		peor = maxf(peor, retraso)
		if retraso < -1.0e-4 or retraso > dt + 1.0e-4:           # ni antes de su hora ni más de un fotograma tarde
			bien = false
	_ok("2 cada paso se dispara a su hora (paso × %.2f s, como mucho %.0f ms tarde)" % [Pulso3D.SEG_POR_CASILLA, peor * 1000.0], bien, str(edades))
	_ok("2 el pulso de 0,08 s por casilla tarda 0,40 s en llegar al paso 5", absf(float(edades.get(5, 0.0)) - 0.40) <= dt + 1.0e-4)
	# Un pulso nuevo: a 0,07 s solo ha salido el origen.
	var q: Pulso3D = _lanzar(Vector2i(0, 0), "", 5)
	var vistos: Array = []
	q.alcanzo.connect(func(_c: Vector2i, paso: int) -> void: vistos.append(paso))
	q.avanzar(0.07)
	_ok("2 a los 0,07 s solo ha salido el origen (paso 0)", vistos == [0], str(vistos))
	q.avanzar(0.01)
	_ok("2 a los 0,08 s sale el paso 1", vistos == [0, 1], str(vistos))
	q.avanzar(0.0)
	await process_frame
	var fin := _Fin.new()
	q.terminado.connect(func() -> void: fin.hecho = true)
	q.avanzar(2.0)
	_ok("2 al acabar emite `terminado` y se libera", fin.hecho)
	await process_frame
	await process_frame
	_ok("2 el nodo del pulso terminado ya no existe", not is_instance_valid(q))


class _Fin extends RefCounted:
	var hecho: bool = false


func _pulso_corte_en_el_aire() -> void:
	_conduce.clear()
	var cerca := Receptor.new()
	cerca.celda = Vector2i(5, 4)
	var lejos := Receptor.new()
	lejos.celda = Vector2i(5, 3)
	var al_lado_2 := Receptor.new()
	al_lado_2.celda = Vector2i(7, 5)
	var p: Pulso3D = _lanzar(Vector2i(5, 5), "", 12, [cerca, lejos, al_lado_2])
	_ok("3 sin conductor solo cuenta el origen (paso 0)", p.alcanzadas.size() == 1 and p.alcanzadas.get(Vector2i(5, 5)) == 0, str(p.alcanzadas))
	_ok("3 por el aire toca las 4 vecinas, en el paso 1 (1 casilla)", p.tocadas.size() == 4 and p.tocadas.get(Vector2i(5, 4)) == 1 and p.tocadas.get(Vector2i(6, 5)) == 1, str(p.tocadas))
	_ok("3 el pulso solo tiene 1 paso", p.pasos() == 1)
	_avanzar_a_mano(p, 0.5)
	_ok("3 una casilla pegada al emisor recibe el aviso en su paso 1 (0,08 s)", cerca.avisos == 1 and cerca.edad_aviso >= 0.08 - 1.0e-4 and cerca.edad_aviso <= 0.09 + 1.0e-4, "avisos %d, a los %.3f s" % [cerca.avisos, cerca.edad_aviso])
	_ok("3 a 2 casillas por el aire NO llega (ni por la columna ni en línea)", lejos.avisos == 0 and al_lado_2.avisos == 0)
	for r in [cerca, lejos, al_lado_2]:
		r.queue_free()


func _colores() -> void:
	_ok("4 COLOR_BASE es azulado claro (#9ED9FF)", Pulso3D.COLOR_BASE.to_html(false).to_upper() == "9ED9FF", Pulso3D.COLOR_BASE.to_html(false))
	_conduce.clear()
	var sin := Pulso3D.new()
	sin.dibujar = false
	sin.preparar([Vector2i(0, 0)], "", 3, null, _f)
	_ok("4 el pulso sin elemento lleva COLOR_BASE", sin.color == Pulso3D.COLOR_BASE and sin.elemento == "")
	var raro := Pulso3D.new()
	raro.preparar([Vector2i(0, 0)], "elemento_inventado", 3, null, _f)
	_ok("4 un elemento desconocido se pinta como el base", raro.color == Pulso3D.COLOR_BASE)
	var runas: Dictionary = {"fuego": "fire", "agua": "water", "hielo": "ice", "rayo": "lightning", "tierra": "earth", "viento": "wind", "tiempo": "time"}
	for e in runas:
		var rd: RuneData = load("res://nucleo/%s_rune.tres" % runas[e]) as RuneData
		var p := Pulso3D.new()
		p.preparar([Vector2i(0, 0)], e, 3, null, _f)
		_ok("4 el pulso de %s toma el color de su runa" % e, rd != null and p.color == rd.color and p.color != Pulso3D.COLOR_BASE, "pulso %s · runa %s" % [p.color.to_html(false), rd.color.to_html(false) if rd != null else "?"])
		p.free()
	sin.free()
	raro.free()


func _pulso_sin_reentradas() -> void:
	# Un anillo de conductores alrededor del emisor y un receptor FUERA, tocando dos casillas del anillo a la vez.
	_conduce.clear()
	for c in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 1)]:
		_conduce[c] = true
	var entre := Receptor.new()
	entre.celda = Vector2i(1, 1)                 # el hueco del anillo: toca (1,0), (2,1), (1,2) y (0,1)
	var emisor := Receptor.new()
	emisor.celda = Vector2i(0, 0)
	var p := Pulso3D.new()
	p.dibujar = false
	p.preparar([Vector2i(0, 0)], "", 12, emisor, _f)
	root.add_child(entre)
	root.add_child(emisor)
	entre.add_to_group(Pulso3D.GRUPO_PULSABLE)
	emisor.add_to_group(Pulso3D.GRUPO_PULSABLE)
	root.add_child(p)
	var veces: Dictionary = {}
	p.alcanzo.connect(func(c: Vector2i, _paso: int) -> void: veces[c] = int(veces.get(c, 0)) + 1)
	_avanzar_a_mano(p, 3.0)
	var repetida: bool = false
	for c in veces:
		if int(veces[c]) != 1:
			repetida = true
	_ok("5 en un anillo cada casilla se alcanza UNA sola vez (8 casillas con el origen)", not repetida and veces.size() == 8, str(veces))
	_ok("5 el receptor que toca cuatro casillas del frente recibe UN aviso", entre.avisos == 1, "avisos %d" % entre.avisos)
	_ok("5 el emisor no se avisa a sí mismo", emisor.avisos == 0)
	_ok("5 el aviso llega en el primer paso que lo toca (paso 2, 0,16 s: (1,0) y (0,1) son el paso 1)", entre.edad_aviso >= 0.16 - 1.0e-4 and entre.edad_aviso <= 0.17 + 1.0e-4, "a los %.3f s" % entre.edad_aviso)
	# Dos pulsos seguidos del mismo emisor son independientes: cada uno avisa una vez.
	var p2 := Pulso3D.new()
	p2.dibujar = false
	p2.preparar([Vector2i(0, 0)], "fuego", 12, emisor, _f)
	root.add_child(p2)
	_avanzar_a_mano(p2, 3.0)
	_ok("5 un segundo pulso (de fuego) vuelve a avisar, una vez más, y el receptor ve su elemento", entre.avisos == 2 and entre.elemento_visto == "fuego", "avisos %d, elemento %s" % [entre.avisos, entre.elemento_visto])
	entre.queue_free()
	emisor.queue_free()


func _pulso_avisa_y_acaba() -> void:
	# Una veta de 5 casillas y un receptor pegado al final: el aviso llega en el paso 6 (la veta es de 1 a 5; el receptor lo toca el frente un paso después).
	_conduce.clear()
	_linea(Vector2i(1, 0), Vector2i(5, 0))
	var r := Receptor.new()
	r.celda = Vector2i(6, 0)
	var p: Pulso3D = _lanzar(Vector2i(0, 0), "rayo", 12, [r])
	_ok("6 el receptor pegado al final de la veta está en `tocadas` con paso 6", p.tocadas.get(Vector2i(6, 0)) == 6, str(p.tocadas))
	p.avanzar(0.47)
	_ok("6 a los 0,47 s (antes del paso 6) aún no ha recibido nada", r.avisos == 0)
	p.avanzar(0.02)
	_ok("6 a los 0,49 s lo toca el frente y recibe un pulso de rayo", r.avisos == 1 and r.elemento_visto == "rayo", "avisos %d" % r.avisos)
	var r2 := Receptor.new()
	r2.celda = Vector2i(6, 0)
	root.add_child(r2)
	r2.add_to_group(Pulso3D.GRUPO_PULSABLE)
	var corto := Pulso3D.new()
	corto.dibujar = false
	corto.preparar([Vector2i(0, 0)], "", 4, null, _f)
	root.add_child(corto)
	_avanzar_a_mano(corto, 3.0)
	_ok("6 con alcance 4 el receptor del paso 6 no se entera (el alcance corta el pulso)", r2.avisos == 0)
	r.queue_free()
	r2.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
#  FASE 2 · la receta, el momento de ejecución y el nombre «crecer»
# ---------------------------------------------------------------------------------------------------------------------

func _runa(archivo: String) -> RuneData:
	return load("res://nucleo/%s_rune.tres" % archivo) as RuneData


func _receta_pulso() -> void:
	var fuego: RuneData = _runa("fire")
	var base: Hechizo = Hechizo.construir(fuego, {})
	var uno: Hechizo = Hechizo.construir(fuego, {"raido": 1})
	var tres: Hechizo = Hechizo.construir(fuego, {"raido": 3})
	var cuatro: Hechizo = Hechizo.construir(fuego, {"raido": 4})
	_ok("7 ᚱ está dado de alta: tablas de Sigils (GLIFOS y GLIFOS_V2), reconocedor (SIGILS, RECORDABLE) y biblia (ᚱ sello)", Sigils.GLIFOS.has("raido") and Sigils.GLIFOS_V2.has("raido")
		and GestureLibrary.SIGILS.has("raido") and GestureLibrary.RECORDABLE.has("raido") and String(GestureLibrary.BIBLIA["raido"]["uso"]) == "sello" and String(GestureLibrary.BIBLIA["raido"]["futhark"]) == "ᚱ")
	_ok("7 sin glifos no resuena; con uno suma 4 casillas, con tres 12, y el tope es 12 (cuatro glifos = 12)", base.resuena == 0.0 and uno.resuena == 4.0 and tres.resuena == 12.0 and cuatro.resuena == 12.0,
		"%s %s %s %s" % [base.resuena, uno.resuena, tres.resuena, cuatro.resuena])
	_ok("7 los datos del glifo: +4 por glifo y tope 12 como constantes con nombre", Sigils.PASO_RESUENA_V2 == 4.0 and Sigils.TOPE_RESUENA_V2 == 12.0 and Sigils.TOPE_RESUENA_V2 == float(Pulso3D.ALCANCE_DEFECTO))
	_ok("7 es una PROPIEDAD de la receta (`resuena`): la cuenta Sigils.aplicar_v2 y la del Hechizo, igual", Sigils.aplicar_v2({"raido": 2})["props"] == {"resuena": 8.0} and uno.propiedades_usadas() == {"resuena": 4.0}
		and Hechizo.construir(fuego, {"raido": 2}).propiedades_usadas() == {"resuena": 8.0})
	_ok("7 no cambia el volumen ni la forma (solo es una propiedad): mismos semiejes y figura que sin ᚱ", uno.semiejes == base.semiejes and uno.figura() == base.figura())
	_ok("7 encarece (propiedad nueva: +25 %)", is_equal_approx(uno.coste, base.coste * (1.0 + Sigils.COSTE_PROP_V2)), "%.3f vs %.3f" % [uno.coste, base.coste])
	_ok("7 el hechizo con ᚱ sigue la paridad de la receta (coste y tinta)", is_equal_approx(uno.coste, Sigils.coste_v2(Sigils.aplicar_v2({"raido": 1}), {"resuena": 4.0})))
	# El pulso del jugador usa la misma señal: elemento de la receta, o el azul base si no hay.
	var p_fuego := Pulso3D.new()
	p_fuego.preparar([Vector2i(0, 0)], uno.elemento, int(uno.resuena), null, _f)
	var p_nada := Pulso3D.new()
	p_nada.preparar([Vector2i(0, 0)], "", int(uno.resuena), null, _f)
	_ok("7 el pulso del jugador toma el elemento de la receta (fuego) y, sin elemento, el azul claro base", p_fuego.elemento == "fuego" and p_fuego.color == fuego.color and p_nada.color == Pulso3D.COLOR_BASE and not p_nada.del_jugador)
	p_fuego.free()
	p_nada.free()
	# El desbloqueo: sin Repertoire no hay ᚱ (los niveles que no lo dan no lo enseñan)
	Repertoire.reset_to_p0()
	_ok("7 por defecto ᚱ NO está en el libro (Repertoire) y se desbloquea con unlock_sigil", not Repertoire.sigil_active("raido") and Repertoire.unlock_sigil("raido") and Repertoire.sigil_active("raido") and not Repertoire.unlock_sigil("raido"))
	Repertoire.lock_sigil("raido")


func _momento_de_ejecucion() -> void:
	var fuego: RuneData = _runa("fire")
	var tierra: RuneData = _runa("earth")
	# La tabla es válida: cada glifo declara un momento conocido y un paso; los que tienen acción la piden del catálogo.
	var tabla_ok: bool = true
	var con_accion: Array = []
	for g in Sigils.GLIFOS:
		var d: Dictionary = Sigils.GLIFOS[g]
		if not Sigils.MOMENTOS.has(String(d.get("momento", Sigils.MOMENTO_DEFECTO))) or int(d.get("paso", 0)) < 1 or int(d.get("paso", 0)) > 5:
			tabla_ok = false
		for regla in (d.get("momento_si", []) as Array):
			if not Sigils.MOMENTOS.has(String(regla["es"])) or not Hechizo.CONDICIONES_MOMENTO.has(String(regla["cuando"])):
				tabla_ok = false
		if d.has("accion"):
			con_accion.append(g)
			if not HechizoVivo.ACCIONES_MOMENTO.has(String(d["accion"])):
				tabla_ok = false
	_ok("8 cada glifo declara su momento (inicio, continuo o final) y su paso de §2.4 como DATO, con reglas y acciones del catálogo cerrado", tabla_ok, str(con_accion))
	_ok("8 solo ᚱ tiene acción hoy; flecha, barrera, repetición, rebote, crecer y permanencia conservan lo que hacen (sin acción)", con_accion == ["raido"])
	# ᚱ: el momento sale de la receta, sin caso especial por pareja de glifos.
	var casos: Array = [
		["sin nada", fuego, {"raido": 1}, "inicio"],
		["volumen más grande", fuego, {"raido": 1, "linea_x": 2}, "inicio"],
		["flecha → final", fuego, {"raido": 1, "flecha": 1}, "final"],
		["flecha + barrera → final (viaja)", fuego, {"raido": 1, "flecha": 1, "barrera": 1}, "final"],
		["barrera → continuo", fuego, {"raido": 1, "barrera": 1}, "continuo"],
		["permanencia → continuo", fuego, {"raido": 1, "permanencia": 1}, "continuo"],
		["tierra (sólido) → continuo", tierra, {"raido": 1}, "continuo"],
		["tierra + flecha → final", tierra, {"raido": 1, "flecha": 1}, "final"],
		["haz (ᛁ + fuego) → inicio", fuego, {"raido": 1, "linea_z": 1}, "inicio"],
		["crecer → inicio", fuego, {"raido": 1, "pulso": 1}, "inicio"],
	]
	for c in casos:
		var h: Hechizo = Hechizo.construir(c[1] as RuneData, c[2] as Dictionary)
		_ok("8 ᚱ %s" % c[0], h.momento_de("raido") == String(c[3]), "salió %s" % h.momento_de("raido"))
	# Con el momento, `acciones_en` da lo que toca; los demás momentos quedan vacíos.
	var hf: Hechizo = Hechizo.construir(fuego, {"raido": 1, "flecha": 1})
	_ok("8 con flecha, las acciones del momento «final» son las de ᚱ y las de «inicio» y «continuo» están vacías", hf.acciones_en("final").size() == 1 and String(hf.acciones_en("final")[0]["glifo"]) == "raido"
		and hf.acciones_en("inicio").is_empty() and hf.acciones_en("continuo").is_empty())
	# El orden de dibujo no cuenta: la receta es un multiconjunto.
	var ab: Hechizo = Hechizo.construir(fuego, {"raido": 2, "barrera": 1, "flecha": 0})
	var ba: Hechizo = Hechizo.construir(fuego, {"barrera": 1, "raido": 2})
	_ok("8 el orden de dibujo no cambia el momento ni las acciones", ab.momento_de("raido") == ba.momento_de("raido") and ab.acciones_en("continuo") == ba.acciones_en("continuo") and ab.resuena == ba.resuena)
	# Orden fijo dentro de un momento: por `paso` y, a igualdad, por el orden de la tabla. Se comprueba con la misma función contra dos entradas inventadas.
	var barajadas: Array = [{"glifo": "d", "paso": 5, "orden": 9}, {"glifo": "b", "paso": 2, "orden": 7}, {"glifo": "c", "paso": 3, "orden": 4}, {"glifo": "a2", "paso": 2, "orden": 8}, {"glifo": "a", "paso": 1, "orden": 1}]
	var ordenadas: Array = Hechizo.ordenar_acciones(barajadas.duplicate()).map(func(a: Dictionary) -> String: return String(a["glifo"]))
	var al_reves: Array = Hechizo.ordenar_acciones(barajadas.duplicate()).map(func(a: Dictionary) -> String: return String(a["glifo"]))
	barajadas.reverse()
	var otra_baraja: Array = Hechizo.ordenar_acciones(barajadas.duplicate()).map(func(a: Dictionary) -> String: return String(a["glifo"]))
	_ok("8 el orden dentro de un momento es el fijo de §2.4 (por paso y, a igualdad, por la tabla), salga como salga la baraja", ordenadas == ["a", "b", "a2", "c", "d"] and otra_baraja == ordenadas and al_reves == ordenadas, str(ordenadas))
	# El recargo del continuo: el mismo número en la receta (Sigils) y en el Hechizo.
	var barrera: Hechizo = Hechizo.construir(fuego, {"barrera": 1})
	var muro_pulso: Hechizo = Hechizo.construir(fuego, {"barrera": 1, "raido": 1})
	var flecha_pulso: Hechizo = Hechizo.construir(fuego, {"flecha": 1, "raido": 1})
	var flecha: Hechizo = Hechizo.construir(fuego, {"flecha": 1})
	var vol_muro: float = barrera.coste / (1.0 + Sigils.COSTE_PROP_V2)            # el volumen en unidades de coste (la barrera ya lleva una propiedad)
	var esperado_muro: float = vol_muro * (1.0 + 2.0 * Sigils.COSTE_PROP_V2) * (1.0 + Sigils.COSTE_CONTINUO_V2)
	_ok("8 el pulso continuo (barrera + ᚱ) cuesta más: propiedad nueva Y recargo del continuo", is_equal_approx(muro_pulso.coste, esperado_muro) and muro_pulso.coste > vol_muro * (1.0 + 2.0 * Sigils.COSTE_PROP_V2), "%.3f vs %.3f" % [muro_pulso.coste, esperado_muro])
	_ok("8 el pulso «al final» (flecha + ᚱ) NO lleva recargo de continuo", is_equal_approx(flecha_pulso.coste, flecha.coste / (1.0 + Sigils.COSTE_PROP_V2) * (1.0 + 2.0 * Sigils.COSTE_PROP_V2)))
	_ok("8 el recargo es el mismo número en la receta (Sigils.coste_v2) y en el Hechizo", is_equal_approx(muro_pulso.coste, Sigils.coste_v2(Sigils.aplicar_v2({"barrera": 1, "raido": 1}), Sigils.aplicar_v2({"barrera": 1, "raido": 1})["props"])))
	_ok("8 las constantes del continuo tienen nombre: periodo mínimo %.1f s (mayor que lo que tarda un pulso en apagarse, %.2f s) y tope de %d disparos" % [Sigils.PERIODO_MIN_CONTINUO_S, Pulso3D.T_COLA, Sigils.MAX_DISPAROS_CONTINUOS],
		Sigils.PERIODO_MIN_CONTINUO_S > Pulso3D.T_COLA and Sigils.MAX_DISPAROS_CONTINUOS >= 2)


func _crecer_y_nombres() -> void:
	var fuego: RuneData = _runa("fire")
	var c1: Hechizo = Hechizo.construir(fuego, {"pulso": 1})
	var c3: Hechizo = Hechizo.construir(fuego, {"pulso": 3})
	_ok("9 ᚷ «crecer» no cambia: id `pulso`, parámetro `crece` (+0,5 por glifo, tope 1,5), runa ᚷ, figura «pulso», sin pulso resonante",
		Sigils.GLIFOS_V2["pulso"]["param"] == "crece" and c1.crece == 0.5 and c3.crece == 1.5 and Hechizo.construir(fuego, {"pulso": 4}).crece == 1.5 and c1.figura() == "pulso" and c1.resuena == 0.0
		and String(GestureLibrary.BIBLIA["pulso"]["futhark"]) == "ᚷ" and c1.acciones_en("inicio").is_empty())
	_ok("9 el jugador lo ve como «crecer» y al glifo nuevo como «pulso»", Sigils.nombre_visible("pulso") == "crecer" and Sigils.nombre_visible("raido") == "pulso" and Sigils.nombre_visible("flecha") == "flecha")
	_ok("9 la chuleta del libro rotula ᚷ «crecer» y ᚱ «pulso» (EjesRecetaUi.EFECTO)", EjesRecetaUi.EFECTO["pulso"] == "crecer" and EjesRecetaUi.EFECTO["raido"] == "pulso")
	_ok("9 los dos glifos tienen PNG propio en el libro", Sigils.GLYPHS.has("pulso") and Sigils.GLYPHS.has("raido") and Sigils.GLYPHS["pulso"] != Sigils.GLYPHS["raido"])
	_ok("9 la onda de viento de siempre (recetas del lab: flecha + ᚷᚷ + ᛁᛁ) sigue construyéndose", Hechizo.construir(_runa("wind"), {"flecha": 1, "pulso": 2, "linea_z": 2}).crece == 1.0)
