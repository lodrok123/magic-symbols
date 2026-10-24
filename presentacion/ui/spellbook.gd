extends Control

## EL GRIMORIO.
##
## Hasta ahora dibujabas encima del juego mientras los enemigos se
## movían: incómodo y poco legible. Ahora el dibujo vive en un libro que
## se abre con TAB y detiene el tiempo mientras esté abierto.
##
## Este nodo es solo la CARA del sistema: captura el trazo y lo pinta.
## Quién reconoce ese trazo y qué hechizo sale de él sigue siendo cosa
## del Spellcaster. Si mañana cambias el reconocimiento de gestos, este
## archivo no se entera.

## Se abre con T y no con TAB a propósito: TAB es la tecla que Godot usa
## por defecto para saltar de un control de interfaz al siguiente, así
## que siempre habría riesgo de que las dos cosas se pisaran.
const OPEN_KEY: Key = KEY_T

const RADIUS: float = 250.0        ## círculo que contiene el hechizo
const CORE_RADIUS: float = 120.0   ## núcleo central: el elemento

## --- Sectores ---
## La corona entre el núcleo y el borde se reparte en 8 porciones:
## arriba, abajo, izquierda, derecha y las cuatro diagonales. El sector
## donde dibujas un trazo recto es la dirección hacia la que saldrá ese
## proyectil, así que cuatro trazos en cuatro sectores son cuatro bolas
## a la vez.
##
## Esto libera al trazo de tener que indicar la dirección con su propia
## forma, que era lo que antes obligaba a gastar los gestos de "arriba"
## y "abajo" en el pilar y la barrera.
const SECTORS: int = 8
const GLYPH_RADIUS: float = 185.0  ## dónde se dibuja la flecha de cada sector

## --- LA TINTA ---
##
## ERA CREMA Y AHORA ES OSCURA, y ese cambio lo arrastra todo lo demás
## de este archivo. La crema se eligió cuando el grimorio era un aro
## flotando sobre un velo negro; al meter la lámina de papel debajo, la
## misma crema desapareció contra el pergamino. En un libro claro se
## escribe con tinta oscura, y punto.
const INK: Color = Color(0.24, 0.19, 0.16)
const INK_SOFT: Color = Color(0.24, 0.19, 0.16, 0.30)
const INK_FAINT: Color = Color(0.24, 0.19, 0.16, 0.14)

## Lo que dibuja el jugador va en AZUL, que es la tinta con la que están
## escritos los glifos de la lámina. Así el trazo recién hecho se lee
## como parte del libro y no como una capa de interfaz por encima.
const STROKE_INK: Color = Color(0.15, 0.25, 0.60)

## El velo ya casi no se ve —la lámina cubre la pantalla entera— pero se
## queda: si alguien juega en una ventana más ancha, es lo que evita que
## asome el juego congelado por los lados.
const VEIL: Color = Color(0.04, 0.03, 0.05, 0.72)
const RECORD_INK: Color = Color(0.78, 0.28, 0.10)

## --- Piezas de interfaz ---
## El grimorio ya no se dibuja solo con arcos: el aro, el núcleo y las
## ranuras de sector son sprites del pack de UI. Se siguen pintando con
## draw_texture_rect y no con nodos Sprite2D porque así el tamaño se
## deriva de RADIUS y CORE_RADIUS — cambias una constante y todo el
## libro se reescala solo, sin tocar la escena.
## LAS CUATRO TEXTURAS DE ANTES YA NO SE CARGAN.
##
## ring.png, slot_core.png, slot.png y slot_empty.png siguen en
## art/ui/ pero no se usan: eran discos azul grisáceo y aros de madera
## dibujados para flotar sobre un velo negro, y sobre el pergamino se
## leían como botones pegados encima del libro. Todo eso pasa a estar
## trazado a tinta unas líneas más abajo, que es lo que hace que el
## grimorio parezca escrito EN el libro y no montado sobre él.
##
## No se borran del proyecto porque son el juego completo de piezas por
## si el libro vuelve a abrirse sobre fondo oscuro.

## --- EL LIBRO ---
##
## Hasta ahora el grimorio era un aro flotando sobre un velo negro. Ahora
## hay un libro de verdad debajo, y eso cambia quién manda en la
## colocación: ya no se centra nada en la pantalla, se coloca todo SOBRE
## LA LÁMINA. El círculo de dibujo va encima del círculo que ya viene
## impreso en la página izquierda, y los glifos conocidos van dentro de
## las casillas que ya vienen impresas en la derecha.
##
## Por eso las medidas de abajo están en PÍXELES DE LA LÁMINA y no de
## pantalla: son dónde está cada cosa en el dibujo, que es un dato del
## dibujo y no de la ventana. Una lámina nueva se ajusta cambiando estos
## números y nada más.
const BOOK_TEXTURE: Texture2D = preload("res://art/ui/grimorio.png")
const BOOK_SIZE: Vector2 = Vector2(1470.0, 1070.0)

## --- LÁMINAS ALTERNATIVAS (una por progresión) ---
##
## Cada una dice dónde está CADA COSA en su dibujo, en píxeles de lámina, igual que las constantes de arriba. Se activa con
## `Repertoire.libro`. Si el PNG no está en el proyecto se usa la lámina de siempre: añadir el arte es opcional y no puede romper.
##
## `huecos` = dónde está el círculo de cada sector que se puede usar (clave = índice de sector, 0 = derecha, sentido horario en
## pantalla; 5 = arriba-izquierda, 6 = arriba, 7 = arriba-derecha). Un trazo hecho en otro sector se lleva al hueco más cercano
## en ángulo: así no hay zonas muertas donde dibujar no hace nada.
## `leyenda` = el centro de cada óvalo de la página derecha, en el orden en que se rellenan.
## `nucleo` = radio del círculo del sello, en unidades de diseño (como CORE_RADIUS, que se multiplica por _ui()).
## `guias` = false porque el arte ya trae impresos el aro, el núcleo y los huecos: el código no los repinta.
##
## Claves de la lámina «bosque» (16/10, Pablo; medidas en docs/ARTE.md §16), todas opcionales y sin efecto en las demás:
## `nucleo_desp` = cuánto se desplaza el SELLO respecto al centro del círculo exterior, en px de lámina (+y = abajo). El sello no está
##   en el centro (≈ 99 px más arriba), y los sectores se miden desde el círculo exterior, no desde el sello.
## `orden_huecos` = en qué orden se abren los huecos de glifo y, con eso, cuáles admiten trazo: se abren los N primeros, N = glifos por
##   página (`Repertoire.max_sigils_per_page`). Un hueco cerrado ni se ve ni admite trazo. Sin esta clave, todos están abiertos.
## `hueco_sprite` / `hueco_sprite_radio` / `hueco_radios` = el aro suelto que se pinta en cada hueco ABIERTO (140 × 140 px, radio 58,1),
##   escalado por `hueco_radios[sector] / hueco_sprite_radio`. El arte no trae los aros impresos: aparecen al desbloquear.
## `leyenda_sellos` = dónde va cada ELEMENTO en la página derecha (6 círculos) y `leyenda` = dónde va cada GLIFO (rejilla 3 × 3). Si hay
##   `leyenda_sellos`, elementos y glifos se cuentan por separado; `sello_tam` y `glifo_tam` son su tamaño en px de lámina.
## `bloque` = el bloque de páginas que se encuadra (en px de lámina); sin él vale PAGE_BLOCK.
const LIBROS: Dictionary = {
	"nivel1": {
		"textura": "res://art/ui/grimorio_nivel1.png",
		"centro": Vector2(450.1, 444.4),
		"radio": 254.1,
		"nucleo": 105.0,
		"huecos": {5: Vector2(260.8, 288.4), 6: Vector2(456.0, 194.3), 7: Vector2(649.0, 288.4)},
		"hueco_radio": 62.0,
		"leyenda": [Vector2(879.0, 263.0), Vector2(1039.0, 264.0), Vector2(1204.0, 264.0)],
		"guias": false,
	},
	# Lámina `grimorio_bosque.png` (1470 × 1070, 16/10). Centros y radios MEDIDOS por Pipeline sobre la imagen (ARTE §16, diario 112).
	# Desde el 16/10 la usan TODAS las progresiones (`PROGRESIONES.libro` = «bosque»): el libro antiguo era un placeholder (decisión de Pablo).
	"bosque": {
		"textura": "res://art/ui/grimorio_bosque.png",
		"centro": Vector2(431.9, 482.4),
		"radio": 232.8,
		"nucleo": 119.6 * RADIUS / 232.8,           # radio del sello (119,6 px de lámina) en unidades de diseño
		"nucleo_desp": Vector2(433.7 - 431.9, 383.1 - 482.4),
		# Sectores por ángulo desde el círculo exterior: 1 ≈ 37°, 2 = 90° (abajo), 3 ≈ 143°. Abren abajo → abajo-izquierda → abajo-derecha.
		"huecos": {2: Vector2(431.4, 628.1), 3: Vector2(305.4, 578.7), 1: Vector2(557.3, 578.7)},
		"orden_huecos": [2, 3, 1],
		"hueco_radios": {2: 59.8, 3: 58.1, 1: 58.1},
		"hueco_sprite": "res://art/ui/grimorio_hueco_glifo.png",
		"hueco_sprite_radio": 58.1,
		"leyenda_sellos": [Vector2(838.3, 276.8), Vector2(913.8, 276.8), Vector2(989.9, 276.8), Vector2(1065.9, 276.8),
				Vector2(1141.4, 276.8), Vector2(1216.9, 276.8)],
		"sello_tam": 46.0,                           # el círculo mide 60,4 de diámetro: el glifo respira dentro
		"leyenda": [Vector2(871.4, 415.6), Vector2(1028.8, 415.6), Vector2(1184.9, 415.6),
				Vector2(871.4, 551.4), Vector2(1028.8, 551.4), Vector2(1184.9, 551.4),
				Vector2(871.4, 683.8), Vector2(1028.8, 683.8), Vector2(1184.9, 683.8)],
		"glifo_tam": 54.0,                           # el óvalo mide 140,5 × 101,0
		"bloque": Rect2(107.0, 86.0, 1240.0, 760.0), # las dos páginas (papel x 107–1347) con la cenefa (y ≈ 90–840)
		"guias": false,
	},
}

## Marca de «este trazo no cae en ningún hueco abierto»: se descarta (no es un elemento, que es lo que daría Vector2.ZERO).
const SIN_HUECO: Vector2 = Vector2(9999.0, 9999.0)

var _libro_cache: String = "?"
var _libro_datos: Dictionary = {}
var _libro_tex: Texture2D = null
var _hueco_tex: Texture2D = null


## Los datos de la lámina alternativa activa, o {} si toca la de siempre (también si falta el PNG).
func _libro() -> Dictionary:
	if _libro_cache != Repertoire.libro:
		_libro_cache = Repertoire.libro
		_libro_datos = {}
		_libro_tex = null
		_hueco_tex = null
		if LIBROS.has(_libro_cache):
			var d: Dictionary = LIBROS[_libro_cache]
			if ResourceLoader.exists(String(d["textura"])):
				_libro_tex = load(String(d["textura"])) as Texture2D
				if _libro_tex != null:
					_libro_datos = d
					var sp: String = String(d.get("hueco_sprite", ""))
					if sp != "" and ResourceLoader.exists(sp):
						_hueco_tex = load(sp) as Texture2D
	return _libro_datos


