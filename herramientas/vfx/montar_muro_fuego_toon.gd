extends SceneTree

## MONTA EL MURO DE FUEGO TOON (1/11, Dirección, prueba 2 de VFX, docs/PRUEBA2_VFX_TOON_2026-11-01.md §2): escribe presentacion/vfx/toon/MuroFuegoToon.tscn
## y las rampas en escalones (rampa_fuego_toon.tres, rampa_fuego_azul.tres) como recursos NORMALES de Godot, para retocarlos luego EN EL EDITOR.
## Es de un solo uso: si se vuelve a correr PISA lo retocado a mano (por eso no lo corre ninguna prueba).
##   godot --headless --path . --script res://herramientas/vfx/montar_muro_fuego_toon.gd
## Escena: EfectoVfx3D (mismo contrato preparar / lanzar / morir que las de la prueba 1) con dos planos de fuego_toon (delante y detrás, semillas distintas),
## humo toon en bolas que nace en la punta de la llama, chispas, UNA luz con titileo en escalones a 12 fps y el AnimationPlayer nacer / vivir / morir.
## Presupuesto: 1 luz y ≤ 300 partículas. Todo el movimiento va a FPS_TOON (los saltos de la luz, `fixed_fps` de las partículas, `fps` del shader).

const DIR: String = "res://presentacion/vfx/toon/"
const SCRIPT_EFECTO: String = "res://presentacion/vfx/efectos/efecto_vfx_3d.gd"
const FPS_TOON: int = 12
const TAM_MURO: Vector2 = Vector2(6.9, 1.5)
const TAM_COLUMNA: Vector2 = Vector2(1.0, 4.0)
const TAM_IMPACTO: Vector2 = Vector2(1.6, 1.5)
const DURA_IMPACTO: float = 1.2
const GROSOR_MURO: float = 0.3                      ## z de tam_referencia (el de MuroFuego)
const SEPARACION_PLANOS: float = 0.09                ## m entre el plano delantero y el trasero
const SUBDIV_ANCHO: int = 48
const SUBDIV_ALTO: int = 6
const COLOR_BORDE: Color = Color("C8321E")           ## rojo
const COLOR_CUERPO: Color = Color("FF8A1F")          ## naranja
const COLOR_NUCLEO: Color = Color("FFF3B0")          ## amarillo claro
const AZUL_BORDE: Color = Color("1E4FC8")
const AZUL_CUERPO: Color = Color("2FA8FF")
const AZUL_NUCLEO: Color = Color("D8F6FF")
const COLOR_LUZ: Color = Color(1.0, 0.58, 0.22)
const ENERGIA_LUZ: float = 2.4
const RANGO_LUZ: float = 6.5
const ALTURA_PUNTA: float = 1.0                      ## m a escala 1 donde nace el humo (punta típica de la llama)
const VIDA_NACER: float = 0.3
const VIDA_VIVIR: float = 1.0
const VIDA_MORIR: float = 0.5
const AMOUNT_HUMO: int = 18
const AMOUNT_CHISPAS: int = 36


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var r1: Error = _guardar_rampa(COLOR_BORDE, COLOR_CUERPO, COLOR_NUCLEO, "rampa_fuego_toon")
	var r2: Error = _guardar_rampa(AZUL_BORDE, AZUL_CUERPO, AZUL_NUCLEO, "rampa_fuego_azul")
	var e: Error = _guardar(_muro(), "MuroFuegoToon")
	var e2: Error = _guardar(_columna(), "ColumnaFuegoToon")
	var e3: Error = _guardar(_impacto(), "ImpactoFuegoToon")
	var e4: Error = _guardar(_bola(), "BolaFuegoToon")
	print("TOON: rampas=%s/%s muro=%s columna=%s impacto=%s bola=%s" % [error_string(r1), error_string(r2), error_string(e), error_string(e2), error_string(e3), error_string(e4)])
	quit(0 if (e == OK and e2 == OK and e3 == OK and e4 == OK and r1 == OK and r2 == OK) else 1)


