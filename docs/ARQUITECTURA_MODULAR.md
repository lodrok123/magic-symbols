# Arquitectura modular del 3D — diagnóstico y diseño (13/10/2026)

Lo escribe el Juego para que Pablo lo lea, lo entienda y lo mejore. Va en paralelo a `LIMPIEZA.md`. Completa
`ARQUITECTURA.md` (de Pablo) con la parte de **código**: dónde están hoy las costuras, por qué meter el agua obligó a
tocar los hechizos, y cómo quedan las capas para que tocar una no mueva las demás. Todo medido sobre el código del
13/10 (repo `Documents\magic-symbols`, tras el pull); las cifras se pueden repetir con `tools/grafo.py`.

## 0. La regla en una frase

> **Las dependencias solo apuntan hacia abajo:** Presentación → Juego (magia, jugador, enemigos, objetos) → Mundo → Núcleo.
> Y **el mundo no sabe quién lo cambia**: recibe «calor en la casilla (3,26)» o «1 u³ de agua en el punto P», nunca
> «el hechizo de fuego del jugador». (Es el *principio clave* de la lámina de la Capa de Mundo, llevado al código.)

Cuando se cumple, añadir agua es tocar `mundo/`: la magia sigue llamando a `mundo.agua.anadir(punto, volumen)` y no sabe
si debajo hay una letra `~`, una simulación de tuberías o un shader.

## 1. Diagnóstico: por qué el agua obligó a reescribir los hechizos

### 1.1 `Lanzador3D` es a la vez la magia y la API del mundo

`lanzador_3d.gd` (115 KB, 103 funciones) tiene **61 miembros estáticos**. Unos son magia (`cast_page`,
`aviso_receta`, `GeometriaHechizo`); otros son el **mundo**: `celda_de`, `centro_de`, `letra_de`, `es_agua`, `altura_en`,
`y_pies`, `bloqueada`, `pisable`, `linea_libre`, `agua_sim`, `montar_agua_sim`, `cauces_abiertos`, `sobre_hielo`,
`atrapar`, `soltar_presos`… Siete archivos consultan el mundo **a través del Lanzador**:

| Quién | Qué pide a `Lanzador3D.` (distintos) |
|---|---|
| `jugador_3d.gd` | `celda_de`, `y_pies`, `altura_en`, `alto_agua`, `es_agua`, `en_mapa`, `pisable`, `sobre_hielo`, `choca_huella`, `es_parcial` (10) |
| `combate_3d.gd` | `celda_de`, `y_pies`, `ALTO_NIVEL`, `pisable`, `linea_libre`, `liberar_celda`, `es_agua`, `en_mapa`, `bloqueada`, `altura_en`, `CAPA_REACTIVO` (11) |
| `surtidor_3d.gd`, `emisor_rayo_3d.gd`, `flotador_3d.gd`, `playlog_3d.gd`, `prueba_test2.gd` | `agua_sim`, `casilla`, `centro_de`, `alto_agua`, `LECHO_AGUA`, `cauces_abiertos`, `letra_de`, `ultimo_impacto`… |

Consecuencia medida: al llegar la simulación (Fase 11), `agua_sim` aparece **34 veces en `lanzador_3d.gd`** y
`es_agua`, `y_pies`, `pisable` cambiaron de significado para todos los de la tabla. El agua no tocó «los hechizos de
agua»: tocó **el archivo donde vive el mundo**, que casualmente es el de los hechizos.

### 1.2 La maqueta (`prueba_test2.gd`, 183 KB) es el mundo *y* su dibujo, y el Juego le mete la mano por dentro

El Juego llega al estado del mundo por **reflexión sobre campos privados** de la maqueta del Pipeline:
`mundo.get("_helada")` (8 veces), `_fx` (7), `_lado` (6), `_poner_canal` (4), `_es_canal` (4), `_al_impactar` (4),
`_letra`, `_goblins`, `_mapa`, `_bloqueadas`, `_velo`, `_liberar`, `_img_estado`, `_camara`, `_agua_render`… Son 25
nombres con guion bajo que no forman contrato: el Pipeline los puede renombrar al ordenar su archivo y el Juego se
entera en el playtest. Y al revés: para que el canal de la tinaja «fuera agua», hubo que tocar `surtidor_3d.gd`,
`lanzador_3d.gd` (`es_cauce_seco`), `prueba_test2.gd` (`_es_canal`, `_poner_canal`) y `canal_3d.gd`. Cuatro archivos
de dos propietarios para un hecho del mundo: *esta casilla tiene agua*.

