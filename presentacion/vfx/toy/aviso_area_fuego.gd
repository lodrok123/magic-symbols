class_name AvisoAreaFuego
extends Node3D

## AVISO DEL ÁREA DE LA EXPLOSIÓN (4/11/2026, decisión de Pablo: «un círculo en el suelo con el radio exacto mientras arde la mecha, que se va llenando y late más rápido según se acaba la mecha»).
## Es un DECAL de fuego (explosion_suelo.gdshader): una caja de lado `2 · radio` que se proyecta sobre el terreno leyendo la profundidad, así que sigue los desniveles y no hay z-fighting. Colores: la rampa de la
## bola de FuegoToy (rojo → naranja; el amarillo no se usa). Borde nítido a `radio` u; relleno que crece del centro al borde con el progreso de la mecha; el latido sube de LATIDO_INI_HZ a LATIDO_FIN_HZ.
## Uso:  var a := AvisoAreaFuego.crear(Barril3D.RADIO); barril.add_child(a)   (el origen del nodo es el SUELO bajo el centro)   ·   cada fotograma: a.actualizar(progreso 0..1, delta)   ·   a.queue_free() lo quita.
## `decal(radio)` es la fábrica de la caja y la usa también ExplosionFuegoToy para su onda.

const SHADER: String = "res://presentacion/vfx/toy/explosion_suelo.gdshader"
const GRUPO: String = "aviso_area_fuego"       ## para que las pruebas cuenten los que hay vivos
const ALTO_CAJA: float = 2.4                    ## u: lo que se proyecta hacia arriba y abajo desde el centro de la caja (cubre un desnivel de ~1 casilla)
const CENTRO_Y: float = 0.4                     ## u sobre el suelo del centro de la caja (queda más suelo hacia abajo que cuerpos hacia arriba)
const LATIDO_INI_HZ: float = 1.6                ## latidos por segundo al encender la mecha
const LATIDO_FIN_HZ: float = 9.0                ## ... y al acabarse
const T_ENTRADA: float = 0.12                   ## s que tarda el aviso en aparecer del todo

var radio: float = 2.6
var progreso: float = 0.0
var _fase: float = 0.0
var _t: float = 0.0
var _caja: MeshInstance3D = null
var _mat: ShaderMaterial = null


static func crear(radio_: float) -> AvisoAreaFuego:
	var a := AvisoAreaFuego.new()
	a.radio = maxf(radio_, 0.2)
	return a


## La caja con el shader de suelo. Devuelve el MeshInstance3D (su `material_override` es el ShaderMaterial). Centrada en (0, CENTRO_Y, 0).
static func decal(radio_: float) -> MeshInstance3D:
	FuegoToy._rampas()
	var caja := BoxMesh.new()
	caja.size = Vector3.ONE
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	m.render_priority = -2
	m.set_shader_parameter("rampa", FuegoToy._rampa_bola)
	m.set_shader_parameter("semilla", randf())
	var mi := MeshInstance3D.new()
	mi.mesh = caja
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(2.0 * radio_, ALTO_CAJA, 2.0 * radio_)
	mi.position = Vector3(0.0, CENTRO_Y, 0.0)
	mi.extra_cull_margin = 2.0
	return mi


func _ready() -> void:
	add_to_group(GRUPO)
	_caja = decal(radio)
	_caja.name = "Circulo"
	_mat = _caja.material_override as ShaderMaterial
	add_child(_caja)
	_aplicar()


## `p` = fracción de mecha consumida (0 recién encendida, 1 a punto de explotar). `delta` hace avanzar la fase del latido, cuyo ritmo sube con `p`.
func actualizar(p: float, delta: float) -> void:
	progreso = clampf(p, 0.0, 1.0)
	_t += delta
	_fase += TAU * ritmo_hz() * delta
	_aplicar()


## Latidos por segundo ahora mismo (sube con el progreso, algo más deprisa al final).
func ritmo_hz() -> float:
	return lerpf(LATIDO_INI_HZ, LATIDO_FIN_HZ, pow(progreso, 1.5))


## 0..1 del latido en este instante.
func latido() -> float:
	return 0.5 + 0.5 * sin(_fase)


## Radio (u) del borde del círculo tal como está dibujado: la escala de la caja entre dos.
func radio_dibujado() -> float:
	return _caja.scale.x * 0.5 if _caja != null else radio


func _aplicar() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("aviso", smoothstep(0.0, T_ENTRADA, _t))
	_mat.set_shader_parameter("llenado", progreso)
	_mat.set_shader_parameter("latido", latido())
