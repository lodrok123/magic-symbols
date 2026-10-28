class_name PiezaApoyada3D
extends Node

## PIEZA APOYADA EN EL SUELO Y VERTICAL (bastón de Marimanta, 23/10). Modo de Equipo3D para una pieza larga que el personaje «agarra» pero que NO cuelga rígida de la mano:
## cada vez que el esqueleto termina de colocar los huesos (`skeleton_updated`, o sea, ya con la pose de la animación) la pieza se pone en espacio de MUNDO así:
##   · el pie (origen de la pieza) en el suelo del personaje (la y de su nodo raíz: vale en terrazas), en la proyección horizontal del punto de agarre de la mano;
##   · el eje vertical, con una inclinación pequeña (INCLINACION_MAX) hacia la mano solo si el pie no puede quedar bajo ella (por la distancia mínima al cuerpo);
##   · el giro sobre su eje, el del personaje más `giro`;
##   · sin escalar: mide lo que mide la pieza colgada del hueso.
## Si la mano se aleja (distancia horizontal > DISTANCIA_SUELTA, o por encima de la punta / por debajo de ALTURA_MIN_AGARRE) el bastón NO la sigue: se queda de pie en el
## último sitio donde estaba, en coordenadas del personaje (se mueve con él pero no con el brazo), hasta que la mano vuelve a menos de DISTANCIA_AGARRA (histéresis).
## Es mejor que estirarlo o inclinarlo: en «pensar» (manos frotándose) o corriendo el palo sigue plantado y no se le cruza por la cara.
## Se activa por datos: sexto dato de la entrada de Equipo3D.EQUIPO, un Dictionary con las claves K_* de abajo.
##
## MODO AGARRADO (28/10, bastón del chamán): `agarrar(true)` hace que la pieza deje de plantarse y siga a la mano RÍGIDA con su transformación de agarre (la que trae colgada del hueso: la
## de la entrada de EQUIPO), para los clips en que el palo se usa (trazar una runa con la punta rozando el suelo, clavarlo). El paso de un modo al otro se mezcla en `mezcla` s (posición y giro
## interpolados) para que el bastón no salte del suelo a la mano. `agarrar(false)` lo vuelve a plantar. `agarrado` dice si está en ese modo (o yendo hacia él).

## Claves del Dictionary de datos.
const K_AGARRE_Y: String = "agarre_y"                    ## altura de la palma sobre el pie, en unidades de la pieza (sin su escala)
const K_GIRO: String = "giro"                            ## grados sobre el eje vertical respecto a hacia donde mira el personaje (0 por defecto)
const K_DIST_MIN_CUERPO: String = "dist_min_cuerpo"      ## u de juego: separación mínima lateral al eje del cuerpo (que no atraviese la túnica)
const K_DESPLAZ_ADELANTE: String = "desplaz_adelante"    ## u de juego: desplazamiento extra hacia delante del agarre
const K_LADO: String = "lado"                            ## signo en X del personaje del lado de la mano (-1 = derecha de un modelo que mira a +Z)

const K_Z_MIN: String = "z_min"                         ## u de juego: lo más atrás (eje Z del personaje, +Z = delante) que puede quedar el pie
const K_Z_MAX: String = "z_max"                         ## y lo más adelante: la mano puede ir al pecho y el palo se queda a su costado, inclinado hacia ella

const INCLINACION_MAX: float = 12.0             ## grados máximos de desvío de la vertical (hacia la mano)
const DISTANCIA_SUELTA: float = 0.20            ## u de juego: la mano a más de esto (en horizontal) del bastón lo deja suelto
const DISTANCIA_AGARRA: float = 0.12            ## u de juego: vuelve a agarrarlo cuando la mano está a menos de esto
const ALTURA_MIN_AGARRE: float = 0.30           ## fracción del largo: la palma por debajo de esto sobre el suelo no agarra
const ALTURA_MAX_AGARRE: float = 1.05           ## fracción del largo: ni por encima de la punta de arriba
const SUAVIZADO: float = 14.0                   ## 1/s del seguimiento exponencial de la posición (más alto = más pegado a la mano)
const SUAVIZADO_GIRO: float = 10.0              ## 1/s del giro sobre el eje
const REPOSO_LATERAL: float = 0.14              ## u de juego: dónde queda plantado si nunca ha agarrado (hacia fuera del lado de la mano)
const REPOSO_ADELANTE: float = 0.04

