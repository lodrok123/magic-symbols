extends SceneTree
## 4/11 · MODO MARCHA del laboratorio gato (laboratorios/LabGato3D.tscn, tecla N). Sin ventana, a 30 fps fijos:
##   1) carga el laboratorio, entra en modo marcha con cada animal (canouro, loberno) y el lince sigue como antes (sin animal de marcha);
##   2) persigue a una presa quieta: el animal se desplaza, la capa corre (`llamadas` > 0) y salen los estados de conducta (lobo: acecho/pausa/embestida;
##      hiena: zigzag o tanteo = «para»/«atras», arrancada);
##   3) B (MARCHA_ANIMAL = false): la capa se para (`llamadas` no sube, `active` = false), el animal sigue moviéndose con el clip de antes;
##   4) B otra vez: la capa vuelve; P patrulla de ida y vuelta; N sale del modo marcha y deja el rig de antes.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_lab_gato_marcha.gd

const DT: float = 1.0 / 30.0
var _fallos: int = 0
var _lab: Node3D = null


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	_correr()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


## Anda `n` fotogramas anotando los estados de conducta vistos y la distancia recorrida.
func _andar(n: int, estados: Dictionary, clips: Dictionary) -> float:
	var recorrido: float = 0.0
	var p0: Vector3 = _lab._mpj.position
	for i in range(n):
		await process_frame
		if _lab._mpj == null:
			break
		var p1: Vector3 = _lab._mpj.position
		recorrido += (p1 - p0).length()
		_max_z = maxf(_max_z, absf(p1.z))
		p0 = p1
		if _lab._mm != null:
			estados[_lab._mm.estado_conducta()] = true
		clips[_lab._mpj.clip_actual()] = true
	return recorrido


