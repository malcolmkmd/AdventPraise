from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
G='/usr/share/fonts/truetype/sand-box/google/'
BASE='/workspace/advent-praise/android-store'
RAW=f'{BASE}/metadata/android/en-US/images/phoneScreenshots'
FR=f'{BASE}/phoneScreenshots-framed/en-US'
os.makedirs(RAW,exist_ok=True); os.makedirs(FR,exist_ok=True)
for f in os.listdir(RAW): os.remove(f'{RAW}/{f}')
sel=[('reader','The hymnal, made for reading','Clear words, verses and choruses, in large print if you like'),
     ('picker','Every hymnal, free','Christ In Song in 9 languages, plus the SDA Hymnal (1985)'),
     ('reader-sdah','The SDA Hymnal, too','All 695 hymns, with its own numbers'),
     ('sheet','Sheet music to read and play from','Page or line view, in step with the piano'),
     ('player','Sing along with the piano','Piano accompaniment that works offline'),
     ('church','Church mode','One verse at a time, big and bright, for the whole congregation'),
     ('numpad','Any hymn in a tap','Type the number and see the title before you go'),
     ('paywall','Advent Praise Pro','Try it free for 3 days, then yearly. Cancel any time')]
EVER=(31,116,102); DEEP=(17,72,64); CREAM=(247,244,238); BRASS=(212,168,83)
W,H=1080,1920
def font(path,size,axes=None):
    f=ImageFont.truetype(G+path,size)
    if axes:
        try: f.set_variation_by_axes(axes)
        except Exception as e: print(e)
    return f
head=font('Noto Serif/NotoSerif-VariableFont_wdth,wght.ttf',78,[600,100])
sub=font('Inter/Inter-VariableFont_opsz,wght.ttf',38,[32,400])
def wrap(d,text,f,maxw):
    words=text.split(); lines=[]; cur=''
    for w in words:
        t=(cur+' '+w).strip()
        if d.textlength(t,font=f)<=maxw: cur=t
        else: lines.append(cur); cur=w
    lines.append(cur); return lines
for i,(name,h,s) in enumerate(sel,1):
    shot=Image.open(f'store-shots-raw/{name}.png').convert('RGB')
    assert shot.size==(1080,1920), shot.size
    shot.save(f'{RAW}/{i:02d}-{name}.png', optimize=True)
    bg=Image.new('RGB',(W,H)); d=ImageDraw.Draw(bg)
    for y in range(H):
        t=y/(H-1); d.line([(0,y),(W,y)],fill=tuple(int(EVER[k]*(1-t)+DEEP[k]*t) for k in range(3)))
    y=120
    for ln in wrap(d,h,head,940):
        tw=d.textlength(ln,font=head); d.text(((W-tw)/2,y),ln,font=head,fill=CREAM); y+=96
    y+=14
    for ln in wrap(d,s,sub,900):
        tw=d.textlength(ln,font=sub); d.text(((W-tw)/2,y),ln,font=sub,fill=(214,232,226)); y+=52
    top=max(y+60,460)
    avail=H-top-70-36
    shh=min(avail,int(1920*0.80)); sw=int(1080*shh/1920)
    sc=shot.resize((sw,shh),Image.LANCZOS)
    pad=18; fw,fh=sw+2*pad, shh+2*pad
    x0=(W-fw)//2
    shadow=Image.new('L',(W,H),0); ImageDraw.Draw(shadow).rounded_rectangle((x0+10,top+24,x0+fw+10,top+fh+24),radius=70,fill=140)
    shadow=shadow.filter(ImageFilter.GaussianBlur(28))
    bg=Image.composite(Image.new('RGB',(W,H),(6,30,26)),bg,shadow); d=ImageDraw.Draw(bg)
    d.rounded_rectangle((x0,top,x0+fw,top+fh),radius=70,fill=(18,22,21))
    m=Image.new('L',(sw,shh),0); ImageDraw.Draw(m).rounded_rectangle((0,0,sw-1,shh-1),radius=54,fill=255)
    bg.paste(sc,(x0+pad,top+pad),m)
    bg.save(f'{FR}/{i:02d}-{name}.png', optimize=True)
print('done')
