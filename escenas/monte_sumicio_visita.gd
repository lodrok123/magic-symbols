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
const SUMICIU := preload("res://arte/piezas/sumicio/sumiciu.tscn")
const VisualSumiciu := preload("res://presentacion/sumiciu_3d.gd")
const VECINOS := ["Iria", "Brais", "Sabela"]
const COFRES := ["baya", "seta_asada", "resina"]
## 14/11: la quinta palloza es el gremio del gorro verde (DISENO_INTERIORES_SUMICIO.md). No es una familia: no tiene cofre ni frase de
## vecino, y quien despacha dentro cambia cosas (el trueque, tienda «gremio» en nucleo/datos/tiendas.tsv).
const GORRO_VERDE := "Gorro verde"
const TRUEQUE := "gremio"

enum Fase { PORTON, ESCOLTA, AUDIENCIA, LIBRE, REGRESO }

@onready var _maqueta: Maqueta = $"../Maqueta"
var _mid: Jugador3D
var _guardia: VisualSumiciu
var _cofre_uniforme: Cofre3D
var _fase := Fase.PORTON
var _paso := 0
var _parlamento := 0
var _objetivo: Label
var _dialogo: CajaDialogo
var _pista: Label
var _casas: Dictionary[Node3D, Interior] = {}
var _exteriores: Array[Node3D]
var _casa: Node3D
var _interior: Interior
var _fundido: ColorRect
var _en_transicion := false
var _posicion_en_torre := Vector3.ZERO
var _giro_exterior := 0.0
var _camara_gira_exterior := false
var _suelo_exterior_visible := true
var _espera_cancela := 0.0
const ESPERA_CANCELA := 0.9      ## s desde que el guardia da paso hasta que echa a andar (la cancela ya va medio abierta)


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
		var nombre: String = GORRO_VERDE if sala.gremio else ("Tendera" if sala.tienda else VECINOS[i])
		var oficio := 2 if sala.gremio else (VisualSumiciu.OFICIO_TENDERA if sala.tienda else 0)
		if sala.casa_brais:
			oficio = VisualSumiciu.OFICIO_ANCIANO
		if not sala.has_node("Iria"):
			var vecino := _figura(nombre, sala.centro + Interior.VECINO, oficio, sala)
			if sala.casa_brais:
				vecino.position += Vector3(-0.48, 0.0, -0.22)
		sala.hide()
		_casas[_exteriores[i]] = sala
	_montar_torre(mundo)
	_guardia = _figura("Guardia", Maqueta.celda(_maqueta.guardia), 0)
	_guardia.position = _maqueta.guardia.global_position
	var marimanta := _figura("Marimanta", Maqueta.celda(_maqueta.marimanta), 3, _sala_torre)
	marimanta.global_position = _maqueta.marimanta.global_position
	_sala_torre.registrar(marimanta, "marimanta")
	_cofre_uniforme = Cofre3D.en(_maqueta.cofre)
	Terreno3D.bloquear_celda(Terreno3D.celda_de(_maqueta.cofre.global_position), _maqueta.cofre)
	# Las partidas previas a este cofre ya podían haber recibido el uniforme de Marimanta.
	if Flags.i().tiene(ADMISION) and Atuendos.tiene(UNIFORME):
		Flags.i().poner(COFRE_UNIFORME)
	if Flags.i().tiene(COFRE_UNIFORME):
		_cofre_uniforme.abrir_ya()
	_montar_cofre_agua()
	EncargoMarimanta.sincronizar()
	Cartografia.jugador = Vector2i(-1, -1)      # el mapa sigue enseñando la Fraga, pero Mid no está en ella
	Niveles.precargar("Bosque_02")              # la vuelta a la Fraga ya leída cuando se pulse E
	var caco := _figura("Caco", Maqueta.celda(_maqueta.caco), 2)
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
		if absf(local.x) < 0.72 and local.z >= Terreno3D.casilla * (float(_interior.salida.y) + 0.12):
			_cruzar(null)
			return
		if not _interior.torre:
			if _interior.gremio:
				_objetivo.text = "Gremio del gorro verde"
			else:
				_objetivo.text = "Tienda y síntesis" if _interior.tienda else "Palloza familiar"
			_pista.text = _pista_interior()
			return
		# La Torre Verde: dentro se sigue con la audiencia, los cofres y Marimanta (abajo).
		var cambio := _sala_torre.cambio_por_posicion(_posicion_en_torre, _mid.position)
		_posicion_en_torre = _mid.position
		if cambio != 0:
			_cambiar_planta(cambio)
			return
	elif _fase != Fase.PORTON:
		var puerta := _puerta_cercana()
		if puerta != null:
			if _casas[puerta].tienda or Flags.i().tiene(COFRE_UNIFORME) or (_casas[puerta].torre and _fase != Fase.ESCOLTA):
				_cruzar(puerta)
				return
	if _fase == Fase.ESCOLTA:
		_avanzar_escolta(delta)
	_maqueta.mostrar_interiores(_mid.position)
	var objetivo := ""
	var pista := ""
	match _fase:
		Fase.PORTON:
			objetivo = "Sube a la cancela y habla con el guardia."
			if _cerca(_maqueta.guardia):
				pista = "[E] Hablar con el guardia"
		Fase.ESCOLTA:
			objetivo = "Sigue al guardia hasta la Torre Verde."
		Fase.AUDIENCIA:
			# 14/11: la audiencia es en el despacho (planta alta), así que dentro de la torre hay que decirle que suba.
			if _interior == null:
				objetivo = "Entra en la Torre Verde: la Maestre te espera dentro."
			elif _en_planta_de("marimanta"):
				objetivo = "Entrega el grimorio a Marimanta."
			else:
				objetivo = "Sube por la escalera hasta el despacho de la Maestre."
			if _en_planta_de("marimanta") and _cerca(_maqueta.marimanta):
				pista = "[E] Entregar el grimorio" if _parlamento == 0 else "[E] Continuar"
		Fase.LIBRE, Fase.REGRESO:
			objetivo = _objetivo_libre()
			if _cerca(_maqueta.caco):
				pista = "[E] Hablar con el caco"
			if _en_planta_de("marimanta") and _cerca(_maqueta.marimanta):
				pista = "[E] Hablar con Marimanta"
	if _cerca(_maqueta.inicio):
		pista = "[E] Volver a la Fraga"
	if _interior != null and _interior.torre and pista == "" and _en_planta_de("cofre_magico") and CofreMagico.cerca(get_tree(), _mid.position):
		pista = "[E] Cofre mágico"
	_objetivo.text = objetivo
	_pista.text = pista
	if Flags.i().tiene(ADMISION) and not Flags.i().tiene(COFRE_UNIFORME):
		_objetivo.text = "Recoge el uniforme del cofre detrás de Marimanta." if _en_planta_de("cofre_uniforme") \
			else "El uniforme está en el cofre del despacho: sube por la escalera."
	if _ante_cofre_agua():
		_pista.text = "[E] Abrir cofre legendario"
	elif _ante_cofre_uniforme():
		_pista.text = "[E] Abrir cofre épico" if Flags.i().tiene(ADMISION) else "[E] Examinar cofre épico"
	elif _puerta_cercana() != null and not Flags.i().tiene(COFRE_UNIFORME):
		_pista.text = "Puerta cerrada"
	if _interior != null and _interior.torre and _sala_torre != null:
		if _sala_torre.planta > 0:
			_objetivo.text = _sala_torre.nombre_planta()


