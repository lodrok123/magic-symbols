extends SceneTree
## GLIFOS DIBUJABLES (24/10, auditoría de Hechizo, propuesta 4): todo glifo que el jugador puede tener (activo en algún kit o
## conseguible en un cofre) y todo elemento jugable debe poder TRAZARSE: tener muestras en gesture_library.tres y que el $P las
## reconozca aunque salgan algo torcidas.
## Fallo que evita: un glifo que se concede (ᚱ en el cofre de la Cueva) pero no se puede dibujar porque nadie grabó sus muestras
## (el jugador lo ve en el libro y no hay manera de escribirlo), o uno que se reconoce mal y se confunde con su vecino.
## Sin ventana y rápida:  godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_glifos_dibujables.gd

const MIN_MUESTRAS: int = 3                 ## muestras mínimas por gesto en la biblioteca (con menos el $P es frágil)
## H5 (30/10): los cuatro glifos nuevos se activan por datos y se prueban por contadores; sus muestras las graba Pablo con G después (PENDIENTES). Mientras tengan 0 muestras avisan en vez de fallar;
## en cuanto tengan alguna, entran en la regla normal (≥ 3 muestras y ≥ 90 % de acierto). ᚱ y ᛉ NO están aquí a propósito: siguen fallando hasta que Pablo grabe las suyas.
const PENDIENTES_DE_GRABAR: PackedStringArray = ["perforar", "retorno", "buscar", "retardo"]
const TASA_MIN: float = 0.9                 ## fracción mínima de variantes deformadas que se reconocen como SU gesto
const VARIANTES_POR_MUESTRA: int = 20       ## cuántas deformaciones se prueban por cada muestra grabada
const ESCALA_MIN: float = 0.9               ## escala por eje (aleatoria, independiente en X e Y: la uniforme la quita normalize)
const ESCALA_MAX: float = 1.1
const GIRO_MAX_GRADOS: float = 5.0          ## giro aleatorio ±
const TEMBLOR: float = 0.012                ## desplazamiento aleatorio de cada punto, en unidades de la nube normalizada (lado ~1)
const SUBDIVISION: int = 6                  ## puntos intermedios por segmento al reconstruir el trazo a partir de la nube
const SALTO_TRAZO: float = 3.0              ## un salto mayor que esto × el paso mediano entre puntos es levantar el ratón (trazo nuevo)
const SEMILLA: int = 2410
const ARCHIVO_COFRES: String = "res://mundo/datos_nivel/mapas/"

var _fallos: int = 0
var _avisos: int = 0
var _rng := RandomNumberGenerator.new()


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _aviso(texto: String) -> void:
	print("AVISO " + texto)
	_avisos += 1


## Qué glifos da cada kit del Lanzador y qué cofres legendarios los conceden. Devuelve {glifo: [procedencias]}.
func _procedencias_glifos() -> Dictionary:
	var res: Dictionary = {}
	var prog: Dictionary = load("res://magia/lanzador_3d.gd").PROGRESIONES
	for kit in prog:
		for g in prog[kit]["glifos"]:
			if not res.has(g):
				res[g] = []
			res[g].append("kit " + String(kit))
	# Cofres: líneas «glifo=<id>» de los mapas (escenas/puzle.gd las convierte en Repertoire.conseguir_sigil).
	var rx := RegEx.new()
	rx.compile("glifo=(\\w+)")
	var dir := DirAccess.open(ARCHIVO_COFRES)
	if dir != null:
		for f in dir.get_files():
			if not f.ends_with(".txt"):
				continue
			var texto: String = FileAccess.get_file_as_string(ARCHIVO_COFRES + f)
			for m in rx.search_all(texto):
				var g: String = m.get_string(1)
				if not res.has(g):
					res[g] = []
				res[g].append("cofre " + f.get_basename())
	return res


## Con qué nombre de gesto se DIBUJA un glifo: el suyo si tiene muestras, o el de un alias (altura se traza como levitacion).
func _gesto_de(glifo: String, lib: GestureLibrary) -> String:
	if lib.sample_count(glifo) > 0:
		return glifo
	for alias in Sigils.ALIAS_V2:
		if Sigils.glifo_v2(alias) == glifo and lib.sample_count(alias) > 0:
			return alias
	return glifo


## Reconstruye un trazo denso a partir de una nube normalizada de 16 puntos: une los consecutivos y corta donde hay un salto
## grande (los trazos distintos de un glifo de varios trazos). Así recognize() vuelve a remuestrear como con un dibujo real.
func _trazos_de(nube: PackedVector2Array) -> Array:
	var pasos: Array = []
	for i in range(nube.size() - 1):
		pasos.append(nube[i].distance_to(nube[i + 1]))
	var orden: Array = pasos.duplicate()
	orden.sort()
	var mediano: float = orden[orden.size() / 2]
	var trazos: Array = []
	var actual: Array = [nube[0]]
	for i in range(nube.size() - 1):
		if pasos[i] > mediano * SALTO_TRAZO and mediano > 0.0:
			trazos.append(actual)
			actual = [nube[i + 1]]
			continue
		for k in range(1, SUBDIVISION + 1):
			actual.append(nube[i].lerp(nube[i + 1], float(k) / float(SUBDIVISION)))
	trazos.append(actual)
	return trazos


