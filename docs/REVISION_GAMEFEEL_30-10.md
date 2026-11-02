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
| 7 | **V2, V3** (otro chat); **S2, U5 a U8** (**hecho 31/10**) | varios | medio | Completan los pilares |

Cada tarea: su prueba headless, su captura con ventana cuando algo no se ve sin pantalla, commit propio con mensaje en español, y en el DIARIO una entrada con dónde verlo (escena y tecla). Nada cambia reglas (daño, tinta, recargas): si una tarea las tocara, se para y se pregunta.

### Preguntas para Pablo antes de empezar

1. **P:** ¿el empuje por elemento se mantiene (tierra empuja mucho más que el rayo) y se **modula** por el daño, como propongo, o quieres que el empuje salga **solo** del daño (y entonces tierra pierde su identidad de «pedrada»)?
2. **H:** ¿el blanco inicial de 0,05 s se queda (asegura que se ve) o prefieres el color del elemento desde el primer fotograma?
3. **M:** ¿cuál era el ejemplo del inventario que querías que analizara? No llegó en el mensaje.
4. **V1:** `presentacion/` es del Pipeline según `PROPIETARIOS.md`. ¿Lo hace este contexto igualmente?

---

## 8. Segunda tanda (1/11): lo que falta más allá de los cuatro pilares

Pedido por Pablo el 1/11 tras cerrar la primera tanda. Cinco tareas que no tocan el VFX de los hechizos (eso lo lleva otro chat; `presentacion/vfx_3d.gd` y los proyectiles no se editan aquí). Todo `static var`, todo respeta `Sensacion3D.ACTIVA` (si es false, nada de movimiento, pero sí sonidos), nada cambia reglas.

### Tarea C · Cámara que reacciona (Sonnet, pequeña)

Hoy el golpe se nota en el enemigo y en la viñeta, pero la cámara solo tiembla (`Vfx3D.temblor`, 5 sacudidas de `h_offset/v_offset`) con intensidad fija por evento (`TEMBLOR_GOLPE` 0,25). No hay Camera3D propia en el repo: todo va por `get_viewport().get_camera_3d()`.

- **C1 · Retroceso al lanzar.** En `Sensacion3D.disparo(lanz, elemento, dir, mano, retroceso)` (`sensacion_3d.gd:175`): empujar la cámara 2 a 6 px (`h_offset/v_offset`) en sentido contrario a `dir` proyectado en pantalla y volver en 0,12 s (TRANS_BACK); la magnitud escala con el número de glifos de la receta (`RETROCESO_CAM_MIN` 2 px con 1 glifo, `RETROCESO_CAM_MAX` 6 px con 5). El lanzador ya sabe los glifos (`glifos_pagina` en `_preparar_pagina`, `lanzador_3d.gd:897`); si `disparo` no los recibe, añadir un parámetro opcional `n_glifos` con valor por defecto 1. Debe convivir con el temblor: ambos escriben `h_offset/v_offset`, así que el retroceso se suma a la base guardada en la meta `temblor_base` de la cámara, no la pisa.
- **C2 · Temblor por daño.** `Combate3D._impacto_visual` (`combate_3d.gd:1050-1066`) llama `temblor(TEMBLOR_GOLPE)`: multiplicar por `_k_golpe` (ya calculado por la tarea P: 0,6 a 1,6) con tope `TEMBLOR_MAX` 0,5. Con debilidad se mantiene `TEMBLOR_DEBIL`. El golpe F y el daño continuo no tiemblan más que hoy.
- **C3 · Sin acumulación.** Dos golpes en el mismo fotograma (área) no suman temblor: `Vfx3D.temblor` ya corta el anterior, pero C2 debe pasar el máximo de los `_k_golpe` del fotograma, no el último. Guardar en `Sensacion3D` un `_temblor_pendiente` que se aplica en el siguiente `_process` con el mayor valor pedido.

**Prueba** `herramientas/prueba_camara_reacciona.gd`: disparo con 1 glifo mueve la cámara ≥ 2 px y con 5 glifos ≥ 2× más; vuelve a la base en 0,15 s; durante un temblor el retroceso no deja la cámara desplazada al acabar (base restaurada); golpe de 5 glifos tiembla más que de 1; dos golpes en el mismo fotograma = un temblor con el mayor; `ACTIVA = false` → cámara quieta. Regresión: `prueba_sensacion` 1-4, `prueba_golpe_cuerpo`, `escenario_lab_hechizos`.

**Dónde verlo:** `laboratorios/LabHechizos3D.tscn`, Espacio con 1 y 5 glifos; panel F3 (`S:RETROCESO_CAM_*`, `TEMBLOR_MAX`).

### Tarea D · Ping de debilidad (Sonnet, pequeña)

`HITSTOP_DEBIL` (0,10 s) ya congela al enemigo, pero la única señal de «has acertado el elemento» es la barra.

- Al golpear con debilidad (`Combate3D.golpe`, rama `mult > 1.0`, `combate_3d.gd:837-845`): sonido `ping_debil` (nuevo, agudo y corto, −10 dB, generado con `audio/gen_sfx_interfaz.py`, bus Master porque es del mundo: `Sfx.play(self, …)`) y un **flash de pantalla de un fotograma** blanco al 18 % (`ALFA_FLASH_DEBIL`), con el patrón de `Sensacion3D._vineta` (`sensacion_3d.gd:290`: CanvasLayer propia «FlashDebil», ColorRect lleno, se apaga en el siguiente fotograma). Con resistencia (`mult < 1.0`): `golpe_sordo` (nuevo, grave y apagado, −12 dB) y sin flash.
- `Sensacion3D.ACTIVA = false` apaga el flash; los sonidos quedan.
- Veda de 120 ms para el flash (un área que golpea a cuatro enemigos débiles no parpadea cuatro veces).

**Prueba** `herramientas/prueba_ping_debil.gd`: golpe débil → `ping_debil` y la capa de flash visible un fotograma y oculta al siguiente; golpe normal → ni sonido ni flash; resistente → `golpe_sordo`; cuatro golpes débiles en 50 ms → un solo flash y cuatro pings (el ping tiene su veda de `Sfx3D`, comprobar lo que salga y documentarlo); `ACTIVA = false` sin flash. Regresión: `prueba_destello_elemento`, `prueba_sensacion`, `prueba_empuje_masa`.

**Dónde verlo:** `laboratorios/LabRecetas3D.tscn`, agua sobre un enemigo de fuego.

### Tarea E · Muerte por elemento (Sonnet, media)

