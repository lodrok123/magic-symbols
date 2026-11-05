# Plan · VFX de los elementos y estado del mundo (31/10/2026)

Encargo de Pablo: «vamos flojos en el VFX de cada elemento». Trae una tabla de referencias por elemento, el principio de que **no todo debe brillar más**, y una lámina de cuatro pilares:

| pilar | referencia | qué tomamos |
|---|---|---|
| Mundo y puzles | Zelda: Echoes of Wisdom | el hechizo deja algo en el mundo que se usa (bloque, placa, charco) |
| Gamefeel | Wizard of Legend | cada golpe se siente: anticipación corta, impacto seco, hitstop, residuo |
| Dirección artística y VFX | Kena: Bridge of Spirits | formas limpias, color con intención, efectos con silueta |
| Reacciones elementales | Noita | el elemento cambia el estado del suelo y ese cambio se ve y se propaga |

Este documento diseña los cambios. **No los implementa.** Cada bloque dice de quién es según `docs/PROPIETARIOS.md`: el **dibujo** es de Pipeline (`presentacion/`, `vfx_elementos/`) y las **reglas y estados** son del Juego (`mundo/`, `magia/`).

---

## 0. Lo que hay hoy (medido en el código el 31/10)

| elemento | archivo | estado |
|---|---|---|
| Fuego | `presentacion/vfx_elementos/fuego.gd` (15 líneas) | **solo una paleta** sobre las piezas comunes del kit (lenguas, brasas, charco de luz). Es el elemento estrella y el que menos dibujo propio tiene |
| Agua | `agua.gd` (83) | paleta, burbuja que chorrea (vuelo) y ola (muro). Sin salpicadura propia ni charco que se extienda |
| Tierra | `tierra.gd` (576) | terrones, cascotes, bloques facetados y GLB de Meshy. Es el más trabajado |
| Viento | `viento.gd` (444) | cintas en espiral, hojas de atlas y remolino |
| Hielo | `hielo.gd` (654) | esquirla, racimos y escarcha con GLB. El sólido de hielo se dibujaba con el bloque de tierra (arreglado en el Juego el 31/10: `BloqueHielo` con material provisional) |
| Rayo | `rayo.gd` (157) | paleta; los arcos los pone `VfxEstado3D` (P1–P2 de `VFX_RAYO_HIELO.md`) |

`VfxKit3D.VALIDADOS` = `["fuego", "agua"]`: solo dos elementos tienen arte validado por Pablo, y los dos usan piezas comunes.

Lo que ya existe para el estado del mundo:
- `EstadosSuelo3D` (Juego): helada, electrificada, quemada, mojada y segada por casilla, con intensidad y caducidad, en una textura (R quemada, G mojada, B helada, A segada) que leen el suelo, la hierba y el agua.
- El autómata de la hierba de la maqueta (`prueba_test2.gd`): crecida → prendiendo (1 s) → ardiendo (5 s) → cenizas, con propagación a vecinas y un tope de 60 casillas. Mojada no prende durante 8 s.
- `ReaccionesVfx3D` / `VfxReaccion3D`: la tabla que elige qué se ve en cada reacción (vapor, apagado, llamas en el cuerpo) separada de los dibujos.
- `Sensacion3D`: hitstop proporcional al daño, temblor, golpe de zoom, retroceso, viñeta.

**Conclusión:** la infraestructura está (estados, tabla de reacciones, kit, gamefeel). Lo que falta es **lenguaje visual propio por elemento** y que **cada reacción termine en un estado que se vea**.

---

## 1. Principios (valen para todos los encargos)

