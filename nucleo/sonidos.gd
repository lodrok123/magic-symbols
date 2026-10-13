class_name Sonidos
extends RefCounted

## SONIDOS SINTETIZADOS en código (no hay audio de mochila ni de monedas en el proyecto).
## Cada uno se genera una vez como AudioStreamWAV de 16 bits y se cachea.

const RATE: int = 22050
static var _cache: Dictionary = {}


static func _wav(muestras: PackedFloat32Array) -> AudioStreamWAV:
	var datos := PackedByteArray()
	datos.resize(muestras.size() * 2)
	for i in range(muestras.size()):
		datos.encode_s16(i * 2, int(clampf(muestras[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = datos
	return w


static func _generar(nombre: String) -> AudioStreamWAV:
	var m := PackedFloat32Array()
	match nombre:
		"bolsa":
			# Roce de tela (ruido filtrado con envolvente irregular) + clic de hebilla.
			var n: int = int(RATE * 0.45)
			m.resize(n)
			var prev: float = 0.0
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in range(n):
				var t: float = float(i) / float(RATE)
				var env: float = (0.55 + 0.45 * sin(t * 38.0)) * exp(-t * 6.0) * minf(1.0, t * 90.0)
				var ruido: float = rng.randf_range(-1.0, 1.0)
				prev = prev * 0.72 + ruido * 0.28
				m[i] = (ruido - prev) * 0.55 * env
			var clic: int = int(RATE * 0.16)
			for i in range(int(RATE * 0.03)):
				var t2: float = float(i) / float(RATE)
				m[clic + i] += sin(TAU * 1800.0 * t2) * exp(-t2 * 220.0) * 0.6
		"moneda":
			var n2: int = int(RATE * 0.22)
			m.resize(n2)
			for i in range(n2):
				var t3: float = float(i) / float(RATE)
				var f: float = 1318.0 if t3 < 0.07 else 1760.0
				m[i] = sin(TAU * f * t3) * exp(-t3 * 14.0) * 0.45
		"pocion":
			var n3: int = int(RATE * 0.35)
			m.resize(n3)
			for i in range(n3):
				var t4: float = float(i) / float(RATE)
				var f2: float = 300.0 + 700.0 * t4 + 90.0 * sin(t4 * 60.0)
				m[i] = sin(TAU * f2 * t4) * sin(PI * t4 / 0.35) * 0.4
		"recoger":
			var n4: int = int(RATE * 0.18)
			m.resize(n4)
			for i in range(n4):
				var t5: float = float(i) / float(RATE)
				m[i] = sin(TAU * (500.0 + 2400.0 * t5) * t5) * exp(-t5 * 16.0) * 0.4
		"golpe":
			var n5: int = int(RATE * 0.12)
			m.resize(n5)
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 3
			for i in range(n5):
				var t6: float = float(i) / float(RATE)
				m[i] = (rng2.randf_range(-1.0, 1.0) * 0.5 + sin(TAU * 140.0 * t6) * 0.7) * exp(-t6 * 38.0)
		"comprar":
			var n6: int = int(RATE * 0.3)
			m.resize(n6)
			for i in range(n6):
				var t7: float = float(i) / float(RATE)
				var f3: float = 880.0 if t7 < 0.1 else (1109.0 if t7 < 0.2 else 1319.0)
				m[i] = sin(TAU * f3 * t7) * exp(-fmod(t7, 0.1) * 18.0) * 0.4
		_:
			m.resize(10)
	return _wav(m)


## Reproduce un sonido sin posición (interfaz). `origen` solo sirve para colgar el
## reproductor del árbol; sigue sonando con el juego en pausa.
static func play(origen: Node, nombre: String, db: float = -6.0, tono: float = 1.0) -> void:
	if origen == null or not origen.is_inside_tree():
		return
	if not _cache.has(nombre):
		_cache[nombre] = _generar(nombre)
	var p := AudioStreamPlayer.new()
	p.stream = _cache[nombre]
	p.volume_db = db
	p.pitch_scale = tono
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	origen.get_tree().root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
