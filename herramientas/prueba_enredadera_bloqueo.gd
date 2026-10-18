extends SceneTree

## PRUEBA DE LA VARIANTE «BLOQUEO» DE ENREDADERA3D (16/10, Juego). Sin ventana: `godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_enredadera_bloqueo.gd`.
## Comprueba, con la lámina real (bosque_ruinas.glb), que el matorral usa las piezas de PiezaBosque3D a su medida, que ardiendo sigue verde, que al
## quemarse cambia al quemado MÁS BAJO y deja los restos, y que al deshacerse todo desaparece. No comprueba el aspecto.

var fallos: int = 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  OK  ", msg)
	else:
		fallos += 1
		print("  FALLO  ", msg)


func _init() -> void:
	var e := Enredadera3D.new()
	root.add_child(e)
	e.preparar(null, 2.2, "bloqueo")
	var viva: MeshInstance3D = e._viva
	var quemada: MeshInstance3D = e._quemada
	_ok(viva != null and quemada != null, "la variante bloqueo crea el vivo y el quemado")
	if viva == null or quemada == null:
		quit(1)
		return
	_ok(absf(viva.get_aabb().size.x - 2.2) < 0.01 and absf(quemada.get_aabb().size.x - 1.83) < 0.01, "medidas de la lámina: vivo 2,2 y quemado 1,83 de ancho (%.2f, %.2f)" % [viva.get_aabb().size.x, quemada.get_aabb().size.x])
	_ok(e._restos.size() == 3 and not (e._restos[0] as Node3D).visible, "hay 3 restos y empiezan ocultos")
	e.brotar()
	await create_timer(1.0).timeout
	_ok(e.fase == Enredadera3D.Fase.VIVA and viva.visible and not quemada.visible, "tras brotar está viva (verde)")
	e.quemar()
	await create_timer(1.0).timeout
	_ok(e.fase == Enredadera3D.Fase.ARDIENDO and viva.visible and not quemada.visible, "ardiendo sigue siendo la verde")
	await create_timer(2.0).timeout
	_ok(e.fase == Enredadera3D.Fase.QUEMADA and quemada.visible and not viva.visible, "quemada: se ve el quemado")
	var todos: bool = true
	for r in e._restos:
		todos = todos and (r as Node3D).visible
	_ok(todos, "al quemarse aparecen los restos y la ceniza")
	await create_timer(4.0).timeout
	_ok(not is_instance_valid(e), "pasado el tiempo se deshace y se borra sola")
	# Escalada: a ancho 1,1 el vivo mide la mitad
	var e2 := Enredadera3D.new()
	root.add_child(e2)
	e2.preparar(null, 1.1, "bloqueo")
	var m2: Node3D = e2._viva.get_parent()
	_ok(absf(m2.scale.x - 0.5) < 0.001, "ancho 1,1 → escala 0,5 (el ancho es el del vivo en el mundo)")
	# Las variantes de siempre no cambian
	var e3 := Enredadera3D.new()
	root.add_child(e3)
	e3.preparar(null, 1.3, "")
	_ok(e3._restos.is_empty(), "la enredadera normal no lleva restos")
	print("FALLOS: ", fallos)
	quit(1 if fallos > 0 else 0)
