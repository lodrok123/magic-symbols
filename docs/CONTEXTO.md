# Magic Symbols — contexto del proyecto

**FUENTE DE VERDAD.** Tres documentos, cada uno con su tiempo verbal:

| documento | cuenta |
|---|---|
| `docs/CONTEXTO.md` (este) | cómo se trabaja, vocabulario, estado en una pantalla |
| `ARQUITECTURA.md` | **lo que el código hace hoy**, sistema por sistema, con el porqué de cada decisión (revisado y aceptado el 4/10/2026) |
| `docs/DISENO_FUTURO.md` | **lo que se quiere que haga**: la cola de sistemas por implementar, con coste y decisiones pendientes |

`docs/NUEVOS_SISTEMAS.md` es la chuleta de escenas, letras del plano y
teclas. `docs/PROPIETARIOS.md` dice qué contexto toca qué archivo. Si dos
documentos se contradicen, manda `ARQUITECTURA.md` para el presente y
`DISENO_FUTURO.md` para el futuro; este archivo se corrige.

Última revisión: 4 de octubre de 2026.

---

## Qué es

Prototipo de aprendizaje en **Godot 4.7**, 2D isométrico. Se dibujan
símbolos con el ratón para lanzar hechizos: un **sello** (el elemento) en
el núcleo del grimorio y uno o más **glifos** (la forma) en los ocho
sectores de la corona. Inspiración: Magicka (combinar), Witch Hat Atelier
(el trazo importa), Breath of the Wild (reacciones físicas); para puzles,
Zelda y Genshin Impact.

Lo escribe una sola persona que está aprendiendo. **El objetivo no es
terminar el juego: es entender lo que se construye.**

## Vocabulario (el de ahora)

| palabra | qué es | ejemplos |
|---|---|---|
| **sello** | el ELEMENTO, se dibuja en el núcleo | fuego, agua, viento, rayo, tierra, hielo (y tiempo, fuera de la progresión) |
| **glifo** | la FORMA, se dibuja en un sector | flecha, barrera, levitación, pilar, rebote, retardo, pulso, atracción, espejo, repetición, amplificar |
| grimorio, núcleo, corona, sector, runa, losa, maleza | como siempre | |

**Ojo:** el código antiguo (`repertoire.gd`, `sigils.gd`, `spellbook.gd`,
`spellcaster.gd`) llama `sigil` o "sello" a la forma. Los niveles, el HUD,
`ARQUITECTURA.md` y `README.md` ya usan el vocabulario de arriba. No se ha
renombrado el código a propósito (cambio grande sin ganancia de juego).

**Regla del grimorio (decidida el 4/10/2026): un glifo por sector.** Cada
sector es un hueco; una vez dibujado un glifo, dibujar encima no hace nada
y el clic derecho lo borra. El tope de glifos por página es
`Repertoire.max_sigils_per_page` (hasta 6). Los glifos de una página se
combinan **entre sectores** en una sola receta cuando se apunta con el
ratón; detalle y consecuencias en `DISENO_FUTURO.md` §3.

## Cómo trabajar en esto

- **Todo en español**, código y comentarios incluidos.
- **Explicar el porqué, no sólo el qué.** Qué se descartó y por qué.
- **Medir antes de afirmar.** Estimar a ojo produjo errores todas las
  veces que se intentó.
- **Verificar antes de escribir en el proyecto.** En la sesión en la nube
  hay un **Godot 4.7 sin ventana**: se comprueba que cada script compila,
  se arrancan las escenas con scripts de prueba (lanzando los hechizos
  reales) y se sacan capturas con `xvfb`. Los personajes del pipeline no
  están en la nube (salen como cuadrados de color), así que su aspecto se
  revisa en el ordenador.
- **Elegir mirando, no adivinando.** Barrido de opciones renderizado y se
  decide sobre la imagen.
- **Cambios mínimos.** No tocar lo que no se ha pedido.
- **Decir lo que cuesta cada decisión**, no sólo lo que gana.
- **Los commits de git los hace él.** Nunca hacer commit ni push.
- **Subir archivos con Godot cerrado**, y abrir Godot después para que
  reimporte el arte nuevo.
- Siempre decir **dónde** queda cada archivo entregado.
- Varias conversaciones tocan el proyecto a la vez: **antes de escribir un
  archivo, comparar con la versión del ordenador** (no pisar cambios ajenos).
- **Dos contextos, un dueño por archivo.** El reparto está en
  `docs/PROPIETARIOS.md`; lo que un contexto necesita del otro se apunta en
  `docs/DIARIO.md` (leerlo al empezar, escribirlo al terminar). Los
  cambios son parciales: nunca reescribir un archivo entero desde una copia
  de la conversación.
