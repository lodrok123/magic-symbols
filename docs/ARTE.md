# Dirección de arte

**Fantasía pintada, isométrica 2.5D.** Sketch Town fue un parche mientras
se buscaba la dirección; se sustituye pieza a pieza, sin parar el juego.

La referencia visual es `docs/guia_arte.png`. Este archivo es su
contraparte en números: lo que hay que cumplir para que una pieza entre
sin tocar código. Los colores de aquí están **medidos sobre la guía**, no
elegidos a ojo.

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

Luces (`glow.gd`): `LUZ_FUEGO` `Color(1.00, 0.78, 0.42)` ·
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

El ambiente de cada uno está en `Glow.AMBIENTE`. No es decoración:
**decide qué elemento importa**. En la cueva volcánica casi no se ve, así
que el fuego deja de ser un arma y pasa a ser la vista; en el desierto
apenas oscurece, así que allí el fuego no da nada que no tuvieras.

---

## 3. El contrato de una hoja de personaje

> **HISTÓRICO (4/10/2026): §3–§5 son del animador y la maga de septiembre.** Hoy el personaje sale del pipeline 3D (celdas 192×240, `meta.json`; ver `export_godot/CONTRATO_GODOT.md`).

Lo lee `actor_animator.gd`. Una hoja que cumpla esto entra sin tocar una
línea de código.

- **64×64 px por celda**, rejilla uniforme, **un PNG por clip**.
- **8 filas = 8 direcciones**, y el orden NO es libre:

  ```
  fila 0  E      fila 4  O
  fila 1  SE     fila 5  NO
  fila 2  S      fila 6  N
  fila 3  SO     fila 7  NE
  ```

  Sale de `_row_for()`: `posmod(round(ángulo / 45°), 8)` sobre el ángulo
  **desaplastado** (`y × 2.109`), con 0° = derecha de pantalla. La guía
  las lista empezando por S; si la hoja llega en ese orden, el mago anda
  mirando hacia donde no es.

- **Columnas por clip.** Cualquier número vale —se declara en
  `ActorAnimator.hero()`— pero hay que decidirlo antes de dibujar:

  | clip | ahora | la guía propone | cómo avanza |
  |---|---|---|---|
  | `walk` | 8 | 8 | por **distancia** recorrida |
  | `idle` | 4 | 4 | por reloj, 4 fps, en bucle |
  | `cast` | 6 | 6 (Lanzamiento) | por reloj, 14 fps, una vez |
  | `hurt` | 3 | 4 (Hit) | por reloj, 12 fps, una vez |
  | `death` | 6 | 6 | por reloj, 8 fps, se queda en el último |

  `walk` va por distancia y no por reloj a propósito: así el ciclo se
  ajusta solo si cambia la velocidad, y **la pisada suena siempre en el
  fotograma en que el pie toca** (columna 0 y columna mitad).

- **Los pies en y=52** de la celda, y nada por encima de y=4. Hay una
  comprobación programática que ya cazó un sombrero saliéndose del sitio.

Clips de la guía que el animador todavía no tiene: `correr`, `sacar
grimorio`, `abrir libro`, `dibujar`. Añadir uno es **una línea** en
`ActorAnimator.hero()`.

---

## 4. La protagonista

**Referencia canónica: `docs/referencia_personaje.png`** — la elfa de
**dos trenzas**, capa azul con ribete dorado y el zurrón al cinto.

Hubo tres tandas antes de fijarla. Se descartó la del **pelo suelto** por
un motivo de producción, no de gusto: el pelo suelto pide su propia
animación —mechones que se mueven con un desfase respecto al cuerpo— y
eso multiplica el trabajo en los cinco clips y en las ocho direcciones.
Las trenzas se mueven como un sólido. Es el tipo de decisión que sale
barata ahora y carísima dentro de doscientos dibujos.

La regla que evita que vuelva a pasar: **pasar la imagen de referencia
como entrada en cada generación**, no solo el texto. Un prompt describe;
una imagen ancla. Si cada tanda trae una chica parecida pero distinta, el
problema no se arregla solo — se acumula, y se descubre tarde, cuando ya
hay cien dibujos hechos.

### Las ocho direcciones: cinco dibujos, no ocho

`E/O`, `SE/SO` y `NE/NO` son parejas simétricas. Con **cinco** vistas
(`S, SE, E, NE, N`) se tienen las ocho, espejando las otras tres.

No es solo ahorrar el 40% del trabajo: **garantiza** que la pareja sea
coherente, y ahí es justo donde falla la generación por IA. Está medido
sobre la primera hoja de direcciones que llegó — el giro `S→SE→E→NE→N`
era correcto (la N era la espalda de verdad), pero las otras tres no
cerraban el círculo:

```
E  vs O    directo 42.9   espejado 53.3   ✗
SE vs SO   directo 37.5   espejado 48.4   ✗
NE vs NO   directo 43.1   espejado 56.3   ✗
```

Espejar las hacía *menos* parecidas, o sea que eran variaciones del mismo
lado. En el juego, andar al este y al oeste se habría visto igual.

Lo que se paga al espejar: los detalles asimétricos —la bolsa del
grimorio, la trenza— cambian de lado al girar. A 78 px se nota poco, y es
lo que hacen casi todos los juegos clásicos.

