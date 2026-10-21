# Plan EoW (2.ª parte) · aspecto visual y nivel de pruebas

21/10/2026 · análisis (Opus) a petición de Pablo: «revisa el plan de integración con EoW de código, shaders, texturas (no copiarlas, pero sí usar sus trucos para quitarles el aspecto cuadrado), posprocesado, iluminación, cómo texturizan a pesar de ser un juego con pocos triángulos… El objetivo final es preparar un nivel de pruebas inspirado en algún nivel de EoW con puzles de fuego o agua».

Fuentes: `docs/estudios/eow/EOW_4_ASSETS.md` (§1–§6), `EOW_2_NIVELES.md` (§6–§7), `docs/ANALISIS_EOW.md` §5, y un inventario del código hecho hoy (qué truco existe, dónde y qué le falta). **Regla de siempre: de EoW no entra nada (ni datos, ni texturas, ni shaders); solo las ideas, con nuestros números.**

---

## 1. Por qué EoW no se ve cuadrado con tan pocos triángulos

Lo que hace EoW, en orden de lo que más pesa en pantalla:

1. **La luz y el posprocesado hacen el trabajo, no la malla.** Una sola luz direccional casi cenital (15–20° de la vertical) cuyo **color** da el tono de cada mazmorra, ambiente de dos colores (cielo / suelo), **SSAO** que «apoya» cada pieza en el suelo, bloom suave, **tonemap**, tilt-shift + DOF (look de maqueta), y sombra ortográfica de una sola caja alrededor de la jugadora.
2. **Albedos pintados de contraste muy bajo** (el valor apenas varía 25–45 niveles de 255) y **sin luz horneada**: el volumen lo ponen la luz y el AO, no la textura.
3. **Texturas en coordenadas de mundo** y **mezcla de 2–3 capas** por máscara, más **tiras de transición con alfa** («joint») en los bordes entre suelos: así las uniones no siguen las aristas de la malla.
4. **El estado en el shader**, no en mallas nuevas: variante «quemado» (albedo × carbón con máscara), aparición/desaparición **por celdas Voronoi** (sin partículas), transparencia por tramado para lo que tapa.
5. **Personajes «de juguete»:** casi planos con degradados suaves, **fresnel de color** + sphere map en vez de PBR realista; silueta visible a través de paredes.
6. **Agua estilizada:** opacidad y color por profundidad, espuma de orilla, cáusticas en coordenadas de mundo, tres escalas de olas, reflejo de un cubemap de 64 px por sala.
7. **Presupuesto pequeño y texturas compartidas:** protagonista ~10 k triángulos con texturas de 256², objetos 700–1.500, salas con sets de 1024² compartidos. Con cámara fija y lejana, más resolución no se ve.

## 2. Dónde estamos (inventario del 21/10)

| Área | Ya está | Falta para el «look EoW» |
|---|---|---|
| Suelo | shader con textura de estado, UV de mundo, 4 capas por máscara, bordes con ruido y franja de hojas (`CODIGO_SUELO`, `presentacion/prueba_test2.gd`) | **las aristas de los bloques son vivas** (tapa plana + 4 lados por casilla); el estado se ve por casillas (bilineal 40×40); lo **quemado no pinta nada** (`fuerza_ceniza = 0`); lo mojado no refleja (`SPECULAR = 0`); lo helado sin fresnel; las **terrazas** de Terra Fina son quads de color plano sin shader |
| Bordes | `BordePiedras3D`: falda suavizada de 0,3 u y cantos en orillas y escalones | el **labio** de arriba de cada escalón sigue vivo |
| Agua | opacidad y color por profundidad, espuma, cáusticas pintadas, flow map, paredes | refracción; 3.ª escala de olas; sonda de reflejos **apagada de serie** |
| Posprocesado | glow (bloom), DOF lejano activo, ajuste de color (`Paleta3D`), tilt-shift **hecho pero apagado** | **SSAO, tonemap, viñeta, FXAA/TAA: no hay**; `project.godot` sin ningún ajuste de render |
| Luz | luz por zona (`LuzZona3D`), OmniLight sin sombra en cada fuego | la zona por defecto está a 35° de la vertical (EoW 15–20°); ambiente de dos colores **en la práctica plano**; sombra con cascadas por defecto |
| Personajes | sombra del sol | **sin rim/fresnel**, **sin silueta** a través de paredes, **sin sombra de contacto** (la tiene el decorado) |
| Estados de objetos | tinte uniforme `CHAMUSCADO`; la enredadera se disuelve por celdas (único caso) | quemado con máscara de ruido y brasa; **disolución por celdas común** (escudo, ecos, objetos que aparecen) |
| Rendimiento | compresión VRAM y normal maps en casi todo | **4,2 M triángulos** en el Bosque 01 (EoW: 2,5–41 k por sala); personajes 30–100 k; texturas de 2048 en personajes |

