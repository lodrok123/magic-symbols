extends "res://herramientas/escenario_base.gd"
## PRUEBA DE COGER Y LANZAR (4/11, jugador/cargar_objeto_3d.gd; docs/RECOGER_LANZAR_2026-11-04.md). Sin ventana, a 30 fps fijos:
##     godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_recoger_lanzar.gd
## Escena de verdad (PruebaBosque, jugadora, Lanzador3D, goblins), la E y la Q son EVENTOS DE TECLA (Input.parse_input_event), no llamadas. Mide:
##   coger un jarrón (tiempos de la agachada, casilla liberada, el objeto sobre la cabeza), que cargando no se corre (ni rueda, golpea o lanza hechizos), la velocidad ×0,7,
##   lanzar (cae a la distancia de la tabla), que se rompe y suelta botín, que daña a un goblin con empuje, que Q lo deja entero delante (y se puede volver a coger),
##   que un golpe recibido lo tira y rompe, un cogible suelto cualquiera (piedra), el interruptor, y (segunda escena) que E sobre un cofre sigue abriéndolo aunque haya un jarrón al lado.
## 4/11 (clips de Meshy, arte/meshy/jugadora_carga_clips.glb): además, que con jugadora_base la pose es la de los clips (los seis roles existen con duración e instantes medidos, `cargar_idle` con las manos
## a la altura de la coronilla, `cargar_andar` en el sitio y a la velocidad del suelo, `levantar` con el agarre en T_FONDO, `lanzar_objeto` con la suelta en su instante, `dejar_objeto`), la ruta del objeto
## pequeño (`coger_lanzar`, sin cargarlo) y que la capa procedural BrazosCarga3D sigue de respaldo si al modelo le falta un clip.

const RUTA_02: String = "res://escenas/PruebaBosque02.tscn"
const CLARO_X: Vector2i = Vector2i(-3, 6)         ## el claro buscado: casillas llanas y libres de claro+CLARO_X.x a claro+CLARO_X.y en X (la jugadora lanza hacia +X)
const CLARO_Y: int = 3                            ## y de claro-CLARO_Y a claro+CLARO_Y

var j: Jugador3D = null
var c: CargarObjeto3D = null
var claro: Vector2i = Vector2i.ZERO
var _n: int = 0


func _escenario() -> void:
	Flags.nuevo()
	Misiones.nuevo()
	Estado.nuevo()
	await cargar(RUTA_BOSQUE, false)
	if maqueta == null or jugador == null:
		return
	j = jugador as Jugador3D
	c = j.carga
	_ok("1 el jugador trae el nodo CargarObjeto3D y el interruptor está en true", c != null and CargarObjeto3D.RECOGER_ACTIVO and c.activo)
	if c == null:
		return
	lanzador.tinta = null
	j.vida = 100000.0
	_claro()
	await _coger()
	await _clips_cargando()
	await _no_correr()
	await _lanzar_y_romper()
	await _dano_goblin()
	await _soltar()
	await _golpe_recibido()
	await _suelto_generico()
	await _pequeno()
	await _respaldo()
	await _interruptor()
	await _cofre()


# ---------------------------------------------------------------------------------------------------------------------
#  Montaje
# ---------------------------------------------------------------------------------------------------------------------

## Un claro llano y libre de (2·MEDIO+1)² casillas lo más cerca posible de la jugadora; los goblins del nivel, lejos y quietos.
func _claro() -> void:
	var ancho: int = int(maqueta.get("_ancho"))
	var alto: int = int(maqueta.get("_alto"))
	var desde: Vector2i = celda_jugador()
	var mejor: Vector2i = Vector2i(-1, -1)
	var dmejor: float = INF
	for y in range(CLARO_Y + 1, alto - CLARO_Y - 1):
		for x in range(-CLARO_X.x + 1, ancho - CLARO_X.y - 1):
			var cc := Vector2i(x, y)
			var n0: int = Terreno3D.altura_en(cc)
			var bien: bool = true
			for dy in range(-CLARO_Y, CLARO_Y + 1):
				for dx in range(CLARO_X.x, CLARO_X.y + 1):
					var v := cc + Vector2i(dx, dy)
					if Terreno3D.es_agua(v) or Terreno3D.bloqueada(v) or Terreno3D.altura_en(v) != n0:
						bien = false
						break
				if not bien:
					break
			if bien and Vector2(cc - desde).length() < dmejor:
				dmejor = Vector2(cc - desde).length()
				mejor = cc
	_ok("2 hay un claro llano de %d×%d casillas" % [CLARO_X.y - CLARO_X.x + 1, CLARO_Y * 2 + 1], mejor.x >= 0, str(mejor))
	claro = mejor
	for g in get_nodes_in_group("combate3d"):
		(g as Combate3D).quieto = true
		(g as Combate3D).position = Vector3(-500.0, 0.0, -500.0)


func _jarron(cel: Vector2i, id: String, tipo: String = "jarron", botin: String = "oro", cant: int = 7) -> Rompible3D:
	var r := Rompible3D.new()
	r.name = id
	r.preparar(cel, tipo, botin, cant, false, "", maqueta)
	maqueta.add_child(r)
	return r


func _pulsar(tecla: Key, frames: int = 2) -> void:
	_tecla(tecla, true)
	await avanzar(frames)
	_tecla(tecla, false)
	await avanzar(1)


## Espera hasta que `cond` sea cierta (tope `max_s`); devuelve los segundos que tardó (-1 si no llegó).
func _hasta(cond: Callable, max_s: float = 3.0) -> float:
	var t0: float = reloj.t
	while reloj.t - t0 < max_s:
		if bool(cond.call()):
			return reloj.t - t0
		await process_frame
	return -1.0


func _poner(cel: Vector2i, mira: Vector3 = Vector3.RIGHT) -> void:
	colocar_jugador(cel)
	j.mirar_hacia(mira)
	(j.pj as Pj3D).mirar(mira, 1.0)


func _poner_mirada(mira: Vector3) -> void:
	j.mirar_hacia(mira)
	(j.pj as Pj3D).mirar(mira, 1.0)


