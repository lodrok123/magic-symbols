extends Node2D

## BLOCKOUT DEL MICRONIVEL: EL VIEJO MOLINO (15 x 12).
##
## Es el mapa lógico del documento de producción, tal cual. No es arte:
## el suelo llano es un rombo de color por zona, los muros son prismas
## oscuros, y lo que SÍ es del juego (hierba, agua, placas, puerta, pira,
## arquero) son las piezas reales, con sus reacciones reales. Lo que se
## prueba aquí es el nivel, no el decorado.
##
## SE JUEGA CON F6 (ejecutar escena actual). La escena principal del
## proyecto sigue siendo IsoTest y no se ha tocado.
##
## EL MAPA ES UN DATO. Cambiar el nivel es cambiar letras de MAPA, no
## código: cada letra dice qué hay en esa casilla.
##
##   #  muro / bosque físico          S  inicio
##   1-8  zonas del recorrido         ~  agua (WaterBlock)
##   H  hierba (se anda)              G  hierba tupida: cierra el paso
##   F  fuego fijo (antorcha)         W  punto de enseñanza del viento
##   C  placa conductora              D  puerta eléctrica
##   A  arquero                       P  pira final (encenderla gana)
##   E  salida (tocarla gana)
##
##   B  barrera de fuego: arde y BLOQUEA el paso; solo el agua la apaga
##   T  antorcha (fuego fijo, no bloquea): el viento que la cruza se lleva el fuego
##   Q  puerta: se abre para siempre con un hechizo de rayo
##   X  puerta final: se abre sola cuando están hechas todas las TAREAS
##      (fuego apagado, puerta de agua abierta y pira encendida)
const MAPA: PackedStringArray = [
	"###############",
	"#S111#333#A666#",
	"#11H1#333#6A66#",
	"#111G22F3#66A6#",
	"####22WFB44D###",
	"#555Q###4~~C77#",
	"#5~5C554T~~~7P#",
	"#5~~~55#44C477#",
	"#555~55###X####",
	"###555#8884888#",
	"#######8H~C8E8#",
	"###############",
]

## --- LA PROGRESIÓN DE RUNAS ---
##
## Sigue las etapas del documento: Z1 solo tiene Fuego, Z2 trae el Agua y
## el segundo sello, Z3 el Viento, Z4 el Rayo. Entrar en una zona
## desbloquea lo suyo Y LO DE LAS ANTERIORES: si te saltas la Z3 por el
## camino de al lado no te quedas sin viento para el examen final.
##
## Ponlo en false para probar con todo el conjunto del test (4 elementos
## x 2 sellos) desde el primer paso. Es lo que hace falta, por ejemplo,
## para el bloque A del playtest (identificar los 8 hechizos).
const DESBLOQUEO_POR_ZONA: bool = false

## Lo ÚNICO usable y visible en el libro cuando DESBLOQUEO_POR_ZONA es false.
## Todo lo que no esté aquí no se dibuja en la leyenda y se rechaza al
## dibujarlo. Sellos = elementos; glifos = flecha, barrera...
const SELLOS_TEST: PackedStringArray = ["fuego", "agua", "viento", "rayo"]
const GLIFOS_TEST: PackedStringArray = ["flecha", "barrera", "pilar", "levitacion"]

const DESBLOQUEOS: Dictionary = {
	"1": {"elementos": ["fuego"], "sellos": ["flecha"]},
	"2": {"elementos": ["agua"], "sellos": ["barrera"]},
	"3": {"elementos": ["viento"], "sellos": []},
	"4": {"elementos": ["rayo"], "sellos": []},
}

const NEUTRAL_SCENE: PackedScene = preload("res://NeutralBlock.tscn")
const GRASS_SCENE: PackedScene = preload("res://GrassBlock.tscn")
const WATER_SCENE: PackedScene = preload("res://WaterBlock.tscn")
const BRAZIER_SCENE: PackedScene = preload("res://Brazier.tscn")
const ARCHER_SCENE: PackedScene = preload("res://Archer.tscn")
const GOAL_SCENE: PackedScene = preload("res://Goal.tscn")

