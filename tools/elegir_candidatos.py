"""ELEGIR CANDIDATOS (26/11/2026): apunta en docs/fab_ue/candidatos_vegetacion.json lo que Pablo elige para cada pieza.

    python tools/elegir_candidatos.py 1abc 2bc 3c 4a 7actual 9ab+actual

Cada argumento: el número de la pieza y las letras elegidas (varias = el juego alterna entre ellas); «actual» = mantener la pieza
actual (sola, o en la mezcla si va con letras: «9ab+actual»). Guarda en «elegido» la lista de piezas (pn_<candidato> o la actual).
«5nueva:a» = el candidato a NO sustituye: se añade al juego como pieza NUEVA de su tipo (campo «nuevas»); se combina: «6actual 6nueva:bc».
"""
import io
import json
import re
import sys

RUTA = "docs/fab_ue/candidatos_vegetacion.json"


def main() -> None:
	if len(sys.argv) < 2:
		print(__doc__)
		sys.exit(1)
	with io.open(RUTA, encoding="utf-8") as f:
		d = json.load(f)
	filas = [f for g in d["grupos"] for f in g["filas"]]
	for arg in sys.argv[1:]:
		mn = re.fullmatch(r"(\d+)nueva:([abc]+)", arg.strip().lower())
		if mn:
			fila = filas[int(mn.group(1)) - 1]
			fila["nuevas"] = ["pn_" + fila["candidatos"]["abc".index(c)] for c in mn.group(2)]
			print("%2d %-16s -> piezas NUEVAS: %s" % (int(mn.group(1)), fila["actual"], ", ".join(fila["nuevas"])))
			continue
		m = re.fullmatch(r"(\d+)([abc]*)(\+?actual)?", arg.strip().lower())
		if not m:
			print("no entiendo:", arg)
			sys.exit(1)
		n, letras, actual = int(m.group(1)), m.group(2), m.group(3)
		fila = filas[n - 1]
		eleg = ["pn_" + fila["candidatos"]["abc".index(c)] for c in letras]
		if actual:
			eleg.append(fila["actual"])
		fila["elegido"] = eleg
		print("%2d %-16s -> %s" % (n, fila["actual"], ", ".join(eleg)))
	with io.open(RUTA, "w", encoding="utf-8", newline="\n") as f:
		json.dump(d, f, indent=1, ensure_ascii=False)


if __name__ == "__main__":
	main()
