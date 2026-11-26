class_name Molino3D
extends Area3D

## MOLINO DE AGUA (15/10, Juego; referencia de Pablo: la rueda de TotK que gira con el agua y «al impactar en el molino este gira
## habilitando un mecanismo»). Una rueda de palas sobre una casilla de agua (canal, cauce o río). Giro REALISTA (23/11, Pablo: «revisa el
## movimiento del molino para que sea realista en el giro»); antes era todo o nada (VEL_MAX si la corriente pasaba del umbral, si no 0):
##   · VELOCIDAD PROPORCIONAL A LA CORRIENTE: la rueda busca ω_obj = (componente de la corriente en el plano de la rueda) / RADIO × EFICIENCIA,
##     con tope VEL_MAX y 0 por debajo de ROZ_ESTATICO u/s (el rozamiento de los cojinetes). Con medio caudal se arrastra; con todo gira con brío.
##   · SENTIDO: las palas de abajo (las que están dentro del agua) van CON el agua. Deducción con `rotate_object_local(RIGHT, ω)` (NO `rotate_x`, que gira alrededor del X del padre y con la rueda girada 90° en Y la hacía girar de lado: error de la versión anterior) (rotación a derechas
##     alrededor del eje X local; la velocidad de un punto es ω · (eje × r)): el punto de abajo es r = (0,−R,0). Con `vertical=si` el eje X local es el
##     X del mundo (1,0,0) y (1,0,0)×(0,−R,0) = (0,0,−R): ω > 0 lleva las palas de abajo hacia −Z. Con `vertical=no` la rueda va girada 90° en Y y su X local
##     es (0,0,−1): (0,0,−1)×(0,−R,0) = (−R,0,0): ω > 0 las lleva hacia −X. Por eso ω_obj = corriente · dir_abajo() (−Z o −X) / R × EFICIENCIA; el signo sale solo
##     de la corriente, y escenario_molino_giro lo comprueba con la transformada real de la rueda, no con esta cuenta.
##   · INERCIA: dω/dt = (ω_obj − ω)/TAU; TAU_AGUA con agua, TAU_SECO sin ella (y además un rozamiento constante que la acaba parando). Sin saltos.
##   · LA RUEDA SE MOJA: el eje se coloca para que la PUNTA de las palas quede PUNTA_SOBRE_FONDO sobre el fondo de su casilla (cauce hondo, canal de ruinas,
##     río `~`; el suelo si es una casilla seca). Los postes van de la orilla (el suelo a los lados) al eje. Si el foso es más hondo que la rueda no se escala:
##     el eje queda por debajo de la orilla y la rueda asoma por encima de ella lo que le sobre.
## `girando(si)` es el DISPARADOR del mecanismo: activo cuando |ω del agua| pasa de la velocidad que daría la corriente `umbral` (ω_umbral = umbral/RADIO × EFICIENCIA)
## y se suelta por debajo del 80 % de ella (histéresis: no parpadea). Así `umbral` sigue significando lo que significaba para los mapas que ya lo usan.
## HECHIZO DE AGUA (clave `hechizo=si|no`, si): el chorro la empuja `T_IMPULSO` s en el sentido de su dirección proyectada en el plano de la rueda (así se activa sin
## arroyo, de un golpe, y luego se frena con la misma inercia). Con `hechizo=no` el golpe es solo un empujón visible y corto (EMPUJON, se frena solo) que NUNCA cuenta para
## `girando`: el mecanismo lo mueve únicamente el agua del cauce.
## `velocidad` es la velocidad angular actual (rad/s, con signo), por si el mecanismo quiere ir a su ritmo.
## Se dibuja solo (eje + rueda de palas que gira de verdad): el modelo bueno lo pondrá el Pipeline encima con `visual`.

signal girando(si: bool)

const T_IMPULSO: float = 6.0            ## s que gira tras un hechizo de agua (con `hechizo=si`)
const VEL_MAX: float = 3.0              ## rad/s: tope de la rueda y velocidad a la que la lleva un hechizo de agua
const EFICIENCIA: float = 0.8           ## la rueda no coge toda la velocidad del agua (las palas resbalan, el agua sale)
const ROZ_ESTATICO: float = 0.05        ## u/s de corriente (en el plano de la rueda) por debajo de los cuales no se mueve
const TAU_AGUA: float = 1.2             ## s: constante de tiempo de la rueda con agua que la mueve
const TAU_SECO: float = 2.5             ## s: sin agua frena más despacio (solo el rozamiento del eje)
const ROZ_EJE: float = 0.06             ## rad/s² de rozamiento constante al frenar: con la exponencial sola no llegaría a pararse
const EMPUJON: float = 2.0              ## rad/s que da un golpe de agua cuando `hechizo=no`
const TAU_EMPUJON: float = 1.0          ## s que tarda en apagarse ese empujón
const HISTERESIS: float = 0.8           ## `girando` se suelta por debajo de este tanto de ω_umbral
const PUNTA_SOBRE_FONDO: float = 0.1    ## u: la punta de las palas queda así sobre el fondo de su casilla
const RADIO: float = 0.75
const PALAS: int = 8

