import wave,json
from pathlib import Path
import numpy as np
q=Path('output/sfx_tanda2_validacion_2026-11-25')
with wave.open(str(q/'referencia_piedra.wav')) as w:
 sr=w.getframerate();x=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768
# Audio facilitado como referencia. Recortes para validación, NO assets del juego.
gain=min(10**(8/20),10**(-3/20)/max(abs(x)))
info=[]
for name,start,end in [('piedra_corta',.45,2.45),('piedra_cola_completa',.45,5.63)]:
 y=x[round(start*sr):round(end*sr)].copy();fade=round(.03*sr)
 y[:fade]*=np.linspace(0,1,fade);y[-fade:]*=np.linspace(1,0,fade);y*=gain
 assert max(abs(y))<1
 with wave.open(str(q/(name+'.wav')),'wb') as w:
  w.setparams((1,2,sr,0,'NONE','not compressed'));w.writeframes(np.round(y*32767).astype('<i2').tobytes())
 info.append({'archivo':name+'.wav','inicio_video_s':start,'fin_video_s':end,'ganancia_db':float(20*np.log10(gain)),'integrado':False})
(q/'recortes_referencia.json').write_text(json.dumps(info,indent=2),encoding='utf8')
print(json.dumps(info,indent=2))
