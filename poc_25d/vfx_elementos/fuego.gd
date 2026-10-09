class_name VfxFuego
extends ElementoVfx

## FUEGO del kit luminoso. Fijado por Pablo el 9/10 (bola, barrera, columna y muro). Todas las piezas son las comunes del kit.


## 9/10 10:45 (Pablo, lámina Flecha_fuego): corazón crema-amarillo pálido grande, amarillo cálido, y naranja solo en el contorno.
func rampa() -> Array:
	return [[0.0, Color(0.93, 0.36, 0.06)], [0.3, Color(1.0, 0.56, 0.13)], [0.55, Color(1.0, 0.76, 0.32)],
		[0.8, Color(1.0, 0.89, 0.55)], [1.0, Color(1.0, 0.96, 0.78)]]


func perfil() -> Dictionary:
	return {"luz": Color(1.0, 0.58, 0.25), "charco": Color(1.0, 0.5, 0.18), "aro": Color(1.0, 0.62, 0.22),
		"particula": [Color(1.0, 0.85, 0.45, 1.0), Color(1.0, 0.5, 0.12, 1.0), Color(0.85, 0.25, 0.04, 0.0)],
		"particula_aditiva": true, "particula_albedo": Color(1.6, 1.1, 0.5, 1.0), "marca": "quemado"}
		
func ajustar_tira(mat: ShaderMaterial, _largo: float, _alto: float, _capa: Array) -> void:
	mat.set_shader_parameter("curva", 0.2)
	mat.set_shader_parameter("inclina", 0.15)
