extends "res://goblin_arquero.gd"

## DUMMY DE PRUEBAS: un goblin arquero azul con nombre. No se mueve, dispara más seguido
## y aguanta mucho, así que obliga a DEFENDERSE (barrera) y a atacar con el elemento
## correcto: es DÉBIL AL FUEGO y RESISTE AGUA Y HIELO. No suelta oro y reaparece solo.

const REAPARICION: float = 6.0

var _muerto_dummy: bool = false


func _ready() -> void:
	max_health = 150.0
	movil = false
	aim_time = 0.6
	cooldown = 1.6
	arrow_damage = 10.0
	super._ready()


func _configurar() -> void:
	combate = CombateComun.equipar(self, max_health, "fuego", "agua", "Goblin helado (dummy)",
		Color(0.55, 0.8, 1.35))
	combate.nombre_fijo = true
	combate.oro = 0
	# Resiste también el hielo: la comprobación del hielo va aparte (ver multiplicador).


func _die() -> void:
	combate.morir(false)
	_muerto_dummy = true
	set_physics_process(false)
	visible = false
	monitoring = false
	await get_tree().create_timer(REAPARICION).timeout
	if not is_inside_tree():
		return
	health = max_health
	combate.revivir()
	_muerto_dummy = false
	visible = true
	monitoring = true
	detectado = false
	target = null
	set_physics_process(true)
