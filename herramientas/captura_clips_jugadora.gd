extends SceneTree
## CAPTURAS de los clips nuevos de la jugadora (24/10; arte/meshy/jugadora_clips.glb vía ClipsFamilia): cada clip en 4 fracciones de su duración, en la jugadora ACTUAL
## (woodland_wanderer) y en la BASE vestida (jugadora_base con capa con capucha y túnica), de tres cuartos. Una hoja por clip: dos filas (actual, base) × cuatro columnas.
## Además, la comparativa de correr y andar: los de siempre frente a los de Meshy (Running y Walking del GLB nuevo), en las dos jugadoras. NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_clips_jugadora.gd -- [carpeta] [secciones: clips,marcha]    (por defecto res://docs/capturas/clips_jugadora)

const ALTO_JUEGO: float = 1.0
const FOTOGRAMAS_ESPERA: int = 6
const CAMARA_PITCH: float = 8.0
const GIRO_TRES_CUARTOS: float = 40.0
const GIRO_LADO: float = 90.0
const CLIPS_DE_LADO: Array = ["empujar", "abrir_cofre", "agacharse"]    ## los que se mueven hacia delante y atrás: además, de perfil
const TAM_CAMARA: float = 1.5
const LADO_FOTO: int = 900
## Recorte de cada fotograma de la hoja (px de la foto de 900 × 900): el personaje de 1,0 u ocupa unos 600 px de alto, centrado.
const RECORTE: Rect2i = Rect2i(150, 90, 600, 720)
const FRACCIONES: Array = [0.0, 0.33, 0.66, 0.99]
const FRACCIONES_MARCHA: Array = [0.0, 0.25, 0.5, 0.75]
const CLIPS: Array = ["abrir_cofre", "agacharse", "ofrecer", "saludo", "empujar"]
const RUTA_CLIPS: String = "res://arte/meshy/jugadora_clips.glb"
const PRENDAS: Array = ["tunica", "capa_capucha"]
## (comparativa) clip de Meshy en el GLB nuevo (arte/meshy/clips_jugadora.py los renombra) -> rol de Pj3D con el que se compara el de siempre
const MARCHA_MESHY: Dictionary = {"Correr": "run", "Andar": "walk"}

var _carpeta: String = "res://docs/capturas/clips_jugadora"
var _actual: Pj3D = null
var _base: Pj3D = null
var _cam: Camera3D = null


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0 and a[0] != "":
		_carpeta = a[0]
	var secciones: PackedStringArray = (a[1] if a.size() > 1 else "clips,marcha").split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_carpeta))
	var gi: FileAccess = FileAccess.open(ProjectSettings.globalize_path(_carpeta).path_join(".gdignore"), FileAccess.WRITE)
	if gi != null:
		gi.close()
	Estado.nuevo()
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
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	raiz.add_child(_cam)
	_cam.current = true
	root.size = Vector2i(LADO_FOTO, LADO_FOTO)
	_actual = Pj3D.new()
	raiz.add_child(_actual)
	_actual.cargar("woodland_wanderer")
	_actual.set_alto(ALTO_JUEGO)
	_base = Pj3D.new()
	raiz.add_child(_base)
	_base.cargar("jugadora_base")
	_base.set_alto(ALTO_JUEGO)
	for prenda in PRENDAS:
		_base.poner_ropa(prenda)
	for p in [_actual, _base]:
		(p as Pj3D).rotation_degrees.y = GIRO_TRES_CUARTOS
	for i in 20:
		await process_frame
	print("INFO  clips de la actual: ", _actual.lista_clips())
	if secciones.has("clips"):
		for rol in CLIPS:
			await _hoja(rol, [["actual", _actual, _actual.clip_de(rol)], ["base", _base, _base.clip_de(rol)]], FRACCIONES)
		for rol in CLIPS_DE_LADO:
			await _hoja(rol + "_lado", [["actual", _actual, _actual.clip_de(rol)], ["base", _base, _base.clip_de(rol)]], FRACCIONES, GIRO_LADO)
	if secciones.has("marcha"):
		for clip_m in MARCHA_MESHY.keys():
			var rol: String = String(MARCHA_MESHY[clip_m])
			var filas: Array = []
			for par in [["actual", _actual], ["base", _base]]:
				var p: Pj3D = par[1] as Pj3D
				var nombre_m: String = "Meshy_" + String(clip_m)
				_poner_meshy(p, String(clip_m), nombre_m)
				filas.append([String(par[0]) + "_siempre", p, p.clip_de(rol)])
				filas.append([String(par[0]) + "_meshy", p, nombre_m])
			await _hoja("marcha_" + String(clip_m).to_lower(), filas, FRACCIONES_MARCHA)
	quit()


## Añade al AnimationPlayer de `p` el clip `clip_m` del GLB nuevo traducido a su esqueleto (sin la corrección de pies: solo para mirarlo).
func _poner_meshy(p: Pj3D, clip_m: String, nombre: String) -> void:
	if p._ap.has_animation(nombre):
		return
	var sk: Skeleton3D = p.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var an: Animation = ClipsFamilia.traducir_clip(Pj3D.glb_de(p.id), RUTA_CLIPS, clip_m, p._modelo, sk)
	if an == null:
		push_warning("sin clip " + clip_m)
		return
	an.loop_mode = Animation.LOOP_LINEAR
	p._ap.get_animation_library("").add_animation(nombre, an)


## Una hoja: filas [etiqueta, personaje, clip] × columnas = fracciones. Guarda `<carpeta>/<nombre>.png`.
func _hoja(nombre: String, filas: Array, fracciones: Array, giro: float = GIRO_TRES_CUARTOS) -> void:
	var hoja := Image.create_empty(RECORTE.size.x * fracciones.size(), RECORTE.size.y * filas.size(), false, Image.FORMAT_RGB8)
	for r in range(filas.size()):
		var fila: Array = filas[r]
		var p: Pj3D = fila[1] as Pj3D
		for q in [_actual, _base]:
			(q as Pj3D).visible = q == p
			(q as Pj3D).rotation_degrees.y = giro
		for c in range(fracciones.size()):
			await _poner(p, String(fila[2]), float(fracciones[c]))
			var foto: Image = await _foto()
			hoja.blit_rect(foto, RECORTE, Vector2i(c * RECORTE.size.x, r * RECORTE.size.y))
		print("fila %s: %s (%s)" % [nombre, fila[0], fila[2]])
	for q in [_actual, _base]:
		(q as Pj3D).visible = true
	hoja.save_png(ProjectSettings.globalize_path(_carpeta).path_join(nombre + ".png"))
	print("captura ", nombre)


func _poner(p: Pj3D, clip: String, fraccion: float) -> void:
	if p._arbol != null:
		p._arbol.active = false
	var ap: AnimationPlayer = p._ap
	ap.active = true
	ap.play(clip)
	ap.seek(ap.get_animation(clip).length * fraccion, true)
	ap.pause()
	for _i in FOTOGRAMAS_ESPERA:
		await process_frame


func _foto() -> Image:
	var dir := Vector3(0.0, -sin(deg_to_rad(CAMARA_PITCH)), -cos(deg_to_rad(CAMARA_PITCH)))
	_cam.size = TAM_CAMARA
	_cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3(0, 0.5, 0) - dir * 20.0)
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_viewport().get_texture().get_image()
