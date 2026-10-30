class_name BD
extends RefCounted

## LA BASE DE DATOS DEL JUEGO (F0 de docs/PLAN_BASE_DATOS.md, 29/10, Juego).
##
## Lee los siete TSV de `res://nucleo/datos/` UNA sola vez y los sirve como Diccionarios y Arrays. No decide nada: el comportamiento son
## datos (una fila por objeto, fuente, receta, mejora...) y el código pregunta aquí. Todo es estático, como `Flags`/`Objetos`: no hay que
## instanciar ni añadir nada a la escena, y las pruebas sin SceneTree lo usan igual.
##
## FORMATO (el mismo en las siete tablas): UTF-8, tabulador, primera línea = nombres de columna. Una fila con otro número de columnas que
## la cabecera, o con un `id` repetido (en las tablas cuya clave es única), NO se carga y se anota en `errores()` (la prueba lo exige vacío).
## Cada fila pasa por el MISMO `_fila`, que convierte según el nombre de la columna (no hay un parser por tabla):
##   `-` o vacío        → valor vacío ("" / [] / {} / 0 / Color.WHITE según la columna)
##   etiquetas, requiere, donde → Array de cadenas (separadas por coma); usos → Array (separadas por «|», porque las frases llevan comas)
##   efecto             → Dictionary: `k=v;k=v`, con los números ya convertidos (`cura=40` → {"cura": 40}; `inmune=veneno` → {"inmune": "veneno"})
##   potencia, pila, peso, min, max, oro, tope, por_nivel, prob, cada_s → número (int si no lleva decimales, float si los lleva)
##   color              → Color (`#RRGGBB`)
##   lo demás           → cadena tal cual (las condiciones y las frases: `condicion`, `desc`, `se_conoce`, `nota`…), salvo `-` → ""

const RUTA: String = "res://nucleo/datos/"
const LISTAS: PackedStringArray = ["etiquetas", "requiere", "donde"]
const LISTAS_BARRA: PackedStringArray = ["usos"]
## F4 (29/10): las columnas NUMÉRICAS de `estados_mundo.tsv` que lee el código (las de texto de esa tabla solo describen). `-` = 0 = no aplica:
## aguante_s (aguante por s, negativo = baja) · dano_s (vida por s a aguante 0 o dentro de la nube) · rellena_s (aguante por s fuera del estado) · mojada_x (× del frío si está mojada) ·
## secado_x (× de la duración del mojado) · hielo_dura_x (× de la del hielo) · hiela_sola_s (s para que el mojado se hiele) · fuego_x, hielo_x, rayo_x, viento_x (× de lo que PERSISTE el hechizo) ·
## empuje (casillas/s del viento) · viento_cambia_s · rayo_cada_s · rayo_casillas · dura_s (dinámicos) · sigue_s, dispersa_s, consume_s, consume_casillas (la nube de veneno) ·
## vista_casillas (la jugadora) · vista_enemigo_casillas · ilumina_s · ilumina_casillas · brasero_casillas (el brasero que protege del frío).
const NUMEROS: PackedStringArray = ["potencia", "pila", "peso", "min", "max", "oro", "tope", "por_nivel", "prob", "cada_s",
	"aguante_s", "dano_s", "rellena_s", "mojada_x", "secado_x", "hielo_dura_x", "hiela_sola_s", "fuego_x", "hielo_x", "rayo_x", "viento_x", "empuje", "viento_cambia_s",
	"rayo_cada_s", "rayo_casillas", "dura_s", "sigue_s", "dispersa_s", "consume_s", "consume_casillas", "vista_casillas", "vista_enemigo_casillas", "ilumina_s", "ilumina_casillas", "brasero_casillas"]

static var _cargada: bool = false
static var _errores: Array[String] = []
static var _objetos: Dictionary = {}          ## id -> fila
static var _fuentes: Array = []               ## filas de fuentes.tsv, en el orden del archivo
static var _fuentes_por_objeto: Dictionary = {}   ## objeto -> Array de filas
static var _botin: Array = []                 ## filas de botin_tablas.tsv
static var _botin_por_tabla: Dictionary = {}  ## tabla -> Array de filas
static var _recetas: Dictionary = {}
static var _mejoras: Dictionary = {}
static var _reactivos: Array = []
static var _reactivos_por_pieza: Dictionary = {}
static var _estados: Dictionary = {}


## Carga las siete tablas si aún no están cargadas (las funciones de acceso lo llaman solas).
static func cargar() -> void:
	if _cargada:
		return
	_cargada = true
	_errores = []
	_objetos = _leer("objetos.tsv", "id")
	_recetas = _leer("recetas.tsv", "id")
	_mejoras = _leer("mejoras.tsv", "id")
	_estados = _leer("estados_mundo.tsv", "id")
	_fuentes = _leer_filas("fuentes.tsv")
	_botin = _leer_filas("botin_tablas.tsv")
	_reactivos = _leer_filas("reactivos_mapa.tsv")
	_fuentes_por_objeto = _agrupar(_fuentes, "objeto")
	_botin_por_tabla = _agrupar(_botin, "tabla")
	_reactivos_por_pieza = _agrupar(_reactivos, "pieza")


## Vuelve a leer los archivos (las pruebas que cambian una tabla; el juego no lo necesita).
static func recargar() -> void:
	_cargada = false
	cargar()


