extends SceneTree
## Prueba del recorrido de Monte Sumicio (13/11/2026): salida norte de Bosque 02, encargo de Marimanta y runa de agua.
##   godot --headless --path . --script res://herramientas/prueba_encargo_marimanta.gd
## 1. Bosque 02: la salida a Monte Sumicio está en el sendero norte (24,1) y la entrada en (24,3); se llega a pie desde la linde.
## 2. Los tres puntos del encargo están junto a la salida y no anotan nada antes de recibirlo.
## 3. Monte Sumicio: la audiencia (textos del PPTX) admite a Mid; tras el uniforme, Marimanta da el encargo.
## 4. En Bosque 02 se anotan hito, planta y criatura; la misión pasa a 3/4.
## 5. Marimanta recibe el trabajo, aparece el cofre legendario y abrirlo da el sello de agua (y queda para otros niveles).

var _fallos := 0
var _f := 0
var _paso := 0
var _mundo: Node


func _initialize() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	change_scene_to_file("res://escenas/PruebaBosque02.tscn")


func _ok(cond: bool, texto: String) -> void:
	print(("OK    " if cond else "FALLO ") + texto)
	if not cond:
		_fallos += 1


func _process(_d: float) -> bool:
	_f += 1
	if _f < 90:
		return false
	_f = 0
	match _paso:
		0:
			_bosque_antes()
		1:
			_mundo = current_scene
			change_scene_to_file("res://escenas/PruebaMonteSumicio.tscn")
		2:
			_sumicio_audiencia_y_encargo()
			change_scene_to_file("res://escenas/PruebaBosque02.tscn")
		3:
			_bosque_encargo()
			change_scene_to_file("res://escenas/PruebaMonteSumicio.tscn")
		4:
			_sumicio_entrega()
		5:
			if String(_visita()._cofre_agua.estado_nombre()) == "apareciendo":
				return false              # la aparición dura ~0,9 s reales; sin ventana los fotogramas van mucho más rápido
			_sumicio_cofre()
			print("FALLOS: %d" % _fallos)
			quit(1 if _fallos > 0 else 0)
	_paso += 1
	return false


func _reglas() -> Node:
	return current_scene.get_node("Reglas")


func _bosque_antes() -> void:
	var salida: SalidaNivel3D = null
	var entrada: Node = null
	for n in current_scene.find_children("*", "", true, false):
		if n is SalidaNivel3D and String(n.get("destino")).begins_with("MonteSumicio"):
			salida = n
		if n.is_in_group("entrada_nivel") and String(n.get("nombre")) == "desde_sumicio":
			entrada = n
	_ok(salida != null, "1.1 hay salida a MonteSumicio:desde_fraga en Bosque 02")
	if salida != null:
		_ok(Terreno3D.celda_de(salida.global_position) == Vector2i(24, 1), "1.2 la salida está en el sendero norte (24,1): %s" % Terreno3D.celda_de(salida.global_position))
	_ok(entrada != null and Terreno3D.celda_de((entrada as Node3D).global_position) == Vector2i(24, 3), "1.3 la entrada desde_sumicio está en (24,3)")
	# Camino a pie: del cruce del norte (24,17) a la entrada (24,3) por la columna abierta.
	var libre := true
	for y in range(1, 18):
		if Terreno3D.bloqueada(Vector2i(24, y)) or Terreno3D.es_vacio(Vector2i(24, y)):
			libre = false
			print("   bloqueada (24,%d) letra %s" % [y, Terreno3D.letra_de(Vector2i(24, y))])
	_ok(libre, "1.4 el sendero x=24 (filas 1..17) se pisa hasta la plaza del estanque")
	var reglas := _reglas()
	var planta: Vector2i = reglas.ENCARGO_CELDAS[1]
	var p := Terreno3D.centro_de(planta, Terreno3D.y_pies(planta)) + Vector3(1.2, 0, 0)
	_ok(reglas.encargo_cercano(p) == 1, "2.1 junto a la planta, E apunta al encargo")
	_ok(EncargoMarimanta.anotar(1) == String(EncargoMarimanta.SIN_ENCARGO[1]) and not Flags.i().tiene(EncargoMarimanta.PLANTA),
		"2.2 sin encargo no se anota nada")
	_ok(Cartografia.nivel == "Bosque_02" and Cartografia.alto() == 52 and Cartografia.ancho() == 40, "2.3 el mapa de Bosque 02 está preparado (40×52)")
	_ok(not Cartografia.registrar(Vector2i(24, 3)) and Cartografia.porcentaje() == 0, "2.4 sin encargo el mapa está bloqueado y no registra")
	_ok(Cartografia.salidas.any(func(s: Dictionary) -> bool: return s["celda"] == Vector2i(24, 1) and s["nombre"] == "Monte Sumicio"),
		"2.5 el mapa marca la salida norte como «Monte Sumicio»")


