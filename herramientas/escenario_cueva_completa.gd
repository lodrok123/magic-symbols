extends "res://herramientas/escenario_base.gd"
## LA CUEVA, DE INICIO A FIN (24/10, FASE 3 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §5 y §12, docs/MATERIALES_CUEVA.md). Pablo: «usar la Cueva como playtest de un recinto cerrado: tiene
## que ser JUGABLE DE INICIO A FIN». Headless, con la escena de verdad (PruebaCueva) y por la VÍA DEL JUGADOR: se anda con las teclas WASD (`_andar_a`, que NO teletransporta: si algo bloquea el
## paso, el escenario falla ahí), se lanza con la receta real (`lanzar`: hechizos del libro, sin tinta ni recarga), se recoge y se abren cofres con la tecla E, y el pulso del escenario (cristales,
## fuente) y el del jugador (ᚱ) corren solos. La única ayuda del arnés: la vida del jugador se repone en la pelea de C4 (los goblins pegan de verdad y esto no prueba el combate).
##
## Con `kit = "pruebas"` (el de PruebaCueva y el del Bosque 01 v01) se entra con TODOS los elementos y los glifos del libro salvo ᚱ: no hace falta dar nada. Lo obligatorio pide fuego (C1, C4), tierra
## (C2) y agua (C3, enfriar la lava con la flecha de agua REAL, 24/10); el hielo también lo piden las estatuas del secreto, que es opcional.
##
## 1 · Montaje: la Cueva (27 × 25) sin avisos; los reactivos de la fase 3 y la cascada de C2 están montados.
## 2 · C1: el cristal late, las setas ENCENDIDAS por la veta maduran y se cogen como seta resonante; un hechizo de fuego sobre el cristal manda un pulso de FUEGO que enciende el brasero del fondo
##     de la veta; dos golpes dan una esquirla de cristal; el otro brasero, a flechazos; la puerta del norte se abre; los braseros alumbran con luz cálida.
## 3 · C2: la cascada (24/10: tres canales sobre una terraza de roca, sin la pieza de ruinas; la cortina de 3 casillas cae al pozo y lo llena); un bloque de tierra tiende el ENLACE de la veta cortada y el pulso tumba la COLUMNA; el nicho da el cofre común; la veta suelta un
##     mineral con tierra; el muro agrietado cae con dos golpes de tierra.
## 4 · C3: enfriar la lava (flecha de agua real: ver el comentario del paso) tiende el puente de basalto: el pulso cruza, el receptor sube la reja del rincón y el cofre común se abre; se cruza el río sobre la roca.
## 5 · C4: la sala se cierra, el pulso de un cristal ATURDE al goblin que pisa la veta, se derrota a los dos goblins, aparece el cofre de la llave y se abre; esquirla y mineral.
## 6 · C5: se rodea la charca a pie; la fuente suelta su pulso; la puerta se abre con la llave.
## 7 · C6: el pulso llega al receptor por el prisma, el cofre legendario (con su columna de luz dorada) se abre y da ᚱ; con ᚱ se abre la pared hueca de la salida.
## 8 · Vuelta a C1: la pared hueca del nicho se abre con ᚱ; las tres estatuas (un fallo las reinicia; fuego, hielo, fuego las completa) hacen aparecer el cofre ÉPICO (columna de luz morada) y da el
##     núcleo de eco.
## 9 · La salida (3..5,18) lleva al Bosque 01 v01 (`boca_cueva`).
## 10 · El color: la luz de la Cueva es azul (sol y ambiente), los braseros alumbran más que el reposo, los cofres épico y legendario echan su columna y suben motas de su color al abrirse.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_cueva_completa.gd

const RUTA: String = "res://escenas/PruebaCueva.tscn"
const FLAG_LLAVE: String = "cueva.c4.llave"
const FLAG_GLIFO: String = "cueva.c6.glifo"
const FLAG_ESTATUAS: String = "cueva.c1.estatuas"
const FLAG_EPICO: String = "cueva.c1.epico"
const VIDA_MAX: float = 100.0
const T_GOBLINS_MAX_S: float = 80.0              ## tope para derrotar a los dos goblins de C4
const T_ESPERA_PULSO_MAX_S: float = 20.0         ## tope para que un pulso del escenario llegue (la fuente descarga cada pocos segundos)
const ALCANCE_FLECHA_CAS: float = 2.8             ## casillas a las que llega una flecha de fuego (medido: de 3 casillas no alcanza el cristal de la pared)
const T_TINTA_MAX_S: float = 8.0                  ## lo que se espera a que vuelva la tinta para lanzar
const TOL_ANDAR: float = 0.3                    ## casillas de margen al llegar a un tramo de la ruta (apuntar bien pide estar cerca del centro)
const TOL_EXACTA: float = 0.12                   ## ponerse en un sitio concreto (a tiro de E de un cofre)
const T_AGACHARSE_S: float = 2.6                ## lo que dura agacharse a coger una seta (el clip a 1,8×, ~1,9 s, más margen)

var _z: Puzle3D = null
var _eje_w: Vector2 = Vector2.ZERO
var _eje_d: Vector2 = Vector2.ZERO


# ---------------------------------------------------------------------------------------------------------------------
#  El jugador: andar, lanzar, coger
# ---------------------------------------------------------------------------------------------------------------------

func _vivo() -> HechizoVivo:
	var ultimo: HechizoVivo = null
	for n in lanzador.get_children():
		if n is HechizoVivo:
			ultimo = n as HechizoVivo
	return ultimo


## Hacia dónde empuja cada tecla (la cámara fija): se mide una vez.
func _medir_ejes() -> void:
	_eje_w = await _empuje(KEY_W)
	_eje_d = await _empuje(KEY_D)


## Anda DE VERDAD (teclas WASD) hasta menos de `tol` casillas del centro de `c`. false si no llega en `max_s` o si se atasca (2,5 s sin acercarse).
func _andar_a(c: Vector2i, max_s: float = 14.0, tol: float = TOL_ANDAR) -> bool:
	if _eje_w == Vector2.ZERO:
		await _medir_ejes()
	var meta: Vector3 = Terreno3D.centro_de(c, 0.0)
	var inicio: float = reloj.t
	var mejor: float = INF
	var t_mejora: float = reloj.t
	var llego: bool = false
	while reloj.t - inicio < max_s:
		if not is_instance_valid(jugador):
			break                                    # se cambió de nivel andando (la salida): ya no hay a quién mover
		var a: Vector2 = Vector2(meta.x - jugador.position.x, meta.z - jugador.position.z)
		var d: float = a.length()
		if d <= tol * Terreno3D.casilla:
			llego = true
			break
		if d < mejor - 0.05:
			mejor = d
			t_mejora = reloj.t
		elif reloj.t - t_mejora > 2.5:
			break
		var adelante: float = a.dot(_eje_w)
		var lado: float = a.dot(_eje_d)
		_tecla(KEY_W, adelante > 0.15 * d)
		_tecla(KEY_S, adelante < -0.15 * d)
		_tecla(KEY_D, lado > 0.15 * d)
		_tecla(KEY_A, lado < -0.15 * d)
		await process_frame
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_tecla(k, false)
	await avanzar(2)
	return llego or not is_instance_valid(jugador)


## Una ruta de casillas a pie. Un solo `_ok` por ruta; si se atasca dice dónde y qué hay alrededor. Cada punto es una casilla o `[casilla, tolerancia]` (para ponerse en un sitio exacto).
func _ruta(nombre: String, puntos: Array) -> bool:
	for p in puntos:
		var c: Vector2i = p if p is Vector2i else (p as Array)[0] as Vector2i
		var tol: float = TOL_ANDAR if p is Vector2i else float((p as Array)[1])
		if not await _andar_a(c, 14.0, tol):
			_ok("%s: a pie hasta %s" % [nombre, str(c)], false, "se quedó en %s (jugador %s)\n%s" % [str(celda_jugador()), str(jugador.position), _alrededor()])
			return false
	var ultimo: Variant = puntos.back()
	_ok("%s: a pie por %d tramos hasta %s" % [nombre, puntos.size(), str(ultimo if ultimo is Vector2i else (ultimo as Array)[0])], true)
	return true


