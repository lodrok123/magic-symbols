# Revisión de gamefeel (30/10/2026) y tareas de programación

> Pedido de Pablo: revisar el gamefeel de TODO el proyecto (combate y menús) con cuatro pilares: **VFX** (el hechizo se corresponde con su geometría y se entiende solo), **SFX** (sutiles y satisfactorios), **pushback** (los golpes se sienten; más daño empuja más; un enemigo ligero se mueve más que uno pesado) y **hit flash** (se ve a simple vista y con el color del elemento). Cada tarea de abajo se programa con Sonnet; este documento es el análisis y el reparto.
>
> Fuentes: código del worktree al 30/10 (`presentacion/sensacion_3d.gd`, `enemigos/combate_3d.gd`, `presentacion/vfx_elemento_3d.gd`, `presentacion/ui/menu_pestanas.gd`, `nucleo/sfx.gd`…), `docs/PROMPT_RESUMEN_GAMEFEEL.md` (lotes 1 a 4) y dos auditorías de lectura (VFX e interfaz). Cuando doc y código discrepan, manda el código.
>
> **Nota:** el mensaje de Pablo decía «pongo un ejemplo para el inventario» pero no llegó ningún adjunto ni texto con el ejemplo. La tarea de la mochila (§6, tarea M) está diseñada desde el código; si el ejemplo era otra cosa, se reajusta.

---

## 1. Resumen en diez líneas

1. El combate ya tiene mucha sensación (lotes 1 a 4: hitstop, respingo, aplastamiento, temblor, polvo, sonidos de cuerpo, cámara con adelanto). Lo que falta en combate es **coherencia**, no cantidad.
2. **Pushback:** el empuje sale solo de `fuerza_golpe` del elemento (tierra 2200, agua 600, fuego 500, rayo 400, hielo 300) y **no mira el daño**: un rayo de 55 empuja menos que un agua de 40, y un hechizo de 5 glifos (daño alto) empuja igual que uno de 1. **No hay masa por enemigo**: solo el elemental tiene factor (0,3) y el gólem no se mueve. Limo, chamán, asesino y gato se empujan igual que un guerrero.
3. **Hit flash:** es **blanco puro** siempre (`Combate3D._destello_blanco`, albedo negro + emisión blanca, 0,20 s). Se ve bien, pero no dice el elemento. El limo y el gólem tienen caminos propios y hay que engancharlos aparte.
4. **VFX:** el dibujo que ve el jugador (`VfxElemento3D`) usa **un solo radio escalar** (`max(x, z)`) y no el elipsoide: la **barrera se dibuja como cúpula o anillo, no como muro**; la altura solo la usan tierra, hielo y viento; el **pulso no crece con `crece`**; **no hay VFX de rebote**; rayo y tiempo son la plantilla del fuego teñida. La pestaña F4 del laboratorio aprueba el dibujante que el juego **no** usa.
5. **SFX de combate:** completos y razonables; pendiente de oído (lote 4 sin validar). Dos sonidos chocan con «sutil»: `logro_brillo` (campana de logro) suena por **cada planta común** y `explosion`/`pira` van a −3 dB.
6. **SFX de menús:** la mochila real (`MenuPestanas`) solo suena al abrir y cerrar. **Beber poción, equipar, cambiar de pestaña, navegar, comprar, cofres del Bosque 01, misiones y la pantalla de muerte son mudos.** Hay cinco sonidos sintetizados sin usar en `nucleo/sonidos.gd` (`pocion`, `recoger`, `comprar`, `moneda`, `golpe`).
7. Los errores de interfaz (no puedes beber, mochila llena, sin oro) son **solo texto**; `no_puedes` existe y solo lo usa el lanzador.
8. El grimorio suena al abrir y cerrar pero **aparece de golpe** (sin tween); la mochila tiene tween pero menos sonido. Al revés de lo que debería.
9. La **muerte de la jugadora** no dispara `Sensacion3D.dano_recibido` (rama letal aparte) ni ningún sonido; `muerte` está en el catálogo sin uso.
10. Orden propuesto: **P (pushback) y H (hit flash)** primero porque son reglas pequeñas con mucho efecto; luego **M (mochila y consumibles)**, **V (VFX de barrera, pulso y rebote)** y **S (sonidos de interfaz)**.

---

## 2. Pilar 3 · Pushback (el más incoherente hoy)

### Lo que hace el código

