extends SceneTree
## PRUEBA del conjuro UAL (25/11, Pablo: «para la flecha + fuego usa en bucle el conjunto UAL conjuro 1, 2, 3 y 4»). Comprueba que:
##  · jugadora_base trae los cuatro clips (ClipsFamilia.FUENTE_CLIPS_UAL) y Pj3D encuentra sus roles;
##  · Lanzador3D.usa_conjuro_ual: sí con fuego + flecha; no con fuego sin flecha ni con agua + flecha;
##  · apuntar: entrar (una vez) y, al acabar, mantener en bucle (sigue ahí pasado su largo); llamar otra vez no la reinicia;
##  · soltar: soltar y luego salir; `soltar_lanzar` vuelve a idle;
##  · lanza con la mano DERECHA (los clips van reflejados, ClipsFamilia «espejo»): manteniendo, la derecha va alta y la izquierda (la del libro) baja;
##  · los dedos van alineados: en mantener, las falanges del índice no se doblan más de 60° (sin alinear pasaban de 100°).
## Sin ventana:
##   godot --headless --path . --script res://herramientas/prueba_conjuro_ual.gd

var _fallos: int = 0


func _ok(c: bool, m: String) -> void:
	print("OK    " if c else "FALLO ", m)
	if not c:
		_fallos += 1


func _initialize() -> void:
	_correr()


func _esperar(seg: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seg * 1000.0):
		await process_frame


func _correr() -> void:
	Estado.nuevo()
	await process_frame
	var pj := Pj3D.new()
	root.add_child(pj)
	pj.cargar("jugadora_base")
	for _i in 3:
		await process_frame
	_ok(pj.tiene_conjuro_ual(), "jugadora_base tiene los cuatro clips del conjuro (%s)" % [Array(Pj3D.CONJURO_UAL).map(func(r: Variant) -> String: return pj.clip_de(String(r)))])

	var r := Lanzador3D.Receta3D.new()
	r.contadores = {"flecha": 1}
	_ok(Lanzador3D.usa_conjuro_ual(r, "fuego"), "fuego + flecha usa el conjuro")
	_ok(not Lanzador3D.usa_conjuro_ual(r, "agua"), "agua + flecha no")
	var r2 := Lanzador3D.Receta3D.new()
	r2.contadores = {"barrera": 1}
	_ok(not Lanzador3D.usa_conjuro_ual(r2, "fuego"), "fuego sin flecha no")

	pj.apuntar_conjuro()
	_ok(pj.animacion_actual == "cast_conjuro_entrar", "al apuntar: entrar (%s)" % pj.animacion_actual)
	await _esperar(pj.duracion("cast_conjuro_entrar") + 0.25)
	_ok(pj.animacion_actual == "cast_conjuro_mantener", "al acabar entrar: mantener (%s)" % pj.animacion_actual)
	await _esperar(pj.duracion("cast_conjuro_mantener") + 0.3)
	_ok(pj.animacion_actual == "cast_conjuro_mantener", "mantener sigue en bucle pasado su largo (%s)" % pj.animacion_actual)
	pj.apuntar_conjuro()
	_ok(pj.animacion_actual == "cast_conjuro_mantener", "apuntar otra vez no reinicia (%s)" % pj.animacion_actual)
	# 25/11 (espejo): lanza con la DERECHA (la izquierda lleva el libro): manteniendo, la mano derecha va alta y al frente y la izquierda baja.
	var md: Vector3 = pj.posicion_mano("derecha")
	var mi: Vector3 = pj.posicion_mano("izquierda")
	var alto: float = pj.alto_modelo() * pj.scale.y
	_ok(md.y - mi.y > 0.15 * alto, "manteniendo, la mano derecha va más alta que la izquierda (%.2f u frente a %.2f; alto %.2f)" % [md.y - pj.global_position.y, mi.y - pj.global_position.y, alto])
	var dedo: float = _flexion_indice(pj)
	_ok(dedo < 60.0, "dedos alineados en mantener: el índice se dobla %.0f° (máx. 60)" % dedo)

	var d: float = pj.lanzar_conjuro("fuego")
	_ok(pj.animacion_actual == "cast_conjuro_soltar", "al soltar: soltar (%s)" % pj.animacion_actual)
	_ok(d > 0.5 and d < 1.5, "soltar + salir duran %.2f s" % d)
	await _esperar(pj.duracion("cast_conjuro_soltar") + 0.2)
	_ok(pj.animacion_actual == "cast_conjuro_salir", "tras soltar: salir (%s)" % pj.animacion_actual)
	pj.soltar_lanzar()
	_ok(pj.animacion_actual == "idle", "soltar_lanzar vuelve a idle (%s)" % pj.animacion_actual)

	print("\n%s (%d fallos)" % ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	quit(1 if _fallos > 0 else 0)


## Mayor ángulo entre falanges consecutivas del índice derecho (y del tramo muñeca → nudillo con la primera).
func _flexion_indice(pj: Pj3D) -> float:
	var sk: Skeleton3D = pj.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var p := func(n: String) -> Vector3: return sk.get_bone_global_pose(sk.find_bone("mixamorig_Right" + n)).origin
	var pts: Array = [p.call("Hand"), p.call("HandIndex1"), p.call("HandIndex2"), p.call("HandIndex3"), p.call("HandIndex4")]
	var m: float = 0.0
	for k in range(1, pts.size() - 1):
		m = maxf(m, rad_to_deg(((pts[k] as Vector3) - (pts[k - 1] as Vector3)).angle_to((pts[k + 1] as Vector3) - (pts[k] as Vector3))))
	return m