func _visita() -> Node:
	return current_scene.get_node("Visita")


func _sumicio_audiencia_y_encargo() -> void:
	var v := _visita()
	var maq := current_scene.get_node("Maqueta")
	for i in range(v.AUDIENCIA.size()):
		v._hablar_con_marimanta()
	_ok(Flags.i().tiene(v.ADMISION), "3.1 tras la audiencia (%d líneas del PPTX) Mid queda admitida" % v.AUDIENCIA.size())
	v._marimanta_despues()
	_ok(not EncargoMarimanta.recibido(), "3.2 sin el uniforme Marimanta no da el encargo")
	var mid: Node3D = v._mid
	mid.position = maq.cofre.global_position + Vector3(0, 0, 1.0)
	v._entregar_uniforme()
	_ok(Flags.i().tiene(v.COFRE_UNIFORME), "3.3 se recoge el uniforme")
	for i in range(v.ENCARGO.size()):
		v._marimanta_despues()
	_ok(EncargoMarimanta.recibido(), "3.4 Marimanta da el encargo")
	_ok(Misiones.i().estado(EncargoMarimanta.MISION) == "activa", "3.5 la misión «Trabajo de campo» está activa en el diario")
	_ok(v._cofre_agua != null and v._cofre_agua.esta_oculto(), "3.6 el cofre legendario sigue oculto")


func _bosque_encargo() -> void:
	var reglas := _reglas()
	for i in reglas.ENCARGO_CELDAS:
		var c: Vector2i = reglas.ENCARGO_CELDAS[i]
		var p := Terreno3D.centro_de(c, Terreno3D.y_pies(c)) + Vector3(1.2, 0, 0)
		var j: int = reglas.encargo_cercano(p)
		if j >= 0:
			print("   ", EncargoMarimanta.anotar(j))
	_ok(EncargoMarimanta.pasos_hechos() == 2 and not EncargoMarimanta.listo_para_entregar(), "4.1 planta y criatura anotadas; falta el mapa")
	# Andar por todo lo que se pisa HOY desde la entrada norte (sin abrir puertas ni resolver puzles) y cartografiar.
	var inicio := Vector2i(24, 3)
	var cola: Array = [inicio]
	var vistas := {inicio: true}
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		Cartografia.registrar(c)
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + v
			if not vistas.has(n) and not Terreno3D.bloqueada(n) and not Terreno3D.es_vacio(n) and not Terreno3D.es_agua(n):
				vistas[n] = true
				cola.append(n)
	print("   casillas a pie: %d  · cartografiado: %d %%" % [vistas.size(), Cartografia.porcentaje()])
	_ok(Cartografia.porcentaje() >= Cartografia.META, "4.0 andando por lo accesible sin puzles se llega al %d %% (hay %d %%)" % [Cartografia.META, Cartografia.porcentaje()])
	reglas._sincronizar_mision()
	_ok(Flags.i().tiene(EncargoMarimanta.MAPA), "4.1b el objetivo del mapa queda cumplido")
	_ok(Misiones.i().progreso(EncargoMarimanta.MISION) == Vector2i(3, 4), "4.2 la misión va 3/4: %s" % Misiones.i().progreso(EncargoMarimanta.MISION))
	_ok(EncargoMarimanta.listo_para_entregar(), "4.3 listo para entregar")


func _sumicio_entrega() -> void:
	var v := _visita()
	for i in range(v.ENTREGA.size()):
		v._marimanta_despues()
	_ok(Flags.i().tiene(EncargoMarimanta.ENTREGADO), "5.1 Marimanta recibe el trabajo de campo")
	_ok(Misiones.i().estado(EncargoMarimanta.MISION) == "completa", "5.2 la misión se completa")
	_ok(not v._cofre_agua.esta_oculto(), "5.3 aparece el cofre legendario")


func _sumicio_cofre() -> void:
	var v := _visita()
	Repertoire.set_active(PackedStringArray(["fuego"]), PackedStringArray())
	var mid: Node3D = v._mid
	mid.position = v._nodo_cofre_agua.global_position + Vector3(0, 0, 1.0)
	_ok(v._ante_cofre_agua(), "5.4 junto al cofre se puede abrir")
	print("   estado del cofre: ", v._cofre_agua.estado_nombre())
	v._interactuar()
	_ok(Flags.i().tiene(EncargoMarimanta.COFRE_AGUA), "5.5 el cofre se abre")
	_ok(Repertoire.active_elements().has("agua"), "5.6 Mid tiene la runa de agua")
	Repertoire.set_active(PackedStringArray(["fuego"]), PackedStringArray())
	EncargoMarimanta.rearmar_sellos()
	_ok(Repertoire.active_elements().has("agua"), "5.7 la runa de agua se conserva al montar otro nivel")
