class_name Flags
extends RefCounted

## FLAGS CON NOMBRE (C1 de PLAN_EOW, 21/10, Juego). Lo que el juego tiene que RECORDAR entre partidas: un cofre abierto, una sala
## resuelta, una puerta que ya se queda abierta. Un interruptor escribe la flag y la leen dos puertas, una valla y un cerrojo, sin
## enlaces directos entre ellos (así lo hace Echoes of Wisdom: ~40 flags por mazmorra grande).
##
## NOMBRES (contrato): `<nivel>.<sala>.<hecho>`, en minúsculas, con letras, cifras y «_» en cada trozo. Ej.: `bosque1.s3.placa_norte`,
## `bosque1.s3.cofre_abierto`. Hacen falta los tres trozos: el nivel y la sala dicen de quién es, y así dos salas no chocan.
##
## Qué es flag y qué no: solo lo persistente. Lo que pasa DENTRO de una sala mientras se juega (un pulsador hundido, una compuerta a
## medio abrir) sigue en las piezas de `Puzle3D`.
##
## Valor: normalmente `true`; se admite un entero (contadores: «cuántas antorchas encendidas»), una CADENA corta con el nombre del estado
## (`"abierto"`, `"roto"`, `"derrotado"`: VERSIÓN 2, F2 de PLAN_BASE_DATOS, 29/10) o `false` (= quitarla). `tiene(nombre)` es true si
## está puesta (true, un número distinto de 0 o una cadena no vacía); `valor(nombre)` devuelve la cadena. `si=flag.x` de `Puzle3D` solo usa `tiene`.
##
## SEÑAL `flag_cambio(nombre, valor)`: solo cuando el valor cambia de verdad. Nadie sondea.
## GUARDADO: el juego guarda TODO en un archivo con `Partida` (`nucleo/partida.gd`), que pide `a_dic()` y reparte `desde_dic()`. `a_dic()`
## separa `estados` (las flags con cadena, como el esbozo de Pablo) y `flags` (true o entero). `guardar()` / `cargar()` a un archivo suelto
## se mantienen solo por compatibilidad (la migración de `Partida` lee con ellos el `flags.json` viejo y algunas pruebas); el juego ya no los llama.
## Uso desde los puzles: `Puzle3D` (acción `flag.poner(nombre)`, señal `cuando=flag.<nombre>`, condición `si=flag.<nombre>`).

signal flag_cambio(nombre: String, valor: Variant)

const RUTA_DEFECTO: String = "user://flags.json"

static var _inst: Flags = null

var ruta_guardado: String = RUTA_DEFECTO
var _valores: Dictionary = {}           ## nombre -> true | int | String


static func i() -> Flags:
	if _inst == null:
		_inst = Flags.new()
	return _inst


## Empezar de cero (escenarios y pruebas, para no heredar nada).
static func nuevo() -> Flags:
	_inst = Flags.new()
	return _inst


