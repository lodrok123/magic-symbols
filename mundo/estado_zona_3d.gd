class_name EstadoZona3D
extends Node

## LOS ESTADOS DE ZONA (F4 de docs/PLAN_BASE_DATOS.md §6, 29/10, Juego): calor, frío, veneno, humedad, oscuridad, tormenta, vendaval y resonancia. Ya había estados por CASILLA
## (`EstadosSuelo3D`) y por PERSONAJE (`mojado`, `envenenado`...). Éste es el de la ZONA: se declara en el mapa y vale mientras se está dentro. Los NÚMEROS de cada estado no viven
## aquí sino en `nucleo/datos/estados_mundo.tsv` (columnas numéricas, `BD.NUMEROS`); este nodo solo sabe DÓNDE vale cada estado y CUÁNDO.
##
## DE DÓNDE SALE UN ESTADO, tres maneras:
##   · FIJO     la línea `; zona <x0>,<y0>..<x1>,<y1> <luz> estado=calor[,veneno]` del mapa del nivel (`mundo/datos_nivel/mapas/<nivel>.txt`). `Zonas3D` (Pipeline) lee las MISMAS líneas
##              pero descarta las claves que no conoce, así que `estado=` lo lee este nodo por su cuenta: mismo formato de rectángulo y manda la ÚLTIMA declarada (una zona pisada por otra
##              sin `estado=` queda sin estados). No comprueba que la luz exista (si la zona de luz es mala `Zonas3D` avisa; los estados valen igual).
##   · DINÁMICO `poner(estado, segundos, opciones)`: tormenta (60 s, la pone un puzle: `hace=zona.poner(tormenta,60)`), vendaval (cambia de dirección cada `viento_cambia_s`), oscuridad...
##              Valen en todo el mapa o en `opciones["rect"]` (Rect2i). `quitar(estado)` los apaga. Se guardan en la sección `mundo` de la partida (`a_dic` / `desde_dic`).
##   · NUBE     el veneno es de las NUBES (`NubeVeneno3D`, con vida propia): una casilla dentro de una nube tiene `veneno`. Las nubes vivas también se guardan.
##
## QUÉ PREGUNTA SE HACE: `estados_en(celda)` (fijos de la zona que manda + dinámicos que cubren la celda + `veneno` si hay nube). `Mundo3D.estado_zona(celda)` y `Mundo3D.estados_jugadora()`
## delegan aquí (y devuelven [] si no hay nodo). Al cruzar de zona sale `estado_zona_cambio(entrando, saliendo)` y se rellena `Sintesis.estados_zona` (receta «al entrar en una zona con <estado>»).
## La TORMENTA cae aquí mismo (un rayo cada `rayo_cada_s` en una casilla `mojada` a ≤ `rayo_casillas` de la jugadora). El VIENTO lo aplica `Jugador3D` leyendo `viento_en`.
## Lo de dibujar (calima, niebla verde, lluvia, relámpagos, viñeta de oscuridad) es del Pipeline: se entera por `rayo_cayo` y `Mundo3D.impacto`.

signal estado_zona_cambio(entrando: Array, saliendo: Array)
signal dinamico_cambio(estado: String, activo: bool)
signal rayo_cayo(celda: Vector2i)

const RUTA_MAPA: String = "res://mundo/datos_nivel/mapas/%s.txt"
## Las cuatro cardinales en el orden en que gira el viento (este, sur, oeste, norte; `y` es la `z` del mundo).
const DIRECCIONES: Array = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
const DANO_RAYO: float = 12.0                ## lo que hiere un rayo de tormenta a quien está en la casilla (jugadora o enemigo; ambos en casilla mojada)
const AGUANTE_MAX: float = 100.0
const RELLENA_DEFECTO: float = 20.0          ## aguante por s fuera de todo estado si la tabla no dice otra cosa
const PERIODO_BRASERO: float = 0.5           ## s que se cachea la pregunta «¿hay un brasero encendido cerca?» (la hacen la jugadora y los enemigos)

