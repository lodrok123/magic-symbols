extends SceneTree

const Flecha = preload("res://laboratorios/vfx_revision/flecha_agua_revision.gd")
const Lab = preload("res://laboratorios/lab_flecha_agua_3d.gd")
const Paleta = preload("res://presentacion/vfx/toy/agua_paleta.gd")
var fallos: int = 0

func comprobar(condicion: bool, mensaje: String) -> void:
	if not condicion:
		fallos += 1
		push_error(mensaje)

func _initialize() -> void:
	call_deferred("probar")

func probar() -> void:
	var e := Flecha.evaluar(2.46, false)
	var horizontal_inicio := Flecha.evaluar(1.4, true, 0.4, true)
	var horizontal_fin := Flecha.evaluar(2.39, true, 0.4, true)
	comprobar(is_equal_approx(horizontal_inicio.pos.y, horizontal_fin.pos.y) and horizontal_fin.pos.x > horizontal_inicio.pos.x, "El vuelo horizontal mantiene la altura y avanza en X")
	var frontal := Flecha.evaluar(2.46, true, 0.4, true)
	comprobar(frontal.escala.x < frontal.escala.y, "El contacto frontal comprime en X")
	comprobar(e.escala.y < 0.4 and e.escala.x > 0.4, "El impacto debe comprimir y ensanchar la masa")
	comprobar(e.charco_visible and e.corona_visible and e.bola_visible, "El deposito empieza durante la compresion")
	var v: Vector2 = Flecha.evaluar(4.0, false).ejes_charco
	var o: Vector2 = Flecha.evaluar(4.0, true).ejes_charco
	comprobar(is_equal_approx(v.x * v.y, o.x * o.y) and o.x > o.y, "El impacto oblicuo conserva el area del deposito")
	var grande: Vector2 = Flecha.evaluar(4.0, false, 0.6).ejes_charco
	comprobar(is_equal_approx(grande.x * grande.y / (v.x * v.y), pow(0.6 / 0.4, 3.0)), "El area escala con el volumen de la esfera")
	comprobar(Flecha.evaluar(8.0, false).vida > 0.99, "El charco persiste tras la salpicadura")
	comprobar(not Flecha.evaluar(10.95, false).charco_visible, "El deposito desaparece al terminar")
	var lab := Lab.new()
	lab.pausa = true
	root.size = Vector2i(1280, 720)
	root.add_child(lab)
	for efecto in lab.efectos:
		for material in [efecto.mat_agua, efecto.mat_corona, efecto.mat_charco, efecto.gotas.material_override, efecto.estela.material_override]:
			for clave in Paleta.uniforms():
				comprobar(material.get_shader_parameter(clave) == Paleta.uniforms()[clave], "Paleta del proyecto compartida: " + clave)
			for clave in ["causticas", "flujo"]:
				comprobar(material.get_shader_parameter(clave) is Texture2D, "Textura de agua del proyecto: " + clave)
	for t in [0.7, 1.8, 2.46, 2.65, 3.4, 6.0, 10.99, 0.0]:
		lab.poner_tiempo(t)
		await process_frame
		await process_frame
		for efecto in lab.efectos:
			comprobar(efecto.bola.visible == efecto.ultimo_estado.bola_visible, "Visibilidad de la esfera al cambiar tiempo")
			comprobar(efecto.charco.visible == efecto.ultimo_estado.charco_visible, "Visibilidad del deposito al cambiar tiempo")
			if t >= Flecha.T_CHOQUE:
				comprobar(efecto.bola.basis.y.normalized().is_equal_approx(Vector3.UP), "La compresion restablece los ejes del contacto")
			if t >= 6.0 or t == 0.0:
				comprobar(efecto.gotas.multimesh.visible_instance_count == 0, "No deben quedar gotas antiguas al retroceder/repetir")
		if OS.get_cmdline_user_args().has("--capturas") and t > 0.0 and t < 7.0:
			await RenderingServer.frame_post_draw
			var carpeta := "res://docs/capturas/vfx_revision_2026-11-19/flecha_agua"
			DirAccess.make_dir_recursive_absolute(carpeta)
			var ruta := "%s/tiempo_%04d.png" % [carpeta, int(t * 100)]
			var error := root.get_texture().get_image().save_png(ruta)
			comprobar(error == OK, "Guardar captura " + ruta)
	if OS.get_cmdline_user_args().has("--capturas"):
		lab.vista = 2
		lab.distancia = 7.0
		lab._actualizar_camara()
		lab.panel.visible = false
		for t in [0.4, 1.0, 1.8, 2.48, 2.65, 2.85, 4.0]:
			lab.poner_tiempo(t)
			await process_frame
			await RenderingServer.frame_post_draw
			var ruta := "res://docs/capturas/vfx_revision_2026-11-19/flecha_agua/cerca_%04d.png" % int(t * 100)
			comprobar(root.get_texture().get_image().save_png(ruta) == OK, "Guardar captura cercana")
		(lab.suelo.material_override as ShaderMaterial).set_shader_parameter("oscuro", 1.0)
		for t in [1.0, 1.8, 2.65, 4.0]:
			lab.poner_tiempo(t)
			await process_frame
			await RenderingServer.frame_post_draw
			var ruta := "res://docs/capturas/vfx_revision_2026-11-19/flecha_agua/oscuro_%04d.png" % int(t * 100)
			comprobar(root.get_texture().get_image().save_png(ruta) == OK, "Guardar captura con suelo oscuro")
	# Volver desde vuelo/impacto a nacimiento no debe conservar la cola.
	for radio in [0.2, 0.4, 0.65]:
		lab.radio = radio
		lab.reconstruir()
		for t in [1.8, 2.65, 0.4, 2.39, 2.48, 10.99, 0.0]:
			lab.poner_tiempo(t)
			for efecto in lab.efectos:
				var cola: float = efecto.mat_agua.get_shader_parameter("cola")
				comprobar(cola > 2.0 if t == 1.8 else cola >= 0.0, "La cola continua debe crecer durante el vuelo")
				if t < Flecha.T_SUELTA or t >= Flecha.T_CHOQUE:
					comprobar(is_zero_approx(cola), "No queda cola al retroceder o terminar el vuelo")
				comprobar(efecto.bola.transform.is_finite(), "Transformacion finita en todos los radios")
				for i in efecto.gotas.multimesh.visible_instance_count:
					var tr: Transform3D = efecto.gotas.multimesh.get_instance_transform(i)
					comprobar(tr.is_finite() and tr.origin.y > 0.0, "Las gotas activas deben estar por encima del suelo")
		await process_frame
	print("Flecha agua: %d fallos" % fallos)
	lab.queue_free()
	await process_frame
	quit(0 if fallos == 0 else 1)