## Rampa en escalones (interpolación constante): borde → cuerpo → núcleo, tres tonos planos.
func _guardar_rampa(borde: Color, cuerpo: Color, nucleo: Color, nombre: String) -> Error:
	var g: Gradient = Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.offsets = PackedFloat32Array([0.0, 0.13, 0.55])
	g.colors = PackedColorArray([borde, cuerpo, nucleo])
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	t.width = 64
	return ResourceSaver.save(t, DIR + nombre + ".tres")


func _muro() -> Node3D:
	var raiz: Node3D = Node3D.new()
	raiz.name = "MuroFuegoToon"
	raiz.set_script(load(SCRIPT_EFECTO))
	raiz.set("tam_referencia", Vector3(TAM_MURO.x, TAM_MURO.y, GROSOR_MURO))
	var cuerpo: Node3D = Node3D.new()
	cuerpo.name = "Cuerpo"
	raiz.add_child(cuerpo)
	var pa: MeshInstance3D = _plano("PlanoA", 0.0, 0.0)
	pa.position = Vector3(0, TAM_MURO.y * 0.5, SEPARACION_PLANOS * 0.5)
	cuerpo.add_child(pa)
	var pb: MeshInstance3D = _plano("PlanoB", 17.0, 0.35)
	pb.position = Vector3(0, TAM_MURO.y * 0.5, -SEPARACION_PLANOS * 0.5)
	cuerpo.add_child(pb)
	var humo: GPUParticles3D = _particulas("Humo", AMOUNT_HUMO, 1.4, 0.4, _mat_humo(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(TAM_MURO.x * 0.48, 0.05, 0.08),
		"direction": Vector3(0, 1, 0), "spread": 8.0, "initial_velocity_min": 0.4, "initial_velocity_max": 0.7,
		"gravity": Vector3(0, 0.1, 0), "scale_min": 0.5, "scale_max": 0.9,
		"scale_curve": _curva([[0.0, 0.35], [1.0, 1.3]])})
	humo.position = Vector3(0, ALTURA_PUNTA, 0)
	cuerpo.add_child(humo)
	var chispas: GPUParticles3D = _particulas("Chispas", AMOUNT_CHISPAS, 1.1, 0.05, _mat_chispa(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(TAM_MURO.x * 0.48, 0.1, 0.1),
		"direction": Vector3(0, 1, 0), "spread": 20.0, "initial_velocity_min": 1.3, "initial_velocity_max": 2.6,
		"gravity": Vector3(0, -0.4, 0), "scale_min": 0.7, "scale_max": 1.3,
		"scale_curve": _curva([[0.0, 1.0], [0.8, 1.0], [1.0, 0.0]])})
	chispas.position = Vector3(0, 0.35, 0)
	cuerpo.add_child(chispas)
	var luz: OmniLight3D = OmniLight3D.new()
	luz.name = "Luz"
	luz.position = Vector3(0, 0.6, 0.7)
	luz.light_color = COLOR_LUZ
	luz.light_energy = ENERGIA_LUZ
	luz.omni_range = RANGO_LUZ
	luz.shadow_enabled = false
	cuerpo.add_child(luz)
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "Anim"
	raiz.add_child(ap)
	var lib: AnimationLibrary = AnimationLibrary.new()
	ap.add_animation_library("", lib)
	_anim(lib, "nacer", VIDA_NACER, false, [
		["Cuerpo/PlanoA:material_override:shader_parameter/erosion", [[0.0, 1.0], [VIDA_NACER, 0.0]]],
		["Cuerpo/PlanoB:material_override:shader_parameter/erosion", [[0.0, 1.0], [VIDA_NACER, 0.0]]],
		["Cuerpo/Luz:light_energy", [[0.0, 0.0], [VIDA_NACER, ENERGIA_LUZ]]]])
	_anim(lib, "vivir", VIDA_VIVIR, true, [["Cuerpo/Luz:light_energy", _titileo()]])
	_anim(lib, "morir", VIDA_MORIR, false, [
		["Cuerpo/PlanoA:material_override:shader_parameter/erosion", [[0.0, 0.0], [VIDA_MORIR, 1.0]]],
		["Cuerpo/PlanoB:material_override:shader_parameter/erosion", [[0.0, 0.0], [VIDA_MORIR, 1.0]]],
		["Cuerpo/Luz:light_energy", [[0.0, ENERGIA_LUZ], [VIDA_MORIR, 0.0]]],
		["Cuerpo/Humo:emitting", [[0.0, false]]], ["Cuerpo/Chispas:emitting", [[0.0, false]]]])
	return raiz


