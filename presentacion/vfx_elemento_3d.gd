class_name VfxElemento3D
extends Node

## VFX POR ELEMENTO (Pipeline, 20/10, entrada 203). Vuelve a dar a cada hechizo el efecto de SU ELEMENTO (fuego, agua, tierra, viento, y el genérico del kit
## para rayo, hielo y tiempo) con las piezas de `VfxKit3D`, después de la mudanza a `Hechizo` / `HechizoVivo`.
## POR QUÉ existe: al pasar a la receta V2 el único dibujo que se enganchó al lanzamiento fue `VfxEstado3D` (por ESTADO de la materia, autocontenido y sin el
## arte validado del kit), así que el efecto del elemento dejó de verse. Este nodo escucha lo MISMO que escucha aquel y no toca la lógica:
##   · `Lanzador3D.child_entered_tree` → cada `HechizoVivo` con `h.velocidad > 0` (flecha, o cualquier hechizo con velocidad) es un PROYECTIL: no emite
##     `hechizo_v2`. Se le cuelga un `Seguidor` (Node3D) con la bola del elemento; viaja con él, y al irse el HechizoVivo se suelta y se apaga solo.
##   · `Lanzador3D.hechizo_v2(estado, elemento, volumen, origen, dir, props)` → hechizo que NO viaja como proyectil. La señal no trae el nodo, pero el
##     `HechizoVivo` se añade al lanzador ANTES de emitir (HechizoVivo.crear → add_child → _materializar → emit), así que es el último que entró: de él
##     cuelga el efecto (nace con él y muere con él; si el HechizoVivo se libera antes de que acabe el dibujo, el dibujo se suelta y se apaga en 0,5 s).
## Variaciones de antes, leídas del `Hechizo` y de `props` (no de nombres de forma, que ya no existen):
##   velocidad > 0 → viaja (bola + estela);  props con `crece` → pulso (aro que se abre);  props con `solidez` → barrera (cúpula);  si no, esfera (impacto en sitio).
##   El volumen trae `haz` (ᛁ `linea` + elemento, 21/10: «rayo de X») → HAZ de la mano a la punta, con el dibujo de cada elemento (`haz`). El muro es solo de `barrera`.
## VfxEstado3D (por estado) queda aparte: `VfxEstado3D.encendido` lo apaga y la maqueta lo deja apagado hasta validar elemento por elemento.
## Uso:   VfxElemento3D.conectar(lanzador, mundo)

## Elementos con pieza propia en este nodo; el resto usa las piezas del kit teñidas por `VfxKit3D.elemento` (sin validar).
const PROPIOS: PackedStringArray = ["fuego", "agua", "tierra", "viento"]
const VIDA_MIN: float = 1.0
const VIDA_MAX: float = 25.0         ## = el límite global `persiste + permanencia` de ESPEC_HECHIZO §1.9. Antes 4 s: un bloque de tierra (8 s) o una barrera con Permanencia perdían el dibujo a los 4 s
const MAX_VIVOS: int = 12            ## efectos a la vez (cada uno puede traer una luz y ~150 partículas; el resto se descarta)
## RAYO (21/10): el haz de ᛁ `linea`. `esc` del dibujo = ancho del haz (u) / HAZ_ANCHO_REF_U, limitado a [HAZ_ESC_MIN, HAZ_ESC_MAX]. 0,8 u = el ancho por defecto (Hechizo.HAZ_ANCHO 0,35 m × casilla 2,3).
const HAZ_ANCHO_REF_U: float = 0.8
const HAZ_ESC_MIN: float = 0.5
const HAZ_ESC_MAX: float = 2.0

