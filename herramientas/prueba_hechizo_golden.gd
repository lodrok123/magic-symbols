extends SceneTree
## FOTO FIJA («golden») DE LOS NÚMEROS DEL HECHIZO (H0 del PLAN_SISTEMA_HECHIZOS, 29/10), sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_hechizo_golden.gd
##   godot --headless --path . --script res://herramientas/prueba_hechizo_golden.gd -- --regenerar     (reescribe el JSON; hazlo A PROPÓSITO y anota en el diario qué cambió)
## Para TODAS las recetas de 0 a 4 glifos (con repetición) de `Sigils.GLIFOS` × los 6 elementos × calidades [1.0, 0.4], `Hechizo.construir(...).a_diccionario()` se compara con
## `herramientas/golden_hechizos.json` (clave: «<elemento> <glifos ordenados con conteo> q<calidad>», p. ej. «fire flecha:2,linea_x:1 q1.0»). Números con tolerancia 1e-4; listas y
## diccionarios, recursivamente; strings y bools, exactos. Si el JSON no existe, lo escribe. Si un cambio mueve un número, esta prueba lo dice con clave y campo.

const MAX_GLIFOS: int = 4
const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]
const CALIDADES: Array = [1.0, 0.4]
const RUTA: String = "res://herramientas/golden_hechizos.json"
const TOLERANCIA: float = 0.0001
const MAX_MOSTRADOS: int = 40

var _fallos_campo: int = 0
var _mostrados: int = 0
var _recetas_con_fallo: int = 0


func _initialize() -> void:
	await process_frame
	var runes: Dictionary = {}
	for e in ELEMENTOS:
		runes[e] = load("res://nucleo/%s_rune.tres" % e)
	var combos: Array = []
	_generar(Sigils.GLIFOS.keys(), MAX_GLIFOS, 0, [], combos)
	var actual: Dictionary = {}
	for combo in combos:
		var c: Dictionary = {}
		for n in combo:
			c[n] = int(c.get(n, 0)) + 1
		for e in ELEMENTOS:
			for q in CALIDADES:
				var h: Hechizo = Hechizo.construir(runes[e] as RuneData, c, float(q))
				actual[_clave(e, c, float(q))] = JSON.parse_string(JSON.stringify(h.a_diccionario()))   # ida y vuelta: lo mismo que verá el JSON (ints → float, Vector3 → array…)
	var regenerar: bool = OS.get_cmdline_user_args().has("--regenerar")
	if regenerar or not FileAccess.file_exists(RUTA):
		var f := FileAccess.open(RUTA, FileAccess.WRITE)
		if f == null:
			print("FALLO: no se puede escribir %s (error %d)" % [RUTA, FileAccess.get_open_error()])
			print("FALLOS: 1")
			quit(1)
			return
		f.store_string(JSON.stringify(actual, "\t", true))
		f.close()
		print("golden escrito: %s · %d recetas (%d combinaciones × %d elementos × %d calidades)" % [RUTA, actual.size(), combos.size(), ELEMENTOS.size(), CALIDADES.size()])
		print("FALLOS: 0")
		quit(0)
		return
	var esperado: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA))
	if not (esperado is Dictionary):
		print("FALLO: %s no es un JSON de diccionario" % RUTA)
		print("FALLOS: 1")
		quit(1)
		return
	for clave in actual:
		if not (esperado as Dictionary).has(clave):
			_fallo(clave, "(receta)", "no está en el golden", "existe")
			_recetas_con_fallo += 1
			continue
		var antes: int = _fallos_campo
		_comparar(clave, "", (esperado as Dictionary)[clave], actual[clave])
		if _fallos_campo > antes:
			_recetas_con_fallo += 1
	for clave in esperado:
		if not actual.has(clave):
			_fallo(clave, "(receta)", "está en el golden", "ya no se genera")
			_recetas_con_fallo += 1
	print("recetas: %d · en el golden: %d · recetas que difieren: %d · campos que difieren: %d" % [actual.size(), (esperado as Dictionary).size(), _recetas_con_fallo, _fallos_campo])
	if _fallos_campo > MAX_MOSTRADOS:
		print("(solo se enseñan los primeros %d; si el cambio es a propósito: -- --regenerar y anótalo en el diario)" % MAX_MOSTRADOS)
	print("FALLOS: %d" % _fallos_campo)
	quit(1 if _fallos_campo > 0 else 0)


func _generar(nombres: Array, restante: int, desde: int, actual: Array, salida: Array) -> void:
	salida.append(actual.duplicate())
	if restante == 0:
		return
	for i in range(desde, nombres.size()):
		actual.append(nombres[i])
		_generar(nombres, restante - 1, i, actual, salida)
		actual.pop_back()


func _clave(elemento: String, c: Dictionary, calidad: float) -> String:
	var nombres: Array = c.keys()
	nombres.sort()
	var partes: PackedStringArray = []
	for n in nombres:
		partes.append("%s:%d" % [n, int(c[n])])
	return "%s %s q%.1f" % [elemento, ",".join(partes), calidad]


func _fallo(clave: String, campo: String, esperado: Variant, obtenido: Variant) -> void:
	_fallos_campo += 1
	if _mostrados < MAX_MOSTRADOS:
		_mostrados += 1
		print("FALLO: «%s» campo %s: esperado %s, obtenido %s" % [clave, campo, str(esperado), str(obtenido)])


func _comparar(clave: String, campo: String, esp: Variant, obt: Variant) -> void:
	var es_num_e: bool = esp is float or esp is int
	var es_num_o: bool = obt is float or obt is int
	if es_num_e and es_num_o:
		if absf(float(esp) - float(obt)) >= TOLERANCIA:
			_fallo(clave, campo, esp, obt)
	elif esp is Array and obt is Array:
		var a: Array = esp
		var b: Array = obt
		if a.size() != b.size():
			_fallo(clave, campo + " (tamaño)", a.size(), b.size())
			return
		for i in range(a.size()):
			_comparar(clave, "%s[%d]" % [campo, i], a[i], b[i])
	elif esp is Dictionary and obt is Dictionary:
		var da: Dictionary = esp
		var db: Dictionary = obt
		for k in da:
			var sub: String = ("%s.%s" % [campo, k]) if campo != "" else String(k)
			if not db.has(k):
				_fallo(clave, sub, str(da[k]), "(falta)")
			else:
				_comparar(clave, sub, da[k], db[k])
		for k in db:
			if not da.has(k):
				_fallo(clave, ("%s.%s" % [campo, k]) if campo != "" else String(k), "(no estaba)", str(db[k]))
	elif typeof(esp) != typeof(obt) or esp != obt:
		_fallo(clave, campo, esp, obt)
