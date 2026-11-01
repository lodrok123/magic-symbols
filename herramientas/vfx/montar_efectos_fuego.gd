extends SceneTree

## MONTA LAS ESCENAS DE EFECTO DE FUEGO (1/11, Dirección, comparativa de VFX §1.3): escribe presentacion/vfx/efectos/ImpactoFuego.tscn, BolaFuego.tscn,
## MuroFuego.tscn y ColumnaFuego.tscn como escenas NORMALES de Godot (partículas, mallas, luces, calor y un AnimationPlayer con nacer / vivir / morir),
## para que a partir de aquí se retoquen EN EL EDITOR. Este script es la primera versión y la documentación de cómo están hechas; si se vuelve a correr
## PISA lo que se haya retocado a mano en el editor (por eso no lo corre ninguna prueba).
##   godot --headless --path . --script res://herramientas/vfx/montar_efectos_fuego.gd
## Materiales: los cuatro shaders de presentacion/vfx/shaders con el atlas de Blender (fuego_8x8 / humo_8x8) y las rampas de presentacion/vfx/atlas.
## Presupuesto por efecto (el mismo que VfxEstado3D / LabVfx3D): ≤ 2 luces y ≤ 400 partículas.

const DIR: String = "res://presentacion/vfx/efectos/"
const SH: String = "res://presentacion/vfx/shaders/"
const AT: String = "res://presentacion/vfx/atlas/"
const SCRIPT_EFECTO: String = "res://presentacion/vfx/efectos/efecto_vfx_3d.gd"
const COLOR_LUZ: Color = Color(1.0, 0.55, 0.2)
const COLOR_BRASA: Color = Color(1.0, 0.6, 0.15)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var e1: Error = _guardar(_impacto(), "ImpactoFuego")
	var e2: Error = _guardar(_bola(), "BolaFuego")
	var e3: Error = _guardar(_muro(), "MuroFuego")
	var e4: Error = _guardar(_columna(), "ColumnaFuego")
	print("ESCENAS: impacto=%s bola=%s muro=%s columna=%s" % [error_string(e1), error_string(e2), error_string(e3), error_string(e4)])
	quit(0 if (e1 == OK and e2 == OK and e3 == OK and e4 == OK) else 1)


# ---------------------------------------------------------------- escenas ----------------------------------------------------------------

