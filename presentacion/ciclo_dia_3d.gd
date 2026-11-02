class_name CicloDia3D
extends Node

## CICLO DE DÍA Y NOCHE (tercera tanda, lote 3, tarea N; 2/11, «nos ayuda a probar la iluminación»). Una hora del día (`HORA`, 0-24) que avanza sola (`DURACION_DIA_S` s por día; 0 = parado) y que
## tiñe la luz del mapa: la dirección del sol (sale a las 6, cenit a las 13, se pone a las 20), su color y su energía (amanecer naranja, día blanco cálido, atardecer rojizo, noche azul de 0,12),
## el ambiente del WorldEnvironment (color y energía), la niebla si el mapa la usa (más densa y azulada de noche) y una luna tenue (segunda DirectionalLight3D).
##
## MULTIPLICA, NO SUSTITUYE. La luz por zona (LuzZona3D / Zonas3D, del Pipeline) sigue mandando: cada fotograma se toma la luz que TIENE la zona AHORA (`Zonas3D.valores_actuales`, la mezcla en curso incluida;
## sin Zonas3D, la fila `zona_luz` de la escena) y se le multiplica el tinte y la energía de la hora (`transformar`, que es pura y se prueba sin nodos). Así un atardecer sigue siendo más naranja que un bosque,
## a cualquier hora. Corre DESPUÉS de Zonas3D (`process_priority` alto): lo último que escribe en el sol y el ambiente es el ciclo. No toca las luces de braseros ni de hechizos (son OmniLight3D).
##
## DÓNDE SE MONTA. Lo monta la maqueta (PruebaTest2) en los mapas exteriores (nivel que empieza por «Bosque»: Bosque, Bosque_01, Bosque_01_v01; `PREFIJOS_EXTERIOR`), nunca en cueva ni salas; y
## LabHechizos3D lo monta a la fuerza (`forzar`) para mirar la luz desde el panel F3 (`S:HORA`, `S:DURACION_DIA_S`). Un mapa sin DirectionalLight3D no lo monta y lo dice por consola una vez.
## No hay teclas en el juego: es depuración, desde F3 y desde `prueba_dia_noche`. `HORA` es static: el día sigue al cambiar de nivel.
##
## TABLAS. `TABLA_SOL` = [hora, tinte (se multiplica al color del sol), energía (se multiplica)] y `TABLA_AMBIENTE` = [hora, tinte, energía], interpolación lineal entre filas, envuelta a las 24.

static var HORA: float = 10.0                       ## 0-24
static var DURACION_DIA_S: float = 600.0            ## s reales por día (600 = un día en 10 minutos); 0 = la hora no avanza
static var HORA_INICIO: float = 10.0                ## a la que empieza el día al reiniciar (`reiniciar`)
static var CICLO_ACTIVO: bool = true                ## false = ningún mapa lo monta (comparar con la luz de antes)
static var HORA_AMANECER: float = 6.0               ## el sol sale
static var HORA_ATARDECER: float = 20.0             ## el sol se pone
static var HORA_CENIT: float = 13.0                 ## (informativa: es la mitad entre las dos de arriba)
static var ELEVACION_MIN: float = 0.3               ## fracción de la inclinación de la zona que conserva el sol bajo el horizonte (la luz de noche sigue cayendo desde arriba, como la luna)
static var GIRO_POR_HORA: float = 8.0               ## grados que gira el sol alrededor de la vertical por hora (la sombra recorre el suelo)
static var PREFIJOS_EXTERIOR: PackedStringArray = ["Bosque"]
static var TABLA_SOL: Array = [
	[0.0, Color(0.45, 0.60, 1.0), 0.12],
	[3.0, Color(0.45, 0.60, 1.0), 0.12],            # noche azul
	[7.0, Color(1.0, 0.66, 0.46), 0.55],            # amanecer naranja
	[10.0, Color(1.0, 1.0, 1.0), 1.0],              # día: tal cual la zona
	[14.0, Color(1.0, 1.0, 1.0), 1.0],
	[17.0, Color(1.0, 0.92, 0.80), 1.0],            # tarde cálida
	[19.5, Color(1.0, 0.55, 0.40), 0.55],           # atardecer rojizo
	[23.0, Color(0.45, 0.60, 1.0), 0.12],
	[24.0, Color(0.45, 0.60, 1.0), 0.12]]
