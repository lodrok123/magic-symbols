extends SceneTree
## CAPTURAS de la jugadora base (jugadora_base) sola y vestida (capa con capucha + túnica), en reposo, en las 6 poses de prueba de docs/PLAN_RIGGING.md §3,
## andando y corriendo, y junto a la jugadora actual (woodland_wanderer). NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_jugadora_base.gd -- <carpeta> [<secciones separadas por coma: vistas,poses,marcha,comparar,cerca,v2> [<prefijo de los ficheros>]]
## Las poses de prueba giran los huesos en el espacio del modelo (+Z delante, +X la izquierda del personaje), sin clips: se ve cómo deforma el cuerpo y cómo
## sigue la ropa (si el brazo atraviesa la capa o la túnica las piernas). Las dos prendas van con el mismo esqueleto (Pj3D.poner_ropa).

const ALTO_JUEGO: float = 1.0
const FOTOGRAMAS_ESPERA: int = 10
const CAMARA_PITCH: float = 8.0
const TAM_COMPLETO: float = 1.5
const TAM_CERCA: float = 0.7
const FRACCION_MARCHA: float = 0.25
## Poses de prueba: [nombre, [[hueso sin prefijo, eje (x, y, z), grados]...], bajar la cadera (u del modelo, 1,7 de alto)]. Los giros son en el espacio del modelo y se
## aplican en el orden dado (de la raíz a las hojas).
const POSES: Array = [
	["brazos_arriba", [["LeftArm", "z", 125.0], ["RightArm", "z", -125.0]], 0.0],
	["brazos_horizontales", [["LeftArm", "z", 60.0], ["RightArm", "z", -60.0]], 0.0],
	["sentadilla", [["LeftUpLeg", "x", -85.0], ["RightUpLeg", "x", -85.0], ["LeftLeg", "x", 105.0], ["RightLeg", "x", 105.0], ["Spine", "x", 12.0]], 0.30],
	["zancada", [["LeftUpLeg", "x", -50.0], ["RightUpLeg", "x", 30.0], ["LeftLeg", "x", 12.0], ["RightLeg", "x", 45.0],
		["LeftArm", "x", 25.0], ["RightArm", "x", -25.0]], 0.05],
	["giro_cintura", [["Spine", "y", 22.0], ["Spine1", "y", 22.0], ["Spine2", "y", 22.0]], 0.0],
	["cabeza_izquierda", [["Neck", "y", 25.0], ["Head", "y", 40.0]], 0.0],
	["cabeza_derecha", [["Neck", "y", -25.0], ["Head", "y", -40.0]], 0.0],
	["codos_doblados", [["LeftForeArm", "x", -110.0], ["RightForeArm", "x", -110.0]], 0.0],
]
const VISTAS: Array = [["frente", 0.0], ["tres_cuartos", 40.0], ["espalda", 180.0], ["lado", 90.0]]

