bl_info = {
    "name"        : "SMWOS mesh importer",
    "author"      : "mariokart64n",
    "version"     : (1, 1, 2),
    "blender"     : (3, 0, 0),
    "location"    : "File > Import > SMWOS (.component*.MESH)",
    "description" : "Imports the proprietary SMWOS split-component mesh format.",
    "category"    : "Import-Export",
}

import struct, os, bpy
from bpy_extras.io_utils import ImportHelper
from mathutils import Vector

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def read(fmt, f):
    sz = struct.calcsize(fmt)
    buf = f.read(sz)
    if len(buf) != sz:
        raise EOFError(f"Unexpected end-of-file while reading {fmt}")
    return struct.unpack(fmt, buf)

def read_half(h):
    s=(h>>15)&1; e=(h>>10)&0x1F; m=h&0x3FF
    if e==0:  return ((-1)**s)*(m/2**10)*2**-14
    if e==31: return float('nan') if m else float('inf')*((-1)**s)
    return ((-1)**s)*(1+m/2**10)*2**(e-15)

def pad16(start, cur):  # same formula as your MaxScript
    return (16 - ((cur - start) & 0xF)) & 0xF

# ---------------------------------------------------------------------------
# structs
# ---------------------------------------------------------------------------
class FVF:
    __slots__=("chan","pos","data","ctype")
    def __init__(self,t): self.chan,self.pos,self.data,self.ctype=t

class MeshDecl:
    __slots__=("count1","count2","count3","unk01","unk02","unk03","unk04",
               "unk05","unk06","unk07","unk08","unk09","unk10","unk11",
               "bone_pal","stride","mag1","mag2","fvf")
    def __init__(self,f):
        blk=f.tell(); f.seek(32,1)
        (self.count1,self.count2,self.count3,
         self.unk01,self.unk02,self.unk03,self.unk04,
         self.unk05,self.unk06,self.unk07,self.unk08,
         self.unk09,self.unk10,self.unk11)=read("<14I",f)

        self.bone_pal=list(read(f"<{self.count3}H",f))
        if (self.count3*2)&3: f.seek((4-((self.count3*2)&3))&3,1)

        self.stride,self.mag1,self.mag2=read("<3I",f)

        self.fvf=[]
        while True:
            blob=f.read(8)
            if len(blob)<8: break
            tup=struct.unpack("<HHHH",blob)
            if tup[0] in (255,0xFFFF): break
            if tup[1]>self.stride or tup[1]>0x100:
                f.seek(-8,1); break
            self.fvf.append(FVF(tup))
        if pad:=pad16(blk,f.tell()): f.seek(pad,1)

class Header:
    __slots__=("mesh_count","bmin","bmax","meshes")
    def __init__(self,f):
        f.seek(24,1)
        self.mesh_count,=read("<I",f)
        f.seek(20,1)
        self.bmin=Vector(read("<3f",f))
        self.bmax=Vector(read("<3f",f))
        f.seek(20,1)

        # ---- 8-byte table skip + *new* 16-byte alignment ----
        table_bytes=self.mesh_count*8
        f.seek(table_bytes,1)
        align=(16-(table_bytes&0xF))&0xF
        if align: f.seek(align,1)
        # -----------------------------------------------------

        self.meshes=[MeshDecl(f) for _ in range(self.mesh_count)]

# ---------------------------------------------------------------------------
# attribute decode
# ---------------------------------------------------------------------------
def decode_attr(f,code):
    if   code==0x04: return [b/255 for b in read("<4B",f)]
    elif code==0x05: return list(read("<4B",f))
    elif code==0x08: return [b/255 for b in read("<4B",f)]
    elif code==0x0F: return [b/127 for b in read("<4b",f)]
    elif code==0x0A: return [s/32767 for s in read("<4h",f)]
    elif code==0x10: return [read_half(h) for h in read("<4H",f)]
    elif code==0x00: a,=read("<f",f); return [a,0,0,0]
    elif code==0x01: a,b=read("<2f",f); return [a,b,0,0]
    elif code==0x02: a,b,c=read("<3f",f); return [a,b,c,0]
    elif code==0x03: return list(read("<4f",f))
    elif code==0x06: a,b=read("<2h",f); return [a/32767,b/32767,0,0]
    elif code==0x07: return [b/255 for b in read("<4B",f)]
    else: raise ValueError

