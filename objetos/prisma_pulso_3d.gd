class_name PrismaPulso3D
extends Area3D

## PRISMA (23/10, FASE 2 del Pulso resonante; docs/PLAN_PULSO_RESONANTE.md §4 y §5): MODIFICADOR de dirección. Un prisma orientable que, cuando le llega un pulso, lo REEMITE desde la casilla
## que mira (`dir`: n | e | s | o, norte = −y del mapa) con el mismo elemento, el mismo dueño (del escenario o del jugador) y el alcance que le quedaba. Es lo que lleva el pulso por una esquina o lo
## desvía hacia otra veta: el prisma no es un conductor (bloquea su casilla), así que el pulso que llega se queda en él, y el que sale es otro `Pulso3D` que NO vuelve por donde vino
## (no recorre las casillas del pulso padre) y que no puede pasar dos veces por el mismo prisma (`Pulso3D.linaje`: dos prismas enfrentados no se lo pasan para siempre).
##
## SE GIRA con un golpe de hechizo (cualquier elemento, como el cristal) o con E a ≤ `ALCANCE_GIRO` u: 90° en el sentido de las agujas del reloj (n → e → s → o → n). «Gira el pulso 90°» es eso:
## cada giro desvía la salida un cuarto de vuelta. Un puntero luminoso en el suelo marca hacia dónde sale (se lee desde la cámara cenital sin tener que fijarse en el modelo).
##
## Aspecto: el modelo `prisma_orientable` con el brillo del pulso de `BrilloPulso3D` (en reposo, un azul muy sutil) y una luz pequeña tenue si queda cupo (`reservar_luz`).
## Se coloca con `; pieza <id> prisma <x> <y> [dir=n|e|s|o]` (escenas/puzle.gd). Señal `gira(dir)` y `emite(pulso)`.

signal gira(dir: String)
signal emite(pulso: Pulso3D)

const DIRS: Dictionary = {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "o": Vector2i(-1, 0)}
const ORDEN: Array = ["n", "e", "s", "o"]                   ## el sentido de los giros (horario visto desde arriba)
const DIR_DEFECTO: String = "n"
const ALCANCE_GIRO: float = 2.7                             ## u (a E)
const ENFRIAR: float = 0.35                                 ## s mínimos entre dos giros (un hechizo continuo no lo hace dar vueltas sin parar)
const T_GIRO: float = 0.25                                  ## s que tarda el modelo en girar el cuarto de vuelta
const T_DESTELLO: float = 0.5
const ENERGIA_LUZ: float = 1.4
const ALCANCE_LUZ: float = 4.0
const ALTO_LUZ: float = 0.9
const ANCHO_CUERPO: float = 1.0
const ALTO_CUERPO: float = 1.2
const ALTO_PUNTERO: float = 0.06                            ## u sobre el suelo
const LARGO_PUNTERO: float = 0.55                           ## fracción de casilla desde el centro hasta la punta del puntero

var celda: Vector2i = Vector2i.ZERO
var dir: String = DIR_DEFECTO
var giros: int = 0                                          ## cuántas veces se ha girado (las pruebas)
var emisiones: int = 0                                      ## cuántos pulsos ha reemitido (las pruebas)
var ultimo: Pulso3D = null                                  ## el último pulso que soltó
var destello: float = 0.0
var _mundo: Node = null
var _enfriando: float = 0.0
var _modelo: Node3D = null
var _puntero: MeshInstance3D = null
var _mat_puntero: StandardMaterial3D = null
var _mats: Array[ShaderMaterial] = []
var _luz: OmniLight3D = null
var _luz_reposo: bool = false
var _suelo: MeshInstance3D = null       ## la mancha de luz azul en el suelo a su pie (BrilloPulso3D.suelo_azul)
var _color: Color = BrilloPulso3D.COLOR_REPOSO


