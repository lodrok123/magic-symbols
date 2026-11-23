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
##
## M1 · CIFRAS DEL LIBRO (22/11, docs/PLAN_HECHIZOS_2026-11-22.md §9; preguntas P1–P3 de docs/DIBUJAR_EN_GAMEPLAY_2026-11-21.md). Solo cuentan; ninguna regla cambia. Van en `d["libro"]`:
##   · aperturas, seg_abierto            ← `libro_abierto()` / `libro_cerrado()` (Spellbook._open / _close)
##   · paginas_reescritas, seg_dibujando ← al cerrar, las páginas de `Repertoire.paginas` que cambiaron desde que se abrió; `seg_dibujando` suma lo que estuvo abierto en esas aperturas
##                                         (segundos por página = seg_dibujando / paginas_reescritas, `seg_por_pagina`)
##   · por_pagina {"1": n}, por_receta {"fuego:flecha+flecha": n} ← `contar_lanzamiento` (Lanzador3D._disparar)
##   · encuentros, encuentros_varias     ← `empieza_encuentro` / `acaba_encuentro` (la música de combate de Sensacion3D); «varias» = se lanzó con más de una página distinta
##   · trazos_reconocidos, trazos_rechazados ← `contar_trazo` (Lanzador3D.add_gesture; «confundido» cuenta como rechazado)
##   · intentos_combate                  ← `contar_intento_libro_en_combate` (Lanzador3D._rechazar_libro_en_combate)

static var total: Dictionary = vacio()
static var por_nivel: Dictionary = vacio()
static var _seg_base_total: float = 0.0
static var _t0_total_ms: int = 0
static var _t0_nivel_ms: int = 0
static var _oro_visto: int = -1
# M1: lo que hace falta recordar entre abrir y cerrar el libro, y durante un encuentro.
static var _t_libro_ms: int = -1                 ## cuándo se abrió el libro (-1 = cerrado)
static var _paginas_al_abrir: Array = []         ## copia de `Repertoire.paginas` al abrir
static var _en_encuentro: bool = false
static var _paginas_encuentro: Dictionary = {}   ## páginas (1, 2, 3) con las que se lanzó en el encuentro de ahora


## Un juego de cifras a cero.
static func vacio() -> Dictionary:
	return {"enemigos": {}, "hechizos": {}, "dano_hecho": 0.0, "dano_recibido": 0.0, "oro_ganado": 0, "muertes": 0, "cofres": 0, "segundos": 0.0, "libro": libro_vacio()}


## M1: las cifras del libro a cero.
static func libro_vacio() -> Dictionary:
	return {"aperturas": 0, "seg_abierto": 0.0, "paginas_reescritas": 0, "seg_dibujando": 0.0, "por_pagina": {}, "por_receta": {},
		"encuentros": 0, "encuentros_varias": 0, "trazos_reconocidos": 0, "trazos_rechazados": 0, "intentos_combate": 0}


## Todo a cero (Nueva partida y las pruebas).
static func reiniciar() -> void:
	total = vacio()
	por_nivel = vacio()
	_seg_base_total = 0.0
	_t0_total_ms = Time.get_ticks_msec()
	_t0_nivel_ms = _t0_total_ms
	_oro_visto = -1
	_t_libro_ms = -1
	_paginas_al_abrir = []
	_en_encuentro = false
	_paginas_encuentro = {}


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
#  M1 · El libro (22/11)
# ---------------------------------------------------------------------------------------------------------------------

## El apartado `libro` de un juego de cifras (lo crea si un juego viejo no lo tiene).
static func _libro_de(d: Dictionary) -> Dictionary:
	if not (d.get("libro") is Dictionary):
		d["libro"] = libro_vacio()
	return d["libro"]


static func _sumar_libro(clave: String, v: float) -> void:
	for d in [total, por_nivel]:
		var l: Dictionary = _libro_de(d)
		l[clave] = (float(l.get(clave, 0.0)) + v) if clave.begins_with("seg_") else (int(l.get(clave, 0)) + int(v))


static func _sumar_en(clave: String, sub: String) -> void:
	for d in [total, por_nivel]:
		var t: Dictionary = _libro_de(d)[clave]
		t[sub] = int(t.get(sub, 0)) + 1


## El libro se ha abierto (Spellbook._open, ya abierto de verdad: no cuenta el intento rechazado en combate).
static func libro_abierto() -> void:
	if _t_libro_ms >= 0:
		return
	_t_libro_ms = Time.get_ticks_msec()
	_paginas_al_abrir = Repertoire.paginas.duplicate(true)
	_sumar_libro("aperturas", 1)


## El libro se ha cerrado: segundos abierto y páginas que cambiaron de receta desde que se abrió.
static func libro_cerrado() -> void:
	if _t_libro_ms < 0:
		return
	var seg: float = float(Time.get_ticks_msec() - _t_libro_ms) / 1000.0
	_t_libro_ms = -1
	_sumar_libro("seg_abierto", seg)
	var cambiadas: int = paginas_distintas(_paginas_al_abrir, Repertoire.paginas)
	_paginas_al_abrir = []
	if cambiadas > 0:
		_sumar_libro("paginas_reescritas", cambiadas)
		_sumar_libro("seg_dibujando", seg)


## Cuántas páginas tienen otra receta (elemento, elemento2 o glifos) entre dos listas como `Repertoire.paginas`. Una página que aparece o desaparece cuenta si no está vacía.
static func paginas_distintas(antes: Array, ahora: Array) -> int:
	var n: int = 0
	for i in range(maxi(antes.size(), ahora.size())):
		var a: String = _clave_pagina(antes[i] if i < antes.size() else {})
		var b: String = _clave_pagina(ahora[i] if i < ahora.size() else {})
		if a != b:
			n += 1
	return n


