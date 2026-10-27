class_name Sfx3D
extends RefCounted
## SONIDO EN EL MUNDO 3D (hermano de `Sfx`, que solo sirve para el 2D: usa AudioStreamPlayer2D y un Node2D).
##
## Dos usos, los dos con la misma idea que Sfx —quien suena llama a una línea y no sabe qué archivo hay detrás—:
##   · `Sfx3D.play(self, "goblin_grito")`        un sonido suelto en la posición de `self` (pasos, grito, maullido, voz).
##   · `var p = Sfx3D.ambiente(self, "fuego")`   un bucle colgado de `self` que dura lo que dure la cosa; `Sfx3D.parar(p)` lo apaga
##                                              con un fundido corto (la llama que se apaga no corta en seco).
##
## Por qué existe aparte: Sfx.play pide un Node2D y el mundo 3D no tiene ninguno (el libro de hechizos busca el «jugador» 2D
## por grupo). Aquí el reproductor es un AudioStreamPlayer3D, que atenúa y reparte izquierda/derecha según dónde esté el sonido
## respecto al AudioListener3D (Jugador3D pone uno en los pies del jugador y lo gira como la cámara; sin él, el oyente sería la
## cámara, que está lejos y haría sonar todo bajito).
##
## Los archivos son los de `audio/` (los genera tools/gen_sonidos_ambiente.py; ver audio/LICENCIAS.md). Si un archivo aún no está
## importado (hay que abrir el editor una vez), el sonido simplemente no suena: nunca falla.

const CARPETA: String = "res://audio/"
const VEDA_MS: int = 70                  ## como en Sfx: el mismo sonido del mismo emisor no se repite antes
const UNIDAD: float = 4.0                ## hasta aquí (u) suena a todo volumen; después baja
const ALCANCE: float = 22.0              ## más allá no se oye (u; la casilla mide 2,3)

## nombre -> archivos (se elige uno al azar, sin repetir el anterior), db, variación de tono (±) y `base` de tono.
## Los db están ESTIMADOS (no medidos en el juego): suben o bajan aquí, en un solo sitio.
const CATALOGO: Dictionary = {
	# 27/10: PISADAS GRABADAS (OpenGameArt, CC0, «Different steps on wood, stone, leaves, gravel and mud» de kdd; ver audio/LICENCIAS.md): hojas
	# en la hierba, barro y grava en la tierra, piedra y grava en la roca y madera en los puentes. Pocas tomas por suelo: la variación la pone el
	# tono (±10 %). Volumen bajo a propósito (Pablo: «muy fuerte, un sonido sutil»): se ajusta de oído aquí. Las sintetizadas suaves
	# (paso_suave_*, tools/gen_pasos_suaves.py) siguen en audio/ por si se prefieren.
	"paso_hierba": {"f": ["oga_paso_hojas_0.ogg", "oga_paso_hojas_1.ogg"], "db": -16.0, "tono": 0.10, "unidad": 3.0, "alcance": 10.0},
	"paso_tierra": {"f": ["oga_paso_barro_0.ogg", "oga_paso_grava_0.ogg"], "db": -16.0, "tono": 0.10, "unidad": 3.0, "alcance": 10.0},
	"paso_roca": {"f": ["oga_paso_piedra_0.ogg", "oga_paso_grava_0.ogg"], "db": -16.0, "tono": 0.10, "unidad": 3.0, "alcance": 10.0},
	"paso_madera": {"f": ["oga_paso_madera_0.ogg", "oga_paso_madera_1.ogg", "oga_paso_madera_2.ogg"], "db": -16.0, "tono": 0.08,
		"unidad": 3.0, "alcance": 10.0},
	"goblin_grito": {"f": ["goblin_grito_0.ogg", "goblin_grito_1.ogg", "goblin_grito_2.ogg"],
		"db": -6.0, "tono": 0.10},
	# Al morir: los mismos gritos, más graves y más cortos de oído (tono 0,8) para que no se confunda con el aviso.
	"goblin_muere": {"f": ["goblin_grito_0.ogg", "goblin_grito_1.ogg", "goblin_grito_2.ogg"],
		"db": -5.0, "tono": 0.05, "base": 0.8},
	"gato_maullido": {"f": ["gato_maullido_0.ogg", "gato_maullido_1.ogg"],
		"db": -9.0, "tono": 0.08},
	"conversacion_voz": {"f": ["conversacion_voz_0.ogg", "conversacion_voz_1.ogg", "conversacion_voz_2.ogg"],
		"db": -10.0, "tono": 0.06},
}

## Bucles: nombre -> archivo, db, y las distancias (más cerrado que los sonidos sueltos: son muchos a la vez).
const AMBIENTES: Dictionary = {
	# 27/10: fuego y agua GRABADOS (OpenGameArt, CC0: «Fire Crackling» de AntumDeluge y el «flowing water» de «30 CC0 SFX loops» de rubberduck).
	# Los sintetizados de antes (fuego_loop, agua_loop) siguen en audio/.
	"fuego": {"f": "oga_fuego_crepita_loop.wav", "db": -6.0, "unidad": 2.0, "alcance": 13.0, "alto": 0.5},
	"agua": {"f": "oga_agua_corriendo_loop.ogg", "db": -10.0, "unidad": 3.0, "alcance": 14.0, "alto": 0.3},
	"agua_cae": {"f": "agua_cae_loop.ogg", "db": -6.0, "unidad": 3.0, "alcance": 16.0, "alto": 0.4},   # 15/10 (Pablo): el chorro de la tinaja al caer
	"murmullo": {"f": "conversacion_murmullo_loop.ogg", "db": -10.0, "unidad": 3.0, "alcance": 12.0, "alto": 1.2},
}

