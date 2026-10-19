class_name GestureAssist
extends RefCounted

## ASISTENCIA AL TRAZO (Fase 14.4, 16/10, Juego). Mientras dibujas, mira lo que llevas del trazo y se pregunta «¿qué runa quiere ser
## esto?». Con la respuesta hace tres cosas: pinta una GUÍA fantasma de la plantilla líder, IMANTA el trazo hacia ella, y deja dar
## por buena la runa aunque falte el final (aceptación anticipada). No decide nada por su cuenta: el reconocimiento de verdad
## (GestureRecognizer.recognize sobre el trazo REAL) sigue mandando; esto es ayuda visual y un seguro contra el último tramo.
##
## POR QUÉ NO BASTA CON EL $P TAL CUAL. El $P normaliza por la caja del trazo: la mitad de una onda, escalada a la caja unidad,
## no se parece a la onda entera. Así que aquí un trazo PARCIAL se compara con PREFIJOS de cada plantilla: los primeros 40 %, 50 %…
## 100 % de su recorrido, cada uno vuelto a normalizar. Las plantillas están ordenadas por el recorrido (el $P las remuestrea por
## longitud de arco), de modo que «el primer 60 %» tiene sentido. La fracción que mejor casa dice además CUÁNTO falta: es la
## `cobertura` (0–1) que usa la aceptación anticipada.
##
## CONFIANZA = el mismo margen del $P (primero contra segundo MEJOR GESTURE ACTIVO), pasado a 0–1 con QUALITY_FULL_MARGIN. Con un
## solo gesto activo no hay segundo y no hay candidata (igual que el reconocedor: sin rival no hay medida). Empate (margen por
## debajo de MARGEN_EMPATE) = sin candidata, sin guía y sin imán: callarse es mejor que enseñar la runa equivocada.
##
## API para quien dibuje (el libro y la mano con la pluma del Pipeline):
##   candidata: String            nombre del gesto líder ("" = ninguna / empate)
##   confianza: float             0–1
##   cobertura: float             0–1, qué parte del recorrido de la plantilla parece estar ya dibujada
##   aceptable: bool              confianza suficiente (margen ≥ umbral del gesto) Y cobertura ≥ COBERTURA_ANTICIPADA
##   guia: Array                  trazos (PackedVector2Array) de la plantilla completa, colocada sobre lo dibujado
##   trazo_imantado(trazo)        el trazo tirado hacia la guía (solo para dibujarlo; lo reconocido es el real)
##   punto_imantado(p)            lo mismo para un punto suelto (para ir pintando según llega)
##   trazos_limpios()             la guía como trazos limpios, para el redibujado al aceptar
##   fuerza_iman()                confianza × asistencia, con tope TOPE_IMAN
##   ms_ultimo: float             lo que costó la última actualización (para medir)

const FRACCIONES: Array = [0.4, 0.5, 0.55, 0.6, 0.65, 0.7, 0.8, 0.9, 1.0]
const MARGEN_EMPATE: float = 0.10        ## por debajo, hay empate y no se enseña nada
const MARGEN_CANDIDATA: float = 0.15     ## margen mínimo para tener candidata (el del reconocedor es 0,30: aquí el trazo está a medias)
const TOPE_IMAN: float = 0.6
const COBERTURA_ANTICIPADA: float = 0.85
const DESV_RAYA: float = 0.08            ## un trazo cuya mayor desviación de la cuerda es < esto × su largo es UN solo tramo recto («raya»)
const LARGO_MIN: float = 40.0            ## tamaño mínimo (px) de lo dibujado para opinar; con menos, cualquier cosa se parece a todo
const SUBDIVISION: int = 3               ## cada tramo de la plantilla (16 puntos) se parte en 3 para la guía y el imán
const ALCANCE_IMAN: float = 0.35         ## el imán solo actúa a menos de esto (× tamaño del trazo) de la guía; más lejos no tira
const TOP_REFINAR: int = 3               ## cuántos gestos se miden por completo tras la pasada rápida
const FINALISTAS: int = 3                ## de cada gesto, cuántas combinaciones (muestra, fracción) pasan a la medida completa

