# Enganche de `FuegoToy` y `AguaToy` al juego (A1, 2/11/2026)

Encargo: dirección A de `docs/DIRECCION_2026-11-02.md` (§2.A): que el fuego y el agua oficiales (`presentacion/vfx/toy/`, diario 307–318) se vean en el juego, creados desde lo que ya hace `HechizoVivo`, sin tocar nada a mano por hechizo. Este documento tiene la **etapa 0** (cómo se dibuja hoy y qué provoca cada cosa), lo que **faltaba en los eventos**, y lo que se hizo.

Regla del plan (`PLAN_VFX_ELEMENTOS.md`): la lógica decide, el VFX representa. Nada de lo que hay aquí cambia gameplay; lo único que se tocó en `HechizoVivo` y `Lanzador3D` son datos y señales para el dibujo.

## 1. Cómo se dibuja hoy el fuego y el agua de un hechizo (etapa 0)

Hay tres piezas que escuchan al `Lanzador3D` (las conecta la maqueta, `presentacion/prueba_test2.gd`, tras `Jugador3D.montar`):

| pieza | escucha | dibuja |
|---|---|---|
| `ConjuroVfx3D` (`conjuro_vfx_3d.gd`) | `conjuro_fase(fase, elemento, posicion)`: «runa», «voluta», «forma», «disparo» | la voluta del libro a la mano, la **forma en la mano** (orbe con chispas; el fuego con `FasesFuego3D`) y el destello/onda al disparar |
| `VfxElemento3D` (`vfx_elemento_3d.gd`) | `child_entered_tree` del lanzador (un `HechizoVivo` con `velocidad > 0`) y `hechizo_v2` | el **proyectil** (`Proyectil` + `VfxKit3D.bola`), los **volúmenes** (esfera → `VfxKit3D.impacto`; pulso → `onda`; barrera → `cupula`) y el **haz** (`VfxKit3D.haz` el fuego, `VfxAgua.chorro` el agua) |
| `VfxEstado3D` (`vfx_estado_3d.gd`) | `hechizo_v2` | por estado de la materia; **apagado** en la maqueta (`encendido = false`), no dibuja |

Fuera de esas tres: `Vfx3D` (`vfx_3d.gd`) y `VfxKit3D` son la biblioteca de piezas (no escuchan nada por sí mismas); las reacciones del mundo (vapor, hielo roto…) cuelgan de `Mundo3D.impacto` y no son del hechizo; el agua real (`AguaSim3D`) y los estados de suelo son lógica. `vfx_elementos/fuego.gd` y `agua.gd` son recetas del kit que usa `VfxElemento3D`.

### Tabla: hechizo → figura toy → qué lo crea → qué lo impacta → qué lo mata

«Figura toy» es la que sale de `FuegoToy.describir(h)` (la misma regla para el agua). Receta de ejemplo = glifos de `Hechizo.construir`. «Hoy» es el dibujo de antes; «con el selector» es lo que hace `VfxToyJuego`.

