class_name Reactivo3D
extends Area3D

## OBJETOS DEL TEST 2 QUE REACCIONAN A UN HECHIZO EN 3D (tarea 4.7). Dueño: Pipeline.
##
## Un solo nodo con varios `tipo`, que implementa el contrato on_spell_hit de Lanzador3D (diario, 2026-10-06 00:50):
## es un Area3D en la capa CAPA_REACTIVO, decide por `rune_data.tags` y trae `spell_reacts`, `carried_element` y
## `nivel_altura`. Las reglas son las del 2D (combustible.gd, fogata.gd, nivel_base.gd: Interruptor, PlacaPeso, puente)
## y las de docs/ESTADOS_SUELO.md §1.6. Los estados se ven por MATERIAL (tinte, emisión, escala), no por PNG.
##
##   seto · tronco · telarana   arden: calor o rayo prenden → CHAMUSCADO (se oscurece) → desaparecen con su cuerpo; agua o
##                              frío los apagan (vuelven a estar sanos); contagian a ≤ 1,7 casillas cada 0,8 s y el viento,
##                              en su cono, a ≤ 3,6. Seto, tronco y telaraña son muro hasta que se queman.
##   totem (fuego|agua|rayo)    se activa con SU elemento (calor · agua · rayo/eléctrico) y se queda: brilla, suelta motas.
##   fogata · brasero           fuego de mapa: calor lo enciende, agua o frío lo apagan; si arde, el viento se lleva la llama.
##                              El brasero es la "antorcha" del Test 2 (empieza apagado); la fogata, empieza encendida.
##   puente                     plegado (levantado, la casilla bloquea) hasta `tender()`, que lo baja. No oye hechizos:
##                              lo tiende el tótem de rayo.
##   placa                      se hunde y se queda cuando algo con peso la pisa (nodo del grupo GRUPO_PESO: bloque de
##                              tierra del Lanzador o empujable). El jugador no pesa.
##   emisor_rayo                9.7 · fuente eléctrica del Bosque 1 (letra `e`): cristal con chispas y destellos PERMANENTES.
##                              No oye hechizos; la corriente por el agua la mete el Juego (emisor_rayo_3d.gd, 9.10).
##   puerta_goblin · torre_goblin  10/10 · madera del campamento goblin (letras `y` y `o`): arden como un seto grande y se
##                              consumen (la puerta deja libre el paso). Nacen con la pieza de su mismo nombre.
##   surtidor                   9.7 · fuente de piedra (letra `u`): con agua echa un chorro, se llena su pila y emite
##                              `activado("surtidor", "agua")` (cada vez). Llenar el cauce es cosa del Juego (9.11).
##                              Con la pieza `tinaja_ruina` (10/10) es una TINAJA con cuatro estados: vacía → llenándose
##                              (T_LLENADO s, sube el agua dentro) → inclinándose (T_INCLINA s, de INCLINA_DESDE° a INCLINA_HASTA°)
##                              → vertiendo (chorro por el pico, gotas y arroyo hacia +Z local hasta la casilla de
##                              delante). Emite `activado` AL EMPEZAR a verter, una sola vez; se queda vertiendo.
##
## Quien lo coloca (PruebaTest2._reactivo) pone antes `fx`, `celda` y `visual`, y conecta `consumido` para liberar la casilla.

signal consumido(celda: Vector2i)
## tipo, elemento ("" si no aplica): tótem activado, fuente encendida/apagada, puente tendido, placa pisada.
signal activado(tipo: String, elemento: String)
## Solo la tinaja: el arroyo ha llegado al canal (T_CAUDAL s después de empezar a caer el agua). Es la señal para llenar el canal:
## llenarlo con `activado` (que sale al empezar a verter) lo haría arrancar antes de que el agua lo alcance.
signal agua_llega

const GRUPO_ARDE: String = "flammable3d"
const GRUPO_REACTIVO: String = "reactivo3d"
const GRUPO_PESO: String = "peso"          ## lo que pesa lo tiene que poner el Juego (bloque de tierra) y el empujable
const S: float = 2.3                       ## lado de una casilla (el de PruebaTest2.S)

const CONTAGIO: float = 1.7 * S            ## 110 px del 2D
const CONTAGIO_VIENTO: float = 3.6 * S     ## 230 px
const PUNTO_VIENTO: float = 0.3
const INTERVALO_CONTAGIO: float = 0.8
const FUNDIDO: float = 0.6
const CHAMUSCADO: Color = Color(0.3, 0.25, 0.22)
const APAGADO: Color = Color(0.72, 0.7, 0.72)          ## la pira apagada del 2D
const COLOR_ELEMENTO: Dictionary = {
	"fuego": Color(1.0, 0.55, 0.25), "agua": Color(0.45, 0.75, 1.0), "rayo": Color(1.0, 0.92, 0.4),
}

## tipo -> [segundos ardiendo, escala de las llamas, medio lado de la zona que arde (u), alto del cuerpo (u)]
const COMBUSTIBLES: Dictionary = {
	"seto": [3.5, 1.0, 0.8, 1.3], "tronco": [4.0, 0.8, 0.8, 0.7], "telarana": [1.6, 0.8, 0.7, 2.0],
	# 10/10 (campamento goblin): la madera de la puerta y de la torre. Más tiempo que un seto (son grandes) y llamas más grandes.
	"puerta_goblin": [5.0, 1.3, 1.4, 1.8], "torre_goblin": [7.0, 1.5, 1.0, 3.2],
}
## Cuerpo ancho (u) de lo que no cabe en una casilla: la zona donde le acierta un hechizo. Lo demás: 0,9 casillas.
const ANCHO_CUERPO: Dictionary = {"puerta_goblin": S * 1.6, "surtidor": S * 1.5}
## Fondo (u) del cuerpo cuando no es 0,9 casillas. La tinaja es un cuerpo grande: su zona envuelve la panza, la boca y el pedestal
## aunque se incline, para que el hechizo le acierte donde se ve.
const FONDO_CUERPO: Dictionary = {"surtidor": S * 1.5}
## tipo -> [alto de las llamas sobre el suelo (u), escala de las llamas, radio de la zona que arde, alto del cuerpo]
const FUENTES: Dictionary = {
	"fogata": [0.1, 0.8, 0.25, 0.6], "brasero": [1.25, 0.65, 0.12, 1.4],
}
const ALTO_TOTEM: float = 1.8

