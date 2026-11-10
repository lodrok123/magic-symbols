class_name VfxToyJuego
extends Node

## EL FUEGO, EL AGUA, EL HIELO, EL RAYO, EL MAGMA, EL VIENTO Y LA TIERRA OFICIALES EN EL JUEGO (A1, 2/11/2026; hielo y rayo, B1, 2/11/2026: HieloToy / RayoToy; 6/11: MagmaToy / VientoToy / TierraToy, ≤ 1 luz por hechizo: la llevan el rayo y la bola de magma, o el FuegoToy hijo de un volumen de magma; viento y tierra, ninguna; docs/DIRECCION_2026-11-02.md §2.A y docs/ENGANCHE_VFX_TOY_2026-11-02.md).
## Selector: ProjectSettings `magic_symbols/vfx_procedural` (false por defecto). Con true, los elementos de la lista (fuego, agua, rayo, magma, viento y tierra de serie) de los hechizos (HechizoVivo) se dibujan con `FuegoToy` / `AguaToy` / `RayoToy` / `MagmaToy` / `VientoToy` / `TierraToy`
## (`desde_hechizo(h)`: figura, semiejes y vuelo salen del Hechizo, sin tocar nada a mano por hechizo) en lugar de `VfxElemento3D` (que con el ajuste a true se calla para esos elementos; «magma» se pregunta con su nombre, no con el de su pieza padre)
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
const ELEMENTOS_DEFECTO: String = "fuego,agua,rayo,magma,viento,tierra"      ## 6/11: magma, viento y tierra se encienden de serie (Pablo quiere verlos en el juego); el hielo sigue con el dibujo de antes
const ELEMENTOS: PackedStringArray = ["fuego", "agua", "hielo", "rayo", "magma", "viento", "tierra"]      ## los que SABE dibujar el toy (cuáles lo hacen de verdad: `usa_toy`)
const MAX_VIVOS: int = 12
const VIDA_MIN: float = 1.0
const VIDA_MAX: float = 25.0                  ## = VfxElemento3D.VIDA_MAX (el límite global persiste + permanencia)
const SITIOS_MAX: int = 4                     ## copias de un volumen que se dibujan (como VfxElemento3D)
const CARGA_MIN_S: float = 0.3
const CARGA_PERDIDA_S: float = 6.0            ## si el disparo no llega (jugadora muerta), la carga de la mano se retira sola
const CARGA_RADIO_MAX: float = 0.45           ## la bola de la mano de lo que NO es un proyectil no crece hasta el tamaño del muro: este tope (m)
const ALTO_BOLA_QUIETA_MIN: float = 0.3
const MAX_AGUA_ELECTRICA: int = 24            ## casillas de suelo electrificado que se dibujan a la vez (cada una, un EstadoRayoToy SUPERFICIE)
const T_ENTIDAD_ELECTRICA: float = 1.2        ## s que dura el estado electrificado dibujado en una entidad tras cada descarga (renovable)
const TIERRA_PILAR_EXTENSION: float = 1.7     ## 422: cuánto sobresale el PILAR del TierraToy respecto a su semieje (roca central ×1,5 + las cuatro de alrededor a ×1,15): para que un pilar de una casilla la cubra justa

## Cuántos toys ha creado de cada elemento y el último (las pruebas y la captura lo leen).
var creados: Dictionary = {"fuego": 0, "agua": 0, "hielo": 0, "rayo": 0, "magma": 0, "viento": 0, "tierra": 0}
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
var _columnas: Array = []                     ## R4: [{toy: WeakRef, ini: ms, nace, t0, t}]: los pilares que crecen de abajo arriba (se escala su Y con el crecimiento lógico)
var _agua_electrica: Dictionary = {}          ## ESTADO ELECTRIFICADO del suelo: casilla (Vector2i) → EstadoRayoToy SUPERFICIE (se quita cuando el estado del suelo caduca: reloj oficial, 2 s)
var electrocutados: int = 0                   ## cuántos estados electrificados de entidad ha dibujado (pruebas)
var _orbes_vivos: Array = []                  ## R3: [{toy: WeakRef, hv: WeakRef, i: int}]: un toy BOLA por orbe, que sigue `HechizoVivo.orbes[i]`
var _tierra_solida: Array = []                ## 422: [{toy: WeakRef, celdas: Array[Vector2i]}]: los TierraToy que cubren bloques reales; se hunden cuando el Lanzador deshace su tierra (`tierra_deshecha`)


