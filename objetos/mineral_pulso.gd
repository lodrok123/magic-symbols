class_name MineralPulso
extends RefCounted

## LOS MATERIALES QUE SUELTAN LOS REACTIVOS DEL PULSO (24/10, fase 3; docs/MATERIALES_CUEVA.md «Minerales»). Un solo sitio para darlos: la veta picada con tierra (`VetaPulso3D.picar`) y el cristal
## resonante golpeado dos veces (`CristalPulso3D`) llaman a `dar`. El material va DIRECTO a la bolsa (como el colmillo del goblin), con el aviso de su calidad y unas motas del color de la calidad
## donde salió; si la mochila está llena no se da y se avisa.

const SFX_MINERAL: String = "logro_brillo"
const MOTAS_N: int = 12
const MOTAS_ALTO: float = 0.5            ## u sobre el reactivo


## Da `id` (un objeto de `Objetos.DATOS`) a la bolsa y avisa. `donde` = el reactivo (de él salen las motas y el sonido). Devuelve `id`, o "" si no cupo.
static func dar(lanz: Node, id: String, donde: Node3D) -> String:
	if id == "" or not Objetos.existe(id):
		return ""
	if Estado.i().agregar(id, 1) <= 0:
		if lanz != null and lanz.has_method("avisar"):
			lanz.call("avisar", "Mochila llena")
		return ""
	AvisoObjeto.mostrar(lanz, id, 1)
	if donde != null and donde.is_inside_tree():
		Sfx.play(donde, SFX_MINERAL)
		if donde.get_parent() is Node3D:
			VfxCalidad3D.motas(donde.get_parent() as Node3D, donde.global_position + Vector3(0.0, MOTAS_ALTO, 0.0), Objetos.color_calidad(id).lerp(Objetos.color(id), 0.5), MOTAS_N, 0.9, 0.08, 1.3, 0.2)
			_pieza_sube(donde, id)
	return id


## 24/10 (tercera tanda): la esquirla que sale del cristal se VE: su pieza (`esquirla_cristal`) salta del reactivo, sube y se apaga camino de la bolsa. Solo los objetos que tienen pieza propia
## (hoy la esquirla); el resto sigue con las motas.
const PIEZAS_QUE_SUBEN: Array = ["esquirla_cristal"]
const T_SUBE: float = 0.9
const ALTO_SUBE: float = 0.9

static func _pieza_sube(donde: Node3D, id: String) -> void:
	if not PIEZAS_QUE_SUBEN.has(id) or not ResourceLoader.exists("res://arte/piezas/%s.tscn" % id):
		return
	var escena: PackedScene = load("res://arte/piezas/%s.tscn" % id) as PackedScene
	var n: Node3D = escena.instantiate() as Node3D if escena != null else null
	if n == null or not (donde.get_parent() is Node3D):
		return
	n.name = "sube_%s" % id
	(donde.get_parent() as Node3D).add_child(n)
	n.global_position = donde.global_position + Vector3(0.0, MOTAS_ALTO * 0.6, 0.0)
	var y0: float = n.position.y
	var tw: Tween = n.create_tween()
	tw.set_parallel(true)
	tw.tween_property(n, "position:y", y0 + ALTO_SUBE, T_SUBE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "rotation:y", TAU, T_SUBE)
	tw.tween_property(n, "scale", Vector3.ONE * 0.05, T_SUBE * 0.35).set_delay(T_SUBE * 0.65)
	tw.chain().tween_callback(n.queue_free)
