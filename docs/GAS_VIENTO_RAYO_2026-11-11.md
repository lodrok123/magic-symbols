# Viento y rayo con el gas volumétrico (y dónde queda el agua) — 11/11/2026

Origen de la técnica: https://github.com/lejrimostfa/force-field-vfx-threejs (MIT). El port está en `laboratorios/haz_gas/` (`docs/HAZ_GAS_PORT_2026-11-09.md`) y el catálogo
de técnicas, en `docs/TECNICAS_REPO_GAS_OTROS_ELEMENTOS_2026-11-10.md`. Este documento añade dos elementos al MISMO solver, sin fork: **viento** y **rayo**. El **agua** ya
estaba (entrada 468 del diario) y no se ha tocado.

## 1. Cómo hace la demo el volumen (lo que se reutiliza)

La demo no dibuja partículas ni láminas: guarda el fuego en **texturas 3D** y las avanza con compute shaders, un paso fijo de 1/60 s.

1. **Campos en rejillas de distinta resolución.** Gas (4 canales: temperatura, hollín, polvo, combustible) a resolución entera; velocidad, presión y rotacional a la mitad;
   luz a un cuarto y a un octavo. Lo caro (la presión) va en la rejilla barata.
2. **Transporte.** El gas se mueve con MacCormack (nítido); la velocidad, con semi-Lagrangiana RK2 (suave, a propósito: da pliegues gordos y no ladrillos).
3. **Fuentes por reglas, no a mano.** El chorro es el punto más cercano de un segmento, con bamboleo y un radio que respira. El humo no se emite: es el calor que
   pierde el gas que se frena. El polvo lo levanta el aire rápido a ras de suelo.
4. **Fuerzas.** Flotación, arrastre hacia un viento de fondo, empuje de un solo sentido (nada vuelve al lanzador), piel del sólido (quita lo que entra y tira hacia la
   superficie para que el gas lo envuelva), confinamiento de vorticidad y turbulencia sin divergencia horneada.
5. **Proyección de presión** (Jacobi con arranque en caliente): es lo que hace que el gas rodee el obstáculo en vez de atravesarlo o amontonarse.
6. **Dibujo.** Un raymarch por píxel dentro de la caja del dominio, cortado contra la profundidad de la escena. En el juego no se acumula densidad: se busca la
   **superficie** del campo (umbral + bisección) y se pinta con el lenguaje toon de cada elemento.
7. **Chispas en GPU** que leen la velocidad del gas, caen y rebotan.

Lo que ya era nuestro y hace que valga para hechizos procedurales: `HazGas.derivar_haz` (dominio, rejilla y escalas a partir de largo, ancho y alto del hechizo) y el campo
de sólidos reales del nivel (`solido.glsl`, `HazGasJuego`).

## 2. Qué es «gas» en cada elemento

Un elemento nuevo son tres cosas: un juego de parámetros (`HazGas.PARAMS_ELEMENTO`), una rama en los dos kernels de fuentes (`gas_fuentes.glsl`, `vel_fuentes.glsl`) y un
dibujo (`raymarch_toon_<elemento>.glsl`). El resto de la cadena (advección, vorticidad, presión, sólidos, chispas) es común. El elemento viaja en `key_pos.w` del UBO
(0 fuego, 1 agua, 2 viento, 3 rayo).

| | Canal x | Otros canales | Lo que lo hace distinto | Dibujo |
|---|---|---|---|---|
| Fuego | temperatura | hollín, polvo, combustible | combustión, flotación, humo por regla | rampa del FuegoToy, lenguas |
| Agua | cantidad de agua | — | peso: cae y se reparte en lámina por la pared | tres tonos, cáusticas, fresnel |
| **Viento** | **ráfaga** (pulsos que viajan con el aire) | **etiquetas de línea de corriente** (y, w) y **polvo** (z) | no se pinta masa: solo los caminos del aire | trazos blancos largos con punta, funda tenue, polvo |
| **Rayo** | **ionización** (aire cargado) | — | se apaga en décimas; repta por la piel del sólido | trazo en zigzag + arcos + halo, en AZUL; el único que brilla |

