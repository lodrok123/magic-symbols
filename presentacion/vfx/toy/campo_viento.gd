class_name CampoViento
extends RefCounted

## UN SOLO CAMPO DE VIENTO (11/11/2026; docs/TECNICAS_REPO_GAS_OTROS_ELEMENTOS_2026-11-10.md, top 5 nº 3 y 4). Lo leído del repo force-field-vfx-threejs (MIT): src/gas/flow.js `bakeFlow`
## (ondas sin divergencia con espectro k^(-5/6)), src/gas/sources.js `windAt` / `velSources` (arrastre 0,7, empuje de un sentido 5, piel que quita lo que entra). Sin nodos, sin GPU: corre en headless.
## Es la velocidad del aire en un punto de MUNDO, suma de tres partes, cada una con su interruptor (`parte_turbulencia`, `parte_viento`, `parte_solidos`):
##   1. TURBULENCIA SIN DIVERGENCIA: rotacional de un potencial vector ψ = Σ b·sin(k·x + φ + ω·t), con b ⟂ k (como HazMasaSim.flujo, pero en forma de potencial). Cerca de un sólido ψ se
##      multiplica por una rampa de la distancia (curl noise de Bridson 2007): v = R·rot ψ + ∇R × ψ. Sigue sin divergencia Y en la piel solo corre tangente: el remolino rodea, no entra.
##      El dibujo se arrastra con el viento uniforme (turbulencia «congelada» que viaja con él).
##   2. VIENTO DIRIGIDO: `dir`·`fuerza` + `sube`·↑ + un remolino de Rankine opcional alrededor de `eje_remolino` (tornado). Con `un_sentido`, nada vuelve contra `dir` (T15).
##   3. SÓLIDOS: SDF de cajas orientadas (casillas, bloques, barreras), cápsulas (enemigos), esferas y, si `usar_suelo`, el suelo. En la piel (`piel` m) se quita la componente que ENTRA conservando
##      la rapidez (el aire rodea, no se frena) y dentro se empuja hacia fuera (T16). Mismas primitivas que HazGasJuego (casillas, cápsulas de enemigos, cajas de empujables, barrera fina) pero en MUNDO.
## Quién lo muestrea: VientoToy (hojas, jirones y puntos de las cintas de viento_corrientes.gd) si `en_viento_toy`, y NubeVenenoVfx (gas pesado) si `NubeVenenoVfx.gas_pesado`.
## Coste: ~6 ondas + las primitivas cercanas por muestra (mídelo con herramientas/prueba_campo_viento.gd).

## INTERRUPTOR del VientoToy (apagado de serie): ajuste `magic_symbols/vfx_campo_viento` o `-- campo-viento` en la línea de órdenes. El lab lo alterna con la tecla «,».
static var en_viento_toy: bool = OS.get_cmdline_user_args().has("campo-viento") or bool(ProjectSettings.get_setting("magic_symbols/vfx_campo_viento", false))

const N_ONDAS: int = 6
const GRUPOS_CAJA: Array[StringName] = [&"empujable", &"bloquea", &"solido_viento"]
const ALTO_BLOQUEADA_CAS: float = 1.5     ## = HazGasJuego.ALTO_BLOQUEADA_CAS: alto (casillas) de una casilla bloqueada

# ---- interruptores de las partes ----
var parte_turbulencia: bool = true
var parte_viento: bool = true
var parte_solidos: bool = true

# ---- ajustes ----
var turbulencia: float = 0.6            ## m/s (valor eficaz aproximado de la parte 1)
var escala: float = 2.4                 ## m: tamaño de la celda que se repite (los remolinos miden ~escala/3)
var alcance: float = 0.6                ## m: distancia a un sólido donde la turbulencia empieza a ceñirse (rampa de Bridson)
var dir: Vector3 = Vector3.ZERO         ## dirección del viento (unitaria o cero)
var fuerza: float = 0.0                 ## m/s a lo largo de `dir`
var sube: float = 0.0                   ## m/s hacia arriba
var centro_remolino: Vector3 = Vector3.ZERO
var eje_remolino: Vector3 = Vector3.UP
var remolino: float = 0.0               ## m/s tangenciales en el radio del núcleo
var radio_remolino: float = 1.0         ## m: núcleo del remolino de Rankine
var un_sentido: bool = true
var arrastre: float = 0.7               ## 1/s (demo 0,7)
var empuje: float = 5.0                 ## 1/s (demo 5): lo que va más lento que el viento se empuja hacia delante
var piel: float = 0.35                  ## m
var usar_suelo: bool = false
var y_suelo: float = 0.0

