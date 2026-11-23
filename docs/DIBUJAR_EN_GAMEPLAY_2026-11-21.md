# ¿Dibujar funciona en el juego? Cómo responderlo (21/11/2026)

21/11/2026 · contexto **dirección (análisis)** · **propuesta de prueba, nada construido**. Sale de los análisis de *Mages of Mystralia* y *Echoes of Mystralia* y del playtest del 14/11.

**La preocupación (Pablo):** una idea «guay» puede romperse en juego porque corta el flujo. A Borealys le pasó dos veces. ¿Nos pasa con el dibujo?

---

## 1. Lo que ya está decidido y cambia la pregunta

**Desde el 5/11 el libro no se abre en combate** (`Lanzador3D.LIBRO_EN_COMBATE = false`, `magia/lanzador_3d.gd:773-777`). Si empieza un combate con el libro abierto, se cierra sin lanzar, y en combate se lanza con 1/2/3. La regla en el código dice: **«el libro es para preparar, no para combatir»**.

Es la misma conclusión a la que llegaron los otros juegos:

| Juego | Dónde se compone el hechizo | Dónde se ejecuta |
|---|---|---|
| *Arx Fatalis* | Gesto con calma, se guarda en 3 ranuras | Botón |
| *Okami HD* | Gesto para lo especial | Botones para atacar |
| *Mages of Mystralia* | Menú de runas (los jugadores **pausaban el combate** para retocar) | Botones |
| *Echoes of Mystralia* | Rejilla, **entre partidas** | Botones |
| *Lost Magic* (DS) | Dibujar **en pleno combate**, con reconocimiento tolerante | Lo mismo: dibujar es atacar |
| **Magic Symbols** | **Libro, fuera de combate** | **Páginas 1/2/3** |

Así que la pregunta «¿dibujar en combate rompe el flujo?» ya la contestaste tú el 5/11: sí, y por eso se sacó del combate. Lo que queda abierto es **otra pregunta, más difícil**:

> **¿Lo que se dibuja fuera del combate cambia lo que pasa dentro?**

Si la respuesta es no, el dibujo es una pantalla de equipo bonita y el combate se juega con tres botones, que es justo lo que se vio en el playtest (todo con fuego + flecha). Si la respuesta es sí, el dibujo es el corazón del juego también en combate, aunque no se dibuje durante la pelea.

---

## 2. Las cuatro preguntas que hay que contestar

| # | Pregunta | Si sale mal, significa… |
|---|---|---|
| **P1** | **¿La jugadora prepara?** ¿Reescribe páginas entre encuentros según lo que viene? | Dibuja una vez y se olvida: el dibujo no da decisiones. |
| **P2** | **¿Las tres páginas se usan?** ¿O una se lleva casi todos los lanzamientos? | Una receta lo resuelve todo: el problema es de diseño de enemigos, no del dibujo. |
| **P3** | **¿Dibujar cuesta demasiado?** Tiempo por página, trazos mal reconocidos, dibujos abandonados. | El dibujo corta el flujo aun fuera del combate: hay que abaratarlo. |
| **P4** | **¿Se echaría de menos?** Si las mismas páginas se eligieran de una lista, ¿sería igual de divertido? | El dibujo no aporta al juego, solo a la estética. |

**P4 es la decisiva** y la más honesta: compara con una versión sin dibujo. Si nadie nota la diferencia, ya sabemos la respuesta.

**Señal extra que ya existe:** cuántas veces se intenta abrir el libro en combate y se rechaza (`_rechazar_libro_en_combate`). Muchos intentos = la jugadora **quiere adaptarse a mitad de pelea**. Eso es un buen síntoma (el dibujo importa) y a la vez una frustración que habrá que atender.

---

## 3. Qué mide hoy el juego y qué falta

`nucleo/estadisticas.gd` cuenta enemigos, hechizos por elemento, daño hecho y recibido, oro, muertes, cofres y tiempo. **No cuenta nada del libro.** Para responder hace falta añadir estas cifras (solo contar; ninguna regla cambia):

| Cifra nueva | Para qué pregunta | De dónde sale (a comprobar al programarlo) |
|---|---|---|
| Veces que se abre el libro y segundos con él abierto | P1, P3 | `Lanzador3D.libro_abierto()` |
| Páginas reescritas (una página cambia de receta) | P1 | el grimorio al cerrar |
| Lanzamientos **por página** (1, 2, 3) y **por receta distinta** | P2 | señal `lanzado` + página activa |
| Encuentros en que se usó más de una página | P2 | `Sensacion3D.enemigos_en_combate` para saber cuándo empieza y acaba un encuentro |
| Trazos no reconocidos o borrados | P3 | el reconocedor del libro |
| Segundos por página dibujada (de abrir a cerrar con cambios) | P3 | libro |
| Intentos de abrir el libro en combate | señal extra | `_rechazar_libro_en_combate` |

