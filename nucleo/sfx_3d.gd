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
	# 10/11: «f_sn» = voces de criatura del lote GDC 2026 de Sonniss (subidas de tono al cocerlas: de orco a goblin). Solo suenan si los archivos están en esta máquina (`Sfx.archivos_de`).
	"goblin_grito": {"f": ["goblin_grito_0.ogg", "goblin_grito_1.ogg", "goblin_grito_2.ogg"], "f_sn": ["sn_goblin_grito_0.ogg", "sn_goblin_grito_1.ogg", "sn_goblin_grito_2.ogg"],
		"db": -6.0, "tono": 0.10},
	# Al morir: los mismos gritos, más graves y más cortos de oído (tono 0,8) para que no se confunda con el aviso.
	"goblin_muere": {"f": ["goblin_grito_0.ogg", "goblin_grito_1.ogg", "goblin_grito_2.ogg"], "f_sn": ["sn_goblin_muere_0.ogg"],
		"db": -5.0, "tono": 0.05, "base": 0.8},
	# 29/10 (gamefeel lote 4, audio/gen_sfx_sensacion.py): el CUERPO que encaja un hechizo (`Combate3D.snd_golpe`: carne, piedra del gólem, chapoteo del limo) y el limo
	# que revienta. Aquí y no en Sfx porque son del enemigo: con distancia y veda por emisor (tres goblins golpeados a la vez suenan tres veces).
	# 2/11 (tarea R): «f» grabado (Kenney Impact, CC0), «f_sint» lo sintetizado de antes (suena con Sfx.GRABADOS = false).
	"golpe_carne":  {"f": ["kenney_golpe_carne_0.ogg", "kenney_golpe_carne_1.ogg", "kenney_golpe_carne_2.ogg"], "f_sn": ["sn_golpe_carne_0.ogg", "sn_golpe_carne_1.ogg", "sn_golpe_carne_2.ogg", "sn_golpe_carne_3.ogg"], "f_sint": ["golpe_carne_0.wav", "golpe_carne_1.wav"], "db": -9.0, "tono": 0.12},
	"golpe_piedra": {"f": ["kenney_golpe_piedra_0.ogg", "kenney_golpe_piedra_1.ogg", "kenney_golpe_piedra_2.ogg"], "f_sint": ["golpe_piedra.wav"], "db": -8.0, "tono": 0.08},
	# Pasos de los enemigos (tarea R): el gólem pesa (concreto, tono ×0,6, fuerte); el goblin es ligero (hierba y madera, tono ×1,2). Los dispara el propio enemigo al andar (`PasosEnemigo3D`).
	"paso_golem":   {"f": ["kenney_paso_golem_0.ogg", "kenney_paso_golem_1.ogg", "kenney_paso_golem_2.ogg", "kenney_paso_golem_3.ogg"], "db": -4.0, "tono": 0.06, "base": 0.6, "unidad": 4.0, "alcance": 16.0},
	"paso_goblin":  {"f": ["kenney_paso_goblin_0.ogg", "kenney_paso_goblin_1.ogg", "kenney_paso_goblin_2.ogg", "kenney_paso_goblin_3.ogg"], "db": -14.0, "tono": 0.08, "base": 1.2, "unidad": 3.0, "alcance": 11.0},
	"limo_golpe":   {"f": ["limo_golpe.wav"], "f_sn": ["sn_limo_golpe_0.ogg"], "db": -9.0, "tono": 0.12},
	"limo_muere":   {"f": ["limo_muere.wav"], "f_sn": ["sn_limo_muere_0.ogg"], "db": -7.0, "tono": 0.06},
	"gato_maullido": {"f": ["oga_gato_maullido_0.wav", "oga_gato_maullido_1.wav", "oga_gato_maullido_2.ogg"], "f_sint": ["gato_maullido_0.ogg", "gato_maullido_1.ogg"],
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
	# 28/10: el arrastre del bloque de piedra al empujarlo (BloqueEmpujable3D): no hay un arrastre grabado, así que el «rodar» sintetizado en bucle, bajo.
	# 2/11 (tarea R): el ronroneo del gato quieto cerca de la jugadora (OpenGameArt «cat purr meow», CC0).
	"gato_ronroneo": {"f": "oga_gato_ronroneo_loop.wav", "db": -14.0, "unidad": 2.0, "alcance": 8.0, "alto": 0.3},
	"arrastre": {"f": "rodar.wav", "db": -17.0, "unidad": 2.0, "alcance": 10.0, "alto": 0.2},
}