## Llamarada de 1 s al caer la bola: cono de llamas hacia arriba, chispas, humo, anillo de calor que se abre, luz que se apaga y quemado 3 s en el suelo.
func _impacto() -> Node3D:
	var raiz: Node3D = _raiz("ImpactoFuego", Vector3(1.0, 1.0, 1.0))
	var llamas: GPUParticles3D = _particulas("Llamas", 40, 0.8, 0.9, _mat_flipbook("fuego", "rampa_fuego", 1.0, {"erosion_max": 0.98, "brillo": 1.8}), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.2,
		"direction": Vector3(0, 1, 0), "spread": 45.0, "initial_velocity_min": 2.0, "initial_velocity_max": 5.0,
		"gravity": Vector3(0, 1.0, 0), "damping_min": 2.0, "damping_max": 3.0, "scale_min": 0.8, "scale_max": 1.3,
		"angle_min": 0.0, "angle_max": 360.0, "angular_velocity_min": -90.0, "angular_velocity_max": 90.0,
		"anim_speed_min": 1.0, "anim_speed_max": 1.0, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"scale_curve": _curva([[0.0, 0.6], [0.3, 1.0], [1.0, 0.2]])})
	llamas.one_shot = true
	llamas.explosiveness = 0.95
	raiz.add_child(llamas)
	var chispas: GPUParticles3D = _particulas("Chispas", 40, 1.0, 0.06, _mat_brasa(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.15,
		"direction": Vector3(0, 1, 0), "spread": 60.0, "initial_velocity_min": 3.0, "initial_velocity_max": 7.0,
		"gravity": Vector3(0, -6.0, 0), "scale_curve": _curva([[0.0, 1.0], [1.0, 0.0]]), "color": COLOR_BRASA})
	chispas.one_shot = true
	chispas.explosiveness = 1.0
	raiz.add_child(chispas)
	var humo: GPUParticles3D = _particulas("Humo", 10, 1.6, 1.1, _mat_flipbook("humo", "rampa_humo", 0.0, {"brillo": 0.8, "erosion_min": 0.3, "erosion_max": 0.9, "color_por_alfa": 1.0}), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.25,
		"direction": Vector3(0, 1, 0), "spread": 30.0, "initial_velocity_min": 1.0, "initial_velocity_max": 2.0,
		"gravity": Vector3(0, 0.6, 0), "damping_min": 1.0, "damping_max": 1.5, "scale_min": 0.8, "scale_max": 1.2,
		"anim_speed_min": 0.6, "anim_speed_max": 0.6, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"scale_curve": _curva([[0.0, 0.5], [1.0, 1.6]]), "color_ramp": _rampa_alfa([[0.0, 0.0], [0.15, 0.35], [1.0, 0.0]])})
	humo.one_shot = true
	humo.explosiveness = 0.9
	raiz.add_child(humo)
	var anillo: MeshInstance3D = _quad("Anillo", Vector2(1.0, 1.0), _mat_calor(false, 0, {"fuerza": 0.06, "borde": 0.5}))
	anillo.position = Vector3(0, 0.05, 0)
	anillo.rotation_degrees = Vector3(-90, 0, 0)
	raiz.add_child(anillo)
	raiz.add_child(_luz("Luz", Vector3(0, 0.4, 0), 4.0, 5.0))
	var quemado: Decal = Decal.new()
	quemado.name = "Quemado"
	quemado.size = Vector3(1.6, 1.0, 1.6)
	quemado.texture_albedo = load("res://presentacion/vfx/grietas_impacto.png")
	quemado.modulate = Color(0.12, 0.08, 0.05)
	quemado.albedo_mix = 1.0
	quemado.position = Vector3(0, 0.2, 0)
	raiz.add_child(quemado)
	var ap: AnimationPlayer = _anim_player(raiz)
	_anim(ap, "nacer", 3.2, false, [
		["Anillo:scale", [[0.0, Vector3(0.5, 0.5, 0.5)], [0.6, Vector3(3.5, 3.5, 3.5)]]],
		["Anillo:material_override:shader_parameter/intensidad", [[0.0, 1.0], [0.6, 0.0]]],
		["Luz:light_energy", [[0.0, 4.0], [0.6, 0.0]]],
		["Quemado:albedo_mix", [[0.0, 1.0], [1.2, 1.0], [3.2, 0.0]]]])
	_anim(ap, "morir", 0.05, false, [])
	return raiz