var celda: Vector2i = Vector2i.ZERO
var umbral: float = 0.3                 ## u/s de corriente a partir de la cual gira
var vertical: bool = true               ## el eje cruza la casilla de este a oeste (la rueda mira al norte-sur: agua que corre N-S)
var hechizo: bool = true                ## ¿lo mueve el chorro de un hechizo de agua como una corriente (T_IMPULSO s)? No: solo un empujón que no cuenta para `girando`
var velocidad: float = 0.0              ## ω total (rad/s, con signo)
var activo: bool = false
var fondo: float = 0.0                  ## y (mundo) del fondo de la casilla bajo la rueda, calculado al preparar
var _cy: float = RADIO * 1.1            ## y local del eje sobre el suelo de la casilla (se recalcula en preparar)
var _t_impulso: float = 0.0
var _signo_impulso: float = 1.0
var _w_agua: float = 0.0                ## la parte de ω que viene del agua (corriente y chorro sostenido): la que cuenta para `girando`
var _w_golpe: float = 0.0               ## el empujón de un golpe con `hechizo=no`: no cuenta
var _rueda: Node3D = null


func preparar(p_celda: Vector2i, p_umbral: float = 0.3, p_vertical: bool = true) -> void:
	celda = p_celda
	umbral = p_umbral
	vertical = p_vertical
	position = Terreno3D.centro_de(celda, Terreno3D.alto_suelo)
	fondo = _fondo_de(celda)
	# El eje sobre el fondo: la punta (RADIO bajo el eje) a PUNTA_SOBRE_FONDO sobre él. En suelo seco da casi el RADIO×1,1 de siempre.
	_cy = fondo + PUNTA_SOBRE_FONDO + RADIO - Terreno3D.alto_suelo


## y del fondo de la casilla bajo la rueda: el cajón del canal de ruinas, el lecho del río `~` o del cauce hondo (foso), y el suelo en una casilla seca.
static func _fondo_de(c: Vector2i) -> float:
	if not Terreno3D.hay_mundo():
		return Terreno3D.alto_suelo
	if Terreno3D.es_canal_ruinas(c):
		return Terreno3D.fondo_canal_en(c)
	if Terreno3D.letra_de(c) == "~":
		return Terreno3D.alto_agua - Terreno3D.LECHO_AGUA
	if Terreno3D.es_hueco_cauce(c):
		return Terreno3D.fondo_cauce()
	return Terreno3D.alto_suelo


## Hacia dónde (X, Z del mundo) van las palas de abajo con ω > 0: ver la deducción de la cabecera.
func dir_abajo() -> Vector2:
	return Vector2(0.0, -1.0) if vertical else Vector2(-1.0, 0.0)


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_mask = 0
	collision_layer = Lanzador3D.CAPA_REACTIVO
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(RADIO * 2.2, RADIO * 2.4, RADIO * 2.2)
	forma.shape = caja
	forma.position = Vector3(0.0, _cy, 0.0)
	add_child(forma)
	_dibujar()
	set_physics_process(true)


func _dibujar() -> void:
	_rueda = Node3D.new()
	_rueda.position = Vector3(0.0, _cy, 0.0)
	if not vertical:
		_rueda.rotation.y = PI * 0.5
	add_child(_rueda)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.36, 0.2)
	var eje := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.08
	cil.bottom_radius = 0.08
	cil.height = Terreno3D.casilla * 0.9
	eje.mesh = cil
	eje.rotation.z = PI * 0.5               # el eje tumbado, de este a oeste
	eje.material_override = mat
	_rueda.add_child(eje)
	for k in range(PALAS):
		var pala := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.06, RADIO, 0.6)
		pala.mesh = b
		var brazo := Node3D.new()
		brazo.rotation.x = float(k) * TAU / float(PALAS)
		pala.position = Vector3(0.0, RADIO * 0.5, 0.0)
		pala.material_override = mat
		brazo.add_child(pala)
		_rueda.add_child(brazo)
	# Dos postes que sostienen el eje: de la orilla (el suelo, y local 0) al eje. Si el eje queda por debajo de la orilla (foso), el poste sube desde el
	# eje hasta un poco por encima de la orilla (la horquilla del cojinete); si queda por encima, baja hasta la orilla.
	var y0: float = minf(0.0, _cy - 0.1)
	var y1: float = maxf(_cy + 0.1, 0.25)
	var yc: float = (y0 + y1) * 0.5
	for lado in [-1.0, 1.0]:
		var poste := MeshInstance3D.new()
		var p := BoxMesh.new()
		p.size = Vector3(0.12, y1 - y0, 0.12)
		poste.mesh = p
		poste.position = Vector3(lado * Terreno3D.casilla * 0.42, yc, 0.0) if vertical else Vector3(0.0, yc, lado * Terreno3D.casilla * 0.42)
		poste.material_override = mat
		add_child(poste)


