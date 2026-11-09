class_name TrampaDragon3D
extends TrampaPared3D

## TRAMPA DRAGÓN (5/11/2026; docs/TRAMPAS_PARED_2026-11-05.md): una cabeza de serpiente-dragón de cuello largo que asoma de una boca de cueva en el muro y ESCUPE UN CHORRO continuo durante `encendida` s
## y descansa `apagada` s (el lanzallamas perpetuo del Zelda). Antes de cada escupitajo AVISA: la cabeza retrocede, abre la mandíbula y echa brasas y humo (AVISO_S = 0,5 s) para poder cronometrar el paso.
##
## EL CHORRO ES UN HECHIZO REAL: el haz de siempre (`elemento` + ᛁ × (alcance − 2); fuego por defecto, el chorro de FuegoToy), lanzado desde la boca cada TICK_S s mientras dura el fuego. El haz del juego es
## instantáneo y se ve HAZ_DURA_S (0,9 s): relanzarlo cada 0,8 s lo deja continuo (un chorro de 2 s son 3 haces). Cada haz hace lo suyo con los enemigos y los objetos de su recorrido (setos, cuerdas, barriles,
## braseros se encienden; el suelo queda quemado). La JUGADORA la hiere la trampa con `recibir_dano(DANO_TICK)` en cada haz si está dentro del chorro (en el eje, a ≤ LATERAL_U u): con la invulnerabilidad de 0,7 s
## de la jugadora y TICK_S = 0,8 s cada tick entra siempre = DANO_TICK / TICK_S de daño por segundo.
##
## Ciclo: `ciclo=<encendida>,<apagada>` en s (2,0 y 1,5 por defecto) y `desfase=<s>` (en qué punto del ciclo empieza; 0 = empieza en reposo). El ciclo se cuenta desde el INICIO del descanso: reposo → aviso (los
## últimos AVISO_S s del descanso) → fuego → reposo… Sin descanso (`apagada` = 0) escupe siempre; sin fuego (`encendida` = 0) no escupe nunca.
## Dibujo: primitivas (losa, boca de cueva, cuello de 5 bolas, cabeza con mandíbula articulada). Pieza `trampa_dragon` en el mapa; dueño: Juego.

signal escupe                      ## empieza a echar fuego
signal calla                       ## deja de echar fuego

enum Fase { REPOSO, AVISO, FUEGO, APAGADA }

const AVISO_S: float = 0.5
const RITMO_LLAMAS: float = 0.7           ## las llamas del chorro crecen un 30 % más despacio que las de la jugadora («nacer» del haz: 0,4 s → 0,57 s; Pablo, 5/11). Solo el dibujo
const TICK_S: float = 0.8                 ## s entre dos haces seguidos (> 0,7 s de invulnerabilidad de la jugadora)
const DANO_TICK: float = 10.0             ## daño a la jugadora por tick (compárese: golpe de goblin 20, barril 20, flecha de goblin 12)
const LATERAL_U: float = 0.75             ## u a cada lado del eje en las que quema a la jugadora
const ENCENDIDA_DEFECTO: float = 2.0
const APAGADA_DEFECTO: float = 1.5
const ALCANCE_DEFECTO: int = 5
const ALCANCE_MIN: int = 3
const ALCANCE_MAX: int = 6

# --- medidas (u, 1 casilla = 2,3 u) ---
const LOSA: Vector3 = Vector3(2.0, 2.6, 0.30)       ## ancho, alto, grueso de la losa pegada al muro
const BOCA_Y: float = 1.20                          ## altura de la boca sobre el suelo
const CABEZA_Z_MIN: float = 0.50                    ## la cabeza (su centro) cuando está retraída
const CABEZA_Z_MAX: float = 1.10                    ## y cuando se lanza a escupir
const PUNTA_CABEZA: float = 0.60                    ## del centro de la cabeza a la punta del hocico
const COLOR_ESCAMA: Color = Color(0.72, 0.15, 0.08)
const COLOR_VIENTRE: Color = Color(0.95, 0.46, 0.13)
const COLOR_CUERNO: Color = Color(0.22, 0.09, 0.07)

var encendida_s: float = 2.0
var apagada_s: float = 1.5
var fase: int = Fase.REPOSO
var ticks: int = 0                        ## haces lanzados (las pruebas)
var golpes_jugadora: int = 0              ## veces que ha herido a la jugadora
var escupidas: int = 0                    ## veces que ha empezado a escupir

