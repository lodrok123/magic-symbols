# Santa Compaña: inventario de animaciones (21/11/2026)

Encargo de Pablo: «fíjate en la leyenda… revisa las animaciones y, basándote en la propia leyenda, inventaría con Mixamo qué podrías necesitar y propón un inventario para el enemigo. Primero inténtalo generando por código».

## La leyenda, en lo que toca a las animaciones

- Una **procesión nocturna de ánimas** con hábito y capucha, en fila, cada una con una **vela** encendida. Se las nota por el olor a cera, un **viento frío** y, a veces, el tañido de una **campanilla**.
- Delante va **un vivo condenado** que porta la **cruz** (en algunas versiones, también un caldero de agua bendita). No puede soltarla: solo se libra **pasándosela a otro**.
- Rezan una **letanía**. A quien se cruza con ellas se le aparecen; para protegerse se traza un círculo en el suelo o se tumba boca abajo.
- La niebla del juego (la cruz que «absorbe vida») sale de ese viento frío que las acompaña.

## Lo que ya hay

Origen: «Meshy» = clips propios de `santa_compana_clips.glb` / modelo; «Mixamo» = `arte/meshy/mixamo_clips.glb` (los 21 clips convertidos que hay en este PC; el dataset completo no está en esta máquina).

| Momento | Clip | Origen | Estado |
|---|---|---|---|
| Andar en procesión (vela) | Unsteady_Walk → «Walking» | Meshy → Mixamo | hecho |
| Andar el guía (cruz) | Spear_Walk | Meshy → Mixamo | hecho (al pasar la cruz en caliente la nueva guía sigue con el andar de vela: limitación conocida) |
| Reposo | Idle (de la elfa) | Meshy | hecho (comprobado por `prueba_santa_compana`) |
| Recibir golpe | FacePunchReaction | Meshy | hecho (comprobado) |
| Morir | Dead | Meshy | hecho (comprobado) |
| Surgir de la tierra (reposición) | Getting_Up | Mixamo | hecho |
| Recoger la cruz del suelo | CollectObject (recortado) | Meshy | hecho |
| Maldición del guía | MageSoellCast001 | Meshy | hecho |
| **Invocar la niebla** (nace/vuelve la niebla) | `InvocarNiebla` | **código** (21/11) | primera versión: mano libre arriba y mirada al cielo, con la cruz plantada. Gesto sutil |

## Lo que propongo añadir

Primero por código (como el brazo ardiendo del goblin o la mano quemada); a Mixamo solo si el código no da.

| Prioridad | Momento | Propuesta | Cómo |
|---|---|---|---|
| 1 | **Alzar la cruz** por encima de la cabeza al invocar la niebla | El gesto que pide la leyenda | Por código se probó el 21/11 y **no sale**: la cruz agarrada a la mano se queda horizontal a lo largo del antebrazo. Hace falta, o retocar la transformación de agarre de la cruz en `Equipo3D` para el modo agarrado, o un clip de Mixamo con algo sujeto en alto con las dos manos (buscar «Holding Torch», «Raising Staff», «Victory» o «Cheering»). |
| 2 | **Letanía** (en reposo, cuando la fila está parada) | Las ánimas rezan con la cabeza baja | `Praying_2` de Mixamo **ya está** en `mixamo_clips.glb`; falta añadirlo como fuente a la familia de la Santa Compaña. |
| 3 | **Campanilla** (la última de la fila, de vez en cuando) | Un toque de campana corto | Por código sobre el Idle (sacudida de muñeca, como la mano quemada) + la pieza «campanilla» (no existe: placeholder) y su sonido. |
| 4 | **Ofrecer la cruz** (el guía la tiende a la jugadora antes de maldecir) | Fiel a la leyenda: el condenado busca a quién pasársela | `Ofrecer` de la jugadora (`jugadora_clips.glb`) retargeteado, o por código (brazo derecho al frente). |
| 5 | **Desvanecerse** al romperse la procesión | Que no «mueran» como un goblin | Mejor VFX que clip: disolver por celdas (`Ocluso3D`, el mismo del escudo quemado) sobre el Dead. |
| 6 | **Deslizarse** en vez de andar (opcional) | Las ánimas no pisan | Por código: el andar con los pies quietos y un vaivén de cadera, o solo bajar el paso del clip. |

## Qué decide Pablo

- Si el alzar la cruz se arregla por código (retocar el agarre) o se busca en Mixamo.
- Qué filas de la tabla de arriba entran en la demo.