func _plano(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------------------------------------------------------------
#  1. Coger
# ---------------------------------------------------------------------------------------------------------------------

var jar: Rompible3D = null


func _coger() -> void:
	await avanzar_s(0.5)
	var cj: Vector2i = claro + Vector2i(-1, 0)
	_poner(claro)
	await avanzar_s(0.3)
	jar = _jarron(cj, "jarron_a")
	_ok("3 el jarrón nace en el grupo cogible con el metadato «cogible» = jarron", jar.is_in_group("cogible") and String(jar.get_meta("cogible")) == "jarron")
	_ok("3 el jarrón tapa su casilla", Terreno3D.bloqueada(cj))
	await avanzar(2)
	_ok("3 sin hacer nada, el candidato es el jarrón", c.candidato() == jar, str(c.candidato()))
	_ok("3 no hay otra interacción más prioritaria a mano", not c.hay_otra_interaccion())
	_ok("3 la pista [E] ofrece «Coger»", PistaProximidad.accion_actual() == "Coger" or c.accion_pista() == "Coger", PistaProximidad.accion_actual())
	var vel_ant: float = await _velocidad(false)          # andar sin carga: se mide aquí, en el mismo claro
	_poner(claro)
	await avanzar_s(0.3)
	var y0: float = jar.global_position.y
	var t0: float = reloj.t
	_tecla(KEY_E, true)
	await avanzar(1)
	_tecla(KEY_E, false)
	await avanzar(1)
	_ok("3 E empieza a cogerlo (estado COGIENDO)", c.estado == CargarObjeto3D.Estado.COGIENDO, str(c.estado))
	_ok("3 mientras se agacha no se anda (gesto)", j.en_gesto())
	var t_fondo: float = await _hasta(func() -> bool: return bool(c._agarrado), 1.5)
	var t_carga: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	var total: float = reloj.t - t0
	var fondo_real: float = float(c.ultimo.get("t_fondo", 9.0))
	print("      tiempos: agarra a los %.2f s de empezar la agachada (T_FONDO %.2f) · cargando a los %.2f s de pulsar E" % [fondo_real, CargarObjeto3D.T_FONDO, total])
	_ok("3 agarra el objeto en el fondo de la agachada (~%.2f s)" % CargarObjeto3D.T_FONDO, t_fondo >= 0.0 and absf(fondo_real - CargarObjeto3D.T_FONDO) < 0.1, str(c.ultimo))
	_ok("3 y lo tiene sobre la cabeza a los 0,5-0,9 s de pulsar E (EoW: ~0,6 s)", t_carga >= 0.0 and total > 0.5 and total < 0.9, "%.2f s" % total)
	_ok("3 el jarrón está en brazos y no tapa la casilla de origen", jar.en_brazos and not Terreno3D.bloqueada(claro + Vector2i(-1, 0)))
	var cabeza: float = j.position.y + (j.pj as Pj3D).alto_modelo() * (j.pj as Pj3D).scale.y
	_ok("3 el objeto va sobre la cabeza (base %.2f u, coronilla %.2f u; la base se hunde ≤ %.2f u en ella)" % [jar.global_position.y, cabeza, CargarObjeto3D.HUNDE_EN_CABEZA], jar.global_position.y >= cabeza - CargarObjeto3D.HUNDE_EN_CABEZA - 0.05, "alto del modelo %.2f · escala %.2f" % [(j.pj as Pj3D).alto_modelo(), (j.pj as Pj3D).scale.y])
	_ok("3 y sobre ella (a ≤ 0,4 u en el plano)", _plano(jar.global_position, j.position) < 0.4, "%.2f u" % _plano(jar.global_position, j.position))
	_ok("3 con él en brazos, F/Ctrl/Shift/hechizos no valen (lleva_carga)", j.lleva_carga() and not j.puede_lanzar())
	_ok("3 el jarrón no se rompe solo estando en brazos (golpear no hace nada)", (func() -> bool:
		jar.golpear(Vector3.ZERO)
		return not jar.roto_ya).call())
	print("      velocidad andando sin carga: %.2f u/s" % vel_ant)
	_vel_sin = vel_ant


var _vel_sin: float = 0.0

const ROLES_CLIPS: Array = ["cargar_idle", "cargar_andar", "levantar", "lanzar_objeto", "dejar_objeto", "coger_lanzar"]
## Roles de los clips de Meshy con instante medido (Pj3D.INSTANTE_CLIP) y su valor esperado (s del clip a velocidad 1; arte/meshy/medir_clips_carga.py).
const INSTANTES: Dictionary = {"levantar": 1.05, "dejar_objeto": 1.3, "lanzar_objeto": 0.41, "coger_lanzar_agarre": 0.72, "coger_lanzar": 2.13}


## Posición de un hueso (Mixamo, sin prefijo) en el mundo, con la pose que tenga el esqueleto ahora.
func _hueso(nombre: String) -> Vector3:
	var sk: Skeleton3D = (j.pj as Pj3D)._esqueleto()
	var i: int = sk.find_bone("mixamorig_" + nombre)
	return sk.global_transform * sk.get_bone_global_pose(i).origin


# ---------------------------------------------------------------------------------------------------------------------
#  1b. Los clips de Meshy (cargando el jarrón de _coger)
# ---------------------------------------------------------------------------------------------------------------------

func _clips_cargando() -> void:
	var pj: Pj3D = j.pj
	if c.estado != CargarObjeto3D.Estado.CARGANDO:
		_ok("3b (no se pudo cargar: se salta)", false)
		return
	_ok("3b coger usó los clips de Meshy (usa_clips) y no la capa de respaldo", c.usa_clips and c._brazos == null and not c.pequeno)
	for rol in ROLES_CLIPS:
		_ok("3b el rol «%s» existe en jugadora_base (clip «%s», %.2f s)" % [rol, pj.clip_de(rol), pj.duracion(rol)], pj.clip_de(rol) == rol and pj.duracion(rol) > 0.0)
	for k in INSTANTES:
		_ok("3b Pj3D.INSTANTE_CLIP[%s] = %.2f s" % [k, INSTANTES[k]], absf(Pj3D.instante_clip_de(pj.id, k) - float(INSTANTES[k])) < 0.001, str(Pj3D.instante_clip_de(pj.id, k)))
		var rol_k: String = k.replace("_agarre", "")
		_ok("3b …y cae dentro del clip «%s» (%.2f s)" % [rol_k, pj.duracion(rol_k)], Pj3D.instante_clip_de(pj.id, k) > 0.0 and Pj3D.instante_clip_de(pj.id, k) < pj.duracion(rol_k))
	# quieta: cargar_idle y las manos en alto (cinemática real de los huesos)
	_poner_mirada(Vector3.RIGHT)
	await avanzar_s(0.6)
	_ok("3b quieta cargando suena cargar_idle", pj.clip_actual() == "cargar_idle", pj.clip_actual())
	# (manos y coronilla de `skeleton_updated`, con los modificadores puestos: la proporción chibi achica la cabeza a 0,80 y fuera de esa señal HeadTop_End sale 6 cm más alto)
	var mi: Vector3 = c.mano_izq
	var md: Vector3 = c.mano_der
	var coronilla: Vector3 = c.cabeza_top
	var centro_cabeza: Vector3 = _hueso("Head")
	var suelo: float = j.position.y
	print("      cargar_idle (cinemática): manos y %.2f / %.2f u sobre los pies · centro de la cabeza %.2f · coronilla %.2f · separación de las manos %.2f u" % [mi.y - suelo, md.y - suelo, centro_cabeza.y - suelo, coronilla.y - suelo, mi.distance_to(md)])
	_ok("3b cargar_idle: las dos manos por encima del centro de la cabeza (≥ 0,1 u)", mi.y > centro_cabeza.y + 0.1 and md.y > centro_cabeza.y + 0.1)
	_ok("3b …y a la altura de la coronilla (no más de 0,15 u por debajo: la chibi tiene la cabeza grande y las manos no la pasan)", mi.y > coronilla.y - 0.15 and md.y > coronilla.y - 0.15 and mi.distance_to(md) < 0.3)
	# andando: cargar_andar, a la velocidad del suelo, y la cadera en el sitio
	var an: Animation = pj._ap.get_animation(pj.clip_de("cargar_andar"))
	var avance: float = 0.0
	for t in range(an.get_track_count()):
		if an.track_get_type(t) == Animation.TYPE_POSITION_3D and String(an.track_get_path(t)).ends_with("Hips"):
			var p0: Vector3 = an.track_get_key_value(t, 0)
			for kk in range(an.track_get_key_count(t)):
				var pk: Vector3 = an.track_get_key_value(t, kk)
				avance = maxf(avance, Vector2(pk.x - p0.x, pk.z - p0.z).length())
	_ok("3b cargar_andar no avanza la cadera (pista del clip: ≤ 0,10 u del GLB frente a los 0,41 u/ciclo de Meshy), duración %.2f s" % pj.duracion("cargar_andar"), avance <= 0.10, "%.3f u" % avance)
	var centro: Vector3 = Vector3.ZERO
	var muestras: Array = []
	_tecla(KEY_W, true)
	await avanzar_s(0.5)
	var clip_andando: String = pj.clip_actual()
	var v_clip: float = pj.arbol().vel_global
	var v_suelo: float = j.vel_suelo.length()
	for _i in range(30):
		await process_frame
		var rel: Vector3 = _hueso("Hips") - j.position
		muestras.append(Vector2(rel.x, rel.z))
		centro += Vector3(rel.x, 0.0, rel.z)
	_tecla(KEY_W, false)
	centro /= float(muestras.size())
	var rango: float = 0.0
	for m in muestras:
		rango = maxf(rango, (m as Vector2).distance_to(Vector2(centro.x, centro.z)))
	print("      cargar_andar: clip a ×%.2f (suelo %.2f u/s, zancada del clip %.2f u/s a ×1, tope ×%.1f) · la cadera se aleja %.3f u de su media en 1 s andando" % [v_clip, v_suelo, CargarObjeto3D.ZANCADA_CARGAR, CargarObjeto3D.VEL_CARGAR_MAX, rango])
	_ok("3b andando cargando suena cargar_andar", clip_andando == "cargar_andar", clip_andando)
	_ok("3b su velocidad sigue a la del suelo (u/s ÷ zancada, con topes ×%.1f–×%.1f)" % [CargarObjeto3D.VEL_CARGAR_MIN, CargarObjeto3D.VEL_CARGAR_MAX], absf(v_clip - c.vel_clip_andar(v_suelo)) < 0.05, "%.2f vs %.2f" % [v_clip, c.vel_clip_andar(v_suelo)])
	_ok("3b no patina: el suelo (%.2f u/s) no va más rápido que los pasos del clip a su tope (%.2f u/s)" % [v_suelo, CargarObjeto3D.VEL_SUELO_CARGAR], v_suelo <= CargarObjeto3D.VEL_SUELO_CARGAR + 0.03 and v_clip < CargarObjeto3D.VEL_CARGAR_MAX + 0.01, "×%.2f" % v_clip)
	_ok("3b andando (cinemática real) la cadera no avanza respecto al cuerpo: se queda a ≤ 0,12 u de su media", rango <= 0.12, "%.3f u" % rango)
	await avanzar_s(0.4)
	_ok("3b y al parar vuelve a cargar_idle", pj.clip_actual() == "cargar_idle", pj.clip_actual())
	_poner(claro)
	await avanzar_s(0.3)
	var mi2: Vector3 = c.mano_izq
	_ok("3b el objeto sigue sobre la cabeza y las manos (base %.2f u, manos %.2f u, coronilla %.2f u; jarrón al %d %% = %.2f u de alto)" % [jar.global_position.y - j.position.y, mi2.y - j.position.y, c.cabeza_top.y - j.position.y, int(CargarObjeto3D.COGIBLES["jarron"]["escala"] * 100.0), float(CargarObjeto3D.COGIBLES["jarron"]["alto"]) * float(CargarObjeto3D.COGIBLES["jarron"]["escala"])], jar.global_position.y > mi2.y - 0.05 and jar.global_position.y > c.cabeza_top.y - CargarObjeto3D.HUNDE_EN_CABEZA - 0.05 and jar.en_brazos)
	_poner_mirada(Vector3.RIGHT)


## Anda 1 s con W (y Mayús si `corre`) desde el centro del claro y devuelve u/s.
func _velocidad(corre: bool) -> float:
	var p0: Vector3 = j.position
	_tecla(KEY_W, true)
	if corre:
		_tecla(KEY_SHIFT, true)
	await avanzar_s(0.4)                                    # arrancar
	var p1: Vector3 = j.position
	var t1: float = reloj.t
	await avanzar_s(0.8)
	var p2: Vector3 = j.position
	_tecla(KEY_W, false)
	_tecla(KEY_SHIFT, false)
	await avanzar_s(0.3)
	if p0 == p1:
		return 0.0
	return _plano(p2, p1) / 0.8


# ---------------------------------------------------------------------------------------------------------------------
#  2. No correr, no rodar, no golpear
# ---------------------------------------------------------------------------------------------------------------------

func _no_correr() -> void:
	if c.estado != CargarObjeto3D.Estado.CARGANDO:
		_ok("4 (no se pudo cargar: se salta)", false)
		return
	_poner(claro)
	await avanzar_s(0.2)
	var v_andar: float = await _velocidad(false)
	_poner(claro)
	await avanzar_s(0.2)
	var v_mayus: float = await _velocidad(true)
	print("      cargando: andar %.2f u/s · Mayús (correr) %.2f u/s · sin carga %.2f u/s" % [v_andar, v_mayus, _vel_sin])
	var r_esp: float = c.mult_vel()   # la fila (×0,7) con el tope de los clips (0,70 u/s: sin patinar)
	_ok("4 cargando se anda a ×%.2f (%.2f vs %.2f u/s)" % [r_esp, v_andar, _vel_sin], _vel_sin > 0.5 and absf(v_andar / _vel_sin - r_esp) < 0.12, "razón %.2f" % (v_andar / maxf(_vel_sin, 0.001)))
	_ok("4 con Mayús NO corre (la misma velocidad)", absf(v_mayus - v_andar) < 0.15 and not j.corriendo, "%.2f vs %.2f" % [v_mayus, v_andar])
	_poner(claro)
	await avanzar_s(0.3)
	_tecla(KEY_CTRL, true)
	await avanzar(2)
	_tecla(KEY_CTRL, false)
	_ok("4 Ctrl no hace la voltereta", float(j.get("_t_roll")) <= 0.0)
	_tecla(KEY_F, true)
	await avanzar(2)
	_tecla(KEY_F, false)
	_ok("4 F no da el golpe cuerpo a cuerpo", float(j.get("_t_pegar")) <= 0.0 and not j.golpeando())
	_ok("4 con jugadora_base la pose de cargar es la del clip de Meshy (no la capa procedural de respaldo)", c.usa_clips and c._brazos == null, "usa_clips %s · capa %s" % [c.usa_clips, c._brazos])
	# manos y cabeza medidas
	var pj: Pj3D = j.pj
	var mi: Vector3 = c.mano_izq                # (de skeleton_updated: fuera de esa señal la pose es la de la animación sin capas)
	var md: Vector3 = c.mano_der
	var cab: float = j.position.y + pj.alto_modelo() * pj.scale.y
	print("      manos: izq y=%.2f der y=%.2f · separación %.2f · cabeza (alto del modelo) %.2f" % [mi.y, md.y, mi.distance_to(md), cab])
	print("      hombro-mano: las manos suben a %.2f u sobre los pies; la coronilla está a %.2f u (la jugadora es chibi: sus brazos no llegan más arriba que su cabeza)" % [mi.y - j.position.y, cab - j.position.y])
	_ok("4 las dos manos quedan juntas (< 0,5 u) y casi a la altura de la coronilla (≥ 80 % de su altura)", mi.distance_to(md) < 0.5 and mi.y - j.position.y >= 0.8 * (cab - j.position.y) and md.y - j.position.y >= 0.8 * (cab - j.position.y))


# ---------------------------------------------------------------------------------------------------------------------
#  3. Lanzar, caer a la distancia y romperse con botín
# ---------------------------------------------------------------------------------------------------------------------

func _lanzar_y_romper() -> void:
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.4)
	var antes_oro: Array = []
	var t0: float = reloj.t
	_tecla(KEY_E, true)
	await avanzar(1)
	_tecla(KEY_E, false)
	_ok("5 E con el jarrón en brazos arma el lanzamiento", c.estado == CargarObjeto3D.Estado.ANTICIPANDO)
	_ok("5 mientras arma no se anda ni se coge otra cosa (quieta)", c.quieta())
	var t_suelta: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.LANZANDO, 1.0)
	var pj: Pj3D = j.pj
	var pos_clip: float = pj.arbol().posicion()
	_ok("5 lo suelta a los ~%.2f s de pulsar E (T_SUELTA_CLIP, el instante medido del clip)" % CargarObjeto3D.T_SUELTA_CLIP, t_suelta >= 0.0 and absf((reloj.t - t0) - CargarObjeto3D.T_SUELTA_CLIP) < 0.1, "%.2f s" % (reloj.t - t0))
	_ok("5 suena el clip lanzar_objeto y el objeto sale en su instante medido (%.2f s del clip; ahora %.2f s)" % [Pj3D.instante_clip_de(pj.id, "lanzar_objeto"), pos_clip], pj.clip_actual() == "lanzar_objeto" and absf(pos_clip - Pj3D.instante_clip_de(pj.id, "lanzar_objeto")) < 0.2, pj.clip_actual())
	var t_vuelo0: float = reloj.t
	await avanzar_s(0.1)
	_ok("5 tras soltarlo sigue quieta (remate) con el clip lanzar_objeto sonando", c.estado == CargarObjeto3D.Estado.LANZANDO and c.quieta() and pj.clip_actual() == "lanzar_objeto" and c._brazos == null, "estado %d · %s" % [c.estado, pj.clip_actual()])
	var t_libre: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.LIBRE, 1.0)
	var t_lanzamiento: float = reloj.t - t0
	print("      lanzamiento total (de pulsar E a poder andar): %.2f s · suelta a los %.2f s (clip a ×%.2f)" % [t_lanzamiento, t_suelta, Pj3D.instante_clip_de(pj.id, "lanzar_objeto") / CargarObjeto3D.T_SUELTA_CLIP])
	_ok("5 el lanzamiento entero dura ~0,5 s (0,40–0,65)", t_libre >= 0.0 and t_lanzamiento > 0.40 and t_lanzamiento < 0.65, "%.2f s" % t_lanzamiento)
	var origen: Vector3 = jar.global_position
	var t_imp: float = await _hasta(func() -> bool: return c.ultimo.get("accion", "") == "impacto", 2.5)
	var t_vuelo: float = reloj.t - t_vuelo0
	var u: Dictionary = c.ultimo
	var esperado: float = float(CargarObjeto3D.COGIBLES["jarron"]["alcance"]) * Terreno3D.casilla
	print("      lanzamiento: vuelo %.2f s · distancia en plano %.2f u (tabla %.2f u = %.1f casillas) · punto %s" % [t_vuelo, float(u.get("distancia", 0.0)), esperado, float(CargarObjeto3D.COGIBLES["jarron"]["alcance"]), u.get("punto", "")])
	_ok("5 cae y avisa del impacto", t_imp >= 0.0 and u.get("accion", "") == "impacto")
	_ok("5 cae a %.1f casillas (%.2f u ±0,6) en la dirección de la mirada" % [float(CargarObjeto3D.COGIBLES["jarron"]["alcance"]), esperado], absf(float(u.get("distancia", 0.0)) - esperado) < 0.6 and (u["punto"] as Vector3).x > origen.x and absf((u["punto"] as Vector3).z - origen.z) < 0.3)
	_ok("5 el vuelo dura 0,5-0,9 s", t_vuelo > 0.5 and t_vuelo < 0.9, "%.2f s" % t_vuelo)
	_ok("5 al caer se rompe (roto_ya)", jar.roto_ya and bool(u.get("rompio", false)))
	_ok("5 y suelta el botín de su fila (7 de oro)", jar.soltado.size() == 1 and String((jar.soltado[0] as Dictionary)["que"]) == "oro" and int((jar.soltado[0] as Dictionary)["n"]) == 7, str(jar.soltado))
	await avanzar(1)
	_ok("5 deja restos en el suelo", jar.n_restos() > 0, str(jar.n_restos()))
	_ok("5 no tapa ninguna casilla", not Terreno3D.bloqueada(Terreno3D.celda_de(jar.global_position)) and not Terreno3D.bloqueada(claro + Vector2i(-1, 0)))
	_ok("5 la jugadora vuelve a andar (manos libres)", c.estado == CargarObjeto3D.Estado.LIBRE and not j.lleva_carga())


