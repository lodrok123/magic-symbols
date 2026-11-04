extends SceneTree
## 4/11 (Pipeline): hoja CENITAL ortogonal de piezas, en cuadrícula, con los ejes pintados: línea roja = norte-sur (el norte, arriba; la cámara
## del juego mira al norte, así que el FRENTE de una pieza con cara debe mirar hacia ABAJO, a +Z), línea azul = este-oeste. NECESITA VENTANA.
##   godot --path . --resolution 1600x900 --script res://herramientas/hoja_giro_modelos.gd -- <salida.png> <id> <id> ...
## Si el nombre de la salida lleva "frente" (p. ej. antes_frente.png) la cámara es la del juego: desde el sur, mirando al norte, inclinada 55°.
## Cada pieza sale de Pieza3D.crear_visual (con su GIRO_MODELO aplicado), a escala común para que quepa en su casilla; se rotula con el id y
## el giro que lleva en la tabla. Se usa para el antes/después de docs/capturas/giro_modelos/.
const COLS: int = 8
const CELDA: float = 3.0
var vp: SubViewport


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var a := OS.get_cmdline_user_args()
	var salida: String = a[0]
	var ids: Array = a.slice(1)
	if ids.has("--sin-giro"):       # el antes: los modelos tal como vienen de Meshy
		ids.erase("--sin-giro")
		Pieza3D.giro_activo = false
	var n: int = ids.size()
	var cols: int = mini(n, COLS)
	var filas: int = ceili(float(n) / cols)
	var px: int = 240
	vp = SubViewport.new()
	var oblicua: bool = salida.get_file().contains("frente")       # <nombre>_frente.png: cámara del juego (desde el sur, inclinada) en vez de cenital
	var esp_z: float = CELDA * (1.7 if oblicua else 1.0)
	var pitch: float = 55.0 if oblicua else 90.0
	vp.size = Vector2i(cols * px, int((filas * esp_z * sin(deg_to_rad(pitch)) + (4.0 if oblicua else 0.0)) * px / CELDA))
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.82, 0.84, 0.80)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.85)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-70.0, -25.0, 0.0)
	vp.add_child(luz)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = float(cols) * CELDA
	vp.add_child(cam)
	cam.position = Vector3(0.0, 30.0 * sin(deg_to_rad(pitch)), 30.0 * cos(deg_to_rad(pitch)))
	cam.rotation_degrees = Vector3(-pitch, 0.0, 0.0)        # mira hacia abajo; arriba de la imagen = -Z = norte
	Pieza3D._cargar_bibliotecas()
	for i in n:
		var id: String = String(ids[i])
		var c: int = i % cols
		var f: int = i / cols
		var centro := Vector3((c - (cols - 1) * 0.5) * CELDA, 0.0, (f - (filas - 1) * 0.5) * esp_z)
		var v: Node3D = Pieza3D.crear_visual(id)
		if v != null:
			vp.add_child(v)
			var caja: AABB = Pieza3D._caja(v, Transform3D.IDENTITY)
			var k: float = (CELDA * (0.62 if oblicua else 0.78)) / maxf(maxf(caja.size.x, caja.size.z), 0.01)
			v.scale = Vector3.ONE * minf(k, 8.0 if not oblicua else 3.0)
			v.position = centro
		if not oblicua:
			_linea(centro, Vector3(0.02, 0.02, CELDA * 0.94), Color(0.85, 0.1, 0.1))        # norte-sur
			_linea(centro, Vector3(CELDA * 0.94, 0.02, 0.02), Color(0.1, 0.25, 0.9))        # este-oeste
			_linea(centro + Vector3(0.0, 0.0, CELDA * 0.47), Vector3(0.5, 0.02, 0.06), Color(0.85, 0.1, 0.1))     # tope sur
		var et := Label3D.new()
		et.text = "%s %s°" % [id, str(snappedf(Pieza3D.giro_de(Pieza3D.id_real(id)), 0.1))]
		et.font_size = 26
		et.pixel_size = 0.009
		et.modulate = Color(0.05, 0.05, 0.05)
		et.outline_size = 6
		et.outline_modulate = Color(1, 1, 1)
		et.no_depth_test = true
		if oblicua:
			et.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		else:
			et.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		vp.add_child(et)
		et.position = centro + (Vector3(0.0, 0.0, CELDA * 0.62) if oblicua else Vector3(0.0, 9.0, -CELDA * 0.42))
	for _i in 8:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(salida.get_base_dir())
	img.save_png(salida)
	print("guardado ", salida, " ", img.get_size(), " piezas ", n)
	quit()


func _linea(pos: Vector3, tam: Vector3, col: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = tam
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	mat.no_depth_test = true
	b.material = mat
	m.mesh = b
	vp.add_child(m)
	m.position = pos + Vector3(0.0, 8.0, 0.0)
