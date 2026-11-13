# VFX de hechizos: matriz de cobertura (13/11/2026)

Qué dibuja cada casilla de elemento × figura y de elemento × tiempo, y qué huecos quedan. Acompaña a `VFX_HECHIZOS_VIGENTE_2026-11-13.md`, que explica el mecanismo.

**Cómo se ha hecho.** Leyendo el enganche (`presentacion/vfx_toy_juego.gd`), las cabeceras de los toys, los interruptores de las capas y `project.godot`, a 13/11 (`main`, bd03f739). **No se ha lanzado el juego ni se han mirado capturas**: dice qué código dibuja cada cosa, no cómo se ve. Las cabeceras de los toys pueden ir por detrás del código (la de `MagmaToy` aún describe el haz como un `FuegoToy` oscuro, y desde la entrada 442 son púas ígneas).

**Leyenda.**
- **toy** = lo dibuja el toy del elemento, encendido de serie.
- **gas** = lo dibuja `HazGasJuego`; entre paréntesis, el plan B.
- **antiguo** = lo dibuja `VfxElemento3D` con las piezas de `presentacion/vfx_elementos/`.
- **—** = no hay nada propio.

## 1. Estado por elemento

| elemento | cómo se obtiene | toy | en el juego |
|---|---|---|---|
| Fuego | runa | `FuegoToy` | toy |
| Agua | runa | `AguaToy` | toy |
| Rayo | runa | `RayoToy` (versión revisada) | toy |
| Tierra | runa | `TierraToy` | toy |
| Viento | runa | `VientoToy` (cintas de `viento_corrientes.gd`) | toy |
| Magma | libro avanzado: fuego + tierra | `MagmaToy` | toy |
| Hielo | runa | `HieloToy`, completo | **antiguo**: no está en `vfx_procedural_elementos` |
| Naturaleza | runa `naturaleza_rune.tres` | no hay toy de jugadora. `NaturalezaProyectilToy` y `NaturalezaBarreraToy` son de los enemigos (`bola_veneno_3d.gd`, `escudo_naturaleza_3d.gd`) | sin comprobar qué sale al lanzarla |
| Tiempo | runa | **fuera de los hechizos procedurales** (decisión de Pablo, 13/11): es un elemento cinemático, de historia | antiguo (`vfx_elementos/tiempo.gd`, piezas del kit) |

El **tiempo** no entra en las tablas de abajo ni cuenta como hueco: no tendrá toy ni entrada en `vfx_procedural_elementos`. Su runa ya lleva la etiqueta `cinematico`.

## 2. Elemento × figura

| | BOLA | MURO | PILAR | BARRERA | HAZ |
|---|---|---|---|---|---|
| **Fuego** | toy: billboard con cabeza, cola y estelas | toy: banda de lenguas | toy: cilindro de llama | toy: cúpula de dos pasadas con aro | gas (plan B: tubo de `FuegoToy`) |
| **Agua** | toy: esfera con cintas y gotas | toy: ola | toy: géiser | **marcador provisional**: un elipsoide de agua | gas (plan B: `AguaToy` HAZ) |
| **Rayo** | toy: esfera de energía con arcos | toy: valla de descargas entre postes | toy: columna que cae del cielo | toy: aro chispeante | gas (plan B: `RayoToy` HAZ); de 0,2 s o menos, un destello |
| **Tierra** | toy: piedra que gira | toy: hilera de rocas sobre las casillas reales | toy: roca alta con cuatro alrededor | toy: corona de rocas cerrada arriba | toy: púas en secuencia, ancladas al suelo |
| **Viento** | toy: ráfaga | toy: cortina | toy: torbellino | toy: anillo | gas (plan B: `VientoToy` HAZ) |
| **Magma** | toy: roca agrietada que rueda | `FuegoToy` hijo oscuro con piedras al rojo («versión sencilla») | ídem | ídem | toy: púas ígneas (un `TierraToy` HAZ dentro) |
| **Hielo** | antiguo (`HieloToy`: bloque facetado) | antiguo (`HieloToy`: dos filas de cristales) | antiguo (`HieloToy`: espiga) | antiguo (`HieloToy`: jaula de cristales) | no aplica: un sólido con ᛁ no hace haz (`SOLIDOS_CON_HAZ` solo tiene la tierra). `HieloToy` HAZ existe, pero el juego no llega a él |
| **Naturaleza** | — | — | — | — | — |

La figura de la tierra sólida no la elige `desde_hechizo`: la decide `_tierra_sobre_celdas` según las casillas que levanta la lógica (muro si es alargado, pilar si es una casilla de dos niveles o más, barrera si es un cuadrado de dos casillas o más).

## 3. Elemento × tiempo

Los cuatro tiempos de `PLAN_VFX_ELEMENTOS.md`: mano, viaje, impacto y residuo.