## ¿Está encendido el selector? (se lee en cada evento: se puede cambiar en marcha desde una prueba o el lab.)
static func activo() -> bool:
	return bool(ProjectSettings.get_setting(AJUSTE, false))


## ¿Dibuja el toy este elemento? (VfxElemento3D y ConjuroVfx3D lo preguntan para callarse.)
static func usa_toy(elemento: String) -> bool:
	return ELEMENTOS.has(elemento) and activo() and elementos_activos().has(elemento)


static func usa_cast_propio(elemento: String) -> bool:
	const RayoTrazos = preload("res://presentacion/vfx/toy/rayo_trazos.gd")
	return ((elemento == "rayo" and RayoTrazos.prueba_reeboo)
		or (elemento == "viento" and VientoToy.prueba_corrientes)) and usa_toy(elemento)


static func aura_viento(obj: Node, duracion: float, levita: bool = false) -> void:
	const AuraViento = preload("res://presentacion/vfx/toy/viento_aura.gd")
	if not VientoToy.prueba_corrientes or not usa_toy("viento") or not obj is Node3D or not obj.is_inside_tree():
		return
	var aura := obj.get_node_or_null("AuraViento") as AuraViento
	if aura == null:
		var ancla := obj as Node3D
		if obj is Limo3D and is_instance_valid(obj.cuerpo):
			ancla = obj.cuerpo
		elif obj is Combate3D or obj is Jugador3D:
			var modelo := obj.get("pj") as Node3D
			if is_instance_valid(modelo):
				ancla = modelo
		aura = AuraViento.new()
		aura.name = "AuraViento"
		aura.ancla = ancla
		aura.dimensiones = _dimensiones(ancla)
		aura.desfase_y = -aura.dimensiones.x * 0.5 if obj is RigidBody3D else 0.0
		aura.top_level = true
		obj.add_child(aura)
	aura.renovar(duracion, levita)


## 6/11 (entrada 422, Pablo): con el toy de tierra encendido, el TierraToy es la ÚNICA representación de la tierra temporal del Lanzador: ni la caja/vestido del `BloqueTierra`
## (lo calla `Lanzador3D.construir_tierra`) ni la terraza de la maqueta en esa casilla (lo pregunta `PruebaTest2._vigilar_alturas` aquí). Las terrazas fijas y el hielo no cambian.
static func oculta_terraza(c: Vector2i) -> bool:
	return usa_toy("tierra") and Terreno3D.alturas_temporales.has(c)


## Los elementos que dibuja el toy: `magic_symbols/vfx_procedural_elementos` (lista separada por comas; «fuego,agua,rayo,magma,viento,tierra» por defecto: el hielo sigue con el dibujo de antes hasta que Pablo lo apruebe).
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
	if lanzador != null and lanzador.has_signal("tierra_deshecha"):
		lanzador.connect("tierra_deshecha", v._al_tierra_deshecha)
	if lanzador != null and lanzador.has_signal("plataforma_tierra_lanzada"):
		lanzador.connect("plataforma_tierra_lanzada", v._retirar_carga)
	if lanzador is Node:
		(lanzador as Node).child_entered_tree.connect(v._en_nodo)
	v._enganchar_estados()
	return v


func vivos() -> int:
	return _vivos


# ------------------------------------------------------------------ estado electrificado (5/11) ------------------------------------------------------------------

## El ESTADO ELECTRIFICADO no es un hechizo: lo ESCUCHA de la lógica. Dos avisos: `Terreno3D.estados.cambio(c, «electrificada», si)` (el suelo, con el reloj oficial) y `Mundo3D.reaccion(«electrocutado», punto, nodo)` (una entidad
## a la que le llega una descarga). Solo dibuja si el rayo es del toy (`usa_toy("rayo")`).
func _enganchar_estados() -> void:
	if Terreno3D.estados != null and not Terreno3D.estados.cambio.is_connected(_al_estado_suelo):
		Terreno3D.estados.cambio.connect(_al_estado_suelo)
	var m: Object = Mundo3D.actual
	if m != null and m.has_signal("reaccion") and not m.is_connected("reaccion", _al_reaccion):
		m.connect("reaccion", _al_reaccion)


## Casillas de suelo electrificadas que se dibujan ahora (pruebas).
func agua_electrica() -> Dictionary:
	return _agua_electrica


