class_name Recolectable3D
extends Area3D

## RECOLECTABLE (la Cueva, 23/10; docs/PLAN_BOSQUE_EOW.md §6). Una planta del suelo (hoy, las setas de la cueva) que se COGE con `E` estando
## cerca y da un INGREDIENTE a la mochila (`Estado.agregar`). Antes de cogerla se le puede lanzar un elemento: se transforma en el ingrediente
## de `Objetos.PLANTAS` (fuego → seta asada, rayo → seta electrificada, hielo → helada, agua → empapada, viento → esporas), cambia de color y
## ya no vuelve a cambiar. Así el ingrediente que se lleva depende del hechizo que se le lanzó: el recolectable habla el idioma del juego.
##
## El aspecto es una pieza del decorado (`setas_rojas`, `setas_azules`, `setas_marrones`): se INTERCALAN por casilla si no se dice cuál, para
## que un corro de setas no sea el mismo modelo repetido. No bloquea el paso.
##
## `rebrota` > 0: a los `rebrota` s vuelve a salir, otra vez sin transformar. 0 = se coge una vez.
##
## SETA RESONANTE (24/10, fase 3 del Pulso; PLAN_PULSO_RESONANTE §4 «setas que maduran», docs/MATERIALES_CUEVA.md). Con `madura=si` la seta está en el grupo de lo que responde a un pulso
## (`Pulso3D.GRUPO_PULSABLE`): cada pulso que la toca la hace BRILLAR un instante (una luz azul suave y unas motas) y, si aún no estaba transformada por un elemento, la MADURA: pasa a dar
## `seta_resonante` (ingrediente común de más valor) y se queda con su tinte azul claro. Un hechizo de elemento ya no la transforma después (ya no es la seta base) ni el pulso, si antes
## la tocó un elemento (la seta asada se queda asada).
## Se coloca desde un mapa con `; pieza <id> seta <x> <y> [variante=roja|azul|marron] [rebrota=<s>] [madura=si]` (escenas/puzle.gd).

signal recogido(objeto: String)

const ALCANCE: float = 2.0              ## u: a cuánto hay que estar para cogerla con E (la jugadora mide ~1)
const VARIANTES: Dictionary = {"roja": "setas_rojas", "azul": "setas_azules", "marron": "setas_marrones"}
const ORDEN_VARIANTES: Array = ["roja", "azul", "marron"]
## Las plantas que no son setas usan una pieza del decorado que ya existe (sin arte nuevo) teñida con el color de su objeto.
const VISUAL_PLANTA: Dictionary = {"alga": "planta_agua", "basalto": "rocas_pequenas"}
const ESCALA_VISUAL: Dictionary = {"basalto": 1.5}   ## la roca suelta se lee mal a la altura de la cámara: se agranda
const CADA_CONDICION: float = 0.2      ## s entre mirada y mirada a `coge_si`
const OBJETO_MADURO: String = "seta_resonante"   ## lo que da la seta madurada por un pulso
const T_BRILLO_PULSO: float = 0.9      ## s que dura el brillo de la seta cuando le llega un pulso
const LUZ_PULSO: float = 1.1           ## energía de su luz en lo más alto del brillo
const LUZ_PULSO_ALCANCE: float = 3.0   ## u
const GESTO_AGACHARSE: String = "agacharse"   ## rol de Pj3D (clip de Meshy, ClipsFamilia): la jugadora se agacha a cogerla
const VEL_AGACHARSE: float = 1.8       ## el clip entero dura 3,5 s; a 1,8× las manos llegan al suelo a ~1 s y todo el gesto dura ~1,9 s

var celda: Vector2i = Vector2i.ZERO
var planta: String = "seta"             ## fila de `Objetos.PLANTAS`
var objeto: String = "seta"             ## lo que da al cogerla (cambia si se le lanza un elemento)
var variante: String = ""
var rebrota: float = 0.0
var recogido_ya: bool = false
## Condición para poder cogerlo (la misma expresión que `si=` de Puzle3D: `casilla(20,14).helada`). Vacía = siempre. Mientras no se cumpla NO se ve ni se coge:
## el alga aparece atrapada en el hielo y el basalto, sobre la roca recién enfriada; si la condición se pierde (el hielo se funde, la lava vuelve) desaparece.
var coge_si: Array = []
var puzle: Object = null                ## el Puzle3D que sabe evaluar `coge_si` (cumple_expr)
var madura: bool = false                ## `madura=si`: responde a un pulso (brilla y, sin transformar, pasa a seta resonante)
var maduraciones: int = 0               ## pulsos que la han hecho madurar (las pruebas)
var pulsos_recibidos: int = 0           ## pulsos que la han tocado (las pruebas)
var brillo: float = 0.0                 ## 1 al llegar un pulso, baja a 0 en T_BRILLO_PULSO
var disponible: bool = true
var _mundo: Node = null
var _visual: Node3D = null
var _t: float = 0.0
var _t_cond: float = 0.0
var _rebrotando: bool = false
var _cogiendo: bool = false             ## la jugadora ya se agacha a cogerla (otra E no lo repite)
var _luz: OmniLight3D = null            ## la luz azul de cuando le llega un pulso (se crea la primera vez)


