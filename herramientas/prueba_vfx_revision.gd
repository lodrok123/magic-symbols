extends SceneTree

const Lab = preload("res://laboratorios/lab_vfx_revision_3d.gd")
const Agua = preload("res://laboratorios/vfx_revision/agua_revision.gd")
const Magma = preload("res://laboratorios/vfx_revision/magma_revision.gd")
const Viento = preload("res://laboratorios/vfx_revision/viento_revision.gd")
var fallos: int = 0
var carpeta_capturas: String = "res://.godot/vfx_revision_capturas"
class Errores extends Logger:
	var cantidad: int = 0
	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		cantidad += 1
var errores := Errores.new()

func _initialize() -> void:
	OS.add_logger(errores)
	call_deferred("probar")

func comprobar(valor: bool, texto: String) -> void:
	if not valor:
		fallos += 1
		push_error(texto)
	else:
		print("OK: ", texto)

func probar() -> void:
	var escena := Node3D.new()
	root.add_child(escena)
	var cam := Camera3D.new()
	escena.add_child(cam)
	cam.position = Vector3(6, 5, 9)
	cam.look_at(Vector3(0, 1, 0))
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, -35, 0)
	escena.add_child(sol)
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(30, 30)
	suelo.mesh = plano
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.16, 0.14)
	suelo.material_override = material
	escena.add_child(suelo)
	var capturar: bool = OS.get_cmdline_user_args().has("--capturas-vfx")
	var ronda2: bool = OS.get_cmdline_user_args().has("--ronda2")
	var ronda3: bool = OS.get_cmdline_user_args().has("--ronda3")
	var ronda4: bool = OS.get_cmdline_user_args().has("--ronda4")
	var ronda5: bool = OS.get_cmdline_user_args().has("--ronda5")
	var perfil: bool = OS.get_cmdline_user_args().has("--perfil")
	if ronda2:
		carpeta_capturas = "res://.godot/vfx_revision_ronda2"
	if ronda3:
		carpeta_capturas = "res://.godot/vfx_revision_ronda3"
	if ronda4:
		carpeta_capturas = "res://.godot/vfx_revision_ronda4"
	if ronda5:
		carpeta_capturas = "res://.godot/vfx_revision_ronda5"
	if perfil:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 9.0
		cam.position = Vector3(10, 1, -1)
		cam.look_at(Vector3(0, 1, -1))
		carpeta_capturas += "/perfil"
	if capturar:
		DirAccess.make_dir_recursive_absolute(carpeta_capturas)
	var indice: int = 0
	for receta in Lab.RECETAS_REVISION:
		indice = Lab.RECETAS_REVISION.find(receta)
		if ronda2 and indice not in [2, 3, 9]:
			continue
		if (ronda3 or ronda4 or ronda5) and indice not in [2, 3]:
			continue
		if OS.get_cmdline_user_args().has("--solo-barrera") and not (receta[1] == "agua" and receta[2] == 3):
			continue
		var efecto: Node3D
		match receta[1]:
			"agua": efecto = Agua.new()
			"magma": efecto = Magma.new()
			_: efecto = Viento.new()
		var tam: Vector3 = receta[3]
		efecto.definir(receta[2], tam.x, tam.y, tam.z)
		escena.add_child(efecto)
		efecto.lanzar(-1)
		var es_ola: bool = receta[1] == "agua" and receta[2] == 1
		var alturas_nacer: Array[float] = []
		for frame in (65 if es_ola else 45):
			await process_frame
			if es_ola and frame == 8:
				comprobar(efecto.crece < 0.01 and efecto.anticipacion_ola > 0.5, "ola: anticipación visible antes de levantar el cuerpo")
			if es_ola and frame in [18, 28, 38]:
				alturas_nacer.append(efecto.crece)
			if capturar and frame == 8:
				await guardar_captura(indice, "nacer")
			if capturar and (ronda2 or ronda3 or ronda4 or ronda5) and frame in [18, 28, 38, 48]:
				await guardar_captura(indice, "nacer_%02d" % frame)
		if capturar:
			await guardar_captura(indice, "activo")
		comprobar(efecto.semiejes().is_equal_approx(tam), receta[0] + ": conserva los ejes")
		if receta[1] == "agua" and receta[2] == 3:
			comprobar(efecto.has_node("Cuerpo/Membrana"), "barrera tiene membrana")
			efecto.golpe_en(efecto.to_global(Vector3(tam.x * 0.866, tam.y * 0.5, 0)))
			await process_frame
			comprobar(efecto._golpe_edad < 0.1, "contacto dispara onda local")
			if capturar:
				for frame in 6:
					await process_frame
				await guardar_captura(indice, "golpe")
		if receta[1] == "agua" and receta[2] == 1:
			comprobar(efecto.has_node("Cuerpo/RastroTrasero"), "ola: estructura anterior restaurada")
			comprobar(is_equal_approx(efecto._ap.get_animation("nacer").length, 1.65), "ola: nacimiento gradual de 1,65 s")
			comprobar(alturas_nacer.size() == 3 and alturas_nacer[0] > 0.0 and alturas_nacer[0] < alturas_nacer[1] and alturas_nacer[1] < alturas_nacer[2] and alturas_nacer[2] < 1.0, "ola: crecimiento paulatino después del retardo")
			comprobar(efecto.has_node("Cuerpo/NacimientoOla") and efecto._ola_cresta != null, "ola: nacimiento y cresta anteriores restaurados")
			var reloj_antes: float = efecto._ola_reloj
			for frame in 12:
				await process_frame
			comprobar(efecto._ola_reloj > reloj_antes + 0.3, "ola: movimiento avanza con el tiempo del efecto")
			var mat: ShaderMaterial = efecto._ola_cresta.material_override
			comprobar(is_equal_approx(float(mat.get_shader_parameter("tiempo_ola")), efecto._ola_reloj), "ola: reloj del volumen sincronizado")
			if capturar:
				await guardar_captura(indice, "movimiento")
		if receta[1] == "magma":
			comprobar(efecto._bloques.size() > 0 and efecto._fuego == null, "magma persistente tiene cuerpo rocoso")
		var es_muro: bool = receta[1] == "agua" and receta[2] == 1
		var cuerpo_sin_encoger: bool = true
		var corte_continuo: bool = false
		efecto.morir()
		for frame in 100:
			await process_frame
			if es_muro and is_instance_valid(efecto):
				corte_continuo = corte_continuo or (efecto.corte > 0.2 and efecto.corte < 0.8)
				cuerpo_sin_encoger = cuerpo_sin_encoger and efecto._cuerpo.scale.is_equal_approx(Vector3.ONE)
			if capturar and frame in ([8, 20, 32, 44, 56, 64] if ronda3 or ronda5 else [8, 20, 32]):
				await guardar_captura(indice, "morir_%02d" % frame)
		comprobar(not is_instance_valid(efecto), receta[0] + ": libera al expirar")
		if es_muro:
			comprobar(corte_continuo, "ola: caída continua, con estados intermedios")
			comprobar(cuerpo_sin_encoger, "ola: el cuerpo conserva escala durante el colapso")
	await probar_viento_alto(escena)
	# Reconstruir una misma instancia ejercita el cambio de figura y referencias de nodos.
	var agua := Agua.new()
	escena.add_child(agua)
	for fig in [3, 2, 1, 3]:
		agua.definir(fig, 1, 1.5, 1)
		await process_frame
	agua.queue_free()
	await process_frame
	var lab := Lab.new()
	root.add_child(lab)
	await process_frame
	lab._param.definir(3, 2.1, 1.7, 1.8)
	lab.mejoras = false
	lab.mostrar_revision(true)
	comprobar(lab._param.semiejes().is_equal_approx(Vector3(2.1, 1.7, 1.8)), "comparación conserva dimensiones ajustadas")
	comprobar(lab._param.get_script() == load("res://presentacion/vfx/toy/agua_toy.gd"), "antes usa el efecto original")
	lab.mejoras = true
	lab.mostrar_revision(true)
	comprobar(lab._param.get_script() == Agua, "después usa la variante experimental")
	lab.receta_revision = 6
	lab.mostrar_revision()
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_F8
	tecla.pressed = true
	lab._unhandled_input(tecla)
	comprobar(lab._param is FuegoToy and lab._param.semiejes().is_equal_approx(Vector3(3.45, 1.5, 0.3)), "F8 compara fuego con magma a la misma escala")
	lab._unhandled_input(tecla)
	comprobar(lab._param.get_script() == Magma, "F8 vuelve al magma revisado")
	for i in Lab.RECETAS_REVISION.size():
		lab.receta_revision = i
		lab.mostrar_revision()
		await process_frame
	comprobar(is_instance_valid(lab._param), "laboratorio recorre las once recetas")
	lab.queue_free()
	await process_frame
	comprobar(errores.cantidad == 0, "sin errores de scripts, shaders ni motor")
	print("FALLOS: ", fallos)
	quit(1 if fallos else 0)