## ¿Es un nombre válido? (nivel.sala.hecho: al menos tres trozos de letras minúsculas, cifras y «_»).
static func nombre_valido(nombre: String) -> bool:
	var trozos: PackedStringArray = nombre.split(".")
	if trozos.size() < 3:
		return false
	for t in trozos:
		if t == "":
			return false
		for k in range(t.length()):
			var ch: String = t[k]
			if not ((ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_"):
				return false
	return true


## Pone la flag (o la quita con `false`). Devuelve true si cambió. Un nombre mal escrito avisa y no se guarda.
func poner(nombre: String, valor: Variant = true) -> bool:
	if not nombre_valido(nombre):
		push_warning("Flags.poner: nombre no válido «%s» (se escribe nivel.sala.hecho)" % nombre)
		return false
	var v: Variant = _normalizar(valor)
	if v == null:
		if not _valores.has(nombre):
			return false
		_valores.erase(nombre)
		flag_cambio.emit(nombre, false)
		return true
	if _valores.has(nombre) and _valores[nombre] == v:
		return false
	_valores[nombre] = v
	flag_cambio.emit(nombre, v)
	return true


func quitar(nombre: String) -> bool:
	return poner(nombre, false)


func tiene(nombre: String) -> bool:
	return _valores.has(nombre)


## El valor (true, un entero o la cadena del estado); `defecto` si no está.
func valor(nombre: String, defecto: Variant = false) -> Variant:
	return _valores.get(nombre, defecto)


## Los nombres puestos, ordenados (para depurar y para las pruebas). Con `prefijo` («bosque1.s3.»), solo los de esa sala.
func nombres(prefijo: String = "") -> Array:
	var r: Array = []
	for n in _valores.keys():
		if prefijo == "" or String(n).begins_with(prefijo):
			r.append(n)
	r.sort()
	return r


## true, los enteros distintos de 0 y las cadenas no vacías se guardan; false, 0, «» y null quitan la flag (devuelve null).
static func _normalizar(v: Variant) -> Variant:
	if v is String or v is StringName:
		var t: String = String(v).strip_edges()
		return t if t != "" else null
	if v is bool:
		return true if v else null
	if v is int or v is float:
		var n: int = int(v)
		return n if n != 0 else null
	return true if v != null else null


# --- Guardado ---

## `{"estados": {nombre: cadena}, "flags": {nombre: true | int}}`: las dos secciones que `Partida` escribe tal cual en el archivo.
func a_dic() -> Dictionary:
	var estados: Dictionary = {}
	var flags: Dictionary = {}
	for n in _valores:
		if _valores[n] is String:
			estados[n] = _valores[n]
		else:
			flags[n] = _valores[n]
	return {"estados": estados, "flags": flags}


## Sustituye lo que hay por lo guardado. Lee las dos secciones (`estados` y `flags`) y también el formato de la versión 1
## (`{"version": 1, "flags": {...}}` o un diccionario plano nombre -> valor). Avisa (`flag_cambio`) de cada flag que cambia, también de las que desaparecen.
func desde_dic(d: Dictionary) -> void:
	var nuevos: Dictionary = {}
	var secciones: Array = [d]                         # plano: nombre -> valor
	if d.has("estados") or d.has("flags"):
		secciones = [d.get("estados", {}), d.get("flags", {})]
	for sec in secciones:
		if not (sec is Dictionary):
			continue
		for n in sec:
			var v: Variant = _normalizar(sec[n])      # JSON devuelve los números como float: vuelven a entero
			if v != null and nombre_valido(String(n)):
				nuevos[String(n)] = v
	var viejos: Dictionary = _valores
	_valores = nuevos
	for n in viejos:
		if not nuevos.has(n):
			flag_cambio.emit(n, false)
	for n in nuevos:
		if not viejos.has(n) or viejos[n] != nuevos[n]:
			flag_cambio.emit(n, nuevos[n])


func guardar(ruta: String = "") -> bool:
	var r: String = ruta if ruta != "" else ruta_guardado
	if r == "":
		return false
	var fa := FileAccess.open(r, FileAccess.WRITE)
	if fa == null:
		push_warning("Flags.guardar: no se pudo abrir %s" % r)
		return false
	fa.store_string(JSON.stringify(a_dic()))        # (compatibilidad: ya no es el formato del juego, ver `Partida`)
	fa.close()
	return true


## Carga el guardado si existe. Devuelve true si cargó algo.
func cargar(ruta: String = "") -> bool:
	var r: String = ruta if ruta != "" else ruta_guardado
	if r == "" or not FileAccess.file_exists(r):
		return false
	var fa := FileAccess.open(r, FileAccess.READ)
	if fa == null:
		return false
	var d: Variant = JSON.parse_string(fa.get_as_text())
	fa.close()
	if not (d is Dictionary):
		push_warning("Flags.cargar: %s no es un guardado válido" % r)
		return false
	desde_dic(d)
	return true