# ---- estado ----
var t: float = 0.0
var muestras: int = 0                   ## cuántas veces se ha muestreado (las pruebas: «la nube muestrea el campo»)
var _desfase: Vector3 = Vector3.ZERO
var _k: PackedVector3Array = PackedVector3Array()
var _a: PackedVector3Array = PackedVector3Array()     ## (k × b): rot ψ = Σ a·cos θ
var _b: PackedVector3Array = PackedVector3Array()     ## ψ = Σ b·sin θ
var _fase: PackedFloat32Array = PackedFloat32Array()
var _w: PackedFloat32Array = PackedFloat32Array()
var _escala_hecha: float = -1.0
var _semilla: int = 11
# primitivas (mundo)
var _c_cen: PackedVector3Array = PackedVector3Array()
var _c_semi: PackedVector3Array = PackedVector3Array()
var _c_inv: Array[Basis] = []
var _c_env: PackedFloat32Array = PackedFloat32Array()
var _k_a: PackedVector3Array = PackedVector3Array()
var _k_b: PackedVector3Array = PackedVector3Array()
var _k_r: PackedFloat32Array = PackedFloat32Array()
var _e_c: PackedVector3Array = PackedVector3Array()
var _e_r: PackedFloat32Array = PackedFloat32Array()


func _init(semilla: int = 11) -> void:
	_semilla = semilla
	_hacer_ondas()


## Las ondas: k entero (la celda de `escala` m se repite), b ⟂ k con |k × b| = |k|^(-5/6) (el espectro de bakeFlow), normalizadas para que el valor eficaz sea ~1.
func _hacer_ondas() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _semilla
	_k.resize(N_ONDAS)
	_a.resize(N_ONDAS)
	_b.resize(N_ONDAS)
	_fase.resize(N_ONDAS)
	_w.resize(N_ONDAS)
	var e: float = TAU / maxf(escala, 0.05)
	var suma: float = 0.0
	var ks: Array = []
	for i in N_ONDAS:
		var k: Vector3 = Vector3(rng.randi_range(-3, 3), rng.randi_range(-2, 2), rng.randi_range(-3, 3))
		if k.length() < 1.5:
			k = Vector3(2, 1, -1) if i % 2 == 0 else Vector3(-1, 1, 2)
		var r: Vector3 = Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5)
		var b: Vector3 = k.cross(r)
		if b.length() < 0.001:
			b = k.cross(Vector3.RIGHT if absf(k.normalized().x) < 0.9 else Vector3.UP)
		var amp: float = pow(k.length(), -5.0 / 6.0)
		b = b.normalized() * amp / (k.length() * e)       # |(e·k) × b| = amp
		ks.append(k)
		_b[i] = b
		_fase[i] = rng.randf() * TAU
		_w[i] = rng.randf_range(0.25, 0.8)
		suma += amp * amp * 0.5
	var norma: float = 1.0 / sqrt(maxf(suma, 1.0e-6))
	for i in N_ONDAS:
		var ke: Vector3 = (ks[i] as Vector3) * e
		_k[i] = ke
		_b[i] = _b[i] * norma
		_a[i] = ke.cross(_b[i])
	_escala_hecha = escala


## Avanza el reloj del campo (y arrastra la turbulencia con el viento uniforme).
func avanzar(dt: float) -> void:
	t += dt
	if parte_viento:
		_desfase += dir * fuerza * dt


# ====================================================================== las tres partes ======================================================================