1. **Silueta y movimiento antes que partículas.** La cámara está alejada: un efecto se lee por su forma y por cómo se mueve, no por la cantidad. Comprobar cada efecto en una captura a la altura real de la cámara y **en escala de grises**: si en gris no se distingue de otro elemento, falla.
2. **El brillo es escaso.** Solo **fuego y rayo** emiten (aditivo, HDR). Agua, tierra, hielo y viento se **mezclan** (no aditivos) y se leen por forma, translucidez y movimiento. El hielo puede tener un borde frío por fresnel, pero no luz propia fuerte.
3. **Cada elemento tiene un carácter físico** que manda en todas sus piezas:

   | elemento | carácter | movimiento | color y luz |
   |---|---|---|---|
   | Fuego | caliente, expansivo, irregular | rápido hacia arriba, se abre en flor | núcleo casi blanco pequeño, naranja en el borde, humo oscuro **no** aditivo |
   | Agua | fluida, pesada | arcos con gravedad, se curva, cae y se extiende | translúcida, oscurece lo que moja |
   | Tierra | maciza | lenta, con sobrepaso y asentamiento; tiembla | opaca, mate, sombras duras |
   | Viento | invisible, se ve por lo que mueve | curvo, continuo, sin peso | casi sin color: cintas finas, hojas, la hierba que se dobla |
   | Hielo | rígido, quebradizo | crece **por etapas** y se rompe en trozos | blanco azulado, bordes facetados, sin animación de llama |
   | Rayo | instantáneo | quebrado, a saltos, dura muy poco | destello breve muy blanco y luego nada |

4. **Cuatro tiempos en todo hechizo** (los tiempos de Wizard of Legend):
   **mano** (anticipación, ya existe el conjuro) → **viaje** → **impacto** (corto, seco) → **residuo** (lo que queda en el mundo). El residuo es lo que distingue Magic Symbols: casi todos los impactos tienen que dejar un estado visible.
5. **Una reacción comunica el estado nuevo, no una explosión.** Se ve en tres piezas: la **transición** (breve: el vapor, el chasquido), el **aspecto persistente** del estado nuevo (la casilla se queda mojada, helada o quemada) y, si aplica, la **propagación** (el fuego avanza, la placa crece, la descarga recorre el agua).
6. **Presupuesto.** Cada efecto declara su tope de partículas y de luces (una GPU integrada aguanta poco: ver `MAX_ARDIENDO`). Un efecto nuevo no sube el coste del fotograma en el laboratorio de geometrías más de lo que ya cuesta la tierra.

---

## 2. Fichas por elemento (Pipeline)

Cada ficha dice qué cambia en cada uno de los cuatro tiempos. Prioridad: **P1** fuego · **P2** agua y rayo · **P3** hielo · **P4** tierra y viento (afinar).

### 2.1 Fuego — P1 (referencia: Wizard of Legend)

Hoy es una paleta. Tiene que pasar a tener `fuego.gd` propio, como la tierra.

| tiempo | qué se ve |
|---|---|
| mano | una llama pequeña que lame hacia arriba; brasas sueltas que suben de la mano |
| viaje | núcleo blanco-crema pequeño + una corona de lenguas irregulares que se quedan atrás (no una esfera lisa); brasas que se desprenden y **suben** (el fuego no cae); un hilo de humo oscuro detrás |
| impacto | **expansión irregular**: lenguas que se abren en flor desde el punto en 0,15–0,25 s, con ruido (nunca un círculo perfecto); un destello corto; brasas lanzadas hacia arriba y hacia fuera; humo oscuro que sale **tarde** (0,2 s después) y sube despacio |
| residuo | la casilla quemada (ya existe) con **ascuas que laten** unos segundos y humo fino; si hay hierba, prende (ya existe) |

Piezas: lengua irregular (shader con ruido y erosión, ya existe en el kit: hay que darle forma de flor y no de cúpula), brasa ascendente (`brasa_tira8.png`), humo no aditivo (`humo_tira8.png`), ascua del suelo (nueva).
Criterio de aceptación: en gris, el impacto de fuego se distingue del de agua por la silueta (picos hacia arriba frente a corona baja).

### 2.2 Agua — P2 (referencia: Kena / Nine Parchments)

| tiempo | qué se ve |
|---|---|
| mano | gotas que se juntan en una esfera |
| viaje | la burbuja actual, con **estela curva** que sigue el arco de la gravedad y gotas que caen de ella (no que flotan) |
| impacto | **salpicadura en corona**: un anillo de gotas que sube y cae por gravedad, más una lámina baja que se extiende; sin destello |
| residuo | el **charco se extiende** desde el punto de impacto (no aparece entero) y **oscurece** el suelo que moja; al secarse (20 s, `DURA`) se aclara desde los bordes (ya hay `SECADO`) |