## Qué hay en las 8 casillas de alrededor del jugador (letra, bloqueada, altura): para entender un atasco.
func _alrededor() -> String:
	var yo: Vector2i = celda_jugador()
	var s: String = ""
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c: Vector2i = yo + Vector2i(dx, dy)
			s += "   %s«%s»%s%s" % [str(c), Terreno3D.letra_de(c), "B" if Terreno3D.bloqueada(c) else "-", str(Terreno3D.altura_en(c))]
		s += "\n"
	return s


## Pulsa E (la tecla de coger y de abrir) y la suelta.
func _pulsar_e() -> void:
	_tecla(KEY_E, true)
	await avanzar(2)
	_tecla(KEY_E, false)
	await avanzar(2)


## Lanza hacia el centro de una casilla desde donde está el jugador DE VERDAD (no desde el centro de su casilla: andando nunca se cae justo en el centro y la flecha tiene que apuntar al blanco).
## Si no sale (sin tinta: el libro gasta tinta y se recupera sola) espera y vuelve a probar, como haría quien juega, hasta T_TINTA_MAX_S.
func _apuntar(elemento: String, glifos: Array, objetivo: Vector2i) -> bool:
	var t: float = 0.0
	while t <= T_TINTA_MAX_S:
		var a: Vector3 = Terreno3D.centro_de(objetivo, 0.0) - Vector3(jugador.position.x, 0.0, jugador.position.z)
		if lanzar(elemento, glifos, a):
			return true
		t += await avanzar_s(0.5)
	return false


## Como `lanzar` pero SIN quitar la gravedad: el hechizo vuela como en el juego. La flecha de tierra (gravedad 1) cae y se queda a UNA casilla delante del jugador, que es donde levanta su bloque o pica una veta;
## con la gravedad quitada (lo que hace `lanzar`, como el resto de escenarios) volaría plana a dos casillas y pasaría por encima de lo que está a ras de suelo. Espera a tener tinta como `_apuntar`.
func _lanzar_real(elemento: String, glifos: Array, dir: Vector3) -> bool:
	var t: float = 0.0
	while t <= T_TINTA_MAX_S:
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element(elemento)
		for g in glifos:
			lanzador.place_sigil(String(g))
		lanzador.cooldown_left[0] = 0.0
		if lanzador.lanzar_pagina_ya(0, jugador.position, Vector3(dir.x, 0.0, dir.z).normalized()):
			return true
		t += await avanzar_s(0.5)
	return false


## 28/10: lo que NACE donde se apunta (tierra + barrera), con el origen en la casilla `objetivo` recortado al alcance (`Lanzador3D.ALCANCE_ORIGEN`), como el indicador del juego.
## Es como se levanta tierra en un sitio desde que la flecha de tierra ya no deja bloque al pararse (sin ᛉ solo golpea; ESPEC §0.3). Espera a tener tinta como `_apuntar`.
func _lanzar_en_punto(elemento: String, glifos: Array, objetivo: Vector2i) -> bool:
	var t: float = 0.0
	while t <= T_TINTA_MAX_S:
		var yo: Vector3 = jugador.position
		var meta: Vector3 = Terreno3D.centro_de(objetivo, 0.0)
		var hacia: Vector3 = Vector3(meta.x - yo.x, 0.0, meta.z - yo.z)
		var tope: float = Lanzador3D.ALCANCE_ORIGEN * Terreno3D.casilla
		var origen: Vector3 = yo + (hacia if hacia.length() <= tope else hacia.normalized() * tope)
		lanzador.select_page(0)
		lanzador.clear_sequence()
		lanzador.place_element(elemento)
		for g in glifos:
			lanzador.place_sigil(String(g))
		lanzador.cooldown_left[0] = 0.0
		if lanzador.lanzar_pagina_ya(0, origen, hacia.normalized()):
			return true
		t += await avanzar_s(0.5)
	return false

func _curar() -> void:
	jugador.set("vida", VIDA_MAX)


## Espera a que no quede ningún pulso en el aire (la fuente de C5 descarga sola). Tope de 8 s.
func _sin_pulsos_en_vuelo() -> void:
	var espera: float = 0.0
	while espera < 8.0:
		if maqueta.find_children("*", "Pulso3D", true, false).is_empty():
			return
		espera += await avanzar_s(0.05)


func _esperar(cond: Callable, max_s: float) -> float:
	var t: float = 0.0
	while not bool(cond.call()) and t < max_s:
		t += await avanzar_s(0.1)
	return t


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_z = maqueta.get_node_or_null("Puzles") as Puzle3D
	_ok("1 Puzle3D monta la Cueva (27 × 25) sin avisos", _z != null and _z.avisos.is_empty(), str(_z.avisos) if _z != null else "sin Puzle3D")
	if _z == null:
		return
	_ok("1 el mapa mide 27 × 25 casillas y el jugador nace en C1 (4,17)", maqueta.get("_ancho") == 27 and maqueta.get("_alto") == 25 and celda_jugador() == Vector2i(4, 17), "%s · %s" % [str(Vector2i(int(maqueta.get("_ancho")), int(maqueta.get("_alto")))), str(celda_jugador())])
	_ok("1 se entra con todos los elementos y los glifos del libro salvo ᚱ (kit de pruebas): fuego, agua, tierra, hielo; ᚱ aún NO", Repertoire.element_active("fuego") and Repertoire.element_active("agua")
		and Repertoire.element_active("tierra") and Repertoire.element_active("hielo") and Repertoire.sigil_active("flecha") and not Repertoire.sigil_active("raido"))
	var tipos: Dictionary = {}
	for pz in _z.piezas():
		tipos[(pz as Puzle3D.Pieza).tipo] = true
	_ok("1 están montados los tipos de la fase 3: columna, estatuas, cofres, vetas con huecos, setas que maduran", tipos.has("columna") and tipos.has("estatuas") and tipos.has("cofre") and tipos.has("veta") and tipos.has("cristal")
		and _z.nodo("hueca_c1") != null and _z.nodo("estatuas_c1") != null and _z.nodo("columna_c2") != null and _z.nodo("cofre_epico") != null)
	await _c1()
	await _c2()
	await _c3()
	await _c4()
	await _c5()
	await _c6()
	await _vuelta_c1()
	await _salida()
	_color_y_luz()


# ---------------------------------------------------------------------------------------------------------------------
#  2 · C1 · La boca
# ---------------------------------------------------------------------------------------------------------------------