## El nodo vivo (null si no hay). Estático para que quien no cuelga de él (Mundo3D, EstadosSuelo3D, AguaSim3D, las pruebas) lo encuentre.
static var actual: EstadoZona3D = null

var zonas: Array = []                        ## {rect: Rect2i, estados: Array[String]} en el orden del mapa (la última que cubre una celda manda)
var avisos: Array = []
## id -> {restante: float (s; 0 con `sin_fin`), sin_fin: bool, rect: Rect2i (sin área = todo el mapa), direccion: Vector2i, t_cambio: float, t_rayo: float}
var dinamicos: Dictionary = {}
var bajo_jugadora: Array = []                ## los estados de la celda de la jugadora en el último `avanzar`
var jugador: Node3D = null                   ## la jugadora (cualquier Node3D con `position`); si falta, la `_jugador` de la maqueta
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var rayos: Array = []                        ## las celdas donde ha caído un rayo (las pruebas)
var _m: Node3D = null
var _nivel: String = ""


## Lo cuelga de la maqueta, lee las zonas de su mapa y devuelve el nodo (como `Zonas3D.montar`).
static func montar(maqueta: Node3D) -> EstadoZona3D:
	var e := EstadoZona3D.new()
	e.name = "EstadoZona3D"
	e._m = maqueta
	e._nivel = String(maqueta.get("nivel"))
	e.leer(e._nivel)
	maqueta.add_child(e)
	return e


func _enter_tree() -> void:
	actual = self
	if not Terreno3D.estados.cambio.is_connected(_al_cambiar_suelo):
		Terreno3D.estados.cambio.connect(_al_cambiar_suelo)


func _exit_tree() -> void:
	if Terreno3D.estados.cambio.is_connected(_al_cambiar_suelo):
		Terreno3D.estados.cambio.disconnect(_al_cambiar_suelo)
	if actual == self:
		actual = null


func _process(delta: float) -> void:
	avanzar(delta)


## --- Leer el mapa ---

func leer(nivel: String) -> void:
	var ruta: String = RUTA_MAPA % nivel
	if not FileAccess.file_exists(ruta):
		return
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return
	leer_texto(f.get_as_text())


## Lo mismo que `leer`, sobre el texto de un mapa (las pruebas lo usan sin archivo).
func leer_texto(texto: String) -> void:
	var n: int = 0
	for bruta in texto.split("\n"):
		var linea: String = bruta.strip_edges()
		n += 1
		if not linea.begins_with(";"):
			continue
		var partes: PackedStringArray = linea.substr(1).strip_edges().split(" ", false)
		if partes.size() < 3 or partes[0] != "zona":
			continue
		var rect: Rect2i = _rect(partes[1])
		if rect.size.x <= 0:
			continue                                  # la zona mala la avisa `Zonas3D`
		var estados: Array = []
		for i in range(3, partes.size()):
			var kv: PackedStringArray = partes[i].split("=", true, 1)
			if kv.size() == 2 and kv[0] == "estado":
				for e in kv[1].split(",", false):
					var id: String = String(e).strip_edges()
					if BD.estado_mundo(id).is_empty():
						_avisar("línea %d: «%s» no es un estado de estados_mundo.tsv (%s)" % [n, id, ", ".join(BD.estados_mundo().keys())])
					elif not estados.has(id):
						estados.append(id)
		agregar(rect, estados)


## Añade una zona (con o sin estados: una sin estados tapa a las que tiene debajo, como las de luz).
func agregar(rect: Rect2i, estados: Array) -> void:
	var lista: Array = []
	for e in estados:
		lista.append(String(e))
	zonas.append({"rect": rect, "estados": lista})


static func _rect(s: String) -> Rect2i:
	var ab: PackedStringArray = s.split("..")
	if ab.size() != 2:
		return Rect2i()
	var a: PackedStringArray = ab[0].split(",")
	var b: PackedStringArray = ab[1].split(",")
	if a.size() != 2 or b.size() != 2 or not (a[0].is_valid_int() and a[1].is_valid_int() and b[0].is_valid_int() and b[1].is_valid_int()):
		return Rect2i()
	var x0: int = mini(a[0].to_int(), b[0].to_int())
	var y0: int = mini(a[1].to_int(), b[1].to_int())
	return Rect2i(x0, y0, absi(b[0].to_int() - a[0].to_int()) + 1, absi(b[1].to_int() - a[1].to_int()) + 1)


