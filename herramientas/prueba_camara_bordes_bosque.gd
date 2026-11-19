extends SceneTree

const Bordes = preload("res://laboratorios/camara_bordes_bosque.gd")
const Lab = preload("res://laboratorios/lab_camara_bosque_3d.gd")
var fallos: int = 0
var comprobaciones: int = 0

class Errores extends Logger:
	var cantidad: int = 0
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		cantidad += 1

var errores := Errores.new()

func _initialize() -> void:
	OS.add_logger(errores)
	call_deferred("probar")

func verificar(condicion: bool, nombre: String) -> void:
	comprobaciones += 1
	if not condicion:
		fallos += 1
		print("FALLO: ", nombre)

func probar() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(cam)
	cam.make_current()
	for tam: Vector2i in [Vector2i(1280,720), Vector2i(1024,768), Vector2i(2560,1080), Vector2i(720,1280)]:
		viewport.size = tam
		for giro: float in [0.0, 90.0, 37.0]:
			var dir := Vector3(0,-1,-1).normalized().rotated(Vector3.UP, deg_to_rad(giro))
			cam.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), -dir * 40)
			for limites: Rect2 in Lab.ZONAS + [Rect2(-2,-2,4,4)]:
				for zoom: float in [6.0, 11.0, 30.0]:
					cam.size = zoom
					cam.size = minf(zoom, Bordes.tamanio_maximo(cam, limites))
					var vista := Bordes.huella(cam)
					verificar(vista.size.x <= limites.size.x and vista.size.y <= limites.size.y, "el zoom cabe en la zona incluso en sala pequeña")
					for pos: Vector2 in [Vector2.ZERO,Vector2(-100,0),Vector2(100,0),Vector2(0,-100),Vector2(0,100),Vector2(-100,-100),Vector2(100,-100),Vector2(-100,100),Vector2(100,100)]:
						var foco := Bordes.limitar(Vector3(pos.x,0,pos.y), limites, vista)
						var tolerancia := limites.grow(0.001)
						var encuadre := Rect2(Vector2(foco.x,foco.z)+vista.position,vista.size)
						verificar(tolerancia.encloses(encuadre), "ningún borde del encuadre sale de la zona: %s / %s / %s" % [tam, giro, pos])
						var suave := Bordes.seguir(Vector3(300,0,-300), Vector3(pos.x,0,pos.y), limites, vista, 1.0/60)
						verificar(tolerancia.encloses(Rect2(Vector2(suave.x,suave.z)+vista.position,vista.size)), "el suavizado tampoco sale al cambiar zoom/ventana")
	viewport.queue_free()
	var vista := Rect2(-4,-3,8,6)
	var limites := Rect2(-15,-10,30,20)
	var borde := Bordes.limitar(Vector3(14,0,2), limites, vista)
	verificar(is_equal_approx(borde.x,11) and is_equal_approx(borde.z,2), "el borde X conserva el seguimiento tangencial Z")
	verificar(Bordes.limitar(Vector3(13,0,2),limites,vista) == borde, "avanzar hacia fuera mantiene el foco bloqueado")
	verificar(Bordes.limitar(Vector3(8,0,2),limites,vista).x < borde.x, "al volver al interior se libera el foco")
	var actual := borde
	for i in 120:
		actual = Bordes.seguir(actual, Vector3(14,0,2),limites,vista,1.0/60)
	verificar(actual.is_equal_approx(borde), "sin deriva ni rebote al permanecer en el borde")
	var lab := Lab.new()
	root.add_child(lab)
	await process_frame
	for zona in 2:
		lab.cambiar_zona(zona)
		for punto in 9:
			lab.ir_a_punto(punto)
			await process_frame
			var vista_lab := Bordes.huella(lab.camara)
			verificar(lab.limites.grow(0.001).encloses(Rect2(Vector2(lab.foco.x,lab.foco.z)+vista_lab.position,vista_lab.size)), "laboratorio real: zona %d / punto %d" % [zona,punto])
			var pantalla := root.get_visible_rect().grow(-8)
			verificar(pantalla.has_point(lab.camara.unproject_position(lab.jugador.position+Vector3(0,1.8,0))) and pantalla.has_point(lab.camara.unproject_position(lab.jugador.position)), "personaje completo dentro de pantalla: zona %d / punto %d" % [zona,punto])
		lab.depuracion = true
		await process_frame
		lab.depuracion = false
		lab.ir_a_punto(6)
		if OS.get_cmdline_user_args().has("--capturas"):
			await process_frame
			await RenderingServer.frame_post_draw
			var nombre := "camara_bosque.png" if zona == 0 else "camara_cueva.png"
			DirAccess.make_dir_recursive_absolute("res://docs/capturas/camara_bordes")
			var ruta := "res://docs/capturas/camara_bordes/" + nombre
			verificar(root.get_texture().get_image().save_png(ruta) == OK, "guardar captura")
	lab.bloqueo = false
	lab.ir_a_punto(8)
	verificar(Vector2(lab.foco.x,lab.foco.z).distance_to(Vector2(lab.jugador.position.x,lab.jugador.position.z)) < 0.001, "comparación sin bloqueo sigue al personaje hasta el borde")
	lab.queue_free()
	await process_frame
	verificar(errores.cantidad == 0, "sin errores de ejecución: %d" % errores.cantidad)
	print("COMPROBACIONES: %d / FALLOS: %d" % [comprobaciones,fallos])
	quit(0 if fallos == 0 else 1)
