class_name LabCastPoint3D
extends RefCounted
## Pestaña F2 del laboratorio de hechizos (LAB_CASTPOINT §2.4): afinar a mano el CAST POINT de cada variación de `CastPoints`
## (recorte del clip, instante del disparo, reparto de las tres fases, mano del libro, desplazamiento del origen) mirando el lanzamiento
## real —el mismo camino que el juego: libro en la mano, clip, fases runa/voluta/forma y disparo en el fotograma— y medir si el hechizo
## nace donde y cuando toca (`Lanzador3D.ultimo_castpoint`: desfase ≤ 1 fotograma, distancia a la mano ≤ 0,15 u).
##
## Lo monta `LabHechizos3D._montar_f2` (si este archivo existe) y le pasa las teclas de la pestaña mientras F2 está abierta. G (guardar) y P (imprimir la
## tabla) son del lab de hechizos: aquí solo se aportan `datos()` y `tabla_texto()`. L y `.` (cámara lenta / paso a paso) son de `TiempoLab3D`.
##
## Teclas (flechas con Mayús = paso grande):
##   Tab / 1–6   siguiente variación / elegir variación          Espacio   lanza esa variación (libro en la mano, camino real)
##   ← → ↑ ↓     desplazamiento del origen: lado / adelante      RePág AvPág   arriba / abajo
##   Q A         instante del disparo + / −                      W S       sostener la pose (s) + / −
##   Z X         inicio del recorte − / +  (con Mayús: el fin)    E D       más / menos tiempo para la runa (el resto se reparte)
##   M           mano del libro (izquierda / derecha)             B         modificador del brazo con los clips originales (sí / no)
##   C           fuente del clip: original + modificador / una mano (gris si la variación no tiene clip a una mano)
##   V           valoración del último lanzamiento: bien / rígido / sin fuerza → PlayLog `castpoint_valoracion`
##   Num /       cámara lateral (la del lab)

const ELEMENTO_PRUEBA: String = "fire"
## Receta que da el nombre derivado de cada posición (glifo -> veces): esfera = x_mano · altura = alto · línea en X sin altura = abajo.
const RECETA_POSICION: Dictionary = {"x_mano": {}, "alto": {"altura": 2}, "abajo": {"linea_x": 2}}
const VALORACIONES: Array = ["bien", "rígido", "sin fuerza"]
const PASO_FINO: float = 0.01
const PASO_GRANDE: float = 0.05

var lab: Variant = null                ## LabHechizos3D
var sel: int = 0                       ## índice en CastPoints.ORDEN
var valoracion: int = -1
var valoraciones: Array = []           ## [{variacion, valoracion, fuente}], lo que se ha ido marcando con V
var ultimo_mensaje: String = ""
var lanzamientos: int = 0


func iniciar(l: Variant) -> void:
	lab = l


func id() -> String:
	return String(CastPoints.ORDEN[sel])


## La posición (x_mano · alto · abajo) a la que pertenece la variación elegida.
func posicion() -> String:
	var d: Dictionary = CastPoints.datos(id())
	return String(d.get("posicion", "x_mano"))


func _v() -> Dictionary:
	return CastPoints.VARIACIONES[id()] as Dictionary


func elegir(i: int) -> void:
	sel = posmod(i, CastPoints.ORDEN.size())
	valoracion = -1
	ultimo_mensaje = "variación %s" % id()


func _pj() -> Variant:
	return lab._jug.pj if lab != null and lab._jug != null else null


## Lanza la variación elegida por el camino real: pone el nombre derivado de su receta apuntando a ella (CastPoints.POR_NOMBRE), con el libro ya en la mano.
func lanzar() -> bool:
	if lab == null or lab._jug == null:
		return false
	var pos: String = posicion()
	CastPoints.POR_NOMBRE[pos] = id()
	var cont: Dictionary = (RECETA_POSICION.get(pos, {}) as Dictionary).duplicate()
	var r: Lanzador3D.Receta3D = lab.receta_de(cont)
	var pj: Variant = _pj()
	if pj != null:
		pj.libro_en_manos(true, 0.2, CastPoints.mano_libro(id()))
	var ficha: Dictionary = lab._lanzar_completo(r, cont, ELEMENTO_PRUEBA, lab.direccion())
	lanzamientos += 1
	valoracion = -1
	ultimo_mensaje = "lanzado %s%s" % [id(), (" · rechazo: " + String(ficha["rechazo"])) if String(ficha.get("rechazo", "")) != "" else ""]
	return String(ficha.get("rechazo", "")) == ""


func _ajustar(clave: String, delta: float, mn: float, mx: float) -> void:
	var v: Dictionary = _v()
	v[clave] = snappedf(clampf(float(v.get(clave, 0.0)) + delta, mn, mx), 0.001)