## Columna de 1 × 4 m (ref_hoguera): dos planos con billboard bloqueado en Y (una sola lengua grande cada uno), humo en la punta, chispas, una luz.
func _columna() -> Node3D:
	var raiz: Node3D = _raiz("ColumnaFuegoToon", Vector3(TAM_COLUMNA.x, TAM_COLUMNA.y, TAM_COLUMNA.x))
	var cuerpo: Node3D = Node3D.new()
	cuerpo.name = "Cuerpo"
	raiz.add_child(cuerpo)
	var extra: Dictionary = {"billboard_y": true, "escala_ruido": 2.0, "altura_llama": 1.0, "desplazamiento": 0.25, "ancho_lengua": 0.62, "base_brillante": 0.0, "gotas": 0.5}
	var pa: MeshInstance3D = _plano("PlanoA", 3.0, 0.0, TAM_COLUMNA, extra)
	pa.position = Vector3(0, TAM_COLUMNA.y * 0.5, 0.02)
	cuerpo.add_child(pa)
	var extra_b: Dictionary = extra.duplicate()
	extra_b["ancho_lengua"] = 0.4
	extra_b["altura_llama"] = 0.75
	var pb: MeshInstance3D = _plano("PlanoB", 29.0, 0.0, TAM_COLUMNA, extra_b)
	pb.position = Vector3(0, TAM_COLUMNA.y * 0.5, -0.02)
	cuerpo.add_child(pb)
	var humo: GPUParticles3D = _particulas("Humo", 14, 1.8, 0.4, _mat_humo(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.25,
		"direction": Vector3(0, 1, 0), "spread": 10.0, "initial_velocity_min": 0.4, "initial_velocity_max": 0.8,
		"gravity": Vector3(0, 0.1, 0), "scale_min": 0.6, "scale_max": 1.0, "scale_curve": _curva([[0.0, 0.4], [1.0, 1.5]])})
	humo.position = Vector3(0, TAM_COLUMNA.y * 0.8, 0)
	cuerpo.add_child(humo)
	var chispas: GPUParticles3D = _particulas("Chispas", 24, 1.4, 0.05, _mat_chispa(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.2,
		"direction": Vector3(0, 1, 0), "spread": 25.0, "initial_velocity_min": 1.2, "initial_velocity_max": 2.4,
		"gravity": Vector3(0, -0.3, 0), "scale_min": 0.7, "scale_max": 1.3, "scale_curve": _curva([[0.0, 1.0], [0.8, 1.0], [1.0, 0.0]])})
	chispas.position = Vector3(0, 0.6, 0)
	cuerpo.add_child(chispas)
	cuerpo.add_child(_luz(Vector3(0, 0.5, 0.5)))
	var ap: AnimationPlayer = _anim_player(raiz)
	var lib: AnimationLibrary = ap.get_animation_library("")
	_anim(lib, "nacer", VIDA_NACER, false, [
		["Cuerpo/PlanoA:material_override:shader_parameter/erosion", [[0.0, 1.0], [VIDA_NACER, 0.0]]],
		["Cuerpo/PlanoB:material_override:shader_parameter/erosion", [[0.0, 1.0], [VIDA_NACER, 0.0]]],
		["Cuerpo/Luz:light_energy", [[0.0, 0.0], [VIDA_NACER, ENERGIA_LUZ]]]])
	_anim(lib, "vivir", VIDA_VIVIR, true, [["Cuerpo/Luz:light_energy", _titileo()]])
	_anim(lib, "morir", VIDA_MORIR, false, [
		["Cuerpo/PlanoA:material_override:shader_parameter/erosion", [[0.0, 0.0], [VIDA_MORIR, 1.0]]],
		["Cuerpo/PlanoB:material_override:shader_parameter/erosion", [[0.0, 0.0], [VIDA_MORIR, 1.0]]],
		["Cuerpo/Luz:light_energy", [[0.0, ENERGIA_LUZ], [VIDA_MORIR, 0.0]]],
		["Cuerpo/Humo:emitting", [[0.0, false]]], ["Cuerpo/Chispas:emitting", [[0.0, false]]]])
	return raiz


