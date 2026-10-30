class_name Consumibles
extends RefCounted

## LOS CONSUMIBLES EQUIPADOS (24/10, Juego; referencia «Consumible equipado» de Echoes of Wisdom): Q usa el que llevas equipado, R pasa al siguiente que tengas.
## No dibuja nada (lo pinta `HudEoW`) ni toca el script del jugador más allá de lo que éste ya ofrece en público: `vida`, `curar()`, `usar_pocion()` y `tinta`.
## Los números de cada efecto NO viven aquí sino en `Objetos.DATOS[id]["efecto"]` (un solo sitio; el texto de `desc` los repite, hay que cambiar los dos).
##
## LOS CUATRO:
##   pocion             Poción de vida     cura 40 al terminar de beber (1,5 s quieto, lo hace `Jugador3D.usar_pocion` como siempre; un golpe la interrumpe)
##   tonico_tinta       Tónico de tinta    recarga 1 frasco de reserva de tinta vacío (`Tinta.recargar_frasco`); inútil con los frascos llenos
##   balsamo_protector  Bálsamo protector  durante 20 s el PRÓXIMO golpe se absorbe entero (`absorber`, lo llama `Jugador3D.recibir_dano`); si no llega, se pierde
##   infusion_brezo     Infusión de brezo  regenera 3 de vida por segundo durante 12 s (36 en total), a golpes de `TICK_REGEN_S`; un golpe no la corta
## F3 (29/10): los otros consumibles de la tabla (`objetos.tsv`, uso = equipar) por la columna `efecto`, SIN un `match` por id:
##   pocion_grande      cura 80 (lo bebe el jugador igual que la poción: `usar_pocion(id)`)      antidoto  `cura_estado=veneno;inmune=veneno;dura=60`
##   frescor / abrigo   `resiste=calor|frio;dura=90`
## Quitar un estado (`cura_estado`) llama a `Jugador3D.curar_estado`. Las protecciones (`inmune`, `resiste`) viven en `inmunidades` / `resistencias`: estado -> segundos
## que quedan, y `actualizar(delta)` las cuenta atrás. Son ESTÁTICAS (un solo reloj para toda la partida, como `Estado`): F4 las lee con `Consumibles.protegido(estado)` y
## `Consumibles.resiste(estado)` desde donde haga falta (el calor, el frío, el veneno). Los pigmentos (uso = pigmento) NO pasan por aquí: ver `aplicar_pigmento`.
## Usar uno gasta una unidad de la mochila (`Estado.quitar`); si no se puede (vida llena, frascos llenos, ya activo...) NO se gasta y se dice por qué.
## El equipado vive en `Estado.consumible_equipado` (viaja con la partida). Al acabarse, el equipado pasa solo al siguiente que quede; si no queda ninguno
## se queda el último a cero (círculo apagado) hasta que consigas más.

signal cambiado                                   ## equipado, cantidades o efectos activos distintos (para repintar el HUD)
signal aviso(texto: String, color: Color)         ## algo que decirle al jugador («Vida llena», «Bálsamo activo»…)
signal usado(id: String)                          ## se ha gastado una unidad de `id`

const TICK_REGEN_S: float = 0.5                   ## cada cuánto cae un trozo de la infusión (tasa × TICK)
const COLOR_OK: Color = Color(0.7, 1.0, 0.8)
const COLOR_NO: Color = Color(1.0, 0.75, 0.55)

var jugador: Node = null                          ## el Jugador3D (o algo con `vida`, `tinta`, `curar` y `usar_pocion`)
var partida: Estado = null                        ## null = el de la partida (`Estado.i()`); las pruebas inyectan uno propio
var escudo_t: float = 0.0                         ## s que le quedan al bálsamo (0 = sin escudo)
var regen_t: float = 0.0                          ## s que le quedan a la infusión
var regen_tasa: float = 0.0                       ## vida por segundo de la infusión activa
var _acum: float = 0.0
## F3: estado ("veneno", "calor", "frio") -> segundos que le quedan a la protección. `inmunidades` = no te afecta; `resistencias` = lo aguantas (lo que decida F4: más tiempo, menos daño).
static var inmunidades: Dictionary = {}
static var resistencias: Dictionary = {}


func _est() -> Estado:
	return partida if partida != null else Estado.i()


func _vida() -> float:
	return float(jugador.get("vida")) if jugador != null else 0.0


func _vida_max() -> float:
	return _est().vida_max


## El equipado ("" si no hay ninguno o es un id que ya no existe).
func equipado() -> String:
	var id: String = _est().consumible_equipado
	return id if Objetos.es_consumible(id) else ""


func cantidad(id: String) -> int:
	return _est().cuenta(id)


## Los consumibles de los que queda alguna unidad, en el orden de `Objetos.CONSUMIBLES` (el de R).
func disponibles() -> Array:
	var r: Array = []
	for id in Objetos.CONSUMIBLES:
		if cantidad(String(id)) > 0:
			r.append(String(id))
	return r


