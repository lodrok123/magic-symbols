extends SceneTree

## PRUEBA DE LA MANO QUE ESCRIBE EN EL LIBRO (16/10, Juego): `spellbook.gd` crea la mano (3D si hay GLB, si no 2D), la enseña al abrir y la esconde al
## cerrar, le da la escala del libro, le pasa cada fotograma el punto (el ÚLTIMO del trazo imantado mientras se dibuja) y recorta la tinta del trazo
## en curso hasta la punta. Sin ventana: `tools\prueba_una.cmd prueba_mano_libro`.
## NO comprueba el aspecto ni el renderizado de la 3D (eso lo mide `prueba_mano_pluma_3d`, que necesita renderizador).

var fallos: int = 0


func _init() -> void:
	Estado.nuevo()
	Repertoire.libro = "bosque"
	var libro: Control = load("res://presentacion/ui/spellbook.gd").new()
	libro.size = Vector2(1280.0, 720.0)
	libro.process_mode = Node.PROCESS_MODE_ALWAYS          # como en la escena: el libro sigue vivo con el árbol en pausa
	root.add_child(libro)
	await process_frame
	var mano: ManoPluma2D = libro.mano
	_ok(mano != null and mano.get_parent() == libro, "1 el libro tiene su mano como hijo")
	_ok(mano.z_index == 100, "1 y va por encima de los trazos (z_index 100)")
	_ok(not mano.visible, "1 con el libro cerrado no se ve")
	_ok((mano is ManoPluma3D) == ManoPluma3D.disponible(), "1 es la 3D si hay GLB y la 2D si no (aquí: %s)" % ("3D" if mano is ManoPluma3D else "2D"))

	# --- Abrir ---
	libro._open()
	_ok(libro.is_open and mano.visible, "2 al abrir el libro la mano se ve")
	var relativa: float = libro._book_rect().size.x / libro.BOOK_SIZE.x
	var esperada: float = relativa if mano is ManoPluma3D else ManoPluma2D.new().escala * relativa
	_ok(absf(mano.escala - esperada) < 0.0001, "2 la escala sigue al tamaño del libro (%.3f, esperada %.3f)" % [mano.escala, esperada])

	# --- Cambia el tamaño de la ventana: la escala la acompaña ---
	libro.size = Vector2(960.0, 540.0)
	await process_frame
	var relativa2: float = libro._book_rect().size.x / libro.BOOK_SIZE.x
	var esperada2: float = relativa2 if mano is ManoPluma3D else ManoPluma2D.new().escala * relativa2
	_ok(relativa2 < relativa and absf(mano.escala - esperada2) < 0.0001, "3 a 960 × 540 la escala baja con el libro (%.3f → %.3f)" % [relativa, mano.escala])

	# --- Dibujando: la mano va al último punto del trazo imantado, y no al ratón ---
	var c: Vector2 = libro._center()
	libro.is_drawing = true
	libro.stroke = PackedVector2Array([c, c + Vector2(40.0, 0.0), c + Vector2(80.0, 10.0)])
	libro.stroke_visible = PackedVector2Array([c, c + Vector2(40.0, 0.0), c + Vector2(80.0, 10.0)])
	for i in range(20):
		await process_frame
	_ok(mano.pose == ManoPluma2D.Pose.ESCRIBIENDO, "4 dibujando, la mano está en pose ESCRIBIENDO")
	_ok(mano.punta().distance_to(c + Vector2(80.0, 10.0)) < 1.0, "4 la punta llega al último punto del trazo (%s, esperado %s)" % [str(mano.punta()), str(c + Vector2(80.0, 10.0))])
	libro.is_drawing = false
	libro.stroke = PackedVector2Array()
	libro.stroke_visible = PackedVector2Array()
	for i in range(10):
		await process_frame
	_ok(mano.pose != ManoPluma2D.Pose.ESCRIBIENDO, "5 al soltar, la mano se levanta (pose %d)" % mano.pose)

	# --- La tinta se recorta hasta la punta (pura) ---
	var recta := PackedVector2Array()
	for i in range(11):
		recta.append(Vector2(i * 10.0, 0.0))
	var r1: PackedVector2Array = libro._tinta_hasta_punta(recta, Vector2(55.0, 0.0))
	_ok(r1[r1.size() - 1].is_equal_approx(Vector2(55.0, 0.0)) and r1.size() == 7, "6 la tinta acaba en la punta si va por detrás del final (acaba en %s, %d puntos)" % [str(r1[r1.size() - 1]), r1.size()])
	var r2: PackedVector2Array = libro._tinta_hasta_punta(recta, Vector2(150.0, 0.0))
	_ok(r2[r2.size() - 1].is_equal_approx(Vector2(100.0, 0.0)), "6 si la punta va por delante del final, la tinta no se alarga (acaba en %s)" % str(r2[r2.size() - 1]))
	var r3: PackedVector2Array = libro._tinta_hasta_punta(recta, Vector2(55.0, 20.0))
	_ok(r3[r3.size() - 1].is_equal_approx(Vector2(55.0, 0.0)), "6 una punta algo apartada se proyecta sobre el trazo (acaba en %s)" % str(r3[r3.size() - 1]))
	var una := PackedVector2Array([Vector2(3.0, 4.0)])
	_ok(libro._tinta_hasta_punta(una, Vector2.ZERO) == una, "6 con un solo punto no hace nada")
	# El tamaño original no se toca: el trazo REAL sigue entero (solo se recorta lo que se pinta).
	_ok(recta.size() == 11, "6 y el trazo de entrada no se modifica")

	# --- Cerrar ---
	libro.is_open = true
	libro.visible = true
	get_root().get_tree().paused = true
	libro._close()
	_ok(not mano.visible, "7 al cerrar el libro la mano se esconde")
	_ok(not get_root().get_tree().paused, "7 y el árbol vuelve a correr")

	print("FALLOS: %d" % fallos)
	quit(1 if fallos > 0 else 0)


func _ok(bien: bool, nombre: String) -> void:
	if bien:
		print("  OK  ", nombre)
	else:
		fallos += 1
		print("  FALLO  ", nombre)