var _t_ciclo: float = 0.0
var _t_tick: float = 0.0
var _t_anim: float = 0.0
var _ext: float = 0.15                    ## 0 = cabeza retraída, 1 = lanzada
var _mand: float = 0.05                   ## rad de apertura de la mandíbula
var _cabeza: Node3D = null
var _mandibula: Node3D = null
var _cuello: Array[MeshInstance3D] = []
var _brillo: StandardMaterial3D = null
var _brasas: CPUParticles3D = null
var _humo: CPUParticles3D = null
var _hechizo: Hechizo = null


func preparar_ciclo(p_encendida: float, p_apagada: float, p_desfase: float) -> void:
	encendida_s = maxf(p_encendida, 0.0)
	apagada_s = maxf(p_apagada, 0.0)
	desfase_s = p_desfase


func periodo() -> float:
	return maxf(encendida_s + apagada_s, 0.001)


func boca_local() -> Vector3:
	if _esq != null:
		var b: Vector3 = _de_modelo(MOD_BOCA)
		return Vector3(b.x, b.y, CABEZA_Z_MAX + PUNTA_CABEZA)          # el hocico del modelo ya queda a 1,70 de la cara del muro
	return Vector3(0.0, BOCA_Y, CABEZA_Z_MAX + PUNTA_CABEZA)


func prof_cuerpo() -> float:
	return 1.05                                 # la cabeza lanzada llega a 1,58 y el haz nace a 1,18 de la cara: ambos por delante de la caja


## La fase del ciclo en el punto `t` (s desde el inicio del descanso).
func fase_de(t: float) -> int:
	if encendida_s <= 0.0:
		return Fase.REPOSO
	var r: float = apagada_s
	var aviso: float = minf(AVISO_S, r)
	if t < r - aviso:
		return Fase.REPOSO
	if t < r:
		return Fase.AVISO
	return Fase.FUEGO


func _ready() -> void:
	super._ready()
	_t_ciclo = fposmod(desfase_s, periodo())
	fase = fase_de(_t_ciclo)
	if fase == Fase.FUEGO:
		_t_tick = 0.0
		escupidas += 1
	_animar(0.0, true)


