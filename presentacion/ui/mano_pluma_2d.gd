class_name ManoPluma2D
extends Node2D
## La mano con la pluma, vista desde arriba, que escribe sobre la página del grimorio (Fase 14.4 · 4.2, Pipeline).
##
## POR QUÉ. Hoy el trazo nace del cursor, sin nada que lo dibuje: parece que la tinta aparece sola. Con la mano, el jugador ve a QUIÉN
## escribe. Es solo la CARA: no reconoce nada y no decide nada. Quien manda es el Juego (`spellbook.gd`), que le da cada fotograma el
## punto del trazo y si se está dibujando; esta clase lo suaviza y lo pinta.
##
## CAPAS (cada una un PNG de `presentacion/ui/laminas/`, todos con la PUNTA de la pluma en el mismo píxel `PUNTA_PX`, así girar y colocar
## el conjunto es mover un solo punto): sombra → pluma → mano. La pluma va DEBAJO de los dedos (los dedos la agarran).
## POSES: REPOSO (apoyada en la página, sin moverse un rato), ESCRIBIENDO (pulsando) y LEVANTADA (entre trazos: más arriba, con la sombra
## más lejos y más difusa). El paso de una a otra no salta: `_alzada` va de 0 a 1 con una rampa de `T_LEVANTAR`.
##
## CÓMO SE USA (el Juego, en la capa de dibujo del libro; nada más):
##     var mano := ManoPluma2D.new()          # una vez, hijo del libro, z_index por encima de los trazos
##     mano.apuntar(punto, is_drawing)        # cada fotograma; `punto` = el ÚLTIMO de `stroke_visible` (el imantado), no el ratón crudo
##     mano.punta()                           # dónde está la punta DE VERDAD (con el retardo): de ahí sale la tinta
##     mano.ocultar() / mano.mostrar()        # con el libro cerrado
##
## EL RETARDO DE 60 MS. La punta no está donde está el punto, sino donde estaba hace `RETARDO` s: la mano «va detrás» y se nota la inercia
## de una muñeca. Se hace con un buffer de (tiempo, punto) y se lee en `ahora − RETARDO` interpolando; así es independiente de los
## fotogramas por segundo (con un contador de fotogramas, a 144 fps el retardo valdría menos).
## LA CURVA DE MUÑECA. La pluma se inclina según hacia dónde va (`inclinacion`): hasta ±`INCLINA_MAX` grados con la velocidad horizontal,
## suavizada; y la mano gira un poco MENOS que la pluma (`GIRO_MANO`), como una muñeca que no es rígida.

enum Pose { REPOSO, ESCRIBIENDO, LEVANTADA }

const RUTA: String = "res://presentacion/ui/laminas/"
## La punta de la pluma en los PNG (todos de 560 × 560): el ancla de todo.
const PUNTA_PX: Vector2 = Vector2(92.0, 330.0)
const RETARDO: float = 0.060               ## s que la punta va por detrás del punto que recibe
const T_LEVANTAR: float = 0.12             ## s que tarda en subir o bajar la mano
const T_REPOSO: float = 1.5                ## s sin moverse ni pulsar para pasar a REPOSO
const INCLINA_MAX: float = 12.0            ## grados máximos que se inclina la pluma por la velocidad
const VEL_INCLINA: float = 900.0           ## px/s a los que se alcanza el máximo
const GIRO_MANO: float = 0.55              ## la mano gira esta fracción de lo que gira la pluma
const SUAVIZADO_GIRO: float = 14.0         ## 1/s de la suavización del giro
## Con la mano levantada la sombra se aleja y se difumina (px del PNG sin escalar) y la mano se agranda un poco.
const SOMBRA_ESCRIBIENDO: Vector2 = Vector2(6.0, 8.0)
const SOMBRA_LEVANTADA: Vector2 = Vector2(22.0, 30.0)
const AUMENTO_LEVANTADA: float = 1.04

## Tamaño en pantalla: los PNG miden 560 px; el libro, 1470. A 0,55 la mano ocupa ~300 px (la cuarta parte del círculo de dibujo).
@export var escala: float = 0.55
@export var visible_al_inicio: bool = true

var pose: int = Pose.REPOSO
var _alzada: float = 1.0                    ## 0 = pulsando sobre la página · 1 = levantada del todo
var _buffer: Array = []                     ## [[t, punto]] de los últimos 0,5 s
var _punta_actual: Vector2 = Vector2.ZERO
var _vel: Vector2 = Vector2.ZERO
var _giro: float = 0.0                      ## grados, ya suavizado
var _dibujando: bool = false
var _t_quieta: float = 0.0
var _reloj: float = 0.0
var _tex: Dictionary = {}
var _grupo: Node2D
var _s_sombra: Sprite2D
var _s_pluma: Sprite2D
var _s_mano: Sprite2D


func _ready() -> void:
	_grupo = Node2D.new()
	_grupo.name = "grupo"
	add_child(_grupo)
	_s_sombra = _sprite("sombra")
	_s_pluma = _sprite("pluma")
	_s_mano = _sprite("mano")
	_s_sombra.self_modulate = Color(1, 1, 1, 1)
	_poner_texturas()
	visible = visible_al_inicio