## Tamaño del dibujo respecto al hechizo (20/10, entrada 215). Antes eran `clampf` escondidos en el código y los cambios de tamaño (glifos de eje, tabla F1 del lab)
## dejaban de verse: la bola del proyectil se paraba en radio 0,9 u (semieje ≈ 0,39 m) y los volúmenes en ×3. Ahora el radio dibujado = el semieje (la caja de golpe) hasta el límite
## global de 3 m; estos topes solo protegen de un valor absurdo. Son `static var` para poder tocarlos desde una prueba o el lab.
static var FACTOR_BOLA_MIN: float = 0.3      ## f = radio_u / 0,3 (la bola del kit mide 0,3·f) · 24/10: de 0,5 a 0,3 para no inflar la flecha de base 0,10 (0,115 u de radio = f 0,38)
static var FACTOR_BOLA_MAX: float = 24.0     ## 24 · 0,3 = 7,2 u > 3 m · 2,3 = 6,9 u (el semieje máximo)
static var ESCALA_VOL_MIN: float = 0.4       ## `esc` de los volúmenes (impacto, onda, cúpula): radio_u / 0,45 · 24/10: de 0,6 a 0,4 (la esfera base de 0,23 u da 0,51)
static var ESCALA_VOL_MAX: float = 8.0
## Un proyectil que nace NO aparece a tamaño completo: empieza pequeño y llega a su tamaño real (enfoque sutil).
static var PROYECTIL_ESCALA_INICIAL: float = 0.2     ## fracción del tamaño real al nacer
static var PROYECTIL_CRECE_S: float = 0.6            ## segundos hasta el tamaño real (smoothstep: arranca despacio, acelera y se asienta; a la flecha, 1,7 casillas/s, le da ~1 casilla)
static var PROYECTIL_COLA_APAGA_S: float = 0.15      ## al pararse, cuánto tarda en apagarse lo que solo tiene sentido en movimiento (cola, chispas)

## Imprime una línea por cada hechizo recibido (elemento, estado, forma, nº de celdas). Para medir: `VfxElemento3D.traza = true`.
static var traza: bool = false

## Tamaño de una casilla (Terreno3D.casilla = 2,3). Propiedad para que la prueba y la maqueta puedan fijarlo.
var casilla: float = 2.3
## Con false no monta nada (lo pone el F4 del lab: allí se aprueba el dibujo por ESTADO y no debe haber otro encima).
var encendido: bool = true

var _mundo: Node3D = null
var _lanzador: Object = null
var _ultimo: WeakRef = null
var _vivos: int = 0
var _proyectiles_n: int = 0
var _volumenes_n: int = 0
var _haces_n: int = 0
var _placas_n: int = 0
var _log: String = ""


## Gira sobre su eje Y local (los anillos del viento y los terrones que orbitan). Un nodo con _process en vez de un tween en bucle: muere con su padre.
class Giro extends Node3D:
	var w: float = 6.0
	func _process(delta: float) -> void:
		rotate_object_local(Vector3.UP, w * delta)


## Raíz del efecto de un hechizo. `top_level` para que, colgada de un HechizoVivo que no se mueve, el efecto se coloque en coordenadas de mundo.
## Guarda su última transformada de mundo: cuando el HechizoVivo se va, el árbol ya no deja leerla (`global_transform` falla fuera del árbol) y hace falta para soltarlo en su sitio.
class Seguidor extends Node3D:
	var ultima: Transform3D = Transform3D.IDENTITY
	func _process(_delta: float) -> void:
		if is_inside_tree():
			ultima = global_transform