## Proyectil: núcleo con fresnel, llamas que se quedan atrás (estela por el movimiento), chispas, humo, luz que parpadea y calor. Al llegar, ImpactoFuego.
func _bola() -> Node3D:
	var raiz: Node3D = _raiz("BolaFuego", Vector3(0.8, 0.8, 0.8))
	raiz.set("escena_impacto", load(DIR + "ImpactoFuego.tscn"))
	var nucleo: MeshInstance3D = MeshInstance3D.new()
	nucleo.name = "Nucleo"
	var esf: SphereMesh = SphereMesh.new()
	esf.radius = 0.28
	esf.height = 0.56
	nucleo.mesh = esf
	nucleo.material_override = _sm("nucleo_fresnel", {"ruido": load(AT + "ruido_perlin.tres")})
	raiz.add_child(nucleo)
	var llamas: GPUParticles3D = _particulas("Llamas", 24, 0.5, 0.6, _mat_flipbook("fuego", "rampa_fuego", 1.0, {}), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.15,
		"direction": Vector3(0, 1, 0), "spread": 180.0, "initial_velocity_min": 0.3, "initial_velocity_max": 0.8,
		"gravity": Vector3(0, 0.8, 0), "scale_min": 0.7, "scale_max": 1.0, "angle_min": 0.0, "angle_max": 360.0,
		"angular_velocity_min": -60.0, "angular_velocity_max": 60.0,
		"anim_speed_min": 1.0, "anim_speed_max": 1.0, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"scale_curve": _curva([[0.0, 1.0], [1.0, 0.1]])})
	llamas.local_coords = true          # pegadas a la bola: con coordenadas de mundo se quedaban 4 m atrás a 8 m/s
	raiz.add_child(llamas)
	var chispas: GPUParticles3D = _particulas("Chispas", 30, 0.8, 0.07, _mat_brasa(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.2,
		"direction": Vector3(0, 1, 0), "spread": 180.0, "initial_velocity_min": 1.0, "initial_velocity_max": 2.5,
		"gravity": Vector3(0, -3.0, 0), "scale_curve": _curva([[0.0, 1.0], [1.0, 0.0]]), "color": COLOR_BRASA})
	chispas.add_to_group("estela", true)
	raiz.add_child(chispas)
	var humo: GPUParticles3D = _particulas("Humo", 8, 1.2, 0.9, _mat_flipbook("humo", "rampa_humo", 0.0, {"brillo": 0.8, "erosion_min": 0.3, "color_por_alfa": 1.0}), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.1,
		"direction": Vector3(0, 1, 0), "spread": 40.0, "initial_velocity_min": 0.2, "initial_velocity_max": 0.5,
		"gravity": Vector3(0, 0.5, 0), "anim_speed_min": 0.8, "anim_speed_max": 0.8, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"scale_curve": _curva([[0.0, 0.6], [1.0, 1.4]]), "color_ramp": _rampa_alfa([[0.0, 0.0], [0.2, 0.3], [1.0, 0.0]])})
	humo.add_to_group("estela", true)
	raiz.add_child(humo)
	raiz.add_child(_luz("Luz", Vector3.ZERO, 2.0, 4.0))
	var calor: MeshInstance3D = _quad("Calor", Vector2(1.0, 1.0), _mat_calor(true, 0, {}))
	raiz.add_child(calor)
	var ap: AnimationPlayer = _anim_player(raiz)
	_anim(ap, "nacer", 0.15, false, [["Nucleo:scale", [[0.0, Vector3(0.2, 0.2, 0.2)], [0.15, Vector3.ONE]]]])
	_anim(ap, "vivir", 0.3, true, [["Luz:light_energy", [[0.0, 1.7], [0.15, 2.3], [0.3, 1.7]]]])
	_anim(ap, "morir", 0.3, false, [
		["Nucleo:material_override:shader_parameter/intensidad", [[0.0, 1.0], [0.3, 0.0]]],
		["Luz:light_energy", [[0.0, 2.0], [0.3, 0.0]]],
		["Llamas:emitting", [[0.0, false]]], ["Chispas:emitting", [[0.0, false]]], ["Humo:emitting", [[0.0, false]]],
		["Calor:material_override:shader_parameter/intensidad", [[0.0, 1.0], [0.3, 0.0]]]])
	return raiz


