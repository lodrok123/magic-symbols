# Hielo y rayo «toy» (`HieloToy`, `RayoToy`), B1, 2/11/2026

Rama `claude/b1-hielo-rayo` (worktree `E:\tmp\wt_b1_hielo_rayo`, desde `main` en 34112d15, sin push). Dos clases hermanas de `FuegoToy` y `AguaToy`, ambas `extends EfectoToy` y con la misma API (figura, `semieje_x/y/z`, `viaja`, `definir`, `describir(h)`, `desde_hechizo(h)`, `empezar_carga`, `soltar`, `impactar_en`, `rebotar`, `terminar_sin_choque`, `finalizar`, `cancelar_carga`) y las mismas cinco figuras (bola, muro, pilar, barrera, haz). `describir` es el de `FuegoToy` (misma casilla de 2,3 m, misma escala: un hechizo cambia de elemento sin cambiar de tamaño). No se ha tocado `FuegoToy` ni `AguaToy`; la máquina de carga e impacto está copiada, no compartida (como hizo `AguaToy`).

**Lámina:** `LAMINA_hielo_rayo.png` (2834 × 2426) y `LAMINA_hielo_rayo_reducida.png` (1600 × 1369): las cinco figuras de cada elemento con los tamaños de la prueba 3 y tres fotogramas del ciclo (hielo: crece, vive, se rompe; rayo: nace, vive, muere), más la paleta de cada uno leída de `hielo_paleta.gd` / `rayo_paleta.gd`.

## 1. Cómo se hizo la lámina

1. `herramientas/captura_fuego_parametrico.gd` (ampliado, no copiado): `godot --path . --script res://herramientas/captura_fuego_parametrico.gd -- <carpeta> hielo_rayo` (con ventana, 1200 × 900). Usa `LabVfxComparativa3D` (suelo, sol, glow del lab, cubos de 1 m) con `poner_elemento("hielo")` / `("rayo")`, `fuego_param(i)` (tamaño de la prueba 3 de cada figura) y la cámara «cerca» del lab (`poner_camara(1)`), la misma de `tonos`. Un tercer argumento opcional (`fuego`, `agua`, `hielo`, `rayo`) hace que los modos `celdas` y `tonos` ya existentes usen la clase de ese elemento.
2. Ciclo: **hielo** = pilar 0,5 · 4 · 0,5; fotos a 0,5 s del `lanzar` (`crece` 0,60: segundo escalón), a ~2 s (todo crecido) y a 0,55 s de `morir()` (`corte` 0,48). **Rayo** = valla (muro) 3,45 · 1,5 · 0,3, a **cámara lenta** (`Engine.time_scale = 0,1`, porque el rayo nace en 0,06 s y muere en 0,18 s y a velocidad normal una foto no lo pilla): `crece` 0,59, `crece` 1,00 y `corte` 0,41. Las esperas ignoran `time_scale`.
3. Para el rayo cada foto espera a que la intensidad del redibujo sea ≥ 0,7 (un 10 % de los redibujos casi se apaga, a propósito, y una foto al azar saldría oscura).
4. `herramientas/lamina_vfx.py --hielo-rayo <carpeta> <lamina.png> [ancho_reducido=1600]` (modo nuevo del mismo script): monta rótulos, ejes x·y·z, paleta y las celdas (540 × 405).
5. Las fotos sueltas (`hr_*.png`, 1200 × 900) no se guardan en el repositorio; se rehacen con 1.

## 2. Tonos medidos (`herramientas/medir_tonos_hielo_rayo.py`, adaptado de `medir_tonos_fuego.py`)

Cada figura se fotografía dos veces con la misma cámara, con el efecto y sin él (`hr_*_base.png`, `e.visible = false`); los píxeles del efecto son los que cambian (diferencia > 28 en algún canal). Es lo que se **ve** (el efecto mezclado con el suelo gris del lab), no los uniforms.

**Hielo** (paleta: HONDO 0,46·0,66·0,88 · CLARO 0,72·0,86·0,97 · ESCARCHA 0,86·0,93·0,99):