var pieza: Node3D = null
var modelo: Node3D = null                       ## el modelo del personaje (hijo del Pj3D): su base da hacia dónde mira y su padre es el suelo
var esqueleto: Skeleton3D = null
var hueso: int = -1
var agarre_local: Vector3 = Vector3.ZERO        ## el punto de la palma en el espacio del hueso (con la pieza tal como cuelga de la mano)
var largo_pieza: float = 0.0                    ## u de mundo, ahora mismo
var giro: float = 0.0
var dist_min_cuerpo: float = 0.0
var desplaz_adelante: float = 0.0
var lado: float = -1.0
var z_min: float = -INF
var z_max: float = INF
var suelta: bool = false                        ## true = la mano está lejos y el bastón se queda plantado a su aire
var inclinacion: float = 0.0                    ## grados actuales respecto a la vertical (para las pruebas)
var distancia_mano: float = 0.0                 ## u de mundo, horizontal, de la palma al palo en el último fotograma (para las pruebas)
var _pie_local: Vector3 = Vector3.ZERO          ## el sitio plantado, en el espacio del personaje girado (sin escala): vive con él
var _yaw: float = 0.0
var _arrancado: bool = false
var _largo_local: float = 0.0
var _escala_local: float = 1.0
var agarrado: bool = false                      ## true = modo agarrado (sigue a la mano rígido), ver `agarrar`
var peso_agarre: float = 0.0                    ## 0 = plantado en el suelo, 1 = agarrado; entre medias, mezclando
var _mezcla: float = 0.12                       ## s que dura el paso entre los dos modos
var _transform_mano: Transform3D = Transform3D.IDENTITY   ## la transformación de la pieza en el espacio del hueso (la de EQUIPO)


## Prepara la pieza ya colgada del BoneAttachment (con su `transform` en el espacio del hueso) y se engancha al esqueleto. `datos` = las claves K_*.
func preparar(p_pieza: Node3D, p_modelo: Node3D, p_esqueleto: Skeleton3D, p_hueso: int, datos: Dictionary) -> void:
	pieza = p_pieza
	modelo = p_modelo
	esqueleto = p_esqueleto
	hueso = p_hueso
	giro = float(datos.get(K_GIRO, 0.0))
	lado = float(datos.get(K_LADO, -1.0))
	z_min = float(datos.get(K_Z_MIN, -INF))
	z_max = float(datos.get(K_Z_MAX, INF))
	dist_min_cuerpo = float(datos.get(K_DIST_MIN_CUERPO, 0.0))
	desplaz_adelante = float(datos.get(K_DESPLAZ_ADELANTE, 0.0))
	_transform_mano = pieza.transform
	agarre_local = pieza.transform * Vector3(0.0, float(datos.get(K_AGARRE_Y, 0.0)), 0.0)
	_largo_local = _largo_malla(pieza)
	_escala_local = pieza.scale.y
	pieza.top_level = true
	esqueleto.skeleton_updated.connect(_al_actualizar_esqueleto)


## Pasa al modo agarrado (`si` = true: la pieza sigue rígida a la mano) o al plantado (false). `mezcla` = s de la transición (0 = de golpe).
func agarrar(si: bool, mezcla: float = 0.12) -> void:
	agarrado = si
	_mezcla = maxf(mezcla, 0.0)
	if _mezcla <= 0.0:
		peso_agarre = 1.0 if si else 0.0


## Escala de la pieza en el mundo: la del hueso (esqueleto y personaje) por la suya propia.
func _escala_mundo() -> float:
	return (esqueleto.global_transform * esqueleto.get_bone_global_pose(hueso)).basis.get_scale().y * _escala_local


func _largo_malla(n: Node3D) -> float:
	var m: float = 0.0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		m = maxf(m, (mi as MeshInstance3D).get_aabb().size.y * (mi as Node3D).scale.y)
	return m


func _al_actualizar_esqueleto() -> void:
	actualizar(get_process_delta_time(), false)