## Muro de 6,9 × 1,5 m: tres planos con scroll + erosión (centro alto, delante y detrás más bajos), llamas, brasas, humo, dos luces y calor.
func _muro() -> Node3D:
	var raiz: Node3D = _raiz("MuroFuego", Vector3(6.9, 1.5, 0.3))
	var cuerpo: Node3D = Node3D.new()
	cuerpo.name = "Cuerpo"
	raiz.add_child(cuerpo)
	var pa: MeshInstance3D = _quad("PlanoA", Vector2(6.9, 1.5), _mat_scroll({"repeticion_x": 4.0, "altura_llama": 1.6, "brillo": 0.55, "base": 0.04}))
	pa.position = Vector3(0, 0.75, 0)
	cuerpo.add_child(pa)
	var pb: MeshInstance3D = _quad("PlanoB", Vector2(6.9, 1.1), _mat_scroll({"repeticion_x": 3.0, "altura_llama": 1.3, "velocidad_a": 0.7, "escala_b": Vector2(1.7, 0.9), "brillo": 0.4, "base": 0.04}))
	pb.position = Vector3(0, 0.55, 0.12)
	cuerpo.add_child(pb)
	var pc: MeshInstance3D = _quad("PlanoC", Vector2(6.9, 1.1), _mat_scroll({"repeticion_x": 3.5, "altura_llama": 1.3, "velocidad_a": 0.45, "escala_a": Vector2(1.3, 0.6), "brillo": 0.4, "base": 0.04}))
	pc.position = Vector3(0, 0.55, -0.12)
	cuerpo.add_child(pc)
	var llamas: GPUParticles3D = _particulas("Llamas", 60, 0.7, 0.7, _mat_flipbook("fuego", "rampa_fuego", 1.0, {}), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(3.3, 0.05, 0.12),
		"direction": Vector3(0, 1, 0), "spread": 10.0, "initial_velocity_min": 1.0, "initial_velocity_max": 1.6,
		"gravity": Vector3(0, 0.5, 0), "scale_min": 0.6, "scale_max": 0.9, "angle_min": -20.0, "angle_max": 20.0,
		"angular_velocity_min": -30.0, "angular_velocity_max": 30.0,
		"anim_speed_min": 1.0, "anim_speed_max": 1.0, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"scale_curve": _curva([[0.0, 0.7], [0.3, 1.0], [1.0, 0.2]])})
	cuerpo.add_child(llamas)
	var brasas: GPUParticles3D = _particulas("Brasas", 40, 1.2, 0.05, _mat_brasa(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(3.4, 0.1, 0.15),
		"direction": Vector3(0, 1, 0), "spread": 25.0, "initial_velocity_min": 1.0, "initial_velocity_max": 2.5,
		"gravity": Vector3(0, -0.5, 0), "scale_curve": _curva([[0.0, 1.0], [1.0, 0.0]]), "color": COLOR_BRASA})
	cuerpo.add_child(brasas)
	var humo: GPUParticles3D = _particulas("Humo", 12, 1.4, 0.9, _mat_flipbook("humo", "rampa_humo", 0.0, {"brillo": 0.8, "erosion_min": 0.3, "color_por_alfa": 1.0}), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX, "emission_box_extents": Vector3(3.2, 0.1, 0.1),
		"direction": Vector3(0, 1, 0), "spread": 15.0, "initial_velocity_min": 0.6, "initial_velocity_max": 1.0,
		"gravity": Vector3(0, 0.3, 0), "anim_speed_min": 0.7, "anim_speed_max": 0.7, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"scale_curve": _curva([[0.0, 0.5], [1.0, 1.5]]), "color_ramp": _rampa_alfa([[0.0, 0.0], [0.2, 0.15], [1.0, 0.0]])})
	humo.position = Vector3(0, 1.0, 0)
	cuerpo.add_child(humo)
	cuerpo.add_child(_luz("Luz1", Vector3(-1.7, 0.8, 0), 2.0, 4.0))
	cuerpo.add_child(_luz("Luz2", Vector3(1.7, 0.8, 0), 2.0, 4.0))
	var calor: MeshInstance3D = _quad("Calor", Vector2(7.0, 1.8), _mat_calor(false, 0, {"borde": 0.6, "fuerza": 0.01}))
	calor.position = Vector3(0, 1.0, 0.2)
	cuerpo.add_child(calor)
	var ap: AnimationPlayer = _anim_player(raiz)
	_anim(ap, "nacer", 0.3, false, [
		["Cuerpo:scale", [[0.0, Vector3(1.0, 0.02, 1.0)], [0.3, Vector3.ONE]]],
		["Cuerpo/Luz1:light_energy", [[0.0, 0.0], [0.3, 2.0]]], ["Cuerpo/Luz2:light_energy", [[0.0, 0.0], [0.3, 2.0]]]])
	_anim(ap, "morir", 0.5, false, [
		["Cuerpo/PlanoA:material_override:shader_parameter/erosion", [[0.0, 0.0], [0.5, 1.0]]],
		["Cuerpo/PlanoB:material_override:shader_parameter/erosion", [[0.0, 0.0], [0.5, 1.0]]],
		["Cuerpo/PlanoC:material_override:shader_parameter/erosion", [[0.0, 0.0], [0.5, 1.0]]],
		["Cuerpo/Luz1:light_energy", [[0.0, 2.0], [0.5, 0.0]]], ["Cuerpo/Luz2:light_energy", [[0.0, 2.0], [0.5, 0.0]]],
		["Cuerpo/Llamas:emitting", [[0.0, false]]], ["Cuerpo/Brasas:emitting", [[0.0, false]]], ["Cuerpo/Humo:emitting", [[0.0, false]]],
		["Cuerpo/Calor:material_override:shader_parameter/intensidad", [[0.0, 1.0], [0.5, 0.0]]]])
	return raiz


