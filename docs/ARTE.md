# Dirección de arte

**Diorama 3D de fantasía, chibi y pastel**, visto con una cámara
ortogonal fija a 60° que gira en pasos de 90° (`ARQUITECTURA.md`, *Vista
3D*). Modelos de Meshy (`.glb`) colocados en casillas de 2,3 u como piezas
`.tscn`, con una paleta cerrada bajo una sola luz.

**Gramática visual de los hechizos (regla madre):** el sello/glifo decide
la macroforma y el comportamiento (silueta, dimensiones, orientación,
trayectoria, persistencia); el elemento decide la microanimación y el
material (color, textura, partículas, luz). Así un elemento nuevo vale con
todos los glifos sin un VFX por combinación (`docs/DECISIONES_CHATS.md`
§1). La barrera es **una** superficie continua, no seis cosas.

**Referencias:** Link's Awakening (estética general y fuego), Echoes of
Wisdom (diorama, desenfoque, agua), Little Goody Two Shoes (luz y
saturación), Genshin, Tears of the Kingdom (marco del inventario).

**Reglas que salieron de los chats (§4 de `DECISIONES_CHATS.md`):**
- Personajes **chibi**; el canon es la elfa chibi (5/10;
  `docs/RETIRADA_ARTE_ANTERIOR.md`). El tamaño de referencia es el del
  personaje **corriendo**, no en idle.
- Goblins de piel verde oscuro, todos con la altura del guerrero.
- Árboles sin rojo («se ve de pegote»): verdes y amarillos en degradado;
  se admiten variantes otoñales.
- Sin contorno por bloque y sin biseles a 45°.
- Presupuesto de triángulos: `arte/meshy/PRESUPUESTO.md` (equipo, 15 k
  como máximo).

**Dónde está cada cosa en este archivo.** §1 y §2 (colores de elemento y
paletas de bioma) siguen vigentes. Lo 3D: §9 piezas de puzle · §10 paleta cerrada y
presentación · §11 escritura, bolsa y diario (2D de interfaz) · §12–§15 y §17–§18 láminas de
Meshy separadas en piezas · §13 conjuro · §16 páginas del grimorio · §19
mano 3D que escribe · §20 retoques del Bosque 01 · §21 rejilla guía ·
§22 glifos · §23 recortador de láminas. §3–§8 son **historia de la era
2D** y están resumidas en un solo párrafo.

La referencia visual de la era 2D era `docs/guia_arte.png`; de ella salen
los colores medidos de §1 y §2, que se conservan.

---

## 1. El color de cada elemento

Dos colores por elemento, y la diferencia importa:

- **cuerpo** — lo que identifica al elemento. Va en `RuneData.color`, y de
  ahí salen el tinte del hechizo y el glifo del grimorio.
- **núcleo** — lo que ilumina. Siempre tira a blanco. Va en `Glow`.

Una antorcha con el color del cuerpo pinta la piedra de naranja y se ve a
tinte; con el del núcleo la pinta de cálido, que es lo que hace el fuego.

| elemento | tono | cuerpo (`RuneData.color`) | hex |
|---|---|---|---|
| Fuego | 14° | `Color(0.95, 0.33, 0.12)` | `#F2551E` |
| Agua | 207° | `Color(0.16, 0.62, 0.98)` | `#2A9DFB` |
| Hielo | 194° | `Color(0.37, 0.81, 0.96)` | `#5ECFF5` |
| Tierra | 24° | `Color(0.78, 0.53, 0.35)` | `#C8875A` |
| Viento | 95° | `Color(0.56, 0.83, 0.42)` | `#8FD46A` |
| Rayo | 44° | `Color(0.95, 0.78, 0.24)` | `#F2C63C` |
| Tiempo | 265° | `Color(0.72, 0.58, 0.98)` | `#B894FA` |

**El viento pasó de casi blanco a verde**, y es el único cambio de fondo.
La guía lo llama "Vital (verde)" y tiene razón por un motivo práctico:
sobre el ambiente oscuro, un blanco grisáceo desaparece y además se
confundía con el hielo y con el agua, que son sus dos vecinos de tono.

Luces de la era 2D (`glow.gd`, ya no está en el repo; los colores siguen
sirviendo de referencia): `LUZ_FUEGO` `Color(1.00, 0.78, 0.42)` ·
`LUZ_RAYO` `Color(0.98, 0.92, 0.55)` · `LUZ_MAGIA` `Color(0.78, 0.70, 1.00)`.

---

## 2. Las paletas de los biomas

Medidas sobre las tiras de color de la guía, en su orden.

| bioma | paleta |
|---|---|
| Bosque | `#57783F` `#84973C` `#C19053` `#60543E` `#272733` |
| Ciudad | `#4E739E` `#DEB690` `#9F7D7A` `#5C5774` `#2E2E4D` |
| Cueva | `#465E86` `#6583B5` `#5F78AB` `#232A44` |
| Pantano | `#346A60` `#8CAF80` `#887F69` `#55434F` `#2B253C` |
| Cueva volcánica | `#141F2B` `#F9851E` `#90403D` `#55202B` |
| Desierto | `#D29850` `#DBA256` `#D59958` `#AC7748` `#7A5537` |

En la era 2D el ambiente de cada uno estaba en `Glow.AMBIENTE`; en 3D la
luz por zona la pone `presentacion/luz_zona_3d.gd` (`ZONAS`) y el Bosque
usa la paleta cerrada de §10. La idea sigue: el ambiente no es decoración:
**decide qué elemento importa**. En la cueva volcánica casi no se ve, así
que el fuego deja de ser un arma y pasa a ser la vista; en el desierto
apenas oscurece, así que allí el fuego no da nada que no tuvieras.

---

## 3–8. Historia: era 2D (hasta el 4/10)

> Estas secciones describían el arte de sprites, y **nada de lo que contaban está ya en el juego**. Se resumen aquí; el texto completo sigue en el historial de git.

Hasta el 4/10/2026 el juego era **isométrico 2.5D en sprites**, de «fantasía pintada», con piezas del pack Sketch Town como parche mientras se buscaba la dirección y `docs/guia_arte.png` como referencia. **§3** fijaba el contrato de una hoja de personaje para `actor_animator.gd`: celdas de 64×64, 8 filas = 8 direcciones (E, SE, S, SO, O, NO, N, NE, con la vertical desaplastada ×2,109), columnas por clip (`walk` por distancia recorrida, el resto por reloj) y pies en y = 52. **§4** era la protagonista de entonces: la elfa de dos trenzas y capa azul de `docs/referencia_personaje.png` (se descartó el pelo suelto porque pedía animación propia), dibujada en 5 vistas y espejada a 8, con la lección de pasar siempre la imagen de referencia a la generación; solo llegó a tener `idle`. **§5** ordenaba el trabajo pendiente de esos 500 dibujos (vistas limpias, `idle`, `walk`, `cast`). **§6** era el contrato de losa: rombo de 128×64 con la cara de arriba en y = 33 (antes, 256×352 de Sketch Town), encogido en el juego a 116×55 por `IsoGrid`, con luz plana y sin detalles que delataran la repetición. **§7** proponía carpetas por categoría (`characters/protagonista/rita_maga/`, `environments/<bioma>/`, `vfx/<elemento>/`, `ui/`) a medida que llegara arte. **§8** separaba los VFX en proyectil, área e impacto por elemento, sobre hojas de sprites en `RuneData`. Todo eso se abandonó con el paso a 3D: el acabado de los personajes no se acercaba al terreno, se notaba el tono plastificado del render y las animaciones en sprites eran inviables de mantener (`docs/DECISIONES_CHATS.md` §2). Lo que sustituye a cada parte: personajes y animación en `ARQUITECTURA.md` (*Animación*), suelo y piezas en *Vista 3D* y *Arte* de ese mismo documento y §9–§23 de este; el canon de personaje es la elfa chibi (`docs/RETIRADA_ARTE_ANTERIOR.md`).

