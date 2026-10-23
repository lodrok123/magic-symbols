class_name ClipsFamilia
extends RefCounted

## Los clips de una familia (docs/PLAN_RIGGING.md §3.6) para un modelo que no trae los suyos: se leen del GLB de otro modelo con los MISMOS
## nombres de hueso Mixamo y se pasan al esqueleto del nuevo (retarget en código, una vez por sesión).
##
## Por qué hace falta retarget: los dos esqueletos se llaman igual pero NO tienen la misma pose de reposo (cada hueso tiene su propio eje local y
## proporciones distintas: elfo_base tiene piernas más largas y la cadera a 0,48 u de 0,98; chibi_elf a 0,64 de 1,7). Una pista de rotación de Godot
## es el giro LOCAL absoluto, así que copiarla tal cual tuerce el cuerpo. Aquí se copia el MOVIMIENTO: lo que cada hueso gira en el espacio del modelo
## respecto a su reposo (`delta = global_animado · global_reposo⁻¹`) se aplica al reposo del esqueleto destino y se vuelve a pasar a local.
## Es lo que hace el importador de Godot con BoneMap + Rest Fixer, pero sin tocar el GLB. Los huesos que la fuente no tiene (los dedos) siguen a su
## padre en su pose de reposo. La traslación de la cadera se reescala con la relación de alturas de cadera, y todo el clip se sube/baja la misma
## cantidad fija para que, con el Idle, el pie más bajo quede a la altura que tiene en el reposo (pies en el suelo).
## Un modelo puede tomar clips de VARIOS GLB y con otros nombres (FUENTES: el goblin asesino usa Gribble para moverse y el goblin guerrero para las reacciones), y un
## clip suelto de otro GLB se traduce con `traducir_clip` (el empujado y levantarse de Pj3D).

## Modelo (id de GLB) -> de dónde toma sus clips. Solo para modelos que NO traen AnimationPlayer propio. Cada fuente es un GLB de la familia (mismos
## nombres de hueso Mixamo, aunque no la misma pose de reposo) con:
##   · «ruta»: el GLB (con esqueleto y AnimationPlayer; la malla da igual y puede faltar: arte/meshy/solo_clips.py la quita);
##   · «referencia»: el clip de la fuente con el que los pies de la fuente pisan el suelo del destino (el reposo de pie; por defecto «Idle»);
##   · «clips»: {nombre en el destino: nombre en la fuente}. Vacío = todos los de la fuente con su propio nombre;
##   · «centrar» (opcional): nombres de clip de la fuente cuya cadera se centra sobre el personaje (`_centrar_cadera`).
## Si dos fuentes dan el mismo nombre de clip, gana la primera.
const FUENTES: Dictionary = {
	"elfo_base": [
		{"ruta": "res://arte/modelos/chibi_elf.glb", "referencia": "Idle", "clips": {}},
	],
	# Jugadora base (23/10, Meshy «Willow Fernstep» pasada a Mixamo, 65 huesos con dedos + headfront): los 22 clips de la elfa actual.
	"jugadora_base": [
		{"ruta": "res://arte/modelos/chibi_elf.glb", "referencia": "Idle", "clips": {}},
	],
	# Goblin asesino (22/10): el movimiento sale de «Gribble the Goblin, All Animations» (Meshy; solo su esqueleto y sus clips) y las reacciones, de los
	# clips del goblin guerrero (el mismo rig de Meshy). Nombres de destino = los de los roles de Pj3D.SINONIMOS.
	"goblin_asesino": [
		{"ruta": "res://arte/meshy/gribble_clips.glb", "referencia": "Combat_Stance", "centrar": ["Combat_Stance"], "clips": {
			"idle": "Combat_Stance",                              # guardia con las rodillas dobladas
			"walk": "Crouch_Walk_with_Torch",                     # el andar agazapado hacia delante (lleva el brazo de la antorcha)
			"run": "Running",
			"paso_lado": "Cautious_Crouch_Walk_Right_inplace",    # agazapado, pero de LADO (no sirve para avanzar)
			"guardia": "_01a165a5_cbee_74b5_b15b_32bb9f9f273a",   # sin nombre: pasos de boxeador con la guardia alta; avanza (no es un ataque)
		}},
		{"ruta": "res://arte/modelos/goblin_warrior_chibi.glb", "referencia": "Idle", "clips": {
			"hit": "SlapReaction", "death": "Die", "drowning": "Drowning",
		}},
	],
}

