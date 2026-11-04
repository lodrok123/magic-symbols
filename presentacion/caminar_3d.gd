class_name Caminar3D
extends RefCounted

## CAMINAR SATISFACTORIO (2/11, docs/REVISION_GAMEFEEL_30-10.md §11, Pablo: «quiero que sea satisfactorio caminar por el mundo»). Cada paso deja algo en el mundo y el cuerpo y la cámara acompañan.
## Nada de esto cambia velocidad, colisión ni reglas: es solo aspecto. Todo `static var` (abajo, por tarea) y todo se apaga con `Sensacion3D.ACTIVA = false` (menos las ondas del agua, que son del mundo).
##
## Quién llama a qué (cambios mínimos y aditivos en los archivos de otros):
##   · `Jugador3D._sonar_pasos`      → `Caminar3D.paso(self, correr)`: polvo y huellas (W1) y vadeo (W4) en cada paso.
##   · `Jugador3D._process`          → `Caminar3D.actualizar(self, hay_mov, delta)` cada fotograma: cuerpo (aplastar, inclinar), balanceo de cámara (W3), rastro de la hierba y las piezas (W2, W5), agua (W4), hojas y pájaros (W5).
##   · `Jugador3D._vertical`         → `Caminar3D.aterrizar(self, vy)`: aplastamiento al tocar suelo (W1).
##   · `Hierba3D._crear_bloque`      → `Caminar3D.decorar_bloque(...)`: hojas y motas por BLOQUE cargado (W5); nacen y mueren con el bloque.
##   · `PruebaTest2._plantilla`      → `Caminar3D.es_pieza_viva` / `fuerza_viento_pieza`: arbustos, helechos y hierba alta se mecen y se apartan (W5; el shader común de `Ocluso3D`).
## El estado de cada jugadora (emisores, rastro, relojes) vive en `Caminar3D.EstCam`, colgado de ella como meta `caminar`.

# ---------------------------------------------------------------------------------------------------------------------
#  W1 · Pies que dejan huella
# ---------------------------------------------------------------------------------------------------------------------
static var POLVO_PASO_ACTIVO: bool = true
static var POLVO_PASO_N: Vector2i = Vector2i(4, 7)                 ## partículas por paso: andando, corriendo
static var POLVO_PASO_TAM: Vector2 = Vector2(0.12, 0.2)            ## u (mín, máx)
static var POLVO_PASO_VIDA: float = 0.5                            ## s
static var POLVO_PASO_SUBE: float = 0.15                           ## u/s de subida
static var POLVO_PASO_COLOR: Color = Color(0.72, 0.62, 0.5, 0.35)  ## camino; la tierra, algo más oscura
static var POLVO_PASO_COLOR_HIERBA: Color = Color(0.42, 0.7, 0.26, 0.9)   ## las motas verdes de la hierba
static var POLVO_PASO_LADO: float = 0.12                           ## u: cada pie, a un lado de la marcha
static var MOTAS_PASO_N: int = 2                                   ## motas verdes que saltan por paso en hierba
static var MOTAS_PASO_SALTO: float = 0.3                           ## u que suben antes de caer
static var ATERRIZA_FUERTE: Vector3 = Vector3(1.08, 0.9, 1.08)     ## aplastamiento si cae de alto (vy <= -Sensacion3D.VY_POLVO_CAIDA)
static var ATERRIZA_LEVE: Vector3 = Vector3(1.03, 0.96, 1.03)      ## en cualquier otro aterrizaje
static var T_ATERRIZA: float = 0.12

# ---------------------------------------------------------------------------------------------------------------------
#  W2 · Hierba viva
# ---------------------------------------------------------------------------------------------------------------------
static var PISADO_ANDAR: float = 0.35                              ## lo que aplasta la hierba su casilla al andar…
static var PISADO_CORRER: float = 0.55                             ## …y al correr (`T_PISADO` de la maqueta se queda)
static var MOTAS_ALTA_ACTIVO: bool = true
static var MOTAS_ALTA_N: int = 4                                   ## briznas sueltas por paso corriendo por hierba alta o crecida
static var ESTELA_PASO: float = 0.3                                ## u que ha de moverse para dejar otro punto en el rastro
static var ESTELA_DT: float = 0.2                                  ## s mínimos entre dos puntos del rastro

# ---------------------------------------------------------------------------------------------------------------------
#  W3 · Cuerpo y cámara que acompañan (el balanceo de cámara está en Sensacion3D: BALANCEO_*)
# ---------------------------------------------------------------------------------------------------------------------
static var CUERPO_ACTIVO: bool = true                              ## aplastar / inclinar el modelo (apaga también el aterrizaje)
static var INCLINACION_GIRO: float = 6.0                           ## grados de inclinación al girar (máximo)
static var GIRO_REF: float = 540.0                                 ## °/s de giro con los que la inclinación llega al máximo
static var T_INCLINA: float = 0.12                                 ## s de suavizado
static var ARRANQUE_APLASTA: Vector3 = Vector3(1.03, 0.96, 1.03)   ## al pasar de parado a correr
static var T_ARRANQUE_APLASTA: float = 0.1
static var FRENADA_INCLINA: float = 4.0                            ## grados hacia delante al frenar en seco desde correr
static var T_FRENADA: float = 0.15
static var FRENADA_VEL: float = 0.8                                ## fracción de la velocidad de correr que cuenta como «venía corriendo»

# ---------------------------------------------------------------------------------------------------------------------
#  W4 · Agua
# ---------------------------------------------------------------------------------------------------------------------
static var AGUA_ACTIVA: bool = true                                ## gotas, salpicadura y chapoteo (las ondas no se apagan con ACTIVA)
static var ONDA_PASO: float = 0.07                                 ## fuerza de la onda de cada paso en agua poco profunda (el brief decía 0,35; ver el diario: >0,12 blanquea el canal)
static var ONDA_ENTRADA: float = 0.14                              ## al entrar en el agua desde tierra (el brief: 0,8)
static var ONDA_NADO: float = 0.05                                 ## nadando, cada T_ONDA_NADO s
static var ONDA_RADIO: float = 0.55                                ## u
static var T_ONDA_NADO: float = 0.6
static var GOTAS_PASO: int = 3
static var DB_CHAPOTEO_PASO: float = -16.0
static var TONO_CHAPOTEO: Vector2 = Vector2(1.1, 1.3)
static var SALPICADURA_ENTRADA: float = 0.8