func _circ_c() -> Vector2:
	var d: Dictionary = _libro()
	return d["centro"] if not d.is_empty() else CIRCLE_CENTRE


func _circ_r() -> float:
	var d: Dictionary = _libro()
	return float(d["radio"]) if not d.is_empty() else CIRCLE_RADIUS


## Centro del SELLO (núcleo) en px de lámina: el del círculo exterior más `nucleo_desp` (0 en las láminas de siempre).
func _core_c() -> Vector2:
	return _circ_c() + (_libro().get("nucleo_desp", Vector2.ZERO) as Vector2)


## Los huecos de glifo que admiten trazo ahora: sector -> posición en la lámina. Sin `orden_huecos` están todos; con él, los N primeros
## (N = glifos por página, `Repertoire.max_sigils_per_page`). Un hueco cerrado no se ve y no atrae trazos.
func _huecos_abiertos() -> Dictionary:
	var todos: Dictionary = _libro().get("huecos", {})
	var orden: Array = _libro().get("orden_huecos", [])
	if orden.is_empty():
		return todos
	var abiertos: Dictionary = {}
	for i in range(mini(maxi(Repertoire.max_sigils_per_page, 0), orden.size())):
		var k: int = int(orden[i])
		if todos.has(k):
			abiertos[k] = todos[k]
	return abiertos


## ¿La lámina limita en qué huecos se puede poner un glifo? (sí si tiene `orden_huecos`). Lo pregunta la paleta de pruebas (F1).
func restringe_huecos() -> bool:
	return not (_libro().get("orden_huecos", []) as Array).is_empty()


## Las direcciones (vectores unitarios, como las del Spellcaster) de los huecos de glifo abiertos, en el orden en que se abrieron.
func sectores_abiertos() -> Array:
	var l: Array = []
	var abiertos: Dictionary = _huecos_abiertos()
	for k in (_libro().get("orden_huecos", []) as Array):
		if abiertos.has(int(k)):
			var ang: float = float(int(k)) * TAU / float(SECTORS)
			l.append(Vector2.RIGHT if int(k) == 0 else Vector2(cos(ang), sin(ang)))
	return l


## El bloque de páginas que se encuadra: el de la lámina si lo dice, y si no PAGE_BLOCK.
func _page_block() -> Rect2:
	var d: Dictionary = _libro()
	return (d.get("bloque", PAGE_BLOCK) as Rect2) if not d.is_empty() else PAGE_BLOCK


## De px de lámina a px de pantalla para una MEDIDA suelta (no un punto: eso es `_on_page`).
func _lam(px: float) -> float:
	return px * (_book_rect().size.x / BOOK_SIZE.x)


## Radio del núcleo en unidades de diseño.
func _core_u() -> float:
	var d: Dictionary = _libro()
	return float(d["nucleo"]) if not d.is_empty() else CORE_RADIUS


## Índice de sector (0..7) de una dirección unitaria.
func _sector_idx(dir: Vector2) -> int:
	return posmod(int(round(dir.angle() / (TAU / float(SECTORS)))), SECTORS)

## El bloque de las dos páginas dentro de la lámina. Es LO QUE SE
## ENCUADRA: la tapa de cuero y las cintas de abajo son adorno y se salen
## de la pantalla sin que importe. Encuadrar por el libro entero dejaría
## las páginas —que es donde se juega— pequeñas y con marco.
const PAGE_BLOCK: Rect2 = Rect2(107.0, 84.0, 1277.0, 750.0)

## El círculo impreso en la página izquierda, medido sobre la lámina por
## mínimos cuadrados y no a ojo.
##
## Hay DOS anillos punteados, a 235 y a 272, y se usa el de dentro. El de
## fuera dejaba el círculo tan pegado al borde de la página que las
## pestañas de arriba y la ayuda de abajo caían encima de la cenefa. Con
## el interior, el anillo exterior se queda de marco —que es para lo que
## está dibujado— y arriba y abajo hay sitio para lo que no es el círculo.
const CIRCLE_CENTRE: Vector2 = Vector2(438.0, 427.0)
const CIRCLE_RADIUS: float = 235.0

## La rejilla de casillas de la página derecha: cuatro columnas por tres
## filas, doce huecos. Que sean doce no es casualidad — son los mismos
## doce de la lámina de glifos.
## El origen y el paso están MEDIDOS buscando cada óvalo impreso, no
## puestos a ojo: la página está dibujada en perspectiva y una rejilla
## calculada desde la esquina se iba quedando unos 5 px alta en todas las
## filas. Poco, pero lo justo para que los glifos no se apoyaran en su
## casilla.
const GRID_ORIGIN: Vector2 = Vector2(894.0, 277.0)
const GRID_STEP: Vector2 = Vector2(117.0, 141.0)
const GRID_COLS: int = 4
const GRID_GLYPH: float = 58.0
const GRID_LABEL_DROP: float = 40.0

var is_open: bool = false
var spellcaster: Node = null

## --- Modo de grabación (herramienta de desarrollo) ---
## Se activa con G dentro del libro. Mientras está activo, dibujar NO
## compone un hechizo: guarda ese trazo como muestra del gesto
## seleccionado con las teclas 1..9.
##
## Vive dentro del propio libro a propósito: así grabas las plantillas
## exactamente en las mismas condiciones en que luego se dibujan —mismo
## tamaño de círculo, mismo ratón, mismo pulso—. Una herramienta aparte
## grabaría gestos que no se parecen a los de la partida real.
const RECORD_KEY: Key = KEY_G

var is_recording: bool = false
var record_index: int = 0
var delete_armed: bool = false
var library: GestureLibrary = GestureLibrary.get_shared()

var stroke: PackedVector2Array = PackedVector2Array()
var is_drawing: bool = false

## Los trazos del gesto que se está dibujando ahora mismo, y el tiempo
## que queda para darlo por cerrado. Ver _process().
##
## 0.65 y no 0.45. Con 0.45 había 450 ms para soltar el ratón, mover la
## mano y empezar el segundo trazo, y en la práctica no llegaba: en los
## registros de partida aparecían rachas de 'pilar' fallando seguido y
## acertando luego a la primera, que es la firma de un gesto partido en
## dos —cada mitad es una raya suelta, y media ⊥ no se parece a nada.
##
## Lo que se paga es un cuarto de segundo más de espera al cerrar cada
## gesto. Sale barato porque el tiempo está detenido mientras el libro
## está abierto: la espera molesta, pero no cuesta nada dentro del juego.
const GESTURE_PAUSE: float = 0.75

var pending_strokes: Array = []
var gesture_countdown: float = 0.0

## Misma distancia mínima entre puntos que usaba el Spellcaster: evita
## guardar cientos de puntos casi pegados cuando mueves el ratón despacio.
const MIN_POINT_DISTANCE: float = 8.0

## --- ASISTENCIA AL TRAZO (Fase 14.4, 16/10) ---
## Mientras dibujas, `asistente` (GestureAssist) adivina qué runa quiere ser el trazo cada ASIST_PERIODO s: pinta su guía fantasma,
## tira del trazo hacia ella (solo lo que se VE) y, al soltar, puede dar por buena la runa aunque falte el final. Lo que se reconoce
## sigue siendo el trazo REAL (`stroke` / `pending_strokes`); el imantado vive aparte en `stroke_visible` / `pending_visible`.
## La opción es `Estado.i().asistencia` (0–1; 0 = exactamente como antes: no se calcula nada).
const ASIST_PERIODO: float = 0.08
const T_REDIBUJADO: float = 0.2          ## al aceptar, el trazo se redibuja limpio con la plantilla en este tiempo
const GUIA_COLOR: Color = Color(0.15, 0.25, 0.60, 0.38)

var asistente: GestureAssist = GestureAssist.new()
var stroke_visible: PackedVector2Array = PackedVector2Array()   ## el trazo en curso, ya imantado (lo que se pinta)
var pending_visible: Array = []                                  ## los trazos cerrados del gesto, imantados
var _asist_reloj: float = 0.0
var _asist_sucio: bool = false
var _t_gesto_ini: int = 0                ## ms del primer trazo del gesto (para PlayLog)
var _t_gesto_fin: int = 0
var _limpio_t: float = -1.0              ## < 0 = sin animación de redibujado
var _limpio_desde: Array = []
var _limpio_hasta: Array = []

## --- TRAZO RECTO (Fase 14.4, 16/10; Pablo: «el trazo es muy lento… que solo tome en cuenta las direcciones») ---
## Con `Estado.i().trazo_recto`, lo que el ratón dibuja (`stroke_crudo`) se rectifica en vivo a tramos rectos en las ocho direcciones del
## compás (GestureRectify) y ESO es `stroke`: lo que se ve, lo que se reconoce y lo que se graba. Así las runas pueden ser líneas rectas
## sin que un ángulo a medias o un temblor las estropee. La asistencia sigue encima (guía fantasma y aceptación anticipada), pero el imán
## sobra: la rectificación ya es el imán. Y al soltar, si ningún gesto activo de la familia necesita más trazos de los ya dibujados
## (GestureLibrary.trazos), el gesto se cierra al momento en vez de esperar GESTURE_PAUSE: es lo que quita la lentitud.
var stroke_crudo: PackedVector2Array = PackedVector2Array()   ## el trazo tal cual lo dibuja el ratón (PlayLog y pluma)
## Con el trazo recto, el reconocedor exige este múltiplo del margen de siempre (0,30 → 0,45): «la horquilla más estrecha» que
## pidió Pablo. Valor a ojo hasta medirlo con las runas regrabadas (prueba_asistencia).
const EXIGENCIA_RECTO: float = 1.0           ## 17/10 (playtest de Pablo): con 1,5 rechazaba levitaciones y repeticiones bien hechas («se parece a: levitacion»); 1 hasta medir con prueba_asistencia

## --- LA MANO QUE ESCRIBE (Fase 14.4 · 4.2, 16/10; contrato en el diario 116 del Pipeline) ---
## Con la mano se ve QUIÉN escribe: la tinta deja de aparecer sola. Es solo cara: no reconoce nada; el reconocimiento sigue usando el trazo REAL
## (`stroke`). Con los GLB de `arte/meshy/escritura/` es `ManoPluma3D`; sin ellos, la de láminas 2D (o nada, si faltan también los PNG: `punta()` sigue
## funcionando). La pluma tiene un retardo de 60 ms respecto al punto que se le da, así que la tinta del trazo EN CURSO se recorta hasta la punta
## de verdad (`_tinta_hasta_punta`): si no, la línea iría por delante del plumín.
var mano: ManoPluma2D = null
const MANO_Z: int = 100                 ## por encima de los trazos y del resto del libro
const MANO_ESCALA_2D: float = 0.55      ## tamaño de diseño de la mano 2D (PNG de 560 px) a 1470 de ancho de libro
const TINTA_MIRA_ATRAS: int = 14        ## puntos del final del trazo entre los que se busca la punta (el retardo son ~60 ms: unos pocos puntos)


func _ready() -> void:
	visible = false
	mano = ManoPluma3D.new() if ManoPluma3D.disponible() else ManoPluma2D.new()
	mano.name = "ManoPluma"
	mano.z_index = MANO_Z
	mano.visible_al_inicio = false          # con el libro cerrado no se ve (ni se renderiza el viewport de la 3D)
	add_child(mano)


