extends "res://herramientas/escenario_base.gd"
## LIBRO × COMBINACIONES (24/10, auditoría de Hechizo, propuesta 3): en el Bosque 01 v01 con el kit «pruebas», TODAS las recetas que el
## jugador puede componer en el libro (multiconjuntos de 0 a 3 glifos de los 8 dibujables) × los 6 elementos se ponen en la página 1
## con la API del libro (`place_element` / `place_sigil`, que respeta 1 glifo por hueco y los huecos abiertos de la lámina) y se lanzan
## con `lanzar_pagina_ya`. Cada una tiene que SALIR (al menos una manifestación) o ser rechazada con un aviso CONOCIDO: página sin glifos,
## sólido de más de 2 niveles de altura (GeometriaV2.aviso_materia) o tinta insuficiente. Cualquier otro rechazo, un hechizo que «sale»
## sin nacer nada, o un error de script, es FALLO.
## Fallo que evita: una receta que el libro deja componer y el juego ni lanza ni explica (el jugador pulsa y no pasa nada), que es lo que
## ninguna prueba miraba (prueba_hechizo / prueba_receta_v2 construyen el hechizo, pero no pasan por el libro ni por el Lanzador).
## Qué NO prueba: el reconocimiento del dibujo (prueba_glifos_dibujables), el apuntado con ratón ni el conjuro animado (se lanza sin él).
## Se quitan los enemigos del nivel: no es una prueba de combate y un goblin que mata a la jugadora a media tanda no dice nada del libro.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_libro_combinaciones.gd   (salida con errores: añade 2>&1)

const RUTA_NIVEL: String = "res://escenas/PruebaBosque01_v01.tscn"
const ELEMENTOS: PackedStringArray = ["fuego", "agua", "viento", "tierra", "rayo", "hielo"]
## Los 8 glifos dibujables con el nombre con que entran en la página (ᛁ se parte en sus dos lecturas, ancho y fondo; ᛏ cuenta como «altura»).
const GLIFOS: PackedStringArray = ["flecha", "barrera", "linea_x", "linea_z", "altura", "repeticion", "rebote", "pulso"]
const MAX_GLIFOS_RECETA: int = 3                 ## los huecos abiertos de la lámina «bosque» (orden_huecos = 3)
const RECETAS_ESPERADAS: int = 165               ## 1 + 8 + 36 + 120
const T_ESPERA: float = 2.0                      ## s máximos que se espera a que mueran los hechizos de un lanzamiento
const LADO_ZONA: int = 7                         ## la zona despejada y llana: LADO_ZONA × LADO_ZONA casillas sin agua ni bloqueo. Debía ser 8, pero el mapa del Bosque 01 v01 no tiene ninguna de 8 × 8 (medido: el mayor cuadrado limpio es de 7)
const MARGEN_ZONA: int = 0                       ## anillo de casillas limpias alrededor de la zona (el nivel es un bosque: ni con 1 cabe una de 8 × 8)
const ZONAS_MAX: int = 4                        ## cuántas zonas se buscan (se rota entre ellas si una se ensucia de agua)
const SEPARACION_ZONAS: int = 10                 ## casillas mínimas entre zonas distintas
const ESPERA_PUEDE_LANZAR_S: float = 5.0         ## s máximos que se espera a que la jugadora pueda lanzar (gesto del lanzamiento anterior, rodar, beber…)
const VOLUMEN_RETIRADO: float = 1000.0           ## u³ que se piden retirar de cada casilla al limpiar (de sobra: retira todo el agua que haya)
const CASILLAS_APUNTADAS: float = 3.0           ## a cuántas casillas por delante "apunta el ratón" en lo que nace donde apuntas (`en_punto`)
const DIRECCION: Vector3 = Vector3.RIGHT         ## hacia dónde se apunta siempre
const INTENTOS_HUECOS: int = 8                   ## glifos que se intentan meter para ver cuántos admite la página
const TOPE_FALLOS_MOSTRADOS: int = 40            ## no se imprimen más de estos fallos de lanzamiento (el recuento sí es completo)

