from pathlib import Path
import json,hashlib
q=Path('output/sfx_tanda5_validacion_2026-11-25')
assert (q/'madera_nueva_a.wav').read_bytes()==Path('audio/madera_rotura.wav').read_bytes()
for p in [q/'generar_revision_4.cjs',Path('docs/VALIDACION_SFX_MADERA_GOBLIN_CORTO_2026-11-25.html')]:
 s=p.read_text(encoding='utf8')
 s=s.replace('26 · Nuevos recortes para validar','26 · A aceptado e integrado')
 s=s.replace('Son propuestas fuera del juego, pendientes de tu escucha. El revisor no ha escuchado los archivos ni confirma la ausencia de contaminación. La burbuja conserva su estallido aprobado. Autor y licencia originales de la referencia no identificados.','A aceptado por Pablo para corte de madera o madera cayendo e integrado como madera_rotura.wav en escudo_roto, sin reprocesar la muestra. B no se integra. La burbuja conserva su estallido propio aprobado. Autor y licencia originales de la referencia no identificados.')
 s=s.replace('29 · Las tres variantes recortadas e integradas','29 · Las tres variantes cortas aceptadas e integradas')
 p.write_text(s,encoding='utf8')
(q/'aprobacion_final.json').write_text(json.dumps({'26':{'variante':'A','uso_aprobado':'corte de madera o madera cayendo','asset':'audio/madera_rotura.wav','entrada':'Sfx.escudo_roto','sha256':hashlib.sha256(Path('audio/madera_rotura.wav').read_bytes()).hexdigest(),'integrado':True},'29':{'estado':'aceptado','variantes':3,'duracion':'primera mitad de cada variante','db':-18,'integrado':True}},ensure_ascii=False,indent=2),encoding='utf8')
print('26A integrado: copia exacta comprobada. 29 aceptado. Página y registro actualizados.')