## Igual que en IsoTest: el rombo crece hacia abajo y a los dos lados
## desde la casilla (0,0), así que hay que desplazarlo.
const ORIGEN: Vector2 = Vector2(700.0, 60.0)

## Cámara: los mismos valores que IsoTest, para que las distancias se
## sientan igual que en el nivel que ya conoces.
const ZOOM: float = 1.45
const MARGEN: float = 40.0
const SEGUIMIENTO: float = 6.0

## Un color por zona, apagado, para que se lea el recorrido sin distraer.
const COLOR_ZONA: Dictionary = {
	"1": Color(0.66, 0.80, 0.58),
	"2": Color(0.58, 0.74, 0.88),
	"3": Color(0.88, 0.86, 0.58),
	"4": Color(0.88, 0.68, 0.48),
	"5": Color(0.74, 0.64, 0.84),
	"6": Color(0.88, 0.58, 0.58),
	"7": Color(0.62, 0.86, 0.82),
	"8": Color(0.82, 0.82, 0.82),
}
## El suelo que no es de ninguna zona (inicio, transiciones, marcadores).
const COLOR_NEUTRO: Color = Color(0.78, 0.78, 0.74)

const MOSTRAR_ZONAS: bool = true

## Cuánto del rombo de la casilla ocupa el cuerpo de un MURO (1.0 = entero). Un
## pelo menos que la casilla evita que el jugador se enganche en las esquinas al
## rozar un muro; la rendija entre dos muros (unos 3 px) sigue sin dejar pasar.
const ENCAJE_MURO: float = 0.93

## Las letras nuevas ocupan una casilla de una zona: esto dice de cuál, para
## que el suelo lleve su color, el rótulo de la zona no se descentre y pisarlas
## cuente como estar en esa zona.
const ZONA_DE: Dictionary = {"B": "4", "T": "4", "Q": "2", "X": "4"}

## ¿Encender la pira gana la partida (como en el juego normal)? En el test la
## pira es una TAREA más y la partida se gana en la salida, tras la puerta
## final. Ponlo en true para volver a lo de antes (y entonces la pira deja de
## contar como tarea).
const PIRA_GANA: bool = false

const NOMBRE_TAREA: Dictionary = {
	"fuego": "Fuego apagado",
	"agua": "Puerta",
	"pira": "Pira encendida",
}

## Los hechizos con dirección salen hacia el RATÓN, no hacia el sector donde
## se dibujó el sello. Ver Repertoire.aim_with_mouse.
const APUNTAR_CON_RATON: bool = true

## Cuántos sellos caben en cada página en este test: 1 elemento + 3 sellos.
## Es lo que impide "llenar el círculo de flechas", que no es lo que se
## prueba. 0 quita el límite.
const LIMITE_SELLOS: int = 3


## Paleta para poner runas con un clic, sin dibujarlas (ver rune_palette.gd). Solo
## para pruebas, mientras los trazos de los glifos nuevos no estén definidos.
const PALETA_RUNAS: bool = true


## --- El puntero ---
##
## El del laboratorio: un círculo con una raya hacia donde apunta el
## ratón. PASABA POR DEBAJO de las texturas porque el orden de dibujo lo
## decide la posición en Y (y_sort) y cualquier bloque o mata con la Y
## algo mayor lo tapaba. `z_index` manda sobre y_sort —lo dice también
## iso_test.gd—, así que con z_index alto siempre se pinta por encima.
##
## La raya apunta al ratón, que es hacia donde saldrán los hechizos con
## dirección (APUNTAR_CON_RATON).
class Puntero extends Node2D:
	var apunta: Vector2 = Vector2.RIGHT

	func _process(_delta: float) -> void:
		var a: Vector2 = get_global_mouse_position() - global_position
		if a != Vector2.ZERO:
			apunta = a.normalized()
		queue_redraw()

	func _draw() -> void:
		# Un contorno oscuro debajo: sobre una losa clara el blanco solo
		# desaparecía.
		draw_circle(Vector2.ZERO, 11.0, Color(0.05, 0.05, 0.08, 0.7))
		draw_circle(Vector2.ZERO, 9.0, Color(0.85, 0.80, 0.95, 0.98))
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(1, 1, 1, 0.7), 1.5, true)
		draw_line(apunta * 16.0, apunta * 34.0, Color(0.05, 0.05, 0.08, 0.7), 5.0, true)
		draw_line(apunta * 16.0, apunta * 34.0, Color(1, 1, 1, 0.95), 2.5, true)