func _al_estado_suelo(c: Vector2i, estado: String, si: bool) -> void:
	if estado != EstadosSuelo3D.ELECTRIFICADA:
		return
	if not si:
		if _agua_electrica.has(c):
			var viejo: EstadoRayoToy = _agua_electrica[c] as EstadoRayoToy
			_agua_electrica.erase(c)
			if viejo != null and is_instance_valid(viejo):
				viejo.apagar()
		return
	if _agua_electrica.has(c) or not usa_toy("rayo") or _mundo == null or not is_instance_valid(_mundo) or _agua_electrica.size() >= MAX_AGUA_ELECTRICA:
		return
	var e: EstadoRayoToy = EstadoRayoToy.para_superficie(Terreno3D.casilla * 0.92, Terreno3D.casilla * 0.92)
	_mundo.add_child(e)
	var y: float = 0.0
	if Terreno3D.hay_mundo():
		y = Terreno3D.superficie_agua(c) if Terreno3D.es_agua(c) else Terreno3D.y_pies(c)
	e.global_position = Terreno3D.centro_de(c, y)
	_agua_electrica[c] = e


func _al_reaccion(nombre: String, _punto: Vector3, nodo: Node) -> void:
	if nombre != "electrocutado" or not usa_toy("rayo") or not (nodo is Node3D) or not is_instance_valid(nodo):
		return
	var cuerpo: Node3D = nodo as Node3D
	var previo: EstadoRayoToy = cuerpo.get_node_or_null("EstadoElectrificado") as EstadoRayoToy
	if previo != null:
		previo.renovar(T_ENTIDAD_ELECTRICA)
		return
	var dim: Vector2 = _dimensiones(cuerpo)
	var e: EstadoRayoToy = EstadoRayoToy.para_entidad(dim.x, dim.y, T_ENTIDAD_ELECTRICA)
	e.name = "EstadoElectrificado"
	cuerpo.add_child(e)
	electrocutados += 1


## (alto, radio) en metros de lo que hay colgado de `n`: la unión de sus mallas visibles (sin escala de mundo); sin mallas, 1,0 × 0,4.
static func _dimensiones(n: Node3D) -> Vector2:
	var union: AABB = AABB()
	var primero: bool = true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var ab: AABB = (n.global_transform.affine_inverse() * mi.global_transform) * mi.mesh.get_aabb()
		union = ab if primero else union.merge(ab)
		primero = false
	if primero:
		return Vector2(1.0, 0.4)
	var esc: float = n.global_transform.basis.get_scale().y
	return Vector2(clampf(union.size.y * esc, 0.5, 3.0), clampf(maxf(union.size.x, union.size.z) * 0.5 * esc, 0.2, 1.2))


func _nuevo(elemento: String) -> Node3D:
	var t: Node3D = null
	match elemento:
		"agua":
			t = AguaToy.new()
		"hielo":
			t = HieloToy.new()
		"rayo":
			t = RayoToy.new()
		"magma":
			t = MagmaToy.new()
		"viento":
			t = VientoToy.new()
		"tierra":
			t = TierraToy.new()
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
		"voluta":
			if usa_cast_propio(elemento) and _lanzador != null and _lanzador.has_method("_pos_cast_point"):
				_empezar_carga(elemento, _lanzador.call("_pos_cast_point") as Vector3)
		"forma":
			if usa_cast_propio(elemento) and is_instance_valid(_carga) and _carga_el == elemento:
				return
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
		if h.proyectil:
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
	if hv.h.proyectil and not hv.h.haz:      # 3/11 (R1): el volumen sólido que viaja lo dibuja `hechizo_v2` (un MURO que recorre su ruta), no la bola de un proyectil
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
	_seguir_orbes()
	_crecer_columnas()


## R3: cada bola sigue a su orbe; al apagarse el orbe (acabó la órbita o salió disparado) se deshace.
func _seguir_orbes() -> void:
	var quedan: Array = []
	for s in _orbes_vivos:
		var t: Node3D = (s["toy"] as WeakRef).get_ref() as Node3D
		if t == null or not is_instance_valid(t) or not t.is_inside_tree():
			continue
		var hv: HechizoVivo = (s["hv"] as WeakRef).get_ref() as HechizoVivo
		var vivo: bool = false
		var lanzado: bool = false
		if hv != null and is_instance_valid(hv) and int(s["i"]) < hv.orbes.size():
			var o: Dictionary = hv.orbes[int(s["i"])]
			lanzado = bool(o.get("lanzado", false))
			if bool(o["activo"]):
				vivo = true
				var a: float = float(o["ang"])
				t.global_position = o["p"] as Vector3
				_orientar(t, Vector3(-sin(a), 0.0, cos(a)))
		if vivo:
			quedan.append(s)
		elif lanzado:
			t.call("morir")                              # el orbe salió disparado: esta bola se apaga y el proyectil nuevo lo dibuja su propio toy
		else:
			t.call("terminar_sin_choque")
	_orbes_vivos = quedan


