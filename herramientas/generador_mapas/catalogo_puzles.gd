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
##   ; activa <pieza>.<señal>        solo `salida`: la señal que cuenta como «resuelto»
##   ; barrera si                    solo `salida`: el generador puede elegirla él solo como activador de una barrera (puerta o puente).
##                                   Sin esto la plantilla solo se pone a mano o con «Puzles del catálogo».
##   ; estira x                      la plantilla es una franja: cada fila se repite hasta el ancho de la sala. Una letra por fila: se repite entera.
##                                   23/11: con varias letras («ccc»), las n-1 primeras son la CABEZA fija (pegada a la izquierda) y la ÚLTIMA se repite hasta
##                                   el ancho de la sala (se ignoran los espacios del final). Una sala más estrecha que la fila más larga no sirve.
##   ; ancho_min <n>                 solo con `estira x`: ancho mínimo de la sala (para que los comodines `$XC` y `$X1` no choquen con la cabeza)
##   ; prueba anchos 5 8 12          (26/11) solo para el COMPROBADOR AUTOMÁTICO (`herramientas/comprobar_puzles_agua.gd`, que documenta el formato entero): los anchos de sala a los que probar
##                                   la plantilla (solo con `estira x`; el generador los fuerza con el parámetro `ancho_puzle`).
##   ; prueba mapa ancho=70 alto=60 sala_min=4  parámetros del mapa generado donde se prueba (para plantillas grandes que no caben en el mapa por defecto).
##   ; prueba solucion A: golpe fuego cuerda | espera puente tendido | max 6
##                                   una prueba jugada con hechizos reales: golpes, esperas hasta una condición, tope de tiempo. También `prueba nada: …` con `nunca … | durante <s>`.
##   ; cueva pieza …               una línea que solo se escribe si el estilo del mapa es «cueva» (el brasero con el modelo de la Cueva)
##   <filas del plano>               # pared · . suelo · ~ agua · c cauce del juego (suelo ocupado, SIN icono «?» por casilla; la vista lo pinta azul) ·
##                                   espacio = no tocar · cualquier otra letra = suelo con esa letra del juego (y un icono «?» en la vista)
##   ; pieza … / ; puzle …           como en un mapa. Los ids son locales (al colocar se les pone delante `cat<n>_`). Las casillas de la plantilla (x y de la pieza y las listas de
##                                   `celdas`, `de`, `sala`, `en`, `camino`, `canal`, `bloque`, `ruta` y `enlaces`) se trasladan a donde cae la plantilla.
##
## Comodines en las líneas: `$NIVEL` (el nivel en minúsculas), `$ID` (`cat<n>`, para flags: `$NIVEL.$ID.hecho`), `$X1` y `$Y1`
## (última columna y fila de la plantilla ya estirada), `$XC` (la columna central de la plantilla ya estirada, `(ancho-1)/2` entero; 23/11) y `$MODELO` (`modelo=cueva` si el estilo del mapa es «cueva»; si no, nada). Añadir un puzle = añadir un archivo; no hay que tocar código.

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
	var e: Dictionary = {"id": id_defecto, "titulo": id_defecto, "tipo": "premio", "pide": "", "activa": "", "estira": "", "ancho_min": 0, "barrera": false, "filas": [], "lineas": [], "lineas_cueva": [], "ancho": 0, "alto": 0,
		"anchos": [], "pruebas": [], "mapa": {}}
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
				"activa":
					e["activa"] = resto
				"estira":
					e["estira"] = resto
				"ancho_min":
					e["ancho_min"] = resto.to_int()
				"barrera":
					e["barrera"] = resto == "si"
				"prueba":
					# Líneas del comprobador (`herramientas/comprobar_puzles_agua.gd`): el generador no las usa.
					if resto.begins_with("anchos"):
						for n in resto.substr(6).strip_edges().split(" ", false):
							(e["anchos"] as Array).append(n.to_int())
					elif resto.begins_with("mapa "):
						for kv in resto.substr(5).split(" ", false):
							var par: PackedStringArray = kv.split("=", true, 1)
							if par.size() == 2:
								(e["mapa"] as Dictionary)[par[0]] = par[1].to_int() if par[1].is_valid_int() else (par[1].to_float() if par[1].is_valid_float() else par[1])
					else:
						(e["pruebas"] as Array).append(resto)
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
	return e
