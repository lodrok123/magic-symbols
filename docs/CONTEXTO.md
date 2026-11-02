# Magic Symbols: contexto del proyecto

**FUENTE DE VERDAD de cómo se trabaja.** Qué es el juego: `docs/GDD.md`. Dónde está hoy: `docs/DIRECCION_2026-11-02.md`.

| documento | cuenta |
|---|---|
| `docs/GDD.md` | qué juego es, pilares, bucle, qué está decidido y qué no |
| `docs/CONTEXTO.md` (este) | cómo se trabaja, vocabulario |
| `ARQUITECTURA.md` | lo que el código hace hoy, con el porqué (partes de la era 2D desfasadas: `docs/DECISIONES_CHATS.md` §2) |
| `docs/DISENO_FUTURO.md` | lo que se quiere que haga, con coste y decisiones pendientes |
| `docs/DIRECCION_2026-11-02.md` | el asesoramiento más reciente: lo maduro, lo verde y seis direcciones |
| `docs/PENDIENTES.md`, `docs/DECISIONES_CHATS.md` | tareas abiertas y decisiones de Pablo |
| `docs/PROPIETARIOS.md` | qué contexto toca qué archivo |

Si dos documentos se contradicen, manda `ARQUITECTURA.md` para el presente y `DISENO_FUTURO.md` para el futuro; este archivo se corrige.

Última revisión: 2 de noviembre de 2026.

---

## Qué es

Juego 3D de puzles y aventura hecho en **Godot 4.7 (Forward+)**. Cámara ortogonal inclinada 60° que gira de 90° en 90°; la protagonista es una elfa chibi. Se dibujan símbolos con el ratón para lanzar hechizos: un **sello** (el elemento) en el núcleo del libro y uno o más **glifos** (la forma) en los sectores. **Con el libro abierto el tiempo va al 30 %**, y el hechizo sale siempre de la jugadora. Seis elementos (fuego, agua, tierra, rayo, hielo, viento) y 14 entradas de glifo en `nucleo/sigils.gd`. Pantalla de arranque: `escenas/MenuPrincipal.tscn`; «Nueva partida» entra en `escenas/PruebaBosque01_v01.tscn`.

Inspiración: Magicka, Witch Hat Atelier, Echoes of Wisdom, Link's Awakening, Wizard of Legend, Kena y Noita.

Lo escribe una sola persona que está aprendiendo. **El objetivo no es terminar el juego: es entender lo que se construye.**

## Vocabulario

| palabra | qué es | ejemplos |
|---|---|---|
| **sello** | el ELEMENTO, se dibuja en el núcleo | fuego, agua, viento, rayo, tierra, hielo |
| **glifo** | la FORMA, se dibuja en un sector | flecha, barrera, líneas, altura, repetición, rebote, crecer, permanencia, pulso, perforar, retorno, buscar, carga |
| **materia** | cómo se ejecuta un elemento | sólido, líquido, plasma, energía, gas |
| libro, núcleo, sector, hechizo | como siempre | |

Algunos ids del código no coinciden con lo que ve el jugador: el id `pulso` se ve como «crecer», `raido` como «pulso» y `retardo` como «carga» (`Sigils.nombre_visible`). El código antiguo (`repertoire.gd`, `sigils.gd`, `spellbook.gd`) llama `sigil` a la forma; no se ha renombrado a propósito (cambio grande sin ganancia de juego).

**Regla del libro (decidida el 4/10/2026): un glifo por sector.** Una vez dibujado un glifo, dibujar encima no hace nada y el clic derecho lo borra. El primer libro tiene sitio para 4 elementos y 6 glifos (`docs/PENDIENTES.md`, «Libro y progresión»).

## Cómo trabajar en esto

- **Todo en español**, código y comentarios incluidos.
- **Explicar el porqué, no sólo el qué.** Qué se descartó y por qué.
- **Medir antes de afirmar.** Estimar a ojo produjo errores todas las veces que se intentó.
- **Verificar antes de escribir en el proyecto.** Cada módulo nuevo nace con su prueba sin ventana en `herramientas/prueba_<modulo>.gd`. Se lanzan con `tools\pruebas.cmd` (todas) o `tools\pruebas.cmd solo <trozo de nombre>` (un subconjunto), y se dan por buenas con `TOTAL DE FALLOS: 0`. Para ver el aspecto hace falta abrir el juego.
- **Elegir mirando, no adivinando.** Barrido de opciones renderizado y se decide sobre la imagen.
- **Cambios mínimos.** No tocar lo que no se ha pedido.
- **Decir lo que cuesta cada decisión**, no sólo lo que gana.
- **Los commits de git los hace Pablo**, salvo que un encargo diga expresamente lo contrario; entonces se hace commit solo de los ficheros propios (`git add` por nombre, nunca `-A`), sin push.
- **Subir archivos con Godot cerrado**, y abrir Godot después para que reimporte el arte nuevo.
- Siempre decir **dónde** queda cada archivo entregado.
- Varias conversaciones tocan el proyecto a la vez, a veces en worktrees aparte: **antes de escribir un archivo, comparar con la versión del disco** (no pisar cambios ajenos).
- **Un dueño por archivo.** El reparto está en `docs/PROPIETARIOS.md`; lo que un contexto necesita del otro se apunta en `docs/DIARIO.md` (leerlo al empezar, escribirlo al terminar). Los cambios son parciales: nunca reescribir un archivo entero desde una copia de la conversación.
- **Documentos nuevos**: van fechados `docs/NOMBRE_AAAA-MM-DD.md` y se enlazan desde `docs/LEEME.md` (regla 7 de `docs/PROPIETARIOS.md`).

