"""Derive the Elfic Forest map from the reference screenshot.

Classifies the reference into a semantic grid (grass/tree/cliff/water), then
emits a *layout* JSON (tile NAMES + prop positions + collision) that the Elixir
map module loads. No pixel data — the client still slices overworld.png.
"""
import json, os
import numpy as np
from PIL import Image

TOOLS=os.path.dirname(os.path.abspath(__file__)); GFX=os.path.dirname(TOOLS)
REF=os.path.expanduser("~/Desktop/Captura de Tela 2026-07-06 às 08.43.11.png")
GW,GH=88,64

def classify_grid():
    im=np.asarray(Image.open(REF).convert("RGB"),dtype=np.int32); H,W,_=im.shape
    cw,ch=W/GW,H/GH
    def pc(r,g,b):
        if b>115 and b>r+15 and b>g-25: return "water"
        if 55<=r<=170 and 35<=g<=120 and b<120 and r>=g-25 and (r-b)<95: return "brown"
        if g>60 and r<105 and b<105 and g>r+30 and (r+g+b)<330: return "dark"
        return "grass"
    lab=[["grass"]*GW for _ in range(GH)]
    for gy in range(GH):
        for gx in range(GW):
            reg=im[int(gy*ch):int((gy+1)*ch),int(gx*cw):int((gx+1)*cw)].reshape(-1,3)
            n=len(reg); fw=fb=fd=0
            for r,g,b in reg:
                c=pc(r,g,b)
                if c=="water":fw+=1
                elif c=="brown":fb+=1
                elif c=="dark":fd+=1
            if fw/n>0.35: lab[gy][gx]="water"
            elif fb/n>0.32: lab[gy][gx]="brown"
            elif fd/n>0.13: lab[gy][gx]="tree"
    return lab

def inb(x,y): return 0<=x<GW and 0<=y<GH

def denoise(lab):
    """Smooth the semantic grid: drop isolated cliff/tree speckle and fill small
    grass holes in tree masses so cliffs read as clean lines and forests solid."""
    def cnt(lab,x,y,val):
        return sum(1 for dx in(-1,0,1) for dy in(-1,0,1)
                   if (dx,dy)!=(0,0) and inb(x+dx,y+dy) and lab[y+dy][x+dx]==val)
    for _ in range(2):
        nw=[row[:] for row in lab]
        for y in range(GH):
            for x in range(GW):
                v=lab[y][x]
                if v=="brown" and cnt(lab,x,y,"brown")<2: nw[y][x]="grass"
                elif v=="tree" and cnt(lab,x,y,"tree")<2: nw[y][x]="grass"
                elif v=="grass" and cnt(lab,x,y,"tree")>=6: nw[y][x]="tree"
        lab=nw
    return lab