# ---------------------------------------------------------------------------------------------------------------------
#  4. Daña a un goblin
# ---------------------------------------------------------------------------------------------------------------------

func _goblin(cel: Vector2i) -> Combate3D:
	var p: Vector3 = Terreno3D.centro_de(cel, Terreno3D.y_pies(cel))
	var modelo := Pj3D.new()
	maqueta.add_child(modelo)
	modelo.cargar("goblin_warrior_chibi")
	modelo.grafo = ArbolAnimPj.GRAFO_REDUCIDO
	modelo.set_alto(0.85)
	modelo.position = p
	var g: Combate3D = Combate3D.equipar(modelo, maqueta, j, lanzador)
	g.altura = 0.85
	g.quieto = true
	g.position = p
	g.casa = p
	g.mirada = Vector3(-1, 0, 0)
	return g


func _dano_goblin() -> void:
	var g: Combate3D = _goblin(claro + Vector2i(3, 0))
	await avanzar_s(0.5)
	var v0: float = g.health
	var p0: Vector3 = g.position
	var jr: Rompible3D = _jarron(claro + Vector2i(-1, 0), "jarron_b", "jarron", "nada", 0)
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.3)
	await _pulsar(KEY_E)
	await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	_poner_mirada(Vector3.RIGHT)
	await avanzar(2)
	await _pulsar(KEY_E)
	var t: float = await _hasta(func() -> bool: return c.ultimo.get("accion", "") == "impacto" and jr.roto_ya, 2.5)
	await avanzar_s(0.6)
	var u: Dictionary = c.ultimo
	print("      goblin: vida %.1f → %.1f · empujado %.2f u · daño %s · impacto en %s (goblin en %s)" % [v0, g.health, _plano(g.position, p0), u.get("danos", []), u.get("punto", ""), p0])
	_ok("6 el jarrón lanzado golpea al goblin (%d enemigo)" % int(u.get("enemigos", 0)), t >= 0.0 and int(u.get("enemigos", 0)) == 1)
	_ok("6 le quita vida (%.1f → %.1f)" % [v0, g.health], g.health < v0 - 1.0)
	_ok("6 y lo empuja (más de 0,5 u)", _plano(g.position, p0) > 0.5)
	_ok("6 choca contra él en el aire, antes de la distancia máxima", float(u.get("distancia", 99.0)) < float(CargarObjeto3D.COGIBLES["jarron"]["alcance"]) * Terreno3D.casilla - 0.5, "%.2f u" % float(u.get("distancia", 99.0)))
	_ok("6 el jarrón se rompe en el golpe", jr.roto_ya)
	g.queue_free()


