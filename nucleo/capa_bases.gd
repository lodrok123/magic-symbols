class_name CapaBases
extends RefCounted
## Capa de sobrescritura EN MEMORIA de las bases del Hechizo: los valores por defecto, los modificadores de cada glifo y los de cada elemento.
##
## Para qué sirve (encargo del lab, 19/10): que LabHechizos3D sirva para DISEÑAR glifos y valores, no solo para probar lanzamientos. En el lab se
## toca una base («Bases», tecla N) y todos los hechizos que se construyan después la usan, sin recompilar ni editar `Sigils.GLIFOS` ni los .tres.
##
## Reglas (por qué es así):
##   · NUNCA escribe en res://. Es solo memoria; lo que se quiera conservar sale como texto (`texto()`) y lo pega Pablo en `Sigils.GLIFOS` y en los .tres.
##   · En el juego normal está VACÍA: `Hechizo.construir` pregunta aquí y, sin entradas, usa exactamente las tablas de siempre (coste: tres lecturas de diccionario vacío).
##   · Guarda solo lo que se tocó. Un glifo sin entrada se lee de `Sigils.GLIFOS`; un elemento sin entrada, de su .tres.
##   · `desde_texto(texto())` devuelve la misma capa: el texto exportado es también el formato de guardado (G) y se comprueba construyendo con él.

## campo -> valor por defecto del Hechizo (lo que `var campo = ...` dice en hechizo.gd).
static var defectos: Dictionary = {}
## nombre de glifo -> lista COMPLETA de modificadores [{campo, op, valor, tope, desde, salta}] que sustituye a la de Sigils.GLIFOS.
static var glifos: Dictionary = {}
## id de elemento (Objetos.elemento_de) -> diccionario COMPLETO {campo: {op, valor, ...}} que sustituye al `modificadores` del .tres.
static var elementos: Dictionary = {}


static func limpiar() -> void:
	defectos = {}
	glifos = {}
	elementos = {}


static func vacia() -> bool:
	return defectos.is_empty() and glifos.is_empty() and elementos.is_empty()


## Copia profunda del estado (para guardar y restaurar en pruebas y en el comparador).
static func copia() -> Dictionary:
	return {"defectos": defectos.duplicate(true), "glifos": glifos.duplicate(true), "elementos": elementos.duplicate(true)}


static func restaurar(c: Dictionary) -> void:
	defectos = (c.get("defectos", {}) as Dictionary).duplicate(true)
	glifos = (c.get("glifos", {}) as Dictionary).duplicate(true)
	elementos = (c.get("elementos", {}) as Dictionary).duplicate(true)


# --- lectura (la usa Hechizo) ---------------------------------------------------------------------------------------------------------------------

## Los modificadores del glifo: los de la capa si se tocó, los de Sigils.GLIFOS si no. Es la lista ORIGINAL (no copia): quien la modifique que la duplique.
static func modificadores_glifo(nombre: String) -> Array:
	if glifos.has(nombre):
		return glifos[nombre] as Array
	return Sigils.GLIFOS[nombre]["modificadores"] as Array


## Los `modificadores` del .tres del elemento, o los de la capa si se tocaron.
static func modificadores_elemento(r: RuneData) -> Dictionary:
	var id: String = Objetos.elemento_de(r)
	if elementos.has(id):
		return elementos[id] as Dictionary
	return r.modificadores


## Pone los valores por defecto de la capa en un Hechizo recién creado (antes de los modificadores del elemento).
static func aplicar_defectos(h: Hechizo) -> void:
	for campo in defectos:
		h._escribir(String(campo), defectos[campo])


# --- escritura (la usa el lab) -----------------------------------------------------------------------------------------------------------------

static func poner_defecto(campo: String, valor: Variant) -> void:
	defectos[campo] = _limpio(valor)


static func quitar_defecto(campo: String) -> void:
	defectos.erase(campo)