## R4: el pilar nace a `nace` de su altura y sube hasta la entera en el tiempo que dice la lógica (`tiempo_crecimiento`): se escala su Y (el dibujo del pilar no anima el crecimiento vertical por sí solo).
func _crecer_columnas() -> void:
	var quedan: Array = []
	for c in _columnas:
		var t: Node3D = (c["toy"] as WeakRef).get_ref() as Node3D
		if t == null or not is_instance_valid(t) or not t.is_inside_tree():
			continue
		var seg: float = float(Time.get_ticks_msec() - int(c["ini"])) / 1000.0 - float(c["t0"])
		var total: float = float(c["t"])
		var f: float = 1.0 if total <= 0.0 else clampf(seg / total, 0.0, 1.0)
		t.scale.y = lerpf(float(c["nace"]), 1.0, f)
		if f < 1.0:
			quedan.append(c)
	_columnas = quedan


## Un volumen que viaja (`viaja` sin velocidad): el toy va de punto en punto de los eventos de tiempo. Devuelve false al llegar al último.
func _recorrer(t: Node3D, ruta: Array, tiempo: float) -> bool:
	var ult: Dictionary = ruta[ruta.size() - 1] as Dictionary
	var es_bola: bool = int(t.get("figura")) == 0       # 3/11: solo una bola se orienta a lo largo del camino; un muro conserva su orientación (también en la vuelta)
	if tiempo >= float(ult["t"]):
		t.global_position = ult["p"] as Vector3
		if es_bola:
			t.call("finalizar", "alcance")
		else:
			t.call("morir")
		return false
	for i in range(ruta.size() - 1):
		var a: Dictionary = ruta[i] as Dictionary
		var b: Dictionary = ruta[i + 1] as Dictionary
		if tiempo <= float(b["t"]):
			var u: float = clampf((tiempo - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 0.001), 0.0, 1.0)
			t.global_position = (a["p"] as Vector3).lerp(b["p"] as Vector3, u)
			if es_bola:
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
		_haz(elemento, hv.h, g["haz"] as Dictionary, suelo, float(g.get("vida_total", Hechizo.HAZ_DURA_S)), origen)
		return
	if g.has("orbita"):
		_orbes(elemento, hv, g["orbita"] as Dictionary)       # 3/11 (R3): ᛃ + ᚠ sin flecha: un toy BOLA por orbe, siguiendo su posición
		return
	if g.has("estalla"):
		vida = clampf(float((g["estalla"] as Dictionary)["t"]), VIDA_MIN, VIDA_MAX)      # 3/11 (R5): la bola de agua que crece estalla cuando dice la lógica
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
		_volumen_que_viaja(elemento, hv.h, g, suelo, d)
		return
	if elemento == "tierra" and _estado == "solido" and int(g.get("niveles", 0)) > 0 and not (g.get("celdas", []) as Array).is_empty() and not g.has("estalla"):
		_tierra_sobre_celdas(hv.h, g, sitios, d, vida)      # 422: el toy cubre el sólido real (casillas × niveles), no la cresta del fuego
		return
	var primero: bool = true
	for pie in sitios:
		var t: Node3D = _volumen(elemento, hv.h, pie as Vector3, d, vida)
		if t != null and not primero:
			_sin_luz(t)                            # presupuesto: una sola luz por hechizo
		if t != null and g.has("estalla"):
			t.set_meta("estalla_m", float((g["estalla"] as Dictionary)["radio"]) * Terreno3D.casilla)      # R5: el radio del daño en área que dice la lógica
		if t != null and g.has("columna"):
			var col: Dictionary = g["columna"] as Dictionary
			_columnas.append({"toy": weakref(t), "ini": Time.get_ticks_msec(), "nace": float(col["nace"]), "t0": float(col["t0"]), "t": float(col["t"])})      # R4: crece de abajo arriba
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


