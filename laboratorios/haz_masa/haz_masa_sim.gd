class_name HazMasaSim
extends RefCounted

## SIMULACION BARATA DE LA «MASA DE FUEGO» DEL HAZ (prototipo del 9/11/2026, docs/HAZ_FUEGO_VS_DEMO_2026-11-09.md). Sin nodos: solo numeros, para poder probarla sin ventana
## (herramientas/prueba_haz_masa.gd). Imita con BOCANADAS movidas por la CPU las reglas de la demo de gas de three.js (src/gas/sources.js, forces.js, render/sparks.js):
##   1. NACER      en el punto de choque (a 0,3 m de la piel hacia el lanzador), con T alta y ritmo de rafagas; sin choque, unas pocas en el ultimo tramo del chorro (55-90 %).
##   2. VIENTO     la velocidad se relaja hacia un viento a lo largo del haz (en el suelo) y lo que va mas lento que el, o vuelve hacia el lanzador, se empuja hacia delante.
##   3. PIEL       contra el obstaculo se quita la componente que entra, un tiron ligero a la superficie (wrap) y un reparto hacia los lados desde el punto de choque
##                 (lo que en la demo hace la presion al proyectar); nunca dentro del volumen: se proyecta a la superficie.
##   4. FLOTACION  v.y += flotacion·T·dt.
##   5. REMOLINOS  campo sin divergencia (ondas cos con a ⟂ k, como flow.js de la demo) escalado por T y velocidad.
##   6. ENFRIAR    «lento» = 1 - smoothstep(|v - viento|); T se enfria mas rapido cuando va lento y lo perdido pasa a hollin; el hollin se olvida. T alta = fuego, hollin = humo pardo.
##   7. CHISPAS    nacen en la piel, siguen el viento con inercia, gravedad, rebotan en suelo y obstaculo; escalonadas.
## Todo en coordenadas de MUNDO. Obstaculo: caja orientada o esfera (un enemigo se trata como esfera de su radio).

const MAX_BOCANADAS: int = 90
const MAX_CHISPAS: int = 120

# ---- ajustes (la demo escala 12 m de caja y un escudo de 2,1 m; aqui un muro de 1 m y un haz de 3 m: velocidades ~1/3) ----
var viento: float = 2.6                 ## m/s a lo largo del haz (demo 8)
var arrastre: float = 0.7               ## 1/s (demo 0,7)
var empuje: float = 5.0                 ## 1/s (demo 5)
var flotacion: float = 1.5              ## m/s² por unidad de T (demo 2,8)
var remolino: float = 6.0               ## m/s² (demo 55 en su escala)
var enfriar: float = 1.0               ## 1/s (demo 1,1)
var rendimiento_hollin: float = 1.3     ## demo 1,3
var olvido_hollin: float = 0.45         ## 1/s demo 0,45
var envolver: float = 5.0               ## m/s² de tiron hacia la piel (demo 42 a su escala)
var reparto: float = 3.2                ## m/s² hacia los lados desde el punto de choque (hace de la presion de la demo)
var piel: float = 0.6                   ## m de grosor de la piel donde actua todo lo anterior (demo 0,5)
var tam_bocanada: float = 0.8           ## m de lado del billboard al nacer
var ritmo_choque: float = 28.0          ## bocanadas/s en el choque (por la rafaga)
var ritmo_punta: float = 5.0            ## bocanadas/s en la punta sin choque
var n_chispas: int = 100

# ---- el haz y el obstaculo ----
var origen: Vector3 = Vector3.ZERO      ## la mano (a la altura del chorro)
var dir: Vector3 = Vector3(0, 0, -1)    ## horizontal, unitaria
var largo: float = 3.0
var obst: int = 0                       ## 0 nada, 1 caja, 2 esfera
var o_centro: Vector3 = Vector3.ZERO
var o_semi: Vector3 = Vector3.ONE * 0.5
var o_base: Basis = Basis.IDENTITY
var o_radio: float = 0.8
var contacto: Vector3 = Vector3.ZERO
var normal_c: Vector3 = Vector3(0, 0, 1)
var hay_choque: bool = false

