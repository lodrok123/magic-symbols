extends SceneTree
## Estados del cofre oculto → aparece → cerrado → abierto (Pipeline, 21/10; PLAN_EOW C3).
##   godot --headless --path . --script res://herramientas/prueba_cofre_estados.gd
## Se mide el estado, la visibilidad y las señales; no se mira a ojo.

var _fallos: int = 0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _initialize() -> void:
	await process_frame
	# Cofre sintético (sin el GLB de 7 MB): pieza > asa > cuerpo + tapa, que es la forma que busca `Cofre3D.preparar`. El cofre real lo cubre prueba_cofre_cerrado.gd.
	var pieza := Node3D.new()
	var asa := Node3D.new()
	var cuerpo := MeshInstance3D.new()
	cuerpo.name = "cofre_cuerpo"
	cuerpo.mesh = BoxMesh.new()
	var tapa := Node3D.new()
	tapa.name = "cofre_tapa"
	asa.add_child(cuerpo)
	asa.add_child(tapa)
	pieza.add_child(asa)
	root.add_child(pieza)
	await process_frame
	await process_frame
	var c: Cofre3D = Cofre3D.en(pieza)
	var apar: Array = [0]
	c.aparecido.connect(func() -> void: apar[0] += 1)

	_ok("A1 nace cerrado y visible", c.estado_nombre() == &"cerrado" and pieza.visible)
	c.ocultar()
	_ok("A2 ocultar(): estado oculto, pieza invisible", c.esta_oculto() and not pieza.visible and c.estado_nombre() == &"oculto")
	_ok("A3 oculto no se puede abrir", not c.abrir() and c.esta_oculto())
	_ok("A4 aparecer() arranca", c.aparecer())
	_ok("A5 apareciendo: visible ya, aún no abrible", pieza.visible and c.estado_nombre() == &"apareciendo" and not c.abrir())
	_ok("A6 aparecer() otra vez no repite", not c.aparecer())
	await create_timer(Cofre3D.T_APARECE + 0.2).timeout
	_ok("A7 acabó: cerrado, una sola señal `aparecido`", c.estado_nombre() == &"cerrado" and apar[0] == 1, "señales=%d" % apar[0])
	_ok("A8 el pop termina en su escala de reposo", asa.scale.is_equal_approx(Vector3.ONE), str(asa.scale))
	_ok("A9 y ahora sí se abre", c.abrir())
	await create_timer(1.3).timeout
	_ok("A10 abierto", c.esta_abierto() and c.estado_nombre() == &"abierto")

	# Restaurar desde el guardado.
	c.poner_estado(&"oculto")
	_ok("B1 poner_estado(oculto) desde abierto", c.esta_oculto() and not pieza.visible)
	c.aparecer_ya()
	_ok("B2 aparecer_ya(): cerrado, visible, sin señal nueva", c.estado_nombre() == &"cerrado" and pieza.visible and apar[0] == 1)
	c.aparecer_ya()
	_ok("B3 aparecer_ya() sobre algo no oculto no hace nada", c.estado_nombre() == &"cerrado")
	c.poner_estado(&"abierto")
	_ok("B4 poner_estado(abierto)", c.esta_abierto() and pieza.visible)
	c.poner_estado(&"disparate")
	_ok("B5 nombre desconocido: no cambia nada", c.esta_abierto())
	c.poner_estado(&"cerrado")
	_ok("B6 poner_estado(cerrado)", c.estado_nombre() == &"cerrado" and pieza.visible and not c.esta_abierto())

	# Ocultar mientras aparece no deja la señal colgada.
	c.ocultar()
	c.aparecer()
	c.ocultar()
	await create_timer(Cofre3D.T_APARECE + 0.2).timeout
	_ok("C1 ocultar() durante la aparición cancela el final (sigue oculto, sin señal)", c.esta_oculto() and not pieza.visible and apar[0] == 1, "señales=%d" % apar[0])
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