func _c1() -> void:
	var cristal: CristalPulso3D = _z.nodo("latido_c1") as CristalPulso3D
	var br_a: Reactivo3D = _z.nodo("br_c1a") as Reactivo3D
	var br_b: Reactivo3D = _z.nodo("br_c1b") as Reactivo3D
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("paso_norte") as Puzle3D.PuertaPuzle
	var seta_a: Recolectable3D = _z.nodo("seta_c1a") as Recolectable3D
	var seta_b: Recolectable3D = _z.nodo("seta_c1b") as Recolectable3D
	var seta_c: Recolectable3D = _z.nodo("seta_c1c") as Recolectable3D
	_ok("2 C1: el cristal, los dos braseros, la puerta del norte y las tres setas están", cristal != null and br_a != null and br_b != null and puerta != null and seta_a != null and seta_b != null and seta_c != null)
	_ok("2 C1: los braseros nacen apagados y la puerta cerrada", not br_a.is_lit and not br_b.is_lit and not puerta.abierta)
	await _esperar(func() -> bool: return cristal.latidos >= 2, 8.0)
	_ok("2 C1: el cristal late solo (pulso del escenario)", cristal.latidos >= 2, "%d latidos" % cristal.latidos)
	# Las setas tocadas por la veta maduran a seta resonante con los latidos.
	_ok("2 C1: las tres setas junto a la veta ya han MADURADO con el pulso (dan seta_resonante)", seta_a.objeto == "seta_resonante" and seta_b.objeto == "seta_resonante" and seta_c.objeto == "seta_resonante",
		"%s %s %s" % [seta_a.objeto, seta_b.objeto, seta_c.objeto])
	_ok("2 C1: cada latido las hace brillar (recibieron varios pulsos)", seta_a.pulsos_recibidos >= 1 and seta_a.maduraciones == 1)
	# A pie hasta la seta de la esquina (se pisa su casilla: la seta no bloquea y se coge a ≤ 2 u) y cogerla con E.
	if not await _ruta("2 C1", [Vector2i(3, 15), Vector2i(1, 15)]):
		return
	await _pulsar_e()
	await avanzar_s(T_AGACHARSE_S)                  # la jugadora se agacha y la coge al llegar las manos al suelo
	var cogidas: int = Estado.i().cuenta("seta_resonante")
	_ok("2 C1: con E se coge una seta madura: va a la bolsa como SETA RESONANTE (no como seta común)", cogidas == 1 and Estado.i().cuenta("seta") == 0, "resonantes %d · setas %d" % [cogidas, Estado.i().cuenta("seta")])
	# Un hechizo de fuego sobre el cristal: pulso de FUEGO por la veta hasta el brasero del fondo.
	if not await _ruta("2 C1", [Vector2i(4, 16), Vector2i(6, 17)]):
		return
	await _sin_pulsos_en_vuelo()
	var latidos0: int = cristal.latidos
	var elementos_vistos: Array = []
	cristal.late.connect(func(p: Pulso3D) -> void: elementos_vistos.append(p.elemento))
	_ok("2 C1: lanzar fuego + flecha al cristal sale", await _apuntar("fuego", ["flecha"], Vector2i(6, 15)))
	await _esperar(func() -> bool: return elementos_vistos.has("fuego"), 4.0)
	_ok("2 C1: el golpe de fuego hace latir al cristal con un pulso de FUEGO (no del jugador)", elementos_vistos.has("fuego") and cristal.latidos > latidos0, "elementos de los latidos: %s" % str(elementos_vistos))
	await _esperar(func() -> bool: return br_a.is_lit, 3.0)
	_ok("2 C1: el pulso de fuego llega por la veta al brasero (2,12) y lo ENCIENDE sin tocarlo con un hechizo", br_a.is_lit and not br_b.is_lit)
	await avanzar_s(Pulso3D.T_COLA + CristalPulso3D.ENFRIAR)
	_ok("2 C1: aún no hay esquirla (un solo golpe)", Estado.i().cuenta("esquirla_cristal") == 0)
	_ok("2 C1: un segundo hechizo sobre el cristal sale", await _apuntar("fuego", ["flecha"], Vector2i(6, 15)))
	await _esperar(func() -> bool: return cristal.esquirla_dada, 4.0)
	_ok("2 C1: a los DOS golpes el cristal suelta una ESQUIRLA a la bolsa (Objetos.mineral_de)", Estado.i().cuenta("esquirla_cristal") == 1 and cristal.esquirla_dada, "esquirlas %d" % Estado.i().cuenta("esquirla_cristal"))
	await avanzar_s(Pulso3D.T_COLA + 0.5)
	await _sin_pulsos_en_vuelo()
	# El otro brasero, a flechazos desde la sala.
	if not await _ruta("2 C1", [Vector2i(7, 14)]):
		return
	_ok("2 C1: fuego + flecha al brasero de la derecha (7,12) sale", await _apuntar("fuego", ["flecha"], Vector2i(7, 12)))
	await _esperar(func() -> bool: return br_b.is_lit, 3.0)
	_ok("2 C1: el brasero de la derecha arde", br_b.is_lit)
	await _esperar(func() -> bool: return puerta.abierta, 3.0)
	_ok("2 C1: con los dos braseros encendidos se ABRE el paso del norte (la regla del contador)", puerta.abierta and not Terreno3D.bloqueada(Vector2i(4, 10)))
	# Los braseros alumbran de verdad.
	var l_a: OmniLight3D = br_b._luz
	_ok("2 C1: la llama del brasero da una luz CÁLIDA (rojo > azul) y fuerte (≥ 2 veces la de siempre, 1,1)", l_a != null and l_a.light_color.r > l_a.light_color.b + 0.3 and l_a.light_energy >= 2.0 and br_a.mult_luz > 2.0,
		"energía %.2f · mult %.1f" % [l_a.light_energy if l_a != null else -1.0, br_a.mult_luz])
	_ok("2 C1: la luz del brasero queda por encima de la luz azul de reposo de los cristales", l_a != null and l_a.light_energy > BrilloPulso3D.LUZ_REPOSO_ENERGIA * 2.0 and l_a.omni_range >= 4.0, "alcance %.1f" % (l_a.omni_range if l_a != null else -1.0))


# ---------------------------------------------------------------------------------------------------------------------
#  3 · C2 · Las grietas
# ---------------------------------------------------------------------------------------------------------------------

