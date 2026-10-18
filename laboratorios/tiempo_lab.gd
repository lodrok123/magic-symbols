class_name TiempoLab3D
extends Node

## TECLAS DE TIEMPO COMPARTIDAS POR LOS LABORATORIOS (R4, 17/10, Juego): cámara lenta y paso a paso. Las usan LabRecetas3D y, cuando exista,
## LabCastPoint3D (LAB_CASTPOINT.md §2.4: «cámara lenta 0,25× (L), paso a paso (.)»). Está aquí, en un nodo propio, para que los dos laboratorios
## se comporten igual y no haya dos copias que se desacompasen.
##
## Teclas:
##   L   alterna cámara lenta (ESCALA_LENTA = 0,25×) y velocidad normal. Si estaba en pausa, la quita y deja la cámara lenta.
##   .   paso a paso: la primera vez PAUSA el juego; cada pulsación siguiente avanza UN fotograma de física (1/60 s de juego).
##   ,   quita la pausa y vuelve a la velocidad en la que estaba.
## Por qué un nodo con `process_mode = ALWAYS`: con el árbol en pausa es el único que sigue recibiendo teclas. Los eventos se atienden con
## `set_input_as_handled()` porque la maqueta (Pipeline) tiene sus propias L (modo de luz) y `,` `.` (postura de la cabeza) y no deben saltar.
## Al salir del árbol devuelve `time_scale = 1` y `paused = false`: recargar la escena (R) no deja el juego a cámara lenta.

const ESCALA_LENTA: float = 0.25

var lenta: bool = false
var en_pausa: bool = false
var pasos: int = 0                       ## fotogramas avanzados con `.` desde la última pausa (para el HUD y para las pruebas)
var _avanzando: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "TiempoLab"


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if is_inside_tree():
		get_tree().paused = false


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_L:
			alternar_lenta()
			get_viewport().set_input_as_handled()
		KEY_PERIOD:
			paso()
			get_viewport().set_input_as_handled()
		KEY_COMMA:
			reanudar()
			get_viewport().set_input_as_handled()


## L: cámara lenta ⇄ normal. Salir de la pausa también cuenta.
func alternar_lenta() -> void:
	if en_pausa:
		en_pausa = false
		get_tree().paused = false
		lenta = true
	else:
		lenta = not lenta
	_aplicar()


## `.`: pausa si no lo estaba; si ya lo estaba, deja correr UN fotograma de física y vuelve a pausar.
func paso() -> void:
	if not en_pausa:
		en_pausa = true
		pasos = 0
		get_tree().paused = true
		return
	if _avanzando:
		return
	_avanzando = true
	pasos += 1
	var arbol: SceneTree = get_tree()
	# Un fotograma es 1/60 s de JUEGO: con time_scale 0,25 sería 1/240 s, así que durante el paso la escala vale 1.
	Engine.time_scale = 1.0
	arbol.paused = false
	await arbol.physics_frame
	await arbol.physics_frame
	arbol.paused = true
	_aplicar()
	_avanzando = false


## `,`: fuera de la pausa, con la velocidad que hubiera (lenta o normal).
func reanudar() -> void:
	en_pausa = false
	get_tree().paused = false
	_aplicar()


func _aplicar() -> void:
	Engine.time_scale = ESCALA_LENTA if lenta else 1.0


## Una línea para el HUD.
func texto() -> String:
	if en_pausa:
		return "PAUSA · paso %d  (. avanza un fotograma · , sigue)" % pasos
	return "CÁMARA LENTA %.2f×  (L · . pausa/paso)" % ESCALA_LENTA if lenta else "tiempo normal  (L lenta · . pausa/paso)"
