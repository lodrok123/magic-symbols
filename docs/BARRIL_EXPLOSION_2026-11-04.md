# Barril de pólvora: explosión y área de efecto (4/11/2026)

Rama `claude/barril-explosion`. Decisiones de Pablo: la explosión daña a enemigos y jugadora dentro del área (como las bombas de Echoes of Wisdom), un círculo en el suelo avisa del alcance mientras arde la mecha, el radio se queda en `Barril3D.RADIO` = 2,6 u. Todo el fuego sale del FuegoToy oficial.

## Qué se ve

**Aviso (mientras arde la mecha, 1,2 s)** · `AvisoAreaFuego` (`presentacion/vfx/toy/aviso_area_fuego.gd`). Un decal de fuego: una caja de lado 2·RADIO que se proyecta sobre el terreno leyendo la profundidad (`explosion_suelo.gdshader`), así que sigue los desniveles (hasta ±1 casilla) y no hay z-fighting. Borde nítido rojo-naranja a 2,6 u exactos, relleno que crece del centro al borde con la mecha (0 % → 100 %) y late: 1,6 Hz al encender, ≈4,3 Hz a mitad, 8-9 Hz al final. Bordes con lamidos suaves. Desaparece al apagar con agua o al explotar. Cada barril de una cadena tiene el suyo.

**Explosión (≈ 0,8 s; el nodo se libera a 1,35 s)** · `ExplosionFuegoToy` (`explosion_fuego_toy.gd`), paramétrica por `radio`. Junta piezas ya hechas:

| Instante | Qué |
|---|---|
| 0–0,14 s | destello hit22 (estrella) con halo y luz que se apaga; la bola nace |
| 0–0,8 s | bola de fuego redonda: `ImpactoFuegoToy` estilo B (flipbook de Le Lu recoloreado con la rampa de la bola) con radio de impacto 0,85 u (0,327 · radio); se hincha en 0,18 s y se enfría |
| 0–0,6 s | chispas y brasas hacia fuera: `ImpactoFuegoToy` estilo C (≈ 32 trazos y unas brasas, con gravedad y rozamiento) |
| 0–0,38 s | onda a ras de suelo: el frente crece de 0 a 2,6 u (ease-out) y llega exactamente al alcance; el anillo se apaga hacia 0,7 s |
| 0–0,85 s | resplandor rojo-naranja en el suelo que se apaga |

Sin humo. Se mantiene el `PulsoPantalla3D` de antes. El cuerpo y el aro metálico del barril desaparecen (antes el aro se quedaba).

## Colores

Todos de `FuegoToy._rampa_bola` (rojo `(0,85, 0,12, 0,03)` → rojo-naranja `(1, 0,32, 0,03)` → naranja `(1, 0,52, 0,08)` → `(1, 0,64, 0,14)` → `(1, 0,8, 0,42)`). El decal no pasa del 0,85 de la rampa (naranja, g/r = 0,62) y usa sobre todo 0,2-0,6 (rojo-naranja). A la bola y las chispas se les baja la temperatura con `ImpactoFuegoToy.desp_calor` = -0,17 (nuevo, 0 por defecto: los demás impactos no cambian). El único amarillo es el núcleo del primer instante (≈ 0,05-0,1 s).

## Daño (en `Barril3D._explotar`, por las vías que ya existen)

| | Valor | Comparación |
|---|---|---|
| Enemigos (`Combate3D.recibir_golpe_cuerpo`) | `DANO_ENEMIGO` 35, `EMPUJE_ENEMIGO` 6000 | golpe F 5 · jarrón 8 · caja 6 · piedra 12 · geoda 30; goblin 50 de vida (con su defensa le quita 33 y sale despedido ≈ 4 u) |
| Jugadora (`Jugador3D.recibir_dano(20, punto)`) | `DANO_JUGADORA` 20 | un golpe de goblin = 20 sobre 100 de vida; respeta defensa, barrera, bálsamo e invulnerabilidad de 0,7 s; retroceso 4,5 u/s desde el barril |
| Alcance | en el plano ≤ `RADIO` 2,6 u y `ALTO_AFECTA` 1,6 u de diferencia de altura | |

Un escudo activo de frente para el golpe del enemigo (vía `recibir_golpe_cuerpo`). Lo de siempre se rompe (grupo `explosionable`: rocas, muro agrietado, jarrones, cajas).

**Cadena:** hasta ahora no funcionaba (el barril no era `explosionable` ni tenía `recibir_explosion`). Ahora los barriles del grupo `barriles_polvora` a ≤ RADIO se encienden por la explosión (con su mecha de 1,2 s y su aviso). No se metió en `explosionable` para no cambiar lo que hace la lava con ese grupo.

## Mecha

`T_MECHA` sigue en 1,2 s. A 3,0 u/s (correr) se sale del círculo en 0,9 s desde el centro; andando (1,6 u/s) desde el centro no daría tiempo (1,9 u < 2,6 u), pero se enciende casi siempre desde lejos. Si el aviso se ve corto al jugar, 1,5 s deja salir andando desde el borde de la casilla; no se ha cambiado.

## Pruebas y capturas

`herramientas/prueba_barril_explosion.gd` (40 comprobaciones; sobre PruebaBosque real) y `herramientas/captura_barril_explosion.gd` (con ventana). Capturas en `docs/capturas/barril_explosion/`: `explosion_juego.png`, `explosion_cerca.png` (6 instantes: 0,04 · 0,10 · 0,18 · 0,30 · 0,48 · 0,72 s), `aviso_juego.png`, `aviso_cerca.png` (15 %, 50 %, 90 % de la mecha), con la cámara del juego mirando al norte (tamaño 6, inclinada 30°). Los pinos del decorado se esconden en la captura porque tapaban el barril.

`PiezaPuzle3D` (familia «barril») y `VfxPuzle3D.fogonazo` se dejan como estaban: el juego no usa `PiezaPuzle3D` para el barril (solo `Barril3D`), así que nunca salen dos explosiones.