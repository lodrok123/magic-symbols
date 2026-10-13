class_name ElementoVfx
extends RefCounted

## Un ELEMENTO del kit de efectos luminosos (VfxKit3D, vfx_kit_3d.gd). Cada elemento es un archivo de esta carpeta que extiende esta
## clase: dice sus colores y cómo se mueve, y si hace falta dibuja él mismo alguna pieza (el agua dibuja su bola como una burbuja).
## El kit pone `VfxKit3D.elemento` y llama a estas funciones mientras construye; lo que no se sobrescribe usa lo común.
##
## Para añadir un elemento: copiar fuego.gd, cambiar `rampa()` y `perfil()`, y añadirlo a VfxKit3D.ELEMENTOS.


## Rampa de color, de frío (el borde que se deshace) a caliente (el corazón): [[posición 0..1, Color], ...].
func rampa() -> Array:
	return [[0.0, Color.BLACK], [1.0, Color.WHITE]]


## Lo demás que cambia por elemento:
##   "luz", "charco", "aro": colores de la OmniLight, del charco de luz y del anillo del impacto.
##   "particula": [inicio, medio, fin] de las partículas; "particula_aditiva": si se suman (fuego) o se mezclan (gotas);
##   "particula_albedo": color base (> 1 = HDR).
##   "marca": lo que queda en el suelo tras un impacto: "quemado", "mojado" o "".
##   "mult": multiplica uniforms del shader en todas las piezas (velocidad, escala_ruido, suave, potencia, ondula).
##   "fijar": fija uniforms del shader en todas las piezas (burbujas, opacidad, borde_claro...).
func perfil() -> Dictionary:
	return {}


## --- Ganchos: piezas que el elemento puede hacer a su manera ---

## Dibuja la bola del proyectil en `cabeza` (el nodo que vuela). Devuelve true si la ha dibujado él; false = la bola común.
func bola(_cabeza: Node3D, _avance: Vector3, _r: float, _esc: float, _vel: float) -> bool:
	return false


## Alto del muro de este elemento a partir del alto común.
func alto_muro(alto: float) -> float:
	return alto


## Retoca el material de una capa de la tira del muro/pilar recién creada. `capa` = [z, erosión, brillo, velocidad].
func ajustar_tira(_mat: ShaderMaterial, _largo: float, _alto: float, _capa: Array) -> void:
	pass