func _mover_origen(dx: float, dy: float, dz: float) -> void:
	var v: Dictionary = _v()
	var o: Vector3 = CastPoints.desplazamiento(id()) + Vector3(dx, dy, dz)
	v["desplazamiento"] = [snappedf(o.x, 0.001), snappedf(o.y, 0.001), snappedf(o.z, 0.001)]


## Mueve la fracción de la anticipación que se lleva la runa; voluta y forma se reparten el resto como estaban.
func _repartir_runa(delta: float) -> void:
	var a: Array = CastPoints.normalizar_anticipacion(_v().get("anticipacion", []))
	var runa: float = clampf(float(a[0]) + delta, 0.05, 0.8)
	var resto: float = float(a[1]) + float(a[2])
	var f: float = float(a[1]) / resto if resto > 0.0001 else 0.5
	var nuevo: Array = [runa, (1.0 - runa) * f, (1.0 - runa) * (1.0 - f)]
	_v()["anticipacion"] = [snappedf(nuevo[0], 0.001), snappedf(nuevo[1], 0.001), snappedf(nuevo[2], 0.001)]


## Devuelve true si la tecla es de esta pestaña (el lab entonces no la mira más).
func tecla(k: InputEventKey) -> bool:
	var paso: float = PASO_GRANDE if k.shift_pressed else PASO_FINO
	var u: float = 0.1 if k.shift_pressed else 0.02          # paso del origen, en unidades del mundo
	match k.keycode:
		KEY_TAB:
			if not k.echo:
				elegir(sel + 1)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			if not k.echo:
				elegir(k.keycode - KEY_1)
		KEY_SPACE:
			if not k.echo:
				lanzar()
		KEY_LEFT:
			_mover_origen(0.0, 0.0, -u)
		KEY_RIGHT:
			_mover_origen(0.0, 0.0, u)
		KEY_UP:
			_mover_origen(u, 0.0, 0.0)
		KEY_DOWN:
			_mover_origen(-u, 0.0, 0.0)
		KEY_PAGEUP:
			_mover_origen(0.0, u, 0.0)
		KEY_PAGEDOWN:
			_mover_origen(0.0, -u, 0.0)
		KEY_Q:
			_ajustar("instante", paso, 0.0, 1.0)
		KEY_A:
			_ajustar("instante", -paso, 0.0, 1.0)
		KEY_W:
			_ajustar("sostener", paso * 2.0, 0.0, 3.0)
		KEY_S:
			_ajustar("sostener", -paso * 2.0, 0.0, 3.0)
		KEY_Z:
			_ajustar("fin" if k.shift_pressed else "inicio", -PASO_FINO, 0.0, 1.0)
		KEY_X:
			_ajustar("fin" if k.shift_pressed else "inicio", PASO_FINO, 0.0, 1.0)
		KEY_E:
			_repartir_runa(PASO_FINO * 2.0)
		KEY_D:
			_repartir_runa(-PASO_FINO * 2.0)
		KEY_M:
			if not k.echo:
				_v()["mano_libro"] = "izquierda" if String(_v().get("mano_libro", "izquierda")) == "derecha" else "derecha"
		KEY_B:
			if not k.echo:
				CastPoints.brazo_activo = not CastPoints.brazo_activo
		KEY_C:
			if not k.echo:
				if String(_v().get("clip_una_mano", "")) == "":
					ultimo_mensaje = "%s no tiene clip a una mano (T-CP4)" % id()
				else:
					CastPoints.usar_una_mano = not CastPoints.usar_una_mano
		KEY_V:
			if not k.echo:
				valorar()
		_:
			return false
	return true


## Anota la valoración siguiente del último lanzamiento (bien → rígido → sin fuerza) con la fuente de clip en uso.
func valorar() -> void:
	valoracion = (valoracion + 1) % VALORACIONES.size()
	var ficha: Dictionary = {"variacion": id(), "valoracion": String(VALORACIONES[valoracion]),
		"fuente": "una_mano" if CastPoints.es_una_mano(id()) else "original", "brazo": CastPoints.brazo_activo}
	valoraciones.append(ficha)
	PlayLog.event("castpoint_valoracion", ficha)


## ¿Cuándo se lanzó y qué se midió? Texto de la última medida del Lanzador3D.
func _medida() -> String:
	if lab == null or lab._l == null or lab._l.ultimo_castpoint.is_empty():
		return "(sin medir: lanza con Espacio)"
	var m: Dictionary = lab._l.ultimo_castpoint
	var ok_t: bool = absf(float(m.get("desfase_fotogramas", 99.0))) <= 1.0
	var ok_d: bool = float(m.get("dist_mano", 99.0)) <= 0.15
	return "%s desfase %.1f fot (%.0f ms) · %s a %.2f u de la mano" % [
		"✔" if ok_t else "✘", float(m.get("desfase_fotogramas", 0.0)), float(m.get("desfase_s", 0.0)) * 1000.0, "✔" if ok_d else "✘", float(m.get("dist_mano", 0.0))]