func _avisar(t: String) -> void:
	avisos.append(t)
	push_warning("EstadoZona3D: " + t)


## --- Preguntar ---

## Los estados FIJOS de la zona que manda en `celda` (la última declarada que la cubre; [] fuera de todas).
func fijos_en(celda: Vector2i) -> Array:
	for i in range(zonas.size() - 1, -1, -1):
		if (zonas[i]["rect"] as Rect2i).has_point(celda):
			return (zonas[i]["estados"] as Array).duplicate()
	return []


## Todos los estados que valen en `celda`: fijos, dinámicos que la cubren y `veneno` si hay una nube encima. Sin repetidos.
func estados_en(celda: Vector2i) -> Array:
	var r: Array = fijos_en(celda)
	for id in dinamicos.keys():
		var d: Dictionary = dinamicos[id]
		var rect: Rect2i = d["rect"]
		if (rect.size.x <= 0 or rect.has_point(celda)) and not r.has(id):
			r.append(String(id))
	if not r.has("veneno") and NubeVeneno3D.cubre(celda):
		r.append("veneno")
	return r


## `estados_en` del nodo vivo ([] si no hay): es lo que usan `Mundo3D`, `EstadosSuelo3D` y los enemigos sin conocer el nodo.
static func estados_de(celda: Vector2i) -> Array:
	return actual.estados_en(celda) if actual != null and is_instance_valid(actual) else []


## La jugadora: la puesta a mano (`jugador`), la del lanzador del nivel o, si no hay, el modelo `_jugador` de la maqueta. null si no se encuentra.
func _jugadora() -> Node3D:
	if jugador != null and is_instance_valid(jugador):
		return jugador
	var j: Node3D = Botin.jugador_de(self) if is_inside_tree() else null
	if j != null:
		return j
	return _m.get("_jugador") as Node3D if _m != null and is_instance_valid(_m) else null


## La celda de la jugadora (Vector2i(-9999, -9999) si no se sabe dónde está).
func celda_jugadora() -> Vector2i:
	var p: Node3D = _jugadora()
	return Terreno3D.celda_de(p.position) if p != null else Vector2i(-9999, -9999)


## El primer valor distinto de 0 de `columna` entre las filas de `estados` (0 si ninguna lo trae): para lo que no se suma (aguante, vista...).
static func numero(estados: Array, columna: String) -> float:
	for e in estados:
		var v: float = float(BD.estado_mundo(String(e)).get(columna, 0))
		if v != 0.0:
			return v
	return 0.0


## El PRODUCTO de los valores distintos de 0 de `columna` entre las filas de `estados` (1 si ninguna): para los factores `*_x`.
static func producto(estados: Array, columna: String) -> float:
	var r: float = 1.0
	for e in estados:
		var v: float = float(BD.estado_mundo(String(e)).get(columna, 0))
		if v != 0.0:
			r *= v
	return r


## Cuánto dura el hielo en esta celda frente a lo normal (× de la columna `hielo_dura_x`; 1 = lo de siempre). Lo lee `AguaSim3D` para el hielo del agua.
static func factor_hielo_dura(celda: Vector2i) -> float:
	if actual == null or not is_instance_valid(actual):
		return 1.0
	return producto(actual.estados_en(celda), "hielo_dura_x")


## --- Dinámicos ---