## Parte 1 SOLA y sin sólidos: rot ψ. Divergencia nula exacta (la mide la prueba).
func turbulencia_libre(p: Vector3) -> Vector3:
	if not is_equal_approx(_escala_hecha, escala):
		_hacer_ondas()
	var q: Vector3 = p - _desfase
	var v: Vector3 = Vector3.ZERO
	for i in N_ONDAS:
		v += _a[i] * cos(_k[i].dot(q) + _fase[i] + _w[i] * t)
	return v * turbulencia


## Parte 2: el viento dirigido sin sólidos.
func viento_base(p: Vector3) -> Vector3:
	if not parte_viento:
		return Vector3.ZERO
	var w: Vector3 = dir * fuerza + Vector3.UP * sube
	if absf(remolino) > 0.0001:
		var r: Vector3 = p - centro_remolino
		r -= eje_remolino * r.dot(eje_remolino)
		var d: float = r.length()
		if d > 0.0001:
			var rn: float = maxf(radio_remolino, 0.05)
			var f: float = d / rn if d < rn else rn / d
			w += eje_remolino.cross(r / d) * remolino * f
	return w


## La velocidad del aire en `p` (mundo), con las partes encendidas.
func velocidad(p: Vector3) -> Vector3:
	return _evaluar(p, false)


## Lo que el campo DESVÍA respecto al viento dirigido libre: turbulencia + rodeo de los sólidos. Lo usan las cintas, cuya forma ya dibuja el viento de la figura.
func desvio(p: Vector3) -> Vector3:
	return _evaluar(p, true)


func _evaluar(p: Vector3, quitar_base: bool) -> Vector3:
	muestras += 1
	var hay_sol: bool = parte_solidos and hay_solidos()
	var d: float = sdf(p) if hay_sol else 1000.0
	var n: Vector3 = Vector3.ZERO
	var tiene_n: bool = false
	var v: Vector3 = Vector3.ZERO
	if parte_turbulencia and turbulencia > 0.0 and d > 0.0:
		if not is_equal_approx(_escala_hecha, escala):
			_hacer_ondas()
		var q: Vector3 = p - _desfase
		var cerca: bool = d < alcance
		var rot: Vector3 = Vector3.ZERO
		var psi: Vector3 = Vector3.ZERO
		for i in N_ONDAS:
			var th: float = _k[i].dot(q) + _fase[i] + _w[i] * t
			rot += _a[i] * cos(th)
			if cerca:
				psi += _b[i] * sin(th)
		if cerca:
			var x: float = d / alcance
			var x2: float = x * x
			var rampa: float = x * (1.875 - 1.25 * x2 + 0.375 * x2 * x2)
			var drampa: float = 1.875 * (1.0 - x2) * (1.0 - x2) / alcance
			n = normal(p)
			tiene_n = true
			v += (rot * rampa + n.cross(psi) * drampa) * turbulencia
		else:
			v += rot * turbulencia
	var base: Vector3 = viento_base(p)
	v += base
	if parte_viento and un_sentido and fuerza > 0.0001:
		var vd: float = v.dot(dir)
		if vd < 0.0:
			v -= dir * vd
	if hay_sol and d < piel:
		if not tiene_n:
			n = normal(p)
		var vn: float = v.dot(n)
		if vn < 0.0:
			var s: float = 1.0 - smoothstep(0.0, piel, d)
			var vt: Vector3 = v - n * vn
			var lt: float = vt.length()
			if lt > 0.00001:
				vt *= minf(v.length() / lt, 3.0)            # rodea con la misma rapidez (en la cara de frente, hasta ×3)
			v = v.lerp(vt, s)
		if d < 0.0:
			v += n * (-d) * 6.0
	if quitar_base:
		v -= base
	return v


## Arrastre de una partícula (hoja, jirón, bocanada) hacia el campo: se relaja a `arrastre`/s y, con `un_sentido`, lo que va más lento que el viento se empuja hacia delante a `empuje`/s.
func arrastrar(p: Vector3, v: Vector3, dt: float, k: float = 1.0) -> Vector3:
	var obj: Vector3 = velocidad(p)
	var r: Vector3 = obj + (v - obj) * exp(-arrastre * k * dt)
	if parte_viento and un_sentido and fuerza > 0.0001 and empuje > 0.0:
		var falta: float = fuerza - r.dot(dir)
		if falta > 0.0:
			r += dir * falta * (1.0 - exp(-empuje * k * dt))
	return r