Hoy hay **tres fuentes de verdad** para «¿hay agua aquí?»: la letra `~` del mapa (`_mapa`), `AguaSim3D` (profundidad)
y `Canal3D` (animación de tiras). `Surtidor3D.convertir_a_agua` existe solo para que las tres digan lo mismo.

### 1.3 Herencia del 2D

- `Lanzador3D extends "res://spellcaster.gd"`, que `extends Node2D`. El lanzador 3D **es un Node2D** colgado de un
  `Node3D`. Funciona porque solo usa lo que no depende de la posición, pero arrastra `SpellFactory`/`Spell` (el
  lanzamiento 2D) y 11 archivos más (ver `LIMPIEZA.md` §2.C).
- `Combate3D` hereda la tabla de debilidades de `CombateComun` (`Node2D`), y eso arrastra `Botin`, `BlockFx`, `Sonidos`.
- `prueba_test2.gd` hace `preload("res://test_2.gd")` por cinco constantes y con ello carga `nivel_base.gd` y el mundo
  2D entero (41 archivos) en memoria en cada arranque del 3D.

### 1.4 Lo que ya está bien (y hay que conservar)

- **El contrato de objetos reactivos** (`on_spell_hit(rune, dir)`, `spell_reacts`, `carried_element`, `nivel_altura`) lo
  cumplen `Reactivo3D`, `Surtidor3D`, `Combate3D`, las barreras del Lanzador. Es exactamente la forma correcta: el
  objeto recibe un *elemento* y decide. Se mantiene tal cual y se extiende (§3.3).
- **`AguaSim3D`** es un módulo limpio: sin nodos, sin saber qué es un hechizo, probado en headless. Es el modelo para
  el resto del mundo.
- **`GeometriaHechizo` / `Receta3D`**: la receta como datos puros (Fase 8) es la dirección correcta.
- **Las pruebas sin ventana** (`herramientas/prueba_*.gd`, 6 archivos, FALLOS 0). Cada módulo nuevo nace con la suya.

## 2. Las capas (correspondencia con el diagrama de Pablo)

| Capa del diagrama | Carpeta | Qué contiene | Puede depender de |
|---|---|---|---|
| Datos y contenido | `nucleo/` | `Runes`, `RuneData`, `Sigils`, `SpellRecipe`, `GeometriaHechizo`, `Estado`, `Objetos`, `Repertoire`, `PlayLog`, gestos | nada (solo Godot) |
| **Capa de Mundo** | `mundo/` | `Terreno3D` (casillas, letras, alturas, bloqueos), `AguaSim3D`, `EstadosSuelo3D` (fuego, hielo, mojado, electrificado), `Mundo3D` (fachada + señales), marcadores, horneado, mapas | `nucleo/` |
| Objetos del mundo | `objetos/` | `Reactivo3D` y especializaciones (surtidor, emisor, puente, enredadera, flotador, canal) | `mundo/`, `nucleo/` |
| Gameplay | `magia/`, `jugador/`, `enemigos/`, `niveles/` | `Lanzador3D`, efectos de hechizo, `Jugador3D`, `Combate3D` e IA, reglas por nivel (`Bosque3D`) | `objetos/`, `mundo/`, `nucleo/` |
| Presentación | `presentacion/` | `Vfx3D`, `AguaRender3D`, ondas, metaballs, costra, hierba, ocluso, `Pj3D`, HUD, grimorio | **todo lo de arriba, por señales**; nadie depende de ella |
| Sistemas base | Godot | física, render, audio | — |

Dos consecuencias prácticas:

1. **El Pipeline escribe solo en `presentacion/` y `arte/`.** Su «maqueta» deja de ser el mundo: es un nodo que
   *escucha* a `Mundo3D` y dibuja. Si quiere saber si una casilla está helada, pregunta `mundo.estados.helada(c)`,
   no mantiene su propio `_helada`.
2. **El Juego escribe en `nucleo/`, `mundo/`, `objetos/`, `magia/`, `jugador/`, `enemigos/`, `niveles/`.** Y nunca
   usa `get("_algo")` sobre un nodo del Pipeline: si le falta un dato, lo pide como método de `Mundo3D`.

## 3. Contratos (lo que un módulo promete al de arriba)

Nombres en español, firmas estables: cambiarlas exige entrada en `DIARIO.md`, como ya pasa con `MsAtlas`.

### 3.1 `Mundo3D` (fachada; nodo raíz de la capa de mundo)

