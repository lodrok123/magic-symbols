## Terreno3D · el suelo del mundo, SIN nodos (M1 de ARQUITECTURA_MODULAR.md, 13/10).
##
## Qué es: lo que antes vivía como estáticos de Lanzador3D y que responde a «¿qué hay en esta casilla?»: de qué casilla es un
## punto, si hay agua o hielo, a qué altura pisa quien está en ella, si se puede estar de pie, si se ven dos puntos, qué
## casillas son sólidas. Más el estado que eso necesita (mundo, tamaño de casilla, alturas, simulación del agua).
##
## Por qué aparte: jugador, goblins, surtidor, rayo y flotador preguntaban al terreno a través de Lanzador3D, que es
## MAGIA. Así el suelo dependía de los hechizos y no se podía probar sin ellos. Terreno3D está en la capa Mundo: no conoce
## hechizos, y por eso lo único «mágico» que necesitó (soltar a los goblins presos en hielo cuando un muro solidifica una
## casilla) entra por un Callable (`al_solidificar`) que pone Lanzador3D al configurar.
##
## Lanzador3D conserva un reenvío de cada función (`## REENVÍO M1`) y dos espejos de variable (mundo_s, agua_sim) para los
## archivos que no son del Juego. Los cuerpos de las funciones son los de siempre, sin cambios (salvo lo dicho arriba).
class_name Terreno3D
extends RefCounted

## Alto de un nivel, en unidades. Es el ALTO de prueba_test2.gd (S * 0,45); configurar() lo lee de allí.
## Es `static var` y no `const` para seguir al mundo: configurar() lo iguala al ALTO de prueba_test2.gd (hoy S*0,45). Para probar
## niveles de media casilla basta con que el Pipeline ponga ALTO = S * 0.5 allí; aquí no hay que tocar nada.
static var ALTO_NIVEL: float = 2.3 * 0.45

## Mismo valor que Terreno3D.CAPA_SOLIDO (que ahora apunta aquí): la capa de la colisión real de las piezas del nivel.
const CAPA_SOLIDO: int = 1 << 10

## Quien debe soltar a los presos cuando un muro hace sólida una casilla (FuenteNodos.bloquear_completa). Lo pone Terreno3D.configurar:
## el hielo y los goblins presos son magia, y el terreno no puede depender hacia arriba de ella.
static var al_solidificar: Callable = Callable()

## Los estados del suelo (helada, electrificada…). Dueño del dato (M2). Existe siempre, haya o no un Mundo3D; Mundo3D se limita a
## escuchar su señal `cambio` y reenviarla como `casilla_cambio`.
static var estados: EstadosSuelo3D = EstadosSuelo3D.new()


## ¿Tiene la casilla el ESTADO «helada»? Es el dato que leen las reglas de puzle y la imagen del suelo. Vale tanto para el hielo sobre agua
## (que se pisa) como para la escarcha del suelo (dos aguas, un hielo sobre tierra). Para saber si hay hielo en el que PISAR, resbalar o
## que cubra el agua, preguntar a `hielo_fisico`.
static func helada(c: Vector2i) -> bool:
	return estados.tiene(c, EstadosSuelo3D.HELADA)


## ¿Hay hielo de verdad en la casilla (agua helada que se pisa)? Es `helada` MENOS la escarcha del suelo, que no cambia cómo se anda ni a qué
## altura se pisa (21/10: sin esta distinción, helar suelo con dos aguas lo habría hundido hasta la altura del agua y lo habría vuelto
## «no agua» para el rayo). Todo lo físico (pisable, y_pies, sobre_hielo, cubre_hielo, es_agua, cabe) pregunta aquí.
static func hielo_fisico(c: Vector2i) -> bool:
	return estados.tiene(c, EstadosSuelo3D.HELADA) and not estados.es_escarcha(c)


## Hiela o deshiela una casilla CON HIELO DE VERDAD (agua helada). Avisa por Mundo3D.casilla_cambio («hielo») solo si cambió algo.
## Si la casilla ya estaba helada como escarcha de suelo y ahora la hiela el agua (una charca que congela), deja de ser escarcha: el estado
## «helada» no cambia pero lo físico sí, así que se avisa a mano para que Caminos3D y la maqueta lo vean.
static func poner_helada(c: Vector2i, si: bool) -> void:
	var era_escarcha: bool = si and estados.es_escarcha(c)
	if era_escarcha:
		estados.quitar_escarcha(c)
	# C2 (3/11): sin caducidad PROPIA (dura = 0). El hielo de agua lo cuenta por trocitos `AguaSim3D` (con `DURA["helada"]` y el factor de zona) y avisa cuando se suelta; si el estado de la
	# casilla también corriese, dos relojes decidirían a la vez cuándo se funde el mismo hielo.
	if not estados.poner(c, EstadosSuelo3D.HELADA, si, 1.0, 0.0) and era_escarcha:
		estados.cambio.emit(c, EstadosSuelo3D.HELADA, true)


## Avisa a Mundo3D (si existe) de que algo de la casilla cambió.
static func _avisar(c: Vector2i, que: String) -> void:
	if Mundo3D.actual != null:
		Mundo3D.actual.casilla_cambio.emit(c, que)

## --- El mundo (lo fija configurar()) ---
static var mundo_s: Node3D = null
static var casilla: float = 2.3             ## S de prueba_test2.gd
static var alto_suelo: float = 2.3 * 0.45   ## ALTO: y de la cara de arriba de una casilla de tierra
static var alto_agua: float = 2.3 * 0.45 * 0.6

## Niveles de cada casilla por encima del suelo (tierra apilada, columnas, cornisas). Vector2i -> int.
static var alturas: Dictionary = {}
## Alturas FIJAS que pone el nivel (una cornisa de un nivel): Vector2i -> int. No caducan.
static var permanentes: Dictionary = {}
## 6/11 (entrada 422): las casillas cuya altura de `alturas` viene de la tierra TEMPORAL del Lanzador (bloques `BloqueTierra` y columnas de barrera;
## el hielo sólido y las cornisas fijas NO cuentan): Vector2i -> niveles. Solo lectura para el dibujo: cuando el TierraToy representa la tierra
## (`VfxToyJuego.usa_toy("tierra")`), la maqueta no pinta terrazas en estas casillas. La escribe `Lanzador3D._recalcular`; la lógica no la lee.
static var alturas_temporales: Dictionary = {}
static var plataformas_tierra: Dictionary = {}  ## Casilla → cota de la superficie pisable.
## Altura a la que se pisa una casilla de puente «b» cuando el puente NO es una losa a ras del agua (el tronco-puente: se anda sobre
## su cara de arriba, 0,35 u por encima de la orilla). Vector2i -> y. Sin entrada, la «b» de siempre (alto_agua + 0,12).
static var y_puentes: Dictionary = {}

## La simulación del nivel (null si no hay). La crea montar_agua_sim() al arrancar el Lanzador.
static var agua_sim: AguaSim3D = null
## Casillas del cauce seco («c») que el surtidor ya ha abierto (11.5). Hasta entonces el cauce es un foso SELLADO para la
## simulación: si no, el río se metería solo y el surtidor no haría falta.
static var cauces_abiertos: Dictionary = {}
## 16/10: casillas que CONDUCEN la electricidad sin ser agua (un NexoRayo3D mojado). Las escribe el objeto; las lee EmisorRayo3D por `conduce`.
static var conductores: Dictionary = {}

## Un hielo de al menos esta hondura (u) cuenta como sólido para proyectiles y miradas (no para andar).
const HIELO_COBERTURA: float = 0.5
## Hondura del lecho bajo una casilla «~» (u). Superficie = alto_agua, así que el agua tiene esta profundidad: más que
## UMBRAL_NADO (0,55) para que se nade, como hasta ahora.
const LECHO_AGUA: float = 0.9
const FONDO_CANAL: float = 0.11        ## el fondo del cajón de Canal3D sobre el suelo: el agua de un canal de ruinas empieza ahí, no en el lecho del río
## 24/10 (cascada de la Cueva, C2): canales de ruinas SOBRE UNA TERRAZA de roca. Casilla -> cuántas u sube el fondo del canal por encima del de siempre (`alto_suelo + FONDO_CANAL`).
## Lo declara la pieza `manantial` con `terraza=` (Puzle3D) y dibuja el bloque de roca; así la caída al pozo mide lo que la cortina de EoW y no una sola casilla de desnivel (la tierra
## levantada es presa para la simulación, así que no se puede hacer con `fijar_altura`). Se vacía al montar la simulación de agua de cada nivel.
static var elevacion_canal: Dictionary = {}


