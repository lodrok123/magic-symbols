class_name GlifoSuelo
extends Node3D

## ᛒ SUELO (18/11/2026, diseño de Pablo). Un hechizo con el glifo `suelo` no viaja: se PLANTA en la casilla del suelo a la que apuntas (`Hechizo.suelo`, que además lo hace nacer donde apuntas), y qué hace depende
## del ELEMENTO y de lo que haya en esa casilla. La decisión es `decidir(elemento, casilla)`; todo lo que se pisa, ralentiza o explota es lógica del juego (terreno, Combate3D, `Lanzador3D._golpear`) y lo que se ve
## lo pone `GlifoSueloVfx` (que no decide nada).
##
##   HIELO · casilla de AGUA (líquida, no helada ya)  →  PLATAFORMA DE HIELO: el agua se hiela (`AguaSim3D.helar`, el hielo de siempre) y se pisa mientras dura el hechizo (`persiste` + `permanencia`: 6 s el hielo).
##                                                        Se dibuja con la placa ya hecha (`HieloToy.Figura.SUELO`). Al acabar el tiempo el hielo se suelta solo y el agua vuelve (camino de siempre: `Lanzador3D._derretir`).
##          · cualquier otra casilla de suelo         →  CAPA DE ESCARCHA: hace PATINAR (`Combate3D.patinar`) a los enemigos pequeños y medianos (masa ≤ `Combate3D.MASA_MAX_PATINA`), no a los grandes.
##   TIERRA · casilla de VACÍO (hueco, foso)          →  PLATAFORMA DE TIERRA: la losa de siempre (`Lanzador3D.levantar_plataforma_tierra`), que se pisa mientras dura (`persiste` + `permanencia`: 8 s la tierra).
##          · casilla de AGUA                         →  NADA (la tierra no cuaja: se rechaza antes de cobrar).
##          · cualquier otra casilla de suelo         →  CAPA DE TIERRA: RALENTIZA a los enemigos (`Combate3D.lento`, el estado que ya existe) mientras la pisan.
##   DEMÁS elementos (fuego, agua, rayo, magma, viento, naturaleza) →  TRAMPA de un solo uso: un símbolo discreto en el suelo. Cuando un ENEMIGO entra en su casilla se ilumina con el color del elemento y
##                                                        EXPLOTA (`RADIO_TRAMPA_CAS` casillas): el golpe del hechizo (`Lanzador3D._golpear` → `Combate3D.golpe`, con su daño y su estado) a lo que haya, y desaparece. Sin pisar,
##                                                        se va a los `TRAMPA_VIDA_S` s (+ la `permanencia` que sume el hechizo).
## Sobre el vacío o el agua (sin ser plataforma) no se planta nada que no se pueda sostener: no hay trampa ni capa ahí. Un hechizo con ᛒ ignora el resto de formas (flecha, barrera, líneas…): ᛒ manda.
## Lo plantado vive en `Lanzador3D._suelos` (como mucho `MAX_VIVOS`: al pasarse se retira lo más antiguo) y avanza con `Lanzador3D._avanzar_caducidades`.

enum Caso { NADA, PLATAFORMA_HIELO, CAPA_HIELO, PLATAFORMA_TIERRA, CAPA_TIERRA, TRAMPA }
const NOMBRES_CASO: PackedStringArray = ["nada", "plataforma_hielo", "capa_hielo", "plataforma_tierra", "capa_tierra", "trampa"]

const MAX_VIVOS: int = 6                       ## trampas, capas y placas de hielo vivas a la vez (el suelo se mantiene legible)
const TRAMPA_VIDA_S: float = 20.0              ## lo que espera una trampa sin que nadie la pise
const VIDA_MIN_S: float = 1.0                  ## una plataforma o capa dura al menos esto (aunque la runa no traiga `persiste`)
const RADIO_TRAMPA_CAS: float = 1.0            ## radio (casillas) de la explosión de la trampa
const LENTO_CAPA_S: float = 0.35               ## `lento` que deja la capa de tierra a quien la pisa (se renueva mientras sigue encima)
const GRACIA_HIELO_S: float = 0.3              ## la placa de hielo no mira si el agua sigue helada hasta pasado esto (la simulación avisa en el siguiente fotograma)
const T_RETIRA_S: float = 1.2                  ## lo que tarda en liberarse el dibujo tras retirar (da tiempo a la rotura de la placa de hielo)

