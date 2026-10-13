extends RigidBody3D
class_name Flotador3D
## Cosa que flota (Fase 11.6, 12/10). Lo escribe el Juego. Troncos, cajas y empujables que caen al agua.
##
## Técnica de las SONDAS (CaptainProton42/DynamicWaterDemo, pedida por Pablo el 12/10): 4 puntos por objeto, y en cada
## uno se mira cuánto está hundido bajo la superficie del agua:
##     sumergido = AguaSim3D.superficie_en(p) − p.y
##     si sumergido > 0:  empuje = FLOTA · sumergido − FRENO · velocidad_vertical     (hacia arriba, aplicado EN p)
## Es LINEAL en lo hundido y no Arquímedes: cerca de la superficie queda más natural (un muelle suave con amortiguación,
## sin saltos). Aplicar la fuerza en cada sonda, y no en el centro, hace que el objeto se incline solo: la esquina más
## hundida empuja más.
##
## La altura sale SIEMPRE de AguaSim3D (CPU), nunca de la textura de ondas de la GPU: el juego tiene que saber dónde está
## el agua aunque el dibujo cambie. Las olas que provoca el objeto no son cosa de este archivo: el Pipeline le cuelga una
## cápsula en la capa `agua_contacto` (11.8).
##
## La corriente (`AguaSim3D.corriente_en`) arrastra el objeto: una fuerza proporcional a la diferencia entre la corriente y
## su velocidad horizontal, tanto mayor cuanto más hundido. Se para contra la orilla porque es un RigidBody3D: necesita
## colisión en el suelo y en las paredes del nivel (la pone el nivel; en el laboratorio, lab_agua_3d.gd).
##
## Valores medidos (prueba_flotador.gd): con masa 1 y gravedad 9,8, cada sonda aguanta 2,45 N en reposo, es decir un
## hundimiento de 2,45 / FLOTA = 0,082 u. FRENO 3 da un amortiguamiento de ~0,5: rebota una o dos veces y se calma en ~2 s.

const FLOTA: float = 30.0          ## N por unidad hundida y por sonda. Más alto = flota más alto y rebota más rápido
const FRENO: float = 3.0           ## N por (u/s) de velocidad vertical y por sonda. Más alto = se calma antes
const ARRASTRE: float = 1.5        ## N por (u/s) de diferencia con la corriente, con todas las sondas hundidas
const PROF_MIN_SONDA: float = 0.05 ## una lámina más fina que esto es suelo mojado, no agua que sostenga

## Medidas de la caja (x largo, y alto, z ancho). Las sondas van en sus 4 esquinas a media altura.
@export var tamano: Vector3 = Vector3(2.0, 0.4, 0.5)
@export var con_malla: bool = true
@export var color: Color = Color(0.55, 0.38, 0.22)

## La simulación del agua. Si no se pone, se usa la del Lanzador (Lanzador3D.agua_sim).
var agua: AguaSim3D = null
var sondas: PackedVector3Array = PackedVector3Array()    ## en el espacio local
var hundidas: int = 0                                     ## cuántas sondas están en el agua ahora mismo
var _costra: CostraHielo3D = null                         ## la costra de hielo (Pipeline) mientras está preso


func _ready() -> void:
	add_to_group("flotador")           # Lanzador3D.atrapar lo encuentra aquí cuando el agua se hiela con él dentro
	mass = 1.0
	angular_damp = 1.2
	linear_damp = 0.15
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tamano
	col.shape = forma
	add_child(col)
	if con_malla:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = tamano
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		b.material = mat
		m.mesh = b
		add_child(m)
	var hx: float = tamano.x * 0.5
	var hz: float = tamano.z * 0.5
	sondas = PackedVector3Array([Vector3(hx, 0, hz), Vector3(-hx, 0, hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz)])


func _agua_actual() -> AguaSim3D:
	return agua if agua != null else Lanzador3D.agua_sim


## El agua se ha helado con el objeto dentro (11.13): queda PRESO, quieto, hasta que el hielo se suelta (tiempo o fuego).
func congelar() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	if _costra == null or not is_instance_valid(_costra):
		_costra = CostraHielo3D.new()
		add_child(_costra)             # recoge las mallas hermanas (la caja del tronco) y las cubre


func _physics_process(_dt: float) -> void:
	var a: AguaSim3D = _agua_actual()
	hundidas = 0
	if a == null:
		return
	if freeze:
		if a.hielo_en(global_position) == -INF:
			freeze = false             # ya no hay hielo debajo: vuelve a flotar
			if _costra != null and is_instance_valid(_costra):
				_costra.derretir()
			_costra = null
		return
	var v_corr := Vector2.ZERO
	for s in sondas:
		var p: Vector3 = to_global(s)
		if a.profundidad_en(p) < PROF_MIN_SONDA:
			continue
		var sumergido: float = a.superficie_en(p) - p.y
		if sumergido <= 0.0:
			continue
		hundidas += 1
		var r: Vector3 = p - global_position
		var vy: float = (linear_velocity + angular_velocity.cross(r)).y
		# El agua empuja, no tira hacia abajo: si el freno pudiera más que el empuje, la fuerza se queda en 0.
		var empuje: float = maxf(0.0, FLOTA * sumergido - FRENO * vy)
		apply_force(Vector3.UP * empuje, r)
		v_corr += a.corriente_en(p)
	if hundidas > 0:
		v_corr /= float(hundidas)
		var dif := Vector2(v_corr.x - linear_velocity.x, v_corr.y - linear_velocity.z)
		var fuerza: Vector2 = dif * ARRASTRE * float(hundidas) / float(sondas.size())
		apply_central_force(Vector3(fuerza.x, 0.0, fuerza.y))


## ¿Está flotando? (al menos 3 de las 4 sondas en el agua). Para decidir si se puede pisar como puente (cuando se encaje).
func flota() -> bool:
	return hundidas >= 3
