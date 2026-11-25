extends Node3D
const B = preload("res://presentacion/estados_blender_3d.gd")
const ACTOR = preload("res://objetos/interaccion_blender_3d.gd")
const TITULOS = ["CRISTAL · Extraer esquirla","ROCA · Impactos sólidos","TOCÓN · Combustión","CALDERA · Abolladura","BARRIL · Abrir / cerrar"]
var indice:=0
var contenido: Node3D
var objeto: Node3D
var cam: Camera3D
var texto: Label
var fx: Vfx3D

func _ready() -> void:
	Ocluso3D.preparar(); Pieza3D._cargar_bibliotecas()
	Terreno3D.cargar_datos(PackedStringArray(["..........","..........","..........","..........",".........."]),{})
	Terreno3D.alto_suelo=0.0
	var we:=WorldEnvironment.new(); we.environment=Environment.new()
	we.environment.background_mode=Environment.BG_COLOR; we.environment.background_color=Color("23303b")
	we.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color=Color(0.85,0.9,1); we.environment.ambient_light_energy=0.65
	add_child(we)
	var luz:=DirectionalLight3D.new(); luz.rotation_degrees=Vector3(-48,-35,0); luz.light_energy=1.2; add_child(luz)
	cam=Camera3D.new(); cam.projection=Camera3D.PROJECTION_ORTHOGONAL; cam.size=3.7
	add_child(cam)
	texto=Label.new(); texto.position=Vector2(16,12); texto.add_theme_font_size_override("font_size",22)
	texto.add_theme_constant_override("outline_size",4); add_child(texto)
	mostrar(0)

func mostrar(i: int) -> void:
	indice=posmod(i,5)
	if is_instance_valid(contenido): contenido.free()
	Flags.nuevo(); Estado.nuevo()
	contenido=Node3D.new(); add_child(contenido)
	fx=Vfx3D.new(); contenido.add_child(fx)
	match indice:
		0:
			objeto=CristalPulso3D.new(); objeto.cada=0; objeto.nivel="lab_blender"
		1:
			objeto=MuroAgrietado3D.new(); objeto.modelo_id="roca_est_1"
			objeto.flag_dano="lab.roca.estado"; objeto.preparar(Vector2i(2,2),2)
		2:
			objeto=Reactivo3D.new(); objeto.set_meta("tocon","tocon"); objeto.flag_consumido="lab.tocon.consumido"
			var visual:=Pieza3D.crear_visual("tocon"); objeto.add_child(visual)
			objeto.preparar("tronco",Vector2i(2,2),"",fx,visual)
		_:
			objeto=ACTOR.new(); objeto.preparar(Vector2i(2,2),"caldera" if indice==3 else "barril_almacen","lab.actor.estado")
	contenido.add_child(objeto); objeto.position=Vector3.ZERO
	var foco:=Vector3(0,0.5 if indice in [0,1] else 0.3,0)
	cam.position=foco+Vector3(2.5,2.5,5); cam.look_at(foco)
	texto.text=TITULOS[indice]+"\n← → Elegir · ESPACIO Actuar · R Reiniciar"

func actuar() -> void:
	if not is_instance_valid(objeto): return
	match indice:
		0:
			objeto._contar_golpe(); objeto._contar_golpe(); objeto.destello=0; objeto._pintar()
		1:
			objeto.on_spell_hit(load("res://nucleo/earth_rune.tres"))
		2:
			objeto.ignite()
		3:
			objeto.on_spell_hit(load("res://nucleo/earth_rune.tres"))
		4:
			objeto.poner_abierto(not objeto.abierto)

func _unhandled_key_input(ev: InputEvent) -> void:
	if not ev is InputEventKey or not ev.pressed or ev.echo: return
	match ev.keycode:
		KEY_RIGHT: mostrar(indice+1)
		KEY_LEFT: mostrar(indice-1)
		KEY_R: mostrar(indice)
		KEY_SPACE: actuar()