## 6/11 (entrada 422, Pablo): la TIERRA SÓLIDA (lo que `Lanzador3D.construir_tierra` levanta por casilla) la representa SOLO el TierraToy, así que cada toy se dimensiona a las casillas
## reales de su copia (las de `g.celdas` más cercanas a su sitio): ancho = casillas de lado × `Terreno3D.casilla`, fondo = casillas a lo largo del tiro × casilla (un muro: UNA casilla),
## alto = niveles × `Terreno3D.ALTO_NIVEL` (la tapa del sólido), y se asienta sobre el suelo real bajo esas casillas (`Terreno3D.y_pies` antes de levantarlas). La figura: MURO si es
## alargado (girado si lo largo va a lo largo del tiro, como `FuegoToy.describir`), PILAR si es una casilla con ≥ 2 niveles, BARRERA si es cuadrado de ≥ 2 casillas (corona: el centro
## queda sin rocas), MURO de una casilla si no. El `definir` se hace aquí, no en el toy. Se hunde cuando el Lanzador deshace el bloque (`tierra_deshecha`); la expiración de siempre queda de red.
func _tierra_sobre_celdas(h: Hechizo, g: Dictionary, sitios: Array, d: Vector3, vida: float) -> void:
	var cas: float = Terreno3D.casilla
	var perp: Vector3 = Vector3(-d.z, 0.0, d.x)
	var grupos: Array = []
	for _s in sitios:
		grupos.append([])
	for c in (g["celdas"] as Array):
		var cc: Vector2i = c
		var p: Vector3 = Terreno3D.centro_de(cc, 0.0)
		var mejor: int = 0
		var dist: float = INF
		for i in sitios.size():
			var s: Vector3 = sitios[i]
			var dd: float = Vector2(p.x - s.x, p.z - s.z).length_squared()
			if dd < dist:
				dist = dd
				mejor = i
		(grupos[mejor] as Array).append(cc)
	var primero: bool = true
	for i in sitios.size():
		var celdas: Array = grupos[i]
		if celdas.is_empty() or _vivos >= MAX_VIVOS:
			continue
		var s: Vector3 = sitios[i]
		var lx_min: float = INF
		var lx_max: float = -INF
		var lz_min: float = INF
		var lz_max: float = -INF
		var y_suelo: float = INF
		for c in celdas:
			var p: Vector3 = Terreno3D.centro_de(c as Vector2i, 0.0)
			var rel: Vector3 = Vector3(p.x - s.x, 0.0, p.z - s.z)
			lx_min = minf(lx_min, rel.dot(perp))
			lx_max = maxf(lx_max, rel.dot(perp))
			lz_min = minf(lz_min, rel.dot(d))
			lz_max = maxf(lz_max, rel.dot(d))
			# el suelo REAL bajo la casilla: sin la tierra temporal que ya hubiera (un segundo muro en el mismo sitio no se apila: el Lanzador renueva el que hay)
			y_suelo = minf(y_suelo, (Terreno3D.y_pies(c as Vector2i) - float(Terreno3D.alturas_temporales.get(c, 0)) * Terreno3D.ALTO_NIVEL) if Terreno3D.hay_mundo() else s.y)
		var ancho_cas: int = int(round((lx_max - lx_min) / cas)) + 1
		var fondo_cas: int = int(round((lz_max - lz_min) / cas)) + 1
		var niveles: int = int(g["niveles"])
		var alto: float = float(niveles) * Terreno3D.ALTO_NIVEL
		var centro: Vector3 = s + perp * ((lx_min + lx_max) * 0.5) + d * ((lz_min + lz_max) * 0.5)
		centro.y = y_suelo if y_suelo != INF else s.y
		var fig: int = FuegoToy.Figura.MURO
		var giro: float = 0.0
		var sx: float = float(ancho_cas) * cas * 0.5
		var sz: float = float(fondo_cas) * cas * 0.5
		if ancho_cas == fondo_cas:
			if ancho_cas == 1 and niveles >= 2:
				fig = FuegoToy.Figura.PILAR
				sx = cas * 0.5 / TIERRA_PILAR_EXTENSION
				sz = sx
			elif ancho_cas >= 2:
				fig = FuegoToy.Figura.BARRERA
		elif fondo_cas > ancho_cas:
			giro = PI * 0.5                            # el muro se alarga por su X: lo largo va a lo largo del tiro
			sx = float(fondo_cas) * cas * 0.5
			sz = float(ancho_cas) * cas * 0.5
		var t: Node3D = _nuevo("tierra")
		t.call("desde_hechizo", h)
		t.call("definir", fig, sx, alto, sz, false)
		_colgar(t)
		t.global_position = centro
		t.look_at(centro + d, Vector3.UP)
		t.rotate_y(giro)
		t.call("lanzar", -1.0)
		_expira_en(t, vida)
		if not primero:
			_sin_luz(t)
		primero = false
		if g.has("columna"):
			var col: Dictionary = g["columna"] as Dictionary
			_columnas.append({"toy": weakref(t), "ini": Time.get_ticks_msec(), "nace": float(col["nace"]), "t0": float(col["t0"]), "t": float(col["t"])})      # R4: crece de abajo arriba
		_tierra_solida.append({"toy": weakref(t), "celdas": celdas.duplicate()})