var candidata: String = ""
var segunda: String = ""
var bloqueada: String = ""             ## si el líder es una runa aún no conocida: cuál (para depurar); candidata queda vacía
var confianza: float = 0.0
var margen: float = 0.0
var cobertura: float = 0.0
var aceptable: bool = false
var raya: bool = false                 ## lo dibujado es un solo tramo recto: no hay forma que medir, se concreta al soltar o al aparecer el 2º tramo
var guia: Array = []
var asistencia: float = 1.0
var ms_ultimo: float = 0.0

## Cache de prefijos: "nombre#índice#fracción" → {nube, crudo, caja_pos, caja_tam, centroide}. Se rehace sola si cambia la biblioteca
## (se mira el número de muestras y se guarda con el nombre).
var _prefijos: Dictionary = {}
var _huellas: Dictionary = {}            ## nombre → nº de muestras con el que se cacheó
var _plantilla_lider: PackedVector2Array = PackedVector2Array()
var _k: float = 1.0                      ## espacio de la plantilla → espacio del trazo: p * _k + _o
var _o: Vector2 = Vector2.ZERO
var _giro: float = 0.0


func reiniciar() -> void:
	candidata = ""
	segunda = ""
	bloqueada = ""
	confianza = 0.0
	margen = 0.0
	cobertura = 0.0
	aceptable = false
	raya = false
	guia = []
	_plantilla_lider = PackedVector2Array()


## Una pasada. `trazos`: lo dibujado hasta ahora (varios trazos si el gesto es de varios). `plantillas`: nombre → muestras (TODAS las de la
## familia, también las runas aún no conocidas, que hacen de señuelo). `activos`: los nombres que cuentan como rival. `giro`: ángulo (rad) con que se giran los trazos antes
## de comparar (los sellos se reconocen girados por el sector; 0 para elementos). `sin_giro`: plantillas que se comparan con el trazo SIN girar aunque haya `giro`
## (ᛁ no se gira hacia el centro: se dibuja como está, horizontal o vertical; EjesRecetaUi.exenta_del_giro). Devuelve `candidata`.
func actualizar(trazos: Array, plantillas: Dictionary, activos: PackedStringArray, p_asistencia: float = 1.0, giro: float = 0.0,
		sin_giro: PackedStringArray = PackedStringArray()) -> String:
	var t0: int = Time.get_ticks_usec()
	reiniciar()
	asistencia = p_asistencia
	_giro = giro
	_actualizar(trazos, plantillas, activos, giro, sin_giro)
	ms_ultimo = float(Time.get_ticks_usec() - t0) / 1000.0
	return candidata


## ¿Alguno de los gestos activos es, él mismo, un único trazo recto?
func _hay_raya_activa(plantillas: Dictionary, activos: PackedStringArray) -> bool:
	for nombre in activos:
		if plantillas.has(nombre) and not (plantillas[nombre] as Array).is_empty() and _es_raya([plantillas[nombre][0]]):
			return true
	return false


## ¿Lo dibujado es un único trazo recto? (con `Estado.trazo_recto` llega como polilínea de 2–3 vértices; también vale uno a mano alzada casi recto)
func _es_raya(trazos: Array) -> bool:
	if trazos.size() != 1 or (trazos[0] as PackedVector2Array).size() < 2:
		return false
	var p: PackedVector2Array = trazos[0]
	var a: Vector2 = p[0]
	var b: Vector2 = p[p.size() - 1]
	var cuerda: float = a.distance_to(b)
	if cuerda < 0.001:
		return false
	var mayor: float = 0.0
	var largo: float = 0.0
	for i in range(p.size()):
		mayor = maxf(mayor, absf((b - a).cross(p[i] - a)) / cuerda)
		if i > 0:
			largo += p[i - 1].distance_to(p[i])
	return mayor <= DESV_RAYA * cuerda and largo <= cuerda * 1.15


