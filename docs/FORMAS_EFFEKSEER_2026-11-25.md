# Formas de fuego, agua y tierra revisadas con el repositorio de Effekseer (25/11/2026)

Pablo: «revisa las formas para fuego, tierra y agua y busca mejoras apoyándote en el repositorio». Después, «las cinco».

Se capturaron en el lab (`LabVfxComparativa3D`, figura del elemento) el muro, el pilar, la barrera y el haz de cada elemento a 0,3, 1 y 2,5 s, y se compararon con los efectos de la demo de Effekseer que hacen lo mismo. Como en los impactos, **de Effekseer se copia el ritmo, no las piezas**: todo está dibujado con nuestros shaders y la paleta de cada elemento.

Referencias usadas:

| Forma | Efectos de Effekseer |
|---|---|
| Pilar | `ef_wind03` (anillos de aura en el suelo y espirales) y `ef_holy01` (cintas y motas que giran y suben) |
| Muro | `ef_ice02` (cristales que salen escalonados a lo largo de una línea) y `ef_ice03` (vaho que se junta antes de que brote el cristal) |
| Haz | `Laser01` y `Laser02` |

`ef_barrior01` (la barrera) no se pudo usar: su material propio no se dibuja en Godot.

Antes de tocar nada ya estaban bien y no se cambian: los muros de agua (la ola) y de tierra, el pilar de agua, la barrera de tierra y los haces.

## Cambios

| # | Forma | Antes | Ahora | Dónde |
|---|---|---|---|---|
| 1 | Barrera de fuego | Cúpula amarillo-blanca (borde blanco al máximo y la rampa hasta su final pálido) | Rojos y naranjas: la rampa se recorre solo hasta 0,62, como el haz (`BARRERA_TOPE_RAMPA`), y el borde blanco baja de 1,0 a 0,3. El aro del suelo, igual. | `fuego_barrera.gdshaderinc`, `aro_barrera.gdshader` (`tope_rampa`), `fuego_toy.gd` |
| 2 | Barrera de agua | El elipsoide provisional, liso | Membrana, según VFX_SECUENCIA_MEJORAS 19/11: vetas finas de agua que suben por los meridianos y se deshacen antes de la cima, espuma en el pie, borde más claro y centro más claro para ver lo de dentro. La espuma del borde se queda tenue mientras vive (antes solo al formarse y al caer). | `agua_esfera.gdshader` (`membrana`), `agua_toy.gd` |
| 3 | Pilar de tierra | Salía de golpe: entero a los 0,3 s | Carga como `ef_ice03`: 0,45 s de marca que se abre, temblor, polvo y piedrecitas que saltan; luego brota con una onda de polvo en anillo y cascotes. Nace en 1 s (`T_NACER_PILAR`). | `tierra_toy.gd` |
| 4 | Pilar de fuego | La columna subía recta y sola | Brasas que suben en espiral alrededor (`ef_holy01`) y aros nítidos que laten en la base (`ef_wind03`), en rojo-naranja, sin luz. Salen con el pilar y se van con él. | `pilar_adorno_toy.gd` (nuevo), `fuego_toy.gd` (`PILAR_ADORNO`) |
| 5 | Muro de agua | La ola subía entera a la vez | Cremallera como `ef_ice02`: el centro sube primero y los extremos después (`OLA_CREMALLERA`). El muro de fuego ya lo hacía desde el 17/11. | `agua_ola.gdshader`, `agua_ola_lamina.gdshader` (`cremallera`), `agua_toy.gd` |

## Hojas

En `docs/capturas/formas_2026-11-25/`:

- `antes_<elemento>.png` y `despues_<elemento>.png`: una fila por forma (muro, pilar, barrera y haz) y una columna por instante (0,3, 1 y 2,5 s).
- `1_barrera_fuego.png` a `5_ola_cremallera.png`: cada cambio de cerca.
- `referencias_effekseer.png`: los originales.

## Pruebas

Pasan sin fallos `prueba_agua_toy`, `prueba_vfx_toy`, `prueba_viento_tierra_toy`, `prueba_fases_fuego`, `prueba_carga_impacto_toy`, `prueba_estela_mundo` y `prueba_humo_regla`.

Se ajustaron tres pruebas a los cambios pedidos:

- La barrera de agua lleva ahora espuma tenue en el pie mientras vive.
- El pilar de fuego tiene dos mallas más (sus aros).
- El pilar de tierra nace en 1 s.

`prueba_vfx_en_juego` da el mismo fallo de antes (el muro de agua no se va a los 7 s), que no viene de estos cambios.