## El punto fuera de los sólidos (a `margen` m de su piel como poco).
func contener(p: Vector3, margen: float = 0.05) -> Vector3:
	if not parte_solidos or not hay_solidos():
		return p
	var q: Vector3 = p
	for _i in 3:
		var d: float = sdf(q)
		if d >= margen:
			break
		q += normal(q) * (margen - d)
	return q


## Arrastra con el campo una lista de partículas {vivo, pos, vel} (Hojas de VientoToy, HumoToy) expresadas en el espacio `xf` (identidad si están en el mundo), que se mueve a `vel_marco`.
func arrastrar_lista(lista: Array, xf: Transform3D, vel_marco: Vector3, dt: float, k: float = 1.0, margen: float = 0.06) -> int:
	var cuantas: int = 0
	var b: Basis = xf.basis
	var bi: Basis = b.inverse()
	var inv: Transform3D = xf.affine_inverse()
	var sol: bool = parte_solidos and hay_solidos()
	for e in lista:
		var dd: Dictionary = e
		if not bool(dd.get("vivo", false)):
			continue
		cuantas += 1
		var pw: Vector3 = xf * (dd["pos"] as Vector3)
		var vw: Vector3 = b * (dd["vel"] as Vector3) + vel_marco
		vw = arrastrar(pw, vw, dt, k)
		var vl: Vector3 = bi * (vw - vel_marco)
		dd["vel"] = vl
		if sol:
			# se contiene donde ESTARÁ tras el paso de su dueño (que integra después): pos + vel·dt
			var pn: Vector3 = pw + (vw - vel_marco) * dt
			var pc: Vector3 = contener(pn, margen)
			if not pc.is_equal_approx(pn):
				dd["pos"] = inv * pc - vl * dt
	return cuantas


## Esferas envolventes (x, y, z, radio) de los sólidos a menos de `r` m de `c` (el suelo no cuenta): para descartar puntos sin llamar a la SDF.
func esferas_cerca(c: Vector3, r: float) -> PackedVector4Array:
	var out: PackedVector4Array = PackedVector4Array()
	if not parte_solidos:
		return out
	for i in _c_cen.size():
		if c.distance_to(_c_cen[i]) < r + _c_env[i]:
			out.append(Vector4(_c_cen[i].x, _c_cen[i].y, _c_cen[i].z, _c_env[i]))
	for i in _k_a.size():
		var mid: Vector3 = (_k_a[i] + _k_b[i]) * 0.5
		var rr: float = _k_r[i] + _k_a[i].distance_to(_k_b[i]) * 0.5
		if c.distance_to(mid) < r + rr:
			out.append(Vector4(mid.x, mid.y, mid.z, rr))
	for i in _e_c.size():
		if c.distance_to(_e_c[i]) < r + _e_r[i]:
			out.append(Vector4(_e_c[i].x, _e_c[i].y, _e_c[i].z, _e_r[i]))
	return out


# ====================================================================== sólidos ======================================================================

func hay_solidos() -> bool:
	return usar_suelo or not _c_cen.is_empty() or not _k_a.is_empty() or not _e_c.is_empty()


func solidos() -> int:
	return _c_cen.size() + _k_a.size() + _e_c.size() + (1 if usar_suelo else 0)


func limpiar_solidos() -> void:
	_c_cen.clear()
	_c_semi.clear()
	_c_inv.clear()
	_c_env.clear()
	_k_a.clear()
	_k_b.clear()
	_k_r.clear()
	_e_c.clear()
	_e_r.clear()


## Caja orientada: `semi` en los ejes de `base` (casillas, bloques empujables, barreras).
func poner_caja(centro: Vector3, semi: Vector3, base: Basis = Basis.IDENTITY) -> void:
	_c_cen.append(centro)
	_c_semi.append(semi.abs())
	_c_inv.append(base.orthonormalized().transposed())
	_c_env.append(semi.length())