def build(lab):
    def is_(l,x,y): return inb(x,y) and lab[y][x]==l
    # cabin: the reference cabin sits top-left; clear that brown blob & place sprite.
    cabin_x,cabin_y=8,1
    for yy in range(cabin_y,cabin_y+6):
        for xx in range(cabin_x,cabin_x+6):
            if inb(xx,yy) and lab[yy][xx]=="brown": lab[yy][xx]="tree"  # roof reads as canopy-ish; will be covered by sprite
    floor=[[None]*GW for _ in range(GH)]
    decor=[]; blocked=set()
    # cabin sprite (house is 5x5)
    decor.append({"x":cabin_x,"y":cabin_y+1,"tile":"house"})
    for dx in range(5):
        for dy in range(5): blocked.add((cabin_x+dx,cabin_y+1+dy))
    # water autotile
    for y in range(GH):
        for x in range(GW):
            if lab[y][x]!="water": continue
            u,d,l,r=is_("water",x,y-1),is_("water",x,y+1),is_("water",x-1,y),is_("water",x+1,y)
            if not u and not l: t="pond_tl"
            elif not u and not r: t="pond_tr"
            elif not d and not l: t="pond_bl"
            elif not d and not r: t="pond_br"
            elif not u: t="pond_tm"
            elif not d: t="pond_bm"
            elif not l: t="pond_ml"
            elif not r: t="pond_mr"
            else: t="pond_c"
            floor[y][x]=t; blocked.add((x,y))
    # cliff autotiler on brown mask
    for y in range(GH):
        for x in range(GW):
            if lab[y][x]!="brown": continue
            u,d,l,r=is_("brown",x,y-1),is_("brown",x,y+1),is_("brown",x-1,y),is_("brown",x+1,y)
            if not u:
                col = "m" if (l and r) else ("l" if not l else "r")
                floor[y][x]="cliff_base_"+col
                # lip on grass above
                if inb(x,y-1) and lab[y-1][x] in ("grass",):
                    wl=is_("brown",x-1,y); wr=is_("brown",x+1,y)
                    lipcol="m" if (wl and wr) else ("l" if not wl else "r")
                    floor[y-1][x]="cliff_lip_"+lipcol
            elif (u or d) and not (l or r):
                floor[y][x]="cliff_face_"+("l" if is_("grass",x-1,y) else "r")
            else:
                floor[y][x]="cliff_face_m"
            blocked.add((x,y))
    # trees: place a 2x2 tree every 2 cells across tree regions (overlapping masses)
    for y in range(0,GH,2):
        for x in range(0,GW,2):
            # tree if this 2x2 block is mostly tree
            cnt=sum(1 for dx in(0,1) for dy in(0,1) if is_("tree",x+dx,y+dy))
            if cnt>=3:
                decor.append({"x":x,"y":y,"tile":"tree"})
                for dx in(0,1):
                    for dy in(0,1):
                        if inb(x+dx,y+dy): blocked.add((x+dx,y+dy))
    # Carve a guaranteed-open spawn plaza in the central valley.
    plaza=(26,30,35,37)
    decor=[p for p in decor if not (plaza[0]<=p["x"]<=plaza[2] and plaza[1]<=p["y"]<=plaza[3])]
    for y in range(plaza[1],plaza[3]+1):
        for x in range(plaza[0],plaza[2]+1):
            if inb(x,y):
                blocked.discard((x,y))
                if floor[y][x] and floor[y][x].startswith(("cliff","pond")): floor[y][x]=None
    # A few motivated logs (benches) on open ground.
    for (lx,ly) in [(23,27),(38,25),(30,40)]:
        if all(not_blocked((lx+i,ly),blocked) for i in range(3)):
            for t,i in zip(("log_l","log_m","log_r"),range(3)):
                decor.append({"x":lx+i,"y":ly,"tile":t}); blocked.add((lx+i,ly))
    # subtle grass texture on remaining grass
    for y in range(GH):
        for x in range(GW):
            if floor[y][x] is None and lab[y][x]=="grass":
                h=(x*73856093 ^ y*19349663)%97
                if h==0: floor[y][x]="grass_dark"
                elif h==5: floor[y][x]="flowers"
                elif h in (11,40): floor[y][x]="grass_tuft"
    return dict(width=GW,height=GH,ground="grass",floor=floor,decor=decor,
                blocked=sorted([list(b) for b in blocked]))

def not_blocked(c,blocked): return c not in blocked

REPO=os.path.abspath(os.path.join(GFX,".."))  # virtual.space -> repo root
OUT=os.path.join(REPO,"apps","retro_hex_chat","priv","maps","elfic_forest.json")

lab=denoise(classify_grid())
m=build(lab)
json.dump(m,open("/tmp/derived_map.json","w"))
os.makedirs(os.path.dirname(OUT),exist_ok=True)
json.dump(m,open(OUT,"w"))
print("floor tiles set:",sum(1 for row in m["floor"] for c in row if c))
print("decor:",len(m["decor"]),"blocked:",len(m["blocked"]),"->",OUT)
