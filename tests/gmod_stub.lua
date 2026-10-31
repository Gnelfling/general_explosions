-- Deliberately small GMod boundary mock; never simulates GPU/engine behavior.
local V = {}
V.__index = V
function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},V) end
function isvector(p) return getmetatable(p) == V end
function V.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
function V.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
function V.__mul(a,b)
    if type(a)=='number' then a,b=b,a end
    return Vector(a.x*b,a.y*b,a.z*b)
end
function V.__div(a,b) return a*(1/b) end
function V:LengthSqr() return self.x^2+self.y^2+self.z^2 end
function V:GetNormalized() return self / math.sqrt(self:LengthSqr()) end
function V:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
function V:Cross(b) return Vector(self.y*b.z-self.z*b.y,self.z*b.x-self.x*b.z,self.x*b.y-self.y*b.x) end
function V:DistToSqr(b) return (self-b):LengthSqr() end
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
math.Clamp = function(v,lo,hi) return math.max(lo,math.min(hi,v)) end
CLIENT,SERVER = false,true
NOW=100
function CurTime() return NOW end
function RealTime() return NOW end
function IsValid(e) return e ~= nil and e ~= false and not e.removed end
function AddCSLuaFile() end
function ErrorNoHalt(e) ERRORS[#ERRORS+1]=e end
ERRORS={}
CVARS={}
function CreateConVar(name,default)
    local c = {value=default}
    function c:GetFloat() return tonumber(self.value) end
    function c:GetInt() return math.floor(tonumber(self.value)) end
    function c:GetBool() return self.value ~= '0' end
    function c:GetString() return tostring(self.value) end
    CVARS[name]=c
    return c
end
CreateClientConVar=CreateConVar
hook={callbacks={}}
function hook.Add(event,name,fn) hook.callbacks[event..':'..name]=fn end
function hook.Remove(event,name) hook.callbacks[event..':'..name]=nil end
concommand={Add=function() end}
file={Exists=function() return true end}
resource={AddFile=function() end}
sound={calls={}}
function sound.Play(path,pos) sound.calls[#sound.calls+1]={path=path,time=NOW,pos=pos} end
util={AddNetworkString=function() end,ScreenShake=function() end}
net={callbacks={},writes={}}
function net.Receive(name,fn) net.callbacks[name]=fn end
function net.Start(name) net.last=name end
function net.Send() end
function net.SendToServer() end
function net.Broadcast() end
for _,name in ipairs({'UInt','Float','Vector','Normal','Bool'}) do
    net['Write'..name]=function(v) net.writes[#net.writes+1]={kind=name,value=v} end
end
game={SinglePlayer=function() return false end}
ents={FindByClass=function() return {} end}
timer={Simple=function(_,fn) fn() end}
ENT={}
function ENT:NetworkVar(_,_,name)
    self['Get'..name]=function(e) return e[name] or 0 end
    self['Set'..name]=function(e,v) e[name]=v end
end
function ENT:GetPos() return Vector(0,0,3) end
function ENT:NextThink() end
function ENT:Remove() self.removed=true end
function ENT:EntIndex() return 7 end
function ENT:SetRenderBounds() end
function EyePos() return Vector(0,0,100) end