var caso: int = Caso.NADA
var celda: Vector2i = Vector2i.ZERO
var elemento: String = ""
var hechizo: Hechizo = null
var lanz: Lanzador3D = null
var color: Color = Color.WHITE
var vida: float = 0.0                          ## s que dura en total
var resta: float = 0.0                         ## s que le quedan
var activo: bool = true                        ## vivo (false: gastado, caducado, deshecho o desalojado). Lo que no está activo ya no hace nada
var disparada: bool = false                    ## trampa que ha explotado
var _t: float = 0.0
var _vfx: Node3D = null
var _lado_m: float = 0.0
var _prev: Dictionary = {}                     ## instance_id del enemigo -> su posición en el último paso (de ahí sale hacia dónde iba)


# ---------------------------------------------------------------------------------------------------------------- la regla

## ¿Qué pasa con este elemento sobre esta casilla? Una de `Caso`. Estática: se mide sin lanzador.
static func decidir(elemento_: String, c: Vector2i) -> int:
	if not Terreno3D.en_mapa(c):
		return Caso.NADA
	var agua: bool = Terreno3D.es_agua(c)                  # líquida y no helada (el hielo físico no cuenta como agua)
	var vacio: bool = Terreno3D.es_vacio(c) or (Terreno3D.es_hueco_cauce(c) and not agua)
	match elemento_:
		"hielo":
			if agua:
				return Caso.PLATAFORMA_HIELO
			return Caso.NADA if vacio else Caso.CAPA_HIELO
		"tierra":
			if agua:
				return Caso.NADA
			return Caso.PLATAFORMA_TIERRA if vacio else Caso.CAPA_TIERRA
	return Caso.NADA if (agua or vacio) else Caso.TRAMPA


## El color con que se ve el elemento (el del juego: `Combate3D.COLORES`; magma y naturaleza, el de su runa).
static func color_de(h: Hechizo) -> Color:
	return Combate3D.COLORES.get(h.elemento, h.color) as Color


## Segundos que dura lo plantado: la trampa espera `TRAMPA_VIDA_S` + la permanencia del hechizo; una plataforma o una capa, lo que dura el hechizo (`persiste` + `permanencia`).
static func vida_de(caso_: int, h: Hechizo) -> float:
	if caso_ == Caso.TRAMPA:
		return TRAMPA_VIDA_S + h.permanencia
	return maxf(h.persiste + h.permanencia, VIDA_MIN_S)


## Por qué NO se puede plantar `h` en el punto `origen` ("" = se puede). Se pregunta antes de cobrar tinta y recarga (`Lanzador3D.rechazo_de_construccion`).
static func rechazo(lanzador: Lanzador3D, h: Hechizo, origen: Vector3) -> String:
	var c: Vector2i = Terreno3D.celda_de(origen)
	if not Terreno3D.en_mapa(c):
		return "fuera del mapa"
	var caso_: int = decidir(h.elemento, c)
	if caso_ == Caso.NADA:
		if Terreno3D.es_agua(c):
			return "la tierra no cuaja sobre el agua" if h.elemento == "tierra" else "no se planta sobre el agua"
		return "no hay suelo"
	if Terreno3D.plataformas_tierra.has(c):
		return "ya hay una plataforma"
	if caso_ != Caso.PLATAFORMA_HIELO and caso_ != Caso.PLATAFORMA_TIERRA and Terreno3D.bloqueada(c):
		return "la casilla está ocupada"
	if caso_ == Caso.PLATAFORMA_HIELO and Terreno3D.agua_sim == null:
		return "el agua no se puede helar aquí"
	return ""


## Planta `h` en la casilla de `origen` (la apuntada). Devuelve las casillas que ocupa (1) o 0 si no se pudo (ver `rechazo`).
static func plantar(lanzador: Lanzador3D, h: Hechizo, origen: Vector3) -> int:
	var c: Vector2i = Terreno3D.celda_de(origen)
	var motivo: String = rechazo(lanzador, h, origen)
	if motivo != "":
		PlayLog.event("suelo_rechazado", {"elemento": h.elemento, "celda": [c.x, c.y], "motivo": motivo})
		return 0
	var caso_: int = decidir(h.elemento, c)
	var duracion: float = vida_de(caso_, h)
	var punto: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	for s in lanzador.suelos_vivos():
		if (s as GlifoSuelo).celda == c:
			(s as GlifoSuelo).retirar("sustituido")           # una casilla, un suelo plantado: el nuevo ocupa el lugar del anterior
	match caso_:
		Caso.PLATAFORMA_TIERRA:
			var celdas: Array[Vector2i] = [c]
			lanzador.levantar_plataforma_tierra(celdas, duracion, Terreno3D.alto_suelo)
		Caso.PLATAFORMA_HIELO:
			if not _helar_agua(lanzador, c, duracion):
				PlayLog.event("suelo_rechazado", {"elemento": h.elemento, "celda": [c.x, c.y], "motivo": "poca agua para helar"})
				return 0
			_montar(lanzador, h, c, caso_, duracion)
		_:
			_montar(lanzador, h, c, caso_, duracion)
	lanzador._sonar_fase_v2("impacto", h.elemento, "abajo", punto)
	PlayLog.event("suelo_plantado", {"elemento": h.elemento, "caso": NOMBRES_CASO[caso_], "celda": [c.x, c.y], "dura": snappedf(duracion, 0.1)})
	return 1