## `p_variante` vacío = la que toque por casilla (intercaladas). `mundo` = la maqueta (pone el modelo con su escala de `Pieza3D.MEDIDA`).
func preparar(p_celda: Vector2i, p_variante: String = "", p_rebrota: float = 0.0, mundo: Node = null, p_planta: String = "seta") -> void:
	celda = p_celda
	planta = p_planta
	objeto = String((Objetos.PLANTAS.get(planta, {}) as Dictionary).get("base", planta))
	variante = p_variante if VARIANTES.has(p_variante) else String(ORDEN_VARIANTES[absi(celda.x * 7 + celda.y * 13) % ORDEN_VARIANTES.size()])
	rebrota = p_rebrota
	_mundo = mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda))


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	add_to_group("recolectable")
	if madura:
		add_to_group(Pulso3D.GRUPO_PULSABLE)
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.45
	forma.shape = esfera
	forma.position = Vector3(0.0, 0.3, 0.0)
	add_child(forma)
	disponible = coge_si.is_empty()
	_poner_visual()
	_aplicar_disponible()
	set_process(not coge_si.is_empty())


func _poner_visual() -> void:
	var id: String = String(VISUAL_PLANTA.get(planta, VARIANTES[variante]))
	var n: Node3D = null
	if _mundo != null and is_instance_valid(_mundo) and _mundo.has_method("_pieza"):
		n = _mundo.call("_pieza", id) as Node3D
	if n == null:
		var escena: PackedScene = load("res://arte/piezas/%s.tscn" % id) as PackedScene
		if escena != null:
			n = escena.instantiate() as Node3D
	if n == null:
		return
	n.name = "visual"
	n.rotation.y = deg_to_rad(float(absi(celda.x * 31 + celda.y * 17) % 360))
	add_child(n)
	_visual = n
	if VISUAL_PLANTA.has(planta):
		Paleta3D.tintar(n, Objetos.color(objeto))
		n.scale *= float(ESCALA_VISUAL.get(planta, 1.0))
	n.visible = disponible and not recogido_ya


## ¿Se cumple la condición ahora? Sin `coge_si` siempre; con ella y sin puzle que la evalúe, nunca.
func puede_cogerse() -> bool:
	if coge_si.is_empty():
		return true
	return puzle != null and is_instance_valid(puzle) and bool(puzle.call("cumple_expr", coge_si))


## ¿Se está viendo su modelo ahora mismo? (para las pruebas y las capturas)
func visible_en_mundo() -> bool:
	return _visual != null and _visual.visible


## Muestra u oculta la planta según `disponible` (y la deja o no a tiro de los hechizos).
func _aplicar_disponible() -> void:
	if _visual != null:
		_visual.visible = disponible and not recogido_ya
	collision_layer = Lanzador3D.CAPA_REACTIVO if (disponible and not recogido_ya) else 0


## --- Contrato con los hechizos ---

