class_name ChamanRitual
extends Node

## EL RITUAL DEL CHAMÁN (28/10): la secuencia completa que corre un `Pj3D` con el modelo `goblin_chaman`, lista para que la use el enemigo (`Chaman3D`) o la escena de prueba:
##   trazar (el bastón agarrado, el orbe verde, la punta dibuja el sello y el rombo en el suelo: RunaSuelo3D sigue la punta) → clavar (alza el bastón y lo clava en el centro; a los
##   AnimacionesChaman.INSTANTE_CLAVAR s, destello y onda verde: `RunaSuelo3D.activar`) → fin (el bastón se vuelve a plantar y el orbe se apaga).
## Uso:  var r := ChamanRitual.iniciar(pj, mundo);  r.terminado.connect(...)   · `r.interrumpir()` rompe la runa y deja al chamán en reposo.
## Señales: `activado` (la onda sale; ya existe `runa.onda_avanza`), `terminado` (acabó entero), `interrumpido`. `fase` = trazar · clavar · fin · interrumpido.
## El chamán GIRA EN EL SITIO mientras traza (`AnimacionesChaman.yaw_en`) con la punta fuera, y la runa se dibuja con la punta REAL del bastón: en cada actualización del esqueleto (ya con la pose
## del fotograma) se lee la punta y se alarga la línea hasta ella, sin desfase. El sello queda centrado en sus pies.

signal activado
signal terminado
signal interrumpido

const COLOR_ORBE: Color = Color(0.35, 1.0, 0.45)
const ENERGIA_ORBE: float = 2.2
const MEZCLA_BASTON: float = 0.2                ## s de la transición del bastón (plantado -> agarrado)
const PUNTA_BAJA_MAX: float = 0.02               ## u del modelo sobre el suelo hasta los que la punta cuenta como apoyada (dibuja)
const DESCANSO_FIN: float = 0.25                ## s DE CLIP (como t_fase: con ritmo 0,8 son 0,31 s reales) tras el impacto antes de dar por terminado

var pj: Pj3D = null
var runa: RunaSuelo3D = null
var fase: String = "trazar"
var t_fase: float = 0.0
var yaw: float = 0.0
var centro: Vector3 = Vector3.ZERO              ## centro de la runa (mundo)
var _mundo: Node = null
var _acabado: bool = false
var _sk: Skeleton3D = null


## Empieza el ritual de `p_pj` (un Pj3D goblin_chaman) y cuelga la runa de `en`. Devuelve null si el modelo no puede trazar.
static func iniciar(p_pj: Pj3D, en: Node) -> ChamanRitual:
	if p_pj == null or p_pj.duracion("trazar") <= 0.0 or p_pj.duracion("clavar") <= 0.0:
		return null
	var r := ChamanRitual.new()
	r.name = "ChamanRitual"
	r.pj = p_pj
	r._mundo = en
	en.add_child(r)
	r._arrancar()
	return r


## El centro de la runa para un chamán en `pos_pies` mirando a `p_yaw`: delante de él, donde alcanza la punta del bastón.
static func centro_para(pj_pos: Vector3, p_yaw: float, escala: float) -> Vector3:
	return pj_pos


func _arrancar() -> void:
	yaw = pj.rotation.y
	var esc: float = pj.scale.y
	centro = centro_para(pj.global_position, yaw, esc)
	process_priority = -100                     # antes que la animación: el giro del nodo ya está puesto cuando el esqueleto se actualiza
	runa = RunaSuelo3D.crear(_mundo, centro, yaw, Terreno3D.casilla, AnimacionesChaman.RADIO_TRAZO * esc, RunaSuelo3D.VERDE)
	var sks: Array[Node] = pj.find_children("*", "Skeleton3D", true, false)
	if not sks.is_empty():
		_sk = sks[0] as Skeleton3D
		_sk.skeleton_updated.connect(_al_esqueleto)
	runa.activada.connect(func() -> void: activado.emit())
	pj.agarrar_baston(true, MEZCLA_BASTON)
	pj.teñir_baston(COLOR_ORBE, ENERGIA_ORBE)
	pj.set_velocidad_animacion(1.0)
	pj.animacion_actual = ""
	pj.jugar("trazar", true)
	fase = "trazar"
	t_fase = 0.0


func _process(delta: float) -> void:
	if _acabado or pj == null or not is_instance_valid(pj):
		return
	t_fase += delta * pj.ritmo          # 28/10: tiempo DEL CLIP (el chamán goblin anima a Pj3D.ritmo): DUR_*, INSTANTE_CLAVAR y la runa que sigue a la punta siguen cuadrando con el clip
	var b: BastonChaman3D = pj.baston()
	if fase == "trazar":
		var u: float = clampf(t_fase / AnimacionesChaman.DUR_TRAZAR, 0.0, 1.0)
		var a: float = yaw + AnimacionesChaman.yaw_en(u)
		pj.mirar(Vector3(sin(a), 0.0, cos(a)), 1.0)
		if runa != null and is_instance_valid(runa):
			runa.progreso(u)
		if t_fase >= AnimacionesChaman.DUR_TRAZAR:
			fase = "clavar"
			t_fase = 0.0
			pj.animacion_actual = ""
			pj.mirar(Vector3(sin(yaw), 0.0, cos(yaw)), 1.0)
			pj.jugar("clavar", true)
			if runa != null and is_instance_valid(runa):
				runa.progreso(1.0)
				runa.punta_mundo(runa.punta, false)
	elif fase == "clavar":
		if runa != null and is_instance_valid(runa) and runa.estado == "dibujando" and t_fase >= AnimacionesChaman.INSTANTE_CLAVAR:
			runa.activar()
		if t_fase >= AnimacionesChaman.DUR_CLAVAR + DESCANSO_FIN:
			_terminar()


## Con el esqueleto ya actualizado: la línea de la runa llega hasta la punta real del bastón.
func _al_esqueleto() -> void:
	if _acabado or fase != "trazar" or runa == null or not is_instance_valid(runa) or pj == null:
		return
	var b: BastonChaman3D = pj.baston()
	if b == null:
		return
	var p: Vector3 = b.punta_global()
	runa.punta_mundo(p, p.y - pj.global_position.y < PUNTA_BAJA_MAX * pj.scale.y)


func _terminar() -> void:
	_acabado = true
	fase = "fin"
	pj.agarrar_baston(false, 0.3)
	pj.teñir_baston(Color.WHITE, 0.0)
	pj.animacion_actual = ""
	terminado.emit()
	queue_free()


## Rompe el ritual: la runa se apaga en rojo-gris, el bastón se vuelve a plantar y el orbe se apaga. No hace nada si ya acabó o ya activó la onda (clavar tras el impacto).
func interrumpir() -> void:
	if _acabado:
		return
	if fase == "clavar" and runa != null and is_instance_valid(runa) and runa.estado != "dibujando":
		return
	_acabado = true
	fase = "interrumpido"
	if runa != null and is_instance_valid(runa):
		runa.cancelar()
	if pj != null and is_instance_valid(pj):
		pj.agarrar_baston(false, 0.2)
		pj.teñir_baston(Color.WHITE, 0.0)
		pj.animacion_actual = ""
	interrumpido.emit()
	queue_free()


func en_curso() -> bool:
	return not _acabado
