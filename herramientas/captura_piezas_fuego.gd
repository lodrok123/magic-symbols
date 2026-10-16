extends SceneTree
## Captura de PiezaFuego3D: todas las piezas con sus estados, en dos filas.
##   xvfb-run -a godot --rendering-driver opengl3 --path . --script res://herramientas/captura_piezas_fuego.gd -- salida.png
func _initialize() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var salida: String = args[0] if args.size() > 0 else "/tmp/piezas_fuego.png"
	var vp := SubViewport.new(); vp.size = Vector2i(2000, 1000); vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 11.0
	vp.add_child(cam); cam.position = Vector3(8.0, 10.0, 11.0); cam.look_at_from_position(cam.position, Vector3(8.0, 0.5, -1.5))
	cam.current = true
	var luz := DirectionalLight3D.new(); vp.add_child(luz); luz.rotation_degrees = Vector3(-50, 25, 0)
	var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.45, 0.62, 0.38)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.65, 0.65, 0.65)
	var we := WorldEnvironment.new(); we.environment = e; vp.add_child(we)
	var fila1: Array = [["cuerda_poste"], ["cuerda_tensa"], ["cuerda_cabo"], ["cuerda_caida"], ["contador_placa", 2], ["leno"], ["fogata_apagada"], ["fogata_lenos"], ["baldosa_falsa"]]
	var fila2: Array = [["caldera_hogar"], ["caldera_cuerpo", 0.0], ["caldera_cuerpo", 0.5], ["caldera_cuerpo", 1.0], ["caldera_medidor", 0.6], ["antorcha_pared", true], ["antorcha_pie", true],
		["goblin_escudo_entero", "entero"], ["goblin_escudo_entero", "ardiendo"], ["goblin_escudo_quemado"]]
	var filas: Array = [fila1, fila2]
	for r in 2:
		var x: float = 0.0
		for it in filas[r]:
			var p: PiezaFuego3D = PiezaFuego3D.crear(it[0])
			vp.add_child(p)
			var sitio := Vector3(x * 1.8 + 1.0, 0.0, -r * 5.2 + 1.4)
			p.position = sitio + (Vector3(0, 1.9, 0) if it[0] == "cuerda_tensa" or it[0] == "cuerda_cabo" else Vector3.ZERO) + (Vector3(0, 0.5, 0) if it[0].begins_with("goblin_escudo") else Vector3.ZERO)
			if it.size() > 1:
				match it[0]:
					"caldera_cuerpo", "caldera_medidor": p.poner_calor(float(it[1]))
					"contador_placa": p.poner_cuenta(int(it[1]))
					"antorcha_pared", "antorcha_pie": p.poner_llama(true)
					"goblin_escudo_entero": p.poner_estado(String(it[1]))
			x += 1.0
	for _i in 20:
		await process_frame
	await create_timer(0.3).timeout
	await process_frame
	vp.get_texture().get_image().save_png(salida)
	print("guardado ", salida)
	quit()