- **No crear documentos nuevos en `docs/` sin proponerlos antes.** Hay un
  plan (`PLAN_ARREGLOS.md`), un diario y un diseño futuro; lo nuevo va
  dentro de ellos. Un documento nuevo se propone en el diario con su nombre,
  su dueño y qué no cabía en los existentes, y lo crea Pablo o quien él
  diga (regla 7 de `PROPIETARIOS.md`).

## Dónde vive

```
C:\Users\pablo\Documents\magic-symbols
```

**Es la única carpeta de trabajo**, en cualquiera de sus ordenadores. Entre
ordenadores viaja por **git + GitHub** (`lodrok123/magic-symbols`, privado):
Pablo ejecuta `SUBIR_A_GITHUB.cmd` al terminar y `BAJAR_DE_GITHUB.cmd` al
empezar; los chats no hacen commit ni push. La copia que hay en
`OneDrive\Documentos\magic-symbols` es un resto del 5/10 y **no se usa**: si
la carpeta conectada a la sesión es esa, decirlo y no escribir.

**Puede no ser el ordenador que tenga delante.** El puente sólo llega a la
máquina enlazada a la sesión: comprobar las carpetas conectadas y confirmar
la ruta antes de tocar nada.

## Cómo está escrito el código

**Datos antes que condicionales.** Añadir un elemento es un `.tres`.
Añadir un glifo es una línea en `Sigils`. Un nivel es un plano de letras.

**Las combinaciones no se programan: salen.** Cada glifo escribe sólo lo
suyo en una receta común (`SpellRecipe`) y es la receta terminada la que se
interpreta. *Resistir la tentación de escribir la regla de una combinación
es la decisión de diseño más importante del proyecto.*

**Contratos que se comprueban solos** (hojas de animación, `meta.json` del
pipeline).

**El mundo habla por duck typing:** `on_spell_hit`, `spell_reacts`,
`receive_damage`, `push`. Un objeto nuevo reacciona sin que el hechizo sepa
que existe.

**Los niveles heredan de un motor común.** `nivel_base.gd` es el motor
(construye el plano, jugador, interfaz, sistemas); cada nivel
(`test_jugabilidad.gd`, `mundo.gd`, `test_2.gd`, `vfx_lab_mundo.gd`) solo da
sus datos sobrescribiendo funciones (`_mapa()`, `_lista_props()`,
`_puestos()`...). Editar un nivel no puede romper a otro.

**Los comentarios cuentan el fallo que evitaron.** Mantener ese estilo.

## Estado (octubre de 2026)

| | |
|---|---|
| **Escena principal** | `Mundo.tscn` (F5). Cada nivel se prueba con F6 sobre su escena |
| **Niveles** | `TestJugabilidad` (23x23, 4 tareas), `Mundo` (40x34), `Test2` (40x40, una prueba por elemento), `VfxLabMundo` y `VfxLab` (laboratorios) |
| **Arte** | sale del **pipeline de sprites isométricos**: GLB de Meshy → `pipeline/` → `export_godot/` (personajes en 8 direcciones, bloques 128x64 con la cara de arriba en y=33, props a 2x anclados en la base). Lo de `art/` son piezas sueltas a 2x (hielo, empujables, puesto, tótems) |
| **Personaje** | el héroe del pipeline (`MsAtlas.frames_heroe`, `MsActor`), con lanzar por tipo, golpe, recoger y muerte |
| **Sistemas** | mochila (8→20), oro, botín, ingredientes por reacción, decorado recogible, puestos con tendero al norte, alquimista (mejoras), encargos, goblins con IA y barra de vida, debilidades, puntos de guardado, pantalla de muerte, bloques empujables, hielo permanente. Detalle en `docs/NUEVOS_SISTEMAS.md` |
| **Grimorio** | se abre con T y para el tiempo; sello en el núcleo, un glifo por sector (8 sectores, tope `max_sigils_per_page`); tres páginas que se recargan, no se gastan; paleta de pruebas con F1 |
| **Trabajo en curso** | `docs/PLAN_ARREGLOS.md` (fases, responsables y casillas) |

## Hilos abiertos

Los que tienen tarea asignada llevan su número de `docs/PLAN_ARREGLOS.md`.

- **Un glifo por sector** (decidido): el libro tiene que enseñar el hueco
  ocupado y rechazar el segundo trazo, y los glifos de la página tienen que
  combinarse entre sectores al apuntar con el ratón (hoy `_component_at`
  solo combina dentro del mismo sector). Juego; ver `DISENO_FUTURO.md` §3.