enum EstadoObj { SANO, ARDIENDO, CONSUMIDO }

var tipo: String = ""
var elemento: String = ""
var celda: Vector2i = Vector2i.ZERO
var fx: Vfx3D = null
var visual: Node3D = null
var start_lit: bool = false          ## fogata: nace encendida
## Lo que el nivel hace para que el fuego de un objeto prenda la hierba: (posicion: Vector3, radio: float, viento: Vector3).
var hierba_cerca: Callable = Callable()

var estado: EstadoObj = EstadoObj.SANO
var is_lit: bool = false             ## arde (igual que en el 2D: el hielo y el viento lo miran)
var activo: bool = false             ## tótem activado
var usado: bool = false              ## placa pisada / puente tendido

var _mats: Array = []                ## [material copiado (StandardMaterial3D o el ShaderMaterial de Ocluso3D), Color original]
var _sprites: Array = []             ## [SpriteBase3D, Color original]
var _llama: Node3D = null
var _luz: OmniLight3D = null
var _t: float = 0.0
var _t_contagio: float = 0.0
var _k: float = 0.0                  ## 0 sano … 1 chamuscado
var _tween: Tween = null
var _disco: MeshInstance3D = null
var _motas: Node3D = null
var _plegado: bool = true


## Se llama una vez, con `visual` ya hijo (o sin él), antes de añadirlo al árbol.
func preparar(p_tipo: String, p_celda: Vector2i, p_elemento: String, p_fx: Vfx3D, p_visual: Node3D) -> void:
	tipo = p_tipo
	celda = p_celda
	elemento = p_elemento
	fx = p_fx
	visual = p_visual


func _ready() -> void:
	add_to_group(GRUPO_REACTIVO)
	var reacciona: bool = tipo != "puente"
	collision_layer = Lanzador3D.CAPA_REACTIVO if reacciona else 0
	collision_mask = 0xFFFFF if tipo == "placa" else 0
	monitoring = tipo == "placa"
	monitorable = reacciona
	var alto: float = _alto_cuerpo()
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(float(ANCHO_CUERPO.get(tipo, S * (0.7 if tipo == "placa" else 0.9))), alto, float(FONDO_CUERPO.get(tipo, S * (0.7 if tipo == "placa" else 0.9))))
	forma.shape = caja
	forma.position = Vector3(S * 0.5 if tipo == "puente" else 0.0, alto * 0.5, 0.0)
	add_child(forma)
	_recoger_materiales()
	if COMBUSTIBLES.has(tipo):
		add_to_group(GRUPO_ARDE)
	match tipo:
		"totem":
			_montar_totem()
		"fogata", "brasero":
			_montar_fuente()
		"puente":
			rotation.z = deg_to_rad(80.0)       # plegado: levantado contra la orilla
		"placa":
			_pintar_emision(Color(0.5, 0.9, 0.6), 0.0)
		"emisor_rayo":
			_montar_emisor()
		"surtidor":
			_montar_surtidor()
	set_process(false)
	set_physics_process(tipo == "placa")


func _alto_cuerpo() -> float:
	if COMBUSTIBLES.has(tipo):
		return float((COMBUSTIBLES[tipo] as Array)[3])
	if FUENTES.has(tipo):
		return float((FUENTES[tipo] as Array)[3])
	match tipo:
		"totem":
			return ALTO_TOTEM
		"placa":
			return 0.3
		"puente":
			return 0.3
		"emisor_rayo":
			return 1.4
		"surtidor":
			return 2.0       # la tinaja mide 1,5 y su boca sube al inclinarse
	return 1.0


## --- Contrato con los hechizos (Lanzador3D) ---

func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO) -> void:
	if rune_data == null:
		return
	var calor: bool = rune_data.tags.has("calor")
	var rayo: bool = rune_data.tags.has("rayo") or rune_data.tags.has("electrico")
	var humedo: bool = rune_data.tags.has("agua") or rune_data.tags.has("frio")
	if COMBUSTIBLES.has(tipo):
		if calor or rayo:
			ignite(Lanzador3D.ultimo_impacto)
		elif humedo and estado == EstadoObj.ARDIENDO:
			_apagar()
		elif rune_data.tags.has("viento") and estado == EstadoObj.ARDIENDO:
			_contagiar(CONTAGIO_VIENTO, direccion)
		return
	match tipo:
		"totem":
			if not activo and _le_toca(rune_data):
				_activar_totem()
		"fogata", "brasero":
			if calor and not is_lit:
				_encender(true)
			elif humedo and is_lit:
				_apagar_fuente()
		"surtidor":
			if rune_data.tags.has("agua"):
				brotar()


## ¿Cambiaría algo este hechizo aquí? Si no, lo atraviesa.
func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	if rune_data == null:
		return false
	var calor: bool = rune_data.tags.has("calor")
	var rayo: bool = rune_data.tags.has("rayo") or rune_data.tags.has("electrico")
	var humedo: bool = rune_data.tags.has("agua") or rune_data.tags.has("frio")
	if COMBUSTIBLES.has(tipo):
		if calor or rayo:
			return estado == EstadoObj.SANO
		return (humedo or rune_data.tags.has("viento")) and estado == EstadoObj.ARDIENDO
	match tipo:
		"totem":
			return not activo and _le_toca(rune_data)
		"fogata", "brasero":
			if calor:
				return not is_lit
			return humedo and is_lit
		"surtidor":
			return rune_data.tags.has("agua")
	return false


## Lo que el viento puede llevarse: una llama si arde.
func carried_element() -> RuneData:
	return _runa_fuego() if is_lit else null


