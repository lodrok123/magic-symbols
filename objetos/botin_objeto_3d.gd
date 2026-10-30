class_name BotinObjeto3D
extends Node3D

## OBJETO SUELTO EN EL SUELO (F1 de docs/PLAN_BASE_DATOS.md, 29/10): la pieza que crea `Botin.soltar` para todo lo que no es oro. Se porta como la moneda (`Combate3D.Botin3D`, gamefeel
## lote 2): al soltarse SALTA desde el cuerpo hasta su sitio, ya en el suelo flota y gira, y si ella pasa cerca se IMANTA, vuela hacia ella y se mete en la bolsa al llegar. La diferencia es
## que lleva un `objeto` (id de `Objetos.DATOS`) y una `cantidad`.
##
## ASPECTO. Si `BD.objeto(id).modelo` nombra una pieza que existe (`res://arte/piezas/<modelo>.tscn`, la misma convención que `Recolectable3D`, `Rompible3D`, `Cofre`…) se enseña esa pieza reducida
## a ~TAMANO_MODELO u; si no hay pieza, una ESFERA pequeña del color del objeto con un aro del color de su calidad (`Objetos.CALIDADES`). Cuando el Pipeline dibuje las piezas que faltan
## (panal, pluma, seda, colmillo…) el objeto las usará solo, sin tocar código.
##
## BOLSA LLENA. Si `Estado.agregar` no mete nada, la pieza se queda en el suelo (ya no se pierde), deja de imantarse y avisa UNA vez «La bolsa está llena»; se vuelve a intentar al pasar de
## nuevo cerca (no antes de REINTENTO s) y también cuando la bolsa cambia (se tira algo, se gasta algo): `Estado.cambiado`.
##
## Con `Sensacion3D.ACTIVA` = false (las pruebas antiguas, sin gamefeel) aparece en su sitio y se coge a menos de RADIO_COGER, sin imán.

const T_SALTO: float = 0.42          ## s del arco desde el cuerpo hasta donde se queda
const ALTO_SALTO: float = 0.9        ## u que sube el arco
const RADIO_IMAN: float = 2.4        ## u (en el plano) a las que empieza a ir hacia ella
const ACEL_IMAN: float = 40.0
const VEL_IMAN_MAX: float = 14.0
const RADIO_COGER: float = 1.1       ## u a las que se coge sin imán
const RADIO_LLEGA: float = 0.45      ## u a las que se coge cuando viene imantada
const ALTURA: float = 0.35           ## u sobre el suelo a la que flota
const TAMANO_MODELO: float = 0.4     ## u: lado mayor de la pieza cuando se enseña un modelo
const RADIO_ESFERA: float = 0.11
const REINTENTO: float = 2.0         ## s entre dos intentos de cogerla con la bolsa llena
const TXT_LLENA: String = "La bolsa está llena"

var jugador: Jugador3D = null
var objeto: String = ""
var cantidad: int = 1
var recogido: bool = false
var imantado: bool = false
var llena_avisada: bool = false      ## ya avisó de «bolsa llena» (una sola vez por pieza)
var con_modelo: bool = false         ## true = enseña la pieza del objeto; false = la esfera con el aro de calidad
var _t: float = 0.0
var _base_y: float = 0.0
var _t_salto: float = -1.0           ## < 0 = ya en su sitio
var _desde: Vector3 = Vector3.ZERO
var _hasta: Vector3 = Vector3.ZERO
var _vel: float = 0.0
var _espera: float = 0.0             ## s hasta poder reintentar tras fallar por bolsa llena
var _visual: Node3D = null


