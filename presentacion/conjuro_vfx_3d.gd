class_name ConjuroVfx3D
extends Node3D

## VFX DEL CONJURO (Fase 14.5, T6b, Pipeline). Dibuja lo que el Juego deja como «sustituto» en `Lanzador3D`: la VOLUTA que va del libro a la mano
## y la FORMA que crece en la mano antes del disparo, con el aspecto de cada elemento (fuego, agua, viento, rayo, hielo, tierra, tiempo).
##
## Por qué escucha una señal y no toca el Lanzador: los tiempos (`RETARDO_CONJURO`, `conjuro_escala`) son del Juego y Pablo los afina allí.
## Este nodo solo lee `conjuro_fase(fase, elemento, posicion)` y `tiempos_conjuro(elemento)` (públicos, diario 104) y dibuja
## EN ESOS TIEMPOS, así que cambiar un tiempo no obliga a retocar nada aquí.
##   «runa»    → no dibuja (el destello de la página lo pone el HUD); guarda la posición de la mano (ahí llegará la voluta).
##   «voluta»  → un núcleo con cola de motas viaja del libro (`posicion`) a la mano, en arco, durante `tiempos[1]`.
##   «forma»   → en la mano crece el núcleo del elemento + una luz, durante `tiempos[2]`.
##   «disparo» → un destello breve y se retira lo que quede (el hechizo lo dibuja `Vfx3D`, no este nodo).
##
## Uso (lo hace la maqueta tras `Jugador3D.montar`):   ConjuroVfx3D.conectar(lanzador, mundo)
## Mientras el Juego no ofrezca `conjuro_vfx_propio` (ver diario 107) el Lanzador sigue dibujando además su hilo y su esfera de prueba:
## se ven las dos cosas a la vez, no es un fallo de este nodo.
##
## 17/10 (T-CP3, cast points): la «forma» crece DONDE llega en `conjuro_fase` (el cast point: ya no siempre la mano) y se queda hasta el
## disparo. Su aspecto depende del ORIGEN del cast point (los tres de `docs/LAB_CASTPOINT.md` §2.1):
##   mano_libre    → orbe del elemento en la mano libre, con chispas que convergen hacia él.
##   manos_alto    → columna de luz que sube sobre la cabeza + un círculo que se dibuja en el suelo, delante (donde nacerá el hechizo).
##   suelo_delante → círculo rúnico en el suelo que se cierra girando y destella al disparar.
## El disparo es igual en los tres: destello + onda corta en el cast point (la onda va tumbada en el suelo si el origen es el suelo).
## El origen lo da el Lanzador con `origen_conjuro(elemento) -> Dictionary` = {"origen": String, "destino": Vector3}: es lo que el Juego
## lee de `CastPoints.de(forma, elemento)["origen"]` (el nodo no conoce la forma: la señal no la lleva). `destino` es el punto del
## suelo donde nacerá el hechizo (solo lo usa «manos_alto»; si falta, se busca el suelo bajo la posición con un rayo).
## Sin ese método el origen es «mano_libre»: el comportamiento de siempre.

## Por elemento: color principal, color de las motas, gravedad de las motas (+ sube, − cae), cuántas, a qué velocidad, y la malla del núcleo.
## Los colores principales son los de los `*_rune.tres` (los de `docs/ARTE.md` §1).
const PERFIL: Dictionary = {
	"fuego":  {"color": Color(0.95, 0.33, 0.12), "mota": Color(1.0, 0.82, 0.38), "grav": 1.6,  "n": 26, "vel": 0.35, "nucleo": "esfera"},
	"agua":   {"color": Color(0.16, 0.62, 0.98), "mota": Color(0.70, 0.90, 1.0),  "grav": -2.2, "n": 22, "vel": 0.25, "nucleo": "esfera"},
	"viento": {"color": Color(0.56, 0.83, 0.42), "mota": Color(0.88, 1.0, 0.80),  "grav": 0.0,  "n": 30, "vel": 0.90, "nucleo": "pequeno"},
	"rayo":   {"color": Color(0.95, 0.78, 0.24), "mota": Color(1.0, 0.98, 0.70),  "grav": 0.0,  "n": 14, "vel": 1.10, "nucleo": "chispa"},
	"hielo":  {"color": Color(0.37, 0.81, 0.96), "mota": Color(0.90, 0.98, 1.0),  "grav": -0.6, "n": 18, "vel": 0.20, "nucleo": "cristal"},
	"tierra": {"color": Color(0.78, 0.53, 0.35), "mota": Color(0.55, 0.36, 0.22), "grav": -3.0, "n": 14, "vel": 0.30, "nucleo": "roca"},
	"tiempo": {"color": Color(0.72, 0.58, 0.98), "mota": Color(0.95, 0.88, 1.0),  "grav": 0.2,  "n": 20, "vel": 0.25, "nucleo": "anillo"},
}
const RADIO_VOLUTA: float = 0.09          ## núcleo que viaja (u)
const RADIO_FORMA: float = 0.25           ## núcleo en la mano: el mismo de la bola del Lanzador (RADIO_BOLA)
const ALTO_ARCO: float = 0.25             ## cuánto sube la voluta a mitad de camino (como el hilo del Juego)

