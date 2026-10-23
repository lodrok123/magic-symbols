class_name VetaPulso3D
extends Node3D

## VETA (23/10, FASE 1 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §4 y §9): CONDUCTOR del pulso, de CELDAS. Un tramo de veta mineral en el SUELO, sin geometría:
## una losa plana por casilla, pegada al suelo, que pinta las vetas de `arte/suelo_meshy/veta_mineral.png` (solo donde su máscara `veta_mineral_mascara.png` es blanca;
## el resto es transparente y se ve la roca del suelo). La textura se lee en COORDENADAS DE MUNDO, así que las losas contiguas casan sin juntas.
##
## EL BRILLO sale de la MÁSCARA × el COLOR del pulso, por EMISIÓN (`energia`): cuando el frente pasa por la casilla (`encender`) sube en `ATAQUE` s y se apaga en `T_BRILLO` s
## detrás de él; en reposo la veta se ve apagada (`REPOSO`). El pulso las alcanza casilla a casilla (`Pulso3D.vetas`: casilla -> veta), así que se enciende una a una.
##
## HILO GUÍA: la textura es una red de grietas al azar que no recorre una casilla de un lado a otro, y un camino de 5 losas no se leería como camino. Cada losa dibuja además un
## HILO fino del centro hacia cada lado con una veta vecina (de esta pieza o de otra). Es un añadido de esta fase, no sale de la textura: se quita con `HILO = 0`.
##
## Se coloca desde un mapa con `; pieza <id> veta <x> <y> celdas=<lista>` (escenas/puzle.gd). `x y` es una referencia (se suele poner la primera casilla).

const RUTA_VETA: String = "res://arte/suelo_meshy/veta_mineral.png"
const RUTA_MASCARA: String = "res://arte/suelo_meshy/veta_mineral_mascara.png"
const ALTO_SOBRE_SUELO: float = 0.03     ## u por encima del suelo (la cámara es cenital: no hay z-fighting que vigilar de lado)
const TAM_TEX: float = 4.6               ## u que mide la textura (la del suelo: 2 casillas)
const ATAQUE: float = 0.04               ## s que tarda en llegar al brillo pleno
const REPOSO: float = 0.55               ## cuánto de su valor (0..1) conserva la veta sin pulso
const ALFA_REPOSO: float = 0.85
const EMISION: float = 0.9              ## multiplicador de la emisión (máscara × color × energía × EMISION); con más se quema a blanco y el azul claro se pierde
const EMISION_REPOSO: float = 0.10      ## brillo azul muy sutil de la veta sin pulso (la cueva iluminada en azul; el frente la lleva a 0,9 y la nueva luz no compite)
const HILO: float = 1.0                 ## fuerza del hilo guía (0 = sin hilo)
const HILO_REPOSO: float = 0.6           ## cuánto del hilo se ve sin pulso (1 = igual que con él)
const HILO_ANCHO: float = 0.045          ## fracción de casilla
const DESVANECER: float = 0.18           ## fracción de casilla en la que una veta que acaba sin vecina se desvanece (no queda cortada a escuadra)

const CODIGO: String = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled;
uniform sampler2D t_veta : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_mascara : filter_linear_mipmap, repeat_enable;
uniform float tam_tex = 4.6;
uniform float lado = 2.3;
uniform vec4 conex = vec4(0.0);          // hay veta vecina al norte (-z), este (+x), sur (+z), oeste (-x)
uniform vec3 color_pulso : source_color = vec3(0.62, 0.85, 1.0);
uniform float energia = 0.0;
uniform float reposo = 0.55;
uniform float alfa_reposo = 0.85;
uniform float emision = 2.2;
uniform vec3 color_reposo : source_color = vec3(0.62, 0.85, 1.0);
uniform float emision_reposo = 0.0;
uniform float hilo = 1.0;
uniform float hilo_reposo = 0.6;
uniform float hilo_ancho = 0.045;
uniform float desvanecer = 0.18;
varying vec2 mundo_xz;
varying vec2 loc;

void vertex() {
	mundo_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	loc = VERTEX.xz / lado;                 // -0.5 .. 0.5
}

