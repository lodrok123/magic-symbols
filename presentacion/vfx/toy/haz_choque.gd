class_name HazChoque
extends RefCounted

## EL HAZ ENVUELVE LO QUE GOLPEA, PARA EL AGUA Y EL RAYO (9/11/2026; ampliación de Pablo: «si ves algo aplicable al resto puedes hacerlo»). El fuego lo hace dentro de FuegoToy (`_haz`); esto es lo
## de AguaToy y RayoToy, con los colores de SUS paletas (agua_paleta.gd, rayo_paleta.gd) y las reglas de cada elemento:
##   AGUA  · salpicadura translúcida en abanico pegada a la superficie golpeada (y tumbada en el suelo, que es lo que lee la cámara del juego) + gotas que caen + un charquito breve en el choque
##           (el decal de suelo, OSCURO y húmedo: el agua NO brilla, regla de PLAN_VFX_ELEMENTOS.md). El suelo bajo el chorro se oscurece un poco.
##   RAYO  · arcos que reptan por la superficie desde el punto de choque (aditivos, a saltos, con el hilo blanco del rayo) + un destello blanco-azulado breve en el suelo (parpadea y se apaga en 0,3 s).
## Los choques los calcula la lógica (`HechizoVivo._haz_choques`) y los pasa VfxToyJuego (`choques` del toy, en su espacio local). Mismos topes que el fuego (FuegoToy.HAZ_MAX_*): salpicaduras y manchas
## de suelo se cuentan por grupo en toda la escena. Con `FuegoToy.haz_ideas` = false no se dibuja nada de esto (el haz de antes).

const SH_AGUA: String = "res://presentacion/vfx/toy/salpicadura_agua_haz.gdshader"
const SH_ARCOS: String = "res://presentacion/vfx/toy/arcos_rayo_haz.gdshader"
const TEX: String = "res://assets/vfx/lelu_noise/"
const AguaPaleta = preload("res://presentacion/vfx/toy/agua_paleta.gd")
const RayoPaleta = preload("res://presentacion/vfx/toy/rayo_paleta.gd")
## Humedad bajo el chorro de agua: el LECHO de la paleta aún más oscuro (suelo mojado), y el tinte del destello del rayo (HALO_BORDE casi blanco).
const TINTE_HUMEDO: Color = Color(0.05, 0.2, 0.24, 1.0)
const TINTE_DESTELLO: Color = Color(0.78, 0.9, 1.0, 1.0)
const GRUPO_GOTAS: StringName = &"gotas_choque"
const GRUPO_MATS: StringName = &"haz_choque_vfx"      ## las láminas y el decal de un toy que no empuja `crece`/`corte` a sus materiales solo (RayoToy): ver `param`


## Pone `nombre` = v en los materiales de las láminas y el decal de ESTE toy (los de su Cuerpo).
static func param(toy: Node, nombre: String, v: float) -> void:
	for n in toy.find_children("*", "MeshInstance3D", true, false):
		if (n as Node).is_in_group(GRUPO_MATS):
			var m: ShaderMaterial = (n as MeshInstance3D).material_override as ShaderMaterial
			if m != null:
				m.set_shader_parameter(nombre, v)


## Largo con el que se DIBUJA el haz: se corta en el primer choque contra un TOPE (muro, casilla sólida, barrera; no los enemigos ni objetos que atraviesa), un poco dentro (MARGEN_TOPE).
## Sin tope (o con `FuegoToy.haz_ideas` = false) es `largo`. Así nada del chorro (malla, punta, humo, luz) queda detrás del obstáculo.
const MARGEN_TOPE: float = 0.04
static func largo_corte(choques: Array, largo: float) -> float:
	if not FuegoToy.haz_ideas:
		return largo
	var corte: float = largo
	for ch in choques:
		if not (ch is Dictionary and (ch as Dictionary).has("d")):
			continue
		var tipo: String = String((ch as Dictionary).get("tipo", "muro"))
		if tipo == "enemigo" or tipo == "objeto":
			continue
		corte = minf(corte, maxf(float((ch as Dictionary)["d"]) + MARGEN_TOPE, 0.3))
	return corte

## Hasta FuegoToy.HAZ_MAX_CHOQUES choques válidos de la lista (cada uno {d, x, n}).
static func validos(choques: Array) -> Array:
	var cs: Array = []
	for ch in choques:
		if cs.size() >= FuegoToy.HAZ_MAX_CHOQUES:
			break
		if ch is Dictionary and (ch as Dictionary).has("d"):
			cs.append(ch)
	return cs


static func _vivos(padre: Node, grupo: StringName) -> int:
	return padre.get_tree().get_nodes_in_group(grupo).size() if padre.is_inside_tree() else 0


