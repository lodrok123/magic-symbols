extends SceneTree
## Mide, pieza a pieza, cuánto ocupa la colisión vieja (caja del 80 % / casco convexo de todo el modelo) frente a la
## medida sobre el contorno (ColisionPieza). Sin ventana: godot --headless --path . -s res://herramientas/medir_contornos.gd
## Columnas (m²): cubierto = planta que el modelo cubre de verdad en la franja de paso; caja = forma_colision antigua;
## casco1 = un casco convexo de todo el modelo; nuevo = suma de los cascos medidos; libre = lo que bloquea de más.

func _init() -> void:
	var ids: Array = ColisionPieza.MODO.keys()
	ids.sort()
	print("id | modo | alto | cubierto | caja_vieja | casco1 | nuevo | n | libre_viejo(casco1) | libre_nuevo")
	var tot_v: float = 0.0
	var tot_n: float = 0.0
	for id in ids:
		var vis: Node3D = Pieza3D.crear_visual(id)
		if vis == null:
			print("%s | SIN MODELO" % id)
			continue
		var modo: String = ColisionPieza.modo(id)
		var tris: PackedVector3Array = ColisionPieza._triangulos(vis, Transform3D.IDENTITY)
		var alto: float = 0.0
		for p in tris:
			alto = maxf(alto, p.y)
		var rec: PackedVector3Array = ColisionPieza._recortar(tris, ColisionPieza.BANDA_MIN, ColisionPieza.BANDA_MAX)
		var celdas: Dictionary = ColisionPieza._planta(rec)
		var cubierto: float = celdas.size() * ColisionPieza.CELDA * ColisionPieza.CELDA
		var f: Dictionary = Pieza3D.forma_colision(id)
		var caja: float = 0.0
		if f.get("cilindro", false):
			caja = PI * float(f["radio"]) * float(f["radio"])
		else:
			caja = (f["tam"] as Vector3).x * (f["tam"] as Vector3).z
		var casco1: float = ColisionPieza._area_planta(rec)
		var lista: Array = ColisionPieza.cascos(vis, modo)
		var nuevo: float = 0.0
		for n in lista:
			nuevo += ColisionPieza._area_planta(n)
		print("%s | %s | %.2f | %.2f | %.2f | %.2f | %.2f | %d | %.2f | %.2f" % [id, modo, alto, cubierto, caja, casco1, nuevo, lista.size(), maxf(casco1 - cubierto, 0.0), maxf(nuevo - cubierto, 0.0)])
		tot_v += maxf(casco1 - cubierto, 0.0)
		tot_n += maxf(nuevo - cubierto, 0.0)
		vis.free()
	print("TOTAL libre bloqueado de más: casco1 %.2f m² → nuevo %.2f m²" % [tot_v, tot_n])
	quit()