---

## 9. Las piezas de puzle (`PiezaPuzle3D`)

*(16/10, Pipeline; Fase 13.5/13.7.)* El modelo, los estados, los efectos y el sonido de cada pieza de `objetos/` del Juego, **sin tocar su
lógica**. El Juego instancia una por pieza, la cuelga de su nodo y le dice en qué estado está:

```gdscript
var v: PiezaPuzle3D = PiezaPuzle3D.crear("pulsador", {"tinte": "agua"})
add_child(v)                    # origen = centro de la base; sin suelo; la colisión es la del Juego (`v.caja()` da el tamaño aproximado)
v.poner_estado("hundido")       # anima, suena y lanza el efecto; `poner_estado("hundido", false)` salta directo (sin animar ni sonar)
```

`poner_estado` devuelve `false` con un id que la familia no conoce (se ignora). Señal `estado_cambiado(id)`. Con `sonido = false` no suenan ni salen
efectos (las pruebas sin ventana). Hoy se dibujan con primitivas facetadas en el estilo del Bosque; **cuando haya GLB de Meshy** (`arte/meshy/piezas/`,
su `.tscn` en `arte/piezas/`) `crear` los cargará y la API **no cambia**: mismos ids de estado, mismos nodos nombrados.

| familia (`crear`) | medida (ancho × alto × fondo, u) | estados (`poner_estado`) | opciones de `crear` / otras llamadas | efecto · sonido al cambiar |
|---|---|---|---|---|
| `pulsador` | 0,9 × 0,9 × 0,9 | `arriba` · `hundido` | `{"tinte": "magia"\|"agua"\|"presencia"}` (rojo · azul · ocre); `poner_tinte(modo)` | `boton_clic` al hundirse; el aro y el botón brillan |
| `placa` | 1,8 × 0,1 × 1,8 | `arriba` · `hundida` (la runa se enciende sola) | `poner_runa(bool)` fuerza la runa | `placa_hunde` |
| `compuerta` | 2,2 × 1,5 × 0,42 | `cerrada` · `abierta` (la hoja baja 0,9 u en 0,6 s) | `{"material": "madera"\|"hierro"}`; `orientar(vertical)` | `compuerta_baja` + polvo |
| `compuerta_hielo` | 2,2 × 1,5 × 0,42 | `entera` · `derritiendose` (3,2 s) · `nada` | `orientar(vertical)` | `hielo_quiebra` + vapor |
| `roca` | Ø2,2 × 1,3 | `entera` · `rota` (4 cascotes que caen y quedan) | nodos `cascote_0..3` | `derrumbe` + polvo |
| `barril` | Ø0,9 × 0,95 | `entero` · `mecha` (arde `T_MECHA` = 1,2 s: la mecha se acorta, parpadea y echa chispas) · `explosion` (el barril desaparece) | `{"mecha": s, "radio": u}` | `mecha` · `explosion` + fogonazo, luz, brasas, humo y polvo |
| `molino` | 2,0 × 1,65 × 1,5 (rueda Ø1,5, ancho 0,6) | `quieto` (un solo estado) | **`v.rueda`** (nodo «rueda»: la gira el Juego con `rueda.rotate_x(w * dt)`); «eje» y los dos postes quedan quietos; `orientar(vertical)` | `rueda_chirria` (la llama el Juego mientras gira) |
| `pila` | Ø1,1 × 0,5 | `seca` · `mojada` (disco de agua) · `electrificada` (bornes brillan, chispas) | — | `agua` + salpicadura · `zumbido_electrico` + chispas; al secarse, vapor |
| `poste_nivel` | 0,3 × 2,0 × 0,3 (vara 0,1) | `apagado` · `encendido` (farolillo + luz) | `{"marca": altura}`; `poner_marca(altura)` | `prender` |
| `reja` | 2,2 × 2,4 × 0,42 | `cerrada` · `abriendose` (1,4 s; al acabar pasa sola a `abierta`) · `abierta` | `orientar(vertical)` | `compuerta_baja` + polvo |
| `tapon_hielo` | 0,9 × 0,4 × 0,9 | `entero` · `derritiendose` · `nada` | — | `hielo_quiebra` + vapor |
| **tinaja** (el modelo `tinaja_ruina`, ya colocado) | el del modelo | `llena` · `vacia` | `PiezaPuzle3D.poner_estado_tinaja(pieza, "vacia")` (estática; vale con cualquier nodo con mallas dentro) | `vacia`: velo pardo (seca y polvorienta) + vapor + `creak` |

- **La compuerta y la reja llevan el ancho en X.** Para una losa que cruza la casilla de norte a sur (`vertical = true` en `Compuerta3D`), `v.orientar(true)`.
- **Tinaja «vacía»:** mientras no haya un modelo propio de tinaja vacía es un velo sobre las mallas del modelo del Bosque. Cuando lo haya,
  `Pieza3D.cambiar_visual(pieza, "tinaja_ruina_vacia")` lo sustituye y `poner_estado_tinaja` deja de hacer falta. El Juego la llama al ver `AguaSim3D.fuentes_agotadas()`.
- **Estados y `Pieza3D.cambiar_visual`:** estas piezas cambian de estado por dentro (movimiento + efecto + sonido a la vez); no hace falta
  cambiar de modelo. `cambiar_visual` sigue siendo para lo que SÍ es otro modelo (seta azul → quemada, tronco con resina → sin resina).

### 9.1 Efectos (`VfxPuzle3D`, `presentacion/vfx_puzle_3d.gd`)

Funciones estáticas, sin estado; cuelgan sus nodos de `padre` y se limpian solas. Las usa `PiezaPuzle3D`, pero el Juego puede llamarlas sueltas
(`VfxPuzle3D.polvo(self, punto)`). Van en código y no en `.tres` porque un GPUParticles3D no cabe en un único `.tres` (necesita su malla de dibujo y su
material) y con una llamada el Juego no tiene que instanciar nada.

| función | qué es | notas |
|---|---|---|
| `salpicadura(padre, pos, esc)` | gotas que saltan y un anillo | al mojar la pila |
| `chispas(padre, pos, continuo, esc)` | chispas eléctricas | `continuo` devuelve el emisor (`emitting = false` lo apaga) |
| `vapor(padre, pos, esc, continuo)` | bocanadas blancas que suben | al secarse, al derretirse |
| `fogonazo(padre, pos, radio)` | bola de luz, luz que ilumina, brasas, humo, polvo | el barril |
| `polvo(padre, pos, radio)` | nube parda a ras de suelo, piedrecitas y un aro | el derrumbe |
| `burbujas(padre, pos, radio, continuo)` | burbujas que suben | bajo el chorro |
| `caida_chorro(padre, pos, esc, continuo)` · `anillo_caida(padre, pos, radio)` | niebla que rebota y anillo de agua | donde cae el chorro al agua |

### 9.2 Sonidos nuevos (`nucleo/sfx.gd`, `audio/`)

