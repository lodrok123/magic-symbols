class_name Sfx
extends RefCounted

## EL SONIDO DEL MUNDO.
##
## Funciones estáticas (como `Sonidos`): sin nodo que
## colocar en ninguna escena y sin autoload que configurar. Quien quiera
## sonar llama `Sfx.play(self, "chispa")` y ya.
##
## --- DE DÓNDE SALE CADA SONIDO ---
##
## Hay dos orígenes y el reparto NO es por comodidad, es por lo que sabe
## hacer cada método:
##
##   SINTETIZADOS (tools/gen_sfx.py, .wav) — todo lo elemental. No existe
##   una grabación de "hielo cristalizando" ni de "el tiempo yendo hacia
##   atrás", así que da igual buscarla: hay que inventarla. Y sale
##   ganando, porque el crepitar del fuego y el del árbol ardiendo salen
##   del mismo generador y suenan a la misma familia.
##
##   GRABADOS (Kenney, CC0, .ogg) — el foley. Un paso, una puerta de
##   madera, un libro que se abre. Aquí la síntesis pierde siempre: el
##   oído conoce esos sonidos de memoria y detecta el fraude al instante.
##   Diez pisadas reales distintas valen más que cualquier algoritmo.
##
## Cambiar de bando es copiar un archivo y tocar una línea de CATALOGO.

const CARPETA: String = "res://audio/"

