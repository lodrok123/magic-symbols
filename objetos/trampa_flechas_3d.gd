class_name TrampaFlechas3D
extends TrampaPared3D

## TRAMPA DE FLECHAS (5/11/2026; docs/TRAMPAS_PARED_2026-11-05.md): un mascarón de piedra en el muro con una ranura de arquero que dispara una FLECHA cada `cada` s. Antes de cada disparo la ranura SE ILUMINA
## (AVISO_S = 0,35 s: del rescoldo al rojo vivo) y al salir da un fogonazo. Con `elemento=fuego` (por defecto) la flecha es de fuego y el mascarón lleva un brasero de carbones encima; con `elemento=ninguno`
## es una flecha normal (un palo que vuela recto) y el brasero está frío.
##
## LA FLECHA DE FUEGO ES UN HECHIZO REAL: `fuego + ᛇ` (la bola de fuego en vuelo de FuegoToy con su cola, el proyectil de la jugadora) con la velocidad, el alcance y SIN caída (`vel` y `alcance` del mapa),
## lanzado desde la ranura con el `Lanzador3D` de la jugadora. Vuela recto, se para en muros, en un bloque (empujable o de tierra) y en una barrera, prende lo inflamable que toca (seto, cuerda, barril, brasero)
## y daña a los enemigos con la vía de los hechizos. A la jugadora la hiere la trampa (`recibir_dano(DANO_JUGADORA)`, con su invulnerabilidad) y detiene la flecha ahí: un proyectil con `golpea_lanzador` no la
## hiere en los primeros 0,25 s y sigue su camino después de herirla. Un hechizo de agua/hielo que le da al mascarón lo apaga 8 s, como al dragón.
## La flecha normal (`FlechaTrampa3D`) hace lo mismo sin hechizo: DANO_JUGADORA a la jugadora, el daño de la flecha de un goblin a los enemigos.
##
## Ciclo: `cada=<s>` (1,2 por defecto), `desfase=<s>` (en qué punto del intervalo empieza), `vel=<casillas/s>` (3,5 ≈ 8 u/s, la flecha del goblin ≈ 9 u/s) y `alcance=<casillas>` (8, el tope de un hechizo).
## Pieza `trampa_flechas` en el mapa; dueño: Juego.
##
## LA BOCA SE MUEVE (5/11/2026, Pablo: «la boca abriendo, disparo, y cierra con anticipación»). El mascarón tiene MANDÍBULA (`Mandibula`, un pivote en la bisagra de atrás) y la cabeza entera (`Mascaron`) se
## mueve con ella. Por disparo: ANTICIPACIÓN (ANTICIPA_S = 0,5 s antes): primero APRIETA la boca y echa la cabeza atrás (APRIETA_S = 0,18 s, el gesto contrario, para que se lea lo que viene), luego la ABRE
## de golpe hasta ABRE_GRADOS y la sostiene abierta un instante → DISPARO: la cabeza da un culatazo atrás y la mandíbula un tirón → CIERRE (CIERRE_S = 0,38 s) con un pequeño rebote al cerrar.
## Con `cada` más corto que ANTICIPA_S + CIERRE_S los tiempos se encogen en proporción. Apagada o dormida: boca cerrada. La ranura que se ilumina (AVISO_S) va dentro de la anticipación.

signal dispara                     ## acaba de salir una flecha

const AVISO_S: float = 0.35
const DANO_JUGADORA: float = 12.0         ## la misma que la flecha del arquero goblin (Combate3D.DANO_FLECHA)
const RADIO_ACIERTO_U: float = 0.6        ## radio con el que la flecha acierta a la jugadora (horizontal)
const ALTO_ACIERTO_U: float = 1.7         ## altura de la jugadora sobre sus pies hasta la que acierta
const CADA_DEFECTO: float = 1.2
const VEL_DEFECTO: float = 3.5            ## casillas/s
const ALCANCE_DEFECTO: int = 8
const FOGONAZO_S: float = 0.25
const SEMIEJE_FLECHA_M: float = 0.28      ## semieje (m) de la bola de la flecha de fuego: el de la jugadora es 0,10 (en vuelo, la mitad); la de la trampa se ve y se esquiva mejor un poco más gruesa

# --- medidas (u) ---
const LOSA: Vector3 = Vector3(1.6, 1.9, 0.30)
const CARA: Vector3 = Vector3(1.2, 1.25, 0.30)       ## el mascarón sale de la losa
const BOCA_Y: float = 0.95
const BOCA_Z: float = 0.62                           ## la ranura, desde la cara del muro
const BISAGRA_Y: float = BOCA_Y - 0.05               ## la mandíbula gira por su arista de arriba y atrás; cerrada deja una raja oscura de 0,10 hasta el labio de arriba
const LABIO_Y: float = BOCA_Y + 0.05