## Llamarada de la bola al caer (ref_impacto): masa de fuego en tres tonos con contorno oscuro, chispas y humo, que crece y se apaga en 1,2 s. Una luz.
func _impacto() -> Node3D:
	var raiz: Node3D = _raiz("ImpactoFuegoToon", Vector3(1.0, 1.0, 1.0))
	var cuerpo: Node3D = Node3D.new()
	cuerpo.name = "Cuerpo"
	raiz.add_child(cuerpo)
	# Masa: una bola grande de tres tonos con contorno (la explosión) y lenguas que salen por arriba.
	var nucleo: MeshInstance3D = MeshInstance3D.new()
	nucleo.name = "Nucleo"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	nucleo.mesh = q
	var mb: ShaderMaterial = ShaderMaterial.new()
	mb.shader = load(DIR + "bola_toon.gdshader")
	mb.resource_local_to_scene = true
	mb.set_shader_parameter("rampa", load(DIR + "rampa_fuego_toon.tres"))
	mb.set_shader_parameter("lobulos", 9.0)
	mb.set_shader_parameter("onda", 0.12)
	mb.set_shader_parameter("contorno", 0.6)
	nucleo.material_override = mb
	nucleo.position = Vector3(0, 0.6, 0)
	nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cuerpo.add_child(nucleo)
	var extra: Dictionary = {"billboard_y": true, "escala_ruido": 3.0, "altura_llama": 1.0, "desplazamiento": 0.5, "ancho_lengua": 0.8, "base_brillante": 0.0,
		"contorno": 0.5, "gotas": 0.0, "retroceso": 0.06}
	var pa: MeshInstance3D = _plano("PlanoA", 5.0, 0.0, Vector2(1.2, 1.6), extra)
	pa.position = Vector3(0, 0.55, -0.02)
	cuerpo.add_child(pa)
	var chispas: GPUParticles3D = _particulas("Chispas", 40, 0.9, 0.06, _mat_chispa(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.2,
		"direction": Vector3(0, 1, 0), "spread": 70.0, "initial_velocity_min": 2.0, "initial_velocity_max": 4.5,
		"gravity": Vector3(0, -3.0, 0), "scale_min": 0.8, "scale_max": 1.5, "scale_curve": _curva([[0.0, 1.0], [0.8, 1.0], [1.0, 0.0]])})
	chispas.one_shot = true
	chispas.explosiveness = 1.0
	chispas.position = Vector3(0, 0.3, 0)
	cuerpo.add_child(chispas)
	var humo: GPUParticles3D = _particulas("Humo", 8, 1.6, 0.4, _mat_humo(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.3,
		"direction": Vector3(0, 1, 0), "spread": 25.0, "initial_velocity_min": 0.5, "initial_velocity_max": 1.0,
		"gravity": Vector3(0, 0.1, 0), "scale_min": 0.7, "scale_max": 1.1, "scale_curve": _curva([[0.0, 0.4], [1.0, 1.6]])})
	humo.one_shot = true
	humo.explosiveness = 0.6
	humo.position = Vector3(0, TAM_IMPACTO.y * 0.7, 0)
	cuerpo.add_child(humo)
	cuerpo.add_child(_luz(Vector3(0, 0.6, 0.4)))
	var ap: AnimationPlayer = _anim_player(raiz)
	var lib: AnimationLibrary = ap.get_animation_library("")
	_anim(lib, "nacer", DURA_IMPACTO, false, [
		["Cuerpo/PlanoA:material_override:shader_parameter/erosion", [[0.0, 1.0], [0.12, 0.0], [DURA_IMPACTO * 0.5, 0.0], [DURA_IMPACTO, 1.0]]],
		["Cuerpo/Nucleo:material_override:shader_parameter/erosion", [[0.0, 0.6], [0.1, 0.0], [DURA_IMPACTO * 0.55, 0.0], [DURA_IMPACTO * 0.95, 1.0]]],
		["Cuerpo:scale", [[0.0, Vector3(0.5, 0.5, 0.5)], [0.2, Vector3.ONE], [DURA_IMPACTO, Vector3(1.15, 1.15, 1.15)]]],
		["Cuerpo/Luz:light_energy", [[0.0, ENERGIA_LUZ * 2.0], [DURA_IMPACTO, 0.0]]]])
	_anim(lib, "morir", 0.05, false, [])
	return raiz


