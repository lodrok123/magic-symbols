class_name VfxCanouro3D
extends RefCounted

## VFX DEL CANOURO (17/10, Pablo: «humo negro alrededor de las patas» y «un zarpazo que genere un vfx en el jugador de unas garras»).
## Dos efectos independientes y sin estado global (no tocan `VfxKit3D.elemento`):
##  · `humo_patas(modelo, esc)`: humo negro continuo que sale de los cuatro pies y se queda atrás al andar.
##  · `zarpazo(padre, pos, esc, giro)`: tres arañazos que se dibujan de un tajo sobre el jugador y se apagan.
## El EMPUJE al jugador NO está aquí: es jugabilidad (Juego). Este archivo solo pone lo que se ve.

## Pies del rig «Wolf» (medidos en canouro_anim.glb: y ≈ 0,02 con el cuerpo a ~0,45 de alto; cuelgan de los IK de cada pata).
const PIES: Array = ["FF.L", "FF.R", "FFB.L", "FFB.R"]

## Dirección del barrido de la pata en el marco LOCAL del canouro (x = su izquierda, y = arriba, z = delante): de la pata alzada y
## afuera (t = 0,24 s) a la pata cruzada delante del pecho (t = 0,48 s), medida en el clip «Zarpazo» (pie: (−0,22; 0,19; 0,13) → (0,07; 0,04; 0,39)).
## El Juego la gira con la base del enemigo: `enemigo.global_transform.basis * VfxCanouro3D.DIR_ZARPAZO_LOCAL`. Para el zarpazo con la
## pata izquierda (el clip espejo no existe aún) bastaría invertir la x.
const DIR_ZARPAZO_LOCAL: Vector3 = Vector3(0.29, -0.15, 0.26)

## Instante del golpe dentro del clip «Zarpazo» del `canouro.glb` (s desde el inicio del clip; la preparación dura hasta ~0,24 y el barrido llega a su punto más adelantado en ~0,40-0,48).
const T_GOLPE_ZARPAZO: float = 0.40

## Humo: negro casi puro, que nace opaco a medias, se ensancha y se apaga. Mezcla normal (no aditiva): el negro tiene que OSCURECER el suelo.
## Colores de las garras: núcleo hueso/blanco (como las uñas del canouro) y borde violeta-índigo (como su pelaje).
const GARRA_NUCLEO: Color = Color(0.93, 0.95, 1.0)
const GARRA_BORDE: Color = Color(0.3, 0.14, 0.62)
## Ángulo (rad, en pantalla) del tajo cuando `giro` del shader vale 0: va de arriba-izquierda a abajo-derecha, atan2(−1,6; 1,7).
const ANGULO_BASE: float = -0.7556

const HUMO_COLORES: Array = [Color(0.03, 0.03, 0.04, 0.0), Color(0.04, 0.04, 0.05, 0.7), Color(0.09, 0.09, 0.11, 0.0)]

const CODIGO_ZARPAZO: String = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// Tres arañazos curvos en un solo quad que mira a cámara. `avance` (0..1) los dibuja de un extremo al otro; `vida` (0..1) los apaga.
uniform float avance : hint_range(0.0, 1.0) = 0.0;
uniform float vida : hint_range(0.0, 1.0) = 0.0;
uniform float giro = -0.6;           // inclinación del tajo en pantalla (rad)
uniform float curva = 0.16;          // cuánto se arquea cada arañazo
uniform float ancho = 0.07;          // semianchura máxima de cada arañazo (en unidades del quad: -1..1)
uniform float separacion = 0.36;     // distancia entre garras
uniform vec4 nucleo : source_color = vec4(0.93, 0.95, 1.0, 1.0);
uniform vec4 borde : source_color = vec4(0.3, 0.14, 0.62, 1.0);
uniform float brillo = 2.2;

