class_name EmisorRayo3D
extends Node3D

## EMISOR DE RAYO AMBIENTAL EN 3D (9.10, Juego). La FUENTE ELÉCTRICA del bosque (letra `e`): cada PERIODO segundos suelta una
## descarga que recorre el AGUA conectada a la suya. Es la cadena de Pablo (10/10): fuente → cauce (cuando el surtidor lo ha
## llenado) → río → tótem de rayo en la orilla. El jugador NO tiene rayo: el tótem solo se activa por esta conducción.
##
## POR QUÉ UNA BÚSQUEDA POR CASILLAS y no un hechizo de rayo con salto. El rayo del Lanzador salta entre ENEMIGOS mojados;
## aquí no hay enemigos de por medio, hay un trozo de agua. Lo que se pide es una pregunta de conectividad («¿llega el agua
## de la fuente hasta esta casilla?»), y las preguntas de conectividad en una rejilla se resuelven con un relleno (BFS) por
## las casillas de agua. Costó decidir una regla de vecindad: se usan las 4 vecinas (sin diagonales), de modo que dos charcos
## que solo se tocan por una esquina NO conducen. Con 8 vecinas un río y un cauce que se rozan en diagonal se unirían sin que
## el jugador lo vea unido.
##
## Qué cuenta como agua: `Terreno3D.es_agua(c)` (la letra `~` sin hielo encima). Por eso un tramo helado CORTA la corriente
## y un puente no la lleva. Es la misma pregunta que se hacen el jugador al nadar y los goblins, y no se duplica la regla.
##
## Qué hace una descarga: (1) calcula el agua conectada AHORA (el cauce puede haberse llenado desde la última); (2) la ilumina
## DURACION segundos; (3) activa los tótems de rayo que estén en su orilla; (4) hiere a quien esté DENTRO del agua
## electrificada cada TICK_DANO segundos. Entre descargas el agua es segura: se puede cruzar nadando si se mide el ritmo.
##
## Lo coloca Bosque3D.colocar() leyendo las `e` del mapa; no hace falta código en el cargador. Dueño: Juego (PROPIETARIOS.md).

signal descarga(celdas: Array)

const PERIODO: float = 4.0            ## s entre una descarga y la siguiente (medidas desde el final de la anterior)
const DURACION: float = 1.6           ## s que el agua está electrificada
const TICK_DANO: float = 0.4          ## s entre dos daños a quien está dentro
const DANO: float = 8.0               ## por tick (el jugador tiene 100 de vida: ~4 s dentro del agua y a la orilla)
const MAX_CHISPAS: int = 6            ## chispazos por tick: más de eso no se ve y cuesta
const LIMITE_BUSQUEDA: int = 4096     ## casillas máximas del relleno (corta un bug que dejase la búsqueda sin fin)
const COLOR: Color = Color(1.0, 0.92, 0.4)

var m: Variant = null                 ## la maqueta (PruebaTest2)
var celda: Vector2i = Vector2i.ZERO   ## dónde está la fuente
var electrificada: Array = []         ## Vector2i que ahora llevan corriente (vacío entre descargas)

var _t: float = 0.0                   ## cuenta atrás hasta la próxima descarga (o hasta que acabe la actual)
var _activa: bool = false
var _t_dano: float = 0.0
var _chispas: int = 0
var _malla: MultiMeshInstance3D = null
var _jug: Node = null
var _sonido: Node = null              ## el chisporroteo de la descarga (Sfx.bucle), mientras dura


func preparar(p_mundo: Variant, p_celda: Vector2i) -> void:
	m = p_mundo
	celda = p_celda
	add_to_group("emisor_rayo")              # 16/10: los nexos (NexoRayo3D) miran si están en la descarga de alguna fuente
	position = Terreno3D.centro_de(celda, Terreno3D.alto_suelo)
	_t = 1.0                          # la primera descarga a poco de empezar, para que se vea que está viva


## Casillas de agua conectadas (por las 4 vecinas) a las vecinas de `origen`. `es_agua` es un Callable(Vector2i) -> bool;
## estática y sin árbol para poder medirla sin escena. El origen es TIERRA (la fuente): la corriente entra por el agua que
## toca; si no toca ninguna, no hay corriente. Si `origen` fuese agua, entra también.
static func agua_conectada(origen: Vector2i, es_agua: Callable) -> Array:
	return EmisorRayo3D.ola([origen], es_agua, LIMITE_BUSQUEDA).keys()