## Lámina vertical pegada a la superficie + lámina tumbada en el suelo delante de ella (la cámara del juego mira a lo largo de Z y una lámina vertical de normal X se vería de canto).
## `mat_fn` crea un material nuevo (con `suelo` = 0 o 1). Devuelve [vertical, suelo] o [] si se llenó el tope de la escena.
static func hojas(padre: Node3D, ch: Dictionary, h: float, tam: float, i: int, mat_fn: Callable) -> Array:
	if _vivos(padre, FuegoToy.HAZ_GRUPO_SALPICADURA) >= FuegoToy.HAZ_MAX_SALPICADURAS:
		return []
	var n: Vector3 = ch.get("n", Vector3(0, 0, 1)) as Vector3
	n.y = 0.0
	n = n.normalized() if n.length() > 0.01 else Vector3(0, 0, 1)
	var p: Vector3 = Vector3(float(ch.get("x", 0.0)), h, -float(ch["d"]))
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(tam, tam)
	var mv: MeshInstance3D = MeshInstance3D.new()
	mv.name = "Salpicadura%d" % i
	mv.mesh = q
	mv.material_override = mat_fn.call(0.0, float(i))
	mv.transform = Transform3D(Basis(Vector3.UP.cross(n).normalized(), Vector3.UP, n), p + n * 0.06)
	mv.extra_cull_margin = 1.0
	mv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mv.add_to_group(FuegoToy.HAZ_GRUPO_SALPICADURA, true)
	mv.add_to_group(GRUPO_MATS, true)
	padre.add_child(mv)
	var qs: QuadMesh = QuadMesh.new()
	qs.size = Vector2(tam, tam)
	qs.orientation = PlaneMesh.FACE_Y
	var ms: MeshInstance3D = MeshInstance3D.new()
	ms.name = "SalpicaduraSuelo%d" % i
	ms.mesh = qs
	ms.material_override = mat_fn.call(1.0, float(i) + 0.5)
	ms.position = Vector3(p.x, 0.16, p.z) + n * tam * 0.2
	ms.extra_cull_margin = 1.0
	ms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ms.add_to_group(GRUPO_MATS, true)
	padre.add_child(ms)
	return [mv, ms]


## Mancha de suelo (decal que lee la profundidad: luz_suelo_haz.gdshader) con un tinte fijo en vez de la rampa del fuego. `p` = parámetros del shader (fuerza, late, parpadeo...).
static func decal(padre: Node3D, largo: float, cs: Array, tinte: Color, p: Dictionary, fuerza_choque: float, radio_choque: float) -> MeshInstance3D:
	if _vivos(padre, FuegoToy.HAZ_GRUPO_LUZ_SUELO) >= FuegoToy.HAZ_MAX_LUCES_SUELO:
		return null
	var longitud: float = largo + 1.8
	var centro_u: float = (largo + 0.6) * 0.5
	var dim: Vector3 = Vector3(FuegoToy.HAZ_LUZ_ANCHO, AvisoAreaFuego.ALTO_CAJA, longitud)
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(FuegoToy.SH_LUZ_SUELO)
	m.render_priority = -2
	m.set_shader_parameter("rampa", FuegoToy._rampa_de_bola())
	m.set_shader_parameter("semilla", randf())
	m.set_shader_parameter("dim", dim)
	m.set_shader_parameter("centro_u", centro_u)
	m.set_shader_parameter("largo", largo)
	m.set_shader_parameter("centro_y", AvisoAreaFuego.CENTRO_Y)
	m.set_shader_parameter("alto_max", FuegoToy.HAZ_LUZ_ALTO_MAX)
	m.set_shader_parameter("tinte", tinte)
	for k in p:
		m.set_shader_parameter(k, p[k])
	for k in cs.size():
		var ch: Dictionary = cs[k]
		m.set_shader_parameter("choque_a" if k == 0 else "choque_b", Vector4(float(ch["d"]), float(ch.get("x", 0.0)), radio_choque, fuerza_choque))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "LuzSuelo"
	var caja: BoxMesh = BoxMesh.new()
	caja.size = Vector3.ONE
	mi.mesh = caja
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = dim
	mi.position = Vector3(0.0, AvisoAreaFuego.CENTRO_Y, -centro_u)
	mi.extra_cull_margin = 2.0
	mi.add_to_group(FuegoToy.HAZ_GRUPO_LUZ_SUELO, true)
	mi.add_to_group(GRUPO_MATS, true)
	padre.add_child(mi)
	return mi


static func _mat(shader: String, extra: Dictionary) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader)
	m.render_priority = 1
	m.set_shader_parameter("ruido_a", load(TEX + "T_PerlinNoise_Tiled.png"))
	m.set_shader_parameter("ruido_fino", load(TEX + "T_Noise1_tiled.png"))
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


## Arranca las partículas de un choque cuando el chorro ya ha llegado (el toy las crea apagadas).
static func _encender_tarde(gp: GPUParticles3D, s: float) -> void:
	if not gp.is_inside_tree():
		gp.emitting = true
		return
	var ref: WeakRef = weakref(gp)
	gp.get_tree().create_timer(s, false).timeout.connect(func() -> void:
		var g: GPUParticles3D = ref.get_ref() as GPUParticles3D
		if g != null and is_instance_valid(g):
			g.emitting = true)