## 3. Plan por pasos (lo que más cambia la imagen por menos trabajo primero)

| # | Qué | Dónde | Dueño | Esfuerzo |
|---|---|---|---|---|
| V1 | **SSAO + tonemap (AgX o Filmic) + FXAA**, y viñeta suave; tilt-shift y sonda de reflejos encendidos de serie; `reflection_size` 64–128 | entorno de la maqueta (`prueba_test2.gd` / `luz_zona_3d.gd`), `project.godot` | Pipeline · `project.godot` decide Pablo | muy bajo |
| V2 | **Luz casi cenital** (≈ 70° de inclinación) con color por zona, **ambiente de dos colores de verdad**, sombra ortogonal sin cascadas con `shadow_blur` | `luz_zona_3d.gd` | Pipeline (cambia el aspecto global: decide Pablo con capturas antes/después) | bajo |
| V3 | **Bisel / labio redondeado** en la arista de arriba de cada bloque y escalón (la falda ya existe abajo) | `borde_piedras_3d.gd`, `_malla_bloque` | Pipeline | medio |
| V4 | **Estado del suelo sin casillas**: umbral por ruido sobre la textura de estado, quemado con máscara de carbón, mojado con reflejo (`SPECULAR` > 0), helado con fresnel; y que lea `Mundo3D.textura_estados()` (encargo B2) | `CODIGO_SUELO` | Juego (el shader del suelo es del Juego desde la entrada 85) | medio |
| V5 | **Personajes juguete**: rim/fresnel de color, silueta a través de paredes (`next_pass` sin profundidad), sombra de contacto bajo jugador, NPC y enemigos | `jugador/pj_3d.gd` `_preparar_materiales` (+ material en `presentacion/`) | Juego + Pipeline | bajo-medio |
| V6 | **Material común con «quemado» y «disolver por celdas»** (Voronoi): setos, troncos, telaraña, escudo que se desintegra, objetos que aparecen (cofre) | `ocluso_3d.gd` (shader) + llamadas desde `objetos/` y `enemigos/` | Pipeline (shader) + Juego (llamadas) | medio |
| V7 | **Terrazas con el shader del suelo** y su falda | `escenas/terra_fina_3d.gd` | Juego | medio |
| V8 | **Presupuesto**: árboles `_2` en el Bosque 01 (−2 M triángulos), texturas de personajes a 1024, decimar piezas de 12 k | `arte/`, niveles | Pablo decide · Pipeline | bajo (sin arte nuevo) |

Recomendación: **V1 + V2 primero** (una tarde, se ve en todo), luego **V4 + V5** (lo que más se nota al jugar), y **V3 + V6** antes del nivel nuevo. V7 y V8 en paralelo cuando Pablo decida.

## 4. Lo que pidió Pablo junto a esto

- **VFX de tierra y viento.** El fuego y el agua tienen su VFX propio en `presentacion/vfx_elementos/` (fuego.gd, agua.gd); tierra y viento usan lo genérico. Propuesta:
  - **Tierra = sólido, no partículas:** proyectil = un **terrón facetado** (malla low-poly de roca, 4–6 variantes) que gira, con polvo al salir y al impactar **cascotes que caen y quedan un momento**; la barrera/muro de tierra = **bloques de roca que emergen del suelo** (de abajo arriba, con polvo), no una caja. Encaja con la «materia» y la solidez de los hechizos.
  - **Viento = líneas y deformación, no humo:** cintas curvas (trails) que giran en espiral alrededor de la trayectoria, hojas y polvo arrastrados, y la hierba que se aparta a su paso (ya existe el empuje por posición).
  - **Hielo** (sólido, como la tierra): cristales facetados translúcidos con fresnel; ya hay `costra_hielo_3d.gd`.
  - **Assets que harían falta (Meshy, 300–1.500 triángulos cada uno, texturas 512²):** lámina «rocas elementales» (6 terrones, 4 cascotes, 3 bloques de muro que emergen, 2 estacas de roca); lámina «hielo» (cristales en racimo, 3 tamaños; una placa de hielo rota en 4 trozos); para viento basta una textura de hoja/brizna (atlas 128×256, tarjetas). **Decide Pablo si se piden** a Meshy o se hacen con primitivas facetadas por código (como las piezas de puzle provisionales).
