# Pantano y Bosque · Objetos, puzles y enemigos

La pasarela de los alrededores de la Torre del Agua sirve de ruta principal. Un desvío lleva a un recinto circular de piedra con ofrendas. En el Bosque aparecen la misma piedra labrada, las tinajas de arcos pintados y los bronces, junto a muros secos y claros. La planta circular remite a los castros del noroeste. Las piezas votivas y la cerámica toman formas del mundo ibérico.

## Lámina 04 · Mecanismos

Orden de lectura por filas. Los tamaños se ajustan al separar el GLB.

| Pieza | Uso en el Pantano | Uso en el Bosque |
|---|---|---|
| Brasero cerámico perforado | Señala un vado de barro que se puede secar | Enciende el acceso a un claro |
| Canaleta de piedra | Conduce agua a una pila baja | Alimenta un abrevadero |
| Contrapeso de barro con anilla | Mantiene abierto el paso de mantenimiento | Acciona un portillo |
| Diana de bronce sobre piedra | Libera el pestillo desde la otra orilla | Acciona un postigo al final de un sendero recto |
| Encastre circular de piedra | Señala dónde asentar una pieza de tierra | Marca el punto de apoyo de un mecanismo del santuario |
| Compuerta de madera y piedra | Controla el agua del canal | Cierra un paso estrecho entre muros |

## Recorrido propuesto

1. **El vado de los braseros · Fuego + Línea X/Y.** Un brazo de barro cruza la ruta de lado a lado y el siguiente discurre a lo largo de la marcha. Un par de braseros en cada extremo marca su eje. Cada línea seca una franja pisable. La textura pasa de barro oscuro y brillante a terrones mates. El secado temporal es una regla propuesta.
2. **La compuerta del embarcadero · Agua + Flecha.** Desde un ensanche seguro, dispara a la diana de bronce en la orilla opuesta. El impacto libera el pestillo y la compuerta deja pasar agua por la canaleta. Una pila receptora se llena y habilita el desembarco. La diana escucha impactos de agua como comportamiento específico de esta pieza.
3. **El recinto de las ofrendas · Agua + Pulso.** Dos pedestales bajos rodean la pila. Desde el centro, un solo pulso alcanza ambos. Cada receptor confirma con un tono y el brillo del engaste. Activarlos abre el atajo al Bosque. La recepción por elemento se puede apoyar en `ReceptorPulso3D`.
4. **El contrapeso de la pasarela · Tierra + Posición + Permanencia.** Desde un mirador se ve un encastre en una casilla libre de la orilla de servicio. La jugadora coloca allí tierra persistente. Su peso mantiene accionado el mecanismo mientras cruza la pasarela. La compuerta se fija al accionar una palanca al otro lado. El peso del bloque sobre el mecanismo requiere una regla específica. Colocar el origen exige alcance, suelo libre y línea de visión.

## Enemigos propuestos

| Enemigo | Diseño y aviso | Respuesta con el repertorio disponible |
|---|---|---|
| **Guardián de la ofrenda** | Exvoto de bronce animado. Se lleva las manos al pecho antes de lanzar un proyectil por un carril. Al disparar abre la guardia. | **Tierra + Línea** corta el carril. **Agua + Flecha** alcanza el pecho durante la apertura. Puede partir del patrón del arquero y la barrera. |
| **Jabalí de piedra** | Escultura fantástica de cuerpo bajo inspirada en los verracos de tradición vetona. Escarba y baja la cabeza antes de embestir en línea recta. | Esquiva o intercepta con **Tierra + Línea**. Si choca contra un sólido, queda aturdido y expone el costado a **Fuego + Flecha**. En el Bosque patrulla un recinto. En el Pantano carga por una ribera seca. |
| **Limo del brasero** | Limo de barro que se cubre con un fragmento de vasija pintada. La costra cruje y se levanta antes del salto. | **Agua + Pulso** desprende la costra de los limos cercanos. **Fuego + Flecha** aprovecha la apertura. Puede partir del limo existente y usar la tinaja rota como referencia de la cobertura. |

Los puntos débiles, el aturdimiento por choque y la costra son reglas de diseño para prototipar. El primer encuentro de cada enemigo funciona en suelo firme y enseña su aviso antes de combinarlo con barro o agua.
