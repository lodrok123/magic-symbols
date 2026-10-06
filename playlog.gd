class_name PlayLog
extends RefCounted

## EL DIARIO DE LA PARTIDA, PARA LAS PRUEBAS.
##
## Escribe una línea por suceso en un archivo (formato JSON Lines: un objeto por
## línea), así que se puede abrir con cualquier editor, o cargar en una hoja de
## cálculo o en Python, sin tener que mirar jugar a nadie para saber qué pasó.
##
## QUÉ SE APUNTA (campo "evento"):
##   inicio_partida     cada vez que arranca el nivel (también al reiniciar con R)
##   trazo              un trazo reconocido: tipo, nombre, margen, calidad
##   fallo              un trazo NO reconocido: lo que se parecía y su rival
##   cast               una página lanzada: página, elemento, glifos, calidad
##   cast_bloqueado     se intentó lanzar con la página recargando
##   voltereta          el jugador rueda
##   zona               cambio de zona (con el tiempo pasado en la anterior)
##   tiempo_por_zona    el resumen de segundos por zona (al morir, ganar o salir)
##   tarea              una tarea del nivel hecha
##   runas              runas nuevas conseguidas
##   muerte, victoria
##
## El tiempo "t" es en segundos de reloj desde que arrancó la partida (cuenta
## también con el libro abierto); "tiempo_por_zona" cuenta solo tiempo de juego.
##
## DÓNDE ESTÁ EL ARCHIVO: se imprime en la consola al empezar. En Windows suele
## ser %APPDATA%\Godot\app_userdata\<nombre del proyecto>\playtest_logs\
##
## Se usa desde cualquier sitio, sin tener que pasarlo de mano en mano:
##     PlayLog.event("cast", {"pagina": 1})

const CARPETA: String = "user://playtest_logs"

## La zona en la que está el jugador; la fija el nivel.
static var zona: String = ""

## Quién sabe volcar el resumen de tiempos (el nivel). Se avisa al morir o ganar.
static var volcado: Callable = Callable()

static var _file: FileAccess = null
static var _inicio_ms: int = 0
static var _partida: int = 0


## Llamar al arrancar el nivel.
static func nueva_partida() -> void:
	_partida += 1
	_inicio_ms = Time.get_ticks_msec()
	zona = ""
	event("inicio_partida")


static func t() -> float:
	return float(Time.get_ticks_msec() - _inicio_ms) / 1000.0


static func event(tipo: String, datos: Dictionary = {}) -> void:
	_abrir()
	if _file == null:
		return
	var linea: Dictionary = {"t": snappedf(t(), 0.01), "partida": _partida,
		"zona": zona, "evento": tipo}
	linea.merge(datos, true)
	_file.store_line(JSON.stringify(linea))
	_file.flush()


## Pide al nivel que escriba su resumen de tiempos (si lo hay).
static func volcar() -> void:
	if volcado.is_valid():
		volcado.call()


static func _abrir() -> void:
	if _file != null:
		return
	DirAccess.make_dir_recursive_absolute(CARPETA)
	var marca: String = Time.get_datetime_string_from_system().replace(":", "-")
	var ruta: String = "%s/run_%s.jsonl" % [CARPETA, marca]
	_file = FileAccess.open(ruta, FileAccess.WRITE)
	if _file == null:
		push_warning("PlayLog: no se pudo abrir %s" % ruta)
		return
	print("Diario de la prueba: ", ProjectSettings.globalize_path(ruta))