La ola (muro de agua) tiene que **caer** al final de su vida, no desvanecerse.
Criterio: el agua nunca brilla. Se lee por el borde claro (fresnel) y por cómo cae.

### 2.3 Rayo — P2 (referencia: Wizard of Legend)

| tiempo | qué se ve |
|---|---|
| mano | chispas finas que saltan entre los dedos; parpadeo |
| viaje / haz | la trayectoria **quebrada** (ya existe), con **ramificaciones** cortas que nacen y mueren cada pocos fotogramas; muy pocos fotogramas encendido |
| impacto | **destello** de 1–2 fotogramas (luz intensa que cae enseguida: es lo que vende el rayo), chispas que rebotan en el suelo y una marca chamuscada pequeña |
| residuo | la casilla electrificada con **chispas intermitentes** (no constantes) |

La descarga por agua y conductores se ve en el §3 (propagación).
Criterio: el rayo dura poco en pantalla. Si un rayo se ve más de 0,3 s seguidos sin parpadear, está mal.
Pendiente del playtest de Pablo (hoja «Revisión elementos»): «Rayo · Mejorable · Revisar VFX».

### 2.4 Hielo — P3 (referencia: Nine Parchments)

| tiempo | qué se ve |
|---|---|
| mano | escarcha que se forma en la mano; vaho frío |
| viaje | la esquirla actual, con copos que **caen** detrás |
| impacto | **cristales ramificados que crecen por etapas**: 3 pasos de 0,08–0,12 s con un chasquido en cada uno (no un crecimiento suave como el fuego) |
| residuo | el sólido de hielo como **bloque de hielo de verdad** (hoy `BloqueHielo` es una caja provisional: falta su dibujo); escarcha que se extiende por el suelo alrededor; al expirar, se **fractura** en trozos (`placa_hielo_rota_0..3` ya existe para el agua helada; hace falta lo mismo para el bloque) |

Pendiente del playtest: «Hielo · No · Ahora mismo está mezclado con tierra». El Juego ya separó el bloque (31/10); el dibujo es de Pipeline.

### 2.5 Tierra — P4 (referencia: Zelda: Echoes of Wisdom)

Las piezas están; falta **peso**:
- **anticipación**: el suelo tiembla y suelta polvo en la casilla 0,1 s antes de que salga el bloque;
- **salida**: el bloque emerge con **sobrepaso** (sube un poco de más) y **se asienta**, con un golpe seco y un temblor de cámara pequeño (el único elemento que tiembla al construir);
- **polvo radial bajo** al asentarse y 2–3 fragmentos que ruedan;
- al desaparecer, se **hunde** en el suelo con polvo, en vez de desvanecerse.

Pendiente del playtest: «Tierra · No · geometrías coherentes con los ejes X y Z». La lógica ya está arreglada (31/10, `perfil_solido`). Pipeline debe comprobar que el dibujo facetado sigue el mismo perfil.

### 2.6 Viento — P4 (referencia: Spellbreak)

El viento no se dibuja: se ve **por lo que mueve**.
- **Cintas** finas y curvas (ya existen), con **distorsión suave** detrás (shader de refracción ligero en la estela, sin color);
- **la hierba se dobla** en la dirección del viento al paso del hechizo (`Hierba3D` ya se mece: falta que reciba una ráfaga local con dirección);
- **hojas y briznas** arrastradas que salen de la hierba que cruza (no de la nada);
- las **llamas se inclinan** a sotavento cuando pasa cerca (ver §3, viento sobre fuego).

Criterio: el viento sin hierba ni objetos alrededor debe verse **poco**. Es correcto.

---

## 3. Estado del mundo (Juego reglas · Pipeline dibujo)

Cada fila: qué la provoca → estado nuevo → transición (breve) → aspecto persistente → propagación → qué existe y qué falta.

