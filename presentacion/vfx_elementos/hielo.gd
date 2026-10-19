class_name VfxHielo
extends ElementoVfx

## HIELO del kit luminoso (19/10, VFX_RAYO_HIELO P5). Rampa azul hondo → hielo claro → blanco; no aditivo (copos que se ven sobre fondo
## claro), casi quieto (`velocidad` × 0,15) y facetado. Los cristales (forma `cristal` de Formas3D) y la escarcha los pone `VfxEstado3D`.

func rampa() -> Array:
	return [[0.0, Color(0.16, 0.34, 0.74)], [0.35, Color(0.45, 0.72, 0.95)], [0.7, Color(0.78, 0.92, 1.0)], [1.0, Color(1.0, 1.0, 1.0)]]


func perfil() -> Dictionary:
	return {"luz": Color(0.6, 0.85, 1.0), "charco": Color(0.5, 0.78, 1.0), "aro": Color(0.8, 0.94, 1.0),
		"particula": [Color(1.0, 1.0, 1.0, 1.0), Color(0.7, 0.9, 1.0, 1.0), Color(0.45, 0.7, 1.0, 0.0)],
		"particula_aditiva": false, "particula_albedo": Color(1.0, 1.0, 1.0, 1.0), "marca": "escarcha",
		"mult": {"velocidad": 0.15, "suave": 0.6, "ondula": 0.2}}
