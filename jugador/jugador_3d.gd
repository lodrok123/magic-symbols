class_name Jugador3D
extends Node3D

## EL JUGADOR DEL TEST 3 (4.3 jugador mínimo, 4.4 altura, 4.4b agua). Dueño: Juego.
##
## No es un modelo nuevo: gobierna al `Pj3D` que PruebaTest2 ya crea (`_jugador`) y le quita el control. Ese nodo sigue
## siendo del Pipeline (el modelo, la escala, la luz); aquí vive lo que el Juego decide: moverse por NIVELES de casilla,
## saltar, nadar, la vida, la muerte y el modo apuntar. Su `position` es la de los pies y se copia a `pj` cada fotograma;
## si algo externo mueve `pj.position` (PruebaTest2.ir_a) se adopta la nueva posición.
##
## Lo monta una sola línea al final de PruebaTest2._ready():   Jugador3D.montar(self)
## (y PruebaTest2 deja de mover al jugador con `externo = true`: ver el diario del 6/10).
##
## ALTURA (4.4). Un nivel = ALTO_NIVEL (un bloque). Se sube a una casilla un nivel más alta SALTANDO; no se puede
## estar a más de MAX_NIVELES_SUBIBLES niveles. Caer no hace daño. Lo que dice cuántos niveles tiene cada casilla es
## Terreno3D.alturas (tierra apilada, columnas de barrera + levitación, cornisas del nivel).
##
## AGUA (4.4b). Si el suelo bajo los pies pasa a ser agua (se derrite el hielo, o se pisa agua) el jugador cae y pasa a
## `nadando`: velocidad x0,4, sin lanzar ni saltar, clip swim_forward (si el modelo no lo tiene, walk), sin daño. Sale
## al tocar una casilla de suelo llano.

const MAX_NIVELES_SUBIBLES: int = 1
## Tope propio de un nivel (0 = sin tope propio: vale MAX_NIVELES_SUBIBLES). Terra Fina lo pone a 2 (tres alturas: pies, pelvis y
## pecho del titán) y lo suelta al salir; así Bosque y los hechizos siguen con 1.
static var tope_niveles_nivel: int = 0
const GRAVEDAD: float = 22.0
const VEL_SALTO: float = 8.4
const TOLERANCIA_SUELO: float = 0.55        ## desnivel que se camina sin saltar (de puente a suelo, escalón)
const TOLERANCIA_AIRE: float = 0.35         ## lo que una casilla puede estar por encima de tus pies en el aire
const MULT_NADO: float = 0.4
## NADO DESACTIVADO DE MOMENTO (Pablo, 16/10): nadar se salta los puzles del tronco (el río del Bosque 01 se cruza con el tronco-puente y el estanque
## con el tronco del estanque). Con false el jugador NO entra al agua andando: el agua se comporta como una pared. Sigue funcionando el nado si algo lo
## mete dentro (el hielo que se derrite bajo los pies, el agua que sube) para que no quede atrapado. Para probar el nado o un nivel que lo quiera:
## `Jugador3D.nado_permitido = true`.
static var nado_permitido: bool = false
const TASA_TREPAR: float = 3.5              ## u/s al salir trepando de un foso (cauce hondo / cuenca): 0,94 u en ~0,27 s
const HUNDIDO: float = 0.35               ## 6.8: los pies quedan a ALTO_AGUA - 0,35 (flota en la superficie)
const INVULNERABLE: float = 0.7
const TICK_VENENO: float = 0.5               ## s entre dos pulsos del veneno (envenenar)
const TIEMPO_REAPARECER: float = 2.2
const T_GOLPE: float = 0.35
const T_LANZAR: float = 0.9
## --- 6.6 Voltereta: ≤ 1 casilla, colisiona paso a paso, sin daño mientras dura, reutilización larga ---
const TIEMPO_VOLTERETA: float = 4.0          ## segundos hasta poder repetirla
const DIST_VOLTERETA: float = 1.0            ## casillas
## --- 6.7 Beber poción: bloqueado mientras bebe; cura al terminar; un golpe la interrumpe ---
const T_BEBER: float = 1.5
const CURA_POCION: float = 40.0
## --- 11.13 Hielo: resbala. Sobre agua helada la velocidad no sigue al teclado al instante: se acerca a ella poco a poco ---
const HIELO_ACEL: float = 3.0                ## u/s² con las teclas puestas (andar = 1,6 u/s: ~0,5 s en alcanzarlo)
const HIELO_FRENO: float = 0.9               ## u/s² sin teclas: cuesta frenar (de 1,6 u/s patinas ~1,4 u)
const HIELO_GIRO: float = 0.35               ## el giro de la mirada va a esta fracción de lo normal

## --- 27/10 Empujar bloques (docs/EMPUJAR_BLOQUES.md) ---
const T_EMPUJAR: float = 0.35                ## s apretando contra un bloque pegado antes de que ceda
const EMPUJE_CARDINAL: float = 0.8           ## componente mínima (de la dirección normalizada) para contar como «hacia una cara»: la diagonal (0,71) no empuja
const EMPUJE_PEGADA: float = 0.3             ## × casilla: lo que hay que haberse adelantado desde el centro de su casilla hacia el bloque (a ≤ 0,7 · S de su centro)
const VEL_CLIP_CARGA: float = 0.4           ## velocidad del clip `empujar` mientras carga los T_EMPUJAR s sin moverse (se lee el esfuerzo)
const ZANCADA_EMPUJAR: float = 0.9          ## u/s de suelo por cada 1,0 de velocidad del clip `empujar` (ESTIMADO, afinar a ojo; como walk x1,6 = 1,6 u/s en commit 93fd42f7): la velocidad del clip = la real del bloque / esto

signal murio
signal reaparecio
signal nado_cambiado(nadando: bool)
signal vida_cambiada(vida: float, maxima: float)

var pj: Pj3D = null
var mundo: Node3D = null
var lanz: Lanzador3D = null
var tinta: Tinta = Tinta.new()               ## el maná (15/10): lo gasta el Lanzador3D al soltar, lo pinta `_actualizar_hud`

var vida: float = 100.0
var muerto: bool = false
var nadando: bool = false
var en_suelo: bool = true
var bloqueado: bool = false
var salto_activo: bool = true         ## R4 (17/10): false = Espacio no salta (el laboratorio de recetas usa Espacio para lanzar)
var vy: float = 0.0
var puntos_inicio: Vector3 = Vector3.ZERO
## La pantalla de «Has muerto» (Fase 14.3). Si existe, ella decide cuándo reaparece el jugador; si no, reaparece solo a los TIEMPO_REAPARECER.
var pantalla_muerte: PantallaMuerte = null

