class_name AmbienteZona
extends Node

## AMBIENTE SONORO POR ZONA (tercera tanda, lote 3, tarea C3; 2/11). Una capa de bucle de fondo según el TIPO de zona en la que está el jugador, en el bus «Mundo», con un fundido cruzado de
## `T_FUNDIDO_AMBIENTE` s al cambiar de zona (y un fundido de entrada al llegar a un nivel):
##   · bosque (exteriores)      viento suave; de día, trinos de pájaros sueltos cada `INTERVALO_PAJAROS` s al azar; de noche los pájaros callan y entran los grillos (`CicloDia3D.es_noche()`)
##   · cueva                    goteo y viento grave
##   · sala (interior)          zumbido bajo
## Qué tipo es cada zona lo dice `TIPO_POR_LUZ`, sobre los mismos nombres que `LuzZona3D.ZONAS`; la zona actual la da `Zonas3D.luz_actual()` (la luz de la escena si el mapa no tiene zonas).
##
## SONIDO. Reproductores PLANOS (`AudioStreamPlayer`, sin posición) en el bus «Mundo» (el mismo que Sfx3D: el volumen Mundo del menú de pausa los gobierna). Los sonidos son los de `Sfx.CATALOGO`
## (`amb_bosque`, `amb_cueva`, `amb_sala`, `amb_grillos`, `amb_pajaros`; generados por audio/gen_sfx_interfaz.py `ambiente_zonas`), a −18 dB; `Sfx.AJUSTES` manda sobre el catálogo y se lee cada
## fotograma (el panel F3 «dB:amb_bosque» se oye al instante). Con `REGISTRAR` cada capa que arranca y cada trino cuentan en `Sfx.CONTEO`.
## `AMBIENTE_ACTIVO = false` calla todo al momento. Lo monta la maqueta en todos los mapas, junto a Zonas3D.

static var AMBIENTE_ACTIVO: bool = true
static var T_FUNDIDO_AMBIENTE: float = 2.0                           ## s del fundido cruzado entre dos capas
static var INTERVALO_PAJAROS: Vector2 = Vector2(6.0, 14.0)           ## s entre un trino y el siguiente (al azar entre los dos)
static var TIPO_POR_LUZ: Dictionary = {
	"bosque": "bosque", "clasico": "bosque", "atardecer": "bosque", "ruinas": "bosque", "hielo": "bosque", "agua": "bosque", "fuego": "bosque",
	"cueva": "cueva", "cueva_lava": "cueva", "cueva_goblin": "cueva", "cueva_hielo": "cueva", "cueva_ruinas": "cueva",
	"santuario": "sala"}
static var TIPO_DEFECTO: String = "bosque"                           ## una luz que no está en la tabla
const SONIDO_POR_TIPO: Dictionary = {"bosque": "amb_bosque", "cueva": "amb_cueva", "sala": "amb_sala", "grillos": "amb_grillos"}
const SONIDO_PAJAROS: String = "amb_pajaros"

var tipo_actual: String = ""                  ## el tipo de zona de ahora ("" = aún ninguno)
var pajaros_disparados: int = 0               ## trinos que han sonado (las pruebas)
var _m: Node = null
var _zonas: Node = null
var _capas: Dictionary = {}                   ## clave de SONIDO_POR_TIPO -> {"p": AudioStreamPlayer, "nivel": 0..1, "meta": 0..1}
var _pajaros: AudioStreamPlayer = null
var _t_pajaro: float = 0.0


## Lo cuelga de la maqueta. Devuelve el nodo.
static func montar(maqueta: Node) -> AmbienteZona:
	if maqueta == null:
		return null
	var previo: Node = maqueta.get_node_or_null("AmbienteZona")
	if previo is AmbienteZona:
		return previo as AmbienteZona
	var a := AmbienteZona.new()
	a.name = "AmbienteZona"
	a._m = maqueta
	maqueta.add_child(a)
	return a


## El tipo de zona de una luz de `LuzZona3D.ZONAS`.
static func tipo_de_luz(luz: String) -> String:
	return String(TIPO_POR_LUZ.get(luz, TIPO_DEFECTO))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS       # el libro y los menús pausan el árbol; el viento sigue (y los fundidos con él)
	_zonas = _m.get_node_or_null("Zonas3D") if _m != null else null
	_asegurar_bus()
	_t_pajaro = _sorteo_pajaro()


func _process(delta: float) -> void:
	paso(delta / maxf(Engine.time_scale, 0.01))


## Un paso de `dt` s reales: decide las capas que tocan, mueve los fundidos y dispara los pájaros. Las pruebas lo llaman a mano.
func paso(dt: float) -> void:
	_asegurar_bus()
	tipo_actual = _tipo_ahora()
	var metas: Dictionary = {}
	if AMBIENTE_ACTIVO:
		if tipo_actual == "bosque" and CicloDia3D.es_noche():
			metas["grillos"] = 1.0
		if tipo_actual != "":
			metas[tipo_actual] = 1.0
	_mover_capas(metas, dt)
	_paso_pajaros(dt, AMBIENTE_ACTIVO and tipo_actual == "bosque" and not CicloDia3D.es_noche())


