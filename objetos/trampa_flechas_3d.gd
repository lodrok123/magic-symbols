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


func _construir() -> void:
	var fuego: bool = elemento == "fuego"
	_caja("Losa", LOSA, Vector3(0.0, LOSA.y * 0.5, LOSA.z * 0.5), _material(COLOR_PIEDRA))
	_caja("Cara", CARA, Vector3(0.0, 1.02, LOSA.z + CARA.z * 0.5), _material(Color(0.36, 0.33, 0.30)))
	_caja("Ceja", Vector3(1.0, 0.1, 0.12), Vector3(0.0, 1.5, LOSA.z + CARA.z + 0.02), _material(COLOR_PIEDRA_OSCURA))
	_ojos = _material(COLOR_BRASA, 0.5, true)
	_caja("OjoIzq", Vector3(0.24, 0.07, 0.04), Vector3(-0.34, 1.3, LOSA.z + CARA.z + 0.01), _ojos)
	_caja("OjoDer", Vector3(0.24, 0.07, 0.04), Vector3(0.34, 1.3, LOSA.z + CARA.z + 0.01), _ojos)
	# La ranura de arquero: un hueco oscuro con un rescoldo detrás.
	_caja("Ranura", Vector3(0.84, 0.16, 0.05), Vector3(0.0, BOCA_Y, LOSA.z + CARA.z + 0.0), _material(Color(0.02, 0.015, 0.015)))
	_ranura = _material(COLOR_BRASA if fuego else Color(0.75, 0.78, 0.82), 0.5, true)
	_caja("Rescoldo", Vector3(0.76, 0.09, 0.02), Vector3(0.0, BOCA_Y, LOSA.z + CARA.z + 0.03), _ranura)
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
		return
	if dormida():
		en_aviso = false
		_t = fposmod(desfase_s, cada_s)
		_pintar(0.0)
		return
	_t += delta
	if _t >= cada_s:
		_t = fposmod(_t, cada_s)
		_disparar()
	var aviso: float = minf(AVISO_S, cada_s)
	en_aviso = _t >= cada_s - aviso
	_pintar(clampf((_t - (cada_s - aviso)) / aviso, 0.0, 1.0) if en_aviso else 0.0)


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