# ---------------------------------------------------------------------------------------------------------------------
#  W5 · El mundo responde
# ---------------------------------------------------------------------------------------------------------------------
static var VIENTO_PIEZAS: float = 0.04                             ## balanceo de helechos y hierba alta (fracción de su alto; el arbusto ya tenía 0,035)
static var APARTAR_PIEZAS_ACTIVO: bool = true
static var APARTAR_PIEZAS_RADIO: float = 1.0                       ## u
static var APARTAR_PIEZAS_RETORNO_S: float = 0.8
static var HOJAS_ACTIVO: bool = true
static var HOJAS_POR_BLOQUE: int = 3                               ## hojas cada T_HOJAS_S en un bloque de hierba con árboles
static var T_HOJAS_S: float = 4.0
static var T_HOJA_CAIDA: float = 2.5                               ## s que tarda en caer
static var HOJA_TAM: float = 0.08
static var HOJAS_ALTURA: float = 3.0                               ## u sobre el suelo de donde caen
static var HOJAS_CORRER: int = 4                                   ## hojas extra al pasar corriendo bajo un árbol
static var ARBOL_RADIO: float = 1.6                                ## u: «bajo un árbol»
static var COLOR_HOJAS: Color = Color(0.5, 0.63, 0.22)
static var MOTAS_ACTIVO: bool = true
static var MOTAS_DIA: int = 6                                      ## motas blancas por bloque
static var MOTAS_NOCHE: int = 4                                    ## luciérnagas amarillas por bloque
static var MOTAS_TAM: float = 0.04
static var MOTAS_ALFA: float = 0.5
static var MOTAS_ALTURA: float = 0.3                               ## u sobre la hierba
static var PAJAROS_ACTIVO: bool = true
static var PROB_PAJAROS: float = 0.15                              ## por bloque al acercarse corriendo
static var PAJAROS_MIN_S: float = 8.0                              ## s mínimos entre dos bandadas (y entre dos tiradas del mismo bloque)
static var PAJAROS_DIST: float = 3.0                               ## u del bloque
static var PAJAROS_TAM: float = 0.15
static var PAJAROS_VIDA: float = 1.5
static var DB_PAJAROS: float = -14.0

## Para las pruebas: cuántas veces ha hecho cada cosa.
static var cuenta: Dictionary = {"polvo_paso": 0, "motas": 0, "huellas": 0, "aterriza": 0, "arranque": 0, "frenada": 0, "gotas": 0, "onda": 0, "onda_sin_agua": 0, "salpica": 0,
		"chapoteo": 0, "hojas": 0, "pajaros": 0}

static var _tex_pajaro: ImageTexture = null
static var _arboles: Dictionary = {}              ## id del mundo -> PackedVector3Array con los árboles (piezas «arbol*») de su decorado
static var _ramp_dia: GradientTexture1D = null
static var _ramp_noche: GradientTexture1D = null


## Lo que Caminar3D recuerda de cada jugadora (colgado de ella como meta «caminar»).
class EstCam extends RefCounted:
	var polvo: Array = [null, null]            ## un emisor por pie
	var motas: GPUParticles3D = null
	var gotas: GPUParticles3D = null
	var hojas: GPUParticles3D = null
	var pajaros: GPUParticles3D = null
	var par: int = 0                           ## qué pie toca
	var reloj: float = 0.0                     ## s de juego acumulados (cadencia de los pájaros)
	# cuerpo
	var aplicada: Vector3 = Vector3.ONE        ## el factor de escala que ahora mismo lleva puesto el modelo
	var sq_pico: Vector3 = Vector3.ONE
	var sq_t: float = 0.0
	var sq_dur: float = 0.0
	var inclina: float = 0.0                   ## rad, sobre Z (al girar)
	var yaw_prev: float = 0.0
	var t_frenada: float = 0.0                 ## s que quedan de inclinación hacia delante
	var vel_prev: float = 0.0
	var corria_prev: bool = false
	var frenando: bool = false
	# rastro de la hierba y las piezas: [Vector3, edad_hierba, edad_piezas] (edad = s desde que salió del radio)
	var rastro: Array = []
	var t_rastro: float = 0.0
	var ultimo_reg: Vector3 = Vector3(1.0e9, 0.0, 1.0e9)
	var radio_h: float = 0.9
	var rastro_h: Array = []                   ## lo último que se mandó a Hierba3D (Vector4)
	var rastro_p: Array = []                   ## y a Ocluso3D
	var empuje: Vector2 = Vector2.ZERO         ## lo último que se mandó como `empuje`
	# agua
	var celda_prev: Vector2i = Vector2i(-99999, -99999)
	var en_agua_prev: bool = false
	var t_nado: float = 0.0
	var t_entrada: float = 0.0
	# W5
	var t_check: float = 0.0
	var t_bloques: float = 0.0                 ## s hasta la próxima revisión de las partículas de los bloques
	var alimentado: bool = false               ## ya se mandó el estado «quieta» a la hierba y las piezas
	var pos_alim: Vector3 = Vector3.INF
	var activa_alim: bool = true
	var t_arbol: float = -99.0
	var t_pajaros: float = -99.0
	var tiradas: Dictionary = {}               ## bloque -> reloj de su última tirada


static func estado(j: Object) -> EstCam:
	if j.has_meta("caminar"):
		return j.get_meta("caminar") as EstCam
	var e := EstCam.new()
	j.set_meta("caminar", e)
	return e


# ---------------------------------------------------------------------------------------------------------------------
#  Emisores reutilizables (uno por jugadora y tipo: se reinician en cada ráfaga, no se crean uno por paso)
# ---------------------------------------------------------------------------------------------------------------------

static func _textura(nombre: String) -> Texture2D:
	return VfxPuzle3D._textura(nombre)