## LA BÚSQUEDA, con distancia (23/10, FASE 1 del Pulso resonante: la comparte `Pulso3D`, no se duplica). Relleno por las 4 vecinas desde
## `origenes` (casillas) por lo que `conduce` (Callable(Vector2i) -> bool) deja pasar, hasta `alcance` casillas. Devuelve {casilla: paso}:
## 1 = vecina del origen, 2 = la siguiente… Las casillas de origen no cuentan como conductoras (paso 0 solo si conducen, o si `origen_siempre`:
## el pulso nace SIEMPRE en su emisor), pero desde ellas se entra en lo que las toca: así la fuente (tierra) electrifica el agua de su orilla.
## El orden del diccionario es el de la búsqueda (por anillos), que es el orden en que el frente de un pulso las alcanza.
static func ola(origenes: Array, conduce: Callable, alcance: int, origen_siempre: bool = false) -> Dictionary:
	var paso: Dictionary = {}                 # las que entran en el resultado
	var dist: Dictionary = {}                 # las ya vistas (incluye el origen aunque no conduzca)
	var cola: Array = []
	for o in origenes:
		if dist.has(o):
			continue
		dist[o] = 0
		cola.append(o)
		if origen_siempre or bool(conduce.call(o)):
			paso[o] = 0
	var i: int = 0
	while i < cola.size() and cola.size() < LIMITE_BUSQUEDA:
		var c: Vector2i = cola[i]
		i += 1
		var d: int = int(dist[c])
		if d >= alcance:
			continue
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + dir
			if not dist.has(v) and bool(conduce.call(v)):
				dist[v] = d + 1
				paso[v] = d + 1
				cola.append(v)
	return paso


## ¿Toca `c` (o alguna de sus 8 vecinas) alguna casilla de `agua`? Para el tótem de la orilla: pegado al agua, en diagonal incluido.
static func toca_agua(c: Vector2i, agua: Dictionary) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if agua.has(c + Vector2i(dx, dy)):
				return true
	return false


static func runa_rayo() -> RuneData:
	var r := RuneData.new()
	r.display_name = "Rayo"
	var t: Array[String] = ["rayo", "electrico"]
	r.tags = t
	return r


func _process(delta: float) -> void:
	if m == null:
		return
	_t -= delta
	if _activa:
		_fuerza_descarga()
		_t_dano -= delta
		if _t_dano <= 0.0:
			_t_dano = TICK_DANO
			_golpear()
		if _t <= 0.0:
			_apagar()
	elif _t <= 0.0:
		_soltar()


## Empieza una descarga con el agua que esté conectada ahora mismo.
func _soltar() -> void:
	# 16/10: conduce el agua Y lo que el mundo declare conductor (un NexoRayo3D mojado): Terreno3D.conduce.
	var f := func(c: Vector2i) -> bool: return Terreno3D.en_mapa(c) and Terreno3D.conduce(c)
	electrificada = EmisorRayo3D.agua_conectada(celda, f)
	_t = DURACION
	if electrificada.is_empty():
		_t = PERIODO                  # sin agua conectada no hay nada que iluminar; se vuelve a mirar en un rato
		return
	_activa = true
	_t_dano = 0.0
	# 27/10: la descarga SUENA: un chasquazo al soltar y chisporroteo mientras dura (se corta en `_apagar`).
	Sfx.play(self, "descarga_electrica")
	_sonido = Sfx.bucle(self, "chasquidos_electricos")
	_pintar()
	_activar_totems()
	descarga.emit(electrificada)


func _apagar() -> void:
	_activa = false
	Sfx.parar(_sonido)
	_sonido = null
	electrificada = []
	_t = PERIODO
	if _malla != null:
		_malla.visible = false


## Los tótems de rayo pegados al agua electrificada se activan (contrato on_spell_hit: él decide con sus etiquetas).
func _activar_totems() -> void:
	var agua: Dictionary = {}
	for c in electrificada:
		agua[c] = true
	for r in get_tree().get_nodes_in_group("reactivo3d"):
		if not is_instance_valid(r) or String(r.get("tipo")) != "totem" or String(r.get("elemento")) != "rayo":
			continue
		if bool(r.get("activo")):
			continue
		if EmisorRayo3D.toca_agua(r.get("celda"), agua):
			(r as Node).call("on_spell_hit", EmisorRayo3D.runa_rayo(), Vector3.ZERO)


## Hiere a quien esté dentro del agua electrificada: el jugador y los goblins (Combate3D).
func _golpear() -> void:
	var agua: Dictionary = {}
	for c in electrificada:
		agua[c] = true
	if _jug == null or not is_instance_valid(_jug):
		_jug = get_tree().get_first_node_in_group("player")
		_jug = (_jug.get("jugador") as Node) if _jug != null and _jug.get("jugador") != null else null
	if _jug != null and agua.has(Terreno3D.celda_de((_jug as Node3D).position)):
		_jug.call("recibir_dano", DANO, position)
	for g in get_tree().get_nodes_in_group("combate3d"):
		if is_instance_valid(g) and agua.has(Terreno3D.celda_de((g as Node3D).position)):
			g.call("receive_damage", DANO)
	_chispas = 0
	for c in electrificada:
		if _chispas >= MAX_CHISPAS:
			break
		if randf() < 0.25 and m != null and m.get("_fx") != null:
			(m.get("_fx") as Vfx3D).chispazo(Terreno3D.centro_de(c, Terreno3D.alto_agua + 0.1), "rayo")
			_chispas += 1


