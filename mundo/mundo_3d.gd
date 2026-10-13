## Mundo3D · la fachada del mundo (M2 de ARQUITECTURA_MODULAR.md, 13/10): terreno, agua y estados del suelo en un solo sitio,
## y las señales con las que la presentación se entera de lo que pasa SIN preguntar por campos privados.
##
## Qué promete:
##   · `terreno`  → Terreno3D (casillas, alturas, bloqueos). Es la misma clase de estáticos; la instancia existe para poder
##                  escribir `mundo.terreno.celda_de(p)` como pide el contrato.
##   · `agua`     → la AguaSim3D del nivel (null si no hay). No es una copia: es `Terreno3D.agua_sim`.
##   · `estados`  → EstadosSuelo3D: helada, electrificada, quemada, mojada. Dueño del dato.
##   · `casilla_cambio(c, que)`  que ∈ «agua», «hielo», «rayo», «fuego», «mojado», «bloqueo», «altura».
##   · `impacto(punto, elemento, radio)`  para VFX y sonido: DÓNDE y de QUÉ, nunca quién.
## Qué NO hace: no dibuja nada, no conoce hechizos (M3 le añadirá `aplicar(AccionElemental)`) ni crea la maqueta (M5).
##
## Cómo se usa: se añade al árbol UNA vez (la maqueta, que es del Pipeline, lo crea en su `_ready`). Mientras esté en el árbol
## es `Mundo3D.actual` y Terreno3D le avisa de los cambios. Si no hay ninguno, todo funciona como antes.
class_name Mundo3D
extends Node3D

signal casilla_cambio(c: Vector2i, que: String)
signal impacto(punto: Vector3, elemento: String, radio: float)

## El mundo vivo (null si no hay). Estático para que los módulos sin nodo (Terreno3D) puedan avisarle.
static var actual: Mundo3D = null

var terreno: Terreno3D = Terreno3D.new()
var estados: EstadosSuelo3D = EstadosSuelo3D.new()
var agua: AguaSim3D:
	get:
		return Terreno3D.agua_sim


func _enter_tree() -> void:
	actual = self
	Terreno3D.estados = estados
	if not estados.cambio.is_connected(_estado_cambio):
		estados.cambio.connect(_estado_cambio)


func _exit_tree() -> void:
	if actual == self:
		actual = null
		Terreno3D.estados = null


func _estado_cambio(c: Vector2i, estado: String, _si: bool) -> void:
	casilla_cambio.emit(c, String(EstadosSuelo3D.QUE.get(estado, estado)))


## La magia o un objeto avisa de un impacto para que la presentación pinte y suene. No decide qué se pinta.
func avisar_impacto(punto: Vector3, elemento: String, radio: float = 0.0) -> void:
	impacto.emit(punto, elemento, radio)