func _unhandled_input(evento: InputEvent) -> void:
	if _en_transicion:
		return
	if not evento.is_action_pressed("interactuar"):
		return
	if _interactuar():
		get_viewport().set_input_as_handled()


func _interactuar() -> bool:
	if _interior != null and not _interior.torre:
		return _interactuar_dentro()
	if _interior != null and _puesto(_interior.salida):
		_cruzar(null)
		return true
	if _en_planta_de("cofre_magico") and CofreMagico.cerca(get_tree(), _mid.position):
		AlmacenUI.abrir_en(get_tree())
		return true
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
				_maqueta.abrir_porton(true)      # la cancela se abre a la vista de Mid
				_espera_cancela = ESPERA_CANCELA
				_dialogo.text = "Guardia · La Maestre te espera. Ve detrás de mí."
				return true
		Fase.AUDIENCIA:
			if _en_planta_de("marimanta") and _cerca(_maqueta.marimanta):
				_hablar_con_marimanta()
				return true
		Fase.LIBRE, Fase.REGRESO:
			if _en_planta_de("marimanta") and _cerca(_maqueta.marimanta):
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
	return "Encargo: mapa de Bosque 02 al %d %% (meta %d %%), planta y criatura (%d/3 hechos)." % [
		Cartografia.porcentaje_de(Cartografia.NIVEL_ENCARGO), Cartografia.META, EncargoMarimanta.pasos_hechos()]


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