func equipar(id: String) -> bool:
	if not Objetos.es_consumible(id) or cantidad(id) <= 0:
		return false
	if _est().consumible_equipado != id:
		_est().consumible_equipado = id
		cambiado.emit()
		_est().cambiado.emit()       # el HUD y el menú (otra instancia de Consumibles) se enteran por aquí
	return true


## R: el siguiente consumible que tengas tras el equipado (da la vuelta). Devuelve el nuevo equipado ("" si no hay ninguno).
func siguiente() -> String:
	var disp: Array = disponibles()
	if disp.is_empty():
		return ""
	var i: int = disp.find(equipado())
	var nuevo: String = String(disp[(i + 1) % disp.size()]) if i >= 0 else String(disp[0])
	equipar(nuevo)
	return nuevo


## Por qué NO se puede usar `id` ahora ("" = se puede). Es lo que se le dice al jugador.
func motivo_no(id: String) -> String:
	if jugador == null or bool(jugador.get("muerto")):
		return "Ahora no"
	if cantidad(id) <= 0:
		return "No te quedan"
	match id:
		"pocion", "pocion_grande":
			if _vida() >= _vida_max() - 0.01:
				return "Ya tienes la vida llena"
		"infusion_brezo":
			if _vida() >= _vida_max() - 0.01:
				return "Ya tienes la vida llena"
			if regen_t > 0.0:
				return "Ya estás regenerando"
		"tonico_tinta":
			var t: Tinta = jugador.get("tinta") as Tinta
			if t == null or t.frascos >= t.maxima_frascos():
				return "Todos los frascos están llenos"
		"balsamo_protector":
			if escudo_t > 0.0:
				return "Ya llevas el bálsamo puesto"
		_:
			var ef: Dictionary = Objetos.efecto(id)
			if ef.has("inmune") and protegido(String(ef["inmune"])) and not ef.has("cura_estado"):
				return "Ya estás protegido"
			if ef.has("resiste") and resiste(String(ef["resiste"])):
				return "Ya aguantas eso"
			if ef.has("inmune") and ef.has("cura_estado") and protegido(String(ef["inmune"])) and not tiene_estado(String(ef["cura_estado"])):
				return "Ya estás protegido"
	return ""


## Q: usa el equipado. Devuelve si se gastó una unidad.
func usar_equipado() -> bool:
	var id: String = equipado()
	if id == "":
		aviso.emit("No llevas ningún consumible", COLOR_NO)
		return false
	return usar(id)


## Usa `id` si se puede (y gasta una unidad); si no, avisa del motivo y no gasta nada.
func usar(id: String) -> bool:
	var motivo: String = motivo_no(id)
	if motivo != "":
		aviso.emit(motivo, COLOR_NO)
		return false
	var ef: Dictionary = Objetos.efecto(id)
	match id:
		"pocion", "pocion_grande":
			# Beber lo hace el jugador (animación, 1,5 s, cura y gasta la poción al terminar). Si está ocupado (rodando, lanzando...) dice que no.
			# La poción de siempre se llama sin argumentos (los jugadores de mentira de las pruebas no los tienen); la grande dice cuál es.
			var bebe: bool = bool(jugador.call("usar_pocion")) if id == "pocion" else bool(jugador.call("usar_pocion", id))
			if not bebe:
				aviso.emit("Ahora no puedes beber", COLOR_NO)
				return false
			cambiado.emit()
			return true       # la unidad se gasta al acabar de beber (Jugador3D._terminar_beber): `HudEoW` lo ve por `Estado.cambiado` y llama a `al_cambiar_mochila`
		"tonico_tinta":
			_est().quitar(id)
			(jugador.get("tinta") as Tinta).recargar_frasco(int(ef.get("frascos", 1)))
			aviso.emit("Frasco de tinta recargado", Color(0.55, 0.75, 1.0))
		"balsamo_protector":
			_est().quitar(id)
			escudo_t = float(ef.get("dura", 20.0))
			aviso.emit("Bálsamo protector: absorbe el próximo golpe", Color(1.0, 0.85, 0.45))
		"infusion_brezo":
			_est().quitar(id)
			regen_t = float(ef.get("dura", 12.0))
			regen_tasa = float(ef.get("tasa", 3.0))
			_acum = 0.0
			aviso.emit("Infusión de brezo: te regeneras", Color(0.85, 0.65, 1.0))
		_:
			if not _efecto_generico(id, ef):
				aviso.emit("Eso no se usa así", COLOR_NO)
				return false
	_tras_gastar(id)
	return true


## Los consumibles de la tabla que no tienen caso propio: `cura_estado`, `inmune` y `resiste` (con `dura`). Gasta la unidad. false si el efecto no trae nada de eso.
func _efecto_generico(id: String, ef: Dictionary) -> bool:
	if not (ef.has("cura_estado") or ef.has("inmune") or ef.has("resiste")):
		return false
	_est().quitar(id)
	var dura: float = float(ef.get("dura", 60.0))
	if ef.has("cura_estado"):
		curar_estado(String(ef["cura_estado"]))
	if ef.has("inmune"):
		inmunidades[String(ef["inmune"])] = dura
	if ef.has("resiste"):
		resistencias[String(ef["resiste"])] = dura
	aviso.emit("%s: %d s" % [String(Objetos.DATOS.get(id, {}).get("nombre", id)), int(dura)], Color(0.65, 0.95, 0.7))
	return true


