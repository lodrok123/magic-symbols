extends SceneTree
## ¿Son compatibles los gestos de ᚱ (raido, «pulso») y ᛉ (permanencia) con los glifos que ya se reconocen? (27/10)
## No hay muestras grabadas de ninguno de los dos, así que se dibujan SINTÉTICOS: cada runa de varias maneras (1, 2 o 3 trazos, palo
## completo o no, panza recta o redonda) con temblor, giro, estiramiento y tamaño al azar, y se pasan por el reconocedor real
## (GestureRecognizer, con y sin GestureRectify) contra las plantillas grabadas de la familia de los glifos.
##   A · Antes de grabarlas: ¿un ᚱ o un ᛉ dibujado se ACEPTA como otro glifo? (eso sería un conflicto hoy mismo).
##   B · Con plantillas sintéticas de las dos runas añadidas: ¿se reconocen ellas, y bajan los aciertos de los glifos de siempre?
##   C · Fuera de su familia: ᚱ contra los ELEMENTOS (se parece a la P del fuego, pero se dibuja en otro sitio y no se comparan).
## No cambia nada del juego ni de la biblioteca. Imprime una tabla y, si se le da carpeta, guarda una lámina con las nubes:
##   godot --headless --path . --script res://herramientas/prueba_gestos_raido_permanencia.gd -- [carpeta]

const N: int = 120                    ## dibujos por variante y caso
const TAM: float = 100.0              ## px de un glifo dibujado
const ESCALA_RECT: float = 200.0      ## radio del círculo del libro (tolerancia al temblor del rectificador)
const ESCALA_FORMA: float = 50.0      ## tamaño de las formas de un glifo para el rectificador (diario 137–138)

## Variantes de cada runa: listas de trazos en una caja 0..1 (y hacia abajo).
const RAIDO: Dictionary = {
	"R 2 trazos": [[Vector2(0.3, 0.0), Vector2(0.3, 1.0)], [Vector2(0.3, 0.0), Vector2(0.72, 0.24), Vector2(0.3, 0.48), Vector2(0.72, 1.0)]],
	"R 1 trazo": [[Vector2(0.3, 1.0), Vector2(0.3, 0.0), Vector2(0.72, 0.24), Vector2(0.3, 0.48), Vector2(0.72, 1.0)]],
	"R panza redonda": [[Vector2(0.3, 0.0), Vector2(0.3, 1.0)], [Vector2(0.3, 0.0), Vector2(0.55, 0.02), Vector2(0.7, 0.12), Vector2(0.7, 0.34), Vector2(0.55, 0.46), Vector2(0.3, 0.48), Vector2(0.72, 1.0)]],
	"R 3 trazos": [[Vector2(0.3, 0.0), Vector2(0.3, 1.0)], [Vector2(0.3, 0.0), Vector2(0.72, 0.24), Vector2(0.3, 0.48)], [Vector2(0.3, 0.48), Vector2(0.72, 1.0)]],
}
const ALGIZ: Dictionary = {
	"Y palo entero 2 trazos": [[Vector2(0.5, 1.0), Vector2(0.5, 0.0)], [Vector2(0.1, 0.05), Vector2(0.5, 0.5), Vector2(0.9, 0.05)]],
	"Y 3 trazos": [[Vector2(0.5, 1.0), Vector2(0.5, 0.0)], [Vector2(0.5, 0.5), Vector2(0.1, 0.05)], [Vector2(0.5, 0.5), Vector2(0.9, 0.05)]],
	"Y brazos desde arriba": [[Vector2(0.5, 1.0), Vector2(0.5, 0.0)], [Vector2(0.12, 0.0), Vector2(0.5, 0.42), Vector2(0.88, 0.0)]],
	"Y 1 trazo (sin palo arriba)": [[Vector2(0.1, 0.0), Vector2(0.5, 0.45), Vector2(0.9, 0.0)], [Vector2(0.5, 0.45), Vector2(0.5, 1.0)]],
}

## Lo que cuenta como fallo (lo demás se imprime para mirarlo): con las runas grabadas, que una se lea como OTRO glifo más de MAX_OTRO
## de las veces, o que le robe algo a un glifo de siempre.
const MAX_OTRO: int = 5

var _rng := RandomNumberGenerator.new()
var _fallos: int = 0


