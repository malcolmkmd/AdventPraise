from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
G='/usr/share/fonts/truetype/sand-box/google/'
OUT='/workspace/advent-praise/android-store/metadata/android/en-US/images'
icon=Image.open('AppIcon.png').convert('RGB')
# 1. Play icon 512x512, 32-bit PNG
icon.resize((512,512),Image.LANCZOS).convert('RGBA').save(f'{OUT}/icon.png')
# 2. Feature graphic 1024x500
W,H=1024,500
EVER=(31,116,102); DEEP=(17,72,64); CREAM=(247,244,238); BRASS=(212,168,83)
bg=Image.new('RGB',(W,H))
d=ImageDraw.Draw(bg)
for y in range(H):
    t=y/(H-1); d.line([(0,y),(W,y)],fill=tuple(int(EVER[i]*(1-t)+DEEP[i]*t) for i in range(3)))
# soft brass glow behind the phone
glow=Image.new('L',(W,H),0); gd=ImageDraw.Draw(glow); gd.ellipse((560,-60,1060,440),fill=70)
glow=glow.filter(ImageFilter.GaussianBlur(90))
bg=Image.composite(Image.new('RGB',(W,H),BRASS),bg,glow)
# brand lockup from the real app icon: find the non-background box
px=icon.load(); bx=[1024,1024,0,0]
for y in range(0,1024,2):
    for x in range(0,1024,2):
        r,g,b=px[x,y]
        if abs(r-31)+abs(g-116)+abs(b-102)>40:
            bx=[min(bx[0],x),min(bx[1],y),max(bx[2],x),max(bx[3],y)]
lock=icon.crop((bx[0]-8,bx[1]-8,bx[2]+8,bx[3]+8))
# mask out the background colour so it sits on the gradient
lm=Image.new('L',lock.size,0); lp=lock.load(); mp=lm.load()
for y in range(lock.height):
    for x in range(lock.width):
        r,g,b=lp[x,y]; dd=abs(r-31)+abs(g-116)+abs(b-102)
        mp[x,y]=max(0,min(255,(dd-12)*6))
lh=330; lw=int(lock.width*lh/lock.height)
lock=lock.resize((lw,lh),Image.LANCZOS); lm=lm.resize((lw,lh),Image.LANCZOS)
lx=60+ (360-lw)//2; ly=40
bg.paste(lock,(lx,ly),lm)
d=ImageDraw.Draw(bg)
f=ImageFont.truetype(G+'Inter/Inter-VariableFont_opsz,wght.ttf',27)
try: f.set_variation_by_axes([28,500])
except Exception as e: print('axes',e)
lines=['Christ In Song in 9 languages','and the SDA Hymnal (1985)']
y=ly+lh+22
for s in lines:
    tw=d.textlength(s,font=f); d.text((60+(360-tw)/2,y),s,font=f,fill=CREAM); y+=36
# phone with a real Android screenshot
shot=Image.open('store-shots-raw/reader.png').convert('RGB')
pw=300; ph=int(shot.height*pw/shot.width)
shot=shot.resize((pw,ph),Image.LANCZOS)
frame_pad=12; fw,fh=pw+2*frame_pad, ph+2*frame_pad
phone=Image.new('RGBA',(fw,fh),(0,0,0,0)); pd=ImageDraw.Draw(phone)
pd.rounded_rectangle((0,0,fw-1,fh-1),radius=44,fill=(20,24,23,255))
sm=Image.new('L',(pw,ph),0); ImageDraw.Draw(sm).rounded_rectangle((0,0,pw-1,ph-1),radius=34,fill=255)
phone.paste(shot,(frame_pad,frame_pad),sm)
phone=phone.rotate(-6,resample=Image.BICUBIC,expand=True)
sh=Image.new('RGBA',phone.size,(0,0,0,0)); sh.putalpha(phone.split()[3].point(lambda a:int(a*0.45)))
sh=sh.filter(ImageFilter.GaussianBlur(18))
px0,py0=600,58
bg.paste((0,0,0),(px0+14,py0+20),sh.split()[3])
bg.paste(phone,(px0,py0),phone)
bg.save(f'{OUT}/featureGraphic.png')
print('lock',bx,lw,lh)
