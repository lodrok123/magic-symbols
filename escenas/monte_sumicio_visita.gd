extends Node

const Maqueta = preload("res://escenas/monte_sumicio_maqueta.gd")
const Interior = preload("res://escenas/interior_palloza.gd")
const Mundo = preload("res://presentacion/prueba_test2.gd")
const ADMISION := "montesumicio.torre.admitida"
const COFRE_UNIFORME := "montesumicio.torre.uniforme_recogido"
const VISITA_COMPLETA := "montesumicio.fraga.visita_completa"
const UNIFORME := "atuendo_sumicio"
const TIENDA := "sumicio"
const DESTINO_FRAGA := "Bosque_02:desde_sumicio"
const SintesisUI = preload("res://presentacion/ui/sintesis_ui.gd")
const VECINOS := ["Iria", "Brais", "Sabela"]
const COFRES := ["baya", "seta_asada", "resina"]

enum Fase { PORTON, ESCOLTA, AUDIENCIA, LIBRE, REGRESO }

@onready var _maqueta: Maqueta = $"../Maqueta"
var _mid: Jugador3D
var _guardia: Node3D
var _cofre_uniforme: Cofre3D
var _fase := Fase.PORTON
var _paso := 0
var _parlamento := 0
var _objetivo: Label
var _dialogo: Label
var _pista: Label
var _casas: Dictionary[Node3D, Interior] = {}
var _exteriores: Array[Node3D]
var _casa: Node3D
var _interior: Interior
var _fundido: ColorRect
var _en_transicion := false
var _giro_exterior := 0.0


func _ready() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)
	_montar.call_deferred()


func _montar() -> void:
	var mundo := get_parent()
	for n in mundo.get_children():
		if n is Jugador3D:
			_mid = n
			break
	if _mid == null:
		push_error("Monte Sumicio: falta el marcador de inicio de Mid.")
		return
	var habitaciones := mundo.get_node("Interiores").get_children()
	_exteriores = _maqueta.casas()
	for i in range(_exteriores.size()):
		var sala := habitaciones[i] as Interior
		sala.montar()
		var nombre: String = "Tendera" if sala.tienda else VECINOS[i]
		var vecino := _figura(nombre, sala.centro + Interior.VECINO, Color("#56473b"),
			Color("#53764c") if sala.tienda else Color("#827259"), sala)
		if sala.casa_brais:
			vecino.position += Vector3(-0.48, 0.0, -0.22)
		sala.hide()
		_casas[_exteriores[i]] = sala
	_guardia = _figura("Guardia", Maqueta.celda(_maqueta.guardia), Color("#635345"), Color("#827259"))
	_guardia.position = _maqueta.guardia.global_position
	var marimanta := _figura("Marimanta", Maqueta.celda(_maqueta.marimanta), Color("#4c5153"), Color("#93394a"))
	marimanta.position = _maqueta.marimanta.global_position
	_cofre_uniforme = Cofre3D.en(_maqueta.cofre)
	# Las partidas previas a este cofre ya podían haber recibido el uniforme de Marimanta.
	if Flags.i().tiene(ADMISION) and Atuendos.tiene(UNIFORME):
		Flags.i().poner(COFRE_UNIFORME)
	if Flags.i().tiene(COFRE_UNIFORME):
		_cofre_uniforme.abrir_ya()
	_montar_cofre_agua()
	EncargoMarimanta.sincronizar()
	var caco := _figura("Caco", Maqueta.celda(_maqueta.caco), Color("#56473b"), Color("#53764c"))
	caco.position = _maqueta.caco.global_position
	_montar_hud()
	add_child(SintesisUI.new())
	_montar_fundido()
	if Flags.i().tiene(ADMISION):
		_fase = Fase.REGRESO if Flags.i().tiene(VISITA_COMPLETA) else Fase.LIBRE
		_maqueta.abrir_porton()
		_guardia.position = Maqueta.punto(Maqueta.celda(_maqueta.guardia) + Vector2i.RIGHT)
	else:
		_dialogo.text = "Mid trae el Grimorio del Guardabosques para la Maestre Marimanta."
	for casa in _casas:
		if _casas[casa].contiene(Terreno3D.celda_de(_mid.position)):
			_entrar(casa, false)
			break
	set_physics_process(true)
	set_process_unhandled_input(true)


