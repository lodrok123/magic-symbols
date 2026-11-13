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

const MAX_NIVELES_SUBIBLES: int = 1      ## 3/11/2026: lo que la jugadora puede ESCALAR de una casilla a otra, NO un límite de los hechizos (la altura de un bloque ya no se capa ni se rechaza)
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
## 6/11 (bloque A4, valor de partida para que Pablo lo afine): 0,7 → 0,4 s de invulnerabilidad tras recibir un golpe. Con 0,7 s un enemigo que pegaba dos veces seguidas casi nunca llegaba a hacer el segundo golpe y el combate cuerpo a cuerpo no tenía riesgo.
const INVULNERABLE: float = 0.4
const TICK_VENENO: float = 0.5               ## s entre dos pulsos del veneno (envenenar)
## 6/11 (Pablo, chamán v2): VENENO QUE SE ACUMULA. Cada golpe del chamán (`envenenar_pila`) añade una pila; cada pila hace PILA_VENENO_DPS por segundo y dura PILA_VENENO_S s (temporizador propio).
const PILA_VENENO_MAX: int = 3
const PILA_VENENO_DPS: float = 2.0
const PILA_VENENO_S: float = 4.0
const VENENO_PUEDE_MATAR: bool = false       ## false: el veneno (pilas, nubes, pantano) nunca baja la vida de 1
## 6/11 (bloque B7, fuego amigo suave): `dano_ambiental` es el daño de lo que NO es un golpe (tu propia llama, tu suelo electrificado, la quemadura de un limo): respeta la invulnerabilidad,
## sube la viñeta y el HUD, pero no empuja, no corta el gesto ni da hitstop (cada tic congelaría el juego). Como el veneno, no la mata: fallo que evita = morir quemada por tu propio hechizo.
const AMBIENTAL_PUEDE_MATAR: bool = false
const VINETA_AMBIENTAL: float = 0.3          ## intensidad de la viñeta roja de un tic ambiental (el golpe de un goblin usa 0,6-1,0)
const COLOR_AMBIENTAL: Dictionary = {"fuego": Color(1.0, 0.5, 0.2), "rayo": Color(1.0, 0.92, 0.3)}
## `aplicar_estado(elemento, segundos)`: los estados de personaje mínimos (D3 del limo). Agua → mojada (más lenta); hielo → ralentizada; fuego → quemada (daño por tics); rayo → aturdida (no hay aturdir
## propio: se queda en ralentizada muy fuerte durante pocos segundos).
const MOJADA_X: float = 0.8
const HIELO_X: float = 0.5
const RAYO_X: float = 0.3
const RAYO_ATURDE_S: float = 0.6             ## el rayo no dura lo que el resto (ESTADO_ATAQUE_S del limo = 3 s): una descarga aturde un instante
const QUEMADA_DANO: float = 2.0              ## por tic de la quemada
const QUEMADA_TICK: float = 0.5
const ELECTRIFICADA_DANO: float = 2.0        ## por descarga del suelo electrificado que pisa
const ELECTRIFICADA_TICK: float = 1.0        ## s entre descargas (la primera, al pisarlo); 1 s y no 0,5 porque cada una la aturde 0,6 s y mas seguidas la dejarian sin moverse
const TIEMPO_REAPARECER: float = 2.2
const T_GOLPE: float = 0.35
const T_LANZAR: float = 0.9
## --- 6.6 Voltereta: ≤ 1 casilla, colisiona paso a paso, sin daño mientras dura, reutilización larga ---
## 6/11 (bloque A4, valor de partida): la recarga baja de 4 s a 1,5 s: con 4 s la esquiva no se podía usar como parte del combate (un enemigo la gastaba y tocaba comérselo todo).
const TIEMPO_VOLTERETA: float = 1.5          ## segundos hasta poder repetirla
const DIST_VOLTERETA: float = 1.0            ## casillas
## --- 6.7 Beber poción: bloqueado mientras bebe; cura al terminar; un golpe la interrumpe ---
const T_BEBER: float = 1.5
const CURA_POCION: float = 40.0
## --- 11.13 Hielo: resbala. Sobre agua helada la velocidad no sigue al teclado al instante: se acerca a ella poco a poco ---
const HIELO_ACEL: float = 3.0                ## u/s² con las teclas puestas (andar = 1,6 u/s: ~0,5 s en alcanzarlo)
const HIELO_FRENO: float = 0.9               ## u/s² sin teclas: cuesta frenar (de 1,6 u/s patinas ~1,4 u)
const HIELO_GIRO: float = 0.35               ## el giro de la mirada va a esta fracción de lo normal

## --- 4/11 (Pablo, Bosque 02) Movimiento: aceleración andar↔correr y giro del cuerpo ---
const T_ANDAR_A_CORRER: float = 0.3          ## s en pasar de la velocidad de andar a la de correr (rampa lineal) al pulsar correr
const T_CORRER_A_ANDAR: float = 0.15         ## s en volver de correr a andar al soltar la tecla de correr
const FRACCION_CORRE_ENTRA: float = 0.6      ## el clip y los pasos pasan a «correr» cuando la velocidad real pasa de andar + 0,6 · (correr − andar)…
const FRACCION_CORRE_SALE: float = 0.4       ## …y vuelven a «andar» por debajo de andar + 0,4 · (correr − andar) (la histéresis evita que parpadee)
const VEL_GIRO_ANDAR: float = 600.0          ## °/s como máximo que gira el cuerpo andando (180° ≈ 0,3 s con la cola del suavizado)
const VEL_GIRO_CORRER: float = 720.0         ## °/s corriendo

## --- 27/10 Empujar bloques (docs/EMPUJAR_BLOQUES.md) ---
const T_EMPUJAR: float = 0.35                ## s apretando contra un bloque pegado antes de que ceda
const EMPUJE_CARDINAL: float = 0.8           ## componente mínima (de la dirección normalizada) para contar como «hacia una cara»: la diagonal (0,71) no empuja
const EMPUJE_TOQUE: float = 0.30             ## u: con el contorno del bloque conocido, está «pegada» si un paso así de corto hacia él ya choca (12/11)
const EMPUJE_PEGADA: float = 0.3            ## × casilla: lo que hay que haberse adelantado desde el centro de su casilla hacia el bloque (a ≤ 0,7 · S de su centro)
const VEL_CLIP_CARGA: float = 0.4           ## velocidad del clip `empujar` mientras carga los T_EMPUJAR s sin moverse (se lee el esfuerzo)
const ZANCADA_EMPUJAR: float = 0.9          ## u/s de suelo por cada 1,0 de velocidad del clip `empujar` (ESTIMADO, afinar a ojo; como walk x1,6 = 1,6 u/s en commit 93fd42f7): la velocidad del clip = la real del bloque / esto

signal murio
signal reaparecio
## F4 (29/10): el aguante cambió. `activo` = hay calor o frío en la zona (o aún se está recuperando): el HUD (Pipeline) muestra la barra SOLO entonces.
signal aguante_cambio(valor: float, activo: bool)
signal nado_cambiado(nadando: bool)
signal vida_cambiada(vida: float, maxima: float)
signal dano_recibido(cantidad: float)             ## A3 (estadísticas): un golpe que de verdad ha quitado vida (no el absorbido por barrera o bálsamo)

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
var _caida_plataforma: Dictionary = {}
var puntos_inicio: Vector3 = Vector3.ZERO
## La pantalla de «Has muerto» (Fase 14.3). Si existe, ella decide cuándo reaparece el jugador; si no, reaparece solo a los TIEMPO_REAPARECER.
var pantalla_muerte: PantallaMuerte = null