# --- la boca (s y grados) ---
const ANTICIPA_S: float = 0.5
const APRIETA_S: float = 0.18
const CIERRE_S: float = 0.38
const ABRE_GRADOS: float = 38.0
const APRIETA_GRADOS: float = -5.0
const TIRON_GRADOS: float = 7.0                      ## de más al disparar
const ATRAS_APRIETA_U: float = 0.04                  ## la cabeza se echa atrás al apretar
const CULATAZO_U: float = 0.07                       ## y al disparar
const CULATAZO_S: float = 0.16

var cada_s: float = CADA_DEFECTO
var vel: float = VEL_DEFECTO
var disparos: int = 0
var golpes_jugadora: int = 0
var en_aviso: bool = false

var _t: float = 0.0                       ## s desde el último disparo
var _t_fogonazo: float = 0.0
var _vuelos: Array = []                   ## WeakRef de los HechizoVivo en vuelo (para herir a la jugadora)
var _ranura: StandardMaterial3D = null
var _carbones: Array[StandardMaterial3D] = []
var _ojos: StandardMaterial3D = null
var _cabeza: Node3D = null
var _mandibula: Node3D = null
var angulo_boca: float = 0.0              ## grados de la mandíbula ahora (+ = abierta)


func preparar_ciclo(p_cada: float, p_desfase: float, p_vel: float) -> void:
	cada_s = maxf(p_cada, 0.2)
	desfase_s = p_desfase
	vel = maxf(p_vel, 0.5)


func boca_local() -> Vector3:
	return Vector3(0.0, BOCA_Y, BOCA_Z)


func prof_cuerpo() -> float:
	return BOCA_Z - 0.07                        # la caja acaba justo antes de la ranura: la flecha nace fuera de ella


func _ready() -> void:
	super._ready()
	_t = fposmod(desfase_s, cada_s)
	_pintar(0.0)
	_poner_boca(pose_boca(_t))


func _construir() -> void:
	var fuego: bool = elemento == "fuego"
	_caja("Losa", LOSA, Vector3(0.0, LOSA.y * 0.5, LOSA.z * 0.5), _material(COLOR_PIEDRA))
	# La garganta: el fondo oscuro de la boca, con el rescoldo, pegado a la losa (no se mueve; se ve al abrir).
	_caja("Ranura", Vector3(0.9, 0.42, 0.04), Vector3(0.0, BOCA_Y - 0.08, LOSA.z + 0.02), _material(Color(0.02, 0.015, 0.015)))
	_ranura = _material(COLOR_BRASA if fuego else Color(0.75, 0.78, 0.82), 0.5, true)
	_caja("Rescoldo", Vector3(0.76, 0.09, 0.02), Vector3(0.0, BOCA_Y, LOSA.z + 0.05), _ranura)
	# La cabeza (se echa atrás y da el culatazo): media cara de arriba con cejas, ojos y colmillos, y la mandíbula colgada de su bisagra.
	_cabeza = Node3D.new()
	_cabeza.name = "Mascaron"
	_cabeza.position = Vector3(0.0, BOCA_Y, LOSA.z)
	add_child(_cabeza)
	var piedra_cara: StandardMaterial3D = _material(Color(0.36, 0.33, 0.30))
	var arriba_y: float = 1.02 + CARA.y * 0.5                       # el alto de la cara de antes (0,395 … 1,645)
	_caja("Cara", Vector3(CARA.x, arriba_y - LABIO_Y, CARA.z), Vector3(0.0, (arriba_y + LABIO_Y) * 0.5 - BOCA_Y, CARA.z * 0.5), piedra_cara, _cabeza)
	_caja("Ceja", Vector3(1.0, 0.1, 0.12), Vector3(0.0, 1.5 - BOCA_Y, CARA.z + 0.02), _material(COLOR_PIEDRA_OSCURA), _cabeza)
	_ojos = _material(COLOR_BRASA, 0.5, true)
	_caja("OjoIzq", Vector3(0.24, 0.07, 0.04), Vector3(-0.34, 1.3 - BOCA_Y, CARA.z + 0.01), _ojos, _cabeza)
	_caja("OjoDer", Vector3(0.24, 0.07, 0.04), Vector3(0.34, 1.3 - BOCA_Y, CARA.z + 0.01), _ojos, _cabeza)
	var diente: StandardMaterial3D = _material(Color(0.72, 0.68, 0.64))
	for x in [-0.32, 0.32]:
		_caja("Colmillo", Vector3(0.08, 0.1, 0.07), Vector3(x, LABIO_Y - BOCA_Y - 0.05, CARA.z - 0.05), diente, _cabeza)
	_mandibula = Node3D.new()
	_mandibula.name = "Mandibula"
	_mandibula.position = Vector3(0.0, BISAGRA_Y - BOCA_Y, 0.0)
	_cabeza.add_child(_mandibula)
	var abajo_y: float = 1.02 - CARA.y * 0.5
	var alto_m: float = BISAGRA_Y - abajo_y
	_caja("Quijada", Vector3(CARA.x * 0.96, alto_m, CARA.z), Vector3(0.0, -alto_m * 0.5, CARA.z * 0.5), piedra_cara, _mandibula)
	for x in [-0.16, 0.16]:
		_caja("Colmillo", Vector3(0.07, 0.08, 0.06), Vector3(x, 0.04, CARA.z - 0.05), diente, _mandibula)
	# Brasero encima: cuenco de piedra y tres carbones (encendidos solo con flechas de fuego).
	var cuenco := MeshInstance3D.new()
	cuenco.name = "Brasero"
	var cil := CylinderMesh.new()
	cil.top_radius = 0.30
	cil.bottom_radius = 0.20
	cil.height = 0.2
	cuenco.mesh = cil
	cuenco.material_override = _material(COLOR_PIEDRA_OSCURA)
	cuenco.position = Vector3(0.0, LOSA.y + 0.1, 0.34)
	add_child(cuenco)
	for i in range(3):
		var m: StandardMaterial3D = _material(COLOR_BRASA if fuego else Color(0.12, 0.1, 0.09), 1.4 if fuego else 0.0, true)
		_carbones.append(m)
		_esfera("Carbon%d" % i, 0.09, Vector3(-0.14 + 0.14 * float(i), LOSA.y + 0.22, 0.34 + (0.05 if i == 1 else -0.03)), m)