## Motivos de rechazo CONOCIDOS.
const R_VACIA: String = "página sin glifos"
const R_ALTURA: String = "altura de sólido de más de 2 niveles"
const R_TINTA: String = "tinta insuficiente"
const R_NO_CABE: String = "construcción imposible, sin cobrar"      ## aviso «Ahí no se puede construir» de un sólido quieto: sin gastar tinta ni recarga (24/10)
const AVISO_NO_CABE: String = "Ahí no se puede construir"

var _zonas: Array = []                           ## Array de Rect2i (esquina + tamaño) en casillas
var _zona_actual: int = 0
var _permanentes_base: Dictionary = {}
var _ultimo_g: Dictionary = {}                   ## la geometría del último hechizo anunciado (señal `hechizo_v2`): para explicar un "no nació nada"
var _lanzados: Array = []                        ## lo que anuncia la señal `lanzado` en el lanzamiento en curso


func _escenario() -> void:
	var t0: int = Time.get_ticks_msec()
	await cargar(RUTA_NIVEL, true)
	if maqueta == null or jugador == null or lanzador == null:
		return
	await avanzar(10)
	# Sin enemigos: no se prueba combate.
	for n in get_nodes_in_group("combate3d"):
		(n as Node).queue_free()
	await avanzar(2)

	_ok("1 el kit «pruebas» tiene los 6 elementos y los 8 glifos activos", _kit_completo(), "elementos %s · glifos %s" % [str(Repertoire.active_elements()), str(Repertoire.active_sigils())])
	_ok("1b hay tinta (el coste se cobra de verdad)", lanzador.tinta != null)
	lanzador.lanzado.connect(func(elem: String, forma: String, n: int) -> void: _lanzados.append([elem, forma, n]))
	lanzador.hechizo_v2.connect(func(_estado: String, _elem: String, g: Dictionary, _origen: Vector3, _dir: Vector3, _props: Dictionary) -> void: _ultimo_g = g)
	_permanentes_base = Terreno3D.permanentes.duplicate()

	_zonas = _buscar_zonas()
	_ok("2 hay una zona despejada y llana de %d × %d casillas" % [LADO_ZONA, LADO_ZONA], not _zonas.is_empty(), "%d zonas: %s" % [_zonas.size(), str(_zonas)])
	if _zonas.is_empty():
		_volcar_mapa_limpio()
		return

	_huecos()
	var recetas: Array = _recetas()
	_ok("3 hay %d recetas lanzables (0 a %d glifos de %d)" % [RECETAS_ESPERADAS, MAX_GLIFOS_RECETA, GLIFOS.size()], recetas.size() == RECETAS_ESPERADAS, str(recetas.size()))

	# --- El barrido ---
	var salen: int = 0
	var rechazos: Dictionary = {R_VACIA: 0, R_ALTURA: 0, R_TINTA: 0, R_NO_CABE: 0}
	var falladas: int = 0
	var cuantas: int = 0
	var vivos_al_plazo: int = 0
	var peor_espera: float = 0.0
	var mostrados: int = 0
	var t_barrido: int = Time.get_ticks_msec()
	print("--- barrido: %d recetas × %d elementos ---" % [recetas.size(), ELEMENTOS.size()])
	for elemento in ELEMENTOS:
		for receta in recetas:
			cuantas += 1
			var r: Dictionary = await _lanzar_receta(String(elemento), receta as Array)
			var etiqueta: String = "%s + [%s]" % [elemento, ", ".join(PackedStringArray(receta))]
			var res: String = String(r["res"])
			if res == "sale":
				salen += 1
			elif rechazos.has(res):
				rechazos[res] = int(rechazos[res]) + 1
			else:
				falladas += 1
				if mostrados < TOPE_FALLOS_MOSTRADOS:
					mostrados += 1
					_ok("barrido %s" % etiqueta, false, "%s" % String(r["info"]))
				else:
					_fallos += 1
			if bool(r["vivo_al_plazo"]):
				vivos_al_plazo += 1
			peor_espera = maxf(peor_espera, float(r["espera"]))
			print("   [%3d/%d] %-40s -> %s %s" % [cuantas, recetas.size() * ELEMENTOS.size(), etiqueta, res, String(r["info"])])
	var t_total: float = float(Time.get_ticks_msec() - t_barrido) / 1000.0

	print("--- resultado del barrido ---")
	print("    lanzadas (salen)            : %d" % salen)
	print("    rechazadas · %-34s: %d" % [R_VACIA, int(rechazos[R_VACIA])])
	print("    rechazadas · %-34s: %d" % [R_ALTURA, int(rechazos[R_ALTURA])])
	print("    rechazadas · %-34s: %d" % [R_TINTA, int(rechazos[R_TINTA])])
	print("    rechazadas · %-34s: %d" % [R_NO_CABE, int(rechazos[R_NO_CABE])])
	print("    falladas (rechazo raro o nada nace): %d" % falladas)
	print("    hechizos aún vivos al agotar T_ESPERA (%.1f s): %d · tiempo simulado máximo esperado %.2f s" % [T_ESPERA, vivos_al_plazo, peor_espera])
	print("    tiempo de pared del barrido: %.1f s (total del escenario %.1f s)" % [t_total, float(Time.get_ticks_msec() - t0) / 1000.0])
	_ok("4 se barrieron todas las combinaciones", cuantas == recetas.size() * ELEMENTOS.size(), "%d" % cuantas)
	_ok("5 ninguna receta falla (cada una sale o se rechaza con un aviso conocido)", falladas == 0, "%d falladas" % falladas)
	_ok("5b las páginas vacías son rechazadas por «sin glifos» (una por elemento)", int(rechazos[R_VACIA]) == ELEMENTOS.size(), str(rechazos[R_VACIA]))
	_ok("5c con la tinta llena ninguna receta se rechaza por tinta", int(rechazos[R_TINTA]) == 0, "%d (114 de las 990 cuestan la barra entera: debería alcanzar)" % int(rechazos[R_TINTA]))
	_ok("5d salieron todas las demás (990 − vacías − altura − sin cabida)", salen + int(rechazos[R_VACIA]) + int(rechazos[R_ALTURA]) + int(rechazos[R_TINTA]) + int(rechazos[R_NO_CABE]) + falladas == cuantas)
	if int(rechazos[R_NO_CABE]) > 0:
		_aviso("8 hay %d recetas de sólido quieto que no caben en la casilla apuntada (aviso conocido «%s»; no cobraron tinta ni recarga)" % [int(rechazos[R_NO_CABE]), AVISO_NO_CABE])
	if int(rechazos[R_ALTURA]) > 0:
		_aviso("7 hay %d recetas de sólido (tierra/hielo) rechazadas por altura de más de 2 niveles (aviso conocido; el jugador las compone y no salen)" % int(rechazos[R_ALTURA]))


