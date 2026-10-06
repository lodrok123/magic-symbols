# Test 2: laboratorio de elementos (40 x 40)

Escena `Test2.tscn` (script `test_2.gd`). Se empieza en la aldea del sur con **todos** los sellos y glifos.
Seis cámaras, una por elemento; la puerta del norte se abre con las seis pruebas superadas.

| Cámara | Qué hay | Qué pide | Cuenta como superada cuando |
|---|---|---|---|
| FUEGO (noroeste) | telaraña en la entrada, fila de setos secos, tótem de fuego | quemar para pasar | el tótem de fuego se enciende |
| AGUA (oeste) | muro con hueco cerrado por barrera de fuego, tótem de agua | apagar la barrera | el tótem de agua se activa |
| TIERRA (suroeste) | foso de agua de 2 y una placa de PESO | cruzar y poner un bloque de tierra en la placa | hay un bloque de tierra (o empujable) sobre la placa |
| VIENTO (noreste) | 3 fogatas, canal de agua de 3, 3 antorchas en la isla | que el viento lleve la llama | las 3 antorchas encendidas |
| RAYO (este) | río con puente plegado, tótem de rayo | electrificar el tótem | se tiende el puente |
| HIELO (sureste) | río de 4 casillas | congelar un camino | 4 casillas del río heladas |

Plaza central: goblins con IA (guerreros y arqueros), plantas reactivas. Aldea: puestos de la librera y
del alquimista con el tendero al norte, guardabosques (encargo: 3 goblins), dummy, guardado.

Cada prueba se apunta en PlayLog: `"prueba", {elemento, segundos}`.

## Comprobado automáticamente
Lanzando los hechizos reales desde un script se superan las seis pruebas y se abre la puerta.
Para el hielo hacen falta 4 lanzamientos (una flecha de hielo congela una casilla).

## Preguntas para sacar conclusiones mientras se juega
(Respuestas medidas el 4 de octubre al final del documento.)
1. **¿Se entiende qué pide cada cámara sin leer el rótulo?** Si no, falta arte que lo cuente (ver assets). -- Mejorar hielo no es entendible. Añadir un paso intermedio a lanzar un hechizo de forma que el flujo 
2. **Solapes:** el hielo también cruza el foso de la tierra y el canal del viento (se puede andar sobre el
   agua helada y encender las antorchas con fuego directo). La tierra también cruza el río del hielo con
   pasaderos. ¿Está bien que haya varias soluciones, o cada elemento necesita algo que SOLO él haga?
   Ideas: la tierra como cobertura contra arqueros o como escalón para subir a sitios altos; el viento para
   mover cosas ligeras (molinos, nubes de esporas, apagar velas a distancia); el hielo para frenar enemigos
   o hacer resbalar bloques.
3. **Ritmo:** apunta los segundos de cada prueba. Una que cueste más de un minuto, o que se resuelva por
   casualidad, hay que rediseñarla.
4. **Coste del hielo:** ¿4 lanzamientos para cruzar se sienten bien o pesados? (Alternativa: que la barrera
   de hielo congele una fila entera.)
5. **Lectura del fuego:** los setos arden en cadena; ¿se ve venir el contagio o sorprende? -- se pierde el cont
6. **Combate en la plaza:** ¿la barra de vida y el rombo de debilidad se leen a la distancia de juego?


---

## Respuestas (medidas el 4 de octubre de 2026)

**Cómo se midió.** No es una partida a mano: es una partida automatizada que lanza los hechizos REALES
(`SpellFactory` / `SpellRecipe`) sobre el nivel y cronometra la simulación, más el recorrido a pie calculado
sobre el plano (velocidad del jugador 100 px/s → 0,64 s por casilla). Lo que depende de ojos humanos
(si algo "se entiende" o "se siente bien") queda marcado como **pendiente de jugarlo tú**.

