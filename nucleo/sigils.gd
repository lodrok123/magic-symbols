class_name Sigils
extends RefCounted

## QUÉ APORTA CADA SELLO.
##
## Cinco sellos son diez parejas; nueve son treinta y seis parejas y
## ochenta y cuatro tríos. Escribir a mano qué hace cada combinación
## mata el sistema: cada sello nuevo obligaría a decidir qué pasa con
## todos los anteriores.
##
## Por eso aquí NO hay combinaciones. Cada sello declara únicamente lo
## suyo, escribe su aportación en una receta común (SpellRecipe), y es
## la receta terminada la que se interpreta al final. Las combinaciones
## no se programan: SALEN.
##
## Añadir un sello es añadir una línea a esta tabla.

## Los sellos de FORMA dicen dónde, cuánto espacio y cuánto tiempo.
##
##   origin    a qué distancia nace, en píxeles (64 = una casilla)
##   travels   si recorre el camino en vez de quedarse quieto
##   reach     cuántas casillas abarca a lo largo de la dirección
##   spread    si ocupa un ÁREA en vez de un punto
##   lifetime  segundos de más que aguanta en el mundo
##   height    cuántos niveles sube
##   cooldown  segundos que tarda en poder lanzarse otra vez la PÁGINA que lo
##             lleva (con varios sellos manda el mayor, no la suma)
##   blocks    si lo que sale BLOQUEA proyectiles (flechas de arqueros, flechas
##             y rayos del jugador...). Es un dato del glifo: una excepción
##             futura (un elemento que atraviesa barreras) se escribe aquí o en
##             Spell.bloquea_a(), no repartida por el código
const FORM: Dictionary = {
	"flecha": {"travels": true, "reach": 1, "cooldown": 1.0},

	# La barrera no dice dónde: dice QUE OCUPA SITIO. Sola, el corro te
	# rodea a ti; con flecha el área se pone de través y sale un muro;
	# con levitación crece hacia arriba y sale una columna. Tres
	# lecturas del mismo sello, y ninguna está escrita.
	"barrera": {"spread": true, "cooldown": 3.0, "blocks": true},

	# Levitación es lo que faltaba para que no todo fuera disparar.
	# Aporta las dos cosas que van juntas en lo que flota: que SE QUEDA
	# (lifetime) y que está POR ENCIMA (height). De ahí salen el tornado
	# quieto, el chorro que permanece y la columna.
	"levitacion": {"lifetime": 2.0, "height": 1, "cooldown": 2.0},

	# ᛉ Permanencia (19/10): lo que sale se QUEDA un rato más. En la receta antigua es solo `lifetime`; el hechizo nuevo lo lee de GLIFOS.
	"permanencia": {"lifetime": 2.0, "cooldown": 1.5},

	# --- LENGUAJE NUEVO: cada uno es UN parámetro más de la receta ---
	#   rebote     bounces  el proyectil rebota en barreras y en lo que golpea; con
	#                       una barrera, la barrera REFLEJA en vez de absorber
	#   retardo    delay    lo que sale tarda en salir (y se ve una marca en el suelo)
	#   pulso      pulse    el área NACE en ti y se EXPANDE; sola es una onda, con
	#                       barrera es una onda que además bloquea
	#   atraccion  pull     lo que toca es TIRADO (hacia ti si viaja, hacia el centro
	#                       si se queda); con viento es un gancho, con barrera un vórtice
	#   espejo     mirror   lo que viaja o nace lejos sale TAMBIÉN hacia atrás
	"rebote": {"bounces": 2, "cooldown": 1.5},
	"retardo": {"delay": 1.5, "cooldown": 1.0},
	"pulso": {"spread": true, "pulse": true, "cooldown": 2.5},
	"atraccion": {"pull": true, "cooldown": 1.5},
	"espejo": {"mirror": true, "cooldown": 1.5},
	# OJO (21/10): esto es la receta ANTIGUA (SpellRecipe, 2D). En el juego 3D (receta V2) `linea` ya NO es un muro: es el RAYO («haz»); el muro es solo de `barrera`. Ver `aplicar_v2` y `Hechizo.haz`.
	"linea": {"spread": true, "blocks": true, "cooldown": 2.0},
	# Fase 8 (glifos como geometría): en 3D el significado lo pone Receta3D/GeometriaHechizo; aquí solo la recarga.
	"altura": {"cooldown": 2.0}
}

## Los sellos OPERADORES no dicen dónde, sino cuánto: transforman lo que
## haya. Por eso "repetición + pilar" y "repetición + flecha" funcionan
## los dos sin decidir nada — la repetición no sabe qué está repitiendo.
##
## 'amplificar' se llamaba 'rombo', y el nombre era un residuo: describía
## el DIBUJO del sello, no lo que hace. Cuando el trazo dejó de ser un
## rombo, el nombre pasó a mentir. Los demás sellos ya se llamaban por su
## efecto, así que este era el único que obligaba a recordar una forma
## para saber de qué se hablaba.
##
## `power` hace dos cosas de una: multiplica el daño (en SpellRecipe, que
## duplica el RuneData para no potenciar el elemento de por vida) y sube
## la INTENSIDAD del efecto (en RuneData, que cambia de hoja de
## animación). Ninguna de las dos está escrita aquí, y así debe ser: este
## sello solo declara un número.
const OPERATOR: Dictionary = {
	"repeticion": {"copies": 2, "cooldown": 1.5},
	"amplificar": {"power": 2.0, "cooldown": 2.0},
}