static func _emisor(padre: Node3D, n: int, vida: float, tam: Vector2, vel: Vector2, grav: Vector3, dir: Vector3, abanico: float, tex: Texture2D, crece: bool, radio_emision: float,
		amortigua: float = 0.0) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.emitting = false
	gp.amount = n
	gp.lifetime = vida
	gp.one_shot = true
	gp.explosiveness = 1.0
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 8, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = abanico
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = grav
	pm.damping_min = amortigua
	pm.damping_max = amortigua * 1.3
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radio_emision
	pm.scale_min = tam.x
	pm.scale_max = tam.y
	var curva := Curve.new()
	if crece:
		curva.add_point(Vector2(0.0, 0.5))
		curva.add_point(Vector2(1.0, 1.4))
	else:
		curva.add_point(Vector2(0.0, 1.0))
		curva.add_point(Vector2(1.0, 0.8))
	var ct := CurveTexture.new()
	ct.curve = curva
	pm.scale_curve = ct
	var g := Gradient.new()                                  # el alfa baja a 0 al final: nada desaparece de golpe
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.billboard_keep_scale = true
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = tex
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	q.orientation = PlaneMesh.FACE_Z
	q.material = sm
	gp.draw_pass_1 = q
	padre.add_child(gp)
	return gp


## Una ráfaga de `n` partículas (de las `n_max` del emisor) en `punto`, con ese color.
static func _disparar(gp: GPUParticles3D, punto: Vector3, n: int, n_max: int, color: Color) -> void:
	if gp == null or not is_instance_valid(gp) or not gp.is_inside_tree():
		return
	gp.global_position = punto
	gp.amount_ratio = clampf(float(n) / float(maxi(n_max, 1)), 0.05, 1.0)
	(gp.process_material as ParticleProcessMaterial).color = color
	gp.restart()


## Un sonido suelto del catálogo de `Sfx` (chapoteo, pájaros) en `pos`, con dB y tono propios; `max_s` > 0 lo corta a ese tiempo (los pájaros son un ambiente largo).
static func _sonido(j: Node, nombre: String, pos: Vector3, db: float, tono: float, max_s: float = 0.0) -> void:
	if j == null or not is_instance_valid(j) or not j.is_inside_tree() or not Sfx.CATALOGO.has(nombre):
		return
	var lista: Array = Sfx.archivos_de(Sfx.CATALOGO[nombre] as Dictionary)
	var flujo: AudioStream = load(Sfx.CARPETA + String(lista.pick_random())) as AudioStream
	Sfx._anotar(nombre, db, tono)
	if flujo == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = flujo
	p.volume_db = db
	p.pitch_scale = tono
	p.unit_size = 3.0
	p.max_distance = 12.0
	j.get_tree().root.add_child(p)
	p.global_position = pos + Vector3(0.0, 0.3, 0.0)
	p.bus = Sfx3D.bus_para(p)
	p.finished.connect(p.queue_free)
	p.play()
	if max_s > 0.0:
		var id: int = p.get_instance_id()
		j.get_tree().create_timer(max_s).timeout.connect(func() -> void:
			var viva: Object = instance_from_id(id)
			if viva != null:
				(viva as Node).queue_free())


# ---------------------------------------------------------------------------------------------------------------------
#  W1 · Polvo de paso, huellas y aplastamiento al aterrizar
# ---------------------------------------------------------------------------------------------------------------------

## Cada paso (lo llama `Jugador3D._sonar_pasos`): polvo y huellas según el suelo, o vadeo si hay agua poco profunda. Piedra y puente: nada.
static func paso(j, correr: bool) -> void:
	if j == null or j.pj == null or not j.is_inside_tree():
		return
	var c: Vector2i = Terreno3D.celda_de(j.position)
	if Terreno3D.es_agua(c) and not j.nadando:
		_paso_agua(j, correr)
		return
	if not Sensacion3D.ACTIVA:
		return
	if Terreno3D.letra_de(c) == "b":
		return
	var tipo: int = 0
	if j.mundo != null and j.mundo.has_method("_tipo_suelo"):
		tipo = int(j.mundo.call("_tipo_suelo", c))
	var k: float = 1.0 if correr else 0.0
	var punto: Vector3 = polvo_paso(j, j.position, k, tipo)
	if tipo == 1 or tipo == 2:
		var hu: Huellas3D = Huellas3D.de(j.mundo)
		if hu != null:
			hu.poner(Vector3(punto.x, j.position.y, punto.z), j._mirada)
			cuenta["huellas"] = int(cuenta["huellas"]) + 1


## El polvo de un paso en `pos_pie`: `k` 0 = andando, 1 = corriendo; `tipo` 0 hierba (motas verdes que saltan), 1 camino, 2 tierra; 3 (piedra) nada. El pie alterna a ±POLVO_PASO_LADO de la marcha.
## Devuelve el punto donde puso el pie (o `pos_pie` si no hizo nada).
static func polvo_paso(j, pos_pie: Vector3, k: float, tipo: int) -> Vector3:
	if not Sensacion3D.ACTIVA or not POLVO_PASO_ACTIVO or j == null or not j.is_inside_tree() or tipo < 0 or tipo > 2:
		return pos_pie
	var e: EstCam = estado(j)
	var dir: Vector3 = j._mirada
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0.0, 0.0, 1.0)
	var signo: float = 1.0 if e.par == 0 else -1.0
	var pie: int = e.par
	e.par = 1 - e.par
	var punto: Vector3 = pos_pie + Vector3(-dir.z, 0.0, dir.x) * (POLVO_PASO_LADO * signo) + Vector3(0.0, 0.04, 0.0)
	if tipo == 0:
		# Hierba: unas motas verdes que saltan MOTAS_PASO_SALTO u y caen (al correr por hierba alta o crecida, más: W2).
		var n: int = MOTAS_PASO_N
		if k > 0.5 and MOTAS_ALTA_ACTIVO and _es_alta(j, Terreno3D.celda_de(pos_pie)):
			n = MOTAS_ALTA_N
		if e.motas == null or not is_instance_valid(e.motas):
			var v0: float = sqrt(2.0 * 9.0 * MOTAS_PASO_SALTO)
			e.motas = _emisor(j, 6, 0.5, Vector2(0.05, 0.09), Vector2(v0 * 0.8, v0 * 1.05), Vector3(0.0, -9.0, 0.0), Vector3.UP, 28.0, _textura("hoja"), false, 0.1)
		_disparar(e.motas, punto, n, 6, POLVO_PASO_COLOR_HIERBA)
		cuenta["motas"] = int(cuenta["motas"]) + 1
		return punto
	if e.polvo[pie] == null or not is_instance_valid(e.polvo[pie]):
		e.polvo[pie] = _emisor(j, POLVO_PASO_N.y, POLVO_PASO_VIDA, POLVO_PASO_TAM, Vector2(POLVO_PASO_SUBE, POLVO_PASO_SUBE * 1.9), Vector3.ZERO, Vector3.UP, 75.0,
				_textura("polvo"), true, 0.08, 0.6)
	var n_p: int = int(round(lerpf(float(POLVO_PASO_N.x), float(POLVO_PASO_N.y), clampf(k, 0.0, 1.0))))
	var col: Color = POLVO_PASO_COLOR
	if tipo == 2:
		col = Color(col.r * 0.86, col.g * 0.84, col.b * 0.82, col.a)       # la tierra, más oscura que el camino
	_disparar(e.polvo[pie] as GPUParticles3D, punto, n_p, POLVO_PASO_N.y, col)
	cuenta["polvo_paso"] = int(cuenta["polvo_paso"]) + 1
	return punto


