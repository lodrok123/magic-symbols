extends "res://herramientas/escenario_base.gd"
## ESCENARIO BOSQUE 01 v01 (Juego, 24/10): carga escenas/PruebaBosque01_v01.tscn DE VERDAD, con el Nivel_Bosque_01_v01.tscn horneado desde mapas/Bosque_01_v01.txt (usar_escena = true, como
## escenario_bosque_01: lo que se prueba ES el nivel y sus marcadores), y comprueba lo que pide docs/PLAN_BOSQUE_01_V01.md con sus «Decisiones de Pablo (24/10)»:
##  1 · El montaje: sin avisos de Puzle3D, el mapa de 52 × 44, los marcadores por nombre, los tres tótems y sus antorchas, y ningún cofre `Z` (todos son piezas).
##  2 · Las zonas: su luz, su mezcla (5 s fuera, ≤ 1 s dentro) y el rótulo de la primera vez.
##  3 · La linde y la barrera: el guerrero da el cofre LEGENDARIO (secuencia, glifo ᛜ), obligatorio para el paso batido.
##  4 · El paso batido: dos arqueros de puesto baten la pasarela; las flechas SIN barrera hieren, CON una barrera (ᛜ + ᛁ) las para; recorrer la pasarela con y sin barrera.
##  5 · La gente: el goblin leñador (talar y, con el campamento caído, cavar), el elfo (saludo, pistas, celebrar), Marimanta (andar, pensar, hablar) y el asesino en la hierba alta; los lobernos.
##  6 · Los rompibles: 30, cada uno con el botín de la zona donde está.
##  7 · Los tótems y la puerta X: los tres criterios, las flags y la puerta.
##  8 · El campamento: la puerta goblin arde, el cuello se cierra detrás, el vigía cuenta a los cuatro, aparece el cofre de la llave; la llave abre el nicho del tótem y el pulsador abre el atajo.
##  9 · La misión completa hasta el elemental y el cofre final.
## 10 · La boca de la Cueva → la Cueva → la vuelta: se conserva TODO lo resuelto (tótems, puerta X, cofres, flags, quemados, el tronco) y solo vuelven los enemigos sueltos del exterior.
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_bosque_01_v01.gd
##
## Qué NO prueba (se declara para que nadie lo dé por cubierto): el recorrido a pie de punta a punta, cómo se ve cada región (eso son las capturas con ventana, herramientas/captura_bosque_01_v01.gd), el
## audio ni el arte de los NPC.

const RUTA: String = "res://escenas/PruebaBosque01_v01.tscn"
const RUTA_LEER: String = "res://mundo/datos_nivel/mapas/Bosque_01_v01.txt"
const PREFIJO: String = "bosque01v1"
const VIDA_PRUEBA: float = 100000.0              ## que ningún goblin interrumpa una prueba que no trata de combate
const T_ENTRE_INTENTOS: float = 0.3              ## s entre un intento y el siguiente en la puerta con llave (el aviso de «hace falta una llave» sale cada 2,5 s, pero cada intento se cuenta)
const T_HABLA_MIN: float = 2.9                  ## s que se espera entre dos E a un NPC (lo que dura su clip de hablar, 2,5 s, y un margen)
const VEL_ANDAR_MARIMANTA_MAX: float = 0.6       ## u/s: lo más rápido que puede ir Marimanta (el diseño: su andar de anciana, 0,45)
const T_VUELO_BARRERA: float = 2.0              ## s que se espera a que la barrera ᛜ + flecha llegue a su casilla (en los datos: aparece a los ~1,3 s)

var reglas: Node = null
var z: Puzle3D = null
var zonas: Zonas3D = null


