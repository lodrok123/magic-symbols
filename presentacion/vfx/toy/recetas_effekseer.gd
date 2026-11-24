extends RefCounted

## RECETAS DE IMPACTO TRADUCIDAS DE EFFEKSEER (25/11/2026). Las reproduce impacto_capas_toy.gd con NUESTRAS piezas y la paleta de cada elemento; aquí solo va la coreografía.
## Cómo se sacaron: `python herramientas/effekseer_receta.py <efecto>.efkefc --salida output/effekseer_impactos_2026-11-25/recetas` (XML del editor + `_plano.txt` con cada capa).
## Efectos de la demo oficial de EffekseerForGodot4 (Demo/effects), probada aparte en E:\pruebas_effekseer\demo. No se copia ninguna textura ni material de Effekseer.
## Conversión: tiempos de fotogramas a 60 fps → s. Tamaños: las unidades de Effekseer se pasan a metros a ojo para que el conjunto mida como nuestros impactos con la bola del lab
## (radio 0,4 m); el factor va en «escala» de cada receta. Curvas: Effekseer «Easing» con StartSpeed > 0 = «sal» (rápido y se asienta); FadeIn / FadeOut → «aparece» / «se_va» (s).
## Campos de una capa (todos opcionales salvo «pieza»; ver impacto_capas_toy.gd):
##   pieza  sprite | halo | chispas | gotas | piedras | humo | grieta | onda | luz
##   nombre la capa de Effekseer de la que sale · t0 retraso (s) · vida (s o [mín, máx]) · n copias · emision (s en que se reparten los nacimientos) · escalonado (s entre copias)
##   tam [inicio, fin] (m) · curva sal | lineal | entra | suave · aparece / se_va (s) · brillo · fuerza (0..1)
##   sprite: tex destello | estallido | bola | mancha · modo aditivo | mezcla · plano (tumbado en la superficie) · altura (× radio) · disperso (m) · sube (m/s) · calor [ini, fin] · tramo · giro (rad/s)
##   halo: anillo (0 disco, 1 aro) · caida · plano · tono (punto de la rampa del elemento en vez de su color de halo)
##   chispas / gotas / piedras: cono [cos mín, cos máx] respecto a la normal · vel [m/s] · roce (1/s) · g (× gravedad; < 0 sube) · r0 [m] · h0 (m) · largo / ancho [m] · brasas (fracción: punto redondo o burbuja)
##   humo: tam [ini, fin] · vida_media · vel · cono · r0 · deriva (m/s² hacia arriba)
##   grieta: tam · abre (s) · marca (peso de la marca de suelo) · onda: tam · anillos · charco · luz: energia · decae (1/s) · rango
## Cada receta lleva «actual» (con qué impacto de ahora se compara en el lab) y «no_traducido» (lo que se dejó fuera y por qué).

