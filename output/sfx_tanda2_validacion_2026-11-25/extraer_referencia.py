import bpy,aud,json
from pathlib import Path
src=Path(r'C:/Users/pablo/AppData/Local/Packages/Microsoft.ScreenSketch_8wekyb3d8bbwe/TempState/Recordings/20261125-1045-37.4288775.mp4')
q=Path(r'E:/magic-symbols/output/sfx_tanda2_validacion_2026-11-25')
a=aud.Sound(str(src))
a.write(str(q/'referencia_piedra.wav'),44100,aud.CHANNELS_MONO,aud.FORMAT_S16,aud.CONTAINER_WAV,aud.CODEC_PCM,0,4096)
s=bpy.context.scene
seq=s.sequence_editor_create()
m=seq.strips.new_movie('Referencia',str(src),channel=1,frame_start=1)
s.render.resolution_x=m.elements[0].orig_width
s.render.resolution_y=m.elements[0].orig_height
s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG'
s.view_settings.view_transform='Standard'
s.render.use_sequencer=True
print('VIDEO_FRAMES',m.frame_duration,'FPS',m.fps,'SIZE',s.render.resolution_x,s.render.resolution_y)
for n,frame in enumerate([max(1,m.frame_duration//3),max(1,2*m.frame_duration//3)]):
 s.frame_set(frame)
 s.render.filepath=str(q/f'referencia_{n}.png')
 bpy.ops.render.render(write_still=True)
