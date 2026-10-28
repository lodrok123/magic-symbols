class_name TiempoBruja
extends RefCounted

## C4 · ESQUIVA CON PREMIO (docs/PROPUESTA_COMBATE.md §2 y §7; 28/10). Dueño: Juego.
##
## Una voltereta en los últimos `AvisoAtaque3D.VENTANA_ESQUIVA` s de un aviso que cubre a la jugadora (C3) abre el TIEMPO BRUJA: el mundo va a `ESCALA` durante `DURA` s DE
## JUEGO (0,6 s del mundo = 2 s de reloj a 0,3), y en ese rato se puede disparar una página. Ella no va lenta: `Jugador3D` divide su delta y su animación por la escala
## mientras dura (como hace el libro con el clip de apuntar), y es invulnerable.
## A destiempo (antes de la ventana, fuera del aviso, sin aviso) la voltereta es la de siempre.
##
## El tiempo del mundo es `Engine.time_scale`, que también usa el lanzamiento (0,3 con el libro, `Lanzador3D.TIEMPO_PAGINA` al mantener 1/2/3). Mientras dura el tiempo bruja
## manda éste (`actualizar` lo vuelve a poner cada fotograma); al acabar devuelve el del lanzamiento si se está apuntando, o 1.
## Todo es estático: solo hay una jugadora y un reloj. `Jugador3D._process` llama a `actualizar` cada fotograma.

const ESCALA: float = 0.3          ## Engine.time_scale durante el tiempo bruja (el del libro, que Pablo confirmó)
const DURA: float = 0.6            ## s de JUEGO (del mundo) que dura

static var veces: int = 0          ## cuántas veces se ha ganado (pruebas y diario)
static var _queda: float = 0.0     ## s DE JUEGO que le quedan (se descuentan con el delta del mundo, ya escalado: así vale igual con fps fijos que con reloj real)
static var _puesto: bool = false   ## lo ha puesto él y aún no lo ha devuelto


static func activa() -> bool:
	return _puesto and _queda > 0.0


## s de juego que le quedan.
static func queda() -> float:
	return _queda if _puesto else 0.0


## Lo abre (o lo alarga, si ya estaba abierto) `DURA` s de juego.
static func activar() -> void:
	_queda = DURA
	_puesto = true
	veces += 1
	Engine.time_scale = ESCALA
	PlayLog.event("tiempo_bruja", {"veces": veces, "dura_real": snappedf(DURA / ESCALA, 0.01)})


## Cada fotograma con el delta del MUNDO (`delta_juego`, el que da `_process`, ya con la escala): mientras dura, mantiene la escala (el lanzamiento la cambia al entrar y al
## salir de apuntar); al acabar, devuelve la del lanzamiento o 1.
static func actualizar(lanz: Lanzador3D = null, delta_juego: float = 0.0) -> void:
	if not _puesto:
		return
	_queda -= delta_juego
	if _queda > 0.0:
		if not is_equal_approx(Engine.time_scale, ESCALA):
			Engine.time_scale = ESCALA
		return
	_puesto = false
	_queda = 0.0
	Engine.time_scale = lanz.escala_de_tiempo() if lanz != null and is_instance_valid(lanz) else 1.0


## Lo corta ya (al morir, al cambiar de nivel, en las pruebas).
static func terminar(lanz: Lanzador3D = null) -> void:
	if not _puesto:
		return
	_queda = 0.0
	actualizar(lanz)


## El factor con que la jugadora compensa la escala para ir a su paso (1 si no hay tiempo bruja).
static func compensacion() -> float:
	return 1.0 / maxf(Engine.time_scale, 0.05) if activa() else 1.0