var _carpeta: String = ""
var _camara_pitch: float = CAMARA_PITCH
## Prefijo del nombre de los ficheros (3.er argumento), p. ej. «v2_» o «v2_antes_».
var _prefijo: String = ""


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	_carpeta = a[0] if a.size() > 0 else "res://docs/capturas/jugadora_base"
	var secciones: PackedStringArray = (a[1] if a.size() > 1 else "vistas,poses,marcha,comparar,cerca").split(",")
	_prefijo = a[2] if a.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_carpeta))
	var raiz := Node3D.new()
	root.add_child(raiz)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.81, 0.91, 0.94)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.82, 0.9)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.light_energy = 1.1
	sol.shadow_enabled = true
	raiz.add_child(sol)
	var suelo := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(30, 30)
	suelo.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.55, 0.68, 0.45)
	sm.roughness = 1.0
	suelo.material_override = sm
	raiz.add_child(suelo)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	raiz.add_child(cam)
	cam.current = true
	root.size = Vector2i(900, 900)
	var pj := Pj3D.new()
	raiz.add_child(pj)
	pj.cargar("jugadora_base")
	pj.set_alto(ALTO_JUEGO)
	for i in 20:
		await process_frame
	print("INFO  prendas puestas: ", pj.ropa_puesta())
	if secciones.has("vistas"):
		for vestida in [false, true]:
			_vestir(pj, vestida)
			_pose_reposo(pj)
			await _esperar()
			for v in VISTAS:
				pj.rotation_degrees.y = float(v[1])
				await _foto(cam, Vector3(0, 0.5, 0), TAM_COMPLETO, "%s/%s_%s.png" % [_carpeta, "vestida" if vestida else "base", v[0]])
			pj.rotation_degrees.y = 0.0
	if secciones.has("poses"):
		_vestir(pj, true)
		for pose in POSES:
			_pose_reposo(pj)
			await process_frame
			_aplicar_pose(pj, pose)
			await _esperar()
			for v in VISTAS.slice(0, 2) + [VISTAS[3]]:
				pj.rotation_degrees.y = float(v[1])
				await _foto(cam, Vector3(0, 0.5, 0), TAM_COMPLETO, "%s/pose_%s_%s.png" % [_carpeta, pose[0], v[0]])
			pj.rotation_degrees.y = 0.0
		# cast: el clip de lanzar al frente, a mitad
		await _clip_congelado(pj, "cast_proyectil", 0.5)
		for v in VISTAS.slice(0, 2) + [VISTAS[3]]:
			pj.rotation_degrees.y = float(v[1])
			await _foto(cam, Vector3(0, 0.5, 0), TAM_COMPLETO, "%s/pose_cast_%s.png" % [_carpeta, v[0]])
		pj.rotation_degrees.y = 0.0
	if secciones.has("marcha"):
		_vestir(pj, true)
		for rol in ["idle", "walk", "run", "hit", "death"]:
			for fr in ([0.25, 0.75] if rol == "walk" or rol == "run" else [0.5]):
				await _clip_congelado(pj, rol, fr)
				for v in [VISTAS[0], VISTAS[1], VISTAS[3]]:
					pj.rotation_degrees.y = float(v[1])
					await _foto(cam, Vector3(0, 0.5, 0), TAM_COMPLETO, "%s/clip_%s_%d_%s.png" % [_carpeta, rol, int(fr * 100.0), v[0]])
				pj.rotation_degrees.y = 0.0
	if secciones.has("cerca"):
		_vestir(pj, true)
		_pose_reposo(pj)
		await _esperar()
		for v in [VISTAS[0], VISTAS[1], VISTAS[2], VISTAS[3]]:
			pj.rotation_degrees.y = float(v[1])
			await _foto(cam, Vector3(0, 0.82, 0), TAM_CERCA, "%s/cerca_cabeza_%s.png" % [_carpeta, v[0]])
			await _foto(cam, Vector3(0, 0.62, 0), TAM_CERCA, "%s/cerca_torso_%s.png" % [_carpeta, v[0]])
		pj.rotation_degrees.y = 0.0
		_pose_reposo(pj)
		_aplicar_pose(pj, _pose("brazos_arriba"))
		await _esperar()
		for v in [VISTAS[0], VISTAS[3]]:
			pj.rotation_degrees.y = float(v[1])
			await _foto(cam, Vector3(0, 0.78, 0), TAM_CERCA * 1.3, "%s/cerca_brazos_arriba_%s.png" % [_carpeta, v[0]])
		pj.rotation_degrees.y = 0.0
		_pose_reposo(pj)
		_aplicar_pose(pj, _pose("codos_doblados"))
		await _esperar()
		for v in [VISTAS[0], VISTAS[1], VISTAS[3]]:
			pj.rotation_degrees.y = float(v[1])
			await _foto(cam, Vector3(0, 0.6, 0), TAM_CERCA * 1.3, "%s/cerca_codos_%s.png" % [_carpeta, v[0]])
		pj.rotation_degrees.y = 0.0
	if secciones.has("v2"):
		await _captura_v2(pj, cam)
	if secciones.has("comparar"):
		pj.position = Vector3(-0.5, 0, 0)
		_vestir(pj, true)
		var elfa := Pj3D.new()
		elfa.position = Vector3(0.5, 0, 0)
		raiz.add_child(elfa)
		elfa.cargar("woodland_wanderer")
		elfa.set_alto(ALTO_JUEGO)
		for i in 10:
			await process_frame
		for pose in [["reposo", ""], ["idle", "idle"], ["andar", "walk"], ["correr", "run"]]:
			for p in [pj, elfa]:
				await _poner_pose(p as Pj3D, String(pose[1]))
			await _esperar()
			for v in [VISTAS[0], VISTAS[1], VISTAS[3]]:
				pj.rotation_degrees.y = float(v[1])
				elfa.rotation_degrees.y = float(v[1])
				await _foto(cam, Vector3(0, 0.5, 0), TAM_COMPLETO * 1.3, "%s/comparar_%s_%s.png" % [_carpeta, pose[0], v[0]])
	quit()