## Una variante torcida del trazo: escala por eje, giro y temblor en cada punto.
func _deformar(trazos: Array) -> Array:
	var sx: float = _rng.randf_range(ESCALA_MIN, ESCALA_MAX)
	var sy: float = _rng.randf_range(ESCALA_MIN, ESCALA_MAX)
	var giro: float = deg_to_rad(_rng.randf_range(-GIRO_MAX_GRADOS, GIRO_MAX_GRADOS))
	var res: Array = []
	for t in trazos:
		var nuevo: Array = []
		for p in t:
			var q: Vector2 = Vector2(p.x * sx, p.y * sy).rotated(giro)
			q += Vector2(_rng.randf_range(-TEMBLOR, TEMBLOR), _rng.randf_range(-TEMBLOR, TEMBLOR))
			nuevo.append(q)
		res.append(PackedVector2Array(nuevo))
	return res


## Fracción de variantes de las muestras de `gesto` que se reconocen como `gesto` (aceptadas) dentro de su familia.
func _tasa(gesto: String, plantillas: Dictionary, activos: PackedStringArray, lib: GestureLibrary) -> float:
	var bien: int = 0
	var total: int = 0
	for muestra in lib.templates.get(gesto, []):
		var base: Array = _trazos_de(muestra)
		for k in range(VARIANTES_POR_MUESTRA):
			var r: Dictionary = GestureRecognizer.recognize(_deformar(base), plantillas, activos)
			total += 1
			if r["accepted"] and r["name"] == gesto:
				bien += 1
	return float(bien) / float(total) if total > 0 else 0.0


func _fila(nombre: String, gesto: String, muestras: int, tasa: float, origen: String) -> void:
	var etiqueta: String = nombre if gesto == nombre else "%s (se dibuja como %s)" % [nombre, gesto]
	print("    %-34s | %3d muestras | tasa %5.1f %% | %s" % [etiqueta, muestras, tasa * 100.0, origen])


func _initialize() -> void:
	await process_frame
	_rng.seed = SEMILLA
	GestureRecognizer.exigencia = 1.0       # el de siempre; Spellbook.EXIGENCIA_RECTO vale 1,0 hoy
	var lib: GestureLibrary = GestureLibrary.get_shared()
	_ok("0 la biblioteca de gestos carga y no está vacía", lib != null and not lib.is_empty())

	var procedencias: Dictionary = _procedencias_glifos()
	_ok("0b se encontraron glifos de kits y cofres", procedencias.size() >= 8, "%d glifos" % procedencias.size())

	# Familia de glifos: las plantillas son TODAS las de sellos (también las de señuelo, como en el libro) y los activos, los dibujables.
	var plantillas_glifos: Dictionary = lib.templates_for(GestureLibrary.SIGILS)
	var activos_glifos := PackedStringArray()
	for g in procedencias:
		var ges: String = _gesto_de(String(g), lib)
		if lib.sample_count(ges) > 0 and not activos_glifos.has(ges):
			activos_glifos.append(ges)
	var plantillas_elem: Dictionary = lib.templates_for(GestureLibrary.ELEMENTS)
	var activos_elem: PackedStringArray = PackedStringArray(GestureLibrary.ELEMENTS)

	print("--- GLIFOS (kit / cofre) ---")
	print("    glifo | muestras | tasa | procedencia")
	var nombres: Array = procedencias.keys()
	nombres.sort()
	for g in nombres:
		var glifo: String = String(g)
		var ges: String = _gesto_de(glifo, lib)
		var n: int = lib.sample_count(ges)
		var origen: String = ", ".join(PackedStringArray(procedencias[g]))
		var tasa: float = 0.0
		if n >= 1:
			tasa = _tasa(ges, plantillas_glifos, activos_glifos, lib)
		_fila(glifo, ges, n, tasa, origen)
		if n == 0 and PENDIENTES_DE_GRABAR.has(glifo):
			_aviso("glifo %s sin muestras: pendiente de que Pablo las grabe con G (H5; se consigue en: %s)" % [glifo, origen])
			continue
		_ok("glifo %s tiene ≥ %d muestras (%s)" % [glifo, MIN_MUESTRAS, ges], n >= MIN_MUESTRAS, "%d muestras; se consigue en: %s" % [n, origen])
		_ok("glifo %s se reconoce ≥ %d %% contra los demás glifos" % [glifo, int(TASA_MIN * 100.0)], n >= 1 and tasa >= TASA_MIN, "tasa %.1f %%" % (tasa * 100.0))

	print("--- ELEMENTOS ---")
	for e in GestureLibrary.ELEMENTS:
		var n: int = lib.sample_count(e)
		var tasa: float = 0.0
		if n >= 1:
			tasa = _tasa(e, plantillas_elem, activos_elem, lib)
		var kits: Array = []
		var prog: Dictionary = load("res://magia/lanzador_3d.gd").PROGRESIONES
		for kit in prog:
			if prog[kit]["sellos"].has(e):
				kits.append(String(kit))
		_fila(e, e, n, tasa, "kit " + ", ".join(PackedStringArray(kits)))
		_ok("elemento %s tiene ≥ %d muestras" % [e, MIN_MUESTRAS], n >= MIN_MUESTRAS, "%d muestras" % n)
		_ok("elemento %s se reconoce ≥ %d %% contra los demás elementos" % [e, int(TASA_MIN * 100.0)], n >= 1 and tasa >= TASA_MIN, "tasa %.1f %%" % (tasa * 100.0))

	# Un sello de uso «sello» en la BIBLIA que ningún kit ni cofre da: existe pero el jugador nunca lo tiene.
	for g in GestureLibrary.BIBLIA:
		if String(GestureLibrary.BIBLIA[g]["uso"]) == "sello" and GestureLibrary.SIGILS.has(g) and not procedencias.has(g):
			_aviso("«%s» es un sello de la BIBLIA pero no está en ningún kit ni se consigue en ningún cofre (no se puede tener)" % g)

	print("FALLOS: %d   AVISOS: %d" % [_fallos, _avisos])
	quit(1 if _fallos > 0 else 0)