## Un muro: prisma oscuro, sin textura. Se dibuja hacia ARRIBA desde la
## casilla, pero el nodo se queda a ras de suelo para que y_sort ordene
## por la casilla y no por lo alto que sea.
class Muro extends Node2D:
	const ALTO: float = 44.0
	const CARA_SUP: Color = Color(0.20, 0.36, 0.22)
	const CARA_IZQ: Color = Color(0.11, 0.21, 0.13)
	const CARA_DER: Color = Color(0.14, 0.27, 0.16)

	func _draw() -> void:
		var s: Vector2 = IsoGrid.STEP
		var b := PackedVector2Array([
			Vector2(0.0, -s.y), Vector2(s.x, 0.0), Vector2(0.0, s.y), Vector2(-s.x, 0.0)])
		var t := PackedVector2Array()
		for p in b:
			t.append(p - Vector2(0.0, ALTO))
		draw_colored_polygon(PackedVector2Array([t[3], t[2], b[2], b[3]]), CARA_IZQ)
		draw_colored_polygon(PackedVector2Array([t[2], t[1], b[1], b[2]]), CARA_DER)
		draw_colored_polygon(t, CARA_SUP)


## Cuerpo sólido que solo existe mientras arde lo que tiene al lado. Cuelga de
## la hoguera: cuando el agua la apaga, en el siguiente paso de física deja
## de estorbar. Es lo que convierte un fuego fijo en un OBSTÁCULO.
class Bloqueo extends StaticBody2D:
	var fuente: Node = null
	var _forma: CollisionShape2D = null
	var _activo: bool = true

	func _ready() -> void:
		_forma = CollisionShape2D.new()
		_forma.shape = IsoGrid.footprint(0.95)
		add_child(_forma)

	func _physics_process(_delta: float) -> void:
		var arde: bool = is_instance_valid(fuente) and bool(fuente.get("is_lit"))
		if arde != _activo:
			_activo = arde
			_forma.set_deferred("disabled", not arde)


