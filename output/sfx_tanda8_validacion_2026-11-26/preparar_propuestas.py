from pathlib import Path
import ast,struct,wave,json
import numpy as np
root=Path('E:/magic-symbols');q=root/'output/sfx_tanda8_validacion_2026-11-26';q.mkdir(exist_ok=True,parents=True)
fuentes=Path('C:/Users/pablo/Downloads/sonniss_gdc2026');sr=44100
tree=ast.parse((root/'audio/procesa_sonniss.py').read_text(encoding='utf8'));fun=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='leer_riff')
exec(compile(ast.Module(body=[fun],type_ignores=[]),'lector_riff_local','exec'))
def buscar(nombre):
 rutas=list(fuentes.rglob(nombre));assert len(rutas)==1,(nombre,len(rutas));return rutas[0]
lista=[('fuego_a',root/'audio/oga_fuego_crepita_loop.wav',1.0,1.0,'Crepitar de fuego real · AntumDeluge, OpenGameArt, CC0'),('fuego_b',buscar("FIRECrkl_Fire Crackling, Popping, Witch's Cauldron_344 Audio_Haunting Ambiences Vol 5.wav"),2.0,1.1,'Crepitar y chasquidos · 344 Audio, Sonniss GDC 2026'),('viento_a',buscar('WINDDsgn_EXT, Eye Of The Storm_344 Audio_Extreme Winds Vol 1.wav'),4.0,1.0,'Ráfaga de viento · 344 Audio, Sonniss GDC 2026'),('viento_b',buscar('WINDInt_ChimneyWind05_InMotionAudio_ChimneyWind.wav'),1.0,1.0,'Aire de chimenea · InMotionAudio, Sonniss GDC 2026')]
datos=[]
for nombre,src,inicio,dur,origen in lista:
 x,s=leer_riff(str(src));x=x[round(inicio*s):round((inicio+dur)*s)].mean(axis=1).astype(float);assert len(x)>s*.2
 if s!=sr:x=np.interp(np.arange(round(len(x)*sr/s))*s/sr,np.arange(len(x)),x)
 a=round(.04*sr);b=round(.16*sr);x[:a]*=np.linspace(0,1,a);x[-b:]*=np.linspace(1,0,b)
 rms=float(np.sqrt(np.mean(x*x)));assert rms>1e-8
 gain=min(10**(-24/20)/rms,10**(-6/20)/max(abs(x)));x*=gain
 with wave.open(str(q/(nombre+'.wav')),'wb') as w:w.setparams((1,2,sr,0,'NONE','not compressed'));w.writeframes(np.round(x*32767).astype('<i2').tobytes())
 datos.append({'archivo':nombre+'.wav','fuente':str(src),'inicio_s':inicio,'duracion_s':len(x)/sr,'origen':origen,'ganancia_db':float(20*np.log10(gain)),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(x*x)))),'pico_dbfs':float(20*np.log10(max(abs(x)))),'integrado':False})
(q/'propuestas.json').write_text(json.dumps(datos,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(datos,ensure_ascii=False,indent=2))