func _physics_process(delta: float) -> void:
	if _en_transicion:
		return
	if _interior != null:
		var centro := Maqueta.punto(_interior.centro)
		var local := _mid.position - centro
		if absf(local.x) < 0.72 and local.z >= Terreno3D.casilla * 2.12:
			_cruzar(null)
			return
		_objetivo.text = "Tienda y síntesis" if _interior.tienda else "Palloza familiar"
		_pista.text = _pista_interior()
		return
	if _fase != Fase.PORTON:
		var puerta := _puerta_cercana()
		if puerta != null:
			if _casas[puerta].tienda or Flags.i().tiene(COFRE_UNIFORME):
				_cruzar(puerta)
				return
	if _fase == Fase.ESCOLTA:
		_avanzar_escolta(delta)
	_maqueta.mostrar_interiores(_mid.position)
	var objetivo := ""
	var pista := ""
	match _fase:
		Fase.PORTON:
			objetivo = "Sube al portón y habla con el guardia."
			if _cerca(_maqueta.guardia):
				pista = "[E] Hablar con el guardia"
		Fase.ESCOLTA:
			objetivo = "Sigue al guardia hasta la Torre Verde."
		Fase.AUDIENCIA:
			objetivo = "Entrega el grimorio a Marimanta."
			if _cerca(_maqueta.marimanta):
				pista = "[E] Entregar el grimorio" if _parlamento == 0 else "[E] Continuar"
		Fase.LIBRE, Fase.REGRESO:
			objetivo = _objetivo_libre()
			if _cerca(_maqueta.caco):
				pista = "[E] Hablar con el caco"
			if _cerca(_maqueta.marimanta):
				pista = "[E] Hablar con Marimanta"
	if _cerca(_maqueta.inicio):
		pista = "[E] Volver a la Fraga"
	_objetivo.text = objetivo
	_pista.text = pista
	if Flags.i().tiene(ADMISION) and not Flags.i().tiene(COFRE_UNIFORME):
		_objetivo.text = "Recoge el uniforme del cofre detrás de Marimanta."
	if _ante_cofre_agua():
		_pista.text = "[E] Abrir cofre legendario"
	elif _ante_cofre_uniforme():
		_pista.text = "[E] Abrir cofre épico" if Flags.i().tiene(ADMISION) else "[E] Examinar cofre épico"
	elif _puerta_cercana() != null and not Flags.i().tiene(COFRE_UNIFORME):
		_pista.text = "Puerta cerrada"


func _unhandled_input(evento: InputEvent) -> void:
	if _en_transicion:
		return
	if not evento.is_action_pressed("interactuar"):
		return
	if _interactuar():
		get_viewport().set_input_as_handled()


func _interactuar() -> bool:
	if _interior != null:
		return _interactuar_dentro()
	if _ante_cofre_uniforme():
		if Flags.i().tiene(ADMISION):
			_entregar_uniforme()
		else:
			_dialogo.text = "El cofre épico está cerrado."
		return true
	if _ante_cofre_agua():
		_abrir_cofre_agua()
		return true
	if _cerca(_maqueta.inicio):
		return _volver_a_la_fraga()
	match _fase:
		Fase.PORTON:
			if _cerca(_maqueta.guardia):
				_fase = Fase.ESCOLTA
				_maqueta.abrir_porton()
				_dialogo.text = "Guardia · La Maestre te espera. Ve detrás de mí."
				return true
		Fase.AUDIENCIA:
			if _cerca(_maqueta.marimanta):
				_hablar_con_marimanta()
				return true
		Fase.LIBRE, Fase.REGRESO:
			if _cerca(_maqueta.marimanta):
				_marimanta_despues()
				return true
			if _cerca(_maqueta.caco):
				_dialogo.text = "Caco · Si buscas provisiones, pásate por la palloza del este."
				return true
	return false


func _objetivo_libre() -> String:
	if not EncargoMarimanta.recibido():
		return "Habla con Marimanta en la Torre Verde."
	if Flags.i().tiene(EncargoMarimanta.COFRE_AGUA):
		return "Encargo cumplido · visita el poblado o vuelve a la Fraga."
	if Flags.i().tiene(EncargoMarimanta.ENTREGADO):
		return "Abre el cofre legendario junto a Marimanta."
	if EncargoMarimanta.listo_para_entregar():
		return "Entrega el trabajo de campo a Marimanta."
	return "Encargo: baja al sendero norte de la Fraga (%d/3 anotados)." % EncargoMarimanta.pasos_hechos()