- Procesar en el pipeline `shot_in_the_back_and_fall` (muerte), `roll_dodge_1` y
  `swim_forward` del héroe: están en `pipeline/inbox/hero` (1.5).
- Confirmar en Godot la lista §4 de `docs/QA_ARTE.md` (hielo hundido, maga
  que se levanta, golpe y hachazo del goblin) (0.7).
- Atribución **CC-BY** de `tree_ghibli_01`: comprobar si se usa y, si sí,
  acreditarlo en el README y en el juego.
- **Solapes de elementos** (medidos en `docs/TEST2_CONCLUSIONES.md`): el hielo
  sustituye al viento y a la tierra para cruzar agua; falta darle al viento y a
  la tierra algo exclusivo.
- Falta casi todo el arte de la lista `docs/ASSETS_PENDIENTES.md` (alquimista,
  hit/death de goblins, placa de peso, iconos).
- `earth_builder.gd` crea el bloque de tierra en mitad de la física y Godot avisa
  por consola ("Can't change this state while flushing queries"); funciona, pero
  habría que diferirlo.
- Vocabulario sello/glifo sin unificar en el código antiguo (ver arriba).
- Sin revisar desde septiembre (pueden seguir o no): el jugador se salta el muro
  estando elevado; el arquero recibía daño de más del circuito tras morir (1.2).

---

## La subtarea de escritura

**La voz ya existe en el juego.** Cuando intentas quemar un árbol, la
maga se niega:

> "Ni hablar. Un incendio forestal no entraba en el plan."
> "...mejor no. Esto arde entero y yo estoy en medio."
> "No pienso ser la maga que quemó el bosque."
> "El árbol no tiene la culpa de nada."

Primera persona, frases cortas, humor seco, se le nota que piensa en voz
alta. **Y existen por un motivo mecánico, no decorativo:** un árbol que se
traga una bola de fuego sin inmutarse y sin decir nada parece un bug; el
mismo árbol con una frase encima es una decisión del personaje. Esa es la
prueba que debería pasar cualquier texto nuevo — *¿está haciendo un
trabajo, o está de adorno?*

**Vocabulario fijo**: el de la sección "Vocabulario" de arriba.

**Lo que no hay que hacer:** tutorializar en boca del personaje, explicar
la mecánica ("ahora combina fuego con flecha"), ni chistes de relleno. El
libro enseña sólo lo que ya has escrito, no el catálogo de lo posible; el
guión debería tener la misma contención.

**Dónde aparece el texto.** Los NPC ya hablan en una **caja inferior**
(clase `Dialogo` de `nivel_base.gd`, panel de Kenney; las frases están en
`DIALOGOS` y en `TENDEROS`). Las negativas de la maga de arriba siguen
saliendo por `print()` y solo existen en `prop.gd` (Blockout/IsoTest), no
en los niveles nuevos. Queda sin decidir dónde habla la propia maga:
bocadillo, la misma caja, o anotación en el grimorio.

---

## Qué adjuntar como conocimiento del proyecto

| archivo | qué cuenta | a qué proyecto |
|---|---|---|
| `docs/CONTEXTO.md` | **este**: reglas, vocabulario, estado en una pantalla | los dos |
| `docs/PROPIETARIOS.md` | quién toca qué archivo; contratos entre contextos | los dos |
| `ARQUITECTURA.md` | lo que el código hace hoy, con el porqué | los dos |
| `docs/DISENO_FUTURO.md` | lo que se quiere hacer, con coste y decisiones | los dos |
| `docs/PLAN_ARREGLOS.md` | tareas con responsable y fase | los dos |
| `docs/NUEVOS_SISTEMAS.md` | escenas, letras del plano, teclas | Juego |
| `docs/TEST2_CONCLUSIONES.md` | el laboratorio de elementos y lo que se ha medido | Juego |
| `docs/QA_ARTE.md` | mediciones de bloques y clips, con lo pendiente de confirmar | los dos |
| `docs/ASSETS_PENDIENTES.md` | el arte que falta y cómo prepararlo según el pipeline | Pipeline |
| `docs/ARTE.md` | colores de elemento y paletas de bioma (§1 y §2 vigentes; §3–§6 son del arte de septiembre) | Pipeline |
| `export_godot/CONTRATO_GODOT.md` | el contrato del pipeline con Godot | Pipeline |
| `README.md` | resumen, teclas, créditos y herramientas | opcional |

`docs/DIARIO.md` no se sube: se lee del disco, porque cambia cada sesión.

`docs/ANIMACION.md` y `docs/PERSONAJE.md` describen el animador antiguo (`ActorAnimator`, la maga sacada de vídeo): históricos; el personaje de ahora sale del pipeline.