var _mirada: Vector3 = Vector3(0, 0, 1)
var _empuje: Vector3 = Vector3.ZERO
var _t_lanzar: float = 0.0
var _lanzando: bool = false
var _t_golpe: float = 0.0
var _t_inv: float = 0.0
var _veneno_t: float = 0.0                       ## s que le quedan de veneno (envenenar)
var _veneno_dps: float = 0.0
var _veneno_tick: float = 0.0
var _t_muerte: float = 0.0
var _ultima: Vector3 = Vector3.ZERO
var _salto_antes: bool = false
var _vel_andar: float = 1.6
var _vel_correr: float = 3.0
var _hud_texto: Label = null
## 24/10: la vida, los frascos y la barra de tinta y el consumible equipado (Q/R) los pinta y gestiona `HudEoW` (presentacion/ui/hud_eow.gd); antes eran aquí dos barras de ColorRect.
var hud_eow: HudEoW = null
var _t_sin_combate: float = 99.0             ## s desde el último golpe recibido: con menos de TINTA_COMBATE s la tinta se recupera más despacio
var _f7_previa: bool = false
const TINTA_COMBATE: float = 6.0
const Y_BARRAS: float = 80.0                 ## px desde arriba donde empiezan la barra de vida y la de tinta
var _trepando: bool = false                  ## cauce hondo: está saliendo de un foso (sube a TASA_TREPAR hasta pisar el suelo)
var caidas_al_agua: int = 0
var saltos: int = 0
var _t_roll: float = 0.0                     ## lo que queda de voltereta (0 = no ruedas)
var _roll_dir: Vector3 = Vector3.ZERO
var _roll_vel: float = 0.0
var _roll_cd: float = 0.0                    ## reutilización
var _roll_previa: bool = false
var _t_beber: float = 0.0
var _beber_previa: bool = false
var _t_gesto: float = 0.0                    ## lo que queda de un gesto (`gesto()`: agacharse, ofrecer, saludo...); 0 = no hay
## true mientras el jugador EMPUJA un bloque (`BloqueEmpujable3D`, 27/10): al andar suena el clip `empujar` (bucle, sin avance) en vez de `walk`/`run`. Lo calcula `_gestionar_empuje` cada fotograma: es true
## mientras anda con dirección cardinal contra un bloque pegado a ella (aunque no se mueva: así se lee «está atascado») y mientras va ACOPLADA a él moviéndose (su posición la marca el bloque); false al soltar,
## al alejarse o si nada/lanza/rueda/hace un gesto. A los `T_EMPUJAR` s de empujar llama a `bloque.empujar(dir)`.
var empujando: bool = false
var _t_empuje: float = 0.0                   ## s que lleva apretando contra el bloque
var _bloque_empuje: Node = null              ## el bloque que empuja (o que acaba de soltar y aún resbala)
var _dir_empuje: Vector2i = Vector2i.ZERO
var _acoplada: bool = false                 ## el bloque que empuja se mueve y su posición manda la de ella
var _dist_empuje: float = 0.0                ## u entre ella y el centro del bloque al acoplarse (se mantiene)
var _lat_empuje: float = 0.0                 ## su coordenada lateral al acoplarse (la entrada lateral se ignora)
var _vel_clip_empuje: float = 1.0            ## velocidad del clip `empujar` (la pone `_gestionar_empuje`, la usa `_animar`)
var _f8_previa: bool = false
## 28/10 · C1 GOLPE CUERPO A CUERPO (tecla F, `GolpeCuerpo`): lo que queda del golpe (0 = no hay), la reutilización, la tecla de antes, el retardo hasta el impacto y si ya salió. `_t_golpe` NO es esto: es el golpe RECIBIDO.
var _t_pegar: float = 0.0
var _pegar_cd: float = 0.0
var _pegar_previa: bool = false
var _pegar_retardo: float = 0.0
var _pegar_hecho: bool = true
var _pegar_dir: Vector3 = Vector3(0, 0, 1)
var ultimo_golpe_cuerpo: Dictionary = {}     ## el resumen del último golpe (GolpeCuerpo.impactar); lo lee la prueba
signal golpe_cuerpo_dado(resumen: Dictionary)
## 28/10 · C4: rodó a tiempo bajo un aviso (C3) y ganó el tiempo bruja (`TiempoBruja`). `aviso` es el AvisoAtaque3D esquivado.
signal esquiva_perfecta(aviso: AvisoAtaque3D)
var esquivas_perfectas: int = 0
var _director: Node = null                 ## Sensacion3D.DirectorSensacion (lote 3)
## Gamefeel (28/10, `Sensacion3D`): s que le quedan congelada (el hitstop compartido de sus golpes y el de recibir uno) y la voltereta pulsada cuando aún no podía rodar.
var _t_hitstop: float = 0.0
var _roll_guardado: float = 0.0
var _roll_guardado_mov: Vector3 = Vector3.ZERO
var _vel_hielo: Vector3 = Vector3.ZERO       ## velocidad real sobre el hielo (u/s); fuera del hielo es la del teclado
## 29/10 (gamefeel lote 4): la velocidad de andar REAL (u/s) con el arranque y la frenada de `Sensacion3D.velocidad_suelo` (fuera del hielo; en el hielo, `_vel_hielo`).
## `corriendo` es lo que la cámara lee para adelantarse más.
var vel_suelo: Vector3 = Vector3.ZERO
var corriendo: bool = false

## --- Sonido (Sfx3D): pasos, río y oyente. Todo en `_actualizar_sonido` y `_sonar_pasos`, más abajo. ---
const DIST_PASO_ANDAR: float = 0.85          ## u recorridas entre dos pasos andando (a 1,6 u/s: ~1,9 pasos por segundo)
const DIST_PASO_CORRER: float = 1.1          ## corriendo (a 3 u/s: ~2,7 pasos por segundo)
const RADIO_AGUA_CASILLAS: int = 4           ## a cuántas casillas de agua empieza a oírse el río
const DB_AGUA: float = -8.0                  ## volumen del río con el agua pegada (estimado, no medido en el juego)
var _dist_paso: float = 0.0
var _oyente: AudioListener3D = null
var _rio: AudioStreamPlayer = null
var _t_rio: float = 0.0
var _vol_rio: float = 0.0
var _vol_rio_obj: float = 0.0


## Lo monta todo: Lanzador3D, Jugador3D, los goblins con Combate3D, las mediciones y la vida en pantalla.
## Devuelve null si el mundo no tiene jugador.
static func montar(p_mundo: Node3D) -> Jugador3D:
	var modelo: Pj3D = p_mundo.get("_jugador")
	if modelo == null:
		push_warning("Jugador3D.montar: el mundo no tiene jugador (_jugador)")
		return null
	Lanzador3D.configurar(p_mundo)
	var j := Jugador3D.new()
	j.name = "Jugador3D"
	j.mundo = p_mundo
	j.pj = modelo
	j.position = modelo.position
	j.puntos_inicio = modelo.position
	j._ultima = modelo.position
	var k: Dictionary = p_mundo.get_script().get_script_constant_map()
	j._vel_andar = float(k.get("VEL_ANDAR", 1.6))
	j._vel_correr = float(k.get("VEL_CORRER", 3.0))
	j.vida = Estado.i().vida_max
	p_mundo.add_child(j)
	p_mundo.set("externo", true)

	var l := Lanzador3D.new()
	l.name = "Lanzador3D"
	l.mundo = p_mundo
	l.fx = p_mundo.get("_fx")
	l.jugador = j
	l.tinta = j.tinta
	l.camara = p_mundo.get("_camara")
	j.lanz = l
	p_mundo.add_child(l)
	l.construir_interfaz()
	if l.fx != null:
		# H4: el impacto pasa por el Lanzador, que descarta agua/hielo sobre casillas elevadas y luego llama a
		# PruebaTest2._al_impactar y a su propio al_impactar (el orden de siempre). Se sustituye la conexion del mundo.
		var directo := Callable(p_mundo, "_al_impactar")
		if l.fx.impacto.is_connected(directo):
			l.fx.impacto.disconnect(directo)
			l.fx.impacto.connect(l.impacto_filtrado)
		else:
			l.fx.impacto.connect(l.al_impactar)     # el mundo no la habia conectado: no se duplica nada

	# Los objetos del Pipeline (Reactivo3D) nacen sin capa (layer 0) hasta que existe el Lanzador: se les da CAPA_REACTIVO.
	for n in p_mundo.get_tree().get_nodes_in_group("reactivo3d"):
		if n is CollisionObject3D:
			(n as CollisionObject3D).collision_layer |= Lanzador3D.CAPA_REACTIVO
	Lanzador3D.colocar_barreras(p_mundo)
	Terreno3D.calcular_huellas(p_mundo)
	PlayLog.nueva_partida()
	PlayLog3D.montar(p_mundo, l)
	for g in (p_mundo.get("_goblins") as Array):
		if (g as Pj3D).id == Gatopedro3D.ID_MODELO:
			Gatopedro3D.equipar_gatopedro(g as Pj3D, p_mundo, j, l)      # el lince enemigo huye en vez de atacar
		else:
			Combate3D.equipar(g as Pj3D, p_mundo, j, l)
	# C2 (28/10): las reacciones de combo contra enemigos devuelven tinta (`TintaReaccion`, cuelga del Mundo3D de la maqueta)
	TintaReaccion.conectar(p_mundo.get("_mundo") as Mundo3D, j.tinta)
	j._construir_hud()
	j.pantalla_muerte = PantallaMuerte.new()
	j.pantalla_muerte.name = "PantallaMuerte"
	p_mundo.add_child(j.pantalla_muerte)
	return j


## =====================================================================================================
##  Lo que pregunta Lanzador3D
## =====================================================================================================

## C4: en el tiempo bruja se puede lanzar aunque aún esté rodando (lanzar corta la voltereta: `apuntar_en_marcha`, `bloquear`).
## Gamefeel (28/10): la congela `t` s (no se acorta si ya lo estaba más). Lo piden `Combate3D` (hitstop compartido de sus golpes) y `Sensacion3D.dano_recibido`.
func hitstop(t: float) -> void:
	if t > _t_hitstop and not muerto:
		_t_hitstop = t


