extends SceneTree

## PRUEBA DE LA ASISTENCIA AL TRAZO (Fase 14.4, 16/10, Juego). Sin ventana: `tools\prueba_una.cmd prueba_asistencia`.
##
## DE DÓNDE SALEN LOS TRAZOS. La biblioteca solo guarda las plantillas YA normalizadas (16 puntos), no los trazos crudos que se
## grabaron. Así que los trazos de prueba se SINTETIZAN a partir de ellas: se toma una muestra, se interpola a un trazo denso y se
## le aplica lo que le pasa a una mano de verdad (escala y posición al azar, giro de unos grados, proporción torcida, temblor, ritmo
## irregular). Para que no sea hacer trampas, cada trazo se evalúa contra la biblioteca SIN la muestra de la que salió
## («deja una fuera»): si no, el trazo coincidiría con su propia plantilla y todo saldría perfecto. Solo se usan gestos con al menos
## 4 muestras. Límite honesto: los gestos de varios trazos se sintetizan como un solo trazo continuo (se perdió dónde se levantó la
## mano), así que viento y tiempo son lo menos fiable de esta prueba; la medida buena será con trazos grabados reales.
##
## QUÉ SE COMPRUEBA
##   1. TRAZOS COMPLETOS: con la asistencia, la tasa de acierto no empeora respecto a hoy. «Hoy» = reconocer el trazo real.
##      «Con asistencia» = lo de hoy, y si no lo acepta, la aceptación anticipada de la candidata (cobertura ≥ 85 %). Se mira también
##      que los aciertos FALSOS (aceptar una runa que no es) no suban.
##   2. PARCIALES AL 60 %: la candidata correcta, ≥ 80 % de los casos.
##   3. Asistencia 0 = como hoy: el imán no mueve nada; el imán con asistencia no pasa de 0,6 y no tira de trazos que no van con la guía.
##   4. Coste de una actualización (ms), para saber si cabe en los 80 ms del temporizador.

var fallos: int = 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 20261016
	var biblioteca: GestureLibrary = GestureLibrary.get_shared()
	_conjunto("P0 (4 elementos)", biblioteca, ["fuego", "agua", "viento", "rayo"] as PackedStringArray, GestureLibrary.ELEMENTS, 0.0)
	_conjunto("P0 (2 sellos)", biblioteca, ["flecha", "barrera"] as PackedStringArray, GestureLibrary.SIGILS, 0.0)
	_conjunto("Todos los elementos", biblioteca, GestureLibrary.ELEMENTS, GestureLibrary.ELEMENTS, 0.0)
	_señuelos(biblioteca)
	await _libro(biblioteca)
	_imán()
	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		fallos += 1
		print("  FALLO  ", msg)


## Un trazo sintético a partir de una plantilla de 16 puntos.
func _sintetizar(plantilla: PackedVector2Array) -> PackedVector2Array:
	var escala: float = rng.randf_range(120.0, 420.0)
	var giro: float = deg_to_rad(rng.randf_range(-8.0, 8.0))
	var sx: float = rng.randf_range(0.9, 1.1)
	var sy: float = rng.randf_range(0.9, 1.1)
	var origen := Vector2(rng.randf_range(300.0, 700.0), rng.randf_range(300.0, 700.0))
	var densos := PackedVector2Array()
	for i in range(plantilla.size() - 1):
		for s in range(6):
			densos.append(plantilla[i].lerp(plantilla[i + 1], float(s) / 6.0))
	densos.append(plantilla[plantilla.size() - 1])
	# Temblor suave: dos ondas lentas de amplitud ~2,5 % del tamaño.
	var f1: float = rng.randf_range(0.0, TAU)
	var f2: float = rng.randf_range(0.0, TAU)
	var salida := PackedVector2Array()
	for i in range(densos.size()):
		var t: float = float(i) / float(densos.size())
		var p: Vector2 = densos[i] * escala
		p = Vector2(p.x * sx, p.y * sy).rotated(giro)
		p += Vector2(sin(t * 17.0 + f1), cos(t * 13.0 + f2)) * escala * 0.025
		salida.append(origen + p)
	return salida


func _largo(p: PackedVector2Array) -> float:
	var l: float = 0.0
	for i in range(1, p.size()):
		l += p[i - 1].distance_to(p[i])
	return l


## Los primeros `frac` del recorrido, reducidos a puntos separados ≥ 8 px como en el libro.
func _recorte(p: PackedVector2Array, frac: float) -> PackedVector2Array:
	var meta: float = _largo(p) * frac
	var fuera := PackedVector2Array([p[0]])
	var l: float = 0.0
	for i in range(1, p.size()):
		l += p[i - 1].distance_to(p[i])
		if l > meta:
			break
		if fuera[fuera.size() - 1].distance_to(p[i]) >= 8.0:
			fuera.append(p[i])
	return fuera


