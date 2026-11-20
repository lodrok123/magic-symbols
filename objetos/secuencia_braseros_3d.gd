class_name SecuenciaBraseros3D
extends Node3D

## BRASEROS EN ORDEN (F15 del laboratorio de fuego, 20/11/2026). Una fila de braseros (`de=<casillas EN ORDEN>`) que hay que encender en ESE orden: el primero de la lista primero, el último al final. Es el hermano de
## `EstatuasPulso3D` (las estatuas piden pulsos de un elemento en un orden) pero con braseros y sin elementos: encender el brasero que toca es un ACIERTO (`acierta`); encender cualquier otro, o uno que aún no
## toca, es un FALLO: TODOS los braseros de la secuencia se APAGAN (también el que se acababa de encender), con un sonido grave, y se empieza de nuevo (`falla`). Al encender el último en su sitio se pone la flag `flag`
## (si hay) y se emite `completa`; hecha, se queda hecha (los braseros ya no se apagan por la secuencia y siguen ardiendo mientras nada más los apague). El orden NO está a la vista: la pista es el MURAL (`MuralPuzle3D`).
##
## Usa la señal `llama(encendida)` de cada brasero (Reactivo3D): vale cualquier forma de encenderlos (hechizo de fuego, contagio, una regla `encender`). Una regla que enciende varios en el mismo fotograma lo hace en
## el orden en que están escritas sus acciones. Los braseros con `rele` (se apagan solos) no sirven aquí.
##
## Se coloca desde un mapa con `; pieza <id> secuencia <x> <y> de=<x,y+x,y+…> [flag=<nombre>]` (escenas/puzle.gd): x,y es solo el sitio del nodo (suena ahí). Señales `acierta(indice, paso)`, `falla`, `completa`;
## condiciones `completa`|`pendiente`.

signal acierta(indice: int, paso: int)
signal falla
signal completa

const TONO_FALLO: float = 0.45
const TONO_PASO: Array = [0.85, 1.05, 1.3, 1.55]
const SFX_ACIERTO: String = "fuego_carga"
const SFX_FALLO: String = "derrumbe"

var braseros: Array = []                      ## los Reactivo3D, en el orden pedido
var celdas: Array = []
var flag: String = ""
var paso: int = 0                             ## cuántos lleva encendidos en orden
var hecha: bool = false
var aciertos: int = 0                         ## las pruebas
var fallos: int = 0                           ## las pruebas
var _reiniciando: bool = false


## `p_braseros`: los Reactivo3D en orden; `p_celdas`: sus casillas (el mismo orden). Se llama ANTES de colgarla del árbol.
func preparar(p_braseros: Array, p_celdas: Array, p_flag: String = "") -> void:
	braseros = p_braseros
	celdas = p_celdas
	flag = p_flag


func _ready() -> void:
	for i in range(braseros.size()):
		var b: Reactivo3D = braseros[i] as Reactivo3D
		if b != null and is_instance_valid(b):
			b.llama.connect(_al_llama.bind(i))
	if flag != "" and Flags.i().tiene(flag):
		hecha = true                           # partida cargada: ya estaba hecha, los braseros vuelven a arder sin efecto
		paso = braseros.size()
		for b in braseros:
			if is_instance_valid(b):
				(b as Reactivo3D).encender_llama()


## ¿Cuál es el siguiente brasero que toca? (-1 si ya está hecha.) Para las pruebas.
func siguiente() -> int:
	return -1 if hecha else paso


func _al_llama(encendida: bool, indice: int) -> void:
	if not encendida or hecha or _reiniciando:
		return
	if indice == paso:
		paso += 1
		aciertos += 1
		if is_inside_tree():
			Sfx.play(self, SFX_ACIERTO, float(TONO_PASO[mini(paso - 1, TONO_PASO.size() - 1)]))
		acierta.emit(indice, paso)
		if paso >= braseros.size():
			_completar()
		return
	_fallar()


## Fallo: se apagan todos (con un instante de por medio: la regla que encendió el último aún no ha acabado) y se empieza de nuevo.
func _fallar() -> void:
	fallos += 1
	paso = 0
	_reiniciando = true
	for b in braseros:
		if is_instance_valid(b):
			(b as Reactivo3D).apagar_llama()
	_reiniciando = false
	if is_inside_tree():
		Sfx.play(self, SFX_FALLO, TONO_FALLO)
	falla.emit()


func _completar() -> void:
	hecha = true
	if flag != "" and not Flags.i().tiene(flag):
		Flags.i().poner(flag)
	Puzle3D._logro("puzle_resuelto", self)
	completa.emit()