## Seguidor de un PROYECTIL (cuelga del HechizoVivo y viaja con él). Hace dos cosas que no son del dibujo del elemento sino de su vida:
##   · NACER: crece desde `PROYECTIL_ESCALA_INICIAL` hasta 1 en `PROYECTIL_CRECE_S` (escala del nodo: lo que cuelga de él, la bola, la cola y las partículas, crece a la vez).
##   · PARARSE: cuando el HechizoVivo deja de estar `activo` (llegó, chocó, golpeó: se queda `permanencia` s con `quedandose`, o desaparece) la cola, las chispas y los jirones
##     se apagan: son «líneas de movimiento» y un proyectil parado no se mueve. Se queda solo el cuerpo (la bola, el terrón, los aros), que es lo que permanece.
class Proyectil extends Seguidor:
	var hv_ref: WeakRef = null
	var cola: Array = []           ## nodos que solo tienen sentido en movimiento (se rellena al montar el dibujo)
	var elemento: String = "fuego"
	var mundo: Node = null         ## de donde cuelgan el impacto y el fin (no del proyectil: se va con él)
	var esc: float = 1.0           ## tamaño del hechizo (radio_u / 0,45), para el impacto
	var escala_ini: float = 0.2    ## escala con la que nace (la fija `_dibujar_proyectil`)
	var _t: float = 0.0
	var _parado: bool = false
	var _t_parado: float = 0.0
	var _avisado: bool = false     ## ya se pidió el impacto / el fin (una sola vez)
	## Cintas/conos de la cola que giran con la velocidad (solo un proyectil que CAE, `gravedad` > 0: el agua en arco). Se montan apuntando hacia atrás
	## de la dirección de salida `dir_cintas`; si no giraran, al curvarse el vuelo se quedarían clavadas en esa dirección (63–82° desviadas a media
	## caída, medido) y se leerían como rayas sueltas que no salen del movimiento. Sin gravedad la dirección no cambia y no se toca nada (el fuego).
	var dir_cintas: Vector3 = Vector3.ZERO      ## ZERO = no giran
	var _cintas: Array = []                      ## [MeshInstance3D, Transform3D de montaje]

	## Guarda las mallas de la cola con su transformación de montaje y la dirección con que se montaron. Lo llama `_dibujar_proyectil` si el hechizo cae.
	func seguir_direccion(d_montaje: Vector3) -> void:
		dir_cintas = d_montaje.normalized()
		_cintas.clear()
		for n in cola:
			if n is MeshInstance3D and is_instance_valid(n):
				_cintas.append([n, (n as MeshInstance3D).transform])

	## Gira las cintas (alrededor de la bola, que es el origen) lo que ha girado la velocidad desde el montaje.
	func _girar_cintas(v: Vector3) -> void:
		if dir_cintas == Vector3.ZERO or v.length() < 0.5:
			return
		var rot := Basis(Quaternion(dir_cintas, v.normalized()))
		for par in _cintas:
			var mi: MeshInstance3D = par[0] as MeshInstance3D
			if mi != null and is_instance_valid(mi):
				mi.transform = Transform3D(rot, Vector3.ZERO) * (par[1] as Transform3D)

	func _process(delta: float) -> void:
		super._process(delta)
		var hv: Object = hv_ref.get_ref() if hv_ref != null else null
		if not _parado:
			_t += delta
			var k: float = clampf(_t / maxf(VfxElemento3D.PROYECTIL_CRECE_S, 0.01), 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)                      # suave al empezar y al llegar (smoothstep): se nota el «enfoque», no un salto
			scale = Vector3.ONE * lerpf(escala_ini, 1.0, k)
			if hv != null and is_instance_valid(hv) and bool(hv.get("activo")):
				_girar_cintas(hv.get("v") as Vector3)
			if hv != null and is_instance_valid(hv) and not bool(hv.get("activo")):
				_parado = true
				al_pararse(hv)
		else:
			_t_parado += delta
			var f: float = clampf(_t_parado / maxf(VfxElemento3D.PROYECTIL_COLA_APAGA_S, 0.01), 0.0, 1.0)
			for n in cola:
				if n == null or not is_instance_valid(n):
					continue
				if n is GPUParticles3D:
					(n as GPUParticles3D).emitting = false
					(n as Node3D).visible = false          # lo ya emitido (chispas alargadas) también fuera: son justo las líneas que no deben verse parado
				elif n is Node3D:
					(n as Node3D).scale = Vector3.ONE * (1.0 - f)
					(n as Node3D).visible = f < 1.0

	## ¿Está parado? (la prueba lo lee)
	func parado() -> bool:
		return _parado

	## El proyectil se ha parado (lo llama `_process` al verlo inactivo, o `VfxElemento3D` si el HechizoVivo se libera en ese mismo cuadro y no hay otro `_process`).
	## Fuego (FasesFuego3D): chocó (golpe, muro, suelo) → EXPLOSIÓN en el punto; se agotó (alcance, tiempo, frenado) → FIN, fogonazo pequeño y humo. Una sola vez.
	func al_pararse(hv: Object) -> void:
		if _avisado or (hv != null and is_instance_valid(hv) and bool(hv.get("activo"))):
			return                       # ya hecho, o el HechizoVivo se va con el proyectil todavía vivo (fin de nivel): sin explosión
		_avisado = true
		if elemento == "tierra" or elemento == "viento" or (elemento == "hielo" and VfxHielo.activo()):      # assets elementos: el hielo con modelos también se rompe al chocar
			_impacto_materia(hv)
			return
		if not FasesFuego3D.aplica(elemento):
			return
		# El fuego que se para (aunque el HechizoVivo se quede por `permanencia`) deja de dibujar su bola: la explosión / el fin ya la sustituyen, y una bola ardiendo
		# pegada al muñeco después del choque era justo el «fogonazo del final» que sobraba (Pablo, 19:53).
		visible = false
		if mundo == null or not is_instance_valid(mundo) or not is_inside_tree():
			return
		var pos: Vector3 = global_position
		var motivo: String = String(hv.get("motivo_fin")) if hv != null and is_instance_valid(hv) else ""
		if ["golpe", "muro", "suelo"].has(motivo):
			FasesFuego3D.impacto(mundo, pos, esc, _suelo_bajo(pos))
		else:
			FasesFuego3D.desvanecer(mundo, pos, esc)

	## Y del suelo bajo `pos` (rayo hacia abajo), o NAN si no hay mundo físico / suelo.
	func _suelo_bajo(pos: Vector3) -> float:
		var w: World3D = get_world_3d()
		if w != null:
			var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.3, pos + Vector3.DOWN * 4.0)
			var r: Dictionary = w.direct_space_state.intersect_ray(q)
			if not r.is_empty():
				return (r["position"] as Vector3).y
		return NAN

	## Tierra y viento (21/10): al CHOCAR (golpe, muro, suelo) el cuerpo se va —el terrón se rompe en cascotes que caen y se quedan, las cintas se abren en un
	## remolino— y se oculta lo que volaba. Si solo se agota (alcance, tiempo, frenado) se queda como estaba (la permanencia): no hay impacto que contar.
	func _impacto_materia(hv: Object) -> void:
		if mundo == null or not is_instance_valid(mundo) or not is_inside_tree():
			return
		var motivo: String = String(hv.get("motivo_fin")) if hv != null and is_instance_valid(hv) else ""
		if not ["golpe", "muro", "suelo"].has(motivo):
			return
		var pos: Vector3 = global_position
		visible = false
		if elemento == "tierra":
			VfxTierra.impacto(mundo, pos, esc, _suelo_bajo(pos))
		elif elemento == "hielo":
			VfxHielo.impacto(mundo, pos, esc, _suelo_bajo(pos))      # assets elementos: racimo que brota y pinchos de escarcha
		else:
			VfxViento.remolino(mundo, pos, esc, _suelo_bajo(pos))


