extends SceneTree
## PRUEBA del elfo base (arte/modelos/elfo_base.glb, Tripo, esqueleto Mixamo de 65 huesos, sin animaciones): carga como Pj3D, mide lo que debe,
## trae los clips de la familia (chibi_elf, vía ClipsFamilia) y tiene los pies en el suelo. Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_elfo_base.gd
## Cómo se VE se mira en docs/capturas/elfo_base/ (herramientas/captura_elfo_base.gd).

const ID: String = "elfo_base"
const ALTO_ESPERADO: float = 1.0          ## u de juego (el de ALTO_PJ en PruebaTest2)
const TOL_ALTO: float = 0.05              ## ±5 %
const ROLES: Array = ["idle", "walk", "run", "talk", "cast", "hit", "death", "roll", "leer", "swim"]
const ROLES_OBLIGATORIOS: Array = ["idle", "walk", "run"]
## Cuánto puede separarse del suelo el hueso de suela más bajo en idle y andar/correr (fracción del alto del modelo). Al andar un pie siempre está en el aire.
const SUELO_IDLE_TOL: float = 0.02
const SUELO_MARCHA_MIN: float = 0.04      ## pisa: el pie más bajo, en el punto más bajo del ciclo, queda a menos de esto
const SUELO_MARCHA_HUNDE: float = -0.03   ## y no atraviesa el suelo más de esto
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]

var _fallos: int = 0


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	var p := Pj3D.new()
	mundo.add_child(p)
	_ok(p.cargar(ID), "elfo_base carga")
	p.set_alto(ALTO_ESPERADO)
	await process_frame
	_ok(absf(p.alto_modelo() * p.scale.y - ALTO_ESPERADO) <= ALTO_ESPERADO * TOL_ALTO, "altura en el juego %.3f (esperada %.2f ±5 %%)" % [p.alto_modelo() * p.scale.y, ALTO_ESPERADO])
	var sks: Array[Node] = p.find_children("*", "Skeleton3D", true, false)
	_ok(not sks.is_empty() and (sks[0] as Skeleton3D).find_bone("mixamorig_Hips") >= 0, "esqueleto con huesos mixamorig")
	var sk: Skeleton3D = sks[0] as Skeleton3D
	_ok(sk.get_bone_count() == 65, "65 huesos (%d)" % sk.get_bone_count())
	_ok(sk.find_bone("mixamorig_LeftHandIndex1") >= 0, "tiene dedos")
	var ap: AnimationPlayer = p._ap
	_ok(ap != null, "AnimationPlayer con los clips de la familia (%d clips)" % (ap.get_animation_list().size() if ap != null else 0))
	if ap == null:
		_acabar()
		return
	for r in ROLES:
		var clip: String = p.clip_de(r)
		if ROLES_OBLIGATORIOS.has(r):
			_ok(clip != "" and p.duracion(r) > 0.0, "rol %s -> %s (%.2f s)" % [r, clip, p.duracion(r)])
		else:
			print("INFO  rol %s -> %s" % [r, clip if clip != "" else "(sin clip)"])
	_ok(p._arbol != null, "árbol de animación montado")
	p.jugar("walk")
	await process_frame
	_ok(p.animacion_actual == "walk" or p.animacion_actual != "", "jugar(walk) sin error (actual: %s)" % p.animacion_actual)
	# Pies: para cada rol, pose real del esqueleto en varios instantes del clip, altura del hueso de suela más bajo (en alturas del modelo).
	var alto: float = p.alto_modelo()
	var reposo: float = _suela_min_reposo(sk)
	_ok(true, "suela más baja en reposo: %.4f u" % reposo)
	for r in ["idle", "walk", "run"]:
		var clip2: String = p.clip_de(r)
		var an: Animation = ap.get_animation(clip2)
		var pasos: int = 24
		var minimo: float = INF
		var maximo: float = -INF
		for k in range(pasos):
			var y: float = _suela_en(p, sk, ap, clip2, an.length * float(k) / float(pasos)) - reposo
			minimo = minf(minimo, y)
			maximo = maxf(maximo, y)
		var rel_min: float = minimo / alto
		var rel_max: float = maximo / alto
		print("INFO  %s (%s): suela mínima %.1f %% , máxima %.1f %% del alto" % [r, clip2, rel_min * 100.0, rel_max * 100.0])
		if r == "idle":
			_ok(absf(rel_min) <= SUELO_IDLE_TOL and absf(rel_max) <= SUELO_IDLE_TOL * 3.0, "idle: pies en el suelo (mín %.3f, máx %.3f del alto)" % [rel_min, rel_max])
		else:
			_ok(rel_min <= SUELO_MARCHA_MIN and rel_min >= SUELO_MARCHA_HUNDE, "%s: pisa el suelo sin hundirse (mín %.3f del alto)" % [r, rel_min])
	_acabar()


func _acabar() -> void:
	print("RESULTADO elfo_base · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _suela_min_reposo(sk: Skeleton3D) -> float:
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, sk.get_bone_global_rest(i).origin.y)
	return m


## Altura (espacio del esqueleto, u del modelo) del hueso de suela más bajo con el clip en `t`.
func _suela_en(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clip: String, t: float) -> float:
	if p._arbol != null:
		p._arbol.active = false          # el árbol manda sobre el reproductor: se apaga para mirar el clip a pelo
	ap.active = true
	ap.play(clip)
	ap.seek(t, true)
	sk.force_update_all_bone_transforms()
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, sk.get_bone_global_pose(i).origin.y)
	return m