static var TABLA_AMBIENTE: Array = [
	[0.0, Color(0.55, 0.65, 1.0), 0.40],
	[3.0, Color(0.55, 0.65, 1.0), 0.40],
	[7.0, Color(1.0, 0.82, 0.72), 0.75],
	[10.0, Color(1.0, 1.0, 1.0), 1.0],
	[14.0, Color(1.0, 1.0, 1.0), 1.0],
	[17.0, Color(1.0, 0.92, 0.84), 0.95],
	[19.5, Color(0.95, 0.72, 0.66), 0.70],
	[23.0, Color(0.55, 0.65, 1.0), 0.40],
	[24.0, Color(0.55, 0.65, 1.0), 0.40]]
static var NIEBLA_NOCHE_MAS: float = 0.8            ## de noche la densidad de la niebla sube hasta (1 + esto) veces
static var NIEBLA_NOCHE_TINTE: Color = Color(0.45, 0.60, 1.0)
static var LUNA_ACTIVA: bool = true
static var LUNA_COLOR: Color = Color(0.62, 0.72, 1.0)
static var LUNA_ENERGIA: float = 0.10               ## energía de la luna con la noche cerrada
static var LUNA_INCLINACION: float = -40.0

static var _avisado: bool = false

var horas_avanzadas: float = 0.0                    ## horas que ha avanzado este nodo sin envolver (las pruebas)
var valores_aplicados: Dictionary = {}              ## lo último que escribió en el sol y el ambiente
var _m: Node3D = null
var _sol: DirectionalLight3D = null
var _env: Environment = null
var _zonas: Node = null
var _luna: DirectionalLight3D = null
var _niebla_base_d: float = -1.0
var _niebla_base_c: Color = Color.WHITE
var _niebla_escrita_d: float = -1.0


## Monta el ciclo en la maqueta si es un mapa exterior (o con `forzar`) y tiene sol. Devuelve el nodo, o null si no lo monta. Idempotente.
static func montar(maqueta: Node3D, forzar: bool = false) -> CicloDia3D:
	if not CICLO_ACTIVO or maqueta == null:
		return null
	var previo: Node = maqueta.get_node_or_null("CicloDia3D")
	if previo is CicloDia3D:
		return previo as CicloDia3D
	if not forzar and not es_exterior(maqueta):
		return null
	var sol: Variant = maqueta.get("_sol")
	if not (sol is DirectionalLight3D):
		if not _avisado:
			_avisado = true
			print("CicloDia3D: el mapa «%s» no tiene DirectionalLight3D; no se monta el ciclo de día y noche." % str(maqueta.get("nivel")))
		return null
	var c := CicloDia3D.new()
	c.name = "CicloDia3D"
	c._m = maqueta
	c._sol = sol as DirectionalLight3D
	c._env = maqueta.get("_env") as Environment
	maqueta.add_child(c)
	return c


## ¿Es un mapa exterior? Por el nombre del nivel (`PREFIJOS_EXTERIOR`) y nunca con estilo «cueva».
static func es_exterior(maqueta: Node) -> bool:
	if str(maqueta.get("estilo")) == "cueva":
		return false
	var nivel: String = str(maqueta.get("nivel"))
	for p in PREFIJOS_EXTERIOR:
		if nivel.begins_with(p):
			return true
	return false


static func reiniciar() -> void:
	HORA = HORA_INICIO


## De noche el sol está bajo el horizonte: antes del amanecer o desde el atardecer.
static func es_noche() -> bool:
	return HORA < HORA_AMANECER or HORA >= HORA_ATARDECER


## 0 de día, 1 con la noche cerrada (sigue la energía de la tabla del sol: 0,55 o más = 0; 0,12 = 1). Mueve la luna, la niebla y los grillos.
static func noche_k(h: float) -> float:
	var e: float = float(_fila(TABLA_SOL, h)[1])
	return clampf((0.55 - e) / (0.55 - 0.12), 0.0, 1.0)


## Fracción de la inclinación de la zona a la hora `h`: sin(π·t) entre el amanecer y el atardecer (1 a mitad: las 13), `ELEVACION_MIN` fuera.
static func elevacion(h: float) -> float:
	h = fposmod(h, 24.0)
	var f: float = 0.0
	if h > HORA_AMANECER and h < HORA_ATARDECER:
		f = sin(PI * (h - HORA_AMANECER) / (HORA_ATARDECER - HORA_AMANECER))
	return lerpf(ELEVACION_MIN, 1.0, f)