static func conectar(lanzador: Object, mundo: Node3D) -> VfxElemento3D:
	var v := VfxElemento3D.new()
	v.name = "VfxElemento3D"
	v._mundo = mundo
	v._lanzador = lanzador
	mundo.add_child(v)
	if lanzador != null and lanzador.has_signal("hechizo_v2"):
		lanzador.connect("hechizo_v2", v._en_hechizo)
	if lanzador is Node:
		(lanzador as Node).child_entered_tree.connect(v._en_nodo)
	# ajustes VFX: el hielo del agua se rompe (Lanzador3D._hielo_cambio → Mundo3D.impacto «hielo_roto») → placa rota. Mismo camino en maqueta y lab.
	if Mundo3D.actual != null and is_instance_valid(Mundo3D.actual) and not Mundo3D.actual.impacto.is_connected(v._en_impacto_mundo):
		Mundo3D.actual.impacto.connect(v._en_impacto_mundo)
	return v


## Avisos de `Mundo3D.impacto` que dibuja este nodo: «hielo_roto» (punto = centro de la casilla a la altura del agua, radio = tamaño de casilla).
func _en_impacto_mundo(punto: Vector3, elemento: String, radio: float) -> void:
	if elemento == "hielo_roto":
		placa_rota(punto, radio)


## La placa helada de una casilla se rompe: 4 trozos que se separan, se ladean y se hunden (VfxHielo.placa_rota). Devuelve la raíz o null.
func placa_rota(punto: Vector3, tam_casilla: float = 0.0) -> Node3D:
	if not encendido or _mundo == null or not is_instance_valid(_mundo) or not VfxHielo.activo():
		return null
	var lado: float = tam_casilla if tam_casilla > 0.1 else casilla
	_placas_n += 1
	return VfxHielo.placa_rota(_mundo, punto, lado / 2.2)      # el GLB mide 2,2 u: a la casilla de 2,3 le toca ×1,045


## Para la medida y las pruebas: cuántos efectos ha montado y qué ha recibido por última vez.
func resumen() -> String:
	return "%d proy · %d vol · vivos %d%s" % [_proyectiles_n, _volumenes_n, _vivos, (" · " + _log) if _log != "" else ""]


func vivos() -> int:
	return _vivos


func proyectiles() -> int:
	return _proyectiles_n


func volumenes() -> int:
	return _volumenes_n


## Placas de hielo rotas dibujadas (la prueba lo lee).
func placas() -> int:
	return _placas_n


## Haces (ᛁ `linea`) dibujados (la prueba lo lee).
func haces() -> int:
	return _haces_n


## --- Entradas ---

func _en_nodo(n: Node) -> void:
	if not (n is HechizoVivo):
		return
	_ultimo = weakref(n)                   # se apunta aunque esté apagado: `hechizo_v2` lo busca
	if not encendido:
		return
	# `h` se asigna en `preparar`, antes de añadirse; la velocidad y la dirección (`v`) se fijan después, en `_iniciar_proyectil`: por eso se dibuja diferido.
	var hv := n as HechizoVivo
	if hv.h != null and hv.h.velocidad > 0.0:
		_dibujar_proyectil.call_deferred(weakref(hv))