## ¿Hierba alta o crecida en la casilla? (la corta decorativa es la letra «,»).
static func _es_alta(j, c: Vector2i) -> bool:
	var h: Hierba3D = _hierba(j.mundo)
	if h != null and h.es_crecida(c):
		return true
	return Terreno3D.letra_de(c) != ","


## Al tocar suelo con velocidad vertical `vy` (negativa): el cuerpo se aplasta y vuelve a su sitio con rebote. Lo llama `Jugador3D._vertical`.
static func aterrizar(j, vy: float) -> void:
	if not Sensacion3D.ACTIVA or not CUERPO_ACTIVO or j == null or j.pj == null:
		return
	var e: EstCam = estado(j)
	_aplastar(e, ATERRIZA_FUERTE if vy <= -Sensacion3D.VY_POLVO_CAIDA else ATERRIZA_LEVE, T_ATERRIZA)
	cuenta["aterriza"] = int(cuenta["aterriza"]) + 1


static func _aplastar(e: EstCam, pico: Vector3, dur: float) -> void:
	e.sq_pico = pico
	e.sq_t = 0.0
	e.sq_dur = maxf(dur, 0.01)


## Tween.TRANS_BACK + EASE_OUT: de 0 a 1 pasándose un poco.
static func _atras(u: float) -> float:
	var c1: float = 1.70158
	var x: float = clampf(u, 0.0, 1.0) - 1.0
	return 1.0 + (c1 + 1.0) * x * x * x + c1 * x * x


# ---------------------------------------------------------------------------------------------------------------------
#  Cada fotograma
# ---------------------------------------------------------------------------------------------------------------------

## Lo llama `Jugador3D._process` cada fotograma (con el delta de juego): `hay_mov` = hay teclas de movimiento apretadas.
static func actualizar(j, hay_mov: bool, delta: float) -> void:
	if delta <= 0.0 or j == null or j.pj == null or not is_instance_valid(j.pj):
		return
	var e: EstCam = estado(j)
	var activa: bool = Sensacion3D.ACTIVA
	e.reloj += delta
	var vel: float = (j.vel_suelo as Vector3).length()
	var en_suelo: bool = bool(j.en_suelo) and not bool(j.nadando)
	_cuerpo(j, e, hay_mov, vel, en_suelo, delta, activa)
	# Balanceo de la cámara: 1 corriendo, 0,5 andando, 0 quieta / nadando / en el aire / rodando.
	var vn: float = 0.0
	if activa and hay_mov and en_suelo and vel > 0.3 and float(j._t_roll) <= 0.0:
		vn = 1.0 if bool(j.corriendo) else 0.5
	if vn > 0.0 or Sensacion3D._bal_peso > 0.0 or not activa:
		Sensacion3D.balanceo_carrera(j.get_viewport(), vn, delta)
	_rastro(j, e, vel, delta, activa)
	_agua(j, e, delta)
	e.t_bloques -= delta
	if e.t_bloques <= 0.0:
		e.t_bloques = 1.0
		_revisar_bloques(j)
	if activa and bool(j.corriendo) and en_suelo:
		e.t_check -= delta
		if e.t_check <= 0.0:
			e.t_check = 0.25
			hojas_bajo_arbol(j, e)
			pajaros_tick(j, e)
	e.vel_prev = vel
	e.corria_prev = bool(j.corriendo)