## AGUA. `padre` = el Cuerpo del toy; h = altura del eje; r = radio del haz; largo = m del haz; k = escala del haz (HazGas.escala_de, 12/11: el choque × k).
static func agua(padre: Node3D, choques: Array, largo: float, h: float, r: float, k: float = 1.0) -> void:
	var kk: float = maxf(k, 0.05)
	var cs: Array = validos(choques)
	var humedo: Dictionary = {"fuerza": 0.34, "late": 0.0}
	decal(padre, largo, cs, TINTE_HUMEDO, humedo, 0.5, 1.2 * kk)          # el suelo bajo el chorro se humedece (oscuro, sin brillo) y el charquito del choque es más fuerte
	for i in cs.size():
		var ch: Dictionary = cs[i]
		var tam: float = clampf(r / kk * 2.4 + 0.3, 1.6, 3.4) * kk
		hojas(padre, ch, h, tam, i, func(suelo: float, sem: float) -> ShaderMaterial:
			return _mat(SH_AGUA, {"semilla": sem * 0.9 + 0.2, "suelo": suelo, "tono_a": AguaPaleta.HONDO, "tono_b": AguaPaleta.SOMERO, "tono_c": AguaPaleta.ESPUMA}))
		var n: Vector3 = ch.get("n", Vector3(0, 0, 1)) as Vector3
		n.y = 0.0
		n = n.normalized() if n.length() > 0.01 else Vector3(0, 0, 1)
		var p: Vector3 = Vector3(float(ch.get("x", 0.0)), h, -float(ch["d"]))
		# gotas que salen del choque, caen y se apagan al tocar el suelo (un pequeño punto de espuma)
		var gp: GPUParticles3D = GPUParticles3D.new()
		gp.name = "GotasChoque%d" % i
		gp.position = p + n * 0.1 * kk
		gp.amount = 10
		gp.lifetime = 0.7
		gp.local_coords = true
		gp.fixed_fps = 0
		gp.emitting = false
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gp.visibility_aabb = AABB(Vector3(-4, -3, -4), Vector3(8, 8, 8))
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.direction = (n + Vector3(0, 0.7, 0)).normalized()
		pm.spread = 50.0
		pm.initial_velocity_min = 1.6 * kk          # velocidad y gravedad × k: la misma duración, recorrido × k
		pm.initial_velocity_max = 3.4 * kk
		pm.gravity = Vector3(0, -9.5, 0) * kk
		pm.scale_min = 0.7
		pm.scale_max = 1.2
		pm.color_ramp = FuegoToy._gradiente([Color(AguaPaleta.SOMERO, 0.0), Color(AguaPaleta.ESPUMA, 0.95), Color(AguaPaleta.SOMERO, 0.0)], [0.0, 0.2, 1.0])
		gp.process_material = pm
		var qd: QuadMesh = QuadMesh.new()
		qd.size = Vector2(0.11, 0.11)
		var sm: StandardMaterial3D = StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		sm.vertex_color_use_as_albedo = true
		sm.albedo_texture = FuegoToy._textura_chispa()
		sm.disable_receive_shadows = true
		qd.material = sm
		gp.draw_pass_1 = qd
		gp.add_to_group(GRUPO_GOTAS, true)
		padre.add_child(gp)
		_encender_tarde(gp, 0.3)


## RAYO. Arcos por la superficie y destello breve en el suelo en el choque. k = escala del haz (HazGas.escala_de, 12/11: el choque × k).
static func rayo(padre: Node3D, choques: Array, largo: float, h: float, r: float, k: float = 1.0) -> void:
	var kk: float = maxf(k, 0.05)
	var cs: Array = validos(choques)
	if cs.is_empty():
		return
	var dm: MeshInstance3D = decal(padre, largo, cs, TINTE_DESTELLO, {"fuerza": 0.0, "late": 0.0, "parpadeo": 1.0, "destello": 1.0}, 0.85, 1.5 * kk)
	if dm != null and padre.is_inside_tree():
		var mat: ShaderMaterial = dm.material_override as ShaderMaterial
		var tw: Tween = padre.create_tween()
		tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("destello", v), 1.0, 0.0, 0.3).set_ease(Tween.EASE_OUT)      # dura muy poco
	for i in cs.size():
		var tam: float = clampf(r / kk * 2.0 + 0.4, 1.6, 3.2) * kk
		hojas(padre, cs[i] as Dictionary, h, tam, i, func(suelo: float, sem: float) -> ShaderMaterial:
			var m: ShaderMaterial = _mat(SH_ARCOS, {"semilla": sem * 0.7, "suelo": suelo, "c_nucleo": RayoPaleta.NUCLEO, "c_cuerpo": RayoPaleta.CUERPO, "c_halo": RayoPaleta.HALO, "c_borde": RayoPaleta.HALO_BORDE})
			return m)