func _en_hechizo(estado: String, elemento: String, g: Dictionary, origen: Vector3, dir: Vector3, props: Dictionary) -> void:
	var hv: HechizoVivo = null
	if _ultimo != null:
		hv = _ultimo.get_ref() as HechizoVivo
	if traza:
		print("[VfxElemento3D] hechizo_v2 %s/%s forma=%s celdas=%d viaja=%s props=%s" % [estado, elemento, str(hv.h.forma) if hv != null and hv.h != null else "?",
			(g.get("celdas", []) as Array).size(), str(g.get("viaja", false)), str(props.keys())])
	_log = "%s/%s" % [estado, elemento]
	if not encendido or _vivos >= MAX_VIVOS or _mundo == null or not is_instance_valid(_mundo):
		return
	_volumenes_n += 1
	var raiz := _raiz_para(hv)
	var el: String = _nombre_elemento(elemento)
	var r_u: float = maxf(float(g.get("x", Sigils.RADIO_BASE_V2)), float(g.get("z", Sigils.RADIO_BASE_V2))) * casilla
	var alto_u: float = float(g.get("y", Sigils.RADIO_BASE_V2)) * casilla
	var vida: float = clampf(maxf(float(g.get("vida_total", 0.0)), float(g.get("persiste", 0.0))), VIDA_MIN, VIDA_MAX)
	var evs: Array = g.get("eventos", []) as Array
	var sitios: Array = []
	for e in evs:
		if sitios.size() >= 4:
			break
		sitios.append((e as Dictionary).get("pos", origen))
	if sitios.is_empty():
		sitios.append(origen)
	var suelo_y: float = float(g.get("suelo", origen.y))
	if g.has("haz"):
		# RAYO (21/10): ᛁ `linea` + elemento. No es un volumen: es UN haz de la mano a la punta, con el dibujo de su elemento (`haz`).
		var hz: Dictionary = g["haz"] as Dictionary
		haz(el, hz["desde"] as Vector3, hz["hasta"] as Vector3, vida, float(hz.get("ancho", HAZ_ANCHO_REF_U)), suelo_y, raiz)
		_vigilar(raiz, hv, vida)
		return
	var forma: String = "barrera" if props.has("solidez") else ("pulso" if props.has("crece") else "esfera")
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z)
	d = d.normalized() if d.length() > 0.01 else Vector3.RIGHT
	for s in sitios:
		# `pos` de un evento es un Vector2 (x, z del mundo); un lanzador de mentira puede dar un Vector3
		var pie: Vector3 = Vector3(origen.x, suelo_y, origen.z)
		if s is Vector2:
			pie = Vector3((s as Vector2).x, suelo_y, (s as Vector2).y)
		elif s is Vector3:
			pie = Vector3((s as Vector3).x, suelo_y, (s as Vector3).z)
		_volumen(raiz, el, forma, pie, d, r_u, alto_u, vida, bool(g.get("viaja", false)))
	_vigilar(raiz, hv, vida)


