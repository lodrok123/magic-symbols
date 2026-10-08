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
##
## Quien lo coloca (PruebaTest2._reactivo) pone antes `fx`, `celda` y `visual`, y conecta `consumido` para liberar la casilla.

signal consumido(celda: Vector2i)
## tipo, elemento ("" si no aplica): tótem activado, fuente encendida/apagada, puente tendido, placa pisada.
signal activado(tipo: String, elemento: String)

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
}
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
	caja.size = Vector3(S * (0.7 if tipo == "placa" else 0.9), alto, S * (0.7 if tipo == "placa" else 0.9))
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
