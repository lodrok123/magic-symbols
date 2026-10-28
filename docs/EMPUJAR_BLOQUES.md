# Empujar bloques

27/10/2026 · contexto JUEGO · **hecho y probado** (`herramientas/escenario_sala_empuje.gd`, 0 fallos).

## Qué hace

Un bloque que ocupa una casilla y que la jugadora **empuja andando contra él** o que **el viento se lleva**. Pieza de mapa `bloque`, clase `BloqueEmpujable3D` (`objetos/bloque_empujable_3d.gd`).

```
; pieza <id> bloque <x> <y> material=piedra|hielo
```

- **Piedra (con peso, 28/10):** va a **1,0 u/s** (≈ 2,3 s por casilla; andar es 1,6): arranque costoso (0,4 s desde parado), tramo constante y frenado suave (0,3 s) solo al final del todo. Si la jugadora sigue apretando y la siguiente casilla está libre **encadena** sin parar; al soltar acaba la casilla en curso frenando, nunca a medias. Sobre el **hueco de una veta** (`enlaces=`) lo **tiende**: el pulso cruza (`BloqueEmpujable3D.piedra_en(c)`, leído por `Pulso3D.enlace_tendido`). Modelo `bloque_enlace` de la Cueva, ensanchado a 1,55 × 1,9 × 1,55.
- **Hielo:** arranca igual de pesado con la jugadora pegada media casilla; luego se suelta y **resbala** a ~0,25 s por casilla hasta que la siguiente no está libre, frenando un poco al chocar; al pararse suena un golpe (`clavar`) y levanta polvo. No conduce el pulso. Cubo translúcido azulado (no hay textura de hielo en `arte/suelo_meshy`).
- Bloquea su casilla (jugadora, enemigos y flechas ven la misma solidez que el muro agrietado: `Terreno3D.bloquear_celda`), está en el grupo `peso` (pisa las placas) y en `empujable`. No usa `fijar_altura`: se mueve.
- **No se guarda su posición:** al recargar el nivel vuelve a su casilla del mapa.

## Átomos

| átomo | dónde | qué hace |
|---|---|---|
| **empujar** (E1) | `Jugador3D._gestionar_empuje` | andar con dirección cardinal contra un bloque pegado, 0,35 s → `bloque.empujar(dir, true)`; mientras se mueve ella va ACOPLADA (su posición la marca el bloque, a la distancia a la que estaba pegada) |
| **puede_moverse(dir)** | `BloqueEmpujable3D` | destino en el mapa, no bloqueado, ni agua ni lava, a la misma altura (una barrera de tierra la sube: obstáculo), sin otro bloque, sin enemigo vivo, sin la jugadora |
| **resbalar** (E2) | `material=hielo` | el empujón se repite hasta que `puede_moverse` falla; algo que lo pare (pared, barrera de tierra, otro bloque) decide dónde acaba |
| **tender el hueco** (E3) | `piedra_en` + `Pulso3D.enlace_tendido` | la piedra sobre un hueco de veta lo hace conductor |
| **viento** (E4) | `on_spell_hit` con `viento` | empuja en la dirección cardinal dominante del impacto (respeta `puede_moverse`); los demás elementos no hacen nada |
| **peso** | grupo `peso` | `Pulsador3D` (`modo=presencia`) lo nota en su casilla |
| **reaparecer** | `_perdido()` + `_reaparecer()` | un bloque sin ningún movimiento posible que no sirve de nada se deshace a los 3 s y vuelve a su casilla |

Señales: `movido(celda)` (al acabar cada movimiento completo; en Puzle3D, la de por defecto) y `reaparecio` (`reaparece`). Condiciones: `quieto` | `en_marcha`.

### Empujar desde la jugadora

`Jugador3D._gestionar_empuje(delta, mov, libre)`: con `mov` (ya en coordenadas del mundo) hacia una cara (componente ≥ 0,8; la diagonal no cuenta), en suelo y sin nadar, lanzar, rodar ni hacer un gesto, si la casilla vecina tiene un `empujable` y ella está **pegada** (adelantada ≥ 0,3 · S desde el centro de su casilla, es decir, a ≤ 0,7 · S del centro del bloque) cuenta el tiempo apretando. `empujando` es true mientras empuja (aunque el bloque no ceda: así se lee «atascado») y mientras va acoplada; entonces `_animar` pone el clip `empujar`: a `VEL_CLIP_CARGA` (0,4) mientras carga los 0,35 s y a (velocidad del bloque / `ZANCADA_EMPUJAR`) mientras empuja, para que los pies no patinen (`ZANCADA_EMPUJAR` = 0,9 u/s por unidad de velocidad del clip es una ESTIMACIÓN: afinar a ojo; el método es el del commit 93fd42f7, walk ×1,6). Si no puede moverse, reintenta cada 0,35 s.

## Medidas reales (autoplay, 30 fps)

Cifras para afinar de oído: `VEL_EMPUJE`, `T_ARRANQUE`, `T_FRENADO`, `VEL_HIELO`, `T_SUELTA_HIELO`, `T_FRENADO_HIELO` (en `BloqueEmpujable3D`) y `T_EMPUJAR`, `VEL_CLIP_CARGA`, `ZANCADA_EMPUJAR` (en `Jugador3D`).

