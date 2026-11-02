class_name Estadisticas
extends RefCounted

## ESTADÍSTICAS DE LA PARTIDA (2/11, gamefeel tercera tanda, A3). Cuenta lo que ya ocurre, sin tocar ninguna regla: enemigos caídos por tipo, hechizos lanzados por elemento, daño hecho y recibido,
## oro ganado, muertes, cofres abiertos y segundos jugados. Hay dos juegos de cifras: `total` (la partida; viaja en la sección `estadisticas` del archivo, versión 3) y `por_nivel` (lo del nivel de ahora;
## `cerrar_nivel()` lo entrega y lo vacía, y es lo que enseña el resumen de nivel, A4).
##
## DE DÓNDE SALE CADA CIFRA (`conectar(mundo, jugador, lanzador)`, una vez desde `Jugador3D.montar`):
##   · enemigos  ← `Estado.enemigo_muerto(pos, id)`      · hechizos ← `Lanzador3D.lanzado(elemento, …)`      · muertes ← `Jugador3D.murio`
##   · dano_recibido ← `Jugador3D.dano_recibido(cantidad)` (señal nueva, tras defensa y barrera)      · cofres ← `Mundo3D.logro("cofre_abierto")`
##   · dano_hecho ← `Estadisticas.dano_hecho(x)`, que llaman `Combate3D.receive_damage` y `Golem3D._aplicar_dano` con el daño que de verdad quita (no pasa de la vida que quedaba)
##   · oro_ganado ← `Estado.cambiado`: cuando el oro SUBE respecto a la última vez que se miró (no hay señal de oro; gastar no resta)
## `segundos` es tiempo de pared desde `reiniciar()`/`desde_dic()` (el mismo criterio que `Partida.segundos_jugados`).

const CLAVES_NUM: PackedStringArray = ["dano_hecho", "dano_recibido", "oro_ganado", "muertes", "cofres"]

static var total: Dictionary = vacio()
static var por_nivel: Dictionary = vacio()
static var _seg_base_total: float = 0.0
static var _t0_total_ms: int = 0
static var _t0_nivel_ms: int = 0
static var _oro_visto: int = -1


## Un juego de cifras a cero.
static func vacio() -> Dictionary:
	return {"enemigos": {}, "hechizos": {}, "dano_hecho": 0.0, "dano_recibido": 0.0, "oro_ganado": 0, "muertes": 0, "cofres": 0, "segundos": 0.0}


## Todo a cero (Nueva partida y las pruebas).
static func reiniciar() -> void:
	total = vacio()
	por_nivel = vacio()
	_seg_base_total = 0.0
	_t0_total_ms = Time.get_ticks_msec()
	_t0_nivel_ms = _t0_total_ms
	_oro_visto = -1


# ---------------------------------------------------------------------------------------------------------------------
#  Contar
# ---------------------------------------------------------------------------------------------------------------------

static func contar_enemigo(id: String) -> void:
	for d in [total, por_nivel]:
		var e: Dictionary = d["enemigos"]
		e[id] = int(e.get(id, 0)) + 1


static func contar_hechizo(elemento: String) -> void:
	var el: String = elemento if elemento != "" else "sin_elemento"
	for d in [total, por_nivel]:
		var h: Dictionary = d["hechizos"]
		h[el] = int(h.get(el, 0)) + 1


## Daño que de verdad ha quitado la jugadora a un enemigo.
static func dano_hecho(cantidad: float) -> void:
	if cantidad > 0.0:
		_sumar("dano_hecho", cantidad)


static func dano_recibido(cantidad: float) -> void:
	if cantidad > 0.0:
		_sumar("dano_recibido", cantidad)


static func contar_oro(n: int) -> void:
	if n > 0:
		_sumar("oro_ganado", n)


static func contar_muerte() -> void:
	_sumar("muertes", 1)


static func contar_cofre() -> void:
	_sumar("cofres", 1)


static func _sumar(clave: String, v: float) -> void:
	for d in [total, por_nivel]:
		d[clave] = (float(d[clave]) + v) if clave.begins_with("dano") else (int(d[clave]) + int(v))


# ---------------------------------------------------------------------------------------------------------------------
#  Tiempo, nivel y guardado
# ---------------------------------------------------------------------------------------------------------------------

static func segundos_total() -> float:
	return _seg_base_total + float(Time.get_ticks_msec() - _t0_total_ms) / 1000.0


static func segundos_nivel() -> float:
	return float(Time.get_ticks_msec() - _t0_nivel_ms) / 1000.0


## Lo que se escribe en la sección `estadisticas` de la partida.
static func a_dic() -> Dictionary:
	var d: Dictionary = total.duplicate(true)
	d["segundos"] = segundos_total()
	return d