## Gamefeel (28/10): ¿no puede lanzar solo por algo que acaba enseguida (rueda, golpea, encaja un golpe, el clip de lanzar)? Entonces `Lanzador3D` guarda la tecla de página
## un momento en vez de negarla.
func ocupada_un_momento() -> bool:
	return not muerto and (_t_roll > 0.0 or _t_pegar > 0.0 or _t_golpe > 0.0 or _lanzando or _t_hitstop > 0.0)


func puede_lanzar() -> bool:
	return not muerto and not nadando and en_suelo and mundo.get("_velo") == null and (_t_roll <= 0.0 or TiempoBruja.activa()) and _t_beber <= 0.0 and _t_gesto <= 0.0 and _t_pegar <= 0.0


func bloquear(b: bool) -> void:
	bloqueado = b
	_empuje = Vector3.ZERO
	if b:
		_t_roll = 0.0                             # C4: apuntar en el tiempo bruja corta la voltereta


## 27/10 · A1 (lanzamiento rápido): `true` mientras se mantiene 1/2/3. NO bloquea: la jugadora anda con WASD a paso normal, pero sin correr, saltar ni rodar, y no gira hacia donde camina sino hacia donde apunta
## (lo hace `Lanzador3D` con `mirar_hacia` cada fotograma): anda «de lado» con el clip de andar. Quieta se queda en la pose de apuntar. Lo pone y quita `Lanzador3D`.
var apuntando_rapido: bool = false


func apuntar_en_marcha(b: bool) -> void:
	apuntando_rapido = b
	if b:
		_t_roll = 0.0                             # C4: apuntar en el tiempo bruja corta la voltereta


## Entra en el modo apuntar: la elfa pone el clip de lanzar de la forma y las motas del elemento en la mano (Pj3D.lanzar,
## del Pipeline) y sigue animada a velocidad normal aunque el mundo vaya al 70 %.
func apuntar_lanzar(elemento: String, _forma: String, ralentizado: float) -> void:
	# 6.2: mientras se apunta se SOSTIENE readandwrite en bucle (una forma vacía no está en ANIM_CAST: Pj3D usa "leer") y
	# las motas del elemento en la mano. El clip de la forma (`cast`) sale solo al soltar (lanzar_clip).
	pj.apuntar()                                   # 6.11: libro en las manos + readandwrite sostenido
	pj.set_velocidad_animacion(1.0 / maxf(ralentizado, 0.1))


## Sale del modo apuntar (al soltar o al cancelar): vuelve a idle. Si se soltó, lanzar_clip vuelve a poner el clip.
## `lanzando` true = se sale del apuntado PARA LANZAR: el libro se queda en la mano (T-CP1: no vuelve al cinto hasta que acabe el lanzamiento).
func terminar_apuntar(lanzando: bool = false) -> void:
	pj.set_velocidad_animacion(1.0)
	pj.soltar_lanzar(not lanzando)
	_lanzando = false


func mirar_hacia(dir: Vector3) -> void:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		return
	_mirada = d.normalized()
	pj.mirar(_mirada, 0.08)


func mirada() -> Vector3:
	return _mirada


## Al soltar: el clip de la forma (Pj3D.ANIM_CAST, o readandwrite) y las motas, lo que dure el clip (entre 0,5 y 1,4 s).
## T-CP1: con `punto` (id de CastPoints) el clip es el del cast point (recortado, a su velocidad, con el libro en la mano que toca) y `_t_lanzar` dura
## lo que dura ese recorte; el disparo lo espera `Lanzador3D` mirando `fraccion_cast()`.
func lanzar_clip(elemento: String, forma: String, punto: String = "") -> void:
	pj.mirar(_mirada, 1.0)
	var d_punto: float = pj.lanzar(forma, elemento, punto)      # pone las motas del elemento y el clip de la forma (en bucle)
	if pj.cast_activo():
		_t_lanzar = clampf(d_punto, 0.4, 4.0)
		_lanzando = true
		return
	# 6.2: el clip de la forma se reproduce UNA vez entera y el jugador espera a que acabe antes de volver a idle.
	var rol: String = String(Pj3D.ANIM_CAST.get(forma, "leer"))
	if pj.duracion(rol) <= 0.0:
		rol = "leer"
	pj.animacion_actual = ""
	pj.jugar(rol, true)
	var dur: float = pj.duracion(rol)
	_t_lanzar = clampf(dur if dur > 0.0 else T_LANZAR, 0.4, 2.5)
	_lanzando = true
	PlayLog.event("cast_clip", {"forma": forma, "clip": rol, "duracion": snappedf(_t_lanzar, 0.01)})


func y_pies_actual() -> float:
	var c: Vector2i = Terreno3D.celda_de(position)
	return Terreno3D.alto_agua if nadando else Terreno3D.y_pies(c)


## ¿Está el jugador en esa casilla? Impide construir tierra debajo de él.
func ocupa(c: Vector2i) -> bool:
	return Terreno3D.celda_de(position) == c


func nivel_actual() -> int:
	return Terreno3D.altura_en(Terreno3D.celda_de(position))


## =====================================================================================================
##  Vida
## =====================================================================================================

## VENENO (28/10, E2: la bola del chamán): `dps` de daño por segundo durante `segundos`, en pulsos de TICK_VENENO s, sin la invulnerabilidad ni el empuje de un golpe (se queda el más fuerte).
func envenenar(dps: float, segundos: float) -> void:
	if muerto:
		return
	_veneno_dps = maxf(_veneno_dps if _veneno_t > 0.0 else 0.0, dps)
	_veneno_t = maxf(_veneno_t, segundos)
	_veneno_tick = minf(_veneno_tick, TICK_VENENO) if _veneno_tick > 0.0 else TICK_VENENO


func recibir_dano(cantidad: float, desde: Vector3 = Vector3.ZERO) -> void:
	if muerto or _t_inv > 0.0 or cantidad <= 0.0:
		return
	if lanz != null and lanz.absorber_golpe(cantidad, desde):
		return                                   # la barrera cúpula lo ha parado (6.3)
	if hud_eow != null and hud_eow.consumibles.absorber(cantidad):
		return                                   # 24/10: el Bálsamo protector se come el golpe (y se acaba)
	if _t_beber > 0.0:
		_cancelar_beber()                       # 6.7: si te golpean mientras bebes, no curas
	_t_gesto = 0.0                              # un golpe corta el gesto (la animación de golpe lo sustituye)
	_t_pegar = 0.0                              # y el golpe cuerpo a cuerpo que estuviera dándose (si no había salido, no sale)
	vida = maxf(0.0, vida - cantidad)
	_t_inv = INVULNERABLE
	_t_sin_combate = 0.0
	_t_golpe = T_GOLPE
	Combate3D.flotante(mundo, position + Vector3(0, 1.6, 0), str(int(round(cantidad))), Color(1, 0.4, 0.35))
	var d: Vector3 = position - desde
	d.y = 0.0
	if desde != Vector3.ZERO and d.length() > 0.01:
		push(d.normalized(), 4.5)
	PlayLog.event("dano_jugador", {"cantidad": cantidad, "vida": vida})
	vida_cambiada.emit(vida, Estado.i().vida_max)
	if vida <= 0.0:
		_morir()
	else:
		pj.animacion_actual = ""
		pj.jugar("hit")
		Sensacion3D.dano_recibido(self, cantidad)     # gamefeel: viñeta roja, temblor y un hitstop corto


func curar(cantidad: float) -> void:
	vida = minf(Estado.i().vida_max, vida + cantidad)
	vida_cambiada.emit(vida, Estado.i().vida_max)


## Contrato push: viento y atracción (y los golpes de los goblins) empujan a quien lo implemente.
## `fuerza` llega en unidades del 2D (2600 el viento): se baja a metros por segundo del 3D.
func push(direccion: Vector3, fuerza: float) -> void:
	var d := Vector3(direccion.x, 0.0, direccion.z)
	if d.length() < 0.01 or muerto:
		return
	var f: float = fuerza * 0.0036 if fuerza > 100.0 else fuerza
	_empuje += d.normalized() * f
	if f >= Sensacion3D.EMPUJE_POLVO_JUGADORA and en_suelo and not nadando:
		Sensacion3D.polvo(mundo, position, Sensacion3D.POLVO_EMPUJE)       # gamefeel lote 2


