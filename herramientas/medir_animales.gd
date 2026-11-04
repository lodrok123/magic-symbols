extends SceneTree
## 4/11 · MEDIR ANIMALES (Fase 1 del encargo de Pablo: comparar canouro/loberno con hiena/lobo). Sin ventana, sin IA: carga cada modelo en Pj3D, pone la escala del juego y, clip a clip, muestrea el
## esqueleto (AnimationPlayer propio, árbol apagado) y mide: duración, velocidad a la que NO patina (suelo que pisa el pie durante el apoyo), zancada, cadencia de pisadas, fase de cada pata,
## pendiente del lomo (cruz frente a grupa), cuello, altura/avance de la cabeza, vaivén lateral de la cabeza y balanceo de hombros.
## Uso: godot --headless --path . --script res://herramientas/medir_animales.gd [-- csv]
##   Con `con_marcha` activo (Combate3D / MarchaCuadrupedo3D) mide también lo nuevo: ver prueba_marcha_animales.gd.

const MODELOS: Array = [["loberno", 0.75], ["canouro", 0.55]]
const CLIPS: Array = ["Idle", "Walk", "Walk_Alt", "Creep", "Gallop", "Run_Alt", "Attack", "Zarpazo", "Idle_2_HeadLow", "Eating"]
const N: int = 96


func _initialize() -> void:
	for m in MODELOS:
		await _medir(String(m[0]), float(m[1]))
	quit()


func _gp(sk: Skeleton3D, i: int) -> Vector3:
	return sk.global_transform * sk.get_bone_global_pose(i).origin


