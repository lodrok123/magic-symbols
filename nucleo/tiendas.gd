class_name Tiendas
extends RefCounted

## LAS TIENDAS (11/11, Juego; decisión de Pablo del 10/11: el oro se mantiene para comprar en tiendas materiales y objetos como pociones y antídotos,
## docs/PROPUESTA_CONSUMIBLES.md §7). Lo que vende cada una está en `nucleo/datos/tiendas.tsv` (tienda, objeto, precio, existencias, se_desbloquea):
##   existencias   cuántas unidades tiene en toda la partida; 0 (o `-`) = sin fin
##   se_desbloquea `siempre`, `flag:<nombre>`, `mejora:<id>>=<n>` o `tener:<objeto>` (las mismas condiciones que `se_conoce` de las recetas: `Sintesis.cumple_se_conoce`)
## Aquí solo están las reglas: qué se ofrece, si se puede comprar y la compra. La pantalla es del Pipeline: escucha `tienda_abierta` (la emiten el alquimista y la
## librera al hablar con ellos), pinta `oferta(tienda)` y llama a `comprar`. Lo comprado de cada tienda viaja con la partida (`Estado.tiendas_compras`).

signal tienda_abierta(tienda: String)
signal comprado(tienda: String, objeto: String, n: int, precio: int)

static var _senal: Tiendas = null
## 11/11: la tienda NO se abre a la primera: la primera E al personaje da su frase con este aviso, y otra E mientras aún habla (VENTANA_OFRECER_MS) abre la tienda.
## Así la frase (las pistas de la librera) no queda tapada por la pantalla, y quien llame a «hablar» desde código (las pruebas, los recorridos) nunca la abre.
const AVISO: String = "   [E: ver la tienda]"
const VENTANA_OFRECER_MS: int = 6000
static var _ofrecida: String = ""
static var _ofrecida_ms: int = -100000

## Por qué no se puede comprar (`puede`): "" = se puede.
const NO_VENDE: String = "no_vende"
const BLOQUEADO: String = "bloqueado"
const AGOTADO: String = "agotado"
const SIN_ORO: String = "oro"
const SIN_SITIO: String = "sitio"


static func i() -> Tiendas:
	if _senal == null:
		_senal = Tiendas.new()
	return _senal


static func _est(e: Estado) -> Estado:
	return e if e != null else Estado.i()


## Abre la tienda `tienda` (la pantalla la escucha).
static func abrir(tienda: String) -> void:
	if BD.tienda(tienda).is_empty():
		return
	PlayLog.event("tienda_abierta", {"tienda": tienda})
	i().tienda_abierta.emit(tienda)


## La E del jugador a un personaje que tiene tienda: si es la segunda E seguida a esa tienda (dentro de VENTANA_OFRECER_MS), la abre y devuelve true (quien llama no dice
## otra frase); si no, apunta la oferta y devuelve false (quien llama dice su frase y añade AVISO).
static func ofrecer(tienda: String) -> bool:
	if BD.tienda(tienda).is_empty():
		return false
	var ahora: int = Time.get_ticks_msec()
	if _ofrecida == tienda and ahora - _ofrecida_ms <= VENTANA_OFRECER_MS:
		_ofrecida = ""
		abrir(tienda)
		return true
	_ofrecida = tienda
	_ofrecida_ms = ahora
	return false


static func _fila(tienda: String, objeto: String) -> Dictionary:
	for f in BD.tienda(tienda):
		if String((f as Dictionary)["objeto"]) == objeto:
			return f
	return {}


static func _clave(tienda: String, objeto: String) -> String:
	return "%s/%s" % [tienda, objeto]


## Cuántas unidades le quedan a la tienda de `objeto`; -1 = sin fin.
static func quedan(tienda: String, objeto: String, e: Estado = null) -> int:
	var f: Dictionary = _fila(tienda, objeto)
	if f.is_empty():
		return 0
	var total: int = int(f["existencias"])
	if total <= 0:
		return -1
	return maxi(0, total - int(_est(e).tiendas_compras.get(_clave(tienda, objeto), 0)))


static func desbloqueado(tienda: String, objeto: String) -> bool:
	var f: Dictionary = _fila(tienda, objeto)
	if f.is_empty():
		return false
	var cond: String = String(f.get("se_desbloquea", ""))
	return cond == "" or cond == "siempre" or Sintesis.cumple_se_conoce(objeto, cond)


## Lo que se ve en la tienda ahora: [{objeto, precio, quedan (-1 = sin fin)}], solo lo desbloqueado y con existencias, en el orden de la tabla.
static func oferta(tienda: String, e: Estado = null) -> Array:
	var r: Array = []
	for f in BD.tienda(tienda):
		var o: String = String((f as Dictionary)["objeto"])
		var q: int = quedan(tienda, o, e)
		if desbloqueado(tienda, o) and q != 0:
			r.append({"objeto": o, "precio": int(f["precio"]), "quedan": q})
	return r


## ¿Se pueden comprar `n` de `objeto`? {ok, motivo ("" o NO_VENDE, BLOQUEADO, AGOTADO, SIN_ORO, SIN_SITIO), precio (total), oro_falta}.
static func puede(tienda: String, objeto: String, n: int = 1, e: Estado = null) -> Dictionary:
	var est: Estado = _est(e)
	var f: Dictionary = _fila(tienda, objeto)
	var precio: int = int(f.get("precio", 0)) * maxi(n, 1)
	var r: Dictionary = {"ok": false, "motivo": "", "precio": precio, "oro_falta": 0}
	if f.is_empty() or n <= 0:
		r["motivo"] = NO_VENDE
	elif not desbloqueado(tienda, objeto):
		r["motivo"] = BLOQUEADO
	elif quedan(tienda, objeto, est) >= 0 and quedan(tienda, objeto, est) < n:
		r["motivo"] = AGOTADO
	elif est.oro < precio:
		r["motivo"] = SIN_ORO
		r["oro_falta"] = precio - est.oro
	elif est.sitio_para(objeto) < n:
		r["motivo"] = SIN_SITIO
	else:
		r["ok"] = true
	return r


## Compra `n` de `objeto`: cobra el oro, lo mete en la mochila y lo apunta contra las existencias. false (sin tocar nada) si `puede` dice que no.
static func comprar(tienda: String, objeto: String, n: int = 1, e: Estado = null) -> bool:
	var est: Estado = _est(e)
	var p: Dictionary = puede(tienda, objeto, n, est)
	if not bool(p["ok"]):
		return false
	if not est.gastar_oro(int(p["precio"])):
		return false
	est.agregar(objeto, n)
	var k: String = _clave(tienda, objeto)
	est.tiendas_compras[k] = int(est.tiendas_compras.get(k, 0)) + n
	PlayLog.event("compra", {"tienda": tienda, "objeto": objeto, "n": n, "precio": int(p["precio"]), "oro": est.oro})
	i().comprado.emit(tienda, objeto, n, int(p["precio"]))
	return true