func _sprite(nombre: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = nombre
	s.centered = false
	s.offset = -PUNTA_PX                    # la punta del PNG queda en el origen del grupo
	_grupo.add_child(s)
	return s


func _cargar(nombre: String) -> Texture2D:
	if _tex.has(nombre):
		return _tex[nombre]
	var ruta: String = RUTA + nombre + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(ruta):
		t = load(ruta) as Texture2D
	_tex[nombre] = t
	return t


static func nombre_pose(p: int) -> String:
	return ["reposo", "escribiendo", "levantada"][clampi(p, 0, 2)]


func _poner_texturas() -> void:
	var n: String = nombre_pose(pose)
	_s_mano.texture = _cargar("mano_" + n)
	_s_sombra.texture = _cargar("sombra_" + n)
	_s_pluma.texture = _cargar("mano_pluma")


## Lo único que el Juego llama cada fotograma. `punto` en las coordenadas del padre; `dibujando` = botón pulsado dentro del círculo.
func apuntar(punto: Vector2, dibujando: bool, ahora: float = -1.0) -> void:
	var t: float = _reloj if ahora < 0.0 else ahora
	_buffer.append([t, punto])
	# Solo se guardan los últimos 0,5 s: más atrás no se lee nunca.
	while _buffer.size() > 2 and float((_buffer[0] as Array)[0]) < t - 0.5:
		_buffer.pop_front()
	_dibujando = dibujando


## Dónde estaba el punto hace `RETARDO` s (interpolando entre las dos muestras que lo rodean). Estática y pura para poder probarla.
static func punto_con_retardo(buffer: Array, ahora: float, retardo: float = RETARDO) -> Vector2:
	if buffer.is_empty():
		return Vector2.ZERO
	var t: float = ahora - retardo
	var primero: Array = buffer[0]
	if t <= float(primero[0]):
		return primero[1] as Vector2
	for i in range(1, buffer.size()):
		var b: Array = buffer[i]
		if float(b[0]) >= t:
			var a: Array = buffer[i - 1]
			var d: float = float(b[0]) - float(a[0])
			var k: float = 0.0 if d <= 0.0 else (t - float(a[0])) / d
			return (a[1] as Vector2).lerp(b[1] as Vector2, k)
	return (buffer[buffer.size() - 1] as Array)[1] as Vector2


## Cuánto se inclina la pluma (grados) con la velocidad: a la derecha → hacia la derecha, hasta ±INCLINA_MAX.
static func inclinacion(velocidad: Vector2) -> float:
	return clampf(velocidad.x / VEL_INCLINA, -1.0, 1.0) * INCLINA_MAX


## Dónde está la punta ahora (con el retardo), en las coordenadas del padre. De aquí sale la tinta.
func punta() -> Vector2:
	return _punta_actual


func mostrar() -> void:
	visible = true


func ocultar() -> void:
	visible = false


func _process(delta: float) -> void:
	_reloj += delta
	if _buffer.is_empty():
		return
	var antes: Vector2 = _punta_actual
	_punta_actual = punto_con_retardo(_buffer, _reloj)
	_vel = (_punta_actual - antes) / maxf(delta, 0.0001)
	# La pose: pulsando → ESCRIBIENDO; sin pulsar → LEVANTADA y, tras T_REPOSO sin moverse, REPOSO.
	if _dibujando:
		_t_quieta = 0.0
		_cambiar_pose(Pose.ESCRIBIENDO)
	else:
		_t_quieta = _t_quieta + delta if _vel.length() < 2.0 else 0.0
		_cambiar_pose(Pose.REPOSO if _t_quieta >= T_REPOSO else Pose.LEVANTADA)
	var objetivo: float = 0.0 if pose == Pose.ESCRIBIENDO else 1.0
	_alzada = move_toward(_alzada, objetivo, delta / T_LEVANTAR)
	if pose == Pose.REPOSO:
		_alzada = move_toward(_alzada, 0.35, delta / T_LEVANTAR)
	# La inclinación sigue a la velocidad, suavizada.
	_giro = lerpf(_giro, inclinacion(_vel), 1.0 - exp(-SUAVIZADO_GIRO * delta))
	_aplicar()


func _cambiar_pose(p: int) -> void:
	if p == pose:
		return
	pose = p
	if _s_mano != null:
		_poner_texturas()


func _aplicar() -> void:
	if _grupo == null:
		return
	position = _punta_actual
	_grupo.scale = Vector2.ONE * escala
	_grupo.rotation_degrees = _giro
	var s: float = lerpf(1.0, AUMENTO_LEVANTADA, _alzada)
	_s_mano.scale = Vector2(s, s)
	_s_mano.rotation_degrees = -_giro * (1.0 - GIRO_MANO)     # la mano gira menos que la pluma
	_s_mano.position = Vector2(0.0, -6.0 * _alzada)
	_s_pluma.position = Vector2(0.0, -4.0 * _alzada)
	_s_sombra.position = SOMBRA_ESCRIBIENDO.lerp(SOMBRA_LEVANTADA, _alzada)
	_s_sombra.modulate.a = lerpf(1.0, 0.7, _alzada)
	_s_sombra.scale = Vector2.ONE * lerpf(1.0, 1.05, _alzada)
