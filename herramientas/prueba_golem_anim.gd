extends SceneTree
## Prueba de las animaciones del gólem (jugador/animaciones_golem.gd + el golpe del elemental retargeteado). Headless:
##   Godot --headless --path . --script res://herramientas/prueba_golem_anim.gd
## Comprueba: existen todos los roles; las duraciones están en rango; idle y walk cierran el bucle; el instante del golpe está dentro del clip;
## los pies no atraviesan el suelo en walk ni en expuesto; y mide la zancada y el instante del impacto. Termina con «FALLOS: n».

const RUTA: String = "res://arte/modelos/golem_piedra_rig.glb"
const ESCALA_JUEGO: float = 1.7 / 0.704346
const DURACIONES: Dictionary = {
	"idle": [2.5, 3.5], "walk": [1.2, 2.2], "attack": [2.4, 3.0], "expuesto": [4.5, 6.5], "resbalar": [1.5, 2.5],
	"levantarse": [3.5, 5.5], "hit": [0.4, 1.0], "death": [2.0, 3.5],
}
var fallos: int = 0
var modelo: Node3D
var sk: Skeleton3D
var ap: AnimationPlayer


func _initialize() -> void:
	modelo = (load(RUTA) as PackedScene).instantiate()
	root.add_child(modelo)
	await process_frame
	sk = modelo.find_children("*", "Skeleton3D", true, false)[0]
	var prefijo: String = String(modelo.get_path_to(sk)) + ":"
	var clips: Dictionary = AnimacionesGolem.construir(sk, prefijo)

	ap = AnimationPlayer.new()
	modelo.add_child(ap)
	ap.root_node = NodePath("..")
	var lib := AnimationLibrary.new()
	for k in clips:
		lib.add_animation(k, clips[k])
	ap.add_animation_library("", lib)
	# 1. roles y duraciones
	for rol in DURACIONES:
		var ok: bool = clips.has(rol)
		_chequea(ok, "existe el rol %s" % rol)
		if ok:
			var d: float = (clips[rol] as Animation).length
			var r: Array = DURACIONES[rol]
			_chequea(d >= float(r[0]) and d <= float(r[1]), "duracion de %s = %.2f s (rango %.1f-%.1f)" % [rol, d, r[0], r[1]])
	# 2. el bucle de idle y walk cierra: pose en t=0 y t=length iguales
	for rol in ["idle", "walk"]:
		var d0: float = _dif_pose(rol, 0.0, (clips[rol] as Animation).length)
		_chequea(d0 < 0.003, "bucle de %s cierra (diferencia de posiciones de huesos %.5f m)" % [rol, d0])
	# 3. el golpe (mazazo con los dos puños)
	var an: Animation = clips["attack"]
	var g: Dictionary = _golpe(an)
	print("golpe: carga hasta los %.2f s; los dos puños tocan el suelo a los %.2f s (de %.2f, fraccion %.2f); caida de %.2f s" % [AnimacionesGolem.T_ATK_ARRIBA, g.t, an.length, g.t / an.length, g.t - AnimacionesGolem.T_ATK_ARRIBA])
	print("  en el impacto: puño izq y=%.3f z=%.3f, der y=%.3f; diferencia %.3f m; los puños quedan a %.2f m por delante de los pies (modelo; %.2f u en el juego, %.2f casillas de 2,3)" % [g.yi, g.zi, g.yd, absf(g.yi - g.yd), g.delante, g.delante * ESCALA_JUEGO, g.delante * ESCALA_JUEGO / 2.3])
	print("  inclinacion maxima del torso hacia delante %.1f grados; arqueo maximo hacia atras %.1f (respecto al reposo, que ya esta inclinado ~6 grados hacia delante); puños en la carga: %.2f m sobre la cabeza" % [g.incl, g.arco, g.sobre_cabeza])
	_chequea(g.t > 0.0 and g.t < an.length, "el instante del golpe (%.2f s) esta dentro del clip" % g.t)
	var avance: float = (float(g.hips_fin) - float(g.hips0)) * ESCALA_JUEGO
	print("  avance de la raiz: %.2f u del juego (AVANCE_GOLPE %.2f); puños a %.2f casillas por delante de los pies de partida; retroceso tras el impacto %.4f m" % [avance, AnimacionesGolem.AVANCE_GOLPE, g.delante * ESCALA_JUEGO / 2.3, g.get("retroceso", 0.0)])
	_chequea(absf(avance - 1.15) <= 0.15, "el avance total es 1,15 +- 0,15 u del juego (%.2f)" % avance)
	_chequea(g.delante * ESCALA_JUEGO / 2.3 >= 0.5, "los puños en el impacto estan >= 0,5 casillas por delante de los pies de partida (%.2f)" % (g.delante * ESCALA_JUEGO / 2.3))
	_chequea(float(g.get("retroceso", 0.0)) < 0.002, "entre el impacto y el final no hay retroceso (%.4f m)" % float(g.get("retroceso", 0.0)))
	_chequea(absf(AnimacionesGolem.avance_golpe_en(an.length) - avance) < 0.03, "avance_golpe_en() coincide con lo que mueve la raiz")
	_chequea(absf(g.t - AnimacionesGolem.INSTANTE_GOLPE) < 0.06, "AnimacionesGolem.INSTANTE_GOLPE (%.2f) coincide con el medido (%.2f)" % [AnimacionesGolem.INSTANTE_GOLPE, g.t])
	_chequea(AnimacionesGolem.T_ATK_ARRIBA - AnimacionesGolem.T_ATK_CARGA >= 0.9, "la carga dura ~1 s (%.2f s)" % (AnimacionesGolem.T_ATK_ARRIBA - AnimacionesGolem.T_ATK_CARGA))
	_chequea(absf(g.yi - g.yd) < 0.05, "los dos puños a la vez en el suelo (diferencia %.3f m < 0,05)" % absf(g.yi - g.yd))
	_chequea(g.min_puno >= 0.02, "los puños no atraviesan el suelo en todo el clip (minimo %.3f m >= 0,02)" % g.min_puno)
	_chequea(g.incl <= AnimacionesGolem.ATAQUE_INCLINACION_MAX, "inclinacion maxima del torso %.1f° <= %.0f°" % [g.incl, AnimacionesGolem.ATAQUE_INCLINACION_MAX])
	_chequea(g.sobre_cabeza > 0.02, "en la carga los puños estan por encima de la cabeza (%.2f m)" % g.sobre_cabeza)
	var d_ini: float = _dif_pose_clips(an, 0.0, clips["idle"], 0.0)
	var d_fin: float = _dif_pose_clips(an, an.length, clips["idle"], 0.0, Vector3(0.0, 0.0, AnimacionesGolem.AVANCE_GOLPE / ESCALA_JUEGO))
	_chequea(d_ini < 0.003 and d_fin < 0.003, "el clip empieza y acaba como idle (el final, salvo el avance; diferencias %.4f / %.4f m)" % [d_ini, d_fin])
	# 4. pies: walk y expuesto
	for rol in ["walk", "expuesto", "idle"]:
		var m: float = _min_pie(clips[rol])
		_chequea(m >= -0.01, "los pies no atraviesan el suelo en %s (minimo %.3f m, en el modelo; 1 cm de margen)" % [rol, m])
	# 5. zancada
	var z: Dictionary = _zancada(clips["walk"])
	print("zancada: el pie de apoyo recorre %.3f m (modelo) por paso = %.3f m en el juego; ciclo %.2f s -> el clip avanza %.3f u/s en el juego" % [z.paso, z.paso * ESCALA_JUEGO, z.ciclo, 2.0 * z.paso * ESCALA_JUEGO / z.ciclo])
	# 6. el resto de poses: nada se estira (aristas) y los huesos no se salen
	var mi: MeshInstance3D = modelo.find_children("*", "MeshInstance3D", true, false)[0]
	for rol in ["walk", "expuesto", "resbalar", "levantarse", "hit", "death"]:
		var e: Array = _estiramiento(clips[rol], mi)
		print("  %s: arista mas estirada x%.2f, mas encogida x%.2f (en los fotogramas muestreados)" % [rol, e[0], e[1]])
		_chequea(e[0] < 3.0 and e[1] > 0.3, "%s no estira absurdamente la malla" % rol)
	print("FALLOS: %d" % fallos)
	quit(1 if fallos > 0 else 0)


