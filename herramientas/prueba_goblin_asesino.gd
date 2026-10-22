extends SceneTree
## PRUEBA del goblin asesino (arte/modelos/goblin_asesino.glb, Tripo, esqueleto Mixamo de 65 huesos SIN clips propios; dos dagas de arte/equipo/daga_goblin.glb).
## Sus clips salen de Gribble (Meshy) y de los goblins guerreros vía ClipsFamilia; el ataque doble se construye por código (AtaqueDoble). Sin ventana:
##   godot --headless --fixed-fps 30 --path . --script res://herramientas/prueba_goblin_asesino.gd
## Cómo se VE se mira en docs/capturas/goblin_asesino/ (herramientas/captura_goblin_asesino.gd).

const ID: String = "goblin_asesino"
const ALTO_ESPERADO: float = 0.85         ## u de juego (el de ALTO_PJ en PruebaTest2: la familia goblin)
const TOL_ALTO: float = 0.05              ## ±5 %
## Rol -> clip que debe resolver.
const ROLES: Dictionary = {"idle": "idle", "walk": "walk", "run": "run", "attack": "AtaqueDoble", "hit": "hit", "death": "death", "drown": "drowning",
	"empujado": "Empujado", "levantarse": "Levantarse", "guardia": "guardia", "paso_lado": "paso_lado"}
const DURACION_ATAQUE: Vector2 = Vector2(0.8, 1.0)     ## s: lo pedido por Pablo
const SEPARACION_CORTES_MIN: float = 0.1               ## fracción del clip entre el primer corte y el segundo
## El brazo en el corte: estirado (distancia hombro-mano / largo de brazo + antebrazo), de frente (ángulo con +Z) y a la altura del hombro (|dirección.y|).
const EXTENSION_MIN: float = 0.97
const ANGULO_CORTE_MAX: float = 20.0
const ELEVACION_MAX: float = 0.2
const PLEGADO_MAX: float = 0.9                         ## el brazo que aún no corta (o en la anticipación) está recogido: extensión por debajo de esto
const LATERAL_MIN: float = 0.9                         ## al acabar el barrido el brazo apunta de lado (|x| de la dirección)
const GIRO_TORSO_MIN: float = 35.0                     ## grados que gira la línea de los hombros entre la anticipación y el final del primer corte
const GIRO_ABIERTO_MAX: float = 20.0                   ## en el corte el torso se abre: los hombros miran de frente (la guardia es de medio lado)
## Ningún hueso del brazo (codo, muñeca, mano) se acerca al eje del torso (cadera-cuello) menos que esto (u del modelo): no lo atraviesan.
const BRAZO_A_TORSO_MIN: float = 0.04
const PASOS_ATAQUE: int = 60
## Daga: triángulos, largo de la pieza en el juego y de la hoja.
const TRIS_DAGA_MAX: int = 4000
const TRIS_DAGA_MIN: int = 1500
const HOJA_FRACCION: float = 0.53                      ## de la hoja en el largo total de la pieza (se midió en la malla: guardia a ~47 % desde el pomo)
const HOJA_JUEGO: Vector2 = Vector2(0.25, 0.35)        ## u en el juego (pedido: ~0,3)
const DAGA_SIGUE_TOL: float = 0.006                    ## u: distancia entre la daga y el punto de la mano donde cuelga
const DAGA_MUEVE_MIN: float = 0.1                      ## u: lo que se mueve la daga entre la guardia y el corte
## Pies.
const SUELO_IDLE_TOL: float = 0.02
const SUELO_MARCHA_MIN: float = 0.04
const SUELO_MARCHA_HUNDE: float = -0.03
const HUESOS_SUELA: PackedStringArray = ["Foot", "ToeBase", "Toe_End"]
## Raíz: lo que se aleja la cadera de donde empieza el clip (fracción del alto del modelo).
const RAIZ_MAX: float = 0.08
const BALANCEO_MAX: float = 0.2

const DT: float = 1.0 / 30.0
const S: float = 2.3
const LADO: int = 14

var _fallos: int = 0
var _mundo: Mundo3D = null


## Jugador de mentira: apunta cuándo recibe un golpe (fotograma del motor) en vez de hacerse daño.
class JugadorFalso extends Jugador3D:
	var golpes: Array = []

	func recibir_dano(_cantidad: float, _desde: Vector3 = Vector3.ZERO) -> void:
		golpes.append(Engine.get_process_frames())


