extends SceneTree
## Prueba del RIESGO de la entrada 505 del diario (16/11): la marca `hz` (agua de hechizo) viaja con el agua. ¿Se le pega al agua
## de un cauce, de un estanque o de una tinaja y la deja frenada al 55 % (HZ_FRENO) o bebida por el suelo (HZ_PELICULA)?
##   godot --headless --path . --script res://herramientas/prueba_agua_hz_cauce.gd
## Cada caso corre DOS simulaciones iguales, una de control (sin hechizo) y otra a la que se le echa agua de hechizo al lado, y
## compara lo que hace el agua del puzle en las dos. El agua de hechizo puede sumar su volumen, pero NO cambiar cómo corre la otra.
##   1. CAUCE con manantial y desagüe: el perfil de profundidad, pasado el hechizo, es el del control; no quedan trocitos marcados.
##   2. ESTANQUE quieto tras una presa: al abrir la presa, el agua llega al final a la vez que en el control.
##   3. TINAJA que se abre sobre un canal seco donde antes cayó un hechizo: el frente llega a la vez que en el control.
## Solo AguaSim3D (sin escena ni ventana). Imprime FALLOS: n.

const S: float = 2.3
const DT: float = 1.0 / 60.0
var _fallos: int = 0


func _init() -> void:
	_cauce()
	_estanque()
	_tinaja()
	print("FALLOS: %d" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _ok(nombre: String, bien: bool, info: String = "") -> void:
	print(("OK    " if bien else "FALLO ") + nombre + "  " + info)
	if not bien:
		_fallos += 1


func _correr(a: AguaSim3D, segundos: float) -> void:
	for _i in range(int(segundos / DT)):
		a.paso(DT)


func _centro(c: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3((float(c.x) + 0.5) * S, y, (float(c.y) + 0.5) * S)


## Lo que hace `HechizoVivo._materia_liquido` en suelo sin manantial: marca la casilla y echa el agua.
func _hechizo(a: AguaSim3D, c: Vector2i, volumen: float) -> void:
	a.marcar_hechizo(c)
	a.anadir(_centro(c), volumen, S * 0.45)


## Trocitos marcados `hz` que aún tienen agua, en las casillas de la fila `fila` entre x0 y x1.
func _marcados(a: AguaSim3D, fila: int, x0: int, x1: int) -> int:
	var n: int = 0
	for x in range(x0, x1 + 1):
		for i in a._trozos(Vector2i(x, fila)):
			if a.hz[i] == 1 and a.prof[i] > AguaSim3D.PROF_MIN:
				n += 1
	return n


## Segundos hasta que la casilla `c` es agua para el juego (o `tope` si no llega).
func _llega(a: AguaSim3D, c: Vector2i, tope: float) -> float:
	var t: float = 0.0
	while t < tope:
		a.paso(DT)
		t += DT
		if a.profundidad_casilla(c) >= AguaSim3D.UMBRAL_AGUA:
			return t
	return tope


# ------------------------------------------------------------------ 1. cauce ------------------------------------------------------------------

## Cauce de 12 casillas (fila 1, suelo 0) entre dos orillas (filas 0 y 2, suelo 1,0). Manantial en x = 0, desagüe (nivel fijo
## a ras de suelo) en x = 11. El hechizo cae en la orilla (5, 0) y se escurre al cauce.
func _nuevo_cauce() -> AguaSim3D:
	var a := AguaSim3D.new()
	a.configurar(12, 3, 3, S, func(c: Vector2i) -> float: return 0.0 if c.y == 1 else 1.0, func(_c: Vector2i) -> bool: return false)
	a.fuente_en(Vector2i(0, 1), 0.6)
	a.fijar_nivel(Vector2i(11, 1), 0.0)
	return a


func _cauce() -> void:
	print("== 1. cauce con manantial y desagüe")
	var ctl: AguaSim3D = _nuevo_cauce()
	var hzs: AguaSim3D = _nuevo_cauce()
	_correr(ctl, 40.0)
	_correr(hzs, 40.0)
	_hechizo(hzs, Vector2i(5, 0), 1.5)
	_correr(ctl, 5.0)
	_correr(hzs, 5.0)
	var marc_5: int = _marcados(hzs, 1, 0, 10)
	_correr(ctl, 55.0)
	_correr(hzs, 55.0)
	var marc_60: int = _marcados(hzs, 1, 0, 10)
	var peor: float = 0.0
	var donde: int = -1
	for x in range(1, 11):
		var pc: float = ctl.profundidad_casilla(Vector2i(x, 1))
		var ph: float = hzs.profundidad_casilla(Vector2i(x, 1))
		var dif: float = absf(ph - pc) / maxf(pc, 0.01)
		if dif > peor:
			peor = dif
			donde = x
	print("   trocitos del cauce con marca hz: %d a los 5 s del hechizo, %d a los 60 s" % [marc_5, marc_60])
	_ok("1 a los 60 s del hechizo el cauce corre como el de control (peor diferencia de profundidad %.1f %% en x = %d; margen 3 %%)" % [peor * 100.0, donde], peor <= 0.03)
	_ok("1 a los 60 s no queda agua del cauce marcada como de hechizo (%d trocitos)" % marc_60, marc_60 == 0)


# ------------------------------------------------------------------ 2. estanque ------------------------------------------------------------------

## Pasillo de 10 casillas (fila 1) entre paredes. Estanque quieto de 0,8 u en x = 0..2, presa de tierra en x = 3, resto seco.
## El hechizo cae DENTRO del estanque (2, 1). 10 s después se quita la presa: ¿cuánto tarda el agua en ser agua en x = 7?
func _nuevo_estanque() -> AguaSim3D:
	var a := AguaSim3D.new()
	a.configurar(10, 3, 3, S, func(_c: Vector2i) -> float: return 0.0, func(c: Vector2i) -> bool: return c.y != 1)
	a.solidificar_casilla(Vector2i(3, 1), true)
	for x in range(3):
		a.llenar_casilla(Vector2i(x, 1), 0.8)
	return a


func _estanque() -> void:
	print("== 2. estanque quieto tras una presa")
	var ctl: AguaSim3D = _nuevo_estanque()
	var hzs: AguaSim3D = _nuevo_estanque()
	_hechizo(hzs, Vector2i(2, 1), 1.5)
	_correr(ctl, 10.0)
	_correr(hzs, 10.0)
	var marc: int = _marcados(hzs, 1, 0, 2)
	ctl.solidificar_casilla(Vector2i(3, 1), false)
	hzs.solidificar_casilla(Vector2i(3, 1), false)
	var meta := Vector2i(6, 1)
	var t_ctl: float = _llega(ctl, meta, 60.0)
	var t_hz: float = _llega(hzs, meta, 60.0)
	print("   trocitos del estanque con marca hz al abrir la presa: %d de 27" % marc)
	# El de hechizo lleva MÁS agua (1,5 u³ más): solo puede llegar antes o igual. Llegar más tarde es el freno.
	_ok("2 al abrir la presa el agua llega a x = %d a la vez o antes que en el control (control %.2f s, con hechizo %.2f s; margen +5 %%)" % [meta.x, t_ctl, t_hz], t_ctl < 60.0 and t_hz <= t_ctl * 1.05)


# ------------------------------------------------------------------ 3. tinaja ------------------------------------------------------------------

## Canal seco de 10 casillas (fila 1) entre paredes. Un hechizo moja el canal en x = 4; 4 s después se abre una tinaja finita
## (12 u³ a 1,2 u³/s) en x = 0. ¿Cuánto tarda en ser agua x = 8 y cuánta agua queda al final?
func _nuevo_canal() -> AguaSim3D:
	var a := AguaSim3D.new()
	a.configurar(10, 3, 3, S, func(_c: Vector2i) -> float: return 0.0, func(c: Vector2i) -> bool: return c.y != 1)
	return a


func _tinaja() -> void:
	print("== 3. tinaja sobre un canal donde cayó un hechizo")
	var ctl: AguaSim3D = _nuevo_canal()
	var hzs: AguaSim3D = _nuevo_canal()
	_hechizo(hzs, Vector2i(4, 1), 0.6)
	_correr(ctl, 4.0)
	_correr(hzs, 4.0)
	for a in [ctl, hzs]:
		(a as AguaSim3D).fuente_en(Vector2i(0, 1), 1.2)
		(a as AguaSim3D).limitar_fuente(Vector2i(0, 1), 12.0)
	var meta := Vector2i(7, 1)
	var t_ctl: float = _llega(ctl, meta, 90.0)
	var t_hz: float = _llega(hzs, meta, 90.0)
	_ok("3 el frente de la tinaja llega a x = %d a la vez o antes que en el control (control %.2f s, con hechizo %.2f s; margen +5 %%)" % [meta.x, t_ctl, t_hz], t_ctl < 90.0 and t_hz <= t_ctl * 1.05)
	_correr(ctl, 30.0)
	_correr(hzs, 30.0)
	var v_ctl: float = ctl.volumen_total()
	var v_hz: float = hzs.volumen_total()
	_ok("3 el suelo no se bebe el agua de la tinaja: queda al menos la del control (control %.2f u³, con hechizo %.2f u³; margen -3 %%)" % [v_ctl, v_hz], v_hz >= v_ctl * 0.97)
