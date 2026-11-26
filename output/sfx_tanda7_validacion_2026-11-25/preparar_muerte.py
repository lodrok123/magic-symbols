from pathlib import Path
import wave,json,ast,struct
import numpy as np
q=Path('E:/magic-symbols/output/sfx_tanda7_validacion_2026-11-25');q.mkdir(parents=True,exist_ok=True)
fuentes=Path('C:/Users/pablo/Downloads/sonniss_gdc2026');sr=44100
# Reutilizar solo el lector RIFF del procesador local: soporta WAV float/24 bit
# con chunks PEAK que dan problemas al decodificador de audio de Blender.
arbol=ast.parse(Path('E:/magic-symbols/audio/procesa_sonniss.py').read_text(encoding='utf8'))
lector=next(n for n in arbol.body if isinstance(n,ast.FunctionDef) and n.name=='leer_riff')
exec(compile(ast.Module(body=[lector],type_ignores=[]),'lector_riff_local','exec'))
propuestas=[('a','DSGNImpt_Metal Hit Thud Thump Low Ring Geofon 1_The Noisery_Moaning Metal.wav',1.1,'Impacto grave con resonancia corta'),('b','Transition Braam Slow Dark Creepy.wav',1.4,'Transición oscura con caída suave'),('c','DSGNBass_Bass Drop & Downer Fast 16_344 Audio_Bass Drops & Downers.wav',.85,'Descenso grave breve')]
datos=[]
for letra,nombre,duracion,descripcion in propuestas:
 matches=list(fuentes.rglob(nombre));assert len(matches)==1,(nombre,len(matches))
 origen=matches[0]
 canales,original_sr=leer_riff(str(origen));x=canales.mean(axis=1).astype(float)
 if original_sr!=sr:x=np.interp(np.arange(round(len(x)*sr/original_sr))*original_sr/sr,np.arange(len(x)),x)
 activos=np.flatnonzero(abs(x)>max(abs(x))*.02);assert len(activos)
 ini=max(0,int(activos[0])-round(.01*sr));fin=min(len(x),ini+round(duracion*sr));y=x[ini:fin].copy()
 a=min(round(.008*sr),len(y)//2);b=min(round(.22*sr),len(y)//2)
 y[:a]*=np.linspace(0,1,a);y[-b:]*=np.linspace(1,0,b)
 gain=min(10**(-22/20)/max(np.sqrt(np.mean(y*y)),1e-9),10**(-6/20)/max(abs(y)));y*=gain
 salida=q/f'muerte_{letra}.wav'
 with wave.open(str(salida),'wb') as w:w.setparams((1,2,sr,0,'NONE','not compressed'));w.writeframes(np.round(y*32767).astype('<i2').tobytes())
 assert max(abs(y))<1
 datos.append({'variante':letra.upper(),'descripcion':descripcion,'archivo':salida.name,'fuente':str(origen),'inicio_s':ini/sr,'duracion_s':len(y)/sr,'ganancia_db':float(20*np.log10(gain)),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(y*y)))),'pico_dbfs':float(20*np.log10(max(abs(y)))),'integrado':False,'licencia':'Sonniss GDC 2026; misma licencia local que audio/sn_*, sin publicar fuentes como archivos sueltos'})
(q/'propuestas_muerte.json').write_text(json.dumps(datos,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(datos,ensure_ascii=False,indent=2))