### Viento

Primera versión (descartada el mismo día): una «bruma» en hélice dibujada como superficie. Pablo: «parece vapor… no parece una ráfaga sostenida de aire sino un fluido».
La conclusión es que **el aire no se puede pintar como masa**: cualquier cuerpo con borde se lee como líquido o vapor. Lo que se pinta ahora son los **caminos del aire**.

- **Líneas de corriente transportadas.** Dos canales del gas (y, w) guardan una ETIQUETA: la posición de cada punto en la sección del chorro, en radios. El gas las
  transporta sin cambiarlas, así que la curva donde las dos etiquetas son constantes es de verdad el camino que sigue el aire, también cuando rodea un sólido.
  Dentro del chorro las etiquetas son analíticas (nítidas); fuera quedan libres y la simulación las dobla.
- **Ráfaga.** El canal x son pulsos que nacen por línea en la mano (cada línea con su ritmo) y viajan a la velocidad del chorro: trazos largos que corren, aparecen y se
  van. `cool` 1,6 es lo que tardan en apagarse.
- **Velocidad.** Chorro con un giro leve alrededor del eje (`sootYield` hace aquí de `REMOLINO`), sin flotación ni peso, turbulencia y confinamiento moderados (las líneas
  se doblan y se rizan al final, no se deshacen). La ráfaga es 1,5 veces más ancha que el lápiz de fuego (`VIENTO_ANCHO`).
- **Polvo.** La regla de la demo: el aire bastante más rápido que el viento de fondo, a ras de suelo, levanta polvo, que se despeja con la altura.
- **Dibujo** (`raymarch_toon_viento.glsl`). Por cada rayo de vista se busca el punto más cercano a una línea de corriente y se afina: trazo blanco nítido, más fino en las
  puntas, con una funda muy tenue alrededor. Sin cuerpo ni contorno. El polvo es una franja terrosa plana (tonos POLVO de HumoRegla) y las chispas del solver se dibujan
  como **hojas** (una de cada ocho).

### Rayo

Un rayo no es un gas, y simular el trazo como gas no funciona (dura menos que lo que tarda la masa en formarse). Lo que sí es gas es el **aire cargado**: la simulación dice
*dónde puede haber electricidad* y el dibujo pone la electricidad encima.

- **Fuente.** Núcleo fino del chorro, mancha en el choque y carga que **repta por la piel del sólido** alrededor del contacto, a ráfagas. Enfriamiento 6/s: al cortar el haz
  quedan arcos unas décimas y se van. El aire casi no se mueve (chorro lento, turbulencia fina).
- **Dibujo** (`raymarch_toon_rayo.glsl`), de dentro a fuera con `RayoPaleta`:
  - **Trazo principal y dos ramas**: tramos rectos entre nudos al azar (9 gordos + 27 finos) de la mano al contacto, sin desvío en los extremos, que se redibujan 14 veces
    por segundo. Por cada rayo de vista se busca la distancia mínima al trazo y se afina, así sale nítido aunque el paso sea de una celda.
  - **Arcos** dentro del aire cargado: la curva donde dos componentes del flujo sin divergencia horneado (`flujo_48`, el de la turbulencia) se anulan a la vez. Como el gas
    envuelve el sólido, los arcos se ciñen a su forma real.
  - **Halo**: la ionización acumulada, en tres escalones de azul.
  - Núcleo y cuerpo tapan el fondo (se leen sobre la hierba clara); el halo se suma.
  - **Color**: en el haz de gas el trazo va en AZUL (núcleo blanco azulado, cuerpo con el HALO_BORDE), no en el amarillo de `RayoPaleta.CUERPO`, para separarlo del
    fuego (decisión de Pablo del 11/11). Los RayoToy del resto de figuras siguen como estaban.

### Agua

Sin cambios: es el modo agua del 10/11, que ya está de serie. Lo pendiente sigue siendo lo de la entrada 468 (demasiadas gotas finas, el muro bajo, grosor de la lámina).

