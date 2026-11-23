extends SceneTree

const LabCueva = preload("res://laboratorios/lab_camara_cuevas_3d.gd")
const Bordes = preload("res://laboratorios/camara_bordes_bosque.gd")
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

func comprobar(valor: bool, texto: String) -> void:
	comprobaciones += 1
	if not valor:
		fallos += 1
		print("FALLO: ", texto)

func probar() -> void:
	# El entorno de pruebas no siempre permite escribir user://; diario temporal del test.
	PlayLog._file = FileAccess.open("res://docs/capturas/camara_cuevas/partida_test.jsonl", FileAccess.WRITE)
	for ruta: String in LabCueva.PRUEBAS_CUEVAS:
		if OS.get_cmdline_user_args().has("--solo-principal") and ruta != LabCueva.PRUEBAS_CUEVAS[0]:
			continue
		Flags.nuevo()
		Estado.nuevo()
		var lab := (load(ruta) as PackedScene).instantiate()
		lab.precalentar_al_inicio = false
		root.add_child(lab)
		for i in 12:
			await process_frame
		for enemigo in lab.find_children("*", "Combate3D", true, false):
			enemigo.quieto = true
		comprobar(lab.get("_jugador") != null and get_first_node_in_group("spellcaster") != null, "%s: personaje y lanzador reales" % lab.nivel)
		comprobar(lab.salas_camara.size() >= 4, "%s: salas leídas del mapa" % lab.nivel)
		comprobar((lab.paredes_reducidas > 0 and lab.paredes_reducidas < lab.paredes_exteriores) if lab.perimetro_disperso else lab.paredes_reducidas == 0, "%s: densidad de perímetro solicitada" % lab.nivel)
		for salida in lab.find_children("*", "SalidaNivel3D", true, false):
			comprobar(salida.process_mode == Node.PROCESS_MODE_DISABLED, "la salida al bosque no abandona el laboratorio")
		var tecla := InputEventKey.new()
		tecla.keycode = KEY_F6
		tecla.pressed = true
		lab._unhandled_input(tecla)
		comprobar(not lab.bloqueo_cueva, "F6 desactiva el bloqueo")
		tecla.shift_pressed = true
		lab._unhandled_input(tecla)
		comprobar(not lab.por_sala, "Mayús+F6 cambia al límite del mapa")
		tecla.shift_pressed = false
		lab._unhandled_input(tecla)
		comprobar(lab.bloqueo_cueva, "F6 reactiva el bloqueo")
		lab.por_sala = true
		for y in range(lab.get("_alto")):
			for x in range(lab.get("_ancho")):
				if (x == 0 or y == 0 or x == int(lab.get("_ancho"))-1 or y == int(lab.get("_alto"))-1) and Terreno3D.letra_de(Vector2i(x,y)) == "#":
					comprobar(Terreno3D.bloqueada(Vector2i(x,y)), "el perímetro conserva su colisión")
		var cam: Camera3D = lab.get("_camara")
		for sala in lab.salas_camara.size():
			for punto: Vector2 in [Vector2(0.5,0.5),Vector2(0,0.5),Vector2(1,0.5),Vector2(0.5,0),Vector2(0.5,1),Vector2.ZERO,Vector2.ONE,Vector2(0,1),Vector2(1,0)]:
				lab.ir_a_revision(sala,punto)
				await process_frame
				var foco: Vector3 = lab.get("_foco")
				var vista := Bordes.huella_desde_foco(cam,foco,float(lab.get("ALTO")))
				var encuadre := Rect2(Vector2(foco.x,foco.z)+vista.position,vista.size)
				comprobar(lab.limites_vista.grow(0.01).encloses(encuadre), "%s: sala %d / punto %s dentro del encuadre" % [lab.nivel,sala,punto])
				comprobar(lab.limites_mapa.grow(0.01).encloses(encuadre), "sin exterior del mapa")
				var pj: Node3D = lab.get("_jugador")
				var pantalla := root.get_visible_rect().grow(-2)
				var altura: float = pj.alto_modelo() * pj.scale.y
				comprobar(pantalla.has_point(cam.unproject_position(pj.position)) and pantalla.has_point(cam.unproject_position(pj.position+Vector3(0,altura,0))), "%s: personaje en pantalla, sala %d / %s" % [lab.nivel,sala,punto])
		lab.ir_a_sala(0)
		lab.por_sala = false
		for i in 75:
			await process_frame
		comprobar(lab.limites_vista.position.distance_to(lab.limites_mapa.position) < 0.01, "paso suave al modo de mapa completo")
		lab.bloqueo_cueva = false
		lab.ir_a_sala(0)
		await process_frame
		comprobar(is_equal_approx(cam.size,lab.zoom_solicitado), "sin bloqueo recupera el zoom solicitado")
		lab.bloqueo_cueva = true
		lab.por_sala = true
		lab.ir_a_sala(0)
		lab.zoom_solicitado = 30.0
		await process_frame
		comprobar(cam.size < 30, "zoom alejado limitado a la sala")
		lab.zoom_solicitado = 6.0
		lab.ir_a_sala(0)
		if lab.indice_cueva == 0:
			await comprobar_caminando(lab)
			await comprobar_pasillo(lab)
			lab.ir_a_sala(0)
		if OS.get_cmdline_user_args().has("--capturas"):
			for i in 45:
				await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://docs/capturas/camara_cuevas")
			comprobar(root.get_texture().get_image().save_png("res://docs/capturas/camara_cuevas/%s.png" % lab.nivel) == OK, "captura de la cueva real")
		print("OK: %s / %d salas / %d de %d muros exteriores retirados" % [lab.nivel,lab.salas_camara.size(),lab.paredes_reducidas,lab.paredes_exteriores])
		lab.queue_free()
		for i in 4:
			await process_frame
	comprobar(errores.cantidad == 0, "errores de ejecución: %d" % errores.cantidad)
	print("COMPROBACIONES: %d / FALLOS: %d" % [comprobaciones,fallos])
	quit(0 if fallos == 0 else 1)