## Hiela el agua de la casilla `duracion` s con el hielo de siempre (la simulación lo cuenta y lo suelta). Devuelve si quedó helada.
static func _helar_agua(lanzador: Lanzador3D, c: Vector2i, duracion: float) -> bool:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return false
	var punto: Vector3 = Terreno3D.centro_de(c, Terreno3D.alto_agua)
	var radio: float = Terreno3D.casilla * ReaccionesAgua3D.RADIO_HIELO
	var efecto: Callable = ReaccionesAgua3D.efecto
	if efecto.is_valid():
		efecto.call("hielo_desde", punto, 0.0, 0.0)
	var n: int = sim.helar(punto, radio, duracion)
	if n > 0 and efecto.is_valid():
		efecto.call("hielo_formado", punto, radio, duracion)
	if efecto.is_valid():
		efecto.call("hielo_cambios", punto, 0.0, 0.0)
	if not sim.casilla_helada(c):
		return false
	lanzador.registrar_hielo_agua(c)            # al soltarse (por tiempo) pasa por `_derretir`: vapor, placa fuera, el agua vuelve a bloquear
	return true


static func _montar(lanzador: Lanzador3D, h: Hechizo, c: Vector2i, caso_: int, duracion: float) -> GlifoSuelo:
	var s := GlifoSuelo.new()
	s.name = "Suelo_%s" % NOMBRES_CASO[caso_]
	s.caso = caso_
	s.celda = c
	s.elemento = h.elemento
	s.hechizo = h
	s.lanz = lanzador
	s.color = color_de(h)
	s.vida = duracion
	s.resta = duracion
	s._lado_m = Terreno3D.casilla
	lanzador.mundo.add_child(s)
	var y: float = (Terreno3D.alto_agua - 0.02) if caso_ == Caso.PLATAFORMA_HIELO else (Terreno3D.y_pies(c) + GlifoSueloVfx.ALTO_CAPA_M)
	s.global_position = Terreno3D.centro_de(c, y)
	s._dibujar()
	lanzador.registrar_suelo(s)
	return s


## Lo que se ve de cada caso (solo dibujo).
func _dibujar() -> void:
	match caso:
		Caso.TRAMPA:
			_vfx = GlifoSueloVfx.simbolo(color, _lado_m * GlifoSueloVfx.LADO_SIMBOLO_CAS)
		Caso.CAPA_HIELO:
			_vfx = GlifoSueloVfx.capa(true, _lado_m * 0.95)
		Caso.CAPA_TIERRA:
			_vfx = GlifoSueloVfx.capa(false, _lado_m * 0.95)
		Caso.PLATAFORMA_HIELO:
			_vfx = GlifoSueloVfx.placa_hielo(_lado_m * 0.95)
	if _vfx == null:
		return
	add_child(_vfx)
	if _vfx is HieloToy:
		(_vfx as HieloToy).lanzar(-1.0)


# ---------------------------------------------------------------------------------------------------------------- la vida

## Un paso de `delta` s (lo da `Lanzador3D._avanzar_caducidades`): lo que hace según el caso y el reloj.
func avanzar(delta: float) -> void:
	if not activo:
		return
	_t += delta
	resta -= delta
	match caso:
		Caso.TRAMPA:
			var dentro: Array = _enemigos_dentro()
			if not dentro.is_empty():
				_explotar(dentro[0] as Node3D)
				return
		Caso.CAPA_HIELO:
			_patinar()
		Caso.CAPA_TIERRA:
			_ralentizar()
		Caso.PLATAFORMA_HIELO:
			if _t > GRACIA_HIELO_S and not Terreno3D.hielo_fisico(celda):
				retirar("deshecho")          # el fuego lo fundió, o se soltó por tiempo
				return
	if resta <= 0.0:
		retirar("caduca")


## Los enemigos (vivos) cuya casilla es la de este suelo.
func _enemigos_dentro() -> Array:
	if lanz == null or not is_instance_valid(lanz) or not lanz.is_inside_tree():
		return []
	return HechizoVivo.nodos_en(lanz, "combate3d", {celda: true})