## 3. En el juego (hechizos procedurales)

`VfxToyJuego._haz` → `HazGasJuego.haz(h, hz, suelo, vida, "viento" | "rayo")`, igual que fuego y agua: el dominio sale del Hechizo real (largo = alcance, ancho, altura de la
mano) y del primer tope de la lógica, contra las casillas, enemigos y bloques reales. Solo dibuja: daño, alcance y choques los sigue decidiendo `HechizoVivo`.

- Ajustes nuevos, **apagados de serie**: `magic_symbols/vfx_haz_gas_viento` y `magic_symbols/vfx_haz_gas_rayo`. Apagados (o sin GPU, o con el tope de 2 gases lleno) sale el
  VientoToy / RayoToy de siempre.
- Con gas, el VientoToy se esconde entero y del RayoToy quedan solo sus luces.
- Solo la figura **haz**. Proyectil, muro, pilar y barrera siguen con sus toys.

## 4. Cómo verlo

- Lab: `laboratorios/LabVfxComparativa3D.tscn`, **Z** hasta VIENTO o RAYO y **Mayús+F12** (esfera) → otra vez (muro) → otra vez sale. Dentro: **B** obstáculo, **C** cámara,
  ESPACIO chorro, U/J largo, I/K alto, O/L ancho.
- Capturas del lab: `godot --path . --resolution 1280x720 --script res://herramientas/captura_gas_elementos.gd` → `docs/capturas/vfx_en_juego/haz_gas_elementos/`
  (`<elemento>_<muro|esfera|nada>_<lateral|juego>.png` y `_corte.png` con el chorro recién cortado).
- Prueba y capturas en el Bosque 01 con hechizos reales: `godot --path . --resolution 1280x720 --script res://herramientas/prueba_haz_gas_viento_rayo.gd`
  (`<elemento>_<aire|muro>_juego.jpg` y `_lateral.jpg` en la misma carpeta).

## 5. Coste

Medido en esta sesión, 1280×720, calidad low, con hechizos reales en el Bosque 01 (ms de GPU por haz, marcas del RenderingDevice). **Los valores absolutos no valen**:
en esta máquina el haz de agua ya aprobado mide 34 ms (el diario dice 0,9–1,4 ms en la RTX 3070), así que casi seguro está corriendo en la gráfica integrada. Sirve la
comparación entre elementos en la misma máquina:

| Haz | Total | Simulación | Volumen |
|---|---|---|---|
| Agua (referencia, ya de serie) | 34 | 4,3 | 30 |
| Viento | 8–13 | 5–9 | 3–4 |
| Rayo | 6–17 | 2,5–3 | 4–14 (el pico, contra el muro) |

Queda por medir en la máquina de la 3070.

## 6. Lo que no está bien todavía

- **Viento**: el polvo apenas aparece con el haz a la altura de la mano (el aire rápido no llega al suelo salvo tras un choque). Contra un muro los trazos acaban en
  la cara y se rizan poco hacia los lados. A media resolución los trazos se ven algo dentados.
- **Rayo**: el trazo se redibuja entero cada 1/14 s; no hay una versión «un solo destello» para hechizos de 0,1 s. La rama del dibujo no conoce los enemigos: salta al
  contacto que dice la lógica, no a cada cuerpo.
- **Los dos**: solo el haz. No hay prueba de píxeles de color como la del agua (turquesa / naranja): la prueba mira la simulación y la lógica, y las capturas se han mirado a ojo.
- **Coste**: sin medir en la 3070 ni en gama media.
- **Pruebas de regresión**: `prueba_haz_gas_agua` da 1 fallo y un error de objeto liberado en esta máquina, **igual con el código de antes de este cambio** (comprobado
  con `git stash`): el gas se apaga por reloj real y aquí cada fotograma tarda demasiado. `prueba_haz_gas_juego` y `prueba_gas_haz` no se han podido dar por buenas aquí
  por lo mismo; hay que pasarlas en la otra máquina.