`boton_clic`, `placa_hunde`, `compuerta_baja`, `hielo_quiebra`, `mecha`, `explosion`, `rueda_chirria`, `zumbido_electrico`, `llenado`: sintetizados
con `audio/gen_sfx_puzles.py` (igualados en RMS; el volumen real lo dice el `CATALOGO`). Se llaman como siempre: `Sfx.play(nodo, "explosion")`.
**`Sfx.llenado(nodo, nivel)`** (nivel 0..1) toca `llenado` con el tono subiendo de 0,7 a 1,6 según el nivel: llamarlo cada ~0,8 s mientras sube el agua.
`Sfx.play` gana un tercer parámetro opcional `tono` (0 = el aleatorio de siempre); quien lo llama sin él no cambia.

Sin ventana o con un `.wav` sin importar (Godot los importa al abrir el editor una vez), `Sfx.play` no suena y no falla.

## 10. La paleta cerrada y la presentación del escenario (Fase 14.2, Pipeline)

Contraparte en código: `presentacion/paleta_3d.gd` (`Paleta3D`). Si cambia una, cambia la otra (la prueba `herramientas/prueba_presentacion.gd` comprueba que cada color de
`Paleta3D` está escrito aquí).

**Por qué una paleta cerrada.** Lo que da aspecto de diorama no es el detalle sino que todo viva en pocos verdes, dos marrones y un azul bajo la misma luz.
Cada color sale de MEDIR lo que el juego ya dibuja, no de elegirlo a ojo.

| Familia | Nombre en `Paleta3D` | Hex | De dónde sale |
|---|---|---|---|
| Hierba ×3 | `HIERBA_SOMBRA` / `HIERBA` / `HIERBA_LUZ` | `8BC77E` / `9FD180` / `B2D983` | k-means (3 grupos) de `hierba_arriba` |
| Tierra ×2 | `TIERRA` / `TIERRA_FLANCO` | `835832` / `DB8F59` | `tierra_arriba` y `cuerpo` (flanco de los bloques) |
| Piedra ×2 | `PIEDRA` / `PIEDRA_OSCURA` | `B8ADB8` / `7D747C` | `losas_piedra` |
| Agua ×2 | `AGUA_SOMERA` / `AGUA_HONDA` | `70CCE8` / `3385CC` | colores estilizados de `AguaRender3D` |
| Madera | `MADERA` | `8C5C33` | piezas de puzle contrastadas con el atlas de `cofre.glb` |
| Metal | `METAL` | `5C616E` | ídem (hierro `383942` en el cofre; el del puzle es el punto medio legible) |
| Fuera de la lista | `CAMINO_ARENA` | `FDD495` | `path_arriba`: lo pinta el shader del suelo (del Juego); no se usa en piezas |

**Ajuste de color único.** Un solo `adjustment` por `WorldEnvironment`, siempre vía `Paleta3D.aplicar_ajuste(env)`: brillo 1,0 · contraste 1,0 · saturación 1,1.
Medido en el Bosque: saturación 1,1 sube la del suelo de 0,34 a 0,36 y la de la tierra de 0,60 a 0,64. Contraste 1,05 empeoraba el tono del suelo (84° → 80°) y brillo
0,94 no lo arregla, porque el recorte ocurre antes del ajuste (ver «Hallazgo»).

**Piezas de Meshy teñidas** (`Paleta3D.PIEZAS`; el tinte MULTIPLICA el albedo, se conserva el dibujo pintado; acotado a 0,6–1,35 por canal):
`helecho` y `canas` → `HIERBA` 0,6 · `flores_blancas` y `hierba_alta` → `HIERBA` 0,5 · `hojas_caidas` → `TIERRA_FLANCO` 0,5. NO se tiñen la tinaja ni los canales: ya son
la «piedra oscura» y teñirlos hacia la clara los fundía con las losas. Los colores medios salen de `herramientas/medir_color_piezas.gd`.

**Hallazgo (sin aplicar, decisión de Pablo).** En el Bosque, en Compatibilidad, el suelo sale sobreexpuesto: el canal verde se recorta a 1,0 y el tono es 84° frente a 97° de la
textura. Bajar `OSCURECER_SUELO` de 0,78 a ~0,64–0,70 lo devuelve a su tono. No se ha tocado.

**Geometría blanda.** `presentacion/borde_piedras_3d.gd`: falda de 0,3 u con normales suavizadas en cada salto de altura y orilla de agua, más un anillo de cantos de 0,3–0,6 u
(MultiMesh, jitter por hash, sin parpadeo al reconstruir). Solo dibujo; no colisiona. **Lecho del río:** `prof_rio` 0,9 → 1,4 para ver el fondo; `prof_color` (0,9) mantiene la rampa
de color, así el agua sigue azul. **Sombra de contacto:** `presentacion/sombra_contacto_3d.gd`, material único para el decorado y las piezas de puzle.

**Profundidad de campo (diorama).** Solo desenfoque lejano, atado a la distancia al jugador; `diorama`, `diorama_fuerza` y `diorama_nitidez` en la maqueta, F7 lo conmuta.
Existe solo en Forward+/Mobile: en Compatibilidad se apaga solo y NO se ha podido ver el efecto; hay que mirarlo en el juego real.

## 11. Escritura de runas, bolsa y diario (Fase 14.3 / 14.4, Pipeline)

Todo el arte 2D sale de scripts de Python (Pillow) que viven junto a los PNG, en `presentacion/ui/laminas/`: `mano.py`, `iconos.py`, `bolsa.py`, `diario.py` (+ `lib.py`).
`python <script>.py <carpeta>` regenera sus PNG. El estilo es el de `objeto_pocion.png` de Pablo: plano, contorno marrón `#6B3A2A`, brillo blanco. Si Pablo pinta uno a mano, basta con sustituir el PNG.

| Pieza | Archivos | Medida | Notas |
|---|---|---|---|
| Mano con pluma | `mano_reposo/escribiendo/levantada.png`, `mano_pluma.png`, `sombra_*.png` | 560 × 560 | La PUNTA de la pluma está en el mismo píxel (92, 330) de las 7 capas (`ManoPluma2D.PUNTA_PX`). Orden: sombra → pluma → mano. La manga se desvanece en los bordes derecho e inferior |
| Iconos de objeto | `objeto_<id>.png` (22) | 128 × 128 | Un icono por cada id de `Objetos.DATOS` menos `oro` y `pocion` (los de Pablo). `BolsaUI.tex("objeto_" + id)` ya los busca ahí, sin tocar nada |
| Bolsa | `bolsa_silueta_g.png` (640 × 720) y `_p.png` (320 × 360), `bolsa_interior_*.png` (máscara), `bolsa_anclas.json` | — | Las anclas (16 por tamaño, filas de 2-3-4-4-3 huecos que se estrechan hacia el cuello) están en fracciones 0–1 de la silueta y todas caen dentro del interior |
| Banda del nombre | `bolsa_banda_nombre.png` | 480 × 72 | Los extremos (34 px) no se estiran: 3 trozos |
| Diario | `diario_pergamino.png` (900 × 1000), `diario_icono_principal/secundaria.png` (64), `diario_seguida.png` (32), `diario_casilla(_hecha).png` (28) | — | Escudo dorado = principal; pergamino plateado = secundaria |