func _c2() -> void:
	var cristal: CristalPulso3D = _z.nodo("latido_c2") as CristalPulso3D
	var columna: MuroAgrietado3D = _z.nodo("columna_c2") as MuroAgrietado3D
	var cofre: Puzle3D.CofrePuzle = _z.nodo("cofre_c2") as Puzle3D.CofrePuzle
	var filon: VetaPulso3D = _z.nodo("filon_c2") as VetaPulso3D
	var grieta: MuroAgrietado3D = _z.nodo("grieta") as MuroAgrietado3D
	_ok("3 C2: el cristal, la columna, el cofre del nicho, el filón y el muro agrietado están", cristal != null and columna != null and cofre != null and filon != null and grieta != null)
	if not await _ruta("3 C2", [Vector2i(4, 13), Vector2i(4, 11), Vector2i(4, 9), Vector2i(4, 7)]):
		return
	_ok("3 C2: se cruza la puerta de C1 a pie y se entra en C2 (zona de luz `cueva`)", celda_jugador().y <= 8)
	# La cascada.
	# 24/10 (Pablo: «que se vea como la del vídeo, sin el puente de ruinas»): tres canales `-` (1..3, 4..5) echan agua a ras de una terraza de roca contra la pared norte y caen JUNTOS (una cortina de 3
	# casillas) a un pozo de seis casillas (1..3, 6..7). El canal sigue siendo canal para el agua, pero su pieza de ruinas (la losa con barandillas: el «puente») ya no se dibuja.
	var sim: AguaSim3D = Terreno3D.agua_sim
	var canales: Array = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(1, 5), Vector2i(2, 5), Vector2i(3, 5)]
	var todo_canal: bool = true
	var sin_pieza: bool = true
	for c in canales:
		todo_canal = todo_canal and Terreno3D.letra_de(c as Vector2i) == "-" and Terreno3D.es_canal_ruinas(c as Vector2i)
		sin_pieza = sin_pieza and Puzle3D.piedras_ocultas.has(c)
	_ok("3 C2: el canal de la cascada (1..3, 4..5) sigue siendo canal `-` para el agua y su PIEZA DE RUINAS (el «puente») no se dibuja en ninguna de sus casillas", todo_canal and sin_pieza, "canal %s · sin pieza %s" % [str(todo_canal), str(sin_pieza)])
	var terraza: Node = (maqueta.get("_props") as Node).get_node_or_null("terraza_1_4")
	_ok("3 C2: el canal está sobre una TERRAZA de roca con pilares entre dos cortinas (láminas de agua, pilares, espuma al pie; casillas bloqueadas, fondo 1,4 u más alto)", terraza != null and (maqueta.get("_props") as Node).get_node_or_null("terraza_1_4_agua_1") != null and (maqueta.get("_props") as Node).get_node_or_null("terraza_1_4_pilar_1") != null and (maqueta.get("_props") as Node).get_node_or_null("terraza_1_4_espuma_0") != null and Terreno3D.bloqueada(Vector2i(2, 4)) and absf(Terreno3D.fondo_canal_en(Vector2i(2, 4)) - (Terreno3D.alto_suelo + Terreno3D.FONDO_CANAL + 1.4)) < 0.01,
		"fondo (2,4) %.2f" % Terreno3D.fondo_canal_en(Vector2i(2, 4)))
	var pozo: float = 0.0
	for y in range(6, 8):
		for x in range(1, 4):
			pozo += sim.profundidad_casilla(Vector2i(x, y))
	var lip_cascada: int = 0
	for x in range(1, 4):
		if sim.hay_cascada_en_casilla(Vector2i(x, 5)):
			lip_cascada += 1
	_ok("3 C2: la CASCADA corre: los tres canales echan agua, caen al pozo (3 casillas de cortina) y lo llenan (profundidad total %.2f)" % pozo, pozo > 1.2 and lip_cascada == 3 and Terreno3D.es_agua(Vector2i(2, 6)), "cortina en %d de 3 casillas del labio (x 1..3, y 5)" % lip_cascada)
	var hueco: float = 0.0
	for c in [Vector2i(4, 5), Vector2i(4, 6), Vector2i(4, 7), Vector2i(4, 4), Vector2i(2, 8)]:
		hueco = maxf(hueco, sim.profundidad_casilla(c as Vector2i))
	_ok("3 C2: el agua queda donde debe (desagüe del pozo y laterales cerrados): ni una gota sobre el suelo de la sala junto a la cascada", hueco < 0.05, "máx. en las casillas de al lado %.3f" % hueco)
	# El enlace: la veta está cortada; el pulso no pasa y la columna sigue en pie.
	await _esperar(func() -> bool: return cristal.latidos >= 2, 10.0)
	_ok("3 C2: con la veta cortada el pulso del cristal NO toca la columna (en pie, sin pulsos)", columna.pulsos_recibidos == 0 and not columna.roto_ya and not Pulso3D.enlace_tendido(Vector2i(4, 3)))
	_ok("3 C2: el nicho está cerrado: la columna bloquea su única casilla y las paredes el resto", Terreno3D.bloqueada(Vector2i(4, 2)) and Terreno3D.bloqueada(Vector2i(3, 3)) and Terreno3D.bloqueada(Vector2i(4, 1)))
	# Tierra: el bloque de enlace.
	if not await _ruta("3 C2", [[Vector2i(4, 5), TOL_EXACTA]]):
		return
	# Hasta 3 intentos: el bloque no se levanta si la jugadora lo pisa (queda en el borde de su casilla); se vuelve a colocar y se repite, como haría quien juega.
	var intentos: int = 0
	while Terreno3D.altura_en(Vector2i(4, 3)) < 1 and intentos < 3:
		intentos += 1
		if intentos > 1:
			await _ruta("3 C2", [[Vector2i(4, 5), TOL_EXACTA]])
		_ok("3 C2: tierra + barrera (nace donde apuntas) sobre el hueco (4,3) desde (4,5) sale, intento %d" % intentos, await _lanzar_en_punto("tierra", ["barrera"], Vector2i(4, 3)))
		await _esperar(func() -> bool: return Terreno3D.altura_en(Vector2i(4, 3)) >= 1, 6.0)
	_ok("3 C2: el bloque de tierra se levanta en el hueco (4,3) y la veta se completa: el hueco CONDUCE", Terreno3D.altura_en(Vector2i(4, 3)) >= 1 and Pulso3D.enlace_tendido(Vector2i(4, 3)) and Pulso3D.conduce_pulso(Vector2i(4, 3)),
		"altura %d" % Terreno3D.altura_en(Vector2i(4, 3)))
	# La tierra vive 8 s (`persiste`) y el cristal late cada 4 s: según el momento del latido en que nace el bloque, por el enlace pasan uno o dos pulsos. La columna guarda la
	# grieta, así que si el bloque se deshace con ella en pie se vuelve a levantar, como haría quien juega (hasta 2 veces más).
	var relevos: int = 0
	await _esperar(func() -> bool: return columna.roto_ya or Terreno3D.altura_en(Vector2i(4, 3)) == 0, 12.0)
	while not columna.roto_ya and relevos < 2:
		relevos += 1
		await _lanzar_en_punto("tierra", ["barrera"], Vector2i(4, 3))
		await _esperar(func() -> bool: return Terreno3D.altura_en(Vector2i(4, 3)) >= 1, 3.0)
		await _esperar(func() -> bool: return columna.roto_ya or Terreno3D.altura_en(Vector2i(4, 3)) == 0, 12.0)
	_ok("3 C2: el pulso cruza el enlace, toca la COLUMNA (golpes %d) y la tumba: cae y deja la casilla libre" % columna.golpes, columna.roto_ya and columna.pulsos_recibidos >= 2 and not Terreno3D.bloqueada(Vector2i(4, 2)), "pulsos %d · bloques de relevo %d" % [columna.pulsos_recibidos, relevos])
	await avanzar_s(MuroAgrietado3D.T_CAER + 0.5)
	_ok("3 C2: la columna terminó de caer (hacia el este) y el polvo ya subió", not columna.cayendo)
	# El nicho.
	if not await _ruta("3 C2", [Vector2i(5, 4), Vector2i(5, 2), Vector2i(4, 2), Vector2i(3, 2), Vector2i(2, 2), [Vector2i(2, 1), TOL_EXACTA]]):
		return
	var pociones0: int = Estado.i().cuenta("pocion")
	var oro0: int = Estado.i().oro
	await _pulsar_e()
	await _esperar(func() -> bool: return cofre.es_abierto, 5.0)
	_ok("3 C2: con E se abre el cofre del nicho y da una poción y 15 de oro", cofre.es_abierto and Estado.i().cuenta("pocion") == pociones0 + 1 and Estado.i().oro == oro0 + 15 and Flags.i().tiene("cueva.c2.cofre"),
		"pociones %d · oro %d" % [Estado.i().cuenta("pocion"), Estado.i().oro])
	# El filón: tierra a la veta, un trozo (mineral de veta). Desde (5,2), tierra que nace encima de la veta (7,2).
	if not await _ruta("3 C2", [Vector2i(4, 2), [Vector2i(5, 2), TOL_EXACTA]]):
		return
	_ok("3 C2: tierra + barrera sobre el filón (7,2) sale (el bloque se levanta encima de la veta)", await _lanzar_en_punto("tierra", ["barrera"], Vector2i(7, 2)))
	await _esperar(func() -> bool: return filon.trozo_dado, 4.0)
	_ok("3 C2: un hechizo de tierra pica la veta y suelta un MINERAL DE VETA (una vez, flag %s)" % filon.flag_mineral(), filon.trozo_dado and Estado.i().cuenta("mineral_veta") == 1 and Flags.i().tiene(filon.flag_mineral()), "mineral_veta %d" % Estado.i().cuenta("mineral_veta"))
	# Segunda vez: no da más.
	await avanzar_s(1.0)
	await _lanzar_en_punto("tierra", ["barrera"], Vector2i(7, 2))
	await avanzar_s(1.5)
	_ok("3 C2: la veta ya picada no suelta un segundo trozo", Estado.i().cuenta("mineral_veta") == 1)
	# El muro agrietado de la salida a C3: dos golpes de tierra desde (8,4).
	if not await _ruta("3 C2", [Vector2i(6, 3), Vector2i(8, 3), [Vector2i(8, 4), TOL_EXACTA]]):
		return
	_ok("3 C2: tierra + flecha al muro agrietado (9,4) sale (1.º golpe)", lanzar("tierra", ["flecha"], Vector3(1.0, 0.0, 0.0)))
	await avanzar_s(1.2)
	_ok("3 C2: el 2.º golpe sale", lanzar("tierra", ["flecha"], Vector3(1.0, 0.0, 0.0)))
	await _esperar(func() -> bool: return grieta.roto_ya, 4.0)
	_ok("3 C2: el muro agrietado cae a los dos golpes y deja libre el paso a C3", grieta.roto_ya and not Terreno3D.bloqueada(Vector2i(9, 4)), "golpes %d" % grieta.recibidos)
	# 28/10: la flecha de tierra ya no levanta bloque al pararse (sin ᛉ solo golpea; ESPEC §0.3): al caer el muro el paso queda libre en el acto.
	await avanzar_s(0.5)
	_ok("3 C2: el último flechazo NO deja bloque de tierra en el hueco: el paso queda del todo libre", Terreno3D.altura_en(Vector2i(9, 4)) == 0 and Terreno3D.altura_en(Vector2i(10, 4)) == 0, "alturas %d / %d" % [Terreno3D.altura_en(Vector2i(9, 4)), Terreno3D.altura_en(Vector2i(10, 4))])


