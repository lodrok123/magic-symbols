## Mundo3D · la fachada del mundo (M2 de ARQUITECTURA_MODULAR.md, 13/10): terreno, agua y estados del suelo en un solo sitio,
## y las señales con las que la presentación se entera de lo que pasa SIN preguntar por campos privados.
##
## Qué promete:
##   · `terreno`  → Terreno3D (casillas, alturas, bloqueos). Es la misma clase de estáticos; la instancia existe para poder
##                  escribir `mundo.terreno.celda_de(p)` como pide el contrato.
##   · `agua`     → la AguaSim3D del nivel (null si no hay). No es una copia: es `Terreno3D.agua_sim`.
##   · `estados`  → EstadosSuelo3D: helada, electrificada, quemada, mojada. Dueño del dato. Los impactos de agua, hielo y fuego lo escriben
##                  por `aplicar_accion` (ReaccionesSuelo3D) y la hierba que arde por `ReaccionesSuelo3D.sincronizar_hierba`.
##   · `casilla_cambio(c, que)`  que ∈ «agua», «hielo», «rayo», «fuego», «mojado», «siega», «bloqueo», «altura».
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
## A4: la lógica avisa de QUÉ ha pasado con un nombre del catálogo cerrado `REACCIONES`; qué se ve y qué suena lo decide la tabla del Pipeline
## (`ReaccionesVfx3D`, PL2), no el Juego. `nodo` = quien reacciona (el Pipeline saca de él el tipo: goblin, flecha, seto...). `punto` en coordenadas de mundo.
signal reaccion(nombre: String, punto: Vector3, nodo: Node)
## Respuesta positiva al jugador (PLAN_EOW_VISUAL §4): la lógica avisa de QUÉ ha logrado con un nombre del catálogo cerrado `LOGROS`; sonido,
## destello, texto y hitstop los decide la tabla de la presentación (`Logros3D`). `punto` = dónde ocurre; `nodo` = la pieza que lo emite.
signal logro(nombre: String, punto: Vector3, nodo: Node)

## CATÁLOGO CERRADO de logros (contrato con la presentación: `Logros3D.TABLA` tiene una fila por nombre). Se avisa UNA vez por suceso real,
## nunca al recargar algo ya resuelto.
##   paso_puzle · parte resuelta (contador que sube sin completar: 2 de 3 braseros)   puzle_resuelto · regla o contador que abre algo
##   sala_limpia · el vigía vio caer al último enemigo     cofre_aparece / cofre_abierto · el cofre del puzle
##   puerta_abierta · un cerrojo se abre      nivel_completado · lo emiten las reglas del nivel al cruzar la salida / abrir el cofre final (`avisar_logro`)
const LOGROS: PackedStringArray = ["paso_puzle", "puzle_resuelto", "sala_limpia", "cofre_aparece", "cofre_abierto", "puerta_abierta", "nivel_completado"]

## CATÁLOGO CERRADO de reacciones (contrato con el Pipeline: `ReaccionesVfx3D.CATALOGO` tiene estos mismos nombres, en este orden).
## Se avisa UNA vez por cambio real de estado, nunca por fotograma. «bloqueado» lo añadió el Pipeline para el escudo; lo emite `Escudo3D` (A5) cuando para un disparo de frente.
const REACCIONES: PackedStringArray = ["prendido", "apagado_agua", "apagado_viento", "consumido", "mojado", "secado", "congelado", "derretido",
	"electrocutado", "hundido", "aturdido", "empujado", "bloqueado"]

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


## M3: el mundo recibe ACCIONES, no hechizos. Reparte al agua (agua, fuego, hielo; ver ReaccionesAgua3D) y al ESTADO del suelo (mojada,
## helada, quemada; ver ReaccionesSuelo3D, 21/10) salvo que `a.toca_suelo` sea false. La maqueta sigue PINTANDO el suelo al impactar el VFX
## (`_impacto_en_suelo`); aquí se guarda el hecho con la misma regla. Los `Reactivo3D` siguen recibiendo `on_spell_hit`. Estática para poder
## usarla sin un Mundo3D en el árbol (pruebas).
static func aplicar_accion(a: AccionElemental) -> void:
	ReaccionesAgua3D.aplicar(a)
	if a.toca_suelo:
		ReaccionesSuelo3D.aplicar(a)


func aplicar(a: AccionElemental) -> void:
	aplicar_accion(a)


## Abre un cauce (canal de la tinaja) a la simulación con un manantial: ver ReaccionesAgua3D.abrir_cauce. `volumen` u³ antes de agotarse
## (0 = infinito, como el canal del Bosque; > 0 = una tinaja con fondo, Surtidor3D.VOL_TINAJA de referencia).
static func abrir_cauce(celdas: Array, caudal: float, volumen: float = 0.0) -> bool:
	return ReaccionesAgua3D.abrir_cauce(celdas, caudal, volumen)


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


## B1 (21/10): la imagen del estado del suelo, un píxel por casilla (R quemada · G mojada · B helada · A segada). Es la que debe
## leer el shader del suelo (encargo B2 al Pipeline) en vez de `_img_estado`. Siempre el mismo objeto; se actualiza sola al pedirla
## si algo cambió. Estática: vale sin Mundo3D en el árbol (pruebas).
static func textura_estados() -> ImageTexture:
	var n: int = Terreno3D.lado_del_mapa()
	if n > 0:
		Terreno3D.estados.dimensionar(n)
	return Terreno3D.estados.textura()


## La magia o un objeto avisa de un impacto para que la presentación pinte y suene. No decide qué se pinta.
func avisar_impacto(punto: Vector3, elemento: String, radio: float = 0.0) -> void:
	impacto.emit(punto, elemento, radio)


## Avisa de una reacción con nombre (A4). Estática: la llaman Reactivo3D y Combate3D, que no saben si hay mundo; sin `Mundo3D.actual` (pruebas, escenas
## sueltas) no hace nada. Un nombre fuera del catálogo se avisa con push_warning (para cazar erratas) y NO se emite: el catálogo es cerrado.
static func avisar_reaccion(nombre: String, punto: Vector3, nodo: Node = null) -> void:
	if not REACCIONES.has(nombre):
		push_warning("Mundo3D.avisar_reaccion: «%s» no está en el catálogo de reacciones" % nombre)
		return
	if actual != null and is_instance_valid(actual):
		actual.reaccion.emit(nombre, punto, nodo)


## Avisa de un logro (respuesta positiva). Estática y sin efecto si no hay Mundo3D; un nombre fuera del catálogo avisa con push_warning y no se emite.
static func avisar_logro(nombre: String, punto: Vector3, nodo: Node = null) -> void:
	if not LOGROS.has(nombre):
		push_warning("Mundo3D.avisar_logro: «%s» no está en el catálogo de logros" % nombre)
		return
	if actual != null and is_instance_valid(actual):
		actual.logro.emit(nombre, punto, nodo)
