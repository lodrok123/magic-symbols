extends SceneTree

## PRUEBA (Pipeline, 21/10): F1–F3 de PLAN_EOW. Luz por zona (`LuzZona3D`), banda tilt-shift (`TiltShift3D`) y sonda de reflejos.
## Mide que cada zona cambia el sol y el ambiente (no solo que exista), que la zona `bosque` reproduce EXACTAMENTE lo que tenía la maqueta antes
## (para no cambiar el aspecto de nada sin que nadie lo pida) y que una zona inexistente no toca nada. Lo que NO puede medir sin GPU es cómo se ve:
## eso se mira en la maqueta (PageUp = siguiente zona, PageDown = tilt-shift).
##   godot --headless --path . --script res://herramientas/prueba_look_diorama.gd
var _fallos: int = 0


func _initialize() -> void:
	_correr()


func _ok(cond: bool, texto: String) -> void:
	print(("  OK   " if cond else "  MAL  ") + texto)
	if not cond:
		_fallos += 1


func _correr() -> void:
	await process_frame          # el árbol ya está listo: global_position solo vale con el nodo dentro del árbol
	print("== LuzZona3D: zonas ==")
	var env := Environment.new()
	var sol := DirectionalLight3D.new()
	root.add_child(sol)
	# «clasico» = el estado de la maqueta ANTES de F1/V2 (prueba_test2.gd): ambiente plano (0,95; 0,94; 1) a 0,6, sol cálido a (-55°, 25°), sombra en 4 cascadas a 30 u.
	_ok(LuzZona3D.aplicar(env, sol, "clasico"), "«clasico» existe y se aplica")
	_ok(sol.light_color.is_equal_approx(Color(1.0, 0.96, 0.88)) and is_equal_approx(sol.light_energy, 1.0), "clasico: el sol cálido de siempre")
	_ok(is_equal_approx(sol.rotation_degrees.x, -55.0) and is_equal_approx(sol.rotation_degrees.y, 25.0), "clasico: -55° / 25° como antes")
	var mat: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
	var plano := Color(0.95, 0.94, 1.0)
	_ok(mat.sky_top_color.is_equal_approx(plano) and mat.ground_bottom_color.is_equal_approx(plano) and mat.sky_horizon_color.is_equal_approx(plano),
		"clasico: los dos colores del ambiente son el lila liso de antes (resultado idéntico al plano)")
	_ok(is_equal_approx(env.ambient_light_energy, 0.6) and env.ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "clasico: energía 0,6 y fuente de ambiente = sky")
	_ok(sol.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS and is_equal_approx(sol.directional_shadow_max_distance, 30.0) and is_equal_approx(sol.shadow_blur, 1.0),
		"clasico: sombra en 4 cascadas, 30 u, blur 1,0 como antes")
	_ok(env.background_mode == Environment.BG_CLEAR_COLOR, "el fondo NO lo toca (lo sigue decidiendo la escena)")

	# V2: «bosque» (la zona por defecto) es casi cenital, con dos colores de verdad y sombra ortogonal.
	_ok(LuzZona3D.aplicar(env, sol, "bosque"), "«bosque» existe y se aplica")
	var mb: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
	_ok(is_equal_approx(sol.rotation_degrees.x, LuzZona3D.SOL_INCLINACION) and sol.rotation_degrees.x < -65.0, "bosque: sol casi cenital (%.0f°)" % sol.rotation_degrees.x)
	_ok(not mb.sky_top_color.is_equal_approx(mb.ground_bottom_color), "bosque: ambiente de DOS colores de verdad (cielo ≠ suelo)")
	_ok(sol.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "bosque: sombra ortogonal sin cascadas")
	_ok(sol.directional_shadow_max_distance >= 30.0 and sol.directional_shadow_max_distance <= 40.0 and sol.shadow_blur > 1.0, "bosque: sombra a %.0f u con blur %.1f" % [sol.directional_shadow_max_distance, sol.shadow_blur])
	for z in ["agua", "fuego"]:
		_ok(LuzZona3D.ZONAS.has(z), "zona de ejemplo «%s» en ZONAS" % z)
	_ok(LuzZona3D.ZONAS["agua"]["sol_color"].b > LuzZona3D.ZONAS["agua"]["sol_color"].r, "agua: luz fría (más azul que roja)")
	_ok(LuzZona3D.ZONAS["fuego"]["sol_color"].r > LuzZona3D.ZONAS["fuego"]["sol_color"].b, "fuego: luz cálida (más roja que azul)")

	var vistos: Dictionary = {}
	for z in LuzZona3D.nombres():
		_ok(LuzZona3D.ZONAS.has(z), "«%s» está en ZONAS" % z)
		LuzZona3D.aplicar(env, sol, z)
		var m: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
		var firma: String = "%s|%s|%s|%.1f" % [sol.light_color, m.sky_top_color, m.ground_bottom_color, sol.rotation_degrees.x]
		_ok(not vistos.has(firma), "«%s» se ve distinta a las anteriores (sol/ambiente/ángulo)" % z)
		vistos[firma] = true
		var d: Dictionary = LuzZona3D.ZONAS[z]
		_ok(sol.light_color.is_equal_approx(d["sol_color"]) and is_equal_approx(sol.rotation_degrees.x, float(d["sol_pitch"])), "«%s»: el sol queda como dice la tabla" % z)
	LuzZona3D.aplicar(env, sol, "atardecer")
	var m2: ProceduralSkyMaterial = env.sky.sky_material as ProceduralSkyMaterial
	_ok(not m2.sky_top_color.is_equal_approx(m2.ground_bottom_color), "atardecer: ambiente de DOS colores (arriba ≠ abajo)")
	_ok(m2.sky_horizon_color.is_equal_approx(m2.sky_top_color.lerp(m2.ground_bottom_color, 0.5)), "el horizonte es la media (sin costura)")

	var antes_c: Color = sol.light_color
	var antes_x: float = sol.rotation_degrees.x
	_ok(not LuzZona3D.aplicar(env, sol, "no_existe"), "una zona inexistente devuelve false")
	_ok(sol.light_color == antes_c and is_equal_approx(sol.rotation_degrees.x, antes_x), "…y no toca el sol")
	_ok(LuzZona3D.aplicar(null, null, "bosque"), "env y sol nulos no revientan")
	var rec: String = "bosque"
	var n: int = 0
	while n < LuzZona3D.ORDEN.size():
		rec = LuzZona3D.siguiente(rec)
		n += 1
	_ok(rec == "bosque", "siguiente() recorre todas las zonas y vuelve al principio")
	_ok(LuzZona3D.siguiente("zzz") == LuzZona3D.ORDEN[1] or LuzZona3D.siguiente("zzz") == LuzZona3D.ORDEN[0], "siguiente() de una zona rara no revienta")

	print("== LuzZona3D: sonda de reflejos (F3) ==")
	var escena := Node3D.new()
	root.add_child(escena)
	var s: ReflectionProbe = LuzZona3D.sonda_reflejos(escena, Vector3(10, 3, 20), Vector3(40, 10, 40))
	_ok(s.get_parent() == escena and s.update_mode == ReflectionProbe.UPDATE_ONCE, "cuelga de la escena y se actualiza UNA vez (coste cero después)")
	_ok(s.size == Vector3(40, 10, 40) and s.box_projection, "cubre la sala y proyecta sobre su caja")
	_ok(s.global_position.is_equal_approx(Vector3(10, 3, 20)), "colocada en el centro pedido")
	_ok(s.ambient_mode == ReflectionProbe.AMBIENT_DISABLED, "solo aporta reflejos (el ambiente lo pone el Environment)")

	print("== TiltShift3D (F2) ==")
	var t := TiltShift3D.new()
	root.add_child(t)
	_ok(t.layer == 0, "va en la capa 0, por debajo del HUD (capa 1)")
	_ok(not t.activo(), "apagado de serie: no se dibuja nada")
	t.encendido = true
	_ok(t.activo(), "encendido: se dibuja")
	t.fuerza = 0.0
	_ok(not t.activo(), "fuerza 0 = apagado de verdad (el rectángulo ni se dibuja)")
	t.fuerza = 6.0
	t.centro = 7.0
	_ok(is_equal_approx(t.centro, 1.0), "centro fuera de rango se recorta (%.2f)" % t.centro)
	t.ancho = -1.0
	_ok(is_equal_approx(t.ancho, 0.0), "ancho negativo se recorta a 0")
	t.transicion = 0.0
	_ok(t.transicion > 0.0, "transición nunca llega a 0 (dividiría por cero en el shader)")
	t.gamma = 99.0
	_ok(is_equal_approx(t.gamma, 4.0), "gamma recortada a 4")
	t.fuerza = 1000.0
	_ok(is_equal_approx(t.fuerza, 24.0), "fuerza recortada a 24")
	var rect: ColorRect = t.get_node("Banda") as ColorRect
	var mt: ShaderMaterial = rect.material as ShaderMaterial
	_ok(is_equal_approx(float(mt.get_shader_parameter("fuerza")), 24.0) and is_equal_approx(float(mt.get_shader_parameter("centro")), 1.0),
		"los valores llegan al shader")
	var nombres: Array = []
	for u in mt.shader.get_shader_uniform_list():
		nombres.append(String(u["name"]))
	for u in ["centro", "ancho", "transicion", "gamma", "fuerza"]:
		_ok(nombres.has(u), "el shader declara «%s»" % u)
	_ok(rect.mouse_filter == Control.MOUSE_FILTER_IGNORE, "no se come los clics")

	print("== Posproceso3D (V1) ==")
	var e2 := Environment.new()
	var vp := SubViewport.new()
	root.add_child(vp)
	Posproceso3D.activo = false
	Posproceso3D.aplicar_entorno(e2, vp)
	_ok(e2.tonemap_mode == Environment.TONE_MAPPER_LINEAR and not e2.ssao_enabled and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "activo=false: el entorno queda como antes (lineal, sin SSAO, sin FXAA)")
	_ok(Posproceso3D.montar_vineta(escena) == null, "activo=false: no se monta la viñeta")
	Posproceso3D.activo = true
	Posproceso3D.aplicar_entorno(e2, vp)
	_ok(e2.tonemap_mode == Posproceso3D.TONEMAP_MODO and is_equal_approx(e2.tonemap_exposure, Posproceso3D.TONEMAP_EXPOSICION), "activo=true: tonemap y exposición de las constantes")
	_ok(vp.screen_space_aa == Posproceso3D.AA_MODO, "activo=true: antialiasing de pantalla de la constante")
	var rm: String = RenderingServer.get_current_rendering_method()
	_ok(e2.ssao_enabled == (Posproceso3D.SSAO_ACTIVO and rm == "forward_plus"), "SSAO: %s con el renderer «%s»" % [str(e2.ssao_enabled), rm])
	var vi: CanvasLayer = Posproceso3D.montar_vineta(escena)
	_ok(vi != null and vi.layer == 0 and vi.get_child(0) is ColorRect, "la viñeta va en la capa 0 (por debajo del HUD)")
	_ok((vi.get_child(0) as ColorRect).mouse_filter == Control.MOUSE_FILTER_IGNORE, "la viñeta no se come los clics")

	print("FALLOS %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