## Aplastar al arrancar y al aterrizar, inclinar al girar y hacia delante al frenar. Reescribe la escala (multiplicando la que tenga) y la rotación X/Z del modelo.
static func _cuerpo(j, e: EstCam, hay_mov: bool, vel: float, en_suelo: bool, delta: float, activa: bool) -> void:
	var pj: Node3D = j.pj
	var on: bool = activa and CUERPO_ACTIVO
	var vc: float = float(j._vel_correr)
	if on and en_suelo:
		if bool(j.corriendo) and not e.corria_prev and e.vel_prev < 0.4:
			_aplastar(e, ARRANQUE_APLASTA, T_ARRANQUE_APLASTA)             # de parado a correr
			cuenta["arranque"] = int(cuenta["arranque"]) + 1
		if hay_mov:
			e.frenando = false
		elif not e.frenando and e.vel_prev >= FRENADA_VEL * vc:
			e.frenando = true                                              # soltó las teclas viniendo a tope
			e.t_frenada = T_FRENADA
			var c: Vector2i = Terreno3D.celda_de(j.position)
			var tipo: int = int(j.mundo.call("_tipo_suelo", c)) if (j.mundo != null and j.mundo.has_method("_tipo_suelo")) else 0
			if Terreno3D.letra_de(c) != "b" and (tipo == 1 or tipo == 2):
				polvo_paso(j, j.position, 1.0, tipo)                       # ráfaga doble: los dos pies
				polvo_paso(j, j.position, 1.0, tipo)
			cuenta["frenada"] = int(cuenta["frenada"]) + 1
	# Aplastamiento: factor sobre la escala base (la que tuviera el modelo antes de nosotros).
	var f := Vector3.ONE
	if on and e.sq_dur > 0.0 and e.sq_t < e.sq_dur:
		e.sq_t += delta
		var u: float = clampf(e.sq_t / e.sq_dur, 0.0, 1.0)
		f = e.sq_pico + (Vector3.ONE - e.sq_pico) * _atras(u)
	var base := Vector3(pj.scale.x / e.aplicada.x, pj.scale.y / e.aplicada.y, pj.scale.z / e.aplicada.z)
	pj.scale = base * f
	e.aplicada = f
	# Inclinación al girar: según el cambio de rumbo por segundo, suavizada.
	var yaw: float = pj.rotation.y
	var giro: float = angle_difference(e.yaw_prev, yaw) / delta
	e.yaw_prev = yaw
	var obj: float = 0.0
	if on and hay_mov and en_suelo:
		obj = clampf(-giro / deg_to_rad(GIRO_REF), -1.0, 1.0) * deg_to_rad(INCLINACION_GIRO)
	e.inclina = lerpf(e.inclina, obj, 1.0 - exp(-delta / maxf(T_INCLINA, 0.001)))
	if absf(e.inclina) < 0.0001 and obj == 0.0:
		e.inclina = 0.0
	pj.rotation.z = e.inclina
	# Frenada: se inclina hacia delante y vuelve (seno).
	var pitch: float = 0.0
	if on and e.t_frenada > 0.0:
		e.t_frenada = maxf(0.0, e.t_frenada - delta)
		pitch = deg_to_rad(FRENADA_INCLINA) * sin(PI * (1.0 - e.t_frenada / maxf(T_FRENADA, 0.01)))
	pj.rotation.x = pitch


## El rastro de la jugadora para la hierba (W2) y las piezas (W5) y el empuje de su marcha. Cada punto vale 1 mientras ella está dentro de su radio; al salir, un seno amortiguado de `T` s.
static func _rastro(j, e: EstCam, vel: float, delta: float, activa: bool) -> void:
	var pos: Vector3 = j.position
	# Quieta, sin rastro y con todo ya mandado: no hay nada que cambiar en los shaders (lo más habitual).
	if e.alimentado and e.rastro.is_empty() and vel < 0.01 and pos == e.pos_alim and activa == e.activa_alim:
		return
	e.alimentado = false
	var h: Hierba3D = _hierba(j.mundo)
	if not activa:
		e.rastro.clear()
		e.rastro_h = []
		e.rastro_p = []
		e.empuje = Vector2.ZERO
		if h != null:
			h.set_apartado([], Hierba3D.APARTAR_RADIO_BASE, Vector2.ZERO)
		Ocluso3D.poner_rastro(pos, 0.0, [])
		e.alimentado = true
		e.pos_alim = pos
		e.activa_alim = false
		return
	var va: float = float(j._vel_andar)
	var vc: float = float(j._vel_correr)
	var k: float = clampf((vel - va * 0.9) / maxf(vc - va, 0.01), 0.0, 1.0)
	var radio_obj: float = lerpf(Hierba3D.APARTAR_RADIO, Hierba3D.APARTAR_RADIO_CORRER, k)
	e.radio_h = lerpf(e.radio_h, radio_obj, 1.0 - exp(-delta * 6.0))
	var rp: float = APARTAR_PIEZAS_RADIO
	var t_h: float = Hierba3D.APARTAR_RETORNO_S
	var t_p: float = APARTAR_PIEZAS_RETORNO_S
	for s in e.rastro:
		var d: float = Vector2(pos.x - (s[0] as Vector3).x, pos.z - (s[0] as Vector3).z).length()
		s[1] = (float(s[1]) + delta) if d > e.radio_h else 0.0
		s[2] = (float(s[2]) + delta) if d > rp else 0.0
	for i in range(e.rastro.size() - 1, -1, -1):
		if float(e.rastro[i][1]) >= t_h and float(e.rastro[i][2]) >= t_p:
			e.rastro.remove_at(i)
	e.t_rastro += delta
	if e.t_rastro >= ESTELA_DT and Vector2(pos.x - e.ultimo_reg.x, pos.z - e.ultimo_reg.z).length() >= ESTELA_PASO:
		e.t_rastro = 0.0
		e.ultimo_reg = pos
		e.rastro.push_front([pos, 0.0, 0.0])
		if e.rastro.size() > 5:
			e.rastro.pop_back()
	e.rastro_h = []
	e.rastro_p = []
	for s in e.rastro:
		var p: Vector3 = s[0]
		e.rastro_h.append(Vector4(p.x, p.y, p.z, peso_muelle(float(s[1]), t_h)))
		e.rastro_p.append(Vector4(p.x, p.y, p.z, peso_muelle(float(s[2]), t_p)))
	var vs: Vector3 = j.vel_suelo
	e.empuje = Vector2(vs.x, vs.z) / maxf(vc, 0.01)
	if e.empuje.length() > 1.0:
		e.empuje = e.empuje.normalized()
	if h != null:
		h.set_apartado(e.rastro_h, e.radio_h, e.empuje)
	Ocluso3D.poner_rastro(pos, rp if APARTAR_PIEZAS_ACTIVO else 0.0, e.rastro_p)
	e.alimentado = absf(e.radio_h - radio_obj) < 0.002
	e.pos_alim = pos
	e.activa_alim = true


## El peso de un punto del rastro `edad` s después de que ella saliera de su radio: 1 al salir, sin pasarse de 0 en un tiempo `t` y con un rebote al otro lado.
static func peso_muelle(edad: float, t: float) -> float:
	if edad <= 0.0:
		return 1.0
	if edad >= t:
		return 0.0
	var u: float = edad / t
	return exp(-3.2 * u) * cos(u * PI * 1.6)