| hechizo (receta) | figura toy | qué lo crea | qué lo impacta | qué lo mata |
|---|---|---|---|---|
| **bola quieta** (sin glifos; ᛟ `pulso` la ensancha) | `BOLA`, `viaja = false`, centro a `semieje_y` sobre el suelo | `HechizoVivo._materializar` → señal `hechizo_v2` (`estado`, `g` con `x,y,z`, `eventos`, `vida_total`, `suelo`). Hoy: `VfxElemento3D._volumen` (esfera o pulso) | no hay impacto: la zona nace donde se apunta. El agua (`area_al_impactar`) estalla en área al acabar | `vida_total` = `persiste` + `permanencia` (fuego plasma 3 s; agua 0 → mínimo 1 s). Hoy: temporizador de `VfxElemento3D._vigilar` (`vida + 0,8`); con el selector: `_expirar` → `terminar_sin_choque` (fuego) / `impactar_en` (agua, área) |
| **proyectil** (ᚠ `flecha`) | `BOLA`, `viaja = true`, semiejes de vuelo (× `ESCALA_PROYECTIL` 0,5) | `HechizoVivo.crear` → `add_child` al lanzador → `child_entered_tree` (`VfxElemento3D._en_nodo`, diferido a `_dibujar_proyectil`: `v` y `p` se fijan en `_iniciar_proyectil`). **Carga en la mano:** `lanzar_ahora(con_conjuro)` → `_conjurar*` → `conjuro_fase("forma")` → `ConjuroVfx3D.forma` | `HechizoVivo._terminar(causa)`: `golpe` (enemigo/objeto), `muro` (casilla sólida o `SolidezV2`), `suelo`. Hoy: `Proyectil.al_pararse` (lee `hv.motivo_fin`) → `FasesFuego3D.impacto` / `desvanecer`; el agua no tiene impacto propio. Rebote: `HechizoVivo._rebotar` | `alcance`, `tiempo`, `frenado`: `_terminar` sin choque (fuego: `FasesFuego3D.desvanecer`). `retorno`: la vuelta de ᛃ. Si el `HechizoVivo` sale del árbol: `_soltar_al_irse` |
| **muro** (ᚦ `barrera` + ᛁ `linea_x`) | `MURO` (alargado en planta, `solidez > 0`) | `hechizo_v2` con `props.solidez` → hoy `_pieza_volumen` forma «barrera» = `VfxKit3D.cupula` (no distingue muro de cúpula). La solidez real es `SolidezV2` | los proyectiles ajenos chocan contra `SolidezV2` (`_barrera_en`); el dibujo no se entera | `vida_total` (`persiste` + `permanencia`, mínimo 2 s de solidez); mismo temporizador |
| **pilar** (ᛉ `altura` × 3) | `PILAR` (`nombre_derivado` = «alto») | `hechizo_v2` → hoy «esfera» (`VfxKit3D.impacto`, no se ve una columna) | — | `vida_total` |
| **barrera / cúpula** (ᚦ + ᛁ horizontal y vertical) | `BARRERA` (`solidez > 0` y no alargada) | `hechizo_v2` con `solidez` → `VfxKit3D.cupula` | como el muro | `vida_total` |
| **haz** (ᛁ `linea` sola) | `HAZ`, largo = recorrido real de la lógica, eje a la altura de la mano | `HechizoVivo._materializar_haz` → `hechizo_v2` con `g["haz"] = {desde, hasta, ancho, alcance, largo}` → hoy `VfxElemento3D.haz` (`_pieza_haz`) | el haz golpea todo su recorrido a la vez en la lógica; el dibujo no tiene impacto de punta | `Hechizo.HAZ_DURA_S` + `permanencia` |

Observaciones que importan:

- El dibujo de antes **no distingue** muro, pilar y bola quieta (son `cupula`, `impacto`, `impacto`); la figura sale entera de `describir(h)`.
- `hechizo_v2` **no trae el `Hechizo` ni el nodo**: `VfxElemento3D` adivina que el `HechizoVivo` es «el último que entró al lanzador». Sirve mientras `HechizoVivo.crear` añada el nodo antes de emitir (hoy lo hace); `VfxToyJuego` hace lo mismo y lo deja anotado como punto frágil.
- `AguaToy` BARRERA sigue siendo un **marcador provisional** (fase 5 del agua, sin hacer); el resto de figuras del agua están hechas.
- La carga en la mano de un hechizo que **no** es proyectil (muro, pilar…) es la misma bola de carga: se apaga al aparecer el volumen.

## 2. Qué datos faltaban en los eventos y qué se añadió