func _dibujar_proyectil(ref: WeakRef) -> void:
	var hv: HechizoVivo = ref.get_ref() as HechizoVivo
	if hv == null or not is_instance_valid(hv) or not hv.is_inside_tree() or hv.h == null:
		return
	if _vivos >= MAX_VIVOS:
		return
	_proyectiles_n += 1
	var el: String = _nombre_elemento(hv.elemento)
	var r_u: float = maxf(hv.h.semiejes_vuelo.x, hv.h.semiejes_vuelo.z) * casilla      # lo que se ve volar y choca: Hechizo.ESCALA_PROYECTIL
	var r_impacto_u: float = maxf(hv.h.semieje_x, hv.h.semieje_z) * casilla            # el impacto (explosión, fin) NO se encoge: mide lo de siempre
	var vel: float = maxf(hv.v.length(), hv.h.velocidad * casilla)
	var d: Vector3 = hv.v.normalized() if hv.v.length() > 0.01 else Vector3.RIGHT
	_log = "proyectil %s" % el
	if traza:
		print("[VfxElemento3D] proyectil %s forma=%s velocidad=%.1f dir=%s" % [el, str(hv.h.forma), vel, str(d)])
	var seg := Proyectil.new()
	seg.name = "VfxElementoProyectil"
	seg.hv_ref = weakref(hv)
	seg.elemento = el
	seg.mundo = _mundo
	seg.esc = clampf(r_impacto_u / 0.45, ESCALA_VOL_MIN, ESCALA_VOL_MAX)
	# Fuego: nace del tamaño de la bola que ya tenía en la mano (continuidad: es la MISMA bola); el resto de elementos, de PROYECTIL_ESCALA_INICIAL.
	seg.escala_ini = FasesFuego3D.escala_inicial_proyectil(clampf(r_u, 0.3 * FACTOR_BOLA_MIN, 0.3 * FACTOR_BOLA_MAX), PROYECTIL_ESCALA_INICIAL) if el == "fuego" else PROYECTIL_ESCALA_INICIAL
	seg.scale = Vector3.ONE * seg.escala_ini      # nace pequeño (el primer fotograma ya lo es, sin parpadeo a tamaño completo)
	hv.add_child(seg)                      # sin top_level: se mueve con el HechizoVivo (su global_position es la del proyectil)
	_vivos += 1
	seg.tree_exited.connect(_menos_uno)
	_con_elemento(el, _pieza_proyectil.bind(el, seg, d, r_u, vel))
	seg.cola = _recoger_cola(seg, el)
	if hv.h.gravedad > 0.0:
		seg.seguir_direccion(d)      # el agua sale en arco: sus cintas siguen a la velocidad (el fuego, sin gravedad, no entra)
	hv.tree_exiting.connect(seg.al_pararse.bind(hv), CONNECT_ONE_SHOT)      # antes de `_soltar_al_irse`: si el HechizoVivo se libera en el mismo cuadro en que se para, el impacto no se pierde
	_soltar_al_irse(seg, hv, 0.35)


## Lo que se monta en un proyectil según el elemento (se llama con `VfxKit3D.elemento` ya puesto, vía `_con_elemento`).
func _pieza_proyectil(el: String, seg: Node3D, d: Vector3, r_u: float, vel: float) -> void:
	if el == "hielo" and VfxHielo.proyectil_con_esquirla():      # la esquirla de Meshy solo si `VfxHielo.proyectil_esquirla = true`; por defecto, el cometa del kit
		VfxHielo.proyectil(seg, d, r_u)
		return
	match el:
		"tierra":
			VfxTierra.proyectil(seg, d, r_u)       # un terrón facetado que rueda (21/10; antes cinco cajas que orbitaban)
		"viento":
			VfxViento.proyectil(seg, d, r_u)       # cintas en espiral y hojas arrastradas (antes cuatro aros)
		_:
			VfxKit3D.bola(seg, d, clampf(r_u / 0.3, FACTOR_BOLA_MIN, FACTOR_BOLA_MAX), 1.0, vel)
			if el == "fuego":
				FasesFuego3D.colorear_bola(seg)      # el mismo degradado que la bola de la mano (carga) y el brillo del impacto


## Lo que se monta en un volumen (esfera, pulso, barrera) según el elemento.
func _pieza_volumen(el: String, raiz: Node3D, forma: String, pie: Vector3, d: Vector3, r_u: float, alto_u: float, vida: float, viaja: bool) -> void:
	var esc: float = clampf(r_u / 0.45, ESCALA_VOL_MIN, ESCALA_VOL_MAX)
	if el == "tierra":
		_tierra_cae(raiz, pie, r_u, alto_u, vida, forma)
		return
	if el == "viento":
		VfxViento.torbellino(_nodo_en(raiz, pie), d if viaja else Vector3.UP, r_u, alto_u, maxf(vida, 1.0))
		return
	if el == "hielo" and VfxHielo.activo():      # assets elementos: racimos de hielo que brotan (barrera, pulso, esfera) con unos copos
		VfxHielo.emerger(raiz, pie, r_u, alto_u, vida, forma, esc)
		VfxKit3D.particulas(raiz, pie + Vector3(0.0, 0.15, 0.0), 12, 1.2, 0.1 * esc, 0.4, false, false, maxf(r_u, 0.5), -0.3, Vector3.UP, 90.0)
		return
	if forma == "pulso":
		VfxKit3D.onda(raiz, pie + Vector3(0.0, 0.1, 0.0), r_u * 4.0, vida, esc)
	elif forma == "barrera":
		VfxKit3D.cupula(raiz, pie, r_u * 1.6, vida, esc)
	else:
		VfxKit3D.impacto(raiz, pie, pie.y, esc, vida if el == "fuego" else 0.0)
		if el == "agua":
			if _fx() != null:
				_fx().salpicadura(pie, esc)
			VfxKit3D.charco(raiz, pie, r_u * 1.4, 1.0, vida)