var _mirada: Vector3 = Vector3(0, 0, 1)
var _empuje: Vector3 = Vector3.ZERO
var _t_lanzar: float = 0.0
var _lanzando: bool = false
var _t_golpe: float = 0.0
var _t_inv: float = 0.0
## 6/11 (Pablo, «El elemental»): ENRAIZADA. Las raíces del elemental de bosque la sujetan `_t_enraizada` s: no anda, no corre, no salta, no rueda y no la empuja nada; SÍ puede lanzar hechizos
## (la tinta, el libro y el cast no dependen de las piernas). Se pone con `enraizar(s)` (no se acorta si ya lo estaba más) y se quita sola, al morir o con `liberar_raices()`.
var _t_enraizada: float = 0.0
var _t_est_vel: float = 0.0                       ## 6/11 (`aplicar_estado`): s que le quedan al estado que la frena (mojada, ralentizada, aturdida)
var _x_est_vel: float = 1.0                       ## ... y por cuánto multiplica su velocidad (el más fuerte de los activos)
var _nombre_est_vel: String = ""                  ## 10/11: cuál de los tres es («mojada», «ralentizada», «aturdida»), para que un antídoto lo quite
var _t_quemada: float = 0.0                       ## s que le quedan de quemada (2 de daño ambiental cada QUEMADA_TICK)
var _tick_quemada: float = 0.0
var _tick_electrica: float = 0.0                  ## s hasta la proxima descarga del suelo electrificado (0 = la siguiente es inmediata)
## 6/11: el último `recibir_dano` lo paró la barrera (burbuja o cúpula del Lanzador3D). Se reinicia al principio de cada `recibir_dano`; lo lee quien acaba de pegar (el elemental, que se queda aturdido).
var golpe_absorbido_por_barrera: bool = false
var _beber_id: String = "pocion"                 ## F3: qué poción se está bebiendo (la grande tarda lo mismo)
## F4 (29/10): AGUANTE 0–100, la barra de las zonas con calor o frío. Baja `aguante_s` de la tabla por segundo (el frío ×`mojada_x` si estás mojada), a 0 quita `dano_s` de vida por segundo y
## fuera de todo estado sube `rellena_s` (20) por segundo. `protegida(estado)` lo anula. Se guarda en la partida (`jugadora.aguante`).
const AGUANTE_MAX: float = 100.0
const TICK_AGUANTE: float = 0.5                  ## s entre dos pulsos del daño por aguante agotado (como el veneno)
var aguante: float = AGUANTE_MAX
var aguante_activo: bool = false
var _aguante_emitido: float = AGUANTE_MAX
var _t_dano_aguante: float = 0.0
var _acum_dano_aguante: float = 0.0
var _t_brasero: float = 0.0                      ## s que faltan para volver a mirar si hay un brasero cerca (se cachea PERIODO_BRASERO)
var _brasero_cerca: bool = false
var _veneno_t: float = 0.0                       ## s que le quedan de veneno (envenenar)
var _veneno_dps: float = 0.0
var _veneno_tick: float = 0.0
var _pilas_veneno: Array[float] = []             ## 6/11: s que le quedan a cada pila de veneno del chamán (máx PILA_VENENO_MAX)
var _pila_tick: float = 0.0
var _t_muerte: float = 0.0
var _ultima: Vector3 = Vector3.ZERO
var _salto_antes: bool = false
var _vel_andar: float = 1.6
var _vel_correr: float = 3.0
var _hud_texto: Label = null
## 24/10: la vida, los frascos y la barra de tinta y el consumible equipado (Q/R) los pinta y gestiona `HudEoW` (presentacion/ui/hud_eow.gd); antes eran aquí dos barras de ColorRect.
var hud_eow: HudEoW = null
var carga: CargarObjeto3D = null            ## 4/11: coger y lanzar objetos (jugador/cargar_objeto_3d.gd); sus siete enganches en este archivo llevan «carga»
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
var vel_marcha: float = -1.0                 ## 4/11: velocidad de andar/correr de ahora (u/s), con rampa entre `_vel_andar` y `_vel_correr`; −1 = aún sin estrenar
var corre_real: bool = false                 ## 4/11: va CORRIENDO de verdad (la velocidad real ya pasó el umbral): lo que miran el clip run/walk y los pasos, no la tecla

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
	var ez: EstadoZona3D = p_mundo.get_node_or_null("EstadoZona3D") as EstadoZona3D
	if ez == null:
		ez = EstadoZona3D.montar(p_mundo)      # F4: los estados de zona del mapa (`; zona … estado=calor`)
	ez.jugador = j

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
	Estadisticas.conectar(p_mundo.get("_mundo") as Mundo3D, j, l)      # tercera tanda A3: enemigos, hechizos, daño, oro, muertes y cofres
	Partida.vigilar_misiones()                                          # tercera tanda A2: completar una misión autoguarda
	j.carga = CargarObjeto3D.montar(j)
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


func lleva_carga() -> bool:                    ## 4/11: con un objeto en las manos no se corre, salta, rueda, golpea ni lanza hechizos
	return carga != null and carga.ocupa_manos()


func puede_lanzar() -> bool:
	return not muerto and not lleva_carga() and not nadando and en_suelo and mundo.get("_velo") == null and (_t_roll <= 0.0 or TiempoBruja.activa()) and _t_beber <= 0.0 and _t_gesto <= 0.0 and _t_pegar <= 0.0


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
	if muerto or inmune_a("veneno"):
		return
	_veneno_dps = maxf(_veneno_dps if _veneno_t > 0.0 else 0.0, dps)
	_veneno_t = maxf(_veneno_t, segundos)
	_veneno_tick = minf(_veneno_tick, TICK_VENENO) if _veneno_tick > 0.0 else TICK_VENENO


## 6/11 (chamán v2): añade UNA pila de veneno (PILA_VENENO_DPS durante PILA_VENENO_S s, cada pila con su reloj). Con PILA_VENENO_MAX pilas, el golpe nuevo renueva la que menos le queda.
## `envenenar` (nubes, pantano, colmena) NO apila: es veneno de ambiente y se suma aparte. Devuelve las pilas que hay ahora (0 si la protege la ropa o un antídoto).
func envenenar_pila() -> int:
	if muerto or inmune_a("veneno"):
		return 0
	if _pilas_veneno.size() < PILA_VENENO_MAX:
		_pilas_veneno.append(PILA_VENENO_S)
	else:
		var peor: int = 0
		for i in range(_pilas_veneno.size()):
			if _pilas_veneno[i] < _pilas_veneno[peor]:
				peor = i
		_pilas_veneno[peor] = PILA_VENENO_S
	if _pila_tick <= 0.0:
		_pila_tick = TICK_VENENO
	Combate3D.flotante(mundo, position + Vector3(0, 1.9, 0), "Veneno x%d" % _pilas_veneno.size(), Color(0.55, 0.9, 0.35), 0.8)
	return _pilas_veneno.size()


func pilas_veneno() -> int:
	return _pilas_veneno.size()