## Muestreo de los clips traducidos (los de la fuente van a 30 fps).
const FPS_MUESTREO: float = 30.0
## Cadera de la fuente por debajo de esto (u) = no se puede calcular la relación de alturas: se deja la escala en 1.
const CADERA_MIN: float = 0.01
## Terminaciones de los huesos que cuentan como «suela» para apoyar los pies (el más bajo de ellos manda).
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]
## Clip de la fuente con el que se mide la altura de los pies si la fuente no dice otro (el reposo de pie).
const CLIP_REFERENCIA: String = "Idle"
## Tolerancia (en grados) de la rotación del nodo del esqueleto respecto al modelo: por encima, el retarget asume que fuente y destino difieren y avisa.
const GIRO_NODO_TOL: float = 1.0

static var _cache: Dictionary = {}     ## id del GLB destino -> {nombre de clip: Animation}
static var _cache_clip: Dictionary = {}    ## id|ruta|clip -> Animation traducida suelta (ver `traducir_clip`)


static func tiene_fuente(glb_id: String) -> bool:
	return FUENTES.has(glb_id)


## Los clips de la familia ya traducidos al esqueleto `sk_d` del modelo `modelo_d` (raíz de la escena del GLB `glb_id`). Las pistas llevan la ruta
## del esqueleto relativa a `modelo_d`, así que el AnimationPlayer ha de colgar de `modelo_d` (root_node = ".."). Vacío si algo falla.
static func clips_para(glb_id: String, modelo_d: Node3D, sk_d: Skeleton3D) -> Dictionary:
	if _cache.has(glb_id):
		return _cache[glb_id]
	var res: Dictionary = {}
	for f in (FUENTES.get(glb_id, []) as Array):
		_traer_de(f as Dictionary, modelo_d, sk_d, res)
	if not res.is_empty():
		_cache[glb_id] = res
	return res


## Un clip suelto de OTRO GLB de la familia (p. ej. el BeHit_FlyUp del empujado) traducido al esqueleto `sk_d`, o null. Sin la subida de pies de los clips
## de `clips_para`: quien lo use (Pj3D._construir_clip) reescribe la cadera con sus propias alturas y solo toma de aquí la traslación RELATIVA y los giros.
## `escala_cadera` > 0 sustituye la relación de alturas de cadera por esa escala (para vuelos y caídas, que deben ser del mismo tamaño RELATIVO al modelo entero).
static func traducir_clip(glb_id: String, ruta: String, clip: String, modelo_d: Node3D, sk_d: Skeleton3D, escala_cadera: float = 0.0) -> Animation:
	var clave: String = glb_id + "|" + ruta + "|" + clip
	if _cache_clip.has(clave):
		return _cache_clip[clave] as Animation
	var res: Animation = null
	var fuente: Node3D = _abrir(ruta)
	if fuente != null:
		var sks: Array[Node] = fuente.find_children("*", "Skeleton3D", true, false)
		var aps: Array[Node] = fuente.find_children("*", "AnimationPlayer", true, false)
		if not sks.is_empty() and not aps.is_empty() and (aps[0] as AnimationPlayer).has_animation(clip):
			var c := _Ctx.new()
			c.preparar(fuente, sks[0] as Skeleton3D, modelo_d, sk_d)
			if escala_cadera > 0.0:
				c.escala_cadera = escala_cadera
			res = (c.traducir((aps[0] as AnimationPlayer).get_animation(clip), String(modelo_d.get_path_to(sk_d)) + ":") as Array)[0]
		fuente.free()
	_cache_clip[clave] = res
	return res


static func _abrir(ruta: String) -> Node3D:
	if ruta == "" or not ResourceLoader.exists(ruta):
		return null
	var sc: PackedScene = load(ruta) as PackedScene
	return sc.instantiate() as Node3D if sc != null else null