| reacción | estado nuevo | transición | aspecto persistente | propagación | existe / falta |
|---|---|---|---|---|---|
| **Agua sobre hierba** | hierba mojada (8 s, `HIERBA_MOJADA_S`) | gotas que salpican las briznas | hierba **más oscura y saturada**, gotas que brillan en las puntas; no prende | ninguna | estado y regla **existen**. Falta el **aspecto**: comprobar qué pinta hoy la hierba con G alto y darle color y gotas (Pipeline, `hierba_3d.gd`) |
| **Fuego sobre hierba** | prendiendo → ardiendo → cenizas | ignición: la llama nace pequeña y crece en 1 s | llamas sobre la hierba, luego **cenizas** y rastrojo | a las vecinas (ya existe) | **existe** todo. Falta: que la propagación se **lea** (la llama nueva nace en el borde que toca la vieja, no en el centro de la casilla) y cenizas con humo que sube |
| **Fuego sobre hierba seca** | igual, más rápido | — | — | más rápida | **falta**: no hay hierba «seca». Propuesta: una variante de hierba en el mapa (letra nueva) con color pajizo que prende en 0,3 s en vez de 1 s. **Decisión de Pablo** |
| **Hielo sobre agua** | agua helada, transitable | **la placa crece** desde el punto de impacto hacia fuera, casilla a casilla (≈0,1 s por casilla), con un crujido por anillo | placa blanca azulada con grietas finas; al caducar, se rompe en trozos (ya existe `placa_hielo_rota`) | por las casillas de agua vecinas hasta el alcance del hechizo | la placa **existe** (`poner_helada`) pero aparece de golpe. Falta: el **orden y el retraso por distancia** (Juego: `poner_helada` con un retraso por anillo; Pipeline: el dibujo por anillo) |
| **Rayo sobre agua** | agua electrificada | **la descarga recorre** las casillas conductoras en orden, con un retraso por distancia (≈0,03 s por casilla): se ve viajar | chispas intermitentes en la superficie; lo que esté dentro recibe | por el agua y los conductores conectados (ya existe la lógica) | la lógica **existe** (`_descarga`). Falta: emitir el **orden** de las casillas (Juego) y dibujar el arco que salta de una a otra (Pipeline) |
| **Viento sobre fuego** | llamas inclinadas; propagación a sotavento | las llamas se **inclinan** en la dirección del viento | — | **propuesta**: la hierba ardiendo prende la casilla a sotavento al instante (sin el segundo de «prendiendo») | inclinar: **falta** (Pipeline: las llamas leen una dirección de viento local). Propagar: **falta** (Juego: regla nueva en el autómata). **Decisión de Pablo**: si el viento propaga o solo inclina |
| **Fuego sobre agua / mojado** | seca (vapor) | nube de vapor blanca (no humo) | el suelo se aclara | — | **existe** (`TRANSICIONES` «vapor», `VfxReaccion3D`) |
| **Hielo sobre mojado** | helada | escarcha que se extiende | suelo blanco | — | **existe** (el mojado se hiela) |

**Regla general para el Juego:** cada transición de `EstadosSuelo3D` debe emitir el **orden y la hora** en que cambia cada casilla (no un cambio en bloque), para que el dibujo pueda mostrar la propagación. Hoy `Mundo3D.casilla_cambio` avisa casilla a casilla, pero todas en el mismo fotograma.

---

## 4. Gamefeel por elemento (Juego · `Sensacion3D`)

El gamefeel general ya está (hitstop, temblor, zoom, retroceso). Lo que falta es que **dependa del elemento**:

| elemento | hitstop | temblor | otros |
|---|---|---|---|
| Fuego | medio | ninguno | pequeño golpe de zoom al impactar |
| Agua | corto | ninguno | — |
| Tierra | largo | **sí**, al construir y al golpear | el único que tiembla al nacer |
| Viento | ninguno | ninguno | empuje visible en el enemigo |
| Hielo | medio, seco | mínimo al romperse | el enemigo congelado se queda quieto (ya existe) |
| Rayo | muy corto, varias veces | ninguno | **destello** de pantalla de 1 fotograma en golpes fuertes |