func preparar(p_celda: Vector2i, p_dir: String = DIR_DEFECTO, mundo: Node = null) -> void:
	celda = p_celda
	dir = p_dir if DIRS.has(p_dir) else DIR_DEFECTO
	_mundo = mundo
	position = Terreno3D.centro_de(celda, Terreno3D.y_pies(celda)) if Terreno3D.hay_mundo() else Terreno3D.centro_de(celda)
	Terreno3D.bloquear_celda(celda)


func _ready() -> void:
	add_to_group(Pulso3D.GRUPO_PULSABLE)
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(ANCHO_CUERPO, ALTO_CUERPO, ANCHO_CUERPO)
	forma.shape = caja
	forma.position = Vector3(0.0, ALTO_CUERPO * 0.5, 0.0)
	add_child(forma)
	_dibujar()
	_orientar(false)
	set_process(true)


func _exit_tree() -> void:
	if _luz_reposo:
		_luz_reposo = false
		BrilloPulso3D.liberar_luz()


func _dibujar() -> void:
	var n: Node3D = BrilloPulso3D.modelo("prisma_orientable", _mundo)
	if n != null:
		n.name = "modelo"
		add_child(n)
		_modelo = n
		_mats = BrilloPulso3D.preparar(n)
	if n == null:
		var cuerpo := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = 0.1
		cil.bottom_radius = 0.36
		cil.height = ALTO_CUERPO * 0.8
		cil.radial_segments = 4
		cuerpo.mesh = cil
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.45, 0.55, 0.6)
		cuerpo.material_override = m
		cuerpo.position = Vector3(0.0, ALTO_CUERPO * 0.4, 0.0)
		add_child(cuerpo)
		_modelo = cuerpo
	# El puntero: un triángulo plano en el suelo que apunta hacia la salida.
	var tri := ArrayMesh.new()
	var lado: float = Terreno3D.casilla
	var verts := PackedVector3Array([Vector3(0.0, 0.0, -LARGO_PUNTERO * lado), Vector3(-0.16 * lado, 0.0, -0.30 * lado), Vector3(0.16 * lado, 0.0, -0.30 * lado)])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	tri.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_puntero = MeshInstance3D.new()
	_puntero.name = "puntero"
	_puntero.mesh = tri
	_mat_puntero = StandardMaterial3D.new()
	_mat_puntero.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_puntero.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_puntero.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_puntero.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_puntero.albedo_color = Color(BrilloPulso3D.COLOR_REPOSO, 0.55)
	_puntero.material_override = _mat_puntero
	_puntero.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puntero.position = Vector3(0.0, ALTO_PUNTERO, 0.0)
	add_child(_puntero)
	_luz = OmniLight3D.new()
	_luz.omni_range = ALCANCE_LUZ
	_luz.light_energy = 0.0
	_luz.shadow_enabled = false
	_luz.position = Vector3(0.0, ALTO_LUZ, 0.0)
	add_child(_luz)
	_luz_reposo = BrilloPulso3D.reservar_luz()
	_suelo = BrilloPulso3D.suelo_azul(self)
	_pintar()


## --- Contrato con los hechizos (como el cristal) ---

func on_spell_hit(_rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> void:
	girar()


func spell_reacts(_rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO) -> bool:
	return _enfriando <= 0.0


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, ALTO_LUZ, 0.0))


## --- Girar ---

## La casilla por la que sale el pulso.
func casilla_salida() -> Vector2i:
	return celda + (DIRS[dir] as Vector2i)


## Gira 90° en el sentido de las agujas del reloj. false si está en `ENFRIAR`.
func girar() -> bool:
	if _enfriando > 0.0:
		return false
	poner_dir(String(ORDEN[(ORDEN.find(dir) + 1) % ORDEN.size()]), true)
	return true


func poner_dir(nueva: String, animar: bool = false) -> void:
	if not DIRS.has(nueva):
		return
	_enfriando = ENFRIAR
	dir = nueva
	giros += 1
	_orientar(animar)
	destello = 0.6
	_color = BrilloPulso3D.COLOR_REPOSO
	_pintar()
	if is_inside_tree() and Terreno3D.hay_mundo():
		Sfx.play(self, Pulso3D.SFX_PULSO, 0.6)
	gira.emit(dir)