## 422: el Lanzador deshizo la tierra de `c`: el toy que la cubría se hunde ahora (su máquina `hunde`), no cuando le toque por vida.
func _al_tierra_deshecha(c: Vector2i) -> void:
	var quedan: Array = []
	for e in _tierra_solida:
		var t: Node3D = (e["toy"] as WeakRef).get_ref() as Node3D
		if t == null or not is_instance_valid(t) or not t.is_inside_tree():
			continue
		if (e["celdas"] as Array).has(c):
			t.call("morir")
			continue
		quedan.append(e)
	_tierra_solida = quedan


## 3/11 (R1/R2): el volumen que VIAJA (el muro de ᛜ + ᛇ, y su vuelta con ᛃ): un toy por copia (como mucho SITIOS_MAX) que recorre los eventos de tiempo de la lógica, en el CENTRO del volumen (la posición del evento más su
## adelanto) y con la orientación de siempre (el muro mira donde se lanzó, también en la vuelta). Una bola (lo que viaja sin solidez) además se orienta a lo largo del camino y sale a media altura.
func _volumen_que_viaja(elemento: String, h: Hechizo, g: Dictionary, suelo: float, d: Vector3) -> void:
	var adelanto_u: float = Lanzador3D.GeometriaV2.adelanto(h.geo()) * Terreno3D.casilla
	var por_copia: Dictionary = {}
	for e in (g.get("eventos", []) as Array):
		var ed: Dictionary = e
		var p2: Vector2 = ed.get("pos", Vector2.ZERO)
		var de2: Vector2 = ed.get("dir", Vector2(d.x, d.z))
		var de3: Vector3 = Vector3(de2.x, 0.0, de2.y)
		de3 = de3.normalized() if de3.length() > 0.01 else d
		var lista: Array = por_copia.get(int(ed.get("copia", 0)), [])
		lista.append({"t": float(ed.get("t", 0.0)), "p": Vector3(p2.x, suelo, p2.y) + de3 * adelanto_u})
		por_copia[int(ed.get("copia", 0))] = lista
	var primero: bool = true
	var n_toys: int = 0
	for copia in por_copia:
		var ruta: Array = por_copia[copia]
		if _vivos >= MAX_VIVOS or ruta.size() < 2 or n_toys >= SITIOS_MAX:
			continue
		n_toys += 1
		var t: Node3D = _nuevo(elemento)
		t.call("desde_hechizo", h)
		_colgar(t)
		var es_bola: bool = int(t.get("figura")) == 0
		var alto: float = maxf(float(t.get("semieje_y")), ALTO_BOLA_QUIETA_MIN) if es_bola else 0.0
		var q: Array = []
		for r in ruta:
			q.append({"t": float((r as Dictionary)["t"]), "p": ((r as Dictionary)["p"] as Vector3) + Vector3(0.0, alto, 0.0)})
		t.global_position = (q[0] as Dictionary)["p"] as Vector3
		if es_bola:
			_orientar(t, ((q[q.size() - 1] as Dictionary)["p"] as Vector3) - ((q[0] as Dictionary)["p"] as Vector3))
		else:
			t.look_at(t.global_position + d, Vector3.UP)
			t.rotate_y(float(FuegoToy.describir(h, Terreno3D.casilla)["giro_y"]))
		t.call("lanzar", -1.0)
		if not primero:
			_sin_luz(t)                                # presupuesto: una sola luz por hechizo
		primero = false
		_sigue.append({"toy": weakref(t), "hv": null, "ruta": q, "t": 0.0})