## Puerta que se abre con agua, y se queda abierta: es una tarea hecha, no un
## cerrojo con reloj como la eléctrica. Reutiliza el modelo de Door entero.
class PuertaAgua extends Door:
	func _ready() -> void:
		super()
		visual.modulate = Color(0.55, 0.80, 1.15)   # azulada: se lee "agua"

	func on_spell_hit(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
		if is_open or rune_data == null or not rune_data.tags.has("rayo"):
			return
		is_open = true
		_apply()
		BlockFx.burst(self, "chispas")
		Sfx.play(self, "puerta_abre")
		print("La puerta se abre.")

	func _process(_delta: float) -> void:
		pass   # no se cierra sola


## La puerta especial: ningún hechizo la abre. Pregunta a `condicion` cada
## fotograma y, cuando es cierta, se abre para siempre.
class PuertaFinal extends Door:
	var condicion: Callable = Callable()

	func _ready() -> void:
		super()
		visual.modulate = Color(1.20, 0.95, 0.50)   # dorada: no es una puerta normal

	func on_spell_hit(_rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> void:
		pass   # ni la electricidad ni nada: solo las tareas

	func _process(_delta: float) -> void:
		if is_open or not condicion.is_valid():
			return
		if condicion.call():
			is_open = true
			_apply()
			BlockFx.burst(self, "chispas")
			Sfx.play(self, "puerta_abre")
			print("La puerta final se abre.")


## Los rótulos de zona y los marcadores sin pieza (S y W). Van en su
## propio nodo con z_index para que no los tape ningún suelo.
class Rotulos extends Node2D:
	var textos: Array = []   # cada uno: {"pos": Vector2, "texto": String, "tam": int}

	func _draw() -> void:
		var fuente: Font = ThemeDB.fallback_font
		for t in textos:
			var ancho: float = fuente.get_string_size(t["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, t["tam"]).x
			draw_string(fuente, t["pos"] - Vector2(ancho * 0.5, 0.0), t["texto"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, t["tam"], Color(0.1, 0.1, 0.12, 0.65))


## El suelo llano: un rombo blanco del tamaño exacto de la casilla, con el
## borde un poco más oscuro para que se vea la rejilla. Se teñe con
## self_modulate, porque NeutralBlock usa `modulate` para enseñar que el
## suelo está mojado o helado y no hay que pisárselo.
static var _rombo_textura: ImageTexture = null

var player: CharacterBody2D = null
var _inicio: Vector2i = Vector2i(1, 1)
var _zona_actual: String = ""
var _mayor_zona: int = 0
var _hud: Label = null
var _aviso: Label = null
var _tween: Tween = null

# Las piezas cuyo estado cuenta como TAREA (sin tipo: son escenas con script).
var _fuego_barrera = null
var _puerta_agua: Door = null
var _pira = null
var _puerta_final: Door = null
var _tareas_hechas: Dictionary = {}
var _final_avisada: bool = false

## Segundos de TIEMPO DE JUEGO (con el libro abierto no corre) en cada zona, para
## el diario de la prueba (ver PlayLog).
var _tiempos: Dictionary = {}
var _tiempos_sucios: bool = false


func _ready() -> void:
	y_sort_enabled = true

	PlayLog.nueva_partida()
	PlayLog.volcado = Callable(self, "_volcar_tiempos")

	_repertorio_inicial()
	_construir_mapa()
	_crear_jugador()
	_crear_interfaz()
	_colocar_camara()
	_refrescar_hud()

	# La progresión de runas (qué se consigue y cuándo). Va al final: al nacer
	# fija las runas iniciales, y tiene que hacerlo DESPUÉS de _repertorio_inicial.
	add_child(Progresion.new())


## Al salir del nivel (también al reiniciar con R) se guarda el resumen de tiempos.
func _exit_tree() -> void:
	_volcar_tiempos()


## Escribe en el diario los segundos pasados en cada zona, si ha cambiado algo
## desde la última vez.
func _volcar_tiempos() -> void:
	if not _tiempos_sucios:
		return
	_tiempos_sucios = false
	var redondeado: Dictionary = {}
	for z in _tiempos:
		redondeado["Z" + str(z)] = snappedf(_tiempos[z], 0.1)
	PlayLog.event("tiempo_por_zona", redondeado)


## --- El repertorio ---

func _repertorio_inicial() -> void:
	Repertoire.max_sigils_per_page = LIMITE_SELLOS
	Repertoire.aim_with_mouse = APUNTAR_CON_RATON
	if DESBLOQUEO_POR_ZONA:
		Repertoire.set_active(PackedStringArray(), PackedStringArray())
		# La zona 1 se abre sin aviso: es donde empiezas.
		_desbloquear_hasta(1, false)
		_mayor_zona = 1
	else:
		Repertoire.set_active(SELLOS_TEST, GLIFOS_TEST)


func _desbloquear_hasta(zona: int, avisar: bool) -> void:
	for n in range(1, zona + 1):
		var d: Dictionary = DESBLOQUEOS.get(str(n), {})
		for e in d.get("elementos", []):
			if Repertoire.unlock_element(e) and avisar:
				_avisar("Nueva runa: %s" % String(e).capitalize())
		for s in d.get("sellos", []):
			if Repertoire.unlock_sigil(s) and avisar:
				_avisar("Nuevo sello: %s" % String(s).capitalize())


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	_actualizar_tareas()

	# El tiempo de juego se suma a la zona en la que estás.
	if _zona_actual != "":
		_tiempos[_zona_actual] = float(_tiempos.get(_zona_actual, 0.0)) + delta
		_tiempos_sucios = true

	var letra: String = _letra(IsoGrid.to_cell(player.position - ORIGEN))
	letra = ZONA_DE.get(letra, letra)
	if letra < "1" or letra > "8" or letra == _zona_actual:
		return

	PlayLog.event("zona", {"sale": _zona_actual, "entra": letra,
		"segundos_en_la_anterior": snappedf(float(_tiempos.get(_zona_actual, 0.0)), 0.1)})
	_zona_actual = letra
	PlayLog.zona = letra
	if DESBLOQUEO_POR_ZONA and int(letra) > _mayor_zona:
		_mayor_zona = int(letra)
		_desbloquear_hasta(_mayor_zona, true)
	_refrescar_hud()


## --- Construcción del mapa ---

func _letra(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= MAPA.size():
		return ""
	var linea: String = MAPA[cell.y]
	if cell.x < 0 or cell.x >= linea.length():
		return ""
	return linea[cell.x]


func _at(cell: Vector2i) -> Vector2:
	return ORIGEN + IsoGrid.to_screen(cell)


func _construir_mapa() -> void:
	var rotulos := Rotulos.new()
	rotulos.z_index = 5
	add_child(rotulos)

	# Los centros de cada zona, para rotularla.
	var suma: Dictionary = {}
	var cuenta: Dictionary = {}

	for y in range(MAPA.size()):
		var linea: String = MAPA[y]
		for x in range(linea.length()):
			var cell := Vector2i(x, y)
			var letra: String = linea[x]

			match letra:
				"#":
					_muro(cell)
				"~":
					_colocar(WATER_SCENE.instantiate(), cell, true)
				"H":
					_colocar(GRASS_SCENE.instantiate(), cell, true)
				"G":
					var g: Node2D = GRASS_SCENE.instantiate()
					g.initial_state = 1   # GROWN: tupida, cierra el paso
					_colocar(g, cell, true)
				_:
					_suelo(cell, letra)
					_objeto(cell, letra)

			var zona: String = ZONA_DE.get(letra, letra)
			if zona >= "1" and zona <= "8":
				suma[zona] = suma.get(zona, Vector2.ZERO) + _at(cell)
				cuenta[zona] = cuenta.get(zona, 0) + 1
			if letra == "S":
				_inicio = cell
				rotulos.textos.append({"pos": _at(cell) + Vector2(0.0, 6.0), "texto": "S", "tam": 20})
			if letra == "W":
				rotulos.textos.append({"pos": _at(cell) + Vector2(0.0, 6.0), "texto": "W", "tam": 20})

	if MOSTRAR_ZONAS:
		for z in suma:
			rotulos.textos.append({"pos": suma[z] / float(cuenta[z]) + Vector2(0.0, 8.0),
				"texto": "Z" + z, "tam": 26})
	rotulos.queue_redraw()


## Añade una pieza a una casilla. `encajar` cambia sus formas de colisión
## al rombo de la casilla: venían dimensionadas para losas de 52x32 y el
## rombo real mide 116x55, así que sin esto se atraviesa medio bloque.
func _colocar(nodo: Node2D, cell: Vector2i, encajar: bool = false) -> Node2D:
	add_child(nodo)
	nodo.position = _at(cell)
	if encajar:
		for c in [nodo.get_node_or_null("CollisionShape2D"),
				nodo.get_node_or_null("SolidBody/CollisionShape2D")]:
			if c:
				c.shape = IsoGrid.diamond()
				c.position = Vector2.ZERO
	return nodo


## El suelo llano de una casilla: un NeutralBlock de verdad (es suelo, se
## moja, se hiela, deja andar) con el dibujo cambiado por un rombo de color.
func _suelo(cell: Vector2i, letra: String) -> void:
	var bloque: Node2D = _colocar(NEUTRAL_SCENE.instantiate(), cell, true)
	var visual: Sprite2D = bloque.get_node("Visual")
	visual.texture = _rombo()
	visual.self_modulate = COLOR_ZONA.get(ZONA_DE.get(letra, letra), COLOR_NEUTRO)


func _rombo() -> ImageTexture:
	if _rombo_textura != null:
		return _rombo_textura

	var w: int = int(IsoGrid.TILE.x)
	var h: int = int(IsoGrid.TILE.y)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cx: float = float(w - 1) * 0.5
	var cy: float = float(h - 1) * 0.5
	for py in range(h):
		for px in range(w):
			# Distancia "de rombo": 1.0 justo en el borde.
			var d: float = absf(float(px) - cx) / (float(w) * 0.5) \
				+ absf(float(py) - cy) / (float(h) * 0.5)
			if d <= 1.0:
				img.set_pixel(px, py, Color(0.82, 0.82, 0.82) if d > 0.94 else Color.WHITE)
	_rombo_textura = ImageTexture.create_from_image(img)
	return _rombo_textura


func _muro(cell: Vector2i) -> void:
	var muro := Muro.new()
	muro.y_sort_enabled = true
	add_child(muro)
	muro.position = _at(cell)

	var cuerpo := StaticBody2D.new()
	var forma := CollisionShape2D.new()
	forma.shape = IsoGrid.footprint(ENCAJE_MURO)
	cuerpo.add_child(forma)
	muro.add_child(cuerpo)


## Lo que hay ENCIMA del suelo, según la letra.
func _objeto(cell: Vector2i, letra: String) -> void:
	match letra:
		"C":
			_colocar(Conductor.make(), cell)
		"D":
			_colocar(Door.make(), cell)
		"F":
			# Fuego fijo: nace encendido y encenderlo NO gana la partida.
			var fuego: Node2D = BRAZIER_SCENE.instantiate()
			fuego.start_lit = true
			fuego.is_goal = false
			_colocar(fuego, cell)
		"P":
			# La pira: encenderla gana solo si PIRA_GANA; si no, es una tarea.
			var pira: Node2D = BRAZIER_SCENE.instantiate()
			pira.is_goal = PIRA_GANA
			_colocar(pira, cell)
			_pira = pira
		"B":
			# Barrera de fuego: como el fuego fijo, pero con un cuerpo sólido
			# mientras arde. Solo el agua la apaga (lo hace la propia hoguera).
			var barrera: Node2D = BRAZIER_SCENE.instantiate()
			barrera.start_lit = true
			barrera.is_goal = false
			_colocar(barrera, cell, true)
			var bloqueo := Bloqueo.new()
			bloqueo.fuente = barrera
			barrera.add_child(bloqueo)
			_fuego_barrera = barrera
		"T":
			# Antorcha: fuego fijo que NO bloquea, para que el viento lo lleve.
			var antorcha: Node2D = BRAZIER_SCENE.instantiate()
			antorcha.start_lit = true
			antorcha.is_goal = false
			_colocar(antorcha, cell)
		"Q":
			var pa := PuertaAgua.new()
			pa.y_sort_enabled = true
			_colocar(pa, cell)
			_puerta_agua = pa
		"X":
			var pf := PuertaFinal.new()
			pf.y_sort_enabled = true
			pf.condicion = Callable(self, "_tareas_completas")
			_colocar(pf, cell)
			_puerta_final = pf
		"A":
			_colocar(ARCHER_SCENE.instantiate(), cell)
		"E":
			_colocar(GOAL_SCENE.instantiate(), cell)


## --- El jugador ---
##
## Se monta con el mismo player.gd de siempre, de modo que la caída, el
## empuje del viento, la vida y el salto funcionan igual que en IsoTest.
## Lo único distinto es lo que se ve: el AnimatedSprite2D va vacío (player.gd
## lo necesita pero no dibuja nada) y el cuerpo es el puntero.
func _crear_jugador() -> void:
	var p := CharacterBody2D.new()
	p.name = "Player"
	p.y_sort_enabled = true
	p.up_direction = Vector2(0.7071068, -0.7071068)
	p.set_script(load("res://player.gd"))

	# Los nombres importan: player.gd los busca por ruta ($Feet, $Shadow...).
	var cuerpo := CollisionShape2D.new()
	cuerpo.name = "CollisionShape2D"
	cuerpo.shape = IsoGrid.footprint(0.42)
	p.add_child(cuerpo)

	var pies := Area2D.new()
	pies.name = "Feet"
	var forma_pies := CollisionShape2D.new()
	forma_pies.name = "CollisionShape2D"
	forma_pies.shape = IsoGrid.footprint(0.30)
	pies.add_child(forma_pies)
	p.add_child(pies)

	var sombra := Sprite2D.new()
	sombra.name = "Shadow"
	sombra.visible = false
	p.add_child(sombra)

	var viejo := Sprite2D.new()
	viejo.name = "Sprite2D"
	p.add_child(viejo)

	var anim := AnimatedSprite2D.new()
	anim.name = "AnimatedSprite2D"
	anim.sprite_frames = SpriteFrames.new()
	p.add_child(anim)

	var caster := Node2D.new()
	caster.name = "Spellcaster"
	caster.set_script(load("res://spellcaster.gd"))
	p.add_child(caster)

	var puntero := Puntero.new()
	puntero.name = "Puntero"
	puntero.z_index = 100
	p.add_child(puntero)

	# La posición ANTES de entrar en el árbol: player.gd apunta su "último
	# sitio seguro" al nacer, y así nace ya en la casilla de inicio.
	p.position = _at(_inicio)
	add_child(p)
	player = p


## --- La interfaz ---

func _crear_interfaz() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	var barra := ProgressBar.new()
	barra.offset_left = 20.0
	barra.offset_top = 20.0
	barra.offset_right = 240.0
	barra.offset_bottom = 48.0
	barra.value = 100.0
	barra.show_percentage = false
	barra.set_script(load("res://health_bar.gd"))
	ui.add_child(barra)

	_hud = Label.new()
	_hud.position = Vector2(20.0, 56.0)
	_hud.add_theme_font_size_override("font_size", 14)
	_hud.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hud.add_theme_constant_override("outline_size", 4)
	ui.add_child(_hud)

	_aviso = Label.new()
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 26)
	_aviso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.modulate.a = 0.0
	_aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_aviso)
	# Los anclajes se fijan YA DENTRO del árbol, que es cuando se sabe cuánto
	# mide la pantalla y los márgenes salen bien.
	_aviso.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_aviso.offset_top = 90.0
	_aviso.offset_bottom = 130.0

	for cartel in [_cartel("¡VICTORIA!", "victory_ui", Color.WHITE),
			_cartel("HAS MUERTO\nPulsa R para reintentar", "gameover_ui", Color(0.9, 0.2, 0.2))]:
		ui.add_child(cartel)
		cartel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Las tres páginas y la voltereta, siempre a la vista (con su recarga).
	var paginas := Control.new()
	paginas.set_script(load("res://page_hud.gd"))
	ui.add_child(paginas)
	paginas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# La paleta de pruebas (F1 la esconde).
	if PALETA_RUNAS:
		var paleta := PanelContainer.new()
		paleta.set_script(load("res://rune_palette.gd"))
		ui.add_child(paleta)

	# El libro: con process_mode ALWAYS, porque congela el árbol al abrirse
	# y tiene que seguir vivo para poder cerrarse.
	var libro := Control.new()
	libro.process_mode = Node.PROCESS_MODE_ALWAYS
	libro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	libro.set_script(load("res://spellbook.gd"))
	ui.add_child(libro)
	libro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Reiniciar con R (siempre activo, también en pausa).
	var control := Node.new()
	control.process_mode = Node.PROCESS_MODE_ALWAYS
	control.set_script(load("res://level_controller.gd"))
	add_child(control)


func _cartel(texto: String, grupo: String, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.visible = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_to_group(grupo)
	return l


func _refrescar_hud() -> void:
	if _hud == null:
		return
	var tareas: Array = []
	var estado: Dictionary = _estado_tareas()
	for k in estado:
		tareas.append("%s %s" % ["[x]" if estado[k] else "[ ]", NOMBRE_TAREA[k]])
	_hud.text = "Zona %s\nElementos: %s\nSellos: %s\nTareas: %s" % [
		_zona_actual if _zona_actual != "" else "1",
		", ".join(Repertoire.active_elements()),
		", ".join(Repertoire.active_sigils()),
		"  ".join(tareas)]


## --- Las tareas ---
##
## Estado de cada tarea AHORA. Una pieza que no existe en el mapa (quitaste su
## letra) cuenta como hecha, para que no quede una puerta imposible de abrir.
func _estado_tareas() -> Dictionary:
	var e: Dictionary = {}
	e["fuego"] = not is_instance_valid(_fuego_barrera) or not bool(_fuego_barrera.get("is_lit"))
	e["agua"] = not is_instance_valid(_puerta_agua) or _puerta_agua.is_open
	if not PIRA_GANA:
		e["pira"] = not is_instance_valid(_pira) or bool(_pira.get("is_lit"))
	return e


func _tareas_completas() -> bool:
	for hecha in _estado_tareas().values():
		if not hecha:
			return false
	return true


## Avisa una sola vez de cada tarea nueva y de la puerta final.
func _actualizar_tareas() -> void:
	var e: Dictionary = _estado_tareas()
	for k in e:
		if e[k] and not _tareas_hechas.get(k, false):
			_tareas_hechas[k] = true
			PlayLog.event("tarea", {"nombre": k})
			_avisar("Tarea hecha: %s" % NOMBRE_TAREA[k])
	if is_instance_valid(_puerta_final) and _puerta_final.is_open and not _final_avisada:
		_final_avisada = true
		_avisar("¡Se abre la puerta final!")


func _avisar(texto: String) -> void:
	_refrescar_hud()
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	# Si llega otro aviso antes de que acabe el anterior, el viejo se cancela:
	# si no, su desvanecido apagaba el texto nuevo a medias.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(1.6)
	_tween.tween_property(_aviso, "modulate:a", 0.0, 0.8)


## --- La cámara ---
##
## Misma que IsoTest: cuelga del jugador y sus límites salen del mapa. Se
## encuadra lo TRANSITABLE (todo menos los muros): así el borde de muros
## queda justo en el filo de la pantalla y no se pasa media vista
## enseñando prismas oscuros.
func _colocar_camara() -> void:
	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = SEGUIMIENTO

	var caja: Rect2 = _limites()
	cam.limit_left = int(caja.position.x)
	cam.limit_top = int(caja.position.y)
	cam.limit_right = int(caja.end.x)
	cam.limit_bottom = int(caja.end.y)

	player.add_child(cam)
	cam.make_current()
	cam.reset_smoothing()


func _limites() -> Rect2:
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)

	for y in range(MAPA.size()):
		var linea: String = MAPA[y]
		for x in range(linea.length()):
			if linea[x] == "#":
				continue
			var p: Vector2 = _at(Vector2i(x, y))
			minimo = minimo.min(p)
			maximo = maximo.max(p)

	var borde := Vector2(IsoGrid.STEP.x + MARGEN, IsoGrid.STEP.y + MARGEN)
	return Rect2(minimo - borde, (maximo - minimo) + borde * 2.0)