## --- CÓMO SE DIBUJA CADA SELLO ---
##
## El glifo con el que el grimorio anota el sello en su sector. Vive aquí
## y no en spellbook.gd por lo mismo que todo lo demás de este archivo:
## añadir un sello sigue siendo añadir UNA línea a una tabla, ahora con
## su dibujo incluido. El libro no sabe qué sellos existen; pinta lo que
## encuentre aquí.
##
## Son siluetas blancas sobre transparente, como los glifos de elemento,
## pero estos NO se tiñen: el color es del elemento, que va en el centro.
## En la corona solo importa qué sello es, así que van todos con la misma
## tinta del libro.
##
## 'pilar' no tiene entrada, y no es un olvido: se retira del repertorio
## (barrera + levitación ya dan la columna, tal como dice el comentario de
## FORM) y no vino icono para él en la lámina. Mientras siga existiendo en
## FORM, el libro lo dibuja con el trazo a mano de siempre.
const GLYPHS: Dictionary = {
	"flecha": preload("res://art/ui/glyphs/flecha.png"),
	"barrera": preload("res://art/ui/glyphs/barrera.png"),
	"levitacion": preload("res://art/ui/glyphs/levitacion.png"),
	"repeticion": preload("res://art/ui/glyphs/repeticion.png"),
	"amplificar": preload("res://art/ui/glyphs/amplificar.png"),
	"rebote": preload("res://art/ui/glyphs/rebote.png"),
	"retardo": preload("res://art/ui/glyphs/retardo.png"),
	"pulso": preload("res://art/ui/glyphs/pulso.png"),
	"atraccion": preload("res://art/ui/glyphs/atraccion.png"),
	"espejo": preload("res://art/ui/glyphs/espejo.png"),
	# Lámina de runas de Pablo (17/10): ᛁ `linea` ya tiene su PNG (art/ui/glyphs/linea.png) pero faltaba aquí, y sin entrada el libro la
	# pintaba con el trazo a mano y la chuleta no la listaba. Los sellos nuevos de la lámina se enchufan igual: un PNG + una línea aquí.
	"linea": preload("res://art/ui/glyphs/linea.png"),
	# 18/10 (diario 156): las dos lecturas de ᛁ que guarda el componente de la página (`Spellcaster._nombre_linea`) usan el MISMO PNG: el libro
	# lo gira al pintar (`EjesRecetaUi.giro_linea`: linea_x 90°, linea_z 0°). `linea` se queda para la chuleta y la paleta (GestureLibrary.SIGILS).
	"linea_x": preload("res://art/ui/glyphs/linea.png"),
	"linea_z": preload("res://art/ui/glyphs/linea.png"),
	# 19/10: ᛉ permanencia (el PNG ya existía en art/ui/glyphs): hace falta aquí para que el panel del laboratorio lo pinte.
	"permanencia": preload("res://art/ui/glyphs/permanencia.png"),
	# 23/10 (Pulso resonante, fase 2): ᚱ raido es el glifo «pulso» nuevo (el PNG ya existía en la lámina).
	"raido": preload("res://art/ui/glyphs/raido.png"),
}

## NOMBRE QUE VE EL JUGADOR (23/10, decisión de Pablo): el id de un glifo es el de sus muestras grabadas (`GestureLibrary`), su PNG y las tablas, y NO se renombra. Lo que se
## muestra (chuleta del libro, paleta, «se parece a…») pasa por aquí: el ᚷ de siempre (id `pulso`, parámetro `crece`) se ve como «crecer», y el ᚱ nuevo (id `raido`, parámetro
## `resuena`) se ve como «pulso». Un id que no esté aquí se muestra tal cual.
const NOMBRE_VISIBLE: Dictionary = {"pulso": "crecer", "raido": "pulso"}


static func nombre_visible(id: String) -> String:
	return String(NOMBRE_VISIBLE.get(id, id))

## --- LA BARRERA QUE AVANZA (barrera + flecha) ---
##
## La flecha NO crea una flecha cuando va con una barrera: le da a la barrera su
## DIRECCIÓN y su AVANCE. Lo que sale es una barrera plana, de frente a la marcha,
## que se desplaza hacia donde apuntas, más despacio que una flecha, y que aplica
## su elemento a cada casilla que cruza. Dura poco: unas 4 casillas de camino.
##   WALL_SPEED     píxeles por segundo (una flecha va a 300)
##   WALL_LIFETIME  segundos que dura; recorre WALL_SPEED x WALL_LIFETIME = ~240 px
const WALL_SPEED: float = 110.0
const WALL_LIFETIME: float = 2.2