## Capa de escarcha: lo pequeño y mediano que la pisa patina hacia donde iba (si no se mueve, hacia su objetivo o hacia donde mira).
func _patinar() -> void:
	var vistos: Dictionary = {}
	for n in _enemigos_dentro():
		var e: Combate3D = n as Combate3D
		if e == null:
			continue
		var id: int = e.get_instance_id()
		vistos[id] = true
		var iba: Vector3 = Vector3.ZERO
		if _prev.has(id):
			iba = e.position - (_prev[id] as Vector3)
		_prev[id] = e.position
		e.patinar(iba)
	for id in _prev.keys():
		if not vistos.has(id):
			_prev.erase(id)


## Capa de tierra: lo que la pisa va más lento (`lento`, el estado de siempre: ×0,6 de velocidad) mientras siga encima.
func _ralentizar() -> void:
	for n in _enemigos_dentro():
		var e: Combate3D = n as Combate3D
		if e == null:
			continue
		if e.lento <= 0.0:
			e.texto("Ralentizado", color, 0.4)
		e.lento = maxf(e.lento, LENTO_CAPA_S)


## La trampa explota: el símbolo se ilumina con el color del elemento, el golpe del hechizo (con su daño y su estado) llega a todo lo que haya en el radio y la trampa se gasta.
func _explotar(pisa: Node3D) -> void:
	disparada = true
	activo = false
	var centro: Vector3 = global_position
	var alcance: float = RADIO_TRAMPA_CAS * Terreno3D.casilla
	var golpeados: int = _golpear_en_area(centro, alcance)
	GlifoSueloVfx.iluminar(_vfx as Node3D, color, _lado_m * GlifoSueloVfx.LADO_SIMBOLO_CAS)
	GlifoSueloVfx.explosion(elemento, Vector3(centro.x, Terreno3D.y_pies(celda), centro.z), alcance, color, lanz.mundo if lanz != null and lanz.mundo != null else get_parent())
	PlayLog.event("suelo_trampa", {"elemento": elemento, "celda": [celda.x, celda.y], "pisa": String(pisa.name) if pisa != null else "", "golpeados": golpeados})
	_liberar_en(T_RETIRA_S)


## A cada enemigo y objeto reactivo a menos de `alcance` u de `centro` le llega el golpe del hechizo, por el camino normal (`Lanzador3D._golpear` → `Combate3D.golpe(hechizo, dir)`; estados y empuje incluidos).
## Devuelve a cuántos golpeó. Es el mismo reparto que `HechizoVivo._danar_area`.
func _golpear_en_area(centro: Vector3, alcance: float) -> int:
	if lanz == null or hechizo == null or hechizo.fuente == null:
		return 0
	var hd: Hechizo = hechizo.copiar()
	hd.eventos = {}
	var n_golpes: int = 0
	for grupo in ["combate3d", "reactivo3d"]:
		for obj in lanz.get_tree().get_nodes_in_group(grupo):
			if HechizoVivo.fuera_de_juego(obj):
				continue
			var pecho: Vector3 = (obj as Node3D).global_position + Vector3(0.0, HechizoVivo.CENTRO_ENEMIGO_U, 0.0)
			var plano: Vector3 = pecho - centro
			plano.y = 0.0
			if plano.length() > alcance + HechizoVivo.RADIO_ENEMIGO_U or absf(pecho.y - centro.y) > alcance + HechizoVivo.VENTANA_Y_U + HechizoVivo.RADIO_ENEMIGO_U:
				continue
			var radial: Vector3 = plano.normalized() if plano.length() > 0.01 else Vector3(0.0, 0.0, 1.0)
			lanz._golpear(obj, hechizo.fuente, radial, (obj as Node3D).global_position, 0, false, centro, hd)
			n_golpes += 1
	return n_golpes


## Se retira sin explotar (caducó, lo deshizo el fuego, lo sustituyó otro o lo desalojó el tope): lo lógico acaba ya y el dibujo se desvanece (la placa de hielo se rompe).
func retirar(motivo: String = "") -> void:
	if not activo:
		return
	activo = false
	if _vfx is HieloToy:
		(_vfx as HieloToy).morir()
	elif _vfx != null:
		GlifoSueloVfx.apagar(_vfx)
	PlayLog.event("suelo_retirado", {"elemento": elemento, "caso": NOMBRES_CASO[caso], "celda": [celda.x, celda.y], "motivo": motivo})
	_liberar_en(T_RETIRA_S)


func _liberar_en(segundos: float) -> void:
	if not is_inside_tree():
		queue_free()
		return
	get_tree().create_timer(segundos, false).timeout.connect(queue_free)