func _construir() -> void:
	if _construir_modelo():
		return
	var piedra: StandardMaterial3D = _material(COLOR_PIEDRA)
	_caja("Losa", LOSA, Vector3(0.0, LOSA.y * 0.5, LOSA.z * 0.5), piedra)
	# Dintel y jambas: la boca de cueva (piedra más oscura) en la que se mete el cuello.
	_caja("Hueco", Vector3(1.0, 1.15, 0.06), Vector3(0.0, BOCA_Y, LOSA.z + 0.01), _material(Color(0.05, 0.03, 0.03)))
	_caja("Dintel", Vector3(1.25, 0.18, 0.2), Vector3(0.0, BOCA_Y + 0.66, LOSA.z + 0.06), _material(COLOR_PIEDRA_OSCURA))
	_caja("JambaIzq", Vector3(0.14, 1.15, 0.2), Vector3(-0.56, BOCA_Y, LOSA.z + 0.06), _material(COLOR_PIEDRA_OSCURA))
	_caja("JambaDer", Vector3(0.14, 1.15, 0.2), Vector3(0.56, BOCA_Y, LOSA.z + 0.06), _material(COLOR_PIEDRA_OSCURA))
	# Cuello: cinco bolas escamosas (con una cresta de púas naranjas en el lomo) que siguen a la cabeza.
	var escama: StandardMaterial3D = _material(COLOR_ESCAMA)
	var vientre: StandardMaterial3D = _material(COLOR_VIENTRE)
	for i in range(5):
		var seg: MeshInstance3D = _esfera("Cuello%d" % i, 0.23 - 0.014 * float(i), Vector3(0.0, BOCA_Y, 0.4), escama if i % 2 == 0 else vientre)
		_puas(seg, 0.23 - 0.014 * float(i), vientre if i % 2 == 0 else escama)
		_cuello.append(seg)
	# Cabeza: cráneo, hocico con fosas, cuernos abiertos hacia atrás, ojos y mandíbula articulada con el interior brillante.
	_cabeza = Node3D.new()
	_cabeza.name = "Cabeza"
	add_child(_cabeza)
	_caja("Craneo", Vector3(0.52, 0.34, 0.56), Vector3(0.0, 0.0, 0.0), escama, _cabeza)
	_caja("Hocico", Vector3(0.36, 0.22, 0.36), Vector3(0.0, -0.04, 0.42), escama, _cabeza)
	_caja("FosaIzq", Vector3(0.07, 0.05, 0.07), Vector3(-0.1, 0.09, 0.56), _material(COLOR_CUERNO), _cabeza)
	_caja("FosaDer", Vector3(0.07, 0.05, 0.07), Vector3(0.1, 0.09, 0.56), _material(COLOR_CUERNO), _cabeza)
	for lado in [-1.0, 1.0]:
		var cuerno: MeshInstance3D = _caja("Cuerno%s" % ("Izq" if lado < 0.0 else "Der"), Vector3(0.09, 0.09, 0.44), Vector3(0.24 * lado, 0.2, -0.2), _material(COLOR_CUERNO), _cabeza)
		cuerno.rotation = Vector3(-0.55, -0.4 * lado, 0.0)
	var ojo: StandardMaterial3D = _material(COLOR_BRASA_VIVA, 3.0, true)
	_esfera("OjoIzq", 0.07, Vector3(-0.22, 0.12, 0.16), ojo, _cabeza)
	_esfera("OjoDer", 0.07, Vector3(0.22, 0.12, 0.16), ojo, _cabeza)
	_mandibula = Node3D.new()
	_mandibula.name = "Mandibula"
	_mandibula.position = Vector3(0.0, -0.14, -0.05)
	_cabeza.add_child(_mandibula)
	_caja("MandibulaHueso", Vector3(0.38, 0.08, 0.66), Vector3(0.0, -0.03, 0.34), vientre, _mandibula)
	_brillo = _material(COLOR_BRASA, 0.6, true)
	_caja("Garganta", Vector3(0.30, 0.04, 0.5), Vector3(0.0, 0.0, 0.34), _brillo, _mandibula)	# Brasas y humo en la boca.
	_brasas = _particulas(Color(1.0, 0.45, 0.1, 0.9), Color(0.8, 0.12, 0.05, 0.0), 14, 0.55, 0.06, Vector3(0.0, 0.5, 1.0), 22.0, 0.9, 1.9, Vector3(0.0, -1.4, 0.0))
	_brasas.position = Vector3(0.0, -0.05, PUNTA_CABEZA)
	_cabeza.add_child(_brasas)
	_humo = _particulas(Color(0.34, 0.31, 0.30, 0.5), Color(0.2, 0.19, 0.19, 0.0), 8, 1.1, 0.2, Vector3(0.0, 1.0, 0.4), 30.0, 0.3, 0.7, Vector3(0.0, 0.45, 0.0))
	_humo.position = Vector3(0.0, 0.02, PUNTA_CABEZA)
	_cabeza.add_child(_humo)


# ---------------------------------------------------------------------------------------------------------------------
#  El modelo de Meshy (5/11/2026, Pablo: «Embergate Dragon»)
# ---------------------------------------------------------------------------------------------------------------------
## Viene en UNA malla (losa + cuello + cabeza, sin rig), normalizada a 1 de alto, con la boca hacia +Z. Aquí se le pone un esqueleto de 4 huesos con pesos suaves sacados de la geometría (raíz = losa,
## cuello, cabeza, mandíbula) para que se eche atrás, se lance y abra la boca sin cortar la malla. Medidas en las coordenadas del modelo (MOD_*): la losa va de z −0,50 a −0,22, el cuello sale del arco
## en z ≈ −0,22 y la cabeza (girada un poco hacia +X) acaba en el hocico, z 0,50, con la boca entre y 0,12 y 0,20.

## Escala: 2,0 u de alto (1,44 de ancho). La losa se mete MOD_HUNDE u en el muro: el hocico queda a 1,70 u de la cara del muro (lo mismo que la cabeza lanzada de las primitivas).
const MODELO: String = "res://arte/meshy/trampa_dragon.glb"
const MOD_ESCALA: float = 2.0
const MOD_HUNDE: float = 0.30
const MOD_CUELLO: Vector3 = Vector3(-0.05, 0.0, -0.22)
const MOD_CABEZA: Vector3 = Vector3(0.06, 0.24, 0.08)
const MOD_BISAGRA: Vector3 = Vector3(0.12, 0.15, 0.22)
const MOD_BOCA: Vector3 = Vector3(0.13, 0.16, 0.47)

