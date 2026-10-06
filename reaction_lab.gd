extends Node2D

## LABORATORIO DE REACCIONES.
##
## Tres puestos aislados, con las piezas REALES del juego (GrassBlock,
## WaterBlock, Conductor, Door, Brazier) y los hechizos REALES (SpellRecipe ->
## SpellFactory -> spell.gd). Nada de esto es una copia: lo que reaccione aquí
## reaccionará igual en el nivel, y lo que se pinte aquí para que se LEA la
## reacción (paso 4 del plan) se pintará igual allí.
##
##   HIERBA        fuego prende (arde 5 s y contagia) · agua riega y apaga ·
##                 viento aviva las llamas y las lanza hacia delante ·
##                 rayo prende de golpe (sin fase previa)
##   CIRCUITO      el rayo sobre el agua electrifica la charca, la corriente
##                 recorre las placas y abre la puerta 4 s · hielo no conduce
##   FUEGO Y ANTORCHA  una pira encendida y otra apagada, a distancia: el
##                 viento que cruza el fuego se lleva el fuego y enciende la
##                 otra. El agua la apaga.
##
## TECLAS
##   1 fuego  2 agua  3 viento  4 rayo        elegir elemento
##   Q flecha  E barrera  X amplificar (on/off)   elegir sello
##   ESPACIO o clic izquierdo                  lanzar hacia el ratón
##   W A S D                                   mover al lanzador
##   R reiniciar los puestos   T cámara lenta   H ocultar la ayuda
##
## Se lanza desde _process/_unhandled_input y no desde _ready porque
## SpellFactory cuelga los hechizos de current_scene.

const ELEMENTOS: Array = [
	{"nombre": "FUEGO", "ruta": "res://fire_rune.tres"},
	{"nombre": "AGUA", "ruta": "res://water_rune.tres"},
	{"nombre": "VIENTO", "ruta": "res://wind_rune.tres"},
	{"nombre": "RAYO", "ruta": "res://lightning_rune.tres"},
]
const SELLOS: Array = ["flecha", "barrera"]

const GRASS_SCENE: PackedScene = preload("res://GrassBlock.tscn")
const WATER_SCENE: PackedScene = preload("res://WaterBlock.tscn")
const BRAZIER_SCENE: PackedScene = preload("res://Brazier.tscn")

const VELOCIDAD: float = 240.0
const LENTA: float = 0.25
const FONDO: Color = Color(0.16, 0.18, 0.15)
const SUELO: Color = Color(0.24, 0.27, 0.22)


## El punto desde el que se lanza. Un círculo con una raya hacia donde apunta.
class Caster extends Node2D:
	var apunta: Vector2 = Vector2.RIGHT

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 9.0, Color(0.85, 0.80, 0.95, 0.95))
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, Color(1, 1, 1, 0.55), 1.5, true)
		draw_line(apunta * 16.0, apunta * 34.0, Color(1, 1, 1, 0.8), 2.5, true)


var _runas: Array = []
var _elemento: int = 0
var _sello: int = 0
var _amplificar: bool = false
var _lenta: bool = false

var _caster: Caster
var _puestos: Node2D
var _suelos: Array = []     # rombos de suelo para dibujar: PackedVector2Array
var _ayuda: Label
var _estado: Label
var _centro: Vector2


func _ready() -> void:
	RenderingServer.set_default_clear_color(FONDO)
	for e in ELEMENTOS:
		_runas.append(load(e["ruta"]))

	_centro = get_viewport_rect().size * 0.5

	_caster = Caster.new()
	_caster.position = _centro + Vector2(-170.0, 170.0)
	add_child(_caster)

	_crear_hud()
	_construir()
	_refrescar()
	_comprobar_versiones()


## Qué versión de cada pieza está cargando Godot de verdad. Existe porque más
## de una vez el editor ha ejecutado scripts antiguos sin avisar: así se ve en
## la propia pantalla, sin abrir nada.
func _comprobar_versiones() -> void:
	var g: Node = GRASS_SCENE.instantiate()
	var mapa: Dictionary = g.get_script().get_script_constant_map()
	g.free()
	var frente: bool = mapa.has("FRONT_SPEED") and mapa.has("FRONT_MIN")
	var impacto: bool = "ultimo_impacto" in SpellFactory
	var l := Label.new()
	l.text = "hierba con frente: %s · impacto: %s" % ["SI" if frente else "NO (script antiguo)", "SI" if impacto else "NO (script antiguo)"]
	l.position = Vector2(get_viewport_rect().size.x - 380.0, 10.0)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if frente and impacto else Color(1.0, 0.5, 0.4))
	l.z_index = 200
	add_child(l)
	print("[LAB] ", l.text)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## --- Los puestos ---

func _construir() -> void:
	if _puestos:
		_puestos.queue_free()
	_suelos.clear()

	_puestos = Node2D.new()
	_puestos.y_sort_enabled = true
	add_child(_puestos)

	_puesto_hierba(_centro + Vector2(-400.0, -60.0))
	_puesto_hierba_alta(_centro + Vector2(330.0, -60.0))
	_puesto_circuito(_centro + Vector2(-170.0, -190.0))
	_puesto_antorcha(_centro + Vector2(0.0, 170.0))
	queue_redraw()


## Un rombo de suelo bajo una casilla, para que las piezas no floten en el vacío.
func _suelo(pos: Vector2) -> void:
	_suelos.append(PackedVector2Array([
		pos + Vector2(0.0, -IsoGrid.STEP.y), pos + Vector2(IsoGrid.STEP.x, 0.0),
		pos + Vector2(0.0, IsoGrid.STEP.y), pos + Vector2(-IsoGrid.STEP.x, 0.0)]))


