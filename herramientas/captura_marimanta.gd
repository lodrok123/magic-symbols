extends SceneTree
## CAPTURAS de Marimanta (la anciana duende, NPC): cada clip congelado en varias fracciones, de frente y de 3/4, y una comparativa de escala junto al goblin
## base y al goblin chibi. NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_marimanta.gd -- <carpeta>
## Salen `<carpeta>/<rol>_<vista>.png` (una figura por fracción, en fila) y `<carpeta>/escala_<vista>.png`.

const ID: String = "marimanta"
const ALTO_MARIMANTA: float = 0.8          ## alto de juego (ALTO_PJ en PruebaTest2)
const ALTO_GOBLIN: float = 0.85            ## alto de juego de la familia goblin
## Revisión de clips: [rol, fracciones del clip]. Los cíclicos no repiten el primer fotograma.
const REVISION: Array = [["idle", [0.0, 0.3, 0.6]], ["walk", [0.0, 0.25, 0.5, 0.75]], ["talk", [0.0, 0.25, 0.5, 0.75]],
	["pensar", [0.0, 0.25, 0.5, 0.75]], ["run", [0.0, 0.33, 0.66]]]
const VISTAS: Array = [["frente", 0.0], ["tres_cuartos", 40.0], ["espalda", 180.0]]
const SEPARACION: float = 1.2
const SEPARACION_ESCALA: float = 1.1
const TAM_REVISION: float = 2.6
const TAM_ESCALA: float = 2.2
const VENTANA: Vector2i = Vector2i(1500, 700)
const CAMARA_PITCH: float = 6.0            ## grados de picado (suave: aquí se mira la figura, no el juego)
const FOTOGRAMAS_ESPERA: int = 12


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var carpeta: String = a[0] if a.size() > 0 else "res://docs/capturas/marimanta"
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
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	raiz.add_child(cam)
	cam.current = true
	root.size = VENTANA
	for _i in 8:
		await process_frame
	await _revision(raiz, cam, carpeta)
	await _escala(raiz, cam, carpeta)
	quit()


## Cada clip en varias fracciones, una figura por fracción en fila, de frente, de 3/4 y de espaldas.
func _revision(raiz: Node3D, cam: Camera3D, carpeta: String) -> void:
	for rev in REVISION:
		var rol: String = String(rev[0])
		var fracciones: Array = rev[1]
		for v in VISTAS:
			var figuras: Array = []
			for k in range(fracciones.size()):
				var f := Pj3D.new()
				raiz.add_child(f)
				f.cargar(ID)
				f.set_alto(ALTO_MARIMANTA)
				f.position = Vector3((float(k) - float(fracciones.size() - 1) * 0.5) * SEPARACION, 0, 0)
				f.rotation_degrees.y = float(v[1])
				figuras.append(f)
			for _i in 4:
				await process_frame
			for k in range(fracciones.size()):
				_congelar(figuras[k] as Pj3D, rol, float(fracciones[k]))
			for _i in FOTOGRAMAS_ESPERA:
				await process_frame
			await _foto(cam, Vector3(0, 0.45, 0), TAM_REVISION, "%s/%s_%s.png" % [carpeta, rol, v[0]])
			for f3 in figuras:
				(f3 as Node).queue_free()
			await process_frame


## Marimanta, goblin base y goblin chibi, los tres en idle y a su alto de juego.
func _escala(raiz: Node3D, cam: Camera3D, carpeta: String) -> void:
	for v in VISTAS:
		var figuras: Array = []
		var ids: Array = [[ID, ALTO_MARIMANTA], ["goblin_base", ALTO_GOBLIN], ["goblin_warrior_chibi", ALTO_GOBLIN]]
		for k in range(ids.size()):
			var f := Pj3D.new()
			raiz.add_child(f)
			f.cargar(String(ids[k][0]))
			f.set_alto(float(ids[k][1]))
			f.position = Vector3((float(k) - 1.0) * SEPARACION_ESCALA, 0, 0)
			f.rotation_degrees.y = float(v[1])
			figuras.append(f)
		for _i in 4:
			await process_frame
		for f2 in figuras:
			_congelar(f2 as Pj3D, "idle", 0.15)
		for _i in FOTOGRAMAS_ESPERA:
			await process_frame
		await _foto(cam, Vector3(0, 0.5, 0), TAM_ESCALA, "%s/escala_%s.png" % [carpeta, v[0]])
		for f3 in figuras:
			(f3 as Node).queue_free()
		await process_frame


## Congela al personaje en `rol`, en la `fraccion` del clip.
func _congelar(p: Pj3D, rol: String, fraccion: float) -> void:
	p._arbol.active = false
	var clip: String = p.clip_de(rol)
	p._ap.active = true
	p._ap.play(clip)
	var an: Animation = p._ap.get_animation(clip)
	p._ap.seek(minf(an.length * fraccion, an.length - 0.001), true)
	p._ap.pause()


func _foto(cam: Camera3D, foco: Vector3, tam: float, ruta: String) -> void:
	var dir := Vector3(0.0, -sin(deg_to_rad(CAMARA_PITCH)), -cos(deg_to_rad(CAMARA_PITCH)))   # mira hacia -Z desde +Z (los modelos miran a +Z), algo picado
	cam.size = tam
	cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 20.0)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ruta)
	print("captura ", ruta)