## OCLUSIÓN (1/11, tarea O): todo AudioStreamPlayer3D de Sfx3D va al bus «Mundo» (0 dB) si hay línea de vista con el oyente, o al bus «Ocluido»
## (−6 dB y filtro paso bajo) si un sólido del nivel se interpone. Los buses viven en default_bus_layout.tres; si faltan (pruebas sin el layout) se crean.
const BUS_MUNDO: String = "Mundo"
const BUS_OCLUIDO: String = "Ocluido"
static var OCLUSION_ACTIVA: bool = true
static var CORTE_OCLUSION: float = 900.0           ## Hz del filtro paso bajo del bus «Ocluido»
static var T_REEVALUAR_OCLUSION: float = 0.25      ## s entre comprobaciones de un bucle (cambia de bus en caliente, sin cortar)
static var VOLUMEN_BUS_MUNDO: float = 0.0
static var VOLUMEN_BUS_OCLUIDO: float = -6.0
static var ALTO_OIDO: float = 0.6                  ## u sobre el suelo del oyente desde donde sale el rayo

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
## `tono_mult` (29/10) multiplica el tono (1 = el del catálogo): un golpe a la debilidad suena más grave.
static func play(origen: Node3D, nombre: String, db_extra: float = 0.0, tono_mult: float = 1.0) -> void:
	if origen == null or not is_instance_valid(origen) or not origen.is_inside_tree() or not CATALOGO.has(nombre):
		return
	var cfg: Dictionary = CATALOGO[nombre]
	var ahora: int = Time.get_ticks_msec()
	var clave: String = "%s|%d" % [nombre, origen.get_instance_id()]
	if ahora - int(_ultima.get(clave, -9999)) < VEDA_MS:
		return
	_ultima[clave] = ahora
	var lista: Array = Sfx.archivos_de(cfg)
	var i: int = randi() % lista.size()
	if lista.size() > 1 and i == int(_ultimo_var.get(nombre, -1)):
		i = (i + 1 + randi() % (lista.size() - 1)) % lista.size()      # nunca el mismo dos veces seguidas
	_ultimo_var[nombre] = i
	var s: AudioStream = _flujo(String(lista[i]))
	if s == null:
		return
	Sfx._anotar(nombre, float(Sfx.AJUSTES.get(nombre, cfg.get("db", -6.0))) + db_extra, 0.0)      # para las pruebas (solo cuenta con Sfx.REGISTRAR)
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = float(Sfx.AJUSTES.get(nombre, cfg.get("db", -6.0))) + db_extra      # S1: el ajuste en vivo (Sfx.AJUSTES) manda sobre el catálogo
	var t: float = float(cfg.get("tono", 0.0))
	p.pitch_scale = float(cfg.get("base", 1.0)) * (1.0 + randf_range(-t, t)) * tono_mult
	p.unit_size = float(cfg.get("unidad", UNIDAD))
	p.max_distance = float(cfg.get("alcance", ALCANCE))
	# Cuelga de la raíz y no del emisor: el goblin que muere se libera a los 1,4 s y se llevaría el grito con él.
	origen.get_tree().root.add_child(p)
	p.global_position = origen.global_position + Vector3(0.0, 0.6, 0.0)
	p.bus = bus_para(p)
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
	p.volume_db = float(Sfx.AJUSTES.get(nombre, cfg.get("db", -8.0)))
	p.unit_size = float(cfg.get("unidad", UNIDAD))
	p.max_distance = float(cfg.get("alcance", ALCANCE))
	p.position = Vector3(0.0, float(cfg.get("alto", 0.5)), 0.0)
	p.tree_entered.connect(_arrancar.bind(p), CONNECT_ONE_SHOT)
	origen.add_child(p)
	return p


