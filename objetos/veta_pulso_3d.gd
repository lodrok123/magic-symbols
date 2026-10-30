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
## FASE 3 (24/10; PLAN_PULSO_RESONANTE §5 y §12.3). Tres añadidos, todos opcionales y por clave del mapa:
##   `enlaces=<lista>`  HUECOS de la veta (C2): casillas que se dibujan apagadas y solo conducen mientras haya un bloque de tierra encima (`Pulso3D.enlaces`, «bloque de enlace»).
##   `aturde=<s>`       el frente deja sin sentido `s` s al enemigo que pisa la veta (C4; `Pulso3D._aturdir_en`).
##   `mineral=si`       la veta es un REACTIVO de tierra: un hechizo de tierra suelta un trozo (`Objetos.mineral_de("veta", "tierra")` = mineral_veta), una vez por veta (flag `<nivel>.mineral.<id>`).
##
## Se coloca desde un mapa con `; pieza <id> veta <x> <y> celdas=<lista> [enlaces=<lista>] [aturde=<s>] [mineral=si]` (escenas/puzle.gd). `x y` es una referencia (se suele poner la primera casilla).

const RUTA_VETA: String = "res://arte/suelo_meshy/veta_mineral.png"
const RUTA_MASCARA: String = "res://arte/suelo_meshy/veta_mineral_mascara.png"
const ALTO_SOBRE_SUELO: float = 0.03     ## u por encima del suelo (la cámara es cenital: no hay z-fighting que vigilar de lado)
const TAM_TEX: float = 4.6               ## u que mide la textura (la del suelo: 2 casillas)
const ATAQUE: float = 0.04               ## s que tarda en llegar al brillo pleno
const REPOSO: float = 0.55               ## cuánto de su valor (0..1) conserva la veta sin pulso
const ALFA_REPOSO: float = 0.85
const EMISION: float = 0.9              ## multiplicador de la emisión (máscara × color × energía × EMISION); con más se quema a blanco y el azul claro se pierde
const EMISION_REPOSO: float = 0.16      ## brillo azul sutil de la veta sin pulso (la cueva iluminada en azul; era 0,10; el frente la lleva a 0,9: sigue casi 6× por encima)
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

## Un hueco de enlace sin bloque: la losa se ve rota (casi transparente) para que se lea «aquí falta un trozo».
const ALFA_HUECO: float = 0.3
const EMISION_HUECO: float = 0.05
## El mineral que suelta la veta con tierra (fase 3): cuántos golpes de tierra hacen falta lo dice `Objetos.MINERALES`.
const CADA_MINERAL: float = 0.2          ## s entre dos miradas a si hay tierra sobre la veta
const RUNA_TIERRA: String = "res://nucleo/earth_rune.tres"

var celdas: Array = []                   ## Vector2i: las casillas de esta veta
var enlaces: Array = []                  ## Vector2i: los huecos (solo conducen con un bloque de tierra encima)
var aturde: float = 0.0                  ## s que aturde a quien pisa la veta cuando pasa el frente
var mineral: bool = false                ## ¿suelta un trozo con un hechizo de tierra?
var nivel: String = ""                   ## el nivel (para la flag del trozo)
var trozo_dado: bool = false             ## ya soltó su trozo (también con la flag puesta al montar)
var golpes_tierra: int = 0
var _losas: Dictionary = {}              ## casilla -> MeshInstance3D
var _mats: Dictionary = {}               ## casilla -> ShaderMaterial
var _vivas: Dictionary = {}              ## casilla -> [edad, color]: las que el frente ha tocado hace poco
var _t_mineral: float = 0.0


func preparar(p_celdas: Array, p_enlaces: Array = [], p_aturde: float = 0.0, p_mineral: bool = false, p_nivel: String = "") -> void:
	celdas = p_celdas
	enlaces = p_enlaces
	aturde = maxf(p_aturde, 0.0)
	mineral = p_mineral
	nivel = p_nivel


func _ready() -> void:
	for c in celdas:
		Pulso3D.vetas[c] = self
	for c in enlaces:
		Pulso3D.enlaces[c] = self
	_dibujar()
	if mineral:
		trozo_dado = Flags.i().tiene(flag_mineral())
	call_deferred("_refrescar_hilos")        # ya están todas las piezas del mapa: se ven las vetas vecinas de otras piezas
	set_process(true)


func _exit_tree() -> void:
	for c in celdas:
		if Pulso3D.vetas.get(c, null) == self:
			Pulso3D.vetas.erase(c)
	for c in enlaces:
		if Pulso3D.enlaces.get(c, null) == self:
			Pulso3D.enlaces.erase(c)


## La flag del trozo: `<nivel>.mineral.<id>` (como la de los rompibles).
func flag_mineral() -> String:
	return "%s.mineral.%s" % [Rompible3D._limpio(nivel), Rompible3D._limpio(String(name))]


