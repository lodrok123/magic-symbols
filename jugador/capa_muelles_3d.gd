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
## SIN CABEZA (25/10; Pablo, con un vídeo del laboratorio: «Revisa la capa. Los pesos están mal. No funciona en ninguna animación, ni idle ni walking»). Medido
## (herramientas/pesos_capa.gd): la parte alta de la capa (y 1,10–1,31, la que rodea por fuera el bajo de la capucha y cae por la nuca hasta 38 cm detrás del
## cuello) llevaba el peso de la CABEZA que le copió Blender del cuerpo: 37 % en cuello y nuca, 59 % en los hombros, 99 % por encima de 1,22 y 460 vértices bajo
## el cuello con hasta 0,27 en Head. Al inclinar la cabeza (idle, andar) su borde de arriba se iba con ella y el de abajo se quedaba con Spine2: la nuca se
## estiraba en un ala hacia atrás. Ahora la capa NO pesa en la cabeza: lo que Blender dio a Head (y a Neck) pasa a HUESO_CUERPO_CAPA (Spine2), y solo el anillo
## del cierre, pegado al cuello (a menos de CUELLO_RADIO de su eje, por encima de la base del cuello), lleva hasta CUELLO_PESO_MAX de Neck, con un fundido
## suave (`parte_cuello`). Lo aplican `herramientas/repesar_capa.gd` (sobre el ropa_capa.glb ya montado) y `montar_ropa_glb.gd` (al montarla desde Blender).
## Y la FORMA: el ala no salía solo del peso. Desde el 24/10 `Pj3D.PROPORCIONES["jugadora_base"]` encoge la cabeza a 0,80 (ProporcionChibi escala el hueso
## Head) y la capucha encoge con ella, pero la parte alta de la capa estaba hecha para la capucha a 1,0: lo que antes tapaba la capucha (la nuca de la capa
## hasta 1,31 y 38 cm detrás del cuello) quedaba al aire como un ala, y con el peso en Head se estiraba. Al quitar la cabeza se HORNEA esa escala en la
## geometría: cada vértice se lleva a donde lo dejaba la cabeza encogida con su peso de Head de Blender (`encoger_con_cabeza`), así la capa en reposo queda
## donde la dejaba la cabeza encogida, pero pegada al torso. Si cambia la proporción de la cabeza hay que repesar desde la capa con los pesos de Blender.
## NUCA: aun así la espalda de la capa seguía hecha para envolver el pelo (que la capucha apaga) y la capucha a 1,0: por detrás, a la altura del cuello, la
## capa quedaba a 40–43 cm del eje del cuello y la espalda del cuerpo a 6 cm (medido por sectores): una joroba. `ajustar_nuca` la pega: por encima de NUCA_DESDE,
## en cada altura y ángulo, el radio de fuera de la capa se limita a una rampa que va del que tiene a NUCA_DESDE al de NUCA_ARRIBA a la altura NUCA_HASTA (bajo
## el borde de la capucha encogida), encogiendo hacia el eje del cuello todos los vértices de esa altura y ángulo por igual (la tela conserva su grosor relativo).
const NUCA_DESDE: float = 1.00
const NUCA_HASTA: float = 1.24
const NUCA_ARRIBA: float = 0.22
const NUCA_SECTORES: int = 24
const NUCA_PASO: float = 0.01
## Solo por DETRÁS: la rampa pesa 0 hasta NUCA_ANG_DESDE grados desde delante y entera desde NUCA_ANG_PLENO (fundido suave). Medido: aplicada en todo el contorno
## (primera prueba) metía los lados (±90°, que ya caían bien sobre los hombros) 8 mm en la mandíbula de la cabeza encogida (prueba_ropa_capa (e)).
const NUCA_ANG_DESDE: float = 110.0
const NUCA_ANG_PLENO: float = 165.0
const HUESOS_CABEZA: PackedStringArray = ["Head", "HeadTop_End", "headfront", "Neck"]
const HUESO_CUELLO: String = "mixamorig_Neck"
const CUELLO_RADIO: float = 0.08
const CUELLO_FUNDIDO: float = 0.04
const CUELLO_BAJO: float = 0.04
const CUELLO_PESO_MAX: float = 0.5
## Ningún vértice de la capa por debajo del cuello (Neck) puede llevar más de esto de peso en Head (prueba_ropa_capa, herramientas/pesos_capa.gd).
const HEAD_MAX_BAJO_CUELLO: float = 0.02
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