func _volver_a_la_fraga() -> bool:
	if Niveles.en_curso or not Niveles.existe("Bosque_02"):
		return false
	if _fase == Fase.LIBRE and Flags.i().tiene(COFRE_UNIFORME):
		_fase = Fase.REGRESO
		Flags.i().poner(VISITA_COMPLETA)
	_en_transicion = Niveles.ir_a(get_parent(), DESTINO_FRAGA)
	return _en_transicion


func _puesto(lugar: Vector2i) -> bool:
	return _distancia_plana(_mid.position, Maqueta.punto(_interior.centro + lugar)) < 1.7


func _cofre_al_alcance() -> bool:
	return not _interior.tienda and _distancia_plana(
		_mid.position, Maqueta.punto(_interior.centro + Interior.COFRE)) < Terreno3D.casilla + 0.10


func _pista_interior() -> String:
	if _puesto(Interior.SALIDA):
		return "[E] Salir a Monte Sumicio"
	if _puesto(Interior.VECINO):
		return "[E] Ver mercancía" if _interior.tienda and Flags.i().tiene(COFRE_UNIFORME) else "[E] Hablar"
	if _interior.tienda and Flags.i().tiene(COFRE_UNIFORME) and _puesto(Interior.MESA):
		return "[E] Abrir mesa de síntesis"
	if _cofre_al_alcance():
		return "Cofre vacío" if Flags.i().tiene(_flag_cofre()) else "[E] Abrir cofre"
	return ""


func _interactuar_dentro() -> bool:
	if _puesto(Interior.SALIDA):
		_cruzar(null)
	elif _puesto(Interior.VECINO):
		if _interior.tienda:
			if Flags.i().tiene(COFRE_UNIFORME):
				_dialogo.text = "Tendera · Así que eres la nueva aprendiz. A ver qué necesitas."
				Tiendas.abrir(TIENDA)
			else:
				_dialogo.text = "Tendera · ¿Te has perdido, forastera? La tienda es para aprendices. La puerta la tienes ahí."
		else:
			var i := _exteriores.find(_casa)
			var frases := ["Acércate al hogar. Aquí arriba el viento se mete por todas partes.",
				"Te he dejado una seta asada en el cofre junto al pesebre. Con una baya de la tienda, podrás preparar una poción.",
				"Los animales duermen abajo. Su calor nos llega hasta el Ástrago."]
			_dialogo.text = "%s · %s" % [VECINOS[i], frases[i]]
	elif _interior.tienda and Flags.i().tiene(COFRE_UNIFORME) and _puesto(Interior.MESA):
		Sintesis.abrir("alquimista")
	elif _cofre_al_alcance() and not Flags.i().tiene(_flag_cofre()):
		var objeto: String = COFRES[_exteriores.find(_casa)]
		if Estado.i().agregar(objeto) == 1:
			Flags.i().poner(_flag_cofre())
			PlayLog.event("cofre_abierto", {"cofre": _flag_cofre(), "objeto": objeto})
			_interior.mostrar_cofre(true)
			_dialogo.text = "Has encontrado %s." % Objetos.nombre(objeto)
			Partida.autoguardar(get_tree(), "monte_sumicio_cofre")
		else:
			_dialogo.text = "La mochila está llena."
	else:
		return false
	return true


func _flag_cofre() -> String:
	return "montesumicio.palloza_%d.cofre_abierto" % _exteriores.find(_casa)


func _puerta_cercana() -> Node3D:
	for casa in _casas:
		var local := casa.to_local(_mid.position)
		if absf(local.x) < 0.48 and local.z >= 1.15 and local.z <= 1.85:
			return casa
	return null