## T-CP1: cómo va el clip del cast point (0 en el recorte de inicio, 1 en el de fin; -1 si no hay), lo que tarda en llegar a su instante y dónde nace el hechizo.
func fraccion_cast() -> float:
	return pj.fraccion_clip()


func tiempo_instante_cast() -> float:
	return pj.tiempo_instante()


func punto_cast() -> String:
	return pj.punto_activo()


func posicion_punto_cast(origen: String, dir: Vector3) -> Vector3:
	return pj.posicion_punto(origen, dir)


func _morir() -> void:
	TiempoBruja.terminar(lanz)
	_t_roll = 0.0
	_t_pegar = 0.0
	_t_beber = 0.0
	_t_gesto = 0.0
	muerto = true
	nadando = false
	_lanzando = false
	vel_suelo = Vector3.ZERO
	pj.soltar_lanzar()
	_t_muerte = TIEMPO_REAPARECER
	if lanz != null and lanz.modo_lanzar:
		lanz.call("_cancelar_modo")
	Jugador3D.una_vez(pj, "death")
	PlayLog.event("muerte", {"celda": [Terreno3D.celda_de(position).x, Terreno3D.celda_de(position).y]})
	murio.emit()
	if pantalla_muerte != null and is_instance_valid(pantalla_muerte):
		_t_muerte = 1.0e9                         # reaparece cuando la pantalla de muerte termina su secuencia
		pantalla_muerte.mostrar(self)
	elif lanz != null:
		lanz.avisar("Has caído", Color(1, 0.5, 0.45))


func reaparecer() -> void:
	vel_suelo = Vector3.ZERO
	muerto = false
	nadando = false
	vida = Estado.i().vida_max
	tinta.rellenar()                         # al reaparecer, tinta llena
	position = puntos_inicio
	vy = 0.0
	en_suelo = true
	_empuje = Vector3.ZERO
	_t_inv = 1.2
	pj.animacion_actual = ""
	pj.jugar("idle")
	PlayLog.event("reaparece")
	vida_cambiada.emit(vida, Estado.i().vida_max)
	reaparecio.emit()
	if lanz != null:
		lanz.avisar("Reapareces", Color(0.7, 1, 0.8))


## Reproduce un clip UNA vez y lo deja en su último fotograma (muerte, golpe final). A1: lo hace el árbol de animación (estado sin bucle, que se queda
## en el último fotograma); antes se dejaba el clip en bucle y un temporizador pausaba el AnimationPlayer justo antes de que acabara.
static func una_vez(pj_: Pj3D, nombre: String) -> void:
	pj_.animacion_actual = ""
	pj_.jugar(nombre, true)


## =====================================================================================================
##  Movimiento por niveles
## =====================================================================================================

func _process(delta: float) -> void:
	if mundo == null or pj == null or not is_instance_valid(pj):
		return
	if _director == null or not is_instance_valid(_director):
		_director = Sensacion3D.director(self)      # gamefeel lote 3: flechas de avisos fuera de pantalla y música de combate
	# C4: en el tiempo bruja el mundo va a 0,3 y ella a su paso: su reloj y su animación se dividen por la escala.
	TiempoBruja.actualizar(lanz, delta)
	var comp: float = TiempoBruja.compensacion()
	delta *= comp
	if _t_hitstop > 0.0:
		# Gamefeel: congelada un instante (su golpe ha conectado, o le han dado): ni se mueve ni se anima.
		_t_hitstop = maxf(0.0, _t_hitstop - delta)
		pj.set_vel_tiempo(0.0)
		return
	pj.set_vel_tiempo(comp)
	if pj.position.distance_to(_ultima) > 0.05:
		position = pj.position              # lo han movido desde fuera (ir_a)
		vy = 0.0
	_t_lanzar = maxf(0.0, _t_lanzar - delta)
	if _lanzando and _t_lanzar <= 0.0:
		_lanzando = false
		pj.soltar_lanzar()                  # quita las motas y vuelve a idle
	_t_golpe = maxf(0.0, _t_golpe - delta)
	_t_inv = maxf(0.0, _t_inv - delta)
	if _veneno_t > 0.0 and not muerto:
		_veneno_t -= delta
		_veneno_tick -= delta
		if _veneno_tick <= 0.0:
			_veneno_tick = TICK_VENENO
			vida = maxf(0.0, vida - _veneno_dps * TICK_VENENO)
			Combate3D.flotante(mundo, position + Vector3(0, 1.6, 0), str(int(ceil(_veneno_dps * TICK_VENENO))), Color(0.55, 0.9, 0.35), 0.8)
			vida_cambiada.emit(vida, Estado.i().vida_max)
			if vida <= 0.0:
				_morir()
	_t_sin_combate += delta
	tinta.actualizar(delta, _t_sin_combate < TINTA_COMBATE)
	# F7: cambia de pigmento (comando de prueba hasta que haya recetas y mochila de pigmentos). F8 no: es "detener" en el editor de Godot.
	var f7: bool = Input.is_key_pressed(KEY_F7)
	if f7 and not _f7_previa:
		tinta.siguiente_pigmento()
		if lanz != null:
			lanz.avisar("Pigmento: %s" % tinta.nombre_pigmento(), tinta.color())
	_f7_previa = f7
	_roll_cd = maxf(0.0, _roll_cd - delta)
	_pegar_cd = maxf(0.0, _pegar_cd - delta)
	if _t_pegar > 0.0:
		_t_pegar = maxf(0.0, _t_pegar - delta)
		if not _pegar_hecho and (_t_pegar <= GolpeCuerpo.DUR - _pegar_retardo or _t_pegar <= 0.0):
			_impactar_golpe()
		if _t_pegar <= 0.0:
			pj.animacion_actual = ""              # el golpe acabó: el siguiente `_animar` vuelve a idle / andar
	if _t_beber > 0.0:
		_t_beber = maxf(0.0, _t_beber - delta)
		if _t_beber <= 0.0:
			_terminar_beber()
	if _t_gesto > 0.0:
		_t_gesto = maxf(0.0, _t_gesto - delta)
		if _t_gesto <= 0.0:
			pj.animacion_actual = ""              # el gesto acabó: el siguiente `_animar` vuelve a idle / andar
	if _t_roll > 0.0:
		_t_roll = maxf(0.0, _t_roll - delta)

	if muerto:
		_t_muerte -= delta
		empujando = false
		_acoplada = false
		if _t_muerte <= 0.0:
			reaparecer()
		_sincronizar()
		_actualizar_hud()
		return

	var entrada := Vector2.ZERO
	var libre: bool = not bloqueado and mundo.get("_velo") == null and not get_tree().paused \
			and not (lanz != null and lanz.libro_abierto())     # con el libro abierto el tiempo corre, pero tú estás escribiendo
	if libre:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			entrada.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			entrada.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			entrada.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			entrada.y += 1.0
	var correr: bool = libre and not apuntando_rapido and Input.is_key_pressed(KEY_SHIFT)     # A1: apuntando de pie-andando no se corre ni se salta
	var salto: bool = libre and not apuntando_rapido and salto_activo and Input.is_key_pressed(KEY_SPACE)
	# Las teclas son de PANTALLA: W = «hacia arriba» como la ve el jugador, sea cual sea el giro de la cámara (Q/E, de 90° en 90°).
	# Se gira el vector de entrada lo mismo que la cámara; así la tecla que lleva hacia donde mira el personaje en pantalla
	# sigue siendo la misma al girarla. Mismo cálculo que el mover propio de la maqueta (PruebaTest2._process): la voltereta,
	# la mirada y la animación parten de este `mov` ya girado, así que ahí no hay que tocar nada.
	var mov := Vector3(entrada.x, 0.0, entrada.y).normalized().rotated(Vector3.UP, deg_to_rad(_giro_camara()))
	_gestionar_acciones(libre, mov)
	var vel: float = (_vel_correr if correr else _vel_andar) * (MULT_NADO if nadando else 1.0)
	if _t_golpe > 0.0 or _t_beber > 0.0 or _lanzando or _t_gesto > 0.0 or _t_pegar > 0.0:
		mov = Vector3.ZERO           # el golpe te frena; beber, el clip de lanzar (6.2b) y los gestos (agacharse...) te dejan quieto hasta que acaban
	var objetivo: Vector3 = mov * vel
	var en_hielo: bool = not nadando and _t_roll <= 0.0 and Terreno3D.sobre_hielo(position)
	corriendo = correr and mov != Vector3.ZERO
	if en_hielo:
		_vel_hielo = Jugador3D.velocidad_hielo(_vel_hielo, objetivo, delta)
		vel_suelo = _vel_hielo
	else:
		# Gamefeel lote 4: andar arranca y frena en un suspiro (ACEL_SUELO / FRENO_SUELO); con la sensación apagada es `objetivo` tal cual, como siempre.
		vel_suelo = Sensacion3D.velocidad_suelo(vel_suelo, objetivo, delta) if (en_suelo and not nadando and _t_roll <= 0.0 and not _acoplada) else objetivo
		_vel_hielo = vel_suelo                   # al salir del hielo vuelve lo normal (y al entrar conserva lo que llevabas)
	var paso: Vector3 = (_vel_hielo if en_hielo else vel_suelo) * delta + _empuje * delta
	if _t_roll > 0.0:
		mov = Vector3.ZERO
		paso = _roll_dir * _roll_vel * delta       # voltereta: sustituye al andar
	var acoplada: bool = _gestionar_empuje(delta, mov)
	if acoplada:
		paso = Vector3.ZERO                       # la posición la marca el bloque (ya puesta): no se anda
		mov = Vector3(float(_dir_empuje.x), 0.0, float(_dir_empuje.y))      # solo para mirar y animar hacia donde empuja
	_empuje = _empuje.lerp(Vector3.ZERO, clampf(7.0 * delta, 0.0, 1.0))
	if paso.length() > 0.0001:
		var antes: Vector3 = position
		_mover_con_choque(paso)
		if mov != Vector3.ZERO and not acoplada:
			_sonar_pasos(position.distance_to(antes), correr)
		if _t_roll > 0.0 and position.distance_to(antes) < 0.0001:
			_t_roll = 0.0                           # choca con algo: la voltereta se acaba ahí
		if en_hielo and position.distance_to(antes) < paso.length() * 0.25:
			_vel_hielo = Vector3.ZERO               # choca contra algo: se para (si no, seguiría empujando la pared)
	if mov != Vector3.ZERO:
		if not apuntando_rapido:                       # A1: apuntando, la mirada la manda el Lanzador (hacia el ratón), no el rumbo
			_mirada = mov
			pj.mirar(mov, delta * (HIELO_GIRO if en_hielo else 1.0))
		if mundo.has_method("marcar_pisado") and not nadando:
			mundo.call("marcar_pisado", Terreno3D.celda_de(position), 0.35)

	_vertical(delta, salto)
	_animar(mov, correr)
	_actualizar_sonido(delta)
	_sincronizar()
	_actualizar_hud()