- `Combate3D.v0_de_empuje(fuerza, suelo)` (`enemigos/combate_3d.gd:507-512`):
  `v0 = fuerza × MULT_EMPUJE (2,0) × ESCALA_EMPUJE (0,0036) × peso`, con `peso = 0,3` si es el elemental y `1,0` para todos los demás. Con daño, mínimo `EMPUJE_MIN_CASILLAS (0,35) × casilla × 7 × peso`.
- `fuerza` viene de `Hechizo.fuerza_golpe` (`nucleo/hechizo.gd:178`), fijada por el `.tres` del elemento (`modificadores.fuerza_golpe`): tierra 2200, agua 600, fuego 500, rayo 400, hielo 300, viento 0 (el viento empuja por `Lanzador3D.empuje_de_golpe`). **Ningún glifo la toca.**
- El daño (`nucleo/dano.gd`) sí crece con los glifos ofensivos (B = 12 / 24 / 40) y con debilidad (×1,5), pero `golpe()` llama `push(d, hechizo.fuerza_golpe, dano > 0)` (`combate_3d.gd:797-798`) sin pasarle el daño.
- Enemigos: guerrero, arquero, asesino, chamán (30 de vida), limo (30; grande el doble), gato (45), elemental (500, peso 0,3), gólem (70; `empujable_golpe = false` y `push` solo resbala sobre hielo, `golem_3d.gd:411`). **No existe `masa`.**
- Lo visual del golpe (hitstop, aplastamiento `SQUASH_ESCALA`, respingo `RESPINGO` 0,16 u) tampoco depende del empuje: un golpe que lanza al goblin por el aire y uno que lo mueve 0,35 casillas hacen el mismo aplastamiento.

### Tarea P · Empuje por daño y por masa (Sonnet)

**Archivos:** `enemigos/combate_3d.gd` (dueño: Juego), `enemigos/limo_3d.gd`, `enemigos/chaman_3d.gd`, `enemigos/gatopedro_3d.gd`, `enemigos/golem_3d.gd`, `presentacion/sensacion_3d.gd`, prueba nueva `herramientas/prueba_empuje_masa.gd`. No tocar los `.tres` ni `Dano`: **el daño no cambia**, solo cuánto se mueve el cuerpo.

**Regla nueva (toda en `static var` para afinarla en vivo desde el panel F3 de `LabHechizos3D`):**

```
v0 = fuerza_golpe × MULT_EMPUJE × ESCALA_EMPUJE × k_dano(dano, debil) / masa
k_dano = lerp(K_EMPUJE_MIN, K_EMPUJE_MAX, clamp(dano / DANO_EMPUJE_MAX, 0, 1)) × (K_EMPUJE_DEBIL si debil)
```

Valores de partida: `K_EMPUJE_MIN = 0,7` (un golpe sin daño o ligero empuja algo menos que hoy), `K_EMPUJE_MAX = 1,6` (daño alto, 40 o más), `DANO_EMPUJE_MAX = 40` (el mismo corte que el hitstop, `Sensacion3D.DANO_HITSTOP_MAX`), `K_EMPUJE_DEBIL = 1,25`. El mínimo `EMPUJE_MIN_CASILLAS` también se divide por `masa`.

**Masa por familia** (`var masa: float = 1.0` en `Combate3D`, la ponen las subclases en su `_ready`/`equipar`): guerrero 1,0 · arquero 0,9 · asesino 0,8 · chamán 0,9 · limo 0,6 (grande 1,2) · gato 0,5 · elemental 3,3 (sustituye a `MULT_EMPUJE_ELEMENTAL = 0,3`: 1/3,3 ≈ 0,3, así el elemental queda igual que hoy) · gólem: sigue con `empujable_golpe = false` (masa 6,0 solo para el resbalón sobre hielo, que no cambia).

**Lo visual acompaña al empuje:** en `_reaccion_visual` y `_respingar`, escalar el aplastamiento y el respingo con `clamp(v0 / V0_REF, 0,6, 1,6)` (`V0_REF = 8` u/s, lo que hoy da un golpe medio); el polvo de `push` (`POLVO_EMPUJE`) con la misma `k`. Así un goblin ligero con un golpe grande se aplasta y salta más, y el elemental apenas.

**Previsión:** `prever_golpe` y `prever_empuje` (`combate_3d.gd:557-583`) ya pasan por `v0_de_empuje`; hay que pasarle también el daño y `debil` que `decidir_golpe` ya calcula, para que el indicador de apuntado siga diciendo la verdad («Se hunde»).