## EL AGUA ELECTRIFICADA (27/10). Antes era una losa amarilla semitransparente por casilla: se leían cuadros y tapaban el frente del pulso
## que viaja por el agua (C5 de la Cueva). Ahora cada casilla lleva un cuadro del tamaño exacto de la casilla con un sombreado en coordenadas
## del MUNDO (las vetas siguen de una casilla a la vecina sin costura), que SUMA luz (no tapa lo de debajo): vetas finas que saltan a
## tirones, un velo tenue y un fundido en los lados que dan a agua sin corriente (INSTANCE_CUSTOM: qué vecinas están electrificadas).
## La fuerza la lleva `_process`: destello al soltar y se apaga a lo largo de la descarga.
const CODIGO_AGUA: String = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.92, 0.4);
uniform float fuerza = 1.0;
uniform float lado = 2.3;
varying vec3 wp;
varying vec4 vecinas;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vecinas = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = wp.xz;
	float t = floor(TIME * 14.0);                      // a tirones, como un chispazo, no un deslizar suave
	float n1 = ruido(p * 1.1 + vec2(t * 0.37, t * 0.21));
	float n2 = ruido(p * 2.6 + vec2(-t * 0.29, t * 0.43) + 7.0);
	float v1 = 1.0 - smoothstep(0.0, 0.035, abs(n1 - 0.5));
	float v2 = 1.0 - smoothstep(0.0, 0.025, abs(n2 - 0.5));
	float venas = max(v1, v2 * 0.6);
	float velo = 0.10 + 0.05 * ruido(p * 0.7 + t * 0.05);
	// Fundido en los lados que dan a agua sin corriente (x = oeste, y = este, z = norte, w = sur; 1 = la vecina también lleva corriente).
	vec2 f = fract(p / lado);
	float borde = 0.22;
	float fade = 1.0;
	fade *= mix(smoothstep(0.0, borde, f.x), 1.0, vecinas.x);
	fade *= mix(smoothstep(0.0, borde, 1.0 - f.x), 1.0, vecinas.y);
	fade *= mix(smoothstep(0.0, borde, f.y), 1.0, vecinas.z);
	fade *= mix(smoothstep(0.0, borde, 1.0 - f.y), 1.0, vecinas.w);
	ALBEDO = color * (venas * 1.4 + velo) * fade * fuerza;
}
"""
const DESTELLO_S: float = 0.25        ## s del destello al soltar (fuerza 1), luego baja hasta FUERZA_FIN al final de la descarga
const FUERZA_FIN: float = 0.35

var _mat_agua: ShaderMaterial = null


func _pintar() -> void:
	if _malla == null:
		var sh := Shader.new()
		sh.code = CODIGO_AGUA
		_mat_agua = ShaderMaterial.new()
		_mat_agua.shader = sh
		_mat_agua.set_shader_parameter("color", COLOR)
		_mat_agua.set_shader_parameter("lado", Terreno3D.casilla)
		var q := QuadMesh.new()
		q.orientation = PlaneMesh.FACE_Y
		q.size = Vector2(Terreno3D.casilla, Terreno3D.casilla)      # entera: los cuadros vecinos se tocan y el dibujo sigue sin costura
		q.material = _mat_agua
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = q
		_malla = MultiMeshInstance3D.new()
		_malla.multimesh = mm
		_malla.top_level = true               # sus transformaciones son del mundo, no de la fuente
		_malla.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_malla)
	var dentro: Dictionary = {}
	for c in electrificada:
		dentro[c] = true
	var mm2: MultiMesh = _malla.multimesh
	mm2.instance_count = electrificada.size()
	for i in range(electrificada.size()):
		var c: Vector2i = electrificada[i]
		mm2.set_instance_transform(i, Transform3D(Basis(), Terreno3D.centro_de(c, Terreno3D.alto_agua + 0.06)))
		mm2.set_instance_custom_data(i, Color(1.0 if dentro.has(c + Vector2i(-1, 0)) else 0.0, 1.0 if dentro.has(c + Vector2i(1, 0)) else 0.0,
				1.0 if dentro.has(c + Vector2i(0, -1)) else 0.0, 1.0 if dentro.has(c + Vector2i(0, 1)) else 0.0))
	_mat_agua.set_shader_parameter("fuerza", 1.0)
	_malla.visible = true


## Destello al soltar y luego se apaga poco a poco hasta el final de la descarga.
func _fuerza_descarga() -> void:
	if _mat_agua == null:
		return
	var pasado: float = DURACION - _t
	var f: float = 1.0 if pasado < DESTELLO_S else lerpf(1.0, FUERZA_FIN, clampf((pasado - DESTELLO_S) / maxf(DURACION - DESTELLO_S, 0.01), 0.0, 1.0))
	_mat_agua.set_shader_parameter("fuerza", f)
