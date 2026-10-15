extends "res://herramientas/escenario_base.gd"
## Escenario 13.10 · hornear: F9 escribe el nivel con el mapa VIVO y al recargarlo sale lo mismo. Lo escribe el Juego (15/10).
##
## Pulsa F9 por código en la escena del Bosque (a partir de las letras), con una letra del mapa cambiada a mano para saber que lo horneado
## es el mapa vivo y no el del disco; comprueba el `Nivel_Bosque.tscn` que sale (fecha nueva, nombre, lado, el suelo con el cambio) y
## RECARGA la escena desde ese archivo (`usar_escena = true`) para compararla con la de las letras: mismo lado, mismas casillas
## bloqueadas, los mismos objetos reactivos.
##
## CUIDADO, ESCRIBE EN EL REPO: HorneadorNivel.hornear pisa `mundo/datos_nivel/Nivel_Bosque.tscn` (ese archivo lleva las ediciones de
## Pablo) y aparta el anterior como `Nivel_Bosque_copia_<hora>.tscn`. Por eso este escenario, ANTES de pulsar F9, guarda una copia
## byte a byte en user://escenario_hornear/ y, al acabar, la devuelve a su sitio y borra la `_copia_` que se haya creado: el repo queda
## como estaba. Si una ejecución anterior se cortó a medias (queda el respaldo), lo primero que hace es restaurarlo y avisar.
## No lo lances con Godot abierto sobre el proyecto: el editor vería cambiar el archivo.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/escenario_hornear.gd

const RUTA_NIVEL: String = "res://mundo/datos_nivel/Nivel_Bosque.tscn"
const CARPETA_NIVELES: String = "res://mundo/datos_nivel/"
const CARPETA_RESPALDO: String = "user://escenario_hornear/"
const RESPALDO: String = "user://escenario_hornear/Nivel_Bosque.respaldo"
const CAMBIADA := Vector2i(6, 24)                       ## hierba abierta: se cambia a hierba alta («g») solo en el mapa vivo

var _existia: bool = false
var _copias_antes: PackedStringArray = []
var _tam_antes: int = -1


func _escenario() -> void:
	_recuperar_respaldo_viejo()
	_existia = FileAccess.file_exists(RUTA_NIVEL)
	_copias_antes = _copias()
	_tam_antes = _tam(RUTA_NIVEL)
	if _existia:
		DirAccess.make_dir_recursive_absolute(CARPETA_RESPALDO)
		_ok("0 se guarda una copia de seguridad del Nivel_Bosque.tscn de verdad", _copiar(RUTA_NIVEL, RESPALDO) and _tam(RESPALDO) == _tam_antes, "%d B" % _tam_antes)
	await _hornear_y_comparar()
	_restaurar()
	_ok("9 el repo queda como estaba: mismo Nivel_Bosque.tscn", _tam(RUTA_NIVEL) == (_tam_antes if _existia else -1), "%d B (antes %d B)" % [_tam(RUTA_NIVEL), _tam_antes])
	_ok("9 y sin ninguna `_copia_` nueva", _copias() == _copias_antes)