```gdscript
class_name Mundo3D extends Node3D
var terreno: Terreno3D        # casillas, letras, alturas, bloqueos, geometría (lo que hoy son los static de Lanzador3D)
var agua: AguaSim3D           # tal cual existe
var estados: EstadosSuelo3D   # fuego / hielo / mojado / electrificado por casilla, con tiempo
signal casilla_cambio(c: Vector2i, que: String)   # "agua", "hielo", "fuego", "bloqueo", "altura", "letra"
signal impacto(punto: Vector3, elemento: String, radio: float)   # para VFX y sonido: dónde y de qué, nunca quién
func cargar(nivel: String) -> void   # letras (mapas/<nivel>.txt) o Nivel_<X>.tscn; monta terreno, agua y estados
```

### 3.2 `Terreno3D` (sin nodos, probable en headless)

```gdscript
const casilla := 2.3
func celda_de(p: Vector3) -> Vector2i;  func centro_de(c: Vector2i, y := 0.0) -> Vector3
func en_mapa(c) -> bool;  func letra(c) -> String;  func altura(c) -> int;  func y_pies(c) -> float
func bloqueada(c) -> bool;  func bloquear(c, si: bool);  func pisable(c, nivel, sube, max_nivel, nada, ignora) -> bool
func linea_libre(a: Vector3, b: Vector3) -> bool;  func solida(c, nivel) -> bool
```
Es, función por función, lo que hoy está en `lanzador_3d.gd` líneas 226–720. **Se mueve, no se reescribe.**

### 3.3 Cómo cambia el mundo: *acciones elementales*, no hechizos

```gdscript
# mundo/accion_elemental.gd — datos puros
class_name AccionElemental
var elemento: String        # "fuego" | "agua" | "hielo" | "rayo" | "viento" | "tierra"
var punto: Vector3; var radio: float; var cantidad: float   # u³ de agua, segundos de hielo, intensidad…
var direccion: Vector3      # para viento y proyectiles
var origen: Node            # solo para NO golpearse a sí mismo; el mundo no lo lee
```
`Mundo3D.aplicar(accion)` reparte: al agua (`agua.anadir/quitar/helar`), a los estados del suelo, a los
`Reactivo3D` que toque (`on_spell_hit` sigue recibiendo `RuneData`; se construye desde `accion.elemento`). Un
hechizo, una tinaja que vierte, un brasero que arde o un goblin de escarcha **generan la misma acción**. Es lo que
hoy hacen `hechizo_sobre_agua`, `atrapar`, `abrir_caudal`, `al_impactar`… repartidos entre Lanzador y maqueta.

### 3.4 Presentación: solo escucha

`Vfx3D`, `AguaRender3D`, la maqueta: `mundo.casilla_cambio.connect(...)`, `mundo.impacto.connect(...)`,
`mundo.agua.textura()`. Prohibido que la magia llame a `_fx.chispazo(...)` directamente: emite `impacto`, y la
presentación decide qué chispazo. (Hoy `Lanzador3D` llama a `mundo.get("_fx")` 7 veces.)

## 4. Plan de migración (estrangulador, no reescritura)

Cada paso deja el juego funcionando y se verifica con las pruebas headless + un playtest corto. Nunca se reescribe
un archivo entero desde una copia: se mueven funciones y se dejan **reenvíos** en el sitio viejo mientras haya
llamadas.

| Paso | Qué | Quién | Cómo se comprueba |
|---|---|---|---|
| **M1** Sacar `Terreno3D` | Mover los estáticos de mundo de `lanzador_3d.gd` (l. 226–720) a `mundo/terreno_3d.gd`. En `Lanzador3D` quedan reenvíos de una línea (`static func celda_de(p): return Mundo3D.terreno.celda_de(p)`) marcados `## REENVÍO M1`. `AguaSim3D` pasa a colgar de `Mundo3D.agua`; `Lanzador3D.agua_sim` queda como reenvío | Juego | `prueba_agua_sim`, `prueba_hechizos`, `prueba_kit`… en FALLOS 0; `grep -c "Lanzador3D\." jugador_3d.gd` baja a 0 al final del paso |
| **M2** `Mundo3D` con señales | Nodo `Mundo3D` que crea la maqueta en `_ready` (el único punto de contacto). `agua_cambio` y `cambios_hielo` pasan a `casilla_cambio`. `EstadosSuelo3D` absorbe `_helada`, `_img_estado`, `marcar_estado` | Juego define, Pipeline conecta | La maqueta deja de tener `_helada`: `grep _helada prueba_test2.gd` = 0 |
| **M3** `AccionElemental` | `hechizo_sobre_agua`, `atrapar`, `abrir_caudal`, el `al_impactar` de la maqueta → `Mundo3D.aplicar`. `Surtidor3D` deja de cambiar letras: `terreno.letra(c)` consulta `agua.es_agua_casilla` cuando la casilla es cauce | Juego | Una sola fuente de verdad para «hay agua»: `convertir_a_agua` desaparece |
| **M4** Cortar el 2D | `Lanzador3D extends Node3D` + un `Grimorio` (RefCounted) con la lógica de `spellcaster.gd` que de verdad usa (reconocer, páginas, recarga). `Combate3D` con su propia tabla. Entonces caen los 11 arrastrados y `spellcaster.gd`/`combate_comun.gd` | Juego | `LIMPIEZA.md` §2.C se vacía; el 3D no carga ningún `Node2D` |
| **M5** La maqueta se parte | `prueba_test2.gd` (183 KB) → `presentacion/maqueta_3d.gd` (suelo, lotes, hierba, agua, luz), `mundo/cargador_nivel.gd` (leer letras/marcadores → `Mundo3D`), `presentacion/vitrina.gd` | Pipeline (dibujo), Juego (cargador) | Cada escena `Prueba*.tscn` sigue arrancando; `vista_suelo_editor` sigue funcionando |

