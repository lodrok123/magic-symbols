extends SceneTree
## BARRIDO DE CONSTRUCCIÓN (24/10, lote 1 de la auditoría de Hechizo; docs/ANALISIS_DIRECCION_24-10/05_auditoria_hechizo.md §B parte A), sin escena ni ventana:
##   godot --headless --path . --script res://herramientas/prueba_barrido_hechizos.gd
## Construye con `Hechizo.construir` TODAS las combinaciones (multiconjuntos) de 0 a `Hechizo.MAX_GLIFOS` (6) glifos de `Sigils.GLIFOS` × los 6 elementos jugables = 8 008 × 6 = 48 048 hechizos y afirma,
## para cada uno: no es null · respeta los límites de la ESPEC §1.9 · su figura y su forma son de las conocidas · su coste es finito y cabe en la barra de tinta (`Tinta.MAXIMA`) · su recarga es > 0
## (salvo la página sin glifos) · `copiar()` y `con({})` reproducen EXACTAMENTE `a_diccionario()` · el camino del libro (`Receta3D`) dice lo mismo que `Hechizo` en tinta, recarga y forma.
## NO afirma (decisión de Pablo pendiente) la altura total (`elevacion` + 2·semieje_y ≤ 2, auditoría D-9) ni que `figura()` coincida con la rama que ejecuta HechizoVivo (D-10): las cuenta y las
## imprime como AVISO, que no suma a FALLOS. El día que se decidan, se pasan a `_ok` (el contador ya está).
## Es la parte de CONSTRUIR; que se EJECUTEN lo mide prueba_ejecucion_combinaciones.gd. Debe tardar menos de 60 s.

const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]
const FIGURAS: Array = ["esfera", "haz", "barrera", "proyectil", "pulso"]
const FORMAS: Array = ["x_mano", "alto", "abajo"]
const MAX_SEGUNDOS: float = 60.0               ## el barrido entero tiene que caber aquí
const MAX_EJEMPLOS: int = 3                    ## cuántos casos concretos se imprimen por cada tipo de fallo

var _fallos: int = 0
var _tipos: Dictionary = {}                    ## criterio -> cuántos hechizos lo incumplen
var _ejemplos: Dictionary = {}                 ## criterio -> primeros casos
var _avisos: Dictionary = {}                   ## aviso -> cuántos
var _ejemplos_aviso: Dictionary = {}


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _anota(criterio: String, caso: String) -> void:
	_tipos[criterio] = int(_tipos.get(criterio, 0)) + 1
	var l: Array = _ejemplos.get(criterio, [])
	if l.size() < MAX_EJEMPLOS:
		l.append(caso)
	_ejemplos[criterio] = l


func _aviso(aviso: String, caso: String) -> void:
	_avisos[aviso] = int(_avisos.get(aviso, 0)) + 1
	var l: Array = _ejemplos_aviso.get(aviso, [])
	if l.size() < MAX_EJEMPLOS:
		l.append(caso)
	_ejemplos_aviso[aviso] = l


## Todos los multiconjuntos de hasta `restante` glifos (con repetición, sin orden), incluido el vacío.
func _generar(nombres: Array, restante: int, desde: int, actual: Array, salida: Array) -> void:
	salida.append(actual.duplicate())
	if restante == 0:
		return
	for i in range(desde, nombres.size()):
		actual.append(nombres[i])
		_generar(nombres, restante - 1, i, actual, salida)
		actual.pop_back()


func _contadores(combo: Array) -> Dictionary:
	var c: Dictionary = {}
	for n in combo:
		c[n] = int(c.get(n, 0)) + 1
	return c