## --- APILAR EL MISMO GLIFO ---
##
## Repetir un glifo no crea una forma nueva: sube la INTENSIDAD de lo que ya hace,
## y lo hace por la misma regla para cualquier número, sin escribir "2 flechas" ni
## "3 barreras" en ninguna parte. Cada unidad extra aporta menos que la anterior
## (raíz cuadrada) y hay techos duros, para que el sexto glifo no sea siempre la
## respuesta ni llene la pantalla.
##   barreras  el aro crece de radio y la barrera que avanza se ensancha
##   flechas   el chorro llega más lejos y se queda más rato
##   cada glifo repetido suma STACK_COOLDOWN a la recarga: lo grande no es gratis
const STACK_SIZE_GAIN: float = 0.6      ## cuánto crece el radio del aro por raíz de barreras extra
const MAX_SIZE_FACTOR: float = 3.0      ## techo del radio, en veces el aro normal
const MAX_WALL_HALF: int = 4            ## techo de la anchura: 2 x esto + 1 casillas
const STACK_HOLD_GAIN: float = 0.8      ## segundos de retención por raíz de flechas extra
const MAX_JET_CELLS: int = 8            ## techo del largo del chorro, en casillas
const STACK_COOLDOWN: float = 0.5       ## recarga extra por cada glifo repetido

## Cuánto crece el aro con `n` barreras (1 = normal).
static func size_factor(n: int) -> float:
	return minf(1.0 + STACK_SIZE_GAIN * sqrt(float(maxi(n - 1, 0))), MAX_SIZE_FACTOR)


## Un paso de lo que flota y te sigue: va hacia `objetivo` con suavidad (llega
## con un poco de retraso, como si flotara) y se mece arriba y abajo. Lo usan el
## hechizo y su campo con la MISMA fórmula, para que no se separen.
static func flotar(actual: Vector2, objetivo: Vector2, delta: float) -> Vector2:
	var balanceo := Vector2(0.0, sin(float(Time.get_ticks_msec()) * 0.004) * 3.0)
	return actual.lerp(objetivo, 1.0 - exp(-FOLLOW_RATE * delta)) + balanceo * delta * 6.0


## Casillas a cada lado del centro de la barrera plana (1 = 3 casillas de ancho).
static func wall_half(n: int) -> int:
	return mini(roundi(1.0 + 0.9 * sqrt(float(maxi(n - 1, 0)))), MAX_WALL_HALF)


## Casillas que ocupa el chorro de `n` flechas (con 2 o más).
static func jet_cells(n: int) -> int:
	return mini(roundi(2.0 * sqrt(float(n))), MAX_JET_CELLS)


## Segundos EXTRA que se queda el chorro de `n` flechas.
static func jet_hold(n: int) -> float:
	return STACK_HOLD_GAIN * sqrt(float(maxi(n - 1, 0)))


## --- LA CALIDAD DEL TRAZO ---
##
## Un trazo apenas reconocido hace un hechizo más flojo: dura y llega menos.
## QUALITY_MIN es el factor con el trazo justo en el límite de ser aceptado; un
## trazo limpio da 1.0. El factor multiplica la duración de lo que se queda y el
## alcance del muro y de la flecha.
const QUALITY_MIN: float = 0.6

## Cuántas manifestaciones forman un corro.
const RING_POINTS: int = 6

## Cuánto dura un hechizo quieto normal. Levitación suma sobre esto.
const BASE_LIFETIME: float = 1.5

## Tope duro de manifestaciones por componente.
##
## Hace falta porque los parámetros se MULTIPLICAN entre sí: un corro de
## 6 con dos alturas y dos repeticiones son 6 x 3 x 4 = 72 hechizos de
## un solo trazo. Sin tope, la combinación más creativa sería también la
## que tira los fotogramas, y eso enseña justo lo contrario de lo que
## queremos: a no experimentar.
const PULSE_SPEED: float = 95.0         ## píxeles por segundo a los que se abre una onda
const WAVE_GAP: float = 0.5             ## segundos entre una onda y la siguiente (repetición + pulso)
const FOLLOW_LIFETIME: float = 6.0      ## segundos que te sigue lo que levita solo
const FOLLOW_RATE: float = 7.0          ## lo rápido que te alcanza (más = más pegado)
const MAX_MANIFESTATIONS: int = 48

## Un trazo recto simple sigue valiendo como atajo del sello
## equivalente: dibujas una raya y sale una flecha. El trazo es azúcar;
## el sello es el lenguaje, y solo el sello se puede combinar.
const PATTERN_AS_SIGIL: Dictionary = {
	Runes.Pattern.ARROW: "flecha",
	Runes.Pattern.BARRIER: "barrera",
}