## Pone un estado dinámico `segundos` s (0 o menos = el `dura_s` de la tabla; si tampoco lo trae, hasta `quitar`). `opciones`: `rect` (Rect2i; sin él, todo el mapa), `direccion` (Vector2i cardinal, del vendaval).
## Devuelve false si el estado no existe o es `veneno` (el veneno es de las nubes: `NubeVeneno3D`).
func poner(estado: String, segundos: float = 0.0, opciones: Dictionary = {}) -> bool:
	var fila: Dictionary = BD.estado_mundo(estado)
	if fila.is_empty():
		_avisar("poner: «%s» no es un estado de estados_mundo.tsv" % estado)
		return false
	if estado == "veneno":
		_avisar("poner: el veneno es de las nubes (NubeVeneno3D.crear), no de la zona")
		return false
	var dura: float = segundos if segundos > 0.0 else float(fila.get("dura_s", 0))
	var dir: Vector2i = opciones.get("direccion", DIRECCIONES[0])
	var nuevo: bool = not dinamicos.has(estado)
	dinamicos[estado] = {"restante": dura, "sin_fin": dura <= 0.0, "rect": opciones.get("rect", Rect2i()),
		"direccion": dir, "t_cambio": float(fila.get("viento_cambia_s", 0)), "t_rayo": float(fila.get("rayo_cada_s", 0))}
	if nuevo:
		dinamico_cambio.emit(estado, true)
	return true


func quitar(estado: String) -> bool:
	if not dinamicos.erase(estado):
		return false
	dinamico_cambio.emit(estado, false)
	return true


## La dirección del viento (cardinal; Vector2i.ZERO si no hay vendaval en `celda`).
func direccion_viento(celda: Vector2i) -> Vector2i:
	if not dinamicos.has("vendaval") and not fijos_en(celda).has("vendaval"):
		return Vector2i.ZERO
	if dinamicos.has("vendaval"):
		var d: Dictionary = dinamicos["vendaval"]
		var rect: Rect2i = d["rect"]
		if rect.size.x <= 0 or rect.has_point(celda):
			return d["direccion"]
	return DIRECCIONES[0]                      # un vendaval FIJO de zona sopla siempre hacia el este


## El viento de `celda` como velocidad en u/s del mundo (dirección × `empuje` casillas/s × casilla); Vector3.ZERO sin vendaval.
func viento_en(celda: Vector2i) -> Vector3:
	var d: Vector2i = direccion_viento(celda)
	if d == Vector2i.ZERO:
		return Vector3.ZERO
	var emp: float = numero(estados_en(celda), "empuje")
	return Vector3(float(d.x), 0.0, float(d.y)) * emp * Terreno3D.casilla


## --- El reloj ---

func avanzar(dt: float) -> void:
	_avanzar_dinamicos(dt)
	_seguir_a_la_jugadora()


func _avanzar_dinamicos(dt: float) -> void:
	for id in dinamicos.keys():
		var d: Dictionary = dinamicos[id]
		var fila: Dictionary = BD.estado_mundo(String(id))
		if not bool(d["sin_fin"]):
			d["restante"] = float(d["restante"]) - dt
			if float(d["restante"]) <= 0.0:
				dinamicos.erase(id)
				dinamico_cambio.emit(String(id), false)
				continue
		var cambia: float = float(fila.get("viento_cambia_s", 0))
		if cambia > 0.0:
			d["t_cambio"] = float(d["t_cambio"]) - dt
			if float(d["t_cambio"]) <= 0.0:
				d["t_cambio"] = cambia
				d["direccion"] = DIRECCIONES[(DIRECCIONES.find(d["direccion"]) + 1) % DIRECCIONES.size()]
		var cada: float = float(fila.get("rayo_cada_s", 0))
		if cada > 0.0:
			d["t_rayo"] = float(d["t_rayo"]) - dt
			if float(d["t_rayo"]) <= 0.0:
				d["t_rayo"] = cada
				caer_rayo(float(fila.get("rayo_casillas", 6)))


## Avisa cuando la jugadora cambia de zona y deja los estados de ahora en `Sintesis.estados_zona`.
func _seguir_a_la_jugadora() -> void:
	var c: Vector2i = celda_jugadora()
	if c == Vector2i(-9999, -9999):
		return
	var ahora: Array = estados_en(c)
	var entrando: Array = []
	var saliendo: Array = []
	for e in ahora:
		if not bajo_jugadora.has(e):
			entrando.append(e)
	for e in bajo_jugadora:
		if not ahora.has(e):
			saliendo.append(e)
	bajo_jugadora = ahora
	if not entrando.is_empty() or not saliendo.is_empty():
		Sintesis.estados_zona = ahora.duplicate()
		estado_zona_cambio.emit(entrando, saliendo)