### Qué falta

- El PNG limpio de la hoja de direcciones (2048×1024) **con
  transparencia**. Lo que llegó era la lámina de documentación
  (1983×793) y sus cuadros traen el fondo pegado: gris moteado con
  manchas rojas y amarillas, el **16% de cada celda**.
- **El andar con trenzas.** Hubo uno de 7 fotogramas × 8 direcciones y
  funcionaba, pero era de la maga de pelo suelto. Está descartado: si se
  dejara puesto, a la maga le cambiaría el peinado al echar a andar, y
  eso se lee como un fallo, mientras que no animar se lee como algo por
  terminar.
- **`cast`, `hurt` y `death`.** Ahora son el fotograma neutro del idle.
  No animan, pero conservan las ocho direcciones, que es lo que de verdad
  se nota — que siga mirando bien mientras lanza.

### Lo que sí está

`idle`: 6 fotogramas × 8 direcciones (5 dibujadas + 3 espejadas), 96 px
de celda, figura de 78, pies en y=86. Medido: respira de verdad (8 px de
recorrido, tres cambios de sentido) y el bucle cierra con 4 px de salto.

---

## 5. Por dónde seguir

Lo más difícil del proyecto entero no es el sistema de runas: son
**8 direcciones × 10 animaciones manteniendo el modelo**. Son más de 500
dibujos que tienen que parecer la misma persona, y es justo donde la
generación por IA se rompe — cada tirada da una chica *parecida*, no la
misma.

Ese paso ya se dio y enseñó justo lo que tenía que enseñar (ver arriba).
El siguiente, en orden:

1. **Las cinco vistas limpias**, con fondo transparente. Las otras tres
   salen espejadas.
2. **`idle` completo**: 4 fotogramas × 5 vistas. Y que se muevan de
   verdad — en la primera tanda la cabeza no subía **ni un píxel** entre
   los ocho cuadros y el área variaba un 2%. Eso no es respiración, es
   ruido de render: en secuencia no se ve respirar, se ve *hervir*.
3. **`walk`**: 8 × 5. Es el que más se mira.
4. **`cast`**. El resto puede esperar a que haya niveles que lo pidan.

---

## 6. El contrato de una losa

Las losas tienen una restricción que el personaje no tiene, y si no se
respeta **no hay nada que ajustar después**: la rejilla isométrica se
apoya en que todas compartan exactamente el mismo rombo. Una losa 4 px
más alta abre una junta visible en todo el mapa.

*(Actualizado el 4/10/2026: el contrato de septiembre era 256×352 con el rombo de 232×110, del
pack Sketch Town. Hoy es el del pipeline.)*

- Rombo de **128×64** (`tile_px`), **cara de arriba centrada hacia la fila y = 33** del sprite
  (los bloques miden 33–36 según la pieza; lo que importa es que una pieza que se apile sobre otra
  tenga la **misma fila** que la que sustituye), costados hacia abajo. Un bloque suelto mide 128×102.
- El juego encoge cada losa con `SX = 116/128` y `SY = 55/64` (`nivel_base.gd`): casilla de
  116×55, paso (58, 27.5), `LEVEL = 55.5` (`IsoGrid`).
- Cualquier pieza que se pinte sobre la rejilla (hielo, tierra creada, empujables) trae **este
  mismo lienzo**. Si trae otro, queda hundida o flotando: el hielo de `art/` (176 de alto, cara en
  y = 96) se dibujaba ~22 px por debajo de las losas vecinas.
- Los bloques viven en `export_godot/terrain/bosque_01/sprites/blocks/`.

### Dos cosas que arruinan una losa aunque cumpla la geometría

- **Luz direccional marcada.** Una losa se repite sesenta veces en
  pantalla. Si trae una sombra proyectada hacia un lado, al enlosar se ve
  la repetición antes que el dibujo. Luz plana y suave; el volumen lo
  dan las tres caras, no las sombras.
- **Detalle que no se pueda repetir.** Una grieta muy característica, una
  flor, una mancha: a la tercera copia el ojo la caza. Eso va en adornos
  sueltos (`prop_*`), que se plantan uno cada varias casillas.

---

## 7. Carpetas

La guía propone una estructura por categoría, y es buena. Se adopta
**según vaya llegando arte**, no de golpe: `art/` sigue en pie con lo de
Sketch Town hasta que cada pieza tenga sustituto. Mover 60 archivos hoy
solo rompería las rutas de todo lo que ya funciona.

```
characters/protagonista/rita_maga/   sprites + atlas
environments/<bioma>/                losas, bloques, props
vfx/<elemento>/                      proyectil, area, impacto
ui/                                  grimorio, iconos, retratos
```

---

## 8. La taxonomía de VFX

La guía separa **Proyectil / Área / Impacto** por elemento, y es mejor
estructura que la de ahora (una hoja por elemento y punto).

Lo bueno es que el código ya distingue los dos primeros sin saberlo:
`SpellRecipe` decide `travels`, y de ahí sale si el hechizo viaja o se
queda. Lo que **no existe** es el impacto — hoy un hechizo desaparece sin
más. Añadirlo daría más sensación que cambiar de estilo.

Encaja en `RuneData` igual que las intensidades del fuego: dos campos más
por elemento, opcionales, y quien no los rellene sigue funcionando.

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