Hoy todos los enemigos mueren igual (`Combate3D._morir`, `combate_3d.gd:2485`: animación `death`, sonido, encoger a 0,01 en 0,35 s tras 1,4 s, botín). Es el momento de mayor recompensa y no dice nada del elemento. `_destello_el` conserva el elemento del golpe letal.

- **E1 · Variante por elemento** en `Combate3D._morir`, leída de `_destello_el` antes de limpiar, en una función `_muerte_elemental(el)` que los hijos pueden sobrescribir:
  - **fuego:** tinte a carbón (`_aplicar_tinte` hacia `Color(0.15, 0.1, 0.08)` en 0,4 s), `Vfx3D.ceniza(p)` sobre el cuerpo y `llamas` pequeñas 0,8 s; el encogido final es un desmoronamiento (escala Y a 0,01 primero, luego XZ).
  - **hielo:** tinte azul claro y emisión fría durante 0,3 s, luego el cuerpo se **rompe**: `Vfx3D.chispazo_suave(p, COLOR[hielo])` y el modelo desaparece de golpe (sin encoger) con 6-8 trozos (cubos pequeños `MeshInstance3D` con el color del tinte que caen con gravedad simple y se funden en 1 s; nodo ayudante `TrozosHielo3D` en `enemigos/`).
  - **rayo:** el cuerpo se queda **rígido** (sin animación `death`: pausar el AnimationPlayer en el fotograma del golpe), tiembla en sitio 0,3 s (`_respingar` repetido) con `Vfx3D.chispazo(p, "rayo")` ×3 y cae de golpe (rotación X 90° en 0,15 s).
  - **agua:** `salpicadura(p, 1.2)` y `vapor(p)`, el cuerpo se desliza 0,5 u en la dirección del último empuje mientras encoge.
  - **tierra:** `polvo` grande (`Sensacion3D.polvo(en, pos, 1.2)`) y `grietas(suelo, 0.6, 1.5)`; el cuerpo se hunde 0,3 u antes de encoger.
  - **viento / sin elemento / golpe F:** como hoy.
- **E2 · Sonido por elemento:** `snd_muere` sigue sonando; además un remate corto por elemento: fuego `pira` a −14 (ya existe), hielo `hielo_rompe` (nuevo), rayo `chispazo` (si existe en catálogo; si no, nuevo), agua `salpicadura` (si existe), tierra `derrumbe` a −12 (existe). Nuevos generados con el script de audio.
- **E3 · Los hijos:** limo (`limo_3d.gd:558`, tiene `_morir` propio y shader) solo recibe el tinte y las partículas, no el desmoronamiento ni los trozos; gólem (`golem_3d.gd:595`) y chamán (`chaman_3d.gd:392`) llaman a `_muerte_elemental` si su `_morir` propio no lo impide; gato como el goblin; elemental (`_morir_elemental`, `combate_3d.gd:2363`) no cambia.
- **E4 · Límite:** máximo `MAX_MUERTES_VFX` 3 muertes con efecto completo por segundo; a partir de ahí solo tinte y sonido (un área que mata a seis no debe bajar los fps). `ACTIVA = false` → muerte de hoy.

**Prueba** `herramientas/prueba_muerte_elemento.gd`: matar a un goblin con cada elemento (fuego, hielo, rayo, agua, tierra, viento, golpe F) y comprobar la rama (tinte, nodos de partículas creados, AnimationPlayer pausado en rayo, trozos en hielo que desaparecen antes de 1,5 s, el nodo se libera en el mismo tiempo que hoy ±0,3 s); el botín y `Estado.enemigo_muerto` llegan igual en todas; limo con fuego → tinte sin trozos; siete muertes en 0,5 s → solo 3 con partículas; `ACTIVA = false` → sin nodos nuevos. Regresión: `prueba_limo_combate`, `prueba_golem_combate`, `prueba_chaman_combate`, `prueba_gatopedro`, `prueba_sensacion` 1-4, `prueba_destello_elemento`, `prueba_empuje_masa`, `escenario_sala_limo`, `escenario_sala_golem`.

**Dónde verlo:** `laboratorios/LabRecetas3D.tscn`, matar goblins con cada elemento; `escenas/PruebaSalaLimo.tscn`.

### Tarea O · Oclusión del sonido (Sonnet, pequeña)

`Sfx3D.play` (`sfx_3d.gd:84`) crea un `AudioStreamPlayer3D` en la raíz, sin bus propio ni filtro. Un enemigo detrás de una roca suena igual que uno a la vista.

- Bus nuevo **«Mundo»** en `default_bus_layout.tres` (0 dB, a Master) con un `AudioEffectLowPassFilter` desactivado por defecto; todos los `AudioStreamPlayer3D` de `Sfx3D` van a él. Bus **«Ocluido»** (a Master) con el mismo filtro a `CORTE_OCLUSION` 900 Hz y −6 dB.
- Al crear el reproductor, `Sfx3D` lanza un `RayCast3D`/`PhysicsDirectSpaceState3D.intersect_ray` desde el oyente (`AudioListener3D` de `jugador_3d.gd:841`) al origen, solo contra la capa de terreno y obstáculos (la que use la jugadora para chocar; comprobar `collision_mask`); si hay algo en medio, el reproductor va al bus «Ocluido». Para bucles (`ambiente`) se reevalúa cada `T_REEVALUAR_OCLUSION` 0,25 s y se cambia de bus en caliente (sin cortar).
- `OCLUSION_ACTIVA` static var; si es false, todo va a «Mundo». Fila «dB:Mundo (bus)» y «dB:Ocluido (bus)» en el panel F3, junto a «dB:Interfaz (bus)».

**Prueba** `herramientas/prueba_oclusion_sfx.gd`: un sonido con línea de vista va al bus «Mundo»; con un `StaticBody3D` con `BoxShape3D` entre medias va a «Ocluido»; un ambiente cambia de bus al interponer y quitar el muro sin reiniciarse (`playing` sigue true, `get_playback_position` no vuelve a 0); `OCLUSION_ACTIVA = false` → siempre «Mundo»; los dB de `AJUSTES` siguen mandando. Regresión: `prueba_ajustes_sfx`, `prueba_golpe_cuerpo`, `prueba_sintesis`, `prueba_mochila_sensacion`.

**Dónde verlo:** `escenas/PruebaBosque.tscn`, un goblin alertado detrás de una roca grande.

### Tarea Pa · Pausa y volumen en juego (Sonnet, media)

