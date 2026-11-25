extends SceneTree
const LAB = preload("res://laboratorios/lab_combustion_objetos.gd")
var fallos: int = 0
func comprobar(b: bool, mensaje: String) -> void:
	print("OK " if b else "FALLO ",mensaje)
	if not b: fallos += 1
func _initialize() -> void:
	call_deferred("correr")
func correr() -> void:
	var lab = LAB.new()
	root.add_child(lab)
	var agua := RuneData.new()
	agua.estado = "liquido"
	agua.modificadores = {"humedad":{"op":"fija","valor":1.0}}
	for r in lab.piezas:
		comprobar(r._combustion.focos.is_empty(),r.tipo+" no reserva llamas ni luces antes de prender")
	for r in lab.piezas:
		r.set_process(false)
		var c = r._combustion
		comprobar(c != null and not c.materiales.is_empty(),r.tipo+" materiales reales compatibles")
		var formas: Array[Node] = r.find_children("*","CollisionShape3D",true,false)
		var forma: Shape3D = formas[0].shape
		var capa: int = r.collision_layer
		var impacto: Vector3 = r.to_global(Vector3(-0.1,0.35,0.1))
		r.ignite(impacto)
		r.set_process(false)
		r._process(float(r._num_combustible()[0])*0.4)
		c._process(0.05)
		comprobar(c.ardiendo and is_equal_approx(c.progreso,0.4),r.tipo+" frente sincronizado con el reloj real")
		comprobar(c.focos.any(func(f: Node3D) -> bool: return f.visible),r.tipo+" llamas en la superficie")
		comprobar(forma == formas[0].shape and r.collision_layer == capa,r.tipo+" física intacta mientras arde")
		var quemado: float = c.progreso
		r.on_spell_hit(agua)
		comprobar(not c.ardiendo and c.calor == 0.0 and c.humedad == 1.0,r.tipo+" agua corta llama y deja humedad")
		comprobar(c.progreso == quemado and c.focos.all(func(f: Node3D)->bool:return not f.visible),r.tipo+" apagado conserva daño sin focos activos")
		comprobar(c.materiales[0].get_shader_parameter("combustion_calor") == 0.0,r.tipo+" brasas apagadas en el material")
		r.ignite(impacto)
		r.set_process(false)
		r._process(float(r._num_combustible()[0])*0.2)
		comprobar(c.progreso > quemado,r.tipo+" volver a prender continúa el frente")
		var origen: Vector3 = c.origen
		r.position += Vector3(2,0,1)
		r.rotation.y = 0.7
		r.scale = Vector3(1.3,0.8,1.1)
		c._process(0.01)
		comprobar(c.origen == origen and c.materiales[0].get_shader_parameter("combustion_espacio").is_equal_approx(c.global_transform.affine_inverse()),r.tipo+" el frente sigue traslación giro y escala")
		r._process(float(r._num_combustible()[0]))
		comprobar(r.estado == Reactivo3D.EstadoObj.CONSUMIDO and r.collision_layer == 0 and c.progreso == 1.0,r.tipo+" consumir libera el paso con el contrato existente")
	comprobar(root.get_node_or_null("RestosCombustion") != null,"La madera deja tablas carbonizadas visuales")
	var restos: Node3D = root.get_node("RestosCombustion")
	comprobar(restos.get_children().all(func(n: Node3D)->bool:return n.position.y > 0.035),"Las tablas caen desde encima del suelo")
	# Materiales entre objetos y duplicados posteriores no comparten el progreso.
	lab.reconstruir()
	var a = lab.piezas[0]._combustion
	var b = lab.piezas[1]._combustion
	comprobar(a.materiales[0] != b.materiales[0],"Materiales independientes por objeto")
	var decor: Node3D = Pieza3D.crear_visual("barril")
	comprobar(decor.find_children("*","MeshInstance3D",true,false)[0].get_active_material(0) is StandardMaterial3D,"El asset compartido no se modifica")
	decor.free()
	lab.free()
	print("TOTAL DE FALLOS: ",fallos)
	quit(1 if fallos else 0)
