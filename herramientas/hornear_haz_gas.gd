extends SceneTree

## HORNEA los dos recursos fijos del port del gas (laboratorios/haz_gas/, demo lejrimostfa/force-field-vfx-threejs, MIT) con los MISMOS generadores que la demo:
##   · laboratorios/haz_gas/flujo_48.bin  — src/gas/flow.js bakeFlow(48, 64): ruido SIN DIVERGENCIA (64 ondas a·cos(2π k·x + fase) con a ⟂ k, espectro k^(-5/6)),
##                                            48³ texeles RGBA8 (rgb = campo / pico · 127,5 + 127,5). 442 368 bytes, crudo, se sube tal cual a una textura 3D.
##   · laboratorios/haz_gas/roca_1024.png — src/render/rock.js bakeRock(1024): altura en 6 octavas de ruido de valor que se repite + normal (rgb) y altura (a).
## Sin ventana (todo CPU):  godot --headless --path . --script res://herramientas/hornear_haz_gas.gd  [-- flujo|roca]
## Tarda: flujo ~10-20 s, roca ~30-60 s (GDScript). Solo hace falta repetirlo si se cambian los generadores.

const DIR: String = "res://laboratorios/haz_gas/"


func _initialize() -> void:
	var que: PackedStringArray = OS.get_cmdline_user_args()
	var t0: int = Time.get_ticks_msec()
	if que.is_empty() or "flujo" in que:
		_flujo()
		print("flujo_48.bin en %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	t0 = Time.get_ticks_msec()
	if que.is_empty() or "roca" in que:
		_roca()
		print("roca_1024.png en %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


# Generador congruencial de la demo: seed = (seed * 1664525 + 1013904223) >>> 0; devuelve (seed >>> 8) / 2^24.
var _seed: int = 0


func _rnd() -> float:
	_seed = (_seed * 1664525 + 1013904223) & 0xFFFFFFFF
	return float(_seed >> 8) / 16777216.0


## Math.round de JavaScript (la mitad redondea hacia +infinito).
func _round_js(x: float) -> int:
	return int(floor(x + 0.5))


func _flujo(size: int = 48, modes: int = 64) -> void:
	_seed = 777
	var ks: Array = []
	var amps: Array = []
	var fases: PackedFloat32Array = PackedFloat32Array()
	while ks.size() < modes:
		var k: Vector3i = Vector3i(_round_js(_rnd() * 20.0 - 10.0), _round_js(_rnd() * 20.0 - 10.0), _round_js(_rnd() * 20.0 - 10.0))
		var lon: float = Vector3(k).length()
		if lon < 2.0 or lon > 10.0:
			continue
		var r: Vector3 = Vector3(_rnd() - 0.5, _rnd() - 0.5, _rnd() - 0.5)
		var a: Vector3 = Vector3(k.y * r.z - k.z * r.y, k.z * r.x - k.x * r.z, k.x * r.y - k.y * r.x)
		var norma: float = a.length()
		if norma == 0.0:
			norma = 1.0
		var gain: float = pow(lon, -5.0 / 6.0) / norma
		ks.append(k)
		amps.append(a * gain)
		fases.append(_rnd() * PI * 2.0)
	var n: int = size * size * size
	var campo: PackedFloat32Array = PackedFloat32Array()
	campo.resize(n * 3)
	var pico: float = 0.0
	var o: int = 0
	var paso: float = PI * 2.0 / float(size)
	for z in size:
		for y in size:
			for x in size:
				var vx: float = 0.0
				var vy: float = 0.0
				var vz: float = 0.0
				for m in modes:
					var k: Vector3i = ks[m]
					var a: Vector3 = amps[m]
					var c: float = cos(float(k.x * x + k.y * y + k.z * z) * paso + fases[m])
					vx += a.x * c
					vy += a.y * c
					vz += a.z * c
				campo[o] = vx
				campo[o + 1] = vy
				campo[o + 2] = vz
				pico = maxf(pico, maxf(absf(vx), maxf(absf(vy), absf(vz))))
				o += 3
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(n * 4)
	for i in n:
		for c in 3:
			datos[i * 4 + c] = clampi(int(campo[i * 3 + c] / pico * 127.5 + 127.5), 0, 255)
		datos[i * 4 + 3] = 255
	var f: FileAccess = FileAccess.open(DIR + "flujo_48.bin", FileAccess.WRITE)
	f.store_buffer(datos)
	f.close()


func _roca(size: int = 1024) -> void:
	var octavas: Array = [[6, 0.7, 3], [14, 0.55, 5], [32, 0.34, 7], [76, 0.22, 11], [170, 0.14, 13], [340, 0.07, 17]]
	var rejillas: Array = []
	for oc in octavas:
		var cells: int = oc[0]
		_seed = int(oc[2])
		var g: PackedFloat32Array = PackedFloat32Array()
		g.resize(cells * cells)
		for i in cells * cells:
			g[i] = _rnd()
		rejillas.append(g)
	var altura: PackedFloat32Array = PackedFloat32Array()
	altura.resize(size * size)
	var fs: float = float(size)
	for y in size:
		var wx_off: float = 22.0 * sin((6.0 * PI * float(y)) / fs)
		for x in size:
			var wx: float = fmod(float(x) + fs + wx_off, fs)
			var wy: float = fmod(float(y) + fs + 22.0 * sin((4.0 * PI * float(x)) / fs), fs)
			var h: float = 0.0
			for i in 6:
				var cells: int = octavas[i][0]
				var g: PackedFloat32Array = rejillas[i]
				var fx: float = wx / fs * float(cells)
				var fy: float = wy / fs * float(cells)
				var ix: int = int(floor(fx))
				var iy: int = int(floor(fy))
				var tx: float = fx - float(ix)
				var ty: float = fy - float(iy)
				tx = tx * tx * (3.0 - 2.0 * tx)
				ty = ty * ty * (3.0 - 2.0 * ty)
				var i0: int = ix % cells
				var i1: int = (ix + 1) % cells
				var j0: int = (iy % cells) * cells
				var j1: int = ((iy + 1) % cells) * cells
				var a: float = g[j0 + i0] + (g[j0 + i1] - g[j0 + i0]) * tx
				var b: float = g[j1 + i0] + (g[j1 + i1] - g[j1 + i0]) * tx
				var v: float = a + (b - a) * ty
				h += float(octavas[i][1]) * ((1.0 - absf(2.0 * v - 1.0)) if i == 1 else v)       # crestas a escala grande, grano a escala pequeña
			altura[y * size + x] = h
	var datos: PackedByteArray = PackedByteArray()
	datos.resize(size * size * 4)
	var fuerza: float = 15.0
	for y in size:
		for x in size:
			var dx: float = (altura[y * size + (x + 1) % size] - altura[y * size + (x - 1 + size) % size]) * fuerza
			var dy: float = (altura[((y + 1) % size) * size + x] - altura[((y - 1 + size) % size) * size + x]) * fuerza
			var l: float = sqrt(dx * dx + dy * dy + 1.0)
			var o: int = (y * size + x) * 4
			datos[o] = clampi(int(((-dx / l) * 0.5 + 0.5) * 255.0), 0, 255)
			datos[o + 1] = clampi(int(((-dy / l) * 0.5 + 0.5) * 255.0), 0, 255)
			datos[o + 2] = clampi(int((1.0 / l) * 0.5 * 255.0 + 127.0), 0, 255)
			datos[o + 3] = clampi(int(minf(255.0, (altura[y * size + x] / 1.5) * 255.0)), 0, 255)
	var img: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, datos)
	img.save_png(DIR + "roca_1024.png")