## Dónde vive

Repositorio `lodrok123/magic-symbols` (privado). Copias de trabajo conocidas: `E:\magic-symbols` (checkout de `main`), `C:\Users\pablo\Documents\magic-symbols` (escritorio) y `C:\Users\paranda\Documents\magic-symbols` (portátil). Entre ordenadores viaja por **git + GitHub** (`BAJAR_DE_GITHUB.cmd` al empezar, `SUBIR_A_GITHUB.cmd` al terminar). Otras sesiones pueden trabajar en worktrees aparte. Antes de tocar nada, comprobar la carpeta conectada y si la copia está al día.

## Cómo está escrito el código

**Datos antes que condicionales.** Añadir un glifo es una entrada en `Sigils`; un nivel es un plano de letras más una escena; las reglas del suelo son una tabla (`EstadosSuelo3D.TRANSICIONES`).

**Las combinaciones no se programan: salen.** Cada glifo escribe sólo lo suyo y el hechizo terminado (`Hechizo`) es lo que se interpreta. *Resistir la tentación de escribir la regla de una combinación es la decisión de diseño más importante del proyecto.*

**El mundo habla por duck typing:** `on_spell_hit`, `spell_reacts`, `receive_damage`, `push`. Un objeto nuevo reacciona sin que el hechizo sepa que existe.

**Los comentarios cuentan el fallo que evitaron.** Mantener ese estilo.

## Estado

Ver `docs/GDD.md` (estado en cinco líneas) y `docs/DIRECCION_2026-11-02.md` §1 (el detalle). Tareas abiertas: `docs/PENDIENTES.md`. Lo que cada sesión hizo: `docs/DIARIO.md`.

---

## La subtarea de escritura

La voz del personaje: primera persona, frases cortas, humor seco, se le nota que piensa en voz alta. Un texto existe por un motivo mecánico, no decorativo: un árbol que se traga una bola de fuego sin decir nada parece un bug; el mismo árbol con una frase encima es una decisión del personaje. La prueba que debe pasar cualquier texto nuevo: *¿está haciendo un trabajo, o está de adorno?*

**Lo que no hay que hacer:** tutorializar en boca del personaje, explicar la mecánica, ni chistes de relleno. El libro enseña sólo lo que ya has escrito, no el catálogo de lo posible.

> Las frases de negativa de la maga de la versión 2D («Ni hablar. Un incendio forestal no entraba en el plan.») no se han encontrado en el código 3D actual; dónde habla la maga en 3D queda sin decidir.

## Qué adjuntar como conocimiento del proyecto

| archivo | qué cuenta |
|---|---|
| `docs/GDD.md` | el juego en dos páginas |
| `docs/CONTEXTO.md` | este: reglas y vocabulario |
| `docs/PROPIETARIOS.md` | quién toca qué archivo; contratos entre contextos |
| `ARQUITECTURA.md` | lo que el código hace hoy |
| `docs/DISENO_FUTURO.md` | lo que se quiere hacer |
| `docs/DIRECCION_2026-11-02.md` | dónde está el proyecto |
| `docs/PLAN_VFX_ELEMENTOS.md` | pilares y plan de VFX y estado del mundo |
| `docs/PLAN_ARREGLOS.md` | tareas con responsable y fase |
| `docs/NUEVOS_SISTEMAS.md`, `docs/ESTADOS_SUELO.md`, `docs/TEST2_CONCLUSIONES.md`, `docs/QA_ARTE.md` | referencia del Juego |
| `docs/ARTE.md`, `docs/ASSETS_PENDIENTES.md` | referencia del arte (`ARTE.md` §1 y §2 vigentes; el resto es de la era 2D) |

`docs/DIARIO.md` no se sube: se lee del disco, porque cambia cada sesión. `docs/ANIMACION.md` y `docs/PERSONAJE.md` describen el animador 2D antiguo: históricos.