Se guardan en `por_nivel` como lo demás, y se pueden ver en el resumen del nivel. Coste: bajo.

---

## 4. La prueba

### 4.1 Dónde
En **su propio mapa de prueba** (como `SalaLimo.txt` o `SalaGolem.txt`), nunca en el Bosque ni en Sumicio. Propuesta: `SalaDibujo.txt` con:
1. **Cuatro encuentros en fila**, cada uno visible **desde un sitio tranquilo antes de entrar**, para que tenga sentido preparar:
   - uno que pida **fuego** (goblins con escudo de madera, si se aprueban los escudos de elemento);
   - uno que pida **agua** (un limo de fuego o un incendio en la hierba);
   - uno que pida **tierra** (un enemigo con armadura o que haya que empujar contra algo);
   - uno **mezclado**.
2. **Solo fuego, agua y tierra**, como la demo.
3. Una **página cada vez menos útil**: ninguna receta sola gana los cuatro encuentros con comodidad.

### 4.2 Dos versiones
- **A, como ahora:** libro libre fuera de combate.
- **B, sin dibujo:** el libro no deja dibujar y ofrece **las mismas recetas ya hechas** para elegir de una lista. Se puede montar con un kit cerrado (ya existe la idea de `kit` por nivel).

Cada persona juega las dos, en distinto orden según la persona (la mitad empieza por A y la otra mitad por B), para que el orden no decida.

### 4.3 Con quién
**De 3 a 5 personas que no hayan jugado**, no tú. Tú miras sin explicar nada (lo que haga falta explicar, lo tiene que explicar el juego). Unos 20 minutos por persona.

### 4.4 Tres preguntas al acabar
1. ¿Qué versión te ha gustado más y por qué?
2. ¿Ha habido algún momento en que dibujar te haya molestado?
3. ¿Has cambiado tus páginas? ¿Por qué sí o por qué no?

### 4.5 Cuándo se da por bueno (umbrales de partida, para que los decidas tú)

| Pregunta | Bien | Mal |
|---|---|---|
| P1 prepara | Reescribe al menos una página en 2 de cada 4 encuentros | Nunca reescribe tras la primera vez |
| P2 usa las tres | Ninguna página pasa del 60 % de los lanzamientos | Una pasa del 80 % |
| P3 coste | Menos de 15 s por página y menos del 10 % de trazos no reconocidos | Abandona dibujos o se queja del reconocimiento |
| P4 se echa de menos | La mayoría prefiere A y lo explica por el dibujo | Prefieren B o les da igual |

---

## 5. Qué hacer según el resultado

| Resultado | Lectura | Qué hacer |
|---|---|---|
| **P1–P4 bien** | El dibujo funciona como preparación | Seguir. Invertir en enemigos que pidan páginas distintas. |
| **P3 mal, el resto bien** | La idea funciona pero cuesta | Abaratar: reconocimiento más tolerante, recordar las últimas páginas, copiar una página a otra, glifos más cortos. |
| **P1 y P2 mal, P4 bien** | Gusta dibujar, pero el combate no lo pide | **No es un problema del dibujo, es de enemigos.** Escudos de elemento, enemigos con varias soluciones, enemigos que escriben suelo (ver `REFERENCIAS_JUEGOS` §4). |
| **Muchos intentos de abrir el libro en combate** | Quieren adaptarse a mitad de pelea | Valorar un respiro: un libro rápido de una sola página, o puntos seguros a mitad de encuentro. No volver a abrir el libro entero en combate. |
| **P4 mal** (B gusta igual o más) | El dibujo no aporta al juego | Dejar el dibujo para lo que sí funciona (puzles, exploración, descubrir reacciones) y aceptar que el combate se prepara con menos fricción. **Es una respuesta válida**, no un fracaso: *Okami HD* hizo lo mismo. |

---

## 6. Lo que ya sabemos sin hacer la prueba

- **En puzles y exploración funciona**: el playtest del 14/11 dice que el flujo de recoger, puzles y pelear es divertido.
- **En combate hoy no da decisiones**: «todo con fuego + flecha». Pero eso puede ser culpa de los enemigos y no del dibujo. La prueba sirve para separar las dos causas.
- **La tolerancia de entrada ya está en parte**: las páginas guardan la pulsación 0,15 s (`BUFFER_PULSACION`).
- **Los otros juegos** dicen que componer con calma y ejecutar con botones funciona. Lo que no hemos medido es si nuestros encuentros **piden** recomponer.

## 7. Preguntas para ti

1. ¿Te parecen bien las cuatro preguntas y los umbrales, o cambiarías alguno?
2. ¿Juegas tú con ratón o con mando? Si hay mando, el coste de dibujar (P3) puede ser muy distinto y habría que probar los dos.
3. ¿Hago primero las cifras nuevas (§3)? Son baratas y sirven también para cualquier playtest futuro, haya prueba A/B o no.