Orden: M1 → M2 → M3 ∥ M4 → M5. **M1 es el que más devuelve por menos riesgo** (es mover funciones estáticas) y
es el que habría evitado el coste del agua.

## 5. Reglas de trabajo para que no vuelva a pasar

1. **Un dato, un dueño.** «¿Hay agua en (x,y)?» lo responde `Mundo3D.agua`. Si otro módulo necesita una copia (una
   letra, una textura), la deriva al recibir `casilla_cambio`, nunca la mantiene a mano.
2. **Ningún `get("_x")`, `call("_x")` ni `has_method("_x")` entre contextos.** Si hace falta, se añade un método público
   a la fachada y se anota en el diario. (Hoy: 25 nombres privados cruzados.)
3. **El mundo no recibe hechizos; recibe acciones elementales.** Un módulo nuevo del mundo (lava, niebla, viento
   persistente) implementa `aplicar(accion)` y emite `casilla_cambio`; la magia no cambia.
4. **Cada módulo nace con su prueba headless** en `herramientas/prueba_<modulo>.gd` y con un párrafo en este documento:
   qué promete, a quién, y qué no hace.
5. **Mover archivos solo con el editor de Godot** (o con `git mv` + corrección de rutas verificada por `grep res://`).
6. **Tamaño:** un archivo que pasa de ~40 KB se parte por responsabilidad, no por línea. `vfx_3d.gd` (111 KB) es el
   siguiente candidato del Pipeline: un archivo por elemento (`vfx_elementos/` ya apunta ahí).

## 6. Qué puede proponer Pablo ahora

- Nombres de los módulos y de las carpetas (§2) — son propuesta.
- Si `AccionElemental` lleva `cantidad` en unidades físicas (u³, segundos) o en «niveles» de diseño (1–3). El Juego
  prefiere físicas: la simulación ya las usa.
- Si la fachada `Mundo3D` es un nodo (señales de Godot, fácil de conectar) o un `RefCounted` (más puro, pero las
  señales se emiten igual). Propuesta: nodo.
- Si M4 (cortar la herencia del 2D) va antes que M3: M4 es grande pero mecánico; M3 toca diseño.

## 7. Correspondencia con el documento de estructura de Pablo (`docs/Estructura del codigo/…docx`)

Para que el documento de Pablo y el código hablen el mismo idioma: qué existe ya, dónde, y qué falta.