## Juego de capturas de la segunda pasada de ropa (docs/capturas/jugadora_base/v2_*): reposo desde cuatro lados, brazos a 90° (`brazos_horizontales`, el brazo
## en reposo cuelga a unos 31° de la vertical y se giran 60°) y a 125°, cast, andar, primer plano de la capucha y la comparativa con woodland_wanderer.
func _captura_v2(pj: Pj3D, cam: Camera3D) -> void:
	_vestir(pj, true)
	_pose_reposo(pj)
	await _esperar()
	for v in VISTAS:
		pj.rotation_degrees.y = float(v[1])
		await _foto(cam, Vector3(0, 0.5, 0), TAM_COMPLETO, "%s/reposo_%s.png" % [_carpeta, v[0]])
	pj.rotation_degrees.y = 0.0
	for par in [["brazos_horizontales", "brazos90"], ["brazos_arriba", "brazos125"]]:
		_pose_reposo(pj)
		await process_frame
		_aplicar_pose(pj, _pose(String(par[0])))
		await _esperar()
		for v in [VISTAS[0], VISTAS[1], VISTAS[3]]:
			pj.rotation_degrees.y = float(v[1])
			await _foto(cam, Vector3(0, 0.62, 0), TAM_COMPLETO * 0.8, "%s/%s_%s.png" % [_carpeta, par[1], v[0]])
	pj.rotation_degrees.y = 0.0
	await _clip_congelado(pj, "cast_proyectil", 0.5)
	for v in [VISTAS[0], VISTAS[1], VISTAS[3]]:
		pj.rotation_degrees.y = float(v[1])
		await _foto(cam, Vector3(0, 0.5, 0), TAM_COMPLETO, "%s/cast_%s.png" % [_carpeta, v[0]])
	await _clip_congelado(pj, "walk", 0.25)
	for v in [VISTAS[0], VISTAS[1], VISTAS[3]]:
		pj.rotation_degrees.y = float(v[1])
		await _foto(cam, Vector3(0, 0.5, 0), TAM_COMPLETO, "%s/andar_%s.png" % [_carpeta, v[0]])
	_pose_reposo(pj)
	await _esperar()
	for v in VISTAS:
		pj.rotation_degrees.y = float(v[1])
		await _foto(cam, Vector3(0, 0.82, 0), TAM_CERCA, "%s/capucha_%s.png" % [_carpeta, v[0]])
	pj.rotation_degrees.y = 0.0


func _pose(nombre: String) -> Array:
	for p in POSES:
		if String(p[0]) == nombre:
			return p
	return POSES[0]


func _vestir(pj: Pj3D, si: bool) -> void:
	for prenda in ["tunica", "capa_capucha"]:
		if si:
			pj.poner_ropa(prenda)
		else:
			pj.quitar_ropa(prenda)


func _esperar() -> void:
	for _i in FOTOGRAMAS_ESPERA:
		await process_frame


func _esqueleto(pj: Pj3D) -> Skeleton3D:
	return pj.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D


## Reposo del GLB sin clips ni árbol.
func _pose_reposo(pj: Pj3D) -> void:
	if pj._arbol != null:
		pj._arbol.active = false
	pj._ap.active = false
	pj._ap.stop()
	if pj.proporcion != null:
		pj.proporcion.set_process(false)
	_esqueleto(pj).reset_bone_poses()


## Gira los huesos de `pose` en el espacio del modelo. Cada giro se aplica sobre la pose global actual del hueso y se vuelve a pasar a local.
func _aplicar_pose(pj: Pj3D, pose: Array) -> void:
	var sk: Skeleton3D = _esqueleto(pj)
	for g in (pose[1] as Array):
		var i: int = sk.find_bone("mixamorig_" + String(g[0]))
		if i < 0:
			continue
		var eje: Vector3 = {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}[String(g[1])]
		var q := Quaternion(eje, deg_to_rad(float(g[2])))
		var actual: Basis = sk.get_bone_global_pose(i).basis
		var padre: int = sk.get_bone_parent(i)
		var padre_b: Basis = sk.get_bone_global_pose(padre).basis if padre >= 0 else Basis.IDENTITY
		var local: Basis = padre_b.inverse() * Basis(q) * actual
		sk.set_bone_pose_rotation(i, local.orthonormalized().get_rotation_quaternion())
	var h: int = sk.find_bone("mixamorig_Hips")
	if float(pose[2]) > 0.0:
		sk.set_bone_pose_position(h, sk.get_bone_rest(h).origin - Vector3(0, float(pose[2]) * 0.01, 0))


## Congela el clip del rol en `fraccion` de su duración.
func _clip_congelado(pj: Pj3D, rol: String, fraccion: float) -> void:
	await _poner_pose(pj, rol, fraccion)
	await _esperar()


func _poner_pose(p: Pj3D, rol: String, fraccion: float = FRACCION_MARCHA) -> void:
	var ap: AnimationPlayer = p._ap
	if rol == "":
		_pose_reposo(p)
		return
	if p._arbol != null:
		p._arbol.active = false
	var clip: String = p.clip_de(rol)
	ap.active = true
	ap.play(clip)
	ap.seek(ap.get_animation(clip).length * fraccion, true)
	ap.pause()
	await process_frame


func _foto(cam: Camera3D, foco: Vector3, tam: float, ruta: String) -> void:
	var dir := Vector3(0.0, -sin(deg_to_rad(_camara_pitch)), -cos(deg_to_rad(_camara_pitch)))   # mira hacia -Z desde +Z (los modelos miran a +Z), algo picado
	cam.size = tam
	cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 20.0)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	ruta = ruta.get_base_dir() + "/" + _prefijo + ruta.get_file()
	img.save_png(ProjectSettings.globalize_path(ruta))
	print("captura ", ruta)