## Se busca al Spellcaster cuando hace falta, no en _ready(): así da
## igual en qué orden se inicialicen los nodos de la escena.
func _spellcaster() -> Node:
	if not is_instance_valid(spellcaster):
		spellcaster = get_tree().get_first_node_in_group("spellcaster")
	return spellcaster


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == OPEN_KEY:
		_toggle()
		# Marcar el evento como atendido evita que llegue a nadie más.
		get_viewport().set_input_as_handled()
		return

	# CON EL LIBRO CERRADO, 1/2/3 LANZAN. Es la mitad que faltaba: el
	# libro prepara con el tiempo parado y estas tres teclas ejecutan sin
	# pararlo. Viven aquí y no en el jugador porque el libro ya es el
	# dueño de todo lo que tiene que ver con hechizos, y repartirlo entre
	# dos nodos obligaría a mantener dos sitios de acuerdo.
	if not is_open:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			var caster := _spellcaster()
			if caster:
				caster.cast_page(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == RECORD_KEY:
			is_recording = not is_recording
			print("Modo grabación: ", "ON" if is_recording else "OFF")
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

		# Fuera de grabación, Retroceso VACÍA LA PÁGINA. Hacía falta:
		# desde que las páginas no se borran al lanzarlas, el clic derecho
		# quita un sello cada vez y rehacer una página de ocho componentes
		# eran ocho clics.
		if not is_recording and event.keycode == KEY_BACKSPACE:
			var caster := _spellcaster()
			if caster:
				caster.clear_sequence()
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

		if is_recording and event.keycode == KEY_BACKSPACE:
			_erase(false)
			get_viewport().set_input_as_handled()
			return

		if is_recording and event.keycode == KEY_DELETE:
			# Borrado total: pide confirmación pulsándolo dos veces
			# seguidas, porque tirar cuarenta trazos por un dedazo
			# sería el peor momento posible para no preguntar.
			_erase(true)
			get_viewport().set_input_as_handled()
			return

		# CON EL LIBRO ABIERTO, 1/2/3 PASAN PÁGINA. Misma tecla, sentidos
		# emparejados: fuera lanza la página 2, dentro te lleva a ella. No
		# hay dos mapas de teclas que aprender, hay uno con dos modos.
		if not is_recording and event.keycode >= KEY_1 and event.keycode <= KEY_3:
			var caster := _spellcaster()
			if caster and event.keycode - KEY_1 < Repertoire.pages_available(caster.PAGES):
				caster.select_page(event.keycode - KEY_1)
				Sfx.play(_oyente(), "pagina")
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

		# Teclas 1..9 para elegir qué gesto se está grabando.
		if is_recording and event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var chosen: int = event.keycode - KEY_1
			if chosen < GestureLibrary.RECORDABLE.size():
				record_index = chosen
				queue_redraw()
			get_viewport().set_input_as_handled()
			return

		# Ya hay más gestos grabables que teclas numéricas, así que las
		# flechas recorren la lista entera. Da la vuelta al llegar al
		# final: con doce gestos, buscar el último a base de pulsar es
		# peor que retroceder uno desde el primero.
		if is_recording and (event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT):
			var step: int = 1 if event.keycode == KEY_RIGHT else -1
			record_index = posmod(record_index + step, GestureLibrary.RECORDABLE.size())
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_stroke(event.position)
		else:
			_end_stroke()
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# Deshacer el último trazo. Con varios trazos por hechizo,
		# equivocarse es constante, y sin esto la única salida era
		# cerrar el libro y lanzar algo que no querías.
		var caster := _spellcaster()
		if caster:
			caster.undo_last()
		queue_redraw()
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and is_drawing:
		_add_point(event.position)
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if is_open:
		_close()
	else:
		_open()


func _open() -> void:
	GestureRecognizer.exigencia = EXIGENCIA_RECTO if _recto_activo() else 1.0
	# Si el árbol ya estaba congelado, la pausa es de otro: has muerto o
	# has ganado. Abrir el libro y cerrarlo luego descongelaría esa
	# pantalla, así que en ese caso no se abre.
	if get_tree().paused:
		return

	# Antes de parar el tiempo: se apunta el sitio hacia el que miraba el
	# ratón, que es hacia donde saldrá el hechizo al cerrar (ver Spellcaster).
	var apuntador := _spellcaster()
	if apuntador:
		apuntador.remember_aim()

	is_open = true
	Sfx.play(_oyente(), "libro_abre")
	visible = true
	stroke = PackedVector2Array()
	pending_strokes = []
	_asist_reiniciar()
	gesture_countdown = 0.0
	is_drawing = false
	_mano_actualizar()
	if mano != null:
		mano.mostrar()

	# ABRIR YA NO BORRA. Antes cada apertura empezaba en blanco porque
	# solo había un hechizo y no tenía sentido conservarlo tras lanzarlo;
	# ahora hay tres páginas y lo que hay dibujado en ellas es
	# precisamente lo que el jugador preparó. Encontrárselo tal y como lo
	# dejó es todo el valor de tener páginas.

	# El árbol se congela: enemigos, temporizadores, incendios. Este nodo
	# sigue vivo porque tiene process_mode = ALWAYS (puesto en la escena).
	get_tree().paused = true
	_empezar_escrituras()
	queue_redraw()


func _close() -> void:
	is_open = false
	Sfx.play(_oyente(), "libro_cierra")
	visible = false
	is_drawing = false
	if mano != null:
		mano.ocultar()
	pending_strokes = []
	_asist_reiniciar()
	gesture_countdown = 0.0

	# Se descongela ANTES de lanzar, para que el hechizo nazca en un
	# mundo que ya corre: si no, aparecería quieto hasta el siguiente
	# fotograma sin pausa.
	get_tree().paused = false

	var caster := _spellcaster()
	if caster:
		caster.cast_current()


## --- Captura del trazo ---

## Radio dentro del cual se puede trazar. Con una lámina (todas las progresiones usan ya la «bosque») es un 25 % mayor que el círculo impreso
## (Pablo, 17/10): un trazo más amplio no se corta al rozar el borde. Es SOLO el límite de dónde nace y hasta dónde sigue el trazo: el dibujo del
## libro, el imán, el rectificado y el reconocimiento siguen midiendo con `RADIUS`, así que nada de lo ya ajustado cambia de escala.
const AMPLIA_AREA_TRAZO: float = 1.25

func _radio_trazo() -> float:
	return _u(RADIUS) * (AMPLIA_AREA_TRAZO if not _libro().is_empty() else 1.0)


## Tolerancia al temblor dentro de un glifo, como fracción de la del círculo grande (diario 137/138). El temblor de la mano mide igual en un
## círculo pequeño que en uno grande, así que no se reduce ×4 con él (medido: ×0,25 deja 73 % de aciertos con temblor fuerte; ×0,5, 98 %).
const TOL_RECTIFICADO_GLIFO: float = 0.5

## Escalas del rectificador para el trazo en curso: x = tolerancia al temblor, y = tamaño de las formas (tramo mínimo y cierre).
## En el núcleo (elementos) y en las láminas sin huecos medidos, las dos valen `_u(RADIUS)` como siempre. En un hueco de glifo las formas
## se miden con el RADIO DEL HUECO (≈ 58 de 233 de lámina): una forma del tamaño del hueco tiene tramos de ~24 px y con el tramo mínimo del
## círculo grande (23 px) se fundían con los vecinos y los giros no salían. El sector se decide por el centro del trazo hasta ahora, igual
## que `_familia_asistencia`.
func _escalas_rectificado() -> Vector2:
	var base: float = _u(RADIUS)
	var radios: Dictionary = _libro().get("hueco_radios", {})
	if radios.is_empty() or stroke_crudo.is_empty():
		return Vector2(base, base)
	var medio := Vector2.ZERO
	for p in stroke_crudo:
		medio += p
	var sector: Vector2 = _sector_of_point(medio / float(stroke_crudo.size()))
	if sector == Vector2.ZERO or sector == SIN_HUECO:
		return Vector2(base, base)
	return Vector2(base * TOL_RECTIFICADO_GLIFO, _lam(float(radios.get(_sector_idx(sector), 58.1))))


func _begin_stroke(pos: Vector2) -> void:
	# El trazo tiene que NACER dentro del círculo. Es la regla que hace
	# del círculo algo más que decoración.
	if pos.distance_to(_center()) > _radio_trazo():
		return

	is_drawing = true
	# Empezar un trazo cancela la cuenta atrás: este trazo forma parte
	# del mismo gesto que los anteriores.
	gesture_countdown = 0.0
	stroke = PackedVector2Array([pos])
	stroke_crudo = PackedVector2Array([pos])
	stroke_visible = PackedVector2Array([pos])
	if pending_strokes.is_empty():
		_t_gesto_ini = Time.get_ticks_msec()
	_asist_reloj = 0.0
	_asist_sucio = true
	queue_redraw()


func _add_point(pos: Vector2) -> void:
	# Salirse del círculo termina el trazo. Preferimos esto a recortar el
	# punto contra el borde: recortar deformaría el gesto y haría que el
	# reconocimiento fallara sin que se entienda por qué.
	if pos.distance_to(_center()) > _radio_trazo():
		_end_stroke()
		return

	if stroke_crudo.is_empty() or stroke_crudo[-1].distance_to(pos) >= MIN_POINT_DISTANCE:
		stroke_crudo.append(pos)
		if _recto_activo():
			# Rectificado en vivo: el trazo entero se recalcula (es determinista y barato: decenas de puntos) y se ve ya recto.
			var esc: Vector2 = _escalas_rectificado()
			stroke = GestureRectify.rectificar(stroke_crudo, esc.x, esc.y)
			stroke_visible = stroke
		else:
			stroke.append(pos)
			# El punto que se ve va imantado con la guía vigente (si la asistencia está activa); el real se guarda tal cual.
			stroke_visible.append(asistente.punto_imantado(pos, _u(RADIUS)) if _asistencia_activa() else pos)
		_asist_sucio = true
		queue_redraw()


## Al soltar el ratón el trazo se guarda, pero el GESTO todavía no está
## cerrado: puede que vengan más trazos. Se arranca la cuenta atrás.
func _end_stroke() -> void:
	if not is_drawing:
		return

	is_drawing = false

	if stroke.size() >= 2:
		pending_strokes.append(stroke)
		pending_visible.append(stroke_visible if stroke_visible.size() == stroke.size() else stroke)
		_t_gesto_fin = Time.get_ticks_msec()
		Sfx.play(_oyente(), "trazo")
		gesture_countdown = GESTURE_PAUSE

	stroke = PackedVector2Array()
	stroke_crudo = PackedVector2Array()
	stroke_visible = PackedVector2Array()
	# Lectura final con el gesto entero (es la que decide la aceptación anticipada al cerrar).
	if _asistencia_activa() and not pending_strokes.is_empty():
		_actualizar_asistencia()
	# Cierre inmediato (trazo recto): si ya no puede venir ningún trazo más, no se hace esperar la pausa.
	if _recto_activo() and not pending_strokes.is_empty() and _cierre_inmediato():
		gesture_countdown = 0.0
		_commit_gesture()
	queue_redraw()


## Con gestos de varios trazos aparece una pregunta que antes no
## existía: ¿cuándo se ha TERMINADO de dibujar? Ya no vale "al soltar el
## ratón". La respuesta es una pausa: si pasan GESTURE_PAUSE segundos
## sin dibujar, el gesto se da por cerrado. Empezar otro trazo antes de
## que venza lo suma al mismo gesto.
## Si el aviso de fallo del Spellcaster estaba visible la última vez que se
## dibujó. Sirve para redibujar justo cuando aparece y cuando se apaga: el libro
## no se redibuja solo, y el aviso dura un segundo.
var _aviso_visible: bool = false


func _process(delta: float) -> void:
	_mano_actualizar()
	if is_drawing and mano != null and mano.visible:
		queue_redraw()                       # la punta se mueve cada fotograma y la tinta del trazo en curso llega hasta ella
	var lanzador := _spellcaster()
	if lanzador:
		var ahora: bool = Time.get_ticks_msec() < lanzador.feedback_until
		if ahora != _aviso_visible:
			_aviso_visible = ahora
			queue_redraw()

	if is_drawing and _asist_sucio and _asistencia_activa():
		_asist_reloj += delta
		if _asist_reloj >= ASIST_PERIODO:
			_asist_reloj = 0.0
			_asist_sucio = false
			_actualizar_asistencia()

	if is_open and not _escribiendo.is_empty():
		_avanzar_escrituras(delta)
	if is_open:
		_empezar_escrituras()          # un glifo conseguido con el libro ya abierto (pruebas, capturas) se escribe igual

	if _limpio_t >= 0.0:
		_limpio_t += delta
		if _limpio_t >= T_REDIBUJADO:
			_limpio_t = -1.0
		queue_redraw()

	if gesture_countdown <= 0.0:
		return

	gesture_countdown -= delta
	if gesture_countdown <= 0.0:
		_commit_gesture()
	else:
		# Redibuja para que se vea la cuenta atrás avanzando.
		queue_redraw()


func _commit_gesture() -> void:
	if pending_strokes.is_empty():
		return

	if is_recording:
		_record_sample()
	else:
		var caster := _spellcaster()
		if caster:
			var sector: Vector2 = _sector_of_gesture()
			if sector != SIN_HUECO:         # un hueco cerrado no admite trazo: se descarta
				var a_enviar: Array = pending_strokes
				if _asistencia_activa():
					a_enviar = _decidir_con_asistencia(caster, sector)
				caster.add_gesture(a_enviar, sector)

	pending_strokes = []
	_asist_reiniciar()
	queue_redraw()


## --- Trazo recto ---

func _recto_activo() -> bool:
	return Estado.i().trazo_recto


## ¿Se puede cerrar el gesto YA? Solo si todos los gestos activos de su familia se dibujan con tantos trazos o menos de los que ya hay
## (dato de GestureLibrary.trazos; si a alguno le falta, -1 y no se cierra) Y el trazo real pasa el reconocedor. Un gesto de un trazo
## cuando queda por conocer uno de tres sigue esperando la pausa: cerrar de más sería peor que esperar.
func _cierre_inmediato() -> bool:
	if is_recording:
		return false
	var fam: Dictionary = _familia_asistencia(pending_strokes)
	if fam.is_empty():
		return false
	# 17/10 (playtest): la raya sola YA NO cierra al instante. Levitación ᛏ y repetición ᚠ empiezan por un palo vertical, y el palo se
	# convertía en `linea` antes de poder dibujar el resto. La raya espera como las demás: cierra al soltar solo cuando la regla general
	# lo permita (ningún sello activo necesita más trazos, `GestureLibrary.trazos`) y, si no, a la pausa.
	var maximo: int = library.trazos_max(fam["activos"])
	if maximo < 0 or maximo > pending_strokes.size():
		return false
	var caster := _spellcaster()
	if caster == null:
		return false
	return bool(_reconocer_real(caster, pending_strokes, _sector_of_gesture())["accepted"])


## --- Asistencia al trazo: puente entre el libro y GestureAssist ---

func _asistencia() -> float:
	return clampf(Estado.i().asistencia, 0.0, 1.0)


## Activa solo con la opción > 0 y fuera del modo de grabación (grabar plantillas con ayuda las estropearía).
func _asistencia_activa() -> bool:
	return _asistencia() > 0.0 and not is_recording


func _asist_reiniciar() -> void:
	asistente.reiniciar()
	pending_visible = []
	stroke_visible = PackedVector2Array()
	_asist_reloj = 0.0
	_asist_sucio = false


## Con qué se compara lo dibujado: el mismo reparto que hace el Spellcaster. Un gesto centrado en el núcleo es un ELEMENTO (sin giro);
## fuera, un SELLO, que se compara girado por su sector. Las plantillas van TODAS (también las runas aún no conocidas, que hacen de
## señuelo) y `activos` dice cuáles pueden salir de candidata: solo se ayuda con lo que el jugador conoce.
func _familia_asistencia(strokes: Array) -> Dictionary:
	var medio := Vector2.ZERO
	var n: int = 0
	for t in strokes:
		for p in t:
			medio += p
			n += 1
	var sector: Vector2 = _sector_of_point(medio / float(maxi(n, 1)))
	if sector == SIN_HUECO:
		return {}
	if sector == Vector2.ZERO:
		return {"plantillas": library.templates_for(GestureLibrary.ELEMENTS), "activos": Repertoire.active_elements(), "giro": 0.0}
	# 16/10: el sello se dibuja apuntando al centro (GestureLibrary.giro_glifo); el trazo se desgira para compararlo derecho.
	var giro: float = -GestureLibrary.giro_glifo(sector)
	# ᛁ no se gira hacia el centro (se dibuja horizontal o vertical tal cual: EjesRecetaUi.exenta_del_giro, 156): su plantilla se compara con el trazo SIN girar.
	var plantillas: Dictionary = library.templates_for(GestureLibrary.SIGILS)
	var sin_giro := PackedStringArray()
	for nombre in plantillas:
		if EjesRecetaUi.exenta_del_giro(String(nombre)):
			sin_giro.append(String(nombre))
	return {"plantillas": plantillas, "activos": Repertoire.active_sigils(), "giro": giro, "sin_giro": sin_giro}


## Una lectura de lo que llevas dibujado (los trazos cerrados y el que está en curso).
func _actualizar_asistencia() -> void:
	var trazos: Array = pending_strokes.duplicate()
	if stroke.size() >= 2:
		trazos.append(stroke)
	if trazos.is_empty():
		asistente.reiniciar()
		return
	var fam: Dictionary = _familia_asistencia(trazos)
	if fam.is_empty():              # trazo sobre un hueco cerrado: sin guía
		asistente.reiniciar()
		return
	asistente.actualizar(trazos, fam["plantillas"], fam["activos"], _asistencia(), fam["giro"], fam.get("sin_giro", PackedStringArray()))
	# El trazo en curso se vuelve a imantar entero: la guía se recoloca al crecer lo dibujado. Con el trazo recto no hay imán.
	if is_drawing and stroke.size() >= 1 and not _recto_activo():
		stroke_visible = asistente.trazo_imantado(stroke, _u(RADIUS))
	queue_redraw()


## Qué trazos se le dan al Spellcaster y qué se anota en PlayLog. El reconocimiento de verdad se hace sobre el trazo REAL: la guía solo
## entra como ACEPTACIÓN ANTICIPADA, y solo cuando el real no ha sido aceptado y la candidata es firme (margen ≥ umbral de su gesto y
## ≥ 85 % del recorrido). En ese caso se le pasa la plantilla colocada sobre el trazo, que es lo que se redibuja limpio.
func _decidir_con_asistencia(caster: Node, sector: Vector2) -> Array:
	var tiempo: float = float(maxi(_t_gesto_fin - _t_gesto_ini, 0)) / 1000.0
	var candidata: String = asistente.candidata
	var real: Dictionary = _reconocer_real(caster, pending_strokes, sector)
	var correccion: String = "ninguna"
	var a_enviar: Array = pending_strokes
	if real["accepted"]:
		if candidata != "" and asistente.fuerza_iman() > 0.0 and not _recto_activo():
			correccion = "iman"
		# Redibujado limpio solo si lo reconocido coincide con la guía que se enseñaba.
		if candidata != "" and real["name"] == candidata:
			_iniciar_redibujado()
	elif candidata != "" and asistente.aceptable:
		correccion = "aceptacion_anticipada"
		a_enviar = asistente.trazos_limpios()
		_iniciar_redibujado()
	PlayLog.event("asistencia", {
		"candidata": candidata, "confianza": snappedf(asistente.confianza, 0.01),
		"cobertura": snappedf(asistente.cobertura, 0.01), "tiempo": snappedf(tiempo, 0.01),
		"correccion": correccion, "iman": snappedf(asistente.fuerza_iman(), 0.01),
		"real": real["name"] if real["accepted"] else "", "asistencia": snappedf(_asistencia(), 0.01),
		"ms": snappedf(asistente.ms_ultimo, 0.1), "recto": _recto_activo(), "trazos": pending_strokes.size()})
	return a_enviar


## Lo que el Spellcaster haría con el trazo real: {name, accepted}. Misma ruta que `add_gesture` (elemento en el núcleo, sello en sector).
func _reconocer_real(caster: Node, strokes: Array, sector: Vector2) -> Dictionary:
	var r: Dictionary
	if sector == Vector2.ZERO:
		r = GestureRecognizer.recognize(strokes, library.templates_for(GestureLibrary.ELEMENTS), Repertoire.active_elements())
	elif caster.has_method("_reconocer_glifo"):
		r = caster.call("_reconocer_glifo", strokes, sector)
	else:
		r = GestureRecognizer.recognize(strokes, library.templates_for(GestureLibrary.SIGILS), Repertoire.active_sigils())
	return {"name": str(r.get("name", "")), "accepted": bool(r.get("accepted", false))}


func _iniciar_redibujado() -> void:
	if asistente.guia.is_empty():
		return
	_limpio_desde = pending_visible.duplicate()
	_limpio_hasta = asistente.trazos_limpios()
	_limpio_t = 0.0


## Guarda el gesto actual como una muestra más del gesto seleccionado.
##
## Se guarda YA NORMALIZADO porque es la forma en que luego se compara.
## Normalizar al grabar y no al comparar ahorra hacerlo una y otra vez
## en cada reconocimiento.
##
## Guarda en disco después de cada muestra: grabar 40 gestos y perderlos
## por cerrar el juego sin pensar sería para tirar la mesa.
## Retroceso borra la última muestra del gesto seleccionado.
## Suprimir (dos veces seguidas) borra TODAS las suyas.
func _erase(whole_gesture: bool) -> void:
	var gesture_name: String = GestureLibrary.RECORDABLE[record_index]

	if not whole_gesture:
		library.remove_last_sample(gesture_name)
		delete_armed = false
		print("Borrada la última muestra de '", gesture_name, "': quedan ",
			library.sample_count(gesture_name))
	elif delete_armed:
		library.clear_gesture(gesture_name)
		delete_armed = false
		print("Borradas TODAS las muestras de '", gesture_name, "'")
	else:
		delete_armed = true
		print("Pulsa SUPR otra vez para borrar todas las muestras de '", gesture_name, "'")
		queue_redraw()
		return

	_save_library()
	queue_redraw()


func _save_library() -> void:
	library.save()


func _record_sample() -> void:
	var normalized := GestureRecognizer.normalize(pending_strokes)
	if normalized.is_empty():
		print("Gesto inválido, no se guarda.")
		return

	var gesture_name: String = GestureLibrary.RECORDABLE[record_index]
	library.add_sample(gesture_name, normalized, pending_strokes.size())

	_save_library()
	delete_armed = false

	print("Guardada muestra de '", gesture_name, "': ",
		library.sample_count(gesture_name), " en total")


## --- DÓNDE CAE EL LIBRO ---
##
## Se encuadra el BLOQUE DE PÁGINAS, no la lámina entera, y se elige la
## escala que lo hace caber entero. Lo que sobra de tapa se sale por los
## bordes: un libro abierto a pantalla completa se lee mejor que un libro
## pequeño y centrado con fondo alrededor.
func _book_rect() -> Rect2:
	var pb: Rect2 = _page_block()
	var fit: float = minf(size.x / pb.size.x, size.y / pb.size.y)
	var block_centre: Vector2 = (pb.position + pb.size * 0.5) * fit
	return Rect2(size * 0.5 - block_centre, BOOK_SIZE * fit)


## De píxel de lámina a píxel de pantalla.
func _on_page(point: Vector2) -> Vector2:
	var book: Rect2 = _book_rect()
	return book.position + point * (book.size.x / BOOK_SIZE.x)


## Cuánto mide en pantalla una unidad de las de siempre.
##
## TODAS las medidas del grimorio (RADIUS, CORE_RADIUS, los tamaños de
## glifo...) se quedan como estaban y se multiplican por esto. Así el
## diseño del círculo sigue escrito en sus propios números —que es como
## se ajustó— y encajarlo en el libro es una sola cuenta: lo que medía
## RADIUS pasa a medir lo que mide el círculo impreso.
func _ui() -> float:
	var book: Rect2 = _book_rect()
	return (book.size.x / BOOK_SIZE.x) * _circ_r() / RADIUS


## Lo mismo para una medida suelta. Se llama así de corto porque aparece
## en casi todas las líneas de dibujo y con un nombre largo no se leería
## ninguna.
func _u(value: float) -> float:
	return value * _ui()


## El texto también encoge con el libro; si no, en el círculo pequeño los
## rótulos saldrían enormes. Con un suelo, porque por debajo de 12 px la
## fuente de Godot deja de leerse.
func _u_font() -> int:
	return maxi(12, int(round(18.0 * _ui())))


## El centro del círculo de dibujo: el que viene impreso en la página
## izquierda. Todo el grimorio cuelga de aquí, así que moverlo mueve el
## conjunto — que es justo lo que hacía falta para pasarlo a la izquierda.
func _center() -> Vector2:
	return _on_page(_circ_c())


## A qué sector pertenece un trazo, devuelto ya como vector unitario.
##
## Se mide desde el CENTRO DEL TRAZO (la media de sus puntos) y no desde
## donde empieza o acaba: el centro es lo único que no cambia si dibujas
## la línea de ida o de vuelta.
##
## `snappedf` redondea el ángulo al múltiplo más cercano de un octavo de
## vuelta, que es exactamente "quedarse con el sector". Un trazo hecho
## sobre el núcleo no cae en ningún sector y devuelve ZERO: no hay
## dirección que deducir.
## El sector del gesto entero: se mide sobre TODOS sus trazos juntos.
## Un ⊥ tiene el palo en un sitio y la base en otro, pero el gesto está
## donde está su conjunto.
func _sector_of_gesture() -> Vector2:
	var middle := Vector2.ZERO
	var count := 0
	for s in pending_strokes:
		for p in s:
			middle += p
			count += 1

	if count == 0:
		return Vector2.ZERO

	return _sector_of_point(middle / float(count))


func _sector_of_point(middle: Vector2) -> Vector2:
	var offset := middle - _center()
	# El sello (núcleo) puede no estar en el centro del círculo: dentro de él es un elemento.
	if (middle - _on_page(_core_c())).length() < _u(_core_u()):
		return Vector2.ZERO

	var step := TAU / float(SECTORS)
	var angle := snappedf(offset.angle(), step)

	# Con lámina alternativa solo existen ciertos huecos: se elige el más cercano en ángulo, SOLO entre los abiertos.
	# Sin ninguno abierto el trazo no va a ningún sitio (SIN_HUECO), y no se confunde con un elemento (ZERO).
	var huecos: Dictionary = _huecos_abiertos()
	if not (_libro().get("huecos", {}) as Dictionary).is_empty() and huecos.is_empty():
		return SIN_HUECO
	if not huecos.is_empty() and not huecos.has(_sector_idx(Vector2(cos(angle), sin(angle)))):
		var mejor: float = INF
		for k in huecos:
			var a: float = float(k) * step
			var dif: float = absf(angle_difference(offset.angle(), a))
			if dif < mejor:
				mejor = dif
				angle = a
	return Vector2(cos(angle), sin(angle))


## --- Dibujo ---
## El aro, el núcleo y las ranuras siguen siendo dibujo por código sobre
## una lámina de fondo. Esa división es la que interesa: la lámina pone
## el sitio y el ambiente, el código pone lo que cambia.

func _draw() -> void:
	var c := _center()

	# El velo sigue estando, pero ahora es lo que oscurece los bordes
	# alrededor del libro: la lámina no llena la pantalla entera por los
	# lados y sin el velo se vería el juego congelado asomando.
	draw_rect(Rect2(Vector2.ZERO, size), VEIL)
	_draw_book()
	# Rejilla guía del trazo (entrada 130 del diario): va ANTES de los aros, la leyenda y el trazo para quedar por debajo de todo.
	# Solo dibuja en las láminas que conoce (la «bosque»); no toca el reconocimiento.
	# Se pasa `{}` como huecos A PROPÓSITO (Pablo, 17/10): la rejilla es una sola, continua por toda la página, sin rejillas finas dentro de los
	# círculos de glifo (se veían mal) y sin apartar la de la página alrededor de ellos. `CuadriculaGuia` sigue sabiendo dibujarlas si se le pasan.
	CuadriculaGuia.dibujar(self, Repertoire.libro, {}, {}, _on_page, _lam)
	_draw_huecos()

	_draw_legend()

	_draw_ring(c)
	_draw_sectors(c)
	_draw_core(_on_page(_core_c()))
	_draw_components(c)
	_draw_pages(c)

	var ink: Color = RECORD_INK if is_recording else STROKE_INK
	var grosor: float = _u(4.0)
	var asistido: bool = _asistencia_activa()
	if asistido:
		_draw_guia()
	# Con asistencia se pinta el trazo imantado; el real solo se usa para reconocer.
	var cerrados: Array = pending_visible if (asistido and pending_visible.size() == pending_strokes.size()) else pending_strokes
	for s in cerrados:
		if s.size() >= 2:
			draw_polyline(s, ink, grosor, true)
	var en_curso: PackedVector2Array = stroke_visible if (asistido and stroke_visible.size() == stroke.size()) else stroke
	if is_drawing and mano != null and mano.visible:
		en_curso = _tinta_hasta_punta(en_curso, mano.punta())
	if en_curso.size() >= 2:
		draw_polyline(en_curso, ink, grosor, true)
	if _limpio_t >= 0.0:
		_draw_redibujado(grosor)

	_draw_hint(c)


## Le da a la mano, cada fotograma, dónde apuntar. Dibujando: el ÚLTIMO punto del trazo ya imantado (`stroke_visible`), no el ratón crudo (así la pluma va
## donde va la tinta, también con la asistencia). Sin dibujar: el ratón, para que se vea dónde empezaría el trazo. La escala sigue al tamaño del libro:
## en la 3D, 1 = tamaño de diseño a 1470 de ancho; la 2D conserva su 0,55.
func _mano_actualizar() -> void:
	if mano == null or not is_open:
		return
	var relativa: float = _book_rect().size.x / BOOK_SIZE.x
	mano.escala = relativa if mano is ManoPluma3D else MANO_ESCALA_2D * relativa
	var punto: Vector2 = get_local_mouse_position()
	if is_drawing and not stroke_visible.is_empty():
		punto = stroke_visible[stroke_visible.size() - 1]
	mano.apuntar(punto, is_drawing)


## Recorta el trazo en curso hasta la punta de la pluma: la punta cae sobre la poligonal, un poco por detrás del último punto (retardo de 60 ms).
## Se busca el segmento más cercano a la punta entre los últimos puntos y se corta ahí; si hay empate gana el más reciente. Solo cambia lo que se
## PINTA: el reconocimiento usa `stroke`, entero.
static func _tinta_hasta_punta(pts: PackedVector2Array, punta: Vector2) -> PackedVector2Array:
	var n: int = pts.size()
	if n < 2:
		return pts
	var mejor_i: int = n - 2
	var mejor_p: Vector2 = pts[n - 1]
	var mejor_d: float = INF
	for i in range(n - 2, maxi(0, n - 2 - TINTA_MIRA_ATRAS) - 1, -1):
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(punta, pts[i], pts[i + 1])
		var d: float = q.distance_squared_to(punta)
		if d < mejor_d - 0.01:
			mejor_d = d
			mejor_i = i
			mejor_p = q
	var salida: PackedVector2Array = pts.slice(0, mejor_i + 1)
	salida.append(mejor_p)
	return salida


## La guía fantasma: puntos tenues a lo largo de la plantilla de la candidata líder. Sin candidata (empate o nada reconocible), nada.
func _draw_guia() -> void:
	if asistente.candidata == "" or asistente.guia.is_empty() or (not is_drawing and pending_strokes.is_empty()):
		return
	var paso: float = _u(11.0)
	var radio: float = _u(2.2)
	for pieza in asistente.guia:
		var resto: float = 0.0
		for i in range(pieza.size() - 1):
			var a: Vector2 = pieza[i]
			var b: Vector2 = pieza[i + 1]
			var largo: float = a.distance_to(b)
			var d: float = resto
			while d <= largo:
				draw_circle(a.lerp(b, d / maxf(largo, 0.0001)), radio, GUIA_COLOR)
				d += paso
			resto = d - largo


## Redibujado limpio (0,2 s) al aceptar: el trazo imantado se desvanece y la plantilla se funde en su lugar.
func _draw_redibujado(grosor: float) -> void:
	var k: float = clampf(_limpio_t / T_REDIBUJADO, 0.0, 1.0)
	var viejo := STROKE_INK
	viejo.a = 1.0 - k
	var nuevo := STROKE_INK
	nuevo.a = k
	for s in _limpio_desde:
		if s.size() >= 2:
			draw_polyline(s, viejo, grosor, true)
	for s in _limpio_hasta:
		if s.size() >= 2:
			draw_polyline(s, nuevo, grosor, true)


## Los aros de los huecos de glifo ABIERTOS (la lámina no los trae impresos); los cerrados no se pintan.
func _draw_huecos() -> void:
	if _hueco_tex == null:
		return
	var radio_sprite: float = float(_libro().get("hueco_sprite_radio", 58.1))
	var radios: Dictionary = _libro().get("hueco_radios", {})
	var abiertos: Dictionary = _huecos_abiertos()
	for k in abiertos:
		var lado: float = _lam(float(_hueco_tex.get_width()) * float(radios.get(k, radio_sprite)) / radio_sprite)
		_draw_texture_centred(_hueco_tex, _on_page(abiertos[k]), lado)


func _draw_book() -> void:
	var tex: Texture2D = BOOK_TEXTURE
	if not _libro().is_empty():
		tex = _libro_tex
	draw_texture_rect(tex, _book_rect(), false)


## --- LA PÁGINA DE LA DERECHA: LO QUE SABE EL JUGADOR ---
##
## Las doce casillas impresas se rellenan con los glifos que el mago ya
## tiene anotados. No es un menú: no se pulsa, no se elige. Es la chuleta
## del propio libro, para no tener que acordarse de doce formas de
## memoria mientras se dibuja en la página de al lado.
##
## QUÉ ENTRA AQUÍ NO SE DECIDE AQUÍ. Entra lo que está ACTIVO
## (Repertoire) Y tiene glifo: los elementos cuyo RuneData trae uno, y los
## sellos que estén en Sigils.GLYPHS. Tiempo y pilar siguen sin aparecer
## porque no tienen dibujo; el resto desaparece o aparece según lo que el
## nivel haya desbloqueado.
##
## Y CONOCIDO NO ES LO MISMO QUE EXISTENTE: un glifo se anota con tinta
## si la biblioteca tiene muestras suyas, y se queda en marca de agua si
## no. Así la página se va llenando según se graban gestos, en vez de
## nacer completa.
## Las casillas impresas en la página: lo que no cabe no se pinta (con todo
## desbloqueado hay más runas que casillas).
const LEGEND_SLOTS: int = 12

func _draw_legend() -> void:
	var caster := _spellcaster()
	if caster == null:
		return

	var slot: int = 0
	# Lámina con círculos de sello propios (bosque): los elementos van a los círculos y los glifos a la rejilla, contados por separado.
	var ley_sellos: Array = _libro().get("leyenda_sellos", [])
	var separa: bool = not ley_sellos.is_empty()
	var limite: int = ley_sellos.size() if separa else LEGEND_SLOTS

	for gesture_name in GestureLibrary.ELEMENTS:
		# Lo que no está activo NO SE ENSEÑA, ni siquiera en marca de agua:
		# la marca de agua dice "esto existe y aún no lo has grabado", y
		# aquí lo que hay que decir es que todavía no está a tu alcance.
		if not Repertoire.element_active(gesture_name):
			continue
		if slot >= limite:
			if separa:
				break
			return
		var tipo: int = caster.GESTURE_TO_RUNE.get(gesture_name, Runes.Type.NONE)
		var datos: RuneData = caster.rune_database.get(tipo)
		if datos == null or datos.glyph == null:
			continue
		# El elemento se anota CON SU COLOR, igual que en el núcleo: la
		# chuleta enseña la runa tal como se va a ver al dibujarla.
		_draw_legend_slot(slot, datos.glyph, datos.display_name,
			datos.color.darkened(CORE_GLYPH_DARKEN),
			library.sample_count(gesture_name) > 0, _glyph_angle(gesture_name), separa)
		slot += 1

	if separa:
		slot = 0
		limite = (_libro().get("leyenda", []) as Array).size()
	for gesture_name in GestureLibrary.SIGILS:
		if not Repertoire.sigil_active(gesture_name):
			continue
		if slot >= limite:
			return
		var glyph: Texture2D = Sigils.GLYPHS.get(gesture_name)
		if glyph == null:
			continue
		# Los sellos, sin teñir. La misma regla que en la corona.
		_draw_legend_slot(slot, glyph, gesture_name, INK,
			library.sample_count(gesture_name) > 0)
		slot += 1


## Un glifo todavía sin muestras se queda en marca de agua.
const LEGEND_FADED: Color = Color(0.24, 0.19, 0.16, 0.16)

## Iconos que se dibujan GIRADOS, en radianes (PI * 0.5 = 90 grados en el
## sentido de las agujas del reloj; con signo negativo, al revés). Se gira el
## dibujo al pintarlo, no el archivo de arte. Clave: nombre del elemento en
## minúsculas.
const GLYPH_ROTATION: Dictionary = {"rayo": PI * 0.5}


func _glyph_angle(nombre: String) -> float:
	return GLYPH_ROTATION.get(nombre.to_lower(), 0.0)


## Un icono centrado y, si toca, girado sobre su propio centro.
func _draw_glyph(texture: Texture2D, centre: Vector2, size: float, tint: Color,
		angle: float) -> void:
	if angle == 0.0:
		_draw_texture_centred(texture, centre, size, tint)
	else:
		_draw_texture_rotated(texture, centre, size, angle, tint)


## Cuántas veces lleva la PÁGINA ABIERTA cada glifo de la receta V2 (el mismo multiconjunto que lee `Receta3D`): `linea_x` / `linea_z` ya vienen
## separados en el componente (`Spellcaster._nombre_linea`) y `levitacion` cuenta como `altura` (`Sigils.ALIAS_V2`). Lo que la V2 no conoce
## (un componente sin sello, los glifos aparcados) no cuenta. Es solo para PINTAR: no decide nada del hechizo.
func _contadores_pagina() -> Dictionary:
	var cont: Dictionary = {}
	var caster := _spellcaster()
	if caster == null:
		return cont
	for component in caster.components():
		for sello_pagina in (component["sigils"] as Array):
			var nombre: String = Sigils.glifo_v2(String(sello_pagina))
			if Sigils.GLIFOS_V2.has(nombre):
				cont[nombre] = int(cont.get(nombre, 0)) + 1
	return cont


## Lo que marcan las insignias de la chuleta: los mismos contadores.
func _usos_pagina() -> Dictionary:
	return _contadores_pagina()


## `sello` = es un elemento y la lámina tiene círculos de sello aparte: va a su círculo, más pequeño y sin rótulo (no cabe dentro).
func _draw_legend_slot(slot: int, glyph: Texture2D, label: String,
		ink: Color, known: bool, angle: float = 0.0, sello: bool = false) -> void:
	var cell := Vector2(float(slot % GRID_COLS), float(slot / GRID_COLS))
	var at: Vector2 = _on_page(GRID_ORIGIN + GRID_STEP * cell)
	var ley: Array = _libro().get("leyenda", [])
	var tam: float = _u(GRID_GLYPH)
	var caida: float = _u(GRID_LABEL_DROP)
	var con_rotulo: bool = true
	if sello and _libro().has("leyenda_sellos"):
		ley = _libro().get("leyenda_sellos", [])
		tam = _lam(float(_libro().get("sello_tam", 46.0)))
		con_rotulo = false
	elif _libro().has("leyenda_sellos"):
		tam = _lam(float(_libro().get("glifo_tam", 54.0)))
		caida = _lam(34.0)
	if not ley.is_empty():
		if slot >= ley.size():
			return
		at = _on_page(ley[slot])

	# 24/10: un glifo recién conseguido se está escribiendo en su casilla (ver `_escribiendo`); al acabar sigue el dibujo de siempre.
	if not sello and _escribiendo.has(label):
		if _draw_escritura(label, glyph, at, tam, ink):
			return

	# 18/10 (diario 156, Pipeline): ᛁ, ᛏ/altura y las cinco propiedades enseñan lo que hacen (ejes y rótulos) y cuántas lleva la página abierta.
	# Para cualquier otro glifo `dibujar_casilla` devuelve false sin pintar y sigue el dibujo de siempre.
	if not sello and EjesRecetaUi.dibujar_casilla(self, label, glyph, at, tam, ink, known, _usos_pagina()):
		return

	if not known:
		# Sin muestras grabadas: la casilla se queda en marca de agua.
		# Se ve que ese hueco existe y que le falta algo, que es más
		# interesante que no enseñar nada.
		_draw_glyph(glyph, at, tam, LEGEND_FADED, angle)
		return

	_draw_glyph(glyph, at, tam, ink, angle)
	if con_rotulo:
		_draw_centered_text(at + Vector2(0.0, caida), Sigils.nombre_visible(label),
			Color(ink.r, ink.g, ink.b, 0.75))


## GLIFOS QUE SE ESCRIBEN EN LA PÁGINA DERECHA (24/10, Pablo): lo que se consigue jugando (`Repertoire.conseguir_sigil`) se escribe en su casilla
## de la chuleta la primera vez que el libro está abierto: de arriba abajo con un frente dorado (el mismo gesto que la página del cofre legendario),
## un halo que se apaga y su nombre al final. Así la página derecha recuerda los glifos que has ido consiguiendo. Clave: nombre del glifo;
## valor: s desde que empezó (negativo = aún espera su turno).
var _escribiendo: Dictionary = {}

const ESCRITURA_RETARDO: float = 0.35      ## s desde que se abre el libro hasta que empieza a escribirse el primero
const ESCRITURA_ESCALON: float = 0.6       ## s entre un glifo y el siguiente si hay varios
const ESCRITURA_TRAZO: float = 1.0         ## s que tarda el trazo de arriba abajo
const ESCRITURA_NOMBRE: float = 0.35       ## s con el halo a pleno tras el trazo (el nombre ya sale, con la casilla de siempre)
const ESCRITURA_HALO: float = 0.6          ## s que tarda en apagarse el halo al acabar
const ESCRITURA_FRENTE: float = 0.08       ## fracción del alto del glifo que ocupa el frente dorado
const ESCRITURA_ORO: Color = Color(1.0, 0.78, 0.26)


## Recoge lo que haya por escribir y lo pone en cola. Devuelve cuántos empezó (las pruebas).
func _empezar_escrituras() -> int:
	var nuevos: PackedStringArray = Repertoire.tomar_por_escribir()
	var en_cola: int = _escribiendo.size()
	for i in nuevos.size():
		if _escribiendo.has(nuevos[i]):
			continue
		_escribiendo[nuevos[i]] = -ESCRITURA_RETARDO - ESCRITURA_ESCALON * float(en_cola + i)
	return nuevos.size()


func _duracion_escritura() -> float:
	return ESCRITURA_TRAZO + ESCRITURA_NOMBRE + ESCRITURA_HALO


func _avanzar_escrituras(delta: float) -> void:
	for nombre in _escribiendo.keys():
		_escribiendo[nombre] = float(_escribiendo[nombre]) + delta
		if float(_escribiendo[nombre]) >= _duracion_escritura():
			_escribiendo.erase(nombre)
	queue_redraw()


## Una casilla a medio escribir. Antes de su turno no se pinta nada (la casilla está vacía, como antes de conseguirlo). Devuelve true si ya la
## ha pintado entera; false = el trazo ya acabó y solo queda el halo: la casilla se pinta como siempre encima (con su nombre y su letra de siempre).
func _draw_escritura(nombre: String, glyph: Texture2D, at: Vector2, tam: float, ink: Color) -> bool:
	var t: float = float(_escribiendo.get(nombre, 0.0))
	if t < 0.0:
		return true
	var p: float = clampf(t / ESCRITURA_TRAZO, 0.0, 1.0)
	# El halo: crece mientras se escribe y se apaga al acabar.
	var halo: float = p if t < ESCRITURA_TRAZO + ESCRITURA_NOMBRE else 1.0 - clampf((t - ESCRITURA_TRAZO - ESCRITURA_NOMBRE) / ESCRITURA_HALO, 0.0, 1.0)
	if halo > 0.0:
		draw_circle(at, tam * 0.78, Color(ESCRITURA_ORO, 0.18 * halo))
		draw_arc(at, tam * 0.78, 0.0, TAU, 48, Color(ESCRITURA_ORO, 0.55 * halo), _u(2.0), true)
	if p >= 1.0:
		return false
	var ts: Vector2 = glyph.get_size()
	var arriba: Vector2 = at - Vector2(tam, tam) * 0.5
	# Lo ya escrito, en tinta.
	if p > 0.0:
		draw_texture_rect_region(glyph, Rect2(arriba, Vector2(tam, tam * p)), Rect2(Vector2.ZERO, Vector2(ts.x, ts.y * p)), ink)
	# El frente: la franja de debajo del trazo, en dorado.
	var f0: float = maxf(p - ESCRITURA_FRENTE, 0.0)
	if p > f0:
		draw_texture_rect_region(glyph, Rect2(arriba + Vector2(0.0, tam * f0), Vector2(tam, tam * (p - f0))),
			Rect2(Vector2(0.0, ts.y * f0), Vector2(ts.x, ts.y * (p - f0))), ESCRITURA_ORO)
	return true


## EL ARO YA NO SE DIBUJA CON TEXTURA, y no es un recorte de trabajo: la
## página trae el círculo impreso, y encima de él la textura del aro era
## un donut de madera que lo tapaba entero. Ahora solo se repasa a tinta
## el borde que ya está dibujado, para que se vea DÓNDE acaba la zona en
## la que se puede trazar — que es la única información que el aro tenía
## que dar y que el círculo impreso, al ser tan tenue, no da del todo.
func _draw_ring(c: Vector2) -> void:
	if not _libro().is_empty() and not bool(_libro().get("guias", true)):
		return
	draw_arc(c, _u(RADIUS), 0.0, TAU, 96, INK_SOFT, _u(2.0), true)


## Dibuja una textura centrada en un punto, con el tamaño que le pidas.
## Todo el libro pasa por aquí, que es lo que permite que cambiar RADIUS
## reescale el conjunto entero.
func _draw_texture_centred(texture: Texture2D, centre: Vector2, size: float, tint := Color.WHITE) -> void:
	var half := size * 0.5
	draw_texture_rect(texture, Rect2(centre - Vector2(half, half), Vector2(size, size)), false, tint)


## Igual, pero girada sobre su propio centro. Solo la usa la flecha: es
## el único glifo cuya rotación dice algo (hacia dónde sale el proyectil).
## draw_set_transform mueve el lienzo entero, así que hay que devolverlo
## a su sitio al terminar o todo lo que se pinte después saldría girado.
func _draw_texture_rotated(texture: Texture2D, centre: Vector2, size: float,
		angle: float, tint := Color.WHITE) -> void:
	var half := size * 0.5
	draw_set_transform(centre, angle, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-half, -half, size, size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## --- El color del núcleo ---
##
## EL NÚCLEO YA NO LLEVA DISCO. Llevaba un lavado del color del elemento,
## y por mucho que se aguara y se recogiera seguía siendo una imagen
## pegada encima de otra: tapaba la rosa de los vientos y las guías que
## la página trae dibujadas justo ahí. El color que pediste para los
## elementos lo lleva el propio glifo, que para eso está teñido; el disco
## no aportaba nada que el glifo no dijera ya, y se comía el libro.
##
## Sin disco debajo, el glifo se dibuja MÁS GRANDE: solo, al tamaño de
## antes, se quedaba pequeño y tímido en medio de un círculo vacío.
const CORE_GLYPH_DARKEN: float = 0.30 

## El nombre, en el mismo color pero más apagado que el glifo.
const CORE_NAME_DARKEN: float = 0.55 

## El glifo ocupa poco más que el radio del núcleo: tiene que respirar
## dentro de la ranura, no tocarle el borde.
const CORE_GLYPH_SIZE: float = CORE_RADIUS * 1.44

## El núcleo solo aparece cuando ya has dibujado un elemento, y toma su
## color y su glifo de la propia ficha del elemento (RuneData). Igual que
## el hechizo: esto no sabe qué elementos existen.
func _draw_core(c: Vector2) -> void:
	var caster := _spellcaster()
	if caster == null:
		return

	var element: RuneData = caster.current_element_data()
	if element == null:
		# Sin elemento, la ranura vacía y apagada esperando.
		if _libro().is_empty():
			draw_arc(c, _u(CORE_RADIUS), 0.0, TAU, 64, INK_FAINT, _u(2.0), true)
		return

	# El glifo, cargado de color y sin nada debajo. El elemento es lo
	# ÚNICO del libro que va coloreado: en la corona los sellos van todos
	# con la misma tinta. Así el color no significa "hay algo aquí" sino
	# "esto es fuego", y se distingue de un vistazo antes de leer el
	# nombre. Sigue mandando el RuneData, así que un elemento nuevo se ve
	# bien sin arte nuevo.
	if element.glyph != null:
		_draw_glyph(element.glyph, c, _u(CORE_GLYPH_SIZE),
			element.color.darkened(CORE_GLYPH_DARKEN), _glyph_angle(element.display_name))

	# El nombre va DENTRO del núcleo ahora que es grande: fuera chocaría
	# con el anillo del glifo.
	_draw_centered_text(c + Vector2(0, _u(_core_u() - 28.0)), element.display_name,
		element.color.darkened(CORE_NAME_DARKEN))

	# 18/10: el tamaño del hechizo en casillas (x·y·z) como un cubo con las proporciones de la página. Sin glifos sale 1·1·1 (la esfera base).
	EjesRecetaUi.dibujar_indicador(self, EjesRecetaUi.sitio_en_nucleo(c, _u(_core_u())), _u(_core_u()), Sigils.aplicar_v2(_contadores_pagina()))


## Las divisiones entre sectores: van del núcleo al borde, porque el
## núcleo no pertenece a ninguno. Se dibujan en las FRONTERAS (medio
## sector girado) para que cada porción quede centrada en su dirección,
## no partida por una línea justo en medio.
func _draw_sectors(c: Vector2) -> void:
	if not _libro().is_empty() and not bool(_libro().get("guias", true)):
		return
	var step := TAU / float(SECTORS)

	# Las divisiones van en las FRONTERAS (medio sector giradas) para que
	# cada porción quede centrada en su dirección, no partida por una
	# raya justo en medio.
	for i in range(SECTORS):
		var angle := step * (float(i) + 0.5)
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(c + dir * _u(CORE_RADIUS), c + dir * _u(RADIUS), INK_FAINT, _u(1.0))

	# Una ranura apagada en cada sector: enseña DÓNDE se puede dibujar
	# sin decir QUÉ. El anillo sigue sin ser un catálogo de opciones.
	#
	# Es un círculo a lápiz y ya no la textura SLOT_EMPTY: sobre el
	# pergamino aquel disco azul grisáceo se leía como un botón pegado
	# encima del libro. Trazado a tinta floja pasa a ser lo que tiene que
	# ser — una casilla que el propio libro trae marcada, igual que las
	# de la página de al lado.
	for i in range(SECTORS):
		var angle := step * float(i)
		var dir := Vector2(cos(angle), sin(angle))
		draw_arc(c + dir * _u(GLYPH_RADIUS), _u(30.0), 0.0, TAU, 32, INK_FAINT, _u(1.5), true)


## --- La corona: UN SOLO SÍMBOLO POR SECTOR ---
##
## Se han probado las otras dos maneras y las dos recargaban la página.
## Primero, la forma grande en el centro con los operadores orbitando el
## borde: quedaban como motas fuera del círculo, medio pisando el papel.
## Después, todos en fila y del mismo tamaño: se leía bien pero llenaba
## de tinta un libro cuya gracia es estar casi vacío.
##
## Así que el sector enseña UN símbolo y ya. El libro no es un informe de
## lo que has escrito: es una página de grimorio, y una página de
## grimorio tiene pocas marcas y grandes.
##
## SE ENSEÑA EL SELLO DE FORMA, que es el que dice qué va a aparecer y
## dónde. Los operadores no se dibujan: cambian cuánto, no qué, y la
## diferencia entre una bola y dos no vale una segunda marca en la hoja.
const SIGIL_GLYPH_SIZE: float = 38.0

## Los sellos que SÍ tienen lado al que mirar. Se giran hacia su sector,
## porque su dirección es información de verdad: hacia dónde sale.
## El resto se dibujan tal cual — un corro no apunta a ningún sitio, y
## una levitación apunta hacia arriba pase lo que pase.
const DIRECTIONAL: Array = ["flecha"]

## Un glifo por cada componente dibujado, en su sector. El anillo sigue
## mostrando solo lo que YA has trazado, no el catálogo de lo posible:
## la opción menos explicativa y más misteriosa, en la línea de Witch
## Hat Atelier.
##
## Los glifos de la corona van SIN TEÑIR, todos con la tinta del libro.
## El color es cosa del núcleo: allí dice qué elemento es, y si aquí
## también hubiera colores dejaría de significar eso.
## Dónde cae el glifo de un sector: en el círculo impreso si la lámina lo trae, y si no en la corona de siempre.
func _slot_pos(c: Vector2, dir: Vector2) -> Vector2:
	var huecos: Dictionary = _libro().get("huecos", {})
	var i: int = _sector_idx(dir)
	if huecos.has(i):
		return _on_page(huecos[i])
	return c + dir * _u(GLYPH_RADIUS)


func _draw_components(c: Vector2) -> void:
	var caster := _spellcaster()
	if caster == null:
		return

	for component in caster.components():
		var dir: Vector2 = component["direction"]
		var pos: Vector2 = _slot_pos(c, dir)
		var sigils: Array = component["sigils"]

		# La ranura ocupada se marca solo con su aro, un poco más firme que
		# el de las vacías. El lavado de tinta que llevaba dentro era una
		# mancha gris más en una página que ya tiene bastante dibujo.
		if _hueco_tex == null:         # con aro propio (lámina bosque) el hueco ya se ve marcado
			draw_arc(pos, _u(27.0 if _libro().is_empty() else 56.0), 0.0, TAU, 32, INK_SOFT, _u(1.5), true)

		_draw_sector_sigil(pos, dir, sigils)


## El símbolo del sector: el sello de FORMA si lo hay, y si no el primero
## que haya.
##
## MANDA EL ORDEN DE LA TABLA, no el orden en que trazaste. Se recorre
## Sigils.FORM y se coge el primero que esté escrito en este sector, así
## que "flecha + repetición" y "repetición + flecha" —que hacen
## exactamente lo mismo— se dibujan igual. Cogiendo el primero del trazo,
## dos hechizos idénticos se verían distintos según cómo te salieron, y
## eso enseña que hay una diferencia donde no la hay.
func _draw_sector_sigil(pos: Vector2, dir: Vector2, sigils: Array) -> void:
	if sigils.is_empty():
		return

	var chosen: String = sigils[0]
	for sigil_name in Sigils.FORM:
		if sigils.has(sigil_name):
			chosen = sigil_name
			break

	var glyph_size: float = _u(SIGIL_GLYPH_SIZE if _libro().is_empty() else 76.0)
	var glyph: Texture2D = Sigils.GLYPHS.get(chosen)

	if glyph == null:
		# Sello sin lámina: hoy solo pilar, que está de retirada. Se
		# dibuja con el trazo a mano de antes.
		_draw_legacy_form_glyph(chosen, pos, dir)
	else:
		# 16/10 (Pablo): TODOS los glifos del sector se pintan apuntando al centro, igual que se trazan (GestureLibrary.giro_glifo).
		# La flecha deja de ser la excepción: la dirección la da el sector, no el dibujo.
		# 18/10: ᛁ NO se gira hacia el centro: su dirección la da el eje (linea_x = ancho, horizontal; linea_z = fondo, vertical), no el hueco.
		var angulo: float = EjesRecetaUi.giro_linea(chosen) if EjesRecetaUi.exenta_del_giro(chosen) else GestureLibrary.giro_glifo(dir)
		_draw_texture_rotated(glyph, pos, glyph_size, angulo, INK)


## El respaldo para los sellos de forma que no tienen lámina. Queda uno
## —pilar— y se va; cuando salga de FORM, esto y los tres trazos de abajo
## se pueden borrar de una vez.
func _draw_legacy_form_glyph(sigil_name: String, pos: Vector2, dir: Vector2) -> void:
	match sigil_name:
		"pilar":
			_draw_pillar_glyph(pos, dir)
		"barrera":
			_draw_barrier_glyph(pos, dir)
		_:
			_draw_arrow_glyph(pos, dir)


## Todos los glifos se construyen girando la propia dirección, nunca con
## coordenadas fijas: así salen igual de bien en las diagonales que en
## los ejes, sin un caso especial por sector.

## Flecha: una línea con punta, apuntando hacia fuera.
func _draw_arrow_glyph(pos: Vector2, dir: Vector2) -> void:
	var tip := pos + dir * _u(15.0)
	draw_line(pos - dir * _u(15.0), tip, INK, _u(3.0))
	draw_line(tip, tip + dir.rotated(PI * 0.8) * _u(10.0), INK, _u(3.0))
	draw_line(tip, tip + dir.rotated(-PI * 0.8) * _u(10.0), INK, _u(3.0))


## Pilar: una columna atravesada, plantada de lado a lado del sector.
func _draw_pillar_glyph(pos: Vector2, dir: Vector2) -> void:
	var across := dir.rotated(PI * 0.5)
	var largo := dir * _u(13.0)
	var ancho := across * _u(9.0)
	draw_line(pos - largo, pos + largo, INK, _u(6.0))
	draw_line(pos + largo - ancho, pos + largo + ancho, INK, _u(3.0))
	draw_line(pos - largo - ancho, pos - largo + ancho, INK, _u(3.0))


## Barrera: un muro de lado, perpendicular a la dirección — la forma de
## algo puesto delante de ti para pararte lo que venga.
func _draw_barrier_glyph(pos: Vector2, dir: Vector2) -> void:
	var across := dir.rotated(PI * 0.5)
	var ala := across * _u(15.0)
	var canto := dir * _u(6.0)
	draw_line(pos - ala, pos + ala, INK, _u(5.0))
	draw_line(pos - ala - canto, pos - ala + canto, INK, _u(3.0))
	draw_line(pos + ala - canto, pos + ala + canto, INK, _u(3.0))


func _draw_hint(c: Vector2) -> void:
	if is_recording:
		_draw_record_banner(c)
		return

	# DOS LÍNEAS, NO TRES. La ventana mide 648 px de alto: con el centro
	# en 324 y el aro acabando en 574, una tercera línea caería en 652 y
	# no se vería. Es exactamente el fallo que ya tuvimos con la fila de
	# sellos del modo grabación, y por eso el número está escrito aquí.
	# Si el último gesto falló, la primera línea lo dice (en rojo, durante un
	# momento): "no reconocido, se parece a X". Una pista de consola no la lee
	# quien juega.
	var lanzador := _spellcaster()
	if lanzador and Time.get_ticks_msec() < lanzador.feedback_until:
		_draw_centered_text(c + Vector2(0, _u(RADIUS + 34.0)),
			lanzador.feedback_text, RECORD_INK)
	else:
		_draw_centered_text(c + Vector2(0, _u(RADIUS + 34.0)),
			"T cierra y lanza · 1 2 3 pasan página", INK_SOFT)
	_draw_centered_text(c + Vector2(0, _u(RADIUS + 56.0)),
		"fuera del libro 1 2 3 lanzan · clic derecho deshace", INK_SOFT)


## En grabación el libro se viste de otro color, para que no haya duda
## de que lo que dibujas no va a lanzar nada.
##
## VA PEGADO A LA ESQUINA, no debajo del anillo, y es una corrección de
## un fallo real: el anillo mide 250 de radio y se centra en la
## pantalla, así que colgar cuatro líneas por debajo las mandaba a y=650
## y y=672 — fuera de una ventana de 648 px de alto. Resultado: la fila
## de sellos y la ayuda de las flechas existían pero NO SE VEÍAN, y con
## ellas los tres últimos gestos, que son los que no tienen tecla.
##
## Las esquinas están siempre libres porque el anillo es un círculo en
## el medio, y no dependen de lo alta que sea la ventana.
const RECORD_MARGIN: Vector2 = Vector2(24.0, 32.0)
const RECORD_LINE: float = 22.0


func _draw_record_banner(_c: Vector2) -> void:
	var gesture_name: String = GestureLibrary.RECORDABLE[record_index]
	var count: int = library.sample_count(gesture_name)

	var y: float = RECORD_MARGIN.y

	_draw_left_text(Vector2(RECORD_MARGIN.x, y),
		"MODO GRABACIÓN — dibujar aquí no lanza nada", RECORD_INK)
	y += RECORD_LINE * 1.3

	_draw_left_text(Vector2(RECORD_MARGIN.x, y),
		"Grabando: %s   (%d muestras)" % [gesture_name, count], RECORD_INK)
	y += RECORD_LINE * 1.3

	# Dos filas: arriba los elementos, abajo los sellos. Enseña la
	# división que de verdad importa —los dos lados nunca compiten entre
	# sí al reconocer— y el número de tecla es el de la lista.
	_draw_record_row(y, 0, GestureLibrary.ELEMENTS.size())
	y += RECORD_LINE
	_draw_record_row(y, GestureLibrary.ELEMENTS.size(),
		GestureLibrary.RECORDABLE.size())
	y += RECORD_LINE * 1.3

	# Las flechas van las primeras y solas en su línea: son la ÚNICA
	# forma de llegar a los gestos del 10 en adelante, que no tienen
	# tecla numérica.
	_draw_left_text(Vector2(RECORD_MARGIN.x, y),
		"←  →   elegir gesto  (los últimos tres solo se alcanzan así)",
		RECORD_INK)
	y += RECORD_LINE

	var help := "RETROCESO borra la última muestra  ·  SUPR borra todas  ·  G sale"
	if delete_armed:
		help = "¿SUPR otra vez para borrar TODAS las de '%s'?" % gesture_name
	_draw_left_text(Vector2(RECORD_MARGIN.x, y), help,
		RECORD_INK if delete_armed else INK_SOFT)


func _draw_left_text(pos: Vector2, text: String, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)


## Un tramo de la lista de grabables. El seleccionado va entre corchetes
## para que se vea de un vistazo cuál estás grabando, que con doce
## nombres seguidos deja de ser evidente.
func _draw_record_row(y: float, from: int, to: int) -> void:
	var names: PackedStringArray = []
	for i in range(from, to):
		var label: String = GestureLibrary.RECORDABLE[i]
		if i < 9:
			label = "%d %s" % [i + 1, label]
		names.append("[%s]" % label if i == record_index else label)

	_draw_left_text(Vector2(RECORD_MARGIN.x, y), " · ".join(names), INK_SOFT)


## ThemeDB.fallback_font es la fuente que Godot trae de serie. Usarla
## evita tener que añadir un archivo de fuente al proyecto solo para
## escribir cuatro palabras.
func _draw_centered_text(pos: Vector2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var tam := _u_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	draw_string(font, pos - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)


## El libro es interfaz: no tiene sitio en el mundo desde el que sonar.
##
## Se usa al JUGADOR como altavoz, y no es un apaño: lo que suena al
## abrir el grimorio es el grimorio del mago, que está donde está él. Si
## algún día la cámara deja de seguirle, seguirá siendo el sitio
## correcto.
## 13/10 (M4): el jugador ya es 3D, así que `as Node2D` daba null y los sonidos del libro no tenían dónde sonar. `Sfx.play` acepta
## cualquier Node desde M4 (si es Node3D suena posicional), así que se devuelve el nodo tal cual.
func _oyente() -> Node:
	return get_tree().get_first_node_in_group("player")


## --- Las pestañas de las páginas ---

## Tres marcas encima del aro. Dicen tres cosas de un vistazo y ninguna
## con palabras: en cuál estás (la grande), cuáles tienen algo preparado
## (las rellenas) y DE QUÉ son (el color del elemento).
##
## El color es lo que las hace útiles de verdad. Con tres pestañas grises
## hay que abrir el libro para saber qué llevas; con una naranja, una
## celeste y una amarilla, se sabe desde fuera con qué tecla se lanza
## qué. Es la misma idea que el anillo: enseñar lo que YA has hecho, sin
## explicar lo que se podría hacer.
const PAGE_TAB_RADIUS: float = 13.0
const PAGE_TAB_GAP: float = 38.0


func _draw_pages(c: Vector2) -> void:
	var caster := _spellcaster()
	if caster == null:
		return

	var total: int = Repertoire.pages_available(caster.PAGES)     # solo las páginas que ya tienes
	var arriba: Vector2 = c - Vector2(0.0, _u(RADIUS + 34.0))

	for i in range(total):
		var x: float = (float(i) - float(total - 1) * 0.5) * _u(PAGE_TAB_GAP)
		var centro: Vector2 = arriba + Vector2(x, 0.0)
		var activa: bool = i == caster.page
		var radio: float = _u(PAGE_TAB_RADIUS) * (1.25 if activa else 1.0)

		var datos: RuneData = caster.page_element_data(i)
		if datos != null:
			# RELLENA solo si la página está LISTA —elemento Y dirección—,
			# y a medias si solo tiene el elemento. La diferencia importa:
			# una página con fuego pero sin hacia dónde no lanza nada, y
			# enterarse al pulsar la tecla en mitad de un combate es la
			# peor forma de descubrirlo.
			var tinte: Color = datos.color
			if not caster.page_ready(i):
				tinte.a = 0.3
			elif not activa:
				tinte = tinte.darkened(0.45)
			draw_circle(centro, radio, tinte)

		draw_arc(centro, radio, 0.0, TAU, 24,
			INK if activa else INK_SOFT, _u(2.0 if activa else 1.0), true)

		# La recarga de la página: un arco rojo por fuera, que se va vaciando.
		var resto: float = caster.page_cooldown_fraction(i)
		if resto > 0.0:
			draw_arc(centro, radio + _u(4.0), -PI * 0.5, -PI * 0.5 + TAU * resto, 24,
				RECORD_INK, _u(3.0), true)

		_draw_centered_text(centro + Vector2(0.0, _u(5.0)), str(i + 1),
			INK if activa else INK_SOFT)

	# El contador de sellos, a la derecha de las pestañas. Solo si el nivel
	# fija un tope; en rojo cuando ya no cabe ninguno más, porque el rechazo
	# de un sello solo suena y se imprime por consola, y quien juega no mira
	# la consola.
	var limite: int = Repertoire.max_sigils_per_page
	if limite > 0:
		var usados: int = caster.sigils_used()
		draw_string(ThemeDB.fallback_font,
			arriba + Vector2(_u(PAGE_TAB_GAP) * (float(total) * 0.5 + 0.6), _u(5.0)),
			"sellos %d/%d" % [usados, limite], HORIZONTAL_ALIGNMENT_LEFT, -1,
			_u_font(), RECORD_INK if usados >= limite else INK_SOFT)