func _medir(id: String, alto: float) -> void:
	var pj := Pj3D.new()
	root.add_child(pj)
	if not pj.cargar(id):
		print("NO CARGA ", id)
		return
	pj.set_alto(alto)
	for i in 4:
		await process_frame
	if pj._arbol != null:
		pj._arbol.active = false
	var ap: AnimationPlayer = pj._ap
	ap.active = true
	var sk: Skeleton3D = pj._modelo.find_children("*", "Skeleton3D", true, false)[0]
	var b := func(n: String) -> int: return sk.find_bone(n)
	var cuerpo: int = b.call("Body")
	var espalda: int = b.call("Back")
	var t3: int = b.call("Torso3")
	var cadena: Array = ["Back", "Torso", "Torso2", "Torso3", "Neck1", "Neck2", "Neck3", "Head"]
	var pies: Array = ["FF.L", "FF.R", "FFB.L", "FFB.R"]
	var tibias: Array = ["FrontLowerLeg.L", "FrontLowerLeg.R", "BackLowerLeg.L", "BackLowerLeg.R"]   # el pie se estima con la tibia (FK): los clips «_Alt» no mueven los IK
	var hom: Array = [b.call("FrontShoulder.L"), b.call("FrontShoulder.R")]
	var cad: Array = [b.call("BackShoulder.L"), b.call("BackShoulder.R")]
	var cabeza: int = b.call("Head")
	var desv: Array = []
	var cuello: int = b.call("Neck1")
	print("")
	print("##### %s  alto=%.2f  escala=%.4f  (id GLB %s)" % [id, alto, pj.scale.x, Pj3D.glb_de(id)])
	# Ejes del cuerpo: delante = de la grupa a la cruz (horizontal), lateral = arriba × delante.
	ap.play("Idle")
	ap.seek(0.0, true)
	sk.force_update_all_bone_transforms()
	for j in range(4):
		var tb: Transform3D = sk.get_bone_global_pose(b.call(tibias[j]))
		desv.append(tb.affine_inverse() * sk.get_bone_global_pose(b.call(pies[j])).origin)
	var fw: Vector3 = _gp(sk, cabeza) - _gp(sk, cuerpo)
	fw.y = 0.0
	fw = fw.normalized()
	var lat: Vector3 = Vector3.UP.cross(fw).normalized()
	print("largo cuerpo (Body→Torso3) = %.3f u ; cruz y=%.3f ; grupa y=%.3f ; cabeza y=%.3f (en reposo Idle)" % [
		(_gp(sk, t3) - _gp(sk, cuerpo)).length(), (_gp(sk, hom[0]).y + _gp(sk, hom[1]).y) / 2.0, (_gp(sk, cad[0]).y + _gp(sk, cad[1]).y) / 2.0, _gp(sk, cabeza).y])
	for nombre in CLIPS:
		if not ap.has_animation(nombre):
			continue
		var an: Animation = ap.get_animation(nombre)
		var L: float = an.length
		ap.play(nombre)
		var piesY: Array = [[], [], [], []]
		var piesF: Array = [[], [], [], []]
		var pend: Array = []                  # pendiente del lomo por muestra
		var cab_y: Array = []
		var cab_f: Array = []
		var cab_l: Array = []
		var hom_roll: Array = []
		var hom_l: Array = []
		var seg: Dictionary = {}
		for k in range(cadena.size() - 1):
			seg[k] = []
		var cabeza_ang: Array = []
		var cadera_y: Array = []
		for i in range(N + 1):
			ap.seek(L * float(i) / float(N), true)
			sk.force_update_all_bone_transforms()
			for j in range(4):
				var p: Vector3 = sk.global_transform * (sk.get_bone_global_pose(b.call(tibias[j])) * (desv[j] as Vector3))
				piesY[j].append(p.y)
				piesF[j].append(p.dot(fw))
			var cruz: Vector3 = (_gp(sk, hom[0]) + _gp(sk, hom[1])) * 0.5
			var grupa: Vector3 = (_gp(sk, cad[0]) + _gp(sk, cad[1])) * 0.5
			var d: Vector3 = cruz - grupa
			pend.append(rad_to_deg(atan2(d.y, d.dot(fw))))
			var hp: Vector3 = _gp(sk, cabeza)
			cab_y.append(hp.y - cruz.y)
			cab_f.append((hp - cruz).dot(fw))
			cab_l.append((hp - (cruz + grupa) * 0.5).dot(lat))
			hom_roll.append(_gp(sk, hom[0]).y - _gp(sk, hom[1]).y)
			hom_l.append(((_gp(sk, hom[0]) + _gp(sk, hom[1]) * 0.5) - grupa).dot(lat))
			cadera_y.append(grupa.y)
			for k in range(cadena.size() - 1):
				var a: Vector3 = _gp(sk, b.call(cadena[k]))
				var c: Vector3 = _gp(sk, b.call(cadena[k + 1]))
				var dd: Vector3 = c - a
				seg[k].append(rad_to_deg(atan2(dd.y, dd.dot(fw))))
			var cuello_v: Vector3 = hp - _gp(sk, cuello)
			cabeza_ang.append(rad_to_deg(atan2(cuello_v.y, cuello_v.dot(fw))))
		print("--- clip %s  dur=%.3f s" % [nombre, L])
		print("  lomo (pendiente cruz-grupa, + = delante alto): media %.1f°  rango [%.1f, %.1f]" % [_med(pend), _mn(pend), _mx(pend)])
		var s: String = "  segmentos (°, + = hacia arriba hacia delante): "
		for k in range(cadena.size() - 1):
			s += "%s→%s %.0f " % [cadena[k], cadena[k + 1], _med(seg[k])]
		print(s)
		print("  cuello→cabeza media %.1f°  | cabeza sobre la cruz: y %.3f u (rango %.3f), avance %.3f u (rango %.3f) | alto cruz %.3f" % [_med(cabeza_ang), _med(cab_y), _mx(cab_y) - _mn(cab_y), _med(cab_f), _mx(cab_f) - _mn(cab_f), (_gp(sk, hom[0]).y + _gp(sk, hom[1]).y) / 2.0])
		print("  vaivén lateral de la cabeza (p2p) %.3f u | balanceo de hombros (altura izq-der p2p) %.3f u | vaivén lateral hombros %.3f u | rebote grupa %.3f u" % [_mx(cab_l) - _mn(cab_l), _mx(hom_roll) - _mn(hom_roll), _mx(hom_l) - _mn(hom_l), _mx(cadera_y) - _mn(cadera_y)])
		# Pies: velocidad del suelo durante el apoyo y fase de cada pata
		var vs: Array = []
		var toques: Array = []
		for j in range(4):
			var ys: Array = piesY[j]
			var rng: float = _mx(ys) - _mn(ys)
			var ymin: float = _mn(ys)
			var enapoyo: Array = []
			for i in range(N):
				if ys[i] <= ymin + 0.25 * rng + 0.002:
					var df: float = piesF[j][i + 1] - piesF[j][i]
					var dfa: float = piesF[j][i] - piesF[j][(i - 1 + N) % N] if i > 0 else piesF[j][1] - piesF[j][0]
					enapoyo.append(-(df) / (L / float(N)))
			vs.append(_med(enapoyo) if enapoyo.size() > 2 else 0.0)
			# toque: primer índice en que el pie pasa de arriba a abajo del umbral
			var umbral: float = ymin + 0.25 * rng + 0.002
			var t_toque: float = -1.0
			for i in range(N):
				if ys[i] > umbral and ys[(i + 1) % N] <= umbral:
					t_toque = float(i + 1) / float(N)
					break
			toques.append(t_toque)
		var vmed: float = (vs[0] + vs[1] + vs[2] + vs[3]) / 4.0
		var fases: String = ""
		for j in range(4):
			var f: float = toques[j]
			var f0: float = toques[0]
			fases += "%s %s  " % [pies[j], ("%.2f" % fposmod(f - f0, 1.0)) if f >= 0.0 and f0 >= 0.0 else "--"]
		print("  pies: v. suelo en apoyo (u/s, a vel. 1) FF.L %.2f FF.R %.2f FFB.L %.2f FFB.R %.2f → media %.2f ; zancada = v·dur = %.3f u ; pisadas/s = %.2f" % [vs[0], vs[1], vs[2], vs[3], vmed, vmed * L, 4.0 / L])
		print("  fase del toque (0 = FF.L): " + fases)
		var recorrido: float = (_mx(piesF[0]) - _mn(piesF[0]))
		print("  recorrido del pie delantero izq. en el eje del cuerpo: %.3f u ; alto máximo del pie %.3f u" % [recorrido, _mx(piesY[0]) - _mn(piesY[0])])
	pj.queue_free()


func _med(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())


func _mn(a: Array) -> float:
	var r: float = INF
	for v in a:
		r = minf(r, float(v))
	return r


func _mx(a: Array) -> float:
	var r: float = -INF
	for v in a:
		r = maxf(r, float(v))
	return r