void vertex() {
	// Billboard: el quad siempre mira a cámara y conserva la escala del nodo.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV * 2.0 - 1.0) * vec2(1.0, -1.0);
	float c = cos(giro);
	float s_ = sin(giro);
	p = mat2(vec2(c, -s_), vec2(s_, c)) * p;
	// Eje del tajo: de arriba-izquierda a abajo-derecha; n es la normal (de una garra a la siguiente).
	vec2 a = vec2(-0.85, 0.8);
	vec2 d = vec2(1.7, -1.6);
	vec2 dir = normalize(d);
	vec2 n = vec2(-dir.y, dir.x);
	float largo = length(d);
	float s = dot(p - a, dir) / largo;
	float m = 0.0;
	float calor = 0.0;
	for (int i = -1; i <= 1; i++) {
		float k = float(i);
		// Las garras no salen a la vez: la del medio va un poco por delante.
		float av = avance * 1.18 - 0.06 * abs(k);
		float t = dot(p - a, n) - k * separacion - curva * sin(clamp(s, 0.0, 1.0) * 3.14159);
		float w = ancho * pow(max(sin(clamp(s, 0.0, 1.0) * 3.14159), 0.0), 0.65) * (1.0 - 0.18 * abs(k));
		float f = smoothstep(w, w * 0.3, abs(t)) * step(0.0, s) * step(s, 1.0);
		f *= smoothstep(av, av - 0.1, s);   // el tajo se dibuja de la cabeza a la cola
		m = max(m, f);
		calor = max(calor, f * smoothstep(w * 0.55, 0.0, abs(t)));
	}
	vec3 col = mix(borde.rgb, nucleo.rgb, calor) * brillo;
	ALBEDO = col;
	ALPHA = clamp(m, 0.0, 1.0) * (1.0 - vida);
}
"""

static var _sombreador_zarpazo: Shader = null


## Humo negro en los cuatro pies del modelo. Devuelve el nodo `Humo` (hijo de `modelo`, se libera con él).
## `esc` multiplica el tamaño de las bocanadas, en metros del MUNDO (los emisores son `top_level`, no heredan la escala del modelo):
## 1 = pensado para un canouro de 1 m de alto, como en el laboratorio; en el juego, `esc` ≈ su altura real (p. ej. 0,55).
static func humo_patas(modelo: Node3D, esc: float = 1.0) -> Node3D:
	var sks: Array[Node] = modelo.find_children("*", "Skeleton3D", true, false)
	if sks.is_empty():
		push_warning("VfxCanouro3D.humo_patas: el modelo no tiene esqueleto")
		return null
	var h := Humo.new()
	h.name = "HumoPatas"
	modelo.add_child(h)
	h.montar(sks[0] as Skeleton3D, esc)
	return h


## Tres garras que se dibujan sobre `pos` (coordenadas de `padre`, normalmente el centro del jugador), **en la dirección del
## barrido** `dir_mundo` (vector del MUNDO, por ejemplo `basis_enemigo * DIR_ZARPAZO_LOCAL`): el tajo se proyecta en la pantalla con la
## cámara activa y se dibuja de su inicio a su final, así que el ángulo coincide con el de la pata desde cualquier punto de vista.
## Se libera sola. Devuelve el MeshInstance3D.
static func zarpazo(padre: Node3D, pos: Vector3, dir_mundo: Vector3, esc: float = 1.0, dura: float = 0.5) -> MeshInstance3D:
	var giro: float = giro_para(padre.get_viewport().get_camera_3d(), dir_mundo)
	if _sombreador_zarpazo == null:
		_sombreador_zarpazo = Shader.new()
		_sombreador_zarpazo.code = CODIGO_ZARPAZO
	var mat := ShaderMaterial.new()
	mat.shader = _sombreador_zarpazo
	mat.set_shader_parameter("giro", giro)
	mat.set_shader_parameter("nucleo", GARRA_NUCLEO)
	mat.set_shader_parameter("borde", GARRA_BORDE)
	mat.render_priority = 5
	var q := QuadMesh.new()
	q.size = Vector2(1.7, 1.7) * esc
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	padre.add_child(mi)
	# Reparto del tiempo: el tajo se dibuja rápido (28 %), se queda un instante y se apaga el resto.
	var t_tajo: float = dura * 0.28
	var tw := mi.create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("avance", v), 0.0, 1.0, t_tajo).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_interval(dura * 0.17)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("vida", v), 0.0, 1.0, dura * 0.55)
	tw.tween_callback(mi.queue_free)
	# Un puñado de motas oscuras saltan del tajo (reutiliza el humo, de un disparo).
	var motas := Humo.crear_emisor(esc, false)
	motas.position = pos
	padre.add_child(motas)
	motas.emitting = true
	padre.get_tree().create_timer(1.6, false).timeout.connect(motas.queue_free)
	return mi


## Giro del shader (rad) para que el tajo apunte en pantalla como `dir_mundo` visto desde `cam`. Sin cámara, o si el barrido va casi
## a lo largo del eje de la vista (no se vería como línea), devuelve un giro por defecto.
static func giro_para(cam: Camera3D, dir_mundo: Vector3) -> float:
	if cam == null:
		return -0.6
	var b: Basis = cam.global_transform.basis
	var sx: float = dir_mundo.dot(b.x)
	var sy: float = dir_mundo.dot(b.y)
	if absf(sx) + absf(sy) < 0.001:
		return -0.6
	return atan2(sy, sx) - ANGULO_BASE


## Nodo que sigue a los pies del esqueleto cada fotograma. Los emisores son `top_level` y se colocan a mano: así el humo no
## hereda la escala del modelo (que depende de ALTO) ni se arrastra pegado a la pata, y se queda atrás cuando el canouro avanza.
class Humo extends Node3D:
	var _sk: Skeleton3D = null
	var _huesos: Array[int] = []
	var _emisores: Array[GPUParticles3D] = []

	func montar(sk: Skeleton3D, esc: float) -> void:
		_sk = sk
		for n in VfxCanouro3D.PIES:
			var i: int = sk.find_bone(String(n))
			if i < 0:
				push_warning("VfxCanouro3D: el esqueleto no tiene el hueso " + String(n))
				continue
			var e: GPUParticles3D = Humo.crear_emisor(esc, true)
			e.top_level = true
			add_child(e)
			_huesos.append(i)
			_emisores.append(e)
		set_process(true)

	func _process(_d: float) -> void:
		if _sk == null:
			return
		for k in _emisores.size():
			_emisores[k].global_position = (_sk.global_transform * _sk.get_bone_global_pose(_huesos[k])).origin

	## Activa o apaga la emisión (las bocanadas ya lanzadas terminan su vida).
	func activar(si: bool) -> void:
		for e in _emisores:
			e.emitting = si

	## Un emisor de humo. `continuo` = nube de los pies; si no, una ráfaga corta de motas que saltan hacia arriba.
	static func crear_emisor(esc: float, continuo: bool) -> GPUParticles3D:
		var gp := GPUParticles3D.new()
		gp.amount = 14 if continuo else 10
		gp.lifetime = 1.1 if continuo else 0.6
		gp.one_shot = not continuo
		gp.explosiveness = 0.0 if continuo else 0.9
		gp.local_coords = false
		gp.emitting = continuo
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gp.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 5, 8))
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3.UP
		pm.spread = 35.0 if continuo else 70.0
		pm.initial_velocity_min = (0.05 if continuo else 0.5) * esc
		pm.initial_velocity_max = (0.18 if continuo else 1.2) * esc
		pm.gravity = Vector3(0.0, 0.05 if continuo else -1.2, 0.0)
		pm.damping_min = 0.4
		pm.damping_max = 0.8
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.05 * esc
		pm.scale_min = (0.16 if continuo else 0.07) * esc
		pm.scale_max = (0.26 if continuo else 0.14) * esc
		# Crece mientras se apaga: la bocanada se ensancha y se deshace.
		var curva := Curve.new()
		curva.add_point(Vector2(0.0, 0.5))
		curva.add_point(Vector2(0.45, 1.0))
		curva.add_point(Vector2(1.0, 1.3))
		var ct := CurveTexture.new()
		ct.curve = curva
		pm.scale_curve = ct
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		g.colors = PackedColorArray(VfxCanouro3D.HUMO_COLORES)
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		gp.process_material = pm
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.billboard_keep_scale = true
		sm.vertex_color_use_as_albedo = true
		sm.albedo_texture = VfxKit3D.mancha()
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		q.orientation = PlaneMesh.FACE_Z
		q.material = sm
		gp.draw_pass_1 = q
		return gp