- **Respuesta positiva al jugador al resolver.** Hoy un puzle resuelto abre una puerta y nada más. Propuesta (un sistema, no un código por sala):
  - un aviso con nombre al resolver (`Mundo3D.reaccion` o una señal nueva `logro(tipo, punto)`: «puzle_resuelto», «sala_limpia», «cofre_abierto»), que emiten las piezas lógicas de C3 y el vigía;
  - la presentación responde con una **tabla** (como `ReaccionesVfx3D`): jingle corto de acierto, destello en la pieza que se activa, cámara que se acerca un instante a la puerta que se abre (si está fuera de pantalla), texto breve en el HUD, y una pausa de impacto (hitstop de 60–100 ms) al derrotar al último enemigo de una sala cerrada;
  - un **sonido de «pista»** (más suave) cuando el jugador completa una parte (2 de 3 braseros), para que sepa que va bien.

## 5. El nivel de pruebas inspirado en EoW

**Modelo:** las mazmorras de EoW estudiadas (`EOW_2_NIVELES.md` §6): salas cenitales de 12–18 × 9–16 casillas, encadenadas; **≈ 1 puzle por sala**, pocos enemigos (0,6 por sala), puzles hechos con piezas lógicas (placa → flag → puerta, sala que se cierra hasta derrotar a todos, cofre con la llave). Las mazmorras de **agua** (luz azulada) y de **fuego** (luz cálida) se distinguen sobre todo por el **color de la luz** y por qué elemento resuelve sus puzles. Se toma la estructura, no ningún mapa.

**Propuesta: «Santuario del Manantial», 6 salas, ~45 × 30 casillas** (escena nueva `escenas/PruebaSantuario.tscn` con su mapa en `mundo/datos_nivel/mapas/Santuario.txt`, piezas y puzles en líneas `; pieza` / `; puzle`; horneable).

| Sala | Tema | Qué se resuelve | Mecánicas nuevas que ejerce |
|---|---|---|---|
| 1 · Vestíbulo | entrada, enseñar | dos braseros apagados flanquean una puerta: encender los dos (fuego) abre; un seto seco esconde un atajo | A2, contador, respuesta positiva |
| 2 · El estanque (agua, luz fría) | llenar y helar | una tinaja llena un cauce; con el nivel alcanzado gira el molino que sube una reja; luego **helar** el estanque para cruzarlo hasta la llave pequeña | agua física, nivel, molino, hielo (B1: escarcha vs hielo físico) |
| 3 · El puente caído | tronco-puente | quemar el tronco en pie para que caiga como puente sobre el río (ahora llega de orilla a orilla); goblins al otro lado que se pueden **empujar al agua** con viento | tronco-puente, A3 (hundirse), D2 (rutas) |
| 4 · La sala cerrada (combate) | todos derrotados | al entrar se cierra; 3 goblins (uno con escudo, un arquero junto a un brasero que enciende sus flechas); al limpiarla se abre y aparece un cofre | C3 vigía + cerrojo + cofre, A5, A2 flechas |
| 5 · Fuego y agua (luz cálida) | orden y condiciones | tres losas que hay que **mojar** mientras el brasero está **apagado**, y luego encenderlo: `si=` compuesto; si quemas la hierba del centro, el cofre secundario no aparece | C2 (`+ \| !`, `casilla(x,y)`), estado del suelo real |
| 6 · El santuario | cierre | puerta con la llave pequeña; dentro, un pedestal: la recompensa (pigmento) y el «nivel completado» | flags (persistencia), pigmentos (E1), respuesta positiva grande |

Cada sala con su **preset de luz** (V2) y su cartel; la sala 2 y la 5 enseñan el contraste frío / cálido. Una prueba sin ventana que recorra el nivel entero por la vía buena (como `escenario_playtest_eow`). El arte sale de lo que ya hay (piezas del Bosque, láminas de puzle, campamento); lo que falte se apunta como encargo.

## 6. Orden propuesto (para decidir)

1. **V1 + V2** (look) y la **respuesta positiva** (sistema + tabla) — se notan en todo y el nivel nuevo las estrena.
2. **VFX de tierra y viento** con primitivas facetadas mientras se deciden los assets de Meshy.
3. **El nivel «Santuario del Manantial»** sala a sala, con commit por sala, como el laboratorio de playtest.
4. **V4, V5, V3, V6** mejorando el nivel ya montado (se ve el antes/después en el mismo sitio).
5. **V7, V8** cuando Pablo decida (terrazas, presupuesto).