## y del fondo del cajón de un canal de ruinas en `c` (con su terraza, si la tiene).
static func fondo_canal_en(c: Vector2i) -> float:
	return alto_suelo + FONDO_CANAL + float(elevacion_canal.get(c, 0.0))

## CAUCE HONDO (22/10, Pablo: «que el jugador se caiga, y que tenga un desnivel; si no, no habrá sensación de profundidad»). Con el interruptor encendido el cauce seco
## (`c`) es un FOSO de verdad: su fondo está donde ya lo ponía la simulación de agua (`alto_agua − LECHO_AGUA`, el lecho del río), no a 0,1 u bajo el suelo. Se anda por
## ese fondo (`y_pies`), se entra CAYENDO (gravedad de Jugador3D) y se sale trepando el borde (la misma regla que el pozo de una cuenca abierta). Apagado = el cauce de antes
## (se pisa a ras de suelo; el fondo de la simulación queda 0,9 u más abajo, tapado por el bloque del lecho). Lo enciende la maqueta (`PruebaTest2.cauce_hondo`).
static var cauce_hondo: bool = false
## Casillas `c` que NO son foso aunque `cauce_hondo` esté encendido: las ocupa una pieza que se apoya en el suelo (la compuerta, `Compuerta3D.preparar`): cerrada es un dique a ras, y al
## abrirse ya es cuenca (`es_cuenca`). Sin esto el hielo de los puzles de fuego (F5) quedaba 0,94 u por encima de los pies de quien lo apunta. `montar_agua_sim` la vacía.
static var cauces_a_ras: Dictionary = {}
## Profundidad del foso (u): del suelo al fondo. Con los valores de la maqueta (ALTO 1,035; ALTO_AGUA 0,995) son 0,94 u, el 91 % de un nivel de terraza (ALTO_NIVEL). La recalcula `configurar`.
static var PROF_CAUCE: float = 2.3 * 0.45 - (2.3 * 0.45 * 0.6 - 0.9)


## y del fondo del cauce hondo (= el fondo de la simulación para una `c`).
static func fondo_cauce() -> float:
	return alto_agua - LECHO_AGUA


## Enciende o apaga el cauce hondo. Las rutas de los enemigos se rehacen (un foso no se rutea, un cauce a ras sí).
static func fijar_cauce_hondo(si: bool) -> void:
	if cauce_hondo == si:
		return
	cauce_hondo = si
	Caminos3D.reiniciar()


## ¿Es un cauce seco `c` con el interruptor del foso encendido? (la letra manda: al llenarse y pasar a «~» deja de serlo y se nada como en el río.)
static func es_cauce_hondo(c: Vector2i) -> bool:
	return cauce_hondo and hay_mundo() and letra_de(c) == "c" and not cauces_a_ras.has(c)


## ¿El suelo de esta casilla es el fondo de un foso? Una cuenca abierta a la simulación o un cauce hondo (seco o con agua en curso, mientras siga siendo `c`).
static func es_hueco_cauce(c: Vector2i) -> bool:
	return es_cuenca(c) or es_cauce_hondo(c)