## --- Haz (ᛁ `linea` + elemento, 21/10: «rayo de X») ---

## Dibuja el haz de un elemento de `desde` (la mano) a `hasta` (la punta, a ras de suelo), de `vida` s, con `ancho_u` de grosor en la punta y `suelo` = y del suelo bajo la punta. Cuelga de `raiz`
## (o de un efecto nuevo del mundo) en un nodo `Haz_<elemento>`; lo que el elemento deja en el suelo (impacto, escarcha, pinchos) cuelga de ese nodo. Cada elemento dibuja el suyo:
##   fuego → `VfxKit3D.haz` (el lanzallamas) · agua → `VfxAgua.chorro` (cintas y gotas) · tierra → `VfxTierra.fila_pinchos` (pinchos que brotan en secuencia) · viento → `VfxViento.corriente`
##   (cintas rectas con hojas) · rayo → `VfxRayo.descarga` (descarga quebrada) · hielo → `VfxHielo.rayo` (haz de cristal con esquirlas y escarcha). Devuelve el nodo.
func haz(el: String, desde: Vector3, hasta: Vector3, vida: float, ancho_u: float, suelo: float, raiz: Node3D = null) -> Node3D:
	if _mundo == null or not is_instance_valid(_mundo):
		return null
	var padre: Node3D = raiz if raiz != null and is_instance_valid(raiz) else _raiz_para(null)
	var nodo := Node3D.new()
	nodo.name = "Haz_" + el
	padre.add_child(nodo)
	_haces_n += 1
	var esc: float = clampf(ancho_u / HAZ_ANCHO_REF_U, HAZ_ESC_MIN, HAZ_ESC_MAX)
	_con_elemento(el, _pieza_haz.bind(el, nodo, desde, hasta, maxf(vida, 0.3), esc, suelo))
	return nodo


func _pieza_haz(el: String, nodo: Node3D, desde: Vector3, hasta: Vector3, vida: float, esc: float, suelo: float) -> void:
	match el:
		"hielo":
			if VfxHielo.activo():
				VfxHielo.rayo(nodo, desde, hasta, vida, esc, suelo)
			else:
				VfxKit3D.haz(nodo, desde, hasta, vida, esc, suelo)
		"tierra":
			VfxTierra.fila_pinchos(nodo, desde, hasta, vida, esc, suelo)
		"viento":
			VfxViento.corriente(nodo, desde, hasta, vida, esc)
		"agua":
			VfxAgua.chorro(nodo, desde, hasta, vida, esc, suelo)
		"rayo":
			VfxRayo.descarga(nodo, desde, hasta, vida, esc)
		_:
			VfxKit3D.haz(nodo, desde, hasta, vida, esc, suelo)


## --- Volúmenes (esfera, pulso, barrera) ---

func _volumen(raiz: Node3D, el: String, forma: String, pie: Vector3, d: Vector3, r_u: float, alto_u: float, vida: float, viaja: bool) -> void:
	var esc: float = clampf(r_u / 0.45, ESCALA_VOL_MIN, ESCALA_VOL_MAX)
	_con_elemento(el, _pieza_volumen.bind(el, raiz, forma, pie, d, r_u, alto_u, vida, viaja))


## --- Tierra y viento: el dibujo vive en `presentacion/vfx_elementos/tierra.gd` y `viento.gd` (VfxTierra / VfxViento) ---
## Aquí solo queda lo que depende del volumen: la grieta del suelo (Vfx3D) y el polvo de fondo de la tierra quieta.

func _tierra_cae(raiz: Node3D, pie: Vector3, r_u: float, alto_u: float, vida: float, forma: String) -> void:
	var esc: float = clampf(r_u / 0.45, ESCALA_VOL_MIN, ESCALA_VOL_MAX)
	var anillo: float = r_u * (1.3 if forma != "pulso" else 3.0)
	# bloques facetados que EMERGEN del suelo de abajo arriba (VfxTierra.emerger), con su polvo
	VfxTierra.emerger(raiz, pie, r_u, alto_u, vida, forma, esc)
	VfxKit3D.particulas(raiz, pie + Vector3(0.0, 0.15, 0.0), 16, 1.3, 0.2 * esc, 0.7, false, false, anillo * 0.6, -0.15, Vector3.UP, 75.0)
	var fx: Vfx3D = _fx()
	if fx != null:
		fx.grietas(pie, maxf(anillo * 1.5, 0.9), maxf(vida, 1.5))