## ¿Es un hueso de cabeza o cuello (Head, su punta, el `headfront` de Meshy o Neck)? Su peso en la capa pasa a HUESO_CUERPO_CAPA (ver SIN CABEZA).
static func es_hueso_cabeza(nombre: String) -> bool:
	return HUESOS_CABEZA.has(nombre.replace("mixamorig_", ""))


## Parte del peso de cuerpo de un vértice de la capa (u del modelo `p`) que va a Neck: hasta CUELLO_PESO_MAX en el anillo del cierre (a menos de CUELLO_RADIO del
## eje vertical del cuello y por encima de la base del cuello menos CUELLO_BAJO), 0 fuera, con fundidos suaves. `cuello` = Neck en reposo (u del modelo).
static func parte_cuello(p: Vector3, cuello: Vector3) -> float:
	var r: float = Vector2(p.x - cuello.x, p.z - cuello.z).length()
	var f_r: float = 1.0 - smoothstep(CUELLO_RADIO, CUELLO_RADIO + CUELLO_FUNDIDO, r)
	var f_y: float = smoothstep(cuello.y - CUELLO_BAJO, cuello.y, p.y)
	return CUELLO_PESO_MAX * f_r * f_y


## Posición (u del modelo) de un vértice de la capa `p` con peso de cabeza `h` (lo que Blender dio a HUESOS_CABEZA menos Neck) cuando la cabeza está escalada
## `escala` alrededor de `cabeza` (Head en reposo, u del modelo): la que le daba la piel con ese peso. Ver SIN CABEZA.
## Probado y descartado (prueba_ropa_capa (e) con la cabeza encogida): con el peso tal cual quedan 6 vértices de los lados (y 1,15–1,20, junto a la mandíbula)
## hasta 8 mm dentro de la cabeza; sin hornear esa franja (solo por encima de 1,18) salen 54, y con el peso ×1,5, 14.
static func encoger_con_cabeza(p: Vector3, h: float, cabeza: Vector3, escala: float) -> Vector3:
	return p.lerp(cabeza + (p - cabeza) * escala, clampf(h, 0.0, 1.0))