## --- DÓNDE VALE CADA SELLO ---
##
## UNA FLECHA VUELA PLANA. Una bola de fuego no se lanza "hacia arriba",
## y hasta ahora se podía: los ocho sectores del grimorio admitían flecha,
## así que la respuesta a cualquier problema era apuntar y disparar.
##
## Prohibirla en los seis sectores que no son horizontales no es una
## limitación arbitraria: es lo que OBLIGA a que los demás sellos existan.
## Si quieres alcanzar algo que no cae en tu horizontal tienes que pensar
## — levitación para que se quede, barrera para ocupar el paso, pilar para
## que nazca lejos. El sistema ya tenía esas respuestas; lo que faltaba
## era quitar la respuesta fácil.
##
## Se declara como un dato más del sello y no como un `if` en el
## Spellcaster: el día que un sello nuevo solo tenga sentido en vertical,
## es una línea aquí y nada más.
const AXIS: Dictionary = {
	"flecha": "plano",
}

## Cuánto puede inclinarse un sector y seguir contando como horizontal.
##
## Con ocho sectores los valores posibles de `y` son 0, ±0.707 y ±1. Con
## 0.35 pasan exactamente los dos horizontales. ES EL ÚNICO MANDO: subirlo
## a 0.8 admitiría también las cuatro diagonales, por si al jugarlo la
## restricción resulta demasiado dura. Bajarlo no cambia nada.
const FLAT_TOLERANCE: float = 0.35


## De calidad del trazo (0..1) a factor de potencia (QUALITY_MIN..1).
static func quality_factor(quality: float) -> float:
	return lerpf(QUALITY_MIN, 1.0, clampf(quality, 0.0, 1.0))


static func is_known(sigil_name: String) -> bool:
	return FORM.has(sigil_name) or OPERATOR.has(sigil_name) or GLIFOS_V2.has(sigil_name) or ALIAS_V2.has(sigil_name)


## ¿Puede este sello usarse hacia ahí? Lo que no aparece en AXIS vale en
## cualquier sector, que es el caso de casi todos: la restricción es la
## excepción y se declara; lo normal no se declara.
static func allowed_on(sigil_name: String, sector: Vector2) -> bool:
	if AXIS.get(sigil_name, "") != "plano":
		return true
	return absf(sector.y) <= FLAT_TOLERANCE


## =====================================================================================================
##  RECETA V2 (17/10, Pablo; docs/GLIFOS_RECETA.md): volumen por ejes + propiedades aditivas
## =====================================================================================================
##
## Sin glifos, un hechizo es una ESFERA de radio RADIO_BASE_V2 (0,25 m). Cada glifo de EJE agranda un semieje del elipsoide;
## cada glifo de PROPIEDAD suma (o multiplica) UN número, con tope. Esta tabla es lo ÚNICO que sabe qué hace cada glifo: `aplicar_v2`
## no pregunta por ninguno por su nombre, solo recorre la tabla. Añadir un glifo es añadir una línea. FORM / OPERATOR siguen
## sirviendo al camino actual (V2 está detrás de `Receta3D.V2`).
##
##   tipo       "eje" (escribe en x|y|z) o "prop" (escribe en props[param])
##   eje/param  a qué número va
##   inicio     valor con el que arranca (el radio base en los ejes; 1 en las copias y en la solidez; 0 en el resto)
##   por_glifo  cuánto aporta CADA glifo: se SUMA, o se MULTIPLICA si modo == "multiplica"
##   tope       el valor no pasa de aquí (en casillas de SEMIEJE para los ejes)
##   repertorio nombre del glifo en el Repertoire/libro (linea_x y linea_z son dos lecturas del mismo ᛁ)
##   cooldown   recarga de la página, la MISMA que le da hoy `FORM` (V2 no toca la recarga)
const RADIO_BASE_V2: float = 0.25         ## semieje base en metros-casilla (19/10, ESPEC_HECHIZO §1.1: antes 0,15; la esfera base mide 0,5 m de ancho)
const PASO_EJE_V2: float = 0.15           ## m que suma CADA glifo de eje a su semieje (antes sumaba lo mismo que el radio base; ahora son dos números)
const TOPE_EJE_HORIZONTAL_V2: float = 3.0  ## semieje máximo en X y Z (§1.9: 6 m de ancho o fondo total)
const TOPE_EJE_ALTURA_V2: float = 1.0      ## semieje máximo en Y (§1.9: 2 niveles; antes 2,0)
const RADIO_BARRERA_U: float = 1.3        ## u: radio de la circunferencia que rodea al jugador con barrera (= Lanzador3D.RADIO_BURBUJA; la prueba comprueba que coinciden)
const VELOCIDAD_FLECHA_ESCALA_ANTIGUA_U: float = 4.0   ## u/s: la velocidad de la flecha de ayer (decisión de Pablo, 19/10: la misma). En metros sale de dividirla por la casilla: `velocidad_flecha()`
## m/s de una flecha = 4 u/s / casilla (≈ 1,7 con casilla 2,3). Es una función y no una const porque depende de `Terreno3D.casilla`; la tabla `GLIFOS` la pide con «@velocidad_flecha».
static func velocidad_flecha() -> float:
	return VELOCIDAD_FLECHA_ESCALA_ANTIGUA_U / maxf(Terreno3D.casilla, 0.001)


