extends SceneTree
## PRUEBA (Pipeline, 22/10): albedos EoW (`Albedos3D`, PLAN_EOW_VISUAL §1.2). Sin ventana. Comprueba que las constantes por familia llegan a los tres sitios
## (shader del suelo, materiales de Hierba3D, shader común de Ocluso3D) y que el interruptor `albedos_eow` = false deja (K, VALOR) = (1, 1) en todos.
## Lo que NO puede medir sin GPU es cómo se ve: eso son las capturas de docs/capturas/albedos/.
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_albedos.gd
const ESCENA: String = "res://escenas/PruebaBosque01.tscn"
var _fallos: int = 0


func _initialize() -> void:
	_correr()


func _ok(cond: bool, texto: String) -> void:
	print(("  OK   " if cond else "  MAL  ") + texto)
	if not cond:
		_fallos += 1


func _v2(v: Variant, x: float, y: float) -> bool:
	return v is Vector2 and (v as Vector2).is_equal_approx(Vector2(x, y))


func _correr() -> void:
	print("== constantes por familia ==")
	_ok(is_equal_approx(Albedos3D.k_de("hierba"), Albedos3D.HIERBA_K) and is_equal_approx(Albedos3D.valor_de("hierba"), Albedos3D.HIERBA_VALOR), "hierba: K y VALOR de las constantes")
	_ok(is_equal_approx(Albedos3D.k_de("hierba_matojos"), Albedos3D.TARJETA_K), "tarjetas de hierba: TARJETA_K")
	_ok(is_equal_approx(Albedos3D.k_de("camino"), Albedos3D.CAMINO_K) and is_equal_approx(Albedos3D.valor_de("camino"), Albedos3D.CAMINO_VALOR), "camino")
	_ok(is_equal_approx(Albedos3D.k_de("tierra"), Albedos3D.TIERRA_K) and is_equal_approx(Albedos3D.valor_de("tierra"), Albedos3D.TIERRA_VALOR), "tierra")
	_ok(is_equal_approx(Albedos3D.k_de("piedra"), Albedos3D.PIEDRA_K) and is_equal_approx(Albedos3D.valor_de("piedra"), Albedos3D.PIEDRA_VALOR), "piedra")
	_ok(is_equal_approx(Albedos3D.k_de("piezas"), Albedos3D.PIEZAS_K) and is_equal_approx(Albedos3D.valor_de("piezas"), Albedos3D.PIEZAS_VALOR), "piezas")
	_ok(is_equal_approx(Albedos3D.k_de("desconocida"), 1.0) and is_equal_approx(Albedos3D.valor_de("desconocida"), 1.0), "familia desconocida: (1, 1)")
	# Lo que se busca: contraste de EoW (rango 25-45 niveles) para las piezas y las losas, y valor parecido entre hierba y suelo (VALOR < 1 = más oscuro que OSCURECER_SUELO solo).
	_ok(Albedos3D.PIEZAS_K < 1.0 and Albedos3D.PIEDRA_K < 1.0 and Albedos3D.TARJETA_K < 1.0, "piezas, losas y tarjetas comprimen su contraste (K < 1)")
	_ok(Albedos3D.CAMINO_K > 1.0, "el camino, casi liso, gana grano (K > 1)")
	_ok(absf(Albedos3D.HIERBA_VALOR - Albedos3D.CAMINO_VALOR) < 0.15, "hierba y camino bajan de valor parecido (OSCURECER_SUELO: ver ARTE.md §10)")
	_ok(_v2(Albedos3D.par(0.5, 0.8, true), 0.5, 0.8) and _v2(Albedos3D.par(0.5, 0.8, false), 1.0, 1.0), "par(): (K, VALOR) encendido y (1, 1) apagado")
	_ok(is_equal_approx(Albedos3D.valor_bloque("res://arte/suelo_meshy/stone_arriba.png", true), Albedos3D.PIEDRA_VALOR)
		and is_equal_approx(Albedos3D.valor_bloque("res://arte/suelo_meshy/cuerpo.png", true), Albedos3D.TIERRA_VALOR)
		and is_equal_approx(Albedos3D.valor_bloque("res://arte/suelo_meshy/cuerpo.png", false), 1.0), "bloques triplanares: su VALOR, y 1 con el interruptor apagado")
	# La estadística de la herramienta de medida: una imagen plana no tiene contraste, y comprimir no cambia la media (en lineal).
	var plana := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	plana.fill(Color(0.5, 0.5, 0.5))
	var e0: Dictionary = load("res://herramientas/medir_albedos.gd").estadistica(plana)
	_ok(is_zero_approx(float(e0["desv"])), "estadística: imagen plana = desviación 0")

	print("== maqueta con albedos_eow = true ==")
	Albedos3D.activo = true
	var m: Node = await _montar(true)
	var suelo: ShaderMaterial = m.get("_mat_suelo") as ShaderMaterial
	_ok(suelo != null, "la maqueta tiene su material de suelo")
	if suelo != null:
		_ok(_v2(suelo.get_shader_parameter("alb_hierba"), Albedos3D.HIERBA_K, Albedos3D.HIERBA_VALOR), "suelo: alb_hierba = (HIERBA_K, HIERBA_VALOR)")
		_ok(_v2(suelo.get_shader_parameter("alb_camino"), Albedos3D.CAMINO_K, Albedos3D.CAMINO_VALOR), "suelo: alb_camino")
		_ok(_v2(suelo.get_shader_parameter("alb_tierra"), Albedos3D.TIERRA_K, Albedos3D.TIERRA_VALOR), "suelo: alb_tierra")
		_ok(_v2(suelo.get_shader_parameter("alb_piedra"), Albedos3D.PIEDRA_K, Albedos3D.PIEDRA_VALOR), "suelo: alb_piedra")
		_ok(suelo.shader.code.contains("alb_corr(t_hierba") and not suelo.shader.code.contains("muestra(t_hierba, t, m)"), "el shader del suelo ya no muestrea la hierba sin corregir")
	var hierba: Node = m.get("_hierba")
	_ok(hierba != null and bool(hierba.get("albedos_eow")), "Hierba3D recibe albedos_eow = true")
	if hierba != null:
		var mb: ShaderMaterial = hierba.get("_mat_matojo") as ShaderMaterial
		var mt: ShaderMaterial = hierba.get("_mat_tarjeta") as ShaderMaterial
		_ok(mb != null and _v2(mb.get_shader_parameter("alb_hierba"), Albedos3D.BRIZNA_K, Albedos3D.HIERBA_VALOR), "briznas: (BRIZNA_K, HIERBA_VALOR)")
		_ok(mt != null and _v2(mt.get_shader_parameter("alb_hierba"), Albedos3D.TARJETA_K, Albedos3D.HIERBA_VALOR), "tarjetas: (TARJETA_K, HIERBA_VALOR)")
		if mt != null:
			var med: Vector3 = mt.get_shader_parameter("alb_media")
			_ok(med.x > 0.0 and med.x < 1.0 and med.y > med.x, "tarjetas: media lineal del atlas razonable (verde: g > r) %s" % str(med))
	_comprobar_ocluso(true)
	m.queue_free()
	await process_frame
	await process_frame

	print("== maqueta con albedos_eow = false (= lo de antes) ==")
	m = await _montar(false)
	suelo = m.get("_mat_suelo") as ShaderMaterial
	if suelo != null:
		for fam in ["alb_hierba", "alb_camino", "alb_tierra", "alb_piedra"]:
			_ok(_v2(suelo.get_shader_parameter(fam), 1.0, 1.0), "suelo: %s = (1, 1)" % fam)
	hierba = m.get("_hierba")
	if hierba != null:
		var mb2: ShaderMaterial = hierba.get("_mat_matojo") as ShaderMaterial
		var mt2: ShaderMaterial = hierba.get("_mat_tarjeta") as ShaderMaterial
		_ok(mb2 != null and _v2(mb2.get_shader_parameter("alb_hierba"), 1.0, 1.0), "briznas: (1, 1)")
		_ok(mt2 != null and _v2(mt2.get_shader_parameter("alb_hierba"), 1.0, 1.0), "tarjetas: (1, 1)")
	_comprobar_ocluso(false)
	m.queue_free()
	await process_frame

	print("")
	print("FALLOS %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _montar(encendido: bool) -> Node:
	var m: Node = (load(ESCENA) as PackedScene).instantiate()
	m.set("albedos_eow", encendido)
	root.add_child(m)
	for _i in 40:
		await process_frame
	return m


func _comprobar_ocluso(encendido: bool) -> void:
	# El valor del uniforme global no se puede leer en headless (renderizador ficticio): se comprueba el estado que se le envía.
	_ok(Albedos3D._registrado, "Ocluso3D: el uniforme global %s está registrado" % Albedos3D.PARAM_PIEZAS)
	_ok(Albedos3D.activo == encendido, "Ocluso3D: interruptor (Albedos3D.activo) = %s" % str(encendido))
	var parcheadas: int = 0
	for cull in ["cull_back", "cull_disabled", "cull_front"]:
		if Ocluso3D._shader(cull).code.contains(Albedos3D.MARCA):
			parcheadas += 1
	_ok(parcheadas == 3, "Ocluso3D: las 3 variantes de culling llevan la corrección (%d)" % parcheadas)
	_ok(Albedos3D.parchear_ocluso() == 3, "parchear_ocluso() es idempotente (3 variantes, sin duplicar)")
	var codigo: String = Ocluso3D._shader("cull_back").code
	_ok(codigo.count("albedos_eow(tex_albedo") == 1 and codigo.find("albedos_eow(tex_albedo") < codigo.find("if (quemado > 0.0)"), "la corrección va una sola vez y antes del quemado")