## Vida que queda tras `d` de veneno: sin VENENO_PUEDE_MATAR no baja de 1 (si ya estaba por debajo, no la toca).
func _vida_tras_veneno(d: float) -> float:
	if VENENO_PUEDE_MATAR:
		return maxf(0.0, vida - d)
	return minf(vida, maxf(1.0, vida - d))


## Un paso de las pilas: cada TICK_VENENO s, pilas × PILA_VENENO_DPS × TICK_VENENO de daño; después gastan su reloj y las que llegan a 0 se van.
func _veneno_pilas_paso(delta: float) -> void:
	if _pilas_veneno.is_empty() or muerto:
		return
	_pila_tick -= delta
	if _pila_tick <= 0.0:
		_pila_tick = TICK_VENENO
		var d: float = float(_pilas_veneno.size()) * PILA_VENENO_DPS * TICK_VENENO
		vida = _vida_tras_veneno(d)
		Combate3D.flotante(mundo, position + Vector3(0, 1.6, 0), str(int(ceil(d))), Color(0.55, 0.9, 0.35), 0.8)
		vida_cambiada.emit(vida, Estado.i().vida_max)
		if vida <= 0.0:
			_morir()
			return
	for i in range(_pilas_veneno.size() - 1, -1, -1):
		_pilas_veneno[i] -= delta
		if _pilas_veneno[i] <= 0.0:
			_pilas_veneno.remove_at(i)


## F3 (29/10): la DEF de la jugadora = la de las mejoras (`Estado.defensa`) + la de la ropa puesta (`Ropa3D`, `efecto.defensa`).
func defensa_total() -> float:
	return Estado.i().defensa + (float(pj.defensa_ropa()) if pj != null else 0.0)


## ¿Eres inmune a `estado` («veneno», «calor», «frio»)? Por la ropa puesta o por un consumible activo (`Consumibles.protegido`). F4 lo lee para el frío, el calor y el veneno.
func inmune_a(estado: String) -> bool:
	return (pj != null and pj.inmune_a(estado)) or Consumibles.protegido(estado)


## F4 (29/10): ¿estás protegida de `estado` ahora mismo? Escalera de la tabla: un CONSUMIBLE activo (`Consumibles.resiste`: frescor, abrigo, antídoto), una PRENDA (`inmune_a`) o lo que dice la tabla
## de ese estado: calor → estar MOJADA (la casilla `mojada` bajo tus pies) o pisar agua; frío → un brasero o fogata ENCENDIDOS a ≤ `brasero_casillas` (2) casillas (se cachea medio segundo).
func protegida(estado: String) -> bool:
	if inmune_a(estado) or Consumibles.resiste(estado):
		return true
	match estado:
		"calor":
			return esta_mojada() or nadando or Terreno3D.es_agua(Terreno3D.celda_de(position))
		"frio":
			return brasero_cerca()
	return false


## ¿Hay una casilla mojada bajo ti? (no existe un estado de personaje «mojada» para la jugadora: es el del suelo que pisa.)
func esta_mojada() -> bool:
	return Terreno3D.estados.tiene(Terreno3D.celda_de(position), EstadosSuelo3D.MOJADA)


## ¿Hay un brasero o una fogata encendidos a ≤ 2 casillas? Cacheado `EstadoZona3D.PERIODO_BRASERO` s (recorre los reactivos); `refrescar_brasero()` fuerza la consulta (pruebas).
func brasero_cerca() -> bool:
	if _t_brasero <= 0.0:
		refrescar_brasero()
	return _brasero_cerca


func refrescar_brasero() -> void:
	_t_brasero = EstadoZona3D.PERIODO_BRASERO
	if not is_inside_tree():
		_brasero_cerca = false
		return
	_brasero_cerca = EstadoZona3D.brasero_cerca(get_tree(), position, maxf(float(BD.estado_mundo("frio").get("brasero_casillas", 2)), 0.0))


## F4: un paso del aguante con los estados de la zona de ahora (ver `AGUANTE_MAX`). `zona` = los estados de tu casilla.
func _actualizar_aguante(delta: float, zona: Array) -> void:
	_t_brasero = maxf(0.0, _t_brasero - delta)
	if zona.is_empty() and aguante >= AGUANTE_MAX:
		if aguante_activo:
			aguante_activo = false
			aguante_cambio.emit(aguante, false)
		return
	var prot: Dictionary = {}
	for e in ["calor", "frio"]:
		prot[e] = zona.has(e) and protegida(e)
	var r: Dictionary = EstadoZona3D.paso_aguante(aguante, delta, zona, prot, esta_mojada() or nadando)
	aguante = float(r["valor"])
	var activo: bool = bool(r["en_zona"]) or aguante < AGUANTE_MAX
	if float(r["dano"]) > 0.0 and not muerto:
		_acum_dano_aguante += float(r["dano"])
		_t_dano_aguante += delta
		if _t_dano_aguante >= TICK_AGUANTE:
			_t_dano_aguante = 0.0
			var d: float = _acum_dano_aguante
			_acum_dano_aguante = 0.0
			vida = maxf(0.0, vida - d)
			Combate3D.flotante(mundo, position + Vector3(0, 1.6, 0), str(int(ceil(d))), Color(1.0, 0.6, 0.3), 0.8)
			vida_cambiada.emit(vida, Estado.i().vida_max)
			if vida <= 0.0:
				_morir()
	else:
		_t_dano_aguante = 0.0
		_acum_dano_aguante = 0.0
	if absf(aguante - _aguante_emitido) >= 0.1 or activo != aguante_activo:
		_aguante_emitido = aguante
		aguante_activo = activo
		aguante_cambio.emit(aguante, activo)


## F4: una zona FIJA con `estado=veneno` (el pantano) envenena como una nube mientras estás dentro (`dano_s` de vida por segundo y `sigue_s` s después), salvo que estés protegida. Las nubes
## envenenan por su cuenta (`NubeVeneno3D`, con su propio radio), así que aquí solo cuentan los estados FIJOS de la casilla.
func _veneno_de_zona(zona: Array) -> void:
	if not zona.has("veneno") or muerto or EstadoZona3D.actual == null:
		return
	if not EstadoZona3D.actual.fijos_en(Terreno3D.celda_de(position)).has("veneno") or protegida("veneno"):
		return
	var fila: Dictionary = BD.estado_mundo("veneno")
	envenenar(float(fila.get("dano_s", 2)), float(fila.get("sigue_s", 3)))


## F4: lo que empuja el vendaval este fotograma (u). Cero si no sopla, si estás nadando o en el aire, o si TRAS UN MURO: la casilla de donde viene el viento está bloqueada o es un bloque de tierra más alto.
func _viento_paso(delta: float, zona: Array) -> Vector3:
	if not zona.has("vendaval") or nadando or not en_suelo or EstadoZona3D.actual == null:
		return Vector3.ZERO
	var c: Vector2i = Terreno3D.celda_de(position)
	var dir: Vector2i = EstadoZona3D.actual.direccion_viento(c)
	if dir == Vector2i.ZERO:
		return Vector3.ZERO
	var contra: Vector2i = c - dir
	if Terreno3D.bloqueada(contra) or Terreno3D.altura_en(contra) > Terreno3D.altura_en(c):
		return Vector3.ZERO
	return EstadoZona3D.actual.viento_en(c) * delta