## TORMENTA: cae un rayo en una casilla `mojada` al azar a ≤ `alcance` casillas de la jugadora (nada si no hay ninguna). Es la descarga del charco: `electrificada` 0,6 s;
## quien esté en la casilla (la jugadora y los enemigos, que por estar en una casilla mojada están mojados) recibe `DANO_RAYO`. Devuelve la celda, o (-1, -1).
func caer_rayo(alcance: float = 6.0) -> Vector2i:
	var base: Vector2i = celda_jugadora()
	var candidatas: Array = []
	for c in Terreno3D.estados.celdas(EstadosSuelo3D.MOJADA):
		var v: Vector2i = c
		if base == Vector2i(-9999, -9999) or Vector2(v - base).length() <= alcance:
			candidatas.append(v)
	if candidatas.is_empty():
		return Vector2i(-1, -1)
	var c: Vector2i = candidatas[rng.randi() % candidatas.size()]
	Terreno3D.estados.poner(c, EstadosSuelo3D.ELECTRIFICADA, true, 1.0, 0.6)
	rayos.append(c)
	var punto: Vector3 = Terreno3D.centro_de(c, Terreno3D.y_pies(c))
	if Mundo3D.actual != null and is_instance_valid(Mundo3D.actual):
		Mundo3D.actual.avisar_impacto(punto, "rayo", Terreno3D.casilla)
	rayo_cayo.emit(c)
	var j: Node3D = _jugadora()
	if j != null and j.has_method("recibir_dano") and Terreno3D.celda_de(j.position) == c:
		j.call("recibir_dano", DANO_RAYO, punto)
	if is_inside_tree():
		for g in get_tree().get_nodes_in_group("combate3d"):
			if is_instance_valid(g) and not bool(g.get("muerto")) and Terreno3D.celda_de((g as Node3D).position) == c:
				g.call("receive_damage", DANO_RAYO)
				Mundo3D.avisar_reaccion("electrocutado", (g as Node3D).position + Vector3(0.0, 0.8, 0.0), g)
	return c


## El fuego prende una casilla: las nubes de veneno a ≤ `consume_casillas` arden y se consumen en `consume_s` (fila `veneno`).
func _al_cambiar_suelo(c: Vector2i, estado: String, si: bool) -> void:
	if si and estado == EstadosSuelo3D.QUEMADA:
		var fila: Dictionary = BD.estado_mundo("veneno")
		NubeVeneno3D.quemar_en(Terreno3D.centro_de(c), float(fila.get("consume_casillas", 1.5)), float(fila.get("consume_s", 4)))


## --- Aguante (lo comparten la jugadora y los enemigos) ---

## Un paso del aguante. `estados` = los de la zona; `protegido` = {estado: bool} (calor, frio) ya resuelto por quien pregunta; `mojada` = ¿está mojada (el frío pesa `mojada_x`)?
## Devuelve {valor, en_zona (hay calor o frío), baja (está perdiendo aguante), dano (vida a quitar en este paso)}. Sin calor ni frío SIN proteger sube `rellena_s`/s; con
## alguno baja la suma de sus `aguante_s`; a 0 hiere `dano_s` por segundo. Protegerse del estado lo anula (y deja recuperar).
static func paso_aguante(valor: float, dt: float, estados: Array, protegido: Dictionary, mojada: bool) -> Dictionary:
	var tasa: float = 0.0
	var dano_s: float = 0.0
	var rellena: float = RELLENA_DEFECTO
	var en_zona: bool = false
	var baja: bool = false
	for e in ["calor", "frio"]:
		if not estados.has(e):
			continue
		var fila: Dictionary = BD.estado_mundo(e)
		var base: float = float(fila.get("aguante_s", 0))
		if base == 0.0:
			continue
		en_zona = true
		var r: float = float(fila.get("rellena_s", 0))
		if r > 0.0:
			rellena = r
		if bool(protegido.get(e, false)):
			continue
		baja = true
		var x: float = 1.0
		if mojada and float(fila.get("mojada_x", 0)) > 0.0:
			x = float(fila["mojada_x"])
		tasa += base * x
		dano_s = maxf(dano_s, float(fila.get("dano_s", 0)))
	var dano: float = 0.0
	if baja:
		valor = maxf(0.0, valor + tasa * dt)
		if valor <= 0.0:
			dano = dano_s * dt
	else:
		valor = minf(AGUANTE_MAX, valor + rellena * dt)
	return {"valor": valor, "en_zona": en_zona, "baja": baja, "dano": dano}


