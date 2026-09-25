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

const INK: Color = Color(0.85, 0.78, 0.62)
const INK_SOFT: Color = Color(0.85, 0.78, 0.62, 0.35)
const VEIL: Color = Color(0.04, 0.03, 0.05, 0.72)
const RECORD_INK: Color = Color(1.0, 0.55, 0.35)

## --- Piezas de interfaz ---
## El grimorio ya no se dibuja solo con arcos: el aro, el núcleo y las
## ranuras de sector son sprites del pack de UI. Se siguen pintando con
## draw_texture_rect y no con nodos Sprite2D porque así el tamaño se
## deriva de RADIUS y CORE_RADIUS — cambias una constante y todo el
## libro se reescala solo, sin tocar la escena.
const RING_TEXTURE: Texture2D = preload("res://art/ui/ring.png")
const CORE_TEXTURE: Texture2D = preload("res://art/ui/slot_core.png")
const SLOT_TEXTURE: Texture2D = preload("res://art/ui/slot.png")
const SLOT_EMPTY_TEXTURE: Texture2D = preload("res://art/ui/slot_empty.png")

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
const GESTURE_PAUSE: float = 0.45

var pending_strokes: Array = []
var gesture_countdown: float = 0.0

## Misma distancia mínima entre puntos que usaba el Spellcaster: evita
## guardar cientos de puntos casi pegados cuando mueves el ratón despacio.
const MIN_POINT_DISTANCE: float = 8.0


func _ready() -> void:
	visible = false


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

	if not is_open:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == RECORD_KEY:
			is_recording = not is_recording
			print("Modo grabación: ", "ON" if is_recording else "OFF")
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
	# Si el árbol ya estaba congelado, la pausa es de otro: has muerto o
	# has ganado. Abrir el libro y cerrarlo luego descongelaría esa
	# pantalla, así que en ese caso no se abre.
	if get_tree().paused:
		return

	is_open = true
	visible = true
	stroke = PackedVector2Array()
	pending_strokes = []
	gesture_countdown = 0.0
	is_drawing = false

	var caster := _spellcaster()
	if caster:
		caster.clear_sequence()

	# El árbol se congela: enemigos, temporizadores, incendios. Este nodo
	# sigue vivo porque tiene process_mode = ALWAYS (puesto en la escena).
	get_tree().paused = true
	queue_redraw()


func _close() -> void:
	is_open = false
	visible = false
	is_drawing = false
	pending_strokes = []
	gesture_countdown = 0.0

	# Se descongela ANTES de lanzar, para que el hechizo nazca en un
	# mundo que ya corre: si no, aparecería quieto hasta el siguiente
	# fotograma sin pausa.
	get_tree().paused = false

	var caster := _spellcaster()
	if caster:
		caster.cast_current()


## --- Captura del trazo ---

func _begin_stroke(pos: Vector2) -> void:
	# El trazo tiene que NACER dentro del círculo. Es la regla que hace
	# del círculo algo más que decoración.
	if pos.distance_to(_center()) > RADIUS:
		return

	is_drawing = true
	# Empezar un trazo cancela la cuenta atrás: este trazo forma parte
	# del mismo gesto que los anteriores.
	gesture_countdown = 0.0
	stroke = PackedVector2Array([pos])
	queue_redraw()


func _add_point(pos: Vector2) -> void:
	# Salirse del círculo termina el trazo. Preferimos esto a recortar el
	# punto contra el borde: recortar deformaría el gesto y haría que el
	# reconocimiento fallara sin que se entienda por qué.
	if pos.distance_to(_center()) > RADIUS:
		_end_stroke()
		return

	if stroke.is_empty() or stroke[-1].distance_to(pos) >= MIN_POINT_DISTANCE:
		stroke.append(pos)
		queue_redraw()


## Al soltar el ratón el trazo se guarda, pero el GESTO todavía no está
## cerrado: puede que vengan más trazos. Se arranca la cuenta atrás.
func _end_stroke() -> void:
	if not is_drawing:
		return

	is_drawing = false

	if stroke.size() >= 2:
		pending_strokes.append(stroke)
		gesture_countdown = GESTURE_PAUSE

	stroke = PackedVector2Array()
	queue_redraw()


## Con gestos de varios trazos aparece una pregunta que antes no
## existía: ¿cuándo se ha TERMINADO de dibujar? Ya no vale "al soltar el
## ratón". La respuesta es una pausa: si pasan GESTURE_PAUSE segundos
## sin dibujar, el gesto se da por cerrado. Empezar otro trazo antes de
## que venza lo suma al mismo gesto.
func _process(delta: float) -> void:
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
			caster.add_gesture(pending_strokes, _sector_of_gesture())

	pending_strokes = []
	queue_redraw()


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
	library.add_sample(gesture_name, normalized)

	_save_library()
	delete_armed = false

	print("Guardada muestra de '", gesture_name, "': ",
		library.sample_count(gesture_name), " en total")