## 10/11: el estado de personaje que corresponde a cada protección de los antídotos (frio → ralentizada por el hielo, rayo → aturdida). El calor es la quemada.
const ESTADO_DE_PROTECCION: Dictionary = {"frio": "ralentizada", "rayo": "aturdida"}
## ... y la protección que frena cada elemento de `aplicar_estado` (el agua no tiene: mojarse no es un estado dañino).
const PROTECCION_DE_ELEMENTO: Dictionary = {"hielo": "frio", "fuego": "calor", "rayo": "rayo"}


## ¿Tiene ahora el estado del que protege `estado` (veneno, frio, calor, rayo)? El frío y el calor de zona (el aguante a medias) cuentan también.
func tiene_estado(estado: String) -> bool:
	match estado:
		"veneno":
			return _veneno_t > 0.0 or not _pilas_veneno.is_empty()
		"calor":
			return esta_quemada() or (aguante_activo and aguante < AGUANTE_MAX - 0.01 and _aguante_de_zona("calor"))
		"frio":
			return (_t_est_vel > 0.0 and _nombre_est_vel == "ralentizada") or (aguante_activo and aguante < AGUANTE_MAX - 0.01 and _aguante_de_zona("frio"))
		"rayo":
			return _t_est_vel > 0.0 and _nombre_est_vel == "aturdida"
	return false


## ¿El aguante que baja ahora es el de esa zona? (en una zona con calor el frasco de frescor rellena; la brasa, no).
func _aguante_de_zona(estado: String) -> bool:
	return EstadoZona3D.actual != null and EstadoZona3D.actual.estados_en(Terreno3D.celda_de(position)).has(estado)


## Quita un estado dañino: veneno, frio (la ralentizada del hielo y el aguante del frío), calor (la quemada y el aguante del calor) o rayo (la aturdida).
## true si había algo que quitar. Lo llaman los antídotos (`Consumibles.curar_estado`).
func curar_estado(estado: String) -> bool:
	if not tiene_estado(estado):
		return false
	match estado:
		"veneno":
			_veneno_t = 0.0
			_veneno_dps = 0.0
			_pilas_veneno.clear()               # 6/11: el antídoto quita también las pilas del chamán
		"calor":
			_t_quemada = 0.0
			if _aguante_de_zona("calor"):
				aguante = AGUANTE_MAX
		"frio", "rayo":
			if _nombre_est_vel == String(ESTADO_DE_PROTECCION[estado]):
				_t_est_vel = 0.0
				_x_est_vel = 1.0
				_nombre_est_vel = ""
			if estado == "frio" and _aguante_de_zona("frio"):
				aguante = AGUANTE_MAX
	return true


## 6/11: la sujetan unas raíces `segundos` s (ver `_t_enraizada`). No hace nada si está muerta.
func enraizar(segundos: float) -> void:
	if muerto or segundos <= 0.0:
		return
	if _t_enraizada <= 0.0:
		Combate3D.flotante(mundo, position + Vector3(0, 1.9, 0), "¡Enraizada!", Color(0.75, 0.5, 0.25), 0.9)
	_t_enraizada = maxf(_t_enraizada, segundos)
	_vel_hielo = Vector3.ZERO
	vel_suelo = Vector3.ZERO
	_empuje = Vector3.ZERO


func esta_enraizada() -> bool:
	return _t_enraizada > 0.0 and not muerto


func liberar_raices() -> void:
	_t_enraizada = 0.0


func recibir_dano(cantidad: float, desde: Vector3 = Vector3.ZERO) -> void:
	golpe_absorbido_por_barrera = false
	if muerto or _t_inv > 0.0 or cantidad <= 0.0:
		return
	cantidad = Dano.tras_defensa(cantidad, defensa_total())   # F3: la misma fórmula que los enemigos, D_final = máx(0,2·D, D − DEF)
	if lanz != null and lanz.absorber_golpe(cantidad, desde):
		golpe_absorbido_por_barrera = true
		return                                   # la barrera cúpula lo ha parado (6.3)
	if hud_eow != null and hud_eow.consumibles.absorber(cantidad):
		return                                   # 24/10: el Bálsamo protector se come el golpe (y se acaba)
	if _t_beber > 0.0:
		_cancelar_beber()                       # 6.7: si te golpean mientras bebes, no curas
	if carga != null:
		carga.al_recibir_golpe()                # 4/11: lo que llevara en brazos se cae y se rompe
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
	dano_recibido.emit(cantidad)                      # A3: lo cuenta `Estadisticas` (daño que de verdad entró, tras defensa, barrera y bálsamo)
	vida_cambiada.emit(vida, Estado.i().vida_max)
	if vida <= 0.0:
		Sensacion3D.dano_recibido(self, cantidad)     # gamefeel U2: la viñeta y el golpe también en el golpe que mata, antes del fundido de la pantalla de muerte
		_morir()
	else:
		pj.animacion_actual = ""
		pj.jugar("hit")
		Sensacion3D.dano_recibido(self, cantidad)     # gamefeel: viñeta roja, temblor y un hitstop corto


## 6/11 (bloque B7): daño que no es un golpe (llama propia, suelo electrificado, quemada). Devuelve lo que de verdad quitó (0 si la invulnerabilidad lo paró, está muerta o no le quedaba vida que
## quitar). Pasa por la defensa, la invulnerabilidad (`_t_inv`: una voltereta atraviesa la llama), la viñeta y el HUD; NO empuja, NO corta el gesto ni el golpe en curso y NO da hitstop.
func dano_ambiental(cantidad: float, elemento: String = "") -> float:
	if muerto or _t_inv > 0.0 or cantidad <= 0.0:
		return 0.0
	if PROTECCION_DE_ELEMENTO.has(elemento) and inmune_a(String(PROTECCION_DE_ELEMENTO[elemento])):
		return 0.0                              # 10/11: la llama propia o el suelo electrificado no dañan con su protección puesta
	cantidad = Dano.tras_defensa(cantidad, defensa_total())
	var antes: float = vida
	vida = maxf(0.0, vida - cantidad) if AMBIENTAL_PUEDE_MATAR else minf(vida, maxf(1.0, vida - cantidad))
	var quitado: float = antes - vida
	if quitado <= 0.0:
		return 0.0
	_t_sin_combate = 0.0
	Combate3D.flotante(mundo, position + Vector3(0, 1.6, 0), str(int(round(quitado))), COLOR_AMBIENTAL.get(elemento, Color(1, 0.4, 0.35)), 0.8)
	dano_recibido.emit(quitado)
	vida_cambiada.emit(vida, Estado.i().vida_max)
	if Sensacion3D.ACTIVA and is_inside_tree():
		Sensacion3D._vineta(self, VINETA_AMBIENTAL)
	if vida <= 0.0:
		_morir()
	return quitado