**Prueba** (`godot --headless --fixed-fps 30 --script res://herramientas/prueba_empuje_masa.gd`): (1) mismo elemento, 1 glifo contra 5 glifos ofensivos → el de 5 recorre más; (2) agua (40) contra rayo (55) sobre guerrero → el rayo recorre al menos lo mismo; (3) misma flecha sobre guerrero, limo y elemental → limo > guerrero > elemental; (4) gólem de pie no se mueve; (5) `prever_empuje` coincide con el recorrido real (±0,1 u); (6) con `Sensacion3D.ACTIVA = false` el recorrido real no cambia (lo visual es lo único que se apaga). Regresión: `prueba_golpe_cuerpo`, `prueba_prevision_hechizo`, `prueba_sensacion*`.

**Dónde verlo:** `laboratorios/LabHechizos3D.tscn` (F1 receta, Espacio lanza; panel F3 entradas «S:» y «C:» para los números) y `laboratorios/LabRecetas3D.tscn` con dianas quietas. En el Bosque, un goblin contra el limo de `escenas/PruebaSalaLimo.tscn`.

---

## 3. Pilar 4 · Hit flash por elemento

### Lo que hace el código

- `Combate3D._destello_blanco(activo)` (`combate_3d.gd:1944-1973`): pone **albedo negro + emisión blanca** en todos los materiales del modelo durante `_destello` s (`DESTELLO_GOLPE` 0,20 s por golpe; `DESTELLO_DANO` 0,10 s por quemadura, veneno y pulsos). Se ve, y bien (decisión del 17/10: «blanco puro para que no asome la textura»).
- El color del elemento aparece solo en la **estrella** y el chorro de partículas (`Vfx3D.golpe_estrella` / `golpe_direccional`, `presentacion/vfx_3d.gd:2364-2396`, `Vfx3D.COLOR`) y en los números flotantes. Los **estados** (quemando, mojado, congelado) tiñen el albedo de forma continua (`_dibujar_estado`, `:1984-1995`).
- El limo (`LimoVisual3D.golpe()`, shader propio) y el gólem (`golem_3d.gd:263, 317`) reutilizan `_destello`, pero el limo pinta con su shader, no con `_materiales`.

### Tarea H · Destello del color del elemento (Sonnet)

**Archivos:** `enemigos/combate_3d.gd`, `enemigos/limo_visual_3d.gd`, `enemigos/golem_3d.gd`, `presentacion/sensacion_3d.gd` (los números), prueba `herramientas/prueba_destello_elemento.gd`.

**Regla:** el destello tiene **dos fases**: `T_FLASH_BLANCO = 0,05` s de blanco puro (lo que hoy garantiza que se ve a simple vista) y después el resto (`DESTELLO_GOLPE − 0,05`) con **emisión del color del elemento** (`Combate3D.COLORES[el].lerp(WHITE, 0,35)`, energía `ENERGIA_FLASH = 1,4`), que se funde a cero en los últimos 0,06 s (hoy corta en seco). Con **debilidad**: 0,28 s y energía 1,8. El **golpe F** (sin elemento) y el daño continuo: blanco corto como hoy (el continuo con el tinte del elemento a energía 0,8 para que no parpadee). Guardar `_destello_el: String` junto a `_destello` para saber qué color pintar.

- `_destello_blanco` pasa a `_destello_pintar(color, energia)`; la devolución de la emisión previa se mantiene igual.
- Limo: `LimoVisual3D.golpe(color)` recibe el color y lo mete en su shader (`uniform` nueva `flash_color`, `flash_fuerza`).
- Gólem: el «Piedra» (sin daño) destella gris corto; el núcleo expuesto, color del elemento y 0,28 s.
- La **barra de vida** ya destella blanco 0,14 s (`DESTELLO_BARRA`); dejarla blanca (lee mejor).

**Prueba:** por elemento, tras `on_spell_hit`, en el fotograma 2 la emisión es blanca y en el fotograma 6 (0,1 s a 60 fps) es del color del elemento (distancia de color < 0,1 al esperado); con `ACTIVA = false` o `DESTELLO_GOLPE = 0` no hay emisión; al apagarse se restaura `emission_enabled` previo; el limo y el gólem también. Regresión: `prueba_sensacion*`, `prueba_limo_combate`, `prueba_golem_combate`.

**Dónde verlo:** `LabRecetas3D.tscn` (dianas quietas; lanzar fuego, agua, rayo e hielo seguidos) y `PruebaSalaLimo.tscn` / `PruebaSalaGolem.tscn`. Captura con ventana: `herramientas/captura_golpe_clip.gd` (ya existe) añadiendo un fotograma a 0,1 s.

---

## 4. Pilar 1 · VFX y geometría