static func _hierba(mundo: Object) -> Hierba3D:
	if mundo == null or not is_instance_valid(mundo):
		return null
	var h: Variant = mundo.get("_hierba")
	if h is Hierba3D and is_instance_valid(h):
		return h as Hierba3D
	return null


# ---------------------------------------------------------------------------------------------------------------------
#  W4 · Agua
# ---------------------------------------------------------------------------------------------------------------------

## Las ondas del agua de la maqueta (null si no hay agua física).
static func _ondas(mundo: Object) -> AguaOndas3D:
	if mundo == null or not is_instance_valid(mundo) or not mundo.has_method("_asegurar_ondas"):
		return null
	return mundo.call("_asegurar_ondas") as AguaOndas3D


static func _onda(j, pos: Vector3, fuerza: float) -> void:
	var o: AguaOndas3D = _ondas(j.mundo)
	if o != null:
		o.impulso(pos, fuerza, ONDA_RADIO)
		cuenta["onda"] = int(cuenta["onda"]) + 1
	else:
		cuenta["onda_sin_agua"] = int(cuenta["onda_sin_agua"]) + 1


## Un paso con los pies en agua poco profunda: onda, tres gotas y un chapoteo bajito más agudo.
static func _paso_agua(j, _correr: bool) -> void:
	var c: Vector2i = Terreno3D.celda_de(j.position)
	var p := Vector3(j.position.x, Terreno3D.superficie_agua(c), j.position.z)
	_onda(j, p, ONDA_PASO)                                              # las ondas son del mundo: no las apaga Sensacion3D.ACTIVA
	if not Sensacion3D.ACTIVA or not AGUA_ACTIVA:
		return
	var e: EstCam = estado(j)
	if e.gotas == null or not is_instance_valid(e.gotas):
		e.gotas = _emisor(j, maxi(GOTAS_PASO, 1), 0.45, Vector2(0.05, 0.09), Vector2(1.2, 2.0), Vector3(0.0, -9.0, 0.0), Vector3.UP, 35.0, _textura("gota"), false, 0.06)
	_disparar(e.gotas, p + Vector3(0.0, 0.05, 0.0), GOTAS_PASO, maxi(GOTAS_PASO, 1), Color(0.7, 0.88, 1.0, 0.9))
	cuenta["gotas"] = int(cuenta["gotas"]) + 1
	_sonido(j, "chapoteo", p, DB_CHAPOTEO_PASO, randf_range(TONO_CHAPOTEO.x, TONO_CHAPOTEO.y))
	cuenta["chapoteo"] = int(cuenta["chapoteo"]) + 1


## Cada fotograma: entrar en el agua desde tierra (onda grande, salpicadura y chapoteo) y, nadando, ondas pequeñas detrás cada T_ONDA_NADO s.
static func _agua(j, e: EstCam, delta: float) -> void:
	e.t_entrada = maxf(0.0, e.t_entrada - delta)
	var c: Vector2i = Terreno3D.celda_de(j.position)
	if c != e.celda_prev:
		e.celda_prev = c
		var en_agua: bool = Terreno3D.en_mapa(c) and Terreno3D.es_agua(c)
		if en_agua and not e.en_agua_prev and e.t_entrada <= 0.0:
			e.t_entrada = 0.5
			var p := Vector3(j.position.x, Terreno3D.superficie_agua(c), j.position.z)
			_onda(j, p, ONDA_ENTRADA)
			if Sensacion3D.ACTIVA and AGUA_ACTIVA:
				var fx: Variant = j.mundo.get("_fx") if j.mundo != null else null
				if fx != null and is_instance_valid(fx) and fx.has_method("salpicadura"):
					fx.call("salpicadura", p, SALPICADURA_ENTRADA)
					cuenta["salpica"] = int(cuenta["salpica"]) + 1
				_sonido(j, "chapoteo", p, Sfx.db_de("chapoteo"), 1.0)
				cuenta["chapoteo"] = int(cuenta["chapoteo"]) + 1
		e.en_agua_prev = en_agua
	if bool(j.nadando):
		e.t_nado -= delta
		if e.t_nado <= 0.0:
			e.t_nado = T_ONDA_NADO
			var dir: Vector3 = j._mirada
			dir.y = 0.0
			var detras: Vector3 = j.position - (dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)) * 0.35
			_onda(j, Vector3(detras.x, Terreno3D.superficie_agua(c), detras.z), ONDA_NADO)
	else:
		e.t_nado = 0.0


# ---------------------------------------------------------------------------------------------------------------------
#  W5 · El mundo responde
# ---------------------------------------------------------------------------------------------------------------------

## ¿Es una pieza del decorado que se mece y se aparta? (arbustos, helechos, hierba alta/crecida/espesa).
static func es_pieza_viva(id: String) -> bool:
	return id.begins_with("arbusto") or id.begins_with("helecho") or id == "hierba_alta" or id == "hierba_crecida" or id == "hierba_espesa"


## `fuerza` de `Ocluso3D.poner_viento` que da VIENTO_PIEZAS (el shader desplaza 0,035 × alto × fuerza en la copa).
static func fuerza_viento_pieza() -> float:
	return VIENTO_PIEZAS / 0.035


## 4/11: qué piezas son árboles para las hojas y el polvo al pasar (los muros llevan pino, árbol viejo y sauce; antes solo «arbol*»).
const PREFIJOS_ARBOL: Array = ["arbol", "pino", "sauce", "abedul"]


static func es_arbol(id: String) -> bool:
	for pre in PREFIJOS_ARBOL:
		if id.begins_with(String(pre)):
			return true
	return false


## Posiciones de los árboles (piezas de PREFIJOS_ARBOL) del decorado de la maqueta, de sus lotes. Se calcula una vez por maqueta.
static func arboles_de(mundo: Object) -> PackedVector3Array:
	if mundo == null or not is_instance_valid(mundo):
		return PackedVector3Array()
	var clave: int = mundo.get_instance_id()
	if _arboles.has(clave):
		return _arboles[clave]
	var r := PackedVector3Array()
	var lotes: Variant = mundo.get("_lotes")
	if lotes is Dictionary:
		for id in (lotes as Dictionary):
			if es_arbol(String(id)):
				for t in ((lotes as Dictionary)[id] as Array):
					r.append((t as Transform3D).origin)
	_arboles[clave] = r
	return r


