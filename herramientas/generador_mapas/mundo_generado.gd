extends "res://presentacion/prueba_test2.gd"
## LA MAQUETA DE UN NIVEL GENERADO (17/11/2026; Pablo: «¿por qué no están aplicados los cambios en las orillas del río o los cambios en las
## juntas y los bordes que se implementaron en el Monte Sumicio?… añádelo y traslada todos los cambios de terreno a todos los mapas»).
##
## Es la maqueta de siempre con el ACABADO DEL TERRENO que en el juego está atado a dos niveles concretos. No copia nada: lo pide prestado,
## así que si esos niveles se afinan, los mapas generados lo heredan.
##   · La ORILLA (orilla integrada, silueta curva de la ribera con sus cantos, juntas suaves): la maqueta solo la prepara si el nivel se llama
##     `Bosque_01_v01` (`_preparar_contacto_suelo`). Aquí se prepara para cualquier nivel.
##   · Las JUNTAS Y LOS BORDES de Monte Sumicio (escenas/monte_sumicio_mundo.gd, `_vestir_suelo`): más relieve en el suelo y en la hierba, la
##     franja de la junta, y la frontera de la hierba rota por ruido fino (matas y calvas entremezcladas con la tierra y la piedra). Se leen
##     las constantes de aquel guion. NO se trae su empedrado: es la piedra de Sumicio; aquí la piedra son las losas del estilo del mapa.
## En estilo «cueva» las juntas no se aplican (todo el suelo es roca y la maqueta apaga el borde de hierba); la orilla sí.
## La escena la escribe el exportador del generador de mapas (exportador_mapa.gd) cuando el mapa lleva «Acabado del terreno».

const Sumicio = preload("res://escenas/monte_sumicio_mundo.gd")

## Con false, el nivel se ve como cualquier otro de la maqueta base (para comparar).
@export var acabado: bool = true


func _preparar_contacto_suelo(mat: ShaderMaterial) -> void:
	if not acabado:
		super._preparar_contacto_suelo(mat)
		return
	# La preparación es general; lo único que la ata a un nivel es su primera línea. Se le presenta ese nombre mientras dura la llamada.
	var mio: String = nivel
	nivel = "Bosque_01_v01"
	super._preparar_contacto_suelo(mat)
	nivel = mio


func _construir_suelo(dibujar: bool = true) -> void:
	super._construir_suelo(dibujar)
	if not acabado or _mat_suelo == null or estilo == "cueva":
		return
	_rugosidad = Sumicio.RUGOSIDAD_SUMICIO
	_mat_suelo.set_shader_parameter("rugosidad", _rugosidad)
	_mat_suelo.set_shader_parameter("relieve_hierba", Sumicio.RELIEVE_HIERBA_SUMICIO)
	_mat_suelo.set_shader_parameter("relieve_junta", Sumicio.RELIEVE_JUNTA_SUMICIO)
	_mat_suelo.set_shader_parameter("borde_extiende", Sumicio.BORDE_EXTIENDE_SUMICIO)
	_mat_suelo.set_shader_parameter("borde_fundido", Sumicio.BORDE_FUNDIDO_SUMICIO)
	_mat_suelo.set_shader_parameter("borde_fuerza", Sumicio.BORDE_FUERZA_SUMICIO)
	_mat_suelo.set_shader_parameter("mezcla_hierba", Sumicio.MEZCLA_HIERBA_SUMICIO)
	_mat_suelo.set_shader_parameter("borde_tinte", Sumicio.BORDE_TINTE_SUMICIO)