| Figura | Píxeles | Color medio | Azul (b > g > r) | Más cercano a hondo / claro / escarcha |
|---|---|---|---|---|
| Bola | 17 173 | 0,86 · 0,94 · 0,98 | 100 % | 0 / 2 / 98 % |
| Muro | 118 234 | 0,81 · 0,90 · 0,95 | 100 % | 1 / 37 / 63 % |
| Pilar | 41 876 | 0,82 · 0,90 · 0,94 | 100 % | 2 / 30 / 68 % |
| Barrera | 79 786 | 0,83 · 0,91 · 0,95 | 100 % | 2 / 19 / 79 % |
| Haz | 29 868 | 0,89 · 0,95 · 0,98 | 99 % | 0 / 1 / 99 % |

Lectura honesta: es **azul claro** (azul en el 99-100 % de los píxeles), pero sale **más claro que la placa helada del mundo** (CLARO 0,72·0,86·0,97): como es translúcido y se ve sobre un suelo gris claro, el color medio queda entre CLARO y ESCARCHA y casi nada cae en HONDO. No he comparado con una captura de la placa helada real del juego, solo con los valores de sus shaders. Si Pablo la quiere más oscura se baja el término `v` de `hielo_cristal.gdshader` o se sube la opacidad.

**Rayo** (paleta: CUERPO 1·0,93·0,40 · NÚCLEO 1·1·0,90 · HALO 0,35·0,62·1):

| Figura | Píxeles del efecto | Blanco | Amarillo | Azul | De los píxeles de color y brillantes: amarillo / azul |
|---|---|---|---|---|---|
| Bola | 21 570 | 20 % | 7 % | 1 % | 61 / 39 % |
| Muro | 103 748 | 12 % | 13 % | 4 % | 83 / 17 % |
| Pilar | 20 722 | 46 % | 7 % | 7 % | 64 / 36 % |
| Barrera | 37 357 | 29 % | 7 % | 3 % | 70 / 30 % |
| Haz | 70 775 | 16 % | 5 % | 6 % | 50 / 50 % |

El «resto» (40-73 %) es el suelo iluminado por la luz del rayo y los halos muy diluidos. **Cómo se llegó aquí:** la primera versión era toda aditiva y casi no tenía píxeles amarillos (0-2 %): sumar amarillo a un suelo claro da blanco, y el rayo del juego es amarillo-blanco con halo azul. Ahora el trazo son dos capas: el **cuerpo amarillo en mezcla normal** (`rayo_trazo_cuerpo.gdshader`) y encima, aditivo, el hilo blanco y el halo azul (`rayo_trazo.gdshader`). Es la única capa del rayo que no es aditiva.

## 3. Paletas (REGLA DE PABLO, 2/11: «los colores salen de lo que ya existe en el juego»)

No se ha medido el estanque helado ni una tormenta del juego con capturas: cada valor se lee del código del juego y la prueba comprueba que coincide (`prueba_hielo_toy` y `prueba_rayo_toy`, sección «paleta», leen los `.gd` del juego y los `.gdshaderinc`).

| Elemento | Color | Valor | Sale de |
|---|---|---|---|
| Hielo | CLARO | 0,72 · 0,86 · 0,97 | `presentacion/costra_hielo_3d.gd` `color_claro` (la placa helada del agua; `agua_render_3d.gd` 0,70·0,84·0,96 y `agua_capa_3d.gd` 0,78·0,90·0,98 coinciden dentro de 0,06) |
| Hielo | HONDO | 0,46 · 0,66 · 0,88 | `costra_hielo_3d.gd` `color_hondo` (= `agua_render_3d.gd` `color_hielo_hondo`) |
| Hielo | GRIETA | 0,30 · 0,50 · 0,76 | `costra_hielo_3d.gd` `color_grieta` |
| Hielo | NUCLEO / BORDE | 0,6·0,88·1,0 / 0,92·1,0·1,0 | `presentacion/vfx_3d.gd`, perfil «hielo» (`nucleo`, `borde`) |
| Hielo | ESCARCHA | 0,86 · 0,93 · 0,99 | `presentacion/vfx_estado_3d.gd`, perfil «hielo» `mota` |
| Rayo | CUERPO | 1,0 · 0,93 · 0,40 | `vfx_3d.gd` COLOR «rayo» (= `objetos/emisor_rayo_3d.gd` COLOR 1,0·0,92·0,4 = `vfx_estado_3d.gd` perfil «rayo» `hondo`) |
| Rayo | NUCLEO | 1,0 · 1,0 · 0,90 | `vfx_estado_3d.gd` perfil «rayo» `mota` |
| Rayo | HALO | 0,35 · 0,62 · 1,0 | `vfx_estado_3d.gd` perfil «rayo» `c` |
| Rayo | HALO_BORDE / HALO_HONDO | 0,5·0,82·1,0 / 0,2·0,45·0,95 | `vfx_3d.gd`, perfil «rayo» (`borde`, `nucleo`) |
| Rayo | LUZ (de la luz) | 0,62 · 0,80 · 1,0 | halo claro, casi blanco: la luz de un rayo se lee blanco azulada, no amarilla (decisión mía, no sale del juego) |