# ---------------------------------------------------------------------------------------------------------------------
#  4 · C3 · El río de lava
# ---------------------------------------------------------------------------------------------------------------------

func _c3() -> void:
	var lava: Lava3D = _z.nodo("rio") as Lava3D
	var cristal: CristalPulso3D = _z.nodo("latido_c3") as CristalPulso3D
	var receptor: ReceptorPulso3D = _z.nodo("receptor_c3") as ReceptorPulso3D
	var reja: Puzle3D.PuertaPuzle = _z.nodo("reja_c3") as Puzle3D.PuertaPuzle
	var cofre: Puzle3D.CofrePuzle = _z.nodo("cofre_c3") as Puzle3D.CofrePuzle
	_ok("4 C3: la lava, el cristal, el receptor, la reja y el cofre están", lava != null and cristal != null and receptor != null and reja != null and cofre != null)
	if not await _ruta("4 C3", [Vector2i(9, 4), Vector2i(11, 4), Vector2i(12, 5)]):
		return
	_ok("4 C3: la lava bloquea el río y NO conduce el pulso: el receptor está apagado y la reja cerrada", Terreno3D.bloqueada(Vector2i(13, 5)) and not Pulso3D.conduce_pulso(Vector2i(13, 5)) and not receptor.activo and not reja.abierta)
	await _esperar(func() -> bool: return cristal.latidos >= 2, 8.0)
	_ok("4 C3: el cristal late a este lado del río y el pulso muere en la orilla (la lava no conduce)", cristal.latidos >= 2 and not receptor.activo)
	# Frío a la lava: la roca enfriada conduce. 24/10: con la flecha de AGUA REAL (`_lanzar_real`: agua + flecha CON su gravedad, como en el juego; no la «plana» de `lanzar`). La flecha vuela hasta el borde
	# de la lava (casilla sólida), se para ahí y deja el agua en la orilla de la simulación; la lava mira la simulación y se enfría (regla en `Lava3D.CADA_AGUA`). Se tira desde la orilla, pegado a la lava.
	var sin_agua: bool = Terreno3D.agua_sim.profundidad_casilla(Vector2i(12, 5)) < 0.005 and not lava.es_roca(Vector2i(13, 5))
	_ok("4 C3: antes de tirar no hay agua en la orilla (12,5) y la lava sigue siendo lava", sin_agua, "agua %.3f" % Terreno3D.agua_sim.profundidad_casilla(Vector2i(12, 5)))
	_ok("4 C3: agua + flecha REAL hacia la lava (13,5) desde la orilla sale", await _lanzar_real("agua", ["flecha"], Vector3(1.0, 0.0, 0.0)))
	await _esperar(func() -> bool: return lava.es_roca(Vector2i(13, 5)) and lava.es_roca(Vector2i(14, 5)), 6.0)
	_ok("4 C3: la flecha de agua enfría la fila 5 en ROCA (13,5) y (14,5): se pisa y CONDUCE (basalto enfriado)", lava.es_roca(Vector2i(13, 5)) and lava.es_roca(Vector2i(14, 5)) and Pulso3D.conduce_pulso(Vector2i(13, 5)) and not Terreno3D.bloqueada(Vector2i(13, 5)),
		"roca (13,5) %s · (14,5) %s · agua orilla %.3f" % [str(lava.es_roca(Vector2i(13, 5))), str(lava.es_roca(Vector2i(14, 5))), Terreno3D.agua_sim.profundidad_casilla(Vector2i(12, 5))])
	# Cruzar sobre la roca (10 s de margen) mientras el pulso la atraviesa.
	if not await _ruta("4 C3", [Vector2i(13, 5), Vector2i(14, 5), Vector2i(15, 4)]):
		return
	_ok("4 C3: se cruza el río a pie sobre la roca recién enfriada", celda_jugador().x >= 15)
	await _esperar(func() -> bool: return receptor.activo, 6.0)
	_ok("4 C3: el pulso cruza el puente de basalto y ACTIVA el receptor (flag cueva.c3.pulso)", receptor.activo and Flags.i().tiene("cueva.c3.pulso"))
	await _esperar(func() -> bool: return reja.abierta, 2.0)
	_ok("4 C3: la regla sube la reja del rincón (17,3)", reja.abierta and not Terreno3D.bloqueada(Vector2i(17, 3)))
	if not await _ruta("4 C3", [Vector2i(16, 4), Vector2i(17, 4), Vector2i(17, 3), [Vector2i(17, 2), TOL_EXACTA]]):
		return
	var oro0: int = Estado.i().oro
	await _pulsar_e()
	await _esperar(func() -> bool: return cofre.es_abierto, 5.0)
	_ok("4 C3: con E se abre el cofre común del rincón: 25 de oro y un mineral de veta", cofre.es_abierto and Estado.i().oro == oro0 + 25 and Estado.i().cuenta("mineral_veta") == 2, "oro %d · mineral_veta %d" % [Estado.i().oro, Estado.i().cuenta("mineral_veta")])
	# La roca vuelve a ser lava a los 10 s y deja de conducir.
	await _esperar(func() -> bool: return not lava.es_roca(Vector2i(13, 5)), 14.0)
	_ok("4 C3: a los 10 s la roca vuelve a ser lava: otra vez bloquea y deja de conducir (contrarreloj)", not lava.es_roca(Vector2i(13, 5)) and Terreno3D.bloqueada(Vector2i(13, 5)) and not Pulso3D.conduce_pulso(Vector2i(13, 5)))
	_ok("4 C3: el receptor y la reja ya abiertos se quedan así (no se re-cierran)", receptor.activo and reja.abierta)


# ---------------------------------------------------------------------------------------------------------------------
#  5 · C4 · La sala cerrada
# ---------------------------------------------------------------------------------------------------------------------

## Los goblins vivos de la sala C4.
func _goblins() -> Array:
	var res: Array = []
	for n in get_nodes_in_group("combate3d"):
		if is_instance_valid(n) and n is Combate3D and not (n as Combate3D).muerto and Rect2i(19, 1, 7, 8).has_point(Terreno3D.celda_de((n as Combate3D).global_position)):
			res.append(n)
	return res


