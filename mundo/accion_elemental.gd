## AccionElemental · «un elemento actúa sobre el mundo en este punto». Datos puros (M3 de ARQUITECTURA_MODULAR.md, 13/10).
##
## Por qué: un hechizo, una tinaja que vierte, un brasero que arde o un goblin de escarcha hacen la MISMA cosa al mundo (echar
## agua, evaporar, helar…). Antes cada uno llamaba a su función de Lanzador3D; ahora todos generan una acción y la reparte
## `Mundo3D.aplicar`. El mundo NO recibe hechizos: recibe acciones.
##
## Qué NO lleva: quién la lanzó (solo `origen`, para no golpearse a sí mismo; el mundo no lo lee) ni cómo se dibuja.
class_name AccionElemental
extends RefCounted

var elemento: String = ""                  ## "fuego" | "agua" | "hielo" | "rayo" | "viento" | "tierra"
var punto: Vector3 = Vector3.ZERO          ## mundo (x, y, z) en metros
var radio: float = 0.0                     ## m; 0 = el habitual del elemento
var cantidad: float = 0.0                  ## agua: u³ (o u³/s si hay `duracion`); fuego: u³ que evapora; 0 = el habitual
var duracion: float = 0.0                  ## s; 0 = instantánea (un impacto); > 0 = continua (un chorro que dura)
var direccion: Vector3 = Vector3.ZERO      ## para viento y proyectiles
var origen: Node = null                    ## solo para NO golpearse a sí mismo
## ¿Deja huella en el ESTADO del suelo (mojada, helada, quemada)? Un impacto de verdad sí. Una acción que solo echa o quita agua de la
## simulación (el charco de una burbuja que revienta) no: la maqueta no pinta nada en el suelo ahí y el estado no debe saber más que la imagen.
var toca_suelo: bool = true


static func nueva(p_elemento: String, p_punto: Vector3, p_radio: float = 0.0, p_cantidad: float = 0.0, p_duracion: float = 0.0) -> AccionElemental:
	var a := AccionElemental.new()
	a.elemento = p_elemento
	a.punto = p_punto
	a.radio = p_radio
	a.cantidad = p_cantidad
	a.duracion = p_duracion
	return a