## 3/11 (R3): los orbes de ᛃ + ᚠ sin flecha: UN toy BOLA por orbe (la misma bola que un proyectil, con cola) que sigue la posición que calcula la lógica (`HechizoVivo.orbes[i]["p"]`). Cuando la lógica apaga el orbe
## (acaba la órbita) se deshace; si el orbe salió disparado contra un enemigo (ᚨ), esa bola se apaga y el proyectil que nace lo dibuja el camino de siempre. Solo la primera lleva luz.
func _orbes(elemento: String, hv: HechizoVivo, o: Dictionary) -> void:
	var r: float = float(o.get("radio_orbe", 0.3))
	for i in range(int(o.get("n", 0))):
		if _vivos >= MAX_VIVOS:
			return
		var t: Node3D = _nuevo(elemento)
		t.call("desde_hechizo", hv.h)
		t.call("definir", FuegoToy.Figura.BOLA, r, r, r, true)
		_colgar(t)
		var p0: Vector3 = (hv.orbes[i] as Dictionary)["p"] as Vector3
		t.global_position = p0
		t.call("lanzar", -1.0)
		if i > 0:
			_sin_luz(t)
		_orbes_vivos.append({"toy": weakref(t), "hv": weakref(hv), "i": i})


## Un haz (ᛁ): del cast point a la punta que calculó la lógica; su largo es el recorrido real (se para en un muro), la altura de su eje la de la mano.
func _haz(elemento: String, h: Hechizo, hz: Dictionary, suelo: float, vida: float, origen: Vector3) -> void:
	if _vivos >= MAX_VIVOS:
		return
	var desde: Vector3 = hz["desde"] as Vector3
	var hasta: Vector3 = hz["hasta"] as Vector3
	var largo: float = maxf(float(hz.get("largo", desde.distance_to(hasta))), 0.3)
	var t: Node3D = _nuevo(elemento)
	t.call("desde_hechizo", h)
	# Integración 10/11: el haz de TIERRA nace a los pies (origen) con su alto fijo (REF_HAZ); el resto, de la mano. Los choques (9/11) se pasan a TODOS los toys que los
	# tengan, medidos desde el mismo punto donde se coloca el toy.
	var tierra: TierraToy = t as TierraToy
	var inicio: Vector3 = origen if tierra != null else desde
	var alto: float = TierraToy.REF_HAZ.y if tierra != null else maxf(desde.y - suelo, 0.4)
	t.call("definir", FuegoToy.Figura.HAZ, largo * 0.5, alto, Hechizo.HAZ_ANCHO * Terreno3D.casilla * 0.5, false)
	var al: Vector3 = Vector3(hasta.x - inicio.x, 0.0, hasta.z - inicio.z)
	if "choques" in t:
		t.set("choques", _choques_locales(hz.get("choques", []) as Array, inicio, al))       # 9/11: la salpicadura y la luz del suelo se dibujan donde la lógica dice que choca
	_colgar(t)
	t.global_position = Vector3(inicio.x, suelo, inicio.z)
	if al.length() > 0.01:
		t.look_at(t.global_position + al, Vector3.UP)
	if tierra != null:
		tierra.anclar_linea_al_suelo(func(pie: Vector3) -> float:
			var celda: Vector2i = Terreno3D.celda_de(pie)
			return Terreno3D.y_pies(celda) if Terreno3D.en_mapa(celda) else suelo)
	t.call("lanzar", -1.0)
	_ritmo_nacer(t, float(h.get_meta(META_RITMO_NACER, 1.0)))
	# 7/11: la vida del haz (HAZ_DURA_S 0,9 s) puede ser MENOR que su «nacer» (el haz de tierra con 14 púas tarda 0,94 s en brotar): el hundimiento empezaba antes de que salieran las últimas y nunca
	# se veían todas arriba. El dibujo aguanta al menos lo que tarda en nacer + una pausa; la lógica (daño, casillas) sigue con su HAZ_DURA_S.
	var ap_n: AnimationPlayer = t.get_node_or_null("Anim") as AnimationPlayer
	if ap_n != null and ap_n.has_animation("nacer"):
		vida = maxf(vida, ap_n.get_animation("nacer").length / maxf(ap_n.speed_scale, 0.05) + 0.45)
	_expira_en(t, maxf(vida, 0.3))
	if elemento == "fuego" and _haz_con_gas(h, hz, suelo, vida):
		HazGasJuego.solo_luz(t)              # el gas dibuja el chorro y la masa; del FuegoToy quedan la luz del suelo y la del hechizo
	elif elemento == "agua" and t is AguaToy and _haz_con_gas(h, hz, suelo, vida, "agua"):
		HazGasJuego.ocultar_toy(t)           # 10/11: el gas en modo agua dibuja el chorro, la lámina y las gotas; el AguaToy sigue vivo pero no se ve