| dato | estaba | ahora |
|---|---|---|
| El `Hechizo` durante el conjuro (para la figura y el tamaño de la carga en la mano) | no: `conjuro_fase` solo lleva fase, elemento y posición | `Lanzador3D.conjuro_actual = {hechizo, carga}` (1 variable + 1 línea en `lanzar_ahora`) |
| Fin del proyectil con su causa, **posición, normal y material** | `motivo_fin` como variable, sin señal; sin normal ni material | señal `HechizoVivo.terminado(causa, pos, normal, material)`. Normal: suelo = arriba; muro = contraria al eje horizontal dominante de la velocidad (las paredes son de casilla); golpe = contra la marcha. Material: la **letra del mapa** de la casilla de contacto (`#`…) para muro y suelo; `""` para golpe y alcance. **Pendiente:** una tabla letra → material (piedra, madera, agua) y el tipo de lo golpeado (enemigo/objeto): el toy hoy no usa el material |
| Rebote | solo la acción interna `al_rebotar` | señal `HechizoVivo.rebotado(pos, normal)` (la normal es la velocidad ya reflejada, hacia fuera de la pared) |
| Expiración de lo que nace quieto | no hay evento (solo `al_expirar` si el hechizo lo pide) | **no se añadió**: `VfxToyJuego` usa `vida_total` del propio `hechizo_v2`, que sale de la lógica (igual que el dibujo de antes). Pendiente si se quiere que el dibujo muera cuando la lógica rompa antes el muro (golpes a `SolidezV2`) |
| Crecimiento de un volumen con `crece` | `tiempo_crecimiento` en el `HechizoVivo` | no se anima en el toy (nace entero). El proyectil con `crece` sí: escala del toy = `_radio_u / _radio_pleno_u` |

## 3. Lo que se hizo

- **Selector**: ajuste de proyecto `magic_symbols/vfx_procedural` (`project.godot`, sección `[magic_symbols]`, por defecto `false`).
- **`presentacion/vfx_toy_juego.gd` (`VfxToyJuego`)**: nodo que conecta la maqueta (`prueba_test2.gd`, una línea) al lanzador y crea los toys. Con el ajuste a `false` no hace nada. Con `true`:
  - `conjuro_fase("forma")` → `empezar_carga(duración, radio)` en la mano (sigue al cast point); si el hechizo es un proyectil el radio es el de vuelo (la misma bola), si no, un tope de 0,45 m.
  - Proyectil (`child_entered_tree`, diferido): `soltar(dir)` de esa misma bola (o un toy nuevo con `desde_hechizo(h)` si no hubo conjuro); sigue posición, dirección y tamaño del `HechizoVivo`.
  - `terminado` → `finalizar(causa, pos, normal)`: golpe/muro/suelo → `impactar_en` con la normal de la lógica; alcance/tiempo/frenado → `terminar_sin_choque`; retorno → `cancelar_carga`. `rebotado` → `rebotar`.
  - `hechizo_v2` (bola quieta, muro, pilar, barrera, haz): un toy por copia (máx. 4, sitios sin repetir), figura y giro de `describir`, apoyado en el suelo de la lógica; el haz con el largo y la altura reales. Vive `vida_total` y se apaga (`_expirar`). Presupuesto: una sola luz por hechizo (las copias sobrantes la apagan).
  - Un volumen con `viaja` sin velocidad recorre los puntos de los `eventos` (no hay receta que lo produzca hoy; sin probar).
- **Un solo renderizador por hechizo**: con el ajuste a `true`, `VfxElemento3D` no dibuja fuego ni agua (`_en_nodo`, `_en_hechizo`) y `ConjuroVfx3D` no dibuja la forma de la mano ni el destello de soltar para ellos (conserva voluta, sonido y retirada). Tierra, viento, hielo, rayo, tiempo no cambian.
- **No se toca** el fuego de la hierba (hasta 60 casillas): no es un `HechizoVivo`, sigue con el kit barato.

## 4. Cómo verlo

1. Con Godot **cerrado**, abrir `project.godot` y, en la sección `[magic_symbols]`, poner `vfx_procedural=true` (o, con Godot abierto: Proyecto → Configuración del proyecto → activar «Configuración avanzada» → «Magic Symbols» → `vfx_procedural`).
2. Abrir y ejecutar `escenas/PruebaBosque01_v01.tscn`. Lanzar fuego y agua con los glifos de siempre: ᚠ `flecha` (proyectil, con su carga en la mano), ᚦ `barrera` + ᛁ (muro), ᛉ `altura` (pilar), ᛁ sola (haz).
3. Para volver a lo de antes: `vfx_procedural=false`.
4. Capturas lado a lado: `docs/capturas/vfx_en_juego/lamina_vfx_en_juego.png` (se rehacen con `herramientas/captura_vfx_en_juego.gd` y `herramientas/lamina_vfx.py --en-juego`).