func _correr() -> void:
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true
	var esc: PackedScene = load("res://laboratorios/LabGato3D.tscn") as PackedScene
	_lab = esc.instantiate()
	root.add_child(_lab)
	await _frames(5)
	_ok("0 el laboratorio carga con su modelo y panel", _lab._modelo != null and _lab._capa != null and _lab._capa.visible)
	_ok("0 antes de N no hay animal de marcha y se ve el rig", _lab._mpj == null and _lab._modelo.visible and not _lab._marcha_activa())

	for id in ["canouro", "loberno"]:
		MarchaCuadrupedo3D.MARCHA_ANIMAL = true
		_lab._marcha_on = false
		_lab._cambiar_modelo("lince")
		await _frames(2)
		_lab._cambiar_modelo(id)
		await _frames(3)
		_lab._alternar_modo_marcha()                # tecla N
		await _frames(10)
		_ok("1 %s: modo marcha con animal, capa colgada del esqueleto" % id, _lab._mpj != null and _lab._mm != null and _lab._mm.get_parent() is Skeleton3D)
		_ok("1 %s: el rig se oculta y se ve el suelo grande" % id, not _lab._capa.visible and not _lab._modelo.visible and _lab._suelo_marcha.visible and _lab._presa.visible)
		if _lab._mpj == null:
			continue
		# 2) persigue a una presa quieta a 9 u
		_lab._presa_pos = Vector3(8.0, 0.0, 0.0)
		_lab.marcha_modo("persigue")
		var estados: Dictionary = {}
		var clips: Dictionary = {}
		_max_z = 0.0
		var x0: float = _lab._mpj.position.x
		var ll0: int = _lab._mm.llamadas
		var rec: float = await _andar(30 * 14, estados, clips)
		var dx: float = _lab._mpj.position.x - x0
		_ok("2 %s: el animal se desplaza hacia la presa" % id, dx > 4.0, "dx=%.2f recorrido=%.2f x=%.2f" % [dx, rec, _lab._mpj.position.x])
		_ok("2 %s: la capa corre (llamadas > 0)" % id, _lab._mm.llamadas - ll0 > 100, "llamadas +%d" % (_lab._mm.llamadas - ll0))
		print("      estados de conducta vistos: %s · clips: %s" % [str(estados.keys()), str(clips.keys())])
		if id == "loberno":
			_ok("2 loberno: aparece el estado de acecho al acercarse", estados.has("acecho"))
			_ok("2 loberno: pausa y embestida", estados.has("pausa") and estados.has("embestida"))
		else:
			_ok("2 canouro: aparece zigzag o tanteo", estados.has("para") or estados.has("atras") or _max_z > 0.12, "desvío lateral máx. %.2f u" % _max_z)
			_ok("2 canouro: tanteo (para y atrás) y arrancada", estados.has("para") and estados.has("atras") and estados.has("arrancada"))
		_ok("2 %s: el rótulo escribe modelo, MARCHA, clip, velocidad, lomo y cabeza" % id, _rotulo_completo(id))
		# 3) B: sin capa
		_lab.alternar_marcha_animal()
		_ok("3 %s: B pone MARCHA_ANIMAL = false" % id, not MarchaCuadrupedo3D.MARCHA_ANIMAL)
		await _frames(2)
		var ll1: int = _lab._mm.llamadas
		_lab._presa_pos = Vector3(-8.0, 0.0, 0.0)
		var estados2: Dictionary = {}
		var clips2: Dictionary = {}
		var x1: float = _lab._mpj.position.x
		await _andar(30 * 4, estados2, clips2)
		_ok("3 %s: sin MARCHA la capa no corre (llamadas no sube)" % id, _lab._mm.llamadas == ll1 and not _lab._mm.active, "llamadas %d -> %d" % [ll1, _lab._mm.llamadas])
		_ok("3 %s: sin MARCHA sigue moviéndose (como antes)" % id, absf(_lab._mpj.position.x - x1) > 1.5, "x %.2f -> %.2f" % [x1, _lab._mpj.position.x])
		_ok("3 %s: sin MARCHA no hay estado de conducta" % id, estados2.size() == 1 and estados2.has(""), str(estados2.keys()))
		print("      sin MARCHA, clips: %s" % str(clips2.keys()))
		# B otra vez
		_lab.alternar_marcha_animal()
		await _frames(3)
		var ll2: int = _lab._mm.llamadas
		await _frames(10)
		_ok("3 %s: B otra vez devuelve la capa" % id, _lab._mm.llamadas > ll2 and _lab._mm.active)
		# 4) patrulla ida y vuelta
		_lab.marcha_modo("patrulla")
		var xmin: float = INF
		var xmax: float = -INF
		for i in range(30 * 14):
			await process_frame
			xmin = minf(xmin, _lab._mpj.position.x)
			xmax = maxf(xmax, _lab._mpj.position.x)
		_ok("4 %s: la patrulla va y vuelve" % id, xmax - xmin > 4.0, "x entre %.2f y %.2f" % [xmin, xmax])
		# N: salir
		_lab._alternar_modo_marcha()
		await _frames(3)
		_ok("4 %s: N vuelve al rig de antes" % id, _lab._mpj == null and _lab._capa.visible and _lab._modelo.visible and _lab._suelo_chico.visible)

	# el lince no tiene perfil: con N sigue como antes
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true
	_lab._cambiar_modelo("lince")
	await _frames(3)
	_lab._alternar_modo_marcha()
	await _frames(5)
	_ok("5 lince: N no monta animal de marcha y el rig sigue a la vista", _lab._mpj == null and _lab._modelo.visible and _lab._capa.visible)
	_lab._alternar_modo_marcha()
	MarchaCuadrupedo3D.MARCHA_ANIMAL = true

	print("")
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


var _max_z: float = 0.0       ## desvío máximo del animal respecto a la línea recta hacia la presa (la presa está en z = 0): el zigzag no es un estado de `_est`, se ve en la trayectoria


func _rotulo_completo(id: String) -> bool:
	var t: String = _lab._rotulo.text
	for k in [id, "MARCHA", "clip", "velocidad real", "pendiente del lomo", "giro de la cabeza", "conducta"]:
		if not t.contains(k):
			return false
	return true