var _esq: Skeleton3D = null
var _modelo: Node3D = null


## Del espacio del modelo al de la trampa (+Z hacia fuera de la cara del muro, y desde el suelo).
static func _de_modelo(p: Vector3) -> Vector3:
	return Vector3(p.x * MOD_ESCALA, (p.y + 0.5) * MOD_ESCALA, (p.z + 0.5) * MOD_ESCALA - MOD_HUNDE)


func _construir_modelo() -> bool:
	_esq = _modelo_con_huesos(MODELO, MOD_ESCALA, _de_modelo(Vector3.ZERO), ["Raiz", "Cuello", "Cabeza", "Mandibula"], [Vector3.ZERO, MOD_CUELLO, MOD_CABEZA, MOD_BISAGRA], _pesos_modelo)
	if _esq == null:
		return false
	_modelo = _esq.get_parent() as Node3D
	# Brasas y humo en la boca: siguen a la cabeza con un BoneAttachment3D.
	var at := BoneAttachment3D.new()
	at.name = "EnCabeza"
	at.bone_name = "Cabeza"
	_esq.add_child(at)
	var boca := Node3D.new()
	boca.name = "Boca"
	boca.position = MOD_BOCA - MOD_CABEZA
	boca.scale = Vector3.ONE / MOD_ESCALA
	at.add_child(boca)
	_brillo = _material(COLOR_BRASA, 0.6, true)
	_brasas = _particulas(Color(1.0, 0.45, 0.1, 0.9), Color(0.8, 0.12, 0.05, 0.0), 14, 0.55, 0.06, Vector3(0.0, 0.5, 1.0), 22.0, 0.9, 1.9, Vector3(0.0, -1.4, 0.0))
	boca.add_child(_brasas)
	_humo = _particulas(Color(0.34, 0.31, 0.30, 0.5), Color(0.2, 0.19, 0.19, 0.0), 8, 1.1, 0.2, Vector3(0.0, 1.0, 0.4), 30.0, 0.3, 0.7, Vector3(0.0, 0.45, 0.0))
	boca.add_child(_humo)
	return true


## a: todo lo que sale por delante de la losa (dentro del arco); b: la cabeza (por delante y por arriba del codo del cuello); c: la quijada (por debajo de la boca, en la parte de delante de la cabeza).
static func _pesos_modelo(p: Vector3) -> Array:
	var en_arco: float = 1.0 - smoothstep(0.26, 0.34, absf(p.x))
	var w_a: float = smoothstep(-0.21, -0.10, p.z) * en_arco
	var w_b: float = smoothstep(-0.04, 0.10, p.z) * smoothstep(-0.06, 0.08, p.y)
	var w_c: float = (1.0 - smoothstep(0.115, 0.15, p.y)) * smoothstep(0.17, 0.25, p.z)
	return [1.0 - w_a, w_a * (1.0 - w_b), w_a * w_b * (1.0 - w_c), w_a * w_b * w_c]


## La pose del modelo: `_ext` 0 = echado atrás (aviso) … 1 = lanzado (fuego); `_mand` = apertura de la boca (rad); `caida` = apagado, cabeza caída.
func _posar_modelo(caida: float, bob: float, tiembla: float) -> void:
	# Echado atrás el cuello se arquea hacia la losa y la cabeza mira arriba; lanzado, el cuello avanza y la cabeza queda horizontal (el chorro sale recto); apagado, todo cae.
	# El modelo en reposo ya mira algo hacia abajo: lanzado se levanta un poco para que la boca quede horizontal. `e` reparte `_ext` (el reposo, 0,15, queda a medio camino).
	var e: float = 1.0 - pow(1.0 - clampf(_ext, 0.0, 1.0), 4.0)
	var cuello := Quaternion(Vector3.RIGHT, lerpf(-0.50, -0.14, e) + caida * 0.8 + bob)
	var cabeza := Quaternion(Vector3.RIGHT, lerpf(-0.25, -0.12, e) + caida * 0.8) * Quaternion(Vector3.UP, tiembla)
	_esq.set_bone_pose_rotation(1, cuello)
	_esq.set_bone_pose_position(1, MOD_CUELLO + Vector3(0.0, lerpf(0.02, -0.01, e), lerpf(-0.05, 0.08, e)))
	_esq.set_bone_pose_rotation(2, cabeza)
	_esq.set_bone_pose_rotation(3, Quaternion(Vector3.RIGHT, _mand * 0.9))