func _ok(c: bool, m: String) -> void:
	if c:
		print("OK    ", m)
	else:
		_fallos += 1
		print("FALLO ", m)


func _initialize() -> void:
	Estado.nuevo()
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	var p := Pj3D.new()
	mundo.add_child(p)
	_ok(p.cargar(ID), "goblin_asesino carga")
	p.set_alto(ALTO_ESPERADO)
	await process_frame
	_ok(absf(p.alto_modelo() * p.scale.y - ALTO_ESPERADO) <= ALTO_ESPERADO * TOL_ALTO, "altura en el juego %.3f (esperada %.2f ±5 %%)" % [p.alto_modelo() * p.scale.y, ALTO_ESPERADO])
	var sks: Array[Node] = p.find_children("*", "Skeleton3D", true, false)
	_ok(not sks.is_empty() and (sks[0] as Skeleton3D).find_bone("mixamorig_Hips") >= 0, "esqueleto con huesos mixamorig")
	var sk: Skeleton3D = sks[0] as Skeleton3D
	_ok(sk.get_bone_count() == 65, "65 huesos (%d)" % sk.get_bone_count())
	_ok(sk.find_bone("mixamorig_LeftHandIndex1") >= 0, "tiene dedos")
	var ap: AnimationPlayer = p._ap
	_ok(ap != null and p._arbol != null, "AnimationPlayer y árbol de animación montados (%d clips)" % (ap.get_animation_list().size() if ap != null else 0))
	if ap == null:
		_acabar()
		return
	_ok(Pj3D.tipo_de(ID) == "goblin", "tipo goblin (clips mínimos: idle, walk, attack, hit, death)")
	var avisos: PackedStringArray = p.validar()
	_ok(avisos.is_empty(), "Pj3D.validar() sin avisos %s" % str(avisos))
	for r in ROLES.keys():
		_ok(p.clip_de(r) == String(ROLES[r]) and p.duracion(r) > 0.0, "rol %s -> %s (%.2f s)" % [r, p.clip_de(r), p.duracion(r)])
	_ok(p.tiene_empujado(), "trae los clips de empujado y levantarse (traducidos a su esqueleto)")
	p.jugar("walk")
	await process_frame
	_ok(p.animacion_actual == "walk", "jugar(walk) (actual: %s)" % p.animacion_actual)
	p.jugar("run")
	await process_frame
	_ok(p.animacion_actual == "run", "jugar(run) (actual: %s)" % p.animacion_actual)
	p.jugar("idle")
	await process_frame
	_ataque(p, sk, ap)
	await _dagas(p, sk, ap)
	_pies_y_raiz(p, sk, ap)
	await _combate()
	_acabar()