## Copia editable de la lista de un glifo (la de la capa o la original) para cambiarla y devolverla con `poner_glifo`.
static func lista_glifo(nombre: String) -> Array:
	return (modificadores_glifo(nombre) as Array).duplicate(true)


static func poner_glifo(nombre: String, lista: Array) -> void:
	glifos[nombre] = _limpio(lista.duplicate(true))


static func quitar_glifo(nombre: String) -> void:
	glifos.erase(nombre)


static func diccionario_elemento(r: RuneData) -> Dictionary:
	return (modificadores_elemento(r) as Dictionary).duplicate(true)


static func poner_elemento(r: RuneData, mods: Dictionary) -> void:
	elementos[Objetos.elemento_de(r)] = _limpio(mods.duplicate(true))


static func quitar_elemento(r: RuneData) -> void:
	elementos.erase(Objetos.elemento_de(r))


## Hay algo distinto de lo original en este glifo / elemento / campo (para marcarlo en la tabla y no exportar lo que no cambió).
static func glifo_tocado(nombre: String) -> bool:
	return glifos.has(nombre) and glifos[nombre] != Sigils.GLIFOS[nombre]["modificadores"]


static func elemento_tocado(r: RuneData) -> bool:
	var id: String = Objetos.elemento_de(r)
	return elementos.has(id) and elementos[id] != r.modificadores


# --- texto: exportar y volver a cargar ------------------------------------------------------------------------------------------------------------

## La capa como texto LISTO PARA PEGAR. Solo sale lo que difiere de lo original. `elementos_rune`: id -> RuneData (para saber el nombre del .tres y compararlo).
## Formato (también es el de guardado y se vuelve a leer con `desde_texto`):
##   # Hechizo — valores por defecto (nucleo/hechizo.gd): cambiar el `var` de cada campo
##   defecto campo = valor
##   # Sigils.GLIFOS["flecha"]["modificadores"]:
##   [
##   	{"campo": "...", "op": "...", "valor": ..., ...},
##   ]
##   # Elemento fire (nucleo/fire_rune.tres, propiedad `modificadores`):
##   modificadores = {"campo": {"op": "fija", "valor": 40.0}, ...}
static func texto(elementos_rune: Dictionary = {}) -> String:
	var l: PackedStringArray = PackedStringArray()
	var cd: Array = defectos.keys()
	cd.sort()
	var hay_def: bool = false
	for campo in cd:
		if var_to_str(defectos[campo]) == var_to_str(Hechizo.defecto_original(String(campo))):
			continue
		if not hay_def:
			l.append("# Hechizo — valores por defecto (nucleo/hechizo.gd): cambiar el `var` de cada campo")
			hay_def = true
		l.append("defecto %s = %s" % [campo, var_to_str(defectos[campo])])
	var cg: Array = glifos.keys()
	cg.sort()
	for nombre in cg:
		if not glifo_tocado(String(nombre)):
			continue
		l.append("# Sigils.GLIFOS[\"%s\"][\"modificadores\"]:" % nombre)
		l.append("[")
		for m in (glifos[nombre] as Array):
			l.append("\t" + _mod_a_texto(m as Dictionary) + ",")
		l.append("]")
	var ce: Array = elementos.keys()
	ce.sort()
	for id in ce:
		var r: RuneData = elementos_rune.get(id, null) as RuneData
		if r != null and not elemento_tocado(r):
			continue
		l.append("# Elemento %s (nucleo/%s_rune.tres, propiedad `modificadores`):" % [id, id])
		var partes: PackedStringArray = PackedStringArray()
		for campo in (elementos[id] as Dictionary):
			partes.append("\"%s\": %s" % [campo, _mod_a_texto(elementos[id][campo] as Dictionary)])
		l.append("modificadores = {%s}" % ", ".join(partes))
	if l.is_empty():
		return "# (bases sin cambios)"
	return "\n".join(l)