## Coloca la pieza. `fijar` = salta directo al objetivo, sin suavizar (pruebas y capturas).
func actualizar(delta: float, fijar: bool) -> void:
	if pieza == null or not is_instance_valid(pieza) or modelo == null or not modelo.is_inside_tree() or not esqueleto.is_inside_tree():
		return
	largo_pieza = _largo_local * _escala_mundo()
	var padre := modelo.get_parent() as Node3D
	var raiz: Vector3 = padre.global_position if padre != null else modelo.global_position
	var zm: Vector3 = modelo.global_basis.z
	var yaw_modelo: float = atan2(zm.x, zm.z)
	var giro_pers := Basis(Vector3.UP, yaw_modelo)
	var mano: Vector3 = esqueleto.global_transform * esqueleto.get_bone_global_pose(hueso) * agarre_local
	var rel: Vector3 = giro_pers.inverse() * (mano - raiz)          # la palma en el espacio del personaje girado, en unidades de mundo
	var altura: float = rel.y
	if not _arrancado:
		_pie_local = Vector3(lado * REPOSO_LATERAL, 0.0, REPOSO_ADELANTE)
	var d_hor: float = Vector2(rel.x - _pie_local.x, rel.z - _pie_local.z).length()
	var agarrable: bool = altura >= largo_pieza * ALTURA_MIN_AGARRE and altura <= largo_pieza * ALTURA_MAX_AGARRE
	var cerca: float = DISTANCIA_AGARRA if suelta else DISTANCIA_SUELTA
	var objetivo_pie: Vector3 = _pie_local
	if agarrable and (d_hor <= cerca or not _arrancado):
		suelta = false
		var x: float = rel.x
		if dist_min_cuerpo > 0.0 and x * lado < dist_min_cuerpo:
			x = lado * dist_min_cuerpo          # lejos del cuerpo: que el palo no atraviese la túnica
		objetivo_pie = Vector3(x, 0.0, clampf(rel.z + desplaz_adelante, z_min, z_max))     # sin cruzarse por delante del pecho ni quedar a la espalda
	else:
		suelta = true
	var k: float = 1.0 if (fijar or not _arrancado) else 1.0 - exp(-SUAVIZADO * delta)
	_pie_local = _pie_local.lerp(objetivo_pie, k)
	_arrancado = _arrancado or not suelta
	var yaw_pieza: float = yaw_modelo + deg_to_rad(giro)
	_yaw = yaw_pieza if fijar else lerp_angle(_yaw, yaw_pieza, 1.0 - exp(-SUAVIZADO_GIRO * delta))
	# Inclinación hacia la mano solo si la palma no queda sobre el pie (por la distancia mínima al cuerpo) y mientras la sostiene.
	var al_mano := Vector3(rel.x - _pie_local.x, 0.0, rel.z - _pie_local.z)
	distancia_mano = al_mano.length()
	var tilt: float = 0.0
	if not suelta:
		tilt = minf(atan2(distancia_mano, maxf(altura, 0.01)), deg_to_rad(INCLINACION_MAX))
	inclinacion = rad_to_deg(tilt)
	var base := Basis(Vector3.UP, _yaw)
	var dir_h: Vector3 = giro_pers * al_mano
	if tilt > 0.0001 and dir_h.length() > 0.0001:
		base = Basis(Vector3.UP.cross(dir_h.normalized()).normalized(), tilt) * base      # rota la vertical hacia la mano
	var plantada := Transform3D(base * Basis.from_scale(Vector3.ONE * _escala_mundo()), raiz + giro_pers * _pie_local)
	# El peso del modo agarrado sube o baja hacia su objetivo (en pruebas `fijar` salta directo).
	var objetivo_peso: float = 1.0 if agarrado else 0.0
	if fijar or _mezcla <= 0.0:
		peso_agarre = objetivo_peso
	else:
		peso_agarre = move_toward(peso_agarre, objetivo_peso, delta / _mezcla)
	if peso_agarre <= 0.0:
		pieza.global_transform = plantada
		return
	var en_mano: Transform3D = esqueleto.global_transform * esqueleto.get_bone_global_pose(hueso) * _transform_mano
	if peso_agarre >= 1.0:
		pieza.global_transform = en_mano
		return
	var u: float = peso_agarre * peso_agarre * (3.0 - 2.0 * peso_agarre)
	var q: Quaternion = plantada.basis.get_rotation_quaternion().slerp(en_mano.basis.get_rotation_quaternion(), u)
	var sc: Vector3 = plantada.basis.get_scale().lerp(en_mano.basis.get_scale(), u)
	pieza.global_transform = Transform3D(Basis(q) * Basis.from_scale(sc), plantada.origin.lerp(en_mano.origin, u))