## El kit «pruebas»: 6 elementos y 8 glifos (tal como los nombra el repertorio: linea_x/linea_z son la lectura de «linea»).
func _kit_completo() -> bool:
	for e in ELEMENTOS:
		if not Repertoire.element_active(e):
			return false
	for g in GLIFOS:
		if not Repertoire.sigil_active(Sigils.repertorio_de(g)):
			return false
	return true


## Todos los multiconjuntos de 0 a MAX_GLIFOS_RECETA glifos, en orden estable.
func _recetas() -> Array:
	var res: Array = [[]]
	var parcial: Array = [[]]
	for _tam in range(MAX_GLIFOS_RECETA):
		var nuevo: Array = []
		for p in parcial:
			var desde: int = 0 if (p as Array).is_empty() else GLIFOS.find((p as Array).back())
			for i in range(desde, GLIFOS.size()):
				var q: Array = (p as Array).duplicate()
				q.append(GLIFOS[i])
				nuevo.append(q)
		res.append_array(nuevo)
		parcial = nuevo
	return res


# ---------------------------------------------------------------------------------------------------------------------
#  Huecos del libro
# ---------------------------------------------------------------------------------------------------------------------

## Ninguna página admite más glifos que huecos abiertos. Se intentan INTENTOS_HUECOS por la paleta y se cuenta cuántos entran; y se
## comprueba que un sector ocupado rechaza al segundo glifo.
func _huecos() -> void:
	var libro: Object = lanzador.libro
	var restringe: bool = libro != null and libro.has_method("restringe_huecos") and bool(libro.call("restringe_huecos"))
	var abiertos: int = (libro.call("sectores_abiertos") as Array).size() if restringe else 8
	print("--- huecos: lámina «%s», restringe=%s, huecos abiertos=%d, glifos por página (presupuesto)=%d ---" % [Repertoire.libro, str(restringe), abiertos, Repertoire.max_sigils_per_page])
	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element("fuego")
	for _i in range(INTENTOS_HUECOS):
		lanzador.place_sigil("flecha")
	var entran: int = lanzador.sigils_used()
	_ok("6 la página admite como mucho tantos glifos como huecos abiertos", entran <= abiertos, "%d glifos con %d huecos abiertos" % [entran, abiertos])
	_ok("6b y los llena todos (ni uno menos)", entran == (abiertos if Repertoire.max_sigils_per_page <= 0 else mini(abiertos, Repertoire.max_sigils_per_page)), "%d" % entran)
	_ok("6c las recetas del barrido (hasta %d glifos) caben en los huecos abiertos" % MAX_GLIFOS_RECETA, abiertos >= MAX_GLIFOS_RECETA, "%d huecos" % abiertos)
	# Un sector ocupado rechaza el segundo glifo.
	var comps: Array = lanzador.components()
	if not comps.is_empty():
		var sector: Vector2 = (comps[0] as Dictionary)["direction"]
		var antes: int = lanzador.sigils_used()
		lanzador.add_sigil(sector, "barrera", 1.0)
		_ok("6d un hueco ocupado rechaza un segundo glifo", lanzador.sigils_used() == antes, "%d → %d" % [antes, lanzador.sigils_used()])
	# Un sector que la lámina no abre: solo lo gobierna el libro dibujado; por la API del Lanzador entra. Se anota, no se exige.
	if restringe:
		lanzador.clear_sequence()
		lanzador.place_element("fuego")
		var cerrado := Vector2(cos(TAU * 5.0 / 8.0), sin(TAU * 5.0 / 8.0))     # el sector 5, que la lámina «bosque» no abre
		var cerrados_abiertos: Array = libro.call("sectores_abiertos")
		var es_cerrado: bool = true
		for s in cerrados_abiertos:
			if (s as Vector2).is_equal_approx(cerrado):
				es_cerrado = false
		if es_cerrado:
			lanzador.add_sigil(cerrado, "flecha", 1.0)
			if lanzador.sigils_used() > 0:
				_aviso("6e Lanzador3D.add_sigil admite un glifo en un sector que la lámina no abre (solo lo impide el libro al dibujar; place_sigil sí respeta los huecos)")
	lanzador.clear_sequence()


