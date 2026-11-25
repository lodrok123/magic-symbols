extends Node3D
## Prueba con assets reales. 1 prende, 2 apaga con agua, 3 reconstruye las piezas.
const FABRICA = preload("res://presentacion/prueba_test2.gd")
class CombustiblePrueba extends Reactivo3D:
	# El laboratorio no tiene mapa donde colocar recogibles. Registrar el botín
	# conserva la prueba de consumo sin pedir alturas a un Terreno3D inexistente.
	func _soltar(lista: Array) -> void:
		soltado = lista
var piezas: Array[Reactivo3D] = []
var fx: Vfx3D
var cam: Camera3D
var etiqueta: Label

func _ready() -> void:
	Ocluso3D.preparar()
	fx = Vfx3D.new()
	add_child(fx)
	var entorno := WorldEnvironment.new()
	entorno.environment = Environment.new()
	entorno.environment.background_mode = Environment.BG_COLOR
	entorno.environment.background_color = Color(0.10,0.13,0.16)
	entorno.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.environment.ambient_light_color = Color(0.75,0.82,0.91)
	entorno.environment.ambient_light_energy = 0.65
	add_child(entorno)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-45,-25,0)
	sol.light_energy = 0.85
	sol.shadow_enabled = true
	add_child(sol)
	var suelo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(30,30)
	suelo.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.24,0.28,0.23)
	suelo.material_override = mat
	add_child(suelo)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 6.6
	cam.position = Vector3(2.5,4.2,7.0)
	add_child(cam)
	cam.look_at(Vector3(0,0.9,0))
	etiqueta = Label.new()
	etiqueta.position = Vector2(18,14)
	etiqueta.add_theme_font_size_override("font_size",23)
	etiqueta.add_theme_constant_override("outline_size",5)
	etiqueta.text = "COMBUSTION / telaraña y barril de madera\n1 Fuego · 2 Agua · 3 Reiniciar"
	add_child(etiqueta)
	reconstruir()

func reconstruir() -> void:
	for r in piezas:
		if not is_instance_valid(r): continue
		remove_child(r)
		r.free()
	piezas.clear()
	var fabrica = FABRICA.new()
	var red := Node3D.new()
	if fabrica._cargar_telarana():
		var sana: MeshInstance3D = fabrica._parte_telarana("sana",fabrica.TELARANA_ESCALA_RED,false)
		sana.position.y += 1.15
		red.add_child(sana)
	else:
		red.add_child(Formas3D.instancia("telarana",Color.WHITE))
	fabrica.free()
	var barril: Node3D = Pieza3D.crear_visual("barril")
	for i in 2:
		var r := CombustiblePrueba.new()
		var visual: Node3D = red if i == 0 else barril
		r.add_child(visual)
		# El barril de madera prueba el contrato del tronco; el explosivo Barril3D
		# conserva su mecha, tiempos y calavera en los niveles.
		r.preparar("telarana" if i == 0 else "tronco",Vector2i(i*10,0),"",fx,visual)
		r.position.x = -1.6 if i == 0 else 1.35
		add_child(r)
		piezas.append(r)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_3:
		reconstruir()
		return
	for r in piezas:
		if not is_instance_valid(r): continue
		if event.keycode == KEY_1: r.ignite(r.global_position+Vector3(-0.15,0.35,0.15))
		if event.keycode == KEY_2 and r.esta_ardiendo(): r._apagar()