## Lee un texto de `texto()` y lo CARGA en la capa (sustituye lo que hubiera). Devuelve los avisos (vacío = todo bien).
static func desde_texto(txt: String) -> PackedStringArray:
	var avisos: PackedStringArray = PackedStringArray()
	limpiar()
	var actual: String = ""        # "glifo:<n>" · "elemento:<id>" · ""
	var lista: Array = []
	for crudo in txt.split("\n"):
		var linea: String = crudo.strip_edges()
		if linea.is_empty():
			continue
		if linea.begins_with("# Sigils.GLIFOS[\""):
			var ini: int = linea.find("\"") + 1
			actual = "glifo:" + linea.substr(ini, linea.find("\"", ini) - ini)
			lista = []
		elif linea.begins_with("# Elemento "):
			actual = "elemento:" + linea.substr(11).split(" ")[0]
		elif linea.begins_with("#"):
			continue
		elif linea.begins_with("defecto "):
			var partes: PackedStringArray = linea.substr(8).split(" = ", true, 1)
			if partes.size() != 2:
				avisos.append("línea de defecto mal formada: " + linea)
				continue
			defectos[partes[0]] = str_to_var(partes[1])
		elif linea == "[":
			lista = []
		elif linea == "]":
			if actual.begins_with("glifo:"):
				glifos[actual.substr(6)] = lista.duplicate(true)
			lista = []
		elif linea.begins_with("{") and actual.begins_with("glifo:"):
			var j: Variant = JSON.parse_string(linea.trim_suffix(","))
			if j is Dictionary:
				lista.append(_numeros_como_antes(j as Dictionary))
			else:
				avisos.append("modificador ilegible: " + linea)
		elif linea.begins_with("modificadores = ") and actual.begins_with("elemento:"):
			var d: Variant = JSON.parse_string(linea.substr(16))
			if d is Dictionary:
				var mods: Dictionary = {}
				for campo in (d as Dictionary):
					mods[campo] = _numeros_como_antes(d[campo] as Dictionary)
				elementos[actual.substr(9)] = mods
			else:
				avisos.append("modificadores ilegibles: " + linea)
		else:
			avisos.append("línea no reconocida: " + linea)
	return avisos


## JSON devuelve todo número como float; los campos que en las tablas son enteros (`salta`) vuelven a serlo para que `==` con las originales funcione.
static func _numeros_como_antes(m: Dictionary) -> Dictionary:
	var r: Dictionary = m.duplicate()
	if r.has("salta"):
		r["salta"] = int(r["salta"])
	return r


## Un modificador como diccionario de GDScript con las claves en el orden de siempre (campo, op, valor, tope, desde, salta): se pega tal cual y, como los valores se escriben como
## números/bool/texto, es también JSON válido (así se vuelve a leer).
static func _mod_a_texto(m: Dictionary) -> String:
	var ordenadas: Array = ["campo", "op", "valor", "tope", "desde", "salta"]
	var partes: PackedStringArray = PackedStringArray()
	for k in ordenadas:
		if m.has(k):
			partes.append("\"%s\": %s" % [k, var_to_str(m[k])])
	for k in m:
		if not ordenadas.has(k):
			partes.append("\"%s\": %s" % [k, var_to_str(m[k])])
	return "{" + ", ".join(partes) + "}"


## Los decimales con ruido de coma flotante (1,1000000000000003) se redondean a 4 cifras al entrar en la capa: lo que se exporta es lo que se probó, y al pegarlo y recargarlo
## sale el MISMO número.
static func _limpio(v: Variant) -> Variant:
	if v is float:
		return String.num(float(v), 4).to_float()
	if v is Array:
		var a: Array = []
		for x in (v as Array):
			a.append(_limpio(x))
		return a
	if v is Dictionary:
		var d: Dictionary = {}
		for k in (v as Dictionary):
			d[k] = _limpio((v as Dictionary)[k])
		return d
	return v