## El hijo de un bloque de hierba que suelta hojas o motas. NO tiene `_process` (decenas de nodos llamándose cada fotograma cuestan): `Caminar3D.actualizar` llama a `revisar` de todos una vez por segundo
## (`Sensacion3D.ACTIVA`, su interruptor y, las motas, si es de noche).
class ParticulasBloque extends GPUParticles3D:
	var tipo: String = "motas"
	var _noche: bool = false

	func revisar() -> void:
		var quiero: bool = Sensacion3D.ACTIVA and (Caminar3D.MOTAS_ACTIVO if tipo == "motas" else Caminar3D.HOJAS_ACTIVO)
		if tipo == "motas":
			var noche: bool = CicloDia3D.es_noche()
			if noche != _noche:
				_noche = noche
				Caminar3D._motas_dia_noche(self, noche)
		if emitting != quiero:
			emitting = quiero


## Hojas y motas de un bloque de hierba recién creado (`rect`, suelo en `y`): dos nodos como mucho, hijos del bloque (se liberan con él). Hojas solo si hay árboles a menos de 2 u del bloque.
static func decorar_bloque(hierba: Node, bloque: Node3D, rect: Rect2, y: float) -> void:
	if hierba == null or bloque == null or not (MOTAS_ACTIVO or HOJAS_ACTIVO):
		return
	var centro := Vector3(rect.get_center().x, y, rect.get_center().y)
	if MOTAS_ACTIVO:
		var m := ParticulasBloque.new()
		m.name = "Motas"
		m.tipo = "motas"
		_config_motas(m, rect, y)
		bloque.add_child(m)
		m.position = Vector3(centro.x, y + MOTAS_ALTURA, centro.z) - bloque.position
		m.emitting = Sensacion3D.ACTIVA
		m._noche = CicloDia3D.es_noche()
		_motas_dia_noche(m, m._noche)
	if HOJAS_ACTIVO:
		var hay: bool = false
		var inflado: Rect2 = rect.grow(2.0)
		for p in arboles_de(hierba.get_parent()):
			if inflado.has_point(Vector2(p.x, p.z)):
				hay = true
				break
		if hay:
			var hj := ParticulasBloque.new()
			hj.name = "Hojas"
			hj.tipo = "hojas"
			_config_hojas(hj, rect, y, COLOR_HOJAS)
			bloque.add_child(hj)
			hj.position = Vector3(centro.x, y + HOJAS_ALTURA, centro.z) - bloque.position
			hj.emitting = Sensacion3D.ACTIVA


## Una vez por segundo: cada hoja/mota de los bloques mira su interruptor, ACTIVA y si es de noche.
static func _revisar_bloques(j) -> void:
	var h: Hierba3D = _hierba(j.mundo)
	if h == null:
		return
	for b in h.nodos_bloques():
		for nombre in ["Motas", "Hojas"]:
			var n: Node = (b as Node).get_node_or_null(nombre)
			if n is ParticulasBloque:
				(n as ParticulasBloque).revisar()


static var _quad_motas: QuadMesh = null           ## el dibujo es el mismo en todos los bloques: se comparte
static var _quad_hojas: QuadMesh = null


static func _quad_compartido(tex: String) -> QuadMesh:
	var q: QuadMesh = _quad_motas if tex == "destello" else _quad_hojas
	if q == null:
		q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		q.orientation = PlaneMesh.FACE_Z
		q.material = _material_particulas(_textura(tex), false)
		if tex == "destello":
			_quad_motas = q
		else:
			_quad_hojas = q
	return q


static func _material_particulas(tex: Texture2D, aditivo: bool = false) -> StandardMaterial3D:
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if aditivo else BaseMaterial3D.BLEND_MODE_MIX
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.billboard_keep_scale = true
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = tex
	return sm


