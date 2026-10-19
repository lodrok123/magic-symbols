class_name VfxTierra
extends ElementoVfx

## TIERRA del kit luminoso (19/10). No brilla: es opaca y pesada. Rampa marrón oscuro → tierra → ocre claro, partículas de polvo que
## se mezclan (no aditivas) y movimiento lento. Los bloques y piedras los pone `VfxEstado3D` con Formas3D y la paleta TIERRA.

func rampa() -> Array:
	return [[0.0, Color(0.30, 0.20, 0.13)], [0.35, Color(0.51, 0.35, 0.2)], [0.7, Color(0.74, 0.55, 0.35)], [1.0, Color(0.86, 0.72, 0.5)]]


func perfil() -> Dictionary:
	return {"luz": Color(0.85, 0.65, 0.4), "charco": Color(0.6, 0.42, 0.25), "aro": Color(0.75, 0.6, 0.4),
		"particula": [Color(0.8, 0.65, 0.45, 1.0), Color(0.55, 0.4, 0.26, 1.0), Color(0.35, 0.25, 0.16, 0.0)],
		"particula_aditiva": false, "particula_albedo": Color(1.0, 1.0, 1.0, 1.0), "marca": "",
		"mult": {"velocidad": 0.3, "suave": 0.5, "potencia": 0.8}}
