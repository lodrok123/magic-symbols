extends SceneTree
## RECORRIDO COMPLETO de Monte Sumicio (13/11/2026), como lo jugaría Pablo, con las salidas de verdad (tecla E → Niveles.ir_a con su fundido):
##   partida nueva en Bosque 02 → de la linde al sendero norte (el arroyo es la única barrera: lo cruza el tronco-puente) → E en la salida →
##   Monte Sumicio: guardia, escolta, audiencia, uniforme, encargo → E en InicioFraga → Bosque 02 → cartografiar andando hasta el 60 %,
##   planta y nido → GUARDAR, vaciar todo y CARGAR → E en la salida → Marimanta → cofre legendario → runa de agua.
##   godot --headless --path . --script res://herramientas/prueba_recorrido_sumicio.gd
## No toca las ranuras del jugador: guarda en user://prueba_recorrido_sumicio/.

const RANURA := 7
const MAX_FOTOGRAMAS_PASO := 3000

var _fallos := 0
var _paso := 0
var _f := 0
var _espera := 0
var _camino: Array = []
var _nivel_antes := ""


func _initialize() -> void:
	Partida.carpeta = "user://prueba_recorrido_sumicio"
	Flags.nuevo()
	Misiones.nuevo()
	change_scene_to_file(Niveles.ESCENAS[Niveles.NIVEL_INICIAL])


func _ok(cond: bool, texto: String) -> void:
	print(("OK    " if cond else "FALLO ") + texto)
	if not cond:
		_fallos += 1


func _fin() -> void:
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


# --- Ayudas ---

func _jug() -> Node3D:
	for n in current_scene.get_children():
		if n is Jugador3D:
			return n
	return null


func _celda() -> Vector2i:
	var j := _jug()
	return Terreno3D.celda_de(j.global_position) if j else Vector2i(-999, -999)


func _poner(p: Vector3) -> void:
	var j := _jug()
	p.y = Terreno3D.y_pies(Terreno3D.celda_de(p))
	j.position = p
	j.pj.position = p


func _poner_celda(c: Vector2i) -> void:
	_poner(Terreno3D.centro_de(c, Terreno3D.y_pies(c)))


func _pulsar_e() -> void:
	var k := InputEventKey.new()
	k.keycode = KEY_E
	k.physical_keycode = KEY_E
	k.pressed = true
	Input.parse_input_event(k)
	var s := InputEventKey.new()
	s.keycode = KEY_E
	s.physical_keycode = KEY_E
	s.pressed = false
	Input.parse_input_event(s)


func _escena() -> String:
	return current_scene.scene_file_path if current_scene else ""


## Casillas a pie desde `desde` (sin puzles: lo bloqueado, el vacío y el agua no se pisan).
func _a_pie(desde: Vector2i) -> Dictionary:
	var cola: Array = [desde]
	var vistas := {desde: desde}
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + v
			if not vistas.has(n) and not Terreno3D.bloqueada(n) and not Terreno3D.es_vacio(n) and not Terreno3D.es_agua(n):
				vistas[n] = c
				cola.append(n)
	return vistas


## Espera a que cargue otra escena tras pulsar E en una salida.
func _esperar_viaje(hacia: String) -> bool:
	if _escena() != hacia or Niveles.en_curso:
		_espera += 1
		if _espera > MAX_FOTOGRAMAS_PASO:
			_ok(false, "el viaje a %s no llegó (escena %s)" % [hacia, _escena()])
			_fin()
		return false
	if _espera < 60:          # que la escena nueva acabe de montarse
		_espera += 1
		return false
	_espera = 0
	return true


# --- El recorrido ---

