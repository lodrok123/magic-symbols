class_name EfectoVfx3D
extends Node3D

## EFECTO COMO ASSET (1/11, Dirección, comparativa de VFX §1.3). Script común de las escenas de `presentacion/vfx/efectos/` (BolaFuego, MuroFuego,
## ColumnaFuego, ImpactoFuego). La escena lleva el dibujo (partículas, mallas, luces, calor) y un AnimationPlayer con «nacer», «vivir» (en bucle,
## opcional) y «morir»; este script solo pone en marcha esas animaciones y escala el conjunto al hechizo. Lo que cambia el aspecto se toca en el
## editor, no aquí.
## Uso suelto (lab):          var e := ESCENA.instantiate(); padre.add_child(e); e.global_position = p; e.lanzar(4.0)
## Uso con un hechizo:        e.preparar(volumen, dir, elemento); e.lanzar(volumen["vida_total"])   (ver COMPARATIVA §1.5, VfxBiblioteca3D)
## Un proyectil (BolaFuego) no se lanza: cuelga de su HechizoVivo con `seguir()` y al llegar se llama `impactar()`.

## Tamaño de referencia de la escena en metros (x, y, z): con este tamaño está diseñada; `preparar` escala el raíz al volumen del hechizo.
@export var tam_referencia: Vector3 = Vector3(1.0, 1.0, 1.0)
## Tamaño de la casilla del juego (Terreno3D.casilla); se multiplica por los semiejes del volumen.
@export var casilla: float = 2.3
## Nodos que giran sobre su eje Y local y su velocidad (rad/s); negativo = al revés. Para las capas de la columna y los aros.
@export var giros: Dictionary = {}
## Escena que se instancia al impactar (solo proyectiles).
@export var escena_impacto: PackedScene = null
## Duración de «morir» (la de la animación; se lee de ella si existe).
@export var dura_morir: float = 0.5

var _ap: AnimationPlayer = null
var _vida_restante: float = -1.0
var _muriendo: bool = false
var _proporcion_particulas: float = 1.0


func _ready() -> void:
	_ap = get_node_or_null("Anim") as AnimationPlayer
	if _ap != null and _ap.has_animation("morir"):
		dura_morir = _ap.get_animation("morir").length


func _process(delta: float) -> void:
	for ruta in giros:
		var n: Node3D = get_node_or_null(ruta) as Node3D
		if n != null:
			n.rotate_y(float(giros[ruta]) * delta)
	if _vida_restante >= 0.0 and not _muriendo:
		_vida_restante -= delta
		if _vida_restante <= dura_morir:
			morir()


## Escala el raíz al volumen del hechizo (semiejes x, y, z en casillas) y orienta el efecto según `dir` (el muro se pone de lado al tiro).
## Las partículas se reparten en proporción al ÁREA en planta (un muro el doble de largo emite el doble, no lo mismo estirado).
func preparar(volumen: Dictionary, dir: Vector3, _elemento: String = "fuego") -> void:
	var tam: Vector3 = Vector3(float(volumen.get("x", 0.5)) * 2.0 * casilla, float(volumen.get("y", 0.5)) * 2.0 * casilla,
		float(volumen.get("z", 0.5)) * 2.0 * casilla)
	var esc: Vector3 = Vector3(tam.x / maxf(tam_referencia.x, 0.01), tam.y / maxf(tam_referencia.y, 0.01), tam.z / maxf(tam_referencia.z, 0.01))
	scale = esc
	var plano: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if plano.length() > 0.01:
		look_at(global_position + plano, Vector3.UP)
	_proporcion_particulas = clampf(esc.x * esc.z, 0.25, 8.0)
	for gp in find_children("*", "GPUParticles3D", true, false):
		var p: GPUParticles3D = gp
		p.amount = maxi(1, int(round(float(p.amount) * _proporcion_particulas)))


## Empieza: «nacer» y, si hay «vivir», en bucle después. Con `vida` > 0 se muere solo cuando queda `dura_morir`; con `vida` ≤ 0 vive hasta que alguien llame a `morir()`.
func lanzar(vida: float = -1.0) -> void:
	_vida_restante = vida
	_muriendo = false
	if _ap == null:
		return
	if _ap.has_animation("nacer"):
		_ap.play("nacer")
		if _ap.has_animation("vivir"):
			_ap.queue("vivir")
	elif _ap.has_animation("vivir"):
		_ap.play("vivir")


## Se apaga (animación «morir») y se libera al acabar.
func morir() -> void:
	if _muriendo:
		return
	_muriendo = true
	if _ap != null and _ap.has_animation("morir"):
		_ap.play("morir")
		await _ap.animation_finished
	queue_free()


## Proyectil: deja de emitir lo que es «línea de movimiento» (estela, chispas) y se queda el cuerpo. Lo llama quien lo mueve cuando se para.
func pararse() -> void:
	for gp in find_children("*", "GPUParticles3D", true, false):
		if (gp as Node).is_in_group("estela"):
			(gp as GPUParticles3D).emitting = false


## Proyectil: instancia la escena de impacto donde está, suelta las partículas que queden y se libera.
func impactar() -> void:
	if escena_impacto != null and is_inside_tree():
		var imp: Node3D = escena_impacto.instantiate() as Node3D
		get_parent().add_child(imp)
		imp.global_position = global_position
		if imp.has_method("lanzar"):
			imp.call("lanzar", -1.0)
	morir()