func _c4() -> void:
	var cerrojo: Puzle3D.CerrojoPuzle = _z.nodo("entrada_c4") as Puzle3D.CerrojoPuzle
	var cofre: Puzle3D.CofrePuzle = _z.nodo("cofre_llave") as Puzle3D.CofrePuzle
	var cris_a: CristalPulso3D = _z.nodo("cris_c4a") as CristalPulso3D
	var cris_b: CristalPulso3D = _z.nodo("cris_c4b") as CristalPulso3D
	var veta_b: VetaPulso3D = _z.nodo("veta_c4b") as VetaPulso3D
	_ok("5 C4: el cerrojo, el cofre de la llave, los dos cristales y las vetas están", cerrojo != null and cofre != null and cris_a != null and cris_b != null and veta_b != null and (_z.nodo("veta_c4a") as VetaPulso3D).aturde > 0.0)
	_ok("5 C4: hay dos goblins en la sala y el cofre de la llave está oculto", _goblins().size() == 2 and cofre.es_oculto)
	if not await _ruta("5 C4", [Vector2i(17, 4), Vector2i(19, 4)]):
		return
	await _esperar(func() -> bool: return cerrojo.cerrado, 2.0)
	_ok("5 C4: al entrar la sala se CIERRA tras la jugadora (cerrojo en (18,4))", cerrojo.cerrado and Terreno3D.bloqueada(Vector2i(18, 4)))
	# El pulso de un cristal aturde al goblin que pisa la veta (se coloca uno encima de la veta del cristal A).
	var gs: Array = _goblins()
	var g: Combate3D = gs[0] as Combate3D
	var tope: float = float(g.get("stun_timer"))
	g.position = Terreno3D.centro_de(Vector2i(22, 2), Terreno3D.y_pies(Vector2i(22, 2)))
	g.pj.position = g.position
	g.casa = g.position
	g.quieto = true                                 # solo para la medida: sin IA no se aparta de la veta en los 0,2 s que tarda el frente
	colocar_jugador(Vector2i(20, 4))
	await avanzar_s(0.4)
	var aturdidos: Array = []
	var capta: Callable = func(p: Pulso3D) -> void: p.aturdio.connect(func(e: Node) -> void: aturdidos.append(e))
	cris_a.late.connect(capta)
	_ok("5 C4: golpear el cristal de la pared (20,2) con fuego + flecha sale", await _apuntar("fuego", ["flecha"], Vector2i(20, 2)))
	await avanzar_s(1.2)
	cris_a.late.disconnect(capta)
	_ok("5 C4: el pulso por la veta ATURDE al goblin que la pisa (%.1f s de sentido perdido)" % float(g.get("stun_timer")), aturdidos.has(g) and (float(g.get("stun_timer")) > 0.5 or tope > 0.0), "stun %.2f" % float(g.get("stun_timer")))
	g.quieto = false
	# Las estalagmitas resonantes (24/10): el pulso hace VIBRAR a la que toca; al 2.º pulso CAE como `estalagmita_rota` y aturde y daña al goblin de la casilla donde cae. La jugadora no recibe daño.
	var est_a: EstalagmitaPulso3D = _z.nodo("est_c4a") as EstalagmitaPulso3D
	_ok("5 C4: las tres estalagmitas resonantes están, en pie y sin bloquear casilla", est_a != null and _z.nodo("est_c4b") is EstalagmitaPulso3D and _z.nodo("est_c4c") is EstalagmitaPulso3D and not Terreno3D.bloqueada(Vector2i(23, 3)) and not est_a.caida_ya)
	var vida_jugadora: float = float(jugador.get("vida"))
	var celda_cae: Vector2i = Vector2i(23, 4)                        # el pulso llega por la veta de arriba (23,2): se cae hacia el sur
	g.quieto = true
	g.position = Terreno3D.centro_de(celda_cae, Terreno3D.y_pies(celda_cae))
	g.pj.position = g.position
	g.casa = g.position
	var salud_g: float = float(g.get("health"))
	# El golpe de fuego al cristal de la pared (20,2) de arriba ya mandó UN pulso por la veta (22..24,2): la estalagmita (23,3), vecina de la veta, ha vibrado con él.
	_ok("5 C4: el 1.er pulso (el del cristal, por la veta de al lado) hace VIBRAR a la estalagmita: la tocó 1 vez, no cae y no golpea a nadie", est_a.pulsos_recibidos == 1 and not est_a.caida_ya and not est_a.cayendo and est_a.golpeados.is_empty(), "pulsos %d" % est_a.pulsos_recibidos)
	Pulso3D.emitir(maqueta, [Vector2i(23, 2)], "", 4)
	await avanzar_s(EstalagmitaPulso3D.T_CAER + 1.0)
	_ok("5 C4: el 2.º pulso la TIRA hacia el sur (opuesta a la veta de la que vino) y queda `estalagmita_rota` en (23,4); el escombro no bloquea", est_a.caida_ya and est_a.dir_caida == "s" and est_a.celda_caida() == celda_cae
		and est_a.get_node_or_null("rota") != null and not Terreno3D.bloqueada(celda_cae), "dir %s · pulsos %d" % [est_a.dir_caida, est_a.pulsos_recibidos])
	_ok("5 C4: al caer ATURDE y DAÑA al goblin que estaba en la casilla donde cae", est_a.golpeados.has(g) and float(g.get("stun_timer")) > 0.5 and float(g.get("health")) < salud_g - 0.5, "stun %.1f · vida %.0f → %.0f" % [float(g.get("stun_timer")), salud_g, float(g.get("health"))])
	_ok("5 C4: la jugadora no recibe daño de la caída", float(jugador.get("vida")) >= vida_jugadora - 0.01, "%.0f → %.0f" % [vida_jugadora, float(jugador.get("vida"))])
	_ok("5 C4: la caída se recuerda (flag cueva.c4.estalagmita_a)", Flags.i().tiene("cueva.c4.estalagmita_a"))
	g.quieto = false
	# La pelea: se acerca uno a ALCANCE_FLECHA_CAS casillas (la flecha llega a ~3: de más lejos no los alcanza ni ellos se enteran) y flechas de fuego a quien esté más cerca; sin tinta se espera.
	var t_inicio: float = reloj.t
	var lanzados: int = 0
	while not _goblins().is_empty() and reloj.t - t_inicio < T_GOBLINS_MAX_S:
		_curar()
		var vivo: Combate3D = null
		var dmin: float = INF
		for n in _goblins():
			var d: float = (n as Combate3D).global_position.distance_to(jugador.position)
			if d < dmin:
				dmin = d
				vivo = n as Combate3D
		if dmin > ALCANCE_FLECHA_CAS * Terreno3D.casilla:
			await _andar_a(Terreno3D.celda_de(vivo.global_position), 1.5, ALCANCE_FLECHA_CAS - 0.5)
			continue
		if await _apuntar("fuego", ["flecha"], Terreno3D.celda_de(vivo.global_position)):
			lanzados += 1
			await avanzar_s(0.7)
		else:
			await avanzar_s(1.2)
	_ok("5 C4: los dos goblins caen a flechazos de fuego (%d flechas, %.0f s)" % [lanzados, reloj.t - t_inicio], _goblins().is_empty(), "quedan %d" % _goblins().size())
	await _esperar(func() -> bool: return not cerrojo.cerrado, 3.0)
	_ok("5 C4: al caer el último se ABRE la sala (cerrojo) y aparece el cofre de la llave", not cerrojo.cerrado and not cofre.es_oculto and cofre.es_cerrado and Flags.i().tiene("cueva.c4.limpia"))
	# Esquirla y mineral de C4 mientras no hay goblins.
	var esq0: int = Estado.i().cuenta("esquirla_cristal")
	await _sin_pulsos_en_vuelo()
	colocar_jugador(Vector2i(24, 5))
	await avanzar_s(0.4)
	_ok("5 C4: dos golpes al cristal (24,7) dan una esquirla de cristal más: el 1.º sale", await _apuntar("fuego", ["flecha"], Vector2i(24, 7)))
	await _esperar(func() -> bool: return cris_b.golpes_recibidos >= 1, 8.0)
	_ok("5 C4: el 1.º golpe llega al cristal (la flecha tarda en llegar: sale tras el gesto de lanzar)", cris_b.golpes_recibidos >= 1)
	await avanzar_s(CristalPulso3D.ENFRIAR + 0.2)
	_ok("5 C4: el 2.º golpe sale", await _apuntar("fuego", ["flecha"], Vector2i(24, 7)))
	await _esperar(func() -> bool: return cris_b.esquirla_dada, 8.0)
	_ok("5 C4: esquirla de cristal +1 (tiene %d)" % Estado.i().cuenta("esquirla_cristal"), Estado.i().cuenta("esquirla_cristal") == esq0 + 1 and cris_b.esquirla_dada, "golpes %d" % cris_b.golpes_recibidos)
	colocar_jugador(Vector2i(23, 7))
	await avanzar_s(0.4)
	var min0: int = Estado.i().cuenta("mineral_veta")
	_ok("5 C4: tierra + barrera sobre la veta de la sala (21,7) sale", await _lanzar_en_punto("tierra", ["barrera"], Vector2i(21, 7)))
	await _esperar(func() -> bool: return veta_b.trozo_dado, 4.0)
	_ok("5 C4: la veta suelta su mineral con la tierra (mineral_veta +1)", veta_b.trozo_dado and Estado.i().cuenta("mineral_veta") == min0 + 1)
	# El cofre de la llave.
	if not await _ruta("5 C4", [[Vector2i(22, 6), TOL_EXACTA]]):
		return
	await _pulsar_e()
	await _esperar(func() -> bool: return cofre.es_abierto, 5.0)
	_ok("5 C4: con E se abre el cofre y da la LLAVE (flag cueva.c4.llave)", cofre.es_abierto and Flags.i().tiene(FLAG_LLAVE))