func _hornear_y_comparar() -> void:
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null:
		return
	var antes: Dictionary = _foto()
	_ok("1 la escena de las letras tiene mapa", int(antes["lado"]) > 0, "lado %d" % int(antes["lado"]))
	var letra_antes: String = Terreno3D.letra_de(CAMBIADA)
	Terreno3D.poner_letra(CAMBIADA, "g")
	_ok("1 la letra de %s cambia de «%s» a «g» en el mapa vivo" % [CAMBIADA, letra_antes], Terreno3D.letra_de(CAMBIADA) == "g")

	var hora_antes: String = Time.get_datetime_string_from_system()
	var unix_antes: float = Time.get_unix_time_from_system() - 1.0
	_tecla(KEY_F9, true)
	await avanzar(2)
	_tecla(KEY_F9, false)
	var pared: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - pared < 30000 and not (FileAccess.file_exists(RUTA_NIVEL) and FileAccess.get_modified_time(RUTA_NIVEL) >= int(unix_antes)):
		await process_frame
	await avanzar(10)
	_ok("2 F9 escribe `Nivel_Bosque.tscn`", FileAccess.file_exists(RUTA_NIVEL) and FileAccess.get_modified_time(RUTA_NIVEL) >= int(unix_antes), "%d ms" % (Time.get_ticks_msec() - pared))

	# --- Lo que hay dentro del archivo ---
	var paquete: PackedScene = ResourceLoader.load(RUTA_NIVEL, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	_ok("3 el archivo carga como escena", paquete != null)
	if paquete == null:
		return
	var nivel: Node = paquete.instantiate()
	var fecha: String = String(nivel.get_meta("horneado", ""))
	_ok("3 trae la fecha del horneado, nueva (≥ %s)" % hora_antes, fecha != "" and fecha >= hora_antes, "«%s»" % fecha)
	if _existia:
		var viejo: Node = (load(RESPALDO) as PackedScene).instantiate() if ResourceLoader.exists(RESPALDO) else null
		var fecha_vieja: String = String(viejo.get_meta("horneado", "")) if viejo != null else ""
		_ok("3 y distinta de la del archivo anterior («%s»)" % fecha_vieja, fecha != fecha_vieja)
		if viejo != null:
			viejo.free()
	_ok("3 el nombre es «Bosque» y el lado el del mapa vivo", String(nivel.get_meta("nombre", "")) == "Bosque" and int(nivel.get_meta("lado", 0)) == int(antes["lado"]), "lado %s" % str(nivel.get_meta("lado", 0)))
	var suelo: GridMap = nivel.get_node_or_null("Suelo") as GridMap
	_ok("3 trae el suelo (GridMap «Suelo»)", suelo != null)
	if suelo != null:
		var item: int = suelo.get_cell_item(Vector3i(CAMBIADA.x, 0, CAMBIADA.y))
		var letra: String = HorneadorNivel.letra_de_item(HorneadorNivel.biblioteca(), item)
		_ok("4 el suelo lleva el MAPA VIVO: en %s hay «g», no «%s»" % [CAMBIADA, letra_antes], letra == "g", "«%s»" % letra)
		var distintas: int = 0
		var lib: MeshLibrary = HorneadorNivel.biblioteca()
		var letras_suelo: Dictionary = {}                 # las letras que tienen un suelo propio en la biblioteca (el resto cae al «.»)
		for i in lib.get_item_list():
			letras_suelo[HorneadorNivel.letra_de_item(lib, i)] = true
		for y in range(Terreno3D.mapa.size()):
			for x in range(Terreno3D.mapa[y].length()):
				var l: String = Terreno3D.mapa[y][x]
				if l == "." or l == "#" or l == " " or not letras_suelo.has(l):
					continue                     # el «.» se reparte al azar entre varios suelos; paredes y marcadores caen al suelo normal
				var it: int = suelo.get_cell_item(Vector3i(x, 0, y))
				if HorneadorNivel.letra_de_item(lib, it) != l:
					distintas += 1
		_ok("4 el resto del suelo con letra propia coincide con el mapa vivo", distintas == 0, "%d casillas distintas, %d letras con suelo propio" % [distintas, letras_suelo.size()])
	nivel.free()

	# --- Recargar desde el archivo y comparar con la escena de las letras ---
	maqueta.queue_free()
	await avanzar(5)
	await cargar(RUTA_BOSQUE, true)
	if maqueta == null:
		return
	var despues: Dictionary = _foto()
	_ok("5 recargada del .tscn: mismo lado de mapa", despues["lado"] == antes["lado"], "%s → %s" % [antes["lado"], despues["lado"]])
	# Dos direcciones distintas: (a) bloqueada con las letras y LIBRE en el .tscn = se ha abierto un hueco que no estaba (muro, tinaja, telaraña…):
	# eso es un fallo. (b) libre con las letras y bloqueada en el .tscn = el nivel horneado cierra casillas de más (la huella de una pieza más
	# ancha que su letra): se enseña como AVISO con la lista, no como fallo, porque puede ser intencionado (tienda de campaña) o no (arcos).
	var solo_letras: Array = (antes["bloqueadas"] as Array).filter(func(c: Vector2i) -> bool: return not (despues["bloqueadas"] as Array).has(c))
	var solo_tscn: Array = (despues["bloqueadas"] as Array).filter(func(c: Vector2i) -> bool: return not (antes["bloqueadas"] as Array).has(c))
	_ok("6 el .tscn no abre ninguna casilla que las letras bloquean", solo_letras.is_empty(), "%d abiertas%s" % [solo_letras.size(), (": " + str(solo_letras.slice(0, 8))) if not solo_letras.is_empty() else ""])
	if not solo_tscn.is_empty():
		var det: Array = []
		for c in solo_tscn:
			var fila: String = (antes["mapa"] as PackedStringArray)[(c as Vector2i).y]
			det.append("%s«%s»" % [c, fila[(c as Vector2i).x] if (c as Vector2i).x < fila.length() else "?"])
		_aviso("6 el .tscn bloquea %d casillas MÁS que las letras (huella de la pieza horneada)" % solo_tscn.size(), " ".join(det))
	_ok("7 mismos objetos reactivos por tipo", antes["reactivos"] == despues["reactivos"], "%s → %s" % [antes["reactivos"], despues["reactivos"]])
	_ok("7 la tinaja sigue en el mismo sitio", antes["tinaja"] == despues["tinaja"], "%s → %s" % [antes["tinaja"], despues["tinaja"]])
	_ok("8 y el cambio hecho al mapa vivo sigue en el nivel recargado (en %s hay «g»)" % CAMBIADA, Terreno3D.letra_de(CAMBIADA) == "g", "«%s»" % Terreno3D.letra_de(CAMBIADA))


## Una foto de lo observable de la escena cargada: lado, casillas bloqueadas, objetos reactivos por tipo y dónde está la tinaja.
func _foto() -> Dictionary:
	var por_tipo: Dictionary = {}
	var tinaja: Vector2i = Vector2i(-1, -1)
	for r in maqueta.find_children("*", "Reactivo3D", true, false):
		var t: String = (r as Reactivo3D).tipo
		por_tipo[t] = int(por_tipo.get(t, 0)) + 1
		if t == "surtidor":
			tinaja = (r as Reactivo3D).celda
	var bloq: Array = []
	var n: int = Terreno3D.lado_del_mapa()
	for y in range(n):
		for x in range(n):
			if Lanzador3D.bloqueada(Vector2i(x, y)):
				bloq.append(Vector2i(x, y))
	return {"lado": n, "bloqueadas": bloq, "reactivos": por_tipo, "tinaja": tinaja, "mapa": Terreno3D.mapa.duplicate()}


func _copias() -> PackedStringArray:
	var r: PackedStringArray = []
	var d: DirAccess = DirAccess.open(CARPETA_NIVELES)
	if d != null:
		for f in d.get_files():
			if f.begins_with("Nivel_Bosque_copia_"):
				r.append(f)
	r.sort()
	return r


func _tam(ruta: String) -> int:
	var f: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	return f.get_length() if f != null else -1


func _copiar(de: String, a: String) -> bool:
	var f: FileAccess = FileAccess.open(de, FileAccess.READ)
	if f == null:
		return false
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var g: FileAccess = FileAccess.open(a, FileAccess.WRITE)
	if g == null:
		return false
	g.store_buffer(bytes)
	g.close()
	return true


## Deja el repo como estaba: devuelve el Nivel_Bosque.tscn de verdad (o borra el que se haya creado si no existía) y borra las `_copia_` nuevas.
func _restaurar() -> void:
	if _existia and FileAccess.file_exists(RESPALDO):
		_copiar(RESPALDO, RUTA_NIVEL)
		DirAccess.remove_absolute(RESPALDO)
	elif not _existia and FileAccess.file_exists(RUTA_NIVEL):
		DirAccess.remove_absolute(RUTA_NIVEL)
	for f in _copias():
		if not _copias_antes.has(f):
			DirAccess.remove_absolute(CARPETA_NIVELES + f)


## Si una ejecución anterior se cortó entre el respaldo y la restauración, el Nivel_Bosque.tscn de Pablo está pisado: se devuelve ya.
func _recuperar_respaldo_viejo() -> void:
	if FileAccess.file_exists(RESPALDO):
		_copiar(RESPALDO, RUTA_NIVEL)
		DirAccess.remove_absolute(RESPALDO)
		_aviso("0 había un respaldo de una ejecución cortada: Nivel_Bosque.tscn restaurado", RESPALDO)
