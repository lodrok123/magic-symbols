from pathlib import Path
import wave,json,shutil
import numpy as np
q=Path('output/sfx_tanda5_validacion_2026-11-25')
with wave.open(str(q/'referencia_madera.wav')) as w:
 sr=w.getframerate();x=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
print('Duración:',len(x)/sr)
print('RMS por 100 ms:',[(round(i/sr,2),round(20*np.log10(max(np.sqrt(np.mean(x[i:i+4410]**2)),1e-9)),1)) for i in range(0,len(x),4410)])
# Recorte por actividad de la referencia: preserva todos los eventos, quita solo silencios exteriores.
activos=np.flatnonzero(abs(x)>max(abs(x))*.015)
ini=max(0,int(activos[0])-round(.015*sr));fin=min(len(x),int(activos[-1])+round(.10*sr))
y=x[ini:fin].copy();f=min(round(.004*sr),len(y)//2);g=min(round(.035*sr),len(y)//2)
y[:f]*=np.linspace(0,1,f);y[-g:]*=np.linspace(1,0,g)
ganancia=min(1,10**(-3/20)/max(abs(y)));y*=ganancia
with wave.open(str(q/'madera_rotura_referencia.wav'),'wb') as w:
 w.setparams((1,2,sr,0,'NONE','not compressed'));w.writeframes(np.round(y*32767).astype('<i2').tobytes())
for src,dest in [('goblin_muerte_b.wav','sn_goblin_muere_1.wav'),('goblin_muerte_c.wav','sn_goblin_muere_2.wav')]:
 shutil.copyfile(q/src,Path('audio')/dest)
datos={'referencia':{'archivo':'madera_rotura_referencia.wav','inicio_s':ini/sr,'fin_s':fin/sr,'duracion_s':len(y)/sr,'ganancia_db':float(20*np.log10(ganancia)),'integrado':False,'procedencia':'Vídeo facilitado por Pablo; autor y licencia originales no identificados'},'goblin':{'variantes':['sn_goblin_muere_0.ogg','sn_goblin_muere_1.wav','sn_goblin_muere_2.wav'],'db':-18,'integrado':True}}
y=x[round(1.32*sr):round(2.22*sr)].copy()
y[:round(.004*sr)]*=np.linspace(0,1,round(.004*sr));y[-round(.035*sr):]*=np.linspace(1,0,round(.035*sr))
with wave.open(str(q/'madera_rotura_corta.wav'),'wb') as w:
 w.setparams((1,2,sr,0,'NONE','not compressed'));w.writeframes(np.round(y*32767).astype('<i2').tobytes())
datos['recorte_corto']={'archivo':'madera_rotura_corta.wav','inicio_s':1.32,'fin_s':2.22,'integrado':False}
(q/'revision_3_decisiones.json').write_text(json.dumps(datos,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(datos,ensure_ascii=False,indent=2))