func _cruzar(puerta: Node3D) -> void:
	_en_transicion = true
	_pista.text = ""
	if _interior == null:
		var bisagra := _maqueta.bisagra(puerta)
		_mid.pj.girar_hacia(-puerta.global_basis.z.normalized(), 1.0, TAU)
		var gesto := _mid.gesto("ofrecer", 1.7)
		if gesto <= 0.0:
			_mid.set_physics_process(false)
		var abrir := create_tween()
		abrir.tween_interval(minf(gesto * 0.32, 0.24))
		# Bisagra izquierda, la hoja barre hacia el interior (+X hacia -Z).
		abrir.tween_property(bisagra, "rotation:y", deg_to_rad(92.0), 0.44).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await abrir.finished
	_mid.set_physics_process(false)
	_fundido.show()
	var animacion := create_tween()
	animacion.tween_property(_fundido, "color:a", 1.0, 0.14)
	await animacion.finished
	if _interior == null:
		_entrar(puerta, true)
		_maqueta.bisagra(puerta).rotation.y = 0.0
	else:
		_salir()
	_mid.set_physics_process(true)
	animacion = create_tween()
	animacion.tween_property(_fundido, "color:a", 0.0, 0.17)
	await animacion.finished
	_fundido.hide()
	_en_transicion = false


func _entrar(puerta: Node3D, colocar: bool) -> void:
	var mundo := get_parent() as Mundo
	_casa = puerta
	_interior = _casas[puerta]
	_giro_exterior = mundo._giro_cam
	mundo._giro_cam = 0.0
	mundo.camara_gira = false
	_interior.show()
	if not _interior.tienda:
		_interior.mostrar_cofre(Flags.i().tiene(_flag_cofre()))
	_interior.camara.make_current()
	_dialogo.text = ""
	if colocar:
		_colocar_mid(Maqueta.punto(_interior.centro + Interior.ENTRADA), Vector3.FORWARD)


func _salir() -> void:
	var mundo := get_parent() as Mundo
	var regreso := _casa.to_global(Vector3.BACK * 2.35)
	regreso.y = Terreno3D.y_pies(Terreno3D.celda_de(regreso))
	_colocar_mid(regreso, _casa.global_basis.z.normalized())
	_interior.hide()
	_interior = null
	_dialogo.text = ""
	mundo._giro_cam = _giro_exterior
	mundo.camara_gira = true
	mundo._foco = mundo._centro(_mid.pj)
	mundo._colocar_camara()
	mundo._camara.make_current()


func _colocar_mid(destino: Vector3, orientacion: Vector3) -> void:
	_mid.position = destino
	_mid.pj.position = destino
	_mid.pj.girar_hacia(orientacion, 1.0, TAU)
	_mid.vy = 0.0
	_mid.en_suelo = true


func _montar_fundido() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 90
	add_child(capa)
	_fundido = ColorRect.new()
	_fundido.color = Color(0, 0, 0, 0)
	capa.add_child(_fundido)
	_fundido.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundido.hide()


func _avanzar_escolta(delta: float) -> void:
	# El guardia espera si Mid se detiene o se desvía.
	if _distancia_plana(_guardia.position, _mid.position) > 5.4:
		return
	var camino := _maqueta.escolta
	var meta := (camino.get_child(_paso) as Node3D).global_position
	_guardia.position = _guardia.position.move_toward(meta, delta * 3.8)
	if not _guardia.position.is_equal_approx(meta):
		return
	_paso += 1
	if _paso == camino.get_child_count() - 1:
		_fase = Fase.AUDIENCIA
		_guardia.position = (camino.get_child(_paso) as Node3D).global_position
		_dialogo.text = "Guardia · Aquí termina mi camino."