## Cápsula de `a` a `b` con radio `r` (enemigos: la CapsuleShape3D de su cuerpo).
func poner_capsula(a: Vector3, b: Vector3, r: float) -> void:
	_k_a.append(a)
	_k_b.append(b)
	_k_r.append(maxf(r, 0.01))


func poner_esfera(centro: Vector3, r: float) -> void:
	_e_c.append(centro)
	_e_r.append(maxf(r, 0.01))


## Barrera fina (lo que HazGasJuego pone donde el haz se paró contra algo que no es una casilla): pared de `ancho` × `alto` de cara a `dir_frente`, con su pie en `punto`.
func poner_barrera(punto: Vector3, dir_frente: Vector3, ancho: float, alto: float, grosor: float = 0.2) -> void:
	var f: Vector3 = Vector3(dir_frente.x, 0.0, dir_frente.z)
	f = f.normalized() if f.length() > 0.001 else Vector3.BACK
	var lado: Vector3 = Vector3.UP.cross(f).normalized()
	poner_caja(punto + Vector3.UP * alto * 0.5, Vector3(ancho * 0.5, alto * 0.5, grosor * 0.5), Basis(lado, Vector3.UP, f))


## Distancia con signo a lo sólido más cercano (negativa dentro).
func sdf(p: Vector3) -> float:
	var m: float = 1000.0
	if usar_suelo:
		m = p.y - y_suelo
	for i in _c_cen.size():
		var c: Vector3 = _c_cen[i]
		if p.distance_to(c) - _c_env[i] >= m:
			continue
		var q: Vector3 = _c_inv[i] * (p - c)
		var dq: Vector3 = q.abs() - _c_semi[i]
		var dd: float = Vector3(maxf(dq.x, 0.0), maxf(dq.y, 0.0), maxf(dq.z, 0.0)).length() + minf(maxf(dq.x, maxf(dq.y, dq.z)), 0.0)
		m = minf(m, dd)
	for i in _k_a.size():
		var a: Vector3 = _k_a[i]
		var ab: Vector3 = _k_b[i] - a
		var l2: float = ab.length_squared()
		var h: float = clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1.0e-8 else 0.0
		m = minf(m, p.distance_to(a + ab * h) - _k_r[i])
	for i in _e_c.size():
		m = minf(m, p.distance_to(_e_c[i]) - _e_r[i])
	return m


## Normal (gradiente de la SDF) por el tetraedro de 4 muestras.
func normal(p: Vector3) -> Vector3:
	const E: float = 0.01
	var k1: Vector3 = Vector3(1, -1, -1)
	var k2: Vector3 = Vector3(-1, -1, 1)
	var k3: Vector3 = Vector3(-1, 1, -1)
	var k4: Vector3 = Vector3(1, 1, 1)
	var g: Vector3 = k1 * sdf(p + k1 * E) + k2 * sdf(p + k2 * E) + k3 * sdf(p + k3 * E) + k4 * sdf(p + k4 * E)
	return g.normalized() if g.length() > 1.0e-6 else Vector3.UP


## ¿Hay algún sólido a menos de `r` m de `c`? (descarte rápido por esferas envolventes; el suelo no cuenta).
func cerca(c: Vector3, r: float) -> bool:
	if not parte_solidos:
		return false
	for i in _c_cen.size():
		if c.distance_to(_c_cen[i]) < r + _c_env[i]:
			return true
	for i in _k_a.size():
		var mid: Vector3 = (_k_a[i] + _k_b[i]) * 0.5
		if c.distance_to(mid) < r + _k_r[i] + _k_a[i].distance_to(_k_b[i]) * 0.5:
			return true
	for i in _e_c.size():
		if c.distance_to(_e_c[i]) < r + _e_r[i]:
			return true
	return false