const RECETAS: Array = [
	{
		"id": "hit01", "titulo": "Golpe hit01", "origen": "sample-material3/ef_parts_hit01.efkefc (4 capas, 0,42 s)",
		"elemento": "fuego", "superficie": "pared", "actual": "ImpactoFuegoToy GOLPE (estilo C)", "escala": "1 u Effekseer ≈ 0,08 m",
		"capas": [
			{"pieza": "halo", "nombre": "light", "t0": 0.0, "vida": 0.05, "tam": [2.4, 0.4], "curva": "lineal", "brillo": 1.4, "caida": 2.6, "se_va": 0.05},
			{"pieza": "sprite", "nombre": "flash", "tex": "rayos", "modo": "aditivo", "t0": 0.0, "vida": 0.1, "tam": [2.0, 0.3], "curva": "lineal", "brillo": 1.6,
				"tramo": Vector2(0.6, 1.0), "altura": 0.22, "se_va": 0.0},
			{"pieza": "halo", "nombre": "light_ring", "anillo": 1.0, "t0": 0.0, "vida": 0.167, "tam": [0.64, 1.6], "curva": "sal", "brillo": 2.6, "aparece": 0.083, "se_va": 0.167},
			{"pieza": "halo", "nombre": "dist", "anillo": 1.0, "t0": 0.033, "vida": 0.42, "tam": [0.0, 1.28], "curva": "sal", "brillo": 0.35, "aparece": 0.083, "se_va": 0.33},
			{"pieza": "luz", "nombre": "(nuestra)", "energia": 1.5, "decae": 10.0, "rango": 3.4},
		],
		"no_traducido": ["dist: distorsión del aire (no tenemos shader de distorsión) → anillo tenue", "aro nítido (tx_shockring): no hay textura de aro; el halo-anillo es blando", "estrella tx_hit01 → T_VFX_Flare_666 de Le Lu", "la luz no está en Effekseer: es la de nuestro golpe"],
	},
	{
		"id": "toonhit", "titulo": "Golpe toon", "origen": "sample-material2/ToonHit.efkefc (7 capas, ~1,2 s)",
		"elemento": "fuego", "superficie": "pared", "actual": "ImpactoFuegoToy GOLPE (estilo C)", "escala": "1 u Effekseer ≈ 0,06 m",
		"capas": [
			{"pieza": "halo", "nombre": "Glow", "t0": 0.067, "vida": 0.67, "tam": [0.12, 0.9], "curva": "sal", "brillo": 1.0, "caida": 2.0, "aparece": 0.133, "se_va": 0.33},
			{"pieza": "halo", "nombre": "HitBase (esfera toon → aro)", "anillo": 1.0, "plano": true, "n": 3, "t0": 0.15, "escalonado": 0.05, "vida": [0.67, 1.0], "tam": [0.0, 1.6], "curva": "sal",
				"brillo": 1.6, "tono": 0.55, "se_va": 0.35},
			{"pieza": "halo", "nombre": "HitSub (esfera toon → aro)", "anillo": 1.0, "plano": true, "n": 3, "t0": 0.18, "escalonado": 0.04, "vida": [0.6, 1.0], "tam": [0.0, 1.0], "curva": "sal",
				"brillo": 1.4, "tono": 0.7, "se_va": 0.35},
			{"pieza": "chispas", "nombre": "HitLine", "n": 8, "t0": 0.15, "vida": [0.42, 0.75], "cono": [0.0, 1.0], "vel": [3.0, 5.0], "roce": 5.0, "g": 0.0,
				"largo": [0.8, 1.4], "ancho": [0.05, 0.07], "brillo": 2.2},
			{"pieza": "chispas", "nombre": "HitLineNull/HitLine", "n": 30, "t0": 0.17, "emision": 0.07, "vida": [0.33, 1.0], "cono": [0.0, 1.0], "vel": [2.0, 4.0], "roce": 5.0, "g": 0.0,
				"largo": [0.3, 0.6], "ancho": [0.025, 0.035], "brillo": 1.9},
			{"pieza": "halo", "nombre": "Ring", "anillo": 1.0, "plano": true, "n": 3, "t0": 0.15, "escalonado": 0.04, "vida": [0.33, 0.83], "tam": [0.0, 1.3], "curva": "sal", "brillo": 1.2, "se_va": 0.3},
			{"pieza": "luz", "nombre": "(nuestra)", "energia": 1.5, "decae": 6.0, "rango": 3.4},
		],
		"no_traducido": ["HitBase / HitSub: esferas toon de rayas (material ToonImpact; la pared las corta en arcos) → aros tumbados en la pared", "6 anillos → 3", "40 rayas pequeñas → 30"],
	},
	{
		"id": "fire02", "titulo": "Explosión fire02", "origen": "sample-material3/ef_fire02.efkefc, fase 02_impact (16 capas, ~2 s)",
		"elemento": "fuego", "superficie": "suelo", "actual": "ExplosionFuegoToy (barril, radio 1,8)", "escala": "a ojo: del tamaño de la explosión del barril (≈ 4 m)",
		"capas": [
			{"pieza": "halo", "nombre": "Flash01_add", "t0": 0.0, "vida": 0.083, "tam": [3.4, 4.6], "curva": "sal", "brillo": 1.6, "caida": 2.0, "aparece": 0.03, "se_va": 0.06, "altura": 2.0},
			{"pieza": "halo", "nombre": "Glow01", "t0": 0.033, "vida": 0.58, "tam": [2.4, 4.4], "curva": "sal", "brillo": 1.0, "caida": 2.2, "aparece": 0.05, "se_va": 0.17, "altura": 2.0},
			{"pieza": "halo", "nombre": "Glow01_add", "t0": 0.033, "vida": 0.42, "tam": [1.2, 1.8], "curva": "sal", "brillo": 1.4, "caida": 2.6, "se_va": 0.08, "altura": 2.0},
			{"pieza": "sprite", "nombre": "Fire01_add", "tex": "bola", "modo": "mezcla", "n": 9, "t0": 0.033, "emision": 0.15, "vida": [0.4, 0.9], "tam": [0.6, 1.5], "curva": "sal",
				"disperso": 0.6, "altura": 0.8, "sube": 0.4, "calor": [0.0, -0.1], "tramo": Vector2(0.0, 0.5), "recorte": Vector2(0.24, 0.62), "luminancia": Vector2(0.25, 0.85), "se_va": 0.5},
			{"pieza": "humo", "nombre": "smoke01 (×2)", "n": 8, "colores": {"claro": Color(0.42, 0.36, 0.34), "sombra": Color(0.26, 0.21, 0.2), "viejo": Color(0.35, 0.32, 0.32)}, "t0": 0.3, "emision": 0.4, "vida_media": 1.3, "tam": [0.5, 1.4], "vel": [0.5, 1.2], "cono": [0.3, 1.0],
				"r0": [0.3, 0.9], "h0": 0.6, "deriva": 0.5},
			{"pieza": "chispas", "nombre": "par01_add", "n": 30, "t0": 0.033, "emision": 0.15, "vida": [0.33, 1.0], "cono": [0.0, 1.0], "vel": [2.5, 6.0], "roce": 2.0, "g": -0.05,
				"brasas": 1.0, "ancho": [0.04, 0.06], "r0": [0.3, 1.0], "h0": 0.3},
			{"pieza": "chispas", "nombre": "par02_add", "n": 30, "t0": 0.42, "emision": 0.15, "vida": [0.33, 1.0], "cono": [0.0, 1.0], "vel": [1.5, 4.0], "roce": 2.0, "g": -0.05,
				"brasas": 1.0, "ancho": [0.04, 0.06], "r0": [0.4, 1.2], "h0": 0.5},
			{"pieza": "chispas", "nombre": "Line01_add", "n": 10, "t0": 0.033, "emision": 0.08, "vida": [0.33, 0.67], "cono": [0.2, 1.0], "vel": [8.0, 13.0], "roce": 3.0, "g": 0.3,
				"largo": [0.8, 1.3], "ancho": [0.06, 0.09], "h0": 0.2},
			{"pieza": "luz", "nombre": "(nuestra)", "energia": 3.0, "decae": 4.0, "rango": 5.0},
		],
		"no_traducido": ["01_firest: la fase de CARGA (polvo y rayas que se juntan en 0,8 s): ya tenemos nuestra carga", "wind01-04: rastros en remolino (no tenemos cinta en espiral)",
			"el disuelto por ruido (mt_dissolve02) → la erosión de nuestro flipbook"],
	},
	{
		"id": "toonwater", "titulo": "Salpicadura toon", "origen": "sample-material2/ToonWater.efkefc, solo la salpicadura (Impact, GloundGlow, GloundWater, Particle)",
		"elemento": "agua", "superficie": "suelo", "actual": "ImpactoAguaToy GOLPE", "escala": "1 u Effekseer ≈ 0,25 m",
		"capas": [
			{"pieza": "halo", "nombre": "GloundGlow", "plano": true, "t0": 0.133, "vida": 1.0, "tam": [1.0, 2.5], "curva": "sal", "brillo": 1.0, "caida": 1.5, "aparece": 0.17, "se_va": 0.33},
			{"pieza": "onda", "nombre": "GloundWater", "n": 3, "t0": 0.05, "escalonado": 0.07, "vida": 0.9, "tam": 2.6, "anillos": 2.0, "charco": 0.35},
			{"pieza": "gotas", "nombre": "Impact/Solashes", "n": 40, "t0": 0.0, "emision": 0.05, "vida": [0.5, 1.0], "cono": [0.5, 0.85], "vel": [3.0, 4.5], "g": 1.0, "roce": 0.6,
				"largo": [0.25, 0.4], "ancho": [0.09, 0.14], "r0": [0.1, 0.25]},
			{"pieza": "gotas", "nombre": "Particle", "n": 40, "t0": 0.1, "emision": 0.3, "vida": [0.33, 1.0], "cono": [0.85, 1.0], "vel": [1.0, 2.6], "g": 0.35, "roce": 1.2,
				"r0": [0.2, 0.6], "largo": [0.06, 0.1], "ancho": [0.04, 0.07], "brasas": 0.3},
		],
		"no_traducido": ["Tube: la columna de agua de 2 s (es un géiser, no un impacto)", "Omen: el aviso previo · Rast: la resaca del final",
			"Solashes: cintas en arco → corona de gotas", "brillo aditivo de Particle → gotas y burbujas (el agua no es luz)"],
	},
	{
		"id": "tierra", "titulo": "Golpe de tierra", "origen": "sample-material3/ef_fire03.efkefc (grieta, rocas, polvo) + ef_ice01.efkefc (debris01)",
		"elemento": "tierra", "superficie": "suelo", "actual": "ImpactoTierraToy GOLPE", "escala": "a ojo: grieta de 2 m",
		"capas": [
			{"pieza": "grieta", "nombre": "Crack01_Ground", "t0": 0.0, "vida": 2.0, "abre": 0.1, "se_va": 0.8, "tam": 2.0, "marca": 0.7},
			{"pieza": "sprite", "nombre": "flash01_add → estallido de polvo", "tex": "estallido", "modo": "mezcla", "plano": true, "t0": 0.0, "vida": 0.33, "tam": [0.6, 1.6],
				"curva": "sal", "tramo": Vector2(0.4, 1.0), "recorte": Vector2(0.16, 0.7), "luminancia": Vector2(0.15, 0.95), "altura": 0.1, "se_va": 0.2},
			{"pieza": "piedras", "nombre": "rock_par01/02", "n": 14, "t0": 0.0, "emision": 0.05, "vida": [0.6, 1.0], "cono": [0.45, 0.95], "vel": [2.5, 4.5], "g": 1.0, "roce": 0.3,
				"ancho": [0.04, 0.08]},
			{"pieza": "piedras", "nombre": "debris01 (ice01)", "n": 20, "t0": 0.02, "vida": [0.2, 0.8], "cono": [0.2, 0.9], "vel": [3.0, 6.0], "g": 1.0, "roce": 0.8, "ancho": [0.015, 0.035]},
			{"pieza": "piedras", "nombre": "rocks_ground01", "n": 5, "t0": 0.0, "vida": [1.25, 1.4], "cono": [0.3, 0.6], "vel": [1.0, 2.0], "g": 1.0, "roce": 0.3, "ancho": [0.07, 0.11]},
			{"pieza": "humo", "nombre": "smoke01", "n": 14, "t0": 0.03, "emision": 0.25, "vida_media": 1.2, "tam": [0.3, 0.9], "vel": [0.8, 2.0], "cono": [0.05, 0.5], "r0": [0.05, 0.3],
				"deriva": 0.25},
			{"pieza": "humo", "nombre": "wind01 (polvo rasante)", "n": 8, "t0": 0.0, "emision": 0.05, "vida_media": 0.8, "tam": [0.2, 0.6], "vel": [2.0, 3.0], "cono": [0.0, 0.15],
				"r0": [0.1, 0.2], "deriva": 0.1},
		],
		"no_traducido": ["GroundGlay (oscurecer el suelo): ya lo hace la marca de la grieta", "line01, par01_add, Glow, flash de luz: la tierra no brilla",
			"ice_mesh01 (cristal): no es tierra", "la grieta de Effekseer dura 3,3 s → 2 s"],
	},
]


static func receta(id: String) -> Dictionary:
	for r in RECETAS:
		if String(r["id"]) == id:
			return r
	return {}