## nombre lógico -> archivos, volumen en dB y cuánto varía el tono.
##
## LOS ARCHIVOS SON SIEMPRE UNA LISTA, aunque haya uno solo. Cuando hay
## varios se elige al azar, y eso importa muchísimo en lo que se repite:
## seis pisadas grabadas distintas no se oyen como "un sonido de pisada",
## se oyen como alguien andando. El oído detecta la repetición exacta
## antes que el propio sonido.
##
## LA VARIACIÓN DE TONO hace el mismo trabajo cuando no hay variantes que
## dar. Un ±10% aleatorio basta para que el trazo de tiza deje de sonar a
## ametralladora; los que suenan una vez por nivel (la pira) no la
## necesitan y llevan 0.
##
## Los .wav salen ya igualados en RMS por gen_sfx.py y los .ogg de Kenney
## vienen razonablemente parejos, así que estos decibelios NO están
## arreglando archivos: dicen la INTENCIÓN. El paso y el trazo van bajos
## porque suenan cien veces por nivel; la pira va alta porque suena una y
## es el final.
const CATALOGO: Dictionary = {
	# --- Elementos (sintetizados). Los busca for_element por etiqueta.
	"fuego":   {"f": ["elem_fuego.wav"],   "db": -8.0,  "tono": 0.10},
	"agua":    {"f": ["elem_agua.wav"],    "db": -7.0,  "tono": 0.10},
	"hielo":   {"f": ["elem_hielo.wav"],   "db": -9.0,  "tono": 0.08},
	"rayo":    {"f": ["elem_rayo.wav"],    "db": -6.0,  "tono": 0.07},
	"viento":  {"f": ["elem_viento.wav"],  "db": -11.0, "tono": 0.12},
	"tierra":  {"f": ["elem_tierra.wav"],  "db": -8.0,  "tono": 0.10},
	"tiempo":  {"f": ["elem_tiempo.wav"],  "db": -10.0, "tono": 0.05},

	# --- Magia del mundo (sintetizados).
	"prender":  {"f": ["prender.wav"],  "db": -9.0,  "tono": 0.12},
	"congelar": {"f": ["congelar.wav"], "db": -10.0, "tono": 0.08},
	"chispa":   {"f": ["chispa.wav"],   "db": -12.0, "tono": 0.14},
	"derrumbe": {"f": ["derrumbe.wav"], "db": -7.0,  "tono": 0.10},
	"rodar":    {"f": ["rodar.wav"],    "db": -8.0,  "tono": 0.08},
	"arco":     {"f": ["arco.wav"],     "db": -9.0,  "tono": 0.08},
	"pira":     {"f": ["pira.wav"],     "db": -3.0,  "tono": 0.0},
	"dano":     {"f": ["dano.wav"],     "db": -7.0,  "tono": 0.10},
	"muerte":   {"f": ["muerte.wav"],   "db": -4.0,  "tono": 0.0},

	# --- Foley (Kenney, CC0).
	"paso": {"f": ["paso_0.ogg", "paso_1.ogg", "paso_2.ogg",
			"paso_3.ogg", "paso_4.ogg", "paso_5.ogg"],
		"db": -14.0, "tono": 0.08},
	"puerta_abre":   {"f": ["puerta_abre_0.ogg", "puerta_abre_1.ogg"],
		"db": -5.0, "tono": 0.05},
	"puerta_cierra": {"f": ["puerta_cierra_0.ogg", "puerta_cierra_1.ogg"],
		"db": -6.0, "tono": 0.05},
	"libro_abre":    {"f": ["libro_abre.ogg"],   "db": -7.0, "tono": 0.04},
	"libro_cierra":  {"f": ["libro_cierra.ogg"], "db": -7.0, "tono": 0.04},
	"pagina":        {"f": ["pagina_0.ogg", "pagina_1.ogg", "pagina_2.ogg"],
		"db": -10.0, "tono": 0.06},
	"clavar":        {"f": ["clavar.ogg"], "db": -10.0, "tono": 0.12},
	"creak":         {"f": ["creak.ogg"],  "db": -11.0, "tono": 0.08},

	# --- Grimorio (sintetizados a propósito).
	#
	# El trazo es tiza: no hay grabación de tiza en los packs, y el
	# ruido filtrado la clava. Y los dos avisos son MÚSICA, no foley —
	# dos notas que suben y una que baja— porque tienen que leerse como
	# "sí" y "no" sin que nadie lo explique.
	"trazo":    {"f": ["trazo.wav"],    "db": -16.0, "tono": 0.18},
	"sello_ok": {"f": ["sello_ok.wav"], "db": -11.0, "tono": 0.03},
	"pulso_resonante": {"f": ["pulso_resonante.wav"], "db": -10.0, "tono": 0.02},      # 26/10: sonido propio del pulso (audio/gen_sfx_pulso.py); lo usan Pulso3D y todo lo que responde
	"sello_no": {"f": ["sello_no.wav"], "db": -12.0, "tono": 0.03},

	# --- Piezas de puzle (16/10, Pipeline; audio/gen_sfx_puzles.py). Las llama PiezaPuzle3D al cambiar de estado; el Juego puede llamarlas
	# también con Sfx.play(nodo, "nombre"). «llenado» se toca con `Sfx.llenado(nodo, nivel)` para que el tono suba con el agua.
	"boton_clic":        {"f": ["boton_clic.wav"],        "db": -8.0,  "tono": 0.05},
	"placa_hunde":       {"f": ["placa_hunde.wav"],       "db": -7.0,  "tono": 0.06},
	"compuerta_baja":    {"f": ["compuerta_baja.wav"],    "db": -7.0,  "tono": 0.05},
	"hielo_quiebra":     {"f": ["hielo_quiebra.wav"],     "db": -9.0,  "tono": 0.08},
	"mecha":             {"f": ["mecha.wav"],             "db": -11.0, "tono": 0.04},
	"explosion":         {"f": ["explosion.wav"],         "db": -3.0,  "tono": 0.06},
	"rueda_chirria":     {"f": ["rueda_chirria.wav"],     "db": -13.0, "tono": 0.1},
	"zumbido_electrico": {"f": ["zumbido_electrico.wav"], "db": -12.0, "tono": 0.03},
	"llenado":           {"f": ["llenado.wav"],           "db": -10.0, "tono": 0.0},

	# --- Fases del conjuro V2 (18/10, Pipeline; audio/gen_sfx_hechizos.py, diario 160/162). Las llama Lanzador3D._sonar_fase_v2: «<elemento>_carga» al
	# empezar el conjuro, y «<nombre derivado>_impacto» (x_mano · alto · abajo) al materializarse el volumen. «<elemento>_disparo» no lleva sonido
	# propio: sigue siendo el elem_* de arriba. Primera versión sintetizada: SE AFINA ESCUCHANDO (estos dB y el tono son un punto de partida).
	"fuego_carga":  {"f": ["fuego_carga.wav"],  "db": -9.0,  "tono": 0.04},
	# Bucle MIENTRAS se carga/apunta (20/10, Pablo): se pide con `Sfx.bucle`, no con `play`. Lo genera audio/gen_sfx_hechizos.py::fuego_carga_bucle.
	"fuego_carga_bucle": {"f": ["fuego_carga_bucle.wav"], "db": -14.0, "tono": 0.0},
	"agua_carga":   {"f": ["agua_carga.wav"],   "db": -9.0,  "tono": 0.04},
	"hielo_carga":  {"f": ["hielo_carga.wav"],  "db": -11.0, "tono": 0.03},
	"rayo_carga":   {"f": ["rayo_carga.wav"],   "db": -9.0,  "tono": 0.04},
	"viento_carga": {"f": ["viento_carga.wav"], "db": -12.0, "tono": 0.05},
	"tierra_carga": {"f": ["tierra_carga.wav"], "db": -8.0,  "tono": 0.04},
	"tiempo_carga": {"f": ["tiempo_carga.wav"], "db": -11.0, "tono": 0.02},
	"x_mano_impacto": {"f": ["x_mano_impacto.wav"], "db": -6.0, "tono": 0.06},
	"alto_impacto":   {"f": ["alto_impacto.wav"],   "db": -6.0, "tono": 0.06},
	"abajo_impacto":  {"f": ["abajo_impacto.wav"],  "db": -5.0, "tono": 0.06},

	# --- Reacciones del mundo (21/10, Pipeline; audio/gen_sfx_reacciones.py; PL2 de PLAN_EOW). Los elige `ReaccionesVfx3D` por el nombre de la reacción
	# (`Mundo3D.reaccion`); el Juego no los llama. «arde_bucle» se pide con `Sfx.bucle` (suena mientras algo arde). Primera versión sintetizada: SE AFINA ESCUCHANDO.
	"siseo_apagado":    {"f": ["siseo_apagado.wav"],    "db": -9.0,  "tono": 0.08},
	"chapoteo":         {"f": ["chapoteo.wav"],         "db": -8.0,  "tono": 0.10},
	"hundido_burbujas": {"f": ["hundido_burbujas.wav"], "db": -8.0,  "tono": 0.05},
	"arde_bucle":       {"f": ["arde_bucle.wav"],       "db": -15.0, "tono": 0.0},
	"escudo_golpe":     {"f": ["escudo_golpe.wav"],     "db": -8.0,  "tono": 0.10},
	"escudo_roto":      {"f": ["escudo_roto.wav"],      "db": -6.0,  "tono": 0.06},
	"aturdido":         {"f": ["aturdido.wav"],         "db": -11.0, "tono": 0.05},
	"empujado":         {"f": ["empujado.wav"],         "db": -11.0, "tono": 0.10},
	"secado":           {"f": ["secado.wav"],           "db": -13.0, "tono": 0.08},
	"derretido":        {"f": ["derretido.wav"],        "db": -11.0, "tono": 0.08},

	# --- Respuesta positiva al jugador (21/10, Juego; audio/gen_sfx_logros.py; PLAN_EOW_VISUAL §4). Los elige `Logros3D.TABLA` por el nombre del logro
	# (`Mundo3D.logro`). Campanas sintetizadas, tono casi fijo (son música: un do-mi-sol desafinado al azar suena a error). SE AFINA ESCUCHANDO.
	"logro_pista":     {"f": ["logro_pista.wav"],     "db": -14.0, "tono": 0.01},
	"logro_acierto":   {"f": ["logro_acierto.wav"],   "db": -9.0,  "tono": 0.01},
	"logro_brillo":    {"f": ["logro_brillo.wav"],    "db": -12.0, "tono": 0.01},
	"logro_fanfarria": {"f": ["logro_fanfarria.wav"], "db": -7.0,  "tono": 0.0},
}