### Lo que hace el código (resumen de la auditoría)

- El juego dibuja con `VfxElemento3D` (`presentacion/vfx_elemento_3d.gd`); `VfxEstado3D` (el único que escala un elipsoide real con los semiejes) está **apagado** en la maqueta (`prueba_test2.gd:1214-1225`). La pestaña **F4 de `LabHechizos3D` enciende `VfxEstado3D`** (`laboratorios/lab_vfx_3d.gd:177-196`): lo que se aprueba allí no es lo que se ve jugando. Además `laboratorios/LabVfx3D.tscn` no abre (su script `extends RefCounted` sobre un `Node3D`).
- Volúmenes: `r_u = max(g.x, g.z) × casilla` (`vfx_elemento_3d.gd:321`); `alto_u` solo lo leen tierra, hielo y viento. **Barrera**: fuego, agua y rayo dibujan una **cúpula** (`VfxKit3D.cupula`, `:419-420`), tierra y hielo un **anillo** de bloques acotado a 4 u (`tierra.gd:105-107, 519`; `hielo.gd:70-72, 656`). El kit ya tiene `muro` y `pilar` (`vfx_kit_3d.gd:960, 976`) y nadie los llama. Una barrera de base (semieje 0,10) sale con 0,37 u de cúpula sobre casillas de 2,3 u; el apuntado sí corrige con un mínimo de `0,42 × casilla` (`apuntado_3d.gd:450-453`).
- **Pulso** (`crece`): un aro `onda` hasta 4× el semieje en `0,55 × vida` s (`:418`, `vfx_kit_3d.gd:833-849`), sin leer `crece` ni `tiempo_crecimiento`. Proyectil con `crece`: crece con smoothstep fijo de 0,6 s (`:120-123`) mientras el radio de golpe sí crece (`hechizo_vivo.gd:1309`).
- **Proyectil**: bola de radio `max(x, z)` (`:361`); un fondo Z alargado no se ve. Solo el estirón de arranque lo deforma.
- **Copias de volumen**: solo los 4 primeros eventos (`:326-329`) con `LIM_COPIAS = 8`; se ignora la `t` de cada evento.
- **Rebote**: ningún VFX ni sonido (`hechizo_vivo.gd:1470-1475`); solo el apuntado lo marca con rombos.
- **Fin por alcance**: solo el fuego tiene `desvanecer`; agua y rayo desaparecen.
- **Barrera rota** (`SolidezV2.golpe`, `lanzador_3d.gd:3318-3323`): el dibujo no se entera y sigue hasta su `vida`. Y `VIDA_MIN` del dibujo (1,0) es menor que la del muro (2,0): ~0,7 s de muro invisible que bloquea (verificar en vivo).
- Posible fallo (verificar en vivo): un volumen quieto sin `_despues` se libera en `crear` y su dibujo se borra a los 0,5 s (`hechizo_vivo.gd:169, 494-496`; `vfx_elemento_3d.gd:546-573`); el haz y el líquido sí se mantienen (`:425`, `:757`).
- Por elemento: fuego, tierra, viento, hielo y el haz de rayo se distinguen por silueta; **rayo y tiempo** son la bola, cúpula y onda del fuego teñidas; el agua en barrera y pulso también.

### Tarea V1 · La forma que se ve es la que golpea (Sonnet; dueño Pipeline para `presentacion/`, Juego para `magia/`)

1. **Radio con suelo** (`vfx_elemento_3d.gd:321`): mismo mínimo que el apuntado (`0,42 × casilla`), y pasar a `_pieza_volumen` los tres semiejes y `d`, no un `r_u`.
2. **Barrera = muro**: para `forma == "barrera"` llamar `VfxKit3D.muro(largo = 2·g.x·casilla, alto = alto_u, lado = d.orthogonal())` en fuego, agua y rayo; tierra y hielo colocan sus bloques en línea perpendicular a `d` (en vez del anillo), sin el tope de 4 u. **Columna** (barrera + altura): `pilar` con la altura real.
3. **Pulso**: `onda` con radio final `g × casilla` y duración `tiempo_crecimiento` (añadir el campo al diccionario `volumen` en `hechizo_vivo.gd:314-317`). Proyectil con `crece`: escala del seguidor = `hv._radio_u / hv._radio_pleno_u`.
4. **Proyectil elipsoidal**: pasar `semiejes_vuelo` a `bola` y escalar en el eje de avance (componer con `Sensacion3D.base_estirada`).
5. **Volumen quieto**: en `_materializar` añadir `_despues(vida_total, …)` como hace el haz (`:425`), y `VIDA_MIN` 2,0 para barrera. Verificar primero en vivo si el dibujo se corta a los 0,5 s.