## =====================================================================================================
##  FUENTE DE SOLIDEZ (6.10, camino A: hornear el mapa a un .tscn)
##  Hoy la pregunta «¿está bloqueada esta casilla?» se contestaba leyendo `_bloqueadas` de PruebaTest2 en una docena de
##  sitios. Ahora TODOS preguntan a `bloqueada(c)` y esa función delega en una FUENTE intercambiable:
##    · FuenteCasillas (por defecto): lo de siempre, `_bloqueadas` + huellas calculadas. Comportamiento IDÉNTICO al anterior.
##    · FuenteNodos: la solidez sale de la COLISIÓN REAL de las piezas del nivel (StaticBody3D en la capa CAPA_SOLIDO,
##      o el grupo "bloquea"). Se activa con `Terreno3D.activar_fuente_nodos(mundo)` cuando exista el Nivel_X.tscn.
##  Por qué una interfaz y no tocar cada sitio: el día que el .tscn mande, cambia UNA línea (la fuente) y no una docena de
##  consultas repartidas por el lanzador, el jugador y los goblins.
## =====================================================================================================
class FuenteSolidez extends RefCounted:
	## ¿Hay algo sólido en la casilla `c`? (el agua y las alturas de tierra NO cuentan aquí: eso sigue en alturas/letras)
	func bloquea(_c: Vector2i) -> bool:
		return false
	## Marca / quita un bloqueo en tiempo de juego (tierra que se solidifica, hielo que se derrite, barrera de fuego).
	## `de` (12/11, opcional): el nodo que la bloquea, si no tiene propiedad `celda` (una pieza de varias casillas): la jugadora chocará con su forma.
	func bloquear(_c: Vector2i, _de: Node3D = null) -> void:
		pass
	func liberar(_c: Vector2i) -> void:
		pass
	## 12/10 (Pablo): un MURO bloquea la casilla ENTERA, siempre (no se roza ni se cuela por un hueco de su forma).
	func bloquear_completa(c: Vector2i) -> void:
		bloquear(c)
	## ¿Se puede ROZAR la casilla (su forma real es menor que la casilla)? Solo el jugador afina; hechizos y goblins no.
	## `con_objetos` (12/11): cuenta también la forma de los OBJETOS de juego que bloquean su casilla (rompibles, barriles, bloques, setas, puertas…). Solo la jugadora lo pide.
	func es_parcial(_c: Vector2i, _con_objetos: bool = false) -> bool:
		return false
	## Con casilla parcial: ¿toca el punto `p` (suelo) lo que de verdad hay ahí?
	func choca_punto(_c: Vector2i, _p: Vector3) -> bool:
		return true


	## ---- 12/11 (Pablo: «las colisiones MUY próximas al tamaño del asset; ni muros invisibles») · la forma de los OBJETOS que bloquean su casilla ----
	## Un rompible, un barril, un bloque, una seta o una puerta llaman a `Terreno3D.bloquear_celda(su casilla)`: para hechizos, enemigos y rutas eso sigue siendo la
	## casilla entera (2,3 u), pero la JUGADORA chocaba también con la casilla entera aunque el modelo midiera 0,6 u: un cubo de pared invisible alrededor de cada
	## objeto, mientras las piezas de decorado (árboles, rocas) chocaban pegadas a su modelo. Ahora, en una casilla de `extras`, la jugadora choca con el CONTORNO DEL
	## MODELO del objeto que la ocupa: el casco convexo, en planta, de sus mallas visibles a la altura del cuerpo (FORMA_Y_MIN..FORMA_Y_MAX sobre el suelo).
	## El objeto no tiene que registrarse: es cualquier Node3D del mundo con una propiedad `celda` (Vector2i) igual a la casilla (todos los objetos de `objetos/` y
	## los de `puzle.gd` la tienen). Se busca la primera vez que la jugadora pregunta por la casilla y se reintenta unas pocas veces (un bloque empujado reserva su
	## destino antes de llegar). Si se mueve, la forma lo sigue; si deja la casilla o desaparece, se vuelve a buscar. Sin objeto con modelo, la casilla entera.
	## Quien bloquea por un nodo SIN `celda` (una pieza de arte que ocupa varias casillas: `Puzle3D._bloquear_huella`) lo dice: `bloquear(c, nodo)`. Si el nodo
	## trae cascos de colisión medidos (ConvexPolygonShape3D de `ColisionPieza`), se usan esos (un polígono por casco: respeta huecos); si no, el casco de sus mallas.
	## Vive en la clase base: vale igual para la solidez por nodos (niveles .tscn) y por casillas (mapas de letras).
	const RADIO_CUERPO: float = 0.25                 ## el cuerpo de la jugadora (ver FuenteNodos)
	const FORMA_Y_MIN: float = 0.12
	const FORMA_Y_MAX: float = 1.6
	const FORMA_ESPERAS: Array = [0, 10, 30, 90, 240]   ## fotogramas de física entre intentos de encontrar el objeto de una casilla recién bloqueada
	var formas: Dictionary = {}                      ## Vector2i -> Array de {"ref": WeakRef, "tf": Transform3D, "local": PackedVector3Array, "poli": PackedVector2Array}
	var _pend: Dictionary = {}                       ## Vector2i -> [intentos, fotograma de física del próximo intento]
	var _sin_forma: Dictionary = {}                  ## Vector2i -> true: ya se buscó y no hay objeto con modelo (hasta el próximo bloquear/liberar)
	var _objetos: Array = []                         ## WeakRef de todos los Node3D con `celda` vistos en el último recorrido del mundo
	var _fijos: Dictionary = {}                      ## Vector2i -> Array de WeakRef: nodos que dijeron «esta casilla la bloqueo yo» (`bloquear(c, nodo)`)

	## El nodo bajo el que se buscan los objetos.
	func _raiz_formas() -> Node:
		return Terreno3D.mundo_s

	## Hay que volver a buscar la forma de `c` (la acaban de bloquear). `de`: el nodo que la bloquea, si lo dice.
	func _forma_pendiente(c: Vector2i, de: Node3D = null) -> void:
		formas.erase(c)
		_sin_forma.erase(c)
		_pend[c] = [0, 0]
		if de != null:
			if not _fijos.has(c):
				_fijos[c] = []
			(_fijos[c] as Array).append(weakref(de))

	func _olvidar_forma(c: Vector2i) -> void:
		formas.erase(c)
		_pend.erase(c)
		_sin_forma.erase(c)
		_fijos.erase(c)

	func _formas_de(c: Vector2i) -> Array:
		if formas.has(c):
			var vale: bool = true
			for f in (formas[c] as Array):
				var fd: Dictionary = f
				var n: Node3D = (fd["ref"] as WeakRef).get_ref() as Node3D
				if n == null or not n.is_inside_tree() or (not bool(fd["fijo"]) and n.get("celda") != c):
					vale = false
					break
				if n.global_transform != (fd["tf"] as Transform3D):
					fd["tf"] = n.global_transform
					fd["poli"] = _poligono(fd["local"] as PackedVector3Array, n.global_transform)
			if vale:
				return formas[c]
			formas.erase(c)
			_pend[c] = [0, 0]
		if not _sin_forma.has(c):
			if not _pend.has(c):
				# bloqueada sin pasar por `bloquear` (el diccionario de la maqueta al cargar): lo que haya ya está puesto; un intento ahora y otro más tarde
				_pend[c] = [FORMA_ESPERAS.size() - 2, 0]
			if Engine.get_physics_frames() >= int((_pend[c] as Array)[1]):
				_resolver_formas()
		if not formas.has(c):
			# Los objetos YA conocidos se miran siempre (es barato): un bloque empujado reserva su destino al salir y no cambia su `celda` hasta llegar, segundos después;
			# sin esto la casilla de llegada se quedaba sin forma (entera) y la jugadora, que ya estaba dentro de ella, la cruzaba por dentro del bloque.
			for r in _objetos:
				var n2: Node3D = (r as WeakRef).get_ref() as Node3D
				if n2 != null and n2.is_inside_tree() and n2.get("celda") == c and n2.is_visible_in_tree():
					for f2 in _formas_de_nodo(n2, c, false):
						if not formas.has(c):
							formas[c] = []
						(formas[c] as Array).append(f2)
			if formas.has(c):
				_pend.erase(c)
				_sin_forma.erase(c)
		return formas.get(c, [])

	## Un solo recorrido del mundo resuelve todas las casillas pendientes que ya toquen.
	func _resolver_formas() -> void:
		var ahora: int = Engine.get_physics_frames()
		var toca: Dictionary = {}
		for c in _pend:
			if ahora >= int((_pend[c] as Array)[1]):
				toca[c] = true
		var raiz: Node = _raiz_formas()
		if toca.is_empty() or raiz == null or not is_instance_valid(raiz):
			return
		# los que se apuntaron a mano
		for c in toca:
			for r in (_fijos.get(c, []) as Array):
				var nf: Node3D = (r as WeakRef).get_ref() as Node3D
				if nf != null and nf.is_inside_tree() and nf.is_visible_in_tree():
					for f0 in _formas_de_nodo(nf, c, true):
						if not formas.has(c):
							formas[c] = []
						(formas[c] as Array).append(f0)
		_objetos.clear()
		var pila: Array = [raiz]
		while not pila.is_empty():
			var n: Node = pila.pop_back()
			if n is Node3D and "celda" in n and n.get("celda") is Vector2i:
				_objetos.append(weakref(n))
			if n is Node3D and "celda" in n and n.get("celda") is Vector2i and toca.has(n.get("celda")) and (n as Node3D).is_visible_in_tree():
				var cn: Vector2i = n.get("celda")
				for f in _formas_de_nodo(n as Node3D, cn, false):
					if not formas.has(cn):
						formas[cn] = []
					(formas[cn] as Array).append(f)
			pila.append_array(n.get_children())
		for c in toca:
			if formas.has(c):
				_pend.erase(c)
				continue
			var intentos: int = int((_pend[c] as Array)[0]) + 1
			if intentos >= FORMA_ESPERAS.size():
				_pend.erase(c)                           # nadie con modelo en esa casilla (agua, tierra, hielo…): entera hasta el próximo bloquear
				_sin_forma[c] = true
			else:
				_pend[c] = [intentos, ahora + int(FORMA_ESPERAS[intentos])]

	## Las formas de `n`: un polígono por cada casco de colisión medido que traiga; si no trae, el casco convexo en planta de sus mallas visibles a la altura del
	## cuerpo. Vacía si no tiene modelo ahí.
	func _formas_de_nodo(n: Node3D, c: Vector2i, fijo: bool) -> Array:
		var res: Array = []
		var inv_n: Transform3D = n.global_transform.affine_inverse()
		for h0 in n.find_children("*", "CollisionShape3D", true, false):
			var cs: CollisionShape3D = h0 as CollisionShape3D
			if not (cs.shape is ConvexPolygonShape3D) or cs.disabled:
				continue
			var pc := PackedVector2Array()
			for v in (cs.shape as ConvexPolygonShape3D).points:
				var w: Vector3 = cs.global_transform * v
				pc.append(Vector2(w.x, w.z))
			var casco_c: PackedVector2Array = Geometry2D.convex_hull(pc)
			if casco_c.size() < 4:
				continue
			var local_c := PackedVector3Array()
			for k in range(casco_c.size() - 1):
				local_c.append(inv_n * Vector3(casco_c[k].x, n.global_position.y, casco_c[k].y))
			res.append({"ref": weakref(n), "fijo": fijo, "tf": n.global_transform, "local": local_c, "poli": _poligono(local_c, n.global_transform)})
		if not res.is_empty():
			return res
		var suelo: float = Terreno3D.y_pies(c)
		var tris := PackedVector3Array()
		var pila: Array = [n]
		while not pila.is_empty():
			var h: Node = pila.pop_back()
			if h != n and "celda" in h and h.get("celda") is Vector2i and h.get("celda") != c:
				continue                                 # un hijo que es otro objeto, de otra casilla
			if h is MeshInstance3D and (h as MeshInstance3D).mesh != null and (h as MeshInstance3D).is_visible_in_tree() \
					and not ((h as MeshInstance3D).mesh is QuadMesh) and not ((h as MeshInstance3D).mesh is PlaneMesh):
				var gt: Transform3D = (h as MeshInstance3D).global_transform
				for v in (h as MeshInstance3D).mesh.get_faces():
					tris.append(gt * v)
			pila.append_array(h.get_children())
		var rec: PackedVector3Array = ColisionPieza._recortar(tris, suelo + FORMA_Y_MIN, suelo + FORMA_Y_MAX)
		if rec.size() < 3:
			return res
		# Lo bajo no es un obstáculo (una placa de presión, una losa, un nido comparten casilla con lo que de verdad bloquea): misma regla que las piezas,
		# `ColisionPieza.ALTO_MIN_SOLIDO`. Sin esto, al llegar un bloque a la casilla de una placa la «forma» era la placa entera y la jugadora quedaba dentro.
		var tope: float = -INF
		for v in rec:
			tope = maxf(tope, v.y)
		if tope - suelo <= ColisionPieza.ALTO_MIN_SOLIDO:
			return res
		var p2 := PackedVector2Array()
		for v in rec:
			p2.append(Vector2(v.x, v.z))
		var casco: PackedVector2Array = Geometry2D.convex_hull(p2)
		if casco.size() < 4:
			return res
		# El casco se guarda en el espacio del nodo: si el objeto se mueve o gira (un bloque empujado), el polígono se recalcula sin volver a leer las mallas.
		var inv: Transform3D = n.global_transform.affine_inverse()
		var local := PackedVector3Array()
		for k in range(casco.size() - 1):                # convex_hull repite el primer punto al final
			local.append(inv * Vector3(casco[k].x, n.global_position.y, casco[k].y))
		res.append({"ref": weakref(n), "fijo": fijo, "tf": n.global_transform, "local": local, "poli": _poligono(local, n.global_transform)})
		return res

	## ¿Toca el cuerpo de la jugadora, en `p`, alguna de las formas de objeto de `c`? -1 = no hay formas (casilla entera), 0 = no toca, 1 = toca.
	func _toca_formas(c: Vector2i, p: Vector3) -> int:
		var lista: Array = _formas_de(c)
		if lista.is_empty():
			return -1
		var p2 := Vector2(p.x, p.z)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for f in lista:
			var poli: PackedVector2Array = (f as Dictionary)["poli"]
			if _toca_poligono(p2, poli):
				return 1
			for v in poli:
				lo = lo.min(v)
				hi = hi.max(v)
		return 1 if _sellado(c, p2, lo, hi) else 0

	## Para las herramientas de medida (`prueba_colisiones_mapa`): ¿se choca en `p` SOLO por la regla de no colarse (no toca el modelo de ningún objeto de `c`)?
	func solo_sellado(c: Vector2i, p: Vector3) -> bool:
		var lista: Array = _formas_de(c)
		if lista.is_empty():
			return false
		var p2 := Vector2(p.x, p.z)
		for f in lista:
			if _toca_poligono(p2, (f as Dictionary)["poli"] as PackedVector2Array):
				return false
		return _toca_formas(c, p) == 1

	## ---- 12/11 · NO COLARSE: el hueco entre un objeto y el borde de su casilla solo se abre si no crea un paso que antes no existía ----
	## Los puzles son de rejilla: un bloque, un seto o una puerta CIERRAN su casilla aunque el modelo mida menos (un bloque de 1 u en un pasillo de 2,3 u). Si la jugadora
	## chocara solo con el contorno, se colaría entre el bloque y la pared. Regla: la casilla se parte en 8 zonas alrededor de la caja del objeto (4 lados y 4 esquinas) y
	## cada zona se abre solo si por ella no se unen dos casillas vecinas que no estuvieran ya unidas entre sí por el anillo de las 8 vecinas:
	##   · un LADO (p. ej. el norte) se abre si la vecina de ese lado está libre;
	##   · una ESQUINA se abre si sus dos vecinas de lado y la diagonal están libres.
	## (Los rincones sin salida, entre el objeto y una pared, también se cierran: apretando contra un bloque en un pasillo la jugadora resbalaba hacia ellos y lo rodeaba.)
	## Así, en campo abierto se rodea el objeto pegado a su modelo; en un pasillo, entre el objeto y la pared no se pasa (y eso sí se ve: no hay sitio «de casilla»).
	const _ANILLO: Array = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]   ## N, NE, E, SE, S, SO, O, NO

	## ¿Se anda por la vecina `v` de `c`? Estricto: en caso de duda, no (sellar de más es seguro; de menos abriría un paso).
	func _vecina_libre(v: Vector2i, c: Vector2i) -> bool:
		if not Terreno3D.en_mapa(v) or Terreno3D.es_vacio(v) or bloquea(v):
			return false
		var l: String = Terreno3D.letra_de(v)
		if l == "#" or (l == "~" and not Terreno3D.hielo_fisico(v)):
			return false
		return Terreno3D.altura_en(v) == Terreno3D.altura_en(c)

	func _sellado(c: Vector2i, p: Vector2, lo: Vector2, hi: Vector2) -> bool:
		# zona de `p` respecto a la caja del objeto: índice en _ANILLO (pares = lados, impares = esquinas)
		var dx: int = -1 if p.x < lo.x else (1 if p.x > hi.x else 0)
		var dz: int = -1 if p.y < lo.y else (1 if p.y > hi.y else 0)
		if dx == 0 and dz == 0:
			# dentro de la caja pero fuera del casco (un pico): cuenta el lado más cercano
			var d: Array = [p.y - lo.y, hi.x - p.x, hi.y - p.y, p.x - lo.x]      # N, E, S, O
			var k: int = 0
			for i in range(1, 4):
				if float(d[i]) < float(d[k]):
					k = i
			dx = [0, 1, 0, -1][k]
			dz = [-1, 0, 1, 0][k]
		var zona: int = _ANILLO.find(Vector2i(dx, dz))
		# componentes del anillo: tramos seguidos de vecinas libres (el anillo es un ciclo)
		var libre: Array = []
		for d2 in _ANILLO:
			libre.append(_vecina_libre(c + (d2 as Vector2i), c))
		var comp: Array = [-1, -1, -1, -1, -1, -1, -1, -1]
		var n_comp: int = 0
		for i in range(8):
			if libre[i] and comp[i] < 0:
				var j: int = i
				while libre[j] and comp[j] < 0:
					comp[j] = n_comp
					j = (j + 1) % 8
				j = (i + 7) % 8
				while libre[j] and comp[j] < 0:
					comp[j] = n_comp
					j = (j + 7) % 8
				n_comp += 1
		return _zona_de(zona, libre, comp) < 0

	## A qué componente del anillo da la zona `z` (-1 = sellada).
	func _zona_de(z: int, libre: Array, comp: Array) -> int:
		if z % 2 == 1:
			# esquina: entre los lados z-1 y z+1, con la diagonal z
			var a: int = (z + 7) % 8
			var b: int = (z + 1) % 8
			return int(comp[z]) if libre[a] and libre[b] and libre[z] else -1
		return int(comp[z]) if libre[z] else -1

	func _poligono(local: PackedVector3Array, tf: Transform3D) -> PackedVector2Array:
		var p2 := PackedVector2Array()
		for v in local:
			var w: Vector3 = tf * v
			p2.append(Vector2(w.x, w.z))
		return Geometry2D.convex_hull(p2)

	## ¿Toca el cuerpo de la jugadora (círculo de RADIO_CUERPO en `p`) el polígono convexo (cerrado: el último punto repite el primero)?
	func _toca_poligono(p: Vector2, poli: PackedVector2Array) -> bool:
		if poli.size() < 4:
			return false
		if Geometry2D.is_point_in_polygon(p, poli):
			return true
		for k in range(poli.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, poli[k], poli[k + 1]).distance_to(p) <= RADIO_CUERPO:
				return true
		return false



