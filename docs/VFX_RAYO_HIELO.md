# VFX de rayo y hielo: diagnóstico y propuesta (16/10/2026, Juego)

Rayo e hielo ya son elementos de puzle (Q7 nexo eléctrico, tapón y compuerta de hielo, agua helada para
cruzar), pero sus efectos se quedaron en la primera pasada del 6/10 mientras fuego y agua recibieron el
kit luminoso (`VfxKit3D` + `vfx_elementos/`). Este documento mide lo que hay, dice qué chirría frente a
las referencias (Echoes of Wisdom, Link's Awakening, Breath of the Wild) y propone qué hacer, con reparto
y prompts. Los archivos de VFX son de `presentacion/` (Pipeline): aquí no se edita nada; el Juego solo
pone los datos que el dibujo necesita (§5).

## 1. Qué hay hoy (leído del disco, portátil al día)

| Pieza | Dónde | Cómo se ve ahora |
|---|---|---|
| Bola de rayo | `vfx_3d.gd` `_esfera_perfil("rayo")` | Esfera translúcida azul (`PERFIL.rayo`: núcleo 0,2/0,45/0,95, borde cian) con "venas"; chispas `chispa_electrica`. |
| Impacto de rayo | `_impacto_rayo` (l. 2046) | **Un rayo baja del cielo** (pieza `rayo` 4 u de alto) y parpadea 3 veces con `visible` a 50/40 ms; 10 chispas; destello amarillo; **grieta oscura 8 s**; luz amarilla 0,35 s; temblor. |
| Agua electrificada | `emisor_rayo_3d.gd` `_pintar` (Juego) | **Una losa amarilla por casilla** (quad 0,92 casilla, alfa 0,55, emisión 1,2, sin sombreado) + `chispazo` en el 25 % de las casillas, tope 6 por tick. |
| Nexo / pila | `nexo_rayo_3d.gd` (Juego) | Disco de agua que se vuelve amarillo con emisión mientras conduce. (Entrada 98: `PiezaPuzle3D` ya tiene estado `"electrificada"` con bornes, chispas y zumbido; aún no lo uso.) |
| Corro / muro de rayo | `anillo_energia.glb` + `CODIGO_ENERGIA` | Cúpula azul con fresnel cian y tramos que se encienden en blanco. **Esto sí está bien** y marca la paleta "campo azul". |
| Tormenta | `_rayo_de_nube` | Rayo de nube con destello y chispas (correcto como tormenta). |
| Bola de hielo | `_esfera_perfil("hielo")` | Esfera facetada (4 niveles) azul claro con copos. |
| Impacto de hielo | `_impacto_hielo` (l. 2071) | **6 cristales en anillo perfecto** (r 0,4, altos 0,5–0,74, escalonados 0,03 s) que duran 7 s y se **encogen** al fundirse; 18 copos; **marca `circulo_runico`**; luz. |
| Agua helada | `agua_render_3d.gd` (hielo_t/hielo_g) | Facetas Voronoi con grietas, crece 0,1 s por trocito desde el centro del impacto, se oscurece y agrieta con G < 0,15. Colores claro 0,70/0,84/0,96, hondo 0,46/0,66/0,88. Bien resuelto. |
| Objeto congelado | `costra_hielo_3d.gd` | Piel Voronoi hinchada 0,03 u sobre las mallas, misma paleta, `aviso` abre grietas. Bien. |
| Conjuro en la mano | `conjuro_vfx_3d.gd` (108) | Siete aspectos en una tabla `PERFIL` propia; el kit solo conoce fuego y agua. |

Dos paletas de rayo conviven: `COLOR["rayo"]` = amarillo (1, 0,93, 0,4) para impacto, losas, nexo y luz;
`PERFIL["rayo"]` = azul/cian para la bola, el corro y el muro. Es la incoherencia más visible: el hechizo
sale azul de la mano y llega amarillo al agua.

## 2. Qué chirría frente a las referencias

Qué toma el proyecto de cada juego (regla del `LEEME` de referencias: forma = malla, elemento = material):

- **Echoes of Wisdom**: siluetas limpias en 2–3 tonos planos con contorno; la electricidad son **arcos gruesos
  blancos con filo de color que cambian a saltos** (8–12 cambios por segundo, no un deslizamiento continuo);
  el hielo son **cristales facetados casi blancos con destellos de cuatro puntas** que parpadean.
- **Link's Awakening**: material de juguete; el hielo es translúcido con brillo especular alto y arista clara;
  los destellos "estrella" en cruz son la firma de cualquier cosa fría o brillante.
- **Breath of the Wild** (lectura funcional, es la que manda en los puzles): el agua electrificada **se tiñe y la
  recorren arcos** que serpentean por la superficie, y los personajes dentro sueltan chispas; el hielo deja
  **escarcha en el suelo alrededor** que se derrite de fuera adentro, suelta **vaho** y al romperse caen
  fragmentos con niebla.

Problemas concretos, por orden de lo que más se nota en el laboratorio:

- **R1 Agua electrificada en losas.** La rejilla de casillas se ve (el agua es continua, la electricidad la
  delata), el amarillo opaco tapa el agua y no se parece a nada de las tres referencias. Debe ser un tinte
  del propio agua más arcos finos encima.
- **R2 La corriente no viaja.** El emisor enciende todas las casillas a la vez; el puzle de continuidad (Q7,
  vídeo de TotK) se entiende mejor si se ve el frente avanzar del emisor al nexo y del nexo al tótem.
- **R3 El impacto de la bola es un rayo del cielo.** La bola viene horizontal de la mano y al llegar cae un
  rayo de 4 u desde arriba: es la imagen de la tormenta, no de un proyectil. El impacto debe ser radial
  (arcos cortos desde el punto + anillo + destello).
- **R4 Grieta oscura 8 s.** Sobre agua no tiene sentido; sobre piedra, un chamuscado estrellado corto sí.
- **R5 Dos paletas** (arriba).
- **H1 Marca `circulo_runico`** bajo el impacto de hielo: el círculo rúnico es la firma del conjuro en el
  lanzador, no del hielo. Debe ser escarcha.
- **H2 Cristales en flor.** Seis iguales en círculo perfecto se leen como un adorno; las referencias ponen uno
  grande inclinado y varios pequeños irregulares, creciendo escalonados.
- **H3 Sin escarcha ni vaho.** El hielo no enfría el suelo ni el aire alrededor; es lo que más "frío" aporta
  en BotW y cuesta poco.
- **H4 Se funde encogiendo.** Un cristal que se encoge hasta 0,01 parece que se lo traga el suelo; el hielo
  se **agrieta, se parte y deja un charco** (y el charco conecta con la simulación de agua: coherente con
  el tapón de hielo del desagüe).
- **H5 Poco contraste hielo/agua.** El claro del hielo (0,70/0,84/0,96) está muy cerca de la rampa del agua
  (0,62/0,84/0,99): sobre el agua el hielo debe ir más blanco y más opaco, con la grieta más saturada.
- **H6 Sin destellos.** Ni el agua helada, ni la costra, ni los cristales parpadean: falta el "sparkle" de
  cuatro puntas que las tres referencias usan para decir "esto es hielo".

## 3. Propuesta, por prioridad

Paleta única de rayo (propuesta; decisión de Pablo, §6): **arco = blanco cálido (1,0 · 1,0 · 0,9) con filo
amarillo (1,0 · 0,93 · 0,4)**, como BotW y EoW; **campo = azul** (0,2 · 0,45 · 0,95 → cian 0,5 · 0,82 · 1,0)
para bruma, tinte del agua, luz ambiente y la cúpula. Así el corro actual no cambia y el impacto gana el
chispazo caliente. Paleta de hielo: claro (0,86 · 0,93 · 0,99), hondo (0,55 · 0,74 · 0,92), grieta
(0,25 · 0,50 · 0,85), destello blanco puro.

### P1 · Agua electrificada (lo que más se ve; Pipeline + dato del Juego)

1. **Tinte en `AguaRender3D`**, igual que el hielo: una textura `electrico_t` (R = segundo en que entró la
   corriente en el trocito, G = segundo en que salió; misma rejilla que `hielo_t`). En el shader, mientras
   dura: el agua se aclara hacia el cian con un pulso de ~6 Hz y encima **venas blancas** dibujadas con el
   ruido que ya tiene (`abs(ruido − 0,5) < ancho` con el ruido desplazado a saltos cada 0,08 s, no continuo).
   Por texel con suavizado: desaparece la rejilla. Nada de losas.
2. **3–6 arcos 3D tumbados** sobre la superficie (la forma `rayo` de `Formas3D` escalada 0,6–1,2 u, tendida
   entre dos casillas vecinas electrificadas elegidas al azar), **re-barajados cada 0,08 s** y tope 6 a la
   vez (como `MAX_CHISPAS`). Color arco. Es lo que BotW hace y lo que da "corriente viva".
3. **Frente que avanza**: cada casilla enciende con retraso `orden × 0,04 s` desde el emisor (orden = pasos en
   la búsqueda que ya hace `EmisorRayo3D.agua_conectada`; el Juego lo expone, §5). A 7 casillas el tótem
   se enciende ~0,3 s después del emisor: se ve el recorrido y el papel del nexo.
4. Mantener `chispas_agua` / `chispazo_suave` (13/10) y la luz, pero una sola luz por descarga, sobre el
   centroide de las casillas, cian, 0,3 s.

### P2 · Impacto de la bola de rayo (Pipeline)

Sustituir el rayo del cielo por un **estallido radial**: 5–7 arcos cortos de pie (pieza `rayo`, altos
0,5–0,9 u) saliendo del punto en direcciones al azar, **re-sorteados 3 veces a 60 ms** (el "a saltos" de
EoW); **anillo eléctrico** con `_onda` (0,3 → 1,6 u en 0,25 s, cian); **destello blanco de 2 cuadros**
(`destello` 1,6 u, 0,05 s crecer / 0,25 s morir, ya existe); 10 chispas; luz cian 0,3 s; temblor 0,05.
Marca: `quemado` estrellado pequeño (0,6 u, 3 s) solo sobre suelo; sobre agua ninguna (la electricidad la
pone P1). El rayo del cielo se queda para `tormenta` y para la forma `columna`.

### P3 · Impacto de hielo (Pipeline)

- **Cristales irregulares**: uno grande (0,7–0,9 u) inclinado 15–25° hacia donde venía la bola y 3–5
  pequeños (0,25–0,45 u) a radio 0,2–0,55 con jitter, escalonados 0,05–0,08 s con el `TRANS_BACK` actual.
- **Marca `escarcha`** nueva (tercera marca del kit, junto a `quemado` y `mojado`): disco blanco de borde
  irregular (Voronoi del propio shader de la costra), 1,2 u, que **se derrite de fuera adentro en 6 s y
  deja `mojado` 3 s**. Hielo → agua, coherente con la simulación.
- **Destellos de cuatro puntas**: 3–4 `destello` de 0,15 u sobre los cristales, cada uno 0,12 s, en momentos
  al azar mientras viven (sparkle EoW/LA).
- **Vaho**: 4–6 partículas de niebla (la `nube` de Formas3D, alfa 0,25, azul grisáceo) subiendo a 0,4 u/s
  durante 1,5 s.
- **Fundirse = romperse**: a los 7 s, 0,3 s de grietas (oscurecer + escala 1,03) y `_fragmentos("hielo")`,
  que ya existe para el aro sólido, más un `mojado` de 0,6 u. Quitar `circulo_runico`.

### P4 · Agua helada y costra (Pipeline)

Paleta de hielo de arriba en `agua_render_3d.gd` y `costra_hielo_3d.gd` (contraste H5); **sparkle por
texel** en el agua helada (hash temporal: 1–2 puntos blancos por casilla que parpadean 0,1 s cada 1–3 s);
al soltarse (G < 0,15 ya abre grietas) añadir **fragmentos y vaho** en la casilla (`VfxPuzle3D.vapor` teñido
frío sirve). El tapón de hielo y la compuerta de hielo de `PiezaPuzle3D` (`"derritiendose"`) usan lo mismo.

### P5 · `vfx_elementos/rayo.gd` y `hielo.gd` (Pipeline)

Los dos elementos entran en el kit como fuego y agua (y se unifican con la tabla `PERFIL` de
`ConjuroVfx3D`, como pedía la entrada 108):

- **rayo**: `rampa` azul → cian → blanco cálido; `perfil` luz cian, charco azul, aro blanco, partícula
  `chispa_electrica` aditiva, marca `quemado`, `mult` velocidad 2,0 y suave 0,5 (bordes duros); `bola` =
  esfera pequeña blanca con **2–3 arcos orbitando que se re-barajan a saltos** y estela de chispas;
  `alto_muro` × 1,2 y `ajustar_tira` = cortina de arcos verticales que se encienden por tramos (reutiliza el
  shader de `CODIGO_ENERGIA`).
- **hielo**: `rampa` azul hondo → claro → blanco; `perfil` luz fría, partícula `copo` no aditiva, marca
  `escarcha`, `fijar` facetas 4, `mult` velocidad 0,15 (casi quieto); `bola` = **carámbano facetado**
  (forma `cristal`) girando lento con copos detrás; muro = pared de puntas (ya descrito en l. 1242) con
  escarcha en la base.

### P6 · Piezas de puzle (Juego, sin esperar)

`NexoRayo3D` pasa a `PiezaPuzle3D.crear("pila")` con `"mojada"`/`"seca"`/`"electrificada"` (entrada 98) y
deja su disco amarillo; `EmisorRayo3D._pintar` desaparece cuando exista P1 (hasta entonces, al menos el
color de las losas pasa al cian con alfa 0,3 para no pelearse con el hechizo). Tótem y emisor: arco
visible entre bornes mientras conducen (pieza `rayo` 0,4 u re-barajada), que es el "estoy encendido" de
las referencias.

## 4. Assets: ¿hace falta comprar o descargar algo?

No. `Formas3D` ya tiene `rayo`, `cristal`, `destello`, `copo` y `nube`, el agua helada y la costra ya
tienen el Voronoi, y la línea del 6/10 es "nada de sprites planos". Todo lo de arriba es código. Si el
Pipeline quiere mirar cómo lo resuelven otros:

- Shaders de arcos procedurales por fragmento: [Lightning Ball](https://godotshaders.com/shader/lightning-ball/)
  y la etiqueta [electricity](https://godotshaders.com/shader-tag/electricity/) de godotshaders (para las
  venas de P1 si el ruido propio no da la pinta; licencias por shader, casi todas MIT/CC0).
- Hielo: [Spatial Ice Shader](https://godotshaders.com/shader/spatial-ice-shader/) (godotshaders) y
  [Godot 3D Ice Material Shaders and VFX](https://dragonforge-development.itch.io/godot-3d-vfx-ice-shaders)
  (CC0, Godot 4.3, el nivel gratis trae material de hielo sólido, muro y suelo; sirve para comparar
  parámetros de fresnel/especular, no para meter tal cual: es realista, no de juguete).
- Sprites de chispa/estrella/humo si alguna vez hacen falta: Kenney Particle Pack (CC0).

## 5. Lo que pone el Juego (datos, no dibujo)

- `EmisorRayo3D`: la señal `descarga(celdas)` pasa a llevar también el **orden** de cada casilla
  (`Dictionary` celda → pasos desde el emisor, que `agua_conectada` ya calcula al recorrer), y una señal
  `fin_descarga`. Con eso el render pinta el frente (P1.3) y apaga a tiempo. `_pintar` se retira cuando
  el render asuma el tinte.
- `NexoRayo3D`: usar `PiezaPuzle3D` (P6). `Terreno3D.conductores` no cambia.
- Lab Q7: nada; el cartel ya explica el nexo.

## 6. Decisiones de Pablo

1. Paleta del rayo: **arco blanco-amarillo + campo azul** (recomendada) o todo cian como la bola actual.
2. Orden: propongo **P1 → P2 → P3 → P6 → P4 → P5** (lo primero es lo que se ve en los puzles; P5 es
   estética del conjuro).
3. Si la escarcha debe **mojar de verdad** la simulación al derretirse (un `PROF_CHARCO` en la casilla) o
   solo pintarse. Propongo solo pintarse: un charco real en cada impacto de hielo llenaría cuencas sin querer.

## 7. Prompt para el Pipeline (copiar tal cual)

> Mejora de VFX de rayo y hielo (Fase 14, `presentacion/`). Lee `docs/DIARIO.md` desde la (96) y este
> encargo. Paleta: arco de rayo blanco cálido (1, 1, 0,9) con filo amarillo (1, 0,93, 0,4); campo/bruma/
> tinte azul (0,2, 0,45, 0,95 → 0,5, 0,82, 1,0); hielo claro (0,86, 0,93, 0,99), hondo (0,55, 0,74, 0,92),
> grieta (0,25, 0,5, 0,85).
> **P1** `agua_render_3d.gd`: textura `electrico_t` (R/G = segundo de entrada/salida, como `hielo_t`) que
> tiñe el agua a cian con pulso 6 Hz y dibuja venas blancas con el ruido a saltos de 0,08 s; sin rejilla.
> `vfx_3d.gd`: `arcos_agua(celdas)` = 3–6 piezas `rayo` tumbadas entre casillas vecinas, re-barajadas cada
> 0,08 s, tope 6; una luz cian por descarga. Entrada: `EmisorRayo3D.descarga(celdas, orden)` (el Juego la
> expone; retraso por casilla = orden × 0,04 s).
> **P2** `_impacto_rayo`: estallido radial (5–7 arcos cortos de pie re-sorteados 3 veces a 60 ms, `_onda`
> cian 0,3→1,6 u en 0,25 s, destello blanco 2 cuadros, 10 chispas, luz 0,3 s, temblor 0,05); marca `quemado`
> 0,6 u / 3 s solo en suelo. El rayo del cielo queda para `tormenta` y `columna`.
> **P3** `_impacto_hielo`: 1 cristal grande (0,7–0,9 u, inclinado 15–25°) + 3–5 pequeños con jitter,
> escalonados 0,05–0,08 s; marca nueva `escarcha` (disco Voronoi 1,2 u que se derrite de fuera adentro en
> 6 s y deja `mojado` 3 s); 3–4 destellos de 4 puntas de 0,12 s; vaho (4–6 `nube` alfa 0,25 subiendo
> 0,4 u/s, 1,5 s); al fundirse, 0,3 s de grietas + `_fragmentos("hielo")` + charco. Quitar `circulo_runico`.
> **P4** Paleta nueva en `agua_render_3d.gd` y `costra_hielo_3d.gd`; sparkle por texel en el agua helada;
> fragmentos + vaho al soltarse.
> **P5** `vfx_elementos/rayo.gd` y `hielo.gd` (extienden `ElementoVfx`, se añaden a `VfxKit3D.ELEMENTOS`)
> y que `ConjuroVfx3D` lea de ahí. Bola de rayo: esfera blanca con 2–3 arcos orbitando a saltos; bola de
> hielo: carámbano facetado con copos.
> Presupuesto: ≤ 6 arcos y 1 luz por descarga; nada vivo 10 s después del último efecto (prueba headless
> `herramientas/prueba_vfx_rayo_hielo.gd` que cuente nodos, más `captura_*`). Entrada en `docs/DIARIO.md`
> con firmas nuevas; sin commit.

— Juego