### Cronómetro
| Prueba | A pie desde el inicio | Lanzamientos mínimos | Espera de la simulación |
|---|---|---|---|
| Fuego | 22,5 s | 3 (telaraña, seto, tótem) | telaraña 1,7 s · hueco en el seto 4,2 s · los 10 setos 8,2 s |
| Agua | 19,3 s | 3 (cada barrera B pide **su** flecha, + tótem) | ~1 s por barrera |
| Tierra | 9,0 s | 3 (2 pasaderos o 2 hielos para el foso, + bloque en la placa) | inmediata |
| Viento | 25,0 s | 2 (una flecha de viento enciende 2 de 3 antorchas) | ~2 s |
| Rayo | 19,9 s | 1 | inmediata (se tiende el puente) |
| Hielo | 10,3 s | **1 con barrera** (congela 7 casillas) · 4 con flecha | inmediata |

Recorrido completo en buen orden (tierra → agua → fuego → viento → rayo → hielo → puerta): **141 casillas ≈ 90 s
andando**, más unos **13 lanzamientos**. Con 3-4 s por abrir el grimorio y dibujar, una persona que ya sabe la
solución tarda **unos 2,5-3 minutos**. Ninguna prueba pasa del minuto ni se resuelve sola.

### 1. ¿Se entiende qué pide cada cámara sin leer el rótulo?
**Pendiente de jugarlo tú.** Lo que sí se puede decir: hoy cada cámara se explica con **texto** (rótulo en la
entrada + lista del HUD), no con el mundo. Fuego, agua y rayo se leen solos (telaraña/setos, muro de llamas,
tótem junto al río). Tierra (una placa gris con la palabra "PESO") e hielo (un río sin nada más) dependen del
rótulo. Es lo que más arte pide (ver `ASSETS_PENDIENTES.md`: placa de peso, losas de prueba, carteles).

### 2. Solapes entre elementos
**Confirmado midiendo:**
- **El hielo resuelve el viento:** congelando el canal se anda hasta la isla y una flecha de fuego enciende la
  antorcha directamente. El viento no es necesario.
- **El hielo cruza el foso de la tierra** (cada flecha congela una casilla). La tierra sigue siendo necesaria
  **solo para la placa de peso**: esa es hoy su única función exclusiva.
- La tierra puede cruzar el río del hielo con pasaderos, pero la prueba de hielo no cuenta pasaderos: ahí no hay
  trampa.
- Fuego, agua y rayo **no tienen sustituto** (tótems que solo responden a su elemento; barrera que solo apaga el agua).

**Conclusión:** el hielo es el comodín (cruza cualquier agua). Para que el viento tenga papel propio, la isla
no debería ser alcanzable andando (antorchas tras una reja o en alto), o el viento tiene que hacer algo que nadie
más hace (mover cosas ligeras, apagar a distancia, llevar llama alrededor de una esquina).

### 3. Ritmo
Medido arriba: la prueba más lenta es el **fuego (~8 s de espera viendo arder la fila)**, el resto es inmediato.
Nada se resuelve por casualidad salvo un detalle: **una sola flecha de viento enciende 2 de 3 antorchas**
(el viento contagia la llama a la antorcha vecina), así que la tercera se siente "regalada" o "a medias".
Falta tu tiempo real con el grimorio para saber cuánto pesa dibujar.

### 4. Coste del hielo
Con **flecha: 4 lanzamientos** (una casilla cada uno). Con **barrera: 1** (congela 7 casillas de golpe), y con
flecha + repetición 1 lanzamiento también. O sea: la alternativa que proponía el documento **ya existe**; la
prueba enseña (sin decirlo) que la barrera rinde más. Si se quiere que el hielo cueste, subir
`HIELO_NECESARIO` no sirve: habría que hacer el río más ancho que una barrera.

### 5. Lectura del fuego
La telaraña cae en 1,7 s y el seto abre hueco en 4,2 s, pero **la fila entera de 10 setos arde en 8,2 s**: el
contagio llega a todo el seto. **Pendiente de jugarlo tú** si se ve venir; por datos, el riesgo es que el
jugador lance al tótem antes de que se apague la fila y la flecha muera contra un seto en llamas.

### 6. Barra de vida a distancia de juego
Medido en captura a la cámara de juego (zoom 1,45): la barra mide **entre 100 y 150 px en pantalla** (según la resolución de la ventana) con marco negro y el
rombo de debilidad de 20 px al lado; se lee bien incluso con dos goblins en pantalla. El nombre solo aparece al
recibir daño (y siempre en el dummy).
