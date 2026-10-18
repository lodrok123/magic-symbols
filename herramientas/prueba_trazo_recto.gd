extends SceneTree
## TRAZO RECTO (16/10, Juego): GestureRectify convierte un trazo a mano alzada en tramos rectos en las ocho direcciones del compás, y
## con eso el $P acierta más sobre runas de líneas rectas. Mide, no supone: formas sintéticas con temblor y ángulos a medias.
##   godot --headless --path . --script res://herramientas/prueba_trazo_recto.gd   (o tools\prueba_una.cmd prueba_trazo_recto)

const ESCALA: float = 250.0            # radio del círculo del libro a tamaño de diseño (Spellbook.RADIUS)

var _fallos: int = 0
var _rng := RandomNumberGenerator.new()


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


## Un trazo "humano" por una polilínea ideal: puntos cada ~6 px, temblor perpendicular `ruido` px, esquinas redondeadas `redondeo` px,
## y cada tramo girado `giro_grados` (ángulo a medias, como quien no traza la diagonal exacta).
func _dibujar(ideal: PackedVector2Array, ruido: float, redondeo: float = 0.0, giro_grados: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var giro: float = deg_to_rad(giro_grados)
	var actual: Vector2 = ideal[0]
	for i in range(ideal.size() - 1):
		var v: Vector2 = (ideal[i + 1] - ideal[i]).rotated(giro)
		var largo: float = v.length()
		var d: Vector2 = v / maxf(largo, 0.001)
		var n := Vector2(-d.y, d.x)
		var t: float = 0.0
		while t < largo:
			var p: Vector2 = actual + d * t + n * _rng.randf_range(-ruido, ruido)
			if redondeo > 0.0 and i > 0 and t < redondeo:     # la esquina se come un poco, como un giro de muñeca
				p += (ideal[i] - ideal[i - 1]).normalized() * (redondeo - t) * 0.5
			pts.append(p)
			t += 6.0
		actual += v
	pts.append(actual)
	return pts


func _dirs(trazo: PackedVector2Array) -> Array:
	var d: Array = []
	for i in range(trazo.size() - 1):
		d.append(GestureRectify.indice(trazo[i + 1] - trazo[i]))
	return d


## Formas de líneas rectas (en píxeles del libro; el origen da igual).
func _formas() -> Dictionary:
	return {
		"raya":  PackedVector2Array([Vector2(0, 0), Vector2(160, 0)]),
		"ele":   PackedVector2Array([Vector2(0, 0), Vector2(0, 150), Vector2(120, 150)]),
		"rombo": PackedVector2Array([Vector2(0, -90), Vector2(90, 0), Vector2(0, 90), Vector2(-90, 0), Vector2(0, -90)]),
		"zeta":  PackedVector2Array([Vector2(0, 0), Vector2(70, 60), Vector2(0, 120), Vector2(70, 180)]),
		"uve":   PackedVector2Array([Vector2(-80, 0), Vector2(0, 80), Vector2(80, 0)]),
		"tejado": PackedVector2Array([Vector2(-80, 80), Vector2(0, 0), Vector2(80, 80)]),
	}


func _initialize() -> void:
	await process_frame
	_rng.seed = 1610

	# 1. Una raya horizontal con temblor de ±4 px queda en UN tramo hacia el este.
	var r1: PackedVector2Array = GestureRectify.rectificar(_dibujar(_formas()["raya"], 4.0), ESCALA)
	_ok("1 raya temblorosa → 1 tramo este", r1.size() == 2 and _dirs(r1) == [0], str(_dirs(r1)))

	# 2. Una L con la esquina redondeada → 2 tramos (sur, este) y largos ±10 %.
	var r2: PackedVector2Array = GestureRectify.rectificar(_dibujar(_formas()["ele"], 3.0, 18.0), ESCALA)
	var largos2: Array = []
	for i in range(r2.size() - 1):
		largos2.append(snappedf(r2[i].distance_to(r2[i + 1]), 1.0))
	_ok("2 ele redondeada → sur, este", _dirs(r2) == [2, 0], str(_dirs(r2)) + " largos " + str(largos2))
	_ok("2b largos de la ele ±10 %", r2.size() == 3 and absf(largos2[0] - 150.0) < 15.0 and absf(largos2[1] - 120.0) < 12.0)

	# 3. Un rombo dibujado con los lados a 35° en vez de 45° y sin llegar a cerrar (le faltan 12 px) → 4 tramos diagonales y CERRADO.
	var ideal3: PackedVector2Array = _formas()["rombo"].duplicate()
	ideal3[4] = ideal3[0] + Vector2(8, 9)
	var r3: PackedVector2Array = GestureRectify.rectificar(_dibujar(ideal3, 3.0, 10.0, 10.0), ESCALA)
	_ok("3 rombo a 35° casi cerrado → 4 diagonales", r3.size() == 5 and _dirs(r3) == [1, 3, 5, 7], str(_dirs(r3)))
	_ok("3b y cierra exacto", r3.size() >= 2 and r3[r3.size() - 1] == r3[0], str(r3[r3.size() - 1].distance_to(r3[0])))

	# 4. Una diagonal a 40° → se cuantiza a 45° (índice 1).
	var r4: PackedVector2Array = GestureRectify.rectificar(_dibujar(PackedVector2Array([Vector2.ZERO, Vector2(150, 0)]), 2.0, 0.0, 40.0), ESCALA)
	_ok("4 diagonal a 40° → 45°", r4.size() == 2 and _dirs(r4) == [1], str(_dirs(r4)))

	# 5. Gancho de arranque (12 px hacia arriba antes de la raya) → se quita: queda 1 tramo.
	var r5: PackedVector2Array = GestureRectify.rectificar(_dibujar(PackedVector2Array([Vector2(0, 12), Vector2(0, 0), Vector2(160, 0)]), 2.0), ESCALA)
	_ok("5 gancho de 12 px al empezar se quita", r5.size() == 2 and _dirs(r5) == [0], str(_dirs(r5)))

	# 6. Un trazo diminuto (6 px) no revienta nada: queda un punto doble.
	var r6: PackedVector2Array = GestureRectify.rectificar(PackedVector2Array([Vector2(0, 0), Vector2(4, 3), Vector2(6, 5)]), ESCALA)
	_ok("6 trazo diminuto → punto", r6.size() == 2 and r6[0].distance_to(r6[1]) < 8.0)

	# 7. Reconocimiento: plantillas = formas rectas limpias (rectificadas); muestras = 40 por forma con temblor 4 px, esquinas 14 px y
	#    giro ±14°. Se mide el acierto del $P con el trazo CRUDO y con el RECTIFICADO: el rectificado no puede ser peor.
	var plantillas: Dictionary = {}
	for nombre in _formas():
		plantillas[nombre] = [GestureRecognizer.normalize([GestureRectify.rectificar(_formas()[nombre], ESCALA)])]
	var activos: PackedStringArray = PackedStringArray(_formas().keys())
	var bien_crudo: int = 0
	var bien_recto: int = 0
	var total: int = 0
	var us_total: int = 0
	for nombre in _formas():
		for k in range(40):
			var crudo: PackedVector2Array = _dibujar(_formas()[nombre], 4.0, 14.0, _rng.randf_range(-14.0, 14.0))
			var t0: int = Time.get_ticks_usec()
			var recto: PackedVector2Array = GestureRectify.rectificar(crudo, ESCALA)
			us_total += Time.get_ticks_usec() - t0
			var a: Dictionary = GestureRecognizer.recognize([crudo], plantillas, activos)
			var b: Dictionary = GestureRecognizer.recognize([recto], plantillas, activos)
			total += 1
			if a["accepted"] and a["name"] == nombre:
				bien_crudo += 1
			if b["accepted"] and b["name"] == nombre:
				bien_recto += 1
	var pc: float = 100.0 * float(bien_crudo) / float(total)
	var pr: float = 100.0 * float(bien_recto) / float(total)
	print("    acierto $P: crudo %.1f %%  ·  rectificado %.1f %%  (%d muestras; rectificar: %.0f µs de media)" % [pc, pr, total, float(us_total) / float(total)])
	_ok("7 rectificar no empeora el acierto", pr >= pc - 1.0, "%.1f vs %.1f" % [pr, pc])
	_ok("7b rectificado acierta ≥ 90 %", pr >= 90.0, "%.1f %%" % pr)
	_ok("7c rectificar es barato (< 500 µs de media)", float(us_total) / float(total) < 500.0)

	# 8. GestureLibrary.trazos: -1 si falta el dato de algún gesto, el máximo si está.
	var lib := GestureLibrary.new()
	lib.add_sample("a", plantillas["raya"][0], 1)
	lib.add_sample("b", plantillas["ele"][0], 2)
	lib.add_sample("c", plantillas["uve"][0])
	_ok("8 trazos_max con todos los datos", lib.trazos_max(PackedStringArray(["a", "b"])) == 2)
	_ok("8b trazos_max sin dato → -1", lib.trazos_max(PackedStringArray(["a", "c"])) == -1)
	_ok("8c gestos no grabados no cuentan", lib.trazos_max(PackedStringArray(["a", "zz"])) == 1)

	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