## 27/10 · EMPUJAR BLOQUES (28/10: con PESO). Con `mov` (ya en coordenadas del mundo: es el vector de las teclas girado con la cámara) hacia una cara (componente dominante ≥ `EMPUJE_CARDINAL`), en suelo y sin
## nadar, lanzar, rodar ni hacer un gesto, si la casilla vecina en esa dirección tiene un bloque (grupo `empujable`) y ella está pegada a él (adelantada ≥ `EMPUJE_PEGADA` · casilla desde el centro de la
## suya), cuenta el tiempo apretando (el clip `empujar` va lento, `VEL_CLIP_CARGA`, para que se lea el esfuerzo); a los `T_EMPUJAR` s llama a `bloque.empujar(dir, true)`. `empujando` queda true mientras
## empuja (haya cedido o no: un bloque atascado se lee como «no puedo»). Si el bloque se mueve, ella queda ACOPLADA: su posición la marca el bloque (detrás de su cara, a la distancia a la que estaba pegada,
## con su posición lateral de entonces) y no su velocidad de andar; mientras siga apretando hacia donde va el bloque le avisa (`sostener`) para que ENCADENE casillas; al soltar, el bloque acaba la
## casilla frenando y ella se para con él. El hielo solo la lleva media casilla. Devuelve true si está acoplada este fotograma (entonces `_process` no la mueve).
func _gestionar_empuje(delta: float, mov: Vector3) -> bool:
	var dir: Vector2i = Vector2i.ZERO
	var libre_de_accion: bool = en_suelo and not nadando and _t_roll <= 0.0 and not _lanzando and _t_gesto <= 0.0 and _t_beber <= 0.0 and _t_golpe <= 0.0 and _t_pegar <= 0.0 \
			and not (lanz != null and lanz.modo_lanzar)
	if libre_de_accion and mov != Vector3.ZERO:
		var m := Vector2(mov.x, mov.z)
		if absf(m.x) >= EMPUJE_CARDINAL * m.length():
			dir = Vector2i(1 if m.x > 0.0 else -1, 0)
		elif absf(m.y) >= EMPUJE_CARDINAL * m.length():
			dir = Vector2i(0, 1 if m.y > 0.0 else -1)
	# Acoplada a un bloque en marcha: lo manda él.
	if _acoplada:
		var b: Node = _bloque_empuje
		if b == null or not is_instance_valid(b) or not libre_de_accion or not bool(b.get("moviendo")) or not bool(b.get("acoplado")):
			_acoplada = false
		else:
			var bp: Vector3 = (b as Node3D).global_position
			if _dir_empuje.x != 0:
				position.x = bp.x - float(_dir_empuje.x) * _dist_empuje
				position.z = _lat_empuje
			else:
				position.z = bp.z - float(_dir_empuje.y) * _dist_empuje
				position.x = _lat_empuje
			if dir == _dir_empuje:
				b.call("sostener", dir)
			empujando = true
			_vel_clip_empuje = clampf(float(b.get("vel")) / ZANCADA_EMPUJAR, VEL_CLIP_CARGA, 2.5)
			_vel_hielo = Vector3.ZERO
			return true
	var bloque: Node = null
	if dir != Vector2i.ZERO:
		var yo: Vector2i = Terreno3D.celda_de(position)
		var vecina: Vector2i = yo + dir
		for n in get_tree().get_nodes_in_group("empujable"):
			if is_instance_valid(n) and n.get("celda") == vecina:
				bloque = n
				break
		if bloque != null:
			var centro: Vector3 = Terreno3D.centro_de(yo)
			var adelantada: float = (position.x - centro.x) * float(dir.x) + (position.z - centro.z) * float(dir.y)
			if adelantada < EMPUJE_PEGADA * Terreno3D.casilla:
				bloque = null                    # aún no está pegada a él
	if bloque != null:
		empujando = true
		_vel_clip_empuje = VEL_CLIP_CARGA
		if bloque != _bloque_empuje or dir != _dir_empuje:
			_bloque_empuje = bloque
			_dir_empuje = dir
			_t_empuje = 0.0
		if bool(bloque.get("moviendo")):
			_t_empuje = 0.0                      # ya se mueve (el viento, o resbala): hasta que pare no se cuenta
		else:
			_t_empuje += delta
			if _t_empuje >= T_EMPUJAR:
				_t_empuje = 0.0
				if bool(bloque.call("empujar", dir, true)):          # si no puede moverse devuelve false y ella se queda empujando (atascado)
					var bp2: Vector3 = (bloque as Node3D).global_position
					_dist_empuje = (bp2.x - position.x) * float(dir.x) + (bp2.z - position.z) * float(dir.y)
					_lat_empuje = position.z if dir.x != 0 else position.x
					_acoplada = true
		return false
	empujando = false
	_t_empuje = 0.0
	_bloque_empuje = null
	_dir_empuje = Vector2i.ZERO
	return false


## Un paso cada `DIST_PASO_*` unidades recorridas (no cada X segundos: así el ritmo sigue a la velocidad real, también si choca contra
## una pared y apenas avanza). El sonido depende del suelo de la casilla (`_tipo_suelo` de la maqueta): hierba, piedra, o el paso
## de siempre (tierra y camino).
func _sonar_pasos(recorrido: float, correr: bool) -> void:
	if nadando or not en_suelo or _t_roll > 0.0:
		_dist_paso = 0.0
		return
	_dist_paso += recorrido
	if _dist_paso < (DIST_PASO_CORRER if correr else DIST_PASO_ANDAR):
		return
	_dist_paso = 0.0
	var tipo: int = 0
	if mundo.has_method("_tipo_suelo"):
		tipo = int(mundo.call("_tipo_suelo", Terreno3D.celda_de(position)))
	# 27/10: sobre un puente (letra «b», tablones) suena a madera.
	if Terreno3D.letra_de(Terreno3D.celda_de(position)) == "b":
		Sfx3D.play(self, "paso_madera")
		return
	Sfx3D.play(self, "paso_roca" if tipo == 3 else ("paso_hierba" if tipo == 0 else "paso_tierra"))


