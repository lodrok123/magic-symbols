class_name VfxToyJuego
extends Node

## EL FUEGO, EL AGUA, EL HIELO Y EL RAYO OFICIALES EN EL JUEGO (A1, 2/11/2026; hielo y rayo, B1, 2/11/2026: HieloToy / RayoToy, ≤ 1 luz por hechizo: solo el rayo la lleva; docs/DIRECCION_2026-11-02.md §2.A y docs/ENGANCHE_VFX_TOY_2026-11-02.md).
## Selector: ProjectSettings `magic_symbols/vfx_procedural` (false por defecto). Con true, el fuego y el agua de los hechizos (HechizoVivo) se dibujan con `FuegoToy` / `AguaToy`
## (`desde_hechizo(h)`: figura, semiejes y vuelo salen del Hechizo, sin tocar nada a mano por hechizo) en lugar de `VfxElemento3D` (que con el ajuste a true se calla para esos dos elementos)
## y de la forma en la mano de `ConjuroVfx3D` (que tampoco la dibuja: la carga la hace el toy). Con false este nodo no hace nada: el juego dibuja lo de siempre. Los demás elementos no cambian.
## «La lógica decide, el VFX representa»: este nodo solo ESCUCHA y nunca toca la lógica. Lo que escucha:
##   · `Lanzador3D.conjuro_fase("forma")`  →  `empezar_carga` (brillo y chispas en la mano; datos del Hechizo en `Lanzador3D.conjuro_actual`);  «runa» o «disparo» sin hechizo → se cancela.
##   · `child_entered_tree` (un HechizoVivo con `velocidad` > 0)  →  PROYECTIL: `soltar` la bola de la mano (o un toy nuevo con `desde_hechizo`) y sigue su posición, su dirección y su tamaño (`crece`).
##   · `HechizoVivo.terminado(causa, pos, normal, material)`  →  `finalizar`: golpe / muro / suelo = `impactar_en` con la normal; alcance / tiempo / frenado = `terminar_sin_choque`; retorno = `cancelar_carga`.
##   · `HechizoVivo.rebotado(pos, normal)`  →  `rebotar`.
##   · `Lanzador3D.hechizo_v2` (lo que NO viaja como proyectil: bola quieta, muro, pilar, barrera, haz)  →  un toy por copia, que vive `vida_total` (lo que dice la lógica) y al acabar se apaga.
## Presupuesto: ≤ 1 luz por hechizo (el fuego de las copias sobrantes la apaga; el agua no tiene) y `MAX_VIVOS` toys a la vez.
## Uso:   VfxToyJuego.conectar(lanzador, mundo)

const AJUSTE: String = "magic_symbols/vfx_procedural"
const AJUSTE_ELEMENTOS: String = "magic_symbols/vfx_procedural_elementos"
const ELEMENTOS_DEFECTO: String = "fuego,agua"
const ELEMENTOS: PackedStringArray = ["fuego", "agua", "hielo", "rayo"]      ## los que SABE dibujar el toy (cuáles lo hacen de verdad: `usa_toy`)
const MAX_VIVOS: int = 12
const VIDA_MIN: float = 1.0
const VIDA_MAX: float = 25.0                  ## = VfxElemento3D.VIDA_MAX (el límite global persiste + permanencia)
const SITIOS_MAX: int = 4                     ## copias de un volumen que se dibujan (como VfxElemento3D)
const CARGA_MIN_S: float = 0.3
const CARGA_PERDIDA_S: float = 6.0            ## si el disparo no llega (jugadora muerta), la carga de la mano se retira sola
const CARGA_RADIO_MAX: float = 0.45           ## la bola de la mano de lo que NO es un proyectil no crece hasta el tamaño del muro: este tope (m)
const ALTO_BOLA_QUIETA_MIN: float = 0.3

## Cuántos toys ha creado de cada elemento y el último (las pruebas y la captura lo leen).
var creados: Dictionary = {"fuego": 0, "agua": 0, "hielo": 0, "rayo": 0}
var ultimo: Node3D = null
var cargas: int = 0                           ## cargas en la mano empezadas

var _mundo: Node3D = null
var _lanzador: Object = null
var _ultimo_hv: WeakRef = null
var _vivos: int = 0
var _carga: Node3D = null
var _carga_el: String = ""
var _sigue: Array = []                        ## [{toy: WeakRef, hv: WeakRef | null, ruta: Array, t: float}]
var _con_luz: Dictionary = {}                 ## lanzamientos (Linaje) que ya tienen un toy con luz: las copias de ᚠ no suman luces


