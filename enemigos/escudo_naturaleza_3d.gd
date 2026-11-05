class_name EscudoNaturaleza3D
extends Node3D

## ESCUDO DE NATURALEZA (28/10; Pablo: la onda verde del chamán lo pone a los aliados que alcanza): una burbuja verde de hojas sobre un `Combate3D` que absorbe VIDA daño y se acaba.
## Distinto del `Escudo3D` del goblin guerrero (el disco de madera del brazo, solo de frente): este cubre por todos lados. El FUEGO lo quema de un golpe (se consume entero, también el
## daño de ese golpe) y el agua no le hace nada. Lo consulta `Combate3D.receive_damage` (`escudo_natural`): `absorber(cantidad, elemento)` devuelve el daño que sí pasa.
## Se pone con `EscudoNaturaleza3D.poner(combate)`: si ya llevaba uno lo rellena. Señal `roto(causa)` («golpes» | «fuego») al acabarse.

signal roto(causa: String)

const VIDA: float = 25.0                        ## daño que absorbe
const COLOR: Color = Color(0.35, 1.0, 0.45)
const COLOR_ROTO: Color = Color(0.9, 0.5, 0.2)
const T_ROTURA: float = 0.45                    ## s mínimos que dura el escudo roto en pantalla (5/11: ahora espera a que su vfx acabe de deshojarse, con tope T_ROTURA_MAX)
const T_ROTURA_MAX: float = 2.6

var combate: Combate3D = null
var vida: float = VIDA
var vida_max: float = VIDA
var estado: String = "activo"                   ## activo · roto · quemado
var absorbidos: float = 0.0                     ## daño total absorbido (pruebas)
var barrera: NaturalezaBarreraToy = null        ## el aspecto (hierba, hojas, cúpula): ver NaturalezaBarreraToy
var _t: float = 0.0
var _t_rotura: float = 0.0


## Pone (o rellena) el escudo de `c`. Devuelve el escudo.
static func poner(c: Combate3D) -> EscudoNaturaleza3D:
	if c == null or c.muerto:
		return null
	if c.escudo_natural != null and is_instance_valid(c.escudo_natural) and c.escudo_natural.estado == "activo":
		c.escudo_natural.vida = c.escudo_natural.vida_max
		return c.escudo_natural
	var e := EscudoNaturaleza3D.new()
	e.name = "EscudoNaturaleza"
	e.combate = c
	c.add_child(e)
	c.escudo_natural = e
	e._construir()
	return e


func activo() -> bool:
	return estado == "activo" and vida > 0.0


func _construir() -> void:
	# 5/11: ya no es una burbuja lisa: anillo de hierba a los pies, hojas que giran y una cúpula tenue (NaturalezaBarreraToy). La lógica (absorber, vida, roto) es la de siempre.
	barrera = NaturalezaBarreraToy.new()
	barrera.name = "Barrera"
	add_child(barrera)
	barrera.montar(combate.altura)


## Recibe `cantidad` de daño de `elemento`; devuelve el que NO absorbe (0 si se lo comió todo). El fuego lo quema entero.
func absorber(cantidad: float, elemento: String = "") -> float:
	if not activo():
		return cantidad
	if elemento == "fuego":
		_romper("fuego")
		Combate3D.flotante(combate.mundo, combate.position + Vector3(0, combate.altura + 0.5, 0), "¡Escudo quemado!", Color(1.0, 0.6, 0.25))
		return 0.0
	var parte: float = minf(cantidad, vida)
	vida -= parte
	absorbidos += parte
	Combate3D.flotante(combate.mundo, combate.position + Vector3(0, combate.altura + 0.5, 0), "Escudo", COLOR, 0.8)
	if barrera != null:
		barrera.poner_vida(vida / vida_max)
		barrera.golpe()
	if vida <= 0.0:
		_romper("golpes")
	return cantidad - parte


func _romper(causa: String) -> void:
	vida = 0.0
	estado = "quemado" if causa == "fuego" else "roto"
	_t_rotura = 0.0
	if barrera != null:
		barrera.romper(causa)
	if combate != null and is_instance_valid(combate) and combate.escudo_natural == self:
		combate.escudo_natural = null
	roto.emit(causa)


func _process(delta: float) -> void:
	_t += delta
	if estado == "activo":
		if combate != null and is_instance_valid(combate):
			position = Vector3.ZERO
	else:
		_t_rotura += delta
		if barrera == null or (barrera.terminada() and _t_rotura >= T_ROTURA) or _t_rotura >= T_ROTURA_MAX:
			queue_free()