# ---------------------------------------------------------------------------------------------------------------------
#  Zonas despejadas
# ---------------------------------------------------------------------------------------------------------------------

func _casilla_limpia(c: Vector2i) -> bool:
	if not Terreno3D.en_mapa(c) or Terreno3D.es_agua(c) or Terreno3D.bloqueada(c) or Terreno3D.celda_solida(c, 0) or Terreno3D.helada(c):
		return false
	if Terreno3D.altura_en(c) != 0:
		return false
	var l: String = Terreno3D.letra_de(c)
	return l != "~" and l != "b" and l != "c" and l != "#" and l != "-" and l != "L" and absf(Terreno3D.y_pies(c) - Terreno3D.alto_suelo) < 0.001


## Las primeras ZONAS_MAX zonas de LADO_ZONA × LADO_ZONA casillas limpias, separadas entre sí.
func _buscar_zonas() -> Array:
	var res: Array = []
	var lado_x: int = Terreno3D.lado_del_mapa()
	var alto_y: int = Terreno3D.mapa.size() if Terreno3D.datos_propios else lado_x
	var ancho_x: int = (Terreno3D.mapa[0].length() if (Terreno3D.datos_propios and Terreno3D.mapa.size() > 0) else lado_x)
	var margen: int = MARGEN_ZONA
	for z0 in range(margen, alto_y - LADO_ZONA - margen):
		for x0 in range(margen, ancho_x - LADO_ZONA - margen):
			var r := Rect2i(x0, z0, LADO_ZONA, LADO_ZONA)
			var lejos: bool = true
			for otra in res:
				if absi((otra as Rect2i).position.x - x0) < SEPARACION_ZONAS and absi((otra as Rect2i).position.y - z0) < SEPARACION_ZONAS:
					lejos = false
			if not lejos:
				continue
			if _zona_limpia(r, margen):
				res.append(r)
				if res.size() >= ZONAS_MAX:
					return res
	return res