func _vecino_al_alcance() -> bool:
	var iria := _interior.get_node_or_null("Iria") as VisualSumiciu
	if iria != null:
		return _distancia_plana(_mid.position, iria.global_position) < 1.7
	return _puesto(Interior.VECINO)


func _cofre_al_alcance() -> bool:
	if _interior.tienda or _interior.gremio:
		return false
	var cofre := _interior.get_node_or_null("Cofre") as Node3D
	return cofre != null and _distancia_plana(_mid.position, cofre.global_position) < Terreno3D.casilla + 0.10


func _pista_interior() -> String:
	if _puesto(_interior.salida):
		return "[E] Salir a Monte Sumicio"
	if _vecino_al_alcance():
		if _interior.gremio:
			return "[E] Trueque"
		return "[E] Ver mercancía" if _interior.tienda and Flags.i().tiene(COFRE_UNIFORME) else "[E] Hablar"
	if _interior.tienda and Flags.i().tiene(COFRE_UNIFORME) and _puesto(Interior.MESA):
		return "[E] Abrir mesa de síntesis"
	if _cofre_al_alcance():
		return "Cofre vacío" if Flags.i().tiene(_flag_cofre()) else "[E] Abrir cofre"
	return ""


func _interactuar_dentro() -> bool:
	if _puesto(_interior.salida):
		_cruzar(null)
	elif _vecino_al_alcance():
		if _interior.gremio:
			# 14/11: el gremio cambia cosas con cualquiera (es lo contrario de la tienda: no pide uniforme, al revés). Marimanta ya avisa
			# de ellos al despedirse: «no te fíes de los del gorro verde».
			_dialogo.text = "%s · Aquí no hay nada robado, aprendiza. Lo que te sobre, se cambia." % GORRO_VERDE
			Tiendas.abrir(TRUEQUE)
		elif _interior.tienda:
			var tendera := _interior.get_node("Tendera") as VisualSumiciu
			tendera.hablar()
			if Flags.i().tiene(COFRE_UNIFORME):
				_dialogo.text = "Tendera · Así que eres la nueva aprendiz. A ver qué necesitas."
				Tiendas.abrir(TIENDA)
			else:
				_dialogo.text = "Tendera · ¿Te has perdido, forastera? La tienda es para aprendices. La puerta la tienes ahí."
		else:
			var i := _exteriores.find(_casa)
			if _interior.casa_brais:
				var brais := _interior.get_node("Brais") as VisualSumiciu
				brais.hablar()
			elif i == 0:
				var iria := _interior.get_node("Iria") as VisualSumiciu
				iria.hablar()
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


## La casa cuya puerta tiene Mid delante. Se mide desde la bisagra de cada puerta (las pallozas la tienen en z 1,59; la torre, en su arco del sur).
func _puerta_cercana() -> Node3D:
	for casa in _casas:
		var local := casa.to_local(_mid.position) - _hueco_puerta(casa)
		# 14/11: hasta 0,55 por fuera (antes 0,26): desde que la casa choca por su malla, el cuerpo de Mid se queda en la cara del muro (~0,3 de la hoja).
		if absf(local.x) < 0.55 and local.z >= -0.44 and local.z <= 0.55:
			return casa
	return null


## El centro del vano de la puerta de `casa`, en local de la casa (la hoja mide ~0,8–1,1 y gira desde la bisagra de la izquierda).
func _hueco_puerta(casa: Node3D) -> Vector3:
	var b := _maqueta.bisagra(casa)
	return casa.to_local(b.global_position) + Vector3(float(b.get_meta("medio_ancho", 0.45)), 0.0, 0.0)


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
	_camara_gira_exterior = mundo.camara_gira
	_interior.show()
	if not _interior.tienda:
		_interior.mostrar_cofre(Flags.i().tiene(_flag_cofre()))
	_dialogo.text = ""
	if colocar:
		_colocar_mid(Maqueta.punto(_interior.centro + _interior.entrada), Vector3.FORWARD)
	if _interior.torre:
		# La cámara baja alcanza el terreno exterior por encima del muro del fondo.
		_suelo_exterior_visible = _maqueta.suelo.visible
		_maqueta.suelo.hide()
		var maestre_aula := _sala_torre.get_node_or_null("Plantas/Aula/Habitantes/MarimantaEnAula") as Node3D
		if maestre_aula != null:
			maestre_aula.visible = Flags.i().tiene(COFRE_UNIFORME)
		_posicion_en_torre = _mid.position
		mundo._giro_cam = 0.0
		mundo.camara_gira = false
		_interior.camara.make_current()
	else:
		_activar_camara_juego(mundo)