# ---- estado ----
var t: float = 0.0
var n: int = 0
var pos: PackedVector3Array = PackedVector3Array()
var vel: PackedVector3Array = PackedVector3Array()
var temp: PackedFloat32Array = PackedFloat32Array()      ## T 1 → 0
var hollin: PackedFloat32Array = PackedFloat32Array()
var tam: PackedFloat32Array = PackedFloat32Array()
var edad: PackedFloat32Array = PackedFloat32Array()
var vida: PackedFloat32Array = PackedFloat32Array()
var semilla: PackedFloat32Array = PackedFloat32Array()
var c_pos: PackedVector3Array = PackedVector3Array()
var c_vel: PackedVector3Array = PackedVector3Array()
var c_vida: PackedFloat32Array = PackedFloat32Array()    ## s que le quedan (<= 0: aparcada)
var c_total: PackedFloat32Array = PackedFloat32Array()
var guardas: int = 0                                     ## veces que el seguro «nada vuelve» ha tenido que actuar (para las pruebas)
var c_rebotes: int = 0                                   ## cuenta de rebotes en el suelo (para las pruebas)
var emitidas: int = 0
var _acc: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ondas: Array = []                                   ## [{k, a, fase, w}]
var _L: float = 5.0


func _init(semilla_rng: int = 7) -> void:
	_rng.seed = semilla_rng
	for i in 8:
		var k: Vector3 = Vector3(_rng.randi_range(-3, 3), _rng.randi_range(-3, 3), _rng.randi_range(-3, 3))
		if k.length() < 1.5:
			k = Vector3(2, 1, -1)
		var r: Vector3 = Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5)
		var a: Vector3 = k.cross(r)
		a = a.normalized() * pow(k.length(), -5.0 / 6.0) if a.length() > 0.001 else Vector3.UP
		_ondas.append({"k": k, "a": a, "fase": _rng.randf() * TAU, "w": _rng.randf_range(0.3, 0.9)})
	c_pos.resize(MAX_CHISPAS)
	c_vel.resize(MAX_CHISPAS)
	c_vida.resize(MAX_CHISPAS)
	c_total.resize(MAX_CHISPAS)
	for i in MAX_CHISPAS:
		c_vida[i] = 0.0
		c_total[i] = 1.0
		c_pos[i] = Vector3(0, -10, 0)
	pos.resize(MAX_BOCANADAS)
	vel.resize(MAX_BOCANADAS)
	temp.resize(MAX_BOCANADAS)
	hollin.resize(MAX_BOCANADAS)
	tam.resize(MAX_BOCANADAS)
	edad.resize(MAX_BOCANADAS)
	vida.resize(MAX_BOCANADAS)
	semilla.resize(MAX_BOCANADAS)


# ------------------------------------------------------------------ escena ------------------------------------------------------------------

func configurar(origen_: Vector3, dir_: Vector3, largo_: float) -> void:
	origen = origen_
	dir = Vector3(dir_.x, 0.0, dir_.z).normalized()
	largo = largo_
	_buscar_contacto()


func poner_caja(centro: Vector3, semi: Vector3, base: Basis) -> void:
	obst = 1
	o_centro = centro
	o_semi = semi
	o_base = base.orthonormalized()
	_buscar_contacto()


func poner_esfera(centro: Vector3, radio: float) -> void:
	obst = 2
	o_centro = centro
	o_radio = radio
	_buscar_contacto()


func quitar_obstaculo() -> void:
	obst = 0
	_buscar_contacto()


## Distancia con signo al obstaculo (negativa dentro). Sin obstaculo, muy lejos.
func sdf(p: Vector3) -> float:
	if obst == 1:
		var q: Vector3 = o_base.transposed() * (p - o_centro)
		var d: Vector3 = q.abs() - o_semi
		return Vector3(maxf(d.x, 0.0), maxf(d.y, 0.0), maxf(d.z, 0.0)).length() + minf(maxf(d.x, maxf(d.y, d.z)), 0.0)
	if obst == 2:
		return p.distance_to(o_centro) - o_radio
	return 1000.0


func normal(p: Vector3) -> Vector3:
	var e: float = 0.02
	var g: Vector3 = Vector3(sdf(p + Vector3(e, 0, 0)) - sdf(p - Vector3(e, 0, 0)), sdf(p + Vector3(0, e, 0)) - sdf(p - Vector3(0, e, 0)), sdf(p + Vector3(0, 0, e)) - sdf(p - Vector3(0, 0, e)))
	return g.normalized() if g.length() > 0.0001 else -dir


