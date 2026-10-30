extends SceneTree
## FOTO FIJA («golden») DE LOS NÚMEROS DEL HECHIZO (H0 del PLAN_SISTEMA_HECHIZOS, 29/10), sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_hechizo_golden.gd
##   godot --headless --path . --script res://herramientas/prueba_hechizo_golden.gd -- --regenerar     (reescribe el JSON; hazlo A PROPÓSITO y anota en el diario qué cambió)
## Para TODAS las recetas de 0 a 4 glifos (con repetición) de `Sigils.GLIFOS` × los 6 elementos × calidades [1.0, 0.4], `Hechizo.construir(...).a_diccionario()` se compara con
## `herramientas/golden_hechizos.json` (clave: «<elemento> <glifos ordenados con conteo> q<calidad>», p. ej. «fire flecha:2,linea_x:1 q1.0»). Números con tolerancia 1e-4; listas y
## diccionarios, recursivamente; strings y bools, exactos. Si el JSON no existe, lo escribe. Si un cambio mueve un número, esta prueba lo dice con clave y campo.
##
## RECORTE (30/10): con 14 glifos el JSON completo pesaba 115 MB (36 720 recetas × ~135 campos, casi todos en su defecto) y GitHub no admite más de 100 MB. Ahora cada receta guarda
## SOLO lo que difiere de su BASE (la receta sin glifos del mismo elemento y calidad, que va entera salvo lo que vale el defecto `Hechizo.defecto`) más los campos de SIEMPRE (daño, tinta,
## recarga, forma, niveles, nivel de daño); `origen`, `glifos`, `semiejes_glifos`, `elemento` y `calidad` no se guardan (los dos últimos van en la clave). La comparación compacta las dos
## partes igual, así que sigue detectando cualquier cambio: un número que se mueve, un campo que deja de valer lo de su base (aparece) o que vuelve a ello (desaparece), un cambio en lo que
## pone el elemento (lo enseña la base y desaparece de las demás) y un cambio en un valor POR DEFECTO (lo enseña la entrada «__defectos__», que guarda el defecto de cada campo y derivado).
## Números a 4 decimales. Una línea por receta, para que el diff en git se lea por receta.

const MAX_GLIFOS: int = 4
const ELEMENTOS: Array = ["fire", "water", "earth", "ice", "lightning", "wind"]
const CALIDADES: Array = [1.0, 0.4]
const RUTA: String = "res://herramientas/golden_hechizos.json"
const TOLERANCIA: float = 0.0001
const MAX_MOSTRADOS: int = 40
## Campos que se guardan SIEMPRE, valgan lo que valgan (lo que más importa de un hechizo y lo que el daño y la tinta derivan).
const SIEMPRE: PackedStringArray = ["dano", "coste_tinta", "recarga", "forma", "niveles", "nivel_dano"]
## Lo que NO se guarda: se deriva de la clave o es de dónde viene cada valor (`origen`), no el valor.
const NUNCA: PackedStringArray = ["origen", "glifos", "semiejes_glifos", "elemento", "calidad"]
const DECIMALES: float = 0.0001
const CLAVE_DEFECTOS: String = "__defectos__"      ## la entrada del golden con el valor por defecto de cada campo y derivado

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
	var completo: Dictionary = {}
	for combo in combos:
		var c: Dictionary = {}
		for n in combo:
			c[n] = int(c.get(n, 0)) + 1
		for e in ELEMENTOS:
			for q in CALIDADES:
				var h: Hechizo = Hechizo.construir(runes[e] as RuneData, c, float(q))
				completo[_clave(e, c, float(q))] = _redondear(JSON.parse_string(JSON.stringify(h.a_diccionario())))   # ida y vuelta: lo mismo que verá el JSON (ints → float, Vector3 → array…)
	# Compacto: la receta BASE de cada elemento y calidad (sin glifos) va entera; las demás, solo lo que difiere de su base más SIEMPRE.
	var actual: Dictionary = {}
	for clave in completo:
		var base_clave: String = _clave_base(String(clave))
		actual[clave] = _compactar(completo[clave], completo[base_clave] if (base_clave != String(clave) and completo.has(base_clave)) else {})
	# Los DEFECTOS, como una receta más: lo que las recetas no guardan por valer el defecto solo queda vigilado si el defecto mismo está en el golden.
	var defectos: Dictionary = {}
	for par in Hechizo.CAMPOS:
		defectos[String(par[0])] = _defecto_plano(String(par[0]))
	for campo in Hechizo.DERIVADOS:
		defectos[String(campo)] = _defecto_plano(String(campo))
	actual[CLAVE_DEFECTOS] = defectos
	var regenerar: bool = OS.get_cmdline_user_args().has("--regenerar")
	if regenerar or not FileAccess.file_exists(RUTA):
		var f := FileAccess.open(RUTA, FileAccess.WRITE)
		if f == null:
			print("FALLO: no se puede escribir %s (error %d)" % [RUTA, FileAccess.get_open_error()])
			print("FALLOS: 1")
			quit(1)
			return
		# una línea por receta, claves ordenadas: el diff de git se lee receta a receta
		var claves: Array = actual.keys()
		claves.sort()
		var lineas: PackedStringArray = PackedStringArray()
		for k in claves:
			lineas.append("%s: %s" % [JSON.stringify(String(k)), JSON.stringify(actual[k], "", true)])
		f.store_string("{\n" + ",\n".join(lineas) + "\n}\n")
		f.close()
		print("golden escrito: %s · %d recetas (%d combinaciones × %d elementos × %d calidades) · %.1f MB" % [RUTA, actual.size(), combos.size(), ELEMENTOS.size(), CALIDADES.size(), float(FileAccess.get_file_as_bytes(RUTA).size()) / 1048576.0])
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


