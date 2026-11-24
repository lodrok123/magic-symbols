extends RefCounted
## CATÁLOGO DE PUZLES del generador de mapas (17/11/2026). Cada puzle es un `.txt` de `herramientas/generador_mapas/catalogo/`, escrito
## con el mismo idioma que los mapas del juego, pero con las casillas contadas desde la esquina de la plantilla (0,0 arriba a la izquierda):
##
##   ; catalogo <id>                 nombre corto (el del archivo)
##   ; titulo <texto>                lo que se lee en la herramienta
##   ; tipo premio | paso | salida   premio: al resolverlo aparece algo dentro de la sala · paso: el puzle ES la barrera (se cruza al
##                                   resolverlo; su agua cuenta como cruzable) · salida: al resolverlo emite una señal que se puede
##                                   enlazar a una puerta o un puente del mapa (pincel «enlazar»)
##   ; pide <elementos>              qué necesita la jugadora (solo informativo)
##   ; necesita <runas>              (24/11) lo que tiene que tener la jugadora para RESOLVERLO, en runas del libro: sellos (fuego, agua, tierra…)
##                                   y glifos (flecha, linea, barrera, raido…) unidos con «+»; varias maneras, separadas con «|».
##                                   Ej.: `fuego+flecha | agua+flecha`. Sin esta línea (o `necesita -`), no pide ninguna runa (se resuelve empujando).
##                                   El generador solo reparte solo las que se pueden resolver con las runas elegidas (kit o casillas).
##   ; activa <pieza>.<señal>        solo `salida`: la señal que cuenta como «resuelto»
##   ; resuelto <pieza>.<señal>      (24/11) la señal que cuenta como «resuelto» para enlazar un COFRE al puzle (pincel «enlazar»: el
##                                   cofre aparece al resolverlo). Sin ella vale la de `activa`; sin ninguna, el puzle no se puede enlazar
##   ; barrera si                    solo `salida`: el generador puede elegirla él solo como activador de una barrera (puerta o puente).
##                                   Sin esto la plantilla solo se pone a mano o con «Puzles del catálogo».
##   ; estira x                      la plantilla es una franja: cada fila se repite hasta el ancho de la sala (una letra por fila)
##   ; cueva pieza …                 una línea que solo se escribe si el estilo del mapa es «cueva» (el brasero con el modelo de la Cueva)
##   <filas del plano>               # pared · . suelo · ~ agua · espacio = no tocar · cualquier otra letra = suelo con esa letra del juego
##   ; pieza … / ; puzle …           como en un mapa. Los ids son locales (al colocar se les pone delante `cat<n>_`).
##
## Comodines en las líneas: `$NIVEL` (el nivel en minúsculas), `$ID` (`cat<n>`, para flags: `$NIVEL.$ID.hecho`), `$X1` y `$Y1`
## (última columna y fila de la plantilla ya estirada) y `$MODELO` (`modelo=cueva` si el estilo del mapa es «cueva»; si no, nada). Añadir un puzle = añadir un archivo; no hay que tocar código.

const CARPETA: String = "res://herramientas/generador_mapas/catalogo/"
const TIPOS: Array[String] = ["premio", "paso", "salida"]

static var _cache: Dictionary = {}


static func todos() -> Dictionary:
	if _cache.is_empty():
		_cache = _leer()
	return _cache


static func recargar() -> void:
	_cache = _leer()


static func _leer() -> Dictionary:
	var res: Dictionary = {}
	var archivos: PackedStringArray = DirAccess.get_files_at(CARPETA)
	archivos.sort()
	for f in archivos:
		if not f.ends_with(".txt"):
			continue
		var e: Dictionary = leer_texto(FileAccess.get_file_as_string(CARPETA + f), f.get_basename())
		res[String(e["id"])] = e
	return res


static func leer_texto(texto: String, id_defecto: String = "") -> Dictionary:
	var e: Dictionary = {"id": id_defecto, "titulo": id_defecto, "tipo": "premio", "pide": "", "activa": "", "resuelto": "", "estira": "", "barrera": false, "filas": [], "lineas": [], "lineas_cueva": [], "ancho": 0, "alto": 0,
		"necesita": []}
	for linea in texto.split("\n"):
		var l: String = String(linea).replace("\r", "")
		if l.strip_edges() == "":
			continue
		if l.begins_with(";"):
			var t: String = l.substr(1).strip_edges()
			var p: PackedStringArray = t.split(" ", false)
			if p.is_empty():
				continue
			var resto: String = t.substr(p[0].length()).strip_edges()
			match p[0]:
				"catalogo":
					e["id"] = resto
				"titulo":
					e["titulo"] = resto
				"tipo":
					e["tipo"] = resto if TIPOS.has(resto) else "premio"
				"pide":
					e["pide"] = resto
				"necesita":
					e["necesita"] = leer_necesita(resto)
				"activa":
					e["activa"] = resto
				"resuelto":
					e["resuelto"] = resto
				"estira":
					e["estira"] = resto
				"barrera":
					e["barrera"] = resto == "si"
				"cueva":
					if resto.begins_with("pieza ") or resto.begins_with("puzle "):
						(e["lineas_cueva"] as Array).append("; " + resto)
				"pieza", "puzle":
					(e["lineas"] as Array).append("; " + t)
			continue
		(e["filas"] as Array).append(l)
	var ancho: int = 0
	for f in e["filas"]:
		ancho = maxi(ancho, String(f).length())
	for i in range((e["filas"] as Array).size()):
		e["filas"][i] = String(e["filas"][i]) + " ".repeat(ancho - String(e["filas"][i]).length())
	e["ancho"] = ancho
	e["alto"] = (e["filas"] as Array).size()
	if String(e["resuelto"]) == "" and String(e["activa"]).contains("."):
		e["resuelto"] = e["activa"]                  # un activador está resuelto cuando da su señal
	return e


## «fuego+flecha | agua+flecha» → [["fuego", "flecha"], ["agua", "flecha"]]. «-» o vacío → [] (no pide nada).
static func leer_necesita(texto: String) -> Array:
	var res: Array = []
	if texto.strip_edges() == "" or texto.strip_edges() == "-":
		return res
	for alt in texto.split("|", false):
		var una: Array = []
		for r in String(alt).split("+", false):
			var t: String = String(r).strip_edges()
			if t != "":
				una.append(t)
		if not una.is_empty():
			res.append(una)
	return res


## ¿Se puede resolver la plantilla `e` con estas runas (sellos y glifos que tiene la jugadora)? Basta una de sus maneras.
static func se_puede(e: Dictionary, runas: Array) -> bool:
	var nec: Array = e.get("necesita", [])
	if nec.is_empty():
		return true
	for una in nec:
		var vale: bool = true
		for r in una:
			if not runas.has(String(r)):
				vale = false
				break
		if vale:
			return true
	return false


## Lo que pide, dicho para leerlo: «fuego + flecha, o agua + flecha». "" si no pide ninguna runa.
static func necesita_dicho(e: Dictionary) -> String:
	var partes: PackedStringArray = PackedStringArray()
	for una in e.get("necesita", []):
		partes.append(" + ".join(PackedStringArray(una)))
	return ", o ".join(partes)
