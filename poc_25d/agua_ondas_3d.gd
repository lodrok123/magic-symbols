extends Node3D
class_name AguaOndas3D
## ONDAS QUE REACCIONAN (Fase 11.8, 12/10). Lo escribe el Pipeline.
##
## Qué es: una ecuación de ondas en una textura de `tam` × `tam` texels que cubre un cuadrado de `lado` unidades alrededor del
## OBJETIVO (la cámara o el jugador) y se mueve con él. Lo que toca el agua llama a `impulso()` y de ahí salen anillos que se
## propagan, rebotan en los bordes de la zona y se apagan. AguaRender3D suma su pendiente a la normal del agua (las caras se
## inclinan al paso de la onda) y un poco de espuma en las crestas.
##
## Por qué sin cómputo: Godot 4.7 en el modo que usa el proyecto no asegura shaders de cómputo en todas las máquinas. Se hace con
## dos SubViewport en ping-pong y un shader canvas_item: cada paso lee el estado del otro y escribe el siguiente. El estado va en
## una textura de coma flotante (RGBA16F): R = altura ahora, G = altura en el paso anterior (la ecuación de ondas necesita las dos).
##
## Idea: iWave (Godot-RealisticEnvironments), los muelles 2D de godot-WaterPack y la ecuación de ondas en dos viewports de DynamicWaterDemo; el código es nuestro.
## Las ondas valen 0 donde la simulación no tiene agua (máscara = la lectura de AguaRender3D conectado), así no cruzan la tierra.
## Lo que no hace (todavía): nacer solas donde algo atraviesa la superficie (la cámara bajo el agua de DynamicWaterDemo); el Juego llama a `impulso()`.
##
## Uso:
##   var ondas := AguaOndas3D.new(); add_child(ondas)
##   ondas.objetivo = camara_o_jugador
##   ondas.conectar(agua_render)                 # AguaRender3D: le pasa la textura y el origen cada fotograma
##   ondas.impulso(pos_mundo, 0.12, 0.8)         # el Juego llama a esto: un paso, un hechizo que cae, un objeto que flota
##
## `fuerza` es la altura (u) que se levanta en el centro: un paso ~0,05, un hechizo que cae ~0,2. `radio` en unidades del mundo.

## Texels por lado y unidades que cubre la zona (0,16 u por texel con los valores de partida).
@export var tam: int = 256
@export var lado: float = 40.0
## Pasos de onda por segundo (la ecuación es estable hasta c² = 0,5; con 60 pasos se ven suaves).
@export var pasos_por_segundo: float = 60.0
## Velocidad al cuadrado de la onda en texels² por paso (≤ 0,5 por estabilidad). Más = las ondas corren más.
@export var velocidad2: float = 0.15
## Lo que queda de la altura tras cada paso (1 = no se apaga nunca).
@export var amortiguacion: float = 0.99
## Cuánto pesa la onda en el dibujo del agua (pendiente y espuma de crestas).
@export var fuerza_dibujo: float = 1.0
## Altura del agua (Y) a la que se proyecta el rayo de la cámara cuando el objetivo es una Camera3D.
@export var nivel_y: float = 0.0
## Quien manda dónde está la zona: una Camera3D (se usa el punto del suelo al que mira) o cualquier Node3D (su posición).
var objetivo: Node3D = null

const MAX_IMPULSOS: int = 8

const CODIGO: String = """
shader_type canvas_item;
render_mode blend_disabled;
uniform sampler2D estado : filter_nearest, repeat_disable;   // R altura ahora, G altura en el paso anterior (del otro SubViewport)
uniform vec2 desplaza = vec2(0.0);                           // la zona se movió: el estado se lee desplazado (en uv)
uniform float c2 = 0.32;
uniform float amort = 0.985;
uniform vec4 imp[8];                                         // xy uv, z fuerza (u), w radio (uv)
uniform int n_imp = 0;
uniform sampler2D mascara : filter_nearest, hint_default_black, repeat_disable;   // la lectura de la simulación: G = profundidad (sin agua = onda 0)
uniform vec4 mascara_rect = vec4(0.0, 0.0, 1.0, 1.0);   // ancho y alto (u) del mundo que cubre la máscara (en zw; xy = 0)
uniform vec3 zona = vec3(0.0, 0.0, 1.0);                // esquina (x, z) y lado (u) de la zona de ondas
uniform float mascara_activa = 0.0;
uniform float minima = 0.05;

vec2 leer(vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return vec2(0.0);                                    // fuera de la zona, agua en calma
	}
	return texture(estado, uv).rg;
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(estado, 0));
	vec2 uv = UV + desplaza;
	vec2 s = leer(uv);
	float h = s.r;
	float hp = s.g;
	float vec_suma = leer(uv + vec2(px.x, 0.0)).r + leer(uv - vec2(px.x, 0.0)).r + leer(uv + vec2(0.0, px.y)).r + leer(uv - vec2(0.0, px.y)).r;
	float hn = (2.0 * h - hp + c2 * (vec_suma - 4.0 * h)) * amort;
	for (int i = 0; i < 8; i++) {
		if (i >= n_imp) {
			break;
		}
		vec2 d = (UV - imp[i].xy);
		float r = max(imp[i].w, 0.0001);
		hn += imp[i].z * exp(-dot(d, d) / (r * r));
	}
	if (mascara_activa > 0.5) {
		// Donde la simulación dice que no hay agua las ondas valen 0: no cruzan la tierra ni rebotan fuera de la orilla.
		vec2 mu = (zona.xy + UV * zona.z) / mascara_rect.zw;
		if (mu.x < 0.0 || mu.y < 0.0 || mu.x > 1.0 || mu.y > 1.0 || texture(mascara, mu).g < minima) {
			hn = 0.0;
			h = 0.0;
		}
	}
	COLOR = vec4(hn, h, 0.0, 1.0);
}
"""

