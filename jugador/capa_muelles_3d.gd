class_name CapaMuelles3D
extends SkeletonModifier3D

## MUELLES DE LA CAPA de `jugadora_base` (arte/modelos/ropa_capa.glb): la capa ya no es rígida. Lleva 8 cadenas de huesos propios (una por sector alrededor del
## cuerpo), hijas de `mixamorig_Spine2`, de 3 huesos cada una: `capa_<sector>_1` nace en el hombro de la capa, `_2` a media caída y `_3` es la punta, en el borde.
## Su reposo es la pose de la capa encajada, así que en reposo nada cambia. Este modificador es un péndulo propio: una partícula en `_2` y otra en `_3` por
## cadena, en el espacio del mundo (andar y girar la mecen), con un muelle que las lleva a su sitio sobre Spine2 (RIGIDEZ), gravedad, amortiguación (ARRASTRE:
## sin rebote de goma), largos fijos y choque contra cápsulas en los brazos, los antebrazos y el torso y esferas en las manos (la capa resbala sobre los brazos
## en vez de atravesarlos); cada fotograma gira `_1` y `_2` hacia las partículas.
## Por qué no SpringBoneSimulator3D: existe en Godot 4.7 y sus colisiones (SpringBoneCollisionSphere3D/Capsule3D) chocan, pero sus radios van en unidades del
## mundo, y el personaje se escala (`Pj3D.set_alto`) después de vestirse; aquí todo va en unidades del modelo y se pasa al mundo cada fotograma, y el muelle
## hacia el reposo es explícito (la capa vuelve a su sitio en idle). Ojo al medir: las poses que pone un SkeletonModifier3D solo se leen dentro de
## `Skeleton3D.skeleton_updated`; fuera, `get_bone_global_pose` da las de antes del modificador.
##
## De dónde salen los huesos: `herramientas/montar_ropa_glb.gd` (con `muelles`) los calcula sobre la malla de la capa con `cadenas()`, los añade al esqueleto que
## exporta en ropa_capa.glb, mete sus binds en el Skin de la capa y le pasa el peso de la mitad baja con `pesos_cadena()`. En el juego, `Ropa3D.poner` copia al
## esqueleto del cuerpo los huesos que trae el .glb de la prenda y no tiene el cuerpo (`anadir_huesos`) ANTES de colgar la malla (el Skin los busca por nombre) y,
## si la prenda lleva `"muelles": true` en arte/modelos/ropa.json, cuelga este simulador del esqueleto. Las demás prendas y los demás personajes no traen huesos de
## más: a ellos no se les añade nada. La capucha no lleva muelles (va pegada a la cabeza).
##
## Unidades: el esqueleto de la base va en centésimas de unidad del modelo (la armadura a escala 100); los radios de aquí están en unidades del modelo (coronilla a
## 1,70) y se pasan al espacio del esqueleto al preparar.

const PREFIJO: String = "capa_"
const HUESO_PADRE: String = "mixamorig_Spine2"
## Sectores: nombre -> ángulo en grados alrededor del eje vertical (0 = delante, +Z; 90 = izquierda del personaje, +X).
## Cada 45° (probado cada 30°: el brazo sigue entrando lo mismo entre cadenas y el coste pasa de 0,15 a 0,30 ms por fotograma).
const SECTORES: Dictionary = {"delante": 0.0, "delante_izq": 45.0, "izq": 90.0, "detras_izq": 135.0, "detras": 180.0, "detras_der": -135.0, "der": -90.0,
	"delante_der": -45.0}
