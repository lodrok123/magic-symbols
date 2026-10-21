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
	if not estados.poner(c, EstadosSuelo3D.HELADA, si) and era_escarcha:
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
	func bloquear(_c: Vector2i) -> void:
		pass
	func liberar(_c: Vector2i) -> void:
		pass
	## 12/10 (Pablo): un MURO bloquea la casilla ENTERA, siempre (no se roza ni se cuela por un hueco de su forma).
	func bloquear_completa(c: Vector2i) -> void:
		bloquear(c)
	## ¿Se puede ROZAR la casilla (su forma real es menor que la casilla)? Solo el jugador afina; hechizos y goblins no.
	func es_parcial(_c: Vector2i) -> bool:
		return false
	## Con casilla parcial: ¿toca el punto `p` (suelo) lo que de verdad hay ahí?
	func choca_punto(_c: Vector2i, _p: Vector3) -> bool:
		return true


## Lo de siempre: el diccionario `_bloqueadas` del mundo y las huellas aproximadas de `calcular_huellas`.
class FuenteCasillas extends FuenteSolidez:
	func _dic() -> Dictionary:
		if Terreno3D.datos_propios:
			return Terreno3D.bloqueadas
		return Terreno3D.mundo_s.get("_bloqueadas") as Dictionary
	func bloquea(c: Vector2i) -> bool:
		return Terreno3D.hay_mundo() and _dic().has(c)
	func bloquear(c: Vector2i) -> void:
		_dic()[c] = true
	func liberar(c: Vector2i) -> void:
		_dic().erase(c)
	func es_parcial(c: Vector2i) -> bool:
		return Terreno3D.huellas.has(c) and bloquea(c)
	func choca_punto(c: Vector2i, p: Vector3) -> bool:
		if not Terreno3D.huellas.has(c):
			return true
		for h in (Terreno3D.huellas[c] as Array):
			var hv: Vector3 = h
			if Vector2(p.x - hv.x, p.z - hv.y).length() <= hv.z + Terreno3D.MARGEN_HUELLA:
				return true
		return false


## La solidez sale de la FÍSICA: lo que se ve es lo que choca. Una casilla está bloqueada si hay colisión sólida (capa
## CAPA_SOLIDO) dentro de ella; el punto del jugador choca si una esfera de su cuerpo toca esa colisión.
## `reconstruir()` rellena la caché de casillas: llamarlo UNA vez tras cargar el nivel y esperar un fotograma de física
## (el motor no ve los cuerpos nuevos hasta entonces). Lo que cambia en juego (tierra, hielo) va en `extras`.
class FuenteNodos extends FuenteSolidez:
	const RADIO_CUERPO: float = 0.3
	var mundo: Node3D = null
	var celdas: Dictionary = {}                      ## Vector2i -> true (sacado de la colisión)
	var extras: Dictionary = {}                      ## bloqueos creados jugando
	var _caja: BoxShape3D = BoxShape3D.new()
	var _bola: SphereShape3D = SphereShape3D.new()

	func _init(p_mundo: Node3D) -> void:
		mundo = p_mundo
		_bola.radius = RADIO_CUERPO

	func reconstruir() -> int:
		celdas.clear()
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
		return celdas.size()

	func bloquea(c: Vector2i) -> bool:
		return celdas.has(c) or extras.has(c)
	func bloquear(c: Vector2i) -> void:
		extras[c] = true
	func liberar(c: Vector2i) -> void:
		extras.erase(c)
		celdas.erase(c)
	func bloquear_completa(c: Vector2i) -> void:
		celdas.erase(c)                              # ya no es «parcial»: sin forma que rozar, la casilla entera es pared
		extras[c] = true
	func es_parcial(c: Vector2i) -> bool:
		return celdas.has(c)                         # la forma real manda: se roza lo que no es la pieza
	func choca_punto(c: Vector2i, p: Vector3) -> bool:
		if not celdas.has(c):
			return true
		var espacio: PhysicsDirectSpaceState3D = mundo.get_world_3d().direct_space_state
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = _bola
		q.collision_mask = Terreno3D.CAPA_SOLIDO
		q.transform = Transform3D(Basis(), Vector3(p.x, Terreno3D.alto_suelo + 0.6, p.z))
		return not espacio.intersect_shape(q, 1).is_empty()


static var fuente: FuenteSolidez = null


static func bloqueada(c: Vector2i) -> bool:
	return fuente != null and fuente.bloquea(c)