## Las capas que están sonando ahora (nivel > 0), con su nivel lineal (0-1). Las pruebas lo leen.
func capas_sonando() -> Dictionary:
	var r: Dictionary = {}
	for k in _capas:
		var c: Dictionary = _capas[k]
		if float(c["nivel"]) > 0.0:
			r[k] = float(c["nivel"])
	return r


## El reproductor de una capa (null si no existe o aún no ha arrancado).
func reproductor(clave: String) -> AudioStreamPlayer:
	var c: Dictionary = _capas.get(clave, {})
	return c.get("p") as AudioStreamPlayer if not c.is_empty() else null


func _tipo_ahora() -> String:
	var luz: String = ""
	if _zonas != null and is_instance_valid(_zonas) and _zonas.has_method("luz_actual"):
		luz = String(_zonas.call("luz_actual"))
	elif _m != null:
		luz = String(_m.get("zona_luz"))
	return tipo_de_luz(luz)


func _mover_capas(metas: Dictionary, dt: float) -> void:
	var paso_nivel: float = dt / maxf(T_FUNDIDO_AMBIENTE, 0.01)
	for clave in metas:
		if not _capas.has(clave):
			_capas[clave] = {"p": null, "nivel": 0.0, "meta": 1.0}
	for clave in _capas.keys():
		var c: Dictionary = _capas[clave]
		c["meta"] = float(metas.get(clave, 0.0))
		if not AMBIENTE_ACTIVO:
			c["nivel"] = 0.0                                      # silencio al momento
		else:
			c["nivel"] = move_toward(float(c["nivel"]), float(c["meta"]), paso_nivel)
		var nivel: float = float(c["nivel"])
		if nivel > 0.0 and not bool(c.get("arranco", false)):
			c["arranco"] = true                                   # una sola vez por fundido: sin el archivo importado no hay reproductor y no se reintenta cada fotograma
			c["p"] = _arrancar(String(SONIDO_POR_TIPO[clave]))
		var p: AudioStreamPlayer = c["p"] as AudioStreamPlayer
		if p != null and is_instance_valid(p):
			if nivel <= 0.0:
				p.queue_free()
				c["p"] = null
			else:
				p.volume_db = Sfx.db_de(String(SONIDO_POR_TIPO[clave])) + linear_to_db(nivel)
		_capas[clave] = c
		if nivel <= 0.0 and float(c["meta"]) <= 0.0 and c["p"] == null:
			_capas.erase(clave)


func _arrancar(sonido: String) -> AudioStreamPlayer:
	var flujo: AudioStream = Sfx.flujo_en_bucle(sonido)
	Sfx._anotar(sonido, Sfx.db_de(sonido), 1.0)
	if flujo == null:
		return null                                               # sin importar aún: calla, nunca falla
	var p := AudioStreamPlayer.new()
	p.stream = flujo
	p.bus = Sfx3D.BUS_MUNDO
	p.volume_db = -80.0
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	p.play(randf() * maxf(flujo.get_length(), 0.1))
	return p


func _paso_pajaros(dt: float, toca: bool) -> void:
	if not AMBIENTE_ACTIVO and _pajaros != null and is_instance_valid(_pajaros) and _pajaros.playing:
		_pajaros.stop()
	if not toca:
		_t_pajaro = maxf(_t_pajaro, 0.5)                         # no se acumula mientras callan: al amanecer no cantan todos de golpe
		return
	_t_pajaro -= dt
	if _t_pajaro > 0.0:
		return
	_t_pajaro = _sorteo_pajaro()
	pajaros_disparados += 1
	var cfg: Dictionary = Sfx.CATALOGO.get(SONIDO_PAJAROS, {})
	if cfg.is_empty():
		return
	Sfx._anotar(SONIDO_PAJAROS, Sfx.db_de(SONIDO_PAJAROS), 1.0)
	var flujo: AudioStream = load(Sfx.CARPETA + String((cfg["f"] as Array).pick_random())) as AudioStream
	if flujo == null:
		return
	if _pajaros == null or not is_instance_valid(_pajaros):
		_pajaros = AudioStreamPlayer.new()
		_pajaros.name = "Pajaros"
		_pajaros.bus = Sfx3D.BUS_MUNDO
		_pajaros.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_pajaros)
	var v: float = float(cfg.get("tono", 0.0))
	_pajaros.stream = flujo
	_pajaros.volume_db = Sfx.db_de(SONIDO_PAJAROS)
	_pajaros.pitch_scale = 1.0 + randf_range(-v, v)
	_pajaros.play()


func _sorteo_pajaro() -> float:
	return randf_range(minf(INTERVALO_PAJAROS.x, INTERVALO_PAJAROS.y), maxf(INTERVALO_PAJAROS.x, INTERVALO_PAJAROS.y))


func _asegurar_bus() -> void:
	if AudioServer.get_bus_index(Sfx3D.BUS_MUNDO) < 0:
		Sfx3D._asegurar_buses()