## Media anchura (grados) del abanico de vértices que se promedia para colocar cada cadena.
const ABANICO: float = 18.0
## Alturas (u del modelo) de la raíz (`_1`) y del codo de la cadena (`_2`); la punta (`_3`) es el borde de la capa en ese sector.
const ALTO_RAIZ: float = 1.06
const ALTO_MEDIO: float = 0.97
const BANDA: float = 0.02
## Pesos: por encima de PESO_DESDE la capa sigue como estaba (torso, cuello, cabeza); hacia abajo pasa a la cadena de su sector hasta el 100 % en el borde.
const PESO_DESDE: float = 1.10
## REPARTO DE PESOS (24/10, segunda versión; Pablo: «los pesos de la capa no están bien»). Medido en la primera versión: en la franja de los hombros (y 0,99–1,11)
## el 47–68 % del peso iba a hombro, brazo y antebrazo (lo copió Blender de la superficie más cercana del cuerpo) y justo debajo pasaba a las cadenas: 4 670 aristas
## con un salto de peso > 0,5 entre vecinos a 1 cm. Al andar, el brazo tiraba de la franja alta y la cadena de la baja: la capa se arrugaba en el hombro.
## Ahora: (1) ningún hueso de brazo pesa en la capa: lo que Blender dio a hombro, brazo, antebrazo y mano pasa a Spine2 (la capa cuelga del torso; de apartarla
## del brazo se encargan los choques del péndulo); (2) la mezcla entre los dos sectores vecinos es suave (smoothstep del ángulo, no lineal);
## (3) tras repartir, SUAVIZADO_PASADAS pasadas de promedio con los vértices vecinos (soldados por posición), como hacía Blender con sus pesos.
const HUESOS_BRAZO: PackedStringArray = ["Shoulder", "Arm", "ForeArm", "Hand"]
const HUESO_CUERPO_CAPA: String = "mixamorig_Spine2"
const SUAVIZADO_PASADAS: int = 4
const SUAVIZADO_MEZCLA: float = 0.5
## Simulación, en u del modelo y segundos. RIGIDEZ: aceleración hacia el sitio por unidad de separación (1/s²; con GRAVEDAD, la capa quieta cuelga
## GRAVEDAD/RIGIDEZ por debajo de su reposo). ARRASTRE: amortiguación de la velocidad (1/s). RADIO_HUESO: grosor de la tela que se suma a cada choque.
const RIGIDEZ: float = 150.0
const ARRASTRE: float = 10.0
const GRAVEDAD: float = 0.6
const RADIO_HUESO: float = 0.015
## CUELGA (25/10, Pablo: «la capa sigue yendo hacia arriba»). Medido: con el muelle hacia el reposo de la capa ENCAJADA (la campana del encaje: los lados a 23 cm
## del eje y el borde de atrás 2 cm más alto que el de delante) la simulación la movía 1 mm; lo que se veía «hacia arriba» era esa campana. Ahora el sitio al que
## tira el muelle es una mezcla entre ese reposo y la VERTICAL bajo la raíz de la cadena (colgar del hombro con el largo de la cadena): COLGAR = 1 cuelga del todo,
## 0 = la campana de antes. De apartarla del cuerpo y de los brazos se encargan los choques; la gravedad del péndulo sigue sumando.
const COLGAR: float = 0.85
## Si una partícula queda a más de esto de su sitio (un salto de cámara, un teletransporte), se vuelve a poner en él.
const SALTO_MAX: float = 0.5
## Pasadas de largos + choques por fotograma.
const PASADAS: int = 1
## Colisiones (u del modelo).
const RADIO_BRAZO: float = 0.06
const RADIO_ANTEBRAZO: float = 0.055
const RADIO_MANO: float = 0.06
## 25/10: con la capa colgando (COLGAR) el paño ENTRE dos cadenas (a 45°) queda a cos(22,5°) ≈ 0,92 del radio de las cadenas: para que no se meta en el
## cuerpo, los radios de torso y cadera llevan esa holgura (0,11 → 0,12 y 0,12 → 0,14; medido: con los de antes el borde entraba 3,6 cm en idle).
const RADIO_TORSO: float = 0.12
const RADIO_CADERA: float = 0.14
const RADIO_MUSLO: float = 0.085
## Puntos de cada tramo de la cadena que se chocan (fracciones del tramo; la partícula es el 1,0): la tela entre partículas tampoco atraviesa el brazo.
const PUNTOS_TRAMO: Array = [0.5, 1.0]
const LADOS: Array = ["Left", "Right"]

## Por cadena: [i_1, i_2, i_3] (índices de hueso), partículas (mundo) y velocidades.
var _cadenas: Array = []
var _pos: Array = []
var _vel: Array = []
## Choques: [hueso_a, hueso_b (-1 = esfera), radio u del modelo].
var _choques: Array = []
var _listo: bool = false
var _reiniciar: bool = true


## Nombres de los huesos de una cadena: [_1, _2, _3].
static func nombres(sector: String) -> Array:
	return [PREFIJO + sector + "_1", PREFIJO + sector + "_2", PREFIJO + sector + "_3"]