## Crea la pieza en `p_mundo` y la devuelve (null si no hay mundo). `pos` = donde cae el botín (los pies de quien lo suelta).
static func soltar(p_mundo: Node3D, p_jugador: Jugador3D, id: String, n: int, pos: Vector3) -> BotinObjeto3D:
	if p_mundo == null:
		return null
	var b := BotinObjeto3D.new()
	b.jugador = p_jugador
	b.objeto = id
	b.cantidad = n
	b.name = "Botin_" + id
	b._hasta = pos + Vector3(randf_range(-0.4, 0.4), ALTURA, randf_range(0.2, 0.6))
	b._base_y = b._hasta.y
	if Sensacion3D.ACTIVA:
		b._desde = pos + Vector3(0.0, 0.6, 0.0)
		b._t_salto = 0.0
		b.position = b._desde
	else:
		b.position = b._hasta
	p_mundo.add_child(b)
	return b


func _ready() -> void:
	_poner_visual()
	if not Estado.i().cambiado.is_connected(_al_cambiar_bolsa):
		Estado.i().cambiado.connect(_al_cambiar_bolsa)


func _exit_tree() -> void:
	if Estado.i().cambiado.is_connected(_al_cambiar_bolsa):
		Estado.i().cambiado.disconnect(_al_cambiar_bolsa)


## La ruta de la pieza de un objeto, o "" si su fila no nombra ninguna o el archivo no existe.
static func ruta_modelo(id: String) -> String:
	var m: String = String(BD.objeto(id).get("modelo", ""))
	if m == "":
		return ""
	var ruta: String = "res://arte/piezas/%s.tscn" % m
	return ruta if ResourceLoader.exists(ruta) else ""


func _poner_visual() -> void:
	var ruta: String = ruta_modelo(objeto)
	if ruta != "":
		var esc: PackedScene = load(ruta) as PackedScene
		var n: Node3D = esc.instantiate() as Node3D if esc != null else null
		if n != null:
			var raiz := Node3D.new()
			raiz.name = "modelo"
			raiz.add_child(n)
			var lado: float = _lado_mayor(n)
			if lado > 0.001:
				raiz.scale = Vector3.ONE * (TAMANO_MODELO / lado)
			add_child(raiz)
			_visual = raiz
			con_modelo = true
			return
	var raiz2 := Node3D.new()
	raiz2.name = "esfera"
	var esfera := SphereMesh.new()
	esfera.radius = RADIO_ESFERA
	esfera.height = RADIO_ESFERA * 2.0
	esfera.radial_segments = 12
	esfera.rings = 6
	var col: Color = Objetos.color(objeto)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.5
	m.roughness = 0.4
	esfera.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = esfera
	raiz2.add_child(mi)
	# El aro de la calidad (común gris, épico morado, legendario dorado): lo mismo que el marco del icono, para que el color mande también en el suelo.
	var cal: Color = Objetos.color_calidad(objeto)
	var aro := TorusMesh.new()
	aro.inner_radius = RADIO_ESFERA * 1.25
	aro.outer_radius = RADIO_ESFERA * 1.6
	aro.rings = 16
	aro.ring_segments = 6
	var ma := StandardMaterial3D.new()
	ma.albedo_color = cal
	ma.emission_enabled = true
	ma.emission = cal
	ma.emission_energy_multiplier = 0.8
	ma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aro.material = ma
	var mia := MeshInstance3D.new()
	mia.name = "aro_calidad"
	mia.mesh = aro
	raiz2.add_child(mia)
	add_child(raiz2)
	_visual = raiz2


## Lado mayor (u) de la caja que envuelve todas las mallas de `n`, en el espacio de `n`. 0 si no tiene mallas.
static func _lado_mayor(n: Node3D) -> float:
	var caja: AABB = AABB()
	var primero: bool = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		var tr: Transform3D = Transform3D.IDENTITY
		var p: Node = m
		while p != null and p != n.get_parent():
			if p is Node3D:
				tr = (p as Node3D).transform * tr
			p = p.get_parent()
		var a: AABB = tr * m.mesh.get_aabb()
		caja = a if primero else caja.merge(a)
		primero = false
	return 0.0 if primero else maxf(caja.size.x, maxf(caja.size.y, caja.size.z))


