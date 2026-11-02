class_name IconoGuardado
extends Control

## EL ICONO DE «GUARDANDO» (2/11, gamefeel tercera tanda A2). Un círculo discreto que gira, abajo a la derecha, `T_ICONO_GUARDADO` s cada vez que `Partida.autoguardar` escribe la ranura «auto»
## (la llama por el grupo `icono_guardado`: `mostrar`). Suena un `ui_tick` a `DB_TICK`. Con `Sensacion3D.ACTIVA = false` no gira (se ve igual). Lo monta `Lanzador3D.construir_interfaz`.
## También hace de reloj del AUTOGUARDADO DIFERIDO: si se pidió con el árbol en pausa (`Partida.diferido`), en cuanto se despausa lo repite aquí.
## Para las pruebas: `mostrar()`, `visible`, `restante_s`, `angulo`.

const GRUPO: String = "icono_guardado"

static var T_ICONO_GUARDADO: float = 1.0       ## s que se ve
static var DB_TICK: float = -24.0
static var LADO_PX: float = 26.0
static var MARGEN_PX: float = 22.0
static var VEL_GIRO: float = 5.0               ## rad/s
static var COLOR_ARO: Color = Color(0.87, 0.71, 0.42, 0.9)   ## TemaInterfaz.BORDE_CALIDO
static var COLOR_ESTELA: Color = Color(0.87, 0.71, 0.42, 0.22)

var restante_s: float = 0.0
var angulo: float = 0.0


func _ready() -> void:
	add_to_group(GRUPO)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	custom_minimum_size = Vector2(LADO_PX, LADO_PX)
	size = Vector2(LADO_PX, LADO_PX)
	offset_left = -(LADO_PX + MARGEN_PX)
	offset_top = -(LADO_PX + MARGEN_PX)
	offset_right = -MARGEN_PX
	offset_bottom = -MARGEN_PX
	visible = false


func mostrar() -> void:
	restante_s = T_ICONO_GUARDADO
	visible = true
	Sfx.play_ui("ui_tick", DB_TICK)
	queue_redraw()


func _process(delta: float) -> void:
	if Partida.diferido and is_inside_tree() and not get_tree().paused:
		Partida.autoguardar(get_tree(), Partida.ultimo_motivo_auto)
	if not visible:
		return
	restante_s -= delta
	if restante_s <= 0.0:
		visible = false
		return
	if Sensacion3D.ACTIVA:
		angulo = fmod(angulo + delta * VEL_GIRO, TAU)
	queue_redraw()


func _draw() -> void:
	var c := Vector2(LADO_PX, LADO_PX) * 0.5
	var r: float = LADO_PX * 0.5 - 3.0
	draw_arc(c, r, 0.0, TAU, 32, COLOR_ESTELA, 3.0, true)
	draw_arc(c, r, angulo, angulo + TAU * 0.28, 16, COLOR_ARO, 3.0, true)