## Las cadenas sobre la malla de la capa: [{nombre, padre, global}] (global = transformación en el espacio del esqueleto). `verts` en el espacio de la malla,
## `malla_a_esqueleto` lleva de él al del esqueleto y `escala` es la de la armadura (u del modelo = espacio del esqueleto × escala).
static func cadenas(sk: Skeleton3D, verts: PackedVector3Array, malla_a_esqueleto: Transform3D, escala: float) -> Array:
	var pts := PackedVector3Array()
	for v in verts:
		pts.append(malla_a_esqueleto * v * escala)
	var borde: float = INF
	for p in pts:
		borde = minf(borde, p.y)
	var centro: Vector2 = _centro(pts, borde)
	var base: Basis = sk.get_bone_global_rest(sk.find_bone(HUESO_PADRE)).basis
	var res: Array = []
	for s in SECTORES:
		var ang: float = float(SECTORES[s])
		var raiz: Vector3 = _media(pts, centro, ang, ALTO_RAIZ - BANDA, ALTO_RAIZ + BANDA)
		var medio: Vector3 = _media(pts, centro, ang, ALTO_MEDIO - BANDA, ALTO_MEDIO + BANDA)
		var punta: Vector3 = _media(pts, centro, ang, borde - 0.005, borde + BANDA * 1.5)
		var n: Array = nombres(s)
		var padre: String = HUESO_PADRE
		for k in 3:
			var p: Vector3 = [raiz, medio, punta][k]
			res.append({"nombre": n[k], "padre": padre, "global": Transform3D(base, p / escala)})
			padre = n[k]
	return res


## Centro en X/Z de la banda baja de la capa.
static func _centro(pts: PackedVector3Array, borde: float) -> Vector2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		if p.y <= borde + 0.06:
			lo = lo.min(Vector2(p.x, p.z))
			hi = hi.max(Vector2(p.x, p.z))
	return (lo + hi) * 0.5


static func angulo(p: Vector3, centro: Vector2) -> float:
	return rad_to_deg(atan2(p.x - centro.x, p.z - centro.y))


static func _media(pts: PackedVector3Array, centro: Vector2, ang: float, y0: float, y1: float) -> Vector3:
	var suma := Vector3.ZERO
	var n: int = 0
	for p in pts:
		if p.y >= y0 and p.y <= y1 and absf(angle_difference(deg_to_rad(angulo(p, centro)), deg_to_rad(ang))) <= deg_to_rad(ABANICO):
			suma += p
			n += 1
	return suma / maxf(n, 1)


## Pesos de un vértice (u del modelo `p`) hacia las cadenas: {nombre de hueso: peso}, ya multiplicados por la parte que pasa a la cadena; `parte` (0..1) es esa
## parte (lo que se quita a los pesos que traía). Mezcla los sectores por ángulo con un abanico suave de ANCHO_MEZCLA grados y `_1`/`_2` por altura.
static func pesos_cadena(p: Vector3, centro: Vector2, borde: float) -> Dictionary:
	var parte: float = clampf((PESO_DESDE - p.y) / (PESO_DESDE - borde), 0.0, 1.0)
	parte = parte * parte * (3.0 - 2.0 * parte)
	if parte <= 0.0:
		return {"parte": 0.0, "pesos": {}}
	var a: float = angulo(p, centro)
	# los DOS sectores más cercanos en ángulo, con mezcla suave entre ellos (smoothstep del ángulo). Solo dos a propósito: con tres o cuatro (probado con un abanico
	# de 70°) salen 6–8 huesos de cadena por vértice, el Skin solo guarda 4, y al recortar se perdía hasta un 40 % del peso de la cadena y Spine2 se inflaba
	# a saltos entre vecinos (1 512 aristas con salto > 0,5). Con dos sectores son 4 huesos de cadena como mucho, más Spine2.
	var por_sector: Dictionary = {}
	var total: float = 0.0
	var cerca: Array = SECTORES.keys()
	cerca.sort_custom(func(x, y): return absf(angle_difference(deg_to_rad(a), deg_to_rad(float(SECTORES[x])))) < absf(angle_difference(deg_to_rad(a), deg_to_rad(float(SECTORES[y])))))
	var s0: String = cerca[0]
	var s1: String = cerca[1]
	var d0: float = absf(rad_to_deg(angle_difference(deg_to_rad(a), deg_to_rad(float(SECTORES[s0])))))
	var d1: float = absf(rad_to_deg(angle_difference(deg_to_rad(a), deg_to_rad(float(SECTORES[s1])))))
	var f: float = d0 / maxf(d0 + d1, 1e-6)        # 0 = justo en s0, 0,5 = a medio camino
	f = f * f * (3.0 - 2.0 * f)
	por_sector[s0] = 1.0 - f
	por_sector[s1] = f
	total = 1.0
	var u: float = clampf((ALTO_RAIZ - p.y) / (ALTO_RAIZ - borde), 0.0, 1.0)
	var res: Dictionary = {}
	for s in por_sector:
		var n: Array = nombres(String(s))
		var w: float = float(por_sector[s]) / maxf(total, 1e-9)
		res[n[0]] = float(res.get(n[0], 0.0)) + parte * w * (1.0 - u)
		res[n[1]] = float(res.get(n[1], 0.0)) + parte * w * u
	return {"parte": parte, "pesos": res}