**La fuente del libro.** El libro NO usa ninguna fuente propia: `spellbook.gd` pinta con `ThemeDB.fallback_font`, la de serie de Godot. No hay ninguna fuente en el repo y el sandbox no puede descargar ninguna, así que no he podido elegir una. Lo que hace falta es un `.ttf` con licencia libre (OFL) en `presentacion/ui/` que el Juego asigne al libro, a la bolsa y al diario; hasta entonces todo sigue con la de serie.

**Mano y tinta (código).** `presentacion/ui/mano_pluma_2d.gd` (`ManoPluma2D`) y `presentacion/ui/tinta_pluma_2d.gd` (`TintaPluma2D`). La mano va 60 ms por detrás del punto que recibe (buffer con interpolación, no contador de fotogramas), inclina la pluma hasta ±12° según la velocidad y la mano gira un 55 % de eso. La tinta ensancha el trazo cuando va despacio (7 px) y lo afina deprisa (2,4 px), con borrón al empezar y de 2 a 6 gotas al soltar.

**Rastrojo.** `presentacion/rastrojo_3d.gd` (`Rastrojo3D`): tres matas de tallos de 4–14 cm y una mancha por casilla, en dos MultiMesh. Cortado = tallos pajizos y mancha verde pardo suave; quemado = tallos de carbón y mancha oscura.

## 12. Las piezas de puzle con modelos de Meshy (láminas «puzle», 16/10, Pipeline)

Pablo generó tres láminas de Meshy (cada una es UNA malla con tres texturas de 2048², con todas las piezas sueltas dentro): **Fantasy Dungeon Props**, **Forgotten Fantasy Pro** y **Fantasy Terrain Asset**. Se han separado en piezas, orientado, escalado y colgado de `PiezaPuzle3D` (§9), que ahora las usa si existen y cae a las primitivas si no.

**Dónde.** `arte/meshy/puzle/puzle_dungeon.glb`, `puzle_forgotten.glb` y `puzle_terrain.glb` (≈ 8,5 MB cada uno; Godot extrae sus tres JPEG al importar, como en las otras bibliotecas). Un nodo por pieza, con el id como nombre. Cada pieza sale **orientada** (sobre Y), **a escala de `CAJA`** y con el **origen en el centro de la base**; las piezas de una familia vienen **ensambladas** en el origen (el botón dentro de la base, la hoja dentro del marco…), así que colgarlas todas en (0,0,0) da la pieza completa.

| Familia | Piezas (archivo) | Nodos con nombre | Medida con modelo (u) |
|---|---|---|---|
| pulsador | `pulsador_base`, `pulsador_boton` (dungeon) | `base`, `boton` (arriba = 0, hundido = −0,15), `aro` (anillo de luz, solo hundido) | Ø0,90 × 0,48 (el botón sobresale 0,10) |
| placa | `placa_marco`, `placa_tapa` (dungeon) | `marco`, `tapa` (0 / −0,04), `runa` (luz sobre la runa tallada) | 1,8 × 0,13 × 1,8 |
| compuerta | `compuerta_marco`, `compuerta_hoja_madera` / `_hierro` (dungeon) | `marco`, `hoja` (0 / −0,9) | 2,2 × 1,5 × 0,5 |
| compuerta_hielo | `compuerta_marco` + `compuerta_hoja_hielo` (terrain) | `marco`, `hoja` | 2,2 × 1,5 × 0,5 |
| roca | `roca_entera`, `roca_cascote_0..3` (terrain) | `entera`, `cascote_0..3` (escondidos hasta `rota`; caen a y = 0) | 2,1 × 1,3 × 1,6 |
| barril | `barril` (terrain) | `cuerpo`, `mecha` (en el centro de la tapa), `luz` | Ø0,95 × 0,95 |
| molino | `molino_rueda`, `molino_soporte` (×2, el segundo girado 180°), `molino_eje` (terrain) | `rueda` (centro = el eje, gira sobre X; el Juego la gira igual que antes), `eje` | rueda Ø1,08, eje a 0,54 |
| pila | `pila_piedra`, `pila_borne` (terrain; `pila_borne_piedra` es la variante de piedra, sin usar) | `pie`, `borne` ×2 (a ±0,72), `agua` | cuenco Ø1,1 × 0,38 |
| poste_nivel | `poste_vara`, `poste_farolillo` (forgotten) | `vara`, `marca`, `farol`, `luz` | 0,36 × 2,25 |
| reja | `reja_marco`, `reja_hoja` (forgotten) | `marco`, `hoja` (0 / −2,2) | 2,2 × 2,4 × 0,5 |
| tapon_hielo | `tapon_hielo` (forgotten) | `hoja` | Ø0,9 × 0,5 |
| tinaja | `tinaja_ruina_vacia` (forgotten) | — (no la monta `PiezaPuzle3D`: es una malla suelta) | 1,75 × 1,5 (misma altura que `tinaja_ruina`) |

**Cómo se separaron** (por si hay que repetirlo con otra lámina). (1) Se sueldan los vértices por posición y se sacan los componentes conexos de la malla: una pieza de Meshy son entre 1 y 150 componentes. (2) Se juntan los componentes cuyos vértices se tocan a menos de ~1 cm (la caja envolvente NO sirve: la rueda del molino envuelve a todo lo demás). (3) Cada grupo se identifica por su número de triángulos y su sitio en la lámina, y se mira en una captura. (4) La orientación: las piezas del Fantasy Dungeon (pulsador y placa) vienen **inclinadas unos 30°** y se enderezan con la normal dominante (la de más área) llevada a +Y; el resto ya viene recto, salvo la rueda del molino, que viene con el eje en Z y se gira 90° (el Juego la gira sobre X). (5) Escala y origen: las piezas que se montan juntas comparten el factor de escala; **compuertas y rejas se ensanchan** hasta 2,2 de ancho (el marco del modelo es más estrecho que la casilla) y su fondo se queda en 0,5 (la caja pedía 0,42; el modelo trae unos pies más gruesos).

**Lo que no es como lo pedía `PROMPTS_PIEZAS_PUZLE.md`.** (a) La lámina de terreno trae un segundo borne, de piedra (`pila_borne_piedra`): se guarda en la biblioteca pero no se usa; (b) el **soporte del molino** salió fundido con su eje (una sola pieza): se cortó por un plano a la altura del poste y salen dos mallas, `molino_soporte` (poste, con las piedrecitas del suelo) y `molino_eje`; el segundo poste es el mismo, girado; (c) el poste del molino es bajo, así que el eje queda a 0,54 y la rueda mide Ø1,08 (la de primitivas era Ø1,5 con el eje a 0,82); (d) el hielo trae su textura de cristales: el motor solo le pone la translucidez y un poco de luz propia; (e) `pulsador` y `placa` salen en **blanco** (la textura es casi blanca) para que el tinte (`poner_tinte`) los coloree: el color del botón es el de `TINTE`, y la base y el marco se quedan de piedra.

**Fallbacks y pruebas.** `PiezaPuzle3D.usar_modelos = false` (global) o `crear(familia, {"modelos": false})` (una pieza) vuelven a las primitivas, con los mismos nodos y estados. `herramientas/prueba_piezas_puzle_modelos.gd` (0 fallos): comprueba los 3 GLB y las 26 piezas, que cada familia se apoya en el suelo y cabe en su caja, cada nodo con nombre, todos los estados con modelo y sin él. `herramientas/captura_piezas_puzle.gd` saca una captura de las 13 piezas en tres filas (inicial · activa · primitivas).

## 13. Conjuro y piezas del laboratorio de fuego (T6, 16/10)