static var _flujos: Dictionary = {}       ## archivo -> AudioStream (solo los que cargaron)
static var _ultima: Dictionary = {}       ## "nombre|emisor" -> ms del último disparo
static var _ultimo_var: Dictionary = {}   ## nombre -> índice del último archivo usado


## El audio, cargado una vez. Null si no está (aún sin importar): no se guarda el fallo para reintentarlo.
static func _flujo(archivo: String) -> AudioStream:
	if _flujos.has(archivo):
		return _flujos[archivo]
	var ruta: String = CARPETA + archivo
	if not ResourceLoader.exists(ruta):
		return null
	var s: AudioStream = load(ruta) as AudioStream
	if s != null:
		_flujos[archivo] = s
	return s


## Un sonido suelto en la posición de `origen`. `db_extra` lo sube o baja para este disparo.
static func play(origen: Node3D, nombre: String, db_extra: float = 0.0) -> void:
	if origen == null or not is_instance_valid(origen) or not origen.is_inside_tree() or not CATALOGO.has(nombre):
		return
	var cfg: Dictionary = CATALOGO[nombre]
	var ahora: int = Time.get_ticks_msec()
	var clave: String = "%s|%d" % [nombre, origen.get_instance_id()]
	if ahora - int(_ultima.get(clave, -9999)) < VEDA_MS:
		return
	_ultima[clave] = ahora
	var lista: Array = cfg["f"]
	var i: int = randi() % lista.size()
	if lista.size() > 1 and i == int(_ultimo_var.get(nombre, -1)):
		i = (i + 1 + randi() % (lista.size() - 1)) % lista.size()      # nunca el mismo dos veces seguidas
	_ultimo_var[nombre] = i
	var s: AudioStream = _flujo(String(lista[i]))
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = float(cfg.get("db", -6.0)) + db_extra
	var t: float = float(cfg.get("tono", 0.0))
	p.pitch_scale = float(cfg.get("base", 1.0)) * (1.0 + randf_range(-t, t))
	p.unit_size = float(cfg.get("unidad", UNIDAD))
	p.max_distance = float(cfg.get("alcance", ALCANCE))
	# Cuelga de la raíz y no del emisor: el goblin que muere se libera a los 1,4 s y se llevaría el grito con él.
	origen.get_tree().root.add_child(p)
	p.global_position = origen.global_position + Vector3(0.0, 0.6, 0.0)
	p.finished.connect(p.queue_free)
	p.play()


## El audio de un ambiente (clave de AMBIENTES) con el bucle activado, o null si no está. Es una COPIA: el bucle se activa en ella
## sin tocar el recurso importado (que otros usos, p. ej. un `Sfx`, esperan como one-shot).
static func bucle(nombre: String) -> AudioStream:
	if not AMBIENTES.has(nombre):
		return null
	var base: AudioStream = _flujo(String((AMBIENTES[nombre] as Dictionary)["f"]))
	if base == null:
		return null
	var s: AudioStream = base.duplicate() as AudioStream
	if s is AudioStreamWAV:
		# 27/10: un .wav no tiene `loop` (eso es del .ogg): se activa el bucle hacia delante sobre todo el audio, como `Sfx.bucle`.
		var w: AudioStreamWAV = s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if w.stereo else 1)
	else:
		s.set("loop", true)
	return s


## Un bucle colgado de `origen` (se libera con él). Devuelve el reproductor para `parar`, o null si el sonido no existe.
## Cada bucle arranca en un punto al azar: si no, ocho braseros encendidos a la vez sonarían en fase y se oirían como uno solo.
static func ambiente(origen: Node3D, nombre: String) -> AudioStreamPlayer3D:
	if origen == null or not is_instance_valid(origen) or not AMBIENTES.has(nombre):
		return null
	var cfg: Dictionary = AMBIENTES[nombre]
	var s: AudioStream = bucle(nombre)
	if s == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = float(cfg.get("db", -8.0))
	p.unit_size = float(cfg.get("unidad", UNIDAD))
	p.max_distance = float(cfg.get("alcance", ALCANCE))
	p.position = Vector3(0.0, float(cfg.get("alto", 0.5)), 0.0)
	p.tree_entered.connect(_arrancar.bind(p), CONNECT_ONE_SHOT)
	origen.add_child(p)
	return p


static func _arrancar(p: AudioStreamPlayer3D) -> void:
	if is_instance_valid(p) and p.stream != null:
		p.play.call_deferred(randf() * maxf(p.stream.get_length(), 0.1))


## Apaga un bucle con un fundido de medio segundo y lo libera. Acepta null o un reproductor ya liberado.
static func parar(p: AudioStreamPlayer3D) -> void:
	if p == null or not is_instance_valid(p):
		return
	if not p.is_inside_tree():
		p.queue_free()
		return
	var tw: Tween = p.create_tween()
	tw.tween_property(p, "volume_db", -60.0, 0.5)
	tw.tween_callback(p.queue_free)
