class_name RaicesElemental3D
extends Node3D

## RAÍCES DEL ELEMENTAL (6/11, Pablo: «El elemental»; Dueño: Juego). Lo que se VE del conjuro de raíces bajo la jugadora (`Combate3D._lanzar_raices`): sin VFX nuevo, solo piezas sencillas.
##   1. AVISO   (`avisar`): una mancha parda en el suelo y unas pocas puntas de raíz que asoman y se agitan cada vez más durante `t_aviso` s. El círculo ROJO del aviso (lo que de verdad
##              pega) lo pone `AvisoAtaque3D.circulo` desde Combate3D; esto lo acompaña para que se lea «raíces» y no un golpe cualquiera.
##   2. BROTAR  (`brotar(dur)`): las puntas se disparan a su altura completa, se quedan `dur` s y se hunden. Si ha atrapado a la jugadora, `cerrar_sobre(pos)` las recoloca apretadas alrededor de
##              sus pies para que se vea que son ellas las que la sujetan.
## Nodo suelto: se cuelga donde se quiere (`avisar(en, ...)`) y se borra solo. Su reloj es `_process` (el del juego).

const COLOR_RAIZ: Color = Color(0.36, 0.2, 0.1)           ## marrón tierra
const COLOR_RAIZ_PUNTA: Color = Color(0.5, 0.17, 0.1)     ## y un tinte rojizo en la mancha, que lo relaciona con el rojo del aviso
const COLOR_MANCHA: Color = Color(0.32, 0.12, 0.07, 0.55)
const N_RAICES: int = 9
const ALTO_RAIZ: float = 1.1                              ## u de alto de una raíz a su altura completa
const ALTO_AVISO_MIN: float = 0.1                         ## fracción de la altura con que asoman al empezar el aviso...
const ALTO_AVISO_MAX: float = 0.35                        ## ...y con que llegan al final del aviso (antes de brotar)
const T_BROTE: float = 0.12                               ## s que tardan en dispararse
const T_HUNDIR: float = 0.3                               ## s que tardan en hundirse al final
const RADIO_AGARRE: float = 0.55                          ## u: el corro apretado alrededor de los pies de la jugadora

var radio: float = 1.8
var t_aviso: float = 1.0
var fase: String = "aviso"                                ## aviso | brotada
var t: float = 0.0                                        ## s en la fase actual
var _dur: float = 0.0                                     ## brotada: s que se queda
var _raices: Array = []                                   ## [{pivote: Node3D, ang: float, r: float, k: float}]
var _mancha: MeshInstance3D = null


## Saca el aviso de raíces en `centro` (radio `p_radio`, `p_t` s hasta que brotan). `en` = el nodo del que cuelga (el mundo).
static func avisar(en: Node, centro: Vector3, p_radio: float, p_t: float) -> RaicesElemental3D:
	var n := RaicesElemental3D.new()
	n.radio = p_radio
	n.t_aviso = maxf(p_t, 0.05)
	if en != null:
		en.add_child(n)
	var c: Vector2i = Terreno3D.celda_de(centro)
	var y: float = Terreno3D.y_pies(c) if Terreno3D.en_mapa(c) else centro.y
	n.position = Vector3(centro.x, y, centro.z)
	n._construir()
	return n


func _construir() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_RAIZ
	mat.roughness = 1.0
	var disco := CylinderMesh.new()
	disco.top_radius = radio
	disco.bottom_radius = radio
	disco.height = 0.01
	disco.radial_segments = 32
	disco.rings = 1
	var mm := StandardMaterial3D.new()
	mm.albedo_color = COLOR_MANCHA
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mancha = MeshInstance3D.new()
	_mancha.mesh = disco
	_mancha.material_override = mm
	_mancha.position = Vector3(0.0, 0.03, 0.0)
	_mancha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mancha)
	# Reparto fijo (no aleatorio: dos avisos iguales se ven iguales y las pruebas no bailan): un anillo exterior y otro interior, desfasados.
	for i in range(N_RAICES):
		var ang: float = TAU * float(i) / float(N_RAICES) + 0.35
		var r: float = radio * (0.8 if i % 2 == 0 else 0.45)
		var pivote := Node3D.new()
		pivote.position = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		pivote.rotation = Vector3(0.0, -ang, deg_to_rad(18.0))      # inclinadas hacia el centro del círculo
		var cono := CylinderMesh.new()
		cono.top_radius = 0.0
		cono.bottom_radius = 0.11 if i % 3 == 0 else 0.08
		cono.height = 1.0
		cono.radial_segments = 6
		cono.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cono
		mi.material_override = mat
		mi.position = Vector3(0.0, 0.5, 0.0)                         # la base del cono a ras del pivote
		pivote.add_child(mi)
		add_child(pivote)
		_raices.append({"pivote": pivote, "ang": ang, "r": r, "k": 0.85 + 0.3 * float(i % 3) / 2.0})
	_poner_alto(ALTO_AVISO_MIN)


## Brotan: se disparan a su altura completa, se quedan `dur` s y se hunden. Si ya brotaron, no hace nada.
func brotar(dur: float) -> void:
	if fase == "brotada":
		return
	fase = "brotada"
	t = 0.0
	_dur = maxf(dur, T_BROTE + T_HUNDIR)


## Han atrapado a la jugadora: las raíces se cierran apretadas alrededor de `pos` (sus pies) y se quedan lo que dure el agarre.
func cerrar_sobre(pos: Vector3) -> void:
	var n: int = _raices.size()
	for i in range(n):
		var d: Dictionary = _raices[i]
		var ang: float = float(d["ang"])
		var piv: Node3D = d["pivote"]
		var fuera: Vector3 = Vector3(cos(ang), 0.0, sin(ang)) * RADIO_AGARRE
		piv.position = Vector3(pos.x - position.x, 0.0, pos.z - position.z) + fuera
		piv.rotation = Vector3(0.0, -ang, deg_to_rad(24.0))
	if _mancha != null:
		_mancha.visible = false


func cancelar() -> void:
	queue_free()


func _poner_alto(f: float) -> void:
	for d in _raices:
		var piv: Node3D = d["pivote"]
		piv.scale = Vector3(1.0, maxf(f * ALTO_RAIZ * float(d["k"]), 0.01), 1.0)


func _process(delta: float) -> void:
	t += delta
	if fase == "aviso":
		var k: float = clampf(t / t_aviso, 0.0, 1.0)
		var base: float = lerpf(ALTO_AVISO_MIN, ALTO_AVISO_MAX, k)
		var temblor: float = 0.04 * k * sin(t * (18.0 + 40.0 * k))        # se agitan más según se acerca el brote
		_poner_alto(base + temblor)
		return
	# brotada
	var f: float = 1.0
	if t < T_BROTE:
		f = lerpf(ALTO_AVISO_MAX, 1.0, t / T_BROTE)
	elif t > _dur - T_HUNDIR:
		f = lerpf(1.0, 0.02, clampf((t - (_dur - T_HUNDIR)) / T_HUNDIR, 0.0, 1.0))
	_poner_alto(f)
	if t >= _dur:
		queue_free()