## Tres púas en el lomo de un segmento del cuello.
func _puas(seg: MeshInstance3D, radio: float, mat: Material) -> void:
	for k in range(3):
		var pu := MeshInstance3D.new()
		pu.name = "Pua%d" % k
		var pm := PrismMesh.new()
		pm.size = Vector3(0.1, 0.16, 0.1)
		pu.mesh = pm
		pu.material_override = mat
		pu.position = Vector3(0.0, radio * 0.95, (float(k) - 1.0) * 0.07)
		seg.add_child(pu)


func _particulas(c0: Color, c1: Color, cuantas: int, vida: float, tam: float, d: Vector3, abre: float, v0: float, v1: float, grav: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = cuantas
	p.lifetime = vida
	p.local_coords = false
	p.direction = d
	p.spread = abre
	p.initial_velocity_min = v0
	p.initial_velocity_max = v1
	p.gravity = grav
	var q := QuadMesh.new()
	q.size = Vector2(tam, tam)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# ---------------------------------------------------------------------------------------------------------------------
#  Marcha
# ---------------------------------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t_anim += delta
	if _contar_apagada(delta):
		_animar(delta)
		return
	if dormida():
		# Lejos de la jugadora no corre el ciclo: si estaba escupiendo o avisando, vuelve al reposo del principio.
		if fase != Fase.REPOSO:
			if fase == Fase.FUEGO:
				calla.emit()
			fase = Fase.REPOSO
			_t_ciclo = fposmod(desfase_s, periodo())
		_animar(delta)
		return
	_t_ciclo = fposmod(_t_ciclo + delta, periodo())
	var nueva: int = fase_de(_t_ciclo)
	if nueva != fase:
		_cambiar_fase(nueva)
	if fase == Fase.FUEGO:
		_t_tick -= delta
		if _t_tick <= 0.0:
			_t_tick += TICK_S
			_tick()
	_animar(delta)


func _cambiar_fase(nueva: int) -> void:
	var antes: int = fase
	fase = nueva
	if nueva == Fase.AVISO and is_inside_tree():
		Sfx.play(self, "fuego_carga")
	if nueva == Fase.FUEGO:
		_t_tick = 0.0
		escupidas += 1
		escupe.emit()
	elif antes == Fase.FUEGO:
		calla.emit()


func _al_apagar() -> void:
	if fase == Fase.FUEGO:
		calla.emit()
	fase = Fase.APAGADA


func _al_encender() -> void:
	_t_ciclo = 0.0
	fase = Fase.REPOSO


## Un haz de fuego desde la boca (y la herida a la jugadora si está dentro).
func _tick() -> void:
	if _hechizo == null:
		_hechizo = construir_hechizo({"linea_x": clampi(alcance - 2, 1, 4)})
	if _hechizo != null:
		var h: Hechizo = _hechizo.copiar()
		h.set_meta(VfxToyJuego.META_RITMO_NACER, RITMO_LLAMAS)
		lanzar_hechizo_vivo(h, origen_chorro(), dir)
	if HumoRegla.capas["dragon"]:           # humo por regla (apagado por defecto): donde el chorro se frena, en su punta
		var punta: Vector3 = global_position + dir * largo_chorro_u()
		HumoRegla.enganchar_dragon(self, Vector3(punta.x, boca_mundo().y - 0.2, punta.z), dir)
	ticks += 1
	if jugadora_en_chorro() and herir_jugadora(DANO_TICK, boca_mundo()):
		golpes_jugadora += 1


## De dónde sale el haz: la boca menos lo que el haz adelanta al nacer (HAZ_BOCA_U), para que se vea salir de ella.
func origen_chorro() -> Vector3:
	return boca_mundo() - dir * HechizoVivo.HAZ_BOCA_U


## Hasta dónde llega el chorro, en u desde la cara del muro: el alcance del haz desde su origen, cortado por la primera casilla sólida.
func largo_chorro_u() -> float:
	var hasta: float = (CABEZA_Z_MAX + PUNTA_CABEZA) - HechizoVivo.HAZ_BOCA_U + float(clampi(alcance, ALCANCE_MIN, ALCANCE_MAX)) * Terreno3D.casilla
	var c: Vector2i = celda_delante()
	for k in range(ALCANCE_MAX + 2):
		if Lanzador3D.celda_solida(c, 0):
			return minf(hasta, float(k) * Terreno3D.casilla)
		c += celda_delante_offset()
	return hasta


## ¿Está la jugadora dentro del chorro? En el eje (a ≤ LATERAL_U u de él), entre la boca y el final del haz, y a la altura del suelo del chorro.
func jugadora_en_chorro() -> bool:
	var j: Node3D = jugadora()
	if j == null:
		return false
	var rel: Vector3 = j.position - global_position
	var a: float = rel.dot(dir)
	var lado: float = absf(rel.dot(Vector3(-dir.z, 0.0, dir.x)))
	return a >= (CABEZA_Z_MAX + PUNTA_CABEZA) - 0.5 and a <= largo_chorro_u() and lado <= LATERAL_U and absf(rel.y) < Terreno3D.ALTO_NIVEL * 0.9


# ---------------------------------------------------------------------------------------------------------------------
#  Dibujo animado
# ---------------------------------------------------------------------------------------------------------------------

func _animar(delta: float, ya: bool = false) -> void:
	var ext_obj: float = 0.15 + 0.04 * sin(_t_anim * 2.2)
	var mand_obj: float = 0.05
	var brillo: float = 0.4
	var luz: float = 0.0
	var caida: float = 0.0
	var vel_ext: float = 2.5
	var brasas: bool = false
	var humo: bool = false
	match fase:
		Fase.AVISO:
			var t_av: float = _t_ciclo - (apagada_s - minf(AVISO_S, apagada_s))
			ext_obj = 0.0 if t_av > 0.12 else 0.15
			mand_obj = 0.5
			brillo = 1.2 + 4.0 * clampf(t_av / AVISO_S, 0.0, 1.0)
			luz = 0.5 + 1.5 * clampf(t_av / AVISO_S, 0.0, 1.0)
			vel_ext = 4.0
			brasas = true
			humo = true
		Fase.FUEGO:
			ext_obj = 1.0
			mand_obj = 0.8
			brillo = 6.0
			luz = 2.6
			vel_ext = 9.0
			brasas = true
		Fase.APAGADA:
			ext_obj = 0.05
			mand_obj = 0.0
			brillo = 0.0
			caida = 0.55
			humo = true
	if ya:
		_ext = ext_obj
		_mand = mand_obj
	else:
		_ext = move_toward(_ext, ext_obj, vel_ext * delta)
		_mand = move_toward(_mand, mand_obj, 5.0 * delta)
	var bob: float = 0.03 * sin(_t_anim * 2.2) if fase == Fase.REPOSO else 0.0
	var tiembla: float = 0.012 * sin(_t_anim * 70.0) if fase == Fase.FUEGO else 0.0
	if _esq != null:
		_posar_modelo(caida, bob * 1.5, tiembla * 2.0)
		_brillo.emission_energy_multiplier = brillo
		if _luz != null:
			_luz.light_energy = luz
			_luz.position = boca_local()
		_brasas.emitting = brasas
		_humo.emitting = humo
		return
	if _cabeza == null:
		return
	var z: float = lerpf(CABEZA_Z_MIN, CABEZA_Z_MAX, _ext)
	var base: Vector3 = Vector3(0.0, BOCA_Y, 0.34)
	var fin: Vector3 = Vector3(tiembla, BOCA_Y + bob - caida * 0.35, z)
	_cabeza.position = fin
	_cabeza.rotation.x = caida
	_mandibula.rotation.x = _mand
	for i in range(_cuello.size()):
		var t: float = float(i) / float(_cuello.size())
		var p: Vector3 = base.lerp(fin, t)
		p.y += sin(t * PI) * 0.17 * (1.0 - 0.6 * _ext)
		p.x += sin(t * TAU + _t_anim * 1.3) * 0.07 * (1.0 - _ext)
		_cuello[i].position = p
	_brillo.emission_energy_multiplier = brillo
	_brillo.albedo_color = COLOR_BRASA if fase != Fase.APAGADA else Color(0.2, 0.1, 0.08)
	if _luz != null:
		_luz.light_energy = luz
		_luz.position = Vector3(0.0, BOCA_Y, z + PUNTA_CABEZA)
	_brasas.emitting = brasas
	_humo.emitting = humo