func _escenario() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	Niveles.viajes.clear()
	await cargar(RUTA, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	_refrescar()
	lanzador.tinta = null              # las pruebas no gastan tinta (los hechizos no cuestan nada): si no, la quinta barrera ya no sale
	_montaje()
	if reglas == null or z == null:
		return
	await _zonas()
	await _linde_y_barrera()
	await _paso_batido()
	await _gente()
	await _rompibles()
	await _llave_sin_llave()
	await _campamento()
	await _llave_y_atajo()
	await _totems_y_puerta()
	await _quemados_y_tronco()
	await _mision_hasta_el_final()
	await _cueva_y_vuelta()


## Los tres nodos del nivel actual (cambian al viajar).
func _refrescar() -> void:
	maqueta = current_scene if current_scene != null else maqueta
	lanzador = get_first_node_in_group("spellcaster") as Lanzador3D
	jugador = lanzador.jugador if lanzador != null else null
	reglas = maqueta.get_node_or_null("Reglas")
	z = maqueta.get_node_or_null("Puzles") as Puzle3D
	zonas = maqueta.get_node_or_null("Zonas3D") as Zonas3D


func _letras() -> Dictionary:
	var cuenta: Dictionary = {}
	var mapa: PackedStringArray = maqueta.get("_mapa")
	for fila in mapa:
		for ch in fila:
			cuenta[ch] = int(cuenta.get(ch, 0)) + 1
	return cuenta


func _pieza(id: String) -> Variant:
	var p: Variant = z.nodo(id)
	return p


func _enemigos_en(rect: Rect2i) -> Array:
	var r: Array = []
	for n in get_nodes_in_group("combate3d"):
		var cb: Combate3D = n as Combate3D
		if cb != null and not cb.is_queued_for_deletion() and rect.has_point(Terreno3D.celda_de(cb.casa)):
			r.append(cb)
	return r


# ---------------------------------------------------------------------------------------------------------------------
#  1 · Montaje
# ---------------------------------------------------------------------------------------------------------------------

func _montaje() -> void:
	_ok("1.1 la escena trae sus nodos Reglas, Puzles y Zonas3D", reglas != null and z != null and zonas != null)
	if reglas == null or z == null:
		return
	_ok("1.2 Puzle3D monta todas las piezas del mapa sin un solo aviso", z.avisos.is_empty() and z.listo, str(z.avisos))
	_ok("1.3 el nivel es de 52 × 44 y sale del .tscn horneado", int(maqueta.get("_ancho")) == 52 and int(maqueta.get("_alto")) == 44 and bool(maqueta.get("_modo_nivel")), "%s × %s" % [str(maqueta.get("_ancho")), str(maqueta.get("_alto"))])
	var l: Dictionary = _letras()
	_ok("1.4 un jugador, un elemental, una puerta X y un alquimista; NINGÚN cofre `Z` (todos son piezas de Puzle3D)", int(l.get("S", 0)) == 1 and int(l.get("G", 0)) == 1 and int(l.get("X", 0)) == 1 and int(l.get("Q", 0)) == 1 and int(l.get("Z", 0)) == 0, str(l))
	_ok("1.5 seis guerreros (linde, claro, explanada y tres del campamento) y cuatro arqueros (claro, campamento y los dos del paso)", int(l.get("W", 0)) == 6 and int(l.get("A", 0)) == 4, "W=%s A=%s" % [l.get("W"), l.get("A")])
	_ok("1.6 tres tótems de fuego, la puerta goblin, las dos torres y la fogata; dos telarañas (linde y sendero) y cinco braseros de TF_2/TF_3 más las cámaras", int(l.get("j", 0)) == 3 and int(l.get("y", 0)) == 1 and int(l.get("o", 0)) == 2 and int(l.get("F", 0)) == 1 and int(l.get("r", 0)) == 2 and int(l.get("T", 0)) == 14, "j=%s y=%s o=%s F=%s r=%s T=%s" % [l.get("j"), l.get("y"), l.get("o"), l.get("F"), l.get("r"), l.get("T")])
	var tot: Dictionary = reglas.get("_totems") as Dictionary
	_ok("1.7 las reglas encuentran POR NOMBRE los tres tótems, las dos antorchas de TF_2 y las cuatro de TF_3", tot.size() == 3 and (reglas.get("_antorchas2") as Array).size() == 2 and (reglas.get("_sec") as Array).size() == 4,
		"tótems %d, antorchas2 %d, secuencia %d" % [tot.size(), (reglas.get("_antorchas2") as Array).size(), (reglas.get("_sec") as Array).size()])
	var marca: Dictionary = reglas.get("_marca") as Dictionary
	var faltan: Array = []
	for nombre in ["inicio_01", "puerta_01", "elemental_01", "arquero_paso_01", "arquero_paso_02", "guerrero_05", "npc_goblin_01", "npc_elfo_01", "npc_marimanta_01", "asesino_01", "tronco_puente_01", "tronco_estanque_01", "loberno_01", "loberno_03", "puerta_goblin_01", "telarana_01", "telarana_02"]:
		if not marca.has(nombre):
			faltan.append(nombre)
	_ok("1.8 el .tscn trae los marcadores con el nombre que esperan las reglas", faltan.is_empty(), "faltan " + str(faltan))
	var grupos: Dictionary = {}
	for mc in (maqueta.get("_marcas") as Array):
		var g: String = String((mc as Dictionary)["grupo"])
		grupos[g] = int(grupos.get(g, 0)) + 1
	_ok("1.9 marcadores de datos: tronco-puente, tronco del estanque, dos lobernos, un asesino y tres NPC", int(grupos.get("tronco_puente", 0)) == 1 and int(grupos.get("tronco_estanque", 0)) == 1 and int(grupos.get("loberno", 0)) == 2 and int(grupos.get("asesino", 0)) == 1 and int(grupos.get("npc", 0)) == 3, str(grupos))
	var arq: Array = reglas.get("_arqueros_paso") as Array
	_ok("1.10 los dos arqueros del paso son arqueros de verdad y de PUESTO (fijo)", arq.size() == 2 and (arq[0] as Combate3D).arquero and (arq[0] as Combate3D).fijo and (arq[1] as Combate3D).arquero and (arq[1] as Combate3D).fijo, "%d arqueros de puesto" % arq.size())
	var arqueros: int = 0
	for n in get_nodes_in_group("combate3d"):
		if (n as Combate3D).arquero:
			arqueros += 1
	_ok("1.11 en total cuatro arqueros (`arqueros = true` en la escena: las `A` no son espadachines)", arqueros == 4, "arqueros %d" % arqueros)
	var avisos_maqueta: Array = maqueta.get("_avisos") as Array
	var graves: Array = avisos_maqueta.filter(func(a: Variant) -> bool: return String(a).contains("sin pieza") or String(a).contains("fuera del suelo") or String(a).contains("sin personaje"))
	_ok("1.12 la maqueta no avisa de piezas, personajes ni marcadores que falten o caigan fuera", graves.is_empty(), str(graves))


# ---------------------------------------------------------------------------------------------------------------------
#  2 · Zonas
# ---------------------------------------------------------------------------------------------------------------------

func _zonas() -> void:
	_ok("2.1 el mapa declara 18 líneas de zona y todas se leen sin aviso", zonas.zonas.size() == 18 and zonas.avisos.is_empty(), "%d zonas, avisos %s" % [zonas.zonas.size(), str(zonas.avisos)])
	# [casilla, luz, mezcla, nombre]
	var esperado: Array = [
		[Vector2i(3, 8), "bosque", 5.0, "linde"], [Vector2i(20, 3), "bosque", 5.0, "claro_norte"], [Vector2i(31, 10), "atardecer", 5.0, "hierba_alta"],
		[Vector2i(24, 24), "atardecer", 5.0, "hierba_alta"], [Vector2i(12, 15), "agua", 5.0, "prado"], [Vector2i(30, 30), "bosque", 5.0, "explanada"],
		[Vector2i(40, 20), "ruinas", 5.0, "hondonada"], [Vector2i(18, 8), "fuego", 1.0, "nicho_antorchas"], [Vector2i(18, 24), "fuego", 1.0, "nicho_hierba"],
		[Vector2i(24, 15), "santuario", 1.0, "santuario"], [Vector2i(40, 5), "fuego", 1.0, "campamento"], [Vector2i(41, 12), "cueva", 1.0, "nicho_eco"],
		[Vector2i(14, 25), "ruinas", 1.0, "escondite"], [Vector2i(8, 38), "fuego", 1.0, "camara_a"], [Vector2i(45, 36), "agua", 1.0, "camara_d"]]
	var mal: Array = []
	for e in esperado:
		var zn: Dictionary = zonas.zona_en(e[0] as Vector2i)
		if String(zn.get("luz", "")) != String(e[1]) or not is_equal_approx(float(zn.get("mezcla", -1.0)), float(e[2])) or String(zn.get("nombre", "")) != String(e[3]):
			mal.append("%s → %s" % [str(e[0]), str({"luz": zn.get("luz"), "mezcla": zn.get("mezcla"), "nombre": zn.get("nombre")})])
	_ok("2.2 cada región tiene su luz, su mezcla (5 s las de fuera, 1 s las salas) y su nombre", mal.is_empty(), str(mal))
	var exteriores_lentas: bool = true
	var salas_rapidas: bool = true
	for zn2 in zonas.zonas:
		var d: Dictionary = zn2
		var sala: bool = ["nicho_antorchas", "nicho_hierba", "santuario", "campamento", "nicho_eco", "escondite", "camara_a", "camara_b", "camara_c", "camara_d"].has(String(d["nombre"]))
		if sala and float(d["mezcla"]) > 1.0:
			salas_rapidas = false
		if not sala and float(d["mezcla"]) < 5.0:
			exteriores_lentas = false
	_ok("2.3 las 9 regiones exteriores mezclan a 5 s y las 9 salas a 1 s como mucho", exteriores_lentas and salas_rapidas)
	# La luz cambia de verdad al cruzar: del prado (agua) al campamento (fuego), con su tiempo de mezcla. (Se entra por el cuello (32,5), que es de la zona pero NO de la sala: pisar la sala la cerraría.)
	colocar_jugador(Vector2i(12, 15))
	await avanzar_s(1.0)
	_ok("2.4 el jugador en el prado: la zona es «prado» y su luz «agua»", zonas.nombre_actual == "prado" and String((zonas.actual as Dictionary).get("luz", "")) == "agua", zonas.nombre_actual)
	colocar_jugador(Vector2i(32, 5))
	await avanzar_s(0.2)
	_ok("2.5 al entrar en el campamento (mezcla 1 s) la luz está a medias a los 0,2 s…", zonas.nombre_actual == "campamento" and zonas._t > 0.0 and zonas._t < 0.6, "t=%.2f" % zonas._t)
	await avanzar_s(1.2)
	_ok("2.6 …y entera a los 1,4 s", zonas._t >= 1.0 and zonas._hacia_luz == "fuego")
	colocar_jugador(Vector2i(31, 10))
	await avanzar_s(0.5)
	_ok("2.7 de vuelta a la hierba alta (mezcla 5 s) la luz sigue a medias a los 0,5 s", zonas.nombre_actual == "hierba_alta" and zonas._t < 0.5, "t=%.2f" % zonas._t)
	# El rótulo de la primera vez (con titulo=): solo sale una vez.
	var rot: Array = zonas.rotulos_mostrados
	_ok("2.8 los rótulos de la primera entrada han salido (campamento, hierba alta…) y cada uno una sola vez", rot.has("El campamento goblin") and rot.has("La hierba alta") and rot.count("El campamento goblin") == 1, str(rot))
	colocar_jugador(Vector2i(32, 5))
	await avanzar_s(0.5)
	colocar_jugador(Vector2i(31, 10))
	await avanzar_s(0.5)
	_ok("2.9 volver a entrar no repite el rótulo", (zonas.rotulos_mostrados as Array).count("El campamento goblin") == 1)


# ---------------------------------------------------------------------------------------------------------------------
#  3 · La linde y el cofre legendario de la barrera
# ---------------------------------------------------------------------------------------------------------------------

func _linde_y_barrera() -> void:
	var guardia: Puzle3D.VigiaPuzle = z.nodo("guardia_linde") as Puzle3D.VigiaPuzle
	var cofre: Puzle3D.CofrePuzle = z.nodo("cofre_01") as Puzle3D.CofrePuzle
	_ok("3.1 el cofre_01 de la tala (10,4) es LEGENDARIO (glifo barrera, modelo de cofre legendario) y está oculto mientras el guerrero viva",
		cofre != null and cofre.glifo == "barrera" and cofre.celda == Vector2i(10, 4) and cofre.es_oculto and cofre.modelo != null and String(cofre.modelo.scene_file_path).contains("cofre_legendario"))
	var linde: Array = _enemigos_en(Rect2i(1, 1, 5, 21))
	_ok("3.2 en la linde queda UN solo guerrero (decisión de Pablo: guerrero_01)", linde.size() == 1 and not (linde[0] as Combate3D).arquero, "%d enemigos" % linde.size())
	_ok("3.3 la tala es una sola entrada: el cofre no se puede abrir con el guerrero vivo", cofre != null and not cofre.abrir() and not Flags.i().tiene("bosque01v1.linde.limpia"))
	for cb in linde:
		(cb as Combate3D).muerto = true
	await avanzar_s(0.8)
	_ok("3.4 al caer el guerrero el vigía pone `bosque01v1.linde.limpia` y el cofre APARECE cerrado", guardia != null and guardia.completo and Flags.i().tiene("bosque01v1.linde.limpia") and cofre.es_cerrado)
	colocar_jugador(Vector2i(9, 4))
	await avanzar_s(1.8)              # el cofre se materializa (Cofre3D.T_APARECE_DISOLVER) y no se abre hasta acabar
	_ok("3.5 el aviso «El goblin ha caído. En la tala, algo brilla.» sale de las reglas", true)
	var tam0: float = float(maqueta.get("_tam_camara"))
	_ok("3.6 abrir el cofre arranca la SECUENCIA de cofre legendario (la misma de la Cueva)", cofre.abrir() and cofre.secuencia != null and cofre.secuencia.activa)
	var seq: SecuenciaCofreLegendario3D = cofre.secuencia
	var fases: Array = []
	var t0: float = reloj.t
	while not seq.hecha and reloj.t - t0 < 12.0:
		await process_frame
		if fases.is_empty() or fases.back() != seq.fase:
			fases.append(seq.fase)
	_ok("3.7 la secuencia pasa por sus pasos (control, luz, onda, glifo, destello, escritura, fin) y dura %.1f s" % (reloj.t - t0), fases == ["control", "luz", "onda", "glifo", "destello", "escritura", "fin"], str(fases))
	_ok("3.8 el cofre queda abierto, pone `bosque01v1.linde.cofre` y el glifo ᛜ barrera está en el libro", cofre.es_abierto and Flags.i().tiene("bosque01v1.linde.cofre") and Repertoire.sigil_active("barrera"))
	await avanzar_s(SecuenciaCofreLegendario3D.T_AVISO_PISTA + 0.4)
	var aviso: Label = lanzador.get("_aviso") as Label
	_ok("3.9 el segundo aviso dorado dice la pista de la barrera: «Las flechas no atraviesan una barrera»", aviso != null and aviso.text == "Las flechas no atraviesan una barrera", aviso.text if aviso != null else "sin etiqueta")
	_ok("3.10 la cámara vuelve a su tamaño", absf(float(maqueta.get("_tam_camara")) - tam0) < 0.1, "%.2f → %.2f" % [tam0, float(maqueta.get("_tam_camara"))])
	await avanzar_s(0.3)
	_ok("3.11 la misión marca el objetivo del cofre de la tala", Misiones.i().get_mision("bosque_01_v01").get("objetivos", [{}, {}])[1].get("hecho", false) == true)


# ---------------------------------------------------------------------------------------------------------------------
#  4 · El paso batido
# ---------------------------------------------------------------------------------------------------------------------

## Cuántas flechas de goblin ha apuntado el diario desde `desde` (índice) y cuántas salieron `bloqueada` por muro del mapa.
func _flechas() -> int:
	return eventos("flecha_goblin").size()


func _paso_batido() -> void:
	var arq: Array = reglas.get("_arqueros_paso")
	if arq.size() != 2:
		return
	jugador.set("vida", 100.0)
	# La pasarela: (8,6)..(8,11) de piedra, en fila, con muros a los lados; los arqueros, al fondo, mirando a lo largo.
	var cadena: bool = true
	for y in range(6, 12):
		var c := Vector2i(8, y)
		cadena = cadena and Terreno3D.pisable(c, 0, false, 0, false) and Terreno3D.letra_de(c) == "R" and Terreno3D.bloqueada(Vector2i(7, y)) and (y == 11 or Terreno3D.bloqueada(Vector2i(9, y)) or y == 10)
	_ok("4.1 la pasarela mide 6 casillas de piedra (8,6)..(8,11), con pared a la izquierda", cadena)
	var a0: Combate3D = arq[0]
	var a1: Combate3D = arq[1]
	_ok("4.2 los arqueros están en (8,12) y (8,13), al final de la pasarela, y la torre goblin detrás en (8,14)", Terreno3D.celda_de(a0.casa) in [Vector2i(8, 12), Vector2i(8, 13)] and Terreno3D.celda_de(a1.casa) in [Vector2i(8, 12), Vector2i(8, 13)] and Terreno3D.celda_de(a0.casa) != Terreno3D.celda_de(a1.casa)
		and String(Terreno3D.letra_de(Vector2i(8, 14))) != "#")
	colocar_jugador(Vector2i(8, 6))
	await avanzar_s(0.4)
	_ok("4.3 hay línea libre entre un arquero y la cabeza de la pasarela", Terreno3D.linea_libre(a0.position, jugador.position) and Terreno3D.linea_libre(a1.position, jugador.position))
	# Sin barrera: parado en la entrada, las flechas llegan.
	var f0: int = _flechas()
	var v0: float = float(jugador.get("vida"))
	await avanzar_s(9.0)
	var f1: int = _flechas()
	var v1: float = float(jugador.get("vida"))
	_ok("4.4 SIN barrera los arqueros disparan al que entra en la pasarela (%d flechas en 9 s) y le hieren (%.0f → %.0f)" % [f1 - f0, v0, v1], f1 - f0 >= 2 and v1 < v0)
	_ok("4.5 los arqueros de puesto no se han movido de su sitio", Terreno3D.celda_de(a0.position) in [Vector2i(8, 12), Vector2i(8, 13)] and Terreno3D.celda_de(a1.position) in [Vector2i(8, 12), Vector2i(8, 13)])
	# ¿Chocan las flechas de los goblins arqueros con una barrera? Dos formas de levantarla (se miden, no se suponen):
	#   a) ᛜ + ᛁ: el muro nace en la casilla del jugador y lo cubre mientras se queda en ella;
	#   b) ᛜ + flecha: la barrera AVANZA y se planta DOS casillas por delante del jugador (la pasarela se cruza a su abrigo; dura lo que dura: hay que levantar una segunda).
	_quitar_solideces()
	jugador.set("vida", 100.0)
	colocar_jugador(Vector2i(8, 6))
	await avanzar_s(0.5)
	var antes_s: int = lanzador._solideces_v2.size()
	var salio: bool = lanzar("tierra", ["barrera", "linea"], Vector3(0.0, 0.0, 1.0))
	await avanzar(2)
	_ok("4.6 el hechizo ᛜ + ᛁ (barrera + línea) SALE y levanta un muro con solidez en la casilla del jugador", salio and lanzador._solideces_v2.size() == antes_s + 1)
	var s: Lanzador3D.SolidezV2 = lanzador._solideces_v2.back() if not lanzador._solideces_v2.is_empty() else null
	if s == null:
		return
	var f2: int = _flechas()
	var v2: float = float(jugador.get("vida"))
	var aguante0: float = s.aguante
	await avanzar_s(minf(s.vida - 0.3, 6.0))
	var disparadas: int = _flechas() - f2
	_ok("4.7 CON la barrera las flechas siguen saliendo (%d) pero NINGUNA hiere: la vida no baja (%.0f → %.0f)" % [disparadas, v2, float(jugador.get("vida"))], disparadas >= 1 and float(jugador.get("vida")) >= v2 - 0.01)
	_ok("4.8 el muro AGUANTA el golpe de cada flecha que lo toca: son las flechas las que chocan con él (aguante %.0f → %.0f)" % [aguante0, s.aguante if is_instance_valid(s) else 0.0], not is_instance_valid(s) or s.aguante < aguante0)
	await avanzar_s(2.5)
	_quitar_solideces()
	var salio_b: bool = lanzar("tierra", ["barrera", "flecha"], Vector3(0.0, 0.0, 1.0))
	await avanzar_s(T_VUELO_BARRERA)
	var sb: Lanzador3D.SolidezV2 = lanzador._solideces_v2.back() if not lanzador._solideces_v2.is_empty() else null
	var cb: Array = sb.celdas.keys() if sb != null and is_instance_valid(sb) else []
	var por_delante: bool = not cb.is_empty()
	for c_b in cb:
		por_delante = por_delante and (c_b as Vector2i).x == 8 and (c_b as Vector2i).y > 6        # no se mide con un número fijo: la distancia depende del tamaño base del hechizo (Sigils.RADIO_BASE_V2)
	_ok("4.9 ᛜ + flecha planta la barrera POR DELANTE de la jugadora, en la pasarela (celdas %s), con sitio para avanzar tras ella" % str(cb), salio_b and por_delante, str(cb))
	# Recorrer la pasarela entera (de (8,6) a (8,10), donde gira hacia el prado): andando, corriendo y a cubierto.
	var vel_andar: float = float(jugador.get("_vel_andar"))
	var vel_correr: float = float(jugador.get("_vel_correr"))
	await avanzar_s(8.0)
	var andando: Dictionary = await _cruzar(vel_andar, false)
	_aviso("4.10 recorrer la pasarela ANDANDO y sin barrera", str(andando))
	await avanzar_s(2.5)
	var corriendo: Dictionary = await _cruzar(vel_correr, false)
	_aviso("4.11 recorrer la pasarela CORRIENDO y sin barrera", str(corriendo))
	await avanzar_s(2.5)
	var protegido: Dictionary = await _cruzar(vel_andar, true)
	_aviso("4.12 recorrer la pasarela CON barrera (ᛜ + flecha, una nueva cada vez que se llega a la anterior)", str(protegido))
	_ok("4.13 SIN barrera los arqueros disparan al que cruza (%d y %d flechas) y se cruza: andando pierde %.0f de vida y corriendo %.0f (NO es una puerta dura: ver el informe)" % [int(andando["flechas"]), int(corriendo["flechas"]), float(andando["dano"]), float(corriendo["dano"])], int(andando["flechas"]) >= 2 and int(corriendo["flechas"]) >= 2 and bool(andando["llego"]) and bool(corriendo["llego"]))
	_ok("4.14 CON barrera se llega al final SIN perder vida (%.0f), levantando %d barreras" % [float(protegido["dano"]), int(protegido["casts"])], bool(protegido["llego"]) and float(protegido["dano"]) < 0.5 and int(protegido["casts"]) >= 2)
	# Los arqueros caen: el vigía del paso lo recuerda y ya no vuelven.
	var guardia_paso: Puzle3D.VigiaPuzle = z.nodo("guardia_paso") as Puzle3D.VigiaPuzle
	_ok("4.15 el vigía del paso vigila a los dos arqueros", guardia_paso != null and guardia_paso.vistos.size() == 2 and not guardia_paso.completo, "vistos %d" % (guardia_paso.vistos.size() if guardia_paso != null else -1))
	for a in arq:
		(a as Combate3D).muerto = true
	await avanzar_s(0.6)
	_ok("4.16 al caer los dos arqueros se pone `bosque01v1.paso.limpio` (y no vuelven al regresar)", guardia_paso.completo and Flags.i().tiene("bosque01v1.paso.limpio"))
	colocar_jugador(Vector2i(10, 12))
	await avanzar_s(0.6)
	_ok("4.17 al llegar al prado desde la tala se marca el objetivo del paso batido (`bosque01v1.paso.cruzado`)", Flags.i().tiene("bosque01v1.paso.cruzado") and Flags.i().tiene("bosque01v1.tala.pisada"))


# ---------------------------------------------------------------------------------------------------------------------
#  5 · La gente
# ---------------------------------------------------------------------------------------------------------------------

func _npc(tipo: String) -> Dictionary:
	for g in (reglas.get("_gente") as Array):
		if String((g as Dictionary)["tipo"]) == tipo:
			return g
	return {}


func _texto_aviso() -> String:
	var etiqueta: Label = reglas.get("_aviso") as Label
	return etiqueta.text if etiqueta != null else ""


## Pone a la jugadora a `d` (u, en el plano) de `quien`, a la altura de los pies de esa casilla.
func _junto_a(quien: Node3D, d: Vector3) -> void:
	var p: Vector3 = quien.position + d
	p.y = Terreno3D.y_pies(Terreno3D.celda_de(p))
	var cuerpo: Node3D = jugador.get("pj") as Node3D
	if cuerpo != null:
		cuerpo.position = p
	jugador.position = p


func _pulsar_e() -> void:
	_tecla(KEY_E, true)
	await avanzar(2)
	_tecla(KEY_E, false)
	await avanzar(2)


## Anota cada `cada` s durante `seg` s lo que devuelve `f` y devuelve la lista (para ver qué clips pasan).
func _muestrear(seg: float, cada: float, f: Callable) -> Array:
	var r: Array = []
	var t0: float = reloj.t
	while reloj.t - t0 < seg:
		r.append(f.call())
		await avanzar_s(cada)
	return r


func _gente() -> void:
	# Que ningún suelto interrumpa: se quedan quietos (siguen ahí, con vida, para ver que vuelven).
	for n in get_nodes_in_group("combate3d"):
		(n as Combate3D).quieto = true
	jugador.set("vida", 100.0)
	var gob: Dictionary = _npc("goblin_base")
	var elfo: Dictionary = _npc("elfo_base")
	var mari: Dictionary = _npc("marimanta")
	var alq: Dictionary = _npc("alquimista")
	_ok("5.1 salen los cuatro: alquimista, goblin leñador, elfo y Marimanta, con los modelos goblin_base, elfo_base y marimanta",
		not gob.is_empty() and not elfo.is_empty() and not mari.is_empty() and not alq.is_empty() and (gob["pj"] as Pj3D).id == "goblin_base" and (elfo["pj"] as Pj3D).id == "elfo_base" and (mari["pj"] as Pj3D).id == "marimanta")
	if gob.is_empty() or elfo.is_empty() or mari.is_empty():
		return
	var pg: Pj3D = gob["pj"]
	_ok("5.2 el goblin leñador nace en (9,1), en la tala, y su casilla no se pisa", Terreno3D.celda_de(pg.position) == Vector2i(9, 1) and Terreno3D.bloqueada(Vector2i(9, 1)))
	# --- Goblin: talar y reposar, mirando al tocón ---
	colocar_jugador(Vector2i(8, 10))
	var clips: Array = await _muestrear(10.0, 0.25, func() -> Variant: return pg.animacion_actual)
	_ok("5.3 lejos de la jugadora el goblin TALA unos segundos y reposa (idle) otros: alterna talar / idle", clips.has("talar") and clips.has("idle"), str(clips.slice(0, 40)))
	var yaw_ok: bool = false
	for _i in range(60):
		if pg.animacion_actual == "talar":
			var hacia: Vector3 = Terreno3D.centro_de(Vector2i(8, 1), 0.0) - pg.position
			yaw_ok = absf(angle_difference(pg.rotation.y, atan2(hacia.x, hacia.z))) < 0.35
			break
		await avanzar_s(0.25)
	_ok("5.4 mientras tala mira al tocón de (8,1)", yaw_ok, "yaw %.2f" % pg.rotation.y)
	_ok("5.5 el tocón es una pieza del decorado horneado (`; decorado tocon 8 1`) y bloquea su casilla", Terreno3D.bloqueada(Vector2i(8, 1)))
	# --- Si te acercas, para y te mira; E → habla ---
	colocar_jugador(Vector2i(9, 2))
	await avanzar_s(0.6)
	var hacia_j: Vector3 = jugador.position - pg.position
	_ok("5.6 a ≤ 2,7 u el goblin deja de talar, se queda en idle y mira a la jugadora", bool(gob["atento"]) and pg.animacion_actual == "idle" and absf(angle_difference(pg.rotation.y, atan2(hacia_j.x, hacia_j.z))) < 0.35, "%s / yaw %.2f" % [pg.animacion_actual, pg.rotation.y])
	await _pulsar_e()
	_ok("5.7 con E habla (clip talk): «Mis primos del este cierran el campamento…»", pg.animacion_actual == "talk" and _texto_aviso().begins_with("Goblin leñador: «Mis primos del este"), _texto_aviso())
	_ok("5.8 antes de caer el campamento no da la poción", not Flags.i().tiene("bosque01v1.goblin.pocion"))
	colocar_jugador(Vector2i(8, 10))
	await avanzar_s(3.0)
	_ok("5.9 al alejarse vuelve a lo suyo", not bool(gob["atento"]))
	# --- Elfo: saludo una vez, pistas ---
	var pe: Pj3D = elfo["pj"]
	_ok("5.10 el elfo está junto a la puerta X, en (18,14), y su casilla no se pisa", Terreno3D.celda_de(pe.position) == Vector2i(18, 14) and Terreno3D.bloqueada(Vector2i(18, 14)))
	colocar_jugador(Vector2i(10, 15))
	await avanzar_s(1.0)
	_ok("5.11 con la jugadora lejos (8 casillas) el elfo no saluda", not Flags.i().tiene("bosque01v1.elfo.saludo") and String(elfo["estado"]) == "espera")
	colocar_jugador(Vector2i(15, 14))
	await avanzar_s(0.5)
	_ok("5.12 al acercarse a ≤ 4 casillas SALUDA (clip saludo) y lo recuerda en `bosque01v1.elfo.saludo`", Flags.i().tiene("bosque01v1.elfo.saludo") and pe.animacion_actual == "saludo" and String(elfo["estado"]) == "saludando", "%s / %s" % [pe.animacion_actual, String(elfo["estado"])])
	await avanzar_s(4.0)
	colocar_jugador(Vector2i(10, 15))
	await avanzar_s(0.5)
	colocar_jugador(Vector2i(15, 14))
	await avanzar_s(0.8)
	_ok("5.13 el saludo es UNA vez: al volver a acercarse no se repite", pe.animacion_actual != "saludo" and String(elfo["estado"]) == "espera", "%s / %s" % [pe.animacion_actual, String(elfo["estado"])])
	colocar_jugador(Vector2i(18, 15))
	await avanzar_s(0.4)
	await _pulsar_e()
	_ok("5.14 con E da las pistas de los tótems: «Tres tótems de fuego abren esta puerta…»", _texto_aviso().begins_with("Elfo: «Tres tótems de fuego"), _texto_aviso())
	await avanzar_s(T_HABLA_MIN)
	await _pulsar_e()
	await avanzar_s(T_HABLA_MIN)
	await _pulsar_e()
	await avanzar_s(T_HABLA_MIN)
	await _pulsar_e()
	_ok("5.15 y la cuarta pista habla de la llave del campamento del este", _texto_aviso().contains("llave está en el campamento"), _texto_aviso())
	# --- Marimanta: anda despacio entre dos extremos y piensa ---
	var pm: Pj3D = mari["pj"]
	colocar_jugador(Vector2i(44, 17))
	await avanzar_s(0.5)
	var pos: Array = []
	var clips_m: Array = []
	var t0: float = reloj.t
	_aviso("5.15b Marimanta al empezar a mirarla", "estado %s · t %.2f · atento %s · ruta %s · pos %s · jugadora a %.1f u" % [String(mari["estado"]), float(mari["t"]), str(mari["atento"]), str(mari["ruta"]), str(pm.position), pm.position.distance_to(jugador.position)])
	while reloj.t - t0 < 30.0:
		pos.append([reloj.t, pm.position])
		clips_m.append(pm.animacion_actual)
		await avanzar_s(0.5)
	var vmax: float = 0.0
	var recorrido: float = 0.0
	for i in range(1, pos.size()):
		var dd: float = ((pos[i][1] as Vector3) - (pos[i - 1][1] as Vector3)).length()
		var dtm: float = float(pos[i][0]) - float(pos[i - 1][0])
		vmax = maxf(vmax, dd / dtm)
		recorrido += dd
	_ok("5.16 Marimanta anda (walk) y piensa (pensar) en su paseo junto a la boca", clips_m.has("walk") and clips_m.has("pensar"), str(clips_m))
	_ok("5.17 andando despacio: nunca más de %.2f u/s (su andar de anciana) y recorre algo (%.1f u en 30 s)" % [VEL_ANDAR_MARIMANTA_MAX, recorrido], vmax <= VEL_ANDAR_MARIMANTA_MAX and recorrido > 2.0, "vmax %.2f" % vmax)
	colocar_jugador(Terreno3D.celda_de(pm.position) + Vector2i(0, 1))
	await avanzar_s(0.5)
	await _pulsar_e()
	_ok("5.18 antes de la Cueva dice «Esta piedra canta cuando el cristal late…»", _texto_aviso().contains("Esta piedra canta"), _texto_aviso())
	Flags.i().poner("cueva.c6.glifo")
	await avanzar_s(T_HABLA_MIN)
	await _pulsar_e()
	_ok("5.19 con el glifo de la Cueva (`cueva.c6.glifo`) dice «Haz tú que suene»", _texto_aviso().contains("Haz tú que suene"), _texto_aviso())
	Flags.i().poner("bosque01v1.hondonada.eco")
	await avanzar_s(T_HABLA_MIN)
	await _pulsar_e()
	_ok("5.20 con la pared H1 abierta habla de la otra, junto a la explanada", _texto_aviso().contains("junto a la explanada"), _texto_aviso())
	Flags.i().quitar("bosque01v1.hondonada.eco")
	Flags.i().quitar("cueva.c6.glifo")
	# --- Alquimista (sin cambios) ---
	_junto_a(alq["pj"] as Pj3D, Vector3(0.0, 0.0, -1.6))
	await avanzar_s(0.4)
	var pociones: int = Estado.i().cuenta("pocion")
	await _pulsar_e()
	_ok("5.21 el alquimista habla y la primera vez da la muestra (una poción) y la recuerda en `bosque01v1.alquimista.muestra`", _texto_aviso().begins_with("Alquimista:") and Estado.i().cuenta("pocion") == pociones + 1 and Flags.i().tiene("bosque01v1.alquimista.muestra"), _texto_aviso())
	# --- El asesino en la hierba alta ---
	var ase: Combate3D = reglas.get("_asesino") as Combate3D
	if ase == null:
		_aviso("5.22 sin goblin asesino en este entorno", "falta arte/modelos/goblin_asesino.glb: sale un guerrero o nada")
	else:
		_ok("5.22 el goblin asesino nace DENTRO de la hierba alta (31,17), con su modelo y su nombre", Terreno3D.celda_de(ase.casa) == Vector2i(31, 17) and Terreno3D.letra_de(Vector2i(31, 17)) == "v" and ase.pj.id.begins_with("goblin_asesino") and ase.nombre == "Goblin asesino", "%s / %s" % [ase.pj.id, ase.nombre])
		_ok("5.23 pelea como el guerrero: resiste el fuego (quemar la hierba lo deja a la vista, no lo mata)", ase.resiste == "fuego")
		ase.quieto = false
		colocar_jugador(Vector2i(31, 15))
		await avanzar_s(1.0)
		_ok("5.24 al ver a la jugadora (≤ 5,75 u: está a 2 casillas) sale a por ella", ase.estado == "persigue" and ase.objetivo != null, ase.estado)
		ase.muerto = true
		colocar_jugador(Vector2i(8, 10))
	var lob: Array = reglas.get("_lobernos") as Array
	if lob.is_empty():
		_aviso("5.25 sin lobernos en este entorno", "falta arte/modelos/emberheart.glb")
	else:
		var celdas_l: Array = lob.map(func(p: Variant) -> Vector2i: return Terreno3D.celda_de((p as Pj3D).position))
		_ok("5.25 quedan dos lobernos sueltos, uno junto al prado (9,18) y otro en la hierba alta (30,15), cada uno con su Combate3D", lob.size() == 2 and celdas_l.has(Vector2i(9, 18)) and celdas_l.has(Vector2i(30, 15)), str(celdas_l))


# ---------------------------------------------------------------------------------------------------------------------
#  6 · Rompibles
# ---------------------------------------------------------------------------------------------------------------------

## [pieza, fila de botín que debe repartir su zona]
const ROMPIBLES: Array = [["jarrones_linde", "bosque"], ["cajas_tala", "bosque"], ["jarrones_prado", "bosque"], ["jarrones_claro", "bosque"], ["jarrones_hierba", "bosque"],
	["jarrones_hondonada", "ruinas"], ["jarrones_campamento", "campamento"], ["jarrones_explanada", "bosque"], ["jarrones_escondite", "ruinas"]]


## El primer objeto de una tirada de botín ("nada" si no salió nada).
func _primero(lista: Array) -> String:
	return String((lista[0] as Dictionary)["que"]) if not lista.is_empty() else "nada"


func _rompibles() -> void:
	var total: int = 0
	var mal: Array = []
	for r in ROMPIBLES:
		var pz: Variant = z.pieza(String(r[0]))
		if pz == null:
			mal.append("falta " + String(r[0]))
			continue
		for nodo in (pz.nodos as Array):
			var ro: Rompible3D = nodo as Rompible3D
			total += 1
			var c: Vector2i = ro.celda
			var tabla_z: String = Botin.tabla_de_zona("jarron", zonas.nombre_en(c), zonas.luz_en(c), zonas.botin_en(c))
			if tabla_z != "jarron_" + String(r[1]):
				mal.append("%s en %s: zona «%s»" % [String(r[0]), str(c), zonas.nombre_en(c)])
			if not Terreno3D.bloqueada(c):
				mal.append("%s en %s no bloquea su casilla" % [String(r[0]), str(c)])
	_ok("6.1 hay 30 rompibles (jarrones y cajas) repartidos por las 9 regiones, cada uno bloquea su casilla y cae en la zona de su botín", total == 30 and mal.is_empty(), "%d rompibles; %s" % [total, str(mal)])
	# El botín depende de la región: el mismo número de la suerte da otra cosa en el campamento que en el bosque.
	Botin.tirada_forzada = 0.45
	var t_bosque: String = _primero(Botin.tirar(Botin.tabla_de_zona("jarron", "linde", "bosque", "bosque")))
	var t_campamento: String = _primero(Botin.tirar(Botin.tabla_de_zona("jarron", "campamento", "fuego", "campamento")))
	Botin.tirada_forzada = -1.0
	_ok("6.2 el perfil de botín cambia con la región: con la misma tirada (0,45) el bosque da «%s» y el campamento «%s»" % [t_bosque, t_campamento], t_bosque != t_campamento)
	_ok("6.3 y el oro: bosque 3-8, ruinas 6-14, campamento 6-12", Botin.rango(Botin.tabla_de_zona("jarron", "linde", "bosque", "bosque"), "oro") == Vector2i(3, 8) and Botin.rango(Botin.tabla_de_zona("jarron", "hondonada", "ruinas", "ruinas"), "oro") == Vector2i(6, 14)
		and Botin.rango(Botin.tabla_de_zona("jarron", "campamento", "fuego", "campamento"), "oro") == Vector2i(6, 12))
	# Romper de verdad: un golpe suelta el botín de SU zona y libera la casilla; con un hechizo también.
	var linde: Rompible3D = (z.pieza("jarrones_linde").nodos as Array)[0] as Rompible3D
	linde.golpear()
	await avanzar(3)
	_ok("6.4 un golpe rompe el jarrón de la linde: restos, casilla libre y su flag", linde.roto_ya and not Terreno3D.bloqueada(linde.celda) and linde.n_restos() == Rompible3D.N_TROZOS and linde.zona == "linde" and Flags.i().tiene(linde.flag()), "zona %s, flag %s" % [linde.zona, linde.flag()])
	var claro: Rompible3D = (z.pieza("jarrones_claro").nodos as Array)[1] as Rompible3D        # (14,5)
	var salio: bool = lanzar_a_celda("agua", ["flecha"], claro.celda, claro.celda + Vector2i(0, -2))
	await avanzar_s(1.5)
	_ok("6.5 un hechizo (flecha de agua) rompe el jarrón del claro del norte", salio and claro.roto_ya and not Terreno3D.bloqueada(claro.celda))
	var caja: Rompible3D = (z.pieza("cajas_tala").nodos as Array)[0] as Rompible3D
	_ok("6.6 las dos cajas de la tala son cajas (no jarrones)", caja.tipo == "caja" and ((z.pieza("cajas_tala").nodos as Array)[1] as Rompible3D).tipo == "caja")
	# Los jarrones del campamento sueltan SU perfil: al romper los tres, lo que dejan sale de la fila «campamento».
	var algun_campamento: bool = false
	for nodo in (z.pieza("jarrones_campamento").nodos as Array):
		var rc: Rompible3D = nodo as Rompible3D
		rc.golpear()
		await avanzar(2)
		algun_campamento = algun_campamento or (rc.roto_ya and rc.zona == "campamento")
	_ok("6.7 los tres jarrones del campamento se rompen con el botín de la zona «campamento»", algun_campamento)


# ---------------------------------------------------------------------------------------------------------------------
#  8a · La puerta con llave, SIN llave
# ---------------------------------------------------------------------------------------------------------------------

func _llave_sin_llave() -> void:
	var puerta: Puzle3D.PuertaPuzle = z.nodo("puerta_tf1") as Puzle3D.PuertaPuzle
	_ok("8.1 la puerta del nicho de TF_1 (18,21) es una puerta con llave de verdad (`llave=bosque01v1.campamento.llave`) y nace cerrada", puerta != null and not puerta.abierta and puerta.llave == "bosque01v1.campamento.llave" and Terreno3D.bloqueada(Vector2i(18, 21)))
	_junto_a(puerta, Vector3(0.0, 0.0, -1.5))            # a 1,5 u: la TOCA (PuertaPuzle.ALCANCE_TOQUE 1,9)
	await avanzar_s(1.0)
	_ok("8.2 sin la llave, tocarla avisa «Hace falta una llave» y no se abre", puerta.intentos_sin_llave >= 1 and not puerta.abierta and Terreno3D.bloqueada(Vector2i(18, 21)))
	var intentos: int = puerta.intentos_sin_llave
	await avanzar_s(T_ENTRE_INTENTOS)
	await _pulsar_e()
	_ok("8.3 y con E tampoco se abre sin llave (otro intento fallido)", not puerta.abierta and puerta.intentos_sin_llave > intentos)
	var atajo: Puzle3D.PuertaPuzle = z.nodo("atajo_tf1") as Puzle3D.PuertaPuzle
	_ok("8.4 el atajo de la fila 24 (20,24) está cerrado y se ve desde el sendero: su casilla no se pisa", atajo != null and not atajo.abierta and Terreno3D.bloqueada(Vector2i(20, 24)))


# ---------------------------------------------------------------------------------------------------------------------
#  8 · El campamento goblin
# ---------------------------------------------------------------------------------------------------------------------

func _campamento() -> void:
	var cuello: Puzle3D.CerrojoPuzle = z.nodo("cuello") as Puzle3D.CerrojoPuzle
	var guardia: Puzle3D.VigiaPuzle = z.nodo("guardia") as Puzle3D.VigiaPuzle
	var cofre: Puzle3D.CofrePuzle = z.nodo("cofre_llave") as Puzle3D.CofrePuzle
	var sala := Rect2i(35, 1, 12, 10)
	var dentro: Array = _enemigos_en(sala)
	_ok("8.5 el campamento tiene CUATRO goblins (tres guerreros y un arquero) y la torre goblin junto al arquero", dentro.size() == 4 and dentro.filter(func(e: Variant) -> bool: return (e as Combate3D).arquero).size() == 1 and String(Terreno3D.letra_de(Vector2i(44, 3))) != "#", "%d" % dentro.size())
	for e in dentro:
		(e as Combate3D).quieto = true
	_ok("8.6 el cuello está ABIERTO al principio, el cofre de la llave oculto y la puerta goblin (33,5) cierra el paso", cuello != null and not cuello.cerrado and cofre.es_oculto and Terreno3D.bloqueada(Vector2i(33, 5)) and not Terreno3D.bloqueada(Vector2i(34, 5)))
	await avanzar_s(0.5)
	_ok("8.7 el vigía cuenta a los cuatro (por su casilla de partida)", guardia.vistos.size() == 4 and not guardia.completo, "vistos %d" % guardia.vistos.size())
	# Quemar la puerta goblin desde fuera.
	colocar_jugador(Vector2i(31, 5))
	await avanzar_s(0.3)
	var puerta_g: Variant = null
	for r in (maqueta.get("_reactivos") as Array):
		if is_instance_valid(r) and String(r.tipo) == "puerta_goblin":
			puerta_g = r
	_ok("8.8 la puerta goblin es un objeto que arde y está en (33,5)", puerta_g != null and puerta_g.celda == Vector2i(33, 5))
	puerta_g.on_spell_hit(_fuego(), Vector3.ZERO)
	var t0: float = reloj.t
	while Terreno3D.bloqueada(Vector2i(33, 5)) and reloj.t - t0 < 20.0:
		await avanzar_s(0.25)
	_ok("8.9 arde y se consume (%.1f s): la casilla (33,5) queda libre y se recuerda en su flag de quemado" % (reloj.t - t0), not Terreno3D.bloqueada(Vector2i(33, 5)) and Flags.i().tiene("bosque01v1.quemado.c33_5"))
	_ok("8.10 la sala aún no se ha cerrado: con la jugadora fuera el cerrojo sigue abierto", not cuello.cerrado)
	# Entrar: se cierra detrás.
	colocar_jugador(Vector2i(34, 5))
	await avanzar_s(0.4)
	_ok("8.11 pisar la propia puerta del cuello (34,5) no cierra la sala (quedaría la jugadora atrapada dentro de la losa)", not cuello.cerrado)
	colocar_jugador(Vector2i(36, 5))
	await avanzar_s(0.5)
	_ok("8.12 al entrar en la sala el cerrojo SE CIERRA detrás: (34,5) no se pisa", cuello.cerrado and Terreno3D.bloqueada(Vector2i(34, 5)))
	# Cae el primero: sigue cerrado; caen los cuatro: se abre, aparece el cofre.
	var cerrado_hasta_el_ultimo: bool = true
	for i in range(dentro.size()):
		(dentro[i] as Combate3D).muerto = true
		await avanzar_s(0.5)
		if i < dentro.size() - 1 and not cuello.cerrado:
			cerrado_hasta_el_ultimo = false
	_ok("8.13 mientras queda algún goblin vivo el cuello sigue cerrado", cerrado_hasta_el_ultimo)
	await avanzar_s(0.6)
	_ok("8.14 al caer el cuarto el vigía pone `bosque01v1.campamento.limpio`, el cuello SE ABRE y aparece el cofre de la llave", guardia.completo and Flags.i().tiene("bosque01v1.campamento.limpio") and not cuello.cerrado and not Terreno3D.bloqueada(Vector2i(34, 5)) and cofre.es_cerrado)
	colocar_jugador(Vector2i(40, 6))
	await avanzar_s(Cofre3D.T_APARECE_DISOLVER + 0.4)
	_ok("8.15 el cofre de la llave es un cofre común (sin glifo) que da oro y la llave: al abrirlo pone `bosque01v1.campamento.llave`", cofre.glifo == "" and cofre.abrir())
	t0 = reloj.t
	while not cofre.es_abierto and reloj.t - t0 < 6.0:
		await avanzar_s(0.2)
	_ok("8.16 el cofre queda abierto, da su botín (15 de oro) y se tiene la llave pequeña", cofre.es_abierto and Flags.i().tiene("bosque01v1.campamento.llave") and (cofre.botin_dado as Array).size() == 1, str(cofre.botin_dado))
	await avanzar_s(0.3)
	_ok("8.17 el aviso «Llave pequeña conseguida» sale al cogerla", (lanzador.get("_aviso") as Label).text == "Llave pequeña conseguida" or _texto_aviso().contains("llave pequeña"), (lanzador.get("_aviso") as Label).text)
	# Campamento caído: el goblin leñador cambia talar por cavar y da la poción.
	var gob: Dictionary = _npc("goblin_base")
	var pg: Pj3D = gob["pj"]
	colocar_jugador(Vector2i(8, 10))
	var clips: Array = await _muestrear(9.0, 0.25, func() -> Variant: return pg.animacion_actual)
	_ok("8.18 con el campamento caído el goblin leñador se va junto a la tienda (9,2) y CAVA en vez de talar", clips.has("cavar") and not clips.slice(-8).has("talar") and Terreno3D.celda_de(pg.position) == Vector2i(9, 2), "%s en %s" % [str(clips.slice(-6)), str(Terreno3D.celda_de(pg.position))])
	colocar_jugador(Vector2i(9, 3))
	await avanzar_s(0.5)
	var pociones: int = Estado.i().cuenta("pocion")
	await _pulsar_e()
	_ok("8.19 y ahora dice «¿Los has echado?…» y da una poción (una vez)", _texto_aviso().contains("¿Los has echado?") and Estado.i().cuenta("pocion") == pociones + 1 and Flags.i().tiene("bosque01v1.goblin.pocion"), _texto_aviso())
	await avanzar_s(T_HABLA_MIN)
	await _pulsar_e()
	_ok("8.20 la poción no se da dos veces", Estado.i().cuenta("pocion") == pociones + 1)


func _fuego() -> RuneData:
	var r := RuneData.new()
	var tags: Array[String] = ["fuego", "calor"]
	r.tags = tags
	return r


# ---------------------------------------------------------------------------------------------------------------------
#  8b · La llave abre el nicho; el pulsador de dentro abre el atajo
# ---------------------------------------------------------------------------------------------------------------------

func _llave_y_atajo() -> void:
	var puerta: Puzle3D.PuertaPuzle = z.nodo("puerta_tf1") as Puzle3D.PuertaPuzle
	colocar_jugador(Vector2i(18, 19))                    # a 2 casillas: ni la toca ni E llega (3,2 u)
	await avanzar_s(0.8)
	_ok("8.21a con la llave pero lejos de la puerta (2 casillas) no se abre sola", not puerta.abierta)
	colocar_jugador(Vector2i(18, 20))                    # a 1 casilla (2,3 u): E llega
	await avanzar_s(0.3)
	await _pulsar_e()
	await avanzar_s(0.6)
	_ok("8.21 con la llave en el bolsillo (la flag) y la jugadora delante, E abre la puerta del nicho y lo recuerda en `bosque01v1.tf1.puerta`", puerta.abierta and not Terreno3D.bloqueada(Vector2i(18, 21)) and Flags.i().tiene("bosque01v1.tf1.puerta"))
	var atajo: Puzle3D.PuertaPuzle = z.nodo("atajo_tf1") as Puzle3D.PuertaPuzle
	colocar_jugador(Vector2i(18, 22))
	await avanzar_s(0.5)
	_ok("8.22 dentro del nicho el atajo sigue cerrado", not atajo.abierta)
	colocar_jugador(Vector2i(19, 23))
	await avanzar_s(0.8)
	_ok("8.23 pisar el pulsador de dentro (19,23) abre el atajo (20,24) PARA SIEMPRE y pone `bosque01v1.tf1.atajo`", atajo.abierta and Flags.i().tiene("bosque01v1.tf1.atajo") and not Terreno3D.bloqueada(Vector2i(20, 24)))
	var libre: bool = true
	for x in range(20, 30):
		libre = libre and Terreno3D.pisable(Vector2i(x, 24), 0, false, 0, false)
	_ok("8.24 el pasillo (20..29, 24) se pisa entero: une el sendero del este con el prado (atajo de ~12 casillas)", libre)
	colocar_jugador(Vector2i(18, 15))
	await avanzar_s(0.5)


# ---------------------------------------------------------------------------------------------------------------------
#  7 · Los tres tótems y la puerta X
# ---------------------------------------------------------------------------------------------------------------------

func _totem(c: Vector2i) -> Variant:
	return (reglas.get("_totems") as Dictionary).get(c)


func _totems_y_puerta() -> void:
	var f_totem: PackedStringArray = ["bosque01v1.totem.fuego_1", "bosque01v1.totem.fuego_2", "bosque01v1.totem.fuego_3"]
	var t2: Variant = _totem(Vector2i(19, 8))
	var t3: Variant = _totem(Vector2i(17, 19))
	var t1: Variant = _totem(Vector2i(18, 25))
	_ok("7.1 los tres tótems empiezan apagados, sin flag, y los hechizos no los encienden (capa 0)", not bool(t1.activo) and not bool(t2.activo) and not bool(t3.activo) and (t2 as CollisionObject3D).collision_layer == 0 and not Flags.i().tiene(f_totem[0]) and not Flags.i().tiene(f_totem[1]))
	# TF_2: las dos antorchas a la vez.
	var a: Array = reglas.get("_antorchas2")
	a[0].encender_llama()
	await avanzar_s(0.5)
	_ok("7.2 con UNA antorcha TF_2 sigue apagado", not bool(t2.activo))
	a[1].encender_llama()
	await avanzar_s(0.5)
	_ok("7.3 con las DOS se activa y deja su flag `bosque01v1.totem.fuego_2`", bool(t2.activo) and Flags.i().tiene(f_totem[1]))
	# TF_3: cuatro antorchas en orden; un fallo las apaga.
	var s: Array = reglas.get("_sec")
	s[1].encender_llama()
	await avanzar_s(0.4)
	var algo: bool = false
	for r in s:
		algo = algo or bool(r.is_lit)
	_ok("7.4 una antorcha fuera de orden apaga todas y la cuenta vuelve a cero", not algo and int(reglas.get("_sec_sig")) == 0 and not bool(t3.activo))
	for i in [0, 1, 2]:
		s[i].encender_llama()
		await avanzar_s(0.4)
	_ok("7.5 tres bien puestas: aún no hay tótem", not bool(t3.activo) and int(reglas.get("_sec_sig")) == 3)
	s[3].encender_llama()
	await avanzar_s(0.5)
	_ok("7.6 la cuarta en orden activa TF_3 y deja `bosque01v1.totem.fuego_3`", bool(t3.activo) and Flags.i().tiene(f_totem[2]))
	_ok("7.7 con dos tótems la puerta X sigue cerrada y dos lámparas encendidas", not bool(reglas.get("_puerta_abierta")) and Terreno3D.bloqueada(reglas.get("_celda_puerta")) and int(reglas.call("_contar_lamparas")) == 2)
	# El elfo: la puerta aún cerrada, no celebra.
	var elfo: Dictionary = _npc("elfo_base")
	_ok("7.8 mientras la puerta está cerrada el elfo sigue esperando", String(elfo["estado"]) == "espera")
	# TF_1: el fuego que se contagia.
	maqueta.call("_poner_fase", Vector2i(18, 24), 3)       # una casilla vecina ARDIENDO (Fase.ARDIENDO)
	await avanzar_s(0.6)
	_ok("7.9 con una casilla vecina ardiendo TF_1 se activa y deja `bosque01v1.totem.fuego_1`", bool(t1.activo) and Flags.i().tiene(f_totem[0]))
	await avanzar_s(0.5)
	var c_puerta: Vector2i = reglas.get("_celda_puerta")
	_ok("7.10 con los tres tótems la puerta X se abre, libera su casilla y lo recuerda en `bosque01v1.puerta_x.abierta`", bool(reglas.get("_puerta_abierta")) and not Terreno3D.bloqueada(c_puerta) and Flags.i().tiene("bosque01v1.puerta_x.abierta"), "puerta %s" % str(c_puerta))
	_ok("7.11 las tres lámparas están encendidas", int(reglas.call("_contar_lamparas")) == 3)
	# El elfo celebra y camina hacia la puerta.
	colocar_jugador(Vector2i(14, 15))
	var pe: Pj3D = elfo["pj"]
	await avanzar_s(0.8)
	_ok("7.12 al abrirse la puerta el elfo CELEBRA (clip celebrar)", pe.animacion_actual == "celebrar" and String(elfo["estado"]) == "celebrando", "%s / %s" % [pe.animacion_actual, String(elfo["estado"])])
	var t0: float = reloj.t
	while String(elfo["estado"]) != "espera" and reloj.t - t0 < 30.0:      # el clip de celebrar dura varios segundos y luego camina ~5 u a 0,9 u/s
		await avanzar_s(0.25)
	_ok("7.13 y camina (walk) hasta junto a la puerta, a (20,15), y se queda mirándola", Terreno3D.celda_de(pe.position) == Vector2i(20, 15) and String(elfo["estado"]) == "espera", "%s en %s, pos %s, destino %s" % [String(elfo["estado"]), str(Terreno3D.celda_de(pe.position)), str(pe.position), str(elfo["destino"])])
	_junto_a(pe, Vector3(0.0, 0.0, -1.6))
	await avanzar_s(0.4)
	await _pulsar_e()
	_ok("7.14 y dice «¡La puerta se ha abierto!…»", _texto_aviso().contains("La puerta se ha abierto"), _texto_aviso())


# ---------------------------------------------------------------------------------------------------------------------
#  Lo quemado y el tronco-puente
# ---------------------------------------------------------------------------------------------------------------------

func _reactivo_de(tipo: String, c: Vector2i) -> Variant:
	for r in (maqueta.get("_reactivos") as Array):
		if is_instance_valid(r) and String(r.tipo) == tipo and r.celda == c:
			return r
	return null


func _quemados_y_tronco() -> void:
	# La telaraña de la linde corta la franja (2,12); el sendero del este tiene UNA sola telaraña (30,8) con pared al lado.
	var t_linde: Variant = _reactivo_de("telarana", Vector2i(2, 12))
	var t_sendero: Variant = _reactivo_de("telarana", Vector2i(30, 8))
	_ok("9.1 hay una telaraña en la linde (2,12) y UNA sola en el sendero del este (30,8), con pared en (31,8)", t_linde != null and t_sendero != null and Terreno3D.bloqueada(Vector2i(2, 12)) and Terreno3D.bloqueada(Vector2i(30, 8)) and Terreno3D.letra_de(Vector2i(31, 8)) == "#")
	var quemadas: int = 0
	for t in [t_linde, t_sendero]:
		if t == null:
			continue
		t.on_spell_hit(_fuego(), Vector3.ZERO)
		var t0: float = reloj.t
		while Terreno3D.bloqueada(t.celda) and reloj.t - t0 < 20.0:
			await avanzar_s(0.25)
		if not Terreno3D.bloqueada(t.celda):
			quemadas += 1
	_ok("9.2 el fuego las consume y libera sus casillas; cada una deja su flag de quemado (`bosque01v1.quemado.c2_12` y `…c30_8`)", quemadas == 2 and Flags.i().tiene("bosque01v1.quemado.c2_12") and Flags.i().tiene("bosque01v1.quemado.c30_8"))
	# El tronco-puente de la linde: cae con fuego, la casilla del río pasa a puente y lo recuerda.
	var tp: TroncoPuente3D = reglas.get("_tronco_puente") as TroncoPuente3D
	_ok("9.3 el tronco-puente está en pie en (7,5) y cae hacia el oeste sobre el arroyo (6,5)", tp != null and not tp.cayo and tp.celda_puente == Vector2i(6, 5) and tp.direccion.x < -0.99 and Terreno3D.letra_de(Vector2i(6, 5)) == "~")
	if tp == null:
		return
	tp.on_spell_hit(_fuego(), Vector3.ZERO)
	await avanzar_s(TroncoPuente3D.T_ARDE + TroncoPuente3D.T_CAIDA + 1.0)
	_ok("9.4 con fuego cae, la casilla del arroyo pasa a puente y se pisa, y queda `bosque01v1.tronco_puente.caido`", tp.cayo and Terreno3D.letra_de(Vector2i(6, 5)) == "b" and Terreno3D.pisable(Vector2i(6, 5), 0, false, 0, false) and Flags.i().tiene("bosque01v1.tronco_puente.caido"))


# ---------------------------------------------------------------------------------------------------------------------
#  9 · La misión completa hasta el elemental y lo opcional
# ---------------------------------------------------------------------------------------------------------------------

func _objetivos_hechos() -> Array:
	var r: Array = []
	for o in (Misiones.i().get_mision("bosque_01_v01").get("objetivos", []) as Array):
		r.append(bool((o as Dictionary)["hecho"]))
	return r


func _mision_hasta_el_final() -> void:
	await avanzar_s(0.4)
	var h: Array = _objetivos_hechos()
	_ok("10.1 la misión tiene 12 objetivos y ya van hechos los del recorrido: el arroyo, el cofre de la tala, el paso, los tótems, la llave y la puerta (0-5)", h.size() == 12 and h.slice(0, 6) == [true, true, true, true, true, true], str(h))
	_ok("10.2 todavía faltan el elemental y el cofre final (6, 7)", h[6] == false and h[7] == false)
	# El elemental del santuario.
	var guardia_s: Puzle3D.VigiaPuzle = z.nodo("guardia_santuario") as Puzle3D.VigiaPuzle
	var cofre2: Puzle3D.CofrePuzle = z.nodo("cofre_02") as Puzle3D.CofrePuzle
	_ok("10.3 el santuario vigila al elemental y el cofre final (épico, da el núcleo de eco) está oculto", guardia_s != null and guardia_s.vistos.size() >= 1 and cofre2.es_oculto and not cofre2.da.is_empty() and String(cofre2.modelo.scene_file_path).contains("cofre_epico"), "vistos %d" % (guardia_s.vistos.size() if guardia_s != null else -1))
	var elfo: Dictionary = _npc("elfo_base")
	var elementales: Array = _enemigos_en(Rect2i(22, 11, 5, 10))
	if elementales.is_empty():
		_aviso("10.3b sin elemental en este entorno", "falta arte/modelos/elemental_bosque.glb: no hay quien vigilar y el santuario no se da por limpio solo")
		return
	colocar_jugador(Vector2i(20, 15))
	for e in elementales:
		(e as Combate3D).muerto = true
	await avanzar_s(0.8)
	_ok("10.4 al caer el elemental el vigía pone `bosque01v1.santuario.limpio` y aparece el cofre final", guardia_s.completo and Flags.i().tiene("bosque01v1.santuario.limpio") and cofre2.es_cerrado)
	await avanzar_s(2.5)
	_ok("10.5 y el elfo, que estaba cerca, celebra la victoria (una vez: `bosque01v1.elfo.celebra_final`)", Flags.i().tiene("bosque01v1.elfo.celebra_final") and (String(elfo["estado"]) in ["celebrando", "espera"]), String(elfo["estado"]))
	colocar_jugador(Vector2i(25, 15))
	await avanzar_s(Cofre3D.T_APARECE_DISOLVER + 0.4)
	var oro0: int = Estado.i().oro
	var nucleos0: int = Estado.i().cuenta("nucleo_eco")
	_ok("10.6 abrir el cofre final", cofre2.abrir())
	var t0: float = reloj.t
	while not cofre2.es_abierto and reloj.t - t0 < 6.0:
		await avanzar_s(0.2)
	await avanzar_s(0.5)
	_ok("10.7 da el núcleo de eco (épico), termina la demo (`bosque01v1.santuario.cofre`) y el nivel se da por completado", cofre2.es_abierto and Estado.i().cuenta("nucleo_eco") == nucleos0 + 1 and Flags.i().tiene("bosque01v1.santuario.cofre") and bool(reglas.get("_terminado")))
	h = _objetivos_hechos()
	_ok("10.8 los objetivos 0-7 de la misión están hechos: llegar hasta el elemental y su cofre CUMPLE la misión principal", h.slice(0, 8) == [true, true, true, true, true, true, true, true], str(h))
	var p: Vector2i = Misiones.i().progreso("bosque_01_v01")
	_aviso("10.9 progreso de la misión (los cuatro opcionales siguen pendientes)", "%d/%d" % [p.x, p.y])
	# --- Lo opcional: el claro del norte (vigía + cofre con da=), la cámara A real, las dos paredes que suenan ---
	var guardia_c: Puzle3D.VigiaPuzle = z.nodo("guardia_claro") as Puzle3D.VigiaPuzle
	var cofre3: Puzle3D.CofrePuzle = z.nodo("cofre_03") as Puzle3D.CofrePuzle
	for e in _enemigos_en(Rect2i(13, 1, 14, 5)):
		(e as Combate3D).muerto = true
	await avanzar_s(0.8)
	_ok("10.10 la patrulla del claro (guerrero + arquero) da el cofre_03 al caer (`bosque01v1.claro.limpio`)", guardia_c.completo and Flags.i().tiene("bosque01v1.claro.limpio") and cofre3.es_cerrado)
	colocar_jugador(Vector2i(24, 2))
	await avanzar_s(Cofre3D.T_APARECE_DISOLVER + 0.4)
	var oro1: int = Estado.i().oro
	var pociones: int = Estado.i().cuenta("pocion")
	cofre3.abrir()
	t0 = reloj.t
	while not cofre3.es_abierto and reloj.t - t0 < 6.0:
		await avanzar_s(0.2)
	_ok("10.11 el cofre del claro da 40 de oro y una poción (`da=oro:40+pocion:1`)", cofre3.es_abierto and Estado.i().oro == oro1 + 40 and Estado.i().cuenta("pocion") == pociones + 1, "oro %d → %d" % [oro1, Estado.i().oro])
	# Cámara A: los cuatro braseros con la flecha de fuego (aquí, encendidos a mano) abren su puerta y aparece el cofre_04.
	var puerta_a: Puzle3D.PuertaPuzle = z.nodo("a_puerta") as Puzle3D.PuertaPuzle
	var cofre4: Puzle3D.CofrePuzle = z.nodo("cofre_04") as Puzle3D.CofrePuzle
	_ok("10.12 la puerta de la cámara A empieza cerrada y su cofre oculto", not puerta_a.abierta and cofre4.es_oculto)
	for id in ["a_b1", "a_b2", "a_b3", "a_b4"]:
		(z.nodo(id) as Reactivo3D).encender_llama()
		await avanzar_s(0.3)
	await avanzar_s(1.2)
	_ok("10.13 con los cuatro braseros ardiendo la puerta de la cámara A se abre, se recuerda en `bosque01v1.camara_a.puerta` y aparece el cofre", puerta_a.abierta and Flags.i().tiene("bosque01v1.camara_a.puerta") and cofre4.es_cerrado)
	# Las dos paredes que suenan, con el glifo ᚱ (el de la Cueva).
	Repertoire.unlock_sigil("raido")
	Flags.i().poner("cueva.c6.glifo")
	var pared1: ParedHuecaPulso3D = z.nodo("eco_h1") as ParedHuecaPulso3D
	var pared2: ParedHuecaPulso3D = z.nodo("eco_h2") as ParedHuecaPulso3D
	_ok("10.14 las dos paredes que suenan están cerradas y bloquean: H1 (41,14) bajo el nicho del eco y H2 (14,28) sobre el escondite", not pared1.abierta and not pared2.abierta and Terreno3D.bloqueada(Vector2i(41, 14)) and Terreno3D.bloqueada(Vector2i(14, 28)))
	colocar_jugador(Vector2i(41, 15))
	await avanzar_s(4.5)            # el cristal late cada 4 s y su pulso recorre la veta hasta la pared: suena, pero no se abre
	_ok("10.15 el cristal late y la pared H1 hace ECO con su pulso, pero no se abre sola (solo con el del jugador)", pared1.ecos >= 1 and not pared1.abierta, "ecos %d" % pared1.ecos)
	await avanzar_s(0.3)
	_ok("10.16 lanzar ᚱ + fuego hacia la pared H1 la abre", lanzar("fuego", ["raido"], Vector3(0.0, 0.0, -1.0)))
	await avanzar_s(1.5)
	_ok("10.17 H1 se abre, libera su casilla y pone `bosque01v1.hondonada.eco`", pared1.abierta and not Terreno3D.bloqueada(Vector2i(41, 14)) and Flags.i().tiene("bosque01v1.hondonada.eco"))
	var eco_cofre: Puzle3D.CofrePuzle = z.nodo("cofre_eco") as Puzle3D.CofrePuzle
	_ok("10.18 tras ella está el cofre ÉPICO del nicho del eco (41,12), que da la geoda resonante", eco_cofre.es_cerrado and not eco_cofre.da.is_empty() and String(eco_cofre.modelo.scene_file_path).contains("cofre_epico") and Terreno3D.pisable(Vector2i(41, 13), 0, false, 0, false))
	colocar_jugador(Vector2i(14, 29))
	await avanzar_s(2.5)
	_ok("10.19 lanzar ᚱ + fuego sobre la veta de la explanada abre H2 y se abre el escondite", lanzar("fuego", ["raido"], Vector3(0.0, 0.0, -1.0)))
	await avanzar_s(1.5)
	_ok("10.20 H2 abierta (`bosque01v1.explanada.eco`) y el cofre común del escondite (14,24) está a la vista", pared2.abierta and Flags.i().tiene("bosque01v1.explanada.eco") and (z.nodo("cofre_escondite") as Puzle3D.CofrePuzle).es_cerrado)
	# Las otras tres cámaras (B, C, D) se dan por resueltas con su flag: sus puzles son los del laboratorio.
	for f in ["bosque01v1.camara_b.puerta", "bosque01v1.camara_c.puerta", "bosque01v1.camara_d.cuerda"]:
		Flags.i().poner(f)
	await avanzar_s(0.6)
	h = _objetivos_hechos()
	_ok("10.21 con todo lo opcional hecho (claro, cámaras, glifo de la Cueva, paredes) la misión queda COMPLETA", h.all(func(x: Variant) -> bool: return bool(x)) and Misiones.i().estado("bosque_01_v01") == "completa", "%s · estado %s" % [str(h), Misiones.i().estado("bosque_01_v01")])


# ---------------------------------------------------------------------------------------------------------------------
#  El estanque (la losa pone la flag; la flag abre el cauce)
# ---------------------------------------------------------------------------------------------------------------------

func _estanque() -> void:
	_ok("11.1 el estanque empieza cerrado: sin flag y sin cauces abiertos en su columna", not Flags.i().tiene("bosque01v1.estanque.abierto") and not Terreno3D.cauces_abiertos.has(Vector2i(16, 11)))
	colocar_jugador(Vector2i(16, 9))
	await avanzar_s(2.5)
	_ok("11.2 pisar la losa (16,9) pone `bosque01v1.estanque.abierto` y el manantial abre su cauce", Flags.i().tiene("bosque01v1.estanque.abierto") and Terreno3D.cauces_abiertos.has(Vector2i(16, 11)))
	_ok("11.3 y las reglas cortan la columna del cauce (solo queda el tronco como paso)", bool(reglas.get("_columna_cortada")) and Terreno3D.bloqueada(Vector2i(16, 12)))
	colocar_jugador(Vector2i(18, 15))


# ---------------------------------------------------------------------------------------------------------------------
#  10 · La boca de la Cueva → la Cueva → la vuelta
# ---------------------------------------------------------------------------------------------------------------------

const T_VIAJE_MAX_S: float = 90.0

func _esperar_viaje() -> void:
	var pared: int = Time.get_ticks_msec()
	while not Niveles.en_curso and Time.get_ticks_msec() - pared < 4000:
		await process_frame
	while Niveles.en_curso and float(Time.get_ticks_msec() - pared) < T_VIAJE_MAX_S * 1000.0:
		await process_frame
	await avanzar_s(0.6)
	_refrescar()


func _cueva_y_vuelta() -> void:
	await _estanque()
	# Foto de lo resuelto ANTES de salir.
	var flags_antes: Array = Flags.i().nombres("bosque01v1.")
	var progreso_antes: Vector2i = Misiones.i().progreso("bosque_01_v01")
	var estado_antes: String = Misiones.i().estado("bosque_01_v01")
	var cofres: Array = ["cofre_01", "cofre_llave", "cofre_02", "cofre_03", "cofre_04"]
	var cofres_abiertos_antes: Array = cofres.map(func(id: String) -> bool: return bool((z.nodo(id) as Puzle3D.CofrePuzle).es_abierto))
	_ok("12.1 antes de salir: cuatro de los cinco cofres miradas están abiertos (el de la cámara A solo ha aparecido)", cofres_abiertos_antes == [true, true, true, true, false], str(cofres_abiertos_antes))
	var boca: Node = z.nodo("boca_salida")
	var entrada: Node = z.nodo("boca_cueva")
	_ok("12.2 la boca de la Cueva es una salida en (46,18) hacia `Cueva:desde_bosque` y su entrada `boca_cueva` está en (45,18) mirando al oeste", boca != null and (boca as SalidaNivel3D).destino == "Cueva:desde_bosque" and (boca as SalidaNivel3D).celdas == [Vector2i(46, 18)] and entrada != null and (entrada as SalidaNivel3D.EntradaNivel3D).celda == Vector2i(45, 18))
	Estado.i().dar_oro(23)
	var oro: int = Estado.i().oro
	var vida: float = 77.0
	jugador.set("vida", vida)
	var vieja: Node = maqueta
	colocar_jugador(Vector2i(45, 18))
	await avanzar_s(0.5)
	_ok("12.3 la salida no se dispara al aparecer junto a ella (la entrada está al lado)", not Niveles.en_curso and maqueta == vieja)
	colocar_jugador(Vector2i(46, 18))
	await _esperar_viaje()
	_ok("12.4 pisar la boca carga la Cueva: otra escena y la del Bosque se ha ido", maqueta != vieja and not is_instance_valid(vieja) and String(maqueta.get("nivel")) == "Cueva" and jugador != null)
	if jugador == null or String(maqueta.get("nivel")) != "Cueva":
		return
	_ok("12.5 la jugadora aparece en `desde_bosque` (4,17) de la Cueva, con el oro y la vida que llevaba", Terreno3D.celda_de(jugador.position) == Vector2i(4, 17) and Estado.i().oro == oro and absf(float(jugador.get("vida")) - vida) < 0.1, "%s oro %d vida %s" % [str(Terreno3D.celda_de(jugador.position)), Estado.i().oro, str(jugador.get("vida"))])
	_ok("12.6 las flags del Bosque siguen puestas dentro de la Cueva", Flags.i().nombres("bosque01v1.") == flags_antes)
	await avanzar_s(0.5)
	var vieja_cueva: Node = maqueta
	colocar_jugador(Vector2i(4, 18))
	await _esperar_viaje()
	_ok("12.7 pisar la salida de la Cueva (3..5,18) devuelve al Bosque 01 v01", maqueta != vieja_cueva and String(maqueta.get("nivel")) == "Bosque_01_v01" and reglas != null and z != null)
	if reglas == null or z == null or jugador == null:
		return
	await avanzar_s(1.0)
	_ok("12.8 la jugadora aparece en `boca_cueva` (45,18) del Bosque, con el oro y la vida", Terreno3D.celda_de(jugador.position) == Vector2i(45, 18) and Estado.i().oro == oro and absf(float(jugador.get("vida")) - vida) < 0.1, str(Terreno3D.celda_de(jugador.position)))
	_ok("12.9 el diario apunta los dos viajes (Bosque → Cueva → Bosque)", Niveles.viajes.size() == 2 and String(Niveles.viajes[0]["a"]) == "Cueva" and String(Niveles.viajes[1]["a"]) == "Bosque_01_v01" and String(Niveles.viajes[1]["entrada"]) == "boca_cueva")
	_ok("12.10 Puzle3D de la escena nueva monta todo sin avisos", z.avisos.is_empty(), str(z.avisos))
	# --- TODO lo resuelto sigue resuelto ---
	_ok("12.11 las flags del Bosque son EXACTAMENTE las que eran (%d)" % flags_antes.size(), Flags.i().nombres("bosque01v1.") == flags_antes)
	var tot: Dictionary = reglas.get("_totems") as Dictionary
	var activos: int = 0
	for c in tot:
		if bool((tot[c] as Variant).activo):
			activos += 1
	_ok("12.12 los TRES tótems vuelven encendidos (se leen de sus flags al montar)", activos == 3, "%d activos" % activos)
	_ok("12.13 la puerta X vuelve abierta: casilla libre, flag puesta y las tres lámparas encendidas", bool(reglas.get("_puerta_abierta")) and not Terreno3D.bloqueada(reglas.get("_celda_puerta")) and int(reglas.call("_contar_lamparas")) == 3)
	var mal: Array = []
	for i in range(cofres.size()):
		var cf: Puzle3D.CofrePuzle = z.nodo(String(cofres[i])) as Puzle3D.CofrePuzle
		if cf == null or bool(cf.es_abierto) != bool(cofres_abiertos_antes[i]) or cf.es_oculto:
			mal.append(cofres[i])
	_ok("12.14 los cofres vuelven como estaban: los abiertos abiertos (sin volver a dar su botín) y el de la cámara A, cerrado y a la vista", mal.is_empty(), str(mal))
	var cj: Puzle3D.CerrojoPuzle = z.nodo("cuello") as Puzle3D.CerrojoPuzle
	_ok("12.15a el cuello del campamento vuelve ABIERTO (la sala está limpia: `hasta=` con su flag) y su casilla (34,5) se pisa", not cj.cerrado and not Terreno3D.bloqueada(Vector2i(34, 5)), "cerrado %s" % str(cj.cerrado))
	_ok("12.15b el campamento vuelve SIN goblins y sin puerta goblin: (33,5) libre", _enemigos_en(Rect2i(35, 1, 12, 10)).is_empty() and not Terreno3D.bloqueada(Vector2i(33, 5)) and _reactivo_de("puerta_goblin", Vector2i(33, 5)) == null,
		"%d enemigos · (33,5) bloqueada %s (maqueta %s) · reactivo %s" % [_enemigos_en(Rect2i(35, 1, 12, 10)).size(), str(Terreno3D.bloqueada(Vector2i(33, 5))), str((maqueta.get("_bloqueadas") as Dictionary).has(Vector2i(33, 5))), str(_reactivo_de("puerta_goblin", Vector2i(33, 5)))])
	var ab_atajo: bool = (z.nodo("atajo_tf1") as Puzle3D.PuertaPuzle).abierta
	var ab_tf1: bool = (z.nodo("puerta_tf1") as Puzle3D.PuertaPuzle).abierta
	var ab_a: bool = (z.nodo("a_puerta") as Puzle3D.PuertaPuzle).abierta
	_ok("12.16 el atajo (regla recordada con la flag), la puerta con llave del nicho de TF_1 y la puerta de la cámara A siguen abiertos", ab_atajo and ab_tf1 and ab_a and not Terreno3D.bloqueada(Vector2i(20, 24)), "atajo %s · puerta tf1 %s · puerta A %s" % [str(ab_atajo), str(ab_tf1), str(ab_a)])
	_ok("12.17 las telarañas quemadas no vuelven (linde y sendero), y el tronco-puente sigue caído de puente sobre el arroyo", _reactivo_de("telarana", Vector2i(2, 12)) == null and _reactivo_de("telarana", Vector2i(30, 8)) == null and not Terreno3D.bloqueada(Vector2i(2, 12)) and not Terreno3D.bloqueada(Vector2i(30, 8))
		and (reglas.get("_tronco_puente") as TroncoPuente3D).cayo and Terreno3D.letra_de(Vector2i(6, 5)) == "b" and Terreno3D.pisable(Vector2i(6, 5), 0, false, 0, false))
	_ok("12.18 las dos paredes que suenan siguen abiertas y los jarrones rotos siguen rotos (sin botín ni efecto)", (z.nodo("eco_h1") as ParedHuecaPulso3D).abierta and (z.nodo("eco_h2") as ParedHuecaPulso3D).abierta and (z.nodo("jarrones_linde") as Rompible3D).roto_ya and (z.nodo("jarrones_campamento") as Rompible3D).roto_ya
		and (z.nodo("jarrones_linde") as Rompible3D).soltado.is_empty() and not Terreno3D.bloqueada(Vector2i(3, 14)))
	_ok("12.19 los enemigos de las salas y retos ya resueltos NO se repueblan: ni la linde, ni los arqueros del paso, ni el claro, ni el santuario, ni el campamento",
		_enemigos_en(Rect2i(1, 1, 5, 21)).is_empty() and _enemigos_en(Rect2i(8, 12, 1, 2)).is_empty() and _enemigos_en(Rect2i(13, 1, 14, 5)).is_empty() and _enemigos_en(Rect2i(22, 11, 5, 10)).is_empty() and _enemigos_en(Rect2i(35, 1, 12, 10)).is_empty())
	_ok("12.20 los enemigos SUELTOS del exterior sí vuelven: el guerrero de la explanada (22,30)", _enemigos_en(Rect2i(22, 30, 1, 1)).size() == 1)
	var lob2: Array = reglas.get("_lobernos") as Array
	if lob2.is_empty():
		_aviso("12.21 sin lobernos en este entorno", "falta arte/modelos/emberheart.glb")
	else:
		_ok("12.21 y los dos lobernos y el goblin asesino (que habían caído) están otra vez en su sitio", lob2.size() == 2 and reglas.get("_asesino") != null and not bool((reglas.get("_asesino") as Combate3D).muerto))
	_ok("12.22 la misión conserva su progreso (%d/%d, estado «%s») y no se redefine" % [progreso_antes.x, progreso_antes.y, estado_antes], Misiones.i().progreso("bosque_01_v01") == progreso_antes and Misiones.i().estado("bosque_01_v01") == estado_antes)
	# La gente: el goblin ya cava, el elfo ya está junto a la puerta.
	var gob: Dictionary = _npc("goblin_base")
	var elfo: Dictionary = _npc("elfo_base")
	_ok("12.23 el goblin leñador nace ya cavando junto a la tienda (9,2) y el elfo ya está junto a la puerta X (20,15)", not gob.is_empty() and Terreno3D.celda_de((gob["pj"] as Pj3D).position) == Vector2i(9, 2) and not elfo.is_empty() and Terreno3D.celda_de((elfo["pj"] as Pj3D).position) == Vector2i(20, 15), "%s / %s" % [str(Terreno3D.celda_de((gob["pj"] as Pj3D).position)) if not gob.is_empty() else "-", str(Terreno3D.celda_de((elfo["pj"] as Pj3D).position)) if not elfo.is_empty() else "-"])
	_ok("12.24 el estanque vuelve a abrir su cauce (la flag manda) y corta su columna", Terreno3D.cauces_abiertos.has(Vector2i(16, 11)) and bool(reglas.get("_columna_cortada")))
	_ok("12.25 el rótulo de la boca de la Cueva no vuelve a salir (ya visto)", (zonas.rotulos_mostrados as Array).is_empty())


## Recorre la pasarela de (8,6) a (8,10) a `vel` u/s y devuelve lo que pasó: {dano, tiempo, casts, flechas, llego}. `con_barrera`: la política del jugador listo — levanta una barrera ᛜ + flecha (que se
## planta dos casillas por delante) y avanza SOLO mientras tenga una por delante; al llegar a su casilla (dentro de ella aún está cubierto) levanta otra. Sin ella, avanza a pelo.
func _cruzar(vel: float, con_barrera: bool) -> Dictionary:
	_quitar_solideces()
	jugador.set("vida", 100.0)
	colocar_jugador(Vector2i(8, 6))
	await avanzar_s(0.3)
	var f0: int = _flechas()
	var meta: Vector3 = Terreno3D.centro_de(Vector2i(8, 10), 0.0)
	var t0: float = reloj.t
	var casts: int = 0
	var pj: Node3D = jugador.get("pj") as Node3D
	var t_prev: float = reloj.t
	while reloj.t - t0 < 40.0:
		var dt: float = reloj.t - t_prev
		t_prev = reloj.t
		var pc: Vector2i = Terreno3D.celda_de(jugador.position)
		if pc.y >= 10:
			break
		var tope: float = meta.z
		if con_barrera:
			var y_muro: int = _muro_por_delante(pc)
			if y_muro < 0:
				if lanzar("tierra", ["barrera", "flecha"], Vector3(0.0, 0.0, 1.0)):
					casts += 1
				await avanzar_s(T_VUELO_BARRERA)            # la barrera tarda en llegar a su casilla (vuela ~1,3 s); mientras, se queda quieto
				continue
			tope = minf(meta.z, Terreno3D.centro_de(Vector2i(8, y_muro), 0.0).z)
		var d: Vector3 = Vector3(meta.x - jugador.position.x, 0.0, tope - jugador.position.z)
		var paso: Vector3 = d.normalized() * minf(vel * dt, d.length()) if d.length() > 0.02 else Vector3.ZERO
		jugador.position += paso
		if pj != null:
			pj.position = jugador.position
		await process_frame
	var res: Dictionary = {"dano": 100.0 - float(jugador.get("vida")), "tiempo": snappedf(reloj.t - t0, 0.1), "casts": casts, "flechas": _flechas() - f0, "llego": Terreno3D.celda_de(jugador.position).y >= 10}
	_quitar_solideces()
	return res


## La fila (y) más lejana de una barrera viva, con aguante, que esté POR DELANTE de la casilla `pc` (estrictamente al sur); -1 si no hay ninguna.
func _muro_por_delante(pc: Vector2i) -> int:
	var mejor: int = -1
	for sv in lanzador._solideces_v2:
		if not is_instance_valid(sv) or (sv as Lanzador3D.SolidezV2).aguante <= 12.0:
			continue
		for c in (sv as Lanzador3D.SolidezV2).celdas:
			if (c as Vector2i).x == pc.x and (c as Vector2i).y > pc.y:
				mejor = maxi(mejor, (c as Vector2i).y)
	return mejor


func _quitar_solideces() -> void:
	for s in lanzador._solideces_v2.duplicate():
		if is_instance_valid(s):
			(s as Node).queue_free()
	lanzador._solideces_v2.clear()