- **VFX del conjuro** (`presentacion/conjuro_vfx_3d.gd`): voluta del libro a la mano y forma en la mano, un aspecto por elemento, dibujado en los tiempos que da `Lanzador3D` (señal `conjuro_fase`). Colores = los de `docs/ARTE.md` §1 (`*_rune.tres`). Núcleo translúcido con corazón claro, halo blando y cola de motas; la forma lleva una luz.
- **Piezas de fuego** (`presentacion/pieza_fuego_3d.gd`, 17 ids): primitivas de la paleta cerrada (madera, piedra, hierro gris neutro, soga, latón) mientras no existan los GLB; con `arte/meshy/fuego/<id>.glb` usa el modelo. Reglas de arte: **nada de llama, brasa ni brillo pintado** (los pone el motor), el hierro de la caldera es gris neutro para poder ponerlo rojo con emisión, y lo que se quema tiene dos mallas (entera y quemada) con el mismo tamaño y origen. Prompts: `arte/meshy/PROMPTS_LAB_FUEGO.md`. API y estados: cabecera del script y diario 108.

## 14. Las láminas de campamento: 17 piezas del laboratorio de fuego con modelo (16/10)

Dos láminas de Meshy (cada una un solo mesh con 3 texturas JPEG de 2048² incrustadas): **Medieval Camp Props** (`1016112734`) y **Rustic Camp Toolkit** (`1016112225`).
Separadas con el método de la §12 (componentes conectados soldando por posición + fusión por proximidad de vértices, eps 0,012) en 12 grupos cada una; 17 son las piezas del
laboratorio de fuego y 7 sobran (ver abajo). Salen en `arte/meshy/fuego/fuego_medieval.glb` y `fuego_rustic.glb`, un nodo por pieza con su id (`PiezaFuego3D.malla_modelo(id)`).

| Lámina | Piezas (id · tris) |
|---|---|
| `fuego_medieval` | `caldera_hogar` 4243 · `caldera_cuerpo` 3208 · `goblin_escudo_quemado` 1636 · `goblin_escudo_entero` 1514 · `antorcha_pared` 1315 · `antorcha_pie` 1258 · `caldera_medidor` 391 · `baldosa_falsa` 370 · `caldera_indice` 204 |
| `fuego_rustic` | `fogata_apagada` 4952 · `cuerda_poste` 2274 · `contador_placa` 2125 · `cuerda_caida` 1757 · `fogata_lenos` 1635 · `cuerda_tensa` 956 · `cuerda_cabo` 839 · `leno` 695 |

- **Orientación:** las piezas planas (hogar, hoguera, caldera, placa, antorcha de pie, índice) se nivelan por su cara dominante; la baldosa, además, se gira a ejes; **los escudos** llevan su disco a +Z con el
  ombligo mirando a +Z (el quemado y el entero con el **mismo factor de escala**, para que el cambio no salte); la antorcha de pared apunta a +Z. Escala por el lado que dice `PiezaFuego3D.MEDIDA`.
- **Origen:** centro de la base; `cuerda_tensa` y `cuerda_cabo` cuelgan de su nudo (hacia −Y); `goblin_escudo_*` en el centro del disco.
- **Medidas que salen (modelo):** `cuerda_poste` 1,41 × 1,9 × 1,0 (el modelo es achaparrado: la anilla queda lejos del poste, **más que la cuerda del Juego, x = 0,28**), `caldera_cuerpo` 1,2 × 0,68 × 1,06, `caldera_hogar` 1,8 × 0,38 × 1,94, `contador_placa` 1,6 × 0,51 × 0,42, `baldosa_falsa` 2,0 × 0,25 × 2,08, `goblin_escudo_*` Ø 0,55 con ombligo de 0,37–0,39 de fondo.
- **Sobran (no están en el catálogo):** en la lámina medieval un tocón de antorcha vertical con aros de hierro, una piedra y un bloque de piedra; en la rústica, cuatro piedras sueltas. Siguen en los GLB originales por si se quieren.
- **Estados con modelo:** la emisión sigue la textura (`emission_texture` = albedo) y se sube menos que con primitivas, o el hierro y la madera se lavan a rosa. Las gemas del contador, la punta de las antorchas y la ranura del medidor están a mano sobre el modelo (`PUNTA_MODELO`, `HUECOS_MODELO`, `RANURA_MODELO`).
- **Peso:** ≈ 18 MB entre los dos GLB (6 JPEG de 2048² al importarse). Si pesa mucho, se bajan a 1024² sin tocar nada más.

## 15. La lámina «Verdant Timber Ruins»: tronco-puente, bloqueo de enredaderas y restos quemados (16/10)

Una lámina de Meshy (un solo mesh, 15 488 tris, 3 JPEG de 2048²) separada con el mismo método que las de campamento (componentes soldados + fusión por cercanía, 34 grupos) y reexportada como **`res://arte/meshy/bosque/bosque_ruinas.glb`**: un nodo por pieza, ya orientada, a escala y con el origen puesto. Cargador: `presentacion/pieza_bosque_3d.gd` (`PiezaBosque3D.malla_modelo(id)` / `crear(id)`; null si falta la lámina). Prueba: `herramientas/prueba_piezas_bosque.gd` (0 fallos).

| id | tris | medida X × Y × Z | origen |
|---|---|---|---|
| `tronco_puente_pie` | 4316 | 1,43 × 2,6 × 1,58 | centro de la base |
| `tronco_puente_caido` | 636 | 2,6 × 0,56 × 0,5 | el pie del tronco, tumbado hacia +X |
| `bloqueo_enredaderas` | 3784 | 2,2 × 1,08 × 1,09 | centro de la base |
| `bloqueo_enredaderas_quemado` | 2623 | 1,83 × 0,66 × 1,02 | centro de la base |
| `enredadera_quemada_a` / `_b` | 798 / 534 | 0,6 × 0,22 × 0,62 / 0,5 × 0,3 × 0,56 | centro de la base |
| `ceniza_enredadera` | 128 | 0,9 × 0,1 × 1,03 | centro de la base |

- **Por qué así:** el bloqueo vivo y el quemado venían fundidos en un solo grupo; se separaron por el centro de cada componente (por triángulos salía un quemado de 2,63 de ancho por restos sueltos). El quemado usa el **mismo factor de escala** que el vivo, así que el cambio no salta; es una mata hundida, por eso es más bajo y estrecho. El tronco caído yace en diagonal en la lámina: se giró por PCA para tumbarlo sobre +X (si no medía 1,18 de fondo).
- **Ojo:** el tronco en pie es achaparrado (1,43 de ancho a 2,6 de alto) y lleva piedras y vainas pegadas en la base, así que su huella real es ≈ 1,4 × 1,6, mayor que el cilindro provisional. El bloqueo mide 2,2 × 1,08 (más ancho y bajo que lo pedido en los prompts).
- **Sobran:** restos quemados flotantes, vainas y piedras sueltas y unos veinte fragmentos mínimos; siguen en el GLB original.
- **No verificado:** aspecto en Forward+ (solo Compatibility/llvmpipe); falta importar en Godot una vez. Del prompt siguen pendientes de generar: tronco_estanque, manos, pluma y libro.

## 16. Las páginas del grimorio nuevo (lámina `grimorio_bosque.png`, 16/10)