## 6/11 (D3 del limo): `elemento` le deja un estado `segundos` s. Devuelve su nombre («mojada», «ralentizada», «quemada», «aturdida») o «» si ese elemento no deja ninguno (tierra, viento).
func aplicar_estado(elemento: String, segundos: float) -> String:
	if muerto or segundos <= 0.0:
		return ""
	if PROTECCION_DE_ELEMENTO.has(elemento) and inmune_a(String(PROTECCION_DE_ELEMENTO[elemento])):
		return ""                               # 10/11: un antídoto o un elixir activo (o la ropa) lo para
	var nombre: String = ""
	var x: float = 1.0
	var dur: float = segundos
	match elemento:
		"agua":
			nombre = "mojada"
			x = MOJADA_X
			_t_quemada = 0.0                    # el agua apaga la quemada
		"hielo":
			nombre = "ralentizada"
			x = HIELO_X
		"rayo":
			nombre = "aturdida"
			x = RAYO_X
			dur = minf(segundos, RAYO_ATURDE_S)
		"fuego":
			nombre = "quemada"
			if _t_quemada <= 0.0:
				_tick_quemada = QUEMADA_TICK
			_t_quemada = maxf(_t_quemada, segundos)
		_:
			return ""
	if x < 1.0:
		if _t_est_vel <= 0.0 or x <= _x_est_vel:
			_x_est_vel = x                      # se queda el estado más lento que esté activo
			_nombre_est_vel = nombre
		_t_est_vel = maxf(_t_est_vel, dur)
	Combate3D.flotante(mundo, position + Vector3(0, 1.9, 0), nombre.capitalize(), COLOR_AMBIENTAL.get(elemento, Color(0.8, 0.9, 1.0)), 0.9)
	return nombre


func esta_quemada() -> bool:
	return _t_quemada > 0.0 and not muerto


## Multiplicador de velocidad de los estados de `aplicar_estado` (1 = sin estado).
func mult_velocidad_estado() -> float:
	# 6/11 (B3): el escombro de su casilla la frena (`EstadosSuelo3D.factor_velocidad`). Aqui y no en cada estado de movimiento: es el unico multiplicador que ya entra en `vel`.
	var suelo: float = Terreno3D.estados.factor_velocidad(Terreno3D.celda_de(position)) if Terreno3D.estados != null else 1.0
	return (_x_est_vel if _t_est_vel > 0.0 else 1.0) * suelo


## 6/11 (B7): pisar una casilla ELECTRIFICADA te descarga cada `ELECTRIFICADA_TICK` s: `aplicar_estado("rayo")` (aturdida corta) + daño ambiental. En el aire o nadando no (no tocas el suelo).
func _suelo_electrico(delta: float) -> void:
	if muerto or not en_suelo or nadando or Terreno3D.estados == null:
		_tick_electrica = 0.0
		return
	if not Terreno3D.estados.tiene(Terreno3D.celda_de(position), EstadosSuelo3D.ELECTRIFICADA):
		_tick_electrica = 0.0
		return
	_tick_electrica -= delta
	if _tick_electrica <= 0.0:
		_tick_electrica = ELECTRIFICADA_TICK
		aplicar_estado("rayo", RAYO_ATURDE_S)
		dano_ambiental(ELECTRIFICADA_DANO, "rayo")


func _estados_paso(delta: float) -> void:
	_t_est_vel = maxf(0.0, _t_est_vel - delta)
	_suelo_electrico(delta)
	if _t_quemada > 0.0 and not muerto:
		_t_quemada = maxf(0.0, _t_quemada - delta)
		_tick_quemada -= delta
		if _tick_quemada <= 0.0:
			_tick_quemada = QUEMADA_TICK
			dano_ambiental(QUEMADA_DANO, "fuego")


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


## 3/11/2026 · R4 (decisión de Pablo: «ᛏ + ᚷ eleva lo que haya dentro»): contrato `elevar`, hermano de `push`: un pilar que crece alza a la jugadora hasta `altura_u` (u sobre el suelo de su casilla) con el MISMO salto de siempre
## (`vy` y `en_suelo`, ver `_vertical`): sube a la velocidad que hace falta para seguir la cima (con tope) y, al acabar el pilar, cae por su gravedad.
const ELEVAR_VY_MAX: float = 7.0

func elevar(altura_u: float, dt: float = 0.016) -> void:
	if muerto or nadando:
		return
	var objetivo: float = Terreno3D.y_pies(Terreno3D.celda_de(position)) + altura_u
	if position.y >= objetivo - 0.02:
		return
	en_suelo = false
	vy = clampf((objetivo - position.y) / maxf(dt, 0.001), 0.0, ELEVAR_VY_MAX)       # sube justo lo que le falta para la cima (sin arrastrar la inercia más allá de ella)


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
	_t_enraizada = 0.0
	_t_est_vel = 0.0
	_t_quemada = 0.0                     # morir quita los estados de `aplicar_estado`: no reaparece ardiendo
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
	aguante = AGUANTE_MAX
	tinta.rellenar()                         # al reaparecer, tinta llena
	position = puntos_inicio
	vy = 0.0
	en_suelo = true
	_empuje = Vector3.ZERO
	_t_inv = 1.2
	pj.animacion_actual = ""
	pj.jugar("idle")
	PlayLog.event("reaparece")
	Sfx.play_ui("reaparecer")                         # gamefeel U2: un tono suave de vuelta
	Sensacion3D.reaparece(self)                       # y una viñeta clara que se abre (0,6 s)
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
	_t_enraizada = maxf(0.0, _t_enraizada - delta)
	if _veneno_t > 0.0 and not muerto:
		_veneno_t -= delta
		_veneno_tick -= delta
		if _veneno_tick <= 0.0:
			_veneno_tick = TICK_VENENO
			vida = _vida_tras_veneno(_veneno_dps * TICK_VENENO)      # 6/11: no mata (VENENO_PUEDE_MATAR)
			Combate3D.flotante(mundo, position + Vector3(0, 1.6, 0), str(int(ceil(_veneno_dps * TICK_VENENO))), Color(0.55, 0.9, 0.35), 0.8)
			vida_cambiada.emit(vida, Estado.i().vida_max)
			if vida <= 0.0:
				_morir()
	_veneno_pilas_paso(delta)
	_estados_paso(delta)
	var zona: Array = Mundo3D.estado_zona(Terreno3D.celda_de(position))        # F4: calor, frío, vendaval... (casi siempre [])
	_actualizar_aguante(delta, zona)
	if not zona.is_empty():
		_veneno_de_zona(zona)
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
		if Input.is_action_pressed("mover_izquierda"):
			entrada.x -= 1.0
		if Input.is_action_pressed("mover_derecha"):
			entrada.x += 1.0
		if Input.is_action_pressed("mover_adelante"):
			entrada.y -= 1.0
		if Input.is_action_pressed("mover_atras"):
			entrada.y += 1.0
	var correr: bool = libre and not apuntando_rapido and not lleva_carga() and Input.is_action_pressed("correr")     # A1: apuntando de pie-andando no se corre ni se salta
	var salto: bool = libre and not apuntando_rapido and not lleva_carga() and salto_activo and _t_enraizada <= 0.0 and Input.is_action_pressed("saltar")
	# Las teclas son de PANTALLA: W = «hacia arriba» como la ve el jugador, sea cual sea el giro de la cámara (Q/E, de 90° en 90°).
	# Se gira el vector de entrada lo mismo que la cámara; así la tecla que lleva hacia donde mira el personaje en pantalla
	# sigue siendo la misma al girarla. Mismo cálculo que el mover propio de la maqueta (PruebaTest2._process): la voltereta,
	# la mirada y la animación parten de este `mov` ya girado, así que ahí no hay que tocar nada.
	var mov := Vector3(entrada.x, 0.0, entrada.y).normalized().rotated(Vector3.UP, deg_to_rad(_giro_camara()))
	_gestionar_acciones(libre, mov)
	if _t_golpe > 0.0 or _t_beber > 0.0 or _lanzando or _t_gesto > 0.0 or _t_pegar > 0.0 or (carga != null and carga.quieta()):
		mov = Vector3.ZERO           # el golpe te frena; beber, el clip de lanzar (6.2b), los gestos (agacharse...) y coger o lanzar algo te dejan quieto hasta que acaban
	if _t_enraizada > 0.0:
		mov = Vector3.ZERO           # 6/11: las raíces del elemental te sujetan los pies (puedes lanzar, no andar)
	var vel: float = _rampa_velocidad(correr and mov != Vector3.ZERO, delta) * (MULT_NADO if nadando else 1.0) * mult_velocidad_estado()
	_actualizar_corre_real(mov != Vector3.ZERO)
	if carga != null:
		vel *= carga.mult_vel()           # cargando: ×0,7 (CargarObjeto3D.COGIBLES)
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
	if not zona.is_empty():
		paso += _viento_paso(delta, zona)          # F4: el vendaval te empuja (salvo tras un muro)
	if _t_enraizada > 0.0:
		paso = Vector3.ZERO                        # 6/11: enraizada ni siquiera el viento o un empujón te mueven
		vel_suelo = Vector3.ZERO
		_vel_hielo = Vector3.ZERO
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
			_sonar_pasos(position.distance_to(antes), corre_real)
		if _t_roll > 0.0 and position.distance_to(antes) < 0.0001:
			_t_roll = 0.0                           # choca con algo: la voltereta se acaba ahí
		if en_hielo and position.distance_to(antes) < paso.length() * 0.25:
			_empujar_bloque_al_resbalar(_vel_hielo)   # 13/11: si es un bloque de hielo y chocó de frente, lo empuja
			_vel_hielo = Vector3.ZERO               # choca contra algo: se para (si no, seguiría empujando la pared)
	if mov != Vector3.ZERO:
		if not apuntando_rapido:                       # A1: apuntando, la mirada la manda el Lanzador (hacia el ratón), no el rumbo
			_mirada = mov                                  # la dirección lógica (voltereta, golpe, lanzar) es la del rumbo, al instante; lo que gira suave es el modelo
			pj.girar_hacia(mov, delta * (HIELO_GIRO if en_hielo else 1.0), VEL_GIRO_CORRER if corre_real else VEL_GIRO_ANDAR)
		if mundo.has_method("marcar_pisado") and not nadando:
			mundo.call("marcar_pisado", Terreno3D.celda_de(position), Caminar3D.PISADO_CORRER if (corriendo and Sensacion3D.ACTIVA) else Caminar3D.PISADO_ANDAR)    # gamefeel W2: más marcado al correr

	_vertical(delta, salto)
	_animar(mov, corre_real)
	Caminar3D.actualizar(self, mov != Vector3.ZERO, delta)     # 2/11 (gamefeel W1-W5): cuerpo, cámara, rastro de la hierba, agua, hojas y pájaros
	_actualizar_sonido(delta)
	_sincronizar()
	_actualizar_hud()