func _salir() -> void:
	var mundo := get_parent() as Mundo
	# La torre se deja siempre en la planta baja: así al volver a entrar se entra por el aula, y las casillas quedan como las dejó la puerta.
	if _sala_torre != null and _interior == _sala_torre:
		_maqueta.suelo.visible = _suelo_exterior_visible
		if _sala_torre.planta != 0:
			_sala_torre.ir_a_planta(0)
	var regreso := _casa.to_global(_hueco_puerta(_casa) + Vector3.BACK * 0.76)
	regreso.y = Terreno3D.y_pies(Terreno3D.celda_de(regreso))
	_colocar_mid(regreso, _casa.global_basis.z.normalized())
	_interior.hide()
	_interior = null
	_dialogo.text = ""
	mundo._giro_cam = _giro_exterior
	mundo.camara_gira = _camara_gira_exterior
	_activar_camara_juego(mundo)


func _activar_camara_juego(mundo: Mundo) -> void:
	mundo._foco = mundo._centro(_mid.pj)
	mundo._colocar_camara()
	mundo._camara.make_current()


func _colocar_mid(destino: Vector3, orientacion: Vector3) -> void:
	_mid.position = destino
	_mid.pj.position = destino
	_mid.pj.girar_hacia(orientacion, 1.0, TAU)
	_mid.vy = 0.0
	_mid.en_suelo = true


## ---- 14/11 · LAS PLANTAS DE LA TORRE (interior_torre.gd) ----

## Mid está en la planta donde vive `sitio` (`PUNTOS` de la torre), o no está en la torre. Las cinco plantas ocupan las MISMAS casillas
## del mundo, así que todo lo que se mide por distancia (Marimanta, el cofre del uniforme, el legendario, el cofre mágico) estaría al
## alcance desde cualquier planta si no se filtrase aquí.
func _en_planta_de(sitio: String) -> bool:
	if _sala_torre == null or _interior != _sala_torre:
		return true
	return int(_sala_torre.planta) == _sala_torre.planta_de(sitio)


