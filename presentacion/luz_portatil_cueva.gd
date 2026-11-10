extends OmniLight3D
## Luz portátil de prueba. Los objetos podrán modificar el radio mediante fijar_bono_radio.

enum Vista { ORIGINAL, RADIO_BASE, RADIO_AMPLIADO }

@export_range(0.5, 8.0, 0.1) var radio_base: float = 3.2
@export_range(0.0, 5.0, 0.1) var bono_de_prueba: float = 1.4
@export_range(0.1, 3.0, 0.05) var altura: float = 1.65
@export_range(0.0, 1.0, 0.01) var ambiente_oscuro: float = 0.10
@export_range(0.0, 1.0, 0.01) var sol_oscuro: float = 0.12
@export var vista: Vista = Vista.RADIO_BASE

var radio_efectivo: float = 0.0
var _bono_radio: float = 0.0
var _mundo: Node3D


func _ready() -> void:
	_mundo = get_parent() as Node3D
	visible = false
	_aplicar_vista.call_deferred()


func alternar_vista() -> void:
	vista = ((int(vista) + 1) % Vista.size()) as Vista
	_aplicar_vista()
	print("Cueva: ", ["luz original", "radio base", "radio ampliado"][vista])


func fijar_bono_radio(unidades: float) -> void:
	_bono_radio = maxf(0.0, unidades)


func _aplicar_vista() -> void:
	var env: Environment = _mundo.get("_env")
	var sol: DirectionalLight3D = _mundo.get("_sol")
	visible = vista != Vista.ORIGINAL
	env.set_meta(LuzZona3D.META_FACTORES_LOCALES, Vector2(ambiente_oscuro, sol_oscuro) if visible else Vector2.ONE)
	var zonas: Zonas3D = _mundo.get_node_or_null("Zonas3D") as Zonas3D
	var valores: Dictionary = zonas.valores_actuales() if zonas != null else LuzZona3D.valores(String(_mundo.get("zona_luz")))
	LuzZona3D.aplicar_valores(env, sol, valores)


func _process(delta: float) -> void:
	if not visible:
		return
	var pj: Node3D = _mundo.get("_jugador")
	if pj == null:
		return
	global_position = pj.global_position + Vector3.UP * altura
	var ampliado: float = bono_de_prueba if vista == Vista.RADIO_AMPLIADO else 0.0
	var objetivo: float = clampf(radio_base + _bono_radio + ampliado, 0.5, 10.0)
	radio_efectivo = move_toward(radio_efectivo, objetivo, delta * 7.0) if radio_efectivo > 0.0 else objetivo
	# Compensa la altura de la fuente para que el ajuste mida el radio en el suelo.
	omni_range = Vector2(radio_efectivo, altura).length()