func _zona_limpia(r: Rect2i, margen: int = 0) -> bool:
	for dz in range(-margen, r.size.y + margen):
		for dx in range(-margen, r.size.x + margen):
			if not _casilla_limpia(Vector2i(r.position.x + dx, r.position.y + dz)):
				return false
	return true


## Para diagnosticar: el mapa en ASCII (`.` limpia, `~` agua, `#` bloqueada o sólida, `^` con altura, `?` otra cosa).
func _volcar_mapa_limpio() -> void:
	var filas: int = Terreno3D.mapa.size()
	for z in range(filas):
		var linea: String = ""
		for x in range(Terreno3D.mapa[z].length()):
			var c := Vector2i(x, z)
			if _casilla_limpia(c):
				linea += "."
			elif Terreno3D.es_agua(c):
				linea += "~"
			elif Terreno3D.bloqueada(c) or Terreno3D.celda_solida(c, 0):
				linea += "#"
			elif Terreno3D.altura_en(c) != 0:
				linea += "^"
			else:
				linea += "?"
		print("    " + linea)
	var otras: Dictionary = {}
	for z in range(filas):
		for x in range(Terreno3D.mapa[z].length()):
			var c2 := Vector2i(x, z)
			if not _casilla_limpia(c2) and not Terreno3D.es_agua(c2) and not Terreno3D.bloqueada(c2) and not Terreno3D.celda_solida(c2, 0) and Terreno3D.altura_en(c2) == 0:
				var k: String = "letra «%s» y_pies %.3f helada %s" % [Terreno3D.letra_de(c2), Terreno3D.y_pies(c2), str(Terreno3D.helada(c2))]
				otras[k] = int(otras.get(k, 0)) + 1
	print("    casillas «?» por causa: " + str(otras))


## Quita lo que un lanzamiento dejó en el suelo de la zona (tierra levantada, hielo, sólidos) para que el siguiente parta igual.
func _limpiar_zona(r: Rect2i) -> void:
	for n in lanzador.get_children():
		if n is HechizoVivo or n is Lanzador3D.SolidezV2 or n is Lanzador3D.ZonaV2 or n is Lanzador3D.Campo or n is Lanzador3D.BarreraFuego:
			n.queue_free()
	# La tierra que dejó el lanzamiento anterior sigue en la lista de bloques del Lanzador (8 s): mientras esté, `construir_tierra` rechaza
	# apilar más y la receta siguiente "no nace" por culpa de la anterior, no suya. Se deshacen aquí (_deshacer_bloque es privado pero esto es
	# una herramienta de pruebas, igual que escenario_base lee PlayLog._file).
	for b in lanzador._bloques.duplicate():
		lanzador._deshacer_bloque(b)
	for k in lanzador._columnas.duplicate():
		if is_instance_valid(k["nodo"]):
			(k["nodo"] as Node).queue_free()
		lanzador._columnas.erase(k)
		lanzador._recalcular(k["celda"] as Vector2i)
	for c in Terreno3D.alturas.keys():
		if not _permanentes_base.has(c):
			Terreno3D.fijar_altura(c, 0)
	for dz in range(-3, r.size.y + 3):
		for dx in range(-3, r.size.x + 3):
			var c := Vector2i(r.position.x + dx, r.position.y + dz)
			if Terreno3D.helada(c):
				Terreno3D.poner_helada(c, false)
			# El agua de un hechizo de agua no se va sola de una zona llana: se funde el hielo y se retira el agua casilla a casilla
			# (sin esto el segundo lanzamiento de agua deja a la jugadora nadando y ya no puede lanzar).
			if Terreno3D.agua_sim != null:
				var centro: Vector3 = Terreno3D.centro_de(c, Terreno3D.alto_suelo)
				Terreno3D.agua_sim.derretir(centro, Terreno3D.casilla)
				Terreno3D.agua_sim.quitar(centro, VOLUMEN_RETIRADO, Terreno3D.casilla)