## Traduce los clips de la fuente `f` (ver FUENTES) y los añade a `res` (sin pisar los que ya estén).
static func _traer_de(f: Dictionary, modelo_d: Node3D, sk_d: Skeleton3D, res: Dictionary) -> void:
	var fuente: Node3D = _abrir(String(f.get("ruta", "")))
	if fuente == null:
		return
	var sks: Array[Node] = fuente.find_children("*", "Skeleton3D", true, false)
	var aps: Array[Node] = fuente.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		fuente.free()
		return
	var ap_s: AnimationPlayer = aps[0] as AnimationPlayer
	var c := _Ctx.new()
	c.preparar(fuente, sks[0] as Skeleton3D, modelo_d, sk_d)
	var base: String = String(modelo_d.get_path_to(sk_d)) + ":"
	# 1) la altura de los pies: con el clip de referencia de la fuente, cuánto hay que subir/bajar la cadera destino.
	var referencia: String = String(f.get("referencia", CLIP_REFERENCIA))
	var sube: float = 0.0
	if ap_s.has_animation(referencia):
		c.sube = 0.0
		var medido: Array = c.traducir(ap_s.get_animation(referencia), base)
		sube = c.suela_reposo - float(medido[1])
	c.sube = sube
	# 2) los clips pedidos (o todos, con su nombre)
	var pedidos: Dictionary = (f.get("clips", {}) as Dictionary).duplicate()
	if pedidos.is_empty():
		for nombre in ap_s.get_animation_list():
			pedidos[nombre] = nombre
	for destino in pedidos.keys():
		var origen: String = String(pedidos[destino])
		if res.has(destino):
			continue
		if not ap_s.has_animation(origen):
			push_warning("ClipsFamilia: la fuente %s no tiene el clip «%s»" % [f.get("ruta", ""), origen])
			continue
		var traducido: Animation = (c.traducir(ap_s.get_animation(origen), base) as Array)[0]
		if (f.get("centrar", []) as Array).has(origen):
			_centrar_cadera(traducido, sk_d)
		res[destino] = traducido
	fuente.free()


## Quita al clip `an` el desplazamiento medio de la cadera en el plano del suelo, para que quede centrado sobre el personaje (los clips «en el sitio» de Mixamo traen la
## postura puesta a un lado: Combat_Stance de Gribble desplaza la cadera 0,34 de su alto de cadera). La altura no se toca.
static func _centrar_cadera(an: Animation, sk_d: Skeleton3D) -> void:
	var cadera: int = sk_d.find_bone("mixamorig_Hips")
	if cadera < 0:
		return
	var reposo: Vector3 = sk_d.get_bone_rest(cadera).origin
	for t in range(an.get_track_count()):
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D or not String(an.track_get_path(t)).ends_with("mixamorig_Hips"):
			continue
		var n: int = an.track_get_key_count(t)
		if n == 0:
			continue
		var media := Vector2.ZERO
		for k in range(n):
			var v: Vector3 = an.track_get_key_value(t, k)
			media += Vector2(v.x, v.z)
		media /= float(n)
		var corrige := Vector2(media.x - reposo.x, media.y - reposo.z)
		for k in range(n):
			var v2: Vector3 = an.track_get_key_value(t, k)
			an.track_set_key_value(t, k, Vector3(v2.x - corrige.x, v2.y, v2.z - corrige.y))