func _process(_d: float) -> bool:
	_f += 1
	if _f < 4:
		return false
	_f = 0
	match _paso:
		0:  # Bosque 02 recién montado
			_espera += 1
			if _espera < 30:
				return false
			_espera = 0
			_inicio_bosque()
		1:  # andar hasta junto a la salida norte y pulsar E
			_poner_celda(Vector2i(24, 2))
			_espera += 1
			if _espera < 6:            # la salida se arma cuando Mid ha estado fuera de su casilla
				return false
			_espera = 0
			_pulsar_e()
		2:
			if not _esperar_viaje(Niveles.ESCENAS["MonteSumicio"]):
				return false
			_llegada_sumicio()
		3:
			if not _escolta():
				return false
		4:  # entrar en la Torre Verde por su puerta (14/11: la audiencia es dentro)
			var v: Node = current_scene.get_node("Visita")
			if v._interior == null:
				var torre: Node3D = current_scene.get_node("Maqueta").torre
				_poner(torre.to_global(v._hueco_puerta(torre) + Vector3(0, 0, 0.1)))
				_espera += 1
				if _espera > 400:
					_ok(false, "4.0 la puerta de la torre no lleva a la sala")
					_fin()
				return false
			if v._en_transicion:
				return false
			_espera = 0
			_ok(v._interior.torre, "4.0 la puerta animada de la torre lleva a su sala")
			var en_muro: Array = []
			for sitio in v._interior.PUNTOS:
				if v._interior.es_muro(v._interior.PUNTOS[sitio]):
					en_muro.append(sitio)
			_ok(en_muro.is_empty(), "4.0b nada de la sala queda dentro del muro %s" % str(en_muro))
			var cofre: Node3D = current_scene.get_node("Maqueta").cofre
			_ok(cofre.is_visible_in_tree() and v._interior.contiene(Terreno3D.celda_de(cofre.global_position)), "4.0c el cofre del uniforme se ve dentro de la sala")
			_audiencia_y_encargo()
		5:  # salir de la torre por su salida y volver a la Fraga con E en InicioFraga
			var v: Node = current_scene.get_node("Visita")
			if v._interior != null:
				_poner(Terreno3D.centro_de(v._interior.centro + v._interior.salida, Terreno3D.alto_suelo) + Vector3(0, 0, 0.6))
				return false
			if v._en_transicion:
				return false
			_poner(current_scene.get_node("Maqueta").inicio.global_position)
			_pulsar_e()
		6:
			if not _esperar_viaje(Niveles.ESCENAS["Bosque_02"]):
				return false
			_ok(_celda() == Vector2i(24, 3), "6.1 al bajar de Sumicio Mid aparece en el sendero norte (24,3): %s" % _celda())
			_ok(Cartografia.desbloqueado(), "6.2 el mapa ya está desbloqueado")
			var a_pie := _a_pie(Vector2i(24, 3))
			_camino = a_pie.keys()
		7:  # cartografiar ANDANDO: Mid recorre casillas y el nivel registra en su sondeo
			if not _camino.is_empty() and Cartografia.porcentaje() < Cartografia.META:
				for i in range(3):
					if not _camino.is_empty():
						_poner_celda(_camino.pop_front())
				return false
			_ok(Cartografia.porcentaje() >= Cartografia.META, "7.1 andando se cartografía el %d %% (hay %d %%)" % [Cartografia.META, Cartografia.porcentaje()])
		8:  # planta y nido con E
			_poner(Terreno3D.centro_de(Vector2i(21, 5), Terreno3D.y_pies(Vector2i(21, 5))) + Vector3(1.4, 0, 0))
			_pulsar_e()
		9:
			_ok(Flags.i().tiene(EncargoMarimanta.PLANTA), "8.1 E junto al helecho lo anota en el herbario")
			_poner(Terreno3D.centro_de(Vector2i(28, 6), Terreno3D.y_pies(Vector2i(28, 6))) + Vector3(-1.4, 0, 0))
			_pulsar_e()
		10:
			_ok(Flags.i().tiene(EncargoMarimanta.CRIATURA), "8.2 E junto al nido lo registra en el bestiario")
			_ok(EncargoMarimanta.listo_para_entregar(), "8.3 el encargo está listo para entregar")
			_guardar_y_cargar()
		11:
			_poner_celda(Vector2i(24, 2))
			_espera += 1
			if _espera < 6:
				return false
			_espera = 0
			_pulsar_e()
		12:
			if not _esperar_viaje(Niveles.ESCENAS["MonteSumicio"]):
				return false
			var v: Node = current_scene.get_node("Visita")
			if v._interior == null or v._en_transicion:
				var torre: Node3D = current_scene.get_node("Maqueta").torre
				_poner(torre.to_global(v._hueco_puerta(torre) + Vector3(0, 0, 0.1)))
				_espera = 60
				return false
			_entrega()
		13:
			var v: Node = current_scene.get_node("Visita")
			if String(v._cofre_agua.estado_nombre()) == "apareciendo":
				return false
			_poner(v._nodo_cofre_agua.global_position + Vector3(0, 0, 1.0))
			_pulsar_e()
		14:
			_ok(Flags.i().tiene(EncargoMarimanta.COFRE_AGUA), "12.1 E abre el cofre legendario")
			_ok(Repertoire.active_elements().has("agua"), "12.2 Mid tiene la runa de agua")
			_ok(Misiones.i().estado(EncargoMarimanta.MISION) == "completa", "12.3 «Trabajo de campo» completa en el diario")
			_fin()
			return true
	_paso += 1
	return false