# ---------------------------------------------------------------------------------------------------------------------
#  Un lanzamiento
# ---------------------------------------------------------------------------------------------------------------------

func _vivos() -> int:
	var n: int = 0
	for h in lanzador.get_children():
		if h is HechizoVivo and not (h as Node).is_queued_for_deletion():
			n += 1
	return n


## Pone la receta en la página 1 por la API del libro, la lanza y devuelve {res, info, vivo_al_plazo, espera}. `res`: «sale», un motivo
## conocido (R_*), o «FALLO».
func _lanzar_receta(elemento: String, glifos: Array) -> Dictionary:
	# Zona limpia: si el lanzamiento anterior la ensució de agua (que no se limpia por API), se pasa a la siguiente.
	var r: Rect2i = _zonas[_zona_actual]
	_limpiar_zona(r)
	if not _zona_limpia(r):
		for k in range(_zonas.size()):
			_zona_actual = (_zona_actual + 1) % _zonas.size()
			r = _zonas[_zona_actual]
			_limpiar_zona(r)
			if _zona_limpia(r):
				break
	await process_frame
	colocar_jugador(Vector2i(r.position.x + 1, r.position.y + LADO_ZONA / 2))
	# La jugadora no puede lanzar mientras dura el gesto del lanzamiento anterior, rueda, bebe o nada: se espera a que pueda (es SU regla,
	# no se toca). Si en ESPERA_PUEDE_LANZAR_S no puede, el lanzamiento se declara fallado con ese motivo en vez de adivinar.
	var espera_puede: float = reloj.t
	while not jugador.puede_lanzar() and reloj.t - espera_puede < ESPERA_PUEDE_LANZAR_S:
		await process_frame
	if not jugador.puede_lanzar():
		return {"res": "FALLO", "info": "la jugadora no puede lanzar tras %.1f s (nadando %s, en el suelo %s)" % [ESPERA_PUEDE_LANZAR_S, str(jugador.get("nadando")), str(jugador.get("en_suelo"))], "vivo_al_plazo": false, "espera": 0.0}

	lanzador.select_page(0)
	lanzador.clear_sequence()
	lanzador.place_element(elemento)
	for g in glifos:
		lanzador.place_sigil(String(g))
	var puestos: int = lanzador.sigils_used()
	if puestos != glifos.size():
		return {"res": "FALLO", "info": "la página admitió %d de %d glifos" % [puestos, glifos.size()], "vivo_al_plazo": false, "espera": 0.0}
	var rune: RuneData = lanzador.page_element_data(0)
	var aviso_esperado: String = Lanzador3D.aviso_receta(_nombres_receta(glifos), rune) if rune != null else ""

	var tinta: Tinta = lanzador.tinta
	if tinta != null:
		tinta.actual = tinta.maxima
	lanzador.cooldown_left[0] = 0.0
	lanzador.feedback_text = ""
	_lanzados.clear()
	_ultimo_g = {}
	# De dónde nace: en el juego TODO nace en la jugadora salvo lo que pide `en_punto` (la barrera y, desde el 24/10, todo sólido quieto de tierra o hielo: nace donde apuntas, sin pasar de
	# ALCANCE_ORIGEN casillas). Si aquí se lanzara la barrera de tierra en la casilla de la propia jugadora, `construir_tierra` la rechazaría
	# (la casilla está ocupada) y se daría por fallo algo que en el juego no pasa apuntando a otro lado.
	var origen: Vector3 = jugador.position
	if rune != null:
		var rec := Lanzador3D.Receta3D.new(Vector2.RIGHT)
		for g in glifos:
			rec.apply(String(g))
		var hz: Hechizo = rec.hechizo(rune)
		if hz != null and hz.en_punto:
			origen += DIRECCION * Terreno3D.casilla * minf(CASILLAS_APUNTADAS, Lanzador3D.ALCANCE_ORIGEN)
	var salio: bool = lanzador.lanzar_pagina_ya(0, origen, DIRECCION)

	if not salio:
		var fb: String = lanzador.feedback_text
		if glifos.is_empty() and fb.contains("falta algún glifo"):
			return {"res": R_VACIA, "info": "", "vivo_al_plazo": false, "espera": 0.0}
		if aviso_esperado != "" and fb == aviso_esperado:
			return {"res": R_ALTURA, "info": "", "vivo_al_plazo": false, "espera": 0.0}
		if fb.begins_with(AVISO_NO_CABE):
			# Rechazo con aviso ANTES de cobrar: la tinta sigue llena y la página no está en recarga. Si cobró, es un fallo, no un rechazo.
			var cobro: bool = (tinta != null and tinta.actual < tinta.maxima - 0.001) or float(lanzador.cooldown_left[0]) > 0.0
			if cobro:
				return {"res": "FALLO", "info": "rechazó con «%s» pero cobró tinta o recarga" % fb, "vivo_al_plazo": false, "espera": 0.0}
			return {"res": R_NO_CABE, "info": fb, "vivo_al_plazo": false, "espera": 0.0}
		if fb.begins_with("Tinta insuficiente"):
			return {"res": R_TINTA, "info": fb, "vivo_al_plazo": false, "espera": 0.0}
		return {"res": "FALLO", "info": "rechazada sin motivo conocido: «%s» (aviso de altura esperado: «%s»)" % [fb, aviso_esperado], "vivo_al_plazo": false, "espera": 0.0}

	if aviso_esperado != "":
		return {"res": "FALLO", "info": "debía rechazarse por «%s» y salió" % aviso_esperado, "vivo_al_plazo": false, "espera": 0.0}
	var manifestaciones: int = int(_lanzados[0][2]) if not _lanzados.is_empty() else -1
	var res: String = "sale"
	var info: String = "manifestaciones %d" % manifestaciones
	if _lanzados.is_empty():
		res = "FALLO"
		info = "lanzar_pagina_ya dijo que sí pero no hubo señal `lanzado`"
	elif manifestaciones < 1 and _vivos() == 0:
		res = "FALLO"
		info = "salió pero no nació nada (0 manifestaciones y ningún HechizoVivo)"
		if not _ultimo_g.is_empty():
			var en_jugadora: bool = false
			for c in (_ultimo_g.get("celdas", []) as Array):
				if bool(jugador.call("ocupa", c)):
					en_jugadora = true
			info += " · celdas del volumen %s%s" % [str(_ultimo_g.get("celdas", [])), " (incluye la casilla de la jugadora: construir_tierra la rechaza en silencio)" if en_jugadora else ""]
	# Se espera a que mueran los hechizos, con tope T_ESPERA (los errores de script de su vida salen aquí, en este lanzamiento).
	var inicio: float = reloj.t
	while _vivos() > 0 and reloj.t - inicio < T_ESPERA:
		await process_frame
	var espera: float = reloj.t - inicio
	var vivo: bool = _vivos() > 0
	return {"res": res, "info": info, "vivo_al_plazo": vivo, "espera": espera}


## Los glifos con el nombre que entiende `aviso_receta` (Receta3D.apply): los mismos que se ponen en la página.
func _nombres_receta(glifos: Array) -> Array:
	return glifos.duplicate()