## Los trazos (girados `giro`) ya remuestreados y normalizados como pide $P; vacío si es muy poco o muy corto.
func _preparar(trazos: Array, giro: float) -> Dictionary:
	var puntos := PackedVector2Array()
	var ids := PackedInt32Array()
	for i in range(trazos.size()):
		for p in trazos[i]:
			puntos.append((p as Vector2).rotated(giro) if giro != 0.0 else p)
			ids.append(i)
	# Con el trazo recto (Estado.trazo_recto) lo dibujado llega como polilínea de pocos vértices (un trazo recortado puede ser de 3): lo que manda es el LARGO (LARGO_MIN), no el número de puntos.
	if puntos.size() < 2:
		return {}
	var caja: Rect2 = GestureRecognizer._bounding_box(puntos)
	var tam: float = maxf(caja.size.x, caja.size.y)
	if tam < LARGO_MIN:
		return {}
	var remuestreado: PackedVector2Array = GestureRecognizer._resample(puntos, ids, GestureRecognizer.NUM_POINTS)
	if remuestreado.is_empty():
		return {}
	var escalado: PackedVector2Array = GestureRecognizer._scale_to_unit(remuestreado)
	var caja_re: Rect2 = GestureRecognizer._bounding_box(remuestreado)
	return {"nube": GestureRecognizer._translate_to_origin(escalado), "centro": GestureRecognizer._centroid(remuestreado),
		"tam_re": maxf(maxf(caja_re.size.x, caja_re.size.y), 0.0001), "giro": giro}