func _inicio_bosque() -> void:
	_ok(_escena() == Niveles.ESCENAS["Bosque_02"], "0.1 la partida nueva empieza en Bosque 02")
	var inicio := _celda()
	print("   Mid empieza en %s" % inicio)
	# Ruta a pie: de la linde a la orilla oeste del arroyo, y desde el sendero norte a la orilla este. El tronco-puente une las dos.
	var oeste := _a_pie(inicio)
	var norte := _a_pie(Vector2i(24, 3))
	_ok(not norte.has(inicio), "0.2 sin cruzar el arroyo no se llega al norte (el tronco-puente es el paso)")
	var tronco := Vector2i(13, 43)
	_ok(oeste.has(tronco + Vector2i(-1, 0)) or oeste.has(tronco), "0.3 desde la linde se llega a pie al tronco-puente %s" % tronco)
	var orilla_este := false
	for y in range(tronco.y - 1, tronco.y + 2):
		for x in range(16, 18):
			orilla_este = orilla_este or norte.has(Vector2i(x, y))
	_ok(orilla_este, "0.4 desde la orilla este del tronco se llega a pie al sendero norte")
	_ok(not Cartografia.desbloqueado() and Cartografia.porcentaje() == 0, "0.5 el mapa está bloqueado al empezar")


func _llegada_sumicio() -> void:
	var maq: Node = current_scene.get_node("Maqueta")
	_ok(Terreno3D.celda_de(_jug().global_position) == Terreno3D.celda_de(maq.inicio.global_position), "2.1 la salida norte lleva a Monte Sumicio (InicioFraga)")
	_poner(maq.guardia.global_position + Vector3(1.0, 0, 0))
	_pulsar_e()


func _escolta() -> bool:
	var v: Node = current_scene.get_node("Visita")
	if v._fase == 1:                       # ESCOLTA: Mid va detrás del guardia
		_poner(v._guardia.global_position + Vector3(0, 0, 1.6))
		_espera += 1
		if _espera > MAX_FOTOGRAMAS_PASO:
			_ok(false, "3.1 la escolta no llega a la Torre")
			_fin()
		return false
	_espera = 0
	_ok(v._fase == 2, "3.1 E con el guardia abre el portón y la escolta llega a la Torre Verde")
	return true


func _audiencia_y_encargo() -> void:
	var v: Node = current_scene.get_node("Visita")
	var maq: Node = current_scene.get_node("Maqueta")
	_poner(maq.marimanta.global_position + Vector3(0, 0, 1.2))
	for i in range(v.AUDIENCIA.size()):
		v._interactuar()
	_ok(Flags.i().tiene(v.ADMISION), "4.1 la audiencia admite a Mid")
	_poner(maq.cofre.global_position + Vector3(0, 0, 1.0))
	v._interactuar()
	_ok(Flags.i().tiene(v.COFRE_UNIFORME), "4.2 se abre el cofre del uniforme")
	_poner(maq.marimanta.global_position + Vector3(0, 0, 1.2))
	for i in range(v.ENCARGO.size()):
		v._interactuar()
	_ok(EncargoMarimanta.recibido(), "4.3 Marimanta da el encargo")
	_ok(Cartografia.desbloqueado(), "4.4 la pestaña Mapa se desbloquea con el encargo")


func _guardar_y_cargar() -> void:
	var pc := Cartografia.porcentaje()
	_ok(Partida.guardar(RANURA), "9.1 se guarda la partida a mitad del recorrido")
	Flags.nuevo()
	Misiones.nuevo()
	_ok(not EncargoMarimanta.recibido(), "9.2 (todo vaciado antes de cargar)")
	var d := Partida.cargar(RANURA)
	_ok(not d.is_empty(), "9.3 se carga la partida")
	_ok(EncargoMarimanta.listo_para_entregar(), "9.4 tras cargar, el encargo sigue listo (planta, nido y mapa)")
	_ok(Cartografia.porcentaje_de(Cartografia.NIVEL_ENCARGO) >= pc - 1, "9.5 tras cargar, el mapa conserva su %d %%" % pc)
	_ok(Misiones.i().existe(EncargoMarimanta.MISION), "9.6 tras cargar, la misión sigue en el diario")


func _entrega() -> void:
	var v: Node = current_scene.get_node("Visita")
	var maq: Node = current_scene.get_node("Maqueta")
	_poner(maq.marimanta.global_position + Vector3(0, 0, 1.2))
	for i in range(v.ENTREGA.size()):
		v._interactuar()
	_ok(Flags.i().tiene(EncargoMarimanta.ENTREGADO), "11.1 Marimanta recibe el trabajo de campo")
	_ok(not v._cofre_agua.esta_oculto(), "11.2 aparece el cofre legendario")