**Prueba:** `herramientas/captura_radio_base.gd` (ya existe, rejilla de casillas) ampliada con barrera, columna y pulso por elemento; comprobación headless nueva `prueba_vfx_geometria.gd`: el AABB del dibujo de una barrera ᛜ+3ᛁ mide ≥ 5 u de largo y < 2 u de fondo, la columna ≥ 1 u de alto, el pulso acaba con radio = `g × casilla` ± 10 %. Regresión: `prueba_vfx_elemento`, `prueba_haz`, `prueba_vfx_tierra_viento`, golden de hechizos (no debería cambiar: no se toca `Hechizo`).

**Dónde verlo:** `laboratorios/LabGeometrias3D.tscn` (Espacio lanza 15 carriles, Tab cambia elemento, numpad suma glifos) con una barrera ancha y una columna.

### Tarea V2 · Momentos sin VFX (Sonnet)

- **Rebote**: en `HechizoVivo._rebotar` llamar `Sensacion3D.impacto_mundo(lanz, p, dir, el, _radio_u, "rebote")` con una variante ligera (estrella ×0,5, sin temblor, `golpe_mundo` a tono alto).
- **Fin por alcance** de agua, rayo, tierra, viento, hielo: `desvanecer` genérico del kit (poof corto del color; `fuego.gd` ya lo tiene como referencia).
- **Barrera rota o caducada**: el seguidor guarda una referencia débil a `SolidezV2` y al `tree_exited` hace fundido rápido + estallido (`vfx_hechizo("estallido")`).
- **Copias de volumen**: deduplicar `sitios` por posición, tope 8 y respetar la `t` de cada evento con `create_timer`.
- **Rayo y tiempo con pieza propia**: al menos la `Formas3D` «rayo» (ya validada en `VfxEstado3D`) para bola y barrera.

### Tarea V3 · El laboratorio aprueba lo que se juega (Sonnet, pequeña)

- La pestaña F4 (`lab_vfx_3d.gd:177-196`) dibuja con `VfxElemento3D` (el del juego) y ofrece una tecla para alternar al de estado. Borrar o arreglar `laboratorios/LabVfx3D.tscn`.

---

## 5. Pilar 2 · SFX (sutiles y satisfactorios)

### Combate

- Catálogo en `nucleo/sfx.gd` (volumen e intención en dB) y `nucleo/sfx_3d.gd` (con distancia). Lote 4 añadió cuerpo golpeado por familia, daño de la jugadora, latido, voltereta, recarga lista, golpe contra el mundo y el zumbido de carga. **Todo sintetizado y sin validar de oído** (PENDIENTES, lote 4). No hay nada que programar ahí hasta escucharlo.
- Lo que choca con «sutil»: `explosion` y `pira` a **−3 dB** y `muerte` a −4 (los más altos del catálogo); `logro_brillo` (campana de logro, −12) suena **por cada planta común** (`objetos/recolectable_3d.gd:315`, `botin_objeto_3d.gd:231`). La muerte de la jugadora no suena en absoluto.
- Lo que falta para «satisfactorio»: ningún sonido distinto por **rareza** del objeto (épico solo tiene luz morada), y la **muerte por elemento** es la misma (PROMPT_RESUMEN §5 D15).

### Tarea S1 · Sesión de escucha con mando en vivo (Sonnet, pequeña; antes que cualquier sonido nuevo)

En el panel F3 de `LabHechizos3D` (entradas «S:») añadir el **volumen de cada entrada de `Sfx.CATALOGO`** en vivo (el `db` es un `const` dentro de un diccionario: hacer que `Sfx.play` consulte una `static var AJUSTES: Dictionary` que se superpone al catálogo, y un botón «imprimir ajustes» que vuelque los dB cambiados por consola). Añadir un **bus «Interfaz»** en `project.godot` (−6 dB de partida) por el que pasan `Sonidos.play` y los sonidos de menú, para bajarlos todos a la vez. Es el único modo de que Pablo afine «sutil» sin reiniciar.

### Tarea S2 · Rareza y bajadas evidentes (Sonnet)

- `AvisoObjeto.mostrar` elige el sonido por calidad: común `recoger` (el sintetizado de `nucleo/sonidos.gd:27-78`, hoy sin uso, pasado a `audio/` y al catálogo), raro `logro_pista`, épico `logro_brillo` + luz morada (como hoy), legendario `logro_acierto`. Quitar `logro_brillo` de `recolectable_3d.gd:315` y `botin_objeto_3d.gd:231`.
- `explosion` y `pira` a −6; `muerte` se reserva para la jugadora (tarea M4).