func on_spell_hit(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	if not spell_reacts(rune_data):
		return
	var nuevo: String = String(_tabla()[Objetos.elemento_de(rune_data)])
	objeto = nuevo
	var c: Color = (Objetos.DATOS.get(nuevo, {}) as Dictionary).get("color", Color.WHITE)
	if _visual != null:
		Paleta3D.tintar(_visual, c)
	if get_parent() is Node3D:
		VfxKit3D.oro_motas(get_parent() as Node3D, global_position + Vector3(0.0, 0.4, 0.0), 8, 0.8, 0.1, 1.0, false, false, 0.2, Vector3.UP, 70.0)
	Sfx.play(self, "sello_ok")


## Reacciona si aún está sin transformar y su planta tiene algo para ese elemento.
func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	if rune_data == null or recogido_ya or not disponible:
		return false
	var base: String = String((Objetos.PLANTAS.get(planta, {}) as Dictionary).get("base", planta))
	return objeto == base and _tabla().has(Objetos.elemento_de(rune_data))


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 0


## --- Contrato con el pulso (solo con `madura=si`) ---

## Le llega el frente de un pulso (`Pulso3D._avisar`): brilla y, si sigue siendo la seta base, madura a seta resonante. Devuelve true si maduró.
func on_pulso(pulso: Pulso3D) -> bool:
	if not madura or recogido_ya or not disponible or pulso == null:
		return false
	pulsos_recibidos += 1
	var maduro_ahora: bool = false
	if objeto == String((Objetos.PLANTAS.get(planta, {}) as Dictionary).get("base", planta)):
		maduro_ahora = true
		maduraciones += 1
		objeto = OBJETO_MADURO
		if _visual != null:
			Paleta3D.tintar(_visual, Objetos.color(OBJETO_MADURO))
	if is_inside_tree():
		if get_parent() is Node3D:
			VfxCalidad3D.motas(get_parent() as Node3D, global_position + Vector3(0.0, 0.45, 0.0), Pulso3D.COLOR_BASE, 14 if maduro_ahora else 6, 0.9, 0.07, 1.0, 0.2)
		Sfx.play(self, Pulso3D.SFX_PULSO, 1.25 if maduro_ahora else 1.05)
	_encender_brillo()
	return maduro_ahora


func _encender_brillo() -> void:
	brillo = 1.0
	if _luz == null:
		_luz = OmniLight3D.new()
		_luz.name = "luz_pulso"
		_luz.light_color = Pulso3D.COLOR_BASE
		_luz.omni_range = LUZ_PULSO_ALCANCE
		_luz.shadow_enabled = false
		_luz.position = Vector3(0.0, 0.6, 0.0)
		add_child(_luz)
	_luz.light_energy = LUZ_PULSO
	set_process(true)


func _tabla() -> Dictionary:
	return (Objetos.PLANTAS.get(planta, {}) as Dictionary).get("tabla", {})


## --- Cogerla ---

func _unhandled_input(ev: InputEvent) -> void:
	if recogido_ya or not disponible or not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_E:
		return
	var pj: Vector3 = _pos_jugador()
	if pj == Vector3.INF:
		return
	# Con varias a mano solo la más cercana responde (cada una recibe la tecla).
	var mia: float = _dist(pj, global_position)
	if mia > ALCANCE:
		return
	for o in get_tree().get_nodes_in_group("recolectable"):
		if o != self and is_instance_valid(o) and not bool(o.get("recogido_ya")) and bool(o.get("disponible")) and _dist(pj, (o as Node3D).global_position) < mia:
			return
	_coger_agachando()


## Con la tecla E la jugadora se AGACHA a cogerla (clip `agacharse`, 24/10) y la planta pasa a la mochila en el fondo de la agachada (Pj3D.instante_clip). Si no se puede agachar
## (no hay jugadora, está ocupada o nadando) se coge ya, como antes. `recoger()` sigue siendo instantáneo: lo usan las pruebas y las reglas del mapa.
func _coger_agachando() -> void:
	if _cogiendo:
		return
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	var j: Node = lanz.get("jugador") as Node if lanz != null else null
	if j != null and is_instance_valid(j) and j.has_method("gesto") and float(j.call("gesto", GESTO_AGACHARSE, VEL_AGACHARSE)) > 0.0:
		_cogiendo = true
		var hacia: Vector3 = global_position - (j as Node3D).global_position
		hacia.y = 0.0
		if hacia.length() > 0.01 and j.has_method("mirar_hacia"):
			j.call("mirar_hacia", hacia)
		get_tree().create_timer(Pj3D.instante_clip(GESTO_AGACHARSE) / VEL_AGACHARSE, false).timeout.connect(_al_llegar_las_manos)
		return
	recoger()


func _al_llegar_las_manos() -> void:
	_cogiendo = false
	if is_instance_valid(self) and is_inside_tree():
		recoger()


## La coge (sin mirar distancias: también la usan las pruebas y las reglas). Devuelve false si la mochila está llena o no se cumple `coge_si`.
func recoger() -> bool:
	if recogido_ya or not puede_cogerse():
		return false
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
	if Estado.i().agregar(objeto, 1) <= 0:
		if lanz != null and lanz.has_method("avisar"):
			lanz.call("avisar", "Mochila llena")
		return false
	recogido_ya = true
	collision_layer = 0
	if _visual != null:
		_visual.visible = false
	AvisoObjeto.mostrar(lanz, objeto, 1)      # común: «X (+1)»; épico: borde morado, más largo y destello
	Sfx.play(self, "logro_brillo")
	recogido.emit(objeto)
	if rebrota > 0.0:
		_t = 0.0
		_rebrotando = true
		set_process(true)
	return true


func _process(delta: float) -> void:
	if brillo > 0.0:
		brillo = maxf(brillo - delta / T_BRILLO_PULSO, 0.0)
		if _luz != null:
			_luz.light_energy = LUZ_PULSO * brillo * brillo
		if brillo <= 0.0 and coge_si.is_empty() and not _rebrotando:
			set_process(false)
	if not coge_si.is_empty():
		_t_cond += delta
		if _t_cond >= CADA_CONDICION:
			_t_cond = 0.0
			var ahora: bool = puede_cogerse()
			if ahora != disponible:
				disponible = ahora
				_aplicar_disponible()
	if not _rebrotando:
		return
	_t += delta
	if _t < rebrota:
		return
	_rebrotando = false
	set_process(not coge_si.is_empty())
	recogido_ya = false
	objeto = String((Objetos.PLANTAS.get(planta, {}) as Dictionary).get("base", planta))
	if _visual != null:
		_visual.queue_free()
		_visual = null
	_poner_visual()
	_aplicar_disponible()


func _pos_jugador() -> Vector3:
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster")
	var j: Node3D = lanz.get("jugador") as Node3D if lanz != null else null
	return j.global_position if j != null else Vector3.INF


func _dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