func _buscar_contacto() -> void:
	hay_choque = false
	if obst == 0:
		return
	var paso: float = 0.02
	var s: float = 0.0
	while s <= largo + 0.5:
		var p: Vector3 = origen + dir * s
		if sdf(p) < 0.0:
			# afinar: la piel esta entre s - paso y s
			var a: float = maxf(s - paso, 0.0)
			var b: float = s
			for _i in 8:
				var m: float = (a + b) * 0.5
				if sdf(origen + dir * m) < 0.0:
					b = m
				else:
					a = m
			contacto = origen + dir * a
			normal_c = normal(contacto)
			hay_choque = true
			return
		s += paso


# ------------------------------------------------------------------ campo de remolinos ------------------------------------------------------------------

## Campo sin divergencia (cada onda es a·cos(k·x) con a ⟂ k): retuerce sin comprimir. ~±1.
func flujo(p: Vector3) -> Vector3:
	var v: Vector3 = Vector3.ZERO
	for o in _ondas:
		var k: Vector3 = o["k"]
		v += (o["a"] as Vector3) * cos(TAU * k.dot(p) / _L + float(o["fase"]) + float(o["w"]) * t)
	return v * 1.6


func _ruido1(x: float) -> float:
	var i: float = floorf(x)
	var f: float = x - i
	var a: float = fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
	var b: float = fposmod(sin((i + 1.0) * 12.9898) * 43758.5453, 1.0)
	return lerpf(a, b, f * f * (3.0 - 2.0 * f))


# ------------------------------------------------------------------ paso ------------------------------------------------------------------

## `alimentado`: hay un haz vivo (con factor 0..1 de cuanto: lo usa la vista para apagar en 1-1,5 s tras el ultimo haz).
func paso(dt: float, alimentado: float) -> void:
	t += dt
	_emitir(dt, alimentado)
	_mover_bocanadas(dt)
	_mover_chispas(dt, alimentado)


func _emitir(dt: float, alimentado: float) -> void:
	if alimentado <= 0.001:
		return
	var rafaga: float = 0.3 + 1.4 * _ruido1(t * 1.9)
	var ritmo: float = (ritmo_choque * rafaga) if hay_choque else ritmo_punta
	_acc += ritmo * alimentado * dt
	while _acc >= 1.0:
		_acc -= 1.0
		if n >= MAX_BOCANADAS:
			continue
		_nacer()


func _nacer() -> void:
	var p: Vector3
	var v: Vector3
	var T0: float
	var up: Vector3 = Vector3.UP
	var lado: Vector3 = up.cross(dir).normalized()
	if hay_choque:
		# alimentacion en la piel: a 0,3 m de la superficie hacia el lanzador, disco al azar alrededor del eje del haz
		var tn: Vector3 = lado * _rng.randf_range(-1.0, 1.0) * 0.35 + up * _rng.randf_range(-0.8, 1.0) * 0.35
		p = contacto + normal_c * 0.3 + tn
		var d: float = sdf(p)
		if d < 0.12:
			p += normal(p) * (0.12 - d)
		v = normal_c * 0.5 + tn * 3.0 + up * _rng.randf_range(0.1, 0.5)
		T0 = _rng.randf_range(1.2, 1.7)
	else:
		var s: float = largo * _rng.randf_range(0.55, 0.9)
		p = origen + dir * s + lado * _rng.randf_range(-0.2, 0.2) + up * _rng.randf_range(-0.15, 0.15)
		v = dir * (viento + 4.5) + up * 0.3           # sale rapido (el chorro): mientras vaya mucho mas deprisa que el viento no se enfria ni hace hollin
		T0 = _rng.randf_range(0.8, 1.1)
	var i: int = n
	n += 1
	emitidas += 1
	pos[i] = p
	vel[i] = v
	temp[i] = T0
	hollin[i] = 0.0
	tam[i] = tam_bocanada * _rng.randf_range(0.8, 1.2)
	edad[i] = 0.0
	vida[i] = _rng.randf_range(1.8, 2.6)
	semilla[i] = _rng.randf()


func _quitar(i: int) -> void:
	n -= 1
	if i != n:
		pos[i] = pos[n]
		vel[i] = vel[n]
		temp[i] = temp[n]
		hollin[i] = hollin[n]
		tam[i] = tam[n]
		edad[i] = edad[n]
		vida[i] = vida[n]
		semilla[i] = semilla[n]