# ---------------------------------------------------------------------------------------------------------------------
#  6 · C5 · La charca eléctrica
# ---------------------------------------------------------------------------------------------------------------------

func _c5() -> void:
	var receptor: ReceptorPulso3D = _z.nodo("ante_cofre") as ReceptorPulso3D
	var puerta: Puzle3D.PuertaPuzle = _z.nodo("puerta_llave") as Puzle3D.PuertaPuzle
	if not await _ruta("6 C5", [Vector2i(22, 8), Vector2i(22, 10), Vector2i(21, 12), Vector2i(19, 13), Vector2i(19, 15)]):
		return
	var vida: float = float(jugador.get("vida"))
	_ok("6 C5: se rodea la charca eléctrica a pie por su orilla oeste (x = 19)", celda_jugador().x == 19 and celda_jugador().y >= 15)
	await _esperar(func() -> bool: return receptor.activo, T_ESPERA_PULSO_MAX_S)
	_ok("6 C5: la fuente suelta su pulso por el agua y la veta de C5 y llega al receptor de C6 por el prisma (flag cueva.c6.pulso)", receptor.activo and Flags.i().tiene("cueva.c6.pulso"), "vida %.0f" % float(jugador.get("vida")))
	_ok("6 C5: la orilla no electrocuta (la vida no bajó)", float(jugador.get("vida")) >= vida - 0.01, "%.0f → %.0f" % [vida, float(jugador.get("vida"))])
	if not await _ruta("6 C5", [Vector2i(19, 16)]):
		return
	await _pulsar_e()
	await _esperar(func() -> bool: return puerta.abierta, 3.0)
	_ok("6 C5: con la llave, E abre la puerta de C6 (flag cueva.c6.puerta)", puerta.abierta and Flags.i().tiene("cueva.c6.puerta") and not Terreno3D.bloqueada(Vector2i(18, 16)))


# ---------------------------------------------------------------------------------------------------------------------
#  7 · C6 · El santuario
# ---------------------------------------------------------------------------------------------------------------------

func _c6() -> void:
	var tesoro: Puzle3D.CofrePuzle = _z.nodo("tesoro") as Puzle3D.CofrePuzle
	var pared: ParedHuecaPulso3D = _z.nodo("salida") as ParedHuecaPulso3D
	_ok("7 C6: el cofre legendario está cerrado y, mientras no se abre, echa su columna de luz DORADA", tesoro.es_cerrado and tesoro.columna != null and VfxCalidad3D.encendida(tesoro.columna) and tesoro.calidad == "legendario")
	if not await _ruta("7 C6", [Vector2i(17, 16), Vector2i(16, 14), [Vector2i(13, 14), TOL_EXACTA]]):
		return
	_ok("7 C6: el cofre está desellado (el receptor sigue activo)", tesoro.sellado_cumplido())
	var col_dorada: Node3D = tesoro.columna
	var motas_al_abrir: Array = [0]
	var ids0: Array = _ids_motas(tesoro.get_parent())
	tesoro.abierto.connect(func() -> void: motas_al_abrir[0] = _motas_nuevas(tesoro.get_parent(), ids0))
	await _pulsar_e()
	_ok("7 C6: con E arranca la secuencia del cofre legendario", tesoro.secuencia != null and tesoro.secuencia.activa)
	await _esperar(func() -> bool: return tesoro.secuencia.hecha, 12.0)
	_ok("7 C6: el cofre da ᚱ «pulso»: flag %s y el glifo queda en el libro" % FLAG_GLIFO, Flags.i().tiene(FLAG_GLIFO) and Repertoire.sigil_active("raido") and tesoro.es_abierto)
	_ok("7 C6: al abrirse suben MOTAS DORADAS de su color (%d emisores nuevos) y la columna de luz se apaga" % int(motas_al_abrir[0]), int(motas_al_abrir[0]) >= 1 and not VfxCalidad3D.encendida(col_dorada) and tesoro.columna == null)
	await avanzar_s(1.5)
	# La salida pide el pulso propio: el del escenario solo hace eco.
	_ok("7 C6: la pared hueca de la salida sigue cerrada hasta usar el glifo", not pared.abierta and Terreno3D.bloqueada(Vector2i(9, 16)))
	if not await _ruta("7 C6", [Vector2i(14, 15), Vector2i(12, 16), Vector2i(11, 16)]):
		return
	_ok("7 C6: lanzar ᚱ + fuego sobre la veta sale (el pulso del jugador)", await _apuntar("fuego", ["raido"], Vector2i(10, 16)))
	await _esperar(func() -> bool: return pared.abierta, 3.0)
	_ok("7 C6: el pulso del JUGADOR abre la pared hueca (flag cueva.c6.salida) y la casilla queda libre", pared.abierta and Flags.i().tiene("cueva.c6.salida") and not Terreno3D.bloqueada(Vector2i(9, 16)))
	await avanzar_s(ParedHuecaPulso3D.T_ABRIR + 0.3)
	await _sin_pulsos_en_vuelo()
	if not await _ruta("7 C6", [Vector2i(10, 16), Vector2i(8, 16)]):
		return
	_ok("7 C6: se vuelve a C1 por el atajo (8,16)", celda_jugador() == Vector2i(8, 16))


## Los emisores de motas de calidad (VfxCalidad3D) que hay ahora bajo `padre`, por su id de instancia.
func _ids_motas(padre: Node) -> Array:
	var ids: Array = []
	if padre != null:
		for n in padre.get_children():
			if n.is_in_group(VfxCalidad3D.GRUPO_MOTAS):
				ids.append(n.get_instance_id())
	return ids


## Cuántos emisores de motas hay bajo `padre` que NO estaban en `antes` (los viejos se apagan solos: contar sin más se confunde).
func _motas_nuevas(padre: Node, antes: Array) -> int:
	return _ids_motas(padre).filter(func(id: int) -> bool: return not antes.has(id)).size()


# ---------------------------------------------------------------------------------------------------------------------
#  8 · De vuelta en C1: el secreto de las estatuas
# ---------------------------------------------------------------------------------------------------------------------