const COSTE_PROP_V2: float = 0.25       ## cada propiedad distinta encarece un 25 %
const PASO_RESUENA_V2: float = 4.0       ## casillas de alcance del pulso que suma cada ᚱ (PLAN_PULSO_RESONANTE §2)
const TOPE_RESUENA_V2: float = 12.0      ## alcance máximo del pulso del jugador = `Pulso3D.ALCANCE_DEFECTO`

## --- MOMENTO DE EJECUCIÓN de las propiedades (23/10, Pulso resonante fase 2; PLAN_PULSO_RESONANTE §10 bis, GLIFOS_RECETA §2.4 bis) ---
## Cada glifo declara CUÁNDO actúa en la vida del hechizo. Es un DATO del glifo (no lo elige el jugador ni depende del orden de dibujo):
##   momento     "inicio" (al nacer el volumen, una vez) · "continuo" (mientras vive, cada `PERIODO_MIN_CONTINUO_S` como mínimo) · "final" (al chocar o acabarse, una vez)
##   momento_si  (opcional) lista de reglas {cuando, es}: la primera cuyo `cuando` se cumple cambia el momento a `es`. `cuando` es uno de `Hechizo.CONDICIONES_MOMENTO`
##               («viaja»: el hechizo es un proyectil; «persistente»: el volumen se queda, o sea barrera, sólido o permanencia). Si ninguna casa, vale `momento`.
##   paso        el paso de GLIFOS_RECETA §2.4 al que pertenece (1 volumen · 2 copias · 3 vida · 4 materia · 5 daño y efectos): ordena los glifos DENTRO de un mismo momento
##   accion      (opcional) lo que el glifo HACE en su momento: una del catálogo cerrado `HechizoVivo.ACCIONES_MOMENTO`. Sin `accion` el glifo no dispara nada en su momento (su efecto ya
##               va dentro del ciclo de vida, como siempre): el `momento` de flecha, barrera, repetición, rebote, crecer y permanencia es la descripción de lo que ya hacen, sin cambiarlo.
## SIN REENTRADAS: un efecto que nace en un momento no vuelve a disparar ese mismo momento del hechizo que lo creó (el pulso «al final» no provoca otro final).
const MOMENTO_INICIO: String = "inicio"
const MOMENTO_CONTINUO: String = "continuo"
const MOMENTO_FINAL: String = "final"
const MOMENTOS: PackedStringArray = ["inicio", "continuo", "final"]
const MOMENTO_DEFECTO: String = "inicio"        ## un glifo sin `momento` (los de eje) actúa al nacer
const PASO_DEFECTO: int = 1
## Periodo MÍNIMO entre dos disparos de un efecto «continuo» (s): un muro que late 8 s con pulso de rayo no puede multiplicar efectos (PLAN §10 bis, «Riesgo»). Mayor que lo que tarda
## en apagarse un pulso (`Pulso3D.T_COLA`) para que dos no se pisen.
const PERIODO_MIN_CONTINUO_S: float = 1.5
## Tope de disparos continuos de un mismo hechizo (aunque viva 25 s).
const MAX_DISPAROS_CONTINUOS: int = 8
## Lo que encarece un efecto continuo (PLAN §2.5: «más propiedades activas = más caro»): se suma a `COSTE_PROP_V2` por cada glifo con `accion` cuyo momento resuelto sea continuo.
const COSTE_CONTINUO_V2: float = 0.25
## RAYO (21/10): con false, ᛁ `linea` vuelve a ser SOLO un eje del volumen (sin haz). Es un interruptor de PRUEBAS y de diseño (las pruebas del volumen genérico —`prueba_materia_v2`, que mide el
## sólido, el líquido, el plasma… sobre elipsoides estirados— lo apagan); el juego lo deja en true.
static var HAZ_ACTIVO: bool = true
const GLIFOS_V2: Dictionary = {
	# Ejes (18/10 Pablo, «A para probar»): los tres empiezan en RADIO_BASE_V2 y cada glifo suma LO MISMO que ese valor (por_glifo = RADIO_BASE_V2). Antes: X +0,5, Z +0,75, Y +0,5.
	# 19/10 (ESPEC_HECHIZO §1.1): base 0,25 y cada glifo suma PASO_EJE_V2 (0,15). Topes: 3,0 de semieje en X y Z (6 m) y 1,0 en Y (2 niveles).
	"linea_x": {"tipo": "eje", "eje": "x", "inicio": RADIO_BASE_V2, "por_glifo": PASO_EJE_V2, "tope": TOPE_EJE_HORIZONTAL_V2, "repertorio": "linea", "cooldown": 2.0},
	"linea_z": {"tipo": "eje", "eje": "z", "inicio": RADIO_BASE_V2, "por_glifo": PASO_EJE_V2, "tope": TOPE_EJE_HORIZONTAL_V2, "repertorio": "linea", "cooldown": 2.0},
	"altura": {"tipo": "eje", "eje": "y", "inicio": RADIO_BASE_V2, "por_glifo": PASO_EJE_V2, "tope": TOPE_EJE_ALTURA_V2, "repertorio": "altura", "cooldown": 2.0},
	# Propiedades.
	"flecha": {"tipo": "prop", "param": "viaja", "inicio": 1.0, "por_glifo": 1.0, "tope": 6.0, "modo": "suma", "repertorio": "flecha", "cooldown": 1.0},
	"barrera": {"tipo": "prop", "param": "solidez", "inicio": 1.0, "por_glifo": 1.5, "tope": 3.0, "modo": "multiplica", "repertorio": "barrera", "cooldown": 3.0},
	"repeticion": {"tipo": "prop", "param": "copias", "inicio": 1.0, "por_glifo": 1.0, "tope": 4.0, "modo": "suma", "repertorio": "repeticion", "cooldown": 1.5},
	"rebote": {"tipo": "prop", "param": "rebotes", "inicio": 0.0, "por_glifo": 1.0, "tope": 3.0, "modo": "suma", "repertorio": "rebote", "cooldown": 1.5},
	"pulso": {"tipo": "prop", "param": "crece", "inicio": 0.0, "por_glifo": 0.5, "tope": 1.5, "modo": "suma", "repertorio": "pulso", "cooldown": 2.5},
	# ᛉ Permanencia (19/10, ESPEC_HECHIZO §3): +2 s por glifo de tiempo que se queda donde nace o donde para. Tope 25 s (el límite global cuenta además la `persiste`).
	"permanencia": {"tipo": "prop", "param": "permanencia", "inicio": 0.0, "por_glifo": 2.0, "tope": 25.0, "modo": "suma", "repertorio": "permanencia", "cooldown": 1.5},
	# ᚱ «pulso» (23/10, Pulso resonante fase 2; PLAN_PULSO_RESONANTE §2): +4 casillas de alcance por glifo, tope 12. El nombre que ve el jugador es «pulso»; el id es el de la runa (raido).
	"raido": {"tipo": "prop", "param": "resuena", "inicio": 0.0, "por_glifo": PASO_RESUENA_V2, "tope": TOPE_RESUENA_V2, "modo": "suma", "repertorio": "raido", "cooldown": 2.0},
}