## Cada CADA_MINERAL s mira si hay tierra levantada sobre alguna casilla de la veta (el bloque que deja un hechizo de tierra al caer encima): esa es la forma de «tierra a una veta». No usa un reactivo de
## colisión: uno a ras de suelo no lo alcanza una flecha que sale de la mano (la altura de salida cambia) y uno alto detiene los flechazos que la cruzan (HechizoVivo cuenta el golpe aunque no reaccione).
func _mirar_tierra(delta: float) -> void:
	_t_mineral -= delta
	if _t_mineral > 0.0 or trozo_dado:
		return
	_t_mineral = CADA_MINERAL
	for c in celdas:
		if Terreno3D.altura_en(c as Vector2i) >= 1:
			picar(load(RUNA_TIERRA) as RuneData)
			return


## Un hechizo de tierra pica la veta. Devuelve el material que soltó ("" si no soltó nada).
func picar(rune: RuneData, hechizo: Hechizo = null) -> String:
	if rune == null or not Materia.golpea(Materia.de(hechizo if hechizo != null else rune)) or trozo_dado:
		return ""
	golpes_tierra += 1
	var da: String = Objetos.mineral_de("veta", "tierra")
	var hace_falta: int = int((Objetos.MINERALES.get("veta", {}) as Dictionary).get("golpes", 1))
	if da == "" or golpes_tierra < hace_falta:
		return ""
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
	var id: String = MineralPulso.dar(lanz, da, self)
	if id != "":
		trozo_dado = true
		Flags.i().poner(flag_mineral())
	return id




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
	for c in celdas + enlaces:
		var hueco: bool = enlaces.has(c)
		var m := ShaderMaterial.new()
		m.shader = _shader
		if t_veta != null:
			m.set_shader_parameter("t_veta", t_veta)
		if t_masc != null:
			m.set_shader_parameter("t_mascara", t_masc)
		m.set_shader_parameter("tam_tex", TAM_TEX)
		m.set_shader_parameter("lado", Terreno3D.casilla)
		m.set_shader_parameter("reposo", REPOSO)
		m.set_shader_parameter("alfa_reposo", ALFA_HUECO if hueco else ALFA_REPOSO)
		m.set_shader_parameter("emision", EMISION)
		m.set_shader_parameter("color_reposo", BrilloPulso3D.COLOR_REPOSO)
		m.set_shader_parameter("emision_reposo", EMISION_HUECO if hueco else EMISION_REPOSO)
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
		v.x = 1.0 if _hay_veta(cc + Vector2i(0, -1)) else 0.0
		v.y = 1.0 if _hay_veta(cc + Vector2i(1, 0)) else 0.0
		v.z = 1.0 if _hay_veta(cc + Vector2i(0, 1)) else 0.0
		v.w = 1.0 if _hay_veta(cc + Vector2i(-1, 0)) else 0.0
		(_mats[c] as ShaderMaterial).set_shader_parameter("conex", v)


## ¿Hay veta (o hueco de enlace, que la continúa) en esa casilla? Para dibujar los hilos entre vecinas.
func _hay_veta(c: Vector2i) -> bool:
	return Pulso3D.vetas.has(c) or Pulso3D.enlaces.has(c)


## El frente llega a la casilla `c`: se enciende con el color del pulso y se apaga detrás.
func encender(c: Vector2i, color: Color) -> void:
	if not celdas.has(c) and not enlaces.has(c):
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


## Los huecos de enlace: con el bloque de tierra puesto la losa se sube a su cara de arriba (`y_pies` cuenta la tierra levantada) y se ve entera, para que se vea pasar el frente; sin él, a ras y rota.
func _seguir_enlaces() -> void:
	for c in enlaces:
		var losa: Node3D = _losas.get(c, null)
		if losa == null:
			continue
		var tendido: bool = Pulso3D.enlace_tendido(c)
		losa.global_position = Terreno3D.centro_de(c as Vector2i, Terreno3D.y_pies(c as Vector2i) + ALTO_SOBRE_SUELO)
		var m: ShaderMaterial = _mats[c] as ShaderMaterial
		m.set_shader_parameter("alfa_reposo", ALFA_REPOSO if tendido else ALFA_HUECO)
		m.set_shader_parameter("emision_reposo", EMISION_REPOSO if tendido else EMISION_HUECO)


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
	_seguir_enlaces()
	if mineral:
		_mirar_tierra(delta)
	for c in _vivas.keys():
		var e: Array = _vivas[c]
		e[0] = float(e[0]) + delta
		if float(e[0]) >= ATAQUE + Pulso3D.T_BRILLO:
			_poner(c, 1.0e9, e[1] as Color)
			_vivas.erase(c)
		else:
			_poner(c, float(e[0]), e[1] as Color)