## Columna de 1 m de diámetro y 4 m de alto: dos cilindros con scroll + erosión girando al contrario, llamas desde el disco de la base, chispas, humo arriba, dos luces y calor envolvente.
func _columna() -> Node3D:
	var raiz: Node3D = _raiz("ColumnaFuego", Vector3(1.0, 4.0, 1.0))
	raiz.set("giros", {"Cuerpo/CilindroInt": 0.6, "Cuerpo/CilindroExt": -0.4})
	var cuerpo: Node3D = Node3D.new()
	cuerpo.name = "Cuerpo"
	raiz.add_child(cuerpo)
	var ci: MeshInstance3D = _cilindro("CilindroInt", 0.38, 0.45, 4.0, _mat_scroll({"uv_rango": Vector2(0.0, 0.5), "altura_llama": 1.2, "brillo": 0.5, "escala_a": Vector2(2.0, 1.0), "escala_b": Vector2(3.0, 1.6), "bordes_x": 0.0, "silueta": 1.2, "base": 0.08, "umbral": 0.4, "ruido_base": 0.2}))
	ci.position = Vector3(0, 2.0, 0)
	cuerpo.add_child(ci)
	var ce: MeshInstance3D = _cilindro("CilindroExt", 0.5, 0.56, 4.0, _mat_scroll({"uv_rango": Vector2(0.0, 0.5), "altura_llama": 1.0, "brillo": 0.3, "aditivo": 0.35, "umbral": 0.45, "escala_a": Vector2(1.6, 0.8), "velocidad_a": 0.4, "bordes_x": 0.0, "silueta": 1.5, "base": 0.1, "ruido_base": 0.15}))
	ce.position = Vector3(0, 2.0, 0)
	cuerpo.add_child(ce)
	var llamas: GPUParticles3D = _particulas("Llamas", 50, 1.0, 0.8, _mat_flipbook("fuego", "rampa_fuego", 1.0, {}), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_RING, "emission_ring_axis": Vector3(0, 1, 0),
		"emission_ring_radius": 0.45, "emission_ring_inner_radius": 0.1, "emission_ring_height": 0.1,
		"direction": Vector3(0, 1, 0), "spread": 8.0, "initial_velocity_min": 2.5, "initial_velocity_max": 3.5,
		"gravity": Vector3(0, 0.5, 0), "scale_min": 0.7, "scale_max": 1.0, "angle_min": -15.0, "angle_max": 15.0,
		"angular_velocity_min": -40.0, "angular_velocity_max": 40.0,
		"anim_speed_min": 1.0, "anim_speed_max": 1.0, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"scale_curve": _curva([[0.0, 0.7], [0.4, 1.0], [1.0, 0.3]])})
	cuerpo.add_child(llamas)
	var chispas: GPUParticles3D = _particulas("Chispas", 30, 1.2, 0.05, _mat_brasa(), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_RING, "emission_ring_axis": Vector3(0, 1, 0),
		"emission_ring_radius": 0.5, "emission_ring_inner_radius": 0.2, "emission_ring_height": 0.2,
		"direction": Vector3(0, 1, 0), "spread": 20.0, "initial_velocity_min": 3.0, "initial_velocity_max": 5.0,
		"gravity": Vector3(0, -1.0, 0), "scale_curve": _curva([[0.0, 1.0], [1.0, 0.0]]), "color": COLOR_BRASA})
	cuerpo.add_child(chispas)
	var humo: GPUParticles3D = _particulas("Humo", 10, 1.6, 1.2, _mat_flipbook("humo", "rampa_humo", 0.0, {"brillo": 0.8, "erosion_min": 0.3, "color_por_alfa": 1.0}), {
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_SPHERE, "emission_sphere_radius": 0.3,
		"direction": Vector3(0, 1, 0), "spread": 20.0, "initial_velocity_min": 0.8, "initial_velocity_max": 1.2,
		"gravity": Vector3(0, 0.3, 0), "anim_speed_min": 0.7, "anim_speed_max": 0.7, "anim_offset_min": 0.0, "anim_offset_max": 1.0,
		"scale_curve": _curva([[0.0, 0.5], [1.0, 1.6]]), "color_ramp": _rampa_alfa([[0.0, 0.0], [0.2, 0.15], [1.0, 0.0]])})
	humo.position = Vector3(0, 3.8, 0)
	cuerpo.add_child(humo)
	cuerpo.add_child(_luz("Luz1", Vector3(0, 1.0, 0), 3.0, 6.0))
	cuerpo.add_child(_luz("Luz2", Vector3(0, 3.0, 0), 1.5, 4.0))
	var calor: MeshInstance3D = _cilindro("Calor", 0.7, 0.7, 4.6, _mat_calor(false, 1, {"borde": 0.25, "fuerza": 0.008}))
	calor.position = Vector3(0, 2.2, 0)
	cuerpo.add_child(calor)
	var ap: AnimationPlayer = _anim_player(raiz)
	_anim(ap, "nacer", 0.3, false, [
		["Cuerpo:scale", [[0.0, Vector3(1.0, 0.02, 1.0)], [0.3, Vector3.ONE]]],
		["Cuerpo/Luz1:light_energy", [[0.0, 0.0], [0.3, 3.0]]], ["Cuerpo/Luz2:light_energy", [[0.0, 0.0], [0.3, 1.5]]]])
	_anim(ap, "morir", 0.5, false, [
		["Cuerpo/CilindroInt:material_override:shader_parameter/erosion", [[0.0, 0.0], [0.5, 1.0]]],
		["Cuerpo/CilindroExt:material_override:shader_parameter/erosion", [[0.0, 0.0], [0.5, 1.0]]],
		["Cuerpo/Luz1:light_energy", [[0.0, 3.0], [0.5, 0.0]]], ["Cuerpo/Luz2:light_energy", [[0.0, 1.5], [0.5, 0.0]]],
		["Cuerpo/Llamas:emitting", [[0.0, false]]], ["Cuerpo/Chispas:emitting", [[0.0, false]]], ["Cuerpo/Humo:emitting", [[0.0, false]]],
		["Cuerpo/Calor:material_override:shader_parameter/intensidad", [[0.0, 1.0], [0.5, 0.0]]]])
	return raiz