# ---------------------------------------------------------------------------------------------------------------------
#  5. Soltar con Q
# ---------------------------------------------------------------------------------------------------------------------

func _soltar() -> void:
	await avanzar_s(0.8)
	var jr: Rompible3D = _jarron(claro + Vector2i(-1, 0), "jarron_c", "jarron", "oro", 3)
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.3)
	await _pulsar(KEY_E)
	await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	_ok("7 cargando otra vez", c.estado == CargarObjeto3D.Estado.CARGANDO)
	_poner_mirada(Vector3.RIGHT)
	await avanzar(2)
	var vida0: float = j.vida
	var t0: float = reloj.t
	var pj: Pj3D = j.pj
	_tecla(KEY_Q, true)
	await avanzar(1)
	_tecla(KEY_Q, false)
	_ok("7 Q empieza a soltarlo con el clip dejar_objeto", c.estado == CargarObjeto3D.Estado.SOLTANDO and pj.clip_actual() == "dejar_objeto", "%s · %s" % [c.estado, pj.clip_actual()])
	var t_apoya: float = await _hasta(func() -> bool: return c.ultimo.get("accion", "") == "soltar", 1.5)
	var pos_dejar: float = pj.arbol().posicion()
	var t_apoyado: float = reloj.t - t0
	var t: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.LIBRE, 1.5)
	var t_dejar_total: float = reloj.t - t0
	print("      dejar_objeto: apoya a los %.2f s (T_DEJAR_FONDO %.2f; clip en %.2f s, instante medido %.2f) · manos libres a los %.2f s" % [t_apoyado, CargarObjeto3D.T_DEJAR_FONDO, pos_dejar, Pj3D.instante_clip_de(pj.id, "dejar_objeto"), t_dejar_total])
	_ok("7 lo apoya a los ~%.2f s, en el instante medido del clip (%.2f s)" % [CargarObjeto3D.T_DEJAR_FONDO, Pj3D.instante_clip_de(pj.id, "dejar_objeto")], t_apoya >= 0.0 and absf(t_apoyado - CargarObjeto3D.T_DEJAR_FONDO) < 0.1 and absf(pos_dejar - Pj3D.instante_clip_de(pj.id, "dejar_objeto")) < 0.25, "%.2f s · clip %.2f s" % [t_apoyado, pos_dejar])
	_ok("7 y todo el gesto dura 0,45–0,8 s", t >= 0.0 and t_dejar_total > 0.45 and t_dejar_total < 0.8, "%.2f s" % t_dejar_total)
	await avanzar(2)
	var delante: Vector3 = jr.global_position - j.position
	delante.y = 0.0
	print("      soltar: %.2f s · queda a %.2f u delante · casilla %s" % [reloj.t - t0, delante.length(), jr.celda])
	_ok("7 Q lo deja entero (no roto, no en brazos)", t >= 0.0 and not jr.roto_ya and not jr.en_brazos)
	_ok("7 delante de ella (a 1-3,5 u en la dirección de la mirada)", delante.length() > 1.0 and delante.length() < 3.5 and delante.normalized().dot(Vector3.RIGHT) > 0.5, str(delante))
	_ok("7 y vuelve a tapar su casilla", Terreno3D.bloqueada(jr.celda) and jr.celda != claro)
	_ok("7 sin soltar botín", jr.soltado.is_empty())
	_ok("7 Q no se bebe nada ni gasta vida", j.vida == vida0)
	await avanzar_s(0.5)
	_ok("7 puede volver a cogerlo (candidato)", c.candidato() == jr, str(c.candidato()))
	await _pulsar(KEY_E)
	var t2: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	_ok("7 y lo coge de nuevo", t2 >= 0.0 and jr.en_brazos)
	jar = jr


