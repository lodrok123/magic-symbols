extends SceneTree

## HOJA DE CONTACTO de las rocas estilizadas (pack LeLu, 4/11): las 5 rocas y las 5 piedras de `arte/meshy/piezas/` a la medida del juego (`Pieza3D.crear_visual` + `MEDIDA`),
## cada una junto a una jugadora de 1 u (`jugadora_base`). NECESITA VENTANA:
##   godot --path . --resolution 1700x900 --script res://herramientas/captura_rocas_estilizadas.gd -- docs/capturas/rocas_estilizadas/hoja_rocas.png
## No es una prueba: se mira a ojo.

## Tres filas: musgo (bosque), neutra (cueva), magma (lava); en cada una las 5 rocas y las 5 piedras.
const FILAS: Array = [
	["musgo", "roca_est_musgo_0", "roca_est_musgo_1", "roca_est_musgo_2", "roca_est_musgo_3", "roca_est_musgo_4", "piedra_est_musgo_0", "piedra_est_musgo_1", "piedra_est_musgo_2", "piedra_est_musgo_3", "piedra_est_musgo_4"],
	["neutra", "roca_est_0", "roca_est_1", "roca_est_2", "roca_est_3", "roca_est_4", "piedra_est_0", "piedra_est_1", "piedra_est_2", "piedra_est_3", "piedra_est_4"],
	["magma", "roca_est_magma_0", "roca_est_magma_1", "roca_est_magma_2", "roca_est_magma_3", "roca_est_magma_4", "piedra_est_magma_0", "piedra_est_magma_1", "piedra_est_magma_2", "piedra_est_magma_3", "piedra_est_magma_4"],
]
const SEP: float = 1.55


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var salida: String = a[0] if a.size() > 0 else "res://docs/capturas/rocas_estilizadas/hoja_rocas.png"
	if not salida.is_absolute_path():
		salida = ProjectSettings.globalize_path("res://" + salida)
	DirAccess.make_dir_recursive_absolute(salida.get_base_dir())
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.62, 0.35)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.85)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	luz.shadow_enabled = true
	root.add_child(luz)
	var suelo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60.0, 60.0)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.42, 0.62, 0.28)
	pm.material = sm
	suelo.mesh = pm
	root.add_child(suelo)
	for f in FILAS.size():
		var z: float = float(f) * 2.3
		var pj := Pj3D.new()
		root.add_child(pj)
		pj.cargar("jugadora_base")
		pj.set_alto(1.0)
		pj.position = Vector3(-1.4, 0.0, z)
		var ids: Array = (FILAS[f] as Array).slice(1)
		for i in ids.size():
			var id: String = ids[i]
			var n: Node3D = Pieza3D.crear_visual(id)
			if n == null:
				print("FALLO sin modelo ", id)
				continue
			root.add_child(n)
			n.position = Vector3(float(i) * SEP, 0.0, z)
			n.rotation.y = deg_to_rad(-25.0)
			var et := Label3D.new()
			et.text = id
			et.font_size = 44
			et.pixel_size = 0.0022
			et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			et.no_depth_test = true
			et.modulate = Color(1, 1, 1)
			et.outline_size = 10
			root.add_child(et)
			et.position = Vector3(float(i) * SEP, -0.02, z + 0.75)
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.look_at_from_position(Vector3(6.6, 8.5, 9.0), Vector3(6.6, 0.2, 2.0))
	for _i in 20:
		await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(salida)
	print("CAPTURA ", salida, " ", img.get_width(), "x", img.get_height())
	quit()