func _chequea(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   ", msg)
	else:
		fallos += 1
		print("  FALLO ", msg)


func _poner(an: Animation, t: float) -> void:
	if ap.current_animation != "":
		ap.stop()
	ap.get_animation_library("").remove_animation("_t") if ap.get_animation_library("").has_animation("_t") else null
	ap.get_animation_library("").add_animation("_t", an)
	ap.play("_t")
	ap.seek(t, true)
	ap.pause()
	sk.force_update_all_bone_transforms()


func _dif_pose(rol: String, t0: float, t1: float) -> float:
	var an: Animation = ap.get_animation(rol)
	_poner(an, t0)
	var a: Array[Vector3] = []
	for i in sk.get_bone_count():
		a.append(sk.get_bone_global_pose(i).origin)
	_poner(an, t1)
	var m: float = 0.0
	for i in sk.get_bone_count():
		m = maxf(m, (sk.get_bone_global_pose(i).origin - a[i]).length())
	return m


func _y(nombre: String) -> float:
	return sk.get_bone_global_pose(sk.find_bone("mixamorig_" + nombre)).origin.y


func _min_pie(an: Animation) -> float:
	var m: float = 1e9
	var t: float = 0.0
	while t <= an.length + 0.0001:
		_poner(an, minf(t, an.length))
		for h in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase", "LeftToe_End", "RightToe_End"]:
			m = minf(m, _y(h))
		t += 1.0 / 15.0
	return m


func _p(nombre: String) -> Vector3:
	return sk.get_bone_global_pose(sk.find_bone("mixamorig_" + nombre)).origin


## Mide el golpe: el instante en que los DOS puños (punta de la mano) llegan al suelo (y < 0,07 m, tras la carga), su altura y su distancia por delante de los pies, la inclinación
## máxima del torso (cadera -> cuello respecto a la vertical, hacia delante / hacia atrás) y cuánto pasan los puños por encima de la cabeza al final de la carga.
func _golpe(an: Animation) -> Dictionary:
	var r := {"t": 0.0, "yi": 0.0, "yd": 0.0, "zi": 0.0, "delante": 0.0, "incl": 0.0, "arco": 0.0, "sobre_cabeza": 0.0, "min_puno": 1e9}
	var t: float = 0.0
	while t <= an.length + 0.0001:
		_poner(an, minf(t, an.length))
		var pi_: Vector3 = _p("LeftHandMiddle4")
		var pd: Vector3 = _p("RightHandMiddle4")
		var v: Vector3 = _p("Neck") - _p("Hips")
		var ang: float = rad_to_deg(atan2(v.z, v.y))
		r.incl = maxf(r.incl, ang)
		if t < 0.001:
			r["ang0"] = ang
			r["pies0"] = maxf(_p("LeftToe_End").z, _p("RightToe_End").z)
			r["hips0"] = _p("Hips").z
		r.arco = maxf(r.arco, float(r.get("ang0", 0.0)) - ang)
		if t >= AnimacionesGolem.T_ATK_ARRIBA - 0.2 and t <= AnimacionesGolem.T_ATK_ARRIBA:
			r.sobre_cabeza = minf(r.sobre_cabeza if r.sobre_cabeza != 0.0 else 1e9, minf(pi_.y, pd.y) - _p("HeadTop_End").y)
		if t > AnimacionesGolem.T_ATK_CARGA:
			r.min_puno = minf(r.min_puno, minf(pi_.y, pd.y))
		if r.t == 0.0 and t > AnimacionesGolem.T_ATK_ARRIBA and pi_.y < 0.09 and pd.y < 0.09:
			r.t = t
			r.yi = pi_.y
			r.yd = pd.y
			r.zi = pi_.z
			r.delante = pi_.z - float(r.get("pies0", 0.0))
		if r.t > 0.0 and t >= r.t:
			r["retroceso"] = maxf(float(r.get("retroceso", 0.0)), float(r.get("hips_max", -1e9)) - _p("Hips").z)
			r["hips_max"] = maxf(float(r.get("hips_max", -1e9)), _p("Hips").z)
		r["hips_fin"] = _p("Hips").z
		t += 1.0 / 60.0
	return r


func _dif_pose_clips(a: Animation, ta: float, b: Animation, tb: float, desp: Vector3 = Vector3.ZERO) -> float:
	_poner(a, ta)
	var p: Array[Vector3] = []
	for i in sk.get_bone_count():
		p.append(sk.get_bone_global_pose(i).origin)
	_poner(b, tb)
	var m: float = 0.0
	for i in sk.get_bone_count():
		m = maxf(m, (sk.get_bone_global_pose(i).origin + desp - p[i]).length())
	return m


## La zancada: lo que retrocede el pie izquierdo respecto a la cadera mientras está apoyado (su altura mínima), por paso.
func _zancada(an: Animation) -> Dictionary:
	var zmin: float = 1e9
	var zmax: float = -1e9
	var t: float = 0.0
	while t <= an.length + 0.0001:
		_poner(an, minf(t, an.length))
		var zp: float = sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftFoot")).origin.z - sk.get_bone_global_pose(sk.find_bone("mixamorig_Hips")).origin.z
		zmin = minf(zmin, zp)
		zmax = maxf(zmax, zp)
		t += 1.0 / 30.0
	return {"paso": zmax - zmin, "ciclo": an.length}


## Estiramiento de aristas de la malla durante un clip (muestreado cada 0,25 s), contando solo las aristas largas (>4 mm).
func _estiramiento(an: Animation, mi: MeshInstance3D) -> Array:
	var a: Array = mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var hu: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var pe: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var skin: Skin = mi.skin
	var mapa: Dictionary = {}
	for k in skin.get_bind_count():
		mapa[k] = sk.find_bone(skin.get_bind_name(k))
	var mx: float = 0.0
	var mn: float = 1e9
	var t: float = 0.0
	while t <= an.length + 0.0001:
		_poner(an, minf(t, an.length))
		var m: Array = []
		for k in skin.get_bind_count():
			m.append(sk.get_bone_global_pose(mapa[k]) * skin.get_bind_pose(k))
		var o := PackedVector3Array()
		o.resize(v.size())
		for i in v.size():
			var p := Vector3.ZERO
			for k in 4:
				var w: float = pe[i * 4 + k]
				if w > 0.0:
					p += (m[hu[i * 4 + k]] * v[i]) * w
			o[i] = p
		for i in range(0, idx.size(), 3 * 7):
			for j in 3:
				var p0: int = idx[i + j]
				var q0: int = idx[i + (j + 1) % 3]
				var l0: float = (v[p0] - v[q0]).length()
				if l0 > 0.004:
					var rr: float = (o[p0] - o[q0]).length() / l0
					mx = maxf(mx, rr)
					mn = minf(mn, rr)
		t += 0.25
	return [mx, mn]
