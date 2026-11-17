# Revisiones pendientes — VFX de los elementos (18/11/2026)

Rama `hechizos/cuatro-elementos`. Lista de todo lo hecho entre el 16 y el 18/11 que **Pablo no ha aceptado todavía** (se subió para poder mirarlo, pero subir no es aceptar).
Cada punto dice dónde verlo en el lab, qué queda dudoso y su entrada del diario. Marca `[x]` lo que des por bueno y anota al lado lo que haya que cambiar.

**Cómo mirarlo:** `tools\Godot_v4.7.2-stable_win64.exe --path <worktree> res://laboratorios/LabVfxComparativa3D.tscn`. `Z` cambia de elemento, `F7` pasa de figura
(bola → muro → pilar → barrera → haz), `F9` lanza un hechizo de ejemplo, `V` hace morir la figura, `C` cambia de cámara, `H` esconde el panel.

**Ya aceptado (no está en la lista):** pilar de fuego de una lengua y muro de fuego denso (509, 510), muro más recto con ruido y llamas más rápidas (512), tierra con el material de la línea (511).

## Fuego (cerrado «de momento» por Pablo el 18/11; nada de esto está aceptado)

- [ ] **Pilar: inicio y final** (513) — anillo de aviso que se cierra, chorro fino que sube y engorda; al morir se corta por la base. *Dudas:* las chispas y los trocitos claros salen ya durante el aviso; las llamitas de la base tardan todo el final en irse; el pilar bajo y ancho no se ha mirado.
- [ ] **Pilar: grietas en el suelo** (514) — salen oscuras, se encienden, viven bajo el pilar y se enfrían al morir. *Dudas:* el dibujo es radial y se lee como una flor (la referencia eran rayos quebrados); son un plano, no se pegan al relieve; sin destello del reventón ni cascotes; naranja rojizo en vez del amarillo de la referencia (regla de Pablo).
- [ ] **Pilar: muere en humo y deja rescoldo** (515, 516) — el chorro se suelta mientras sale humo toon pardo; grietas y humo quedan 1,5 s. *Dudas:* el fuego se va un poco antes de que el humo lo tape; el aumento a 20 bocanadas no se recapturó; si el juego reutiliza el nodo del pilar, se quedaría sin grietas (sin comprobar).
- [ ] **Pilar: más ruido en el contorno** (516).
- [ ] **Muro: grietas a los dos lados** (515) — *Dudas:* finas desde la cámara del juego.
- [ ] **Muro: inicio y final** (517) — grietas que corren del centro a los extremos, muro en cremallera, retirada al centro con humo y rescoldo. *Dudas:* chispas durante el aviso; las láminas de relleno no hacen cremallera; solo visto el muro de referencia.
- [ ] **Todos los hechizos plantados, +20 % de altura de dibujo** (508) — *Dudas:* es solo dibujo (la lógica no cambia); el viento ya llevaba +50 % y ahora se suma.
- Sin hacer: inicio y final de la **barrera** y de la **línea** de fuego.

## Agua y viento

- [ ] **Muro de agua: altura y espuma en la cresta** (507) — cresta que ondula, cabrillas que corren, vetas verticales. *Dudas:* la onda viajera solo está vista en fotogramas sueltos; el muro de referencia sigue viéndose bajo desde la cámara del juego.
- [ ] **Columnas bajas y anchas de agua y de viento** (506).
- [ ] **Arreglo de lógica: la marca del agua de hechizo contaminaba cauces y estanques** (506) — con su prueba (`prueba_agua_hz_cauce`). *Dudas:* no se repitió la prueba de la gruta ni el recuento de casillas mojadas de PruebaBosque.
- Sin hacer: inicio y final de agua y de viento en todas las formas; el muro de agua que moja hacia delante (lógica).

## Tierra

- [ ] **Carga: las piedrecitas salen del anillo del suelo** (518) — tecla `G`. *Dudas:* las piedras del anillo no se gastan; suben rectas, sin arco.
- [ ] **Pilar: columna prismática acabada en pico** (519) — *Dudas:* el aviso es corto (la marca sale a la vez que el temblor); el final es hundirse, no romperse; solo visto el pilar de referencia.
- [ ] **Muro: inicio lento con grieta y polvo, final en estallido** (520) — *Dudas:* grieta fina y polvo discreto; el nacer de 1,3 s cuenta dentro de la vida del hechizo.
- [ ] **Toda la tierra con los estratos de la línea** — aceptado el 17/11, pero *sin mirar en el Bosque*, donde ya no casa con los pedruscos grises del mapa; en rocas muy estiradas las franjas salen muy anchas.
- Sin hacer: barrera, línea y bola de tierra.

## Hielo

- [ ] **Figura nueva «suelo»: placa de hielo** (521) — tecla `Insert` (otra pulsación la rompe). *Dudas:* solo dibujo: ni se pisa, ni flota, ni la crea ningún hechizo.
- [ ] **Efecto de congelado** (522) — tecla `Supr`, o el dummy con hielo. *Dudas:* no visto sobre un enemigo de verdad; la costra son bolas de hielo, no envuelve la forma del cuerpo; asoma algún cuadradito lila sin explicar.
- [ ] **Haz de hielo = viento helado, sin cristales** (523, 526) — ráfagas, copos y vaho estirado; *las ráfagas son muy finas y casi no se ven en fotogramas*. *Dudas:* **no está comprobado en el juego que el haz congele a un enemigo y a un objeto** (se deduce del código y de las pruebas); el efecto sobre objetos tiene tamaño fijo y no se ha visto; no hay impacto propio (escarcha que se extiende).
- [ ] **Muro: inicio y final** (524) — *Dudas:* vaho escaso; la escarcha del aviso es una elipse que se estira.
- [ ] **Haz: sello en la mano y corona de cristales donde da** (528) — *Falta:* el gesto de extender la mano (animación del personaje, sin hacer); la corona no se recoloca si el haz da antes en un enemigo o un muro.
- [ ] **Barrera sin cúpula** (527) — *Dudas:* queda abierta por arriba, ya no cierra como un domo.
- Sin hacer: pilar, barrera y bola de hielo; enlazar «suelo» a una forma o a una plataforma.

## Laboratorio

- [ ] **Dummy de estados** (525) — `Intro` le aplica el elemento actual; `Mayús+Intro` lo limpia; `Ctrl+Intro` lo quita. *Dudas:* usa la runa de serie (sin glifos) y las reglas de un enemigo normal, no las del gólem, el limo o el elemental; no recibe daño ni se empuja.

## Pruebas que fallan y no vienen de estos cambios (comprobado con el código anterior)

- `prueba_magma_toy`: 23 fallos (tiempos de nacer y liberarse).
- `prueba_golem_combate`: 7 fallos.
- `prueba_limo_combate`: intermitente (falló 3 de 4 pasadas con el código original).
- `prueba_viento_tierra_toy`: una vez falló «[viento] en vuelo la estela…»; no se repitió en cinco pasadas.
- `prueba_haz_tamano`: 0 fallos, pero a veces el motor se cierra de golpe al salir (12 de ~75 pasadas el 19/11, a rachas); no usa el hielo y no se sabe la causa.
- `prueba_agua_toy`: el fallo intermitente de la bola no se reprodujo; queda un diagnóstico extra en la prueba.

## Lo que ninguna de estas cosas tiene

Todo está visto **en fotogramas del lab**, no en movimiento, ni en el juego, ni en la 3070. Las capturas están en `docs/capturas/` (carpetas con fecha 2026-11-16 a 2026-11-18).