## La audiencia (Monte-Sumicio.pptx, «La entrega» … «La nueva discípula»). Cada E avanza una línea; la última admite a Mid.
const AUDIENCIA: Array = [
	"Mid se presenta ante la Maestre Marimanta y le entrega el Grimorio del Guardabosques.",
	"Marimanta · El grimorio de Leonardo… Déjame verlo.   (Por primera vez, Mid ve a un Sumiciu triste por alguien ajeno a su comunidad.)",
	"Marimanta · Sabía que su destino estaría sellado si volvía a la cabaña. Me negué a sacrificar a los míos cuando desoyó mi advertencia. Solo podía esperar al cambio de guardia.",
	"Marimanta · Poco después de su desaparición llegó la Noche de la Fada. No quedó nadie con vida que echara en falta al Guardabosques. El Canouro pudo alargar su agonía cuanto deseó.",
	"Marimanta · Pedro Chosco tampoco se preocupó por el puesto. Sus Escribas Viajeros no suelen pisar el sector norte: es territorio Sumicio.",
	"Marimanta · Pero siempre hay alguno que desobedece: un soñador nostálgico que ansía recuperar la gloria pasada de su raza y estudiar en la nueva torre arcana.",
	"Marimanta · Para ellos creamos la prueba del Biosbardo: «Eu son Leonardo, ti es biosbardo. Biosbardo, vinte pró saco, ca eu che agardo, e son Leonardo.»",
	"(La rima lleva el nombre de Leonardo: un reconocimiento cruel para Marimanta, un insulto para cualquier Mouro. La mirada de Mid se desvía a las paredes.)",
	"Marimanta · Aun así, quedas aceptada como alumna de la Torre Verde. Revisaré tu grimorio para ver la formación que te dieron en Terra Fina.",
	"Marimanta · Recoge el uniforme del cofre que hay detrás de mí. Con la capucha roja podrás entrar y salir del poblado.",
]
## El encargo (diapositivas «Cuatro asignaturas» y «Hacia el bosque»): lo da tras recoger el uniforme.
const ENCARGO: Array = [
	"Marimanta · Por lo que dice tu grimorio, te faltan cuatro asignaturas para el Nivel I: Historia, Botánica y Herboristería, Orientación y Cuaderno de Campo, y Competencia Rúnica.",
	"Marimanta · En Terra Fina te enseñaron a leer, a dibujar y a activar runas básicas, pero Pedro Chosco nunca te dejó hacer trabajo de campo en la Fraga.",
	"Marimanta · Empieza por ahí. Baja al sendero norte de la Fraga y, junto a la subida, anota el hito del camino, identifica una planta y registra una criatura. Luego vuelve.",
]
const RECORDATORIO := "Marimanta · El hito, la planta y la criatura del sendero norte. Y nada de trampas: los mapas de la torre están prohibidos hasta el Nivel I."
const ENTREGA: Array = [
	"Marimanta · A ver ese grimorio… El hito, un helecho, un nido de mirlo. Limpio, para venir de Terra Fina.",
	"Marimanta · Te lo has ganado: abre el cofre de mi izquierda. Guarda una runa de agua. Aquí arriba no nos sirve de mucho: es más rápido bajar al río.",
]
const COFRE_LEGENDARIO := preload("res://arte/piezas/cofre_legendario.tscn")
var _cofre_agua: Cofre3D
var _nodo_cofre_agua: Node3D


func _hablar_con_marimanta() -> void:
	_dialogo.text = String(AUDIENCIA[mini(_parlamento, AUDIENCIA.size() - 1)])
	_parlamento += 1
	if _parlamento < AUDIENCIA.size():
		return
	Flags.i().poner(ADMISION)
	_fase = Fase.LIBRE
	_parlamento = 0
	# Oro de prueba para poder hacer un intercambio en esta escena aislada.
	Estado.i().dar_oro(15)
	Partida.autoguardar(get_tree(), "monte_sumicio_admision")


## Marimanta después de la admisión: el encargo, el recordatorio o la entrega.
func _marimanta_despues() -> void:
	if not Flags.i().tiene(COFRE_UNIFORME):
		_dialogo.text = "Marimanta · Primero el uniforme: está en el cofre que hay detrás de mí."
	elif not EncargoMarimanta.recibido():
		_dialogo.text = String(ENCARGO[_parlamento])
		_parlamento += 1
		if _parlamento >= ENCARGO.size():
			_parlamento = 0
			Flags.i().poner(EncargoMarimanta.RECIBIDO)
			EncargoMarimanta.sincronizar()
			Partida.autoguardar(get_tree(), "monte_sumicio_encargo")
	elif EncargoMarimanta.listo_para_entregar():
		_dialogo.text = String(ENTREGA[_parlamento])
		_parlamento += 1
		if _parlamento >= ENTREGA.size():
			_parlamento = 0
			Flags.i().poner(EncargoMarimanta.ENTREGADO)
			EncargoMarimanta.sincronizar()
			_cofre_agua.aparecer()
			Partida.autoguardar(get_tree(), "monte_sumicio_encargo_entregado")
	elif Flags.i().tiene(EncargoMarimanta.ENTREGADO):
		_dialogo.text = "Marimanta · Las otras asignaturas te esperan en la Fraga. Y no te fíes de los del gorro verde."
	else:
		_dialogo.text = RECORDATORIO