func _poner(nodo: Node2D, origen: Vector2, celda: Vector2i) -> void:
	nodo.position = origen + IsoGrid.to_screen(celda)
	_suelo(nodo.position)
	_puestos.add_child(nodo)


func _rotulo(texto: String, pos: Vector2, color: Color = Color(1, 1, 1, 0.85)) -> void:
	var l := Label.new()
	l.text = texto
	l.position = pos
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	l.z_index = 100
	_puestos.add_child(l)


## HIERBA: 3x3, con dos matas altas (que bloquean y también arden).
func _puesto_hierba(origen: Vector2) -> void:
	_rotulo("HIERBA · fuego/rayo prenden · agua riega/apaga · viento aviva",
		origen + Vector2(-110.0, 150.0))
	for x in range(3):
		for y in range(3):
			var g: Node2D = GRASS_SCENE.instantiate()
			if (x == 1 and y == 1) or (x == 2 and y == 0):
				g.initial_state = 1   # GROWN
			_poner(g, origen, Vector2i(x, y))


## HIERBA ALTA: 3x2 de hierba crecida con briznas dibujadas, para ver el fuego
## en una hierba más montada.
func _puesto_hierba_alta(origen: Vector2) -> void:
	_rotulo("HIERBA ALTA · el fuego devora las briznas",
		origen + Vector2(-110.0, 110.0))
	for x in range(3):
		for y in range(2):
			var g: Node2D = GRASS_SCENE.instantiate()
			g.initial_state = 1   # GROWN
			g.blades = true
			_poner(g, origen, Vector2i(x, y))


## CIRCUITO: charcas -> placas -> puerta, en fila.
func _puesto_circuito(origen: Vector2) -> void:
	_rotulo("CIRCUITO · rayo en el agua → placas → puerta (4 s)",
		origen + Vector2(-90.0, -70.0))
	for x in range(3):
		for y in range(2):
			_poner(WATER_SCENE.instantiate(), origen, Vector2i(x, y))
	_poner(Conductor.make(), origen, Vector2i(3, 0))
	_poner(Conductor.make(), origen, Vector2i(4, 0))
	_poner(Door.make(), origen, Vector2i(5, 0))


## FUEGO Y ANTORCHA: dos piras en horizontal, la de la izquierda encendida.
func _puesto_antorcha(origen: Vector2) -> void:
	_rotulo("FUEGO + ANTORCHA · viento a través del fuego enciende la otra",
		origen + Vector2(-70.0, -90.0))
	var fuego: Node2D = BRAZIER_SCENE.instantiate()
	fuego.start_lit = true
	fuego.is_goal = false
	fuego.position = origen
	_suelo(fuego.position)
	_puestos.add_child(fuego)

	var antorcha: Node2D = BRAZIER_SCENE.instantiate()
	antorcha.is_goal = false
	antorcha.position = origen + Vector2(232.0, 0.0)
	_suelo(antorcha.position)
	_puestos.add_child(antorcha)


func _draw() -> void:
	for rombo in _suelos:
		draw_colored_polygon(rombo, SUELO)
		var cerrado: PackedVector2Array = rombo.duplicate()
		cerrado.append(rombo[0])
		draw_polyline(cerrado, Color(1, 1, 1, 0.07), 1.0)


## --- HUD ---

func _crear_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	_estado = Label.new()
	_estado.position = Vector2(14.0, 10.0)
	_estado.add_theme_font_size_override("font_size", 18)
	hud.add_child(_estado)

	_ayuda = Label.new()
	_ayuda.position = Vector2(14.0, get_viewport_rect().size.y - 46.0)
	_ayuda.add_theme_font_size_override("font_size", 13)
	_ayuda.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_ayuda.text = "1 fuego · 2 agua · 3 viento · 4 rayo    Q flecha · E barrera · X amplificar\n" \
		+ "ESPACIO / clic lanzar · WASD mover · R reiniciar · T lenta · H ocultar ayuda"
	hud.add_child(_ayuda)


func _refrescar() -> void:
	_estado.text = "%s + %s%s%s" % [
		ELEMENTOS[_elemento]["nombre"], String(SELLOS[_sello]).to_upper(),
		"  ×2" if _amplificar else "", "   (LENTA)" if _lenta else ""]


## --- Entrada ---

func _process(delta: float) -> void:
	var mov := Vector2(
		_eje(KEY_A, KEY_D),
		_eje(KEY_W, KEY_S))
	if mov != Vector2.ZERO:
		_caster.position += mov.normalized() * VELOCIDAD * delta / maxf(Engine.time_scale, 0.001)

	var a: Vector2 = get_global_mouse_position() - _caster.global_position
	if a != Vector2.ZERO:
		_caster.apunta = a.normalized()
	_caster.queue_redraw()


func _eje(menos: Key, mas: Key) -> float:
	return float(Input.is_key_pressed(mas)) - float(Input.is_key_pressed(menos))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_lanzar()
		return

	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_1: _elemento = 0
		KEY_2: _elemento = 1
		KEY_3: _elemento = 2
		KEY_4: _elemento = 3
		KEY_Q: _sello = 0
		KEY_E: _sello = 1
		KEY_X: _amplificar = not _amplificar
		KEY_SPACE: _lanzar()
		KEY_R: _construir()
		KEY_H: _ayuda.visible = not _ayuda.visible
		KEY_T:
			_lenta = not _lenta
			Engine.time_scale = LENTA if _lenta else 1.0
	_refrescar()


func _lanzar() -> void:
	var dir: Vector2 = _caster.apunta
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var receta := SpellRecipe.new(dir)
	receta.apply(SELLOS[_sello])
	if _amplificar:
		receta.apply("amplificar")
	receta.build(_caster, _runas[_elemento])