## La fila interpolada [tinte, energía] de una tabla a la hora `h`.
static func _fila(tabla: Array, h: float) -> Array:
	h = fposmod(h, 24.0)
	for i in range(tabla.size() - 1):
		var a: Array = tabla[i]
		var b: Array = tabla[i + 1]
		if h >= float(a[0]) and h <= float(b[0]):
			var t: float = (h - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return [(a[1] as Color).lerp(b[1] as Color, t), lerpf(float(a[2]), float(b[2]), t)]
	return [(tabla[0] as Array)[1], (tabla[0] as Array)[2]]


static func _por(c: Color, tinte: Color) -> Color:
	return Color(c.r * tinte.r, c.g * tinte.g, c.b * tinte.b, c.a)


## La luz de la hora `h` encima de una luz de zona (`LuzZona3D.valores`): MULTIPLICA el color y la energía del sol y el ambiente, y fija la inclinación y el giro del sol. Pura (no toca nodos).
static func transformar(base: Dictionary, h: float) -> Dictionary:
	var s: Array = _fila(TABLA_SOL, h)
	var a: Array = _fila(TABLA_AMBIENTE, h)
	var r: Dictionary = base.duplicate()
	r["sol_color"] = _por(base["sol_color"] as Color, s[0] as Color)
	r["sol_energia"] = float(base["sol_energia"]) * float(s[1])
	r["sol_pitch"] = -absf(float(base["sol_pitch"])) * elevacion(h)
	r["sol_yaw"] = float(base["sol_yaw"]) + (fposmod(h, 24.0) - HORA_CENIT) * GIRO_POR_HORA
	r["ambiente_arriba"] = _por(base["ambiente_arriba"] as Color, a[0] as Color)
	r["ambiente_abajo"] = _por(base["ambiente_abajo"] as Color, a[0] as Color)
	r["ambiente_energia"] = float(base["ambiente_energia"]) * float(a[1])
	return r


func _init() -> void:
	process_priority = 100                          # después de Zonas3D (0): lo último que escribe en el sol y el ambiente es el ciclo


func _ready() -> void:
	_zonas = _m.get_node_or_null("Zonas3D") if _m != null else null
	if LUNA_ACTIVA and _m != null:
		_luna = DirectionalLight3D.new()
		_luna.name = "Luna"
		_luna.shadow_enabled = false
		_luna.light_color = LUNA_COLOR
		_luna.light_energy = 0.0
		_luna.visible = false
		_m.add_child(_luna)
	aplicar()


func _process(delta: float) -> void:
	if DURACION_DIA_S > 0.0:
		var dh: float = 24.0 * delta / DURACION_DIA_S
		HORA = fposmod(HORA + dh, 24.0)
		horas_avanzadas += dh
	aplicar()


## Pone en el sol, el ambiente, la niebla y la luna la luz de `HORA` encima de la de la zona de ahora.
func aplicar() -> void:
	if _sol == null or not is_instance_valid(_sol):
		return
	var base: Dictionary = {}
	if _zonas != null and is_instance_valid(_zonas) and _zonas.has_method("valores_actuales"):
		base = _zonas.call("valores_actuales")
	elif _m != null:
		base = LuzZona3D.valores(String(_m.get("zona_luz")))
	if base.is_empty():
		base = LuzZona3D.valores("bosque")
	if _env != null and _env.sky == null:
		LuzZona3D.ambiente_dos_colores(_env, base["ambiente_arriba"], base["ambiente_abajo"], float(base["ambiente_energia"]))
	valores_aplicados = transformar(base, HORA)
	LuzZona3D.aplicar_valores(_env, _sol, valores_aplicados)
	_aplicar_niebla()
	_aplicar_luna()


func _aplicar_niebla() -> void:
	if _env == null or not _env.fog_enabled:
		return
	if _niebla_base_d < 0.0 or not is_equal_approx(_env.fog_density, _niebla_escrita_d):
		_niebla_base_d = _env.fog_density           # el mapa (u otro) cambió la niebla: esa es la nueva base
		_niebla_base_c = _env.fog_light_color
	var k: float = noche_k(HORA)
	_env.fog_density = _niebla_base_d * (1.0 + NIEBLA_NOCHE_MAS * k)
	_env.fog_light_color = _niebla_base_c.lerp(_por(_niebla_base_c, NIEBLA_NOCHE_TINTE), k)
	_niebla_escrita_d = _env.fog_density


func _aplicar_luna() -> void:
	if _luna == null or not is_instance_valid(_luna):
		return
	var e: float = LUNA_ENERGIA * noche_k(HORA) if LUNA_ACTIVA else 0.0
	_luna.light_energy = e
	_luna.light_color = LUNA_COLOR
	_luna.visible = e > 0.001
	_luna.rotation_degrees = Vector3(LUNA_INCLINACION, float(valores_aplicados.get("sol_yaw", 0.0)) + 180.0, 0.0)


func _exit_tree() -> void:
	if _luna != null and is_instance_valid(_luna) and not _luna.is_queued_for_deletion():
		_luna.queue_free()
