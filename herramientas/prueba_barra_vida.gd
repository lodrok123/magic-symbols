extends SceneTree
## Gamefeel de la barra de vida de los goblins (15/10, Juego): invisible con la vida llena, aparece al primer golpe con el relleno en BLANCO
## un instante, y el trozo perdido se queda blanco `RETARDO_PERDIDA` s antes de vaciarse. Sin ventana ni modelo: un Combate3D suelto.
##   godot --headless --path . --script res://herramientas/prueba_barra_vida.gd

var _fallos: int = 0
const DT: float = 1.0 / 60.0


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _paso(c: Combate3D, segundos: float) -> void:
	for _i in range(int(round(segundos / DT))):
		c._dibujar_estado(DT)


func _initialize() -> void:
	var c := Combate3D.new()
	c._construir_barra()
	_paso(c, 0.1)
	_ok("1 con la vida llena la barra no se ve", not c._barra_fondo.visible and not c._barra_vida.visible and not c._barra_perdida.visible)
	c.receive_damage(30.0)
	_paso(c, DT)
	_ok("2 tras el golpe la barra aparece", c._barra_fondo.visible and c._barra_vida.visible)
	var col: Color = (c._barra_vida.material_override as StandardMaterial3D).albedo_color
	_ok("2 y el relleno se pone blanco", col.is_equal_approx(Color.WHITE), str(col))
	_paso(c, Combate3D.DESTELLO_BARRA + 0.05)
	col = (c._barra_vida.material_override as StandardMaterial3D).albedo_color
	_ok("3 pasado el destello vuelve a su color de vida (verde a 70 %)", not col.is_equal_approx(Color.WHITE) and col.g > col.r, str(col))
	_ok("4 el trozo perdido se queda: 100 % mientras espera", is_equal_approx(c._vida_mostrada, 1.0), "%.3f" % c._vida_mostrada)
	_paso(c, Combate3D.RETARDO_PERDIDA)
	_paso(c, 0.5)
	_ok("5 después se vacía hacia la vida real (0,70)", c._vida_mostrada < 0.75 and c._vida_mostrada >= 0.70 - 1e-4, "%.3f" % c._vida_mostrada)
	_paso(c, 0.5)
	_ok("6 la barra sigue visible aunque no haya golpes nuevos (vida < 100 %)", c._barra_vida.visible)
	c.health = c.vida_max
	_paso(c, 0.1)
	_ok("7 curado del todo vuelve a esconderse", not c._barra_fondo.visible)
	c.free()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
