class_name Mejoras
extends RefCounted

## LAS MEJORAS DEL PERSONAJE (F3 de PLAN_BASE_DATOS, 29/10, Juego). Un solo sitio que sabe qué hace cada fila de `nucleo/datos/mejoras.tsv`.
##
## El NIVEL de cada mejora vive en `Estado.mejoras` (id -> nivel), así viaja con la partida (`Partida` guarda la sección `mejoras`). Lo DERIVADO (vida máxima, cura
## de la poción, defensa, velocidad, huecos de bolsa, frascos de tinta, páginas y huecos del libro) NO se guarda: `aplicar_todas()` lo recalcula desde la base, de
## modo que llamarlo dos veces deja lo mismo que una (idempotente) y se puede llamar siempre que se cargue una partida o se cambie un nivel.
## Las cifras (`tope`, `por_nivel`) salen de la tabla, no de aquí; lo único «de código» son las BASES (lo que vale cada cosa sin mejoras).
##
## QUÉ APLICA CADA `campo` (columna `campo` de la tabla → dónde cae):
##   vida_max       Estado.vida_max = VIDA_BASE + 20 × nivel            capacidad   Estado.capacidad = capacidad_base + 4 × nivel (tope CAPACIDAD_MAX)
##   cura_pocion    Estado.cura_pocion = CURA_BASE + 10 × nivel         defensa     Estado.defensa = 1 × nivel (lo lee Jugador3D.recibir_dano)
##   velocidad      Estado.vel_extra = 10 × nivel                       frascos_tinta  Tinta.frascos_max() = FRASCOS_MAX + nivel (el frasco nuevo nace lleno)
##   tinta_frasco   Tinta.tinta_por_frasco() = maxima × (1 + 0,1 × nivel)
##   paginas        Repertoire.max_pages: la base la fija el nivel de juego (Lanzador3D), la mejora SUMA encima (ver `_sumar`)
##   huecos_glifo   Repertoire.max_sigils_per_page: los ENGARCES FIJAN EL TOTAL (decisión de Pablo, 10/11, diario 458): máx(base del libro, 1 + engarces), tope HUECOS_MAX.
##                  Con el libro del bosque (base 1) cada engarce abre un hueco; con el avanzado (base 4) solo se notan a partir del cuarto. Ninguno se pierde al cambiar de libro.
##   tinta_jefe / tinta_secreto   ya los lleva `Tinta.ganar_jefe/ganar_secreto`; aquí solo `nivel` y `tope` informativos (no se suben con `subir`).

signal cambiada                                   ## (instancia única, para la UI) una mejora ha subido de nivel
static var _senal: Mejoras = null

## Mejoras que NO se compran: las gana otro sistema. `subir` las rechaza.
const AJENAS: PackedStringArray = ["tinta_jefe", "tinta_secreto"]

## Lo último que `aplicar_todas` dejó puesto en el libro, para poder quitarlo y volver a la base que fijó el nivel (ver `_sumar`).
static var _libro_puesto: Dictionary = {"max_pages": -1, "max_sigils_per_page": -1}
static var _libro_sumado: Dictionary = {"max_pages": 0, "max_sigils_per_page": 0}
const HUECOS_MAX: int = 6                ## huecos de glifo por página como mucho (los seis de la corona del libro avanzado)


static func i() -> Mejoras:
	if _senal == null:
		_senal = Mejoras.new()
	return _senal


static func _est(e: Estado) -> Estado:
	return e if e != null else Estado.i()


static func existe(id: String) -> bool:
	return not BD.mejora(id).is_empty()


static func nivel(id: String, e: Estado = null) -> int:
	return _est(e).nivel(id)


static func tope(id: String) -> int:
	return int(BD.mejora(id).get("tope", 0))


## Lo que suma cada nivel (puede ser decimal: 0,1 en `tinta_frasco`).
static func por_nivel(id: String) -> float:
	return float(BD.mejora(id).get("por_nivel", 0))


## `por_nivel × nivel`: lo que da la mejora ahora mismo.
static func valor(id: String, e: Estado = null) -> float:
	return por_nivel(id) * float(nivel(id, e))


static func al_tope(id: String, e: Estado = null) -> bool:
	return nivel(id, e) >= tope(id)