## 4/11 · ACELERACIÓN andar↔correr. Devuelve la velocidad base de este fotograma (sin el factor de nado): `vel_marcha` sube de `_vel_andar` a `_vel_correr` en `T_ANDAR_A_CORRER` s y baja
## en `T_CORRER_A_ANDAR` (rampas lineales). Quieta (o sin la tecla de correr) la meta es la de andar: el siguiente arranque corriendo empieza gradual, no a tope.
func _rampa_velocidad(quiere_correr: bool, delta: float) -> float:
	var meta: float = _vel_correr if quiere_correr else _vel_andar
	if vel_marcha < 0.0:
		vel_marcha = _vel_andar
	var salto: float = maxf(_vel_correr - _vel_andar, 0.01)
	var tasa: float = salto / (T_ANDAR_A_CORRER if meta > vel_marcha else T_CORRER_A_ANDAR)
	vel_marcha = move_toward(vel_marcha, meta, tasa * delta)
	return vel_marcha


## 4/11 · ¿Va corriendo DE VERDAD? Por la velocidad de la rampa (no por la tecla), con histéresis. Lo leen `_animar` (clip walk/run) y los pasos (distancia entre pasos, polvo).
func _actualizar_corre_real(hay_mov: bool) -> void:
	if not hay_mov:
		corre_real = false
		return
	var dif: float = _vel_correr - _vel_andar
	if corre_real:
		corre_real = vel_marcha >= _vel_andar + FRACCION_CORRE_SALE * dif
	else:
		corre_real = vel_marcha >= _vel_andar + FRACCION_CORRE_ENTRA * dif