# ---------------------------------------------------------------------------------------------------------------------
#  6. Un golpe recibido lo tira
# ---------------------------------------------------------------------------------------------------------------------

func _golpe_recibido() -> void:
	_ok("8 sigue cargando el jarrón antes del golpe", c.estado == CargarObjeto3D.Estado.CARGANDO and jar.en_brazos)
	var vida0: float = j.vida
	j.recibir_dano(6.0, j.position + Vector3(2.0, 0, 0))
	await avanzar(2)
	print("      golpe: vida %.1f → %.1f · jarrón roto %s · restos %d · botín %s" % [vida0, j.vida, jar.roto_ya, jar.n_restos(), jar.soltado])
	_ok("8 el golpe le quita vida", j.vida < vida0)
	_ok("8 deja de cargar (manos libres)", c.estado == CargarObjeto3D.Estado.LIBRE and not j.lleva_carga())
	_ok("8 el jarrón se cae y se rompe", jar.roto_ya)
	_ok("8 con su botín (3 de oro)", jar.soltado.size() == 1 and int((jar.soltado[0] as Dictionary)["n"]) == 3, str(jar.soltado))
	await avanzar_s(0.8)
	_ok("8 los brazos vuelven a la animación (capa a 0)", c._brazos == null or c._brazos.influence < 0.01)
	_ok("8 y puede volver a lanzar hechizos (puede_lanzar) y su velocidad es la de siempre", j.puede_lanzar() and c.mult_vel() == 1.0)