func _montar_cofre_agua() -> void:
	_nodo_cofre_agua = COFRE_LEGENDARIO.instantiate() as Node3D
	_maqueta.torre.add_child(_nodo_cofre_agua)
	_nodo_cofre_agua.position = Vector3(-2.3, 0.0, -2.85)
	_cofre_agua = Cofre3D.en(_nodo_cofre_agua)
	if Flags.i().tiene(EncargoMarimanta.COFRE_AGUA):
		_cofre_agua.abrir_ya()
	elif Flags.i().tiene(EncargoMarimanta.ENTREGADO):
		_cofre_agua.aparecer_ya()
	else:
		_cofre_agua.ocultar()


func _ante_cofre_agua() -> bool:
	return _cofre_agua != null and not _cofre_agua.esta_oculto() and not Flags.i().tiene(EncargoMarimanta.COFRE_AGUA) \
		and _distancia_plana(_mid.position, _nodo_cofre_agua.global_position) < 1.65


func _abrir_cofre_agua() -> void:
	if not _cofre_agua.abrir():
		return
	Flags.i().poner(EncargoMarimanta.COFRE_AGUA)
	EncargoMarimanta.dar_sello_agua()
	PlayLog.event("cofre_abierto", {"cofre": EncargoMarimanta.COFRE_AGUA, "objeto": "sello_agua", "calidad": "legendario"})
	_dialogo.text = "Has conseguido la runa de agua."
	Partida.autoguardar(get_tree(), "monte_sumicio_runa_agua")


func _entregar_uniforme() -> void:
	var estado := Estado.i()
	if not Atuendos.tiene(UNIFORME) and estado.agregar(UNIFORME) == 0:
		_dialogo.text = "Haz sitio en la mochila para recoger el uniforme."
		return
	Flags.i().poner(COFRE_UNIFORME)
	_cofre_uniforme.abrir()
	PlayLog.event("cofre_abierto", {"cofre": COFRE_UNIFORME, "objeto": UNIFORME, "calidad": "epico"})
	if Atuendos.poner(_mid.pj, UNIFORME):
		_dialogo.text = "Has recogido el uniforme de Monte Sumicio."
	else:
		_dialogo.text = "Marimanta · Ya eres alumna de la Torre Verde. Tienes el uniforme en el vestuario."
	Partida.autoguardar(get_tree(), "monte_sumicio_uniforme")


func _ante_cofre_uniforme() -> bool:
	return not Flags.i().tiene(COFRE_UNIFORME) and _distancia_plana(
		_mid.position, _cofre_uniforme.get_parent().global_position) < 1.65


func _cerca(marcador: Node3D) -> bool:
	return _distancia_plana(_mid.position, marcador.global_position) < 2.7


static func _distancia_plana(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _figura(nombre: String, c: Vector2i, ropa: Color, gorro: Color, padre: Node3D = null) -> Node3D:
	var figura := Node3D.new()
	figura.name = nombre
	var contenedor: Node = self if padre == null else padre
	contenedor.add_child(figura)
	figura.global_position = Maqueta.punto(c)
	var cuerpo := CapsuleMesh.new()
	cuerpo.radius = 0.32
	cuerpo.height = 1.12
	_parte(figura, cuerpo, ropa, 0.58)
	var cabeza := SphereMesh.new()
	cabeza.radius = 0.22
	cabeza.height = 0.44
	_parte(figura, cabeza, Color("#c49a7f"), 1.10)
	if nombre != "Guardia":
		var capucha := CylinderMesh.new()
		capucha.bottom_radius = 0.25
		capucha.top_radius = 0.02
		capucha.height = 0.37
		_parte(figura, capucha, gorro, 1.39)
	var rotulo := Label3D.new()
	rotulo.text = nombre
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.position.y = 1.85
	rotulo.pixel_size = 0.012
	figura.add_child(rotulo)
	return figura


func _parte(figura: Node3D, malla: Mesh, color: Color, y: float) -> void:
	var parte := MeshInstance3D.new()
	parte.mesh = malla
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	parte.material_override = material
	parte.position.y = y
	figura.add_child(parte)


func _montar_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	var panel := MarginContainer.new()
	capa.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -115
	panel.offset_bottom = -12
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var textos := VBoxContainer.new()
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(textos)
	_objetivo = _etiqueta(textos, 18)
	_dialogo = _etiqueta(textos, 20)
	_pista = _etiqueta(textos, 17)


func _etiqueta(padre: Control, tam: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.add_theme_font_size_override("font_size", tam)
	etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	etiqueta.add_theme_constant_override("outline_size", 8)
	padre.add_child(etiqueta)
	return etiqueta