## Niveles de alto que ocupa (0 = a ras): lo que choca con un proyectil normal tiene 1.
func nivel_altura() -> int:
	return 0 if (tipo == "fogata" or tipo == "puente" or tipo == "placa") else 1


static func _runa_fuego() -> RuneData:
	var r := RuneData.new()
	r.display_name = "Fuego"
	var t: Array[String] = ["fuego", "calor"]
	r.tags = t
	return r


func _le_toca(rune_data: RuneData) -> bool:
	match elemento:
		"fuego":
			return rune_data.tags.has("calor")
		"agua":
			return rune_data.tags.has("agua")
	return rune_data.tags.has("rayo") or rune_data.tags.has("electrico")


## --- Objetos que arden ---

func can_burn() -> bool:
	return COMBUSTIBLES.has(tipo) and estado == EstadoObj.SANO


func ignite(_desde: Vector3 = Vector3.INF) -> void:
	if not can_burn():
		return
	estado = EstadoObj.ARDIENDO
	is_lit = true
	_t = 0.0
	_t_contagio = 0.0
	var d: Array = COMBUSTIBLES[tipo]
	_llama = fx.llamas(global_position, float(d[1]), float(d[2]))
	_luz = _crear_luz(Color(1.0, 0.6, 0.3), 0.9, 3.0, Vector3(0.0, 0.8, 0.0))
	_ver_ardiendo(true)
	_animar_k(1.0)
	set_process(true)
	if hierba_cerca.is_valid():
		hierba_cerca.call(global_position, CONTAGIO, Vector3.ZERO)


func _process(delta: float) -> void:
	if estado != EstadoObj.ARDIENDO:
		return
	_t += delta
	_t_contagio += delta
	if _t_contagio >= INTERVALO_CONTAGIO:
		_t_contagio = 0.0
		_contagiar(CONTAGIO, Vector3.ZERO)
	if _t >= float((COMBUSTIBLES[tipo] as Array)[0]):
		_consumir()


func _apagar() -> void:
	estado = EstadoObj.SANO
	is_lit = false
	_quitar_fuego()
	_ver_ardiendo(false)
	_animar_k(0.0)
	fx.vapor(global_position + Vector3(0.0, 0.5, 0.0))
	set_process(false)