## 9/11 (Pablo, prototipo A llevado al juego): el haz de FUEGO se dibuja con la simulación de gas toon (HazGasJuego) contra los sólidos reales, si hay RenderingDevice
## (Forward+ / Mobile), el ajuste `magic_symbols/vfx_haz_gas` está encendido (lo está de serie) y no se ha llegado al tope de instancias. Si no, false: el FuegoToy HAZ de siempre.
## 10/11: el de AGUA igual, con el gas en modo agua y su propio ajuste `magic_symbols/vfx_haz_gas_agua`; si no, el AguaToy HAZ de siempre. El tope es de los dos juntos.
## Solo dibuja: lo que hace el haz (daño, alcance, ticks, choques) lo sigue decidiendo HechizoVivo.
var gas: HazGasJuego = null


func _haz_con_gas(h: Hechizo, hz: Dictionary, suelo: float, vida: float, elemento: String = "fuego") -> bool:
	if not HazGasJuego.disponible(elemento):
		return false
	if gas == null or not is_instance_valid(gas):
		gas = HazGasJuego.conectar(_mundo)
	return gas.haz(h, hz, suelo, vida, elemento) != null


## Los choques del haz (mundo: punto y normal) en el espacio del toy, que mira a -Z desde la mano (`al` = hacia dónde va el haz): [{d: m a lo largo, x: m a un lado, n: normal local}].
## Se descartan los que quedan detrás de la mano o más allá del largo (no son del haz).
static func _choques_locales(choques: Array, desde: Vector3, al: Vector3) -> Array:
	var res: Array = []
	if al.length() < 0.01:
		return res
	var fwd: Vector3 = al.normalized()
	var der: Vector3 = fwd.cross(Vector3.UP).normalized()           # el +X local del toy tras look_at
	var largo: float = al.length()
	for ch in choques:
		var p: Vector3 = (ch as Dictionary)["punto"] as Vector3
		var n: Vector3 = (ch as Dictionary)["normal"] as Vector3
		var d: float = (p - desde).dot(fwd)
		if d < 0.1 or d > largo + 0.3:
			continue
		res.append({"d": d, "x": (p - desde).dot(der), "n": Vector3(n.dot(der), n.y, -n.dot(fwd)), "tipo": String((ch as Dictionary).get("tipo", "muro"))})
	return res


## 5/11 (Pablo, el dragón de pared: «desacelera las llamas un 30 % para que crezcan menos rápido»): quien lanza el hechizo puede marcarlo con la meta `ritmo_nacer_vfx` (× la velocidad de «nacer»;
## 0,7 = un 30 % más lento). Solo el crecimiento: al acabar «nacer» el toy vuelve a ritmo 1 (su «morir» dura lo de siempre). Sin la meta no cambia nada.
const META_RITMO_NACER: StringName = &"ritmo_nacer_vfx"


func _ritmo_nacer(t: Node3D, ritmo: float) -> void:
	if absf(ritmo - 1.0) < 0.001:
		return
	var ap: AnimationPlayer = t.get_node_or_null("Anim") as AnimationPlayer
	if ap == null or not ap.has_animation("nacer"):
		return
	ap.speed_scale = maxf(ritmo, 0.05)
	var ref: WeakRef = weakref(ap)
	_mundo.get_tree().create_timer(ap.get_animation("nacer").length / ap.speed_scale, false).timeout.connect(func() -> void:
		var a: AnimationPlayer = ref.get_ref() as AnimationPlayer
		if a != null and is_instance_valid(a):
			a.speed_scale = 1.0)


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
		if t.get("area_al_impactar") == true:      # sin lista de clases; FuegoToy no tiene la propiedad (get = null)
			if t.has_meta("estalla_m"):
				t.call("impactar_en", t.global_position, Vector3.UP, float(t.get_meta("estalla_m")))      # R5: con el radio de la lógica
			else:
				t.call("impactar_en", t.global_position, Vector3.UP)
		else:
			t.call("terminar_sin_choque")
	else:
		t.call("morir")