func _mover_bocanadas(dt: float) -> void:
	var w: Vector3 = dir * viento
	var i: int = 0
	while i < n:
		edad[i] += dt
		if edad[i] >= vida[i]:
			_quitar(i)
			continue
		var p: Vector3 = pos[i]
		var v: Vector3 = vel[i]
		var T: float = temp[i]
		var h: float = hollin[i]
		# 4. flotacion y 5. remolinos (a la demo le salen mas fuertes con el calor, el humo y la velocidad)
		v.y += flotacion * T * dt
		v += flujo(p) * remolino * (0.2 + T + 0.3 * h + 0.06 * v.length()) * dt * 0.5
		# 2. relajar hacia el viento y empujar hacia delante lo que va mas lento o vuelve
		v = w.lerp(v, exp(-arrastre * dt))
		var lag: float = maxf(viento - v.dot(dir), 0.0)
		v += dir * lag * (1.0 - exp(-empuje * dt))
		# 3. la piel del obstaculo
		if obst != 0:
			var d: float = sdf(p)
			if d < piel:
				var nn: Vector3 = normal(p)
				var sk: float = 1.0 - smoothstep(0.0, piel, d)
				v -= nn * minf(v.dot(nn), 0.0) * sk
				v -= nn * sk * envolver * dt
				var off: Vector3 = p - contacto
				var tang: Vector3 = off - nn * off.dot(nn)
				if tang.length() > 0.04:
					v += tang.normalized() * reparto * sk * (0.4 + T) * dt
				v.y += reparto * 0.12 * sk * T * dt
		# nada vuelve hacia el lanzador: el empuje de un sentido ya lo corrige; esto es el seguro por si un remolino o el tiron lo ganan en un paso
		var avance: float = v.dot(dir)
		if avance < 0.0:
			guardas += 1
			v -= dir * avance
		p += v * dt
		if obst != 0:
			var d2: float = sdf(p)
			if d2 < 0.05:
				p += normal(p) * (0.05 - d2)
		if p.y < 0.15:
			p.y = 0.15
			v.y = maxf(v.y, 0.0)
		# 6. enfriar y hacerse humo
		var rel: float = (v - w).length()
		var lento: float = 1.0 - smoothstep(1.6, 5.0, rel)
		var antes: float = T
		T = maxf(T * exp(-enfriar * (1.0 + 1.2 * lento) * dt) - T * T * T * T * dt * 0.4, 0.0)
		h += (antes - T) * rendimiento_hollin * lento * (1.0 - smoothstep(0.35, 0.95, T))
		h *= exp(-olvido_hollin * dt)
		pos[i] = p
		vel[i] = v
		temp[i] = T
		hollin[i] = h
		tam[i] = tam[i] + dt * (0.18 + 0.35 * h)
		i += 1


func _mover_chispas(dt: float, alimentado: float) -> void:
	var w: Vector3 = dir * viento
	for i in MAX_CHISPAS:
		if c_vida[i] > 0.0:
			c_vida[i] -= dt
			var p: Vector3 = c_pos[i]
			var v: Vector3 = c_vel[i]
			v = v.lerp(w, minf(1.6 * dt, 1.0))
			v.y -= 7.0 * dt
			p += v * dt
			if p.y < 0.04:
				p.y = 0.04
				v.y = absf(v.y) * 0.35
				c_rebotes += 1
			if obst != 0:
				var d: float = sdf(p)
				if d < 0.05:
					var nn: Vector3 = normal(p)
					p += nn * (0.05 - d)
					v -= nn * minf(v.dot(nn), 0.0) * 1.5
			c_pos[i] = p
			c_vel[i] = v
		elif alimentado > 0.001 and hay_choque and i < int(float(n_chispas) * alimentado):
			# escalonadas: cada una espera un azar antes de renacer (la demo reparte la primera vida en 2,3 s)
			if _rng.randf() < dt * 1.2:
				_chispa(i)
		else:
			c_pos[i] = Vector3(0, -10, 0)


func _chispa(i: int) -> void:
	var rnd: Vector3 = Vector3(_rng.randf() - 0.5, _rng.randf() - 0.5, _rng.randf() - 0.5) * 2.0
	var up: Vector3 = Vector3.UP
	var lado: Vector3 = up.cross(dir).normalized()
	var front: Vector3 = (rnd + normal_c * 1.2).normalized()
	var p: Vector3 = contacto + lado * _rng.randf_range(-0.6, 0.6) + up * _rng.randf_range(-0.4, 0.9) + normal_c * 0.12
	var d: float = sdf(p)
	if d < 0.12:
		p += normal(p) * (0.12 - d)
	c_pos[i] = p
	c_vel[i] = front * 1.6 + rnd * 2.4 + (-dir * 1.2 + up * 2.2)
	c_total[i] = _rng.randf_range(0.5, 1.6)
	c_vida[i] = c_total[i]