- **Empuje:** el bloque empieza a moverse a los **0,33 s** de quedarse pegada. Apretar 0,2 s no lo mueve.
- **Piedra:** velocidad constante **1,00 u/s** (2,30 s por casilla); 3 casillas apretando sin soltar, **7,1 s** desde que se mueve (arranque incluido), pasando por los centros a 1,0 u/s (sin paradas intermedias) y frenando a 0,3 u/s al llegar. Cuatro casillas desde pegarse, ~10 s.
- **Soltar a mitad de casilla:** el bloque acaba la casilla y queda en el centro (error < 0,03 u); ella se queda quieta con él (< 0,05 u).
- **Acoplamiento:** distancia jugadora–bloque constante (1,21 u, variación < 0,01 u). Clip `empujar`: 0,40 cargando; 1,11 (= 1,0 / 0,9) moviéndose, proporcional a la velocidad del bloque.
- **Hielo:** primera casilla pesada (1,35 s hasta soltarse), luego **0,27 s por casilla**; 4 casillas hasta la pared en **2,3 s** desde que se mueve.
- **Atascado:** el hielo contra la pared del fondo (sin placa debajo) se deshace y vuelve a su casilla a los 3 s de parar. Si ella está en la pista al otro lado de la casilla de origen cuando reaparece, puede empujarlo hacia atrás (sale de la pista y vuelve a reaparecer a los 3 s: no se atasca).
- **Barrera de tierra:** ocupa **una** casilla (altura 1), así que «justo detrás de la placa» es exacto. Alcance de la barrera: 3 casillas del centro de la jugadora (`Lanzador3D.ALCANCE_ORIGEN`); por eso la placa de E1 y el hueco de E3 están a 5.
- **Flecha de viento:** `distancia_max` = **2 casillas** (la de fuego, igual): solo alcanza un bloque a ≤ 2 casillas de la jugadora (mano incluida). Es lo que fija la geometría de E4 (agua de 1 casilla).

## La Sala del Empuje (`mapas/SalaEmpuje.txt`, `escenas/PruebaSalaEmpuje.tscn`, `Niveles.ESCENAS["SalaEmpuje"]`)

Cuatro salas de 7 × 7, kit `pruebas`, una puerta entre cada una. **Regla de oro:** cada bloque vive en una pista de una casilla de ancho, cerrada por paredes y empujable desde un solo lado, para que no se pueda arrinconar en una esquina.

| sala | rótulo | idea | cómo se resuelve |
|---|---|---|---|
| E1 | El bloque | empujar | piedra por la pista (3..7, 4) hasta la placa (7,4); abre la puerta (8,6) mientras esté encima. En la esquina (7,7) hay otro contra las paredes: no cede |
| E2 | El hielo | el hielo resbala | tierra + ᛜ en (13,2), justo tras la placa (12,2), desde la cabecera (10,2); luego se empuja. Sin ella pasa de largo hasta la pared y vuelve a (11,2) |
| E3 | La veta | la piedra tiende el hueco | cristal que late → veta con hueco (21,2) → receptor → reja (24,6). La piedra sube 4 casillas por la pista (21,3..6) |
| E4 | La otra orilla | hielo + viento a distancia | viento + flecha desde (26,4) cruza el agua (27,4); el hielo (28,4) resbala hasta la placa (31,4); abre la reja (25,2) del cofre |

Ninguna se resuelve sin su idea: la barrera de tierra no llega a la placa de E1 ni al hueco de E3 (a 5 casillas) y el fuego no mueve el bloque de E4. Alternativas legítimas que quedan (misma idea): el viento puede empujar el bloque de E1 desde la cabecera; en E4 se puede helar el agua con hielo + ᛜ y empujar a mano.

## Cómo editar

- Cambiar de sitio un bloque, una placa o una pista: líneas `; pieza … bloque …` y las paredes del plano. **Mantener la pista de una casilla de ancho** y la placa/hueco más allá del alcance de la barrera (3 casillas) si no se quiere el atajo mágico.
- Un bloque que pueda acabar sin salida (pared al final de una pista sin placa) **ya no es un problema**: reaparece. Un bloque en una esquina desde el principio (`bloque_fijo_e1`) es adorno inmóvil; no reaparece (ya está en su casilla).
- Un bloque nuevo en un mapa de otro nivel: `; pieza b1 bloque 5 5 material=hielo` y una placa debajo de su destino. No hace falta nada más.

## Lo que no hace

- No hay empuje contra enemigos (un enemigo en la casilla destino lo impide) ni arrastre/tirón.
- No se guarda su posición en la partida (decidido).
- El bloque de piedra no se rompe ni el de hielo se funde con fuego (solo el viento los toca).
- Sonido: la piedra suena con un bucle bajo mientras se mueve (`Sfx3D.AMBIENTES["arrastre"]` = el `rodar.wav` sintetizado en bucle; no hay un arrastre grabado); el hielo, `rodar` al empezar y `clavar` al parar; `derrumbe` al reaparecer.
- Sin polvo continuo a ras de suelo: no existe un efecto pequeño (`VfxPuzle3D.polvo` es una nube grande de derrumbe); el hielo solo levanta un poco al parar.