No hay pausa: con el juego limpio, Escape no hace nada (`menu_pestanas.gd:417` y `lanzador_3d.gd:1105` solo cierran lo suyo). El mando de volumen de S1 vive en el panel F3 del laboratorio.

- `presentacion/ui/menu_pausa.gd` (`MenuPausa`), montado en `lanzador_3d.gd` justo tras `MenuPestanas` (`:615-617`), `process_mode = ALWAYS`. Escape con nada abierto lo abre (y pausa con el mismo patrón de `MenuPestanas.abrir`: `get_tree().paused`, `_pausado_por_mi`, no se abre si ya hay pausa ni con el libro abierto); Escape o «Continuar» lo cierra. Si `MenuPestanas` o el libro están abiertos, Escape sigue cerrándolos como hoy (orden de prioridad: libro → mochila → pausa).
- Contenido, navegable con flechas y Enter y con ratón, con el tema de `prueba_tema_interfaz`: **Continuar**, **Volumen general / Mundo / Interfaz** (tres deslizadores de −30 a +6 dB, en vivo con `Sfx.fijar_volumen_bus`; «Mundo» solo si la tarea O ya existe, si no, Master e Interfaz), **Sensación** (interruptor que escribe `Sensacion3D.ACTIVA`), **Reiniciar nivel** (recarga la escena actual, con confirmación), **Salir** (`get_tree().quit()`, con confirmación). Los volúmenes se guardan en `user://ajustes.cfg` (`ConfigFile`) y se cargan al arrancar (`Sfx._ready` o un autoload que ya exista).
- Entrada y salida con tween 0,15 s (fundido y escala 0,96 → 1, como el grimorio de U1); sonidos `libro_abre`/`libro_cierra` a −12, `ui_tick` al navegar, `ui_equipar` al confirmar, `no_puedes` en opciones no disponibles. Un fondo oscurecido al 55 % sobre el juego, sin desenfoque.
- No existe menú principal y no se crea en esta tarea.

**Prueba** `herramientas/prueba_menu_pausa.gd`: Escape pausa el árbol y abre con tween y `libro_abre`; segundo Escape cierra y despausa; con la mochila abierta Escape cierra la mochila y no abre la pausa; con el libro abierto no se abre; mover el deslizador de Interfaz cambia `AudioServer` y se guarda en `user://ajustes.cfg`; recargar los ajustes recupera el valor; interruptor Sensación escribe `ACTIVA`; «Reiniciar» recarga la escena (comprobar que la raíz cambia de instancia); `ACTIVA = false` abre sin tween. Regresión: `prueba_hud_eow`, `prueba_bolsa`, `prueba_lanzamiento_rapido`, `prueba_mochila_sensacion`, `prueba_tema_interfaz`, `prueba_ajustes_sfx`.

**Dónde verlo:** `escenas/PruebaBosque.tscn`, Escape.

### Orden

| Orden | Tarea | Tamaño | Lote |
|---|---|---|---|
| 1 | **C** cámara que reacciona | pequeño | A |
| 2 | **D** ping de debilidad | pequeño | A |
| 3 | **E** muerte por elemento | medio | A |
| 4 | **O** oclusión del sonido | pequeño | B |
| 5 | **Pa** pausa y volumen | medio | B |

Lote A toca `enemigos/`, `presentacion/sensacion_3d.gd` y el catálogo; lote B toca `nucleo/sfx_3d.gd`, `presentacion/ui/` y los buses. Se programan uno tras otro para no pisar `nucleo/sfx.gd`. **Los dos lotes hechos el 1/11** (diario 301 y 302). Hallazgo sin tocar: en headless un bucle de `Sfx3D.ambiente` que arranca pasada la mitad del archivo se para solo; conviene oír un brasero en el juego real.

---

## 9. Tercera tanda (2/11): actualización larga de bajo riesgo

Pedida por Pablo el 2/11: «una actualización larga y con poco riesgo de error». Todo aditivo: nada cambia daño, tinta, hechizos ni el VFX de hechizos (otro chat). Excluidos por Pablo: B3 códex, C2 brújula, C4 captura, bloque D accesibilidad. Añadido por Pablo: ciclo día/noche (N), «nos ayuda a probar la iluminación».