static func _arrancar(p: AudioStreamPlayer3D) -> void:
	if is_instance_valid(p) and p.stream != null:
		p.bus = bus_para(p)
		var t := Timer.new()                       # reevalúa la oclusión mientras dure el bucle (el temporizador muere con él)
		t.wait_time = maxf(T_REEVALUAR_OCLUSION, 0.05)
		t.timeout.connect(_reevaluar.bind(p))
		p.add_child(t)
		t.start()
		p.play.call_deferred(randf() * maxf(p.stream.get_length(), 0.1))


static func _reevaluar(p: AudioStreamPlayer3D) -> void:
	if not is_instance_valid(p) or not p.is_inside_tree():
		return
	var b: String = bus_para(p)
	if String(p.bus) != b:
		p.bus = b                                  # cambio en caliente: no reinicia ni corta el bucle
	for h in p.get_children():
		if h is Timer:
			(h as Timer).wait_time = maxf(T_REEVALUAR_OCLUSION, 0.05)


## El bus (nombre) que le toca a un reproductor ya dentro del árbol: «Mundo» con línea de vista, «Ocluido» si un sólido (capa Terreno3D.CAPA_SOLIDO, la de
## la colisión del nivel contra la que choca la jugadora) se interpone entre el oyente y él. Con OCLUSION_ACTIVA = false, siempre «Mundo».
static func bus_para(p: Node3D) -> StringName:
	_asegurar_buses()
	if not OCLUSION_ACTIVA or p == null or not p.is_inside_tree():
		return BUS_MUNDO
	var oyente: Variant = _pos_oyente(p)
	if oyente == null:
		return BUS_MUNDO
	var mundo: World3D = p.get_world_3d()
	if mundo == null:
		return BUS_MUNDO
	var q := PhysicsRayQueryParameters3D.create(oyente as Vector3, p.global_position, Terreno3D.CAPA_SOLIDO)
	q.collide_with_areas = false
	return BUS_OCLUIDO if not mundo.direct_space_state.intersect_ray(q).is_empty() else BUS_MUNDO


## Dónde está el oído (AudioListener3D activo, y si no, la cámara) con un poco de altura sobre los pies; null si no hay ninguno.
static func _pos_oyente(p: Node3D) -> Variant:
	var vp: Viewport = p.get_viewport()
	if vp == null:
		return null
	var o: Node3D = null
	if vp.has_method("get_audio_listener_3d"):
		o = vp.call("get_audio_listener_3d") as Node3D
	if o == null:
		o = vp.get_camera_3d()
	if o == null:
		return null
	return o.global_position + Vector3(0.0, ALTO_OIDO, 0.0)


## Crea «Mundo» y «Ocluido» (a Master) si el layout no los trae, y deja el corte del filtro de «Ocluido» en CORTE_OCLUSION.
static func _asegurar_buses() -> void:
	for par in [[BUS_MUNDO, VOLUMEN_BUS_MUNDO], [BUS_OCLUIDO, VOLUMEN_BUS_OCLUIDO]]:
		if AudioServer.get_bus_index(par[0]) >= 0:
			continue
		AudioServer.add_bus()
		var n: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(n, par[0])
		AudioServer.set_bus_send(n, "Master")
		AudioServer.set_bus_volume_db(n, par[1])
		if par[0] == BUS_OCLUIDO:
			var f := AudioEffectLowPassFilter.new()
			AudioServer.add_bus_effect(n, f)
	var i: int = AudioServer.get_bus_index(BUS_OCLUIDO)
	if i >= 0 and AudioServer.get_bus_effect_count(i) > 0:
		var ef: AudioEffect = AudioServer.get_bus_effect(i, 0)
		if ef is AudioEffectLowPassFilter and not is_equal_approx((ef as AudioEffectLowPassFilter).cutoff_hz, CORTE_OCLUSION):
			(ef as AudioEffectLowPassFilter).cutoff_hz = CORTE_OCLUSION


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
