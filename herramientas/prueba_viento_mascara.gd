extends SceneTree

## PRUEBA (22/10): el atlas de remolino como MÁSCARA (`VfxViento.remolino_mascara`): las tarjetas de remolino usan el color de las cintas, alfa global bajo y fundido.
##   godot --headless --path . --fixed-fps 30 -s herramientas/prueba_viento_mascara.gd

var _fallos: int = 0


func _initialize() -> void:
	_correr()


func _ok(cond: bool, texto: String) -> void:
	print(("  OK   " if cond else "  MAL  "), texto)
	if not cond:
		_fallos += 1


func _tarjetas(raiz: Node) -> Array:
	var res: Array = []
	for n in raiz.find_children("remolino_*", "MeshInstance3D", true, false):
		res.append(n)
	return res


func _correr() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	await process_frame
	VfxViento.usar_atlas = true
	_ok(VfxViento.atlas_real(), "el atlas real de Meshy se usa (si no, no hay tarjetas de remolino)")
	_ok(VfxViento.remolino_mascara, "el interruptor remolino_mascara arranca en true")
	_ok(absf(VfxViento.REMOLINO_MASCARA_ALFA - 0.45) < 0.001 and VfxViento.REMOLINO_MASCARA_ALFA < VfxViento.CINTA_ALFA + 0.1, "alfa global de la tarjeta = %.2f" % VfxViento.REMOLINO_MASCARA_ALFA)

	# 1. material de la tarjeta
	var card: MeshInstance3D = VfxViento.hoja(0.8, 0, true)
	mundo.add_child(card)
	var m: Material = card.material_override
	_ok(m is ShaderMaterial, "con máscara la tarjeta de remolino usa un ShaderMaterial")
	if m is ShaderMaterial:
		var sm: ShaderMaterial = m
		var c: Color = sm.get_shader_parameter("color")
		_ok(c.is_equal_approx(VfxViento.COLOR_CINTA), "el color de la tarjeta es COLOR_CINTA (%s)" % str(c))
		var cinta: StandardMaterial3D = VfxViento.material_cinta()
		_ok(Color(cinta.albedo_color.r, cinta.albedo_color.g, cinta.albedo_color.b).is_equal_approx(Color(c.r, c.g, c.b)), "es el mismo color que el material de las cintas")
		_ok(is_equal_approx(float(sm.get_shader_parameter("alfa")), VfxViento.REMOLINO_MASCARA_ALFA), "alfa global del material = REMOLINO_MASCARA_ALFA")
		_ok(sm.get_shader_parameter("atlas") == VfxViento.atlas(), "la textura del atlas solo da la forma (sampler del atlas)")
		_ok(sm.shader.code.contains("blend_mix") and sm.shader.code.contains("depth_draw_never") and not sm.shader.code.contains("blend_add"), "mezcla alfa y sin profundidad, como las cintas")
		_ok(sm.shader.code.contains("smoothstep") and sm.shader.code.contains("dot(t.rgb"), "forma = alfa × luminancia con borde suave (smoothstep)")
	var hoja: MeshInstance3D = VfxViento.hoja(0.3, 1, false)
	_ok(hoja.material_override is StandardMaterial3D and (hoja.material_override as StandardMaterial3D).albedo_texture == VfxViento.atlas(), "las hojas (filas 0-2) siguen con su color del atlas")
	hoja.free()
	card.free()

	# 2. interruptor
	VfxViento.remolino_mascara = false
	var card2: MeshInstance3D = VfxViento.hoja(0.8, 0, true)
	_ok(card2.material_override is StandardMaterial3D and (card2.material_override as StandardMaterial3D).albedo_texture == VfxViento.atlas(), "con remolino_mascara = false: material antiguo con la textura del atlas")
	card2.free()
	VfxViento.remolino_mascara = true

	# 3. fundido en el remolino de impacto
	var raiz: Node3D = VfxViento.remolino(mundo, Vector3.ZERO, 1.5, 0.0)
	var cs: Array = _tarjetas(raiz)
	_ok(cs.size() == VfxViento.REMOLINO_TARJETAS, "el remolino lleva %d tarjetas de remolino (hay %d)" % [VfxViento.REMOLINO_TARJETAS, cs.size()])
	var maximo: float = 0.0
	var f0: float = 1.0
	var fin: float = 1.0
	var t: float = 0.0
	if cs.size() > 0:
		f0 = float((cs[0] as MeshInstance3D).get_instance_shader_parameter("fundido"))
	var previo: float = f0
	var salto: float = 0.0
	while t < VfxViento.T_REMOLINO + 0.1 and is_instance_valid(raiz):
		await create_timer(1.0 / 30.0, false).timeout
		t += 1.0 / 30.0
		if cs.size() > 0 and is_instance_valid(cs[0]):
			var f: float = float((cs[0] as MeshInstance3D).get_instance_shader_parameter("fundido"))
			maximo = maxf(maximo, f)
			salto = maxf(salto, absf(f - previo))
			previo = f
			fin = f
	_ok(f0 < 0.2, "la tarjeta nace casi invisible (fundido %.2f)" % f0)
	_ok(maximo > 0.95, "llega a fundido pleno (máx %.2f)" % maximo)
	_ok(fin < 0.1, "acaba desvanecida (fundido %.2f)" % fin)
	_ok(salto < 0.35, "sin cortes: salto máximo por fotograma %.2f" % salto)
	await create_timer(0.3, false).timeout
	_ok(not is_instance_valid(raiz), "el remolino se libera")

	# 4. torbellino: aparece y se va
	var pie := Node3D.new()
	mundo.add_child(pie)
	var eje: Node3D = VfxViento.torbellino(pie, Vector3.UP, 0.8, 2.0, 1.6)
	var tt: Array = _tarjetas(eje)
	_ok(tt.size() == VfxViento.TORBELLINO_TARJETAS, "el tornado lleva %d tarjetas de remolino (hay %d)" % [VfxViento.TORBELLINO_TARJETAS, tt.size()])
	await create_timer(0.8, false).timeout
	_ok(tt.size() > 0 and float((tt[0] as MeshInstance3D).get_instance_shader_parameter("fundido")) > 0.95, "en mitad de la vida el tornado tiene fundido pleno")
	await create_timer(1.2, false).timeout
	_ok(not is_instance_valid(eje), "el tornado se libera al acabar")

	print("FALLOS ", _fallos)
	quit(1 if _fallos > 0 else 0)