## Recoge los sólidos del mundo alrededor de `centro` (radio `radio` m), como HazGasJuego.primitivas_estaticas / _dinamicas pero en mundo:
##   casillas del nivel más altas que `y_ref` (o bloqueadas) si el centro está en el mapa · enemigos (grupo combate3d: su CapsuleShape3D) · cajas de los grupos empujable, bloquea y solido_viento.
func recoger_de(nodo: Node, centro: Vector3, radio: float, y_ref: float) -> void:
	limpiar_solidos()
	if nodo == null or not nodo.is_inside_tree():
		return
	var cas: float = Terreno3D.casilla
	if Terreno3D.en_mapa(Terreno3D.celda_de(centro)):
		var c0: Vector2i = Terreno3D.celda_de(centro - Vector3(radio, 0, radio))
		var c1: Vector2i = Terreno3D.celda_de(centro + Vector3(radio, 0, radio))
		for cz in range(c0.y, c1.y + 1):
			for cx in range(c0.x, c1.x + 1):
				var c: Vector2i = Vector2i(cx, cz)
				var y1: float
				if not Terreno3D.en_mapa(c) or Terreno3D.bloqueada(c) or Terreno3D.cubre_hielo(c):
					y1 = y_ref + ALTO_BLOQUEADA_CAS * cas
				else:
					y1 = Terreno3D.y_pies(c)
					if y1 <= y_ref + 0.05:
						continue
				var y0: float = y_ref - cas
				poner_caja(Vector3((cx + 0.5) * cas, (y0 + y1) * 0.5, (cz + 0.5) * cas), Vector3(cas * 0.5, (y1 - y0) * 0.5, cas * 0.5))
	var arbol: SceneTree = nodo.get_tree()
	for n in arbol.get_nodes_in_group("combate3d"):
		if not (n is Node3D) or not (n as Node3D).is_inside_tree() or n.get("muerto") == true:
			continue
		var r: float = Combate3D.RADIO_CUERPO_ENEMIGO
		var alto: float = 1.0
		var cen: Vector3 = (n as Node3D).global_position + Vector3(0, 0.5, 0)
		var col: Variant = n.get("_col")
		if col is CollisionShape3D and is_instance_valid(col) and (col as CollisionShape3D).shape is CapsuleShape3D:
			var cs: CapsuleShape3D = (col as CollisionShape3D).shape as CapsuleShape3D
			r = cs.radius * (col as Node3D).global_basis.get_scale().x
			alto = cs.height * (col as Node3D).global_basis.get_scale().y
			cen = (col as Node3D).global_position
		if Vector2(cen.x - centro.x, cen.z - centro.z).length() > radio + r:
			continue
		var media: float = maxf(alto * 0.5 - r, 0.0)
		poner_capsula(cen - Vector3(0, media, 0), cen + Vector3(0, media, 0), r)
	for g in GRUPOS_CAJA:
		for n in arbol.get_nodes_in_group(g):
			if n is Node3D and (n as Node3D).is_inside_tree():
				_forma_de(n as Node3D, centro, radio)


## La primera forma de colisión de `n` (caja, cápsula o esfera) como primitiva, si está a menos de `radio` de `centro`.
func _forma_de(n: Node3D, centro: Vector3, radio: float) -> void:
	var formas: Array = n.find_children("*", "CollisionShape3D", true, false)
	if n is CollisionShape3D:
		formas.push_front(n)
	for k in formas:
		var cs: CollisionShape3D = k
		if cs.shape == null or cs.disabled:
			continue
		var xf: Transform3D = cs.global_transform
		var esc: Vector3 = xf.basis.get_scale()
		var dist: float = Vector2(xf.origin.x - centro.x, xf.origin.z - centro.z).length()
		if cs.shape is BoxShape3D:
			var semi: Vector3 = (cs.shape as BoxShape3D).size * 0.5 * esc
			if dist <= radio + semi.length():
				poner_caja(xf.origin, semi, xf.basis.orthonormalized())
			return
		if cs.shape is CapsuleShape3D:
			var cp: CapsuleShape3D = cs.shape as CapsuleShape3D
			var r: float = cp.radius * esc.x
			var media: float = maxf(cp.height * esc.y * 0.5 - r, 0.0)
			var eje: Vector3 = xf.basis.y.normalized()
			if dist <= radio + r + media:
				poner_capsula(xf.origin - eje * media, xf.origin + eje * media, r)
			return
		if cs.shape is SphereShape3D:
			var rs: float = (cs.shape as SphereShape3D).radius * esc.x
			if dist <= radio + rs:
				poner_esfera(xf.origin, rs)
			return