---

## 6. Menús e interfaz (todo el proyecto)

### Lo que hay (resumen de la auditoría)

| Pantalla | Suena | Se anima | Error con sonido |
|---|---|---|---|
| Mochila (`MenuPestanas`, tecla I; `bolsa_ui.gd` ya no se monta) | `Sonidos "bolsa"` abrir/cerrar | tween 0,22 s / 0,16 s (sube 34 px, fundido) | no |
| Pestañas (Q/E) | no | no | no |
| Navegar huecos / misiones | no | anillo dorado de golpe | no |
| Equipar consumible (Enter) | no | no (el refresco destruye y recrea los 20 huecos) | no |
| Beber poción (Q) | **no** (`Sonidos "pocion"` existe sin uso) | clip `drink` 1,5 s + «+N» verde | no (solo texto naranja) |
| R cambia consumible / tónico / bálsamo / infusión | no | anillo de tiempo | no |
| Grimorio abrir/cerrar | `libro_abre/cierra` | **no** (`visible` de golpe) | – |
| Grimorio pasar página / trazo / glifo | `pagina` / `trazo` / `sello_ok` | no | `sello_no` (dos rechazos sin él: `grimorio.gd:293, 534`) |
| Deshacer / vaciar página | no | no | – |
| HUD páginas y recargas | `no_puedes`, `recarga_lista` | temblar rojo, destello, barrido | sí |
| Barra de vida / tinta | latido (vida baja), `logro_pista` (tinta recuperada) | suavizado 0,18 s; frasco gastado pop | tinta: rojo 0,35 s |
| Pantalla de muerte | **nada** | shader 0,6 s, fundido | – |
| Pausa / menú principal | no existe | – | – |
| Tienda (E en el guardabosques) | `conversacion_voz` al hablar; comprar **mudo** | no | no |
| Diálogo NPC | `conversacion_voz` | el NPC mira y habla; texto sin caja | – |
| Recoger planta / botín / oro | `logro_brillo` / `logro_brillo` / `moneda` | agacharse; arco e imán | mochila llena: solo texto |
| Cofre (`Cofre3D`) | **nada en el nodo**; `logro_fanfarria` solo por `Logros3D` en `puzle.gd`; en el Bosque 01 solo texto | anticipación, luz, tapa | – |
| Misiones (recibir, avanzar, completar) | **nada** | la línea del HUD cambia de golpe | – |
| Pista «[E]» (`PistaInteraccion`) | – | lista, pero **no montada** | – |

Además: `Sfx.play` con un `CanvasLayer` de origen falla en `global_position` (`sfx.gd:245`); `Sonidos` (`nucleo/sonidos.gd`) es un segundo sistema con cinco sonidos sin usar; con el libro abierto (tiempo 0,3, no pausa) se puede abrir la mochila encima (`menu_pestanas.gd:251`).

### Tarea M · Mochila y consumibles (el ejemplo desarrollado; Sonnet)

**Objetivo:** que cada acción del inventario se oiga y se vea, suave, sin que nada tape el juego. **Archivos:** `presentacion/ui/menu_pestanas.gd`, `presentacion/ui/bolsa_ui.gd` (solo `Hueco`), `presentacion/ui/hud_eow.gd`, `nucleo/consumibles.gd`, `jugador/jugador_3d.gd`, `nucleo/sfx.gd` (catálogo), `nucleo/sonidos.gd` (migrar sus 5 sonidos a `.wav` en `audio/` con `audio/gen_sfx_interfaz.py` y darlos de alta en `Sfx.CATALOGO` en el bus «Interfaz»; `Sonidos` queda como alias y se retira). Prueba `herramientas/prueba_mochila_sensacion.gd` (headless: cuenta de sonidos y de tweens) y captura `herramientas/captura_mochila.gd` (con ventana, 6 fotogramas).

**M1 · Abrir y cerrar.** Mantener el tween (0,22 / 0,16 s). Sonido `bolsa` ya existe: bajarlo a −10 dB y que la **J** (misiones) use `libro_abre`/`libro_cierra` en vez de `bolsa`. Al abrir, el hueco elegido entra con un **pop** (escala 1,15 → 1 en 0,12 s, TRANS_BACK).