## 4. Carácter

- **Hielo, crece por etapas:** `crece` 0 → 1 en 0,9 s con la función `HieloToy.escalon`: 0 → 0,34 → 0,67 → 1 con una meseta entre cada subida (el 10 % de `crece` por subida); cada cristal arranca con su pequeño retraso. La espiga del pilar mide 1,36 · 2,68 · 4,00 m con `crece` 0,2 · 0,55 · 0,95 (medido). La escarcha de la base se extiende con ellos. **Se rompe:** `corte` 0 → 1 en 0,9 s: tiembla, se agrieta (grietas de `T_Cracks336`) y cada cristal estalla a su hora (de 0 a 0,55 de `corte`), suelta esquirlas que giran, caen con la gravedad, rebotan una vez y se quedan; la escarcha se derrite. Sin brillo propio, `blend_mix`, fresnel claro.
- **Rayo, dura muy poco:** nace en 0,06 s (medido 0,07-0,09 s contando fotogramas), muere en 0,18 s (medido 0,15-0,20 s), la línea quebrada se redibuja cada 0,05 s (28 redibujos en 1,5 s, 0,052 s de media) con otra intensidad (de 0,2 a 0,95). Valla de descargas entre postes (muro), columna de descarga (pilar, de 2 a 4 rayos que caen de la cima), aro chispeante (barrera, tres aros y cuatro arcos), arco entre la mano y el objetivo (haz), bola con seis descargas cortas y un zigzag detrás en vuelo. **Una luz** (`OmniLight3D «Luz»`, sin sombra) que sigue el parpadeo; `VfxToyJuego` la apaga en las copias sobrantes.

## 5. Pruebas (todas sin ventana, resultados reales)

| Prueba | Resultado |
|---|---|
| `prueba_hielo_toy` | FALLOS 0 (128 OK): shaders blend_mix sin emisión, paleta, cinco figuras, escalones, rotura, carga, impactos, API, 195 instancias de MultiMesh como máximo, 0 luces, lab y `VfxToyJuego` |
| `prueba_rayo_toy` | FALLOS 0 (138 OK): shaders aditivos, paleta, cinco figuras, nace y muere, parpadeo, una luz, carga, impactos, API, 202 instancias como máximo, lab y `VfxToyJuego` |
| `prueba_vfx_toy` (FuegoToy) | FALLOS 0 (243 OK) |
| `prueba_agua_toy` | FALLOS 0 (190 OK); se cambió una línea: la parte del lab vuelve al fuego con `poner_elemento("fuego")` porque Z ya no es un interruptor de dos estados |
| `prueba_vfx_en_juego` | FALLOS 0 (256 OK), **ampliada a fuego, agua, hielo y rayo** con el selector encendido |

En `prueba_vfx_en_juego` el hielo pide tres excepciones (la prueba las dice): la lógica rechaza el pilar de hielo de prueba por altura (`cast_rechazado_altura`: no hay nada que dibujar), el haz de un estado sólido no emite `haz` (sale por `desde_hechizo` como volumen, figura 1) y un bloque de hielo **sube el terreno** de su casilla, así que el suelo se mide antes de lanzar.

## 6. Qué queda a medias

