extends VientoToy

func _construir() -> void:
	super._construir()
	if figura != Figura.PILAR or _corrientes == null:
		return
	var padre := _corrientes.get_parent()
	padre.remove_child(_corrientes)
	_corrientes.free()
	_corrientes = preload("res://laboratorios/vfx_revision/viento_corrientes_revision.gd").new()
	padre.add_child(_corrientes)

func _actualizar_corrientes(delta: float) -> void:
	super._actualizar_corrientes(delta)
	# Las hojas y las cintas comparten el eje ascendente incluso con mucho radio.
	if figura == Figura.PILAR and _hojas != null:
		for hoja in _hojas._s:
			if hoja is Dictionary and hoja.has("v"):
				var v: Vector3 = hoja["v"]
				v.y = maxf(v.y, semieje_y * 0.8 * aparicion)
				hoja["v"] = v