static func _config_motas(gp: GPUParticles3D, rect: Rect2, _y: float) -> void:
	gp.amount = maxi(MOTAS_DIA, MOTAS_NOCHE)
	gp.lifetime = 6.0
	gp.preprocess = 6.0
	gp.explosiveness = 0.0
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-rect.size.x * 0.5 - 1.0, -1.0, -rect.size.y * 0.5 - 1.0), Vector3(rect.size.x + 2.0, 3.0, rect.size.y + 2.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(rect.size.x * 0.5, 0.15, rect.size.y * 0.5)
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.14
	pm.gravity = Vector3.ZERO
	pm.scale_min = MOTAS_TAM
	pm.scale_max = MOTAS_TAM * 1.4
	gp.process_material = pm
	gp.draw_pass_1 = _quad_compartido("destello")


## De día motas blancas lentas (MOTAS_DIA); de noche luciérnagas amarillas que parpadean (MOTAS_NOCHE).
static func _motas_dia_noche(gp: GPUParticles3D, noche: bool) -> void:
	var pm: ParticleProcessMaterial = gp.process_material as ParticleProcessMaterial
	if pm == null:
		return
	if _ramp_dia == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_ramp_dia = GradientTexture1D.new()
		_ramp_dia.gradient = g
		var gn := Gradient.new()
		gn.offsets = PackedFloat32Array([0.0, 0.1, 0.2, 0.35, 0.5, 0.65, 0.8, 0.9, 1.0])
		gn.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_ramp_noche = GradientTexture1D.new()
		_ramp_noche.gradient = gn
	pm.color_ramp = _ramp_noche if noche else _ramp_dia
	pm.color = Color(1.0, 0.9, 0.4, MOTAS_ALFA * 1.6) if noche else Color(1.0, 1.0, 1.0, MOTAS_ALFA)
	pm.scale_min = MOTAS_TAM * (1.5 if noche else 1.0)
	pm.scale_max = MOTAS_TAM * (2.0 if noche else 1.4)
	var n: int = MOTAS_NOCHE if noche else MOTAS_DIA
	if gp.amount != n:
		gp.amount = n
	var sm: StandardMaterial3D = (gp.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	if sm != null:
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if noche else BaseMaterial3D.BLEND_MODE_MIX


static func _config_hojas(gp: GPUParticles3D, rect: Rect2, _y: float, color: Color) -> void:
	gp.amount = maxi(1, int(round(float(HOJAS_POR_BLOQUE) * T_HOJA_CAIDA / maxf(T_HOJAS_S, 0.1))))
	gp.lifetime = T_HOJA_CAIDA
	gp.preprocess = T_HOJA_CAIDA
	gp.explosiveness = 0.0
	gp.local_coords = false
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gp.visibility_aabb = AABB(Vector3(-rect.size.x * 0.5 - 1.0, -HOJAS_ALTURA - 1.0, -rect.size.y * 0.5 - 1.0), Vector3(rect.size.x + 2.0, HOJAS_ALTURA + 2.0, rect.size.y + 2.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(rect.size.x * 0.5, 0.3, rect.size.y * 0.5)
	pm.direction = Vector3.DOWN
	pm.spread = 15.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3(0.0, -2.0 * HOJAS_ALTURA / (T_HOJA_CAIDA * T_HOJA_CAIDA), 0.0)      # cae HOJAS_ALTURA u en T_HOJA_CAIDA s
	pm.turbulence_enabled = true                                                               # el vaivén
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 2.5
	pm.turbulence_noise_speed = Vector3(0.3, 0.0, 0.3)
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -150.0
	pm.angular_velocity_max = 150.0
	pm.scale_min = HOJA_TAM
	pm.scale_max = HOJA_TAM * 1.3
	pm.color = color
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.85, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	gp.process_material = pm
	gp.draw_pass_1 = _quad_compartido("hoja")


## Corriendo bajo un árbol (a menos de ARBOL_RADIO u): HOJAS_CORRER hojas extra que caen sobre ella. Como mucho una vez cada 1,5 s.
static func hojas_bajo_arbol(j, e: EstCam) -> void:
	if not HOJAS_ACTIVO or e.reloj - e.t_arbol < 1.5:
		return
	var pos: Vector3 = j.position
	var cerca: Vector3 = Vector3.INF
	for p in arboles_de(j.mundo):
		if Vector2(p.x - pos.x, p.z - pos.z).length() < ARBOL_RADIO:
			cerca = p
			break
	if cerca == Vector3.INF:
		return
	e.t_arbol = e.reloj
	if e.hojas == null or not is_instance_valid(e.hojas):
		e.hojas = _emisor(j, maxi(HOJAS_CORRER, 1), T_HOJA_CAIDA, Vector2(HOJA_TAM, HOJA_TAM * 1.3), Vector2(0.0, 0.3), Vector3(0.0, -2.0 * 2.4 / (T_HOJA_CAIDA * T_HOJA_CAIDA), 0.0),
				Vector3.DOWN, 30.0, _textura("hoja"), false, 0.5)
	_disparar(e.hojas, Vector3(pos.x, pos.y + 2.4, pos.z), HOJAS_CORRER, maxi(HOJAS_CORRER, 1), COLOR_HOJAS)
	cuenta["hojas"] = int(cuenta["hojas"]) + 1


## Corriendo a menos de PAJAROS_DIST de un bloque de hierba: con probabilidad PROB_PAJAROS (una tirada por bloque cada PAJAROS_MIN_S s, y no más de una bandada cada PAJAROS_MIN_S s) salen 2-3 pájaros.
static func pajaros_tick(j, e: EstCam) -> void:
	if not PAJAROS_ACTIVO:
		return
	var h: Hierba3D = _hierba(j.mundo)
	if h == null:
		return
	for par in h.bloques_cerca(j.position, PAJAROS_DIST):
		var b: Vector2i = par[0]
		if e.reloj - float(e.tiradas.get(b, -999.0)) < PAJAROS_MIN_S:
			continue
		e.tiradas[b] = e.reloj
		if randf() >= PROB_PAJAROS or e.reloj - e.t_pajaros < PAJAROS_MIN_S:
			continue
		e.t_pajaros = e.reloj
		lanzar_pajaros(j, e, par[1] as Rect2)
		return


## 2-3 siluetas oscuras que salen en arco hacia arriba desde el rincón del bloque más cercano a la jugadora y se desvanecen en PAJAROS_VIDA s; con un trozo corto de `amb_pajaros`.
static func lanzar_pajaros(j, e: EstCam, rect: Rect2) -> void:
	var pos: Vector3 = j.position
	var q := Vector2(clampf(pos.x, rect.position.x, rect.end.x), clampf(pos.z, rect.position.y, rect.end.y))
	var dir := Vector2(rect.get_center().x - q.x, rect.get_center().y - q.y)
	dir = dir.normalized() * 0.8 if dir.length() > 0.01 else Vector2.ZERO
	var desde := Vector3(q.x + dir.x, pos.y + 0.2, q.y + dir.y)
	if e.pajaros == null or not is_instance_valid(e.pajaros):
		if _tex_pajaro == null:
			var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
			img.fill(Color(1, 1, 1, 0))
			for x in range(16):
				var d: float = absf(float(x) - 7.5) / 7.5
				var yy: int = 1 + int(round((1.0 - d) * 3.0))
				img.set_pixel(x, yy, Color(1, 1, 1, 1))
				img.set_pixel(x, yy + 1, Color(1, 1, 1, 1))
			_tex_pajaro = ImageTexture.create_from_image(img)
		e.pajaros = _emisor(j, 3, PAJAROS_VIDA, Vector2(PAJAROS_TAM * 0.9, PAJAROS_TAM * 1.1), Vector2(2.6, 3.6), Vector3(0.0, -1.6, 0.0), Vector3.UP, 38.0, _tex_pajaro, false, 0.3)
	_disparar(e.pajaros, desde, randi_range(2, 3), 3, Color(0.07, 0.07, 0.1, 1.0))
	cuenta["pajaros"] = int(cuenta["pajaros"]) + 1
	_sonido(j, "amb_pajaros", desde, DB_PAJAROS, randf_range(0.95, 1.1), 1.3)