## =====================================================================================================
##  GLIFOS: la misma tabla, en el idioma de MODIFICADORES de `Hechizo` (HC1, 18/10; docs HECHIZO_CLASE.md §2.1)
## =====================================================================================================
## Cada glifo es una lista de modificadores `{campo, op, valor, tope, desde}` sobre campos de `Hechizo`:
##   campo   nombre de un campo de Hechizo; un componente de un Vector3 se escribe con punto («semiejes.x»)
##   op      "suma" (v + valor·n) · "multiplica" (v · valor^n) · "fija" (v = valor) · "minimo" (v = max(v, valor), después de los topes)
##   valor   número; o un símbolo que depende de la casilla del terreno y por eso no puede ser una constante: «@radio_barrera» = Sigils.radio_barrera_casillas(), «@velocidad_flecha» = Sigils.velocidad_flecha()
##   tope    el campo no pasa de aquí (opcional)
##   salta   (opcional) los k primeros glifos no cuentan: n = max(n − k, 0), y con n = 0 el modificador no se aplica («persiste +1 por cada glifo SUCESIVO»: salta 1)
##   desde   valor de partida si ningún otro glifo ha tocado ya ese campo (opcional; p. ej. la solidez parte de 1 con el primer glifo y vale 0 sin ninguno)
## Más `repertorio` (nombre en el libro) y `cooldown` (recarga de la página), igual que GLIFOS_V2. **Un glifo nuevo es solo datos aquí.**
## GLIFOS_V2 se conserva MIENTRAS lo lean el laboratorio, la UI de ejes (Pipeline) y las pruebas; `prueba_hechizo` comprueba que las dos tablas dicen lo mismo.
const GLIFOS: Dictionary = {
	"linea_x": {"repertorio": "linea", "cooldown": 2.0, "momento": "inicio", "paso": 1, "modificadores": [{"campo": "semiejes.x", "op": "suma", "valor": PASO_EJE_V2, "tope": TOPE_EJE_HORIZONTAL_V2}]},
	"linea_z": {"repertorio": "linea", "cooldown": 2.0, "momento": "inicio", "paso": 1, "modificadores": [{"campo": "semiejes.z", "op": "suma", "valor": PASO_EJE_V2, "tope": TOPE_EJE_HORIZONTAL_V2}]},
	"altura": {"repertorio": "altura", "cooldown": 2.0, "momento": "inicio", "paso": 1, "modificadores": [{"campo": "semiejes.y", "op": "suma", "valor": PASO_EJE_V2, "tope": TOPE_EJE_ALTURA_V2}]},
	# La flecha (18/10, diseño de Pablo): el 1.er glifo la pone en marcha (velocidad 4 u/s) y da 2 casillas de alcance; cada glifo SUCESIVO suma 1 casilla (solo alcance, la velocidad no cambia).
	"flecha": {"repertorio": "flecha", "cooldown": 1.0, "momento": "continuo", "paso": 3, "modificadores": [
		{"campo": "velocidad", "op": "fija", "valor": "@velocidad_flecha"},
		{"campo": "distancia_max", "op": "suma", "valor": 1.0, "tope": 6.0, "desde": 1.0}]},
	# La barrera (18/10): solidez 1 · 1,5^n (tope 3). El 1.er glifo la hace nacer DONDE APUNTAS (en_punto); cada glifo sucesivo suma 1 s de PERMANENCIA (salta 1; antes iba a `persiste`, ESPEC_HECHIZO §0.3). Ya NO hay radio mínimo: el tamaño lo ponen solo los ejes X/Y/Z.
	"barrera": {"repertorio": "barrera", "cooldown": 3.0, "momento": "continuo", "paso": 4, "modificadores": [
		{"campo": "solidez", "op": "multiplica", "valor": 1.5, "tope": 3.0, "desde": 1.0},
		{"campo": "en_punto", "op": "fija", "valor": true},
		{"campo": "permanencia", "op": "suma", "valor": 1.0, "salta": 1}]},
	"repeticion": {"repertorio": "repeticion", "cooldown": 1.5, "momento": "inicio", "paso": 2, "modificadores": [{"campo": "copias", "op": "suma", "valor": 1.0, "tope": 4.0, "desde": 1.0}]},
	"rebote": {"repertorio": "rebote", "cooldown": 1.5, "momento": "final", "paso": 3, "modificadores": [{"campo": "rebotes", "op": "suma", "valor": 1.0, "tope": 3.0}]},
	# ᚷ «crecer» (hasta el 23/10 se llamaba «pulso»; el id, el parámetro `crece` y el efecto no cambian: ver NOMBRE_VISIBLE). Crece mientras vive.
	"pulso": {"repertorio": "pulso", "cooldown": 2.5, "momento": "continuo", "paso": 3, "modificadores": [{"campo": "crece", "op": "suma", "valor": 0.5, "tope": 1.5}]},
	# ᛉ Permanencia (19/10, ESPEC_HECHIZO §3): lo que hace que un hechizo SE QUEDE (defensas, piezas de puzle). +2 s por glifo; `Hechizo._limitar` recorta persiste + permanencia a 25 s.
	"permanencia": {"repertorio": "permanencia", "cooldown": 1.5, "momento": "final", "paso": 3, "modificadores": [{"campo": "permanencia", "op": "suma", "valor": 2.0, "tope": 25.0}]},
	# ᚱ «pulso» (23/10, Pulso resonante fase 2; PLAN_PULSO_RESONANTE §2 y §10 bis): el volumen suelta un `Pulso3D` de `resuena` casillas con el elemento de la receta.
	# Cuándo: al FINAL si el hechizo viaja (flecha + pulso = pulso donde choca, sin caso especial); CONTINUO si el volumen se queda (barrera, sólido, permanencia); al INICIO en el resto.
	"raido": {"repertorio": "raido", "cooldown": 2.0, "momento": "inicio", "paso": 5, "accion": "emitir_pulso",
		"momento_si": [{"cuando": "viaja", "es": "final"}, {"cuando": "persistente", "es": "continuo"}],
		"modificadores": [{"campo": "resuena", "op": "suma", "valor": PASO_RESUENA_V2, "tope": TOPE_RESUENA_V2}]},
}


