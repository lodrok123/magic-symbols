# Magic Symbols

Juego 3D de puzles y aventura de magia por dibujo de runas, hecho en **Godot 4.7** (Forward+). La protagonista es una elfa chibi; la cámara es ortogonal, inclinada 60°, y gira de 90° en 90°.

Abres el libro, dibujas un sello (el elemento) y glifos (la forma), y lanzas el hechizo desde la jugadora. El elemento cambia el mundo de forma física: el fuego quema la hierba, el agua moja y, con más agua, hiela, el calor funde el hielo, el rayo se conduce por el agua.

Referencias: *Magicka* (combinar elementos), *Witch Hat Atelier* (que dibujar importe), *Echoes of Wisdom*, *Link's Awakening*, *Wizard of Legend*, *Kena* y *Noita*. El resumen de diseño está en **`docs/GDD.md`**.

---

## Cómo se juega

Las teclas se pueden reasignar desde el menú de pausa; estas son las de serie (`nucleo/controles.gd`).

| tecla | acción |
|---|---|
| `WASD` / flechas | moverse |
| `Shift` | correr |
| `Espacio` | saltar |
| `Ctrl` | voltereta |
| `F` | golpe cuerpo a cuerpo |
| `E` | interactuar (hablar, recoger, abrir) |
| `T` | abrir / cerrar el libro de hechizos |
| `1` `2` `3` | con el libro cerrado, lanzar la página 1, 2 o 3; con el libro abierto, cambiar de página |
| `I` / `J` | mochila / misiones |
| `Q` / `R` | usar consumible / cambiar consumible |
| `Esc` | pausa |

**Con el libro abierto el tiempo va al 30 %**: tienes tiempo para dibujar, pero el mundo sigue vivo. El hechizo siempre sale de la jugadora.

Con el libro abierto:

- Dibuja en el **núcleo** (el círculo central) para elegir el **sello**, es decir el elemento: fuego, agua, tierra, rayo, hielo o viento.
- Dibuja en un **sector** (uno de los que rodean el núcleo) para añadir un **glifo**. Los glifos se combinan: nadie ha programado «barrera + flecha», sale de que cada glifo aporte lo suyo al hechizo.
- Al cerrar el libro con `T`, se lanza la página abierta. Hay tres páginas; no se gastan, se recargan. Los hechizos cuestan tinta (se empieza con 100, el tope es 300).

Los dibujos de cada runa están en `docs/runas.png`.

### Modo de grabación

Dentro del libro, `G` entra y sale del modo de grabación, donde dibujar **no lanza nada**: guarda el trazo como muestra del gesto seleccionado. Graba **varias muestras por gesto** (cuatro o cinco): el mismo trazo sale distinto rápido que despacio, grande que pequeño. Las muestras viven en `nucleo/gesture_library.tres`.

---

## Cómo está montado

La idea que sostiene el proyecto es que **el comportamiento son datos, no código**.

- **Hechizo** (`nucleo/hechizo.gd`): elemento + glifos dan tres semiejes X/Y/Z, una figura, si viaja y si es un haz. Los glifos están en `nucleo/sigils.gd`; el elemento decide su **materia** (sólido, líquido, plasma, energía, gas) y `magia/hechizo_vivo.gd` la ejecuta.
- **Mundo con estado** (`mundo/`): cada casilla puede estar helada, electrificada, quemada, mojada o segada, y las transiciones son una tabla (`mundo/estados_suelo_3d.gd`).
- **Enemigos** (`enemigos/`): comparten `combate_3d.gd` (vida, debilidades, estados, empuje por masa).
- **Gesto** (`nucleo/gesture_*`): el reconocedor es **$P (Point-Cloud Recognizer)** de Vatavu, Anthony y Wobbrock (ICMI 2012), licencia New BSD.
- **Nivel**: un plano de letras en `mundo/datos_nivel/mapas/` más una escena en `escenas/`; las reglas de puzle están en `escenas/puzle.gd`.
- **Reacciones**: el mundo habla por contratos pequeños (`on_spell_hit`, `spell_reacts`) y por la tabla de estados, no por «¿eres fuego?».