var _vp: Array[SubViewport] = []
var _mat: Array[ShaderMaterial] = []
var _actual: int = 0                    ## el viewport que escribió el último paso (su textura es el estado más reciente)
var _acum: float = 0.0
var _origen := Vector2.ZERO             ## esquina (x, z) de la zona en el mundo, siempre en múltiplos de un texel
var _desplaza := Vector2.ZERO
var _cola: Array = []                   ## [Vector4(u, v, fuerza, radio_uv)] por aplicar en el próximo paso
var _render: AguaRender3D = null
var _listo: bool = false


func _ready() -> void:
	for i in range(2):
		var vp := SubViewport.new()
		vp.size = Vector2i(tam, tam)
		vp.use_hdr_2d = true                                      # RGBA16F: la altura va con signo
		vp.transparent_bg = false
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(vp)
		var rect := ColorRect.new()
		rect.size = Vector2(tam, tam)
		var sh := Shader.new()
		sh.code = CODIGO
		var m := ShaderMaterial.new()
		m.shader = sh
		rect.material = m
		vp.add_child(rect)
		_vp.append(vp)
		_mat.append(m)
	_listo = true
	_origen = _origen_para(_punto_objetivo())


## Enchufa el dibujo del agua: cada fotograma se le pasa la textura de las ondas y dónde está la zona.
func conectar(render: AguaRender3D) -> void:
	_render = render


## La textura del estado más reciente (R = altura). AguaRender3D saca de ella la pendiente.
func textura() -> Texture2D:
	return _vp[_actual].get_texture() if _listo else null


## Esquina (x, z) de la zona en el mundo y su lado: lo que AguaRender3D necesita para colocar la textura.
func origen() -> Vector2:
	return _origen


## Levanta una onda en `pos` (mundo). `fuerza` = altura en el centro (u), `radio` = alcance (u). Se aplica en el siguiente paso.
func impulso(pos: Vector3, fuerza: float, radio: float) -> void:
	var uv := Vector2((pos.x - _origen.x) / lado, (pos.z - _origen.y) / lado)
	if uv.x < -0.1 or uv.y < -0.1 or uv.x > 1.1 or uv.y > 1.1:
		return                                                    # fuera de la zona: no se ve
	if _cola.size() >= 64:
		_cola.pop_front()
	_cola.append(Vector4(uv.x, uv.y, fuerza, radio / lado))


func _process(delta: float) -> void:
	if not _listo:
		return
	# La zona sigue al objetivo en saltos de un texel entero (así las ondas no «tiemblan»).
	var o: Vector2 = _origen_para(_punto_objetivo())
	var texel: float = lado / float(tam)
	var salto: Vector2 = (o - _origen) / texel
	if absf(salto.x) >= 1.0 or absf(salto.y) >= 1.0:
		_desplaza += Vector2(roundf(salto.x), roundf(salto.y)) / float(tam)
		_origen += Vector2(roundf(salto.x), roundf(salto.y)) * texel
	_acum += delta
	var n: int = mini(int(_acum * pasos_por_segundo), 4)          # nunca más de 4 pasos por fotograma (evita la espiral)
	_acum = minf(_acum, 4.0 / pasos_por_segundo)
	if n > 0:
		_acum -= float(n) / pasos_por_segundo
	for k in range(n):
		_paso()
	if _render != null:
		_render.fuente_ondas(textura(), _origen, lado, fuerza_dibujo)


func _paso() -> void:
	var dst: int = 1 - _actual
	var src: int = _actual
	var m: ShaderMaterial = _mat[dst]
	m.set_shader_parameter("estado", _vp[src].get_texture())
	m.set_shader_parameter("desplaza", _desplaza)
	m.set_shader_parameter("c2", velocidad2)
	m.set_shader_parameter("amort", amortiguacion)
	var arr: Array = []
	var n: int = mini(_cola.size(), MAX_IMPULSOS)
	for i in range(MAX_IMPULSOS):
		arr.append(_cola[i] if i < n else Vector4(0, 0, 0, 0.001))
	m.set_shader_parameter("imp", arr)
	m.set_shader_parameter("n_imp", n)
	_cola = _cola.slice(n)
	var sim: AguaSim3D = _render.sim if _render != null else null
	var datos: Texture2D = _render.textura_datos() if _render != null else null
	if sim != null and datos != null:
		m.set_shader_parameter("mascara", datos)
		m.set_shader_parameter("mascara_rect", Vector4(0.0, 0.0, float(sim.w) * sim.l, float(sim.h) * sim.l))
		m.set_shader_parameter("zona", Vector3(_origen.x, _origen.y, lado))
		m.set_shader_parameter("mascara_activa", 1.0)
	_desplaza = Vector2.ZERO                                      # el desplazamiento se aplica una sola vez
	_vp[dst].render_target_update_mode = SubViewport.UPDATE_ONCE
	_actual = dst


## El punto del mundo en el que se centra la zona.
func _punto_objetivo() -> Vector3:
	if objetivo == null:
		return global_position
	if objetivo is Camera3D:
		var cam := objetivo as Camera3D
		var d: Vector3 = -cam.global_transform.basis.z
		if absf(d.y) > 0.0001:
			var t: float = (nivel_y - cam.global_position.y) / d.y
			if t > 0.0:
				return cam.global_position + d * t
	return objetivo.global_position


## Esquina de la zona para un centro dado, redondeada a texels.
func _origen_para(centro: Vector3) -> Vector2:
	var texel: float = lado / float(tam)
	return Vector2(roundf((centro.x - lado * 0.5) / texel), roundf((centro.z - lado * 0.5) / texel)) * texel