static func _clave_pagina(p: Variant) -> String:
	if not (p is Dictionary):
		return ""
	var d: Dictionary = p
	var gl: PackedStringArray = PackedStringArray()
	for g in d.get("glifos", []):
		gl.append(String(g))
	var e: String = String(d.get("elemento", ""))
	if e == "" and gl.is_empty():
		return ""
	return "%s/%s:%s" % [e, String(d.get("elemento2", "")), "+".join(gl)]


## Un lanzamiento de la página `pagina` (1, 2, 3) con la receta `elemento` + `glifos`.
static func contar_lanzamiento(pagina: int, elemento: String, glifos: Array) -> void:
	var gl: PackedStringArray = PackedStringArray()
	for g in glifos:
		gl.append(String(g))
	_sumar_en("por_pagina", str(pagina))
	_sumar_en("por_receta", "%s:%s" % [elemento if elemento != "" else "sin_elemento", "+".join(gl)])
	if _en_encuentro:
		_paginas_encuentro[pagina] = true


## Empieza un encuentro (enemigos persiguiendo). Lo avisa la música de combate de Sensacion3D.
static func empieza_encuentro() -> void:
	if _en_encuentro:
		return
	_en_encuentro = true
	_paginas_encuentro = {}
	_sumar_libro("encuentros", 1)


## Acaba el encuentro: ¿se lanzó con más de una página?
static func acaba_encuentro() -> void:
	if not _en_encuentro:
		return
	_en_encuentro = false
	if _paginas_encuentro.size() > 1:
		_sumar_libro("encuentros_varias", 1)
	_paginas_encuentro = {}


## Un gesto dibujado en el libro: reconocido o no (rechazado o confundido).
static func contar_trazo(reconocido: bool) -> void:
	_sumar_libro("trazos_reconocidos" if reconocido else "trazos_rechazados", 1)


## Se quiso abrir el libro en combate y no se dejó.
static func contar_intento_libro_en_combate() -> void:
	_sumar_libro("intentos_combate", 1)


## Segundos por página reescrita (0 si no se reescribió ninguna).
static func seg_por_pagina(d: Dictionary) -> float:
	var l: Dictionary = d.get("libro", {}) if d.get("libro") is Dictionary else {}
	var n: int = int(l.get("paginas_reescritas", 0))
	return float(l.get("seg_dibujando", 0.0)) / float(n) if n > 0 else 0.0


## La parte del total de lanzamientos que se lleva la página más usada (0..1; 0 si no hay lanzamientos). Umbrales de DIBUJAR §4.5: bien ≤ 0,6, mal > 0,8.
static func cuota_pagina_mas_usada(d: Dictionary) -> float:
	var l: Dictionary = d.get("libro", {}) if d.get("libro") is Dictionary else {}
	var tot: int = 0
	var mayor: int = 0
	for k in (l.get("por_pagina", {}) as Dictionary):
		var v: int = int((l["por_pagina"] as Dictionary)[k])
		tot += v
		mayor = maxi(mayor, v)
	return float(mayor) / float(tot) if tot > 0 else 0.0


## Las líneas de las cifras del libro, para Pablo (no las enseña la pestaña de la jugadora): [[etiqueta, valor], …].
static func filas_libro(d: Dictionary) -> Array:
	var l: Dictionary = d.get("libro", {}) if d.get("libro") is Dictionary else libro_vacio()
	var rec: int = int(l.get("trazos_reconocidos", 0))
	var rech: int = int(l.get("trazos_rechazados", 0))
	var f: Array = []
	f.append(["Libro abierto (veces)", str(int(l.get("aperturas", 0)))])
	f.append(["Libro abierto (tiempo)", texto_tiempo(float(l.get("seg_abierto", 0.0)))])
	f.append(["Páginas reescritas", str(int(l.get("paginas_reescritas", 0)))])
	f.append(["Segundos por página", "%.1f" % seg_por_pagina(d)])
	f.append(["Lanzamientos por página", str(l.get("por_pagina", {}))])
	f.append(["Página más usada (cuota)", "%d %%" % int(round(cuota_pagina_mas_usada(d) * 100.0))])
	f.append(["Recetas distintas lanzadas", str((l.get("por_receta", {}) as Dictionary).size())])
	f.append(["Encuentros (con más de una página)", "%d (%d)" % [int(l.get("encuentros", 0)), int(l.get("encuentros_varias", 0))]])
	f.append(["Trazos no reconocidos", "%d de %d (%d %%)" % [rech, rec + rech, int(round(100.0 * float(rech) / float(rec + rech))) if rec + rech > 0 else 0]])
	f.append(["Intentos de abrir el libro en combate", str(int(l.get("intentos_combate", 0)))])
	return f


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
	# M1 (22/11): las cifras del libro. Un archivo anterior no las trae: se quedan a cero.
	var lb: Variant = s.get("libro", {})
	if lb is Dictionary:
		var l: Dictionary = total["libro"]
		for k in (lb as Dictionary).keys():
			var v: Variant = (lb as Dictionary)[k]
			if not l.has(String(k)):
				continue
			if v is Dictionary:
				var sub: Dictionary = {}
				for c in (v as Dictionary).keys():
					sub[String(c)] = int((v as Dictionary)[c])
				l[String(k)] = sub
			elif String(k).begins_with("seg_"):
				l[String(k)] = float(v)
			else:
				l[String(k)] = int(v)


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