Documentos:

- **`docs/GDD.md`**: qué juego es y qué está decidido.
- **`ARQUITECTURA.md`**: lo que el código hace hoy, con el porqué (partes de la era 2D están desfasadas, ver `docs/DECISIONES_CHATS.md` §2).
- **`docs/DISENO_FUTURO.md`**: lo que se quiere hacer.
- **`docs/DIRECCION_2026-11-02.md`**: dónde está el proyecto y por dónde seguir.
- **`docs/PROPIETARIOS.md`**: quién toca qué.
- **`docs/CONTEXTO.md`**: cómo se trabaja.

---

## Seguir en otro ordenador

1. Instala **Godot 4.7** y clona este repositorio (`BAJAR_DE_GITHUB.cmd` y `SUBIR_A_GITHUB.cmd` hacen la subida y la bajada).
2. Abre la carpeta desde el gestor de proyectos de Godot.
3. La primera apertura tarda: Godot reconstruye `.godot/` reimportando las texturas. Es normal y solo pasa una vez.
4. Escena de arranque: `escenas/MenuPrincipal.tscn` (menú principal); «Nueva partida» entra en `escenas/PruebaBosque01_v01.tscn`. Cada nivel se prueba con F6 sobre su escena `Prueba*.tscn`.

### Lanzar las pruebas

Sin ventana, desde la raíz del repo:

- `tools\pruebas.cmd` lanza todas las pruebas `herramientas/prueba_*.gd` y los escenarios, y resume el resultado (busca Godot en `tools\godot_local.txt`).
- `tools\pruebas.cmd solo <trozo de nombre>` lanza un subconjunto; `tools\prueba_una.cmd` lanza una sola.
- Un módulo nuevo nace con su `herramientas/prueba_<modulo>.gd` y se da por bueno con `TOTAL DE FALLOS: 0`.

---

## Créditos de recursos

- **Kenney** (CC0): interfaz, runas y partículas.
- **Personajes, enemigos y piezas del juego**: modelos 3D de Meshy (`arte/modelos/`, `arte/meshy/`).
- **Sonidos**: `audio/`, con sus licencias en `audio/LICENCIAS.md`.
- Reconocedor de gestos **$P** de Vatavu, Anthony y Wobbrock (New BSD).

> **Atribución pendiente de comprobar.** El árbol `tree_ghibli_01` figuraba como **CC-BY-4.0** (autor «Alex Ace», Sketchfab), con atribución obligatoria. Si sigue en el juego, su crédito tiene que figurar aquí y en el juego. No se ha podido comprobar en este checkout porque el catálogo del que salía ya no está en el repositorio.

---

## Herramientas (`tools/`)

| herramienta | qué hace |
|---|---|
| `pruebas.cmd`, `prueba_una.cmd`, `resumen_prueba.ps1` | lanzan y resumen las pruebas sin ventana |
| `grabar_laboratorio.bat` | graba un laboratorio con el modo Movie Maker de Godot |
| `subir_a_github.bat` | comprobaciones y subida a GitHub |
| `podar_gestos.py` | quita muestras dispersas y nombres muertos de `gesture_library.tres` |
| `grafo.py` | grafo de dependencias entre scripts |
| `limpieza_mover.ps1`, `reorganizar.ps1` | scripts de limpieza del 13/10 |
| `gen_pasos_suaves.py`, `gen_sonidos_ambiente.py` | generadores de sonido |
| `ampliar_bosque_01.py`, `hoja_a_nivel.py` | utilidades de niveles |
| `autorig_chaman.py`, `autorig_golem.py`, `separar_orbe_baston.py` | utilidades de modelos |

> `tools/` contiene además un `Godot_v4.7.2-stable_win64.exe` de unos 180 MB, vídeos y un zip. GitHub rechaza archivos de más de 100 MB: comprobar con `git ls-files tools` si están versionados (en este checkout el ejecutable y los vídeos no figuran en `git ls-files`).