## 13/11 (tarea 18) · La jugadora que resbala sobre hielo y choca DE FRENTE (la velocidad apunta a una cara, componente ≥ `EMPUJE_CARDINAL`) contra un bloque de HIELO en reposo lo empuja: cuenta como un
## empujón (`empujones`) y el bloque sale resbalando (`empujar(dir, false, true)`: ya suelto, sin acoplarla). Contra un bloque de piedra o de roca (o con `BloqueEmpujable3D.EMPUJE_AL_RESBALAR` en false) no
## hace nada aquí: se para como contra una pared. Necesita llegar con `VEL_MIN_EMPUJE_RESBALANDO` u/s y tener el bloque a una casilla o menos por delante. Devuelve true si lo empujó.
func _empujar_bloque_al_resbalar(v: Vector3) -> bool:
	if not BloqueEmpujable3D.EMPUJE_AL_RESBALAR or _acoplada or v.length() < BloqueEmpujable3D.VEL_MIN_EMPUJE_RESBALANDO:
		return false
	var m := Vector2(v.x, v.z)
	var dir: Vector2i = Vector2i.ZERO
	if absf(m.x) >= EMPUJE_CARDINAL * m.length():
		dir = Vector2i(1 if m.x > 0.0 else -1, 0)
	elif absf(m.y) >= EMPUJE_CARDINAL * m.length():
		dir = Vector2i(0, 1 if m.y > 0.0 else -1)
	if dir == Vector2i.ZERO:
		return false
	var d3 := Vector3(float(dir.x), 0.0, float(dir.y))
	var yo: Vector2i = Terreno3D.celda_de(position)
	for n in get_tree().get_nodes_in_group("empujable"):
		if not is_instance_valid(n) or not (n is BloqueEmpujable3D):
			continue
		var b: BloqueEmpujable3D = n as BloqueEmpujable3D
		if b.material != "hielo" or b.moviendo:
			continue
		var delante: float = (b.global_position - position).dot(d3)
		if (b.celda == yo + dir or (b.celda == yo and delante > 0.0)) and delante <= Terreno3D.casilla:
			return b.empujar(dir, false, true)
	return false


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
		# 12/11: la jugadora choca con el CONTORNO del bloque (Terreno3D.es_parcial(c, true)), no con su casilla entera: para llegar a tocar una roca pequeña entra en la
		# casilla de la roca. Por eso el bloque puede estar en la casilla vecina o en la suya propia (siempre por delante de ella).
		var d3 := Vector3(float(dir.x), 0.0, float(dir.y))
		for n in get_tree().get_nodes_in_group("empujable"):
			if not is_instance_valid(n) or not (n is Node3D):
				continue
			var cb: Variant = n.get("celda")
			if cb == vecina or (cb == yo and ((n as Node3D).global_position - position).dot(d3) > 0.0):
				bloque = n
				if cb == vecina:
					break
		if bloque != null:
			var c_bloque: Vector2i = bloque.get("celda")
			if Terreno3D.es_parcial(c_bloque, true):
				# con forma conocida: pegada = un paso corto más hacia él ya choca con su contorno
				if not Terreno3D.choca_huella(c_bloque, position + d3 * EMPUJE_TOQUE):
					bloque = null
			else:
				# sin forma (la casilla entera bloquea): lo de siempre, adelantada hacia el borde de su casilla
				var centro: Vector3 = Terreno3D.centro_de(yo)
				var adelantada: float = (position.x - centro.x) * float(dir.x) + (position.z - centro.z) * float(dir.y)
				if c_bloque != vecina or adelantada < EMPUJE_PEGADA * Terreno3D.casilla:
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
	Caminar3D.paso(self, correr)         # 2/11 (gamefeel W1/W4): polvo, huellas y vadeo en cada paso
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
	var ctrl: bool = libre and not lleva_carga() and Input.is_action_pressed("voltereta")
	var ocupado: bool = _lanzando or _t_golpe > 0.0 or _t_gesto > 0.0 or _t_pegar > 0.0 or (lanz != null and lanz.modo_lanzar)
	var puede_rodar: bool = _roll_cd <= 0.0 and _t_roll <= 0.0 and _t_beber <= 0.0 and not ocupado and not nadando and en_suelo and _t_enraizada <= 0.0
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
	var tecla_golpe: bool = libre and not lleva_carga() and Input.is_action_pressed("golpe")
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
	# C6: con fuego/hielo/agua seleccionado deja su estado en la casilla de la que sale (4 de tinta; ver VolteretaRastro). Antes de moverse, para que sea la de salida.
	VolteretaRastro.dejar(lanz, tinta, Terreno3D.celda_de(position))
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
## 10/11 (docs/PROPUESTA_CONSUMIBLES.md §2): la G (acción `lanzar_objeto`) lanza el lanzable elegido de la rueda (`Estado.lanzable_elegido`) hacia el punto del
## suelo bajo el ratón (`Lanzador3D.punto_en_suelo`; sin lanzador, 4 u hacia donde mira). Se marca como atendida para que no llegue a las teclas de depuración de
## la maqueta (allí la G enseña u oculta la hierba). La rueda que se abre con Alt es del Pipeline; hasta entonces se elige con `Estado.elegir_hueco`.
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo and ev.is_action("lanzar_objeto"):
		get_viewport().set_input_as_handled()
		lanzar_objeto()


## Lanza el elegido de la rueda. `hacia` = dónde apunta (Vector3.INF = el ratón). Devuelve el proyectil o null (y avisa por qué).
func lanzar_objeto(hacia: Vector3 = Vector3.INF) -> Lanzable3D:
	if muerto or _t_beber > 0.0 or _t_roll > 0.0 or lleva_carga() or nadando:
		return null
	var id: String = Estado.i().lanzable_elegido()
	var motivo: String = Lanzables.motivo_no(id)
	if motivo != "":
		if lanz != null and lanz.has_method("avisar"):
			lanz.call("avisar", motivo, Color(1.0, 0.75, 0.55))
		return null
	var objetivo: Vector3 = hacia
	if objetivo == Vector3.INF:
		if lanz != null and lanz.has_method("punto_en_suelo") and is_inside_tree():
			objetivo = lanz.call("punto_en_suelo", get_viewport().get_mouse_position())
		else:
			objetivo = position + _mirada.normalized() * 4.0
	var desde: Vector3 = position + Vector3(0.0, 1.1, 0.0)
	return Lanzables.lanzar(mundo, lanz, self, id, desde, objetivo)


func usar_pocion(id: String = "pocion") -> bool:
	var ocupado: bool = _lanzando or _t_golpe > 0.0 or _t_gesto > 0.0 or _t_pegar > 0.0 or (lanz != null and lanz.modo_lanzar)
	if _t_beber <= 0.0 and _t_roll <= 0.0 and not ocupado and not nadando and en_suelo and not muerto \
			and vida < Estado.i().vida_max and Estado.i().cuenta(id) > 0:
		_beber_id = id
		_iniciar_beber()
		return true
	return false


func _iniciar_beber() -> void:
	_t_beber = T_BEBER
	if pj.beber(T_BEBER) <= 0.0:                   # Pipeline: stand_drink recortado + poción en la mano
		pj.jugar("drink", true)                    # sin clip: al menos que dure lo mismo
	_sonar_beber()
	PlayLog.event("beber_inicio", {"pociones": Estado.i().cuenta("pocion")})


## Gamefeel M4 (31/10): los «glu glu» de la poción en bucle `T_SONIDO_BEBER_S` s acompañando al clip `drink` (se corta antes si acaba o te golpean).
static var T_SONIDO_BEBER_S: float = 1.2
## ... y el destello verde de la jugadora al terminar de beber (emisión de sus materiales, como el hit flash de `Combate3D`, que se apaga solo).
static var COLOR_DESTELLO_BEBER: Color = Color(0.55, 1.0, 0.6)
static var T_DESTELLO_BEBER_S: float = 0.2
static var ENERGIA_DESTELLO_BEBER: float = 1.2
static var DB_CANCELAR_BEBER: float = -12.0
var _snd_beber: Node = null
var _tw_destello_beber: Tween = null
var _emision_destello_beber: Array = []            ## [material, enabled, color, energía] de cada material antes del destello, para devolverlo igual


func _sonar_beber() -> void:
	_parar_sonido_beber(0.0)
	_snd_beber = Sfx.bucle(self, "pocion")
	if _snd_beber != null and is_inside_tree():
		get_tree().create_timer(T_SONIDO_BEBER_S).timeout.connect(_cortar_sonido_beber.bind(weakref(_snd_beber)))


## Pasado `T_SONIDO_BEBER_S` corta el bucle de la poción si aún suena (el reproductor puede haberse liberado ya al terminar o cancelar: por eso un WeakRef y no una captura).
func _cortar_sonido_beber(ref: WeakRef) -> void:
	var p: Object = ref.get_ref()
	if p != null:
		Sfx.parar(p as Node, 0.1)


func _parar_sonido_beber(fundido: float = 0.1) -> void:
	if _snd_beber != null and is_instance_valid(_snd_beber):
		Sfx.parar(_snd_beber, fundido)
	_snd_beber = null


## Destello de color sobre los materiales de la jugadora: emisión de `color` a `energia` que baja a 0 en `dur` s y devuelve la emisión que tenían. Sin sensación, no se hace.
func destello_color(color: Color, dur: float, energia: float) -> void:
	if not Sensacion3D.ACTIVA or pj == null or not is_inside_tree():
		return
	_fin_destello_color()
	for m in pj._materiales:
		if is_instance_valid(m):
			_emision_destello_beber.append([m, m.emission_enabled, m.emission, m.emission_energy_multiplier])
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = energia
	pj.sincronizar_juguete()
	_tw_destello_beber = create_tween()
	_tw_destello_beber.tween_method(_paso_destello_color.bind(energia), 1.0, 0.0, dur)
	_tw_destello_beber.tween_callback(_fin_destello_color)