Encargo: una tabla `Sensacion3D.POR_ELEMENTO` con estos números y que `hitstop_de` y `disparo` la lean. Son datos: se ajustan en playtest.

---

## 5. Orden de trabajo

| fase | quién | qué | cómo se valida |
|---|---|---|---|
| **V0** | Pipeline | **banco de comparación**: en el laboratorio de geometrías, una fila por elemento con los cuatro tiempos en bucle y una cámara a la altura del juego, con opción de verla en gris | captura de la fila en color y en gris; Pablo elige |
| **V1** | Pipeline | **fuego** propio (§2.1) | Pablo valida con el banco. Entra en `VALIDADOS` |
| **V2** | Pipeline | **agua** (§2.2) y **rayo** (§2.3) | ídem |
| **E1** | Juego | propagación con **orden y hora** por casilla (§3, regla general) y la **placa de hielo que crece** y la **descarga que viaja** | pruebas sin ventana: el orden de las casillas y los retrasos medidos |
| **V3** | Pipeline | dibujo de E1 (placa por anillos, arco que salta) y **aspecto persistente** de hierba mojada | banco + captura en el bosque |
| **V4** | Pipeline | **hielo** (§2.4), incluido el bloque de hielo de verdad | banco |
| **G1** | Juego | `Sensacion3D.POR_ELEMENTO` (§4) | prueba de los números por elemento; playtest |
| **V5** | Pipeline | afinar **tierra** y **viento** (§2.5, §2.6), con la hierba que se dobla y las llamas que se inclinan | banco |
| **E2** | Juego | viento sobre fuego e hierba seca, **solo si Pablo decide** que existen | pruebas del autómata |

V1 y E1 no dependen entre sí y pueden ir a la vez.

---

## 5 bis. Shaders elegidos por Pablo (godotshaders.com, 31/10)

Revisados uno a uno en su página (licencia, versión, tipo, coste). **Pipeline los integra**; aquí, qué hay que cambiar en cada uno y dónde va.