func _initialize() -> void:
	_rng.seed = 2710
	var lib: GestureLibrary = GestureLibrary.get_shared()
	var familia: Dictionary = lib.templates_for(GestureLibrary.SIGILS)
	var activos := PackedStringArray(familia.keys())
	print("glifos con muestras: %s" % ", ".join(activos))

	# --- A · sin plantillas de ᚱ ni ᛉ: ¿se aceptan como otro glifo? ---
	print("\nA · un ᚱ o un ᛉ dibujado, ANTES de grabarlos (aceptado como otro glifo = conflicto)")
	for runa in [["ᚱ", RAIDO], ["ᛉ", ALGIZ]]:
		for variante in (runa[1] as Dictionary):
			for rect in [false, true]:
				var r: Dictionary = _medir((runa[1] as Dictionary)[variante], familia, activos, "", rect)
				print("  %s %-28s %s  aceptado como otro %3d%%  · más parecido: %s" % [runa[0], variante, "rect" if rect else "a mano", r["aceptado_otro"], r["top"]])

	# --- B · con plantillas sintéticas (4 por runa, de dos variantes) ---
	# Las plantillas se graban como se dibuja: a mano para los trazos a mano y rectificadas para los rectificados.
	var con: Dictionary = familia.duplicate(true)
	con["raido"] = _plantillas(RAIDO, ["R 2 trazos", "R 1 trazo"], false)
	con["permanencia"] = _plantillas(ALGIZ, ["Y palo entero 2 trazos", "Y 3 trazos"], false)
	var con_rect: Dictionary = familia.duplicate(true)
	con_rect["raido"] = _plantillas(RAIDO, ["R 2 trazos", "R 1 trazo"], true)
	con_rect["permanencia"] = _plantillas(ALGIZ, ["Y palo entero 2 trazos", "Y 3 trazos"], true)
	var activos_con := PackedStringArray(con.keys())
	print("\nB · con 4 plantillas sintéticas de cada runa (de las variantes «2 trazos» y «1 trazo» / «3 trazos»)")
	for runa in [["ᚱ", RAIDO, "raido"], ["ᛉ", ALGIZ, "permanencia"]]:
		for variante in (runa[1] as Dictionary):
			for rect in [false, true]:
				var r: Dictionary = _medir((runa[1] as Dictionary)[variante], con_rect if rect else con, activos_con, runa[2], rect)
				print("  %s %-28s %s  acierto %3d%%  · se va a otro %3d%%  · rival: %s" % [runa[0], variante, "rect" if rect else "a mano", r["acierto"], r["aceptado_otro"], r["rival"]])
				if int(r["aceptado_otro"]) > MAX_OTRO:
					_fallos += 1
					print("FALLO %s %s se lee como otro glifo el %d %%" % [runa[0], variante, r["aceptado_otro"]])
	print("\nB · los glifos de siempre (sus propias muestras con temblor), sin y con las dos runas")
	for nombre in familia:
		var sin: Dictionary = _medir_plantilla(nombre, familia, activos)
		var con_r: Dictionary = _medir_plantilla(nombre, con, activos_con)
		print("  %-11s acierto %3d%% → %3d%%   robados por ᚱ/ᛉ %3d%%   rival con ellas: %s" % [nombre, sin["acierto"], con_r["acierto"], con_r["robados"], con_r["rival"]])
		if int(con_r["robados"]) > 0:
			_fallos += 1
			print("FALLO ᚱ/ᛉ le roban a %s el %d %%" % [nombre, con_r["robados"]])

	# --- C · ᚱ contra los elementos (otra familia: solo informativo) ---
	var elems: Dictionary = lib.templates_for(GestureLibrary.ELEMENTS)
	print("\nC · ᚱ dibujado en el NÚCLEO (contra los elementos; en el juego no se comparan con los glifos)")
	for variante in RAIDO:
		var r: Dictionary = _medir(RAIDO[variante], elems, PackedStringArray(elems.keys()), "", false)
		print("  ᚱ %-28s aceptado como elemento %3d%% · más parecido: %s" % [variante, r["aceptado_otro"], r["top"]])

	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_lamina(con, args[0])
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## Dibuja N veces una variante con ruido y la reconoce. `objetivo` vacío = solo se mira si la acepta como otro.
func _medir(trazos_base: Array, plantillas: Dictionary, activos: PackedStringArray, objetivo: String, rect: bool) -> Dictionary:
	var ok: int = 0
	var otro: int = 0
	var cuenta: Dictionary = {}
	for _i in N:
		var t: Array = _dibujar(trazos_base)
		if rect:
			t = GestureRectify.rectificar_gesto(t, ESCALA_RECT, ESCALA_FORMA)
		var r: Dictionary = GestureRecognizer.recognize(t, plantillas, activos)
		var nombre: String = String(r["name"])
		cuenta[nombre] = int(cuenta.get(nombre, 0)) + 1
		if bool(r["accepted"]):
			if nombre == objetivo:
				ok += 1
			else:
				otro += 1
	return {"acierto": roundi(100.0 * ok / N), "aceptado_otro": roundi(100.0 * otro / N), "top": _top(cuenta, objetivo), "rival": _top(cuenta, objetivo)}