func _acabar() -> void:
	print("RESULTADO goblin_asesino · FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


## ---------------------------------------------------------------------------------------------------------------------------------------------------
##  El ataque doble
## ---------------------------------------------------------------------------------------------------------------------------------------------------
func _ataque(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer) -> void:
	var dur: float = p.duracion("attack")
	_ok(dur >= DURACION_ATAQUE.x and dur <= DURACION_ATAQUE.y + 0.001, "el ataque dura %.2f s (pedido %.1f–%.1f)" % [dur, DURACION_ATAQUE.x, DURACION_ATAQUE.y])
	var an: Animation = ap.get_animation(p.clip_de("attack"))
	var cortes: Array = p.momentos_corte("attack")
	_ok(cortes.size() == 2, "el ataque tiene DOS instantes de corte (%s)" % str(cortes))
	if cortes.size() != 2:
		return
	var c0: float = float(cortes[0])
	var c1: float = float(cortes[1])
	_ok(c0 > 0.0 and c1 < 1.0 and c1 - c0 >= SEPARACION_CORTES_MIN, "cortes en %.2f y %.2f del clip (separados ≥ %.2f)" % [c0, c1, SEPARACION_CORTES_MIN])
	_ok(is_equal_approx(c0, AtaqueDoble.T_CORTE_DERECHO) and is_equal_approx(c1, AtaqueDoble.T_CORTE_IZQUIERDO), "los instantes son los de AtaqueDoble (derecho primero, izquierdo después)")
	var huesos: Dictionary = {}
	for lado in ["Right", "Left"]:
		huesos[lado] = [sk.find_bone("mixamorig_%sArm" % lado), sk.find_bone("mixamorig_%sForeArm" % lado), sk.find_bone("mixamorig_%sHand" % lado)]
	var largo: Dictionary = {}
	for lado in ["Right", "Left"]:
		var h: Array = huesos[lado]
		largo[lado] = sk.get_bone_global_rest(h[0]).origin.distance_to(sk.get_bone_global_rest(h[1]).origin) \
			+ sk.get_bone_global_rest(h[1]).origin.distance_to(sk.get_bone_global_rest(h[2]).origin)
	# En cada corte: ese brazo, estirado, de frente y a la altura del hombro; el otro, recogido (corta DESPUÉS).
	var por_corte: Array = [["Right", "Left", c0], ["Left", "Right", c1]]
	for pc in por_corte:
		_pose_en(p, sk, ap, an, float(pc[2]) * an.length)
		var info: Array = _brazo(sk, huesos[pc[0]], float(largo[pc[0]]))
		_ok(float(info[0]) >= EXTENSION_MIN, "corte %s: brazo estirado (extensión %.3f)" % [pc[0], info[0]])
		_ok(float(info[1]) <= ANGULO_CORTE_MAX, "corte %s: de frente (%.1f° con +Z, máx %.0f°)" % [pc[0], info[1], ANGULO_CORTE_MAX])
		_ok(absf(float(info[2])) <= ELEVACION_MAX, "corte %s: a la altura del hombro (elevación %.2f)" % [pc[0], info[2]])
		if pc[0] == "Right":
			var otro: Array = _brazo(sk, huesos[pc[1]], float(largo[pc[1]]))
			_ok(float(otro[0]) <= PLEGADO_MAX, "en el primer corte el brazo izquierdo sigue recogido (extensión %.3f)" % otro[0])
	# Fin de cada barrido: de lado, estirado.
	var fines: Array = [["Right", AtaqueDoble.T_FIN_DERECHO, -1.0], ["Left", AtaqueDoble.T_FIN_IZQUIERDO, 1.0]]
	for fn in fines:
		_pose_en(p, sk, ap, an, float(fn[1]) * an.length)
		var info2: Array = _brazo(sk, huesos[fn[0]], float(largo[fn[0]]))
		_ok(float(info2[0]) >= EXTENSION_MIN and float(info2[3]) * float(fn[2]) >= LATERAL_MIN, "fin del barrido %s: estirado (%.3f) y de lado (x %.2f)" % [fn[0], info2[0], info2[3]])
	# Anticipación: los dos brazos recogidos y CRUZADOS delante del pecho (la mano derecha pasa a la izquierda del eje del cuerpo y al revés), torso girado.
	_pose_en(p, sk, ap, an, AtaqueDoble.T_PLEGADO * an.length)
	var mr: Vector3 = sk.get_bone_global_pose(huesos["Right"][2]).origin
	var ml: Vector3 = sk.get_bone_global_pose(huesos["Left"][2]).origin
	var eje_x: float = sk.get_bone_global_pose(sk.find_bone("mixamorig_Spine1")).origin.x
	_ok(float(_brazo(sk, huesos["Right"], float(largo["Right"]))[0]) <= PLEGADO_MAX and float(_brazo(sk, huesos["Left"], float(largo["Left"]))[0]) <= PLEGADO_MAX,
		"anticipación: los dos brazos recogidos")
	_ok(mr.x > eje_x and ml.x < eje_x, "anticipación: brazos cruzados (mano derecha x %.3f, izquierda x %.3f, eje %.3f)" % [mr.x, ml.x, eje_x])
	var yaw_a: float = _giro_hombros(sk)
	_pose_en(p, sk, ap, an, AtaqueDoble.T_FIN_DERECHO * an.length)
	var yaw_b: float = _giro_hombros(sk)
	_ok(absf(wrapf(yaw_a - yaw_b, -180.0, 180.0)) >= GIRO_TORSO_MIN, "el torso gira entre la anticipación y el final del primer corte (%.1f° → %.1f°)" % [yaw_a, yaw_b])
	_pose_en(p, sk, ap, an, AtaqueDoble.T_CORTE_DERECHO * an.length)
	var yaw_c: float = _giro_hombros(sk)
	_ok(absf(yaw_c) <= GIRO_ABIERTO_MAX, "en el primer corte los hombros miran de frente (%.1f°, tope ±%.0f°; en la guardia %.1f°)" % [yaw_c, GIRO_ABIERTO_MAX, _giro_en(p, sk, ap, idle_clip(p, ap), 0.0)])
	# Ningún brazo atraviesa el tronco en todo el ataque.
	var minimo: float = INF
	var donde: float = 0.0
	var quien: String = ""
	var cuello: int = sk.find_bone("mixamorig_Neck")
	var cadera: int = sk.find_bone("mixamorig_Hips")
	for k in range(PASOS_ATAQUE + 1):
		var u: float = float(k) / float(PASOS_ATAQUE)
		_pose_en(p, sk, ap, an, u * an.length)
		var a: Vector3 = sk.get_bone_global_pose(cadera).origin
		var b: Vector3 = sk.get_bone_global_pose(cuello).origin
		for lado in ["Right", "Left"]:
			var hs: Array = huesos[lado]
			for i in [hs[1], hs[2]]:       # el codo (origen del antebrazo) y la muñeca (origen de la mano)
				var d: float = _dist_segmento(sk.get_bone_global_pose(i).origin, a, b)
				if d < minimo:
					minimo = d
					donde = u
					quien = sk.get_bone_name(i)
	_ok(minimo >= BRAZO_A_TORSO_MIN, "ningún codo ni muñeca se acerca al eje del torso a menos de %.3f u (mínimo %.3f, %s, en %.2f del clip)" % [BRAZO_A_TORSO_MIN, minimo, quien, donde])
	# El clip empieza y acaba en la guardia (el Idle en t = 0): sin salto al entrar ni al salir.
	var idle: Animation = ap.get_animation(p.clip_de("idle"))
	_pose_en(p, sk, ap, idle, 0.0)
	var g0: Array = _poses(sk)
	_pose_en(p, sk, ap, an, 0.0)
	var d_ini: float = _dif_poses(g0, _poses(sk))
	_pose_en(p, sk, ap, an, an.length)
	var d_fin: float = _dif_poses(g0, _poses(sk))
	_ok(d_ini < 0.005 and d_fin < 0.005, "empieza y acaba en la guardia del Idle (diferencia %.4f al principio, %.4f al final)" % [d_ini, d_fin])


## [extensión (distancia hombro-mano / largo), ángulo en grados entre la dirección del brazo y +Z, elevación (y de la dirección), x de la dirección].
func _brazo(sk: Skeleton3D, h: Array, largo: float) -> Array:
	var a: Vector3 = sk.get_bone_global_pose(h[0]).origin
	var m: Vector3 = sk.get_bone_global_pose(h[2]).origin
	var d: Vector3 = m - a
	var dir: Vector3 = d.normalized()
	return [d.length() / largo, rad_to_deg(dir.angle_to(Vector3(0, 0, 1))), dir.y, dir.x]


## Giro (grados, alrededor de la vertical) de la línea que une los dos hombros.
func _giro_hombros(sk: Skeleton3D) -> float:
	var r: Vector3 = sk.get_bone_global_pose(sk.find_bone("mixamorig_RightArm")).origin
	var l: Vector3 = sk.get_bone_global_pose(sk.find_bone("mixamorig_LeftArm")).origin
	var d: Vector3 = l - r
	return rad_to_deg(atan2(-d.z, d.x))


func idle_clip(p: Pj3D, ap: AnimationPlayer) -> Animation:
	return ap.get_animation(p.clip_de("idle"))


## Giro de los hombros con el clip `an` en `t`.
func _giro_en(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, an: Animation, t: float) -> float:
	_pose_en(p, sk, ap, an, t)
	return _giro_hombros(sk)


func _dist_segmento(pt: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((pt - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return pt.distance_to(a + ab * t)


func _poses(sk: Skeleton3D) -> Array:
	var r: Array = []
	for i in range(sk.get_bone_count()):
		r.append(sk.get_bone_global_pose(i).origin)
	return r


func _dif_poses(a: Array, b: Array) -> float:
	var m: float = 0.0
	for i in range(a.size()):
		m = maxf(m, (a[i] as Vector3).distance_to(b[i] as Vector3))
	return m


## Pone el esqueleto en el instante `t` del clip `an` (el árbol se apaga: el reproductor manda).
func _pose_en(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, an: Animation, t: float) -> void:
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	var nombre: String = ap.find_animation(an)
	ap.play(nombre)
	ap.seek(clampf(t, 0.0, an.length), true)
	ap.pause()
	sk.force_update_all_bone_transforms()


## ---------------------------------------------------------------------------------------------------------------------------------------------------
##  Las dagas
## ---------------------------------------------------------------------------------------------------------------------------------------------------
func _dagas(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer) -> void:
	var piezas: Dictionary = {}     # lado -> [pieza, BoneAttachment3D]
	for h in sk.get_children():
		if h is BoneAttachment3D:
			for c in h.get_children():
				if String(c.get_meta("equipo_id", "")) == "daga_goblin":
					piezas[String((h as BoneAttachment3D).bone_name).trim_prefix("mixamorig_")] = [c, h]
	_ok(piezas.has("RightHand") and piezas.has("LeftHand") and piezas.size() == 2, "dos dagas colgadas de las manos (%s)" % str(piezas.keys()))
	if not (piezas.has("RightHand") and piezas.has("LeftHand")):
		return
	var pd: Node3D = (piezas["RightHand"] as Array)[0]
	var pi: Node3D = (piezas["LeftHand"] as Array)[0]
	_ok(pd.scale.x > 0.0 and pi.scale.x < 0.0 and is_equal_approx(absf(pi.scale.x), pd.scale.x), "la daga izquierda es la derecha reflejada (escala X %.3f / %.3f)" % [pd.scale.x, pi.scale.x])
	# Triángulos.
	var tris: int = 0
	var caja := AABB()
	var primera: bool = true
	for m in pd.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (m as MeshInstance3D).mesh
		if mesh == null:
			continue
		tris += mesh.get_faces().size() / 3
		caja = (m as MeshInstance3D).get_aabb() if primera else caja.merge((m as MeshInstance3D).get_aabb())
		primera = false
	_ok(tris <= TRIS_DAGA_MAX and tris >= TRIS_DAGA_MIN, "daga de %d triángulos (entre %d y %d)" % [tris, TRIS_DAGA_MIN, TRIS_DAGA_MAX])
	# Largo en el juego: lo que mide la pieza en su eje de la hoja × las escalas (pieza y personaje).
	var largo_juego: float = caja.size.y * pd.scale.y * p.scale.y
	var hoja: float = largo_juego * HOJA_FRACCION
	_ok(hoja >= HOJA_JUEGO.x and hoja <= HOJA_JUEGO.y, "hoja de ~%.2f u en el juego (pieza entera %.2f u; pedido ~0,3)" % [hoja, largo_juego])
	# Siguen el hueso: en la guardia y en el corte la daga está donde la mano, a la misma distancia, y se ha movido.
	var an: Animation = ap.get_animation(p.clip_de("attack"))
	var pos: Dictionary = {}
	for k in [["guardia", 0.0], ["corte", AtaqueDoble.T_CORTE_DERECHO * an.length], ["corte2", AtaqueDoble.T_CORTE_IZQUIERDO * an.length]]:
		_pose_en(p, sk, ap, an, float(k[1]))
		await process_frame
		await process_frame
		var rec: Dictionary = {}
		for lado in ["RightHand", "LeftHand"]:
			var pieza: Node3D = (piezas[lado] as Array)[0]
			var hueso: Variant = p.hueso_ahora("mixamorig_" + lado)
			rec[lado] = [pieza.global_position, (hueso as Transform3D).origin if hueso != null else Vector3.INF, pieza.global_transform]
		pos[String(k[0])] = rec
	for lado in ["RightHand", "LeftHand"]:
		var peor: float = 0.0
		for k in pos.keys():
			var r: Array = (pos[k] as Dictionary)[lado]
			var esperado: float = (Vector3(0.0, 0.045, 0.0)).length() * p.scale.y      # DAGA_POS_*: a 0,045 de la muñeca a lo largo del hueso
			peor = maxf(peor, absf((r[0] as Vector3).distance_to(r[1] as Vector3) - esperado))
		_ok(peor <= DAGA_SIGUE_TOL, "la daga de %s sigue al hueso (error de distancia máx %.4f u)" % [lado, peor])
		var recorrido: float = ((pos["guardia"] as Dictionary)[lado][0] as Vector3).distance_to(((pos["corte" if lado == "RightHand" else "corte2"] as Dictionary)[lado][0] as Vector3))
		_ok(recorrido >= DAGA_MUEVE_MIN, "la daga de %s se mueve con el clip (%.2f u de la guardia a su corte)" % [lado, recorrido])
	# En su corte: la hoja apunta hacia delante, con el filo hacia el lado al que barre (-X la derecha, +X la izquierda).
	for par in [["RightHand", "corte", -1.0], ["LeftHand", "corte2", 1.0]]:
		var pose_pieza: Transform3D = ((pos[par[1]] as Dictionary)[par[0]] as Array)[2]      # la de cada instante, guardada al ponerlo
		var hacia: Vector3 = (pose_pieza.basis * Vector3(0, 1, 0)).normalized()
		var filo: Vector3 = (pose_pieza.basis * Vector3(-1, 0, 0)).normalized()
		_ok(hacia.dot(Vector3(0, 0, 1)) >= 0.9, "%s: la hoja apunta hacia delante en su corte (%.2f con +Z)" % [par[0], hacia.dot(Vector3(0, 0, 1))])
		_ok(filo.x * float(par[2]) >= 0.9, "%s: el filo mira al lado del barrido (x %.2f, esperado signo %+d)" % [par[0], filo.x, int(par[2])])


## ---------------------------------------------------------------------------------------------------------------------------------------------------
##  Pies y raíz
## ---------------------------------------------------------------------------------------------------------------------------------------------------
func _pies_y_raiz(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer) -> void:
	var alto: float = p.alto_modelo()
	var reposo: float = _suela_min_reposo(sk)
	for r in ["idle", "walk", "run", "guardia", "paso_lado"]:
		var clip2: String = p.clip_de(r)
		var an: Animation = ap.get_animation(clip2)
		var minimo: float = INF
		var maximo: float = -INF
		for k in range(24):
			var y: float = _suela_en(p, sk, ap, clip2, an.length * float(k) / 24.0) - reposo
			minimo = minf(minimo, y)
			maximo = maxf(maximo, y)
		var rel_min: float = minimo / alto
		var rel_max: float = maximo / alto
		print("INFO  %s (%s): suela mínima %.1f %%, máxima %.1f %% del alto" % [r, clip2, rel_min * 100.0, rel_max * 100.0])
		if r == "idle":
			_ok(absf(rel_min) <= SUELO_IDLE_TOL and absf(rel_max) <= SUELO_IDLE_TOL * 3.0, "idle: pies en el suelo (mín %.3f, máx %.3f del alto)" % [rel_min, rel_max])
		elif r == "walk":
			_ok(rel_min <= SUELO_MARCHA_MIN and rel_min >= SUELO_MARCHA_HUNDE, "walk: pisa el suelo sin hundirse (mín %.3f del alto)" % rel_min)
		else:
			_ok(rel_min >= SUELO_MARCHA_HUNDE, "%s: no atraviesa el suelo (mín %.3f del alto)" % [r, rel_min])
	for r in ["idle", "walk", "run", "guardia", "paso_lado", "attack", "hit"]:
		var deriva: float = _deriva_cadera(p, sk, ap, p.clip_de(r)) / alto
		var tope: float = RAIZ_MAX if (r == "walk" or r == "run" or r == "guardia" or r == "paso_lado" or r == "attack") else BALANCEO_MAX
		_ok(deriva <= tope, "%s: sin movimiento de raíz (deriva %.3f del alto, tope %.2f)" % [r, deriva, tope])


func _suela_min_reposo(sk: Skeleton3D) -> float:
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, sk.get_bone_global_rest(i).origin.y)
	return m


func _deriva_cadera(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clip: String) -> float:
	var h: int = sk.find_bone("mixamorig_Hips")
	var largo: float = ap.get_animation(clip).length
	_suela_en(p, sk, ap, clip, 0.0)
	var o: Vector3 = sk.get_bone_global_pose(h).origin
	var m: float = 0.0
	for k in range(1, 25):
		_suela_en(p, sk, ap, clip, largo * float(k) / 25.0)
		var q: Vector3 = sk.get_bone_global_pose(h).origin
		m = maxf(m, Vector2(q.x - o.x, q.z - o.z).length())
	return m


func _suela_en(p: Pj3D, sk: Skeleton3D, ap: AnimationPlayer, clip: String, t: float) -> float:
	if p._arbol != null:
		p._arbol.active = false
	ap.active = true
	ap.play(clip)
	ap.seek(t, true)
	sk.force_update_all_bone_transforms()
	var m: float = INF
	for i in range(sk.get_bone_count()):
		for fin in HUESOS_SUELA:
			if sk.get_bone_name(i).ends_with(fin):
				m = minf(m, sk.get_bone_global_pose(i).origin.y)
	return m


## ---------------------------------------------------------------------------------------------------------------------------------------------------
##  Como enemigo (Combate3D): mismo cuerpo a cuerpo que el guerrero, con un golpe por corte
## ---------------------------------------------------------------------------------------------------------------------------------------------------
func _combate() -> void:
	var filas: PackedStringArray = []
	var bloq: Dictionary = {}
	for y in range(LADO):
		var f: String = ""
		for x in range(LADO):
			if x == 0 or y == 0 or x == LADO - 1 or y == LADO - 1:
				f += "#"
				bloq[Vector2i(x, y)] = true
			else:
				f += "."
		filas.append(f)
	Terreno3D.alturas.clear()
	Terreno3D.permanentes.clear()
	Terreno3D.cargar_datos(filas, bloq)
	Terreno3D.activar_fuente_casillas()
	_mundo = Mundo3D.new()
	root.add_child(_mundo)
	var jug := JugadorFalso.new()
	var base := Vector3(6.5 * S, Terreno3D.alto_suelo, 6.5 * S)
	jug.position = base + Vector3(0.0, 0.0, 0.7)
	jug.pj = Pj3D.new()
	_mundo.add_child(jug.pj)
	var modelo := Pj3D.new()
	_mundo.add_child(modelo)
	modelo.cargar(ID)
	modelo.set_alto(ALTO_ESPERADO)
	modelo.position = base
	var g: Combate3D = Combate3D.equipar(modelo, _mundo, jug, null)
	g.set_physics_process(false)
	g.altura = ALTO_ESPERADO
	g.position = base
	g.casa = base
	await process_frame
	_ok(g.nombre == "Goblin asesino" and not g.arquero and not g.elemental, "Combate3D lo reconoce: «%s», cuerpo a cuerpo" % g.nombre)
	_ok(modelo.rol_visual == "enemigo" and modelo.grafo == ArbolAnimPj.GRAFO_REDUCIDO, "rol visual enemigo y grafo de animación reducido")
	# Un ataque como los del guerrero: `_atacar` con la carga a punto. Se cuenta cuándo recibe golpe el jugador (sin invulnerabilidad: es falso).
	g.estado = "persigue"
	g._descanso = 0.0
	g._carga = Combate3D.PREPARAR_GOLPE
	var f0: int = Engine.get_process_frames()
	g._atacar(DT)
	var total: float = g._ataque
	_ok(absf(total - modelo.duracion("attack")) < 0.01, "el ataque dura lo que el clip (%.2f s)" % total)
	var cortes: Array = modelo.momentos_corte("attack")
	for _i in range(int(ceil(total * 30.0)) + 6):
		await process_frame
	var frames: Array = []
	for fr in jug.golpes:
		frames.append(int(fr) - f0)
	_ok(jug.golpes.size() == 2, "un golpe por corte: %d golpes al jugador (%s fotogramas desde el inicio)" % [jug.golpes.size(), str(frames)])
	if jug.golpes.size() == 2:
		for k in range(2):
			var t_real: float = float(frames[k]) / 30.0
			var t_esp: float = total * float(cortes[k])
			_ok(absf(t_real - t_esp) <= 0.08, "golpe %d a los %.2f s (esperado %.2f s = %.2f del clip)" % [k + 1, t_real, t_esp, float(cortes[k])])
	g.queue_free()
	modelo.queue_free()
	await process_frame
