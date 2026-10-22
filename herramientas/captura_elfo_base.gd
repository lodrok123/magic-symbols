extends SceneTree
## CAPTURAS del elfo base (elfo_base) junto a la elfa jugadora (woodland_wanderer), en reposo, idle, andando y corriendo. NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_elfo_base.gd -- <carpeta>
## Cada pose sale de frente y de 3/4 con los dos personajes a su alto de juego (1,0 los dos), y además primeros planos del elfo (torso y piernas)
## para mirar cómo deforman hombros, codos, mangas y rodillas. «reposo» = la pose del GLB sin ningún clip.

const ALTO_JUEGO: float = 1.0
const SEPARACION: float = 1.0
const POSES: Array = [["reposo", ""], ["idle", "idle"], ["andar", "walk"], ["correr", "run"]]
const FRACCION_CLIP: float = 0.25          ## en qué punto del ciclo se congela (los clips de andar/correr tienen ahí una zancada abierta)
const VISTAS: Array = [["frente", 0.0], ["tres_cuartos", 40.0]]
const FOTOGRAMAS_ESPERA: int = 12
const CAMARA_PITCH: float = 12.0           ## grados de picado (suave: aquí se mira la figura, no el juego)
const TAM_COMPLETO: float = 1.7
const TAM_CERCA: float = 0.8
## Revisión de clips: [rol, fracciones del clip]. Los tumbados (muerte) llegan hasta el final; los cíclicos no repiten el primer fotograma.
const REVISION: Array = [["idle", [0.0, 0.3, 0.6, 0.9]], ["walk", [0.0, 0.25, 0.5, 0.75]], ["talk", [0.0, 0.3, 0.6, 0.9]],
	["saludo", [0.1, 0.3, 0.55, 0.85]], ["celebrar", [0.1, 0.3, 0.55, 0.85]]]
const VISTAS_REVISION: Array = [["frente", 0.0], ["tres_cuartos", 40.0]]
const SEPARACION_REVISION: float = 1.4
const TAM_REVISION: float = 3.0
const VENTANA_REVISION: Vector2i = Vector2i(1500, 700)
const CAMARA_PITCH_REVISION: float = 6.0
var camara_pitch: float = CAMARA_PITCH


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var carpeta: String = a[0] if a.size() > 0 else "res://docs/capturas/elfo_base"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta))
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
	var elfo := Pj3D.new()
	var elfa := Pj3D.new()
	elfo.position = Vector3(-SEPARACION * 0.5, 0, 0)
	elfa.position = Vector3(SEPARACION * 0.5, 0, 0)
	raiz.add_child(elfo)
	raiz.add_child(elfa)
	elfo.cargar("elfo_base")
	elfa.cargar("woodland_wanderer")
	elfo.set_alto(ALTO_JUEGO)
	elfa.set_alto(ALTO_JUEGO)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	raiz.add_child(cam)
	cam.current = true
	for i in 20:
		await process_frame
	var etiqueta: String = a[1] if a.size() > 1 else "despues"
	var solo_revision: bool = a.size() > 2 and a[2] == "revision"
	if solo_revision:
		elfo.queue_free()
		elfa.queue_free()
		await _revision(raiz, cam, carpeta, etiqueta)
		quit()
		return
	for pose in POSES:
		for p in [elfo, elfa]:
			await _poner_pose(p as Pj3D, String(pose[1]))
		for _i in FOTOGRAMAS_ESPERA:
			await process_frame
		for v in VISTAS:
			var giro: float = float(v[1])
			elfo.rotation_degrees.y = giro
			elfa.rotation_degrees.y = giro
			await _foto(cam, Vector3(0, 0.5, 0), TAM_COMPLETO, "%s/%s_%s_comparativa.png" % [carpeta, pose[0], v[0]])
			if pose[0] != "reposo" or v[0] == "frente":
				await _foto(cam, elfo.position + Vector3(0, 0.62, 0), TAM_CERCA, "%s/%s_%s_elfo_cerca.png" % [carpeta, pose[0], v[0]])
	await _revision(raiz, cam, carpeta, etiqueta)
	quit()


## REVISIÓN v2 (clips del elfo base): cada clip se congela en varias fracciones, una figura por fracción en fila, de frente y de lado.
## Sale una imagen por clip y vista: `<carpeta>/v2_<etiqueta>_<rol>_<vista>.png` (etiqueta = «antes» / «despues»). Con «revision» como tercer argumento
## solo se hace esto.
func _revision(raiz: Node3D, cam: Camera3D, carpeta: String, etiqueta: String) -> void:
	root.size = VENTANA_REVISION
	for _i in 4:
		await process_frame
	for rev in REVISION:
		var rol: String = String(rev[0])
		var fracciones: Array = rev[1]
		for v in VISTAS_REVISION:
			var figuras: Array = []
			for k in range(fracciones.size()):
				var f := Pj3D.new()
				raiz.add_child(f)
				f.cargar("elfo_base")
				f.set_alto(ALTO_JUEGO)
				f.position = Vector3((float(k) - float(fracciones.size() - 1) * 0.5) * SEPARACION_REVISION, 0, 0)
				f.rotation_degrees.y = float(v[1])
				figuras.append(f)
			for _i in 4:
				await process_frame
			for k in range(fracciones.size()):
				var f2: Pj3D = figuras[k]
				f2._arbol.active = false
				var clip: String = f2.clip_de(rol)
				f2._ap.active = true
				f2._ap.play(clip)
				var an: Animation = f2._ap.get_animation(clip)
				f2._ap.seek(minf(an.length * float(fracciones[k]), an.length - 0.001), true)
				f2._ap.pause()
			for _i in FOTOGRAMAS_ESPERA:
				await process_frame
			var pitch_antes: float = camara_pitch
			camara_pitch = CAMARA_PITCH_REVISION
			await _foto(cam, Vector3(0, 0.5, 0), TAM_REVISION, "%s/v2_%s_%s_%s.png" % [carpeta, etiqueta, rol, v[0]])
			camara_pitch = pitch_antes
			for f3 in figuras:
				(f3 as Node).queue_free()
			await process_frame


## Congela al personaje en `rol` (en FRACCION_CLIP del ciclo) o, con rol vacío, en la pose de reposo del GLB sin clips.
func _poner_pose(p: Pj3D, rol: String) -> void:
	var arbol: AnimationTree = p._arbol
	var ap: AnimationPlayer = p._ap
	var sk: Skeleton3D = p.find_children("*", "Skeleton3D", true, false)[0]
	if rol == "":
		arbol.active = false
		ap.active = false
		ap.stop()
		sk.reset_bone_poses()
		return
	arbol.active = false
	var clip: String = p.clip_de(rol)
	ap.active = true
	ap.play(clip)
	ap.seek(ap.get_animation(clip).length * FRACCION_CLIP, true)
	ap.pause()
	await process_frame


func _foto(cam: Camera3D, foco: Vector3, tam: float, ruta: String) -> void:
	var dir := Vector3(0.0, -sin(deg_to_rad(camara_pitch)), -cos(deg_to_rad(camara_pitch)))   # mira hacia -Z desde +Z (los modelos miran a +Z), algo picado
	cam.size = tam
	cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 20.0)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ruta)
	print("captura ", ruta)