func _conjunto(nombre: String, biblioteca: GestureLibrary, activos: PackedStringArray, familia: PackedStringArray, _x: float) -> void:
	print("== ", nombre)
	var completos_total: int = 0
	var hoy_ok: int = 0
	var hoy_mal: int = 0
	var asist_ok: int = 0
	var asist_mal: int = 0
	var parciales_total: int = 0
	var parciales_ok: int = 0
	var parciales_sin: int = 0
	var ms: Array = []
	var por_gesto: Dictionary = {}
	var asistente := GestureAssist.new()
	for gesto in activos:
		var muestras: Array = biblioteca.templates[gesto]
		if muestras.size() < 4:
			continue
		for i in range(muestras.size()):
			# Biblioteca sin la muestra i de este gesto.
			var sin: Dictionary = {}
			for n in familia:
				if not biblioteca.templates.has(n):
					continue
				var lista: Array = biblioteca.templates[n].duplicate()
				if n == gesto:
					lista.remove_at(i)
				sin[n] = lista
			var activas_sin: Dictionary = {}
			for n in activos:
				if sin.has(n):
					activas_sin[n] = sin[n]
			for v in range(4):
				var trazo: PackedVector2Array = _sintetizar(muestras[i])
				# 1. Completo: hoy.
				completos_total += 1
				var real: Dictionary = GestureRecognizer.recognize([trazo], sin, activos)
				var hoy_acepta: bool = real["accepted"] and activos.has(real["name"])
				if hoy_acepta and real["name"] == gesto:
					hoy_ok += 1
				elif hoy_acepta:
					hoy_mal += 1
				# Con asistencia: lo de hoy, o la candidata si es aceptable.
				var acepta: bool = hoy_acepta
				var nombre_acep: String = real["name"]
				var parcial_completo: PackedVector2Array = _recorte(trazo, 1.0)
				var t0: int = Time.get_ticks_usec()
				asistente.actualizar([parcial_completo], sin, activos, 1.0)
				ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
				if not acepta and asistente.aceptable:
					acepta = true
					nombre_acep = asistente.candidata
				if acepta and nombre_acep == gesto:
					asist_ok += 1
				elif acepta:
					asist_mal += 1
				# 2. Parcial al 60 %.
				parciales_total += 1
				var parcial: PackedVector2Array = _recorte(trazo, 0.6)
				asistente.actualizar([parcial], sin, activos, 1.0)
				var d: Dictionary = por_gesto.get(gesto, {"ok": 0, "n": 0, "sin": 0})
				d["n"] += 1
				if asistente.candidata == gesto:
					parciales_ok += 1
					d["ok"] += 1
				elif asistente.candidata == "":
					parciales_sin += 1
					d["sin"] += 1
				por_gesto[gesto] = d
	var t_hoy: float = float(hoy_ok) / maxf(completos_total, 1)
	var t_asi: float = float(asist_ok) / maxf(completos_total, 1)
	var t_par: float = float(parciales_ok) / maxf(parciales_total, 1)
	print("  completos: hoy %.1f%% (falsos %d)  con asistencia %.1f%% (falsos %d)  de %d" % [100.0 * t_hoy, hoy_mal, 100.0 * t_asi, asist_mal, completos_total])
	print("  parciales 60%%: candidata correcta %.1f%%  sin candidata %d de %d" % [100.0 * t_par, parciales_sin, parciales_total])
	for g in por_gesto:
		print("     ", g, ": ", por_gesto[g]["ok"], "/", por_gesto[g]["n"], "  (sin candidata ", por_gesto[g]["sin"], ")")
	ms.sort()
	if ms.size() > 0:
		print("  coste de actualizar (trazo completo): mediana %.1f ms  p95 %.1f ms  máx %.1f ms" % [ms[ms.size() / 2], ms[int(ms.size() * 0.95)], ms[ms.size() - 1]])
	_ok(t_asi >= t_hoy - 0.0001, "con asistencia el acierto de trazos completos no empeora (%.1f%% >= %.1f%%)" % [100.0 * t_asi, 100.0 * t_hoy])
	_ok(asist_mal <= hoy_mal + int(0.01 * completos_total), "los aciertos falsos no suben más de un 1 %% (%d vs %d)" % [asist_mal, hoy_mal])
	_ok(t_par >= 0.8, "parciales al 60 %%: candidata correcta ≥ 80 %% (%.1f%%)" % [100.0 * t_par])