## ¿Está encendido el selector? (se lee en cada evento: se puede cambiar en marcha desde una prueba o el lab.)
static func activo() -> bool:
	return bool(ProjectSettings.get_setting(AJUSTE, false))


## ¿Dibuja el toy este elemento? (VfxElemento3D y ConjuroVfx3D lo preguntan para callarse.)
static func usa_toy(elemento: String) -> bool:
	return ELEMENTOS.has(elemento) and activo() and elementos_activos().has(elemento)


## Los elementos que dibuja el toy: `magic_symbols/vfx_procedural_elementos` (lista separada por comas; «fuego,agua» por defecto: hielo y rayo siguen con el dibujo de antes hasta que Pablo los apruebe).
## ÚNICO criterio del juego: VfxToyJuego, VfxElemento3D y ConjuroVfx3D preguntan aquí.
static func elementos_activos() -> PackedStringArray:
	var r: PackedStringArray = []
	for e in String(ProjectSettings.get_setting(AJUSTE_ELEMENTOS, ELEMENTOS_DEFECTO)).split(",", false):
		r.append(e.strip_edges().to_lower())
	return r


static func conectar(lanzador: Object, mundo: Node3D) -> VfxToyJuego:
	if mundo == null:
		return null
	var v := VfxToyJuego.new()
	v.name = "VfxToyJuego"
	v._mundo = mundo
	v._lanzador = lanzador
	mundo.add_child(v)
	if lanzador != null and lanzador.has_signal("conjuro_fase"):
		lanzador.connect("conjuro_fase", v._al_fase)
	if lanzador != null and lanzador.has_signal("hechizo_v2"):
		lanzador.connect("hechizo_v2", v._en_hechizo)
	if lanzador is Node:
		(lanzador as Node).child_entered_tree.connect(v._en_nodo)
	return v


func vivos() -> int:
	return _vivos


func _nuevo(elemento: String) -> Node3D:
	var t: Node3D = null
	match elemento:
		"agua":
			t = AguaToy.new()
		"hielo":
			t = HieloToy.new()
		"rayo":
			t = RayoToy.new()
		_:
			t = FuegoToy.new()
	t.set("casilla", Terreno3D.casilla)
	creados[elemento] = int(creados[elemento]) + 1
	ultimo = t
	return t


func _colgar(t: Node3D) -> void:
	_mundo.add_child(t)
	_vivos += 1
	t.tree_exited.connect(_menos_uno)


func _menos_uno() -> void:
	_vivos = maxi(_vivos - 1, 0)


# ------------------------------------------------------------------ carga en la mano ------------------------------------------------------------------

func _al_fase(fase: String, elemento: String, posicion: Vector3) -> void:
	match fase:
		"runa":
			_retirar_carga()                       # lo que quedara de un conjuro anterior que no llegó a disparar
		"forma":
			if usa_toy(elemento):
				_empezar_carga(elemento, posicion)


func _empezar_carga(elemento: String, pos: Vector3) -> void:
	_retirar_carga()
	if _vivos >= MAX_VIVOS or _mundo == null or not is_instance_valid(_mundo):
		return
	var datos: Dictionary = {}
	if _lanzador != null and "conjuro_actual" in _lanzador:
		datos = _lanzador.get("conjuro_actual") as Dictionary
	var h: Hechizo = datos.get("hechizo") as Hechizo
	var carga_s: float = float(datos.get("carga", 0.0))
	var t_forma: float = 0.2
	if _lanzador != null and _lanzador.has_method("tiempos_conjuro"):
		t_forma = float((_lanzador.call("tiempos_conjuro", elemento) as Array)[2])
	var dur: float = maxf(t_forma + carga_s, CARGA_MIN_S)
	var r: float = 0.3
	if h != null:
		if h.velocidad > 0.0:
			r = maxf(h.semiejes_vuelo.x, h.semiejes_vuelo.z) * Terreno3D.casilla       # la MISMA bola que saldrá volando
		else:
			r = clampf(maxf(h.semieje_x, h.semieje_z) * Terreno3D.casilla, 0.15, CARGA_RADIO_MAX)
	var t: Node3D = _nuevo(elemento)
	_colgar(t)
	t.global_position = pos
	t.call("empezar_carga", dur, r)
	_carga = t
	_carga_el = elemento
	cargas += 1
	_mundo.get_tree().create_timer(CARGA_PERDIDA_S + dur, false).timeout.connect(_carga_perdida.bind(weakref(t)))


func _carga_perdida(ref: WeakRef) -> void:
	var t: Node3D = ref.get_ref() as Node3D
	if t != null and is_instance_valid(t) and t == _carga:
		_retirar_carga()


