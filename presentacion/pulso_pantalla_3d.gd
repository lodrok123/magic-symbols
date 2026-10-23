class_name PulsoPantalla3D
extends RefCounted
## PULSO DE PANTALLA (bloque 2 de la revisión EoW, 23/10): un desenfoque radial breve, con una pizca de aberración cromática, que sale del
## punto donde pasa algo grande (una explosión, la sala despejada, el nivel completado) y se apaga en unas décimas.
##
## POR QUÉ. El posproceso de EoW tiene `radial_blur_mode` y `chromatic_aberration_mode` como modos de efecto, no siempre encendidos
## (docs/estudios/eow/EOW_4_ASSETS.md §1.4). Aquí es lo mismo: nada de serie; un golpe de pantalla cuando el juego lo pide.
##
## CÓMO. Un `ColorRect` a pantalla completa en un `CanvasLayer` propio (capa 1: encima de la viñeta, debajo del HUD) con un shader que lee la
## pantalla y la promedia hacia el centro del golpe; el rojo y el azul se desplazan un poco distinto (la aberración). La fuerza baja a 0 con un
## tween que ignora la escala del tiempo (un hitstop no lo congela) y la capa se borra. Un pulso nuevo mientras dura otro lo reinicia.

static var activo: bool = true

const CAPA: int = 1
const ALCANCE: float = 0.07         ## fracción de pantalla que se arrastra a fuerza 1 (el shader toma 8 muestras)

const CODIGO: String = """
shader_type canvas_item;
uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
uniform float fuerza = 0.0;
uniform vec2 centro = vec2(0.5);
uniform float alcance = 0.07;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - centro;
	vec3 suma = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		vec2 o = dir * (float(i) / 7.0) * fuerza * alcance;
		suma.r += texture(pantalla, uv - o * 1.2).r;
		suma.g += texture(pantalla, uv - o).g;
		suma.b += texture(pantalla, uv - o * 0.8).b;
	}
	suma /= 8.0;
	// El centro del golpe se queda nítido; el arrastre crece hacia fuera.
	float mezcla = smoothstep(0.04, 0.45, length(dir)) * clamp(fuerza, 0.0, 1.0);
	COLOR = vec4(mix(texture(pantalla, uv).rgb, suma, mezcla), 1.0);
}
"""

static var _capa: CanvasLayer = null
static var _mat: ShaderMaterial = null
static var _tw: Tween = null


## Lanza un pulso de `fuerza` (0..1) que dura `dura` s, centrado en `centro` (coordenadas de pantalla 0..1).
static func lanzar(arbol: SceneTree, fuerza: float, dura: float = 0.35, centro: Vector2 = Vector2(0.5, 0.5)) -> void:
	if not activo or arbol == null or arbol.root == null or fuerza <= 0.0:
		return
	if _capa == null or not is_instance_valid(_capa):
		_capa = CanvasLayer.new()
		_capa.name = "PulsoPantalla"
		_capa.layer = CAPA
		_capa.process_mode = Node.PROCESS_MODE_ALWAYS
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		var sh := Shader.new()
		sh.code = CODIGO
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_mat.set_shader_parameter("alcance", ALCANCE)
		rect.material = _mat
		_capa.add_child(rect)
		arbol.root.add_child(_capa)
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var bruto: Variant = _mat.get_shader_parameter("fuerza")       # null hasta que se pone por primera vez
	var actual: float = float(bruto) if bruto != null else 0.0
	_mat.set_shader_parameter("fuerza", maxf(fuerza, actual))
	_mat.set_shader_parameter("centro", centro)
	_tw = _capa.create_tween().set_ignore_time_scale(true)
	_tw.tween_method(_poner_fuerza, maxf(fuerza, actual), 0.0, dura).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_callback(_borrar)


## Igual que `lanzar`, pero centrado en un punto del MUNDO (lo proyecta la cámara activa; fuera de cámara, en el centro de la pantalla).
static func lanzar_en(arbol: SceneTree, punto: Vector3, fuerza: float, dura: float = 0.35) -> void:
	var centro := Vector2(0.5, 0.5)
	if arbol != null and arbol.root != null:
		var cam: Camera3D = arbol.root.get_camera_3d()
		if cam != null and not cam.is_position_behind(punto):
			var tam: Vector2 = arbol.root.get_visible_rect().size
			if tam.x > 0.0 and tam.y > 0.0:
				centro = (cam.unproject_position(punto) / tam).clamp(Vector2.ZERO, Vector2.ONE)
	lanzar(arbol, fuerza, dura, centro)


static func _poner_fuerza(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("fuerza", v)


static func _borrar() -> void:
	if _capa != null and is_instance_valid(_capa):
		_capa.queue_free()
	_capa = null
	_mat = null
	_tw = null