func _consumir() -> void:
	estado = EstadoObj.CONSUMIDO
	is_lit = false
	_quitar_fuego()
	fx.ceniza(global_position)
	collision_layer = 0
	remove_from_group(GRUPO_ARDE)
	consumido.emit(celda)
	set_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.0, 0.05, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for s in _sprites:
		tw.tween_property(s[0], "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(queue_free)


## La telaraña de modelos (PruebaTest2._poner_telarana) trae dos hijas en `visual`: "sana" y "ardiendo" (la red con brasas).
## Sin ellas (la de Formas3D, otro combustible) no hace nada: basta el chamuscado del material.
func _ver_ardiendo(si: bool) -> void:
	if visual == null:
		return
	var sana: Node3D = visual.get_node_or_null("sana") as Node3D
	var ardiendo: Node3D = visual.get_node_or_null("ardiendo") as Node3D
	if sana == null or ardiendo == null:
		return
	sana.visible = not si
	ardiendo.visible = si


func _quitar_fuego() -> void:
	if _llama != null and is_instance_valid(_llama):
		fx.apagar(_llama)
	_llama = null
	if _luz != null and is_instance_valid(_luz):
		_luz.queue_free()
	_luz = null


## Contagia a los objetos que arden de alrededor (y a la hierba, vía `hierba_cerca`): `viento` ≠ 0 = solo en su cono.
func _contagiar(radio: float, viento: Vector3) -> void:
	for otro in get_tree().get_nodes_in_group(GRUPO_ARDE):
		if otro == self or not is_instance_valid(otro) or not otro.has_method("can_burn") or not otro.can_burn():
			continue
		var hacia: Vector3 = (otro as Node3D).global_position - global_position
		hacia.y = 0.0
		if hacia.length() > radio:
			continue
		if viento != Vector3.ZERO and hacia.normalized().dot(viento.normalized()) < PUNTO_VIENTO:
			continue
		otro.ignite(global_position)
	if hierba_cerca.is_valid():
		hierba_cerca.call(global_position, radio, viento)


## --- Tótems ---

func _montar_totem() -> void:
	var c: Color = COLOR_ELEMENTO.get(elemento, Color.WHITE)
	# Círculo rúnico en el suelo (pieza 3D plana, Formas3D "runa"): apagado = casi del color del suelo; al activarse, el del elemento.
	_disco = Formas3D.instancia("runa", c.lerp(Color(0.62, 0.6, 0.56), 0.72))
	_disco.scale = Vector3(S * 1.1, 1.0, S * 1.1)
	_disco.position = Vector3(0.0, 0.02, 0.0)      # = Y_DECAL - ALTO de prueba_test2.gd: una sola altura para todo decal
	add_child(_disco)
	_pintar_emision(c, 0.0)


func _activar_totem() -> void:
	activo = true
	var c: Color = COLOR_ELEMENTO.get(elemento, Color.WHITE)
	_luz = _crear_luz(c, 1.0, 3.5, Vector3(0.0, 1.4, 0.0))
	fx.chispazo(global_position + Vector3(0.0, 1.0, 0.0), elemento)
	# Motas sutiles que se quedan saliendo de la runa (como `_particulas_runa` del 2D).
	_motas = Node3D.new()
	_motas.position = Vector3(0.0, 1.1, 0.12)
	add_child(_motas)
	var gp: GPUParticles3D = fx.chispas_mano(elemento, 1.2)
	_motas.add_child(gp)
	if elemento == "rayo":
		# Encendido para siempre: chispas eléctricas continuas por el suelo.
		var suelo: GPUParticles3D = fx.chispas_mano("rayo", 1.6)
		suelo.position = Vector3(0.0, 0.1, 0.0)
		(suelo.process_material as ParticleProcessMaterial).emission_sphere_radius = S * 0.4
		_motas.add_child(suelo)
		suelo.global_position = global_position + Vector3(0.0, 0.1, 0.0)
	_animar_k(1.0)
	if _disco != null:
		_disco.set_surface_override_material(0, Formas3D.material_tinte(c, true))
	activado.emit("totem", elemento)


## --- Fogatas y braseros ---

func _montar_fuente() -> void:
	if start_lit:
		_encender(false)
	else:
		_pintar_tinte(1.0)


func _encender(con_efectos: bool) -> void:
	is_lit = true
	var d: Array = FUENTES[tipo]
	_llama = fx.llamas(global_position + Vector3(0.0, float(d[0]), 0.0), float(d[1]), float(d[2]), 1)   # 6.15: una sola lengua
	_luz = _crear_luz(Color(1.0, 0.6, 0.3), 1.1, 3.0, Vector3(0.0, float(d[0]) + 0.7, 0.0))
	_pintar_tinte(0.0)
	_pintar_emision(Color(1.0, 0.55, 0.25), 0.25)
	if con_efectos:
		fx.chispazo(global_position + Vector3(0.0, float(d[0]) + 0.3, 0.0), "fuego")
		activado.emit(tipo, "fuego")


func _apagar_fuente() -> void:
	is_lit = false
	_quitar_fuego()
	_pintar_tinte(1.0)
	_pintar_emision(Color.BLACK, 0.0)
	fx.ceniza(global_position + Vector3(0.0, float((FUENTES[tipo] as Array)[0]), 0.0))
	activado.emit(tipo, "")


## --- 9.7 · Fuente eléctrica y surtidor (Bosque 1) ---

const COLOR_RAYO: Color = Color(1.0, 0.92, 0.4)
var _agua_pila: MeshInstance3D = null    ## surtidor: el agua de la pila (invisible hasta el primer chorro)
var _t_chispa: Timer = null              ## emisor_rayo: cada cuánto salta un chispazo grande


## Chispas que no paran (dos emisores a distinta altura), luz amarilla que parpadea a golpes irregulares y, cada 1–2,5 s,
## un chispazo grande en un punto al azar del cristal. Por qué tanto: es lo único que dice «esto da corriente» antes de que
## el jugador vea el agua electrificada.
## Tiñe el modelo del cristal de amarillo (material propio por malla, con un brillo suave).
func _tinte_amarillo(nodo: Node) -> void:
	Pieza3D.tinte_amarillo(nodo)      # 13/10: el mismo tinte que el marcador `e` en el editor (vive en Pieza3D)


func _montar_emisor() -> void:
	_pintar_emision(COLOR_RAYO, 0.6)
	if visual != null:
		_tinte_amarillo(visual)          # 12/10: el cristal es amarillo con chispas, no azul (el modelo trae el azul de serie)
	_motas = Node3D.new()
	add_child(_motas)
	# 13/10 (Pablo): las chispas del cristal, mucho más sutiles: menos, más pequeñas y apagadas (BRILLO_CHISPAS_CRISTAL).
	for alto in [0.7, 1.35]:
		var gp: GPUParticles3D = fx.chispas_mano("rayo", 1.5)
		(gp.process_material as ParticleProcessMaterial).emission_sphere_radius = 0.45
		gp.amount = 4
		Vfx3D.atenuar(gp, BRILLO_CHISPAS_CRISTAL)
		_motas.add_child(gp)
		gp.global_position = global_position + Vector3(0.0, float(alto), 0.0)
	_luz = _crear_luz(COLOR_RAYO, LUZ_CRISTAL, 4.0, Vector3(0.0, 1.3, 0.0))
	var tw := _luz.create_tween().set_loops()
	for e in [1.7, 0.6, 1.3, 0.4, 1.9, 0.8]:          # parpadeo de tubo que falla, no un seno suave
		tw.tween_property(_luz, "light_energy", float(e) * LUZ_CRISTAL, 0.07)
		tw.tween_interval(0.05 + 0.1 * float(e))
	_t_chispa = Timer.new()
	_t_chispa.one_shot = true
	add_child(_t_chispa)
	_t_chispa.timeout.connect(_chispa_grande)
	_t_chispa.start(randf_range(0.5, 1.5))


func _chispa_grande() -> void:
	if fx != null:
		fx.chispazo_suave(global_position + Vector3(randf_range(-0.4, 0.4), randf_range(0.6, 1.5), randf_range(-0.4, 0.4)),
			COLOR_RAYO)
	_t_chispa.start(randf_range(2.5, 5.0))         # 13/10: menos a menudo (antes cada 1-2,5 s) y más pequeño


## 13/10 (Pablo: «mucho más sutiles»): brillo de las chispas del cristal (1 = el de antes) y energía de su luz (antes 1).
const BRILLO_CHISPAS_CRISTAL: float = 0.4
const LUZ_CRISTAL: float = 0.4


## La pila de piedra alrededor del pilar (la pieza `pilar` es el visual) y su agua, apagada hasta el primer chorro.
func _montar_surtidor() -> void:
	if visual != null and (visual.name == "tinaja_ruina" or visual.find_child("tinaja_ruina", true, false) != null):
		_montar_tinaja()
		return
	var piedra := StandardMaterial3D.new()
	piedra.albedo_color = Color(0.58, 0.56, 0.52)
	piedra.roughness = 0.95
	var borde := CylinderMesh.new()
	borde.top_radius = 0.95
	borde.bottom_radius = 1.0
	borde.height = 0.3
	borde.material = piedra
	var pila := MeshInstance3D.new()
	pila.mesh = borde
	pila.position = Vector3(0.0, 0.15, 0.0)
	add_child(pila)
	var agua := StandardMaterial3D.new()
	agua.albedo_color = Color(0.35, 0.62, 0.9, 0.85)
	agua.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	agua.roughness = 0.1
	agua.emission_enabled = true
	agua.emission = Color(0.2, 0.45, 0.7)
	agua.emission_energy_multiplier = 0.3
	var disco := CylinderMesh.new()
	disco.top_radius = 0.85
	disco.bottom_radius = 0.85
	disco.height = 0.02
	disco.material = agua
	_agua_pila = MeshInstance3D.new()
	_agua_pila.mesh = disco
	_agua_pila.position = Vector3(0.0, 0.31, 0.0)
	_agua_pila.visible = false
	add_child(_agua_pila)


## El surtidor echa agua: columna de agua de 2 s, salpicadura en la pila y la pila se llena (se queda llena). Público para que
## el Juego lo dispare también sin hechizo (p. ej. al cargar una partida con el cauce ya lleno).
func brotar(instantaneo: bool = false) -> void:
	if _es_tinaja:
		_brotar_tinaja(instantaneo)
		return
	if fx != null:
		fx.lanzar_forma("columna", "agua", global_position, global_position, {"dura": 2.0})
		fx.salpicadura(global_position + Vector3(0.0, 0.32, 0.0), 0.6)
	if _agua_pila != null and not _agua_pila.visible:
		_agua_pila.visible = true
		_agua_pila.scale = Vector3(0.2, 1.0, 0.2)
		_agua_pila.create_tween().tween_property(_agua_pila, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	usado = true
	activado.emit("surtidor", "agua")


## --- Tinaja de ruinas (10/10): vacía → llenándose → vertiendo ---
## Medidas en unidades de juego, en el espacio local del reactivo (la pieza mide 1,5 de alto y mira hacia +Z con giro 0).
## Medidas sobre el modelo (ruinas_agua.glb, ×2,70): el pico es la muesca del borde. Si cambias la pieza, mídelas de nuevo.
const BOCA_PICO: Vector3 = Vector3(0.16, 1.1, 0.52)      ## por dónde se derrama, con la tinaja SIN inclinar
## La boca está medida sobre la malla (10/10, mapa de alturas visto desde arriba): el borde es un anillo casi plano, inclinado ~17° hacia
## +X, con plano y = -0,288 x - 0,095 z + 1,396. La tinaja es un cuello abierto y hueco (el interior se ve opaco).
const BOCA_CENTRO: Vector3 = Vector3(0.254, 1.307, 0.158)   ## centro del borde de la boca, sobre el plano del anillo
const BOCA_RADIO: float = 0.26                              ## radio del borde exterior (por donde se derrama al inclinar)
const BOCA_NORMAL: Vector3 = Vector3(0.288, 1.0, 0.095)     ## normal del plano del borde (sin normalizar): el cuello apunta así
const AGUA_RADIO: float = 0.15                              ## el agua de dentro: un disco más estrecho que el hueco (~0,17)…
const AGUA_PROFUNDIDAD: float = 0.14                        ## …y metido por el cuello, por debajo del borde: así los lados del cuello lo tapan
const VUELO_Z: float = 0.4                               ## velocidad horizontal del chorro al salir (u/s)
const GRAVEDAD_CHORRO: float = 9.8
const SUELO_CHORRO: float = 0.05                         ## altura a la que termina el chorro
const T_LLENADO: float = 1.6                             ## s que tarda en llenarse antes de inclinarse
## Inclinación (encargo de Pablo): de 90° a 135°, es decir 45° MÁS sobre la pose de reposo. INCLINA_DESDE/HASTA solo importan por su
## diferencia; INCLINA_SENTIDO la multiplica (0,5 = la mitad). HACIA QUÉ LADO se inclina lo decide INCLINA_HACIA (abajo).
const INCLINA_DESDE: float = 90.0
const INCLINA_HASTA: float = 135.0
const INCLINA_SENTIDO: float = 0.5
## Hacia dónde se inclina y vierte, en el espacio LOCAL de la tinaja (la pieza mira a +Z con giro 0; su izquierda es +X):
## (1, 0, 0) = su izquierda (el valor de Pablo) · (0, 0, 1) = hacia delante (como antes) · (-1, 0, 0) = su derecha · (0, 0, -1) = atrás.
## Va con el giro de la pieza (`; giro x y grados` en el mapa): con giro 180 la izquierda de la tinaja es el OESTE del mapa.
## El chorro, las gotas, el arroyo y la casilla donde empieza el canal (`_montar_canal`) siguen esta dirección.
const INCLINA_HACIA: Vector3 = Vector3(1.0, 0.0, 0.0)
const T_INCLINA: float = 1.2                             ## s que dura la inclinación
const PIVOTE_TINAJA: Vector3 = Vector3(0.0, 0.55, 0.0)   ## centro de la panza: la tinaja gira alrededor de este punto
const T_CAUDAL: float = 2.2                              ## s que tarda el arroyo en llegar a su tamaño
const ARROYO_HASTA: float = S * 0.5                      ## el arroyo llega hasta el borde de la casilla de delante (donde empieza el canal)
const ARROYO_ANCHO: float = 0.42
## Velocidad del arroyo (u/s). Tarda lo que mide el trecho entre donde cae el chorro y el borde del canal (máximo T_CAUDAL, mínimo 0,15 s);
## si el chorro ya cae DENTRO de la casilla del canal (tinaja movida hacia ella) no hay arroyo y el canal empieza a llenarse al instante.
const VEL_ARROYO: float = 0.6
const COLOR_AGUA: Color = Color(0.35, 0.66, 0.95, 0.85)
## Brillo de la tinaja al recibir agua (feedback): sube a BRILLO_PICO (energía de emisión) en T_BRILLO s al empezar a llenarse, se queda
## suave mientras vierte y se apaga solo. Sutil: con el color del agua y poca energía.
const COLOR_BRILLO: Color = Color(0.5, 0.8, 1.0)
const BRILLO_PICO: float = 0.9
const BRILLO_REPOSO: float = 0.35                        ## fracción del pico que se mantiene mientras se llena
const T_BRILLO: float = 0.35
const T_BRILLO_FIN: float = 1.6                          ## s que tarda en apagarse una vez que vierte

## Agua que fluye (sin cálculo de fluidos: franjas que corren por la superficie). `por_x`: la corriente va por U en vez de V.
## Se comparte con los canales del suelo (la tubería abierta).
const CODIGO_CAUDAL: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 color : source_color = vec4(0.35, 0.66, 0.95, 0.85);
uniform float velocidad = 2.5;
uniform float frecuencia = 6.0;
uniform bool por_x = false;
uniform bool opaco = false;
void fragment() {
	float u = por_x ? UV.x : UV.y;
	float v = por_x ? UV.y : UV.x;
	float franja = sin((u * frecuencia - TIME * velocidad) * 6.2832) * 0.5 + 0.5;
	float onda = sin((v * 5.0 + u * 3.0 - TIME * 0.6) * 6.2832) * 0.5 + 0.5;
	float k = clamp(franja * 0.6 + onda * 0.4, 0.0, 1.0);
	ALBEDO = mix(color.rgb, vec3(0.9, 0.97, 1.0), k * 0.55);
	ALPHA = opaco ? 1.0 : color.a * (0.7 + 0.3 * k);
}
"""

var _es_tinaja: bool = false
var _llenando: bool = false
var _pivote: Node3D = null               ## tinaja: gira la tinaja entera (modelo, agua de la boca) al inclinarse
var _gotas: GPUParticles3D = null        ## tinaja: gotas finas que salen hacia abajo (casi solo Y, muy poco X y Z)
var _chorro: Array = []                  ## tramos del chorro (MeshInstance3D), se enseñan de arriba abajo
var _punto_caida: Vector3 = Vector3.ZERO     ## local: donde cae el chorro
var _arroyo: Node3D = null               ## pivote en el punto de caída; su escala Z es lo que avanza el arroyo
var _tira: PlaneMesh = null              ## la tira del arroyo (su largo se ajusta con ajustar_arroyo)
var _tira_mi: MeshInstance3D = null
var _dist_arroyo: float = 1.0           ## trecho real (u) del chorro al borde del canal; ≤ 0,15 = el chorro cae ya dentro del canal
var _t_salp: Timer = null
static var _sombreado_caudal: Shader = null


static func material_caudal(por_x: bool = false, velocidad: float = 2.5, frecuencia: float = 6.0, opaco: bool = false) -> ShaderMaterial:
	if _sombreado_caudal == null:
		_sombreado_caudal = Shader.new()
		_sombreado_caudal.code = CODIGO_CAUDAL
	var m := ShaderMaterial.new()
	m.shader = _sombreado_caudal
	m.set_shader_parameter("color", COLOR_AGUA)
	m.set_shader_parameter("por_x", por_x)
	m.set_shader_parameter("opaco", opaco)
	m.set_shader_parameter("velocidad", velocidad)
	m.set_shader_parameter("frecuencia", frecuencia)
	return m


## Punto del chorro `t` segundos después de salir por el pico (tiro parabólico).
static func punto_chorro(t: float) -> Vector3:
	return pico_inclinado() + dir_vertido() * (VUELO_Z * t) + Vector3(0.0, -0.5 * GRAVEDAD_CHORRO * t * t, 0.0)


## Dirección horizontal (local, unitaria) hacia la que se inclina y vierte.
static func dir_vertido() -> Vector3:
	var d := Vector3(INCLINA_HACIA.x, 0.0, INCLINA_HACIA.z)
	return d.normalized() if d.length() > 0.001 else Vector3(0.0, 0.0, 1.0)


## Eje de giro que baja el borde del lado `dir_vertido()` (Y × dirección: para +Z da +X, como antes).
static func eje_inclina() -> Vector3:
	return Vector3.UP.cross(dir_vertido()).normalized()


## Por dónde sale el agua con la tinaja SIN inclinar: la muesca del pico si vierte hacia delante; si no, el punto del borde de la
## boca que mira hacia donde se inclina (sobre el plano del anillo).
static func boca_vertido() -> Vector3:
	if dir_vertido().is_equal_approx(Vector3(0.0, 0.0, 1.0)):
		return BOCA_PICO
	var p: Vector3 = BOCA_CENTRO + dir_vertido() * BOCA_RADIO
	p.y = 1.396 - 0.288 * p.x - 0.095 * p.z
	return p


## Dónde queda el punto de vertido cuando la tinaja ya está inclinada (giro alrededor del pivote).
static func pico_inclinado() -> Vector3:
	var giro := Basis(eje_inclina(), deg_to_rad((INCLINA_HASTA - INCLINA_DESDE) * INCLINA_SENTIDO))
	return PIVOTE_TINAJA + giro * (boca_vertido() - PIVOTE_TINAJA)


func _montar_tinaja() -> void:
	_es_tinaja = true
	# El modelo cuelga de un pivote en la panza para poder inclinarlo sin mover la base de piedra del suelo.
	_pivote = Node3D.new()
	_pivote.position = PIVOTE_TINAJA
	add_child(_pivote)
	if visual != null and visual.get_parent() == self:
		remove_child(visual)
		_pivote.add_child(visual)
		visual.position -= PIVOTE_TINAJA
	# El agua dentro de la boca: un disco inclinado como la boca, invisible hasta que empieza a llenarse.
	# 10/10 (Pablo): el agua de dentro NO se ve fuera de la boca. Es un disco OPACO y más estrecho que el hueco, metido por el cuello
	# por debajo del borde: lo tapan las paredes y solo se ve a través de la abertura. Se queda nivelado al inclinar (_brotar_tinaja).
	var disco := CylinderMesh.new()
	disco.top_radius = AGUA_RADIO
	disco.bottom_radius = AGUA_RADIO
	disco.height = 0.01
	disco.material = material_caudal(false, 1.0, 3.0, true)
	_agua_pila = MeshInstance3D.new()
	_agua_pila.mesh = disco
	_agua_pila.position = BOCA_CENTRO - BOCA_NORMAL.normalized() * AGUA_PROFUNDIDAD - PIVOTE_TINAJA
	_agua_pila.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_agua_pila.visible = false
	_pivote.add_child(_agua_pila)
	# Chorro: ocho cilindros finos siguiendo la parábola.
	var t_fin: float = sqrt(2.0 * (pico_inclinado().y - SUELO_CHORRO) / GRAVEDAD_CHORRO)
	for i in range(8):
		var a: Vector3 = punto_chorro(t_fin * float(i) / 8.0)
		var b: Vector3 = punto_chorro(t_fin * float(i + 1) / 8.0)
		var cil := CylinderMesh.new()
		cil.top_radius = 0.06
		cil.bottom_radius = 0.05
		cil.height = a.distance_to(b)
		cil.radial_segments = 8
		cil.rings = 1
		cil.material = material_caudal(false, 3.5, 3.0)
		var mi := MeshInstance3D.new()
		mi.mesh = cil
		mi.position = (a + b) * 0.5
		mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_chorro.append(mi)
	var caida: Vector3 = punto_chorro(t_fin)
	caida.y = 0.0
	_punto_caida = caida + Vector3(0.0, 0.045, 0.0)      # donde toca el suelo el chorro (salpicadura); ya no hay charco dibujado
	_arroyo = Node3D.new()
	_arroyo.position = caida + Vector3(0.0, 0.05, 0.0)
	_arroyo.rotation.y = atan2(dir_vertido().x, dir_vertido().z)      # su +Z mira hacia donde vierte
	_arroyo.visible = false
	add_child(_arroyo)
	var tira := PlaneMesh.new()
	_dist_arroyo = ARROYO_HASTA - caida.dot(dir_vertido())
	var largo: float = maxf(_dist_arroyo, 0.1)    # distancia hasta el borde de la casilla, en la dirección del vertido
	tira.size = Vector2(ARROYO_ANCHO, largo)
	tira.material = material_caudal(false, 2.5, 3.0)
	var tira_mi := MeshInstance3D.new()
	tira_mi.mesh = tira
	tira_mi.position = Vector3(0.0, 0.0, largo * 0.5)     # el pivote queda en el extremo de arriba de la tira
	tira_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arroyo.add_child(tira_mi)
	_tira = tira
	_tira_mi = tira_mi
	# Gotas: un «hechizo» de agua con la velocidad casi toda en Y (hacia abajo) y muy poca en X y Z.
	_gotas = GPUParticles3D.new()
	_gotas.amount = 28
	_gotas.lifetime = 0.5
	_gotas.emitting = false
	_gotas.local_coords = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(dir_vertido().x * 0.25, -1.0, dir_vertido().z * 0.25)
	pm.spread = 6.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0.0, -GRAVEDAD_CHORRO, 0.0)
	_gotas.process_material = pm
	var gota := SphereMesh.new()
	gota.radius = 0.025
	gota.height = 0.05
	gota.radial_segments = 6
	gota.rings = 3
	var mg := StandardMaterial3D.new()
	mg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mg.albedo_color = Color(0.7, 0.88, 1.0, 0.9)
	mg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gota.material = mg
	_gotas.draw_pass_1 = gota
	_gotas.position = punto_chorro(0.0)
	add_child(_gotas)
	_t_salp = Timer.new()
	_t_salp.wait_time = 0.7
	_t_salp.timeout.connect(_salpicar_caida)
	add_child(_t_salp)


## El arroyo debe llegar hasta `hasta` (distancia desde el origen de la tinaja, en la dirección del vertido): el borde de la casilla
## donde empieza el canal. Lo llama la maqueta al montar el canal; la tinaja puede no estar centrada en su casilla (marcador movido).
func ajustar_arroyo(hasta: float) -> void:
	if _tira == null:
		return
	var t_fin: float = sqrt(2.0 * (pico_inclinado().y - SUELO_CHORRO) / GRAVEDAD_CHORRO)
	_dist_arroyo = hasta - punto_chorro(t_fin).dot(dir_vertido())
	var largo: float = maxf(_dist_arroyo, 0.1)
	_tira.size = Vector2(ARROYO_ANCHO, largo)
	_tira_mi.position = Vector3(0.0, 0.0, largo * 0.5)


## 13/10: dónde toca el suelo el chorro, en coordenadas del mundo. El canal empieza su agua justo aquí (PruebaTest2._montar_canal).
func punto_caida_global() -> Vector3:
	return global_transform * _punto_caida


## 13/10: el canal empieza donde cae el chorro, así que no hay arroyo que recorrer: el agua llega al canal en cuanto cae.
func sin_arroyo() -> void:
	_dist_arroyo = 0.0


func _salpicar_caida() -> void:
	if fx != null and is_inside_tree():
		fx.salpicadura(to_global(_punto_caida), 0.35)


## Vacía → llenándose → inclinándose → vertiendo. Una sola vez; después se queda vertiendo. `instantaneo`: sin esperas ni
## animación (al cargar una partida): la tinaja aparece ya inclinada y vertiendo.
func _brotar_tinaja(instantaneo: bool) -> void:
	if _llenando or usado:
		return
	_llenando = true
	_agua_pila.visible = true
	var angulo: float = deg_to_rad((INCLINA_HASTA - INCLINA_DESDE) * INCLINA_SENTIDO)
	var eje: Vector3 = eje_inclina()
	if instantaneo:
		_agua_pila.scale = Vector3.ONE
		_pivote.basis = Basis(eje, angulo)
		_agua_pila.quaternion = Quaternion(eje, -angulo)       # el agua se queda nivelada
		_empezar_a_verter(true)
		return
	_agua_pila.scale = Vector3(0.15, 1.0, 0.15)
	_brillar()
	var tw: Tween = create_tween()
	tw.tween_property(_agua_pila, "scale", Vector3.ONE, T_LLENADO).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_inclinar.bind(eje, angulo), 0.0, 1.0, T_INCLINA).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_empezar_a_verter.bind(false))


## Un paso (k de 0 a 1) de la inclinación: gira la tinaja entera y contragira el agua para que se quede nivelada.
func _inclinar(k: float, eje: Vector3, angulo: float) -> void:
	_pivote.basis = Basis(eje, angulo * k)
	_agua_pila.quaternion = Quaternion(eje, -angulo * k)


## Brillo sutil de la tinaja al recibir el agua (feedback visual): sube rápido, se queda suave mientras se llena y se apaga al verter.
func _brillar() -> void:
	var tb: Tween = create_tween()
	tb.tween_method(_poner_brillo, 0.0, 1.0, T_BRILLO).set_trans(Tween.TRANS_SINE)
	tb.tween_method(_poner_brillo, 1.0, BRILLO_REPOSO, T_LLENADO).set_trans(Tween.TRANS_SINE)


func _poner_brillo(k: float) -> void:
	_pintar_emision(COLOR_BRILLO, BRILLO_PICO * k)


func _empezar_a_verter(instantaneo: bool) -> void:
	usado = true
	if instantaneo:
		for mi in _chorro:
			(mi as MeshInstance3D).visible = true
		_arroyo.visible = true
		_arroyo.scale = Vector3.ONE
		agua_llega.emit()
	else:
		var tw: Tween = create_tween()
		for i in range(_chorro.size()):         # el chorro baja de tramo en tramo (0,05 s cada uno)
			tw.tween_callback((_chorro[i] as MeshInstance3D).set_visible.bind(true))
			tw.tween_interval(0.05)
		tw.tween_callback(_abrir_caudal)
		create_tween().tween_method(_poner_brillo, BRILLO_REPOSO, 0.0, T_BRILLO_FIN).set_trans(Tween.TRANS_SINE)     # el brillo se apaga
	# 13/10 (Pablo): sin salpicadura donde cae el chorro: ahí empieza el río (el agua del canal), ver punto_caida_global.
	_gotas.emitting = true
	activado.emit("surtidor", "agua")


## El agua llega al suelo y el arroyo avanza hacia el canal (sin charco: el canal ya es el agua que se ve). Sin simulación: solo el
## tiempo y la escala. Al terminar el arroyo emite `agua_llega`: ahí empieza a llenarse el canal.
func _abrir_caudal() -> void:
	if _dist_arroyo <= 0.15:         # el chorro cae ya en el canal: nada que recorrer, el canal empieza ahora
		agua_llega.emit()
		return
	_arroyo.visible = true
	_arroyo.scale = Vector3(1.0, 1.0, 0.02)
	var tw: Tween = _arroyo.create_tween()
	tw.tween_property(_arroyo, "scale:z", 1.0, clampf(_dist_arroyo / VEL_ARROYO, 0.15, T_CAUDAL)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(agua_llega.emit)


## --- Puente y placa ---

func tender() -> void:
	if tipo != "puente" or usado:
		return
	usado = true
	_plegado = false
	var tw := create_tween()
	tw.tween_property(self, "rotation:z", 0.0, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(fx.chispazo.bind(global_position + Vector3(S * 0.5, 0.3, 0.0), "rayo"))
	activado.emit("puente", "")


func esta_plegado() -> bool:
	return _plegado


## Algo con peso encima: se hunde y se queda (una vez, como en el 2D).
func pesar() -> void:
	if tipo != "placa" or usado:
		return
	usado = true
	var tw := create_tween()
	tw.tween_property(visual, "position:y", -0.06, 0.2)
	_pintar_emision(Color(0.5, 0.9, 0.6), 0.6)
	fx.chispazo(global_position + Vector3(0.0, 0.2, 0.0), "agua")
	activado.emit("placa", "")


func _physics_process(_delta: float) -> void:
	if usado:
		set_physics_process(false)
		return
	for a in get_overlapping_areas():
		if a.is_in_group(GRUPO_PESO):
			pesar()
			return
	for b in get_overlapping_bodies():
		if b.is_in_group(GRUPO_PESO):
			pesar()
			return


## --- Materiales: cada objeto trae sus copias, para tintar uno sin tocar a los demás ---

func _recoger_materiales() -> void:
	if visual == null:
		return
	for n in visual.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var mat: Material = mi.get_active_material(s)
			if mat is StandardMaterial3D:
				var copia: Material = (mat as StandardMaterial3D).duplicate() as Material
				copia = Ocluso3D.convertir(copia)      # con el círculo de transparencia del jugador (si está activo)
				mi.set_surface_override_material(s, copia)
				_mats.append([copia, Ocluso3D.color_de(copia)])
	for n in visual.find_children("*", "SpriteBase3D", true, false):
		_sprites.append([n, (n as SpriteBase3D).modulate])
	if visual is SpriteBase3D:
		_sprites.append([visual, (visual as SpriteBase3D).modulate])


## Tinta todo hacia `hacia` (multiplicando el color original): k = 0 sano … 1 el tinte.
func _pintar_tinte(k: float, hacia: Color = APAGADO) -> void:
	for m in _mats:
		Ocluso3D.poner_color(m[0] as Material, (m[1] as Color).lerp((m[1] as Color) * hacia, k))
	for s in _sprites:
		(s[0] as SpriteBase3D).modulate = (s[1] as Color).lerp((s[1] as Color) * hacia, k)


func _pintar_emision(c: Color, energia: float) -> void:
	for m in _mats:
		Ocluso3D.poner_emision(m[0] as Material, c, energia)


## Lleva el chamuscado (combustibles) o el brillo (tótem) a `destino` en FUNDIDO s.
func _animar_k(destino: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_poner_k, _k, destino, FUNDIDO)


func _poner_k(k: float) -> void:
	_k = k
	if tipo == "totem":
		_pintar_emision(COLOR_ELEMENTO.get(elemento, Color.WHITE), 1.2 * k)
	else:
		_pintar_tinte(k, CHAMUSCADO)


func _crear_luz(c: Color, energia: float, rango: float, p: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energia
	l.omni_range = rango
	l.position = p
	l.shadow_enabled = false
	add_child(l)
	return l
