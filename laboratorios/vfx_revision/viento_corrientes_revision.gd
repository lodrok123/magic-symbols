extends "res://presentacion/vfx/toy/viento_corrientes.gd"

func _columna(ejes: Vector3, tiempo: float, alfa: float) -> void:
	if ejes.y / maxf(ejes.x, ejes.z) >= 2.7:
		# Acelerar la columna completa mantiene la coherencia entre hélices y vetas.
		super._columna(ejes, tiempo * 1.55, alfa)
		_hilos_rapidos(ejes, tiempo, alfa)
		return
	# Cintas inclinadas hacia arriba: alternan grosor sin formar aros apilados.
	for i in 12:
		var fase: float = fposmod(tiempo * 0.7 + float(i) * 0.618, 1.0)
		var puntos := PackedVector3Array()
		for j in 20:
			var h: float = clampf(fase - float(j) / 19.0 * 0.65, 0.0, 1.0)
			var ang: float = float(i) * 2.399 + h * 0.7 + tiempo * 0.5
			puntos.append(Vector3(cos(ang) * ejes.x * 0.85, 0.04 + ejes.y * h, sin(ang) * ejes.z * 0.85))
		var env: float = sin(fase * PI)
		_guardar(puntos, (0.045 if i % 3 else 0.15) * alfa, alfa * env * 0.85, 1.0, 0.65, true)

func _hilos_rapidos(ejes: Vector3, tiempo: float, alfa: float) -> void:
	# Dieciocho trazos extra, ascendentes, desfasados y sin engordar el disco.
	for i in 18:
		var fase: float = fposmod(tiempo * (2.6 + 0.15 * float(i % 4)) + float(i) * 0.618, 1.0)
		var largo: float = 0.26 + 0.1 * float(i % 3)
		var cabeza: float = lerpf(0.0, COL_CIMA + largo, fase)
		var puntos := PackedVector3Array()
		for j in 12:
			var nivel: float = clampf(cabeza - float(j) / 11.0 * largo, 0.0, COL_CIMA)
			var ang: float = float(i) * 2.399 + tiempo * 0.9 + nivel * 0.6
			var radio: float = 0.5 + 0.45 * fposmod(float(i) * 0.37, 1.0)
			puntos.append(Vector3(cos(ang) * ejes.x * radio, 0.08 + ejes.y * nivel, sin(ang) * ejes.z * radio))
		var env: float = smoothstep(0.0, 0.12, fase) * (1.0 - smoothstep(0.82, 1.0, fase))
		_guardar(puntos, (0.025 + 0.01 * float(i % 3)) * alfa, alfa * env * 0.85, 1.0, 0.4)

func _disco_suelo(ejes: Vector3, tiempo: float, opacidad: float) -> void:
	var peso: float = 0.12 if ejes.y / maxf(ejes.x, ejes.z) < 2.7 else 0.3
	super._disco_suelo(ejes, tiempo, opacidad * peso)