## Lo contrario. Una sección ausente o rota (un archivo v2) deja todo a cero.
static func desde_dic(d: Variant) -> void:
	reiniciar()
	if not (d is Dictionary):
		return
	var s: Dictionary = d
	for k in ["enemigos", "hechizos"]:
		var origen: Variant = s.get(k, {})
		if origen is Dictionary:
			for clave in (origen as Dictionary).keys():
				total[k][String(clave)] = int((origen as Dictionary)[clave])
	total["dano_hecho"] = float(s.get("dano_hecho", 0.0))
	total["dano_recibido"] = float(s.get("dano_recibido", 0.0))
	for k in ["oro_ganado", "muertes", "cofres"]:
		total[k] = int(s.get(k, 0))
	total["segundos"] = float(s.get("segundos", 0.0))
	_seg_base_total = float(total["segundos"])


## Entrega las cifras del nivel que se acaba (con sus segundos) y empieza otro juego vacío. Lo llama `Niveles` al viajar.
static func cerrar_nivel() -> Dictionary:
	var d: Dictionary = por_nivel.duplicate(true)
	d["segundos"] = segundos_nivel()
	por_nivel = vacio()
	_t0_nivel_ms = Time.get_ticks_msec()
	return d


## ¿Ha pasado algo contable? (el tiempo solo no cuenta: un laboratorio no enseña resumen).
static func hay_actividad(d: Dictionary) -> bool:
	return total_enemigos(d) > 0 or total_hechizos(d) > 0 or float(d.get("dano_hecho", 0.0)) > 0.0 or float(d.get("dano_recibido", 0.0)) > 0.0 \
		or int(d.get("oro_ganado", 0)) > 0 or int(d.get("muertes", 0)) > 0 or int(d.get("cofres", 0)) > 0


static func total_enemigos(d: Dictionary) -> int:
	var n: int = 0
	for k in (d.get("enemigos", {}) as Dictionary):
		n += int((d["enemigos"] as Dictionary)[k])
	return n


static func total_hechizos(d: Dictionary) -> int:
	var n: int = 0
	for k in (d.get("hechizos", {}) as Dictionary):
		n += int((d["hechizos"] as Dictionary)[k])
	return n


## «1 h 05 min», «12 min 07 s», «45 s».
static func texto_tiempo(seg: float) -> String:
	var s: int = int(seg)
	if s >= 3600:
		return "%d h %02d min" % [s / 3600, (s % 3600) / 60]
	if s >= 60:
		return "%d min %02d s" % [s / 60, s % 60]
	return "%d s" % s


## Las líneas [[etiqueta, valor], …] que enseñan la pestaña y el resumen (en el orden del documento).
static func filas(d: Dictionary) -> Array:
	var f: Array = []
	f.append(["Tiempo jugado", texto_tiempo(float(d.get("segundos", 0.0)))])
	f.append(["Enemigos vencidos", str(total_enemigos(d))])
	f.append(["Hechizos lanzados", str(total_hechizos(d))])
	f.append(["Daño hecho", str(int(round(float(d.get("dano_hecho", 0.0)))))])
	f.append(["Daño recibido", str(int(round(float(d.get("dano_recibido", 0.0)))))])
	f.append(["Oro ganado", str(int(d.get("oro_ganado", 0)))])
	f.append(["Cofres abiertos", str(int(d.get("cofres", 0)))])
	f.append(["Veces caída", str(int(d.get("muertes", 0)))])
	return f


# ---------------------------------------------------------------------------------------------------------------------
#  Conectar
# ---------------------------------------------------------------------------------------------------------------------

## Engancha las señales que ya existen. Se llama una vez por nivel desde `Jugador3D.montar`. Lo que cuelga de nodos del nivel (jugadora, lanzador, mundo) se suelta solo al liberarse;
## lo de los singletons (`Estado`) se comprueba con `is_connected` para no duplicar.
static func conectar(mundo: Node, jugador: Node, lanzador: Node) -> void:
	var est: Estado = Estado.i()
	if not est.enemigo_muerto.is_connected(_al_morir_enemigo):
		est.enemigo_muerto.connect(_al_morir_enemigo)
	if not est.cambiado.is_connected(_al_cambiar_estado):
		est.cambiado.connect(_al_cambiar_estado)
	_oro_visto = est.oro
	if lanzador != null and lanzador.has_signal("lanzado") and not lanzador.is_connected("lanzado", _al_lanzar):
		lanzador.connect("lanzado", _al_lanzar)
	if jugador != null:
		if jugador.has_signal("murio") and not jugador.is_connected("murio", contar_muerte):
			jugador.connect("murio", contar_muerte)
		if jugador.has_signal("dano_recibido") and not jugador.is_connected("dano_recibido", dano_recibido):
			jugador.connect("dano_recibido", dano_recibido)
	if mundo != null and mundo.has_signal("logro") and not mundo.is_connected("logro", _al_logro):
		mundo.connect("logro", _al_logro)


static func _al_morir_enemigo(_pos: Vector2, id: String) -> void:
	contar_enemigo(id)


static func _al_cambiar_estado() -> void:
	var oro: int = Estado.i().oro
	if _oro_visto >= 0 and oro > _oro_visto:
		contar_oro(oro - _oro_visto)
	_oro_visto = oro


static func _al_lanzar(elemento: String, _forma: String, _manifestaciones: int) -> void:
	contar_hechizo(elemento)


static func _al_logro(nombre: String, _punto: Vector3, _nodo: Node) -> void:
	if nombre == "cofre_abierto":
		contar_cofre()