## Bola de fuego (ref_hoguera / ref_impacto): núcleo en tres tonos (bola_toon), una lengua grande hacia arriba y chispas de estela. Al llegar se llama `impactar()`.
func _bola() -> Node3D:
	var raiz: Node3D = _raiz("BolaFuegoToon", Vector3(0.8, 0.8, 0.8))
	raiz.set("escena_impacto", load(DIR + "ImpactoFuegoToon.tscn"))
	var cuerpo: Node3D = Node3D.new()
	cuerpo.name = "Cuerpo"
	raiz.add_child(cuerpo)
	var nucleo: MeshInstance3D = MeshInstance3D.new()
	nucleo.name = "Nucleo"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.8, 0.8)
	nucleo.mesh = q
	var mb: ShaderMaterial = ShaderMaterial.new()
	mb.shader = load(DIR + "bola_toon.gdshader")
	mb.resource_local_to_scene = true
	mb.set_shader_parameter("rampa", load(DIR + "rampa_fuego_toon.tres"))
	nucleo.material_override = mb
	nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cuerpo.add_child(nucleo)
	var extra: Dictionary = {"billboard_y": true, "escala_ruido": 3.0, "altura_llama": 1.0, "desplazamiento": 0.3, "ancho_lengua": 0.8, "base_brillante": 0.0, "gotas": 0.0, "retroceso": 0.06}
	var llama: MeshInstance3D = _plano("Llama", 7.0, 0.0, Vector2(0.5, 1.0), extra)
	llama.position = Vector3(0, 0.5, -0.02)
	cuerpo.add_child(llama)
	var estela: GPUParticles3D = _particulas("Chispas", 24, 0.7, 0.05, _mat_chispa(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.25,
		"direction": Vector3(0, 1, 0), "spread": 40.0, "initial_velocity_min": 0.3, "initial_velocity_max": 1.0,
		"gravity": Vector3(0, -0.5, 0), "scale_min": 0.7, "scale_max": 1.3, "scale_curve": _curva([[0.0, 1.0], [0.8, 1.0], [1.0, 0.0]])})
	estela.add_to_group("estela", true)
	cuerpo.add_child(estela)
	cuerpo.add_child(_luz(Vector3(0, 0.1, 0.3)))
	var ap: AnimationPlayer = _anim_player(raiz)
	var lib: AnimationLibrary = ap.get_animation_library("")
	_anim(lib, "nacer", 0.15, false, [["Cuerpo:scale", [[0.0, Vector3(0.2, 0.2, 0.2)], [0.15, Vector3.ONE]]]])
	_anim(lib, "vivir", VIDA_VIVIR, true, [["Cuerpo/Luz:light_energy", _titileo()]])
	_anim(lib, "morir", 0.2, false, [["Cuerpo:scale", [[0.0, Vector3.ONE], [0.2, Vector3(0.05, 0.05, 0.05)]]],
		["Cuerpo/Luz:light_energy", [[0.0, ENERGIA_LUZ], [0.2, 0.0]]], ["Cuerpo/Chispas:emitting", [[0.0, false]]]])
	return raiz


