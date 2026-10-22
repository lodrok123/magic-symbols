extends SceneTree
## CAPTURAS del goblin asesino (goblin_asesino): cada clip congelado en varias fracciones, de frente y de lado (se ven los brazos y las dos dagas), y una comparativa de
## escala junto al goblin guerrero chibi y al goblin base. NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_goblin_asesino.gd -- <carpeta> [clips separados por coma]
## Salen `<carpeta>/<clip>_<vista>[_<n>].png` (una figura por fracción, en fila; si hay más de FIGURAS_POR_IMAGEN se parte en varias) y `<carpeta>/escala_<vista>.png`.
## Sin clips en la línea de órdenes saca todos los de REVISION y la escala.

const ID: String = "goblin_asesino"
const ALTO_GOBLIN: float = 0.85            ## alto de juego de la familia goblin (ALTO_PJ en PruebaTest2)
## Revisión de clips: [rol, fracciones del clip, (opcional) nombre del archivo]. Los cíclicos no repiten el primer fotograma. El ataque incluye los dos instantes de corte (AtaqueDoble.CORTES).
const REVISION: Array = [
	["idle", [0.0, 0.3, 0.6, 0.85]],
	["walk", [0.0, 0.25, 0.5, 0.75]],
	["run", [0.0, 0.25, 0.5, 0.75]],
	["guardia", [0.0, 0.2, 0.4, 0.6, 0.8]],
	["attack", [0.0, 0.18, 0.31, AtaqueDoble.T_CORTE_DERECHO, AtaqueDoble.T_FIN_DERECHO, AtaqueDoble.T_CORTE_IZQUIERDO, AtaqueDoble.T_FIN_IZQUIERDO, 0.88]],
	["attack", [AtaqueDoble.T_CORTE_DERECHO, AtaqueDoble.T_CORTE_IZQUIERDO], "cortes"],     # solo los dos instantes de corte, más grandes
	["paso_lado", [0.0, 0.25, 0.5, 0.75]],
	["hit", [0.0, 0.05, 0.12, 0.3]],
	["death", [0.0, 0.2, 0.5, 1.0]],
	["empujado", [0.0, 0.3, 0.6, 1.0]],
	["levantarse", [0.0, 0.3, 0.6, 0.95]],
]
const VISTAS: Array = [["frente", 0.0], ["lado", 90.0]]
const SEPARACION: float = 1.25
const SEPARACION_ESCALA: float = 1.1
const FIGURAS_POR_IMAGEN: int = 4
const TAM_MIN: float = 1.7
const TAM_ESCALA: float = 2.2
const VENTANA: Vector2i = Vector2i(1500, 700)
const CAMARA_PITCH: float = 6.0            ## grados de picado (suave: aquí se mira la figura, no el juego)
const FOTOGRAMAS_ESPERA: int = 12

var _tam_fijo: float = 0.0


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var carpeta: String = a[0] if a.size() > 0 else "res://docs/capturas/goblin_asesino"
	var solo: PackedStringArray = String(a[1]).split(",") if a.size() > 1 else PackedStringArray()
	_tam_fijo = float(a[2]) if a.size() > 2 else 0.0      # tercer argumento opcional: tamaño de la cámara fijo (acercar a una figura)
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
	pl.size = Vector2(60, 60)
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
	DisplayServer.window_set_size(VENTANA)
	root.size = VENTANA
	for _i in 8:
		await process_frame
	for rev in REVISION:
		if solo.is_empty() or solo.has(String(rev[2]) if rev.size() > 2 else String(rev[0])):
			await _revision(raiz, cam, carpeta, rev)
	if solo.is_empty() or solo.has("escala"):
		await _escala(raiz, cam, carpeta)
	quit()


## Un clip en varias fracciones, una figura por fracción en fila, de frente y de lado.
func _revision(raiz: Node3D, cam: Camera3D, carpeta: String, rev: Array) -> void:
	var rol: String = String(rev[0])
	var fracciones: Array = rev[1]
	for v in VISTAS:
		var trozos: int = int(ceil(float(fracciones.size()) / float(FIGURAS_POR_IMAGEN))) if fracciones.size() > 5 else 1
		var por_imagen: int = int(ceil(float(fracciones.size()) / float(trozos)))
		for tr in range(trozos):
			var ini: int = tr * por_imagen
			var fin: int = mini(ini + por_imagen, fracciones.size())
			var figuras: Array = []
			for k in range(ini, fin):
				var f := Pj3D.new()
				raiz.add_child(f)
				f.cargar(ID)
				f.set_alto(ALTO_GOBLIN)
				f.position = Vector3((float(k - ini) - float(fin - ini - 1) * 0.5) * SEPARACION, 0, 0)
				f.rotation_degrees.y = float(v[1])
				figuras.append(f)
			for _i in 4:
				await process_frame
			for k in range(ini, fin):
				if not _congelar(figuras[k - ini] as Pj3D, rol, float(fracciones[k])):
					print("SIN CLIP ", rol)
			for _i in FOTOGRAMAS_ESPERA:
				await process_frame
			var tam: float = _tam_fijo if _tam_fijo > 0.0 else maxf(TAM_MIN, float(fin - ini) * SEPARACION / (float(VENTANA.x) / float(VENTANA.y)))
			var sufijo: String = "" if trozos == 1 else "_%d" % (tr + 1)
			var nombre: String = String(rev[2]) if rev.size() > 2 else rol
			await _foto(cam, Vector3(0, 0.45, 0), tam, "%s/%s_%s%s.png" % [carpeta, nombre, v[0], sufijo])
			for f3 in figuras:
				(f3 as Node).queue_free()
			await process_frame


## El asesino, el goblin guerrero chibi y el goblin base, los tres en idle y a su alto de juego.
func _escala(raiz: Node3D, cam: Camera3D, carpeta: String) -> void:
	for v in VISTAS:
		var figuras: Array = []
		var ids: Array = [[ID, ALTO_GOBLIN], ["goblin_warrior_chibi", ALTO_GOBLIN], ["goblin_base", ALTO_GOBLIN]]
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


## Congela al personaje en `rol`, en la `fraccion` del clip. Devuelve false si no hay clip.
func _congelar(p: Pj3D, rol: String, fraccion: float) -> bool:
	var clip: String = p.clip_de(rol)
	if clip == "" or p._ap == null:
		return false
	p._arbol.active = false
	p._ap.active = true
	p._ap.play(clip)
	var an: Animation = p._ap.get_animation(clip)
	p._ap.seek(minf(an.length * fraccion, an.length - 0.001), true)
	p._ap.pause()
	return true


func _foto(cam: Camera3D, foco: Vector3, tam: float, ruta: String) -> void:
	var dir := Vector3(0.0, -sin(deg_to_rad(CAMARA_PITCH)), -cos(deg_to_rad(CAMARA_PITCH)))   # mira hacia -Z desde +Z (los modelos miran a +Z), algo picado
	cam.size = tam
	cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), foco - dir * 20.0)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(ruta)
	print("captura ", ruta, " ", img.get_width(), "x", img.get_height())
