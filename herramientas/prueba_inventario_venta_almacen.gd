extends SceneTree
## Playtest 14/11: mochila +4, vender en la tienda y el cofre mágico (almacén compartido).
##   godot --headless --path . --script res://herramientas/prueba_inventario_venta_almacen.gd

var _fallos := 0
var _f := 0


func _ok(c: bool, t: String) -> void:
	print(("OK    " if c else "FALLO ") + t)
	if not c:
		_fallos += 1


func _initialize() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	change_scene_to_file("res://escenas/PruebaBosque02.tscn")


func _process(_d: float) -> bool:
	_f += 1
	if _f < 150:
		return false
	var e := Estado.i()
	# 1. Mochila
	_ok(Estado.CAPACIDAD_INICIAL == 12 and Estado.CAPACIDAD_MAX == 24, "1.1 la mochila empieza con 12 huecos y llega a 24")
	var viejo := {"bolsa": {"capacidad": 8, "oro": 0, "items": {}}}
	e.desde_dic(viejo)
	_ok(e.capacidad == 12, "1.2 una partida guardada con 8 huecos sube a 12 (%d)" % e.capacidad)
	_ok(MenuPestanas.COLUMNAS * MenuPestanas.FILAS == Estado.CAPACIDAD_MAX, "1.3 la rejilla del menú dibuja los 24 huecos")
	# 2. Vender
	e.items = {}
	e.oro = 0
	e.agregar("seta", 5)
	var p := Tiendas.precio_venta("seta")
	_ok(p >= 1, "2.1 la seta se vende (%d de oro la unidad)" % p)
	_ok(Tiendas.vender("alquimista", "seta", 3) and e.cuenta("seta") == 2 and e.oro == p * 3, "2.2 vender 3 setas paga %d y deja 2" % (p * 3))
	_ok(not Tiendas.vender("alquimista", "seta", 5), "2.3 no se venden más de las que hay")
	_ok(Tiendas.precio_venta("atuendo_sumicio") == 0, "2.4 el uniforme (categoría clave) no se vende")
	var ui := TiendaUI.new()
	root.add_child(ui)
	ui.abrir("alquimista")
	ui.cambiar_modo(true)
	_ok(ui.vendiendo and ui.oferta().size() == 1 and String(ui.oferta()[0]["objeto"]) == "seta", "2.5 la pestaña Vender lista lo que lleva la jugadora")
	ui.comprar()
	_ok(e.cuenta("seta") == 1, "2.6 el botón de la pestaña Vender vende")
	ui.cerrar()
	# 3. Cofre mágico
	_ok(get_nodes_in_group("cofre_magico").size() == 2, "3.1 Bosque 02 tiene dos cofres mágicos (linde y sendero norte)")
	e.agregar("baya", 7)
	_ok(e.guardar_en_almacen("baya", 7) == 7 and e.cuenta("baya") == 0 and e.en_almacen("baya") == 7, "3.2 se guardan 7 bayas en el cofre mágico")
	_ok(e.sacar_de_almacen("baya", 3) == 3 and e.cuenta("baya") == 3, "3.3 se sacan 3")
	var d := e.a_dic()
	e.almacen = {}
	e.desde_dic(d)
	_ok(e.en_almacen("baya") == 4, "3.4 el cofre mágico se guarda con la partida")
	_ok(Estado.ALMACEN_HUECOS == 50, "3.5 el cofre mágico tiene 50 huecos")
	var al := AlmacenUI.abrir_en(self)
	_ok(al.abierta and paused, "3.6 el cofre mágico abre su pantalla y pausa el mundo")
	al.cerrar()
	_ok(not paused, "3.7 al cerrarlo se reanuda")
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)
	return true