## Etiqueta del elemento -> sonido. Se mira en ESTE orden, y el orden
## importa: el hielo lleva "frio" y el fuego "calor", pero un hechizo
## futuro podría llevar las dos y hay que decidir cuál manda.
const POR_ETIQUETA: Array = [
	["rayo", "rayo"], ["hielo", "hielo"], ["fuego", "fuego"],
	["agua", "agua"], ["viento", "viento"], ["tierra", "tierra"],
	["tiempo", "tiempo"],
]

## EL ANTIRRÁFAGA, y hace más falta de lo que parece.
##
## Un hechizo con corro y altura son hasta 24 manifestaciones que nacen
## EN EL MISMO FOTOGRAMA. Sin esto son 24 copias del mismo sonido a la
## vez: no suena 24 veces más fuerte, suena a distorsión, porque ondas
## idénticas se suman en fase y saturan la salida.
##
## Con 70 ms de veda por sonido, un hechizo de 24 puntos suena una vez —
## que además es lo correcto: el jugador lanzó UN hechizo.
const VEDA_MS: int = 70

static var _ultima: Dictionary = {}


## Suena EN EL SITIO donde pasa la cosa, no en el centro de la pantalla.
## Un AudioStreamPlayer2D se atenúa y se reparte según dónde esté, así
## que la pira del otro lado del canal se oye lejos y a la derecha.
##
## Los reproductores cuelgan de la ESCENA y no del emisor, igual que las
## partículas y las luces: muchos de los sonidos que más importan ocurren
## justo cuando el objeto DESAPARECE —una roca que se desmorona, una
## flecha que se clava— y un hijo se va con su padre.
## `tono` > 0 fija el pitch_scale (16/10: el llenado sube con el nivel); 0 = el aleatorio de siempre. Quien llama sin él no nota nada.
static func play(origen: Node, nombre: String, tono: float = 0.0) -> void:
	if not CATALOGO.has(nombre) or origen == null or not origen.is_inside_tree():
		return

	var ahora: int = Time.get_ticks_msec()
	if ahora - int(_ultima.get(nombre, -9999)) < VEDA_MS:
		return
	_ultima[nombre] = ahora

	var cfg: Dictionary = CATALOGO[nombre]
	var archivos: Array = cfg["f"]
	var flujo: AudioStream = load(CARPETA + String(archivos.pick_random()))
	if flujo == null:
		return

	# M4: el origen puede ser un nodo 3D (Lanzador3D, Grimorio) o uno 2D (el libro, el 2D que aún queda). 3D → reproductor 3D.
	var p: Node = AudioStreamPlayer3D.new() if origen is Node3D else AudioStreamPlayer2D.new()
	p.set("stream", flujo)
	p.set("volume_db", float(cfg["db"]))
	var v: float = float(cfg["tono"])
	p.set("pitch_scale", 1.0 if v <= 0.0 else randf_range(1.0 - v, 1.0 + v))
	if tono > 0.0:
		p.set("pitch_scale", tono)

	# El grimorio detiene el árbol entero (get_tree().paused). Si el
	# reproductor se pausara con él, abrir el libro cortaría el sonido a
	# media nota y al cerrarlo seguiría donde lo dejó, que suena a error.
	p.process_mode = Node.PROCESS_MODE_ALWAYS

	# Sin ventana (escenarios de prueba) `current_scene` es null: se cuelga de la raíz.
	var padre: Node = origen.get_tree().current_scene
	if padre == null:
		padre = origen.get_tree().root
	padre.add_child(p)
	p.set("global_position", origen.get("global_position"))
	p.connect("finished", p.queue_free)
	p.call("play")