func _iguales(a: Variant, b: Variant) -> bool:
	if a is float and b is float:
		return absf(float(a) - float(b)) < 0.0001 or (is_nan(float(a)) and is_nan(float(b)))
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in range((a as Array).size()):
			if not _iguales(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k in a:
			if not (b as Dictionary).has(k) or not _iguales(a[k], b[k]):
				return false
		return true
	return a == b


func _diferencias(d0: Dictionary, d1: Dictionary) -> Array:
	var dif: Array = []
	for k in d0:
		if not d1.has(k) or not _iguales(d0[k], d1[k]):
			dif.append(k)
	return dif


func _initialize() -> void:
	await process_frame
	var t0: int = Time.get_ticks_msec()
	var runes: Dictionary = {}
	for e in ELEMENTOS:
		runes[e] = load("res://nucleo/%s_rune.tres" % e)
	var glifos: Array = Sigils.GLIFOS.keys()
	var combos: Array = []
	_generar(glifos, Hechizo.MAX_GLIFOS, 0, [], combos)
	var total: int = 0
	for combo in combos:
		var c: Dictionary = _contadores(combo)
		# La receta del libro no depende del elemento (tinta, recarga y forma salen solo de los glifos): se monta una vez por combinación y se compara con los 6 hechizos.
		var r := Lanzador3D.Receta3D.new(Vector2.RIGHT)
		for gl in combo:
			r.apply(String(gl))
		for e in ELEMENTOS:
			total += 1
			_comprobar(runes[e], e, combo, c, r)
	var seg: float = float(Time.get_ticks_msec() - t0) / 1000.0
	_resumen(combos.size(), total, seg)
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Construye un hechizo y apunta cada criterio que incumple.
func _comprobar(rune: RuneData, elemento: String, combo: Array, c: Dictionary, r: Lanzador3D.Receta3D) -> void:
	var et: String = "%s %s" % [elemento, str(combo)]
	var h: Hechizo = Hechizo.construir(rune, c, 1.0)
	if h == null:
		_anota("construye (no es null)", et)
		return
	# --- ESPEC §1.9 (la altura total NO: ver la cabecera) ---
	if h.semieje_x > Hechizo.LIM_SEMIEJE_HORIZONTAL + 1e-6 or h.semieje_z > Hechizo.LIM_SEMIEJE_HORIZONTAL + 1e-6 or h.semieje_y > Hechizo.LIM_SEMIEJE_ALTO + 1e-6:
		_anota("§1.9 semiejes ≤ 3 / 3 / 1", et)
	if h.semieje_x < h.grosor_min - 1e-6 or h.semieje_y < h.grosor_min - 1e-6 or h.semieje_z < h.grosor_min - 1e-6:
		_anota("§1.9 ningún semieje baja de grosor_min", et)
	if h.elevacion > Hechizo.LIM_ELEVACION + 1e-6 or h.elevacion < 0.0:
		_anota("§1.9 elevacion en [0, 2]", et)
	if h.distancia_max > Hechizo.LIM_DISTANCIA + 1e-6 or h.alcance_haz > Hechizo.LIM_DISTANCIA + 1e-6:
		_anota("§1.9 distancia_max y alcance del haz ≤ 8", et)
	if h.persiste + h.permanencia > Hechizo.LIM_VIDA_S + 1e-6:
		_anota("§1.9 persiste + permanencia ≤ 25 s", et)
	if h.copias < 1 or h.copias > Hechizo.LIM_COPIAS:
		_anota("§1.9 copias en [1, 8]", et)
	if h.niveles > 2:
		_anota("§1.9 niveles ≤ 2", et)
	# --- forma y figura ---
	var fig: String = h.figura()
	if not FIGURAS.has(fig):
		_anota("figura() es una de las conocidas", et + " → " + fig)
	if not FORMAS.has(h.forma):
		_anota("forma es x_mano / alto / abajo", et + " → " + h.forma)
	# --- tinta y recarga ---
	if is_nan(h.coste_tinta) or is_inf(h.coste_tinta) or h.coste_tinta > Tinta.MAXIMA + 1e-6 or h.coste_tinta < 0.0:
		_anota("coste de tinta finito y ≤ Tinta.MAXIMA", et + " → %s" % str(h.coste_tinta))
	if combo.size() > 0 and h.recarga <= 0.0:
		_anota("recarga > 0 (salvo la página vacía)", et)
	# --- copiar() y con({}) ---
	var d0: Dictionary = h.a_diccionario()
	var copia: Hechizo = h.copiar()
	var d1: Dictionary = copia.a_diccionario()                  # la copia tal cual…
	var d2: Dictionary = copia.con({}).a_diccionario()          # …y la misma copia tras `con({})` (que recalcula los derivados)
	d0.erase("origen")
	d1.erase("origen")
	d2.erase("origen")
	if not _iguales(d0, d1):
		_anota("copiar() = a_diccionario()", et + " " + str(_diferencias(d0, d1)))
	if not _iguales(d0, d2):
		_anota("con({}) = a_diccionario()", et + " " + str(_diferencias(d0, d2)))
	# --- el camino del libro dice lo mismo ---
	if not is_equal_approx(Tinta.coste_receta(r.coste_v2()), h.coste_tinta):
		_anota("Receta3D = Hechizo en tinta", et)
	if not is_equal_approx(r.cooldown, h.recarga):
		_anota("Receta3D = Hechizo en recarga", et)
	if r.forma() != h.forma:
		_anota("Receta3D = Hechizo en forma", et)
	# --- AVISOS (decisión de Pablo pendiente: no suman a FALLOS) ---
	if h.elevacion + 2.0 * h.semieje_y > 2.0 + 1e-6:
		_aviso("D-9 altura total (elevacion + 2·semieje_y) > 2 niveles", et)
	var rama: String = "haz" if h.haz else ("proyectil" if h.velocidad > 0.0 else "volumen")        # lo que HechizoVivo ejecuta
	if (rama == "haz" and fig != "haz") or (rama == "proyectil" and fig != "proyectil") or (rama == "volumen" and (fig == "haz" or fig == "proyectil")):
		_aviso("D-10 figura() «%s» pero HechizoVivo ejecuta «%s»" % [fig, rama], et)


## Una línea OK/FALLO por criterio (con cuántos hechizos lo incumplen y los primeros casos) y los avisos.
func _resumen(n_combos: int, total: int, seg: float) -> void:
	print("barrido: %d combinaciones de 0..%d glifos × %d elementos = %d hechizos construidos en %.1f s" % [n_combos, Hechizo.MAX_GLIFOS, ELEMENTOS.size(), total, seg])
	_ok("se construyen los 48 048 (8 008 × 6)", total == 48048, "%d" % total)
	var criterios: Array = ["construye (no es null)", "§1.9 semiejes ≤ 3 / 3 / 1", "§1.9 ningún semieje baja de grosor_min", "§1.9 elevacion en [0, 2]", "§1.9 distancia_max y alcance del haz ≤ 8",
		"§1.9 persiste + permanencia ≤ 25 s", "§1.9 copias en [1, 8]", "§1.9 niveles ≤ 2", "figura() es una de las conocidas", "forma es x_mano / alto / abajo",
		"coste de tinta finito y ≤ Tinta.MAXIMA", "recarga > 0 (salvo la página vacía)", "copiar() = a_diccionario()", "con({}) = a_diccionario()",
		"Receta3D = Hechizo en tinta", "Receta3D = Hechizo en recarga", "Receta3D = Hechizo en forma"]
	for crit in criterios:
		var n: int = int(_tipos.get(crit, 0))
		_ok("%s (en %d hechizos)" % [crit, n], n == 0, "" if n == 0 else "p. ej. " + str(_ejemplos.get(crit, [])))
	_ok("el barrido cabe en %.0f s" % MAX_SEGUNDOS, seg < MAX_SEGUNDOS, "%.1f s" % seg)
	for aviso in _avisos:
		print("AVISO %s: %d hechizos · p. ej. %s" % [aviso, int(_avisos[aviso]), str(_ejemplos_aviso.get(aviso, []))])
	if _avisos.is_empty():
		print("AVISO (ninguno: D-9 y D-10 ya no se dan; pásalos a _ok)")