## Se encoge y se apaga lo que haya en la mano (el hechizo no salió o no es un proyectil: lo que nace lo dibuja otro toy).
func _retirar_carga() -> void:
	if _carga != null and is_instance_valid(_carga):
		_carga.call("cancelar_carga")
	_carga = null
	_carga_el = ""


func _tomar_carga(elemento: String) -> Node3D:
	if _carga != null and is_instance_valid(_carga) and _carga_el == elemento:
		var t: Node3D = _carga
		_carga = null
		_carga_el = ""
		return t
	return null


# ------------------------------------------------------------------ proyectil ------------------------------------------------------------------

func _en_nodo(n: Node) -> void:
	if not (n is HechizoVivo):
		return
	var hv := n as HechizoVivo
	_ultimo_hv = weakref(hv)
	if hv.h == null or not usa_toy(String(hv.elemento)):
		return
	if hv.h.velocidad > 0.0 and not hv.h.haz:
		_proyectil.call_deferred(weakref(hv))      # `v` y la posición se fijan en `_iniciar_proyectil`, después de añadirse


func _proyectil(ref: WeakRef) -> void:
	var hv: HechizoVivo = ref.get_ref() as HechizoVivo
	if hv == null or not is_instance_valid(hv) or not hv.is_inside_tree() or hv.h == null or _mundo == null:
		return
	var el: String = String(hv.elemento)
	var d: Vector3 = hv.v.normalized() if hv.v.length() > 0.01 else Vector3.RIGHT
	var t: Node3D = _tomar_carga(el)
	if t != null:
		t.global_position = hv.global_position
		t.call("soltar", d)                        # la MISMA bola de la mano (pop, cola, estelas)
	else:
		if _vivos >= MAX_VIVOS:
			return
		t = _nuevo(el)
		t.call("desde_hechizo", hv.h)
		_colgar(t)
		t.global_position = hv.global_position
		_orientar(t, d)
		t.call("lanzar", -1.0)
	var lin: int = hv.linaje.get_instance_id() if hv.linaje != null else 0
	if _con_luz.has(lin):
		_sin_luz(t)                                # presupuesto: una sola luz por hechizo (las copias de ᚠ salen del mismo lanzamiento)
	else:
		if _con_luz.size() > 64:
			_con_luz.clear()
		_con_luz[lin] = true
	_sigue.append({"toy": weakref(t), "hv": weakref(hv), "ruta": [], "t": 0.0})
	hv.terminado.connect(_al_terminar.bind(weakref(t)), CONNECT_ONE_SHOT)
	hv.rebotado.connect(_al_rebotar.bind(weakref(t)))
	hv.tree_exiting.connect(_hv_se_va.bind(weakref(t)), CONNECT_ONE_SHOT)


func _orientar(t: Node3D, d: Vector3) -> void:
	if d.length() < 0.001 or not t.is_inside_tree():
		return
	var n: Vector3 = d.normalized()
	t.look_at(t.global_position + n, Vector3.UP if absf(n.y) < 0.99 else Vector3.FORWARD)


## La lógica ha parado el proyectil: el toy hace lo que toca según la causa (con la normal y la posición que da la lógica).
func _al_terminar(causa: String, pos: Vector3, normal: Vector3, _material: String, ref: WeakRef) -> void:
	var t: Node3D = ref.get_ref() as Node3D
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		return
	t.global_position = pos
	t.set_meta("finalizado", true)                 # el toy ya sabe cómo acabar (impacto, encogerse, cancelar): `_hv_se_va` no lo corta
	t.call("finalizar", causa, pos, normal)
	_quitar_seguido(t)


func _al_rebotar(pos: Vector3, normal: Vector3, ref: WeakRef) -> void:
	var t: Node3D = ref.get_ref() as Node3D
	if t != null and is_instance_valid(t) and t.is_inside_tree():
		t.call("rebotar", pos, normal)
		_orientar_tras_rebote(t)


func _orientar_tras_rebote(t: Node3D) -> void:
	for s in _sigue:
		if (s["toy"] as WeakRef).get_ref() == t and (s["hv"] as WeakRef) != null:
			var hv: HechizoVivo = (s["hv"] as WeakRef).get_ref() as HechizoVivo
			if hv != null and is_instance_valid(hv):
				_orientar(t, hv.v)


## El HechizoVivo desaparece sin haber dicho `terminado` (cambio de nivel, lo libera una prueba): el toy se apaga donde esté.
func _hv_se_va(ref: WeakRef) -> void:
	var t: Node3D = ref.get_ref() as Node3D
	if t != null and is_instance_valid(t):
		_quitar_seguido(t)
		if t.is_inside_tree() and not t.has_meta("finalizado"):
			t.call("morir")