## Lo de siempre: el diccionario `_bloqueadas` del mundo y las huellas aproximadas de `calcular_huellas`.
class FuenteCasillas extends FuenteSolidez:
	func _dic() -> Dictionary:
		if Terreno3D.datos_propios:
			return Terreno3D.bloqueadas
		return Terreno3D.mundo_s.get("_bloqueadas") as Dictionary
	func bloquea(c: Vector2i) -> bool:
		return Terreno3D.hay_mundo() and _dic().has(c)
	func bloquear(c: Vector2i, de: Node3D = null) -> void:
		_dic()[c] = true
		_forma_pendiente(c, de)
	func liberar(c: Vector2i) -> void:
		_dic().erase(c)
		_olvidar_forma(c)
	## 12/11: el terreno (pared `#`, agua, vacío) no es un objeto: no se le busca forma.
	func _es_objeto(c: Vector2i) -> bool:
		var l: String = Terreno3D.letra_de(c)
		return l != "#" and l != "~" and l != " "
	func es_parcial(c: Vector2i, con_objetos: bool = false) -> bool:
		if not bloquea(c):
			return false
		if Terreno3D.huellas.has(c):
			return true
		return con_objetos and _es_objeto(c) and not _formas_de(c).is_empty()
	func choca_punto(c: Vector2i, p: Vector3) -> bool:
		var hay_forma: bool = false
		if Terreno3D.huellas.has(c):
			hay_forma = true
			for h in (Terreno3D.huellas[c] as Array):
				var hv: Vector3 = h
				if Vector2(p.x - hv.x, p.z - hv.y).length() <= hv.z + Terreno3D.MARGEN_HUELLA:
					return true
		if bloquea(c) and _es_objeto(c):
			var toca: int = _toca_formas(c, p)
			if toca == 1:
				return true
			if toca == 0:
				hay_forma = true
		return not hay_forma


