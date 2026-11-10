extends "res://herramientas/escenario_base.gd"
## godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_catalogo_hechizos.gd


func _escenario() -> void:
	LabHechizos3D.cargar_al_abrir = false
	await cargar("res://laboratorios/LabHechizos3D.tscn")
	var lab := maqueta.get_node("Reglas") as LabHechizos3D
	_ok("el catálogo reúne los ocho elementos jugables", lab._elemento_catalogo.item_count == 8)
	colocar_jugador(Vector2i(4, 8))
	var origen: Vector3 = Terreno3D.centro_de(Vector2i(6, 8), 0.0)
	# Camino de uso: botón → apuntado real → soltar. La receta larga nace como plataforma.
	lab._elemento_catalogo.select(2)
	lab._elemento_catalogo.item_selected.emit(2)
	lab._receta_catalogo.select(lab._receta_catalogo.item_count - 1)
	lab.apuntar_catalogo()
	_ok("Apuntar abre la vista de lanzamiento y aparta el panel", lanzador.modo_lanzar and not lab._capa_catalogo.visible)
	if lanzador.modo_lanzar:
		lanzador._origen_fijo = origen
		lanzador._punto_vivo = origen + Vector3.RIGHT * Terreno3D.casilla
		lanzador._fijado = true
		lanzador._soltar()
		await avanzar(60)
		_ok("el puente duradero levanta cuatro casillas de suelo firme", Terreno3D.plataformas_tierra.size() == 4)
		_ok("al terminar de apuntar vuelve el panel", lab._capa_catalogo.visible)
		lab.limpiar_sala()
		await avanzar(1)
	var salidas: Array[int] = []
	lanzador.lanzado.connect(func(_el: String, _forma: String, n: int) -> void: salidas.append(n))
	for i in range(lab._elemento_catalogo.item_count):
		lab._elemento_catalogo.select(i)
		lab._elemento_catalogo.item_selected.emit(i)
		var id: String = lab._elemento_catalogo.get_item_metadata(i)
		for j in range(lab._receta_catalogo.item_count):
			var ficha: Dictionary = lab._fichas_catalogo[j]
			var datos: Dictionary = lab.datos_catalogo(ficha)
			var nombre := "%s · %s" % [id, ficha["nombre"]]
			var h: Hechizo = datos.get("hechizo")
			if h == null:
				_ok(nombre, false, "no construye la receta")
				continue
			salidas.clear()
			var desde: Vector3 = origen if h.en_punto else jugador.position
			var sale: bool = lanzador.lanzar_ahora(datos, desde, Vector3.RIGHT)
			_ok(nombre, sale and not salidas.is_empty() and salidas[0] > 0)
			lab.limpiar_sala()
			await avanzar(1)
	await avanzar(45)
	# Desmontar los efectos mientras la sala aún existe, para que puedan soltar sus VFX.
	for nodo in lanzador.get_children():
		if nodo is HechizoVivo:
			nodo.queue_free()
	await avanzar(2)