Lámina del libro abierto con el estilo del grimorio de cuero marrón y verde (cenefa de hojas y capullos): `art/ui/grimorio_bosque.png`, 1470 × 1070. La generó Pablo con un generador de imágenes a partir de dos prompts (base en blanco + trazos simples) y se ajustó aquí. **No sustituye a `grimorio_nivel1.png`** (que no existe) ni a `grimorio.png`: está aparte a propósito, porque su distribución es distinta y activarla con los datos de `nivel1` rompería el libro.

- **Por qué se rellenó arriba y abajo:** la imagen generada medía 1266 × 865 (1,46:1) y `spellbook.gd` dibuja la lámina estirada a `BOOK_SIZE` 1470 × 1070 (1,37:1): estirarla habría vuelto ovalados los círculos. Se escaló uniforme a 1470 de ancho (×1,1611, alto 1004) y se repitió el borde oscuro 33 px arriba y abajo. Eso queda fuera del bloque de páginas, que es lo que se encuadra.
- **Medidas** (px de lámina, medidas sobre la imagen con componentes conexos, no a ojo):

| Pieza | Centro | Radio |
|---|---|---|
| Círculo exterior | (431,9; 482,4) | 232,8 |
| Sello (núcleo), **desplazado hacia arriba** | (433,7; 383,1) | 119,6 |
| Hueco de glifo abajo-izquierda (sector 3) — **no impreso** | (305,4; 578,7) | 58,1 |
| Hueco de glifo abajo (sector 2) — **no impreso** | (431,4; 628,1) | 59,8 |
| Hueco de glifo abajo-derecha (sector 1) — **no impreso** | (557,3; 578,7) | 58,1 |
| 6 círculos de sello (derecha), y = 276,8 | x = 838,3 · 913,8 · 989,9 · 1065,9 · 1141,4 · 1216,9 | 30,2 |
| 3 × 3 óvalos de glifo (derecha) | x = 871,4 · 1028,8 · 1184,9; y = 415,6 · 551,4 · 683,8 | 140,5 × 101,0 de caja |

- **Pendiente de Juego** (`spellbook.gd` es suyo): el núcleo ya no está en el centro del círculo exterior (≈ 99 px más arriba), y hoy `LIBROS` solo tiene `centro` y `nucleo` (radio). Hace falta un dato de desplazamiento del núcleo; además los sectores de los huecos salen a ≈ 37°, 90° y 143° (no 45/90/135), así que se usan las posiciones exactas de `huecos`. La página derecha pasa de 12 casillas a **6 sellos + 9 glifos**. El bloque de páginas (`PAGE_BLOCK`) hay que revisarlo: por ojo la cenefa va de y ≈ 90 a ≈ 840 y el actual es 84–834.
- **Siguiente paso de Pipeline:** variantes por progresión, con los huecos aún no comprados cerrados (capullo, de la hoja de piezas de Pablo) y los óvalos/círculos sin desbloquear en tenue.

**Los huecos de glifo no vienen impresos (Pablo, 16/10).** Están ligados a las **mejoras** del jugador: al principio el sello es lo único que se ve y se puede escribir en la página, y cada hueco aparece al desbloquearlo. Por eso `grimorio_bosque.png` lleva solo el círculo exterior y el sello; los tres aros se quitaron de la lámina (relleno del pergamino por inpainting, comprobado a la vista) y quedan como sprite aparte, **`art/ui/grimorio_hueco_glifo.png`** (140 × 140, aro de tinta con alfa, centro (70; 70), radio 58,1): se pinta en cada hueco desbloqueado, escalado por `hueco_radio / 58,1`. Un hueco bloqueado ni se ve ni admite trazo (ver diario 112).

## 17. Pluma y mano de escritura con modelo (láminas «Verdant Quill» y «Pointing Hand Emerging», 16/10)

Dos GLB de Meshy, separados y reexportados con un nodo por pieza (origen y escala horneados): `arte/meshy/escritura/pluma.glb` y `arte/meshy/escritura/mano.glb`. Cargador `presentacion/pieza_escritura_3d.gd` (`PiezaEscritura3D.crear(id)`; null si falta el GLB) y prueba `herramientas/prueba_pieza_escritura.gd` (0 fallos).

| id | tris | medida X × Y × Z | origen |
|---|---|---|---|
| `pluma` | 15 963 | 0,21 × 0,7 × 0,045 | la punta del plumín, de pie (la pluma sube por +Y; cara plana a +Z) |
| `mano_apuntando` | 8 275 | 0,39 × 0,5 × 0,54 | la punta del índice (que apunta hacia abajo, −Y) |
| `manga_mano` | 8 172 | 0,49 × 0,53 × 0,58 | el mismo que la mano: juntas forman el brazo |
| `mano_agarre` | 6 456 | 0,27 × 0,23 × 0,5 | **el centro del pellizco**, entre la yema del pulgar y la del índice |
| `manga_agarre` | 9 565 | 0,29 × 0,29 × 0,26 | el mismo que `mano_agarre` (la muñeca queda hacia −Z) |

- **La mano no sujeta la pluma:** es un puño con el índice estirado ("señalando"), no la pose de agarre de los prompts C1–C3. Sirve tal cual para señalar o para escribir con el dedo; para una mano que sujete la pluma habría que generar otra o colocar la pluma a mano, sin garantía de que quede bien entre los dedos.
- **Peso:** la pluma pesa 15 963 triángulos (el prompt pedía 300–700): es mucho para un objeto de 0,7. Si se usa en pantalla pequeña o muchas a la vez, conviene reducirla (decimar) o seguir con el PNG 2D.
- **Textura:** cada GLB lleva su propio JPEG (≈ 12 MB entre los dos). No verificado en Forward+.

**La mano de agarre (`mano_agarre.glb`, la buena para escribir).** Tercera mano, generada con Image to 3D a partir de la imagen editada por Pablo: pose de escritura con el pellizco abierto y sin pluma. Se separó por componentes (mano 6 456 tris, manga 9 565 tris con el disco de piel de la muñeca) y el origen se puso en el centro del pellizco. Dedos hacia +Z, palma a −Y, dorso a +Y.
- **Pulgar cerrado a mano:** el hueco entre las yemas era de 0,255 (casi un 27 % de la mano) y ninguna pluma fina lo salvaba, así que el pulgar se acercó 0,09 hacia el índice con una deformación suave (peso por z y x; las UV no cambian). Se comprobó con render de lado y de arriba que no se ve estirado.
- **La pluma en la mano:** `PiezaEscritura3D.pluma_en_agarre()` devuelve su `Transform3D` (el plumín asoma 10 cm hacia delante y abajo del pellizco, la pluma se tumba hacia atrás y arriba a 50° sobre el dorso, girada 40° sobre su eje). Salió de probar tres giros con render; se ve sujeta en las dos vistas.
- **Pluma oculta al no escribir:** son piezas separadas, basta con ocultar la pluma.
- **Pesa:** 16 021 triángulos entre mano y manga, más 15 963 de la pluma; se puede decimar después si hace falta (Pablo).

## 18. Las dos láminas de bosque: orilla del estanque y sendero («Forest Flora Collection» y «Enchanted Forest Elements», 16/10)

Salen de los prompts de `arte/meshy/PROMPTS_BOSQUE_LAMINAS.md` (lámina 1 = orilla, lámina 2 = sendero). Separadas con el método de siempre y reexportadas con un nodo por pieza en `arte/meshy/bosque/bosque_orilla.glb` y `bosque_sendero.glb`; las lee `PiezaBosque3D` (ahora con 28 ids; prueba `herramientas/prueba_piezas_bosque.gd`, 0 fallos). Origen: centro de la base, salvo `tronco_estanque` (centro del eje).