## ¿Hay un brasero o una fogata ENCENDIDOS a ≤ `casillas` casillas de `p`? Recorre el grupo de reactivos: quien pregunta cada fotograma debe cachearlo `PERIODO_BRASERO`.
static func brasero_cerca(arbol: SceneTree, p: Vector3, casillas: float) -> bool:
	if arbol == null:
		return false
	var radio: float = casillas * Terreno3D.casilla
	for r in arbol.get_nodes_in_group(Reactivo3D.GRUPO_REACTIVO):
		if not is_instance_valid(r) or not (r is Reactivo3D):
			continue
		var re: Reactivo3D = r
		if (re.tipo == "brasero" or re.tipo == "fogata") and re.is_lit:
			var c: Vector3 = Terreno3D.centro_de(re.celda)
			if Vector2(c.x - p.x, c.z - p.z).length() <= radio:
				return true
	return false


## --- Partida ---

## Lo que se guarda en `mundo[<nivel>]`: los dinámicos activos y las nubes vivas con su posición y vida.
func a_dic() -> Dictionary:
	var din: Dictionary = {}
	for id in dinamicos.keys():
		var d: Dictionary = dinamicos[id]
		var rect: Rect2i = d["rect"]
		var dir: Vector2i = d["direccion"]
		din[String(id)] = {"restante": float(d["restante"]), "sin_fin": bool(d["sin_fin"]),
			"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y] if rect.size.x > 0 else [],
			"direccion": [dir.x, dir.y], "t_cambio": float(d["t_cambio"]), "t_rayo": float(d["t_rayo"])}
	var nubes: Array = []
	for n in NubeVeneno3D.vivas:
		if is_instance_valid(n):
			nubes.append((n as NubeVeneno3D).a_dic())
	return {"dinamicos": din, "nubes": nubes}


## Lo contrario: pone los dinámicos y recrea las nubes (cuelgan de la maqueta, o de este nodo si no hay). Un diccionario ilegible no hace nada.
func desde_dic(d: Dictionary) -> void:
	dinamicos.clear()
	var din: Variant = d.get("dinamicos", {})
	if din is Dictionary:
		for id in (din as Dictionary).keys():
			var v: Variant = (din as Dictionary)[id]
			if not (v is Dictionary) or BD.estado_mundo(String(id)).is_empty():
				continue
			var vd: Dictionary = v
			var r: Variant = vd.get("rect", [])
			var dir: Variant = vd.get("direccion", [1, 0])
			dinamicos[String(id)] = {"restante": float(vd.get("restante", 0)), "sin_fin": bool(vd.get("sin_fin", true)),
				"rect": Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])) if r is Array and (r as Array).size() == 4 else Rect2i(),
				"direccion": Vector2i(int(dir[0]), int(dir[1])) if dir is Array and (dir as Array).size() == 2 and DIRECCIONES.has(Vector2i(int(dir[0]), int(dir[1]))) else DIRECCIONES[0],
				"t_cambio": float(vd.get("t_cambio", 0)), "t_rayo": float(vd.get("t_rayo", 0))}
	for n in NubeVeneno3D.vivas.duplicate():
		if is_instance_valid(n):
			(n as NubeVeneno3D).retirar()
	var nubes: Variant = d.get("nubes", [])
	if nubes is Array:
		for nd in (nubes as Array):
			if nd is Dictionary:
				NubeVeneno3D.desde_dic(_m if _m != null and is_instance_valid(_m) else self, nd as Dictionary)