# ---------------------------------------------------------------- piezas ----------------------------------------------------------------

func _raiz(nombre: String, tam: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = nombre
	n.set_script(load(SCRIPT_EFECTO))
	n.set("tam_referencia", tam)
	return n


func _sm(shader: String, params: Dictionary) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(SH + shader + ".gdshader")
	m.resource_local_to_scene = true
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


func _mat_flipbook(atlas: String, rampa: String, aditivo: float, extra: Dictionary) -> ShaderMaterial:
	var p: Dictionary = {"atlas": load(AT + atlas + "_8x8.png"), "columnas": 8, "filas": 8, "ruido": load(AT + "ruido_perlin.tres"),
		"rampa": load(AT + rampa + ".tres"), "aditivo": aditivo}
	p.merge(extra, true)
	return _sm("flipbook_erosion", p)


func _mat_scroll(extra: Dictionary) -> ShaderMaterial:
	var p: Dictionary = {"ruido_a": load(AT + "ruido_perlin.tres"), "ruido_b": load(AT + "ruido_celular.tres"), "rampa": load(AT + "rampa_fuego.tres")}
	p.merge(extra, true)
	return _sm("scroll_erosion", p)


func _mat_calor(billboard: bool, mascara: int, extra: Dictionary) -> ShaderMaterial:
	var p: Dictionary = {"normales": load(AT + "normales_ruido.tres"), "billboard": billboard, "mascara": mascara}
	p.merge(extra, true)
	var m: ShaderMaterial = _sm("calor", p)
	m.render_priority = -1          # se dibuja antes que las llamas: lo que distorsiona es la pasada opaca y las llamas van encima
	return m


## Brasa: billboard aditivo con la textura brasa.png que ya tenía el proyecto.
func _mat_brasa() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load("res://presentacion/vfx/brasa.png")
	m.albedo_color = Color(1.0, 0.8, 0.4)
	m.disable_receive_shadows = true
	return m


func _particulas(nombre: String, cantidad: int, vida: float, tam: float, material: Material, props: Dictionary) -> GPUParticles3D:
	var gp: GPUParticles3D = GPUParticles3D.new()
	gp.name = nombre
	gp.amount = cantidad
	gp.lifetime = vida
	gp.local_coords = false
	gp.fixed_fps = 30
	gp.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 10, 16))
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(tam, tam)
	gp.draw_pass_1 = q
	gp.material_override = material
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	for k in props:
		pm.set(k, props[k])
	gp.process_material = pm
	return gp