## ¿Es un hueso de brazo (hombro, brazo, antebrazo o mano, de cualquier lado)? Su peso en la capa pasa a HUESO_CUERPO_CAPA.
static func es_hueso_brazo(nombre: String) -> bool:
	var n: String = nombre.replace("mixamorig_", "").trim_prefix("Left").trim_prefix("Right")
	for h in HUESOS_BRAZO:
		if n == h:
			return true
	return false


## Copia a `destino` los huesos de `origen` que empiezan por PREFIJO y `destino` no tiene (mismo nombre, padre por nombre, mismo reposo). Devuelve cuántos.
static func anadir_huesos(destino: Skeleton3D, origen: Skeleton3D) -> int:
	var n: int = 0
	for i in origen.get_bone_count():
		var nombre: String = origen.get_bone_name(i)
		if not nombre.begins_with(PREFIJO) or destino.find_bone(nombre) >= 0:
			continue
		var j: int = destino.get_bone_count()
		destino.add_bone(nombre)
		var padre: int = origen.get_bone_parent(i)
		if padre >= 0:
			destino.set_bone_parent(j, destino.find_bone(origen.get_bone_name(padre)))
		destino.set_bone_rest(j, origen.get_bone_rest(i))
		destino.reset_bone_pose(j)
		n += 1
	return n


## Busca las cadenas y los huesos de choque en `sk` (ya con los huesos de la capa). Se llama al colgarlo del esqueleto.
func preparar(sk: Skeleton3D) -> void:
	_cadenas.clear()
	for s in SECTORES:
		var n: Array = nombres(String(s))
		var ids: Array = [sk.find_bone(n[0]), sk.find_bone(n[1]), sk.find_bone(n[2])]
		if not ids.has(-1):
			_cadenas.append(ids)
	_choques.clear()
	for lado in LADOS:
		_choques.append([sk.find_bone("mixamorig_%sArm" % lado), sk.find_bone("mixamorig_%sForeArm" % lado), RADIO_BRAZO])
		_choques.append([sk.find_bone("mixamorig_%sForeArm" % lado), sk.find_bone("mixamorig_%sHand" % lado), RADIO_ANTEBRAZO])
		_choques.append([sk.find_bone("mixamorig_%sHand" % lado), -1, RADIO_MANO])
	_choques.append([sk.find_bone("mixamorig_Spine1"), sk.find_bone("mixamorig_Neck"), RADIO_TORSO])
	_choques.append([sk.find_bone("mixamorig_Hips"), sk.find_bone("mixamorig_Spine1"), RADIO_CADERA])
	for lado in LADOS:
		_choques.append([sk.find_bone("mixamorig_%sUpLeg" % lado), sk.find_bone("mixamorig_%sLeg" % lado), RADIO_MUSLO])
	_listo = not _cadenas.is_empty()
	_reiniciar = true


## Vuelve a poner las partículas en su sitio en el fotograma siguiente.
func reset() -> void:
	_reiniciar = true