# ---------------------------------------------------------------------------------------------------------------------
#  Marcha
# ---------------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_vigilar_vuelos()
	if _t_fogonazo > 0.0:
		_t_fogonazo = maxf(_t_fogonazo - delta, 0.0)
	if _contar_apagada(delta):
		en_aviso = false
		_pintar(0.0)
		_cerrar_boca(delta)
		return
	if dormida():
		en_aviso = false
		_t = fposmod(desfase_s, cada_s)
		_pintar(0.0)
		_cerrar_boca(delta)
		return
	_t += delta
	if _t >= cada_s:
		_t = fposmod(_t, cada_s)
		_disparar()
	var aviso: float = minf(AVISO_S, cada_s)
	en_aviso = _t >= cada_s - aviso
	_pintar(clampf((_t - (cada_s - aviso)) / aviso, 0.0, 1.0) if en_aviso else 0.0)
	_poner_boca(pose_boca(_t))


## La pose de la boca a `t` s del último disparo (el siguiente, a `cada_s - t`): {"angulo": grados de la mandíbula, "atras": u que se echa atrás la cabeza, "aprieta": 0…1}.
func pose_boca(t: float) -> Dictionary:
	var k: float = minf(1.0, cada_s / (ANTICIPA_S + CIERRE_S))         # con un `cada` corto todo se encoge
	var antic: float = ANTICIPA_S * k
	var cierre: float = CIERRE_S * k
	var hasta: float = cada_s - t
	var ang: float = 0.0
	var atras: float = 0.0
	var aprieta: float = 0.0
	if disparos > 0 and t < cierre:
		# Tras el disparo: tirón de más y culatazo, luego cierra con un rebote (sale un poco por debajo de cerrada y vuelve).
		var s: float = t / cierre
		if s < 0.2:
			ang = ABRE_GRADOS + TIRON_GRADOS * sin(PI * s / 0.2)
		else:
			ang = ABRE_GRADOS * (1.0 - _sale_con_rebote((s - 0.2) / 0.8))
		var c: float = t / (CULATAZO_S * k)
		if c < 1.0:
			atras = CULATAZO_U * (1.0 - c) * (1.0 - c)                   # de golpe atrás y vuelve
	elif hasta < antic:
		var r: float = 1.0 - hasta / antic
		var ap: float = APRIETA_S / ANTICIPA_S
		if r < ap:
			aprieta = smoothstep(0.0, 1.0, r / ap)
			ang = APRIETA_GRADOS * aprieta
			atras = ATRAS_APRIETA_U * aprieta
		else:
			var u: float = minf((r - ap) / ((1.0 - ap) * 0.8), 1.0)        # abre en el 80 % y sostiene abierta el resto
			var e: float = 1.0 - pow(1.0 - u, 3.0)                        # de golpe al principio
			ang = lerpf(APRIETA_GRADOS, ABRE_GRADOS, e)
			atras = ATRAS_APRIETA_U * (1.0 - e)
			aprieta = 1.0 - e
	return {"angulo": ang, "atras": atras, "aprieta": aprieta}