func _actualizar(trazos: Array, plantillas: Dictionary, activos: PackedStringArray, giro: float, sin_giro: PackedStringArray = PackedStringArray()) -> void:
	var base: Dictionary = _preparar(trazos, giro)
	if base.is_empty() or activos.size() < 2:
		return
	# Un solo tramo recto no tiene forma: su prefijo de ᛏ, de fuego o de agua es el mismo palo, y la medida sale en empate de ~0 (o, peor, con
	# un margen enorme hacia la runa equivocada). Callarse es mejor: candidata «raya», sin guía ni imán, y se decide al soltar o con el 2º tramo.
	# Excepción: si entre los gestos activos hay uno que ES una raya (ᛁ), un palo sí puede ser la respuesta y se mide como siempre.
	if _es_raya(trazos) and not _hay_raya_activa(plantillas, activos):
		raya = true
		return
	# Las plantillas «sin giro» se miden contra el trazo tal cual se dibujó (otra nube, solo si hace falta).
	var sin: Dictionary = base
	if giro != 0.0 and not sin_giro.is_empty():
		sin = _preparar(trazos, 0.0)
		if sin.is_empty():
			sin = base
	var nube_de: Callable = func(nombre: String) -> Dictionary: return sin if sin_giro.has(nombre) else base

	# Pasada rápida: una sola dirección y un solo punto de partida, para ordenar los gestos. Luego se mide bien a los mejores.
	var mejor_rapido: Dictionary = {}       # nombre → {d, idx, f}
	for nombre in plantillas:
		var muestras: Array = plantillas[nombre]
		_asegurar_prefijos(nombre, muestras)
		var mejor: float = INF
		var todos: Array = []
		for i in range(muestras.size()):
			for fi in range(FRACCIONES.size()):
				var pre: Dictionary = _prefijos["%s#%d#%d" % [nombre, i, fi]]
				if pre.is_empty():
					continue
				var d: float = GestureRecognizer._greedy_match(nube_de.call(nombre)["nube"], pre["nube"], 0)
				todos.append([d, i, fi])
				mejor = minf(mejor, d)
		if mejor < INF:
			todos.sort_custom(func(a, b): return a[0] < b[0])
			mejor_rapido[nombre] = {"d": mejor, "mejores": todos.slice(0, FINALISTAS)}
	if mejor_rapido.size() < 2:
		return

	var orden: Array = mejor_rapido.keys()
	orden.sort_custom(func(a, b): return mejor_rapido[a]["d"] < mejor_rapido[b]["d"])

	# Pasada fina: las TOP_REFINAR mejores, todas sus muestras y fracciones, con la distancia completa del $P.
	var fino: Dictionary = {}               # nombre → {d, i, fi}
	for n in range(mini(TOP_REFINAR, orden.size())):
		var nombre: String = orden[n]
		var mejor2: float = INF
		var info2: Dictionary = {}
		for par in mejor_rapido[nombre]["mejores"]:
			var pre2: Dictionary = _prefijos["%s#%d#%d" % [nombre, par[1], par[2]]]
			var d2: float = GestureRecognizer._cloud_distance(nube_de.call(nombre)["nube"], pre2["nube"])
			if d2 < mejor2:
				mejor2 = d2
				info2 = {"d": d2, "i": par[1], "fi": par[2]}
		fino[nombre] = info2
	# El resto de rivales entran con su medida rápida (que nunca es menor que la fina): así el segundo no sale inflado por no medirse.
	var primero: String = ""
	var d1: float = INF
	for nombre in fino:
		if float(fino[nombre]["d"]) < d1:
			d1 = fino[nombre]["d"]
			primero = nombre
	# El líder puede ser un SEÑUELO (una runa en la biblioteca que el jugador aún no conoce): entonces no hay candidata. Es lo mismo que
	# hace el reconocedor al medir contra todas las plantillas, y evita que un trazo de una runa bloqueada se «asista» como una conocida.
	if not activos.has(primero):
		bloqueada = primero
		return
	# El segundo es el mejor rival ACTIVO, como en el reconocedor (los señuelos son rivales para ganar, no para el margen).
	var d2s: float = INF
	var segundo: String = ""
	for nombre in fino:
		if nombre != primero and activos.has(nombre) and float(fino[nombre]["d"]) < d2s:
			d2s = fino[nombre]["d"]
			segundo = nombre
	if segundo == "":
		# Ningún activo entre los finalistas: se usa la medida rápida del mejor activo restante (nunca menor que la fina → margen prudente).
		for nombre in orden:
			if nombre != primero and activos.has(nombre):
				d2s = mejor_rapido[nombre]["d"]
				segundo = nombre
				break
	if primero == "" or segundo == "":
		return
	margen = (d2s - d1) / maxf(d1, 0.0001)
	var umbral: float = GestureRecognizer.MIN_MARGIN_BY_GESTURE.get(primero, GestureRecognizer.MIN_MARGIN)
	confianza = clampf(margen / GestureRecognizer.QUALITY_FULL_MARGIN, 0.0, 1.0)
	segunda = segundo
	if margen < MARGEN_EMPATE or margen < MARGEN_CANDIDATA:
		return

	candidata = primero
	var ganadora: Dictionary = fino[primero]
	var pre_g: Dictionary = _prefijos["%s#%d#%d" % [primero, ganadora["i"], ganadora["fi"]]]
	cobertura = float(FRACCIONES[ganadora["fi"]])
	aceptable = margen >= umbral and cobertura >= COBERTURA_ANTICIPADA

	# Colocación de la plantilla completa sobre lo dibujado: el prefijo (crudo, en espacio de plantilla) se normalizó con
	# (P - pos)/tam - c; el parcial, igual con su caja y su centroide. Igualar ambos da una escala y un desplazamiento:
	#   p_trazo = P * (S/tam) + (centro_in - c*S - pos*(S/tam))
	_plantilla_lider = plantillas[primero][ganadora["i"]]
	var elegida: Dictionary = nube_de.call(primero)       # la nube con la que ganó (girada o no) manda en la escala, el sitio y el giro de la guía
	var tam_re: float = float(elegida["tam_re"])
	var centro_in: Vector2 = elegida["centro"]
	var k: float = tam_re / float(pre_g["tam"])
	_k = k
	_o = centro_in - (pre_g["centroide"] as Vector2) * tam_re - (pre_g["pos"] as Vector2) * k
	guia = _construir_guia(_plantilla_lider, float(elegida["giro"]))


## Los trazos de la guía: la plantilla (16 puntos) subdividida y cortada donde hay un salto (levantar el lápiz entre trazos), en el
## espacio del trazo SIN girar (para pintarlo donde se dibuja).
func _construir_guia(plantilla: PackedVector2Array, giro: float) -> Array:
	var piezas: Array = []
	if plantilla.size() < 2:
		return piezas
	var tramos: PackedFloat32Array = PackedFloat32Array()
	for i in range(plantilla.size() - 1):
		tramos.append(plantilla[i].distance_to(plantilla[i + 1]))
	var ordenados: Array = Array(tramos)
	ordenados.sort()
	var mediana: float = float(ordenados[ordenados.size() / 2])
	var actual := PackedVector2Array()
	for i in range(plantilla.size()):
		var p: Vector2 = plantilla[i] * _k + _o
		if giro != 0.0:
			p = p.rotated(-giro)
		if i > 0 and tramos[i - 1] > maxf(mediana * 2.6, 0.0001):
			if actual.size() >= 2:
				piezas.append(actual)
			actual = PackedVector2Array()
		if i > 0 and actual.size() > 0:
			var q: Vector2 = actual[actual.size() - 1]
			for s in range(1, SUBDIVISION):
				actual.append(q.lerp(p, float(s) / float(SUBDIVISION)))
		actual.append(p)
	if actual.size() >= 2:
		piezas.append(actual)
	return piezas