func _quad(nombre: String, tam: Vector2, material: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	var q: QuadMesh = QuadMesh.new()
	q.size = tam
	mi.mesh = q
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _cilindro(nombre: String, r_arriba: float, r_abajo: float, alto: float, material: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nombre
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = r_arriba
	c.bottom_radius = r_abajo
	c.height = alto
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 32
	c.rings = 8
	mi.mesh = c
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _luz(nombre: String, pos: Vector3, energia: float, rango: float) -> OmniLight3D:
	var l: OmniLight3D = OmniLight3D.new()
	l.name = nombre
	l.position = pos
	l.light_color = COLOR_LUZ
	l.light_energy = energia
	l.omni_range = rango
	l.shadow_enabled = false
	return l


func _curva(puntos: Array) -> CurveTexture:
	var c: Curve = Curve.new()
	for p in puntos:
		c.add_point(Vector2(float(p[0]), float(p[1])))
	var t: CurveTexture = CurveTexture.new()
	t.curve = c
	return t


## Rampa de color blanca con el alfa dado por [[pos, alfa], …] (para el fundido de humo).
func _rampa_alfa(puntos: Array) -> GradientTexture1D:
	var g: Gradient = Gradient.new()
	var offs: PackedFloat32Array = PackedFloat32Array()
	var cols: PackedColorArray = PackedColorArray()
	for p in puntos:
		offs.append(float(p[0]))
		cols.append(Color(1, 1, 1, float(p[1])))
	g.offsets = offs
	g.colors = cols
	var t: GradientTexture1D = GradientTexture1D.new()
	t.gradient = g
	return t


func _anim_player(raiz: Node) -> AnimationPlayer:
	var ap: AnimationPlayer = AnimationPlayer.new()
	ap.name = "Anim"
	raiz.add_child(ap)
	var lib: AnimationLibrary = AnimationLibrary.new()
	ap.add_animation_library("", lib)
	return ap


## pistas: [[ruta "Nodo:propiedad", [[t, valor], …]], …]
func _anim(ap: AnimationPlayer, nombre: String, largo: float, bucle: bool, pistas: Array) -> void:
	var a: Animation = Animation.new()
	a.length = largo
	a.loop_mode = Animation.LOOP_LINEAR if bucle else Animation.LOOP_NONE
	for p in pistas:
		var i: int = a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(i, NodePath(String(p[0])))
		var claves: Array = p[1]
		a.value_track_set_update_mode(i, Animation.UPDATE_DISCRETE if (claves.size() > 0 and typeof(claves[0][1]) == TYPE_BOOL) else Animation.UPDATE_CONTINUOUS)
		for c in claves:
			a.track_insert_key(i, float(c[0]), c[1])
	(ap.get_animation_library("") as AnimationLibrary).add_animation(nombre, a)


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