| elemento | shader | licencia | encaja | qué hay que cambiarle | dónde se usa |
|---|---|---|---|---|---|
| Fuego | [Spatial Fire Raymarched v2](https://godotshaders.com/shader/spatial-fire-raymarched/) | CC0 | **sí**: fuego volumétrico en un quad con billboard, con núcleo, medio, borde y humo | es **caro** (raymarching por píxel): usar 4 pasos o `potato_mode`. Necesita una `NoiseTexture3D` y el `depth_texture` (atenuación por cercanía). Hacer el quad más grande que la llama (si no, la corta) | proyectil, impacto, columna y barrera de fuego. **No** en la hierba que arde (hasta 60 casillas a la vez: ahí siguen las lenguas baratas del kit) |
| Agua | [Stylized Toon Water](https://godotshaders.com/shader/stylized-toon-water/) | MIT | **a medias**: es para bolas y masas de agua (desplaza vértices y pinta bandas según el ángulo) | viene con `blend_add` y `unshaded`, así que **brilla** y cambia según el fondo: contradice el principio 2 («el agua no brilla»). Pasar a `blend_mix` con alfa. Necesita una malla con vértices suficientes y dos texturas de ruido Perlin | la burbuja que viaja y la ola. **No** para la superficie del agua del mundo (ya es `agua_render_3d`) |
| Rayo | [3D Lightning](https://godotshaders.com/shader/3d-lightning-shader/) | CC0 | **sí**: rayo procedural en un quad, parpadea solo | el **alfa sale solo del canal rojo** del color: con un azul o un cian (poco rojo) el rayo desaparece. Cambiarlo por la luminancia. `Power_Texture` no se usa: se puede quitar | el haz de rayo (ᛁ + rayo) y el rayo del impacto. Los arcos dentro del volumen pueden seguir siendo los de `VfxEstado3D` |
| Hielo (no sólido) | [Spatial Ice Shader](https://godotshaders.com/shader/spatial-ice-shader/) | CC0 | **no para eso**: es un shader de **superficie** (fresnel, refracción, mapa de normales), no un volumen ni un gas. Además está en sintaxis de Godot 3 (`hint_color`, `hint_albedo`): hay que portarlo a 4 (`source_color`, `hint_screen_texture`; en los comentarios de la página hay una versión 4.4) | **recomendación**: usarlo para el **bloque de hielo sólido** (`BloqueHielo`, que hoy es una caja provisional) y los racimos, que es justo lo que hace bien. Para el soplo de aire helado, el shader de fuego de arriba con paleta fría, sin emisión y en `blend_mix`: es un volumen y se mueve como un gas | bloque y racimos de hielo; el soplo helado, con el de fuego. **Decidido por Pablo (31/10): así** |
| Runas en el suelo | [Procedural Magic Circle](https://godotshaders.com/shader/procedural-magic-circle/) | MIT | **a medias**: probado en Godot 4.7, todo procedural | es `canvas_item` (2D): para el suelo hay que portarlo a `spatial` sobre un plano (UV, `unshaded`) o pintarlo en un `SubViewport`. **No tiene runas**: solo anillos, estrella, marcas y orbes. Las runas de cada hechizo hay que añadirlas en un anillo con los PNG de los glifos (`Sigils.GLYPHS`). El autor dice que se escribió con ayuda de IA | el círculo bajo la jugadora mientras conjura y donde nace lo que se apunta (`en_punto`) |

**Licencias:** CC0 no pide nada. MIT pide conservar el aviso de copyright: hay que guardarlo junto al shader (cabecera del `.gdshader`) o en un archivo de licencias del proyecto.

## 6. Decisiones de Pablo (31/10)

| pregunta | decisión | qué implica |
|---|---|---|
| ¿Existe la **hierba seca**? | **Sí** | variante de hierba en el mapa (letra nueva) que prende en ~0,3 s en vez de 1 s, con color pajizo. Entra en E2 |
| ¿El **viento sobre el fuego** propaga o solo inclina? | **Propaga** | la hierba ardiendo prende al instante la casilla a sotavento cuando pasa viento, y además las llamas se inclinan. Entra en E2 (regla) y V5 (dibujo) |
| ¿Destello de pantalla en el **rayo**? | **Sí** | 1 fotograma en los golpes fuertes. Entra en G1 |
| ¿Solo la **tierra** tiembla al construir? | **Sí** | `Sensacion3D.POR_ELEMENTO`: temblor al construir solo en tierra. Entra en G1 |
| Velocidades de propagación | **De momento así** | placa de hielo 0,1 s por casilla; descarga 0,03 s por casilla. Se ajustan en playtest |

**Ojo con quién toca qué.** El autómata de la hierba (prender, arder, cenizas, propagación) vive en la maqueta, `presentacion/prueba_test2.gd`, que es de **Pipeline**. La hierba seca y el viento que propaga son REGLAS, pero hoy esas reglas están dentro de ese archivo. Dos caminos:
- (a) Pipeline añade las dos reglas al autómata de la maqueta, con los números que da este plan;
- (b) el Juego saca el autómata a `mundo/` (como se hizo con `EstadosSuelo3D` en B1/B2) y la maqueta solo lo dibuja. Es más trabajo, pero deja las reglas donde las demás.
Recomendación: **(a) ahora** para poder probarlo, y (b) cuando se toque la hierba otra vez.

### Nota 5/11 · Rayo ya en el juego (rama claude/vfx-rayo-ref)
El rayo procedural (RayoToy) está encendido de serie (`vfx_procedural_elementos="fuego,agua,rayo"`) y se llevó a la referencia en vídeo de Pablo (solo referencia visual; todo procedural): bola con estrella y estela recta, impacto con ramas verticales y marca de grietas, pilar sobre sello circular con raíces, haz tubular con hélices, muro de arcos sobre línea de suelo, área con sello y descargas, y el ESTADO electrificado (`EstadoRayoToy`: en entidad y en el agua del suelo, reloj oficial 2 s). Ver DIARIO 365 y `docs/capturas/vfx_en_juego/rayo_ref/`. Pendiente: contraste sobre hierba clara y estado en entidad más legible.
