extends Area2D

## OBJETO QUE ARDE: seto, tronco, setas, telaraña.
##
## Dos dibujos por objeto: el SANO y el CHAMUSCADO. Mientras arde se ve el chamuscado
## (el dibujo "se degrada" por el fuego) y, cuando el fuego termina, el objeto DESAPARECE
## del mapa, con su cuerpo sólido incluido. Así un seto o una telaraña es un muro hasta
## que se quema, y el dibujo siempre dice la verdad sobre si se puede pasar.
##
## Es del grupo "flammable" y cumple el mismo contrato que la hierba (can_burn / ignite /
## on_spell_hit / carried_element), así que el fuego salta entre hierba y objetos, y el
## viento puede llevarse la llama de uno a otro sin una línea más.
##
##   calor, rayo   prenden
##   agua, frio    lo apagan si arde: vuelve a estar sano (se puede volver a intentar)
##   viento        aviva: contagia más lejos y hacia donde sopla

signal ardiendo
signal quemado

const FIRE_RUNE: RuneData = preload("res://fire_rune.tres")
const GRUPO: String = "flammable"
const RADIO_CONTAGIO: float = 110.0
const RADIO_VIENTO: float = 230.0
const PUNTO_VIENTO: float = 0.3
const INTERVALO_CONTAGIO: float = 0.8
const FUNDIDO: float = 0.6

## Los pone quien lo crea (el nivel): texturas, anclaje y comportamiento.
var tex_sano: Texture2D = null
var tex_chamuscado: Texture2D = null
var ancla: Vector2 = Vector2.ZERO       ## punto del dibujo que cae en el centro de la casilla
var escala: float = 0.5                 ## los dibujos estan a 2x
var cuerpo_tam: float = 0.95            ## 0 = no estorba; si no, tamaño del hueco sólido (en casillas)
var tiempo_arder: float = 3.0

var arde: bool = false
var is_lit: bool = false                ## igual que la pira y la fogata: el viento lo mira

var sano: Sprite2D
var chamuscado: Sprite2D
var cuerpo: StaticBody2D = null
var fx_llama: GPUParticles2D = null
var fx_luz: PointLight2D = null
var _reloj_fin: Timer
var _reloj_contagio: Timer
var _t_fundido: float = 0.0


func _ready() -> void:
	add_to_group(GRUPO)

	sano = _sprite(tex_sano)
	add_child(sano)
	chamuscado = _sprite(tex_chamuscado)
	chamuscado.modulate.a = 0.0
	add_child(chamuscado)

	var deteccion := CollisionShape2D.new()
	deteccion.shape = IsoGrid.diamond()
	add_child(deteccion)

	if cuerpo_tam > 0.0:
		cuerpo = StaticBody2D.new()
		var forma := CollisionShape2D.new()
		forma.shape = IsoGrid.footprint(cuerpo_tam)
		cuerpo.add_child(forma)
		add_child(cuerpo)

	_reloj_fin = Timer.new()
	_reloj_fin.one_shot = true
	_reloj_fin.timeout.connect(_consumido)
	add_child(_reloj_fin)

	_reloj_contagio = Timer.new()
	_reloj_contagio.wait_time = INTERVALO_CONTAGIO
	_reloj_contagio.timeout.connect(_contagiar.bind(RADIO_CONTAGIO, Vector2.ZERO))
	add_child(_reloj_contagio)


func _sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = -ancla
	s.scale = Vector2(escala, escala)
	return s


func _process(delta: float) -> void:
	if not arde or _t_fundido >= FUNDIDO:
		return
	_t_fundido = minf(_t_fundido + delta, FUNDIDO)
	chamuscado.modulate.a = _t_fundido / FUNDIDO


## --- Contrato con los hechizos y con la hierba ---

func can_burn() -> bool:
	return not arde


func on_spell_hit(rune_data: RuneData, direction: Vector2 = Vector2.ZERO) -> void:
	if rune_data == null:
		return
	if rune_data.tags.has("calor") or rune_data.tags.has("rayo"):
		ignite(SpellFactory.ultimo_impacto)
	elif (rune_data.tags.has("agua") or rune_data.tags.has("frio")) and arde:
		_apagar()
	elif rune_data.tags.has("viento") and arde:
		_contagiar(RADIO_VIENTO, direction)


## ¿Cambiaría algo este hechizo aquí? Si no, lo atraviesa.
func spell_reacts(rune_data: RuneData, _direction: Vector2 = Vector2.ZERO) -> bool:
	if rune_data == null:
		return false
	if rune_data.tags.has("calor") or rune_data.tags.has("rayo"):
		return not arde
	if rune_data.tags.has("agua") or rune_data.tags.has("frio") or rune_data.tags.has("viento"):
		return arde
	return false


func carried_element() -> RuneData:
	return FIRE_RUNE if arde else null


func ignite(_desde: Vector2 = Vector2.INF) -> void:
	if arde:
		return
	arde = true
	is_lit = true
	_t_fundido = 0.0
	fx_luz = Glow.attach(self, Glow.LUZ_FUEGO, 150.0, 1.1, true)
	fx_llama = BlockFx.flames(self)
	BlockFx.burst(self, "chispas")
	Sfx.play(self, "pira")
	_reloj_fin.start(tiempo_arder)
	_reloj_contagio.start()
	ardiendo.emit()


## --- Fin del fuego ---

func _apagar() -> void:
	arde = false
	is_lit = false
	_reloj_fin.stop()
	_reloj_contagio.stop()
	_quitar_fx()
	BlockFx.burst(self, "ceniza")
	var t: Tween = create_tween()
	t.tween_property(chamuscado, "modulate:a", 0.0, FUNDIDO)


func _consumido() -> void:
	_quitar_fx()
	BlockFx.burst(self, "ceniza")
	quemado.emit()
	# Se va el dibujo y se va el cuerpo: lo que bloqueaba el paso ya no está.
	queue_free()


func _quitar_fx() -> void:
	if is_instance_valid(fx_llama):
		fx_llama.queue_free()
	fx_llama = null
	if is_instance_valid(fx_luz):
		fx_luz.queue_free()
	fx_luz = null


func _contagiar(radio: float, viento: Vector2) -> void:
	for otro in get_tree().get_nodes_in_group(GRUPO):
		if otro == self or not is_instance_valid(otro) or not otro.has_method("can_burn"):
			continue
		if not otro.can_burn():
			continue
		var hacia: Vector2 = (otro as Node2D).global_position - global_position
		if hacia.length() > radio:
			continue
		if viento != Vector2.ZERO and hacia.normalized().dot(viento.normalized()) < PUNTO_VIENTO:
			continue
		otro.ignite(global_position)