func _paso_destello_color(k: float, energia: float) -> void:
	for e in _emision_destello_beber:
		if is_instance_valid(e[0]):
			(e[0] as StandardMaterial3D).emission_energy_multiplier = energia * k
	pj.sincronizar_juguete()


func _fin_destello_color() -> void:
	if _tw_destello_beber != null and _tw_destello_beber.is_valid():
		_tw_destello_beber.kill()
	for e in _emision_destello_beber:
		if is_instance_valid(e[0]):
			var m: StandardMaterial3D = e[0]
			m.emission_enabled = bool(e[1])
			m.emission = e[2]
			m.emission_energy_multiplier = float(e[3])
	_emision_destello_beber.clear()
	if pj != null:
		pj.sincronizar_juguete()


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
	_parar_sonido_beber()
	if Estado.i().quitar(_beber_id):
		var cura: float = Mejoras.cura_de(_beber_id) if Objetos.efecto(_beber_id).has("cura") else CURA_POCION   # F3: la de la tabla + la mejora «Poción más dulce»
		curar(cura)
		var ef: Dictionary = Objetos.efecto(_beber_id)
		if ef.has("regen") and hud_eow != null and hud_eow.get("consumibles") is Consumibles:
			(hud_eow.get("consumibles") as Consumibles).iniciar_regen(float(ef["regen"]), float(ef.get("dura", 10.0)))   # 10/11: la poción mayor
		Combate3D.flotante(mundo, position + Vector3(0, 1.6, 0), "+%d" % int(cura), Color(0.5, 1.0, 0.55))
		Sfx.play_ui("pocion_fin")                                       # M4: el último trago (la poción +15 %)
		destello_color(COLOR_DESTELLO_BEBER, T_DESTELLO_BEBER_S, ENERGIA_DESTELLO_BEBER)
		if hud_eow != null:
			hud_eow.pulso_vida()
		PlayLog.event("beber_fin", {"vida": vida})
	pj.animacion_actual = ""


func _cancelar_beber() -> void:
	_t_beber = 0.0
	_parar_sonido_beber()
	Sfx.play_ui("no_puedes", DB_CANCELAR_BEBER)         # M4: el golpe te cortó el trago
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
	if not _caida_plataforma.is_empty():
		return false
	if TroncoEstanque3D.bloquea_a(p, position.y) and not TroncoEstanque3D.bloquea_a(position, position.y):
		return false                       # 22/10: el tronco del estanque (aún en el fondo del cauce) no se atraviesa
	var c: Vector2i = Terreno3D.celda_de(p)
	var actual: Vector2i = Terreno3D.celda_de(position)
	var parcial: bool = Terreno3D.es_parcial(c, true)      # 12/11: también el contorno del modelo de los objetos (rompibles, barriles, bloques…), no su casilla entera
	if c == actual:
		if parcial and Terreno3D.choca_huella(c, p) and not Terreno3D.choca_huella(c, position):
			return false                   # dentro de una casilla bloqueada solo se roza lo que no es el objeto
		return Terreno3D.en_mapa(c) or Terreno3D.plataformas_tierra.has(c)
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
	if not _caida_plataforma.is_empty():
		if c != _caida_plataforma["celda"] or Terreno3D.plataformas_tierra.has(c):
			_caida_plataforma.clear()
		else:
			vy -= GRAVEDAD * delta
			position.y += vy * delta
			if position.y <= float(_caida_plataforma["fondo"]):
				_volver_a_suelo_seguro(c)
			_salto_antes = salto
			return
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

	var suelo: float = Terreno3D.y_pies(c) + Terreno3D.realce_en(position)      # 4/11: encima de una piedra o un tronco bajo, los pies suben (no bloquean: ver ColisionPieza.REALCE)
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
				Sfx.play(self, "salto")     # 13/11 (inventario SFX): antes no sonaba
	if not en_suelo:
		vy -= GRAVEDAD * delta
		position.y += vy * delta
		if position.y <= suelo and vy <= 0.0:
			if vy <= -Sensacion3D.VY_POLVO_CAIDA and not agua:
				Sensacion3D.polvo(mundo, Vector3(position.x, suelo, position.z), Sensacion3D.POLVO_CAIDA)     # gamefeel lote 2: cae de alto
			if not agua:
				Sfx.play(self, "aterrizar")     # 13/11 (inventario SFX): antes no sonaba
				Caminar3D.aterrizar(self, vy)     # gamefeel W1: el cuerpo se aplasta un poco al tocar suelo
			position.y = suelo
			vy = 0.0
			en_suelo = true
			if agua:
				_cambiar_nado(true)
	_salto_antes = salto
	# Por si algo ha cambiado el suelo justo debajo (el hielo se derrite bajo los pies ya apoyados)
	if en_suelo and agua and not nadando and position.y <= Terreno3D.superficie_agua(c) + 0.3:
		_cambiar_nado(true)


func caer_de_plataforma(celda: Vector2i, anclaje: Vector2i) -> void:
	var fondo: float = position.y - 0.9
	if not Terreno3D.es_vacio(celda) and Terreno3D.es_agua(celda):
		fondo = minf(Terreno3D.superficie_agua(celda), position.y - 0.45)
	_caida_plataforma = {"celda": celda, "anclaje": anclaje, "fondo": fondo}
	en_suelo = false
	vy = minf(vy, 0.0)


func _volver_a_suelo_seguro(desde: Vector2i) -> void:
	var destino: Vector2i = _caida_plataforma["anclaje"]
	var distancia: int = 2147483647
	var lado: int = Terreno3D.lado_del_mapa()
	for z in range(lado):
		for x in range(lado):
			var c := Vector2i(x, z)
			var d: int = (c - desde).length_squared()
			if d >= distancia:
				continue
			if not Terreno3D.plataformas_tierra.has(c):
				if Terreno3D.es_agua(c) or not Terreno3D.pisable(c, 0, true, maxi(MAX_NIVELES_SUBIBLES, tope_niveles_nivel), false):
					continue
			destino = c
			distancia = d
	_caida_plataforma.clear()
	position = Terreno3D.centro_de(destino, Terreno3D.y_pies(destino))
	vy = 0.0
	en_suelo = true


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
		Sfx.play(self, "chapoteo")     # 13/11 (inventario SFX): antes no sonaba
	nado_cambiado.emit(n)


## A1: true = otro (el laboratorio, pestaña F5) lleva la animación del personaje; el Jugador3D no pide idle/andar/correr/nadar cada fotograma. Solo el laboratorio lo pone.
var animacion_externa: bool = false


func _animar(mov: Vector3, correr: bool) -> void:
	if animacion_externa:
		return
	if _t_roll > 0.0 or _t_beber > 0.0 or _t_gesto > 0.0 or _t_pegar > 0.0:
		return                                         # el clip de voltereta / beber / gesto ya está sonando
	if carga != null and carga.animar(mov):
		return                                         # 4/11: cargando un objeto (andar a su ritmo, idle al lanzar o soltar)
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
	var tienda := TiendaUI.new()           # 11/11: la pantalla de tienda; se abre sola cuando el alquimista o la librera avisan (`Tiendas.tienda_abierta`)
	tienda.name = "TiendaUI"
	add_child(tienda)
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
