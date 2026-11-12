extends SceneTree
## ICONOS DE LOS ATUENDOS (12/11, Pablo: «en la tienda una pequeña imagen del producto a la derecha de la lista tipo Breath of the Wild»): la jugadora base
## vestida con cada atuendo (`Atuendos.ids`), de tres cuartos y algo picada, con fondo transparente, a `arte/iconos/<id>.png` de LADO × LADO. Los usan la
## pantalla de la tienda (el detalle del producto) y la pestaña Vestuario del menú (`Objetos.dibujar` carga `arte/iconos/<id>.png` si existe). NECESITA VENTANA:
##   godot --path . --script res://herramientas/captura_iconos_atuendos.gd
## Después hay que reimportar (`godot --headless --path . --import`) para que `ResourceLoader.exists` los vea.

const LADO: int = 256
const ALTO_JUEGO: float = 1.0
const FOCO: Vector3 = Vector3(0.0, 0.49, 0.0)
const TAM: float = 1.08


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(LADO, LADO)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.84, 0.92)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	sol.light_energy = 1.1
	sv.add_child(sol)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = TAM
	sv.add_child(cam)
	# Desde delante y un poco a la izquierda de la jugadora (los modelos miran a +Z), algo picada, como en la tienda de Breath of the Wild.
	var dir := Vector3(-0.5, -0.32, -1.0).normalized()
	cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), FOCO - dir * 12.0)
	var pj := Pj3D.new()
	sv.add_child(pj)
	if not pj.cargar("jugadora_base"):
		push_error("no carga jugadora_base")
		quit(1)
		return
	pj.set_alto(ALTO_JUEGO)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/iconos"))
	for id in Atuendos.ids():
		for p in (pj.ropa_puesta() as Array).duplicate():
			pj.quitar_ropa(String(p))
		for p in Atuendos.prendas(String(id)):
			pj.poner_ropa(String(p))
		for _i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = sv.get_texture().get_image()
		var ruta: String = "res://arte/iconos/%s.png" % id
		img.save_png(ProjectSettings.globalize_path(ruta))
		print("icono ", ruta)
	quit(0)