## El ángulo (rad) del modelo para la dirección: n = 0, e = −90°, s = 180°, o = 90° (giro horario visto desde arriba).
static func angulo_de(d: String) -> float:
	return -float(ORDEN.find(d)) * PI * 0.5


func _orientar(animar: bool) -> void:
	var a: float = angulo_de(dir)
	if _modelo != null:
		if animar and is_inside_tree():
			var tw: Tween = _modelo.create_tween()
			tw.tween_property(_modelo, "rotation:y", _alcanzar_angulo(_modelo.rotation.y, a), T_GIRO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_modelo.rotation.y = a
	if _puntero != null:
		_puntero.rotation.y = a


## Gira siempre en el mismo sentido (horario): si el destino queda "detrás" lo lleva una vuelta más allá en vez de desandar tres cuartos.
static func _alcanzar_angulo(actual: float, destino: float) -> float:
	var d: float = fposmod(destino - actual + PI, TAU) - PI
	if d > 0.0:
		d -= TAU
	return actual + d


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey):
		return
	var k: InputEventKey = ev as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_E:
		return
	var j: Node3D = Puzle3D.jugador_nodo(get_tree(), _mundo)
	if j == null:
		return
	var d: Vector3 = j.global_position - global_position
	d.y = 0.0
	if d.length() <= ALCANCE_GIRO and girar():
		get_viewport().set_input_as_handled()


## --- El pulso ---

## Le llega un pulso: lo reemite por la casilla que mira. Devuelve el pulso nuevo (null si no lo reemite: ya pasó por este prisma o no hay mundo donde ponerlo).
func on_pulso(pulso: Pulso3D) -> Pulso3D:
	if pulso == null or pulso.linaje.has(self) or not is_inside_tree():
		return null
	var padre: Pulso3D = pulso
	var f: Callable = func(c: Vector2i) -> bool: return Pulso3D.conduce_pulso(c) and not padre.alcanzadas.has(c)
	var linaje: Array = pulso.linaje.duplicate()
	linaje.append(self)
	var cont: Node = pulso.get_parent() if pulso.get_parent() != null else self
	ultimo = Pulso3D.emitir(cont, [casilla_salida()], pulso.elemento, pulso.alcance_restante(), self, f, pulso.del_jugador, linaje)
	emisiones += 1
	destello = 1.0
	_color = pulso.color
	_pintar()
	if Terreno3D.hay_mundo():
		Pulso3D.anillo(self, global_position, pulso.color)
	emite.emit(ultimo)
	return ultimo


func _process(delta: float) -> void:
	if _enfriando > 0.0:
		_enfriando = maxf(_enfriando - delta, 0.0)
	if destello > 0.0:
		destello = maxf(destello - delta / T_DESTELLO, 0.0)
		_pintar()


func _pintar() -> void:
	var e: float = destello * destello
	BrilloPulso3D.poner(_mats, _color, BrilloPulso3D.ENERGIA_MAX * e)
	if _mat_puntero != null:
		_mat_puntero.albedo_color = Color(BrilloPulso3D.COLOR_REPOSO.lerp(_color, e), 0.55 + 0.45 * e)
	if _luz != null:
		var reposo: float = BrilloPulso3D.LUZ_REPOSO_ENERGIA if _luz_reposo else 0.0
		_luz.light_color = BrilloPulso3D.COLOR_REPOSO.lerp(_color, e)
		_luz.light_energy = reposo + ENERGIA_LUZ * e
		if _luz_reposo:
			_luz.omni_range = maxf(ALCANCE_LUZ, BrilloPulso3D.LUZ_REPOSO_ALCANCE)
	BrilloPulso3D.pintar_suelo(_suelo, BrilloPulso3D.COLOR_REPOSO.lerp(_color, e), e)