## La solidez sale de la FÍSICA: lo que se ve es lo que choca. Una casilla está bloqueada si hay colisión sólida (capa
## CAPA_SOLIDO) dentro de ella; el punto del jugador choca si una esfera de su cuerpo toca esa colisión.
## `reconstruir()` rellena la caché de casillas: llamarlo UNA vez tras cargar el nivel y esperar un fotograma de física
## (el motor no ve los cuerpos nuevos hasta entonces). Lo que cambia en juego (tierra, hielo) va en `extras`.
class FuenteNodos extends FuenteSolidez:
	## 4/11 (auditoría de colisiones): 0,3 → 0,25. La caja de jugadora_base (a su alto de 1,0) mide 0,49 × 0,35 u con los brazos como en idle: medio ancho 0,245. Con 0,3 (0,6 de diámetro) se
	## chocaba contra el aire a 5 cm de cada árbol, valla y piedra; con 0,25 el cuerpo choca donde acaba el modelo.
	## (12/11: la constante `RADIO_CUERPO` = 0,25 vive ahora en la clase base, con las formas de los objetos.)
	## 21/10: qué parte CENTRAL de la casilla ha de tocar una forma para que la casilla cuente como bloqueada ENTERA (la que ven
	## hechizos, flechas, línea de visión, el BFS de las pruebas). Antes bastaba rozar el 90 % de la casilla: un pino de 1,59 de
	## radio (cono medido sobre el modelo) metía 0,4 u en cada casilla vecina y las marcaba enteras → pasillos de una casilla
	## «cerrados» (90 casillas por pino y 15 por arbol_redondo_2 en Bosque 01) aunque el jugador pasa de sobra por la forma real.
	const FRACCION_CENTRO: float = 0.5
	var mundo: Node3D = null
	var celdas: Dictionary = {}                      ## Vector2i -> true: la forma TOCA la casilla (el jugador y los goblins chocan con la forma, no con la casilla)
	var cubiertas: Dictionary = {}                   ## ...y de esas, las que cubre de verdad (su centro o la casilla de la pieza): bloqueadas enteras
	var extras: Dictionary = {}                      ## bloqueos creados jugando
	var _caja: BoxShape3D = BoxShape3D.new()
	var _caja_centro: BoxShape3D = BoxShape3D.new()
	var _bola: SphereShape3D = SphereShape3D.new()

	func _init(p_mundo: Node3D) -> void:
		mundo = p_mundo
		_bola.radius = RADIO_CUERPO

	func reconstruir() -> int:
		celdas.clear()
		cubiertas.clear()
		var espacio: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
		var lado: int = int(mundo.get("_lado"))
		var cas: float = Terreno3D.casilla
		_caja.size = Vector3(cas * 0.9, 4.0, cas * 0.9)   # alto: cualquier cosa por encima del suelo de la casilla
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _caja
		q.collision_mask = Terreno3D.CAPA_SOLIDO
		for y in range(lado):
			for x in range(lado):
				q.transform = Transform3D(Basis(), Terreno3D.centro_de(Vector2i(x, y), Terreno3D.alto_suelo + 2.0))
				if not espacio.intersect_shape(q, 1).is_empty():
					celdas[Vector2i(x, y)] = true
		# De las casillas tocadas, las que la forma cubre por el centro: son las que cuentan como bloqueadas enteras.
		_caja_centro.size = Vector3(cas * FRACCION_CENTRO, 4.0, cas * FRACCION_CENTRO)
		var qc := PhysicsShapeQueryParameters3D.new()
		qc.shape = _caja_centro
		qc.collision_mask = Terreno3D.CAPA_SOLIDO
		for c in celdas.keys():
			qc.transform = Transform3D(Basis(), Terreno3D.centro_de(c, Terreno3D.alto_suelo + 2.0))
			if not espacio.intersect_shape(qc, 1).is_empty():
				cubiertas[c] = true
		# La casilla donde está la pieza (su origen) cuenta siempre, aunque la forma quede descentrada (pieza arrastrada a un borde).
		for n in mundo.get_tree().get_nodes_in_group("bloquea"):
			var cuerpo: CollisionObject3D = n as CollisionObject3D
			# 12/11: un arco (`paso_libre`) tiene su origen en el hueco por el que se pasa: su casilla no cuenta como bloqueada entera
			if cuerpo != null and (cuerpo.collision_layer & Terreno3D.CAPA_SOLIDO) != 0 and not cuerpo.has_meta("paso_libre"):
				var co: Vector2i = Terreno3D.celda_de(cuerpo.global_position)
				if celdas.has(co):
					cubiertas[co] = true
		return celdas.size()

	func bloquea(c: Vector2i) -> bool:
		return cubiertas.has(c) or extras.has(c)
	func _raiz_formas() -> Node:
		return mundo
	func bloquear(c: Vector2i, de: Node3D = null) -> void:
		extras[c] = true
		_forma_pendiente(c, de)                      # su forma se busca la primera vez que la jugadora pregunte por la casilla
	func liberar(c: Vector2i) -> void:
		extras.erase(c)
		celdas.erase(c)
		cubiertas.erase(c)
		_olvidar_forma(c)
	func bloquear_completa(c: Vector2i) -> void:
		celdas.erase(c)                              # ya no es «parcial»: sin forma que rozar, la casilla entera es pared
		cubiertas.erase(c)
		extras[c] = true
		_olvidar_forma(c)
		_sin_forma[c] = true
	func es_parcial(c: Vector2i, con_objetos: bool = false) -> bool:
		if extras.has(c):
			# 12/11: un bloqueo de juego SIN forma conocida (tierra, hielo, barrera, agua) es la casilla entera aunque la roce el casco de una pieza vecina
			# (antes `celdas` mandaba y esa casilla se atravesaba). Con forma (el modelo del objeto), la jugadora la roza; el resto sigue viendo la casilla.
			return con_objetos and not _formas_de(c).is_empty()
		return celdas.has(c)                         # la forma real manda: se roza lo que no es la pieza
	func choca_punto(c: Vector2i, p: Vector3) -> bool:
		var hay_forma: bool = false
		if celdas.has(c):
			hay_forma = true
			var espacio: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = _bola
			q.collision_mask = Terreno3D.CAPA_SOLIDO
			q.transform = Transform3D(Basis(), Vector3(p.x, Terreno3D.alto_suelo + 0.6, p.z))
			if not espacio.intersect_shape(q, 1).is_empty():
				return true
		if extras.has(c):
			var toca: int = _toca_formas(c, p)
			if toca != 0:
				return true                              # toca la forma, o es un bloqueo sin forma (la casilla entera)
			hay_forma = true
		return not hay_forma


static var fuente: FuenteSolidez = null


static func bloqueada(c: Vector2i) -> bool:
	return fuente != null and fuente.bloquea(c)


## `de` (12/11, opcional): el nodo que bloquea la casilla cuando no es un objeto con propiedad `celda` (ver `FuenteSolidez._formas_de`).
static func bloquear_celda(c: Vector2i, de: Node3D = null) -> void:
	if fuente != null:
		fuente.bloquear(c, de)
		_avisar(c, "bloqueo")


static func bloquear_celda_completa(c: Vector2i) -> void:
	if fuente != null:
		fuente.bloquear_completa(c)


static func liberar_celda(c: Vector2i) -> void:
	if fuente != null:
		fuente.liberar(c)
		_avisar(c, "bloqueo")


## Cambia a la solidez por colisión real. Devuelve las casillas bloqueadas que ve (0 = aún no hay cuerpos en la física).
static func activar_fuente_nodos(p_mundo: Node3D) -> int:
	var f := FuenteNodos.new(p_mundo)
	var n: int = f.reconstruir()
	fuente = f
	return n


static func activar_fuente_casillas() -> void:
	fuente = FuenteCasillas.new()

## ¿Está el punto sobre agua helada? Quien camina por ahí resbala (Jugador3D).
static func sobre_hielo(p: Vector3) -> bool:
	var c: Vector2i = celda_de(p)
	return en_mapa(c) and hielo_fisico(c)


## ¿El hielo de esta casilla es tan gordo que para proyectiles y miradas? (No para andar.)
static func cubre_hielo(c: Vector2i) -> bool:
	return agua_sim != null and en_mapa(c) and hielo_fisico(c) \
			and agua_sim.espesor_hielo(c) >= HIELO_COBERTURA


static func celda_de(p: Vector3) -> Vector2i:
	return Vector2i(int(floorf(p.x / casilla)), int(floorf(p.z / casilla)))


