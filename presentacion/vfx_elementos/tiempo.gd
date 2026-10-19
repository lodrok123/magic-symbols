class_name VfxTiempo
extends ElementoVfx

## TIEMPO del kit luminoso (19/10). Violeta profundo → lila → oro pálido (arena y reloj), aditivo y lento, con anillos.

func rampa() -> Array:
	return [[0.0, Color(0.28, 0.14, 0.55)], [0.35, Color(0.52, 0.33, 0.85)], [0.65, Color(0.85, 0.7, 0.95)], [1.0, Color(1.0, 0.92, 0.7)]]


func perfil() -> Dictionary:
	return {"luz": Color(0.7, 0.55, 1.0), "charco": Color(0.55, 0.4, 0.9), "aro": Color(0.95, 0.85, 0.6),
		"particula": [Color(1.0, 0.92, 0.7, 1.0), Color(0.7, 0.55, 1.0, 1.0), Color(0.35, 0.2, 0.7, 0.0)],
		"particula_aditiva": true, "particula_albedo": Color(1.3, 1.1, 1.6, 1.0), "marca": "",
		"mult": {"velocidad": 0.5, "suave": 1.2}}