func _center() -> Vector2:
	return size * 0.5


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
	if offset.length() < CORE_RADIUS:
		return Vector2.ZERO

	var step := TAU / float(SECTORS)
	var angle := snappedf(offset.angle(), step)
	return Vector2(cos(angle), sin(angle))


## --- Dibujo ---
## Todo el grimorio está pintado con código: arcos, líneas y círculos.
## No usa ninguna imagen, así que cambiar su aspecto es cambiar números
## aquí, y no depende de conseguir arte.

func _draw() -> void:
	var c := _center()

	# Velo oscuro sobre el juego congelado
	draw_rect(Rect2(Vector2.ZERO, size), VEIL)

	_draw_ring(c)
	_draw_sectors(c)
	_draw_core(c)
	_draw_components(c)

	var ink: Color = RECORD_INK if is_recording else INK
	for s in pending_strokes:
		if s.size() >= 2:
			draw_polyline(s, ink, 4.0, true)
	if stroke.size() >= 2:
		draw_polyline(stroke, ink, 4.0, true)

	_draw_hint(c)


func _draw_ring(c: Vector2) -> void:
	_draw_texture_centred(RING_TEXTURE, c, RADIUS * 2.0 + 24.0)


## Dibuja una textura centrada en un punto, con el tamaño que le pidas.
## Todo el libro pasa por aquí, que es lo que permite que cambiar RADIUS
## reescale el conjunto entero.
func _draw_texture_centred(texture: Texture2D, centre: Vector2, size: float, tint := Color.WHITE) -> void:
	var half := size * 0.5
	draw_texture_rect(texture, Rect2(centre - Vector2(half, half), Vector2(size, size)), false, tint)


## El núcleo solo aparece cuando ya has dibujado un elemento, y toma su
## color de la propia ficha del elemento (RuneData.color). Igual que el
## hechizo: esto no sabe qué elementos existen.
func _draw_core(c: Vector2) -> void:
	var caster := _spellcaster()
	if caster == null:
		return

	var element: RuneData = caster.current_element_data()
	if element == null:
		# Sin elemento, la ranura vacía y apagada esperando.
		_draw_texture_centred(SLOT_EMPTY_TEXTURE, c, CORE_RADIUS * 2.0, Color(1, 1, 1, 0.5))
		return

	# La ranura se TIÑE con el color del elemento en vez de tener una
	# textura por elemento: sigue siendo el RuneData quien manda, así que
	# un elemento nuevo se ve bien sin arte nuevo.
	_draw_texture_centred(CORE_TEXTURE, c, CORE_RADIUS * 2.0, element.color)
	# El nombre va DENTRO del núcleo ahora que es grande: fuera chocaría
	# con el anillo del glifo.
	_draw_centered_text(c + Vector2(0, CORE_RADIUS - 28.0), element.display_name, INK)


## Las divisiones entre sectores: van del núcleo al borde, porque el
## núcleo no pertenece a ninguno. Se dibujan en las FRONTERAS (medio
## sector girado) para que cada porción quede centrada en su dirección,
## no partida por una línea justo en medio.
func _draw_sectors(c: Vector2) -> void:
	var step := TAU / float(SECTORS)

	# Las divisiones van en las FRONTERAS (medio sector giradas) para que
	# cada porción quede centrada en su dirección, no partida por una
	# raya justo en medio.
	for i in range(SECTORS):
		var angle := step * (float(i) + 0.5)
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(c + dir * CORE_RADIUS, c + dir * RADIUS, INK_SOFT, 1.0)

	# Una ranura apagada en cada sector: enseña DÓNDE se puede dibujar
	# sin decir QUÉ. El anillo sigue sin ser un catálogo de opciones.
	for i in range(SECTORS):
		var angle := step * float(i)
		var dir := Vector2(cos(angle), sin(angle))
		_draw_texture_centred(SLOT_EMPTY_TEXTURE, c + dir * GLYPH_RADIUS, 52.0, Color(1, 1, 1, 0.25))


## Un glifo por cada componente dibujado, en su sector. El anillo sigue
## mostrando solo lo que YA has trazado, no el catálogo de lo posible:
## la opción menos explicativa y más misteriosa, en la línea de Witch
## Hat Atelier.
func _draw_components(c: Vector2) -> void:
	var caster := _spellcaster()
	if caster == null:
		return

	for component in caster.components():
		var dir: Vector2 = component["direction"]
		var pos: Vector2 = c + dir * GLYPH_RADIUS
		var sigils: Array = component["sigils"]

		_draw_texture_centred(SLOT_TEXTURE, pos, 56.0)

		# El glifo grande es la FORMA que va a tomar. Los operadores
		# (repetición, aumento) no tienen forma propia: modifican a la
		# que haya, así que se muestran como marcas alrededor.
		var operators := 0
		for sigil_name in sigils:
			match sigil_name:
				"flecha":
					_draw_arrow_glyph(pos, dir)
				"pilar":
					_draw_pillar_glyph(pos, dir)
				"barrera":
					_draw_barrier_glyph(pos, dir)
				_:
					operators += 1

		# Una marca por operador apilado, en el borde del círculo.
		for i in range(operators):
			var angle := -PI * 0.5 + float(i) * 0.55
			draw_circle(pos + Vector2(cos(angle), sin(angle)) * 26.0, 4.0, INK)