func _process_modification_with_delta(delta: float) -> void:
	var sk: Skeleton3D = get_skeleton()
	if not _listo or sk == null:
		return
	var a_mundo: Transform3D = sk.global_transform
	var a_esq: Transform3D = a_mundo.affine_inverse()
	# u del modelo -> mundo (el esqueleto va en centésimas y el personaje escalado)
	var k: float = a_mundo.basis.get_scale().x / ((sk.get_parent() as Node3D).scale.y if sk.get_parent() is Node3D else 1.0)
	var dt: float = clampf(delta, 0.0, 0.05)
	var segs: Array = []
	for c in _choques:
		if int(c[0]) < 0:
			continue
		var pa: Vector3 = a_mundo * sk.get_bone_global_pose(int(c[0])).origin
		var pb: Vector3 = pa if int(c[1]) < 0 else a_mundo * sk.get_bone_global_pose(int(c[1])).origin
		segs.append([pa, pb, (float(c[2]) + RADIO_HUESO) * k])
	if _reiniciar or _pos.size() != _cadenas.size():
		_pos.resize(_cadenas.size())
		_vel.resize(_cadenas.size())
	for ci in _cadenas.size():
		var ids: Array = _cadenas[ci]
		var padre: int = sk.get_bone_parent(int(ids[0]))
		var g1: Transform3D = sk.get_bone_global_pose(padre) * sk.get_bone_rest(int(ids[0]))
		var g2: Transform3D = g1 * sk.get_bone_rest(int(ids[1]))
		var g3: Transform3D = g2 * sk.get_bone_rest(int(ids[2]))
		var raiz: Vector3 = a_mundo * g1.origin
		var sitio: Array = [a_mundo * g2.origin, a_mundo * g3.origin]
		var largos: Array = [(sitio[0] - raiz).length(), (sitio[1] - sitio[0]).length()]
		# colgar: el sitio se acerca a la vertical bajo la raíz (ver COLGAR), conservando los largos
		var colgado0: Vector3 = raiz + Vector3.DOWN * largos[0]
		var colgado1: Vector3 = colgado0 + Vector3.DOWN * largos[1]
		sitio[0] = (sitio[0] as Vector3).lerp(colgado0, COLGAR)
		sitio[1] = (sitio[1] as Vector3).lerp(colgado1, COLGAR)
		if _reiniciar or _pos[ci] == null or ((_pos[ci] as Array)[1] - sitio[1]).length() > SALTO_MAX * k:
			_pos[ci] = [sitio[0], sitio[1]]
			_vel[ci] = [Vector3.ZERO, Vector3.ZERO]
		var p: Array = _pos[ci]
		var v: Array = _vel[ci]
		var amort: float = exp(-ARRASTRE * dt)
		# solo los choques al alcance de la cadena
		var alcance: float = largos[0] + largos[1]
		var cerca: Array = []
		for s in segs:
			if (Geometry3D.get_closest_point_to_segment(raiz, s[0], s[1]) - raiz).length() < alcance + float(s[2]):
				cerca.append(s)
		for j in 2:
			var acel: Vector3 = (sitio[j] - p[j]) * RIGIDEZ + Vector3.DOWN * GRAVEDAD * k
			v[j] = v[j] * amort + acel * dt
			p[j] = p[j] + v[j] * dt
		for _pasada in PASADAS:
			var ancla: Vector3 = raiz
			for j in 2:
				p[j] = ancla + (p[j] - ancla).normalized() * largos[j]
				# en el tramo de arriba solo la partícula: su raíz nace en el cuello, pegada al torso, y el medio del tramo ya roza la cápsula del pecho en reposo
				for f in (PUNTOS_TRAMO if j == 1 else [1.0]):
					# un punto del tramo dentro de un choque mueve la partícula lo que haga falta para sacarlo (palanca 1/f)
					for s in cerca:
						var q: Vector3 = ancla.lerp(p[j], f)
						var fuera: Vector3 = _fuera(q, s[0], s[1], s[2])
						if fuera != q:
							p[j] = p[j] + (fuera - q) / f
				p[j] = ancla + (p[j] - ancla).normalized() * largos[j]
				ancla = p[j]
		_pos[ci] = p
		_vel[ci] = v
		# girar _1 hacia la partícula de _2, y _2 hacia la de _3 (en el espacio del esqueleto)
		var n1: Basis = Basis(Quaternion((g2.origin - g1.origin).normalized(), ((a_esq * p[0]) - g1.origin).normalized())) * g1.basis
		var g1n := Transform3D(n1, g1.origin)
		sk.set_bone_pose_rotation(int(ids[0]), (sk.get_bone_global_pose(padre).basis.inverse() * n1).get_rotation_quaternion())
		var g2n: Transform3D = g1n * sk.get_bone_rest(int(ids[1]))
		var g3n: Transform3D = g2n * sk.get_bone_rest(int(ids[2]))
		var n2: Basis = Basis(Quaternion((g3n.origin - g2n.origin).normalized(), ((a_esq * p[1]) - g2n.origin).normalized())) * g2n.basis
		sk.set_bone_pose_rotation(int(ids[1]), (g1n.basis.inverse() * n2).get_rotation_quaternion())
	_reiniciar = false


## `q` empujado fuera de la cápsula a-b de radio r (esfera si a == b).
static func _fuera(q: Vector3, a: Vector3, b: Vector3, r: float) -> Vector3:
	var c: Vector3 = a if a == b else Geometry3D.get_closest_point_to_segment(q, a, b)
	var d: Vector3 = q - c
	var l: float = d.length()
	if l >= r or l < 1e-9:
		return q
	return c + d / l * r
