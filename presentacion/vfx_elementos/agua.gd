class_name VfxAgua
extends ElementoVfx

## AGUA del kit luminoso (9/10, láminas de Pablo de las 11:35 y 11:47). Usa las piezas comunes con su rampa y sus ajustes, salvo dos:
## la bola es una BURBUJA que chorrea (`bola`) y el muro es una OLA (`ajustar_tira`, `alto_muro`).


## 11:47 (Pablo, segunda lámina): azul celeste, como vidrio.
func rampa() -> Array:
	return [[0.0, Color(0.25, 0.55, 0.85)], [0.3, Color(0.42, 0.7, 0.95)], [0.6, Color(0.62, 0.84, 0.99)],
		[0.85, Color(0.82, 0.93, 1.0)], [1.0, Color(0.96, 0.99, 1.0)]]


func perfil() -> Dictionary:
	return {"luz": Color(0.55, 0.78, 1.0), "charco": Color(0.45, 0.72, 1.0), "aro": Color(0.7, 0.88, 1.0),
		"particula": [Color(0.92, 0.98, 1.0, 1.0), Color(0.55, 0.8, 1.0, 1.0), Color(0.3, 0.55, 0.9, 0.0)],
		"particula_aditiva": false, "particula_albedo": Color(1.0, 1.0, 1.0, 1.0), "marca": "mojado",
		# El agua no es una llama: fluye más despacio, con manchas más grandes, bordes más suaves, puntas redondeadas y más ondulación.
		# 11:35 (Pablo): más ruido (más fino) para que se lea como fluido, y burbujas; translúcida como en su lámina.
		"mult": {"velocidad": 0.7, "escala_ruido": 1.2, "suave": 1.5, "potencia": 0.7, "ondula": 1.6},
		"fijar": {"burbujas": 0.6, "opacidad": 0.78, "borde_claro": 0.8}}


## Bola de AGUA (Pablo, 11:47): una burbuja que chorrea. Esfera con el contorno claro por fresnel y el interior casi transparente,
## un brillo pequeño arriba, cintas finas que salen hacia atrás (de la mano a la bola) y gotas que caen de ella.
func bola(cabeza: Node3D, avance: Vector3, r: float, esc: float, vel: float) -> bool:
	var piel: ShaderMaterial = VfxKit3D.material({"cerrado": true, "eje": VfxKit3D.EJE_BORDE, "erosion": 0.25, "suave": 0.25, "brillo": 1.05, "calor_max": 0.9,
		"fresnel_pot": 2.2, "peso_ruido": 0.7, "ondula": 0.1 * esc, "ondula_freq": 10.0, "escala_ruido": Vector2(2.5, 2.0), "velocidad": Vector2(0.15, 0.4)})
	VfxKit3D._malla(cabeza, VfxKit3D._esfera(r * 1.15), piel)
	var brillo_mi: MeshInstance3D = VfxKit3D._malla(cabeza, VfxKit3D._esfera(r * 0.16), VfxKit3D._material_plano(VfxKit3D.mancha(), Color(1, 1, 1), 1.2))
	brillo_mi.position = Vector3(-0.35, 0.55, 0.35) * r
	# Cintas (Pablo, 11:55: «repártelas por la superficie»): 6 conos finos que nacen en un anillo alrededor de la parte de atrás de la
	# burbuja, cada uno con su largo y un poco abierto hacia fuera, y ondulan. Juntos hacen el chorro que la sigue.
	var largo: float = r * (0.3 + clampf(vel, 2.0, 16.0) * 0.25)   # 12:01 (Pablo): la mitad de largas cambiado a 0,75 / 0,55
	var y: Vector3 = -avance.normalized()
	var x: Vector3 = y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	var n_cintas: int = 3
	for i in range(n_cintas):
		var ang: float = float(i) / float(n_cintas) * TAU + 0.3
		var radial: Vector3 = (x * cos(ang) + z * sin(ang)).normalized()      # dirección hacia fuera, perpendicular al vuelo
		var k: float = 0.22 + 0.12 * float((i * 7) % 3) / 2.0                  # grosor
		var l: float = largo * (0.65 + 0.35 * float((i * 5) % 4) / 3.0)        # largo distinto en cada una
		# 11:58 (Pablo): mucho más ruido en las cintas: más peso del ruido, más fino, más erosión y más ondulación.
		var mat_c: ShaderMaterial = VfxKit3D.material({"cerrado": true, "erosion": 0.4, "suave": 0.12, "brillo": 1.0, "calor_max": 0.8, "peso_ruido": 1.5,
			"ondula": 0.13 * esc, "ondula_freq": 14.0, "escala_ruido": Vector2(2.6, 1.8), "velocidad": Vector2(0.4, 2.4), "fase": float(i) * 0.37})
		mat_c.render_priority = -1
		var mi: MeshInstance3D = VfxKit3D._malla(cabeza, VfxKit3D._cono(r * k, l), mat_c)
		# El eje de la cinta va hacia atrás y se abre un poco hacia fuera; nace en la superficie de la burbuja.
		var eje: Vector3 = (y + radial * 0.22).normalized()
		var ex: Vector3 = eje.cross(radial).normalized()
		var ez: Vector3 = ex.cross(eje).normalized()
		mi.basis = Basis(ex, eje, ez)
		var nace: Vector3 = radial * r * 0.75 + y * r * 0.55
		mi.position = nace + eje * l * 0.5
	# Gotas que se desprenden y caen
	VfxKit3D.particulas(cabeza, Vector3.ZERO, 16, 0.7, 0.07 * esc, 0.6, false, true, r * 0.9, -7.0, Vector3.DOWN, 50.0)
	return true