## El oyente va en los pies del jugador y gira como la cámara (izquierda/derecha del sonido = izquierda/derecha de la pantalla);
## y el río, que no es un punto sino un tramo largo, se oye más cuanto más cerca esté el agua más próxima.
func _actualizar_sonido(delta: float) -> void:
	if _oyente == null:
		_oyente = AudioListener3D.new()
		add_child(_oyente)
		_oyente.make_current()
		var flujo: AudioStream = Sfx3D.bucle("agua")
		if flujo != null:
			_rio = AudioStreamPlayer.new()
			_rio.stream = flujo
			_rio.volume_db = -60.0
			add_child(_rio)
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		_oyente.global_rotation = Vector3(0.0, cam.global_rotation.y, 0.0)
	if _rio == null:
		return
	_t_rio -= delta
	if _t_rio <= 0.0:
		_t_rio = 0.2                         # 81 casillas cada 0,2 s: casi nada, y el agua no cambia más deprisa
		var c0: Vector2i = Terreno3D.celda_de(position)
		var cerca: float = float(RADIO_AGUA_CASILLAS) + 1.0
		for dy in range(-RADIO_AGUA_CASILLAS, RADIO_AGUA_CASILLAS + 1):
			for dx in range(-RADIO_AGUA_CASILLAS, RADIO_AGUA_CASILLAS + 1):
				var c: Vector2i = c0 + Vector2i(dx, dy)
				if Terreno3D.en_mapa(c) and Terreno3D.es_agua(c):
					cerca = minf(cerca, Vector2(dx, dy).length())
		_vol_rio_obj = 1.0 if nadando else clampf(1.0 - cerca / float(RADIO_AGUA_CASILLAS + 1), 0.0, 1.0)
	_vol_rio = move_toward(_vol_rio, _vol_rio_obj, delta * 1.2)      # sube y baja en ~1 s: no entra de golpe al pisar la orilla
	if _vol_rio <= 0.01:
		if _rio.playing:
			_rio.stop()
		return
	if not _rio.playing:
		_rio.play(randf() * _rio.stream.get_length())
	_rio.volume_db = DB_AGUA + linear_to_db(_vol_rio)


## La velocidad sobre hielo tras `delta`: se acerca al objetivo (lo que piden las teclas) con HIELO_ACEL si hay teclas, o con
## HIELO_FRENO si no. Estática para medirla sin escena.
static func velocidad_hielo(v: Vector3, objetivo: Vector3, delta: float) -> Vector3:
	var tasa: float = HIELO_ACEL if objetivo != Vector3.ZERO else HIELO_FRENO
	return v.move_toward(objetivo, tasa * delta)


## Intenta el paso entero y, si no cabe, cada eje por separado (para deslizar por las paredes).
## 6.6: Ctrl = voltereta. Se dispara al PULSAR (no mientras se mantiene). (Q ya no bebe aquí: desde el 24/10 Q usa el consumible equipado, en `HudEoW`,
## que para la poción llama a `usar_pocion()` de más abajo.)
func _gestionar_acciones(libre: bool, mov: Vector3) -> void:
	var ctrl: bool = libre and Input.is_key_pressed(KEY_CTRL)
	var ocupado: bool = _lanzando or _t_golpe > 0.0 or _t_gesto > 0.0 or _t_pegar > 0.0 or (lanz != null and lanz.modo_lanzar)
	var puede_rodar: bool = _roll_cd <= 0.0 and _t_roll <= 0.0 and _t_beber <= 0.0 and not ocupado and not nadando and en_suelo
	if ctrl and not _roll_previa:
		if puede_rodar:
			_iniciar_voltereta(mov)
		else:
			# Gamefeel (28/10): pulsada mientras aún rueda, golpea o lanza (o con la recarga a punto de acabar), se guarda Lanzador3D.BUFFER_PULSACION s reales.
			_roll_guardado = Lanzador3D.BUFFER_PULSACION
			_roll_guardado_mov = mov
	elif _roll_guardado > 0.0:
		_roll_guardado = maxf(0.0, _roll_guardado - get_process_delta_time() / maxf(Engine.time_scale, 0.05))
		if puede_rodar and libre:
			_roll_guardado = 0.0
			PlayLog.event("pulsacion_guardada", {"accion": "voltereta"})
			_iniciar_voltereta(mov if mov != Vector3.ZERO else _roll_guardado_mov)
	# C1 (28/10): F = golpe cuerpo a cuerpo. Se dispara al PULSAR; no gasta tinta. En suelo y sin nadar, rodar, beber, lanzar, apuntar, hacer un gesto ni empujar un bloque; con su reutilización.
	var tecla_golpe: bool = libre and Input.is_key_pressed(KEY_F)
	if tecla_golpe and not _pegar_previa:
		_iniciar_golpe_cuerpo()                  # (comprueba `puede_golpear_cuerpo`)
	_pegar_previa = tecla_golpe
	# F11: invoca un elemental de bosque 6 u por delante (banco de pruebas; los niveles lo traerán con su marcador).
	# Mayús+F11: invoca un Gatopedro (el lince que huye) en el mismo sitio. Alt+F11: un goblin asesino.
	# No F8: es el atajo del editor de Godot para DETENER el juego y la ventana se cerraba antes de llegar aquí.
	var f8: bool = libre and Input.is_key_pressed(KEY_F11)
	if f8 and not _f8_previa and lanz != null:
		var m: Vector3 = _mirada.normalized()
		var destino: Vector3 = position + m * 6.0
		var cc: Vector2i = Terreno3D.celda_de(destino)
		if Terreno3D.en_mapa(cc) and not Terreno3D.es_agua(cc) and not Terreno3D.bloqueada(cc):
			destino.y = Terreno3D.y_pies(cc)
			if Input.is_key_pressed(KEY_SHIFT):
				Gatopedro3D.invocar(mundo, self, lanz, destino)
			else:
				if Input.is_key_pressed(KEY_ALT):
					Combate3D.invocar_asesino(mundo, self, lanz, destino)      # Alt+F11: goblin asesino (22/10)
				else:
					Combate3D.invocar_elemental(mundo, self, lanz, destino)
		else:
			lanz.avisar("No cabe un elemental ahí delante", Color(1, 0.7, 0.5))
	_f8_previa = f8
	_roll_previa = ctrl


## Cuánto le queda a la voltereta para volver (1 = recién usada, 0 = lista). Lo pinta `PageHud` junto a las páginas (29/10: el HUD lo pedía desde el 14/10 y nadie lo daba).
func roll_cooldown_fraction() -> float:
	return clampf(_roll_cd / maxf(TIEMPO_VOLTERETA, 0.01), 0.0, 1.0)


## Lo que le queda a la voltereta (s). Lo lee `Sensacion3D.DirectorSensacion` para el clic de «ya puedes».
func roll_cd() -> float:
	return _roll_cd


## Giro actual de la cámara de la maqueta en grados (0 si el mundo no gira la cámara).
func _giro_camara() -> float:
	var g: Variant = mundo.get("_giro_cam") if mundo != null else null
	return float(g) if g != null else 0.0


func _iniciar_voltereta(mov: Vector3) -> void:
	_roll_dir = mov if mov != Vector3.ZERO else _mirada
	_roll_dir = Vector3(_roll_dir.x, 0.0, _roll_dir.z).normalized()
	var dur: float = clampf(pj.duracion("roll"), 0.35, 1.0) if pj.duracion("roll") > 0.0 else 0.6
	_t_roll = dur
	_roll_vel = DIST_VOLTERETA * Terreno3D.casilla / dur
	_roll_cd = TIEMPO_VOLTERETA
	_t_inv = maxf(_t_inv, dur)                     # sin daño por contacto mientras dura
	_mirada = _roll_dir
	pj.mirar(_roll_dir, 1.0)
	pj.rodar()                                     # 6.12: roll sin desplazamiento de cadera (lo movemos nosotros)
	Sensacion3D.voltereta(self)                    # gamefeel lote 4: polvo a los pies y roce de tela
	PlayLog.event("voltereta", {"dir": [_roll_dir.x, _roll_dir.z], "dur": dur})
	_esquiva_con_premio()