## La receta en compacto: solo los campos de SIEMPRE y los que difieren de su BASE (la receta sin glifos del mismo elemento y calidad; si `base` está vacía, ESTA es la base y va
## entera salvo lo que vale su defecto `Hechizo.defecto`); nunca los de NUNCA. Así lo que pone el elemento se guarda una vez por elemento y calidad, y cada receta solo lo que añaden sus glifos.
## Los números ya vienen a 4 decimales (`_redondear`): una diferencia de coma flotante no ensucia el diff y la tolerancia de la comparación sigue valiendo.
static func _compactar(d: Dictionary, base: Dictionary) -> Dictionary:
	var salida: Dictionary = {}
	var claves: Array = d.keys()
	claves.sort()
	for k in claves:
		var campo: String = String(k)
		if NUNCA.has(campo):
			continue
		var v: Variant = d[campo]
		var referencia: Variant = base[campo] if base.has(campo) else _defecto_plano(campo)
		if not SIEMPRE.has(campo) and _igual(v, referencia):
			continue
		salida[campo] = v
	return salida


## La clave de la receta base (sin glifos) de la clave de una receta: «<elemento> <glifos> q<calidad>» → «<elemento>  q<calidad>».
static func _clave_base(clave: String) -> String:
	var partes: PackedStringArray = clave.split(" ")
	return "%s  %s" % [partes[0], partes[partes.size() - 1]]


## El defecto de un campo con el mismo viaje por JSON que el valor (ints → float, Vector3 → array, Color → html). Vale también para los derivados: en un Hechizo recién hecho valen lo de la esfera base.
static var _cache_defectos: Dictionary = {}
static func _defecto_plano(campo: String) -> Variant:
	if not _cache_defectos.has(campo):
		var h := Hechizo.new()
		CapaBases.aplicar_defectos(h)
		var v: Variant = h.get(campo) if campo in h else null
		_cache_defectos[campo] = _redondear(JSON.parse_string(JSON.stringify({"v": Hechizo._plano(v)}))["v"])
	return _cache_defectos[campo]


static func _redondear(v: Variant) -> Variant:
	if v is float:
		return snappedf(v, DECIMALES)
	if v is Array:
		var r: Array = []
		for x in v:
			r.append(_redondear(x))
		return r
	if v is Dictionary:
		var r: Dictionary = {}
		for k in v:
			r[k] = _redondear(v[k])
		return r
	return v


static func _igual(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a) - float(b)) < TOLERANCIA
	if a is Array and b is Array:
		if (a as Array).size() != (b as Array).size():
			return false
		for i in range((a as Array).size()):
			if not _igual(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for k in a:
			if not (b as Dictionary).has(k) or not _igual(a[k], b[k]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


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