## --- Utilidades ---

## Qué del dibujo de un proyectil son «líneas de movimiento» (solo se ven yendo): todas las partículas (estela de brasas, chispas alargadas, jirones, polvo) y, en el fuego y
## el agua, las mallas que no son esferas (los conos de la cola de cometa y las cintas de la burbuja). El cuerpo —esferas del fuego y del agua, terrones de tierra, aros de
## viento— se queda. Se reconoce por el tipo de malla, sin tocar el kit: así un elemento nuevo que use `VfxKit3D.bola` cumple la regla sin hacer nada.
func _recoger_cola(raiz: Node, el: String) -> Array:
	var lista: Array = []
	var mallas_cola: bool = el != "tierra" and el != "viento" and not (el == "hielo" and VfxHielo.proyectil_con_esquirla())      # la esquirla (si se usa) es el cuerpo, no cola
	for n in raiz.find_children("*", "", true, false):
		if n is GPUParticles3D:
			lista.append(n)
		elif mallas_cola and n is MeshInstance3D and not ((n as MeshInstance3D).mesh is SphereMesh):
			lista.append(n)
	return lista


## Pone `VfxKit3D.elemento` a `el` mientras dura `hacer` y lo restituye: es un estado global y otros efectos (la maqueta, Vfx3D) cuentan con el suyo.
func _con_elemento(el: String, hacer: Callable) -> void:
	var antes: String = VfxKit3D.elemento
	VfxKit3D.elemento = el
	hacer.call()
	VfxKit3D.elemento = antes


func _nombre_elemento(e: String) -> String:
	return e if Vfx3D.ELEMENTOS.has(e) else "fuego"


func _fx() -> Vfx3D:
	if _lanzador != null and is_instance_valid(_lanzador) and "fx" in _lanzador:
		return _lanzador.get("fx") as Vfx3D
	return null


## Raíz del efecto de un volumen: cuelga del HechizoVivo (si lo hay) y es top_level para ignorar su transformación.
func _raiz_para(hv: HechizoVivo) -> Node3D:
	var r := Seguidor.new()
	r.name = "VfxElemento"
	var padre: Node = hv if hv != null and is_instance_valid(hv) and hv.is_inside_tree() else _mundo
	padre.add_child(r)
	r.top_level = true
	_vivos += 1
	r.tree_exited.connect(_menos_uno)
	return r


func _menos_uno() -> void:
	_vivos = maxi(_vivos - 1, 0)


func _nodo_en(raiz: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	raiz.add_child(n)
	n.position = pos
	return n


## Que el dibujo viva lo que pida la receta y se libere solo; si el HechizoVivo se va antes, el dibujo se suelta al mundo y se apaga.
func _vigilar(raiz: Node3D, hv: HechizoVivo, vida: float) -> void:
	_mundo.get_tree().create_timer(vida + 0.8, false).timeout.connect(_borrar.bind(weakref(raiz)))
	if hv != null and is_instance_valid(hv):
		_soltar_al_irse(raiz, hv, 0.5)


## Referencia DÉBIL, no una lambda que capture el nodo: si el nodo muere antes, la lambda da error en el motor (mismo motivo que `Lanzador3D._borrar_si_vive`).
func _borrar(ref: WeakRef) -> void:
	var n: Object = ref.get_ref()
	if n != null and is_instance_valid(n):
		(n as Node).queue_free()


func _soltar_al_irse(nodo: Node3D, hv: HechizoVivo, fundido: float) -> void:
	hv.tree_exiting.connect(_soltar.bind(weakref(nodo), fundido), CONNECT_ONE_SHOT)


## El HechizoVivo se va: el dibujo pasa a colgar del mundo, donde estaba, y se apaga en `fundido` s. Reparent INMEDIATO (no diferido): al acabar el
## `tree_exiting` el HechizoVivo se libera con todos sus hijos y un reparent diferido llegaría a un nodo ya muerto.
func _soltar(ref: WeakRef, fundido: float) -> void:
	var nodo: Node3D = ref.get_ref() as Node3D
	if nodo == null or not is_instance_valid(nodo) or _mundo == null or not is_instance_valid(_mundo):
		return
	var donde: Transform3D = (nodo as Seguidor).ultima if nodo is Seguidor else Transform3D.IDENTITY
	nodo.reparent(_mundo, false)
	if nodo is Seguidor and not nodo.top_level:
		nodo.global_transform = donde
	_mundo.get_tree().create_timer(fundido, false).timeout.connect(_borrar.bind(weakref(nodo)))