## Orígenes de cast point que sabe dibujar este nodo (los de `CastPoints`). Cualquier otro valor se trata como «mano_libre».
const ORIGENES: Array = ["mano_libre", "manos_alto", "suelo_delante"]
const RADIO_CIRCULO: float = 0.85         ## radio del círculo rúnico del suelo (u; la casilla mide 2,3)
const ALTO_COLUMNA: float = 1.9           ## altura de la columna de luz sobre las manos (u)
const ALTURA_MANOS_ALTO: float = 1.6      ## si no hay `destino` ni suelo bajo las manos, se supone el suelo a esta altura por debajo
const T_AUTOLIMPIEZA: float = 6.0         ## si el disparo no llega (jugador muerto, conjuro interrumpido) la forma se retira sola

## Círculo rúnico: aro exterior que se dibuja con `progreso` (0..1) y gira con `giro`, aro interior y marcas que aparecen al cerrarse.
## `destello` (0..2) lo aviva al disparar y `alfa` lo apaga. Aditivo: no tapa el suelo.
const CODIGO_ANILLO: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 mota : source_color = vec4(1.0);
uniform float progreso : hint_range(0.0, 1.0) = 0.0;
uniform float giro = 0.0;
uniform float destello : hint_range(0.0, 2.0) = 0.0;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform float marcas = 10.0;
float seg(float x, float a, float b, float s) {
	return smoothstep(a - s, a, x) - smoothstep(b, b + s, x);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = fract((atan(p.y, p.x) + giro) / 6.2831853);
	float s = 0.014;
	float ext = seg(r, 0.86, 0.93, s);
	float arco = step(t, progreso);
	float cabeza = smoothstep(progreso - 0.07, progreso, t) * step(t, progreso);
	float inte = seg(r, 0.56, 0.60, s) * smoothstep(0.3, 0.9, progreso);
	float marca = seg(r, 0.64, 0.80, s) * step(fract(t * marcas), 0.13) * smoothstep(0.4, 1.0, progreso);
	float disco = smoothstep(0.55, 0.0, r) * 0.28 * progreso;
	float m = ext * arco + ext * cabeza * 1.4 + inte + marca * 0.85 + disco;
	vec3 col = mix(color.rgb, mota.rgb, clamp(ext * cabeza + marca, 0.0, 1.0)) * (1.6 + destello * 2.0) + vec3(destello * 0.6);
	ALBEDO = col;
	ALPHA = clamp(m, 0.0, 1.0) * alfa * (1.0 - smoothstep(0.96, 1.0, r));
}
"""

## Columna de luz: cilindro abierto, brillante en la base (las manos) y que se apaga hacia arriba; el borde se desvanece (fresnel)
## para que parezca un haz y no un tubo, con vetas que suben. El mesh tiene la base en y = 0 (su origen), `alto` es su altura.
const CODIGO_COLUMNA: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color = vec4(1.0);
uniform vec4 mota : source_color = vec4(1.0);
uniform float brillo = 1.7;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform float destello : hint_range(0.0, 2.0) = 0.0;
uniform float alto = 1.9;
varying float vy;
void vertex() {
	vy = clamp(VERTEX.y / alto + 0.5, 0.0, 1.0);
}
void fragment() {
	float f = 1.0 - vy;
	float borde = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.3);
	float vetas = 0.72 + 0.28 * sin(UV.x * 40.0 + TIME * 6.0 - vy * 10.0);
	float a = f * f * borde * vetas;
	ALBEDO = mix(color.rgb, mota.rgb, f * f) * brillo * (1.0 + destello * 1.5);
	ALPHA = clamp(a * 1.6, 0.0, 1.0) * alfa;
}
"""

