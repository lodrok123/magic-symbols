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

## Modelo (id de GLB) -> GLB de la familia del que toma los clips. Solo para modelos que NO traen AnimationPlayer propio.
const FUENTE_DE: Dictionary = {
	"elfo_base": "res://arte/modelos/chibi_elf.glb",
}

## Muestreo de los clips traducidos (los de la fuente van a 30 fps).
const FPS_MUESTREO: float = 30.0
## Cadera de la fuente por debajo de esto (u) = no se puede calcular la relación de alturas: se deja la escala en 1.
const CADERA_MIN: float = 0.01
## Terminaciones de los huesos que cuentan como «suela» para apoyar los pies (el más bajo de ellos manda).
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]
## Clip de la fuente con el que se mide la altura de los pies (el reposo de pie).
const CLIP_REFERENCIA: String = "Idle"
## Tolerancia (en grados) de la rotación del nodo del esqueleto respecto al modelo: por encima, el retarget asume que fuente y destino difieren y avisa.
const GIRO_NODO_TOL: float = 1.0

static var _cache: Dictionary = {}     ## ruta del GLB destino -> {nombre de clip: Animation}


static func tiene_fuente(glb_id: String) -> bool:
	return FUENTE_DE.has(glb_id)


## Los clips de la familia ya traducidos al esqueleto `sk_d` del modelo `modelo_d` (raíz de la escena del GLB `glb_id`). Las pistas llevan la ruta
## del esqueleto relativa a `modelo_d`, así que el AnimationPlayer ha de colgar de `modelo_d` (root_node = ".."). Vacío si algo falla.
static func clips_para(glb_id: String, modelo_d: Node3D, sk_d: Skeleton3D) -> Dictionary:
	if _cache.has(glb_id):
		return _cache[glb_id]
	var res: Dictionary = {}
	var ruta: String = String(FUENTE_DE.get(glb_id, ""))
	if ruta == "" or not ResourceLoader.exists(ruta):
		return res
	var sc: PackedScene = load(ruta) as PackedScene
	if sc == null:
		return res
	var fuente: Node3D = sc.instantiate() as Node3D
	var sks: Array[Node] = fuente.find_children("*", "Skeleton3D", true, false)
	var aps: Array[Node] = fuente.find_children("*", "AnimationPlayer", true, false)
	if sks.is_empty() or aps.is_empty():
		fuente.free()
		return res
	var sk_s: Skeleton3D = sks[0] as Skeleton3D
	var ap_s: AnimationPlayer = aps[0] as AnimationPlayer
	var c := _Ctx.new()
	c.preparar(fuente, sk_s, modelo_d, sk_d)
	var base: String = String(modelo_d.get_path_to(sk_d)) + ":"
	# 1) la altura de los pies: con el Idle de la fuente, cuánto hay que subir/bajar la cadera destino.
	var sube: float = 0.0
	if ap_s.has_animation(CLIP_REFERENCIA):
		c.sube = 0.0
		var medido: Array = c.traducir(ap_s.get_animation(CLIP_REFERENCIA), base)
		sube = c.suela_reposo - float(medido[1])
	c.sube = sube
	for nombre in ap_s.get_animation_list():
		res[nombre] = (c.traducir(ap_s.get_animation(nombre), base) as Array)[0]
	fuente.free()
	_cache[glb_id] = res
	return res


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