**M2 · Navegar.** Al cambiar el hueco elegido (flechas o ratón, `_elegir` `:489-500`): tick `ui_tick` (nuevo, sintetizado, −20 dB, tono ±4 %, veda 70 ms) y el anillo dorado **se desliza** del hueco anterior al nuevo en 0,08 s (un `Control` aparte por encima de la rejilla; hoy el anillo es parte del `_draw` de cada `Hueco`, `bolsa_ui.gd:281-282`). El panel de detalle (`Detalle.mostrar`, `:635-667`) funde el icono 0,1 s. Cambiar de pestaña (`cambiar_pestana` `:276-293`): `pagina` a −14 dB y el contenido entra desde 12 px a un lado en 0,12 s.

**M3 · Equipar y usar desde el menú.** Enter sobre consumible no equipado (`accion` `:417-431`): `ui_equipar` (dos notas cortas, −12 dB), el icono del hueco hace pop y el círculo del HUD (`hud_eow.gd` `Circulo`) destella 0,2 s. **Para poder animar el hueco hay que dejar de destruir los 20 huecos en `_refrescar` (`:441-479`)**: crear una vez y actualizar `id`/`cantidad`, con `queue_redraw`. Enter sobre material o clave (`:423-424`): `no_puedes` a −14 dB y el hueco tiembla 0,15 s (mismo patrón que `PageHud.temblar`).

**M4 · Beber poción (Q), fuera del menú.** `jugador_3d.gd:989` (`_iniciar_beber`): `pocion` (el sintetizado) en bucle corto de 1,2 s acompañando al clip `drink`; `:1016-1023` (`_terminar_beber`): `pocion_fin` (tono +15 %), **destello verde** en la jugadora (reutilizar el camino del destello de `Combate3D` sobre `pj._materiales`, color `Color(0.55, 1.0, 0.6)`, 0,2 s) y la barra de vida **sube con un pulso** (franja clara que avanza por delante del relleno, `barra_hud.gd:65-69`). Cancelar por golpe (`_cancelar_beber`): `no_puedes` corto. Errores (`consumibles.gd:95-124, 148-149`): `no_puedes` a −14 dB y el círculo del HUD tiembla 0,15 s. R cambia de consumible (`hud_eow.gd:180-189`): `ui_tick` y el icono del círculo gira 180° en 0,15 s.

**M5 · Objeto nuevo.** Con el menú cerrado ya hay `AvisoObjeto` (se queda; el sonido lo decide S2). Con el menú abierto (`_al_cambiar_mochila`): el hueco nuevo hace pop y brilla 0,4 s. El contador de oro (`_oro.text`, `:445`) **cuenta** hacia el valor nuevo en 0,3 s y hace pop; `moneda` al subir.

**M6 · Reglas.** Nada de esto cambia qué se equipa ni cuánto cura. Con el libro abierto no se abre la mochila (`menu_pestanas.gd:251`: comprobar `lanz.libro_abierto()`). Los sonidos de interfaz van por el bus «Interfaz» y se reproducen con un `AudioStreamPlayer` plano (sin posición): añadir `Sfx.play_ui(nombre)` para no pasar por `global_position` (`sfx.gd:245`).

**Prueba:** abrir con I y comprobar: 1 sonido `bolsa`, tween vivo; mover 3 veces → 3 `ui_tick` y la posición del anillo acaba en el hueco 3; Enter sobre poción → `ui_equipar` + destello del círculo; Enter sobre material → `no_puedes`; Q fuera del menú con vida llena → `no_puedes` y sin `pocion`; Q con vida baja → `pocion` al empezar y `pocion_fin` + destello verde al acabar; recibir un objeto con el menú abierto → el hueco nuevo tiene tween; `Sensacion3D.ACTIVA = false` apaga pops y destellos pero no los sonidos de confirmación (son interfaz, no sensación). Regresión: `prueba_bolsa`, `prueba_consumibles` (si existe), `prueba_escritura_hud`, `prueba_tema_interfaz`.

**Dónde verlo:** `escenas/PruebaBosque.tscn`, tecla I; Q con una poción en la mochila (la paleta F1 «Añadir todos» da pociones). Capturas en `docs/capturas/mochila/`.

### Tarea U · Resto de la interfaz (Sonnet; se puede partir en dos)