## Onda corta del disparo: un aro que se abre (`radio` 0..1) y se apaga. `bill` = true: mira siempre a cámara (quad); false: tumbada (plano).
const CODIGO_ONDA: String = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 color : source_color = vec4(1.0);
uniform float radio = 0.2;
uniform float grosor = 0.12;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform bool bill = false;
void vertex() {
	if (bill) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	}
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = smoothstep(grosor, 0.0, abs(r - radio)) * (1.0 - smoothstep(0.9, 1.0, r));
	ALBEDO = color.rgb * 2.2;
	ALPHA = a * alfa;
}
"""

static var _sh_anillo: Shader = null
static var _sh_columna: Shader = null
static var _sh_onda: Shader = null

var _lanzador: Object = null
var _mano: Vector3 = Vector3.ZERO
var _vivos: Array[Node] = []
var _origen: String = "mano_libre"      ## origen del cast point del conjuro en curso (lo resuelve `_resolver_origen` al empezar «forma»)
var _destino: Vector3 = Vector3.INF    ## punto del suelo donde nacerá el hechizo (INF = no lo sabemos)


## Crea el nodo, lo cuelga de `padre` y lo conecta al Lanzador. Devuelve null si no hay señal a la que engancharse.
static func conectar(lanzador: Object, padre: Node) -> ConjuroVfx3D:
	if lanzador == null or not lanzador.has_signal("conjuro_fase") or padre == null:
		return null
	var c := ConjuroVfx3D.new()
	c.name = "ConjuroVfx3D"
	padre.add_child(c)
	c._lanzador = lanzador
	lanzador.connect("conjuro_fase", Callable(c, "_al_fase"))
	return c


func _al_fase(fase: String, elemento: String, posicion: Vector3) -> void:
	var t: Array = [0.1, 0.25, 0.1]
	if _lanzador != null and _lanzador.has_method("tiempos_conjuro"):
		t = _lanzador.call("tiempos_conjuro", elemento)
	match fase:
		"runa":
			limpiar()                    # lo que quedara de un conjuro anterior que no llegó a disparar
			_mano = posicion
		"voluta":
			voluta(elemento, posicion, _mano, float(t[1]))
		"forma":
			_mano = posicion
			_resolver_origen(elemento)
			forma(elemento, posicion, float(t[2]), _origen, _destino)
		"disparo":
			destello(elemento, posicion, _origen)
			onda(elemento, posicion, _origen)
			retirar_forma()
			_origen = "mano_libre"
			_destino = Vector3.INF


## Pregunta al Lanzador por el origen del cast point (`origen_conjuro(elemento) -> {"origen", "destino"}`). Sin ese método, o con un
## origen que no conocemos, vale «mano_libre»: la forma en la mano de siempre.
func _resolver_origen(elemento: String) -> void:
	_origen = "mano_libre"
	_destino = Vector3.INF
	if _lanzador == null or not _lanzador.has_method("origen_conjuro"):
		return
	var d: Variant = _lanzador.call("origen_conjuro", elemento)
	if not (d is Dictionary):
		return
	var o: String = String((d as Dictionary).get("origen", "mano_libre"))
	_origen = o if ORIGENES.has(o) else "mano_libre"
	var dest: Variant = (d as Dictionary).get("destino", Vector3.INF)
	if dest is Vector3:
		_destino = dest as Vector3


## La voluta: núcleo con cola que va de `desde` a `hasta` en `dura` s por un arco. Se retira sola al llegar.
func voluta(elemento: String, desde: Vector3, hasta: Vector3, dura: float) -> Node3D:
	var p: Dictionary = _perfil(elemento)
	var cab := Node3D.new()
	add_child(cab)
	cab.global_position = desde
	_vivos.append(cab)
	var nucleo: MeshInstance3D = _nucleo(p, RADIO_VOLUTA)
	cab.add_child(nucleo)
	cab.add_child(_motas(p, 0.5))
	var medio: Vector3 = (desde + hasta) * 0.5 + Vector3(0.0, ALTO_ARCO, 0.0)
	dura = maxf(dura, 0.05)
	var tw := cab.create_tween()
	tw.tween_method(func(k: float) -> void:
		# Bézier cuadrática: el mismo arco que el hilo del Juego, con un balanceo lateral que da vida a la voluta.
		var a: Vector3 = desde.lerp(medio, k)
		var b: Vector3 = medio.lerp(hasta, k)
		var q: Vector3 = a.lerp(b, k)
		var lado: Vector3 = (hasta - desde).cross(Vector3.UP).normalized()
		cab.global_position = q + lado * sin(k * TAU * 2.0) * 0.05 * (1.0 - k), 0.0, 1.0, dura)
	tw.tween_callback(func() -> void:
		var gp := cab.get_node_or_null("Motas") as GPUParticles3D
		if gp != null:
			gp.emitting = false      # deja de emitir pero las motas ya soltadas acaban su vida
		nucleo.visible = false)
	tw.tween_interval(0.8)
	tw.tween_callback(cab.queue_free)
	return cab


## La forma del conjuro EN EL CAST POINT (`pos`), según su `origen`: crece durante `dura` s y se queda (con un latido) hasta el disparo,
## que la retira con `retirar_forma`. `destino` = punto del suelo donde nacerá el hechizo (lo usa «manos_alto»; INF = buscarlo).
func forma(elemento: String, pos: Vector3, dura: float, origen: String = "mano_libre", destino: Vector3 = Vector3.INF) -> Node3D:
	var p: Dictionary = _perfil(elemento)
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = pos
	_vivos.append(raiz)
	dura = maxf(dura, 0.05)
	match origen:
		"manos_alto":
			_forma_alto(raiz, p, pos, dura, destino)
		"suelo_delante":
			_forma_suelo(raiz, p, dura)
		_:
			_forma_mano(raiz, p, dura)
	# Si el disparo no llega (muerte, interrupción) la forma no se queda colgando para siempre.
	# Un tween atado a `raiz` y no un temporizador del árbol con una lambda que captura `raiz`: si el disparo la retira antes de los 6 s, el tween muere con ella,
	# mientras que el temporizador seguía vivo y, al saltar, llamaba a una lambda cuya captura ya estaba liberada («Lambda capture at index 0 was freed», 26 avisos por pasada de la prueba).
	var auto := raiz.create_tween()
	auto.tween_interval(T_AUTOLIMPIEZA)
	auto.tween_callback(raiz.queue_free)
	return raiz


## mano_libre: el núcleo del elemento crece de 0,2 a 1 con una luz, y a su alrededor convergen chispas hacia él. Después late.
func _forma_mano(raiz: Node3D, p: Dictionary, dura: float) -> void:
	var nucleo: MeshInstance3D = _nucleo(p, RADIO_FORMA)
	raiz.add_child(nucleo)
	nucleo.scale = Vector3.ONE * 0.2
	raiz.add_child(_motas(p, 0.8))
	raiz.add_child(_chispas_convergentes(p, 0.6))
	var luz := OmniLight3D.new()
	luz.light_color = p["color"]
	luz.omni_range = 2.2
	luz.light_energy = 0.0
	luz.shadow_enabled = false
	raiz.add_child(luz)
	var tw := raiz.create_tween().set_parallel(true)
	tw.tween_property(nucleo, "scale", Vector3.ONE, dura).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(luz, "light_energy", 1.4, dura)
	if nucleo.has_meta("gira"):
		tw.tween_property(nucleo, "rotation:y", TAU, dura + 0.3)
	_latido(raiz, nucleo, dura)


## manos_alto: una columna de luz sube sobre las manos y, en el suelo delante, se dibuja el círculo donde nacerá el hechizo.
func _forma_alto(raiz: Node3D, p: Dictionary, pos: Vector3, dura: float, destino: Vector3) -> void:
	var mats: Array = []
	# Orbe pequeño entre las manos.
	var nucleo: MeshInstance3D = _nucleo(p, RADIO_FORMA * 0.7)
	raiz.add_child(nucleo)
	nucleo.scale = Vector3.ONE * 0.2
	# La columna: pivote con la base en las manos; crece hacia arriba (escala en Y).
	var pivote := Node3D.new()
	raiz.add_child(pivote)
	pivote.scale = Vector3(1.0, 0.04, 1.0)
	var cil := CylinderMesh.new()
	cil.top_radius = 0.09
	cil.bottom_radius = 0.24
	cil.height = ALTO_COLUMNA
	cil.radial_segments = 18
	cil.rings = 1
	cil.cap_top = false
	cil.cap_bottom = false
	var mc := ShaderMaterial.new()
	mc.shader = _shader(CODIGO_COLUMNA, 1)
	mc.set_shader_parameter("color", p["color"])
	mc.set_shader_parameter("mota", p["mota"])
	mc.set_shader_parameter("alto", ALTO_COLUMNA)
	var col := MeshInstance3D.new()
	col.mesh = cil
	col.position = Vector3(0.0, ALTO_COLUMNA * 0.5, 0.0)
	col.material_override = mc
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivote.add_child(col)
	mats.append(mc)
	# Motas que suben por la columna.
	raiz.add_child(_subida(p))
	# Círculo que se dibuja en el suelo, delante.
	var suelo: Vector3 = destino if destino.is_finite() else _suelo_bajo(pos)
	var anillo: MeshInstance3D = _anillo(p, RADIO_CIRCULO)
	raiz.add_child(anillo)
	anillo.global_position = suelo + Vector3(0.0, 0.03, 0.0)
	var ma: ShaderMaterial = anillo.material_override as ShaderMaterial
	mats.append(ma)
	raiz.set_meta("mats", mats)
	var luz := OmniLight3D.new()
	luz.light_color = p["color"]
	luz.omni_range = 2.6
	luz.light_energy = 0.0
	luz.shadow_enabled = false
	luz.position = Vector3(0.0, 0.6, 0.0)
	raiz.add_child(luz)
	var tw := raiz.create_tween().set_parallel(true)
	tw.tween_property(nucleo, "scale", Vector3.ONE, dura).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivote, "scale:y", 1.0, dura * 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(luz, "light_energy", 1.6, dura)
	tw.tween_method(func(v: float) -> void: ma.set_shader_parameter("progreso", v), 0.0, 1.0, dura).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_girar(raiz, ma, 1.7)
	_latido(raiz, nucleo, dura)


## suelo_delante: círculo rúnico en el suelo que se cierra girando; sube un polvo de motas del aro. Destella al disparar (`retirar_forma`).
func _forma_suelo(raiz: Node3D, p: Dictionary, dura: float) -> void:
	var anillo: MeshInstance3D = _anillo(p, RADIO_CIRCULO)
	raiz.add_child(anillo)
	anillo.position = Vector3(0.0, 0.03, 0.0)
	var ma: ShaderMaterial = anillo.material_override as ShaderMaterial
	raiz.set_meta("mats", [ma])
	raiz.set_meta("expande", true)
	var gp: GPUParticles3D = _particulas_luz(p, 20, 0.8, 0.09)
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_height = 0.02
	pm.emission_ring_radius = RADIO_CIRCULO * 0.9
	pm.emission_ring_inner_radius = RADIO_CIRCULO * 0.8
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3.ZERO
	gp.position = Vector3(0.0, 0.05, 0.0)
	raiz.add_child(gp)
	var luz := OmniLight3D.new()
	luz.light_color = p["color"]
	luz.omni_range = 2.4
	luz.light_energy = 0.0
	luz.shadow_enabled = false
	luz.position = Vector3(0.0, 0.5, 0.0)
	raiz.add_child(luz)
	var tw := raiz.create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void: ma.set_shader_parameter("progreso", v), 0.0, 1.0, dura).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(luz, "light_energy", 1.4, dura)
	_girar(raiz, ma, 2.4)


## Gira el círculo sin parar (`vueltas_por_s` · 2π rad/s) hasta que el nodo desaparezca.
func _girar(raiz: Node3D, mat: ShaderMaterial, rad_por_s: float) -> void:
	var tw := raiz.create_tween().set_loops()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("giro", v), 0.0, TAU, TAU / rad_por_s)


## Cuando termina de crecer, el núcleo late (±8 %): se nota que el conjuro está vivo y esperando el disparo.
func _latido(raiz: Node3D, nucleo: Node3D, dura: float) -> void:
	var tw := raiz.create_tween()
	tw.tween_interval(dura)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(nucleo):
			return
		var lt := nucleo.create_tween().set_loops()
		lt.tween_property(nucleo, "scale", Vector3.ONE * 1.08, 0.14).set_trans(Tween.TRANS_SINE)
		lt.tween_property(nucleo, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_SINE))


## Un círculo rúnico plano (decal tumbado) de radio `radio` con el color del elemento. El material se queda en `material_override`.
func _anillo(p: Dictionary, radio: float) -> MeshInstance3D:
	var pl := PlaneMesh.new()
	pl.size = Vector2(radio * 2.0, radio * 2.0)
	var m := ShaderMaterial.new()
	m.shader = _shader(CODIGO_ANILLO, 0)
	m.set_shader_parameter("color", p["color"])
	m.set_shader_parameter("mota", p["mota"])
	var mi := MeshInstance3D.new()
	mi.mesh = pl
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## El suelo bajo `pos`: un rayo hacia abajo; si no choca con nada, se supone a `ALTURA_MANOS_ALTO` por debajo.
func _suelo_bajo(pos: Vector3) -> Vector3:
	if is_inside_tree() and get_world_3d() != null:
		var q := PhysicsRayQueryParameters3D.create(pos, pos + Vector3.DOWN * 4.0)
		var r: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			return r["position"] as Vector3
	return Vector3(pos.x, pos.y - ALTURA_MANOS_ALTO, pos.z)


## Partículas de luz del color del elemento (puntos blandos aditivos que se apagan). El llamador ajusta `process_material`.
func _particulas_luz(p: Dictionary, n: int, vida: float, tam: float) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.amount = n
	gp.lifetime = vida
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-4, -3, -4), Vector3(8, 6, 8))
	var pm := ParticleProcessMaterial.new()
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var mota: Color = p["mota"]
	var col: Color = p["color"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(mota, 1.0), Color(col, 0.85), Color(col, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = VfxKit3D.mancha()
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	q.material = sm
	gp.draw_pass_1 = q
	gp.emitting = true
	return gp


## Chispas que nacen en una esfera de radio `radio` alrededor del núcleo y convergen hacia él (aceleración radial hacia dentro).
## Con `local_coords` siguen a la mano si se mueve.
func _chispas_convergentes(p: Dictionary, radio: float) -> GPUParticles3D:
	var gp: GPUParticles3D = _particulas_luz(p, 30, 0.36, 0.07)
	gp.name = "Convergen"
	gp.local_coords = true
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = radio
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.0
	pm.gravity = Vector3.ZERO
	# 2·r / t² con t ≈ lifetime: llegan al núcleo justo al apagarse.
	var a: float = 2.0 * radio / (0.34 * 0.34)
	pm.radial_accel_min = -a
	pm.radial_accel_max = -a * 1.15
	return gp


## Motas que suben por la columna de luz.
func _subida(p: Dictionary) -> GPUParticles3D:
	var gp: GPUParticles3D = _particulas_luz(p, 22, 0.9, 0.08)
	gp.name = "Subida"
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.16
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 1.8
	pm.gravity = Vector3.ZERO
	return gp


## Shader cacheado (0 = anillo, 1 = columna, 2 = onda).
func _shader(codigo: String, cual: int) -> Shader:
	match cual:
		1:
			if _sh_columna == null:
				_sh_columna = Shader.new()
				_sh_columna.code = codigo
			return _sh_columna
		2:
			if _sh_onda == null:
				_sh_onda = Shader.new()
				_sh_onda.code = codigo
			return _sh_onda
		_:
			if _sh_anillo == null:
				_sh_anillo = Shader.new()
				_sh_anillo.code = codigo
			return _sh_anillo


## Destello del disparo en el cast point: una esfera de luz que crece y se apaga en 0,2 s. Con origen «suelo_delante» el destello va
## aplastado contra el suelo (el círculo ya destella solo).
func destello(elemento: String, pos: Vector3, origen: String = "mano_libre") -> void:
	var p: Dictionary = _perfil(elemento)
	var m := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = RADIO_FORMA
	esf.height = RADIO_FORMA * 2.0
	m.mesh = esf
	var mat := _material(Color(p["color"]).lerp(Color.WHITE, 0.5), 3.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos
	var fin: Vector3 = Vector3.ONE * 2.2
	if origen == "suelo_delante":
		fin = Vector3(2.6, 0.7, 2.6)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, "scale", fin, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(m.queue_free)


## Onda corta del disparo en el cast point: un aro que se abre y se apaga en 0,25 s. Tumbada en el suelo si el origen es el suelo;
## en las manos, de cara a la cámara.
func onda(elemento: String, pos: Vector3, origen: String = "mano_libre") -> void:
	var p: Dictionary = _perfil(elemento)
	var suelo: bool = origen == "suelo_delante"
	var mat := ShaderMaterial.new()
	mat.shader = _shader(CODIGO_ONDA, 2)
	mat.set_shader_parameter("color", Color(p["color"]).lerp(Color.WHITE, 0.35))
	mat.set_shader_parameter("bill", not suelo)
	var mi := MeshInstance3D.new()
	if suelo:
		var pl := PlaneMesh.new()
		pl.size = Vector2.ONE
		mi.mesh = pl
	else:
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos + (Vector3(0.0, 0.05, 0.0) if suelo else Vector3.ZERO)
	mi.scale = Vector3.ONE * 2.0
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("radio", v), 0.1, 0.95, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("alfa", v), 1.0, 0.0, 0.25)
	tw.chain().tween_callback(mi.queue_free)


## Retira la forma al disparar. La del suelo y la columna no se cortan: destellan (0,07 s) y se apagan (0,2 s); lo demás desaparece ya.
func retirar_forma() -> void:
	for n in _vivos:
		if not is_instance_valid(n):
			continue
		if n.has_meta("mats"):
			_apagar_destellando(n as Node3D)
		else:
			n.queue_free()
	_vivos.clear()


func _apagar_destellando(n: Node3D) -> void:
	var mats: Array = n.get_meta("mats")
	var tw := n.create_tween()
	tw.tween_method(_destello_mats.bind(mats), 0.0, 1.0, 0.07)
	tw.tween_method(_apagar_mats.bind(mats), 0.0, 1.0, 0.2)
	tw.tween_callback(n.queue_free)
	if n.has_meta("expande"):
		n.create_tween().tween_property(n, "scale", Vector3(1.18, 1.0, 1.18), 0.27).set_ease(Tween.EASE_OUT)


## Sube el destello de los materiales de la forma (los argumentos ligados con `bind` llegan DESPUÉS del valor del tween).
func _destello_mats(v: float, mats: Array) -> void:
	for m in mats:
		(m as ShaderMaterial).set_shader_parameter("destello", v)


## Baja a la vez el destello y la opacidad (v = 0 → 1).
func _apagar_mats(v: float, mats: Array) -> void:
	for m in mats:
		(m as ShaderMaterial).set_shader_parameter("destello", 1.0 - v)
		(m as ShaderMaterial).set_shader_parameter("alfa", 1.0 - v)


## Retira lo que quede del conjuro (la forma en la mano). La cola de la voluta se apaga sola.
func limpiar() -> void:
	for n in _vivos:
		if is_instance_valid(n):
			n.queue_free()
	_vivos.clear()


func _perfil(elemento: String) -> Dictionary:
	return PERFIL.get(elemento, PERFIL["fuego"])


func _material(color: Color, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energia
	return m


## El núcleo según el elemento: esfera (fuego, agua), punto pequeño (viento), chispa alargada (rayo), cristal (hielo), roca (tierra), anillo (tiempo).
func _nucleo(p: Dictionary, radio: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var color: Color = p["color"]
	match String(p["nucleo"]):
		"pequeno":
			var s := SphereMesh.new(); s.radius = radio * 0.6; s.height = radio * 1.2; m.mesh = s
		"chispa":
			var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = radio * 0.5; c.height = radio * 1.8; c.radial_segments = 5
			m.mesh = c; m.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		"cristal":
			var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = radio * 0.8; c.height = radio * 2.2; c.radial_segments = 6
			m.mesh = c; m.set_meta("gira", true)
		"roca":
			var s := SphereMesh.new(); s.radius = radio; s.height = radio * 2.0; s.radial_segments = 6; s.rings = 3; m.mesh = s
			m.set_meta("gira", true)
		"anillo":
			var t := TorusMesh.new(); t.inner_radius = radio * 0.65; t.outer_radius = radio; m.mesh = t
			m.rotation_degrees = Vector3(70.0, 0.0, 0.0); m.set_meta("gira", true)
		_:
			var s := SphereMesh.new(); s.radius = radio; s.height = radio * 2.0; m.mesh = s
	var fuera: StandardMaterial3D = _material(Color(color, 0.72), 2.2)
	fuera.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA     # translúcido: deja ver el corazón de dentro
	m.material_override = fuera
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Corazón más claro (calor / brillo) y halo blando: sin ellos el núcleo se lee como un disco plano de un solo color.
	var dentro := MeshInstance3D.new()
	dentro.mesh = m.mesh
	dentro.scale = Vector3.ONE * 0.55
	dentro.material_override = _material(color.lerp(Color.WHITE, 0.75), 3.0)
	dentro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(dentro)
	var halo := MeshInstance3D.new()
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_texture = VfxKit3D.mancha()
	hm.albedo_color = Color(color, 0.55)
	hm.no_depth_test = false
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED      # el billboard da la vuelta al cuadrado: con las caras de culling normal la malla propia (a diferencia de QuadMesh) quedaba de espaldas y el halo desaparecía
	halo.mesh = _malla_halo(radio * 5.0)
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(halo)
	return m


## El cuadrado del halo como `ArrayMesh` (centrado, mirando a +Z) y no como `QuadMesh`: en Godot `QuadMesh` HEREDA de `PlaneMesh`, y la prueba reconoce el círculo rúnico del suelo
## con `mesh is PlaneMesh`, así que un halo de núcleo de la mano lo tomaba por un círculo en el suelo (fallaba «orbe con chispas que convergen» en los ocho elementos). El tamaño va
## en la malla y no en la escala del nodo: con `billboard_mode` y sin `billboard_keep_scale` el material descarta la escala. Una malla por tamaño, cacheada.
static var _mallas_halo: Dictionary = {}

static func _malla_halo(lado: float) -> ArrayMesh:
	var clave: int = roundi(lado * 1000.0)
	if _mallas_halo.has(clave):
		return _mallas_halo[clave]
	var h: float = lado * 0.5
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-h, -h, 0.0), Vector3(h, -h, 0.0), Vector3(h, h, 0.0), Vector3(-h, h, 0.0)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mallas_halo[clave] = m
	return m


## Cola de motas del color del elemento (puntos blandos que se apagan). `escala` = tamaño relativo.
func _motas(p: Dictionary, escala: float) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.name = "Motas"
	gp.amount = int(p["n"])
	gp.lifetime = 0.45
	gp.local_coords = false          # la cola se queda atrás cuando el núcleo se mueve
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-4, -3, -4), Vector3(8, 6, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = float(p["vel"]) * 0.4
	pm.initial_velocity_max = float(p["vel"])
	pm.gravity = Vector3(0.0, float(p["grav"]), 0.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	pm.scale_min = 0.5 * escala
	pm.scale_max = 1.0 * escala
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var mota: Color = p["mota"]
	var col: Color = p["color"]
	g.colors = PackedColorArray([Color(mota, 1.0), Color(col, 0.8), Color(col, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = VfxKit3D.mancha()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	q.material = sm
	gp.draw_pass_1 = q
	gp.emitting = true
	return gp