# ---------------------------------------------------------------------------
# index strip ? triangle list
# ---------------------------------------------------------------------------
def read_faces(f,index_count):
    idx=list(read(f"<%dH"%index_count,f))
    faces,strip=[],[]
    for ix in idx:
        if ix==0xFFFF: strip.clear(); continue
        strip.append(ix)
        if len(strip)>=3:
            i=len(strip)-3
            tri=(strip[i+1],strip[i],strip[i+2]) if i&1 else (strip[i],strip[i+1],strip[i+2])
            if tri[0]!=tri[1]!=tri[2]!=tri[0]: faces.append(tri)
    if (index_count*2)&3: f.seek((4-((index_count*2)&3))&3,1)
    return faces

# ---------------------------------------------------------------------------
# importer
# ---------------------------------------------------------------------------
def import_smwos(path,scale=39.3701):
    root=os.path.splitext(os.path.splitext(path)[0])[0]
    head, payl = root+".component0.MESH", root+".component1.MESH"
    if not (os.path.exists(head) and os.path.exists(payl)):
        raise FileNotFoundError

    with open(head,"rb") as fh: hdr=Header(fh)
    bscale=Vector((hdr.bmax.x,hdr.bmax.z,hdr.bmax.y))

    with open(payl,"rb") as fp:
        for mi,md in enumerate(hdr.meshes):
            V,N,C,UV0,UV1,W,BID=[],[],[],[],[],[],[]
            vbase=fp.tell()
            for v in range(md.unk03):
                P=Nrm=Col=None; t0=t1=wt=bid=None
                for e in md.fvf:
                    fp.seek(vbase+v*md.stride+e.pos)
                    val=decode_attr(fp,e.data)
                    if   e.ctype==0x00: uv=Vector((val[0],-val[2],val[1])); P=Vector((uv.x*scale*bscale.x, uv.y*scale*bscale.y, uv.z*scale*bscale.z))
                    elif e.ctype==0x03: Nrm=Vector((val[0],-val[2],val[1])).normalized()
                    elif e.ctype==0x05: t0=val[:2]
                    elif e.ctype==0x06: t1=val[:2]
                    elif e.ctype==0x0A: Col=val
                    elif e.ctype==0x01: wt=val
                    elif e.ctype==0x02: bid=val
                V.append(P); N.append(Nrm)
                UV0.append(t0 or (0,0)); UV1.append(t1 or (0,0))
                C.append(Col or (1,1,1,1))
                W.append(wt or (0,0,0,0))
                BID.append((bid or (0,0,0,0))[0])
            fp.seek(vbase+md.unk03*md.stride)
            faces=read_faces(fp,md.unk07)

            me=bpy.data.meshes.new(f"SMWOS_{mi}")
            me.from_pydata(V,[],faces)
            me.validate(); me.update()
            for p in me.polygons: p.flip()
            try: me.use_auto_smooth=True
            except: pass
            me.normals_split_custom_set_from_vertices(N)

            if UV0:
                uv=me.uv_layers.new(name="UV0")
                for li,l in enumerate(me.loops): uv.data[li].uv=UV0[l.vertex_index]
            if any(UV1):
                uv1=me.uv_layers.new(name="UV1")
                for li,l in enumerate(me.loops): uv1.data[li].uv=UV1[l.vertex_index]
            if any(C):
                cl=me.color_attributes.new(name="Col",type='BYTE_COLOR',domain='POINT')
                for i,c in enumerate(C): cl.data[i].color=(*c[:3],c[3])
            me.attributes.new(name="weights",type='FLOAT_VECTOR',domain='POINT')
            me.attributes["weights"].data.foreach_set("vector",[x for v in W for x in v[:3]])
            me.attributes.new(name="bone_id0",type='INT',domain='POINT')
            me.attributes["bone_id0"].data.foreach_set("value",BID)

            obj=bpy.data.objects.new(me.name,me)
            bpy.context.collection.objects.link(obj)

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
class IMPORT_OT_smwos(bpy.types.Operator,ImportHelper):
    bl_idname="import_mesh.smwos"; bl_label="Import SMWOS mesh"
    filename_ext=".MESH"
    filter_glob:bpy.props.StringProperty(default="*.component0.MESH;*.component1.MESH;*.MESH",options={'HIDDEN'})
    scale:bpy.props.FloatProperty(name="Scale",default=2.54)
    def execute(self,ctx):
        try: import_smwos(self.filepath,self.scale); return {'FINISHED'}
        except Exception as e: self.report({'ERROR'},str(e)); return {'CANCELLED'}

def menu_fn(self,ctx):
    self.layout.operator(IMPORT_OT_smwos.bl_idname,text="SMWOS mesh (.MESH)")

def register():
    bpy.utils.register_class(IMPORT_OT_smwos)
    bpy.types.TOPBAR_MT_file_import.append(menu_fn)
def unregister():
    bpy.types.TOPBAR_MT_file_import.remove(menu_fn)
    bpy.utils.unregister_class(IMPORT_OT_smwos)
if __name__=="__main__": register()
