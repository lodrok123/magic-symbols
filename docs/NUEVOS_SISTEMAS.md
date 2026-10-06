# Sistemas nuevos

## Qué escena abrir (F6 sobre la escena)
| Escena | Script | Qué es |
|---|---|---|
| `TestJugabilidad.tscn` | `test_jugabilidad.gd` | El mapa de siempre (23x23) con TODO lo nuevo integrado |
| `Mundo.tscn` | `mundo.gd` | El mapa grande (40x34): aldea, prado, bosque, río, fuerte |
| `Test2.tscn` | `test_2.gd` | Laboratorio 40x40: una prueba por elemento (ver `docs/TEST2_CONCLUSIONES.md`) |
| `VfxLabMundo.tscn` | `vfx_lab_mundo.gd` | Cada elemento aislado en su bahía contra lo que reacciona (F9 ↔ VfxLab) |
| `VfxLab.tscn` | `vfx_lab.gd` | El laboratorio clásico de glifos (ahora F9 lleva al de mundo) |

## Cómo se heredan los niveles
```
nivel_base.gd              EL MOTOR: construir el plano (agua y su hielo, árboles, puente, tótems,
  │                        fogatas, empujables...), jugador, cámara, interfaz, NPC y diálogo, puestos
  │                        con tendero al norte, mochila, botín, recolectables, alquimista, encargos,
  │                        goblins con IA, guardados, pantalla de muerte, placa de peso, 4 tareas
  ├─ test_jugabilidad.gd   SOLO DATOS: el mapa de siempre (plano, props, setos, botín, guardados...)
  ├─ mundo.gd              el mapa grande
  ├─ test_2.gd             el laboratorio de elementos (sus 6 pruebas en vez de las 4 tareas)
  └─ vfx_lab_mundo.gd      las bahías del laboratorio de VFX
```
Un nivel solo **sobrescribe** lo suyo: `_mapa()`, `_lista_props()`, `_lista_setos()`, `_suelo_objetos()`,
`_celdas_guardado()`, `_lista_empujables()`, `_puestos()`, `_definir_encargos()`, `_letra_extra()`,
`_extras_nivel()`, `_repertorio_inicial()` y, si sus tareas son otras, `_progreso()` / `_refrescar_hud()` /
`_actualizar_tareas()`. Todas tienen un valor por defecto vacío en el motor.

**Por qué se invirtió (4/10/2026).** Antes el motor vivía dentro de `test_jugabilidad.gd` y los demás niveles
dependían de unos ganchos marcados "NO BORRAR": si otra conversación reescribía ese archivo desde una copia
vieja, Mundo y Test 2 dejaban de arrancar (pasó una vez). Ahora `test_jugabilidad.gd` es un nivel más: se
puede editar o reescribir sin romper a nadie. **Lo que cuesta:** el motor es un archivo largo (~2500
líneas) y los cambios de mecánicas (cómo arde algo, cómo se congela el agua en el plano...) ahora se hacen en
`nivel_base.gd`, no en `test_jugabilidad.gd`. Si otra conversación tiene una copia vieja de
`test_jugabilidad.gd` con el motor dentro, **no debe subirla**: hay que pasarle sus cambios a `nivel_base.gd`.

Al invertirlo se quitó el puesto antiguo de un solo vendedor (pociones a 2 de oro y tomos de hielo/tierra):
lo sustituyen la librera y el alquimista. Y un arreglo de paso: los setos del mapa de siempre ya no quitan
decorado en esas mismas casillas de los otros mapas.

## Letras del plano que añade nivel_base.gd
`n` puesto de la librera · `Q` puesto del alquimista (el puesto ocupa x y x+1; el tendero va AL NORTE, en x,y-1)
· `M` guardabosques · `D` dummy · `s f q` seta/flor/raíz reactivas · `O` fogata de encargo ·
`K` placa de peso (solo la pisa un bloque de tierra o un empujable, no el jugador).

## Archivos nuevos
| Archivo | Para qué |
|---|---|
| `nivel_base.gd` | El motor común de todos los niveles |
| `test_2.gd`, `vfx_lab_mundo.gd` | Niveles (ver arriba) |
| `recolectable.gd` | Decorado que se recoge con E (lavanda, bayas, helecho, flores, piedras) y rebrota |
| `estado.gd` | Oro, mochila (8→20 huecos, pilas de 9), mejoras. `Estado.i()` |
| `objetos.gd` | Catálogo de objetos, tabla planta+elemento→ingrediente, iconos dibujados |
| `sonidos.gd` | Sonidos sintetizados: bolsa, moneda, poción, golpe, compra |
| `botin.gd` | Objetos en el suelo (oro/poción se cogen solos; ingredientes con E) |
| `combate_comun.gd` | Barra de vida (siempre visible), debilidades, efectos por elemento, botín, IA |
| `goblin_guerrero.gd` / `goblin_arquero.gd` / `goblin_escarcha.gd` | IA de goblins y el dummy |
| `reagente.gd` | Plantas que dan ingredientes al reaccionar con un elemento |
| `bolsa_ui.gd` | Mochila: barra de 8 huecos siempre visible (abajo a la derecha) + ventana completa con I |
| `pantalla_muerte.gd` | "HAS MUERTO" al acabar la animación de caída + volver al último guardado |
| `misiones.gd` | Encargos de los guardabosques (matar, quemar, apagar; 100 de oro) |
| `alquimia.gd` | Mejoras del alquimista (oro + ingredientes): vida, huecos, cura, velocidad |

## Archivos tocados (cambios pequeños)
`player.gd` (muerte: espera a que acabe la animación), `ms_atlas.gd` (clip de muerte
`shot_in_the_back_and_fall` → `death` → `hit_reaction_to_waist`), `spell.gd` (**arreglo**: los hechizos
morían al instante en la mitad lejana de los mapas grandes porque se medía la distancia al origen de la
escena; ahora se mide lo recorrido), `vfx_lab.gd` (tecla F9), `test_jugabilidad.gd` (ahora solo datos del nivel), `project.godot` (escena
principal `Mundo.tscn`; quitado el plugin `ms_sprite_importer`, que no existía).

## Elementos y sus propiedades (sobre enemigos)
- **fuego**: daño + quemadura 3 s (el mojado la apaga con vapor)
- **agua**: daño + mojado 6 s (más lento; el rayo hace +50 % y salta a otro enemigo)
- **rayo**: daño alto + aturde; mojado → descarga en cadena
- **hielo**: poco daño + congela (más si está mojado)
- **viento**: interrumpe lo que hace y lo empuja lejos
- **tierra**: pedrada con daño propio, retroceso fuerte y lentitud

Debilidades (x2) y resistencias (x0,5): guerrero débil al agua / resiste fuego; arquero débil al fuego /
resiste tierra; dummy débil al fuego / resiste agua y hielo. El rombo de color junto a la barra indica la debilidad.

## Teclas
I mochila · Q beber poción · E hablar / recoger / comprar en un puesto · clic en un hueco de la barra con
una poción = beberla · clic sobre un objeto del suelo = ver su nombre.