func _raiz(nombre: String, tam: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = nombre
	n.set_script(load(SCRIPT_EFECTO))
	n.set("tam_referencia", tam)
	return n


func _luz(pos: Vector3) -> OmniLight3D:
	var luz: OmniLight3D = OmniLight3D.new()
	luz.name = "Luz"
	luz.position = pos
	luz.light_color = COLOR_LUZ
	luz.light_energy = ENERGIA_LUZ
	luz.omni_range = RANGO_LUZ
	luz.shadow_enabled = false
	return luz


func _anim_player(raiz: Node) -> AnimationPlayer:
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "Anim"
	raiz.add_child(ap)
	ap.add_animation_library("", AnimationLibrary.new())
	return ap


## Un fotograma de luz cada 1/FPS_TOON s con una de tres intensidades (en escalones, sin interpolar).
func _titileo() -> Array:
	var niveles: Array = [0.82, 1.0, 1.12, 0.9, 1.06, 0.95]
	var claves: Array = []
	for i in FPS_TOON:
		claves.append([float(i) / float(FPS_TOON), ENERGIA_LUZ * float(niveles[(i * 5) % niveles.size()])])
	return claves


func _plano(nombre: String, semilla: float, desfase_color: float, tam: Vector2 = TAM_MURO, extra: Dictionary = {}) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = tam
	pm.orientation = PlaneMesh.FACE_Z
	pm.subdivide_width = SUBDIV_ANCHO
	pm.subdivide_depth = SUBDIV_ALTO
	mi.mesh = pm
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(DIR + "fuego_toon.gdshader")
	m.resource_local_to_scene = true
	m.set_shader_parameter("rampa", load(DIR + "rampa_fuego_toon.tres"))
	m.set_shader_parameter("fps", float(FPS_TOON))
	m.set_shader_parameter("tam_malla", tam)
	m.set_shader_parameter("semilla", semilla)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _mat_humo() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(DIR + "humo_toon.gdshader")
	m.resource_local_to_scene = true
	return m


func _mat_chispa() -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(DIR + "chispa_toon.gdshader")
	m.resource_local_to_scene = true
	return m


func _particulas(nombre: String, cantidad: int, vida: float, tam: float, material: Material, props: Dictionary) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = nombre
	gp.amount = cantidad
	gp.lifetime = vida
	gp.local_coords = false
	gp.fixed_fps = FPS_TOON          # el estilo E: las partículas se mueven a saltos de 1/12 s
	gp.interpolate = false
	gp.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 10, 16))
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(tam, tam)
	gp.draw_pass_1 = q
	gp.material_override = material
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	for k in props:
		pm.set(k, props[k])
	gp.process_material = pm
	return gp


func _curva(puntos: Array) -> CurveTexture:
	var c: Curve = Curve.new()
	for p in puntos:
		c.add_point(Vector2(float(p[0]), float(p[1])), 0.0, 0.0)
	var t: CurveTexture = CurveTexture.new()
	t.curve = c
	return t


## pistas: [[ruta "Nodo:propiedad", [[t, valor], …]], …]; interpolación del vecino más cercano en las numéricas de la luz y el erosionado (a saltos de fotograma).
func _anim(lib: AnimationLibrary, nombre: String, largo: float, bucle: bool, pistas: Array) -> void:
	var a: Animation = Animation.new()
	a.length = largo
	a.loop_mode = Animation.LOOP_LINEAR if bucle else Animation.LOOP_NONE
	for p in pistas:
		var i: int = a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(i, NodePath(String(p[0])))
		var claves: Array = p[1]
		var es_bool: bool = claves.size() > 0 and typeof(claves[0][1]) == TYPE_BOOL
		a.value_track_set_update_mode(i, Animation.UPDATE_DISCRETE if es_bool else Animation.UPDATE_CONTINUOUS)
		if not es_bool and nombre == "vivir":
			a.track_set_interpolation_type(i, Animation.INTERPOLATION_NEAREST)
		for c in claves:
			a.track_insert_key(i, float(c[0]), c[1])
	lib.add_animation(nombre, a)


func _guardar(raiz: Node, nombre: String) -> Error:
	_adoptar(raiz, raiz)
	var ps: PackedScene = PackedScene.new()
	var e: Error = ps.pack(raiz)
	if e != OK:
		return e
	e = ResourceSaver.save(ps, DIR + nombre + ".tscn")
	raiz.free()
	return e


func _adoptar(n: Node, duenio: Node) -> void:
	for h in n.get_children():
		h.owner = duenio
		_adoptar(h, duenio)