# ---------------------------------------------------------------------------------------------------------------------
#  7. Un cogible suelto cualquiera (caja, nodo que no es Rompible3D) y las filas de la tabla
# ---------------------------------------------------------------------------------------------------------------------

func _suelto_generico() -> void:
	await avanzar_s(1.0)
	var cel: Vector2i = claro + Vector2i(-1, 0)
	var caja := Node3D.new()
	caja.name = "caja_p"
	maqueta.add_child(caja)
	caja.set_meta("cogible", "caja")
	caja.add_to_group("cogible")
	caja.global_position = Terreno3D.centro_de(cel, Terreno3D.y_pies(cel))
	var mi := MeshInstance3D.new()
	var cubo := BoxMesh.new()
	cubo.size = Vector3(0.4, 0.4, 0.4)
	mi.mesh = cubo
	mi.position.y = 0.2
	caja.add_child(mi)
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.3)
	await _pulsar(KEY_E)
	var t: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	_poner_mirada(Vector3.RIGHT)
	await avanzar(2)
	_ok("9 una caja (nodo suelto con metadato cogible) se coge cargándola", t >= 0.0 and c.tipo == "caja" and not c.pequeno and c.usa_clips, c.tipo)
	var m_esp: float = minf(float(CargarObjeto3D.COGIBLES["caja"]["vel"]), CargarObjeto3D.VEL_SUELO_CARGAR / j._vel_andar)
	_ok("9 con su fila y el tope de los clips: ×%.3f de velocidad (fila ×%.1f, tope %.2f u/s)" % [m_esp, float(CargarObjeto3D.COGIBLES["caja"]["vel"]), CargarObjeto3D.VEL_SUELO_CARGAR], is_equal_approx(c.mult_vel(), m_esp), "%.3f" % c.mult_vel())
	await _pulsar(KEY_E)
	await _hasta(func() -> bool: return c.ultimo.get("accion", "") == "impacto", 2.5)
	var u: Dictionary = c.ultimo
	var esperado: float = float(CargarObjeto3D.COGIBLES["caja"]["alcance"]) * Terreno3D.casilla
	_ok("9 cae a %.1f casillas (%.2f u ±0,6)" % [float(CargarObjeto3D.COGIBLES["caja"]["alcance"]), esperado], absf(float(u.get("distancia", 0.0)) - esperado) < 0.6, "%.2f u" % float(u.get("distancia", 0.0)))
	await avanzar(2)
	_ok("9 y, como su fila rompe y no es un Rompible3D, se esfuma", bool(u.get("rompio", false)) and (not is_instance_valid(caja) or caja.is_queued_for_deletion()))
	for tipo in CargarObjeto3D.COGIBLES:
		var f: Dictionary = CargarObjeto3D.COGIBLES[tipo]
		_ok("9 la fila «%s» trae peso, alcance, daño y rompe" % tipo, f.has("vel") and f.has("alcance") and f.has("dano") and f.has("rompe") and f.has("empuje"))
	_ok("9 la distinción ligero/pesado: jarrón y caja se cargan, la piedra no", not CargarObjeto3D.es_ligero(CargarObjeto3D.COGIBLES["jarron"]) and not CargarObjeto3D.es_ligero(CargarObjeto3D.COGIBLES["caja"]) and CargarObjeto3D.es_ligero(CargarObjeto3D.COGIBLES["piedra"]))
	_ok("9 sin la clave `ligero` manda el alto (≤ %.2f u: una fruta de 0,2 sí, una caja de 0,4 no)" % CargarObjeto3D.UMBRAL_LIGERO, CargarObjeto3D.es_ligero({"alto": 0.2}) and not CargarObjeto3D.es_ligero({"alto": 0.4}) and not CargarObjeto3D.es_ligero({"alto": 0.2, "ligero": false}))
	if is_instance_valid(caja):
		caja.queue_free()
	await avanzar_s(0.8)


# ---------------------------------------------------------------------------------------------------------------------
#  7b. Objeto pequeño: coger_lanzar (se agacha, coge con la derecha, da un paso y lanza; sin cargarlo)
# ---------------------------------------------------------------------------------------------------------------------