## La barra del clip: 40 casillas del recorte; R/V/F = fases de la anticipación, | = el instante, ▮ = dónde va el clip.
func barra() -> String:
	var v: Dictionary = _v()
	var n: int = 40
	var inst: float = clampf(float(v.get("instante", 0.5)), 0.0, 1.0)
	var a: Array = CastPoints.normalizar_anticipacion(v.get("anticipacion", []))
	var celdas: Array = []
	for i in range(n):
		var f: float = float(i) / float(n)
		var c: String = "·"
		if f < inst:
			var q: float = f / maxf(inst, 0.001)
			c = "R" if q < float(a[0]) else ("V" if q < float(a[0]) + float(a[1]) else "F")
		celdas.append(c)
	var pos: int = clampi(int(round(inst * n)), 0, n - 1)
	celdas[pos] = "|"
	var pj: Variant = _pj()
	if pj != null and pj.cast_activo():
		var fr: float = clampf(float(pj.fraccion_clip()), 0.0, 0.999)
		celdas[clampi(int(fr * n), 0, n - 1)] = "▮"
	return "[" + "".join(celdas) + "]"


func texto() -> String:
	var v: Dictionary = _v()
	var d: Dictionary = CastPoints.datos(id())
	var l: PackedStringArray = []
	l.append("F2 · CAST POINT   %s   (%d/%d)   posición %s" % [id(), sel + 1, CastPoints.ORDEN.size(), posicion()])
	var pj: Variant = _pj()
	var clip_real: String = ""
	if pj != null and pj.cast_activo() and pj._ap != null:
		clip_real = String(pj._ap.current_animation)
	l.append("clip: %s → %s%s" % [CastPoints.rol_clip(id()), clip_real if clip_real != "" else "(no suena)",
		"   [UNA MANO]" if CastPoints.es_una_mano(id()) else ""])
	l.append(barra())
	var rec: Vector2 = CastPoints.recorte(id())
	l.append("recorte %.2f–%.2f (Z/X, Mayús = fin) · instante %.2f (Q/A) · sostener %.2f s (W/S) · velocidad %.2f" % [rec.x, rec.y, float(d["instante"]), float(d["sostener"]), float(d["velocidad"])])
	var a: Array = d["anticipacion"]
	l.append("anticipación runa/voluta/forma %.2f/%.2f/%.2f (E/D)" % [float(a[0]), float(a[1]), float(a[2])])
	var o: Vector3 = CastPoints.desplazamiento(id())
	l.append("origen %s + desplazamiento (adelante %.2f · arriba %.2f · lado %.2f) (flechas, RePág/AvPág)" % [String(d["origen"]), o.x, o.y, o.z])
	l.append("libro en la mano %s (M) · modificador del brazo %s (B) · fuente %s (C)" % [String(d["mano_libro"]), "sí" if CastPoints.brazo_activo else "no",
		"una mano" if CastPoints.usar_una_mano else "original"])
	l.append("medida: " + _medida())
	if valoracion >= 0:
		l.append("valoración: %s (V)" % String(VALORACIONES[valoracion]))
	else:
		l.append("valoración: — (V: bien / rígido / sin fuerza)")
	l.append(_reaccion())
	if ultimo_mensaje != "":
		l.append(ultimo_mensaje)
	l.append("Tab/1–6 variación · Espacio lanza · G guarda · P imprime la tabla")
	return "\n".join(l)


## Qué hace un golpe con el valor de F3 (empuje, parada): el vínculo entre «cuándo sale» y «cómo reacciona el enemigo».
func _reaccion() -> String:
	if lab == null:
		return ""
	return "reacción (F3): empuje ×%.2f · mín %.2f casillas · hitstop %.2f s · goblin atacante %s" % [
		float(lab.impacto_valor("MULT_EMPUJE")), float(lab.impacto_valor("EMPUJE_MIN_CASILLAS")), float(lab.impacto_valor("HITSTOP")),
		"sí" if bool(lab.atacar_goblin) else "no"]


func datos() -> Dictionary:
	return {"variacion": id(), "tabla": CastPoints.a_diccionario(), "valoraciones": valoraciones.duplicate(true),
		"ultimo": lab._l.ultimo_castpoint.duplicate() if lab != null and lab._l != null else {}}


func tabla_texto() -> String:
	return CastPoints.tabla_texto()
