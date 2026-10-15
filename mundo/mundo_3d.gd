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
## Los estados NO son de este nodo: son `Terreno3D.estados` (existen aunque no haya Mundo3D, para las pruebas); aquí solo se escuchan.
## Cómo se usa: se añade al árbol UNA vez (la maqueta, que es del Pipeline, lo crea en su `_ready`). Mientras esté en el árbol
## es `Mundo3D.actual` y Terreno3D le avisa de los cambios. Si no hay ninguno, todo funciona como antes.
class_name Mundo3D
extends Node3D

signal casilla_cambio(c: Vector2i, que: String)
signal impacto(punto: Vector3, elemento: String, radio: float)

## El mundo vivo (null si no hay). Estático para que los módulos sin nodo (Terreno3D) puedan avisarle.
static var actual: Mundo3D = null

var terreno: Terreno3D = Terreno3D.new()
var estados: EstadosSuelo3D:
	get:
		return Terreno3D.estados
var agua: AguaSim3D:
	get:
		return Terreno3D.agua_sim


func _enter_tree() -> void:
	actual = self
	if not estados.cambio.is_connected(_estado_cambio):
		estados.cambio.connect(_estado_cambio)


func _exit_tree() -> void:
	if estados.cambio.is_connected(_estado_cambio):
		estados.cambio.disconnect(_estado_cambio)
	if actual == self:
		actual = null


func _estado_cambio(c: Vector2i, estado: String, _si: bool) -> void:
	casilla_cambio.emit(c, String(EstadosSuelo3D.QUE.get(estado, estado)))


## M3: el mundo recibe ACCIONES, no hechizos. Hoy reparte al agua (agua, fuego, hielo; ver ReaccionesAgua3D). Lo que hace el suelo
## (quemado, mojado, hielo de la casilla) lo sigue haciendo la maqueta al impactar el VFX, hasta que pase a `estados`; los
## `Reactivo3D` siguen recibiendo `on_spell_hit`. Estática para poder usarla sin un Mundo3D en el árbol (pruebas).
static func aplicar_accion(a: AccionElemental) -> void:
	ReaccionesAgua3D.aplicar(a)


func aplicar(a: AccionElemental) -> void:
	aplicar_accion(a)


## Abre un cauce (canal de la tinaja) a la simulación con un manantial permanente: ver ReaccionesAgua3D.abrir_cauce.
static func abrir_cauce(celdas: Array, caudal: float) -> bool:
	return ReaccionesAgua3D.abrir_cauce(celdas, caudal)


## --- Fachada para la presentación (M5): lo que la maqueta pedía por campos privados o por Lanzador3D.<static> ---
## «Bloquear casilla»: marca o libera una casilla como sólida para quien camina y para los hechizos.
func bloquear_casilla(c: Vector2i, si: bool) -> void:
	if si:
		Terreno3D.bloquear_celda(c)
	else:
		Terreno3D.liberar_celda(c)


## «Punto de activación» de un objeto reactivo: dónde hay que golpearlo para activarlo (Vector3.INF si no es activable).
static func punto_activacion(obj: Object) -> Vector3:
	if obj != null and obj.has_method("punto_activacion"):
		return obj.call("punto_activacion")
	return Vector3.INF


## El cargador entrega el nivel (letras, bloqueos, canales, giros); ver Terreno3D.cargar_datos.
func cargar_datos(p_mapa: PackedStringArray, p_bloqueadas: Dictionary, p_celdas_canal: Dictionary = {}, p_giros: Dictionary = {}) -> void:
	Terreno3D.cargar_datos(p_mapa, p_bloqueadas, p_celdas_canal, p_giros)


func letra(c: Vector2i) -> String:
	return Terreno3D.letra_de(c)


## La magia o un objeto avisa de un impacto para que la presentación pinte y suene. No decide qué se pinta.
func avisar_impacto(punto: Vector3, elemento: String, radio: float = 0.0) -> void:
	impacto.emit(punto, elemento, radio)
