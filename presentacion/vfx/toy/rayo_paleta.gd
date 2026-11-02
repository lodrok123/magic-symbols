extends RefCounted

## PALETA CENTRAL DEL RAYO DE HECHIZO. REGLA DE PABLO (2/11/2026): «los colores salen de lo que ya existe en el juego, para que se sienta igual».
## La referencia es el RAYO DEL JUEGO tal como se ve: amarillo-blanco con halo azul (el emisor de rayo de los puzles, el rayo de VfxElemento3D / VfxKit3D y el perfil «rayo» de los estados). Es el único de los
## cuatro elementos nuevos que BRILLA: los shaders del rayo son aditivos y unshaded (el halo azul es lo que hace que el amarillo no se vea plano).
## De dónde sale cada valor (leído del código del juego; no medido en capturas):
##  · CUERPO     = vfx_3d.gd COLOR «rayo» 1.0,0.93,0.40 (el trazo amarillo). Coincide con objetos/emisor_rayo_3d.gd COLOR 1.0,0.92,0.4 (el emisor de los puzles) y con vfx_estado_3d.gd PERFIL «rayo» `hondo` 1.0,0.93,0.40.
##  · NUCLEO     = vfx_estado_3d.gd PERFIL «rayo» `mota` 1.0,1.0,0.90 (el centro blanco del trazo; vfx_elementos/rayo.gd DESC_COLOR_NUCLEO es 1.0,1.0,0.9: el mismo).
##  · HALO       = vfx_estado_3d.gd PERFIL «rayo» `c` 0.35,0.62,1.0 (el halo azul claro; el rayo de vfx_elementos/rayo.gd lleva 0.25,0.6,1.0 de halo: dentro de 0,1).
##  · HALO_BORDE = vfx_3d.gd perfil «rayo» `borde` 0.5,0.82,1.0 (el borde claro del halo).
##  · HALO_HONDO = vfx_3d.gd perfil «rayo» `nucleo` 0.2,0.45,0.95 (el azul profundo de lo más lejano al trazo).
## Reparto en el trazo (de dentro a fuera): NUCLEO (blanco, un hilo) → CUERPO (amarillo) → HALO_BORDE → HALO → HALO_HONDO (azul que se apaga). En el suelo y en las paredes el rayo no deja nada propio: solo el destello.
## Los shaders (rayo_toy.gdshaderinc) llevan estos mismos valores como defaults y RayoTrazos.material() los pasa como uniforms: si se cambian aquí hay que cambiarlos también en el .gdshaderinc (la prueba
## prueba_rayo_toy lo comprueba leyendo el fichero).

const NUCLEO: Color = Color(1.0, 1.0, 0.90)
const CUERPO: Color = Color(1.0, 0.93, 0.40)
const HALO: Color = Color(0.35, 0.62, 1.0)
const HALO_BORDE: Color = Color(0.5, 0.82, 1.0)
const HALO_HONDO: Color = Color(0.2, 0.45, 0.95)
## Color de la luz del destello (halo claro, casi blanco: la luz de un rayo se lee blanco azulada, no amarilla).
const LUZ: Color = Color(0.62, 0.80, 1.0)

## nombre del uniform → valor, para pasarlos a cualquier ShaderMaterial del rayo.
static func uniforms() -> Dictionary:
	return {"color_nucleo": NUCLEO, "color_cuerpo": CUERPO, "color_halo": HALO, "color_borde": HALO_BORDE, "color_hondo": HALO_HONDO}