func _quitar_seguido(t: Node3D) -> void:
	_sigue = _sigue.filter(func(s: Dictionary) -> bool: return (s["toy"] as WeakRef).get_ref() != t)


func _process(delta: float) -> void:
	if _carga != null and is_instance_valid(_carga) and _lanzador != null and _lanzador.has_method("_pos_cast_point"):
		_carga.global_position = _lanzador.call("_pos_cast_point") as Vector3      # sigue a la mano mientras carga
	var quedan: Array = []
	for s in _sigue:
		var t: Node3D = (s["toy"] as WeakRef).get_ref() as Node3D
		if t == null or not is_instance_valid(t) or not t.is_inside_tree():
			continue
		var hv: HechizoVivo = null
		if s["hv"] != null:
			hv = (s["hv"] as WeakRef).get_ref() as HechizoVivo
		if hv != null and is_instance_valid(hv):
			if hv.activo:
				t.global_position = hv.global_position
				_orientar(t, hv.v)
				if hv._radio_u < hv._radio_pleno_u and hv._radio_pleno_u > 0.0:
					t.scale = Vector3.ONE * clampf(hv._radio_u / hv._radio_pleno_u, 0.05, 1.0)      # `crece`: nace pequeño y llega a su tamaño en vuelo
				else:
					t.scale = Vector3.ONE
			quedan.append(s)
		elif (s["ruta"] as Array).size() > 1:
			s["t"] = float(s["t"]) + delta
			if _recorrer(t, s["ruta"] as Array, float(s["t"])):
				quedan.append(s)
	_sigue = quedan


## Un volumen que viaja (`viaja` sin velocidad): el toy va de punto en punto de los eventos de tiempo. Devuelve false al llegar al último.
func _recorrer(t: Node3D, ruta: Array, tiempo: float) -> bool:
	var ult: Dictionary = ruta[ruta.size() - 1] as Dictionary
	if tiempo >= float(ult["t"]):
		t.global_position = ult["p"] as Vector3
		t.call("finalizar", "alcance")
		return false
	for i in range(ruta.size() - 1):
		var a: Dictionary = ruta[i] as Dictionary
		var b: Dictionary = ruta[i + 1] as Dictionary
		if tiempo <= float(b["t"]):
			var u: float = clampf((tiempo - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 0.001), 0.0, 1.0)
			t.global_position = (a["p"] as Vector3).lerp(b["p"] as Vector3, u)
			_orientar(t, (b["p"] as Vector3) - (a["p"] as Vector3))
			return true
	return true


# ------------------------------------------------------------------ lo que no viaja como proyectil ------------------------------------------------------------------

func _en_hechizo(_estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, _props: Dictionary) -> void:
	if not usa_toy(elemento) or _mundo == null or not is_instance_valid(_mundo):
		return
	var hv: HechizoVivo = _ultimo_hv.get_ref() as HechizoVivo if _ultimo_hv != null else null
	if hv == null or not is_instance_valid(hv) or hv.h == null:
		return                                     # sin el Hechizo no hay figura (la señal no lo trae): se queda sin dibujo, no se inventa
	_retirar_carga()                               # la carga de la mano se apaga: lo que nace lo dibujan los toys de abajo
	if _vivos >= MAX_VIVOS:
		return
	var vida: float = clampf(maxf(float(g.get("vida_total", 0.0)), float(g.get("persiste", 0.0))), VIDA_MIN, VIDA_MAX)
	var suelo: float = float(g.get("suelo", origen.y))
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length() > 0.01 else Vector3.RIGHT
	if g.has("haz"):
		_haz(elemento, hv.h, g["haz"] as Dictionary, suelo, float(g.get("vida_total", Hechizo.HAZ_DURA_S)))
		return
	var sitios: Array = []
	var ruta: Array = []
	for e in (g.get("eventos", []) as Array):
		var p2: Variant = (e as Dictionary).get("pos", Vector2(origen.x, origen.z))
		var pie: Vector3 = Vector3(origen.x, suelo, origen.z)
		if p2 is Vector2:
			pie = Vector3((p2 as Vector2).x, suelo, (p2 as Vector2).y)
		ruta.append({"t": float((e as Dictionary).get("t", 0.0)), "p": pie})
		var repetido: bool = false
		for s in sitios:
			if (s as Vector3).distance_to(pie) < 0.2:
				repetido = true
		if not repetido and sitios.size() < SITIOS_MAX:
			sitios.append(pie)
	if sitios.is_empty():
		sitios.append(Vector3(origen.x, suelo, origen.z))
	if bool(g.get("viaja", false)) and ruta.size() > 1:
		_volumen_que_viaja(elemento, hv.h, ruta)
		return
	var primero: bool = true
	for pie in sitios:
		var t: Node3D = _volumen(elemento, hv.h, pie as Vector3, d, vida)
		if t != null and not primero:
			_sin_luz(t)                            # presupuesto: una sola luz por hechizo
		primero = false


