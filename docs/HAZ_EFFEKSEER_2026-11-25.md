# El haz de fuego y de agua revisado con Laser01 / Laser02 de Effekseer (25/11/2026)

Pablo: «formas aprobadas, ahora mira el haz». Después: «las cuatro».

En el juego, el chorro de fuego y el de agua no los dibuja el «toy»: los dibuja la **simulación de gas** (`HazGasJuego` → `HazGas`, laboratorios/haz_gas). El de tierra es la línea de púas de `TierraToy`: brota una tras otra desde la mano. Estaba bien y no se toca.

Capturas con la cámara del juego (`captura_vfx_en_juego.gd`, hechizo `haz`; desde hoy acepta los instantes como sexto argumento). Lo que fallaba en fuego y agua:

- El chorro **no salía de la mano**. La lógica pone `hz.desde` unos 0,7 m por delante de la jugadora, y cerca de la boquilla el gas es fino y no se dibuja.
- **Aparecía entero de golpe**: a los 0,1 s ya estaba a toda su longitud.
- **Banda plana**: el fuego era naranja uniforme y el agua cian uniforme.
- Sin nada en la mano ni en el punto donde choca.

## Cambios

| # | Qué | Cómo | Dónde |
|---|---|---|---|
| 1 | El haz sale de la mano | La BOQUILLA va en la mano (`origen` + 0,3 m hacia delante, no en `hz.desde`). Mientras vive, lenguas cortas de llama (fuego) o rocío y vaho (agua) cubren el tramo entre la mano y el principio del gas. | `presentacion/vfx/toy/haz_adornos_toy.gd` (nuevo), `vfx_toy_juego.gd` |
| 2 | Fogonazo en la mano | Al soltar: un halo y una estrella breves en el fuego, un halo tenue en el agua (Charge / LaserCore de los láseres). | `haz_adornos_toy.gd` (receta de la boquilla) |
| 3 | Golpe en el extremo | Donde la lógica dice que choca con un MURO, mientras vive: brillo, chispas y llamas (fuego), o salpicadura y espuma (agua). Es el Burst de Laser02. | `haz_adornos_toy.gd` (receta de la punta) |
| 4 | Núcleo más claro y salida que viaja | El chorro del dibujo toon crece desde la boquilla en `T_SALIDA` = 0,15 s (tiempo de juego). El shader no dibuja más allá de un límite que avanza (`look2.w`, que estaba libre). Fuego: `contraste` 1,1 → 1,5 y `escala_rampa` 1,0 → 1,25 (bordes rojos y centro naranja claro, con el tope de siempre en 0,62: nunca amarillo). Agua: `contraste` 1,0 → 1,35 y `profundidad` 0,6 → 0,9. La simulación no cambia. | `laboratorios/haz_gas/haz_gas.gd`, `haz_gas_raymarch.gd`, `shaders/raymarch_toon.glsl`, `raymarch_toon_agua.glsl`, `vista_comun.glslinc` |

Los adornos solo se ponen cuando el haz lo dibuja el gas, para no duplicar el haz «toy» del lab. Se liberan solos.

## Comprobado

- **Salida que viaja:** con `T_SALIDA` puesto a 1 s para verla (`salida_que_viaja_prueba_1s.png`), a los 0,03 s solo hay un trozo de chorro junto a la mano. Con 0,15 s dura 9 fotogramas.
- **Boquilla y punta:** probadas contra una pared en una escena aparte (`boquilla_y_punta_contra_pared.png`). En el juego la boquilla cubre el hueco de la mano (`boquilla_mano.png`).

Hojas en `docs/capturas/haz_2026-11-25/` (`antes_juego.png` y `despues_juego.png`: fuego arriba, agua abajo; 0,03, 0,07, 0,12, 0,25 y 0,5 s).

## Pruebas

- Sin fallos: `prueba_haz_tamano`, `prueba_haz_fuego_ideas` y `prueba_haz_corte_enemigos`.
- `prueba_haz_gas_agua`: 0 fallos.
- `prueba_haz_gas_juego`: 1 fallo, el amarillo del dragón, que ya fallaba igual en la copia sin estos cambios.
- `prueba_haz_gas_viento_rayo`: 3 fallos (el rayo sobre el goblin), los mismos que en la copia sin estos cambios.
- En una primera pasada, con la máquina cargada, salieron dos fallos más en el haz de gas y uno en el agua. Al repetirla no aparecieron: eran de tiempos.
- Al capturar el haz salen avisos «Parameter "material" is null». Ya salían antes de tocar el gas.