## Quita el estado (hoy solo el veneno) a la jugadora. El gancho de F4: si el jugador tiene `curar_estado`, lo llama. Devuelve si había algo que quitar.
func curar_estado(estado: String) -> bool:
	if jugador != null and jugador.has_method("curar_estado"):
		return bool(jugador.call("curar_estado", estado))
	return false


## ¿Tiene la jugadora ese estado ahora? (para no gastar un antídoto en balde si además ya está protegida).
func tiene_estado(estado: String) -> bool:
	return jugador != null and jugador.has_method("tiene_estado") and bool(jugador.call("tiene_estado", estado))


## ¿Es inmune a `estado` ahora mismo por un consumible? (la ropa se pregunta aparte: `Ropa3D.inmune_ids`).
static func protegido(estado: String) -> bool:
	return float(inmunidades.get(estado, 0.0)) > 0.0


## ¿Aguanta `estado`? Vale una resistencia o una inmunidad (quien es inmune también aguanta).
static func resiste(estado: String) -> bool:
	return float(resistencias.get(estado, 0.0)) > 0.0 or protegido(estado)


## Segundos que le quedan a la protección contra `estado` (la mayor de las dos; 0 si ninguna).
static func tiempo_proteccion(estado: String) -> float:
	return maxf(float(inmunidades.get(estado, 0.0)), float(resistencias.get(estado, 0.0)))


static func limpiar_protecciones() -> void:
	inmunidades = {}
	resistencias = {}


## Gasta una unidad de un objeto de uso «pigmento» y activa su pigmento en la tinta de la jugadora. Mismo contrato que `Sintesis.aplicar_pigmento`.
func aplicar_pigmento(objeto: String) -> bool:
	var t: Tinta = jugador.get("tinta") as Tinta if jugador != null else null
	var ok: bool = Sintesis.aplicar_pigmento(objeto, t, _est())
	if ok:
		aviso.emit("Pigmento: %s" % String(Objetos.DATOS.get(objeto, {}).get("nombre", objeto)), Color(0.6, 0.8, 1.0))
		cambiado.emit()
	return ok


func _tras_gastar(id: String) -> void:
	usado.emit(id)
	_ajustar_equipado()
	cambiado.emit()


## Si el equipado se ha acabado y queda otro, pasa a él (si no queda ninguno se queda el último, a cero).
func _ajustar_equipado() -> void:
	var eq: String = equipado()
	if eq == "" or cantidad(eq) <= 0:
		var disp: Array = disponibles()
		if not disp.is_empty():
			equipar(String(disp[0]) if eq == "" else String(disp[(maxi(disp.find(eq), -1) + 1) % disp.size()]))


## La mochila ha cambiado (se bebió una poción, se cogió algo...): reajusta el equipado y repinta. Lo llama `HudEoW` al oír `Estado.cambiado`.
func al_cambiar_mochila() -> void:
	_ajustar_equipado()
	cambiado.emit()


## El bálsamo: si está activo, el próximo golpe (de `cantidad` > 0) se absorbe entero y el escudo se acaba. Devuelve true si absorbió.
func absorber(cant: float) -> bool:
	if escudo_t <= 0.0 or cant <= 0.0:
		return false
	escudo_t = 0.0
	aviso.emit("¡El bálsamo ha absorbido el golpe!", Color(1.0, 0.85, 0.45))
	cambiado.emit()
	return true


static func _contar_atras(d: Dictionary, delta: float) -> void:
	for k in d.keys():
		var t: float = float(d[k]) - delta
		if t <= 0.0:
			d.erase(k)
		else:
			d[k] = t


func escudo_activo() -> bool:
	return escudo_t > 0.0


func regen_activa() -> bool:
	return regen_t > 0.0


## Avanza el reloj del bálsamo y de la infusión (cada `TICK_REGEN_S` cae un trozo de vida con `curar`).
func actualizar(delta: float) -> void:
	_contar_atras(inmunidades, delta)
	_contar_atras(resistencias, delta)
	if escudo_t > 0.0:
		escudo_t = maxf(0.0, escudo_t - delta)
		if escudo_t <= 0.0:
			aviso.emit("El bálsamo se ha agotado", COLOR_NO)
			cambiado.emit()
	if regen_t > 0.0 and jugador != null:
		var paso: float = minf(delta, regen_t)
		regen_t -= paso
		_acum += paso
		while _acum >= TICK_REGEN_S - 1e-6 or (regen_t <= 0.0 and _acum > 1e-6):
			var dt: float = minf(_acum, TICK_REGEN_S)
			_acum -= dt
			if not bool(jugador.get("muerto")):
				jugador.call("curar", regen_tasa * dt)
		if regen_t <= 0.0:
			_acum = 0.0
			regen_tasa = 0.0
			cambiado.emit()