void fragment() {
	vec2 uv = mundo_xz / tam_tex;
	float m = smoothstep(0.15, 0.6, texture(t_mascara, uv).r);
	vec3 col = texture(t_veta, uv).rgb;
	// El hilo serpentea un poco (en coordenadas de mundo, así que casa entre losas) para que no parezca una línea de interfaz.
	float ond_x = 0.03 * sin(mundo_xz.y * 3.1) + 0.02 * sin(mundo_xz.y * 7.3 + 1.0);
	float ond_y = 0.03 * sin(mundo_xz.x * 3.1 + 2.0) + 0.02 * sin(mundo_xz.x * 7.3);
	float h = 0.0;
	if (conex.x > 0.5 && loc.y <= 0.0) { h = max(h, 1.0 - smoothstep(hilo_ancho * 0.35, hilo_ancho, abs(loc.x - ond_x))); }
	if (conex.z > 0.5 && loc.y >= 0.0) { h = max(h, 1.0 - smoothstep(hilo_ancho * 0.35, hilo_ancho, abs(loc.x - ond_x))); }
	if (conex.y > 0.5 && loc.x >= 0.0) { h = max(h, 1.0 - smoothstep(hilo_ancho * 0.35, hilo_ancho, abs(loc.y - ond_y))); }
	if (conex.w > 0.5 && loc.x <= 0.0) { h = max(h, 1.0 - smoothstep(hilo_ancho * 0.35, hilo_ancho, abs(loc.y - ond_y))); }
	h = max(h, 1.0 - smoothstep(hilo_ancho * 0.6, hilo_ancho * 1.6, length(loc))) * 0.9;     // el nudo del centro
	h *= hilo;
	h *= mix(hilo_reposo, 1.0, clamp(energia, 0.0, 1.0));            // en reposo el hilo es más tenue que las vetas de la textura
	float v = max(m, h * 0.8);
	// Sin veta vecina por un lado, la veta se desvanece antes del borde de la losa (no se corta a escuadra).
	float borde = 1.0;
	if (conex.x < 0.5) { borde *= smoothstep(-0.5, -0.5 + desvanecer, loc.y); }
	if (conex.z < 0.5) { borde *= 1.0 - smoothstep(0.5 - desvanecer, 0.5, loc.y); }
	if (conex.y < 0.5) { borde *= 1.0 - smoothstep(0.5 - desvanecer, 0.5, loc.x); }
	if (conex.w < 0.5) { borde *= smoothstep(-0.5, -0.5 + desvanecer, loc.x); }
	v *= borde;
	vec3 base = mix(col, vec3(0.45, 0.78, 0.9), clamp(h * (1.0 - m), 0.0, 1.0));
	ALBEDO = base * reposo;
	ROUGHNESS = 0.6;
	EMISSION = (color_pulso * energia * emision + color_reposo * emision_reposo) * v;
	ALPHA = clamp(v, 0.0, 1.0) * mix(alfa_reposo, 1.0, clamp(energia, 0.0, 1.0));
}
"""

static var _shader: Shader = null

var celdas: Array = []                   ## Vector2i: las casillas de esta veta
var _losas: Dictionary = {}              ## casilla -> MeshInstance3D
var _mats: Dictionary = {}               ## casilla -> ShaderMaterial
var _vivas: Dictionary = {}              ## casilla -> [edad, color]: las que el frente ha tocado hace poco


func preparar(p_celdas: Array) -> void:
	celdas = p_celdas


func _ready() -> void:
	for c in celdas:
		Pulso3D.vetas[c] = self
	_dibujar()
	call_deferred("_refrescar_hilos")        # ya están todas las piezas del mapa: se ven las vetas vecinas de otras piezas
	set_process(true)


func _exit_tree() -> void:
	for c in celdas:
		if Pulso3D.vetas.get(c, null) == self:
			Pulso3D.vetas.erase(c)


func _dibujar() -> void:
	if not Terreno3D.hay_mundo():
		return                               # sin mundo (una prueba de lógica) solo hay conducción
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODIGO
	var t_veta: Texture2D = load(RUTA_VETA) as Texture2D if ResourceLoader.exists(RUTA_VETA) else null
	var t_masc: Texture2D = load(RUTA_MASCARA) as Texture2D if ResourceLoader.exists(RUTA_MASCARA) else null
	var q := QuadMesh.new()
	q.orientation = PlaneMesh.FACE_Y
	q.size = Vector2(Terreno3D.casilla, Terreno3D.casilla)
	for c in celdas:
		var m := ShaderMaterial.new()
		m.shader = _shader
		if t_veta != null:
			m.set_shader_parameter("t_veta", t_veta)
		if t_masc != null:
			m.set_shader_parameter("t_mascara", t_masc)
		m.set_shader_parameter("tam_tex", TAM_TEX)
		m.set_shader_parameter("lado", Terreno3D.casilla)
		m.set_shader_parameter("reposo", REPOSO)
		m.set_shader_parameter("alfa_reposo", ALFA_REPOSO)
		m.set_shader_parameter("emision", EMISION)
		m.set_shader_parameter("color_reposo", BrilloPulso3D.COLOR_REPOSO)
		m.set_shader_parameter("emision_reposo", EMISION_REPOSO)
		m.set_shader_parameter("hilo", HILO)
		m.set_shader_parameter("hilo_reposo", HILO_REPOSO)
		m.set_shader_parameter("hilo_ancho", HILO_ANCHO)
		m.set_shader_parameter("desvanecer", DESVANECER)
		m.set_shader_parameter("energia", 0.0)
		m.set_shader_parameter("color_pulso", Pulso3D.COLOR_BASE)
		var mi := MeshInstance3D.new()
		mi.name = "veta_%d_%d" % [(c as Vector2i).x, (c as Vector2i).y]
		mi.mesh = q
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = Terreno3D.centro_de(c as Vector2i, Terreno3D.y_pies(c as Vector2i) + ALTO_SOBRE_SUELO)
		_losas[c] = mi
		_mats[c] = m
	_refrescar_hilos()


## Qué lados de cada losa tienen veta vecina (norte −z, este +x, sur +z, oeste −x).
func _refrescar_hilos() -> void:
	for c in _mats:
		var v := Vector4(0.0, 0.0, 0.0, 0.0)
		var cc: Vector2i = c
		v.x = 1.0 if Pulso3D.vetas.has(cc + Vector2i(0, -1)) else 0.0
		v.y = 1.0 if Pulso3D.vetas.has(cc + Vector2i(1, 0)) else 0.0
		v.z = 1.0 if Pulso3D.vetas.has(cc + Vector2i(0, 1)) else 0.0
		v.w = 1.0 if Pulso3D.vetas.has(cc + Vector2i(-1, 0)) else 0.0
		(_mats[c] as ShaderMaterial).set_shader_parameter("conex", v)


## El frente llega a la casilla `c`: se enciende con el color del pulso y se apaga detrás.
func encender(c: Vector2i, color: Color) -> void:
	if not celdas.has(c):
		return
	_vivas[c] = [0.0, color]
	_poner(c, 0.0, color)


## Brillo actual (0..1) de la casilla. Para las pruebas y las capturas.
func energia_en(c: Vector2i) -> float:
	if not _vivas.has(c):
		return 0.0
	return _curva(float((_vivas[c] as Array)[0]))


## El color con el que brilla la casilla ahora (el del último pulso que pasó; base si nunca).
func color_en(c: Vector2i) -> Color:
	if _vivas.has(c):
		return (_vivas[c] as Array)[1] as Color
	return Pulso3D.COLOR_BASE


## 0 → 1 en ATAQUE s y de 1 → 0 en T_BRILLO s.
static func _curva(edad: float) -> float:
	if edad < ATAQUE:
		return edad / ATAQUE
	return clampf(1.0 - (edad - ATAQUE) / Pulso3D.T_BRILLO, 0.0, 1.0)


func _poner(c: Vector2i, edad: float, color: Color) -> void:
	var m: ShaderMaterial = _mats.get(c, null)
	if m == null:
		return
	m.set_shader_parameter("color_pulso", color)
	m.set_shader_parameter("energia", _curva(edad))


func _process(delta: float) -> void:
	for c in _vivas.keys():
		var e: Array = _vivas[c]
		e[0] = float(e[0]) + delta
		if float(e[0]) >= ATAQUE + Pulso3D.T_BRILLO:
			_poner(c, 1.0e9, e[1] as Color)
			_vivas.erase(c)
		else:
			_poner(c, float(e[0]), e[1] as Color)