## Sonido en BUCLE que dura mientras alguien lo mantenga (la carga de un hechizo: suena mientras se apunta y se corta al disparar). Devuelve el reproductor
## para que quien lo pide le cambie el tono (`pitch_scale`) o el volumen con el tiempo y lo pare con `Sfx.parar`; null si no hay sonido o no hay árbol.
## Va a la raíz de la escena, como `play`, y NO se pausa con el grimorio por lo mismo. Un `AudioStreamWAV` importado trae el bucle apagado: se duplica
## el recurso (el original lo comparten todos) y se activa el bucle hacia delante sobre todo el audio.
static func bucle(origen: Node, nombre: String, tono: float = 1.0) -> Node:
	if not CATALOGO.has(nombre) or origen == null or not origen.is_inside_tree():
		return null
	var cfg: Dictionary = CATALOGO[nombre]
	var flujo: AudioStream = load(CARPETA + String((cfg["f"] as Array)[0]))
	if flujo == null:
		return null
	if flujo is AudioStreamWAV:
		var w: AudioStreamWAV = (flujo as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		var muestras: int = w.data.size() / (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if w.stereo else 1)
		w.loop_end = muestras
		flujo = w
	var p: Node = AudioStreamPlayer3D.new() if origen is Node3D else AudioStreamPlayer2D.new()
	p.set("stream", flujo)
	p.set("volume_db", float(cfg["db"]))
	p.set("pitch_scale", tono)
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	var padre: Node = origen.get_tree().current_scene
	if padre == null:
		padre = origen.get_tree().root
	padre.add_child(p)
	p.set("global_position", origen.get("global_position"))
	p.call("play")
	return p


## Corta un bucle de `Sfx.bucle` con un fundido (`fundido` s; 0 = de golpe) y libera el reproductor. Admite null y reproductores ya liberados.
static func parar(p: Node, fundido: float = 0.12) -> void:
	if p == null or not is_instance_valid(p):
		return
	if fundido <= 0.0 or not p.is_inside_tree():
		p.queue_free()
		return
	if p.has_meta("tween_bucle"):                       # el tono/volumen que subía quien lo pidió: se cancela, o pelearía con el fundido
		var viejo: Variant = p.get_meta("tween_bucle")
		if viejo is Tween and (viejo as Tween).is_valid():
			(viejo as Tween).kill()
	var tw: Tween = p.create_tween()
	tw.tween_property(p, "volume_db", -60.0, fundido)
	tw.tween_callback(p.queue_free)


## El llenado de un pozo o una cuenca: `nivel` 0..1 (profundidad / profundidad máxima) sube el tono de 0,7 a 1,6, como cuando se llena
## un vaso. El antirráfaga (VEDA_MS) lo deja sonar a lo sumo cada 70 ms: llamarlo cada 0,3 s con el nivel actual va bien.
static func llenado(origen: Node, nivel: float) -> void:
	play(origen, "llenado", lerpf(0.7, 1.6, clampf(nivel, 0.0, 1.0)))


## El sonido que le toca a un elemento. Lo decide la ETIQUETA y no el
## nombre, por lo mismo de siempre: un elemento nuevo que lleve "calor"
## sonará a fuego sin que haya que tocar nada.
static func for_element(origen: Node2D, rune_data: RuneData) -> void:
	if rune_data == null:
		return
	for pareja in POR_ETIQUETA:
		if rune_data.tags.has(pareja[0]):
			play(origen, pareja[1])
			return