## Cuántas veces se dibujó cada glifo (`contadores`: nombre -> n; los que falten valen 0) -> el volumen y las propiedades:
##   {x, y, z: semiejes del elipsoide en casillas, props: {param: valor}} (x_glifos / z_glifos ya no se escriben: la barrera dejó de tener radio mínimo, 18/10)
## `props` SOLO lleva las propiedades de glifos usados (sin glifos, está vacío), así `props.size()` es el nº de propiedades.
## Solo suma o multiplica con topes; el orden en que se dibujó cada glifo no existe (es un multiconjunto). Un nombre que no esté en la
## tabla se ignora.
static func aplicar_v2(contadores: Dictionary) -> Dictionary:
	var salida: Dictionary = {"x": RADIO_BASE_V2, "y": RADIO_BASE_V2, "z": RADIO_BASE_V2, "props": {}}
	var destinos: Dictionary = {"eje": salida, "prop": salida["props"]}
	for nombre in GLIFOS_V2:
		var n: int = maxi(int(contadores.get(nombre, 0)), 0)
		if n == 0:
			continue
		var d: Dictionary = GLIFOS_V2[nombre]
		var destino: Dictionary = destinos[d["tipo"]]
		var clave: String = String(d.get("eje", d.get("param", "")))
		var v: float = float(destino.get(clave, d["inicio"]))
		# multiplica: v × por_glifo^n · suma: v + por_glifo × n (un glifo repetido n veces vale n veces su aporte)
		v = v * pow(float(d["por_glifo"]), float(n)) if d.get("modo", "suma") == "multiplica" else v + float(d["por_glifo"]) * float(n)
		destino[clave] = minf(v, float(d["tope"]))
	# RAYO (21/10, Pablo): ᛁ `linea` + elemento = un haz recto; el MURO es solo de `barrera`. Hay haz si se dibujó alguna ᛁ y no hay barrera (solidez) ni flecha (viaja).
	# Es un dato derivado de la receta (como el nombre de la forma): `GeometriaV2.nombre_derivado` y `Hechizo.haz` lo leen igual.
	var props_salida: Dictionary = salida["props"]
	salida["haz"] = HAZ_ACTIVO and maxi(int(contadores.get("linea_x", 0)), 0) + maxi(int(contadores.get("linea_z", 0)), 0) > 0 and not props_salida.has("solidez") and not props_salida.has("viaja")
	return salida


