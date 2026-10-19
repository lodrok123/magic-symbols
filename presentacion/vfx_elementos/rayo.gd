class_name VfxRayo
extends ElementoVfx

## RAYO del kit luminoso (19/10, VFX_RAYO_HIELO P5). Rampa azul → cian → blanco cálido; chispas eléctricas aditivas, bordes duros
## (`suave` bajo) y movimiento muy rápido: no es una llama, es una descarga. La bola con arcos que se re-sortean a saltos la dibuja
## `VfxEstado3D` con la forma `rayo` de Formas3D (misma pieza validada que el pilar de rayo); aquí solo el color y el carácter.

func rampa() -> Array:
	return [[0.0, Color(0.12, 0.28, 0.9)], [0.3, Color(0.2, 0.58, 1.0)], [0.6, Color(0.55, 0.9, 1.0)],
		[0.85, Color(0.9, 0.98, 1.0)], [1.0, Color(1.0, 0.98, 0.88)]]


func perfil() -> Dictionary:
	return {"luz": Color(0.45, 0.85, 1.0), "charco": Color(0.3, 0.6, 1.0), "aro": Color(0.85, 0.95, 1.0),
		"particula": [Color(1.0, 1.0, 1.0, 1.0), Color(0.5, 0.9, 1.0, 1.0), Color(0.2, 0.4, 1.0, 0.0)],
		"particula_aditiva": true, "particula_albedo": Color(1.3, 1.5, 2.0, 1.0), "marca": "quemado",
		"mult": {"velocidad": 2.0, "suave": 0.5, "potencia": 1.2}}


## El rayo cae más alto que la llama: un poco más largo.
func alto_muro(alto: float) -> float:
	return alto * 1.2