static func bloquear_celda(c: Vector2i) -> void:
	if fuente != null:
		fuente.bloquear(c)
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
	if agua_sim != null:
		return agua_sim.es_agua_casilla(c)
	return letra_de(c) == "~"


## ¿Se NADA en esta casilla? Agua de verdad, salvo el canal de ruinas: ahí el agua es una lámina de menos de media casilla sobre
## el fondo de la pieza (0,48 como mucho con la tinaja) y se vadea. Seguirá siendo `es_agua` (conduce el rayo), pero nadar la
## hundía los pies hasta `alto_agua - HUNDIDO` (≈0,27), 0,9 u por debajo del suelo de la pieza, y la casilla siguiente los subía (P3).
static func se_nada(c: Vector2i) -> bool:
	return es_agua(c) and not es_canal_ruinas(c)


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
	conductores.clear()
	if not hay_mundo() or lado_del_mapa() == 0:
		return null
	var lado: int = lado_del_mapa()
	var sim := AguaSim3D.new()
	var suelo := func(c: Vector2i) -> float:
		var l: String = letra_de(c)
		if es_canal_ruinas(c):
			return alto_suelo + FONDO_CANAL       # el cajón de piedra: el agua llega a la altura de la pieza y se ve
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


## y de los pies de quien está en la casilla `c`: el suelo, más sus niveles; el agua y el puente, más bajo.
static func y_pies(c: Vector2i) -> float:
	var n: int = altura_en(c)
	if n > 0:
		return alto_suelo + float(n) * ALTO_NIVEL
	var l: String = letra_de(c)
	var helada: bool = hielo_fisico(c)      # la escarcha del suelo no baja los pies al nivel del agua
	if helada and agua_sim != null:
		var y_hielo: float = agua_sim.hielo_en_casilla(c)      # 11.13: se pisa a la altura del hielo, sea cual sea el nivel del agua
		if y_hielo > -INF:
			return y_hielo
	if es_canal_ruinas(c):
		return alto_suelo + FONDO_CANAL       # P3: el suelo de la pieza, con o sin agua. La lámina del canal no se nada: se vadea
	if es_cuenca(c):
		return alto_agua - LECHO_AGUA         # 15/10 (Pablo: «que se intuya profundidad»): el fondo del pozo; con agua, el jugador nada en su superficie
	if l == "b" or helada:
		return alto_agua + 0.12
	if l == "~":
		return alto_agua
	return alto_suelo


## ¿Pasa la electricidad por esta casilla? Agua de juego (es_agua) o un conductor declarado (NexoRayo3D mojado).
static func conduce(c: Vector2i) -> bool:
	return es_agua(c) or conductores.has(c)


## ¿Es una CUENCA: un cauce seco `c` ya abierto a la simulación (un pozo de LECHO_AGUA de hondo que se llena y se vacía)? 15/10, lab de
## puzles de agua. Un `c` sin abrir sigue siendo «cauce seco» (se pisa a ras: es el lecho de piedras del Bosque hasta que el surtidor lo llena).
static func es_cuenca(c: Vector2i) -> bool:
	return hay_mundo() and letra_de(c) == "c" and cauces_abiertos.has(c)


## Y de la SUPERFICIE del agua en la casilla: lo que el jugador tiene que flotar. El río y el puente, `alto_agua`; una cuenca o un canal,
## lo que diga la simulación (suelo + profundidad en su centro). Sin agua, el suelo de la casilla (y_pies).
static func superficie_agua(c: Vector2i) -> float:
	if agua_sim != null and (es_cuenca(c) or es_canal_ruinas(c)):
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


static func calcular_huellas(p_mundo: Node3D) -> int:
	huellas.clear()
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
static func es_parcial(c: Vector2i) -> bool:
	return fuente != null and fuente.es_parcial(c)


## ¿Está el punto dentro de lo que ocupa de verdad un objeto de esa casilla?
static func choca_huella(c: Vector2i, p: Vector3) -> bool:
	return fuente == null or fuente.choca_punto(c, p)


## ¿Puede ESTAR alguien de pie en `c`? Lo usan el jugador y los goblins. `nivel` es en el que está;
## `sube` si puede subir uno (saltando); `max_nivel` lo más alto donde se puede estar; `nada` si puede entrar en agua.
static func pisable(c: Vector2i, nivel: int, sube: bool, max_nivel: int, nada: bool, ignora_bloqueo: bool = false) -> bool:
	if not en_mapa(c):
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
	alturas.clear()
	permanentes.clear()
	estados.limpiar()                    # nivel nuevo: ni hielo ni electricidad de antes
	agua_sim = null