## Estado del retarget entre una fuente y un destino.
class _Ctx:
	var sk_s: Skeleton3D
	var sk_d: Skeleton3D
	var orden_d: Array = []                       ## índices de hueso destino, padres antes que hijos
	var orden_s: Array = []
	var mapa: Array = []                          ## hueso destino -> hueso fuente (-1 = no existe en la fuente)
	var rs: Quaternion = Quaternion.IDENTITY      ## rotación del esqueleto fuente respecto a la raíz de su escena
	var rd: Quaternion = Quaternion.IDENTITY
	var gr_s: Array = []                          ## rotación global de reposo (espacio de la raíz) de cada hueso
	var gr_d: Array = []
	var rl_d: Array = []                          ## rotación local de reposo destino
	var rl_s: Array = []
	var cadera_s: int = -1
	var cadera_d: int = -1
	var escala_cadera: float = 1.0
	var suela_d: Array = []                       ## huesos destino que cuentan como suela
	var suela_reposo: float = 0.0                 ## altura del hueso de suela más bajo con el esqueleto destino en reposo
	var sube: float = 0.0                         ## cuánto se desplaza en vertical la cadera destino en todos los clips

	func preparar(raiz_s: Node3D, p_sk_s: Skeleton3D, raiz_d: Node3D, p_sk_d: Skeleton3D) -> void:
		sk_s = p_sk_s
		sk_d = p_sk_d
		rs = _giro_a_raiz(sk_s, raiz_s)
		rd = _giro_a_raiz(sk_d, raiz_d)
		if rs.angle_to(rd) > deg_to_rad(GIRO_NODO_TOL):
			push_warning("ClipsFamilia: el esqueleto fuente y el destino no están orientados igual en su escena (%.1f°)" % rad_to_deg(rs.angle_to(rd)))
		orden_s = _orden(sk_s)
		orden_d = _orden(sk_d)
		for i in range(sk_s.get_bone_count()):
			gr_s.append(rs * _quat(sk_s.get_bone_global_rest(i).basis))
			rl_s.append(_quat(sk_s.get_bone_rest(i).basis))
		var min_y: float = INF
		for i in range(sk_d.get_bone_count()):
			gr_d.append(rd * _quat(sk_d.get_bone_global_rest(i).basis))
			rl_d.append(_quat(sk_d.get_bone_rest(i).basis))
			mapa.append(sk_s.find_bone(sk_d.get_bone_name(i)))
			for fin in HUESOS_SUELA:
				if sk_d.get_bone_name(i).ends_with(fin):
					suela_d.append(i)
					min_y = minf(min_y, sk_d.get_bone_global_rest(i).origin.y)
					break
		suela_reposo = min_y if min_y != INF else 0.0
		cadera_s = sk_s.find_bone("mixamorig_Hips")
		cadera_d = sk_d.find_bone("mixamorig_Hips")
		if cadera_s >= 0 and cadera_d >= 0:
			var hs: float = sk_s.get_bone_rest(cadera_s).origin.y
			if hs > CADERA_MIN:
				escala_cadera = sk_d.get_bone_rest(cadera_d).origin.y / hs

	## Traduce `an` (de la fuente) al destino. Devuelve [Animation, altura media del pie más bajo (sin contar `sube`)].
	func traducir(an: Animation, prefijo: String) -> Array:
		var dest := Animation.new()
		dest.length = an.length
		dest.loop_mode = an.loop_mode
		var n_d: int = sk_d.get_bone_count()
		var pista_rot: Array = []     # hueso destino -> pista de rotación de la fuente (-1 = sin pista, se queda en reposo)
		pista_rot.resize(sk_s.get_bone_count())
		pista_rot.fill(-1)
		var pista_pos: int = -1
		for t in range(an.get_track_count()):
			var hueso: String = String(an.track_get_path(t)).get_slice(":", 1)
			var b: int = sk_s.find_bone(hueso)
			if b < 0:
				continue
			if an.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				pista_rot[b] = t
			elif an.track_get_type(t) == Animation.TYPE_POSITION_3D and b == cadera_s:
				pista_pos = t
		# Pistas destino: una de rotación por hueso con equivalente + la posición de la cadera.
		var pd_rot: Array = []
		pd_rot.resize(n_d)
		pd_rot.fill(-1)
		for i in range(n_d):
			if int(mapa[i]) >= 0:
				var t_n: int = dest.add_track(Animation.TYPE_ROTATION_3D)
				dest.track_set_path(t_n, NodePath(prefijo + sk_d.get_bone_name(i)))
				pd_rot[i] = t_n
		var t_pos: int = -1
		if cadera_d >= 0 and cadera_s >= 0:
			t_pos = dest.add_track(Animation.TYPE_POSITION_3D)
			dest.track_set_path(t_pos, NodePath(prefijo + sk_d.get_bone_name(cadera_d)))
		var pasos: int = maxi(int(ceil(an.length * FPS_MUESTREO)), 1)
		var suma_suela: float = 0.0
		var r_cad_d: Vector3 = sk_d.get_bone_rest(cadera_d).origin if cadera_d >= 0 else Vector3.ZERO
		var r_cad_s: Vector3 = sk_s.get_bone_rest(cadera_s).origin if cadera_s >= 0 else Vector3.ZERO
		for k in range(pasos + 1):
			var tiempo: float = minf(float(k) / FPS_MUESTREO, an.length)
			# Fuente: rotaciones globales animadas.
			var ga_s: Array = []
			ga_s.resize(sk_s.get_bone_count())
			for i in orden_s:
				var p: int = sk_s.get_bone_parent(i)
				var loc: Quaternion = rl_s[i]
				if int(pista_rot[i]) >= 0:
					loc = an.rotation_track_interpolate(int(pista_rot[i]), tiempo)
				ga_s[i] = (rs if p < 0 else ga_s[p] as Quaternion) * loc
			# Destino: el movimiento de la fuente sobre el reposo destino.
			var ga_d: Array = []
			ga_d.resize(n_d)
			var pos: Array = []
			pos.resize(n_d)
			var p_cad: Vector3 = r_cad_d
			if pista_pos >= 0:
				var delta_p: Vector3 = an.position_track_interpolate(pista_pos, tiempo) - r_cad_s
				p_cad = r_cad_d + rd.inverse() * (rs * delta_p) * escala_cadera
			p_cad.y += sube
			var suelo: float = INF
			for i in orden_d:
				var p: int = sk_d.get_bone_parent(i)
				var j: int = int(mapa[i])
				if j >= 0:
					ga_d[i] = ((ga_s[j] as Quaternion) * (gr_s[j] as Quaternion).inverse()) * (gr_d[i] as Quaternion)
				else:
					ga_d[i] = (rd if p < 0 else ga_d[p] as Quaternion) * (rl_d[i] as Quaternion)
				var padre_q: Quaternion = rd if p < 0 else ga_d[p] as Quaternion
				if int(pd_rot[i]) >= 0:
					dest.rotation_track_insert_key(int(pd_rot[i]), tiempo, (padre_q.inverse() * (ga_d[i] as Quaternion)).normalized())
				# Posición (espacio del esqueleto) para medir los pies.
				if p < 0:
					pos[i] = p_cad if i == cadera_d else sk_d.get_bone_rest(i).origin
				else:
					pos[i] = (pos[p] as Vector3) + (rd.inverse() * (ga_d[p] as Quaternion)) * sk_d.get_bone_rest(i).origin
				if suela_d.has(i):
					suelo = minf(suelo, (pos[i] as Vector3).y)
			if t_pos >= 0:
				dest.position_track_insert_key(t_pos, tiempo, p_cad)
			suma_suela += (suelo if suelo != INF else 0.0) - sube
		return [dest, suma_suela / float(pasos + 1)]

	static func _quat(b: Basis) -> Quaternion:
		return b.orthonormalized().get_rotation_quaternion()

	## Rotación del nodo `n` respecto a la raíz `raiz` (producto de las rotaciones de los nodos intermedios).
	static func _giro_a_raiz(n: Node3D, raiz: Node3D) -> Quaternion:
		var q: Quaternion = Quaternion.IDENTITY
		var actual: Node = n
		while actual != null and actual != raiz:
			if actual is Node3D:
				q = _quat((actual as Node3D).transform.basis) * q
			actual = actual.get_parent()
		return q

	## Índices de hueso con los padres antes que los hijos.
	static func _orden(sk: Skeleton3D) -> Array:
		var res: Array = []
		var visto: Dictionary = {}
		for i in range(sk.get_bone_count()):
			var cadena: Array = []
			var b: int = i
			while b >= 0 and not visto.has(b):
				cadena.push_front(b)
				visto[b] = true
				b = sk.get_bone_parent(b)
			res.append_array(cadena)
		return res