**Se quitó la capa plana de hierba/hojas** que Meshy pegó bajo cada pieza (componentes de menos de 0,02 de alto, 20 triángulos o más, a ras de la base del grupo): 1 070 triángulos en los juncos, 1 076 en el tocón, 514 en las setas, 180 en la roca grande, y unas decenas en las piezas del sendero. **No** se quitó en las piezas que son planas de por sí (nenúfares, montón de hojas y hojas del suelo).

| Pieza | tris | medida X × Y × Z |
|---|---|---|
| `tronco_estanque` | 3 842 | 2,6 × 0,65 × 0,79 |
| `juncos_a` / `juncos_b` | 1 793 / 1 575 | 0,8 × 0,55 × 0,82 / 0,8 × 0,44 × 0,58 |
| `tocon_musgo` | 1 272 | 0,9 × 0,45 × 0,67 |
| `setas_grupo` | 886 | 0,5 × 0,3 × 0,31 |
| `roca_musgo_g` / `_m` / `_p` | 332 / 406 / 216 | 1,2 × 0,8 × 0,94 / 0,7 × 0,44 × 0,83 / 0,35 × 0,16 × 0,35 |
| `nenufar_a` (con capullo) / `nenufar_b` | 470 / 336 | 0,56 × 0,26 × 0,7 / 0,46 × 0,1 × 0,5 |
| `arbusto_hojas` / `arbusto_frutos` | 2 755 / 2 104 | 1,2 × 0,68 × 1,16 / 1,4 × 0,86 × 1,31 |
| `raiz_grande` | 1 298 | 1,4 × 0,72 × 1,45 |
| `hojas_monton` | 1 344 | 0,7 × 0,19 × 0,9 |
| `tronco_hueco` | 1 244 | 0,89 × 1,1 × 1,0 |
| `valla_tramo` | 1 175 | 2,0 × 0,93 × 1,55 |
| `troncos_apilados` | 861 | 1,0 × 0,54 × 1,0 |
| `cartel_bosque` (tablilla en blanco) | 826 | 0,93 × 1,6 × 1,15 |
| `hojas_suelo_a` / `_b` / `_c` | 638 / 437 / 430 | ≈ 0,55 × 0,05 × 0,7 |

- **El tronco del estanque salió achaparrado** (largo/grueso ≈ 2,3, y hacía falta 4,3): se alargó **1,6× en X** respecto a Y y Z para llegar a 2,6 de largo, y aun así queda más grueso que el cilindro provisional (0,65 × 0,79 frente a Ø 0,6). Si molesta el grosor, o se acepta, o se pide otro tronco más fino. En `TroncoEstanque3D` cambiaría `RADIO` y `_y_arriba` (su cara de arriba queda ≈ 0,33 sobre el eje).
- **Tamaño del cartel:** salió diminuto en la lámina (178 triángulos en la pieza principal) y se amplió ×7,9 a 1,6 de alto: a esa escala se verá poco detallado.
- **No salieron** del prompt: el helecho grande (lámina 1) y las 3 piedras de pasadero salieron como pedazos de 24–62 triángulos (descartados). El «seto seco» se convirtió en `arbusto_frutos` (hojas verdes y frutos marrones, no seco), y el arbusto con flores salió sin flores (`arbusto_hojas`).
- **Peso:** ≈ 8–9 MB por GLB (un JPEG de 2048² cada uno). No verificado en Forward+.

## 19. La mano 3D que escribe en el libro (`ManoPluma3D`, 16/10, Pipeline)

Sustituye a `ManoPluma2D` con el modelo de agarre (§17). Archivo: `presentacion/ui/mano_pluma_3d.gd`; prueba: `herramientas/prueba_mano_pluma_3d.gd` (necesita renderizador, no vale `--headless`); captura para mirar: `herramientas/captura_mano_pluma_3d.gd`.

- **Interfaz: la misma.** `ManoPluma3D` **hereda** de `ManoPluma2D`, así que `apuntar()`, `punta()`, `mostrar()`, `ocultar()`, `pose`, el retardo de 60 ms y la inclinación son literalmente el mismo código (la prueba B1 compara las dos: diferencia 0,00000 px). Una variable tipada `ManoPluma2D` admite una `ManoPluma3D`. `TintaPluma2D` no cambia. `ManoPluma3D.disponible()` dice si están los GLB; sin ellos no pinta nada pero `punta()` sigue valiendo.
- **Cómo se ve un 3D sobre una UI 2D.** Un `SubViewport` transparente (mundo 3D propio, MSAA 4×, 560 × 560, se renderiza solo si el nodo está visible) con una **cámara ortogonal** inclinada 28° de la vertical (para que se lea el volumen), y un `Sprite2D` que muestra su textura. Es un nodo 2D normal: `capa_z` (100) es su `z_index`, hereda la escala del libro y se oculta con `visible`. Sin perspectiva, la mano mide lo mismo en cualquier punto de la página: 520 px por metro (la mano ≈ 260 px, como la 2D). La manga sale por la esquina de abajo a la derecha y se desvanece con un shader para que no se vea el corte.
- **Escala.** `escala` vale 1 = tamaño de diseño (libro a 1470 de ancho). Para que acompañe al libro en otra resolución, el Juego pone `mano.escala = book.size.x / BOOK_SIZE.x` (el mismo factor que `_on_page`). El viewport no cambia de resolución: con `escala` > 1 se ve algo más blando.
- **Escribir y no escribir.** En `Pose.ESCRIBIENDO` la pluma se ve y el plumín está en la página (altura 0). En cualquier otra pose la mano sube 12 cm (en REPOSO, el 35 %) con la sombra más lejos y más clara, como la 2D. **Desde el 16/10 la pluma se ve siempre** (pedido de Pablo; export `pluma_siempre = true`; con `false` vuelve a ocultarse al no escribir). El conjunto es `ancla` (la punta del plumín, en el origen) → `brazo` (mano + manga) y `pluma`, usando `PiezaEscritura3D.pluma_en_agarre()`. La pluma gira con la velocidad y la mano un 55 % de eso, como antes.
- **La punta (punto 5 del encargo).** `PUNTA_PX` ya **no existe** en la 3D: el plumín es el origen del modelo y la cámara lo coloca en el píxel `PUNTA_VP` (170, 170) del viewport; el sprite se desplaza esa cantidad y el nodo va en `punta()`. Por construcción el plumín cae en `punta()` sin depender de la lámina ni de su relleno de 33 px (esos 33 px ya van dentro del PNG de 1470 × 1070 que `spellbook` dibuja entero). Lo que tiene que ser exacto es el punto que da el libro con `_on_page`. **Medido** en la imagen renderizada, solo con la pluma, con el encuadre de `_book_rect()` y el `bloque` del libro nuevo: en los 3 huecos de glifo, el sello y dos círculos de sello de la derecha, error de **1,2–2,2 px de pantalla** (≤ 2,2 px de lámina) a 1280 × 720 y a 960 × 540. Es el tamaño del píxel con el que se mide más el redondeo de la punta del modelo; el trazo mide 2,4–7 px de ancho.
- **Pluma de 15 963 triángulos (punto 6).** No hace falta una versión ligera de la malla: con la mano y la pluma puestas, los buffers de geometría suman **+1,4 MB** (medido) y la pluma ocupa unos 360 px de alto, así que sus triángulos son más pequeños que un píxel y decimarlos no cambiaría la imagen. Lo que pesa son las **texturas**: 2048² (albedo + normal) en la pluma y otras tantas en la mano. Medido en el sandbox (Compatibility/llvmpipe, sin compresión de VRAM): **+108 MB de memoria de textura** al instanciar la mano. En una GPU real con compresión sería bastante menos (no medido). Si se quiere recortar, lo útil es bajar las texturas de `pluma.glb` y `mano_agarre.glb` a 1024 (o 512 la pluma), no los triángulos: se puede hacer sin tocar la geometría ni el contrato.
- **Sin ver en el juego real:** probado solo en Compatibility con llvmpipe, y la mano aún no está enchufada en `spellbook.gd` (ahí no hay ninguna llamada a `ManoPluma2D`: solo la usaban `prueba_escritura_hud` y `captura_escritura`).