## Sube o baja una planta, con el mismo fundido corto que las puertas.
func _cambiar_planta(delta: int) -> void:
	_en_transicion = true
	_pista.text = ""
	_mid.set_physics_process(false)
	_fundido.show()
	var animacion := create_tween()
	animacion.tween_property(_fundido, "color:a", 1.0, 0.14)
	await animacion.finished
	_sala_torre.ir_a_planta(_sala_torre.planta + delta)
	_colocar_mid(_sala_torre.llegada(delta), Vector3.FORWARD if delta > 0 else Vector3.BACK)
	_posicion_en_torre = _mid.position
	_dialogo.text = ""
	PlayLog.event("torre_planta", {"planta": _sala_torre.planta})
	_mid.set_physics_process(true)
	animacion = create_tween()
	animacion.tween_property(_fundido, "color:a", 0.0, 0.17)
	await animacion.finished
	_fundido.hide()
	_en_transicion = false


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
	# 14/11: el guardia no echa a andar hasta que las hojas de la cancela se han apartado (si no, las atraviesa mientras giran).
	if _espera_cancela > 0.0:
		_espera_cancela -= delta
		return
	# El guardia espera si Mid se detiene o se desvía.
	if _distancia_plana(_guardia.position, _mid.position) > 5.4:
		_guardia.andar(false)
		return
	var camino := _maqueta.escolta
	var meta := (camino.get_child(_paso) as Node3D).global_position
	# 14/11: la audiencia es DENTRO de la torre: el guardia se queda delante de la puerta y Mid entra sola.
	if _puerta_torre != null and meta.z <= _puerta_torre.global_position.z + Terreno3D.casilla * 1.2:
		_fase = Fase.AUDIENCIA
		_guardia.andar(false)
		_dialogo.text = "Guardia · La Maestre te espera dentro. Aquí termina mi camino."
		return
	var direccion := meta - _guardia.position
	if Vector2(direccion.x, direccion.z).length_squared() > 0.00001:
		_guardia.rotation.y = atan2(direccion.x, direccion.z)
	_guardia.andar(true)
	_guardia.position = _guardia.position.move_toward(meta, delta * 3.8)
	if not _guardia.position.is_equal_approx(meta):
		return
	_paso += 1
	if _paso == camino.get_child_count() - 1:
		_fase = Fase.AUDIENCIA
		_guardia.andar(false)
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
	"Marimanta · Empieza por ahí. Baja a la Fraga y haz su mapa: con que cartografíes algo más de la mitad del bosque me basta. Junto a la subida, identifica una planta y registra una criatura. Luego vuelve.",
	"Marimanta · Toma este cuaderno de campo. Se irá llenando conforme andes. (Se desbloquea la pestaña Mapa: tecla I y Q/E.)",
]
const RECORDATORIO := "Marimanta · El mapa de la Fraga, la planta y la criatura del sendero norte. Y nada de trampas: los mapas de la torre están prohibidos hasta el Nivel I."
const ENTREGA: Array = [
	"Marimanta · A ver ese cuaderno… El mapa de la Fraga, un helecho, un nido de mirlo. Limpio, para venir de Terra Fina.",
	"Marimanta · Te lo has ganado: abre el cofre de mi izquierda. Guarda una runa de agua. Aquí arriba no nos sirve de mucho: es más rápido bajar al río.",
]
const COFRE_LEGENDARIO := preload("res://arte/piezas/cofre_legendario.tscn")
var _cofre_agua: Cofre3D
var _nodo_cofre_agua: Node3D


## 14/11: LA TORRE VERDE POR DENTRO (escenas/InteriorTorre.tscn). La torre se cruza por su puerta animada como una palloza; dentro despacha
## Marimanta con sus cofres (el del uniforme, el legendario del encargo) y hay un cofre mágico. Los marcadores de la torre se llevan a la sala.
const SalaTorre = preload("res://escenas/interior_torre.gd")
var _sala_torre: SalaTorre
var _puerta_torre: Node3D
const PUERTA_TORRE_MODELO := preload("res://arte/meshy/piezas/puerta_torre_sumicio.glb")
## 14/11 (Pablo: «quita la puerta antigua de la torre e intégrala mejor»): la malla de la torre se usa SIN su puerta pintada
## (herramientas/hornear_torre_sin_puerta.gd) y la puerta nueva ocupa exactamente ese hueco: x −0,70..0,63, y 0..2,36, cara en z ≈ 3,6
## (local de la torre). La hoja de Meshy mide 0,612 × 1,0 × 0,133 centrada: se estira al hueco y su bisagra va en el borde izquierdo.
const PUERTA_TORRE_POMO := "res://arte/meshy/piezas/puerta_torre_sumicio_pomo.res"
const PUERTA_TORRE_TEXTURA := "res://arte/meshy/piezas/puerta_torre_sumicio_pomo.png"
const TORRE_SIN_PUERTA :="res://arte/meshy/piezas/torre_verde_sumicio_sin_puerta.res"
const HUECO_TORRE := Rect2(-0.70, 0.0, 1.33, 2.36)      ## x, y, ancho, alto del vano
const Z_PUERTA_TORRE := 3.62
const PUERTA_TORRE := Vector3(-0.70, 0.0, 3.62)          ## bisagra (borde izquierdo, abajo)
const TINTE_PUERTA_TORRE := Color(0.62, 0.5, 0.42)       ## la madera de Meshy es más naranja que la de la torre (#5f3711): se oscurece y apaga