func medir_caminata(lab: Node, bloqueo: bool) -> Dictionary:
	lab.preparar_borde_oeste()
	lab.bloqueo_cueva = bloqueo
	for i in 4:
		await process_frame
	var pj: Node3D = lab.get("_jugador")
	var cam: Camera3D = lab.get("_camara")
	var quietos: int = 0
	var distancia_bloqueada: float = 0.0
	var movimiento: float = 0.0
	Input.action_press("mover_izquierda")
	for i in 240:
		var antes_pj := pj.position.x
		var antes_cam := cam.position.x
		await process_frame
		var avance := absf(pj.position.x - antes_pj)
		movimiento += avance
		if avance > 0.005 and absf(cam.position.x - antes_cam) < 0.002:
			quietos += 1
			distancia_bloqueada += avance
			if bloqueo and quietos in [8,25] and OS.get_cmdline_user_args().has("--capturas"):
				await RenderingServer.frame_post_draw
				var nombre := "Cueva_bloqueada_1.png" if quietos == 8 else "Cueva_bloqueada_2.png"
				comprobar(root.get_texture().get_image().save_png("res://docs/capturas/camara_cuevas/"+nombre) == OK,"captura con cámara quieta y personaje andando")
	Input.action_release("mover_izquierda")
	return {"fotogramas":quietos,"distancia":distancia_bloqueada,"movimiento":movimiento}

func comprobar_caminando(lab: Node) -> void:
	var con := await medir_caminata(lab,true)
	var sin := await medir_caminata(lab,false)
	print("CAMINANDO con límite: %d fotogramas y %.2f u de personaje moviéndose con cámara quieta; sin límite: %d fotogramas" % [con.fotogramas,con.distancia,sin.fotogramas])
	comprobar(con.movimiento > 2.0 and sin.movimiento > 2.0, "el recorrido usa movimiento real y colisiones")
	comprobar(con.fotogramas >= 5 and con.distancia >= 0.25, "la cámara se detiene mientras el personaje sigue andando ANTES de chocar")
	comprobar(sin.fotogramas <= 2, "sin límite la cámara sigue durante el mismo recorrido")
	lab.bloqueo_cueva = true

func comprobar_pasillo(lab: Node) -> void:
	var puzles := lab.get_node("Puzles") as Puzle3D
	var puerta: Node = puzles.nodo("paso_norte")
	comprobar(puerta != null, "el recorrido entre salas usa la puerta real")
	if puerta == null:
		return
	puerta.call("abrir")
	lab.ir_a(Vector2i(4,12))
	lab._actualizar_limites(1.0,true)
	lab._colocar_camara()
	var pj: Node3D = lab.get("_jugador")
	var cam: Camera3D = lab.get("_camara")
	var salas: Array[int] = []
	var fuera: int = 0
	var salto_maximo: float = 0.0
	for accion: String in ["mover_adelante","mover_atras"]:
		Input.action_press(accion)
		for i in 240:
			var antes := cam.position
			await process_frame
			salto_maximo = maxf(salto_maximo,cam.position.distance_to(antes))
			if not salas.has(lab.sala_actual):
				salas.append(lab.sala_actual)
			var pantalla := root.get_visible_rect().grow(-2)
			var altura: float = pj.alto_modelo()*pj.scale.y
			if not pantalla.has_point(cam.unproject_position(pj.position)) or not pantalla.has_point(cam.unproject_position(pj.position+Vector3(0,altura,0))):
				fuera += 1
		Input.action_release(accion)
	print("PASILLO: salas %s / personaje fuera %d fotogramas / salto máximo cámara %.3f u" % [salas,fuera,salto_maximo])
	comprobar(salas.has(0) and salas.has(-1) and salas.has(1), "camina de C1 al pasillo y a C2")
	comprobar(lab.sala_actual == 0, "vuelve caminando desde C2 a C1")
	comprobar(fuera == 0, "personaje completo visible durante el cambio de sala")
	comprobar(salto_maximo < 0.8, "el cambio de sala no provoca un salto de cámara")
