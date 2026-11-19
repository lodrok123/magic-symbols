# Empalizada modular de Monte Sumicio

La lámina 4 de `Monte-Sumicio.pptx` muestra una muralla de troncos aguzados con cuerdas y un portón de tablas reforzadas. La [lámina para Meshy](empalizada_sumicio_v2.png) separa las cuatro piezas y usa el acabado de madera cálida y veta suave de las piezas del juego.

| Posición en la lámina | Pieza | Medida y encaje en Godot |
| --- | --- | --- |
| Arriba izquierda | Tramo recto A | Una casilla de **2,30 u** en X. Cinco troncos de **0,48 u** de diámetro, con centros separados **0,46 u**. Altura total de **2,51 a 2,75 u**, incluida la punta de **0,36 u**. |
| Arriba derecha | Tramo recto B | Mismo encaje que A, con variación de veta y alturas. Alternar A y B y girarlos 90° en Y para los laterales. |
| Abajo izquierda | Esquina de 90° | Pieza nueva de una casilla con un poste compartido en el encuentro. En planta, los dos brazos van desde el centro hasta dos bordes perpendiculares de la casilla, a **1,15 u** del centro. Verificar el ángulo en planta al ajustar el GLB. |
| Abajo derecha | Hoja móvil del portón | **2,26 × 2,60 × 0,34 u** para la hoja principal (ancho × alto × fondo). El refuerzo exterior del modelo actual lleva el fondo total a **0,48 u**. La bisagra está a **1,15 u** a la izquierda del centro de la casilla y gira 90° en Y. |

El vano ocupa una casilla de **2,30 u**. La hoja actual es única y se mantiene como pieza independiente para poder animarla. Recortar cada cuadrante antes de generar el GLB y ajustar la escala en Godot. Para los tramos rectos y la esquina, usar origen a ras de suelo en el centro de la casilla. Para el portón, colocar el pivote en la base del canto izquierdo.

La escena actual contiene **55 tramos y un portón**. Las cuatro esquinas son tramos rectos en la escena de partida. Al incorporar el módulo de esquina, sustituir esos cuatro tramos. La cara norte se apoya a **Y = 3,105 u**, la sur a **Y = 2,07 u** y los laterales pasan por un rellano de **Y = 2,5875 u**. Los módulos mantienen base plana y se colocan a la altura de su casilla.

Medidas tomadas de [empalizada_sumicio.gd](../../piezas/empalizada_sumicio.gd) y [Nivel_MonteSumicio.tscn](../../../mundo/datos_nivel/Nivel_MonteSumicio.tscn).