func _montar_torre(mundo: Node) -> void:
	_sala_torre = mundo.get_node_or_null("Interiores/TorreVerde") as SalaTorre
	if _sala_torre == null:
		return
	_sala_torre.montar()
	_sala_torre.hide()
	var torre: Node3D = _maqueta.torre
	_puerta_torre = Node3D.new()
	_puerta_torre.name = "Puerta"
	torre.add_child(_puerta_torre)
	_puerta_torre.position = PUERTA_TORRE
	_puerta_torre.set_meta("medio_ancho", HUECO_TORRE.size.x * 0.5)
	# La torre sin la puerta pintada.
	if ResourceLoader.exists(TORRE_SIN_PUERTA):
		for m in torre.get_node("Modelo").find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).mesh = load(TORRE_SIN_PUERTA)
	# La hoja, estirada al hueco y con la madera de la torre.
	var hoja := PUERTA_TORRE_MODELO.instantiate() as Node3D
	var escala := Vector3(HUECO_TORRE.size.x / 0.612, HUECO_TORRE.size.y, 1.3)
	hoja.scale = escala
	hoja.position = Vector3(0.306 * escala.x, 0.5 * escala.y, 0.0)
	for m in hoja.find_children("*", "MeshInstance3D", true, false):
		var mm := m as MeshInstance3D
		if ResourceLoader.exists(PUERTA_TORRE_POMO):
			mm.mesh = load(PUERTA_TORRE_POMO)        # el aldabón, a media altura del lado (herramientas/hornear_puerta_torre_pomo.gd)
		var mat := (mm.get_active_material(0) as BaseMaterial3D).duplicate() as BaseMaterial3D
		mat.albedo_color = TINTE_PUERTA_TORRE
		if ResourceLoader.exists(PUERTA_TORRE_TEXTURA):
			mat.albedo_texture = load(PUERTA_TORRE_TEXTURA)    # sin la sombra pintada donde estaba el aldabón
		mm.material_override = mat
	_puerta_torre.add_child(hoja)
	# El vano en penumbra detrás (como el FondoVano de las pallozas): al abrir se ve el interior a oscuras, no el hueco de la malla.
	var vano := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(HUECO_TORRE.size.x + 0.1, HUECO_TORRE.size.y + 0.05, 0.04)
	vano.mesh = caja
	var oscuro := StandardMaterial3D.new()
	oscuro.albedo_color = Color("#140f0b")
	oscuro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vano.material_override = oscuro
	torre.add_child(vano)
	vano.position = Vector3(HUECO_TORRE.get_center().x, HUECO_TORRE.size.y * 0.5, Z_PUERTA_TORRE - 0.22)
	_casas[torre] = _sala_torre
	# Lo de la audiencia, dentro de la sala.
	_maqueta.marimanta.global_position = _sala_torre.punto("marimanta")
	_maqueta.cofre.global_position = _sala_torre.punto("cofre_uniforme")
	# 14/11: cada cofre choca con su modelo (antes, la casilla entera): se apuntan al crearse (aquí el mágico; los otros dos, en `_montar`).
	var magico := CofreMagico.poner_en(_sala_torre, _sala_torre.punto("cofre_magico"))
	Terreno3D.bloquear_celda(Terreno3D.celda_de(magico.global_position), magico)
	# 14/11: cada uno se ve solo en su planta. El cofre del uniforme NO es hijo de la sala (vive en la maqueta), así que la sala no puede
	# encontrarlo por su cuenta: se le apunta aquí, igual que Marimanta y el mágico.
	_sala_torre.registrar(_maqueta.marimanta, "marimanta")
	_sala_torre.registrar(_maqueta.cofre, "cofre_uniforme")
	_sala_torre.registrar(magico, "cofre_magico")


func _hablar_con_marimanta() -> void:
	_dialogo.tecla = "[E] continuar" if _parlamento < AUDIENCIA.size() - 1 else ""
	_dialogo.text = String(AUDIENCIA[mini(_parlamento, AUDIENCIA.size() - 1)])
	_dialogo.tecla = ""
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
	if _sala_torre != null:
		_sala_torre.add_child(_nodo_cofre_agua)
		_nodo_cofre_agua.global_position = _sala_torre.punto("cofre_agua")
		_sala_torre.registrar(_nodo_cofre_agua, "cofre_agua")
	else:
		_maqueta.torre.add_child(_nodo_cofre_agua)
		_nodo_cofre_agua.position = Vector3(-2.3, 0.0, -2.85)
	_cofre_agua = Cofre3D.en(_nodo_cofre_agua)
	Terreno3D.bloquear_celda(Terreno3D.celda_de(_nodo_cofre_agua.global_position), _nodo_cofre_agua)
	if Flags.i().tiene(EncargoMarimanta.COFRE_AGUA):
		_cofre_agua.abrir_ya()
	elif Flags.i().tiene(EncargoMarimanta.ENTREGADO):
		_cofre_agua.aparecer_ya()
	else:
		_cofre_agua.ocultar()


