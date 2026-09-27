class_name Sfx
extends RefCounted

## EL SONIDO DEL MUNDO.
##
## Mismo patrón que BlockFx y Glow: funciones estáticas, sin nodo que
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
	"sello_no": {"f": ["sello_no.wav"], "db": -12.0, "tono": 0.03},
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
static func play(origen: Node2D, nombre: String) -> void:
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

	var p := AudioStreamPlayer2D.new()
	p.stream = flujo
	p.volume_db = float(cfg["db"])
	var v: float = float(cfg["tono"])
	p.pitch_scale = 1.0 if v <= 0.0 else randf_range(1.0 - v, 1.0 + v)

	# El grimorio detiene el árbol entero (get_tree().paused). Si el
	# reproductor se pausara con él, abrir el libro cortaría el sonido a
	# media nota y al cerrarlo seguiría donde lo dejó, que suena a error.
	p.process_mode = Node.PROCESS_MODE_ALWAYS

	origen.get_tree().current_scene.add_child(p)
	p.global_position = origen.global_position
	p.finished.connect(p.queue_free)
	p.play()


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