## Pega la nuca de la capa (ver NUCA): `pts` en u del modelo, `eje` = X/Z del cuello (Neck en reposo). Devuelve los puntos nuevos. Idempotente: sobre una capa ya
## pegada el radio no pasa de la rampa y no cambia nada.
static func ajustar_nuca(pts: PackedVector3Array, eje: Vector2) -> PackedVector3Array:
	var y_max: float = NUCA_DESDE
	for p in pts:
		y_max = maxf(y_max, p.y)
	var filas: int = int(ceil((y_max - NUCA_DESDE) / NUCA_PASO)) + 1
	var paso_ang: float = TAU / NUCA_SECTORES
	# radio de fuera por fila (altura) y sector (ángulo), contando los vecinos (±1,5 filas, ±1 sector)
	var r_max: Array = []
	for f in filas:
		var fila: Array = []
		fila.resize(NUCA_SECTORES)
		fila.fill(0.0)
		r_max.append(fila)
	for p in pts:
		if p.y < NUCA_DESDE - NUCA_PASO * 1.5:
			continue
		var d := Vector2(p.x, p.z) - eje
		var fy: float = (p.y - NUCA_DESDE) / NUCA_PASO
		var s0: int = int(round(fposmod(atan2(d.x, d.y), TAU) / paso_ang))
		for f in range(maxi(0, int(floor(fy - 1.5))), mini(filas, int(ceil(fy + 1.5)) + 1)):
			if absf(f - fy) > 1.5:
				continue
			for k in [-1, 0, 1]:
				var s: int = posmod(s0 + k, NUCA_SECTORES)
				r_max[f][s] = maxf(float(r_max[f][s]), d.length())
	# factor de encogimiento por fila y sector: la rampa desde el radio de la fila de NUCA_DESDE hasta NUCA_ARRIBA en NUCA_HASTA
	var fac: Array = []
	for f in filas:
		var y: float = NUCA_DESDE + f * NUCA_PASO
		var t: float = clampf((y - NUCA_DESDE) / (NUCA_HASTA - NUCA_DESDE), 0.0, 1.0)
		var fila: Array = []
		for s in NUCA_SECTORES:
			var r0: float = float(r_max[0][s])
			var r: float = float(r_max[f][s])
			var lim: float = lerpf(r0 if r0 > 0.0 else NUCA_ARRIBA, NUCA_ARRIBA, t)
			var detras: float = smoothstep(NUCA_ANG_DESDE, NUCA_ANG_PLENO, absf(angle_difference(0.0, s * paso_ang)) * 180.0 / PI)
			fila.append(1.0 if r <= lim or r <= 0.0 else lerpf(1.0, lim / r, detras))
		fac.append(fila)
	# una pasada de suavizado por ángulo (que no queden escalones entre sectores)
	for f in filas:
		var viejo: Array = (fac[f] as Array).duplicate()
		for s in NUCA_SECTORES:
			fac[f][s] = minf(float(viejo[s]), (float(viejo[posmod(s - 1, NUCA_SECTORES)]) + 2.0 * float(viejo[s]) + float(viejo[(s + 1) % NUCA_SECTORES])) * 0.25)
	var res := PackedVector3Array()
	res.resize(pts.size())
	for i in pts.size():
		var p: Vector3 = pts[i]
		if p.y <= NUCA_DESDE:
			res[i] = p
			continue
		var d := Vector2(p.x, p.z) - eje
		var fy: float = clampf((p.y - NUCA_DESDE) / NUCA_PASO, 0.0, filas - 1.0)
		var fs: float = fposmod(atan2(d.x, d.y), TAU) / paso_ang
		var f0: int = int(floor(fy))
		var f1: int = mini(f0 + 1, filas - 1)
		var s0: int = int(floor(fs)) % NUCA_SECTORES
		var s1: int = (s0 + 1) % NUCA_SECTORES
		var ty: float = fy - f0
		var ts: float = fs - floor(fs)
		var k: float = lerpf(lerpf(float(fac[f0][s0]), float(fac[f0][s1]), ts), lerpf(float(fac[f1][s0]), float(fac[f1][s1]), ts), ty)
		var d2: Vector2 = eje + d * k
		res[i] = Vector3(d2.x, p.y, d2.y)
	return res


## Pesos de cuerpo de un vértice de la capa sin cabeza: `w` = {nombre de hueso: peso}; lo de HUESOS_CABEZA pasa a HUESO_CUERPO_CAPA y de ahí `parte_cuello` a
## HUESO_CUELLO. Las cadenas `capa_*` y el resto no se tocan. Devuelve un diccionario nuevo (sin normalizar: la suma no cambia).
static func pesos_sin_cabeza(w: Dictionary, p: Vector3, cuello: Vector3) -> Dictionary:
	var res: Dictionary = {}
	for n in w:
		var destino: String = HUESO_CUERPO_CAPA if es_hueso_cabeza(String(n)) else String(n)
		res[destino] = float(res.get(destino, 0.0)) + float(w[n])
	var torso: float = float(res.get(HUESO_CUERPO_CAPA, 0.0))
	var al_cuello: float = torso * parte_cuello(p, cuello)
	if al_cuello > 0.0:
		res[HUESO_CUERPO_CAPA] = torso - al_cuello
		res[HUESO_CUELLO] = al_cuello
	return res


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