| Sistema del documento | Qué hay hoy | Dónde | Qué falta / hacia dónde va |
|---|---|---|---|
| **Player System** (Controller, Movement, Interaction, MagicCaster, Health, Inventory, StateMachine, Progression) | Movimiento, nado, trepar, hablar, inventario (BolsaUI), vida | `jugador_3d.gd`, `pj_3d.gd`, `equipo_3d.gd`, `bolsa_ui.gd`, `estado.gd`, `repertoire.gd` | No hay máquina de estados explícita (IDLE/MOVING/CASTING/HIT/DEAD): los estados son booleanos sueltos (`nadando`, `preso`, modo lanzar). Candidato M-jugador: un `enum Estado` en `Jugador3D` con transiciones en un solo sitio |
| **SymbolRecognizer** | Reconocedor $P con plantillas grabadas (`G`) | `gesture_recognizer.gd`, `gesture_library.(gd|tres)`, `tools/podar_gestos.py` | Ya es un módulo limpio; va a `nucleo/` |
| **SymbolDefinition** (sellos; glifos de geometría X/Y/Z; glifos de propiedad) | Sellos = elementos (`Runes`, `*_rune.tres`); glifos = `Sigils.FORM`; geometría = Fase 8 (Línea, Altura, Tamaño) | `runes.gd`, `rune_data.gd`, `sigils.gd`, `lanzador_3d.gd::GeometriaHechizo` | El documento pide «valor fijo de X, Y, Z» por glifo: `GeometriaHechizo` ya calcula `largo/alto/radio`; faltaría exponerlo como X/Y/Z en el HUD (es lo que usa el chorro 11.17) |
| **SpellDefinition / SpellCaster** (hasta 2 elementos + 6 glifos) | Receta = `SpellRecipe` + `Receta3D`; lanzador = `Lanzador3D` (1 elemento, un glifo por sector, 3 páginas) | `spell_recipe.gd`, `lanzador_3d.gd` | Tras M1/M4 el Lanzador queda solo con esto (magia). Dos elementos = `ElementCombinationResolver`, hoy inexistente (rayo y hielo son elementos directos) |
| **ElementalReceiver** (`flammable`, `freezable`, `conductive`, `wettable`, `breakable`) y `target.receive_element(FIRE)` | **Existe y es el contrato bueno:** `on_spell_hit(rune, dir)`, `spell_reacts(rune)`, `carried_element()`, `nivel_altura()` | `objetos_3d.gd` (`Reactivo3D`), `surtidor_3d.gd`, `combate_3d.gd`, barreras en `lanzador_3d.gd` | Las propiedades están implícitas en el tipo (`tipo == "telarana"` arde). M3 las hace explícitas: `Reactivo3D.propiedades = {"arde": true, "conduce": false…}` y `on_spell_hit` las consulta; `receive_element` ≡ `on_spell_hit` |
| **ReactionResolver / ElementalInteractionSystem** | Repartido: `hechizo_sobre_agua`, `atrapar`, `abrir_caudal`, `al_impactar` de la maqueta, tabla de `ESTADOS_SUELO.md` | `lanzador_3d.gd`, `prueba_test2.gd` | Es exactamente `Mundo3D.aplicar(AccionElemental)` (§3.3): un solo sitio |
| **ElementalState / Status Effects** (BURNING, WET, FROZEN, SHOCKED; `WET + ICE → FROZEN`) | Mojado y hielo con tiempo en `AguaSim3D`; `preso_hielo` en goblins; fuego/hielo del suelo con caducidad | `agua_sim_3d.gd`, `combate_3d.gd`, `lanzador_3d.gd` | No hay sistema de estados por entidad (duración, modificadores, combinaciones). Candidato: `nucleo/estado_elemental.gd` (datos: nombre, duración, modificadores) + `EstadosSuelo3D` para casillas y un componente para entidades. Las reglas `WET+ICE→FROZEN` se escriben como tabla, no como `if` en cada objeto |
| **DamagePayload** (amount, type, element, source, knockback, status) | `on_spell_hit(rune)` + tabla de debilidades de `CombateComun` | `combate_3d.gd` | Hoy el daño se deduce del elemento; no hay payload. Con `AccionElemental` (§3.3) el payload es la propia acción más `dano` y `empuje` |
| **Enemy** (Data, Brain, Combat, Movement, Perception) | IA de goblins (guerrero, arquero), área de influencia, vuelta a casa, retardo de ataque | `combate_3d.gd` (45 KB, 59 funciones) | Todo en un archivo: partir en `enemigos/goblin_ia.gd` (Brain), `enemigos/combate_3d.gd` (Combat/Health) y datos por tipo en un `.tres` (Data) |
| **Puzzle** (Trigger / Condition / Action / State) | Reglas escritas a mano por nivel | `bosque_3d.gd`, `jugabilidad_3d.gd`, `nivel_pruebas.gd` | Lo que el documento llama piezas (`RuneReceiver`, `WaterLevelDetector`…) son `Reactivo3D` que emiten señal; falta el `SequenceController`/`Counter` genérico. Candidato tras M2: `niveles/puzle.gd` que conecta señales de `Mundo3D` y de reactivos a acciones (`abrir_puerta`, `encender_runa`) |
| **World Interaction** (WaterPool LIQUID/FROZEN/ELECTRIFIED) | `AguaSim3D` + hielo + `electrificar_agua` | `agua_sim_3d.gd`, `prueba_test2.gd` | Electrificado vive en la maqueta (Pipeline): en M2 pasa a `EstadosSuelo3D` |