## Sube un nivel. false si la mejora no existe, la gana otro sistema (`AJENAS`) o ya está en su tope. Aplica el efecto en el acto.
static func subir(id: String, e: Estado = null) -> bool:
	if not existe(id) or AJENAS.has(id) or al_tope(id, e):
		return false
	var est: Estado = _est(e)
	est.mejoras[id] = nivel(id, est) + 1
	aplicar_todas(est)
	if id == "frascos_tinta":
		_llenar_frasco_nuevo(est)
	i().cambiada.emit()
	return true


## Recalcula TODO lo derivado desde la base. Idempotente. Se llama al cargar la partida (`Estado.desde_dic`) y tras cada `subir`.
## `avisar` = false cuando quien llama ya va a emitir `cambiado` él mismo (`Estado.desde_dic`).
static func aplicar_todas(e: Estado = null, avisar: bool = true) -> void:
	var est: Estado = _est(e)
	est.vida_max = Estado.VIDA_BASE + valor("vida_max", est)
	est.cura_pocion = Estado.CURA_BASE + valor("cura_pocion", est)
	est.defensa = valor("defensa", est)
	est.vel_extra = valor("velocidad", est)
	est.capacidad = clampi(est.capacidad_base + int(valor("capacidad", est)), 1, Estado.CAPACIDAD_MAX)
	est.frascos_tinta = clampi(est.frascos_tinta, 0, Tinta.frascos_max(est))
	if est == Estado.i():
		_sumar("max_pages", int(valor("paginas", est)))
		_fijar_huecos(int(valor("huecos_glifo", est)))
	if avisar:
		est.cambiado.emit()


## El libro. Lo que fija el nivel de juego (`Lanzador3D`: `glifos_por_pagina`, `paginas`) es la BASE; la mejora suma encima. Para ser idempotente se recuerda lo último
## que se puso: si el valor actual sigue siendo ese, la base es «actual − lo sumado»; si es otro, el nivel lo ha vuelto a fijar y esa es la base. 0 = sin límite (no se toca).
## Los huecos de glifo (10/11, diario 458): los engarces FIJAN EL TOTAL = máx(base, 1 + engarces), tope HUECOS_MAX. La base la apunta `Repertoire` cada vez que el
## nivel o el libro fijan `max_sigils_per_page` (`base_sigils_per_page`), así que no hay que adivinarla. 0 = sin límite: no se toca.
static func _fijar_huecos(engarces: int) -> void:
	var base: int = Repertoire.base_sigils_per_page
	if base <= 0:
		return
	Repertoire._desde_mejoras = true
	Repertoire.max_sigils_per_page = maxi(base, mini(1 + engarces, HUECOS_MAX))
	Repertoire._desde_mejoras = false
	_libro_puesto["max_sigils_per_page"] = Repertoire.max_sigils_per_page
	_libro_sumado["max_sigils_per_page"] = Repertoire.max_sigils_per_page - base


## `fija_total` (los huecos de glifo): en vez de sumar, el total es máx(base, 1 + extra) con tope HUECOS_MAX (si la base ya pasa del tope, se respeta la base).
static func _sumar(campo: String, extra: int, fija_total: bool = false) -> void:
	var actual: int = Repertoire.max_pages if campo == "max_pages" else Repertoire.max_sigils_per_page
	var base: int = actual - int(_libro_sumado[campo]) if actual == int(_libro_puesto[campo]) else actual
	if base <= 0:
		_libro_puesto[campo] = actual
		_libro_sumado[campo] = 0
		return
	var nuevo: int = maxi(base, mini(1 + extra, HUECOS_MAX)) if fija_total else base + extra
	if campo == "max_pages":
		Repertoire.max_pages = nuevo
	else:
		Repertoire._desde_mejoras = true
		Repertoire.max_sigils_per_page = nuevo
		Repertoire._desde_mejoras = false
	_libro_puesto[campo] = nuevo
	_libro_sumado[campo] = nuevo - base


## El frasco de reserva que acaba de ganarse empieza lleno: si hay una `Tinta` viva (`Partida.tinta`) se llena ella; si no, el número que viaja en el Estado.
static func _llenar_frasco_nuevo(est: Estado) -> void:
	if Partida.tinta != null and est == Estado.i():
		Partida.tinta.recargar_frasco(1)
	else:
		est.frascos_tinta = mini(est.frascos_tinta + 1, Tinta.frascos_max(est))


## Cuánto cura ahora una poción `id` al beberla: su `cura` de la tabla + lo que suma la mejora `cura_pocion`.
static func cura_de(id: String, e: Estado = null) -> float:
	return float(Objetos.efecto(id).get("cura", Estado.CURA_BASE)) + valor("cura_pocion", e)