func _ante_cofre_agua() -> bool:
	return _cofre_agua != null and not _cofre_agua.esta_oculto() and not Flags.i().tiene(EncargoMarimanta.COFRE_AGUA) \
		and _en_planta_de("cofre_agua") \
		and _distancia_plana(_mid.position, _nodo_cofre_agua.global_position) < 1.65


func _abrir_cofre_agua() -> void:
	if not _cofre_agua.abrir():
		return
	Flags.i().poner(EncargoMarimanta.COFRE_AGUA)
	var agua_nueva: bool = not Repertoire.element_active("agua")
	EncargoMarimanta.dar_sello_agua()
	if agua_nueva:
		LaminaGlifo.mostrar(self, "agua", true, true)          # 23/11: la ficha del sello nuevo (pausa y se cierra con E/clic)
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
	return not Flags.i().tiene(COFRE_UNIFORME) and _en_planta_de("cofre_uniforme") and _distancia_plana(
		_mid.position, _cofre_uniforme.get_parent().global_position) < 1.65


func _cerca(marcador: Node3D) -> bool:
	return _distancia_plana(_mid.position, marcador.global_position) < 2.7


static func _distancia_plana(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _figura(nombre: String, c: Vector2i, oficio: int, padre: Node3D = null) -> VisualSumiciu:
	var figura := SUMICIU.instantiate() as VisualSumiciu
	figura.name = nombre
	figura.nombre_visible = nombre
	figura.oficio = oficio
	if oficio == 3:
		figura.estatura = 1.05
	elif nombre == "Guardia":
		figura.estatura = 1.16
	var contenedor: Node = self if padre == null else padre
	contenedor.add_child(figura)
	figura.global_position = Maqueta.punto(c)
	return figura


func _montar_hud() -> void:
	# 14/11 (playtest: «los textos quedan opacados abajo»): el diálogo va en la caja de pergamino (CajaDialogo); el objetivo, en una plaquita arriba
	# en el centro; la pista de la tecla, en otra plaquita abajo a la derecha, encima de la caja.
	_dialogo = CajaDialogo.new()
	_dialogo.dura_s = 12.0
	add_child(_dialogo)
	var capa := CanvasLayer.new()
	capa.layer = 6
	add_child(capa)
	_objetivo = _plaquita(capa, 17, Control.PRESET_CENTER_TOP, Vector2(0, 14))
	_pista = _plaquita(capa, 17, Control.PRESET_BOTTOM_RIGHT, Vector2(-24, -150))   # encima de la rueda de consumibles (abajo a la derecha)


## Una etiqueta con su fondo de pergamino que se ve solo cuando tiene texto.
func _plaquita(capa: CanvasLayer, tam: int, ancla: Control.LayoutPreset, margen: Vector2) -> Label:
	var raiz := Control.new()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(raiz)
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var caja := PanelContainer.new()
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var papel := TemaInterfaz.caja_panel(TemaInterfaz.PERGAMINO_DIALOGO, Color("947047"), 1)
	papel.content_margin_left = 14.0
	papel.content_margin_right = 14.0
	papel.content_margin_top = 6.0
	papel.content_margin_bottom = 6.0
	caja.add_theme_stylebox_override("panel", papel)
	raiz.add_child(caja)
	caja.set_anchors_and_offsets_preset(ancla, Control.PRESET_MODE_MINSIZE)
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH if ancla == Control.PRESET_CENTER_TOP else Control.GROW_DIRECTION_BEGIN
	caja.grow_vertical = Control.GROW_DIRECTION_END if ancla == Control.PRESET_CENTER_TOP else Control.GROW_DIRECTION_BEGIN
	caja.position += margen
	var etiqueta := Label.new()
	etiqueta.add_theme_font_override("font", TemaInterfaz.fuente())
	etiqueta.add_theme_font_size_override("font_size", tam)
	etiqueta.add_theme_color_override("font_color", Color("32271e"))
	caja.add_child(etiqueta)
	caja.hide()
	return etiqueta


## Las plaquitas se ven solo con texto (el texto lo pone `_physics_process`).
func _process(_delta: float) -> void:
	for l in [_objetivo, _pista]:
		if l != null:
			(l.get_parent() as Control).visible = l.text != ""