## --- Contrato con los hechizos: solo el agua la empuja ---

func on_spell_hit(rune_data: RuneData, direccion: Vector3 = Vector3.ZERO, hechizo_lanzado: Hechizo = null) -> void:
	if rune_data == null or not Materia.riega(Materia.de(hechizo_lanzado if hechizo_lanzado != null else rune_data)):
		return
	# Sentido: el de la dirección del chorro proyectada en el plano de la rueda (las palas de abajo van con el chorro). Sin componente, +1.
	var d := Vector2(direccion.x, direccion.z)
	var en_plano: float = d.dot(dir_abajo())
	var s: float = 1.0 if (d.length() < 0.001 or absf(en_plano) < 0.1 * d.length()) else signf(en_plano)
	if hechizo:
		_t_impulso = T_IMPULSO
		_signo_impulso = s
	else:
		_w_golpe = s * EMPUJON


func spell_reacts(rune_data: RuneData, _direccion: Vector3 = Vector3.ZERO, hechizo_lanzado: Hechizo = null) -> bool:
	return rune_data != null and Materia.riega(Materia.de(hechizo_lanzado if hechizo_lanzado != null else rune_data))


func carried_element() -> RuneData:
	return null


func nivel_altura() -> int:
	return 1


func punto_activacion() -> Vector3:
	return to_global(Vector3(0.0, _cy, 0.0))


## y (mundo) de la punta más baja de las palas.
func punta_y() -> float:
	return to_global(Vector3(0.0, _cy - RADIO, 0.0)).y


## La rueda (el nodo que gira), para quien quiera medir su transformada.
func rueda() -> Node3D:
	return _rueda


## Corriente bajo la rueda (X, Z; u/s), 0 sin simulación.
func flujo() -> Vector2:
	var sim: AguaSim3D = Terreno3D.agua_sim
	if sim == null:
		return Vector2.ZERO
	return sim.corriente_en(Terreno3D.centro_de(celda, 0.0))


## Corriente bajo la rueda (u/s, módulo), 0 sin simulación.
func corriente() -> float:
	return flujo().length()


## ω a la que llevaría la rueda una corriente de `v_plano` u/s a lo largo del plano de la rueda (con tope y rozamiento estático).
static func omega_de(v_plano: float) -> float:
	if absf(v_plano) < ROZ_ESTATICO:
		return 0.0
	return clampf(v_plano / RADIO * EFICIENCIA, -VEL_MAX, VEL_MAX)


## ω a partir de la cual el mecanismo da la rueda por girando: la que daría una corriente `umbral`.
func omega_umbral() -> float:
	return maxf(umbral / RADIO * EFICIENCIA, 0.01)


func _physics_process(delta: float) -> void:
	_t_impulso = maxf(_t_impulso - delta, 0.0)
	var w_obj: float = omega_de(flujo().dot(dir_abajo()))
	if hechizo and _t_impulso > 0.0:
		w_obj = _signo_impulso * VEL_MAX
	if w_obj != 0.0:
		_w_agua += (w_obj - _w_agua) * (1.0 - exp(-delta / TAU_AGUA))
	else:
		_w_agua -= _w_agua * (1.0 - exp(-delta / TAU_SECO))
		_w_agua = move_toward(_w_agua, 0.0, ROZ_EJE * delta)
		if absf(_w_agua) < 0.01:
			_w_agua = 0.0
	# El empujón de un golpe sin `hechizo`: se apaga solo.
	if _w_golpe != 0.0:
		_w_golpe -= _w_golpe * (1.0 - exp(-delta / TAU_EMPUJON))
		_w_golpe = move_toward(_w_golpe, 0.0, ROZ_EJE * delta)
		if absf(_w_golpe) < 0.01:
			_w_golpe = 0.0
	velocidad = clampf(_w_agua + _w_golpe, -VEL_MAX, VEL_MAX)
	if _rueda != null:
		_rueda.rotate_object_local(Vector3.RIGHT, velocidad * delta)   # alrededor del eje X LOCAL de la rueda (rotate_x gira alrededor del X del PADRE: con la rueda girada 90° en Y la haría girar de lado)
	var w_um: float = omega_umbral()
	var ahora: bool = absf(_w_agua) > (w_um * HISTERESIS if activo else w_um)
	if ahora != activo:
		activo = ahora
		girando.emit(activo)