## RAYO de agua (21/10, ᛁ `linea` + agua): un CHORRO de la mano a la punta. El cuerpo es el haz translúcido del kit con la rampa del agua (borde claro, burbujas que suben por él y la
## cuña que sale de la mano); encima, gotas que se desprenden y caen a lo largo, y donde da, una salpicadura hacia arriba y el charco de luz. `esc` = tamaño; `suelo` = y del suelo bajo
## la punta (NAN = la de la punta). Se libera solo a los `vida` s. Devuelve el haz. Hay que llamarlo con `VfxKit3D.elemento = "agua"` (lo pone `VfxElemento3D._con_elemento`).
static func chorro(padre: Node3D, desde: Vector3, hasta: Vector3, vida: float, esc: float = 1.0, suelo: float = NAN) -> Node3D:
	if padre == null or not is_instance_valid(padre) or not padre.is_inside_tree():
		return null
	var k: float = clampf(esc, 0.5, 2.0)
	var y_s: float = suelo if not is_nan(suelo) else hasta.y - 0.1
	var d: Vector3 = hasta - desde
	var dir: Vector3 = d.normalized() if d.length() > 0.001 else Vector3.RIGHT
	var raiz: Node3D = VfxKit3D.haz(padre, desde, hasta, vida, k, y_s)
	# gotas que se desprenden del chorro y caen (a lo largo de todo él: nacen en la mano y salen a la velocidad del chorro)
	VfxKit3D.particulas(raiz, Vector3.ZERO, 22, 0.55, 0.07 * k, maxf(d.length() * 1.6, 2.0), false, true, 0.06 * k, -6.0, dir, 14.0)
	var punta := Vector3(hasta.x, y_s, hasta.z)
	VfxKit3D.particulas(padre, punta + Vector3(0.0, 0.1, 0.0), 14, 0.6, 0.08 * k, 2.2, false, false, 0.15 * k, -7.0, Vector3.UP, 60.0)
	VfxKit3D.charco(padre, punta, 0.6 * k, 1.0, vida)
	return raiz


## La ola de agua es más alta que el muro de fuego (lámina de Pablo, 11:47).
func alto_muro(alto: float) -> float:
	return alto * 2.5


func ajustar_tira(mat: ShaderMaterial, largo: float, alto: float, capa: Array) -> void:
	# Muro de AGUA (Pablo, 11:47): una ola. Arriba, arcos (crestas) en vez de lenguas; el agua cae (ruido hacia abajo, en
	# chorros verticales finos) y el contorno se aclara.
	mat.set_shader_parameter("ondas", maxf(1.0, roundf(largo / 2.0)))
	mat.set_shader_parameter("velocidad", Vector2(0.0, -1.1 * float(capa[3])))
	mat.set_shader_parameter("escala_ruido", Vector2(largo / 0.4, alto * 0.08))
	mat.set_shader_parameter("potencia", 0.7)
	mat.set_shader_parameter("peso_ruido", 0.15)        # que mande la forma de los arcos, no el ruido
	mat.set_shader_parameter("erosion", float(capa[1]) - 0.16)