## Runas que el jugador NO conoce (señuelos): dibujadas, no deben aceptarse como una conocida. Es lo que hoy evita el reconocedor
## midiendo contra todas las plantillas; la asistencia no puede ser más permisiva que eso. Se cuenta con y sin señuelos en juego.
func _señuelos(biblioteca: GestureLibrary) -> void:
	print("== Señuelos (runas que no se conocen)")
	var activos: PackedStringArray = ["fuego", "agua", "viento", "rayo"]
	var a := GestureAssist.new()
	var total: int = 0
	var aceptadas: int = 0
	var hoy: int = 0
	var candidatas_60: int = 0
	for gesto in ["tierra", "hielo", "tiempo"]:
		var muestras: Array = biblioteca.templates[gesto]
		for i in range(muestras.size()):
			var sin: Dictionary = biblioteca.templates_for(GestureLibrary.ELEMENTS).duplicate()
			var lista: Array = muestras.duplicate()
			lista.remove_at(i)
			sin[gesto] = lista
			for v in range(4):
				var trazo: PackedVector2Array = _sintetizar(muestras[i])
				total += 1
				var real: Dictionary = GestureRecognizer.recognize([trazo], sin, activos)
				if real["accepted"] and activos.has(real["name"]):
					hoy += 1
				a.actualizar([trazo], sin, activos, 1.0)
				if a.aceptable:
					aceptadas += 1
				a.actualizar([_recorte(trazo, 0.6)], sin, activos, 1.0)
				if a.candidata != "":
					candidatas_60 += 1
	print("  de %d trazos de runas desconocidas: hoy se aceptan como conocida %d; la asistencia los acepta %d; con candidata al 60%% %d" % [total, hoy, aceptadas, candidatas_60])
	_ok(aceptadas <= hoy + int(0.02 * total), "la asistencia no acepta runas desconocidas más que hoy (%d vs %d de %d)" % [aceptadas, hoy, total])


func _imán() -> void:
	print("== Imán y API")
	var biblioteca: GestureLibrary = GestureLibrary.get_shared()
	var activos: PackedStringArray = ["fuego", "agua", "viento", "rayo"]
	var plantillas: Dictionary = biblioteca.templates_for(GestureLibrary.ELEMENTS)
	var trazo: PackedVector2Array = _sintetizar(biblioteca.templates["agua"][0])
	var parcial: PackedVector2Array = _recorte(trazo, 0.7)
	var a := GestureAssist.new()
	a.actualizar([parcial], plantillas, activos, 0.0)
	_ok(a.candidata == "agua", "candidata al 70 %% = agua (salió '%s', confianza %.2f, cobertura %.2f)" % [a.candidata, a.confianza, a.cobertura])
	_ok(a.fuerza_iman() == 0.0, "asistencia 0 → fuerza de imán 0")
	_ok(a.punto_imantado(parcial[3]) == parcial[3], "asistencia 0 → el imán no mueve nada")
	a.actualizar([parcial], plantillas, activos, 1.0)
	_ok(a.fuerza_iman() <= GestureAssist.TOPE_IMAN + 0.0001, "la fuerza del imán no pasa de 0,6 (%.2f)" % a.fuerza_iman())
	_ok(a.fuerza_iman() > 0.0, "con asistencia 1 y candidata, el imán tira")
	_ok(not a.guia.is_empty(), "hay guía para la candidata")
	var movido: PackedVector2Array = a.trazo_imantado(parcial, 250.0)
	var antes: float = 0.0
	var despues: float = 0.0
	for p in parcial:
		antes += _dist_guia(a, p)
	for p in movido:
		despues += _dist_guia(a, p)
	_ok(despues < antes, "el trazo imantado queda más cerca de la guía (%.1f → %.1f px acumulados)" % [antes, despues])
	var lejos := Vector2(5000.0, 5000.0)
	_ok(a.punto_imantado(lejos, 250.0) == lejos, "un punto lejísimos de la guía no se mueve")
	# El imán es solo para pintar: el trazo real no se toca.
	var copia: PackedVector2Array = parcial.duplicate()
	a.trazo_imantado(parcial, 250.0)
	_ok(parcial == copia, "el trazo real no se modifica")
	a.actualizar([PackedVector2Array([Vector2(100, 100), Vector2(110, 100)])], plantillas, activos, 1.0)
	_ok(a.candidata == "" and a.guia.is_empty(), "un trazo diminuto no da candidata ni guía")
	a.actualizar([parcial], plantillas, ["fuego"] as PackedStringArray, 1.0)
	_ok(a.candidata == "", "con un solo gesto activo no hay candidata (sin rival no hay medida)")