Lo que ya existe y se reutiliza: `Partida` (nucleo/partida.gd: ranuras `user://partidas/ranura_<n>.json`, `guardar/cargar/existe/borrar/segundos_jugados`, `continuar`), `_guardar_partida` y `_continuar_partida` en escenas/jugabilidad_3d.gd, `Niveles` (nucleo/niveles.gd: fundido, tabla ESCENAS, `cambiar`), `MenuPausa` (user://ajustes.cfg), `MenuPestanas` (pestañas Q/E), `Estado` (oro, bolsa, señales `enemigo_muerto`), flechas de borde de pantalla de `DirectorSensacion` (aviso de ataque), `LuzZona3D` (luz y ambiente por mapa), `Sfx3D.ambiente` y bus «Mundo», `TemaInterfaz`.

### Lote 1 · Partida (Sonnet)

**A1 · Menú principal y continuar.** Escena nueva `escenas/MenuPrincipal.tscn` + `presentacion/ui/menu_principal.gd`, puesta como `run/main_scene` en project.godot (la actual, `PruebaBosque01_v01.tscn`, pasa a ser la «Nueva partida»; anotar en el diario cuál era). Opciones: **Nueva partida** (borra la ranura 1 con confirmación si existe y entra por `Niveles`), **Continuar** (solo si `Partida.existe(1)`; usa `Partida.continuar`), **Cargar** (lista de las ranuras existentes con mapa y tiempo jugado de `segundos_jugados`, con Enter carga y Supr borra con confirmación), **Ajustes** (abre `MenuPausa` en modo «sin partida»: sin Continuar, Reiniciar ni Salir al menú; añadir ese modo), **Salir**. Navegación con flechas, Enter, Escape y ratón; sonidos `ui_tick`, `ui_equipar`, `no_puedes`; fondo: la escena del bosque cargada detrás no (demasiado peso): un ColorRect con el degradado del tema y el título. `MenuPausa` gana la opción **Salir al menú principal** (con confirmación), que guarda en la ranura «auto» (A2) y cambia de escena. Tween 0,15 s de entrada como la pausa.

**A2 · Autoguardado.** `Partida.AUTOGUARDADO` static var (true). Guardar en la ranura 0 («auto») al cambiar de nivel (`Niveles`, justo antes del fundido de salida), al completar una misión (`Misiones.mision_completada`) y al salir al menú. El HUD muestra un icono discreto (un pequeño círculo girando del tema, esquina inferior derecha) durante `T_ICONO_GUARDADO` 1 s, con `ui_tick` a −24. **Continuar** del menú principal carga la ranura más reciente entre la 1 y la auto (por `meta.fecha`). Los puntos de guardado siguen escribiendo en la ranura 1 como hoy. Con el árbol en pausa no se autoguarda (se difiere al despausar).

**A3 · Estadísticas.** `nucleo/estadisticas.gd` (`Estadisticas`, static): diccionario con `enemigos` por tipo, `hechizos` por elemento, `dano_hecho`, `dano_recibido`, `oro_ganado`, `muertes`, `cofres`, `segundos`. Se alimenta por señales que ya existen (`Estado.enemigo_muerto`, `Lanzador3D.lanzado`, `Combate3D.golpe` → `dano_hecho`, `Jugador3D` daño recibido y muerte, `Mundo3D.logro("cofre_abierto")`, oro por la función que ya suena `moneda`): enganchar desde `Estadisticas.conectar(arbol)` llamado una vez en `Jugador3D.montar()` o donde se monte el lanzador, sin tocar las reglas. Se guarda en `Partida` como sección `estadisticas` (versión 3 del archivo, con migración trivial: ausente = ceros) y se reinicia con «Nueva partida». Pestaña nueva **Estadísticas** en `MenuPestanas` (tras Misiones), texto en dos columnas con el tema. También `por_nivel` (mismas claves, se vacía al cambiar de nivel tras emitir A4).

**A4 · Resumen de nivel.** `presentacion/ui/resumen_nivel.gd`: al cambiar de nivel (`Niveles`, antes del fundido), tarjeta centrada 3 s (`T_RESUMEN` static var) con el nombre del nivel y las cifras de `Estadisticas.por_nivel` (tiempo, enemigos, cofres, oro, daño recibido); entra con tween 0,2 s, se puede saltar con cualquier tecla; `logro_pista` al aparecer. Si el nivel no ha registrado nada (laboratorios), no se muestra.

**Prueba** `herramientas/prueba_partida_menu.gd`: el menú principal muestra Continuar solo si hay ranura; Nueva partida pide confirmación si existe; Cargar lista las ranuras con tiempo; autoguardado escribe la ranura 0 al cambiar de nivel y al completar misión y no en pausa (se difiere); el icono aparece 1 s; Continuar elige la más reciente; las estadísticas cuentan una muerte, un hechizo, daño hecho y recibido y oro; se guardan y cargan (v3) y un archivo v2 carga con ceros; la pestaña existe y muestra las cifras; el resumen aparece con cifras y no aparece en vacío; `ACTIVA = false` sin tweens. Las pruebas usan ranuras de prueba (`Partida.RUTA_BASE` o similar apuntando a `user://partidas_prueba/`) y limpian al acabar. Regresión: `prueba_partida`, `prueba_hud_eow`, `prueba_misiones`, `prueba_menu_pausa`, `prueba_mochila_sensacion`, `prueba_niveles` (si existe), `escenario_bosque_01`, `prueba_estados_mundo`.

**Dónde verlo:** arrancar el juego (F5) → menú principal; `escenas/PruebaBosque01_v01.tscn` → completar una misión, cambiar de nivel; mochila (I) → pestaña Estadísticas; Escape → Salir al menú.

### Lote 2 · Controles e información (Sonnet)

**B1 · Input map y remapeo.** Añadir sección `[input]` a project.godot con acciones con nombre: `mover_adelante/atras/izquierda/derecha` (WASD y flechas si no las usa nada), `correr` (Shift), `interactuar` (E), `usar_consumible` (Q), `cambiar_consumible` (R), `mochila` (I), `misiones` (J), `libro` (T), `golpe` (F), `lanzar` (Espacio), `apuntar` (lo que sea hoy), `pausa` (Escape), `pagina_1/2/3` (1/2/3), `notas` (N) y las que aparezcan al buscar `KEY_` en jugador_3d.gd, lanzador_3d.gd, menu_pestanas.gd, hud_eow.gd, spellbook.gd, diario_misiones.gd, bosque_3d.gd, jugabilidad_3d.gd, bosque_01_3d.gd, recolectable_3d.gd. Sustituir cada `event.keycode == KEY_X` / `Input.is_key_pressed(KEY_X)` por `event.is_action_pressed("x")` / `Input.is_action_pressed("x")`. **NO tocar** las teclas de depuración y laboratorio (F1-F12, F3 panel, teclas de laboratorios/, herramientas/ y pruebas): siguen con `KEY_`. Atención a `_input` vs `_unhandled_input` y a `echo`: mantener el comportamiento exacto. Pantalla **Controles** en `MenuPausa` (y en Ajustes del menú principal): lista acción → tecla, Enter y pulsar una tecla para remapear, Escape cancela, «Restaurar» vuelve a las de fábrica; guardado en `user://ajustes.cfg` sección `[controles]` y aplicado al arrancar con `InputMap.action_erase_events/add_event`. Una tecla ya usada por otra acción se intercambia y avisa con `no_puedes`.

**Prueba** `herramientas/prueba_input_map.gd`: cada acción existe en `InputMap` con su tecla de fábrica; simular `InputEventKey` de cada tecla antigua produce el mismo efecto que antes (abrir mochila, cambiar consumible, golpe F, pausa, etc., comprobando el estado resultante); remapear `mochila` a K: I ya no abre y K sí; guardar y recargar el .cfg conserva el cambio; «Restaurar» vuelve a I; intercambio al elegir una tecla ocupada. Regresión: **todas** las pruebas que simulen teclas (buscar `InputEventKey` y `KEY_` en herramientas/: ejecutarlas todas y listar cuáles), más `prueba_hud_eow`, `prueba_bolsa`, `prueba_lanzamiento_rapido`, `prueba_menu_pausa`, `prueba_mochila_sensacion`, `prueba_interfaz_u1_u4`, `prueba_golpe_cuerpo`, `escenario_lab_hechizos`.

**B2 · Iconos de estado del enemigo.** Junto a la barra de vida del enemigo (`combate_3d.gd` ~2118-2150, donde viven `_nombre_etiqueta` y `_marca_debil`): hasta 4 iconos pequeños (`Label3D` billboard con un carácter por estado y color del elemento: quemado 🔥 o «♨», congelado «❄», envenenado «☠», mojado «≈», electrificado «⚡»; si la fuente del sistema no tiene el glifo, usar letras Q/C/V/M/E con círculo) con un anillo o barra de tiempo restante debajo. Leen los estados que ya existen (buscar en combate_3d.gd las variables de quemadura, congelado, veneno, mojado, electrificado y sus tiempos restantes); no los cambian. Visibles mientras la barra lo esté o mientras haya un estado activo (`ICONOS_ESTADO_SIEMPRE` static var, false = solo con la barra). Limo y gólem heredan sin cambios; elemental no muestra.

**Prueba** `herramientas/prueba_iconos_estado.gd`: prender a un goblin → icono de quemado visible con tiempo; congelar → dos iconos; al expirar desaparecen; con `ICONOS_ESTADO_SIEMPRE = false` y la barra oculta no se ven; `ACTIVA = false` → se siguen viendo (son información, no sensación). Regresión: `prueba_barra_vida`, `prueba_destello_elemento`, `prueba_fases_fuego`, `prueba_reacciones_vfx`, `prueba_limo_combate`, `prueba_golem_combate`.

**B4 · Descripciones de objetos y glifos.** Tabla nueva `nucleo/textos_objetos.gd` (`TextosObjetos.DESCRIPCION: Dictionary` id → texto de 1-2 frases en español, y `TextosObjetos.GLIFO: Dictionary` nombre de glifo → qué hace en una frase) rellenada para **todos** los objetos de `nucleo/objetos.gd` y todos los glifos de `Sigils` (leer sus efectos en el código para escribir textos verdaderos: ᛁ decreciente, ᛏ 4 niveles, etc.; ver DIARIO entrada del playtest de glifos del 30/10). Mostrarlas en el detalle de la mochila (`MenuPestanas.Detalle.mostrar`) bajo el nombre, y en el grimorio (`spellbook.gd`) al elegir un glifo (un pie de página de una línea). Las 3 descripciones que ya existen en objetos.gd se mueven a la tabla.

**Prueba** `herramientas/prueba_textos_objetos.gd`: cada id de `Objetos` tiene descripción no vacía; cada glifo de `Sigils` tiene texto; el detalle de la mochila muestra la descripción del objeto elegido; el grimorio muestra el texto del glifo elegido. Regresión: `prueba_bolsa`, `prueba_mochila_sensacion`, `prueba_grimorio`, `prueba_capacidad_libro`.

**Dónde verlo:** Escape → Controles; `laboratorios/LabRecetas3D.tscn` prender y congelar goblins; mochila (I) y libro (T).

### Lote 3 · Mundo (Sonnet)

**C1 · Marcador de misión en el mundo.** `presentacion/ui/marcador_mision.gd`: flecha en el borde de pantalla hacia el objetivo de la misión seguida, reutilizando el dibujo de las flechas de aviso de ataque de `DirectorSensacion` (buscar la función que las proyecta al borde) con color dorado del tema y la distancia en metros (`Terreno3D.casilla` = 1 m si no hay otra escala). Cada misión necesita un `punto_objetivo` opcional (Vector3 o nombre de nodo/grupo) en `nucleo/misiones.gd`: añadirlo a las misiones existentes donde el objetivo sea un lugar o un NPC (buscar en bosque_3d.gd, bosque_01_3d.gd dónde se activan y qué apuntan); sin punto, no hay flecha. Se oculta a menos de `DIST_OCULTAR_MARCADOR` 5 u y cuando el objetivo está en pantalla (entonces un rombo pequeño sobre él, `Label3D`). `MARCADOR_MISION_ACTIVO` static var.

**C3 · Ambiente sonoro por zona.** `nucleo/ambiente_zona.gd` (`AmbienteZona`): capa de bucle en el bus «Mundo» por tipo de zona que ya distingue `LuzZona3D` (bosque: viento suave + pájaros a intervalos; cueva: goteo y viento grave; sala/interior: zumbido bajo), con fundido cruzado de `T_FUNDIDO_AMBIENTE` 2 s al cambiar de zona o nivel. Sonidos generados con `tools/gen_sonidos_ambiente.py` (existe) o el script de audio, a −18 dB, con `AudioStreamPlayer` plano (no posicional) y `Sfx.AJUSTES` mandando. Los pájaros son un reproductor aparte que dispara una variante cada `INTERVALO_PAJAROS` 6-14 s aleatorio. De noche (N) los pájaros callan y entran grillos. `AMBIENTE_ACTIVO` static var.

**N · Ciclo día y noche.** `presentacion/ciclo_dia_3d.gd` (`CicloDia3D`), montado en los mapas exteriores (bosque y Bosque 01; no en cueva ni salas). Hora del día `HORA` static var (0-24, float), `DURACION_DIA_S` static var (600 s por defecto = un día en 10 minutos; 0 = parado), `HORA_INICIO` 10. Gobierna, **multiplicando** lo que `LuzZona3D` ya pone (no sustituye su color por zona): rotación de la `DirectionalLight3D` del mapa (elevación por hora: sale a las 6, cenit 13, se pone a las 20), su energía y color (amanecer naranja, día blanco cálido, atardecer rojizo, noche azul 0,12 de energía), ambiente del `WorldEnvironment` (energía y color), niebla (más densa y azulada de noche si la zona la usa) y una luna (segunda `DirectionalLight3D` tenue de noche, opcional). Las luces de braseros y hechizos no se tocan. Curvas en `Curve` o tablas por hora en `static var` para poder afinarlas. Panel F3 de LabHechizos3D: filas `S:HORA` y `S:DURACION_DIA_S`; teclas en el juego **no** (es depuración: desde el panel y desde `prueba_dia_noche`). `AmbienteZona` lee `CicloDia3D.es_noche()`. Si un mapa no tiene `DirectionalLight3D`, el ciclo no se monta y lo dice por consola una vez.

**Prueba** `herramientas/prueba_mundo_tanda3.gd` (una sola, con secciones): marcador: misión con punto fuera de pantalla → flecha visible con distancia; a menos de 5 u → oculta; objetivo en pantalla → rombo; misión sin punto → nada; completar → desaparece. Ambiente: entrar en zona bosque → bucle de viento en bus «Mundo» a −18; pasar a cueva → fundido cruzado de 2 s (los dos suenan durante el cruce, luego solo uno); pájaros disparan al menos una vez en 15 s a `INTERVALO_PAJAROS` forzado a 1-2; `AMBIENTE_ACTIVO = false` → silencio. Día/noche: con `DURACION_DIA_S = 10` la hora avanza 24 en 10 s; a las 13 la luz tiene elevación máxima y energía ≥ 0,9×día; a las 2 energía ≤ 0,15 y color azulado; el color por zona de `LuzZona3D` sigue multiplicado (cueva no monta el ciclo); amanecer y anochecer continuos (sin salto de color entre dos horas consecutivas > 0,2); `es_noche()` true a las 23 y false a las 12; con `DURACION_DIA_S = 0` la hora no cambia. Regresión: `prueba_misiones`, `prueba_interfaz_u1_u4`, `prueba_ataques_avisados`, `prueba_sintesis`, `prueba_ajustes_sfx`, `prueba_oclusion_sfx`, `escenario_bosque_01`, `escenario_bosque_01_ramas`, `escenario_cueva_completa`, `prueba_estados_mundo`, y cualquier prueba que mencione `LuzZona3D` o `WorldEnvironment`.

**Dónde verlo:** `escenas/PruebaBosque01_v01.tscn`: seguir una misión y mirar el borde de la pantalla; quedarse quieto y escuchar; panel F3 de `LabHechizos3D` con `S:HORA` a 2, 7, 13 y 19 (el laboratorio tiene que montar `CicloDia3D` si tiene luz direccional).

### Orden y lotes

| Lote | Tareas | Archivos principales |
|---|---|---|
| 1 | A1, A2, A3, A4 | nucleo/partida.gd, nucleo/estadisticas.gd (nuevo), nucleo/niveles.gd, escenas/jugabilidad_3d.gd, presentacion/ui/menu_principal.gd (nuevo), menu_pausa.gd, menu_pestanas.gd, resumen_nivel.gd (nuevo), hud_eow.gd, project.godot |
| 2 | B1, B2, B4 | project.godot [input], jugador_3d.gd, lanzador_3d.gd, ui/*, escenas/*.gd, combate_3d.gd, nucleo/textos_objetos.gd (nuevo), spellbook.gd |
| 3 | C1, C3, N | presentacion/ui/marcador_mision.gd (nuevo), nucleo/misiones.gd, nucleo/ambiente_zona.gd (nuevo), presentacion/ciclo_dia_3d.gd (nuevo), escenas de bosque, lab_hechizos_3d.gd |

Uno tras otro, commit por lote, diario 303, 304 y 305. **Hechos el 2/11.**

---

## 10. Sonidos grabados (2/11): sustituir síntesis por grabaciones

Pablo pidió buscar SFX reales y sintetizar solo lo que no se encuentre. Inventario en `audio/LICENCIAS.md` §«Fuentes descargadas»; packs en `audio/fuentes/` (con `.gdignore`). Hallazgo: `tools/gen_sfx.py`, que LICENCIAS cita como generador de `elem_*`, `prender`, `chispa`, `derrumbe`, `rodar`, `arco`, `pira`, `dano`, `muerte`, `trazo`, `sello_ok`, `sello_no` y `congelar`, **no existe en el repo**; esos wav no se pueden regenerar.

### Tarea R · Sustitución (Sonnet; Pablo escucha y decide)

Regla: cada sustitución es una línea del `CATALOGO` (o de `Sfx3D.CATALOGO`) apuntando a un archivo nuevo copiado a `audio/` con prefijo (`kenney_`, `oga_`, `fs_`, `lk_`); el sintetizado se queda. Un `static var Sfx.GRABADOS: bool = true` permite volver a los sintetizados en bloque (el catálogo guarda las dos rutas: `"archivo"` y `"archivo_sint"`), y una fila `S:GRABADOS` en el panel F3 para comparar en vivo con el mando de dB de S1.

| entrada del catálogo | hoy | candidato | notas |
|---|---|---|---|
| `moneda` | síntesis | Kenney RPG `handleCoins`, `handleCoins2` (2 variantes) | oro |
| `recoger` (común) | síntesis | Kenney RPG `cloth1..4` o `handleSmallLeather` | objeto |
| `ui_equipar` | síntesis | Kenney RPG `beltHandle1..2` | equipar |
| `bolsa` | síntesis | Kenney RPG `handleSmallLeather2` + `cloth` | abrir mochila |
| `ui_tick` | síntesis | Kenney Interface `click_001..005` (−20 dB) | navegar |
| `no_puedes` (interfaz) | síntesis | Kenney Interface `error_001..008` | solo en menús; el `no_puedes` del mundo se queda |
| `comprar` | síntesis | Kenney RPG `handleCoins` + Interface `confirmation_001` | tienda |
| `cofre_tapa` | síntesis | Kenney RPG `doorOpen` corto o Impact `impactWood_medium` | tapa |
| `golpe_piedra` (gólem) | síntesis | Kenney Impact `impactMining_00x`, `impactStone` | golpe al gólem |
| `golpe_carne` | síntesis | Kenney Impact `impactPunch_00x` o `impactSoft` | golpe a enemigo |
| `clavar` (golpe F) | Kenney `chop` | Kenney Impact `impactPunch` + `impactWood` | ya es grabado; comparar |
| pasos del gólem (nuevo `paso_golem`) | nada | Kenney Impact `footstep_concrete` a tono 0,6 y −4 dB | pasos pesados |
| pasos del goblin (nuevo `paso_goblin`) | nada | Kenney Impact `footstep_grass/wood` a tono 1,2 | enemigos sin pasos |
| `gato_maullido` | síntesis | OGA `cat_mewpurr`, `cat_softmew`, `Meow` (3 variantes) | alerta y muerte |
| ronroneo del gato (nuevo, bucle) | nada | OGA `cat_purractive_loop` | cuando está quieto cerca |
| `trazo` | tiza sintetizada al soltar | `fs_pluma_*` como **bucle mientras se arrastra** (volumen por velocidad del trazo) + el `trazo` de hoy al soltar | cambio de comportamiento en `spellbook.gd:715` |
| `pagina` | Kenney `bookFlip1..3` | se queda; añadir `paginas_bucle` = `fs_paginas_P_Chester` recortado para la animación de hojas | la animación no existe (tarea L) |
| impactos por elemento (`fuego_impacto`…) | solo `x_mano/alto/abajo_impacto` | lentikula Basic + Druid, 5 variantes por elemento | **cuando Pablo baje los packs**; `_sonar_fase_v2` pide `<elemento>_impacto` antes que el derivado |

Lo que sigue sintetizado porque no hay grabación libre: `sello_ok`/`sello_no` (son música), los jingles de logro, `pulso_resonante`, elemento tiempo, `carga_bucle`, voces de chamán y elemental, `limo_*` (Coucassi lo tiene pero es CC-BY: decide Pablo), goblin y gólem (Morphonaut, 2 $, decide Pablo).

**Prueba** `herramientas/prueba_sonidos_grabados_2.gd`: cada entrada sustituida carga, dura < 3 s salvo bucles, y `GRABADOS = false` devuelve el archivo sintetizado; los nuevos (`paso_golem`, `paso_goblin`, ronroneo) suenan desde su enemigo. Regresión: `prueba_sonidos_grabados`, `prueba_ajustes_sfx`, `prueba_mochila_sensacion`, `prueba_interfaz_u5_u8`, `prueba_gatopedro`, `prueba_golem_combate`.

### Tarea L · Animación de pasar página con la mano (Sonnet, media) — ver abajo

---

## 11. Caminar satisfactorio (2/11)

Pablo: «quiero que sea satisfactorio caminar por el mundo»; pidió polvo sutil al moverse por tierra y hierba que se mueve al pasar. Criterio para todo este bloque: cada paso deja algo en el mundo y el cuerpo y la cámara acompañan; nada de esto cambia velocidad, colisión ni reglas. Todo `static var`, todo se apaga con `Sensacion3D.ACTIVA = false` (menos las ondas del agua, que son del mundo). **No tocar** `presentacion/vfx_3d.gd` ni los hechizos.

**Lo que ya hay** (auditoría del 2/11): la hierba (`presentacion/hierba_3d.gd`, MultiMesh por bloques) ya tiene viento y **ya se aparta** alrededor de `posicion_jugador` (shader, `set_posicion_jugador`, llamado en `prueba_test2.gd:5169`) y **se aplasta** con la textura `pisado` (`marcar_pisado(celda, 0.35)` desde `jugador_3d.gd:738`, se levanta sola con `T_PISADO`). Los pasos se detectan por distancia en `Jugador3D._sonar_pasos` (`jugador_3d.gd:825`) con el tipo de suelo de `mundo._tipo_suelo(celda)` (0 hierba, 1 camino, 2 tierra, 3 piedra, «b» puente). `Sensacion3D.polvo(en, pos, radio)` (`sensacion_3d.gd:532`) delega en `VfxPuzle3D.polvo` (16 partículas + piedrecitas + aro: demasiado para un paso). Sombra de contacto (`sombra_contacto_3d.gd`) y ondas de agua (`agua_ondas_3d.gd`, `AguaOndas3D.impulso`) existen. No existe: polvo de paso, motas, hojas, huellas, balanceo de arbustos, chapoteo visual, balanceo de cámara al correr.

### W1 · Pies que dejan huella (Sonnet)
- **Polvo de paso.** En `_sonar_pasos`, con tipo 1 (camino) y 2 (tierra): `Sensacion3D.polvo_paso(j, pos_pie, k)`, función nueva en `sensacion_3d.gd` que crea **un solo** `GPUParticles3D` reutilizable por jugadora (no uno por paso) con `emitting` por ráfaga: `POLVO_PASO_N` 4 partículas andando y 7 corriendo, tamaño 0,12-0,2 u, vida 0,5 s, subida 0,15 u/s, color del suelo (`POLVO_PASO_COLOR` (0.72, 0.62, 0.5, 0.35)), sin sombras, `local_coords = false`. El pie: alternar `±0,12 u` lateral respecto a la dirección de marcha (izquierdo/derecho). Piedra (3) y puente: nada. Hierba (0): 2 **motas verdes** (`POLVO_PASO_COLOR_HIERBA`) que saltan 0,3 u y caen. En agua (`Terreno3D.se_nada`): nada aquí (W4).
- **Huellas.** En tierra y camino, un quad `MultiMesh` de huellas (`presentacion/huellas_3d.gd`, `Huellas3D`, hasta `HUELLAS_MAX` 48 en anillo) orientado a la marcha, alternando pie, albedo oscuro al 25 % que se funde en `T_HUELLA` 6 s. En hierba no (ya está el pisado). Se apagan con ACTIVA.
- **Aterrizar.** El polvo de caída ya existe (`POLVO_CAIDA`); añadir un **aplastamiento** del cuerpo (`Vector3(1.08, 0.9, 1.08)` → 1 en 0,12 s, TRANS_BACK; buscar cómo escala el modelo `pj`) si `vy <= -VY_POLVO_CAIDA`, y uno más leve (1.03/0.96) en cualquier aterrizaje.

### W2 · Hierba viva (Sonnet)
- Comprobar que `set_posicion_jugador` y `marcar_pisado` se llaman en **todos** los mapas con hierba (no solo donde lo hace `prueba_test2.gd:5169`): si algún nivel instancia `Hierba3D` por otro camino, engancharlo.
- **Apartado con muelle.** Hoy el apartado es radial e instantáneo. Añadir al shader un retorno con rebote: la brizna se inclina `APARTAR_FUERZA` (hoy el valor que haya) y, al salir la jugadora del radio, vuelve con `sin` amortiguado 0,6 s (uniform `t_salida` por bloque o aproximación: `posicion_jugador_anterior` + tiempo desde que se alejó, calculado en GDScript y pasado como uniform). Radio `APARTAR_RADIO` 0,9 u andando y 1,2 corriendo (pasar `vel_suelo` normalizada como uniform `empuje`).
- **Pisado más visible al correr:** `marcar_pisado(celda, 0.35)` pasa a `0.35` andando y `0.55` corriendo; `T_PISADO` se queda.
- Dos o tres **briznas sueltas** (motas) saltan al correr por hierba alta (`hierba_alta`, `hierba_crecida`): reutiliza las motas de W1 con 4 partículas.

### W3 · Cuerpo y cámara que acompañan (Sonnet)
- **Balanceo de cámara al correr:** `Sensacion3D.balanceo_carrera(vp, vel_norm, t)`: `v_offset` oscila `BALANCEO_AMPLITUD` 0,02 u a `BALANCEO_HZ` 2,6 Hz (dos pasos por ciclo) solo mientras `corriendo` y en suelo, con entrada y salida suaves 0,25 s; se suma a la base de `temblor_base`/retroceso como ya hace C1 (misma función de composición). Andando: la mitad. Nadando y en pausa: nada.
- **Inclinación al girar:** el modelo `pj` rota en Z hasta `INCLINACION_GIRO` 6° según el cambio de rumbo por segundo, suavizado 0,12 s; vuelve a 0 recto.
- **Arranque y frenada:** al pasar de parado a correr, aplastamiento leve 0,96 Y / 1,03 XZ en 0,1 s; al frenar en seco desde correr, una ráfaga de polvo de paso doble y el cuerpo se inclina hacia delante 4° 0,15 s.
- **Sombra de contacto** bajo la jugadora: comprobar que `SombraContacto3D` la cubre; si no, añadirla (radio 0,35 u, alfa 0,45) para que los pies «toquen» el suelo.

### W4 · Agua (Sonnet)
- Al andar con los pies en agua poco profunda (`Terreno3D.superficie_agua` y no `nadando`): cada paso llama `AguaOndas3D.impulso(pos, 0.35)` (la función existe; buscar la instancia en el mundo: `mundo.get("_ondas")` o como la obtenga `prueba_test2.gd:5545`) y 3 gotas (partículas azul claro, `GOTAS_PASO`) y `chapoteo` a −16 (ya en catálogo, sonido; usar `Sfx3D.play` con tono 1,1-1,3). Al entrar en el agua desde tierra: impulso 0,8 + salpicadura (`Vfx3D.salpicadura(p, 0.8)` es público; permitido llamarlo) y `chapoteo` normal. Nadando: ondas pequeñas cada 0,6 s detrás de la jugadora.

### W5 · El mundo responde (Sonnet)
- **Arbustos y helechos que se apartan:** `pieza_bosque_3d.gd` (sin viento ni reacción hoy). Añadir a las piezas `arbusto*`, `helecho*`, `hierba_alta`, `hierba_crecida`, `hierba_espesa` un `ShaderMaterial` de superposición (o `next_pass`, lo que menos cambie el look: leer `docs/HIERBA_OPTIMIZACION.md` y respetar PROPIETARIOS: `presentacion/` es del Pipeline, así que cambios mínimos y aditivos) con balanceo de viento suave (`VIENTO_PIEZAS` 0,04, misma fórmula de tiempo que la hierba) y apartado por `posicion_jugador` (radio 1,0 u, inclinación según distancia, retorno 0,8 s), ponderado por la altura del vértice (la base no se mueve). Un solo material compartido actualizado desde el mismo sitio que `Hierba3D.set_posicion_jugador`.
- **Hojas que caen:** bajo las copas de los árboles (piezas `arbol*`), un `GPUParticles3D` por bloque de hierba cargado (reutilizar la paginación de `Hierba3D`), `HOJAS_POR_BLOQUE` 3 hojas cada 4 s, caída con vaivén (`sin`) 2,5 s, quad de 0,08 u con el color del árbol de la zona. Solo exteriores. Y al pasar la jugadora bajo un árbol corriendo, 4 hojas extra.
- **Motas en la hierba:** `GPUParticles3D` de polen/luciérnagas por bloque: de día 6 motas blancas lentas (`MOTAS_DIA`), de noche (`CicloDia3D.es_noche()`) 4 luciérnagas amarillas con parpadeo (`MOTAS_NOCHE`). Alfa 0,5, tamaño 0,04 u, flotando 0,3 u sobre la hierba.
- **Pájaros que salen volando:** cuando la jugadora corre a menos de 3 u de un bloque de hierba con `PAJAROS_ACTIVO`, con probabilidad `PROB_PAJAROS` 0,15 por bloque y un mínimo de 8 s entre dos, salen 2-3 siluetas (quads billboard oscuros de 0,15 u) en arco hacia arriba y se desvanecen en 1,5 s, con una variante de `amb_pajaros` corta a −14.

**Presupuesto:** todo W5 por bloque de hierba cargado, nunca por mapa entero; `medir_rendimiento.gd` no debe subir más de 0,4 ms por fotograma con todo activo (medirlo antes y después y anotarlo en el diario). Cada efecto con su `static var *_ACTIVO`.

**Prueba** `herramientas/prueba_caminar.gd` (una, con secciones): W1 polvo de paso en tierra y camino (el emisor emite tras recorrer `DIST_PASO_ANDAR`), nada en piedra, motas en hierba, huellas creadas y desvanecidas tras 6 s, aplastamiento al aterrizar; W2 `posicion_jugador` y pisado se actualizan en PruebaBosque01_v01 y en PruebaBosque, pisado 0,55 corriendo, uniform `empuje` sigue la velocidad; W3 `v_offset` oscila solo corriendo y vuelve a la base al parar (sin deriva: base restaurada ±0,001), inclinación al girar y a 0 en recto, aplastamiento al arrancar, sombra de contacto presente; W4 impulso y gotas al andar en agua, salpicadura al entrar, ondas nadando; W5 material de piezas con `posicion_jugador`, hojas y motas solo por bloques cargados (contar nodos ≤ bloques × 2), pájaros con cadencia mínima; `ACTIVA = false` apaga todo menos las ondas. Regresión: `prueba_sensacion` 1-4, `prueba_look_diorama`, `prueba_terreno`, `prueba_suelo_impactos`, `prueba_humedad`, `prueba_presentacion`, `prueba_jugadora_base`, `prueba_estados_anim`, `prueba_camara_reacciona`, `prueba_golpe_cuerpo`, `escenario_bosque_01_v01`, `prueba_mundo_tanda3`, `medir_rendimiento`.

**Dónde verlo:** `escenas/PruebaBosque01_v01.tscn`: correr por el camino de tierra (polvo y huellas), atravesar hierba alta (apartado con rebote, motas), vadear el río, pasar bajo árboles corriendo, quedarse quieto en la hierba de noche (`S:HORA` 23 en el panel F3 de LabHechizos3D).

### Tarea L · Animación de pasar página con la mano (Sonnet, media)

No existe: `spellbook.gd` cambia de página solo con sonido y `mano_pluma_2d/3d` solo tiene poses de escribir. Al pulsar `pagina_N`: la mano 3D sube (`LEVANTADA`), se desplaza al borde derecho del libro en 0,12 s, «pinza» (nueva pose `PINZA`, pulgar e índice juntos) y arrastra hacia la izquierda mientras la hoja actual se aplasta en `scale.x` hasta 0,02 y la nueva se despliega (patrón de `grimorio_ui.gd:158-165`, 0,09 + 0,12 s), con `paginas_bucle` de fondo y `pagina` al terminar; la mano vuelve a `REPOSO`. Total ≤ 0,45 s; con `Sensacion3D.ACTIVA = false` cambio instantáneo como hoy. La escritura queda bloqueada durante la animación (no se pierde ningún trazo: se encola). Prueba `prueba_pasar_pagina.gd`: la página cambia al final de la animación, no antes; un trazo durante la animación se aplica después; tiempos; ACTIVA false.