## Las muestras de un glifo grabado, deformadas (se rehacen trazos a partir de la nube: un trazo por muestra), contra la familia.
func _medir_plantilla(nombre: String, plantillas: Dictionary, activos: PackedStringArray) -> Dictionary:
	var ok: int = 0
	var robados: int = 0
	var cuenta: Dictionary = {}
	var muestras: Array = plantillas[nombre]
	for i in N:
		var nube: PackedVector2Array = muestras[i % muestras.size()]
		var t := PackedVector2Array()
		for p in nube:
			t.append(p * TAM + Vector2(_rng.randfn(0.0, 2.0), _rng.randfn(0.0, 2.0)))
		var r: Dictionary = GestureRecognizer.recognize([t], plantillas, activos)
		var n: String = String(r["name"])
		cuenta[n] = int(cuenta.get(n, 0)) + 1
		if bool(r["accepted"]) and n == nombre:
			ok += 1
		elif bool(r["accepted"]) and (n == "raido" or n == "permanencia"):
			robados += 1
	return {"acierto": roundi(100.0 * ok / N), "robados": roundi(100.0 * robados / N), "rival": _top(cuenta, nombre)}


## Una versión dibujada a mano: tamaño, estiramiento, giro y temblor al azar; los segmentos se rellenan con puntos cada ~3 px.
func _dibujar(trazos_base: Array) -> Array:
	var esc: float = TAM * _rng.randf_range(0.8, 1.25)
	var asp := Vector2(_rng.randf_range(0.85, 1.15), _rng.randf_range(0.85, 1.15))
	var giro: float = deg_to_rad(_rng.randf_range(-10.0, 10.0))
	var res: Array = []
	for tr in trazos_base:
		var pts := PackedVector2Array()
		var vs: Array = tr
		for k in range(vs.size() - 1):
			var a: Vector2 = vs[k]
			var b: Vector2 = vs[k + 1]
			var pasos: int = maxi(2, int(a.distance_to(b) * esc / 3.0))
			for s in pasos:
				var p: Vector2 = a.lerp(b, float(s) / float(pasos))
				p = ((p - Vector2(0.5, 0.5)) * asp).rotated(giro) * esc
				pts.append(p + Vector2(_rng.randfn(0.0, esc * 0.015), _rng.randfn(0.0, esc * 0.015)))
		var ult: Vector2 = vs[vs.size() - 1]
		pts.append(((ult - Vector2(0.5, 0.5)) * asp).rotated(giro) * esc)
		res.append(pts)
	return res


func _plantillas(variantes: Dictionary, nombres: Array, rect: bool) -> Array:
	var l: Array = []
	for n in nombres:
		for _i in 2:
			var t: Array = _dibujar(variantes[n])
			if rect:
				t = GestureRectify.rectificar_gesto(t, ESCALA_RECT, ESCALA_FORMA)
			l.append(GestureRecognizer.normalize(t))
	return l


func _top(cuenta: Dictionary, salvo: String) -> String:
	var mejor: String = "—"
	var m: int = 0
	for k in cuenta:
		if k != salvo and int(cuenta[k]) > m:
			m = int(cuenta[k])
			mejor = "%s %d%%" % [k if k != "" else "(nada)", roundi(100.0 * m / N)]
	return mejor


## Lámina con la primera nube de cada gesto (para mirar a ojo qué se parece a qué).
func _lamina(plantillas: Dictionary, carpeta: String) -> void:
	var nombres: Array = plantillas.keys()
	var c: int = 160
	var img := Image.create(c * nombres.size(), c + 20, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.1, 0.12))
	for i in nombres.size():
		var nube: PackedVector2Array = (plantillas[nombres[i]] as Array)[0]
		for p in nube:
			var q := Vector2(i * c + c * 0.5, c * 0.5 + 10) + p * c * 0.8
			for dx in range(-3, 4):
				for dy in range(-3, 4):
					var x: int = int(q.x) + dx
					var y: int = int(q.y) + dy
					if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
						img.set_pixel(x, y, Color(0.95, 0.8, 0.4) if nombres[i] in ["raido", "permanencia"] else Color(0.7, 0.85, 1.0))
	DirAccess.make_dir_recursive_absolute(carpeta)
	img.save_png(carpeta.path_join("nubes_glifos.png"))
	print("\nlámina: %s (orden: %s)" % [carpeta.path_join("nubes_glifos.png"), ", ".join(nombres)])