## ¿Está todavía saltando hacia su sitio? (las pruebas lo leen)
func saltando() -> bool:
	return _t_salto >= 0.0


func _process(delta: float) -> void:
	if recogido:
		return
	_t += delta
	_espera = maxf(_espera - delta, 0.0)
	if _visual != null:
		_visual.rotate_y(delta * (2.0 if not imantado else 9.0))
	if _t_salto >= 0.0:
		_t_salto += delta
		var u: float = clampf(_t_salto / T_SALTO, 0.0, 1.0)
		var plano: Vector3 = _desde.lerp(_hasta, u)
		var arco: float = 4.0 * ALTO_SALTO * u * (1.0 - u)
		var bote: float = absf(sin(clampf((_t_salto - T_SALTO) / 0.18, 0.0, 1.0) * PI)) * 0.12
		position = Vector3(plano.x, lerpf(_desde.y, _base_y, u) + arco + bote, plano.z)
		if _t_salto >= T_SALTO + 0.18 or (_t_salto >= T_SALTO and _cerca_para_iman()):
			_t_salto = -1.0
			_t = 0.0
		return
	if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		position.y = _base_y + sin(_t * 3.0) * 0.06
		return
	var hacia: Vector3 = jugador.position + Vector3(0.0, 0.8, 0.0) - position
	var d: float = Vector2(hacia.x, hacia.z).length()
	var misma_altura: bool = absf(jugador.position.y + ALTURA - _base_y) < 1.4
	var puede: bool = _espera <= 0.0
	if Sensacion3D.ACTIVA and puede and misma_altura and (imantado or d < RADIO_IMAN):
		imantado = true
		_vel = minf(VEL_IMAN_MAX, _vel + ACEL_IMAN * delta)
		var paso: float = minf(_vel * delta, hacia.length())
		position += hacia.normalized() * paso
		if hacia.length() - paso <= RADIO_LLEGA:
			recoger()
		return
	position.y = _base_y + sin(_t * 3.0) * 0.06
	if puede and d < RADIO_COGER and misma_altura:
		recoger()


func _cerca_para_iman() -> bool:
	if jugador == null or not is_instance_valid(jugador) or jugador.muerto:
		return false
	return Vector2(jugador.position.x - position.x, jugador.position.z - position.z).length() < RADIO_IMAN


## Lo mete en la bolsa con el aviso de su calidad. Devuelve false si no cabe NADA: entonces se queda en el suelo y avisa una sola vez. Si cabe solo una parte, mete esa y se queda con el resto.
func recoger() -> bool:
	if recogido:
		return false
	var lanz: Node = get_tree().get_first_node_in_group("spellcaster") if is_inside_tree() else null
	var entra: int = Estado.i().agregar(objeto, cantidad)
	if entra <= 0:
		imantado = false
		_vel = 0.0
		_espera = REINTENTO
		if not llena_avisada:
			llena_avisada = true
			if lanz != null and lanz.has_method("avisar"):
				lanz.call("avisar", TXT_LLENA, Color(1.0, 0.75, 0.5))
		return false
	AvisoObjeto.mostrar(lanz, objeto, entra)
	PlayLog.event("objeto_suelo", {"objeto": objeto, "n": entra})
	if is_inside_tree() and Sensacion3D.ACTIVA:
		Sfx.play(self, "logro_brillo")
	cantidad -= entra
	if cantidad > 0:
		imantado = false
		_vel = 0.0
		_espera = REINTENTO
		return true                      # una parte entró; el resto espera a que haya sitio
	recogido = true
	queue_free()
	return true


## La bolsa cambió (algo se gastó o se tiró): si estaba esperando sitio, que pueda volver a intentarlo ya.
func _al_cambiar_bolsa() -> void:
	if llena_avisada:
		_espera = 0.0