- **U1 · Grimorio:** tween al abrir y cerrar (`spellbook.gd:498-555`: escala 0,96 → 1 y fundido en 0,15 s, como ya hace `GrimorioUI` de pruebas); `sello_no` en los dos rechazos mudos (`grimorio.gd:293, 534`); `pagina` suave al deshacer (`undo_last`) y un «barrido» al vaciar (`clear_sequence`).
- **U2 · Muerte y reaparición:** la rama letal de `jugador_3d.gd:500-506` llama también a `Sensacion3D.dano_recibido` (viñeta y golpe antes del fundido); `pantalla_muerte.gd:112` suena `muerte` (ya en catálogo, bajar a −8) y `reaparecer` (`jugador_3d.gd:566-584`) un tono suave de vuelta + viñeta clara que se abre.
- **U3 · Misiones:** `MisionHud` (`mision_hud.gd:41-53`) reacciona a `Misiones.activar/objetivo_hecho/completar` con `logro_pista` (activar y objetivo) y `logro_acierto` (completar), y la línea entra deslizándose 0,2 s y destella.
- **U4 · Tienda y oro:** `bosque_3d.gd:403-417`: `comprar` (migrado de `Sonidos`) al comprar, `no_puedes` sin oro o ya comprada; oro de cofres y misiones con `moneda` (`puzle.gd:1061`, `bosque_01_3d.gd:685`, `misiones.gd:219`).
- **U5 · Cofres:** `cofre_3d.gd:299` (`creak` al anticipar) y `:340` (chasquido de tapa, nuevo `cofre_tapa`); los cofres del Bosque 01 pasan por `Mundo3D.avisar_logro("cofre_abierto")` como los de `puzle.gd:1092`.
- **U6 · Pista «[E]»:** montar `PistaInteraccion` con un detector de proximidad en los cuatro sitios que escuchan la E (`bosque_3d.gd:363`, `jugabilidad_3d.gd:615`, `bosque_01_3d.gd:629`, `recolectable_3d.gd:257`).
- **U7 · Mochila llena y bálsamo:** `no_puedes` en `recolectable_3d.gd:306`, `botin_objeto_3d.gd:220`, `jugabilidad_3d.gd:604`; el bálsamo usa `escudo_golpe` al absorber y `escudo_roto` al agotarse (`consumibles.gd:254-288`).
- **U8 · Barras con peso** (PROMPT_RESUMEN E17): franja fantasma que baja más lento y flash blanco en la barra de vida de la jugadora (`barra_hud.gd`), pulso al curar, destello del frasco al recargarse con tónico.

---

## 7. Orden propuesto y reparto

| Orden | Tarea | Dueño | Tamaño | Por qué primero |
|---|---|---|---|---|
| 1 | **P** empuje por daño y masa (**hecho 31/10**) | Juego | medio | Es el pilar más incoherente y toca una sola función (`v0_de_empuje`) con previsión ya conectada |
| 2 | **H** destello por elemento (**hecho 31/10**) | Juego | pequeño | Lo que Pablo pidió literalmente; un solo sitio de pintura |
| 3 | **M** mochila y consumibles (**hecho 31/10**) | Juego (UI) | medio | El ejemplo pedido; corrige lo más mudo del juego (poción, errores) |
| 4 | **S1** mando de volumen en vivo + bus Interfaz (**hecho 31/10**) | Juego | pequeño | Sin esto «sutil» no se puede afinar sin reiniciar |
| 5 | **V1** barrera = muro, pulso que crece, radio con suelo | Pipeline / Juego | grande | Lo más visible del pilar VFX; el apuntado ya promete lo que el VFX no cumple |
| 6 | **U1 + U2 + U3 + U4** grimorio, muerte, misiones, tienda (**hecho 31/10**) | Juego | pequeño ×3 | Momentos clave sin ningún sonido |
| 7 | **V2, V3, S2, U1, U5 a U8** | varios | medio | Completan los pilares |

Cada tarea: su prueba headless, su captura con ventana cuando algo no se ve sin pantalla, commit propio con mensaje en español, y en el DIARIO una entrada con dónde verlo (escena y tecla). Nada cambia reglas (daño, tinta, recargas): si una tarea las tocara, se para y se pregunta.

### Preguntas para Pablo antes de empezar

1. **P:** ¿el empuje por elemento se mantiene (tierra empuja mucho más que el rayo) y se **modula** por el daño, como propongo, o quieres que el empuje salga **solo** del daño (y entonces tierra pierde su identidad de «pedrada»)?
2. **H:** ¿el blanco inicial de 0,05 s se queda (asegura que se ve) o prefieres el color del elemento desde el primer fotograma?
3. **M:** ¿cuál era el ejemplo del inventario que querías que analizara? No llegó en el mensaje.
4. **V1:** `presentacion/` es del Pipeline según `PROPIETARIOS.md`. ¿Lo hace este contexto igualmente?