func guardar_captura(indice: int, fase: String) -> void:
	await RenderingServer.frame_post_draw
	var imagen: Image = root.get_texture().get_image()
	imagen.save_png("%s/%02d_%s.png" % [carpeta_capturas, indice, fase])

func probar_viento_alto(escena: Node3D) -> void:
	var original := preload("res://presentacion/vfx/toy/viento_corrientes.gd").new()
	var nuevo := preload("res://laboratorios/vfx_revision/viento_corrientes_revision.gd").new()
	escena.add_child(original)
	escena.add_child(nuevo)
	var ejes := Vector3(0.5, 4, 0.5)
	original.dibujar(&"PILAR", ejes, 0.1, 1.0, 1.0)
	nuevo.dibujar(&"PILAR", ejes, 0.1, 1.0, 1.0)
	comprobar(nuevo._trazos.size() >= original._trazos.size() + 12, "viento alto: más líneas que la referencia")
	nuevo._trazos.clear()
	nuevo._hilos_rapidos(ejes, 0.1, 1.0)
	var y_inicial: float = nuevo._trazos[0]["puntos"][0].y
	nuevo._trazos.clear()
	nuevo._hilos_rapidos(ejes, 0.12, 1.0)
	comprobar(nuevo._trazos[0]["puntos"][0].y > y_inicial, "viento alto: trazos ascienden")
	var y_pleno: float = nuevo._trazos[0]["puntos"][0].y
	nuevo._trazos.clear()
	nuevo._hilos_rapidos(ejes, 0.12, 0.2)
	comprobar(is_equal_approx(nuevo._trazos[0]["puntos"][0].y, y_pleno), "viento alto: apagado conserva la altura")
	original.queue_free()
	nuevo.queue_free()
	await process_frame