func _pequeno() -> void:
	var pj: Pj3D = j.pj
	await avanzar_s(1.0)
	var cel: Vector2i = claro + Vector2i(-1, 0)
	var piedra := Node3D.new()
	piedra.name = "piedra_p"
	maqueta.add_child(piedra)
	piedra.set_meta("cogible", "piedra")
	piedra.add_to_group("cogible")
	piedra.global_position = Terreno3D.centro_de(cel, Terreno3D.y_pies(cel))
	var mi := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.175
	esfera.height = 0.35
	mi.mesh = esfera
	mi.position.y = 0.175
	piedra.add_child(mi)
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.3)
	_ok("10 la piedra es candidata y es un objeto ligero (clave `ligero`)", c.candidato() == piedra and CargarObjeto3D.es_ligero(CargarObjeto3D.COGIBLES["piedra"]))
	var t0: float = reloj.t
	var origen: Vector3 = piedra.global_position
	_tecla(KEY_E, true)
	await avanzar(1)
	_tecla(KEY_E, false)
	_ok("10 E empieza el gesto de coger-y-lanzar (COGIENDO, pequeño) con el clip coger_lanzar", c.estado == CargarObjeto3D.Estado.COGIENDO and c.pequeno and not c.usa_clips and pj.clip_actual() == "coger_lanzar", "%s · %s" % [c.estado, pj.clip_actual()])
	_ok("10 mientras tanto no se anda (gesto) ni se carga nada", j.en_gesto() and c.ocupa_manos())
	var t_agarra: float = await _hasta(func() -> bool: return bool(c._agarrado), 1.5)
	var pos_agarre: float = pj.arbol().posicion()
	await avanzar(2)
	var en_mano: float = (piedra.global_position + Vector3(0.0, float(CargarObjeto3D.COGIBLES["piedra"]["alto"]) * 0.5, 0.0)).distance_to(c.mano_der)
	_ok("10 agarra con la mano derecha en el fondo de la agachada (%.2f s; clip en %.2f s, instante medido %.2f s)" % [t_agarra, pos_agarre, Pj3D.instante_clip_de(pj.id, "coger_lanzar_agarre")], t_agarra >= 0.0 and absf(pos_agarre - Pj3D.instante_clip_de(pj.id, "coger_lanzar_agarre")) < 0.25)
	_ok("10 y la piedra va en esa mano (centro a %.2f u de la mano derecha)" % en_mano, en_mano < 0.2, "%.2f u" % en_mano)
	var t_suelta: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.LANZANDO, 2.0)
	var pos_suelta: float = pj.arbol().posicion()
	var t_s: float = reloj.t - t0
	_ok("10 sale de la mano en el instante medido del clip (%.2f s; clip en %.2f s) y no pasó por CARGANDO" % [Pj3D.instante_clip_de(pj.id, "coger_lanzar"), pos_suelta], t_suelta >= 0.0 and absf(pos_suelta - Pj3D.instante_clip_de(pj.id, "coger_lanzar")) < 0.3 and c.ultimo.has("t_suelta"))
	var t_libre: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.LIBRE, 1.5)
	var t_total: float = reloj.t - t0
	print("      objeto pequeño: agarra a los %.2f s · suelta a los %.2f s · manos libres a los %.2f s (T_PEQUENO %.1f) · origen %s" % [c._t_fondo, t_s, t_total, CargarObjeto3D.T_PEQUENO, origen])
	_ok("10 el gesto entero dura ~%.1f s (1,0–1,4)" % CargarObjeto3D.T_PEQUENO, t_libre >= 0.0 and t_total > 1.0 and t_total < 1.4, "%.2f s" % t_total)
	var t_imp: float = await _hasta(func() -> bool: return c.ultimo.get("accion", "") == "impacto", 2.5)
	var u: Dictionary = c.ultimo
	var esperado: float = float(CargarObjeto3D.COGIBLES["piedra"]["alcance"]) * Terreno3D.casilla
	# (coger la deja mirando a la piedra, que está a su izquierda en el claro: «hacia delante» es hacia donde estaba la piedra)
	_ok("10 cae a %.1f casillas (%.2f u ±0,6) hacia donde miraba (hacia donde estaba la piedra)" % [float(CargarObjeto3D.COGIBLES["piedra"]["alcance"]), esperado], t_imp >= 0.0 and absf(float(u.get("distancia", 0.0)) - esperado) < 0.6 and (u["punto"] as Vector3).x < origen.x - 1.0, "%.2f u · x %.2f (piedra en x %.2f)" % [float(u.get("distancia", 0.0)), (u["punto"] as Vector3).x, origen.x])
	_ok("10 y se queda entera en el suelo (no rompe)", is_instance_valid(piedra) and not bool(u.get("rompio", true)) and absf(piedra.global_position.x - (u["punto"] as Vector3).x) < 0.01)
	_ok("10 la jugadora vuelve a tener las manos libres y andar a ×1", c.estado == CargarObjeto3D.Estado.LIBRE and not j.lleva_carga() and c.mult_vel() == 1.0)
	piedra.queue_free()
	await avanzar_s(0.8)


# ---------------------------------------------------------------------------------------------------------------------
#  7c. Respaldo: un modelo sin los clips de cargar sigue con la capa procedural BrazosCarga3D
# ---------------------------------------------------------------------------------------------------------------------

func _respaldo() -> void:
	var pj: Pj3D = j.pj
	var lib: AnimationLibrary = pj._ap.get_animation_library("")
	var guardado: Animation = lib.get_animation("levantar")
	lib.remove_animation("levantar")                  # al modelo «le falta» un clip
	_ok("11 sin el clip «levantar» el modelo no tiene los clips de cargar (tiene_clips false)", not c.tiene_clips())
	await avanzar_s(0.5)
	var cel: Vector2i = claro + Vector2i(-1, 0)
	var jr: Rompible3D = _jarron(cel, "jarron_resp", "jarron", "nada", 0)
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.3)
	await _pulsar(KEY_E)
	var t: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
	_ok("11 coge el jarrón con la capa de respaldo (usa_clips false, BrazosCarga3D puesta y con los brazos en alto)", t >= 0.0 and not c.usa_clips and c._brazos != null and c._brazos.influence > 0.99, "peso %s" % (c._brazos.influence if c._brazos != null else "sin capa"))
	_ok("11 y el objeto sigue sobre la cabeza (respaldo: escala %.2f)" % jr.scale.x, jr.en_brazos and is_equal_approx(jr.scale.x, float(CargarObjeto3D.COGIBLES["jarron"]["escala"])))
	_poner_mirada(Vector3.RIGHT)
	await avanzar(2)
	await _pulsar(KEY_E)
	await _hasta(func() -> bool: return c.ultimo.get("accion", "") == "impacto", 2.5)
	_ok("11 y lo lanza y rompe como antes", jr.roto_ya)
	await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.LIBRE, 1.0)
	lib.add_animation("levantar", guardado)
	_ok("11 al volver el clip, el modelo vuelve a los clips", c.tiene_clips())
	await avanzar_s(0.8)