- Los impactos y las cargas son **primeras versiones sencillas** (esquirlas y cristales que brotan, descargas y chispas); no hay lámina de ellos. `Y` (estilos de impacto) sigue siendo solo del fuego.
- El **hielo y el rayo en el juego real no se han visto con ventana**: solo en el lab y en las pruebas sin ventana. Con `magic_symbols/vfx_procedural = true` salen estos dos en lugar de `VfxElemento3D`, pero los efectos de **estado** del hielo y del rayo (`VfxEstado3D`, la costra helada, el rayo de los puzles) siguen siendo los de siempre.
- El rayo nuevo no se ha comparado en pantalla con una tormenta ni con el emisor de rayo del juego, solo con sus colores.
- Sin precalentar los shaders (posible tirón en el primer lanzamiento, igual que fuego y agua).
- Mandos de `EfectoToy` que no hacen nada: hielo (`halo`, `tono`, `blandura`, `ondulacion`, `luz`), rayo (`altura`, `halo`, `tono`, `blandura`, `ondulacion`).
- El hielo sale más claro que la placa helada del mundo (ver §2).

## 7. Horas (reloj del PC, 2/11)

Ver la entrada 342 del diario.


## Ronda bola (3/11)

Rama `claude/b1b-bola-rayo` (worktree `E:\tmp\wt_b1b_bola_rayo`, desde `main` en 6afb9b2d, sin push). Solo la BOLA de `RayoToy` (quieta, en carga, en vuelo y su muerte); muro, pilar, barrera, haz, HieloToy, FuegoToy, AguaToy y la paleta no se tocan.

**Lámina:** `LAMINA_bola_rayo.png` (2834 × 2156) y `LAMINA_bola_rayo_reducida.png` (1600 × 1217). Filas: quieta (antes de B1 y después, en cámara «cerca» y en cámara del juego), carga a tres momentos (progreso 0,22 / 0,5 / 0,95), vuelo (lateral y juego, antes y después) y muerte a tres momentos (corte 0,2 / 0,45 / 0,75, a cámara lenta ×10). Las fotos «antes» de B1 están en `bola_antes_b1/` (se sacaron con una copia temporal de `rayo_toy.gd` de `6afb9b2d`, con otro `class_name`, que no se guarda).

**Cómo se rehace:** `godot --path . --script res://herramientas/captura_fuego_parametrico.gd -- <carpeta> bola_rayo rayo [antes]` (con ventana, 1200 × 900; `antes` necesita la copia temporal en `presentacion/vfx/toy/_antes_tmp/rayo_toy_b1.gd`) y `python herramientas/lamina_vfx.py --bola-rayo <carpeta> <lamina.png>`. La cámara del juego es ortogonal, tamaño 6 y 30° de elevación (las del lab).

**Qué cambió:** de seis trazos que salían del centro a una esfera de energía: cuerpo esférico (`rayo_bola.gdshader`, `blend_mix`, fresnel: blanco al centro, amarillo del rayo del juego, canto algo más oscuro, velo azul, vetas que crepitan) + halo azul detrás + seis arcos que recorren la superficie + tres que saltan y vuelven (todo se redibuja cada 0,05 s). Núcleo ≥ 0,6 siempre. En vuelo: destello de cabeza solo en vuelo, cola corta (≤ 2 diámetros) que nace dentro de la cabeza y hasta 16 chispas que se quedan atrás y caen. Carga: la esfera ya lo es a medio crecer y los arcos salen de su superficie. Muerte: `morir` anima `corte` (0,15 s): la esfera se contrae y revienta en ocho arcos cortos y chispas.

**Rondas de captura (mirando cada imagen):** (1) ya se leía como esfera, pero era lechosa y casi blanca, sin contorno; arcos gordos y pálidos; chispas minúsculas → más amarillo (blanco solo en el centro), canto oscurecido, arcos más finos y brillantes, saltos más bajos, chispas más grandes. (2) Amarilla y con volumen; una foto salió casi transparente porque la herramienta fotografiaba antes de que acabara «nacer» (arreglado en la herramienta); la cola, fina → más gruesa. (3) Lámina completa y revisada.

**Presupuesto (medido, `prueba_rayo_toy`):** 239 instancias de MultiMesh como máximo en todo el ciclo (≤ 300), 1 luz, 0 GPUParticles3D; la esfera es un MeshInstance3D (cuenta como 1 material de mezcla normal, junto con la capa del cuerpo del trazo).

**Lo que no sale bien:** en la cámara del juego la bola mide unos 120 px de 900 y los arcos finos se pierden algo (el cuerpo amarillo sí se lee); el reventón a veces deja arcos algo gruesos y pálidos; las chispas de vuelo no chocan con nada, solo se apagan al bajar de la altura del suelo; el impacto (GOLPE, FIN) es el de B1; no se ha visto en el juego real con ventana.