## 20. Retoques del Bosque 01 tras la prueba de Pablo (16/10, Pipeline)

- **Cofre abierto al nacer.** `cofre_anim.glb` sale con la **tapa abierta** y solo `Cofre3D.preparar` la deja en el clip «cerrado»; como `preparar` se llamaba al pulsar E, el cofre se veía abierto hasta entonces (medido: sin preparar la tapa queda a 0° y el cofre mide 0,85; preparado, 0,75). Ahora `arte/piezas/cofre.tscn` lleva un nodo `Cofre3D` como hijo, el `Cofre3D._ready` se prepara solo, y `generador_piezas.gd` lo añade al regenerar la pieza. `Cofre3D.en(pieza)` devuelve el que ya lleva. Prueba: `herramientas/prueba_cofre_cerrado.gd` (0 fallos).
- **Suelo y hierba.** Medido sobre las capturas de Pablo (agrupando los píxeles verdes en colores): el suelo sin hierba sale en (186, 230, 130) y (160, 217, 125), saturación 0,42–0,44; la hierba pintada en (158, 212, 85) y (127, 193, 81), saturación 0,58–0,60: el suelo era más pálido y menos saturado a igual brillo. `arte/suelo_meshy/hierba_arriba.png` se multiplica por (0,86 · 0,92 · 0,66) por canal, y la media pasa de (160, 210, 129) a (138, 193, 85), tono 97° → 91°, saturación 0,39 → 0,56. Se supone que una multiplicación sobre la textura es la misma en pantalla (luz × albedo y luego se codifica); la rampa de luz del suelo (`contraste`) puede apartarlo un poco: no medido. **No se tocan las briznas** de `Hierba3D` (`color_base`/`color_punta`, calculadas contra el suelo anterior): si ahora salen más pálidas que el suelo, hay que bajarles el azul. No visto en el juego real.
- **Arbustos.** Los de la captura son `arbusto_flores` (bola verde azulada con bultos rosas); los demás arbustos del nivel son `arbusto` (amarillo-verdoso con flores amarillas) y `arbusto_otono`. Lámina 3 de `arte/meshy/PROMPTS_BOSQUE_LAMINAS.md`: seis arbustos nuevos en verde cálido para sustituirlos.

## 21. Rejilla guía del trazo (`CuadriculaGuia`, 17/10, Pipeline)

Pedido de Pablo: una cuadrícula muy tenue en la página donde se dibuja, para que el jugador construya la runa bien desde el principio (y se reconozca mejor). Por código, sin asset: `presentacion/ui/cuadricula_guia.gd`; captura y prueba: `herramientas/captura_cuadricula_guia.gd` (0 fallos; necesita renderizador).

- **Qué dibuja.** (1) Una cuadrícula continua en toda la página izquierda, de **52,6 px de lámina** de paso, alineada con los **4 × 4 nodos del sello** (cuadrado de lado 0,66 × el diámetro del sello, centro 433,7 · 383,1, radio 119,6) y apagada hacia la cenefa (70 px) para no pelearse con las enredaderas. (2) Dentro de cada **círculo de glifo abierto**, una rejilla de 4 × 4 más fina (0,62 × su radio); ahí la de la página se aparta. Los huecos cerrados no llevan (igual que su aro).
- **Cuánto se ve.** Tinta marrón del trazo; líneas al 9 % de opacidad (11 % en los huecos), nodos de 2 px al 23 % (1,6 px al 26 % en los huecos). Medido: el cambio medio de color respecto a la lámina sola es 0,001 por píxel. Para subir o bajar, las constantes `ALFA_*` y `RADIO_PUNTO*` del archivo.
- **Geometría medida en la lámina** del bosque (1470 × 1070), guardada en `CuadriculaGuia.LIBROS["bosque"]`: si se rehace la lámina o se mueve un hueco, se cambian esos números (y `LIBROS` de `spellbook.gd`). Otra lámina no dibuja nada. `CuadriculaGuia.activa = false` la apaga.

## 22. Glifos de runas desde la lámina (encargo 133)
- **Origen:** `docs/runas_lista_definitiva.png`. Los 24 glifos de `art/ui/glyphs/` (96×96, blanco sobre transparente) salen de ahí. Los cuatro sin lámina (`amplificar, retardo, atraccion, espejo`) siguen con su versión anterior.
- **Método (v2, la vigente):** cada runa está definida a mano como polilíneas sobre la retícula de la rejilla guía (alto = 3 unidades, y hacia abajo), con un script del Pipeline (`fino.py`, no versionado). Trazo de 7,2 px con puntas y uniones redondas, 8× de supersampleo, centrado en (48,48), 74 px el lado mayor. Se descartó vectorizar el esqueleto de la imagen (daba rabitos y puntas cortas) y recortar la imagen (diagonales onduladas).
- **Si se rehace la lámina:** repetir el proceso con el mismo grosor y tamaño para que `glifo_tam` (76) siga valiendo. Una runa nueva = una piedra nueva en la lámina + un PNG con el nombre de la BIBLIA.

## 23. Recortador de láminas con dos puertas (`arte/herramientas/recortar_assets.py`)
- **Para qué:** cortar una lámina con muchos assets en un PNG por pieza, sin que nada llegue a su sitio final sin que Pablo lo vea. Detalle de uso en la cabecera del propio script.
- **Puerta 1, aprobación:** `cortar` deja las piezas en `arte/aprobacion/<lote>/` (carpeta con `.gdignore`: Godot no la importa) con id `<lote>-001…`, una `hoja_contacto.png` y un `lote.json` con el estado de cada pieza. Se aprueba o rechaza con `marcar`.
- **Puerta 2, procesar:** solo lo aprobado y con destino (`asignar`) se copia a su sitio (`procesar`), que solo escribe en carpetas del Pipeline y no pisa nada sin `--sobrescribir`.
- **Personajes:** pasan antes por el laboratorio (`laboratorio` los copia a `arte/laboratorio/humanoides` o `enemigos`; `procesar` los rechaza hasta que estén `revisado`). Que los laboratorios lean esas carpetas está por hacer.
- **Detección:** fondo = mediana del borde de la lámina (o `alfa`, o un color); se descartan las sombras del suelo (fondo oscurecido sin cambio de tono; `--con-sombras` las conserva); las partes sueltas de una pieza se agrupan con `--une`. Orden de lectura por filas. Dependencias: Python con Pillow, NumPy y SciPy.
- **Probado** con la lámina de runas real (36 piezas: 24 runas más los óvalos y rótulos de la anotación, que se rechazan en la puerta 1) y con una lámina sintética de personajes con sombra.