func _sale_con_rebote(u: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var v: float = u - 1.0
	return 1.0 + c3 * v * v * v + c1 * v * v


func _poner_boca(p: Dictionary) -> void:
	angulo_boca = float(p["angulo"])
	if _mandibula != null:
		_mandibula.rotation.x = deg_to_rad(angulo_boca)
	if _cabeza != null:
		var a: float = float(p["aprieta"])
		_cabeza.position.z = LOSA.z - float(p["atras"])
		_cabeza.scale = Vector3(1.0 + 0.03 * a, 1.0 - 0.04 * a, 1.0)


func _cerrar_boca(delta: float) -> void:
	_poner_boca({"angulo": move_toward(angulo_boca, 0.0, 120.0 * delta), "atras": 0.0, "aprieta": 0.0})


func _al_apagar() -> void:
	en_aviso = false


func _al_encender() -> void:
	_t = 0.0


func _disparar() -> void:
	disparos += 1
	_t_fogonazo = FOGONAZO_S
	dispara.emit()
	var origen: Vector3 = boca_mundo()
	if RUNAS.has(elemento):
		var h: Hechizo = construir_hechizo({"flecha": 1}, {"velocidad": vel, "distancia_max": float(alcance), "gravedad": 0.0, "impulso_salida": 0.0, "golpea_lanzador": false, "rebotes": 0,
				"semiejes.x": SEMIEJE_FLECHA_M, "semiejes.y": SEMIEJE_FLECHA_M, "semiejes.z": SEMIEJE_FLECHA_M})
		var hv: HechizoVivo = lanzar_hechizo_vivo(h, origen, dir)
		if hv != null:
			_vuelos.append(weakref(hv))
	else:
		FlechaTrampa3D.disparar(self, origen, dir, float(alcance) * Terreno3D.casilla, lanzador())
		lanzamientos += 1


## La flecha de fuego en vuelo hiere a la jugadora si la alcanza (y se acaba ahí, con su impacto de golpe).
func _vigilar_vuelos() -> void:
	if _vuelos.is_empty():
		return
	var j: Node3D = jugadora()
	var quedan: Array = []
	for ref in _vuelos:
		var hv: HechizoVivo = (ref as WeakRef).get_ref() as HechizoVivo
		if hv == null or not is_instance_valid(hv) or not hv.activo:
			continue
		quedan.append(ref)
		if j == null or bool(j.get("muerto")):
			continue
		var d: Vector3 = hv.p - j.position
		if Vector2(d.x, d.z).length() <= RADIO_ACIERTO_U and d.y >= -0.1 and d.y <= ALTO_ACIERTO_U:
			if herir_jugadora(DANO_JUGADORA, hv.p):
				golpes_jugadora += 1
			hv._sitio_golpe = j.position
			hv._contacto_celdas = [Terreno3D.celda_de(j.position)]
			hv._terminar_o_volver("golpe")
	_vuelos = quedan


func vuelos_activos() -> int:
	var n: int = 0
	for ref in _vuelos:
		var hv: Variant = (ref as WeakRef).get_ref()
		if hv != null and is_instance_valid(hv) and bool((hv as HechizoVivo).activo):
			n += 1
	return n


func _pintar(aviso_k: float) -> void:
	var fuego: bool = elemento == "fuego"
	var e: float = (0.5 if fuego else 0.1) + 5.0 * aviso_k + 9.0 * (_t_fogonazo / FOGONAZO_S)
	if not activa:
		e = 0.0
	if _ranura != null:
		_ranura.emission_energy_multiplier = e
		_ranura.albedo_color = (COLOR_BRASA_VIVA if aviso_k > 0.5 or _t_fogonazo > 0.0 else COLOR_BRASA) if fuego else Color(0.8, 0.82, 0.86)
		_ranura.emission = _ranura.albedo_color
	if _ojos != null:
		_ojos.emission_energy_multiplier = (0.5 + 2.5 * aviso_k) if activa and fuego else 0.1
	for i in range(_carbones.size()):
		_carbones[i].emission_energy_multiplier = ((1.1 + 0.4 * sin(Time.get_ticks_msec() * 0.006 + float(i) * 2.0)) if (fuego and activa) else 0.0)
	if _luz != null:
		_luz.light_color = COLOR_BRASA
		_luz.light_energy = (0.6 + 2.0 * aviso_k + 2.5 * (_t_fogonazo / FOGONAZO_S)) if (fuego and activa) else 0.0
		_luz.position = boca_local()
		_luz.omni_range = 3.5