func _volumen(elemento: String, h: Hechizo, pie: Vector3, d: Vector3, vida: float) -> Node3D:
	if _vivos >= MAX_VIVOS:
		return null
	var t: Node3D = _nuevo(elemento)
	t.call("desde_hechizo", h)
	_colgar(t)
	var pos: Vector3 = pie
	if int(t.get("figura")) == 0:                  # BOLA quieta: su centro a media altura sobre el suelo (no enterrada)
		pos.y += maxf(float(t.get("semieje_y")), ALTO_BOLA_QUIETA_MIN)
	t.global_position = pos
	t.look_at(pos + d, Vector3.UP)                 # el X del muro queda de lado al tiro
	t.rotate_y(float(FuegoToy.describir(h, Terreno3D.casilla)["giro_y"]))
	t.call("lanzar", -1.0)
	_expira_en(t, vida)
	return t


func _volumen_que_viaja(elemento: String, h: Hechizo, ruta: Array) -> void:
	if _vivos >= MAX_VIVOS:
		return
	var t: Node3D = _nuevo(elemento)
	t.call("desde_hechizo", h)
	_colgar(t)
	var alto: float = maxf(float(t.get("semieje_y")), ALTO_BOLA_QUIETA_MIN)
	var q: Array = []
	for r in ruta:
		q.append({"t": float((r as Dictionary)["t"]), "p": ((r as Dictionary)["p"] as Vector3) + Vector3(0.0, alto, 0.0)})
	t.global_position = (q[0] as Dictionary)["p"] as Vector3
	_orientar(t, ((q[q.size() - 1] as Dictionary)["p"] as Vector3) - ((q[0] as Dictionary)["p"] as Vector3))
	t.call("lanzar", -1.0)
	_sigue.append({"toy": weakref(t), "hv": null, "ruta": q, "t": 0.0})


## Un haz (ᛁ): del cast point a la punta que calculó la lógica; su largo es el recorrido real (se para en un muro), la altura de su eje la de la mano.
func _haz(elemento: String, h: Hechizo, hz: Dictionary, suelo: float, vida: float) -> void:
	if _vivos >= MAX_VIVOS:
		return
	var desde: Vector3 = hz["desde"] as Vector3
	var hasta: Vector3 = hz["hasta"] as Vector3
	var largo: float = maxf(float(hz.get("largo", desde.distance_to(hasta))), 0.3)
	var t: Node3D = _nuevo(elemento)
	t.call("desde_hechizo", h)
	t.call("definir", FuegoToy.Figura.HAZ, largo * 0.5, maxf(desde.y - suelo, 0.4), Hechizo.HAZ_ANCHO * Terreno3D.casilla * 0.5, false)
	_colgar(t)
	t.global_position = Vector3(desde.x, suelo, desde.z)
	var al: Vector3 = Vector3(hasta.x - desde.x, 0.0, hasta.z - desde.z)
	if al.length() > 0.01:
		t.look_at(t.global_position + al, Vector3.UP)
	t.call("lanzar", -1.0)
	_expira_en(t, maxf(vida, 0.3))


func _sin_luz(t: Node3D) -> void:
	var l: OmniLight3D = t.find_child("Luz", true, false) as OmniLight3D
	if l != null:
		l.visible = false
		l.light_energy = 0.0
		t.set("luz", 0.0)


# ------------------------------------------------------------------ expiración ------------------------------------------------------------------

func _expira_en(t: Node3D, vida: float) -> void:
	_mundo.get_tree().create_timer(vida, false).timeout.connect(_expirar.bind(weakref(t)))


## Se acabó la vida que dijo la lógica: una zona esférica se apaga (el agua, que explota en área, lo hace; el fuego se deshace), lo demás hace su «morir».
func _expirar(ref: WeakRef) -> void:
	var t: Node3D = ref.get_ref() as Node3D
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		return
	if int(t.get("figura")) == 0:
		if (t is AguaToy or t is HieloToy or t is RayoToy) and bool(t.get("area_al_impactar")):
			t.call("impactar_en", t.global_position, Vector3.UP)
		else:
			t.call("terminar_sin_choque")
	else:
		t.call("morir")