## C4: si rueda en los últimos AvisoAtaque3D.VENTANA_ESQUIVA s de un aviso que la cubre, gana el tiempo bruja: el mundo a 0,3 durante 0,6 s de juego, ella a su paso,
## invulnerable mientras dura y con una página a mano (`puede_lanzar` deja lanzar aunque aún ruede). A destiempo no pasa nada más que la voltereta.
func _esquiva_con_premio() -> void:
	var av: AvisoAtaque3D = AvisoAtaque3D.esquiva_a_tiempo(get_tree(), position)
	if av == null:
		return
	TiempoBruja.activar()
	esquivas_perfectas += 1
	_t_inv = maxf(_t_inv, TiempoBruja.DURA / TiempoBruja.ESCALA)        # s reales (su reloj va compensado)
	Combate3D.flotante(mundo, position + Vector3(0, 1.9, 0), "¡Esquiva!", Color(0.8, 0.7, 1.0))
	Sfx3D.play(self, "sello_ok")
	Sensacion3D.esquiva_perfecta(self)             # gamefeel lote 2: filtro violeta, estela de copias y tic-tac
	PlayLog.event("esquiva_perfecta", {"queda": snappedf(av.queda(), 0.01), "veces": esquivas_perfectas})
	esquiva_perfecta.emit(av)


## Beber una poción (la usa `Consumibles` cuando Q tiene la poción equipada). Devuelve si empezó a beber.
func usar_pocion() -> bool:
	var ocupado: bool = _lanzando or _t_golpe > 0.0 or _t_gesto > 0.0 or _t_pegar > 0.0 or (lanz != null and lanz.modo_lanzar)
	if _t_beber <= 0.0 and _t_roll <= 0.0 and not ocupado and not nadando and en_suelo and not muerto \
			and vida < Estado.i().vida_max and Estado.i().cuenta("pocion") > 0:
		_iniciar_beber()
		return true
	return false


func _iniciar_beber() -> void:
	_t_beber = T_BEBER
	if pj.beber(T_BEBER) <= 0.0:                   # Pipeline: stand_drink recortado + poción en la mano
		pj.jugar("drink", true)                    # sin clip: al menos que dure lo mismo
	PlayLog.event("beber_inicio", {"pociones": Estado.i().cuenta("pocion")})


## Un GESTO (24/10): el clip del rol (`agacharse`, `ofrecer`, `saludo`...: Pj3D.SINONIMOS) suena UNA vez a la velocidad `vel` y te deja quieto lo que dura; después vuelve idle.
## Devuelve lo que dura (s) con esa velocidad, o 0 si no se pudo (muerto, nadando, en el aire, rodando, bebiendo, lanzando, con la animación llevada desde fuera o sin ese clip):
## entonces no pasa nada y quien llama sigue como si el gesto no existiera.
func gesto(rol: String, vel: float = 1.0) -> float:
	var ocupado: bool = _lanzando or _t_golpe > 0.0 or _t_beber > 0.0 or _t_roll > 0.0 or _t_gesto > 0.0 or _t_pegar > 0.0 or (lanz != null and lanz.modo_lanzar)
	var clip_dur: float = pj.duracion(rol)
	if ocupado or muerto or nadando or not en_suelo or animacion_externa or clip_dur <= 0.0 or vel <= 0.0:
		return 0.0
	_t_gesto = clip_dur / vel
	pj.animacion_actual = ""
	pj.jugar(rol, true, vel)
	PlayLog.event("gesto", {"rol": rol, "dur": snappedf(_t_gesto, 0.01)})
	return _t_gesto


## ¿Está haciendo un gesto ahora mismo?
func en_gesto() -> bool:
	return _t_gesto > 0.0


func _terminar_beber() -> void:
	if pj.has_method("desequipar"):
		pj.call("desequipar")
	if Estado.i().quitar("pocion"):
		curar(CURA_POCION)
		Combate3D.flotante(mundo, position + Vector3(0, 1.6, 0), "+%d" % int(CURA_POCION), Color(0.5, 1.0, 0.55))
		PlayLog.event("beber_fin", {"vida": vida})
	pj.animacion_actual = ""


func _cancelar_beber() -> void:
	_t_beber = 0.0
	if pj.has_method("desequipar"):
		pj.call("desequipar")
	pj.animacion_actual = ""
	PlayLog.event("beber_interrumpido", {})


func _mover_con_choque(paso: Vector3) -> void:
	for v in [paso, Vector3(paso.x, 0.0, 0.0), Vector3(0.0, 0.0, paso.z)]:
		var destino: Vector3 = position + (v as Vector3)
		if (v as Vector3).length() > 0.0001 and _puede_estar(destino):
			position.x = destino.x
			position.z = destino.z
			return


## ¿Cabe el jugador (de pie, a su altura actual) en esa posición?
func _puede_estar(p: Vector3) -> bool:
	if TroncoEstanque3D.bloquea_a(p, position.y) and not TroncoEstanque3D.bloquea_a(position, position.y):
		return false                       # 22/10: el tronco del estanque (aún en el fondo del cauce) no se atraviesa
	var c: Vector2i = Terreno3D.celda_de(p)
	var actual: Vector2i = Terreno3D.celda_de(position)
	var parcial: bool = Terreno3D.es_parcial(c)
	if c == actual:
		if parcial and Terreno3D.choca_huella(c, p) and not Terreno3D.choca_huella(c, position):
			return false                   # dentro de una casilla bloqueada solo se roza lo que no es el objeto
		return Terreno3D.en_mapa(c)
	if parcial and Terreno3D.choca_huella(c, p):
		return false
	var nivel: int = Terreno3D.altura_en(actual)
	if not Terreno3D.pisable(c, nivel, true, maxi(MAX_NIVELES_SUBIBLES, tope_niveles_nivel), nado_permitido or nadando, parcial):
		return false
	if nadando:
		return Terreno3D.altura_en(c) == 0          # del agua solo se sale a suelo llano
	var y_dest: float = Terreno3D.y_pies(c)
	var tolerancia: float = TOLERANCIA_SUELO if en_suelo else TOLERANCIA_AIRE
	if Terreno3D.es_hueco_cauce(actual) and not Terreno3D.es_hueco_cauce(c):
		tolerancia += Terreno3D.LECHO_AGUA + (Terreno3D.alto_suelo - Terreno3D.alto_agua)   # 15/10: de una cuenca vacía se sale trepando el borde (un pozo de 0,94 u). 22/10: igual del cauce hondo
	return y_dest <= position.y + tolerancia


func _vertical(delta: float, salto: bool) -> void:
	var c: Vector2i = Terreno3D.celda_de(position)
	var agua: bool = Terreno3D.se_nada(c)          # el canal de ruinas con agua se vadea (P3): es_agua, pero no se nada

	if nadando:
		if not agua:
			_cambiar_nado(false)                       # tocó suelo, puente o hielo: sale
			position.y = Terreno3D.y_pies(c)
		else:
			# 15/10: se flota en la superficie que diga el mundo (en una cuenca, la de la simulación: sube y baja con el nivel).
			position.y = move_toward(position.y, Terreno3D.superficie_agua(c) - HUNDIDO, 3.0 * delta)
			vy = 0.0
			en_suelo = true
			_salto_antes = salto
			return

	var suelo: float = Terreno3D.y_pies(c)
	if en_suelo:
		if position.y > suelo + TOLERANCIA_SUELO:
			en_suelo = false                           # se acabó el suelo (bloque caducado): cae
			vy = 0.0
		else:
			# 22/10 (cauce hondo): salir de un foso es TREPAR (mide 0,94 u): más despacio que el escalón de menos de 0,55 u que se sube de un paso.
			if suelo > position.y + TOLERANCIA_SUELO:
				_trepando = true
			elif suelo <= position.y + 0.01:
				_trepando = false
			position.y = move_toward(position.y, suelo, (TASA_TREPAR if _trepando else 9.0) * delta)
			if salto and not _salto_antes and absf(position.y - suelo) < 0.05:
				vy = VEL_SALTO
				en_suelo = false
				saltos += 1
	if not en_suelo:
		vy -= GRAVEDAD * delta
		position.y += vy * delta
		if position.y <= suelo and vy <= 0.0:
			if vy <= -Sensacion3D.VY_POLVO_CAIDA and not agua:
				Sensacion3D.polvo(mundo, Vector3(position.x, suelo, position.z), Sensacion3D.POLVO_CAIDA)     # gamefeel lote 2: cae de alto
			position.y = suelo
			vy = 0.0
			en_suelo = true
			if agua:
				_cambiar_nado(true)
	_salto_antes = salto
	# Por si algo ha cambiado el suelo justo debajo (el hielo se derrite bajo los pies ya apoyados)
	if en_suelo and agua and not nadando and position.y <= Terreno3D.superficie_agua(c) + 0.3:
		_cambiar_nado(true)