| | Mano | Viaje | Impacto | Residuo |
|---|---|---|---|---|
| **Fuego** | toy: la bola crece en la mano | toy: bola con cola | `ImpactoFuegoToy` + humo (`impacto_bola`) | la lógica deja «quemado»; humo sobre la hierba que arde (`suelo`) |
| **Agua** | toy: gotas que convergen, ondas bajo los pies | toy: bola con estela y gotas que caen | `ImpactoAguaToy`; vapor si cae sobre fuego (`vapor`) | la lógica deja «mojado» |
| **Rayo** | toy, desde la fase «voluta» | toy + chispas de estela (`rayo_proyectil`) | `ImpactoRayoToy` + chispas (`rayo_impacto`, `rayo_pilar`) | la lógica deja «electrificado»: `EstadoRayoToy` en la casilla y en la entidad, con chispas |
| **Tierra** | toy: piedrecitas que convergen y anillo de aviso | toy: piedra que suelta terrones | `ImpactoTierraToy` con decal de suelo. La capa `polvo_tierra` está **apagada** | no deja estado: quedan los bloques, que el toy hunde cuando la lógica los deshace |
| **Viento** | toy, desde la fase «voluta» | toy: ráfaga con estela | `ImpactoVientoToy`. La capa `polvo_viento` está **apagada** | nada. Aura de viento en lo que empuja (`aura_viento`) |
| **Magma** | toy: la roca nace gris y se calienta | toy: rueda, con brasas (`magma_proyectil`) y humo detrás (`magma`) | `ImpactoMagmaToy`: cráter con decal, brasas (`magma_impacto`) y humo mientras se enfría | la lógica deja «quemado» |
| **Hielo** | antiguo | antiguo | antiguo (`ImpactoHieloToy` existe, sin usar) | la lógica deja «helado» |
| **Naturaleza** | — | — | — | no deja estado |

Los estados del suelo que no son el electrificado (quemado, mojado, helado) no los dibuja un toy: los leen el suelo, la hierba y el agua de la imagen de `EstadosSuelo3D`. Cómo se ven no se ha revisado aquí.

## 4. Constancia de aprobación de Pablo

Solo lo que se ha encontrado escrito en el diario. Un «—» significa que no he encontrado la entrada, no que esté rechazado.

| qué | constancia |
|---|---|
| `FuegoToy` paramétrico | aprobado (entrada 308) |
| Fuego y agua como referencias de estilo | entrada 447 |
| Haz de fuego con gas en modo toon | Pablo eligió el prototipo A (entrada 430) |
| Haces de gas de agua, viento y rayo | validados en la 3070 y encendidos de serie (entradas 479 y 480) |
| Humo de magma, chispas, campo de viento, veneno como gas pesado | validados y encendidos de serie (entrada 484) |
| Púas de tierra en el Bosque | dado por bueno con capturas (entrada 492) |
| Choque del haz de viento que envuelve | dado por bueno en el lab (entrada 494) |
| «Soltar» del viento con jirones blandos | **rechazado** y revertido: «está peor» (entrada 494) |
| `HieloToy` | sin aprobar: por eso sigue apagado |
| `MagmaToy`, `TierraToy` y `VientoToy` como toys enteros | — (encendidos el 6/11 porque Pablo quería verlos en el juego) |
| `RayoToy` revisado | — |
| Polvo de tierra y de viento | apagado por Pablo (entrada 426, según `TECNICAS_REPO_GAS_OTROS_ELEMENTOS`) |

## 5. Huecos, por orden de lo que más se nota

1. **Hielo.** El toy está hecho y completo, pero el juego dibuja el antiguo. Falta la aprobación de Pablo y añadirlo al ajuste.
2. **Naturaleza de la jugadora.** No hay toy ni entrada en `VfxToyJuego.ELEMENTOS`. Lo que existe es de los enemigos.
3. **Barrera de agua.** Es un marcador provisional (la fase 5 de `PROPUESTA_AGUA_TOY`, sin hacer).
4. **Muro, pilar y barrera de magma.** Son un `FuegoToy` oscuro con piedras. La bola y el haz sí tienen dibujo propio.
5. **Haz de viento contra un enemigo sin muro detrás:** en el juego no dibuja choque (pendiente de la entrada 494).
6. **Glifos sin lectura propia.** La barrera que late, ᚦ perforar, ᚨ buscar, el retardo y el raído no tienen un camino en el enganche (ver la guía vigente, §4). Sin revisar a fondo.
7. **Residuo.** Solo el electrificado tiene un dibujo de estado con el estilo de los toys.
8. **Dos haces de gas a la vez como mucho**, entre todos los elementos. El tercero cae al toy, y el chorro del dragón de pared también ocupa un dominio: el plan B se puede ver más de lo que parece.

## 6. Cómo mantenerla

Se actualiza cuando cambie una casilla: un toy nuevo, un elemento que entra en `vfx_procedural_elementos`, una capa que se enciende o una aprobación de Pablo. La fuente de verdad es el código: `VfxToyJuego._nuevo` y `ELEMENTOS`, `HumoRegla.DE_SERIE`, `ChispasRepo.DE_SERIE` y `[magic_symbols]` en `project.godot`.