static func centro_de(c: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3((float(c.x) + 0.5) * casilla, y, (float(c.y) + 0.5) * casilla)


## DATOS PROPIOS DEL MAPA (M5, parte del Juego, 13/10). Hasta ahora el terreno le preguntaba a la maqueta por reflexión (`_letra`,
## `_lado`, `_bloqueadas`, `_es_canal`, `_abre_hacia`: 5 nombres privados del Pipeline). Con `cargar_datos` el cargador del nivel le
## entrega el mapa UNA vez y el terreno contesta solo, sin maqueta (se puede probar en headless sin nodos). Mientras nadie la llame,
## todo sigue por reflexión como antes.
static var datos_propios: bool = false
static var mapa: PackedStringArray = []          ## filas de letras. Dueño: Terreno3D (cambiar una letra: `poner_letra`)
static var bloqueadas: Dictionary = {}           ## Vector2i -> true (COMPARTIDO por referencia con quien lo pase)
static var celdas_canal: Dictionary = {}         ## casillas de canal de nivel horneado (piezas canal_*), Vector2i -> true
static var giros: Dictionary = {}                ## Vector2i -> grados del marcador de canal (para saber qué lados abre)


## El cargador entrega el nivel. `p_mapa` se COPIA (después, `poner_letra`); los tres diccionarios se comparten por referencia, así
## quien ya los tenga (la maqueta) y el terreno ven lo mismo sin sincronizar nada a mano.
static func cargar_datos(p_mapa: PackedStringArray, p_bloqueadas: Dictionary, p_celdas_canal: Dictionary = {}, p_giros: Dictionary = {}) -> void:
	mapa = p_mapa.duplicate()
	bloqueadas = p_bloqueadas
	celdas_canal = p_celdas_canal
	giros = p_giros
	datos_propios = true


## Vuelve a preguntar a la maqueta (como antes de M5).
static func olvidar_datos() -> void:
	datos_propios = false
	cauces_a_ras.clear()
	mapa = []
	bloqueadas = {}
	celdas_canal = {}
	giros = {}


## ¿Hay un mundo al que preguntar? (la maqueta de siempre o datos propios).
static func hay_mundo() -> bool:
	return mundo_s != null or datos_propios


## Lado del mapa (cuadrado). 0 si no hay mundo.
static func lado_del_mapa() -> int:
	if datos_propios:
		return mapa.size()
	return int(mundo_s.get("_lado")) if mundo_s != null and mundo_s.get("_lado") != null else 0


## Cambia una letra del mapa (agua que llega a un cauce…). Con datos propios es la única forma; avisa por Mundo3D («letra»).
static func poner_letra(c: Vector2i, l: String) -> void:
	if not datos_propios or c.y < 0 or c.y >= mapa.size() or c.x < 0 or c.x >= mapa[c.y].length():
		return
	var fila: String = mapa[c.y]
	mapa[c.y] = fila.substr(0, c.x) + l.substr(0, 1) + fila.substr(c.x + 1)
	_avisar(c, "letra")


static func en_mapa(c: Vector2i) -> bool:
	if datos_propios:
		return c.x >= 0 and c.y >= 0 and c.x < mapa.size() and c.y < mapa.size()
	return mundo_s != null and c.x >= 0 and c.y >= 0 and c.x < int(mundo_s.get("_lado")) and c.y < int(mundo_s.get("_lado"))


static func letra_de(c: Vector2i) -> String:
	if datos_propios:
		if c.y < 0 or c.y >= mapa.size() or c.x < 0 or c.x >= mapa[c.y].length():
			return "#"                        # fuera del mapa: pared, como la maqueta
		return mapa[c.y][c.x]
	return String(mundo_s.call("_letra", c))


## ¿Es un tramo de canal? Con las letras: `-` y `L`. Con un nivel horneado esas letras ya no existen: son las piezas canal_recto /
## canal_codo que el cargador apuntó en `celdas_canal`. (Copia de `_es_canal` de la maqueta.)
static func es_canal(c: Vector2i) -> bool:
	if datos_propios:
		return celdas_canal.has(c) or (en_mapa(c) and (letra_de(c) == "-" or letra_de(c) == "L"))
	return mundo_s != null and mundo_s.has_method("_es_canal") and bool(mundo_s.call("_es_canal", c))


## ¿Tiene el canal de `c` abierto su lado hacia `v`? Recto (`-`): corre a lo largo de su eje X local (giro 0 = este-oeste);
## codo (`L`): abre al oeste y al sur con giro 0, y gira con el marcador. (Copia de `_abre_hacia` de la maqueta.)
static func abre_hacia(c: Vector2i, v: Vector2i) -> bool:
	if not datos_propios:
		return mundo_s != null and mundo_s.has_method("_abre_hacia") and bool(mundo_s.call("_abre_hacia", c, v))
	var giro: float = deg_to_rad(float(giros.get(c, 0.0)))
	var base: Array = [Vector2(-1, 0), Vector2(1, 0)] if letra_de(c) != "L" else [Vector2(-1, 0), Vector2(0, 1)]
	for b in base:
		var lx: float = b.x
		var lz: float = b.y
		var mx: int = roundi(lx * cos(giro) + lz * sin(giro))
		var mz: int = roundi(-lx * sin(giro) + lz * cos(giro))
		if Vector2i(mx, mz) == v:
			return true
	return false


## Agua de verdad: ni puente ni hielo encima. Con la simulación (Fase 11.3) pregunta a AguaSim3D por la profundidad de la
## casilla; sin ella, a la letra «~» del mapa (el respaldo de siempre).
static func es_agua(c: Vector2i) -> bool:
	if not hay_mundo():
		return false
	if hielo_fisico(c):
		return false
	# Un puente («b»: losa o tronco-puente caído) se ANDA: no es agua para pisar, nadar, hundirse ni rutear, aunque la simulación siga viendo agua debajo (la
	# letra cambió, la profundidad no). Sin esta salida el goblin que cruza el tronco lo mandaba `_ajustar_al_suelo` de vuelta a su puesto («se le fue el suelo»).
	# Lo que el puente NO apaga es la corriente: bajo él el agua sigue conduciendo (ver `conduce`).
	if letra_de(c) == "b":
		return false
	if agua_sim != null:
		return agua_sim.es_agua_casilla(c)
	return letra_de(c) == "~"


## ¿Se NADA en esta casilla? Agua de verdad, salvo el canal de ruinas: ahí el agua es una lámina de menos de media casilla sobre
## el fondo de la pieza (0,48 como mucho con la tinaja) y se vadea. Seguirá siendo `es_agua` (conduce el rayo), pero nadar la
## hundía los pies hasta `alto_agua - HUNDIDO` (≈0,27), 0,9 u por debajo del suelo de la pieza, y la casilla siguiente los subía (P3).
static func se_nada(c: Vector2i) -> bool:
	return not plataformas_tierra.has(c) and es_agua(c) and not es_canal_ruinas(c)


static func es_vacio(c: Vector2i) -> bool:
	return not en_mapa(c) or letra_de(c) == " "


## ¿Es un cauce seco que el surtidor llenará? La letra «c» o un tramo de CANAL de la maqueta (`-`, `L` o las piezas canal_* de un
## nivel horneado: `_es_canal`). Sin esto la simulación no conocía el canal de la tinaja y el agua no entraba en él (diario 12/10 15:30).
static func es_cauce_seco(c: Vector2i) -> bool:
	if not hay_mundo():
		return false
	return letra_de(c) == "c" or es_canal(c)


## ¿Es un tramo de canal de RUINAS (`-`, `L` o pieza canal_*) y no un cauce «c»? Su fondo está sobre el suelo, no en el lecho del río.
static func es_canal_ruinas(c: Vector2i) -> bool:
	return hay_mundo() and letra_de(c) != "c" and es_canal(c)


## Lados (Vector2i en 4 direcciones) por los que el canal de la casilla `c` deja pasar el agua: los que abre la pieza
## (`_abre_hacia` de la maqueta); sin ese método, los vecinos que también son canal.
static func lados_de_canal(c: Vector2i) -> Array:
	var r: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if datos_propios or mundo_s.has_method("_abre_hacia"):
			if abre_hacia(c, d):
				r.append(d)
		elif es_canal_ruinas(c + d):
			r.append(d)
	return r


## Crea la simulación del nivel: suelo de cada casilla (el lecho bajo «~», `alto_suelo` más sus niveles en el resto), paredes
## en lo que bloquea (menos el agua), las casillas «~» llenas hasta `alto_agua`, y nivel FIJO en las «~» del borde del mapa
## (por donde el río entra o sale: se mantiene lleno y se lleva lo que sobra). Devuelve la simulación; también la guarda.
static func montar_agua_sim(sub: int = 3) -> AguaSim3D:
	agua_sim = null
	cauces_abiertos.clear()
	elevacion_canal.clear()
	conductores.clear()
	if not hay_mundo() or lado_del_mapa() == 0:
		return null
	var lado: int = lado_del_mapa()
	var sim := AguaSim3D.new()
	var suelo := func(c: Vector2i) -> float:
		var l: String = letra_de(c)
		if es_canal_ruinas(c):
			return fondo_canal_en(c)              # el cajón de piedra: el agua llega a la altura de la pieza y se ve (más arriba si el canal está sobre una terraza)
		if l == "~" or es_cauce_seco(c):
			return alto_agua - LECHO_AGUA
		return alto_suelo + float(altura_en(c)) * ALTO_NIVEL
	# Es pared: lo que bloquea (menos el agua), la tierra levantada (hace de presa, 11.4) y el cauce seco sin abrir (11.5).
	var pared := func(c: Vector2i) -> bool:
		if altura_en(c) >= 1:
			return true
		if es_cauce_seco(c):
			return not cauces_abiertos.has(c)
		return letra_de(c) != "~" and bloqueada(c)
	sim.configurar(lado, lado, sub, casilla, suelo, pared)
	for y in range(lado):
		for x in range(lado):
			var c := Vector2i(x, y)
			if letra_de(c) != "~":
				continue
			sim.llenar_casilla(c, alto_agua)
			if x == 0 or y == 0 or x == lado - 1 or y == lado - 1:
				sim.fijar_nivel(c, alto_agua)
	# Canal de ruinas: el agua solo ocupa su cajón (centro + lados que abre la pieza). Sin aplicar: sigue sellado hasta que el
	# surtidor lo abra, y entonces se abre con esta forma (solidificar_casilla).
	for y in range(lado):
		for x in range(lado):
			var cc := Vector2i(x, y)
			if es_canal_ruinas(cc):
				sim.abrir_solo(cc, lados_de_canal(cc), false)
	agua_sim = sim
	return sim


static func altura_en(c: Vector2i) -> int:
	return int(alturas.get(c, 0))


static func fijar_altura(c: Vector2i, niveles: int) -> void:
	## Para el nivel: una cornisa. No caduca. Pasar 0 la quita.
	if niveles <= 0:
		permanentes.erase(c)
		alturas.erase(c)
	else:
		permanentes[c] = niveles
		alturas[c] = maxi(int(alturas.get(c, 0)), niveles)
	_avisar(c, "altura")


## Un puente «b» que se pisa a otra altura que la losa (la cara de arriba de un tronco). Se pone ANTES de `poner_letra(c, "b")`.
static func fijar_y_puente(c: Vector2i, y: float) -> void:
	y_puentes[c] = y


## y de los pies de quien está en la casilla `c`: el suelo, más sus niveles; el agua y el puente, más bajo.
static func y_pies(c: Vector2i) -> float:
	if plataformas_tierra.has(c):
		return float(plataformas_tierra[c])
	var n: int = altura_en(c)
	if n > 0:
		return alto_suelo + float(n) * ALTO_NIVEL
	var l: String = letra_de(c)
	if l == "b" and y_puentes.has(c):
		return float(y_puentes[c])
	var helada: bool = hielo_fisico(c)      # la escarcha del suelo no baja los pies al nivel del agua
	if helada and agua_sim != null:
		var y_hielo: float = agua_sim.hielo_en_casilla(c)      # 11.13: se pisa a la altura del hielo, sea cual sea el nivel del agua
		if y_hielo > -INF:
			return y_hielo
	if es_canal_ruinas(c):
		return fondo_canal_en(c)              # P3: el suelo de la pieza, con o sin agua. La lámina del canal no se nada: se vadea
	if es_hueco_cauce(c):
		return alto_agua - LECHO_AGUA         # 15/10 (Pablo: «que se intuya profundidad»): el fondo del pozo; con agua, el jugador nada en su superficie. Cauce hondo (22/10): el mismo fondo, aún seco
	if l == "b" or helada:
		return alto_agua + 0.12
	if l == "~":
		return alto_agua
	return alto_suelo


## ¿Pasa la electricidad por esta casilla? Agua de juego (es_agua) o un conductor declarado (NexoRayo3D mojado).
static func conduce(c: Vector2i) -> bool:
	# El agua que corre BAJO un puente («b») sigue conduciendo: el tronco no la corta (es_agua dice «no» para andar, la simulación sigue diciendo «sí»).
	var bajo_puente: bool = agua_sim != null and letra_de(c) == "b" and not hielo_fisico(c) and agua_sim.es_agua_casilla(c)
	return es_agua(c) or bajo_puente or conductores.has(c)


## ¿Es una CUENCA: un cauce seco `c` ya abierto a la simulación (un pozo de LECHO_AGUA de hondo que se llena y se vacía)? 15/10, lab de
## puzles de agua. Un `c` sin abrir sigue siendo «cauce seco» (se pisa a ras: es el lecho de piedras del Bosque hasta que el surtidor lo llena).
static func es_cuenca(c: Vector2i) -> bool:
	return hay_mundo() and letra_de(c) == "c" and cauces_abiertos.has(c)


## Y de la SUPERFICIE del agua en la casilla: lo que el jugador tiene que flotar. El río y el puente, `alto_agua`; una cuenca o un canal,
## lo que diga la simulación (suelo + profundidad en su centro). Sin agua, el suelo de la casilla (y_pies).
static func superficie_agua(c: Vector2i) -> float:
	# Un cauce abierto que ya pasó a «~» (el surtidor, `llenar_cauce`) sigue teniendo el nivel de la simulación: sube desde el fondo, no está «lleno» de golpe como el río.
	if agua_sim != null and (es_hueco_cauce(c) or es_canal_ruinas(c) or cauces_abiertos.has(c)):
		var p: float = agua_sim.profundidad_casilla(c)
		if p > AguaSim3D.PROF_MIN:
			return agua_sim.superficie_en(centro_de(c, 0.0))
		return y_pies(c)
	if letra_de(c) == "~" or letra_de(c) == "b":
		return alto_agua
	return y_pies(c)


## Lo sólido para un hechizo que vuela a nivel `nivel`: el mapa (árboles, muros, objetos) o una torre de tierra.
static func celda_solida(c: Vector2i, nivel: int) -> bool:
	if not en_mapa(c):
		return true
	var l: String = letra_de(c)
	if l != "~" and bloqueada(c):
		return true
	if cubre_hielo(c):
		return true                          # 11.13: un hielo gordo para proyectiles
	return altura_en(c) >= 1 + nivel


## ---- Ocupación por casilla y altura (D1 de PLAN_EOW, 21/10) ----
## Medido antes de escribir: había TRES formas de preguntar por lo sólido y ninguna para una forma entera. `celda_solida(c, nivel)`
## (una casilla, para hechizos: lanzador_3d ×2, hechizo_vivo ×4), `pisable(c, …)` (quien camina: jugador, goblins, lanzador) y
## `construir_tierra` (lanzador), que repite a mano agua + bloqueo + cornisa. «¿Cabe una forma de N casillas y M alturas aquí?»
## (rasterizado de glifos de la Fase 8, bloque de tierra, camino de enemigos) no la contestaba nadie. Estas dos funciones lo hacen
## SIN inventar reglas: `ocupado` es exactamente `celda_solida` (misma respuesta para los hechizos) y `cabe` la repite por casilla
## y altura. No saben de actores (jugador, goblins): eso lo sigue mirando quien construye.
## Simplificación que hereda de `celda_solida`: una pieza que bloquea (árbol, roca) ocupa TODAS las alturas de su casilla.

## ¿Hay algo sólido en la casilla `c` a la altura `nivel` (0 = a ras del suelo, 1 = un bloque de tierra más arriba…)? Fuera del mapa,
## sí. Cuenta: piezas que bloquean (no en el río «~»), hielo gordo y la tierra/cornisa que llegue a ese nivel.
static func ocupado(c: Vector2i, nivel: int) -> bool:
	return celda_solida(c, nivel)


## ¿Cabe una forma que ocupa `celdas` y va de `nivel_desde` a `nivel_desde + alto - 1`? `sobre_agua = false` además la rechaza si
## alguna casilla es agua sin helar (lo que pide el bloque de tierra: no se construye en el río).
static func cabe(celdas: Array, nivel_desde: int, alto: int = 1, sobre_agua: bool = true) -> bool:
	if celdas.is_empty() or alto < 1:
		return false
	for c in celdas:
		var q: Vector2i = c
		if not en_mapa(q):
			return false
		if not sobre_agua and es_agua(q) and not hielo_fisico(q):
			return false
		for k in range(nivel_desde, nivel_desde + alto):
			if ocupado(q, k):
				return false
	return true


## ---- Huellas: lo que ocupa DE VERDAD cada objeto que bloquea una casilla ----
## La rejilla bloquea casillas enteras (2,3 u) aunque el modelo sea un barril de 1 u o un puesto que ocupa casilla y media.
## Para el JUGADOR se afina: en una casilla bloqueada solo choca dentro del círculo de los objetos que la tocan (más el
## cuerpo). Sin huella conocida (telaraña, barrera, puente, paredes de árboles...) la casilla sigue entera.
## Los hechizos y los goblins siguen usando la casilla entera.
static var huellas: Dictionary = {}        ## Vector2i -> Array de Vector3(x, z, radio)
const MARGEN_HUELLA: float = 0.3


## ---- Realces: lo bajo que se SUBE (4/11, Pablo: «que puedas pasar por rocas o pequeñas elevaciones, como los troncos») ----
## Las piedras y los troncos tumbados de ≤ `ColisionPieza.ALTO_MIN_SOLIDO` (0,45 u) no bloquean (no tienen cuerpo); en vez de atravesarlos con los pies, la jugadora SUBE encima: su suelo sube hasta
## alto · fracción (`ColisionPieza.REALCE`) en el centro de la pieza y baja suave a 0 en su borde. Vector2i (casilla de la pieza y las 8 vecinas) → Array de Vector4(x, z, radio, altura del realce).
static var realces: Dictionary = {}
const REALCE_BORDE: float = 0.55           ## fracción del radio, desde el borde hacia dentro, en que el realce sube de 0 al máximo


## Cuánto sube el suelo (u) en el punto `p` por las piedras y los troncos bajos que hay ahí. 0 casi siempre.
static func realce_en(p: Vector3) -> float:
	if realces.is_empty():
		return 0.0
	var lista: Variant = realces.get(celda_de(p))
	if lista == null:
		return 0.0
	var mejor: float = 0.0
	for r in (lista as Array):
		var rv: Vector4 = r
		var d: float = Vector2(p.x - rv.x, p.z - rv.y).length()
		if d >= rv.z:
			continue
		var k: float = clampf((rv.z - d) / maxf(rv.z * REALCE_BORDE, 0.001), 0.0, 1.0)
		mejor = maxf(mejor, rv.w * (k * k * (3.0 - 2.0 * k)))
	return mejor


static func calcular_huellas(p_mundo: Node3D) -> int:
	huellas.clear()
	realces.clear()
	var lotes: Variant = p_mundo.get("_lotes")
	if not (lotes is Dictionary) or (lotes as Dictionary).is_empty():
		return 0
	var n: int = 0
	for id in (lotes as Dictionary):
		var partes: Array = p_mundo.call("_plantilla", String(id))
		var caja := AABB()
		var primero: bool = true
		for parte in partes:
			var m: Mesh = (parte as Array)[0] as Mesh
			if m == null:
				continue
			var a: AABB = ((parte as Array)[1] as Transform3D) * m.get_aabb()
			caja = a if primero else caja.merge(a)
			primero = false
		if primero:
			continue
		for t in ((lotes as Dictionary)[id] as Array):
			var tr: Transform3D = t
			var c: Vector2i = celda_de(tr.origin)
			var esc: float = tr.basis.get_scale().x
			var centro: Vector3 = tr * caja.get_center()
			var r: float = 0.5 * maxf(caja.size.x, caja.size.z) * esc
			if ColisionPieza.REALCE.has(String(id)):
				var alto_r: float = (caja.position.y + caja.size.y) * tr.basis.get_scale().y * float(ColisionPieza.REALCE[String(id)])
				for dy2 in range(-1, 2):
					for dx2 in range(-1, 2):
						var q2 := c + Vector2i(dx2, dy2)
						if not realces.has(q2):
							realces[q2] = []
						(realces[q2] as Array).append(Vector4(centro.x, centro.z, r * 0.9, alto_r))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q := c + Vector2i(dx, dy)
					if bloqueada(q) and letra_de(q) != "#" and letra_de(q) != "~":
						if not huellas.has(q):
							huellas[q] = []
						(huellas[q] as Array).append(Vector3(centro.x, centro.z, r))
						n += 1
	return n


## ¿Es una casilla bloqueada cuya forma real conocemos (y por tanto se puede rozar)?
## `con_objetos` (12/11, solo la jugadora): cuenta también el contorno del modelo de los objetos de juego que bloquean su casilla (ver `FuenteNodos._formas_de`).
static func es_parcial(c: Vector2i, con_objetos: bool = false) -> bool:
	return fuente != null and fuente.es_parcial(c, con_objetos)


## ¿Está el punto dentro de lo que ocupa de verdad un objeto de esa casilla?
static func choca_huella(c: Vector2i, p: Vector3) -> bool:
	return fuente == null or fuente.choca_punto(c, p)


## ¿Puede ESTAR alguien de pie en `c`? Lo usan el jugador y los goblins. `nivel` es en el que está;
## `sube` si puede subir uno (saltando); `max_nivel` lo más alto donde se puede estar; `nada` si puede entrar en agua.
static func pisable(c: Vector2i, nivel: int, sube: bool, max_nivel: int, nada: bool, ignora_bloqueo: bool = false) -> bool:
	if plataformas_tierra.has(c):
		return true
	if es_vacio(c):
		return false
	var l: String = letra_de(c)
	if l == "~":
		if hielo_fisico(c):
			pass                                     # hielo: se pisa
		else:
			return nada                              # agua: solo nadando
	elif bloqueada(c) and not ignora_bloqueo:
		return false
	# 6.22a: la hierba crecida YA NO es sólida: se atraviesa (antes bloqueaba el paso).
	var n: int = altura_en(c)
	if n > max_nivel:
		return false
	return n <= nivel + (1 if sube else 0)


## ¿Se ven dos puntos? Las casillas sólidas del mapa y las torres de tierra cortan la vista.
static func linea_libre(a: Vector3, b: Vector3) -> bool:
	var d: Vector3 = b - a
	d.y = 0.0
	var largo: float = d.length()
	if largo < 0.01:
		return true
	var paso: float = casilla * 0.25
	var u: Vector3 = d / largo
	var previa: Vector2i = celda_de(a)
	# Una casilla elevada solo corta la vista si es MÁS ALTA que quien mira (o que quien es mirado): en una terraza no se
	# ve a través de nada de su propio nivel. A nivel 0 es lo de siempre (altura ≥ 1 corta).
	var nivel_vista: int = maxi(altura_en(previa), altura_en(celda_de(b)))
	var rec: float = paso
	while rec < largo:
		var c: Vector2i = celda_de(a + u * rec)
		if c != previa:
			var l: String = letra_de(c)
			if not en_mapa(c) or (l != "~" and bloqueada(c)) or altura_en(c) > nivel_vista or cubre_hielo(c):
				return false
			previa = c
		rec += paso
	return true



## Fija el mundo y reinicia el estado del terreno. (Es la parte «de terreno» de Lanzador3D.configurar, sin cambios.)
static func configurar(p_mundo: Node3D) -> void:
	mundo_s = p_mundo
	fuente = FuenteCasillas.new()        # por defecto, lo de siempre (6.10)
	var k: Dictionary = p_mundo.get_script().get_script_constant_map()
	casilla = float(k.get("S", casilla))
	alto_suelo = float(k.get("ALTO", alto_suelo))
	ALTO_NIVEL = alto_suelo
	alto_agua = float(k.get("ALTO_AGUA", alto_agua))
	PROF_CAUCE = alto_suelo - fondo_cauce()
	alturas.clear()
	alturas_temporales.clear()
	plataformas_tierra.clear()
	permanentes.clear()
	y_puentes.clear()
	estados.limpiar()                    # nivel nuevo: ni hielo ni electricidad de antes
	estados.olvidar_materiales()         # B4: ni los materiales de la pieza `; material` del nivel anterior (`limpiar` no los toca: también corre al cargar una partida)
	agua_sim = null
