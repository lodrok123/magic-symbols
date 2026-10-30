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
	estados.estado_zona_en = EstadoZona3D.estados_de          # F4: el suelo se seca, se hiela y caduca según los estados de la zona


func _exit_tree() -> void:
	if estados.cambio.is_connected(_estado_cambio):
		estados.cambio.disconnect(_estado_cambio)
	if estados.estado_zona_en == Callable(EstadoZona3D, "estados_de"):
		estados.estado_zona_en = Callable()
	if actual == self:
		actual = null


## EL RELOJ DE LOS ESTADOS DEL SUELO (27/10, lote 3, cambio 1): uno solo, el del mundo vivo. Antes `avanzar` solo lo llamaban las pruebas
## y nada caducaba; ahora el mojado se seca (`EstadosSuelo3D.DURA`). En pausa no corre (es un `_process` de nodo normal).
func _process(delta: float) -> void:
	estados.avanzar(delta)
	avanzar_iluminadas(delta)
	var sim: AguaSim3D = agua
	if sim != null and not sim.factor_hielo_dura.is_valid():
		sim.factor_hielo_dura = EstadoZona3D.factor_hielo_dura       # F4: el hielo del agua dura según la zona (calor 1/3, frío casi no caduca)


func _estado_cambio(c: Vector2i, estado: String, si: bool) -> void:
	casilla_cambio.emit(c, String(EstadosSuelo3D.QUE.get(estado, estado)))
	if si and estado == EstadosSuelo3D.SEGADA:
		Botin.al_segar(self, c)                  # F1: segar hierba puede dar una baya o una flor (tabla `hierba_segada`, una vez por casilla cada 60 s)


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


## B1 (21/10): la imagen del estado del suelo, un píxel por casilla (R quemada · G mojada · B helada · A segada). B2: es la ÚNICA que leen el
## shader del suelo, el del agua y el de la hierba (la maqueta ya no tiene `_img_estado`). Siempre el mismo objeto; se actualiza sola al pedirla
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


## =====================================================================================================
##  F4 · Estados del mundo (docs/PLAN_BASE_DATOS.md §6). Los lleva `EstadoZona3D`; aquí está la fachada que usan el Lanzador, los enemigos y el suelo.
##  Estáticas: valen sin un Mundo3D en el árbol (pruebas) y sin `EstadoZona3D` devuelven lo neutro ([] / 1 / ZERO / false).
## =====================================================================================================

## Los estados del mundo que valen en `celda` (fijos de la zona, dinámicos y `veneno` si hay una nube). [] si no hay.
static func estado_zona(celda: Vector2i) -> Array:
	return EstadoZona3D.estados_de(celda)


## Los estados de la celda donde está la jugadora ahora ([] si no se sabe o no hay).
static func estados_jugadora() -> Array:
	var e: EstadoZona3D = EstadoZona3D.actual
	if e == null or not is_instance_valid(e):
		return []
	var c: Vector2i = e.celda_jugadora()
	return e.estados_en(c) if c != Vector2i(-9999, -9999) else []


## Por cuánto se multiplica lo que PERSISTE un hechizo de `elemento` lanzado en `celda` (1 = igual): el producto de las columnas `fuego_x`, `hielo_x`, `rayo_x` y `viento_x` de los estados de la zona
## (calor: fuego ×1,5, hielo ×0,5 · frío: hielo ×1,5, fuego ×0,7 · humedad: fuego ×0,7, rayo ×1,5 · tormenta: rayo ×1,5). El VIENTO solo cuenta «a favor» del vendaval: pasa la `direccion` del
## hechizo y, si va a favor del viento de la zona (producto escalar > 0,5), sube ×`viento_x` (2); sin dirección vale 1. `HechizoVivo` debe multiplicar su `persiste` por esto (docs/DIARIO.md, petición).
static func factor_persiste(elemento: String, celda: Vector2i, direccion: Vector3 = Vector3.ZERO) -> float:
	var estados: Array = estado_zona(celda)
	if estados.is_empty():
		return 1.0
	if elemento == "viento":
		var v: Vector3 = viento_zona(celda)
		if v == Vector3.ZERO or direccion.length() < 0.01:
			return 1.0
		var d := Vector3(direccion.x, 0.0, direccion.z).normalized()
		return EstadoZona3D.producto(estados, "viento_x") if d.dot(v.normalized()) > 0.5 else 1.0
	if not ["fuego", "hielo", "rayo"].has(elemento):
		return 1.0
	return EstadoZona3D.producto(estados, elemento + "_x")


## El viento de la zona de `celda` como velocidad en u/s del mundo (dirección × `empuje` casillas/s × casilla); Vector3.ZERO si no hay vendaval. `HechizoVivo` debe sumarlo a la velocidad de los proyectiles.
static func viento_zona(celda: Vector2i) -> Vector3:
	var e: EstadoZona3D = EstadoZona3D.actual
	return e.viento_en(celda) if e != null and is_instance_valid(e) else Vector3.ZERO


## Por cuánto se multiplica lo que DURA el hielo en `celda` (calor 1/3; frío ×100 = no caduca). Lo usa el hielo del agua (`AguaSim3D`); el del suelo lo hace `Lanzador3D` (docs/DIARIO.md, petición).
static func factor_hielo_dura(celda: Vector2i) -> float:
	return EstadoZona3D.factor_hielo_dura(celda)


## --- Luz para la oscuridad ---
## celda -> s que le quedan. Fuego, rayo y esporas luminosas la encienden (`Lanzador3D` debe llamar a `iluminar`, docs/DIARIO.md); el pulso también podrá. En la oscuridad la jugadora se ve
## desde cualquier distancia si su casilla está `iluminada`.
static var _iluminadas: Dictionary = {}


## Ilumina `celda` `segundos` s (0 o menos = `ilumina_s` de la tabla, 10). Volver a iluminarla alarga, no acorta.
static func iluminar(celda: Vector2i, segundos: float = 0.0) -> void:
	var s: float = segundos if segundos > 0.0 else float(BD.estado_mundo("oscuridad").get("ilumina_s", 10))
	_iluminadas[celda] = maxf(float(_iluminadas.get(celda, 0.0)), s)


## ¿Está `celda` iluminada? Cuenta una luz encendida a ≤ `ilumina_casillas` casillas (3).
static func iluminada(celda: Vector2i) -> bool:
	if _iluminadas.is_empty():
		return false
	var radio: float = float(BD.estado_mundo("oscuridad").get("ilumina_casillas", 3))
	for c in _iluminadas.keys():
		if Vector2((c as Vector2i) - celda).length() <= radio:
			return true
	return false


## Cuenta atrás de las luces (la llama `_process`; las pruebas sin nodo la llaman a mano).
static func avanzar_iluminadas(dt: float) -> void:
	if _iluminadas.is_empty():
		return
	for c in _iluminadas.keys():
		var t: float = float(_iluminadas[c]) - dt
		if t <= 0.0:
			_iluminadas.erase(c)
		else:
			_iluminadas[c] = t


static func apagar_luces() -> void:
	_iluminadas.clear()