## Las filas mal formadas que se descartaron al cargar (vacío = todas las tablas están bien).
static func errores() -> Array[String]:
	cargar()
	return _errores


static func objeto(id: String) -> Dictionary:
	cargar()
	return _objetos.get(id, {})


static func objetos() -> Dictionary:
	cargar()
	return _objetos


## Las filas de `fuentes.tsv` de un objeto (de dónde sale); [] si no sale de ningún sitio.
static func fuentes_de(id: String) -> Array:
	cargar()
	return _fuentes_por_objeto.get(id, [])


static func fuentes() -> Array:
	cargar()
	return _fuentes


## Las filas de una tabla de botín (`jarron_cueva`, `goblin`…); [] si no existe.
static func tabla(id: String) -> Array:
	cargar()
	return _botin_por_tabla.get(id, [])


static func receta(id: String) -> Dictionary:
	cargar()
	return _recetas.get(id, {})


static func recetas() -> Dictionary:
	cargar()
	return _recetas


static func mejora(id: String) -> Dictionary:
	cargar()
	return _mejoras.get(id, {})


static func mejoras() -> Dictionary:
	cargar()
	return _mejoras


## Las filas de `reactivos_mapa.tsv` de una pieza del mundo (una por cada cosa que le puedes hacer); [] si no reacciona.
static func reactivos(pieza: String) -> Array:
	cargar()
	return _reactivos_por_pieza.get(pieza, [])


static func estado_mundo(id: String) -> Dictionary:
	cargar()
	return _estados.get(id, {})


static func estados_mundo() -> Dictionary:
	cargar()
	return _estados


# ---------------------------------------------------------------------------------------------------------------------
## Lee un TSV y devuelve sus filas válidas (Array de Dictionary), anotando las malas en `_errores`.
static func _leer_filas(archivo: String) -> Array:
	var filas: Array = []
	var f: FileAccess = FileAccess.open(RUTA + archivo, FileAccess.READ)
	if f == null:
		_errores.append("%s: no se pudo abrir (%s)" % [archivo, error_string(FileAccess.get_open_error())])
		return filas
	var cab: PackedStringArray = PackedStringArray()
	var n: int = 0
	while not f.eof_reached():
		var linea: String = f.get_line().trim_suffix("\r")
		n += 1
		if linea.strip_edges() == "":
			continue
		var campos: PackedStringArray = linea.split("\t")
		if cab.is_empty():
			cab = campos
			continue
		if campos.size() != cab.size():
			_errores.append("%s línea %d: %d columnas, la cabecera tiene %d" % [archivo, n, campos.size(), cab.size()])
			continue
		filas.append(_fila(cab, campos))
	return filas


## Como `_leer_filas` pero indexado por la columna `clave` (única): un repetido se descarta y se anota.
static func _leer(archivo: String, clave: String) -> Dictionary:
	var r: Dictionary = {}
	for fila in _leer_filas(archivo):
		var id: String = String((fila as Dictionary).get(clave, ""))
		if id == "":
			_errores.append("%s: una fila sin «%s»" % [archivo, clave])
		elif r.has(id):
			_errores.append("%s: id repetido «%s»" % [archivo, id])
		else:
			r[id] = fila
	return r


static func _agrupar(filas: Array, clave: String) -> Dictionary:
	var r: Dictionary = {}
	for fila in filas:
		var k: String = String((fila as Dictionary).get(clave, ""))
		if not r.has(k):
			r[k] = []
		(r[k] as Array).append(fila)
	return r


## UNA fila: cabecera + campos → Dictionary con cada valor ya convertido según el nombre de la columna.
static func _fila(cab: PackedStringArray, campos: PackedStringArray) -> Dictionary:
	var d: Dictionary = {}
	for i in range(cab.size()):
		var k: String = cab[i].strip_edges()
		var v: String = campos[i].strip_edges()
		var vacio: bool = v == "" or v == "-"
		if k == "efecto":
			d[k] = {} if vacio else _efecto(v)
		elif k == "color":
			d[k] = Color.WHITE if vacio else Color.html(v)
		elif NUMEROS.has(k):
			d[k] = 0 if vacio else _numero(v)
		elif LISTAS.has(k):
			d[k] = [] if vacio else _lista(v, ",")
		elif LISTAS_BARRA.has(k):
			d[k] = [] if vacio else _lista(v, "|")
		else:
			d[k] = "" if vacio else v
	return d


static func _lista(v: String, sep: String) -> Array:
	var r: Array = []
	for t in v.split(sep):
		var s: String = t.strip_edges()
		if s != "":
			r.append(s)
	return r


## `k=v;k=v` → {k: v}; un trozo sin «=» queda como k: true.
static func _efecto(v: String) -> Dictionary:
	var r: Dictionary = {}
	for t in v.split(";"):
		var par: String = t.strip_edges()
		if par == "":
			continue
		var p: int = par.find("=")
		if p < 0:
			r[par] = true
		else:
			r[par.substr(0, p).strip_edges()] = _valor(par.substr(p + 1).strip_edges())
	return r


## Un número si lo parece (entero o decimal); si no, la cadena.
static func _valor(v: String) -> Variant:
	if v.is_valid_int() or v.is_valid_float():
		return _numero(v)
	return v


static func _numero(v: String) -> Variant:
	if v.is_valid_int():
		return v.to_int()
	return v.to_float() if v.is_valid_float() else 0