func _cambiar_nado(n: bool) -> void:
	if nadando == n:
		return
	nadando = n
	if n:
		caidas_al_agua += 1
		PlayLog.event("nada", {"celda": [Terreno3D.celda_de(position).x, Terreno3D.celda_de(position).y]})
		if lanz != null:
			lanz.avisar("Nadas: lento y sin lanzar", Color(0.6, 0.85, 1.0))
	else:
		PlayLog.event("sale_del_agua")
	nado_cambiado.emit(n)


## A1: true = otro (el laboratorio, pestaña F5) lleva la animación del personaje; el Jugador3D no pide idle/andar/correr/nadar cada fotograma. Solo el laboratorio lo pone.
var animacion_externa: bool = false


func _animar(mov: Vector3, correr: bool) -> void:
	if animacion_externa:
		return
	if _t_roll > 0.0 or _t_beber > 0.0 or _t_gesto > 0.0 or _t_pegar > 0.0:
		return                                         # el clip de voltereta / beber / gesto ya está sonando
	if apuntando_rapido and _t_lanzar <= 0.0 and _t_golpe <= 0.0 and lanz != null and lanz.modo_lanzar and not nadando and en_suelo:
		# A1: apuntando con 1/2/3 pulsada. Quieta: la pose de apuntar (libro en las manos); andando: el clip de andar (la mirada ya la lleva el Lanzador hacia el ratón). `jugar` no reinicia el clip que ya suena.
		# Andando el clip sigue el ritmo del mundo (a `TIEMPO_PAGINA` los pies no patinan); quieta la pose va a velocidad normal, como en `apuntar_lanzar`.
		pj.set_velocidad_animacion(1.0 if mov != Vector3.ZERO else 1.0 / maxf(Engine.time_scale, 0.1))
		pj.jugar("walk" if mov != Vector3.ZERO else "leer")
		return
	if _t_lanzar > 0.0 or _t_golpe > 0.0 or (lanz != null and lanz.modo_lanzar):
		return
	if nadando:
		pj.jugar("swim")                               # swim_forward (rol "swim" de Pj3D); si no existe, walk
		if pj.animacion_actual != "swim":
			pj.jugar("walk")
		pj.set_velocidad_animacion(1.0 if mov != Vector3.ZERO else 0.4)
		return
	pj.set_velocidad_animacion(1.0)
	if not en_suelo:
		return                                         # en el aire se queda con la pose que tenía
	if mov == Vector3.ZERO:
		pj.jugar("idle")
	elif empujando and pj.duracion("empujar") > 0.0:
		pj.jugar("empujar")                            # empujando algo: el clip de empujar andando (bucle, sin avance)
		pj.set_velocidad_animacion(_vel_clip_empuje)    # 28/10: lento mientras carga, proporcional a lo que avanza el bloque después (sin patinar)
	else:
		pj.jugar("run" if correr else "walk")


func _sincronizar() -> void:
	pj.position = position
	_ultima = position
	if _t_inv > 0.0 and not muerto and _t_roll <= 0.0 and not TiempoBruja.activa():
		pj.visible = int(_t_inv * 14.0) % 2 == 0       # parpadea mientras es invulnerable (en el tiempo bruja no: taparía las copias y parecería daño)
	else:
		pj.visible = true


## =====================================================================================================
##  Vida en pantalla
## =====================================================================================================

func _construir_hud() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 9
	add_child(capa)
	# La vida, los frascos de tinta + su barra y el consumible equipado los pinta `HudEoW` (24/10). Arriba a la izquierda (15/10, Pablo), desde `Y_BARRAS`: 80 y no 8
	# porque la maqueta (Pipeline) pinta ahí su texto de depuración (FPS, atajos, avisos: ~3 líneas) y taparía las barras; si algún día ese texto se mueve, basta bajar `Y_BARRAS`.
	hud_eow = HudEoW.new()
	hud_eow.name = "HudEoW"
	hud_eow.jugador = self
	add_child(hud_eow)
	_hud_texto = Label.new()
	_hud_texto.add_theme_font_size_override("font_size", 14)
	_hud_texto.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_texto.add_theme_constant_override("outline_size", 5)
	_hud_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(_hud_texto)
	_hud_texto.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)    # el texto de ayuda se queda abajo
	_hud_texto.offset_left = 14.0
	_hud_texto.offset_top = -50.0
	_hud_texto.offset_right = 560.0
	_hud_texto.offset_bottom = -8.0


func _actualizar_hud() -> void:
	if _hud_texto == null:
		return
	var extra: String = ""
	if nadando:
		extra = " · nadando"
	elif not en_suelo:
		extra = " · en el aire"
	elif nivel_actual() > 0:
		extra = " · nivel %d" % nivel_actual()
	_hud_texto.text = "Vida %d/%d · oro %d%s\nT libro · mantén 1/2/3 para apuntar, suelta para lanzar · F golpe · Q usar consumible · R cambiar · I menú · Espacio saltar · F12 medición" % [
		int(vida), int(Estado.i().vida_max), Estado.i().oro, extra]



## =====================================================================================================
##  28/10 · C1 · Golpe cuerpo a cuerpo (F)
## =====================================================================================================

## ¿Puede dar un golpe ahora mismo? En suelo, sin nadar, rodar, beber, lanzar, apuntar (A1), gesto ni empujar un bloque, y con la reutilización (`GolpeCuerpo.CD`) cumplida.
func puede_golpear_cuerpo() -> bool:
	return not muerto and not nadando and en_suelo and not animacion_externa and _t_pegar <= 0.0 and _pegar_cd <= 0.0 and _t_roll <= 0.0 and _t_beber <= 0.0 \
		and _t_gesto <= 0.0 and _t_golpe <= 0.0 and not _lanzando and not apuntando_rapido and not empujando and not _acoplada \
		and not (lanz != null and lanz.modo_lanzar) and mundo != null and mundo.get("_velo") == null


## ¿Está dando un golpe cuerpo a cuerpo ahora mismo?
func golpeando() -> bool:
	return _t_pegar > 0.0


## Empieza el golpe: se queda quieta hacia donde mira, suena el clip y a los `retardo` s sale el impacto (`_impactar_golpe`). No cuesta tinta. Devuelve false si no puede.
func _iniciar_golpe_cuerpo() -> bool:
	if not puede_golpear_cuerpo():
		return false
	_t_pegar = GolpeCuerpo.DUR
	_pegar_cd = GolpeCuerpo.CD
	_pegar_hecho = false
	_pegar_retardo = Pj3D.golpe_retardo(GolpeCuerpo.DUR)
	_pegar_dir = Vector3(_mirada.x, 0.0, _mirada.z)
	if _pegar_dir.length() < 0.01:
		_pegar_dir = Vector3(0, 0, 1)
	_pegar_dir = _pegar_dir.normalized()
	_vel_hielo = Vector3.ZERO
	pj.mirar(_pegar_dir, 1.0)
	pj.animacion_actual = ""
	var con_clip: bool = pj.golpear_cuerpo(GolpeCuerpo.DUR)
	PlayLog.event("golpe_inicio", {"dir": [snappedf(_pegar_dir.x, 0.01), snappedf(_pegar_dir.z, 0.01)], "clip": con_clip, "retardo": snappedf(_pegar_retardo, 0.01)})
	return true


## El instante del impacto: aplica el golpe a lo que haya en el cono (`GolpeCuerpo.impactar`) y lo apunta en el diario.
func _impactar_golpe() -> void:
	_pegar_hecho = true
	var r: Dictionary = GolpeCuerpo.impactar(self, _pegar_dir)
	ultimo_golpe_cuerpo = r
	PlayLog.event("golpe", {"enemigos": r["enemigos"], "escudos": r["escudos"], "rompibles": r["rompibles"], "bloques": r["bloques"], "movidos": r["movidos"],
		"celda": [Terreno3D.celda_de(position).x, Terreno3D.celda_de(position).y]})
	golpe_cuerpo_dado.emit(r)