## Todos los glifos se construyen girando la propia dirección, nunca con
## coordenadas fijas: así salen igual de bien en las diagonales que en
## los ejes, sin un caso especial por sector.

## Flecha: una línea con punta, apuntando hacia fuera.
func _draw_arrow_glyph(pos: Vector2, dir: Vector2) -> void:
	var tip := pos + dir * 15.0
	draw_line(pos - dir * 15.0, tip, INK, 3.0)
	draw_line(tip, tip + dir.rotated(PI * 0.8) * 10.0, INK, 3.0)
	draw_line(tip, tip + dir.rotated(-PI * 0.8) * 10.0, INK, 3.0)


## Pilar: una columna atravesada, plantada de lado a lado del sector.
func _draw_pillar_glyph(pos: Vector2, dir: Vector2) -> void:
	var across := dir.rotated(PI * 0.5)
	draw_line(pos - dir * 13.0, pos + dir * 13.0, INK, 6.0)
	draw_line(pos + dir * 13.0 - across * 9.0, pos + dir * 13.0 + across * 9.0, INK, 3.0)
	draw_line(pos - dir * 13.0 - across * 9.0, pos - dir * 13.0 + across * 9.0, INK, 3.0)


## Barrera: un muro de lado, perpendicular a la dirección — la forma de
## algo puesto delante de ti para pararte lo que venga.
func _draw_barrier_glyph(pos: Vector2, dir: Vector2) -> void:
	var across := dir.rotated(PI * 0.5)
	draw_line(pos - across * 15.0, pos + across * 15.0, INK, 5.0)
	draw_line(pos - across * 15.0 - dir * 6.0, pos - across * 15.0 + dir * 6.0, INK, 3.0)
	draw_line(pos + across * 15.0 - dir * 6.0, pos + across * 15.0 + dir * 6.0, INK, 3.0)


func _draw_hint(c: Vector2) -> void:
	if is_recording:
		_draw_record_banner(c)
		return

	_draw_centered_text(c + Vector2(0, RADIUS + 34.0), "T para cerrar y lanzar", INK_SOFT)
	_draw_centered_text(c + Vector2(0, RADIUS + 56.0), "clic derecho deshace", INK_SOFT)


## En grabación el libro se viste de otro color, para que no haya duda
## de que lo que dibujas no va a lanzar nada.
func _draw_record_banner(c: Vector2) -> void:
	var gesture_name: String = GestureLibrary.RECORDABLE[record_index]
	var count: int = library.sample_count(gesture_name)

	_draw_centered_text(c + Vector2(0, RADIUS + 34.0),
		"GRABANDO: %s  (%d muestras)" % [gesture_name, count], RECORD_INK)

	# Ya no cabe la lista entera en una línea, así que se dibuja en dos:
	# arriba los elementos, abajo los sellos. Además de caber, enseña la
	# división que de verdad importa —los dos lados nunca compiten entre
	# sí al reconocer—, y el número de tecla sigue siendo el de la lista.
	_draw_record_row(c, RADIUS + 56.0, 0, GestureLibrary.ELEMENTS.size())
	_draw_record_row(c, RADIUS + 76.0,
		GestureLibrary.ELEMENTS.size(), GestureLibrary.RECORDABLE.size())

	var help := "← → cambiar  ·  RETROCESO borra la última  ·  SUPR borra todas  ·  G sale"
	if delete_armed:
		help = "¿SUPR otra vez para borrar TODAS las de '%s'?" % gesture_name
	_draw_centered_text(c + Vector2(0, RADIUS + 98.0), help, RECORD_INK if delete_armed else INK_SOFT)


## Un tramo de la lista de grabables. El seleccionado va entre corchetes
## para que se vea de un vistazo cuál estás grabando, que con doce
## nombres seguidos deja de ser evidente.
func _draw_record_row(c: Vector2, y: float, from: int, to: int) -> void:
	var names: PackedStringArray = []
	for i in range(from, to):
		var label: String = GestureLibrary.RECORDABLE[i]
		if i < 9:
			label = "%d %s" % [i + 1, label]
		names.append("[%s]" % label if i == record_index else label)

	_draw_centered_text(c + Vector2(0, y), " · ".join(names), INK_SOFT)


## ThemeDB.fallback_font es la fuente que Godot trae de serie. Usarla
## evita tener que añadir un archivo de fuente al proyecto solo para
## escribir cuatro palabras.
func _draw_centered_text(pos: Vector2, text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, pos - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