## El radio de la circunferencia de la barrera (RADIO_BARRERA_U, en u) expresado en casillas de semieje.
static func radio_barrera_casillas() -> float:
	return RADIO_BARRERA_U / maxf(Terreno3D.casilla, 0.001)


## Glifos del libro que en la receta V2 valen lo mismo que otro (R3, 17/10): ᛏ (`levitacion`) ya no da permanencia ni altura aparte, es SOLO `altura`.
const ALIAS_V2: Dictionary = {"levitacion": "altura"}


## El nombre con el que cuenta un glifo en la receta V2 (resuelve ALIAS_V2; lo que no tenga alias se devuelve igual).
static func glifo_v2(sigil_name: String) -> String:
	return String(ALIAS_V2.get(sigil_name, sigil_name))


## Volumen del elipsoide en casillas cúbicas. Lo usa el coste y `Lanzador3D.GeometriaV2.volumen`.
static func volumen_v2(g: Dictionary) -> float:
	return 4.0 / 3.0 * PI * float(g["x"]) * float(g["y"]) * float(g["z"])


## Coste en tinta (solo el número, relativo: la esfera base sin propiedades vale 1): crece con el volumen y con el nº de
## propiedades distintas, ∝ volumen × (1 + COSTE_PROP_V2 × nº). La RECARGA no cambia: sigue siendo la de `cooldown_v2`.
static func coste_v2(g: Dictionary, props: Dictionary) -> float:
	var base: float = volumen_v2({"x": RADIO_BASE_V2, "y": RADIO_BASE_V2, "z": RADIO_BASE_V2})
	# Con barrera el volumen sube al de la circunferencia del jugador, pero eso NO encarece el hechizo: se cuenta lo que dieron los glifos.
	var gc: Dictionary = {"x": g.get("x_glifos", g["x"]), "y": g["y"], "z": g.get("z_glifos", g["z"])}
	return volumen_v2(gc) / base * (1.0 + COSTE_PROP_V2 * float(props.size())) * recargo_continuo(props)


## Recargo de tinta por tener un efecto CONTINUO (PLAN_PULSO_RESONANTE §10 bis y GLIFOS_RECETA §2.5): ×(1 + COSTE_CONTINUO_V2) si la receta lleva ᚱ (`resuena`) y su volumen se queda
## sin viajar (barrera o permanencia). Se decide SOLO con las propiedades de la receta (es lo único que ve el coste en tinta, que no sabe el elemento); el momento de ejecución
## real (`Hechizo.momento_de`) además cuenta como «se queda» a un elemento sólido: ahí el pulso también late, pero sin recargo (pendiente anotado en GLIFOS_RECETA).
static func recargo_continuo(props: Dictionary) -> float:
	var continuo: bool = props.has("resuena") and not props.has("viaja") and (props.has("solidez") or props.has("permanencia"))
	return 1.0 + (COSTE_CONTINUO_V2 if continuo else 0.0)


## Recarga de una página V2: la mayor de sus glifos (+ STACK_COOLDOWN por glifo repetido), igual que hace hoy SpellRecipe.apply.
static func cooldown_v2(contadores: Dictionary) -> float:
	var c: float = 0.0
	for nombre in GLIFOS_V2:
		var n: int = maxi(int(contadores.get(nombre, 0)), 0)
		if n > 0:
			c = maxf(c, float(GLIFOS_V2[nombre]["cooldown"]) + STACK_COOLDOWN * float(n - 1))
	return c


## Nombre del glifo en el Repertoire/libro: linea_x y linea_z son el mismo ᛁ (`linea`). Lo que no esté en GLIFOS_V2 se devuelve igual.
static func repertorio_de(sigil_name: String) -> String:
	return String(GLIFOS_V2[sigil_name]["repertorio"]) if GLIFOS_V2.has(sigil_name) else sigil_name


## Orientación de la raya sola (ᛁ) respecto a la PÁGINA: más horizontal que vertical -> "linea_x"; más vertical -> "linea_z".
## La diagonal exacta cuenta como X (docs/GLIFOS_RECETA.md §2.1). Las ocho direcciones del rectificador salen con un error de
## coma flotante (cos 45° y sin 45° no son idénticos), por eso la comparación lleva un margen del 0,1 %.
static func orientacion_linea(a: Vector2, b: Vector2) -> String:
	var d: Vector2 = b - a
	return "linea_x" if absf(d.x) >= absf(d.y) * 0.999 else "linea_z"
