extends SceneTree
## DIAGNÓSTICO del contorno claro en el agua del lab (sala 2, vista lab_sala2_cerca). NECESITA VENTANA.
##   godot --path . --script res://herramientas/captura_agua_diag.gd -- <carpeta>
## Mismo encuadre que captura_agua_eow.gd (lab sala2_cerca) y TIME congelado (Engine.time_scale ~ 0). Variantes A..G, cada una desde el estado de serie.
const S: float = 2.3
const VISTA: Array = [11.5, 3.0, 4.5]
const VARIANTES: Array = ["A_todo", "A2_repeticion", "B_sin_refraccion", "C_sin_guijarros", "D_sin_ssao", "E_sin_especular", "F_sin_lecho", "G_sin_espuma"]
var _m: Node3D = null
var _r: AguaRender3D = null
var _mat: ShaderMaterial = null
var _codigo: String = ""


func _initialize() -> void:
	_correr()


func _correr() -> void:
	var carpeta: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(carpeta)
	var f := FileAccess.open(carpeta.path_join(".gdignore"), FileAccess.WRITE)
	if f != null:
		f.close()
	var esc: PackedScene = load("res://laboratorios/LabPlaytestEoW.tscn")
	_m = esc.instantiate()
	root.add_child(_m)
	for _i in 150:
		await process_frame
	_ocultar_ui(root)
	_r = _m.get("_agua_render") as AguaRender3D
	_mat = _r.get("_mat") as ShaderMaterial
	_codigo = _mat.shader.code
	if Terreno3D.agua_sim != null:
		for cy in [2, 3, 4]:
			for cx in [13, 14]:
				Terreno3D.agua_sim.helar_casilla(Vector2i(cx, cy), true)
		for _i in 40:
			await process_frame
	_m.set("_jugador", null)
	_m.set("_foco", Vector3((VISTA[0] + 0.5) * S, 0.5, (VISTA[1] + 0.5) * S))
	_m.set("_tam_camara", VISTA[2])
	_m.get("_camara").size = VISTA[2]
	_m.call("_colocar_camara")
	for _i in 60:
		await process_frame
	var lecho: Node = _buscar(_m, "lecho_rio")
	print("lecho_rio: ", lecho, " hijos MultiMesh instancias: ", ((lecho as MultiMeshInstance3D).multimesh.instance_count if lecho != null else -1))
	var env: Environment = _m.get("_env") as Environment
	print("ssao antes: ", env.ssao_enabled if env != null else "sin env", " refraccion: ", _r.agua_refraccion)
	# Congela el tiempo: el TIME del shader y la simulación quedan quietos.
	Engine.time_scale = 0.00001
	for _i in 10:
		await process_frame
	for v in VARIANTES:
		_restaurar(lecho, env)
		match v:
			"B_sin_refraccion":
				_r.agua_refraccion = false
			"C_sin_guijarros":
				if lecho != null:
					(lecho as Node3D).visible = false
			"D_sin_ssao":
				if env != null:
					env.ssao_enabled = false
			"E_sin_especular":
				var sh := Shader.new()
				sh.code = _codigo.replace("SPECULAR = 0.5 * v_spec;", "SPECULAR = 0.0;").replace("* 0.5 * LIGHT_COLOR * ATTENUATION * v_spec;", "* 0.0 * LIGHT_COLOR * ATTENUATION * v_spec;")
				print("E: especular reemplazado: ", sh.code != _codigo)
				_mat.shader = sh
			"F_sin_lecho":
				_mat.set_shader_parameter("lecho", 0.0)
			"G_sin_espuma":
				_mat.set_shader_parameter("espuma_manchas", 5.0)
				_mat.set_shader_parameter("transicion_orilla", 0.0001)
				_mat.set_shader_parameter("menisco", 0.0)
				_mat.set_shader_parameter("caida_fuerza", 0.0)
		for _i in 12:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [carpeta, v])
		print("captura ", v)
	quit()


func _restaurar(lecho: Node, env: Environment) -> void:
	_r.agua_refraccion = true
	if lecho != null:
		(lecho as Node3D).visible = true
	if env != null:
		env.ssao_enabled = true
	_mat.shader = _r.get("_mat").shader if false else _mat.shader
	var sh := Shader.new()
	sh.code = _codigo
	_mat.shader = sh
	_mat.set_shader_parameter("lecho", 0.5)
	_mat.set_shader_parameter("espuma_manchas", 0.5)
	_mat.set_shader_parameter("transicion_orilla", 0.08)
	_mat.set_shader_parameter("menisco", 0.55)
	_mat.set_shader_parameter("caida_fuerza", 1.0)


func _buscar(n: Node, nombre: String) -> Node:
	if n.name == nombre:
		return n
	for h in n.get_children():
		var r := _buscar(h, nombre)
		if r != null:
			return r
	return null


func _ocultar_ui(n: Node) -> void:
	for h in n.get_children():
		if h is CanvasLayer and not (h is TiltShift3D) and h.name != "Vineta3D":
			(h as CanvasLayer).visible = false
		_ocultar_ui(h)