# ---------------------------------------------------------------------------------------------------------------------
#  8. Interruptor
# ---------------------------------------------------------------------------------------------------------------------

func _interruptor() -> void:
	var cel: Vector2i = claro + Vector2i(-1, 0)
	var jr: Rompible3D = _jarron(cel, "jarron_d")
	_poner(claro, Vector3.RIGHT)
	await avanzar_s(0.3)
	c.activo = false
	await _pulsar(KEY_E)
	await avanzar_s(0.5)
	_ok("10 con el interruptor apagado, E no coge nada", c.estado == CargarObjeto3D.Estado.LIBRE and not jr.en_brazos and c.accion_pista() == "")
	c.activo = true
	_ok("10 con él encendido el mismo jarrón sí es candidato", c.candidato() == jr)
	jr.golpear()
	# el bloque empujable no es cogible
	var bloque := BloqueEmpujable3D.new()
	_ok("10 un bloque empujable no está en el grupo cogible (no se coge)", not bloque.is_in_group("cogible"))
	bloque.free()
	await avanzar_s(0.3)


# ---------------------------------------------------------------------------------------------------------------------
#  9. E sobre un cofre sigue abriéndolo (Bosque 02, con un jarrón al lado)
# ---------------------------------------------------------------------------------------------------------------------

func _cofre() -> void:
	maqueta.queue_free()
	maqueta = null
	await avanzar(5)
	Flags.nuevo()
	await cargar(RUTA_02, true)
	if maqueta == null or jugador == null:
		return
	await avanzar(10)
	j = jugador as Jugador3D
	c = j.carga
	lanzador.tinta = null
	j.vida = 100000.0
	var abre: Variant = null
	for n in get_nodes_in_group("e_cofre"):
		if bool(n.get("es_cerrado")) and bool(n.call("sellado_cumplido")) and String(n.get("glifo")) == "" and String(n.get("calidad")) == "":
			abre = n
			break
	_ok("11 hay un cofre común cerrado y abrible en el Bosque 02", abre != null, "cofres: %d" % get_nodes_in_group("e_cofre").size())
	if abre == null:
		return
	var cofre: Node3D = abre as Node3D
	var cc: Vector2i = abre.get("celda")
	# jugadora en una casilla libre vecina y un jarrón en otra vecina de ella
	var libres: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var v: Vector2i = cc + (d as Vector2i)
		if Terreno3D.pisable(v, Terreno3D.altura_en(v), false, Terreno3D.altura_en(v), false):
			libres.append(v)
	_ok("11 el cofre tiene casillas libres alrededor", libres.size() >= 2, str(libres))
	if libres.size() < 2:
		return
	var yo: Vector2i = libres[0]
	var jc: Vector2i = Vector2i(-1, -1)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var v3: Vector2i = yo + (d as Vector2i)
		if v3 != cc and v3 != yo and not Terreno3D.bloqueada(v3) and Terreno3D.pisable(v3, Terreno3D.altura_en(v3), false, Terreno3D.altura_en(v3), false):
			jc = v3
			break
	_ok("11 hay una casilla libre junto a la jugadora para el jarrón", jc.x >= 0)
	if jc.x < 0:
		return
	colocar_jugador(yo)
	var jr: Rompible3D = _jarron(jc, "jarron_cofre")
	j.mirar_hacia(Terreno3D.centro_de(cc, 0.0) - j.position)
	await avanzar_s(0.5)
	var d_cofre: float = PistaProximidad.dist_plana(cofre.global_position, j.position)
	var d_jarron: float = PistaProximidad.dist_plana(jr.global_position, j.position)
	print("      cofre a %.2f u, jarrón a %.2f u de la jugadora" % [d_cofre, d_jarron])
	_ok("11 el jarrón está al alcance de E (candidato)", c.candidato() == jr, "d=%.2f" % d_jarron)
	_ok("11 el cofre cerrado manda: hay otra interacción más prioritaria", c.hay_otra_interaccion())
	_ok("11 y la pista no ofrece «Coger»", c.accion_pista() != "Coger", c.accion_pista())
	await _pulsar(KEY_E)
	await avanzar_s(1.0)
	await avanzar_s(2.5)
	_ok("11 E ABRE el cofre", bool(cofre.get("es_abierto")), "abierto=%s abriendo=%s" % [cofre.get("es_abierto"), cofre.get("_abriendo")])
	_ok("11 y NO coge el jarrón", c.estado == CargarObjeto3D.Estado.LIBRE and not jr.en_brazos)
	# alejada del cofre, E sí coge el jarrón
	var lejos: Vector2i = Vector2i(-1, -1)
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var v2: Vector2i = jc + Vector2i(dx, dy)
			if lejos.x < 0 and PistaProximidad.dist_plana(Terreno3D.centro_de(v2, 0.0), cofre.global_position) > 4.5 and PistaProximidad.dist_plana(Terreno3D.centro_de(v2, 0.0), Terreno3D.centro_de(jc, 0.0)) < 6.0 and Terreno3D.pisable(v2, Terreno3D.altura_en(v2), false, Terreno3D.altura_en(v2), false):
				lejos = v2
	if lejos.x >= 0:
		var cel2: Vector2i = lejos + Vector2i(1, 0)
		if Terreno3D.pisable(cel2, Terreno3D.altura_en(cel2), false, Terreno3D.altura_en(cel2), false):
			var jr2: Rompible3D = _jarron(cel2, "jarron_lejos")
			colocar_jugador(lejos)
			j.mirar_hacia(Vector3.RIGHT)
			await avanzar_s(0.5)
			await _pulsar(KEY_E)
			var t: float = await _hasta(func() -> bool: return c.estado == CargarObjeto3D.Estado.CARGANDO, 2.0)
			_ok("11 lejos del cofre, E coge el jarrón", t >= 0.0 and jr2.en_brazos)
