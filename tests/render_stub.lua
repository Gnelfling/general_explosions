CLIENT,SERVER=true,false
MATERIAL_TRIANGLES=1
function Material(name)
    return {name=name,IsError=function() return false end,
        GetTexture=function() return {IsError=function() return false end} end}
end
function CreateMaterial(name)
    local m=Material(name)
    m.SetFloat=function() end
    m.SetTexture=function() end
    return m
end
function FrameNumber() return math.floor(NOW*120) end
engine={TickCount=function() return math.floor(NOW*66) end}
util.GetPixelVisibleHandle=function() return {} end
util.PixelVisible=function() PIXEL_CALLS=PIXEL_CALLS+1; return 1 end
PIXEL_CALLS=0
function EyeAngles() return {Right=function() return Vector(1,0,0) end} end
LIGHTS={}
function DynamicLight(id) LIGHTS[id]=LIGHTS[id] or {}; return LIGHTS[id] end
render={state={},calls=0,beam=0}
function render.SetMaterial() end
local function finite(v) assert(v==v and v>-math.huge and v<math.huge) end
local function position(v) finite(v.x);finite(v.y);finite(v.z) end
function render.DrawSprite(p,w,h,c) position(p);finite(w);finite(h);finite(c.a); render.calls=render.calls+1 end
function render.DrawBeam(a,b,w,s,t,c) position(a);position(b);finite(w);finite(c.a);render.calls=render.calls+1 end
function render.StartBeam(n) assert(render.beam==0); render.beam=n; render.added=0 end
function render.AddBeam(p,w,t,c) position(p);finite(w);finite(c.a);render.added=render.added+1 end
function render.EndBeam() assert(render.added==render.beam);render.beam=0 end
for _,name in ipairs({'SetStencilEnable','OverrideDepthEnable','OverrideColorWriteEnable','OverrideAlphaWriteEnable','SetBlend'}) do
    render[name]=function(value) render.state[name]=value end
end
for _,name in ipairs({'ClearStencil','SetStencilWriteMask','SetStencilTestMask','SetStencilReferenceValue',
    'SetStencilCompareFunction','SetStencilPassOperation','SetStencilFailOperation','SetStencilZFailOperation',
    'ClearBuffersObeyStencil'}) do render[name]=function() end end
MESHES={}
function Mesh()
    local m={}
    function m:Destroy() self.destroyed=true end
    function m:Draw() if FAIL_DRAW then error('injected draw failure') end end
    MESHES[#MESHES+1]=m
    return m
end
mesh={}
function mesh.Begin(m,kind,n)
    mesh.expected=(type(m)=='number' and kind or n)*3
    mesh.count=0
end
function mesh.Position(p) position(p); if FAIL_VERTEX then error('injected mesh failure') end end
function mesh.TexCoord() end
function mesh.Color(r,g,b,a) finite(r);finite(g);finite(b);finite(a) end
function mesh.AdvanceVertex() mesh.count=mesh.count+1 end
function mesh.End() if not FAIL_VERTEX then assert(mesh.count==mesh.expected) end end
TRACES=0
function util.TraceLine(tr)
    TRACES=TRACES+1
    return {Hit=true,HitWorld=true,HitPos=Vector(tr.start.x,tr.start.y,0),HitNormal=Vector(0,0,1)}
end
EMITTERS={}
function ParticleEmitter()
    local e={particles={}}
    function e:Add(mat,p)
        if FAIL_PARTICLE then error('injected particle failure') end
        local particle={}
        for _,name in ipairs({'Velocity','DieTime','StartAlpha','EndAlpha','StartSize','EndSize','Roll',
            'RollDelta','AirResistance','Gravity','Collide','Lighting','Color','StartLength','EndLength'}) do
            particle['Set'..name]=function(self,v) self[name]=v end
        end
        e.particles[#e.particles+1]=particle
        return particle
    end
    function e:Finish() assert(not self.finished);self.finished=true end
    function e:SetNoDraw(v) self.hidden=v end
    EMITTERS[#EMITTERS+1]=e
    return e
end
