class_name VfxViento
extends ElementoVfx

## VIENTO del kit luminoso (19/10). Casi invisible: blanco verdoso muy suave, rápido y con bordes difusos; las hojas y los remolinos
## (método del kit: rampa + ruido + erosión) los pone `VfxEstado3D`.

func rampa() -> Array:
	return [[0.0, Color(0.62, 0.8, 0.78)], [0.4, Color(0.78, 0.92, 0.88)], [0.8, Color(0.92, 0.98, 0.95)], [1.0, Color(1.0, 1.0, 1.0)]]


func perfil() -> Dictionary:
	return {"luz": Color(0.8, 0.95, 0.9), "charco": Color(0.7, 0.9, 0.85), "aro": Color(0.9, 1.0, 0.95),
		"particula": [Color(1.0, 1.0, 1.0, 0.9), Color(0.8, 0.95, 0.9, 0.7), Color(0.7, 0.85, 0.8, 0.0)],
		"particula_aditiva": false, "particula_albedo": Color(1.0, 1.0, 1.0, 1.0), "marca": "",
		"mult": {"velocidad": 1.8, "suave": 2.0, "potencia": 0.6, "ondula": 1.5},
		"fijar": {"opacidad": 0.55}}