## --- Imán ---

func fuerza_iman() -> float:
	if candidata == "":
		return 0.0
	return minf(confianza * asistencia, TOPE_IMAN)


## Tira de `p` hacia el punto más cercano de la guía. Más lejos de ALCANCE_IMAN × `escala` de la guía no tira (es un trazo suelto
## que no va con la candidata, o un salto de lápiz), y entre medias el tirón se desvanece, para que no haya saltos al cruzar el límite.
func punto_imantado(p: Vector2, escala: float = 100.0) -> Vector2:
	var f: float = fuerza_iman()
	if f <= 0.0 or guia.is_empty():
		return p
	var mejor: Vector2 = p
	var d_mejor: float = INF
	for pieza in guia:
		for i in range(pieza.size() - 1):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pieza[i], pieza[i + 1])
			var d: float = p.distance_to(q)
			if d < d_mejor:
				d_mejor = d
				mejor = q
	var alcance: float = maxf(ALCANCE_IMAN * escala, 1.0)
	var peso: float = f * clampf(1.0 - d_mejor / alcance, 0.0, 1.0)
	return p.lerp(mejor, peso)


func trazo_imantado(trazo: PackedVector2Array, escala: float = 100.0) -> PackedVector2Array:
	var fuera := PackedVector2Array()
	for p in trazo:
		fuera.append(punto_imantado(p, escala))
	return fuera


func trazos_limpios() -> Array:
	return guia.duplicate()


## --- Prefijos de las plantillas ---

func _asegurar_prefijos(nombre: String, muestras: Array) -> void:
	if _huellas.get(nombre, -1) == muestras.size() and _prefijos.has("%s#0#0" % nombre):
		return
	_huellas[nombre] = muestras.size()
	for i in range(muestras.size()):
		for fi in range(FRACCIONES.size()):
			_prefijos["%s#%d#%d" % [nombre, i, fi]] = _prefijo(muestras[i], float(FRACCIONES[fi]))


## Los primeros `fraccion` del recorrido de una plantilla, remuestreados a 16 puntos y normalizados como un trazo cualquiera.
func _prefijo(plantilla: PackedVector2Array, fraccion: float) -> Dictionary:
	var n: int = GestureRecognizer.NUM_POINTS
	if plantilla.size() < 2:
		return {}
	var acum := PackedFloat32Array([0.0])
	for i in range(1, plantilla.size()):
		acum.append(acum[i - 1] + plantilla[i - 1].distance_to(plantilla[i]))
	var total: float = acum[acum.size() - 1]
	if total <= 0.0001:
		return {}
	var hasta: float = total * fraccion
	var crudo := PackedVector2Array()
	var seg: int = 1
	for j in range(n):
		var s: float = hasta * float(j) / float(n - 1)
		while seg < acum.size() - 1 and acum[seg] < s:
			seg += 1
		var a: float = acum[seg - 1]
		var b: float = acum[seg]
		var t: float = 0.0 if b <= a else clampf((s - a) / (b - a), 0.0, 1.0)
		crudo.append(plantilla[seg - 1].lerp(plantilla[seg], t))
	var caja: Rect2 = GestureRecognizer._bounding_box(crudo)
	var tam: float = maxf(maxf(caja.size.x, caja.size.y), 0.0001)
	var escalado: PackedVector2Array = GestureRecognizer._scale_to_unit(crudo)
	return {
		"nube": GestureRecognizer._translate_to_origin(escalado),
		"crudo": crudo,
		"pos": caja.position,
		"tam": tam,
		"centroide": GestureRecognizer._centroid(escalado),
	}