## El libro de verdad: se dibuja con el ratón (por código) un trazo de agua y se mira qué pasa con la asistencia a 0 y a 0,5.
func _libro(biblioteca: GestureLibrary) -> void:
	print("== Libro (integración)")
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(1280.0, 720.0)
	root.add_child(libro)
	await process_frame
	libro.visible = true
	var c: Vector2 = libro._center()
	var radio: float = libro._u(libro.RADIUS)
	# Un trazo de agua a ~la mitad del radio, centrado en el núcleo (elemento), al 100 % y recortado al 70 %.
	var plantilla: PackedVector2Array = biblioteca.templates["agua"][0]
	var puntos := PackedVector2Array()
	for p in plantilla:
		puntos.append(c + p * radio * 0.9)
	var denso := PackedVector2Array()
	for i in range(puntos.size() - 1):
		for s in range(6):
			denso.append(puntos[i].lerp(puntos[i + 1], float(s) / 6.0))
	var parcial: PackedVector2Array = _recorte(denso, 0.7)

	# Asistencia 0: nada se calcula y se pinta el trazo real.
	Estado.nuevo().asistencia = 0.0
	libro._begin_stroke(parcial[0])
	for i in range(1, parcial.size()):
		libro._add_point(parcial[i])
		libro._process(0.1)
	_ok(libro.asistente.candidata == "", "asistencia 0: el asistente no calcula nada")
	_ok(libro.stroke_visible == libro.stroke, "asistencia 0: lo que se ve es el trazo real")
	libro._end_stroke()
	libro.pending_strokes = []
	libro._asist_reiniciar()

	# Asistencia 0,5: candidata agua, guía, trazo imantado distinto del real pero el real intacto.
	Estado.nuevo().asistencia = 0.5
	libro._begin_stroke(parcial[0])
	for i in range(1, parcial.size()):
		libro._add_point(parcial[i])
		libro._process(0.1)
	var real: PackedVector2Array = libro.stroke.duplicate()
	_ok(libro.asistente.candidata == "agua", "asistencia 0,5: candidata agua a medio trazo (salió '%s', confianza %.2f)" % [libro.asistente.candidata, libro.asistente.confianza])
	_ok(not libro.asistente.guia.is_empty(), "hay guía fantasma")
	_ok(libro.stroke_visible.size() == real.size() and libro.stroke_visible != real, "el trazo que se ve va imantado")
	_ok(libro.asistente.fuerza_iman() <= GestureAssist.TOPE_IMAN + 0.0001, "fuerza de imán dentro del tope")
	_ok(libro.stroke == real, "el trazo real queda intacto")
	libro._end_stroke()
	_ok(libro.pending_strokes[0] == real, "al soltar se guarda el trazo REAL, no el imantado")
	libro.pending_strokes = []
	libro._asist_reiniciar()
	# Aceptación anticipada: trazos de agua al 90 % del recorrido. Cuando el real no pasa y la asistencia lo da por bueno, lo que
	# se envía (la plantilla colocada) tiene que ser reconocido como agua por el reconocedor de siempre.
	var lib_todas: Dictionary = biblioteca.templates_for(GestureLibrary.ELEMENTS)
	var activos: PackedStringArray = Repertoire.active_elements()
	var anticipadas: int = 0
	var anticipadas_ok: int = 0
	var enviados_vacios: int = 0
	var muestras_agua: Array = biblioteca.templates["agua"]
	for v in range(24):
		var tr: PackedVector2Array = _sintetizar(muestras_agua[v % muestras_agua.size()])
		# Reencuadrado al círculo del libro (lo sintético sale en otro rango de píxeles).
		var caja := Rect2(tr[0], Vector2.ZERO)
		for q in tr:
			caja = caja.expand(q)
		var k: float = radio * 1.4 / maxf(caja.size.x, caja.size.y)
		var ct: Vector2 = caja.get_center()
		var encajado := PackedVector2Array()
		for q in tr:
			encajado.append(c + (q - ct) * k)
		var t90: PackedVector2Array = _recorte(encajado, 0.9)
		libro.pending_strokes = [t90]
		libro.pending_visible = [t90]
		libro._t_gesto_ini = 0
		libro._t_gesto_fin = 1500
		libro._actualizar_asistencia()
		var enviado: Array = libro._decidir_con_asistencia(Node.new(), Vector2.ZERO)
		if enviado.is_empty():
			enviados_vacios += 1
		elif enviado != libro.pending_strokes:
			anticipadas += 1
			var r: Dictionary = GestureRecognizer.recognize(enviado, lib_todas, activos)
			if r["accepted"] and r["name"] == "agua":
				anticipadas_ok += 1
		libro._asist_reiniciar()
	print("  aceptación anticipada: %d de 24 trazos de agua al 90%% se aceptaron con la plantilla; reconocidos como agua: %d" % [anticipadas, anticipadas_ok])
	_ok(enviados_vacios == 0, "nunca se envía un gesto vacío")
	_ok(anticipadas_ok == anticipadas, "toda aceptación anticipada es reconocida como la runa que se anunciaba")
	libro.queue_free()
	await process_frame


func _dist_guia(a: GestureAssist, p: Vector2) -> float:
	var d: float = INF
	for pieza in a.guia:
		for i in range(pieza.size() - 1):
			d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pieza[i], pieza[i + 1])))
	return d
