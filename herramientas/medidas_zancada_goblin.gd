extends "res://herramientas/escenario_base.gd"
## 28/10 · Zancada de los goblins: u de juego que avanza el cuerpo por ciclo de `walk` y de `run` con el clip a velocidad 1 (sin root motion), para que su andar no patine
## (Combate3D.ZANCADA_GOBLIN). Se reproduce el clip de verdad (Pj3D.jugar) y se mide el pie apoyado en el esqueleto ya escalado al tamaño de juego: mientras un pie está en el
## suelo (el tercio más bajo de su altura) retrocede, respecto de la cadera, justo a la velocidad del cuerpo; zancada = esa velocidad (mediana) × la duración del ciclo.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/medidas_zancada_goblin.gd

const MODELOS: Array = [["guerrero", "goblin_warrior_chibi"], ["arquero", "goblin_archer_chibi"], ["asesino", "goblin_asesino"], ["chaman", "goblin_chaman"]]
const CLIPS: Array = ["walk", "run"]
const LENTO: float = 0.25                      ## se reproduce a un cuarto de velocidad: cuatro muestras por fotograma de clip (lo medido es a velocidad de clip 1)


func _pos(c: Vector2i) -> Vector3:
	return Vector3((float(c.x) + 0.5) * Terreno3D.casilla, Terreno3D.y_pies(c), (float(c.y) + 0.5) * Terreno3D.casilla)


func _hueso(sk: Skeleton3D, lado: String, parte: String) -> int:
	for i in sk.get_bone_count():
		var n: String = sk.get_bone_name(i).to_lower()
		if n.contains(parte) and (lado == "" or n.contains(lado)) and not n.contains("toe") and not n.contains("end"):
			return i
	return -1


func _mediana(a: Array) -> float:
	if a.is_empty():
		return 0.0
	a.sort()
	return float(a[a.size() / 2])


func _escenario() -> void:
	Flags.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	for m in MODELOS:
		var modelo: Pj3D = maqueta.call("_personaje", [m[1]], _pos(Vector2i(12, 33)))
		if modelo == null:
			print("SIN MODELO ", m[1])
			continue
		modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
		await avanzar(5)
		var sk: Skeleton3D = modelo._esqueleto()
		var cadera: int = _hueso(sk, "", "hips")
		if cadera < 0:
			cadera = _hueso(sk, "", "pelvis")
		var nombres: PackedStringArray = []
		for i in sk.get_bone_count():
			nombres.append(sk.get_bone_name(i))
		print("# ", m[0], " cadera=", cadera, " pies: ", _hueso(sk, "left", "foot"), "/", _hueso(sk, "right", "foot"), " ", nombres.slice(0, 12))
		for clip in CLIPS:
			modelo.animacion_actual = ""
			modelo.set_velocidad_animacion(LENTO)
			modelo.jugar(clip)
			var dur: float = modelo.duracion(clip)
			await avanzar(int(8.0 / LENTO))
			var inv: Transform3D = modelo.global_transform.orthonormalized().affine_inverse()
			var s: float = modelo.global_transform.basis.get_scale().y
			var series := {}
			for lado in ["left", "right"]:
				series[lado] = {"f": [], "z": [], "y": []}
			var n_fot: int = int(ceil(dur * 3.0 * 30.0 / LENTO))
			for k in n_fot:
				await avanzar(1)
				var ch: Vector3 = inv * (sk.global_transform * sk.get_bone_global_pose(cadera).origin)
				for lado in ["left", "right"]:
					var h: int = _hueso(sk, lado, "foot")
					var p: Vector3 = inv * (sk.global_transform * sk.get_bone_global_pose(h).origin)
					series[lado]["f"].append(p.x - ch.x)
					series[lado]["z"].append(p.z - ch.z)
					series[lado]["y"].append(p.y)
			var res: Array = []
			for lado in ["left", "right"]:
				var sr: Dictionary = series[lado]
				var rx: float = (sr["f"] as Array).max() - (sr["f"] as Array).min()
				var rz: float = (sr["z"] as Array).max() - (sr["z"] as Array).min()
				var eje: Array = sr["z"] if rz >= rx else sr["f"]
				var ys: Array = sr["y"]
				var y0: float = ys.min()
				var y1: float = ys.max()
				var vs: Array = []
				for k in range(1, ys.size() - 1):
					if float(ys[k]) <= y0 + (y1 - y0) * 0.25:
						vs.append(absf(float(eje[k + 1]) - float(eje[k - 1])) * 30.0 / (2.0 * LENTO))
				res.append(_mediana(vs) * dur)
				print("   ", lado, " rango ", snappedf(maxf(rx, rz), 0.001), " altura pie ", snappedf(y0, 0.001), "..", snappedf(y1, 0.001), " muestras apoyo ", vs.size(), "/", ys.size())
			print("%-9s %-4s clip %.3f s  escala %.3f  zancada izq %.3f  der %.3f  -> %.3f u por ciclo" % [m[0], clip, dur, s, res[0], res[1], (res[0] + res[1]) / 2.0])
		modelo.queue_free()
