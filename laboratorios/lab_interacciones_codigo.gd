extends Node3D
## Banco visual de efectos existentes y nuevos. Flechas cambian muestra; R repite.
const F = preload("res://presentacion/feedback_objeto_3d.gd")
const TITULOS = ["Cristal en reposo","Cristal cargado","Carga a punto de agotarse","Nexo electrificado","Puerta congelada","Metal caliente","Nido: cae pluma","Nido: todavía en espera","Arbusto recolectado","Veta agotada","Cuenco lleno","Cuenco: vapor","Canal y bordes húmedos","Ondas de flotación","Placa con peso","Compuerta en movimiento","Caja: tablas al romper","Escarcha desprendida"]
class Carga extends Node3D:
	var celda := Vector2i.ZERO
	var peso_valor: int = 3
var indice: int = 0
var escenario: Node3D
var muestra: Node3D
var cam: Camera3D
var etiqueta: Label

func _ready() -> void:
	Terreno3D.cargar_datos(PackedStringArray(["..........","..........","..........","..........","..........",".........."]),{})
	Terreno3D.alto_suelo = 0.0
	Estado.nuevo()
	Flags.nuevo()
	Ocluso3D.preparar()
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.12,0.16,0.20)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.78,0.83,0.9)
	we.environment.ambient_light_energy = 0.65
	add_child(we)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-42,-28,0)
	sol.light_energy = 0.8
	add_child(sol)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(cam)
	etiqueta = Label.new()
	etiqueta.position = Vector2(14,12)
	etiqueta.add_theme_font_size_override("font_size",22)
	etiqueta.add_theme_constant_override("outline_size",5)
	add_child(etiqueta)
	mostrar(0)

func poner(n: Node3D) -> Node3D:
	escenario.add_child(n)
	return n

func mostrar(numero: int) -> void:
	indice = posmod(numero,TITULOS.size())
	if is_instance_valid(escenario):
		remove_child(escenario)
		escenario.free()
	escenario = Node3D.new()
	add_child(escenario)
	muestra = null
	match indice:
		0,1,2:
			var c := CristalPulso3D.new()
			c.cada = 0
			poner(c)
			c.set_process(false)
			c.cargado_s = 20.0 if indice==1 else (1.0 if indice==2 else 0.0)
			c._process(0.01)
			muestra = c
		3:
			var n := NexoRayo3D.new()
			poner(n)
			n.mojar()
			n.set_process(false)
			n._feedback.estado(1,0,0,1) # muestra de alimentación; en partida la decide EmisorRayo
			muestra = n
		4,17:
			var r := Reactivo3D.new()
			var visual: Node3D = Pieza3D.crear_visual("puerta_goblin")
			r.add_child(visual)
			r.preparar("puerta_goblin",Vector2i.ZERO,"",null,visual)
			poner(r)
			r._poner_congelado(true)
			r._process(0.1)
			r.set_process(false)
			if indice==17: F.rafaga(escenario,Vector3(0,0.7,0),"escarcha",Color(0.65,0.85,1.0),8)
			muestra = r
		5:
			muestra = poner(PiezaFuego3D.crear("caldera_cuerpo"))
			var f = F.instalar(muestra,muestra)
			f.estado(0,0,0.9)
		6,7:
			var n := Nido3D.new()
			poner(n)
			n.sacudir(100)
			if indice == 7:
				for hijo in escenario.get_children():
					if hijo != n: hijo.free()
				n.sacudir(100.1)
			muestra = n
		8:
			var r := Recolectable3D.new()
			r.preparar(Vector2i.ZERO,"",0,null,"bayas")
			poner(r)
			r.position = Vector3.ZERO
			r.recoger()
			muestra = r
		9:
			var veta := VetaPulso3D.new()
			veta.preparar([Vector2i.ZERO],[],0,true,"lab_codigo")
			poner(veta)
			veta.picar(load("res://nucleo/earth_rune.tres"))
			muestra = veta
		10,11:
			var r := Reactivo3D.new()
			var fx := Vfx3D.new()
			poner(fx)
			r.preparar("cuenco",Vector2i.ZERO,"",fx,null)
			poner(r)
			if indice==10: r.brotar()
			else: r._vaporizar()
			muestra = r
		12:
			var canal := Canal3D.new()
			poner(canal)
			canal.configurar([Vector3(-0.6,0,-0.4),Vector3(0.6,0,0.4)],Vector3.RIGHT)
			canal.llenar()
			muestra = canal
		13:
			var flotador := Flotador3D.new()
			flotador.freeze = true
			poner(flotador)
			F.rafaga(escenario,Vector3(0,0.06,0),"onda",Color(0.5,0.75,0.9),3,2.0)
			muestra = flotador
		14:
			var c := Carga.new()
			poner(c)
			c.add_to_group("peso")
			var p := Pulsador3D.new()
			p.modo = "presencia"
			p.peso_min = 2
			poner(p)
			p.pulsar()
			muestra = p
		15:
			var c := Compuerta3D.new()
			c.preparar(Vector2i.ZERO)
			poner(c)
			c.position = Vector3.ZERO
			c.abrir()
			muestra = c
		16:
			var c := Rompible3D.new()
			c.preparar(Vector2i.ZERO,"caja","nada",0,false,"lab_codigo")
			poner(c)
			c.position = Vector3.ZERO
			c.romper()
			muestra = c
	etiqueta.text = "%02d / %s\nFlechas: cambiar · R: repetir" % [indice+1,TITULOS[indice]]
	var caja: AABB = Pieza3D._caja(muestra,Transform3D.IDENTITY)
	var centro: Vector3 = caja.get_center()
	cam.size = clampf(maxf(caja.size.x,maxf(caja.size.y,caja.size.z))*1.55,1.3,4.0)
	if indice in [0,1,2]:
		cam.size = 2.5
		centro = Vector3(0,0.75,0)
	cam.position = centro+Vector3(0.4,0.55,1.0).normalized()*12
	cam.look_at(centro)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_RIGHT: mostrar(indice+1)
	elif event.keycode == KEY_LEFT: mostrar(indice-1)
	elif event.keycode == KEY_R: mostrar(indice)