func _vuelta_c1() -> void:
	var hueca: ParedHuecaPulso3D = _z.nodo("hueca_c1") as ParedHuecaPulso3D
	var est: EstatuasPulso3D = _z.nodo("estatuas_c1") as EstatuasPulso3D
	var epico: Puzle3D.CofrePuzle = _z.nodo("cofre_epico") as Puzle3D.CofrePuzle
	_ok("8 C1: la pared hueca del nicho está cerrada, el cofre épico oculto y las estatuas esperan", not hueca.abierta and epico.es_oculto and est.paso == 0 and not est.hecha and hueca._dir_sala() == Vector2i(0, -1))
	if not await _ruta("8 C1", [Vector2i(7, 17), Vector2i(7, 18)]):
		return
	# La pared hueca avisa al acercarse y se abre con el pulso del jugador.
	_ok("8 C1: la pared del nicho AVISA al acercarse (grietas en el suelo, nota grave)", hueca.avisos >= 1, "%d avisos" % hueca.avisos)
	_ok("8 C1: lanzar ᚱ + fuego junto a la pared sale", await _apuntar("fuego", ["raido"], Vector2i(7, 19)))
	await _esperar(func() -> bool: return hueca.abierta, 3.0)
	_ok("8 C1: el pulso del jugador abre la pared del nicho (flag cueva.c1.nicho)", hueca.abierta and Flags.i().tiene("cueva.c1.nicho") and not Terreno3D.bloqueada(Vector2i(7, 19)))
	await avanzar_s(ParedHuecaPulso3D.T_ABRIR + 0.3)
	# Dentro del nicho: a la losa de la primera estatua.
	if not await _ruta("8 C1", [Vector2i(7, 20), Vector2i(6, 21), [Vector2i(5, 22), TOL_EXACTA]]):
		return
	# Primero un fallo: hielo sobre la estatua que pide fuego.
	var falla: Array = [0]
	est.falla.connect(func() -> void: falla[0] += 1)
	_ok("8 C1: ᚱ + HIELO desde la losa de la 1.ª estatua (pide fuego) sale", await _apuntar("hielo", ["raido", "flecha"], Vector2i(5, 21)))
	await avanzar_s(0.8)
	_ok("8 C1: es un FALLO: la secuencia se reinicia (paso 0) y las estatuas se apagan", falla[0] == 1 and est.fallos == 1 and est.paso == 0 and not est.estatua(0).encendida)
	await _sin_pulsos_en_vuelo()
	# La secuencia buena: fuego, hielo, fuego.
	_ok("8 C1: ᚱ + fuego sobre la 1.ª estatua sale", await _apuntar("fuego", ["raido"], Vector2i(5, 21)))
	await avanzar_s(0.8)
	_ok("8 C1: la 1.ª estatua se enciende (fuego)", est.paso == 1 and est.estatua(0).encendida and est.aciertos == 1)
	await _sin_pulsos_en_vuelo()
	if not await _ruta("8 C1", [Vector2i(6, 22), [Vector2i(7, 22), TOL_EXACTA]]):
		return
	_ok("8 C1: ᚱ + hielo sobre la 2.ª estatua sale", await _apuntar("hielo", ["raido", "flecha"], Vector2i(7, 21)))
	await avanzar_s(0.8)
	_ok("8 C1: la 2.ª estatua se enciende (hielo)", est.paso == 2 and est.estatua(1).encendida and est.estatua(0).encendida)
	await _sin_pulsos_en_vuelo()
	if not await _ruta("8 C1", [Vector2i(8, 22), [Vector2i(9, 22), TOL_EXACTA]]):
		return
	_ok("8 C1: ᚱ + fuego sobre la 3.ª estatua sale", await _apuntar("fuego", ["raido"], Vector2i(9, 21)))
	await avanzar_s(0.8)
	_ok("8 C1: la secuencia fuego, hielo, fuego está completa: flag cueva.c1.estatuas, las tres encendidas", est.hecha and Flags.i().tiene(FLAG_ESTATUAS) and est.estatua(2).encendida and est.estatua(1).encendida and est.estatua(0).encendida)
	await _esperar(func() -> bool: return epico.es_cerrado, 3.0)
	_ok("8 C1: APARECE el cofre ÉPICO (8,21) y echa su columna de luz MORADA", epico.es_cerrado and not epico.es_oculto and epico.columna != null and VfxCalidad3D.encendida(epico.columna) and epico.calidad == "epico")
	var color_col: Color = Objetos.CALIDADES["epico"]["color"]
	_ok("8 C1: la columna es del color de la calidad épica (morado: azul > verde)", color_col.b > color_col.g and color_col.r > color_col.g)
	# Abrirlo: núcleo de eco.
	if not await _ruta("8 C1", [[Vector2i(8, 22), TOL_EXACTA]]):
		return
	var col_morada: Node3D = epico.columna
	var motas_epico: Array = [0]
	var ids1: Array = _ids_motas(epico.get_parent())
	epico.abierto.connect(func() -> void: motas_epico[0] = _motas_nuevas(epico.get_parent(), ids1))
	await _pulsar_e()
	await _esperar(func() -> bool: return epico.es_abierto, 6.0)
	_ok("8 C1: con E se abre el cofre épico: da el NÚCLEO DE ECO (épico) y pone la flag cueva.c1.epico", epico.es_abierto and Estado.i().cuenta("nucleo_eco") == 1 and Flags.i().tiene(FLAG_EPICO) and Objetos.calidad("nucleo_eco") == "epico", "núcleos %d" % Estado.i().cuenta("nucleo_eco"))
	await avanzar_s(VfxCalidad3D.T_APAGAR + 0.2)
	_ok("8 C1: al abrirse suben motas moradas (%d emisores nuevos) y la columna de luz se apaga" % int(motas_epico[0]), int(motas_epico[0]) >= 1 and not VfxCalidad3D.encendida(col_morada) and epico.columna == null)


# ---------------------------------------------------------------------------------------------------------------------
#  9 · La salida al Bosque
# ---------------------------------------------------------------------------------------------------------------------

func _salida() -> void:
	if not await _ruta("9 salida", [Vector2i(6, 22), Vector2i(6, 20), Vector2i(7, 20), Vector2i(7, 18), Vector2i(5, 17)]):
		return
	var vieja: Node = maqueta
	var pared: int = Time.get_ticks_msec()
	await _andar_a(Vector2i(4, 18))
	while not Niveles.en_curso and Time.get_ticks_msec() - pared < 6000 and celda_jugador().y == 18:
		await process_frame
	while Niveles.en_curso and Time.get_ticks_msec() - pared < 90000:
		await process_frame
	await avanzar_s(0.6)
	maqueta = current_scene if current_scene != null else maqueta
	_ok("9 pisar la salida de C1 (3..5,18) lleva al Bosque 01 v01 (`boca_cueva`)", maqueta != vieja and String(maqueta.get("nivel")) == "Bosque_01_v01", String(maqueta.get("nivel")) if maqueta != null else "sin escena")
	var lz: Lanzador3D = get_first_node_in_group("spellcaster") as Lanzador3D
	var j: Node3D = lz.jugador if lz != null else null
	_ok("9 la jugadora llega a la boca de la Cueva del Bosque (45,18)", j != null and Terreno3D.celda_de(j.position) == Vector2i(45, 18), str(Terreno3D.celda_de(j.position)) if j != null else "sin jugadora")
	_ok("9 trae lo ganado en la Cueva: el núcleo de eco en la bolsa y las flags de los cofres (llave, glifo, épico)", Estado.i().cuenta("nucleo_eco") == 1 and Flags.i().tiene(FLAG_GLIFO) and Flags.i().tiene(FLAG_EPICO) and Flags.i().tiene(FLAG_LLAVE))
	_ok("9 y ᚱ «pulso» SIGUE en el libro en el Bosque (Puzle3D reaplica los glifos ganados: la progresión de cada nivel los borraba)", Repertoire.sigil_active("raido"))


# ---------------------------------------------------------------------------------------------------------------------
#  10 · El color
# ---------------------------------------------------------------------------------------------------------------------

func _color_y_luz() -> void:
	var cu: Dictionary = LuzZona3D.ZONAS["cueva"]
	var sol: Color = cu["sol_color"]
	var arriba: Color = cu["ambiente_arriba"]
	var abajo: Color = cu["ambiente_abajo"]
	_ok("10 la luz de la Cueva es AZUL: sol, cielo y rebote del suelo con el azul por encima del rojo y del verde", sol.b > sol.g and sol.g > sol.r and arriba.b > arriba.g and arriba.g > arriba.r and abajo.b > abajo.g and abajo.g >= abajo.r)
	_ok("10 el azul domina de verdad (el azul del ambiente ≥ 1,6 × el rojo, arriba y abajo)", arriba.b >= 1.6 * arriba.r and abajo.b >= 1.6 * abajo.r, "arriba %.2f/%.2f · abajo %.2f/%.2f" % [arriba.b, arriba.r, abajo.b, abajo.r])
	var todas_azules: bool = true
	for z in ["cueva", "cueva_lava", "cueva_goblin", "cueva_hielo", "cueva_ruinas"]:
		var d: Dictionary = LuzZona3D.ZONAS[z]
		var a: Color = d["ambiente_arriba"]
		if not (a.b > a.r * 1.3 and a.b > a.g and float(d["sol_energia"]) <= 0.4 and float(d["ambiente_energia"]) < 0.6):
			todas_azules = false
	_ok("10 las seis salas llevan ambiente azul y oscuro (ninguna usa ya la luz naranja o verde del Bosque)", todas_azules)
	_ok("10 el brasero (energía 1,1 × 2,4) sigue claramente por encima del destello azul de los cristales (1,6) y de su reposo (0,8)", 1.1 * 2.4 > CristalPulso3D.ENERGIA_LUZ and 1.1 * 2.4 > BrilloPulso3D.LUZ_REPOSO_ENERGIA * 3.0)
