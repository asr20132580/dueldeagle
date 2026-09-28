local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer

local S = {
    ESP = { Enabled=false, TeamCheck=true, ShowBox=true, ShowName=true, ShowHealth=true, ShowDistance=false, ShowWeapon=false, ShowSkeleton=false, ShowHeadDot=false, CornerBox=false, FilledBox=false, EnemyChams=false, MaxDistance=500, Color=Color3.fromRGB(255,0,0), SkeletonColor=Color3.fromRGB(255,255,255), FilledTransparency=0.7 },
    Aimbot = { Enabled=false, FOV=100, Smoothness=0.3, VisibleCheck=true, TeamCheck=true },
    SilentAim = { Enabled=false, VisibleCheck=true },
    Hitbox = { Enabled=false, Size=3, TeamCheck=true },
    Trigger = { Enabled=false, Delay=0.1, TeamCheck=true },
    World = { ColorEnabled=false, ColorTint=Color3.fromRGB(255,100,100), SkyEnabled=false, SkyColor=Color3.fromRGB(0,0,0), SkyTopColor=Color3.fromRGB(0,0,0), SkyBrightness=-5, Darkness=0, Atmosphere=false },
    LP = { Realism=false },
    Movement = { BunnyHop=false, AutoStrafe=false, Speed=false, SpeedValue=22 }
}

local KeyBinds = {}
local BindingMode = nil
local BindWindow = nil
local toggleButtons = {}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible=false; FOVCircle.Radius=150; FOVCircle.Color=Color3.fromRGB(200,100,255)
FOVCircle.Thickness=1; FOVCircle.Filled=false; FOVCircle.NumSides=40; FOVCircle.Transparency=0.7

local ESPDrawings = {}
local FPS = 0
local FrameCount = 0
local LastFPSTime = os.clock()
local OriginalHitboxData = {}
local EnemyHighlights = {}

local Theme = {
    GlassBg = Color3.fromRGB(20,20,30),
    GlassBgTransparency = 0.45,
    GlassStroke = Color3.fromRGB(255,255,255),
    GlassStrokeTransparency = 0.85,
    Accent = Color3.fromRGB(120,90,255),
    Text = Color3.fromRGB(255,255,255),
    TextDim = Color3.fromRGB(200,200,220),
    TextMuted = Color3.fromRGB(150,150,170),
    ToggleOn = Color3.fromRGB(120,90,255),
    ToggleOff = Color3.fromRGB(60,60,80),
    Hover = Color3.fromRGB(255,255,255)
}

-- ===== ESP =====
local function ClearESP()
    for _, o in ipairs(ESPDrawings) do if o and o.Remove then o:Remove() end end
    ESPDrawings = {}
end

local function Line(a, b, c, t, tr)
    local l = Drawing.new("Line")
    l.From=a; l.To=b; l.Color=c; l.Thickness=t or 1.5; l.Transparency=tr or 1; l.Visible=true
    table.insert(ESPDrawings, l); return l
end

local function Text(txt, pos, c, sz)
    local l = Drawing.new("Text")
    l.Text=txt; l.Position=pos; l.Color=c; l.Size=sz or 13
    l.Center=true; l.Outline=true; l.OutlineColor=Color3.fromRGB(0,0,0); l.Visible=true
    table.insert(ESPDrawings, l); return l
end

local function Circle(pos, r, c, f)
    local ci = Drawing.new("Circle")
    ci.Position=pos; ci.Radius=r; ci.Color=c; ci.Thickness=1; ci.Filled=f or false
    ci.NumSides=30; ci.Transparency=1; ci.Visible=true
    table.insert(ESPDrawings, ci); return ci
end

local function Square(pos, sz, c, f, tr)
    local sq = Drawing.new("Square")
    sq.Position=pos; sq.Size=sz; sq.Color=c; sq.Filled=f or false; sq.Thickness=1
    sq.Transparency=tr or 1; sq.Visible=true
    table.insert(ESPDrawings, sq); return sq
end

local function IsVisible(plr)
    if not plr or not plr.Character then return false end
    local tp = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
    if not tp then return false end
    local p = RaycastParams.new()
    p.FilterType = Enum.RaycastFilterType.Blacklist
    p.FilterDescendantsInstances = {LP.Character, Camera}
    local r = Workspace:Raycast(Camera.CFrame.Position, (tp.Position - Camera.CFrame.Position).Unit * 1000, p)
    if r and r.Instance then return r.Instance:IsDescendantOf(plr.Character) end
    return true
end

local function GetEnemies(checkTeam, maxDist)
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        if not plr.Character then continue end
        local h = plr.Character:FindFirstChildOfClass("Humanoid")
        local r = plr.Character:FindFirstChild("HumanoidRootPart")
        local hd = plr.Character:FindFirstChild("Head")
        if not r or not h or h.Health <= 0 then continue end
        if checkTeam and plr.Team == LP.Team then continue end
        local d = (Camera.CFrame.Position - r.Position).Magnitude
        if maxDist and d > maxDist then continue end
        table.insert(list, {Player=plr, Character=plr.Character, Root=r, Head=hd or r, Humanoid=h, Distance=d})
    end
    return list
end

local SkeletonConns = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}
}

local function DrawSkeleton(char, col)
    for _, c in ipairs(SkeletonConns) do
        local p1 = char:FindFirstChild(c[1])
        local p2 = char:FindFirstChild(c[2])
        if p1 and p2 then
            local s1,o1 = Camera:WorldToViewportPoint(p1.Position)
            local s2,o2 = Camera:WorldToViewportPoint(p2.Position)
            if o1 and o2 then Line(Vector2.new(s1.X,s1.Y), Vector2.new(s2.X,s2.Y), col, 1.5) end
        end
    end
end

local function UpdateEnemyChams(enemies)
    for plr, h in pairs(EnemyHighlights) do
        if h and h.Parent then h:Destroy() end
        EnemyHighlights[plr] = nil
    end
    if not S.ESP.EnemyChams then return end
    for _, e in ipairs(enemies) do
        if e.Character then
            local h = Instance.new("Highlight")
            h.Name = "MB_EnemyChams"
            h.FillColor = S.ESP.Color
            h.FillTransparency = 0.4
            h.OutlineColor = S.ESP.Color
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Adornee = e.Character
            h.Parent = e.Character
            EnemyHighlights[e.Player] = h
        end
    end
end

local function UpdateESP()
    ClearESP()
    if not S.ESP.Enabled then UpdateEnemyChams({}) return end
    local list = GetEnemies(S.ESP.TeamCheck, S.ESP.MaxDistance)
    UpdateEnemyChams(S.ESP.EnemyChams and list or {})
    for _, e in ipairs(list) do
        local plr, root, head, hum, char = e.Player, e.Root, e.Head, e.Humanoid, e.Character
        local color = S.ESP.Color
        local hs, onH = Camera:WorldToViewportPoint(head.Position)
        local fs, onF = Camera:WorldToViewportPoint(root.Position + Vector3.new(0,-2.5,0))
        if not onH and not onF then continue end
        local topY, botY, cx = hs.Y, fs.Y, (hs.X+fs.X)/2
        if not onH then topY = fs.Y - 100; cx = fs.X end
        if not onF then botY = hs.Y + 100; cx = hs.X end
        local boxH = math.abs(botY - topY); if boxH < 5 then boxH = 60 end
        local boxW = boxH * 0.4
        local x = cx - boxW/2
        local y = math.min(topY, botY)
        if S.ESP.ShowBox then
            Line(Vector2.new(x,y), Vector2.new(x+boxW,y), color, 1.5)
            Line(Vector2.new(x+boxW,y), Vector2.new(x+boxW,y+boxH), color, 1.5)
            Line(Vector2.new(x+boxW,y+boxH), Vector2.new(x,y+boxH), color, 1.5)
            Line(Vector2.new(x,y+boxH), Vector2.new(x,y), color, 1.5)
        end
        if S.ESP.CornerBox then
            local len = boxW * 0.25
            local t = 2
            Line(Vector2.new(x,y), Vector2.new(x+len,y), color, t)
            Line(Vector2.new(x,y), Vector2.new(x,y+len), color, t)
            Line(Vector2.new(x+boxW,y), Vector2.new(x+boxW-len,y), color, t)
            Line(Vector2.new(x+boxW,y), Vector2.new(x+boxW,y+len), color, t)
            Line(Vector2.new(x,y+boxH), Vector2.new(x+len,y+boxH), color, t)
            Line(Vector2.new(x,y+boxH), Vector2.new(x,y+boxH-len), color, t)
            Line(Vector2.new(x+boxW,y+boxH), Vector2.new(x+boxW-len,y+boxH), color, t)
            Line(Vector2.new(x+boxW,y+boxH), Vector2.new(x+boxW,y+boxH-len), color, t)
        end
        if S.ESP.FilledBox then
            Square(Vector2.new(x,y), Vector2.new(boxW,boxH), color, true, S.ESP.FilledTransparency)
        end
        if S.ESP.ShowSkeleton then DrawSkeleton(char, S.ESP.SkeletonColor) end
        if S.ESP.ShowHeadDot then
            local hs2, o2 = Camera:WorldToViewportPoint(head.Position)
            if o2 then Circle(Vector2.new(hs2.X,hs2.Y), 4, color, true) end
        end
        if S.ESP.ShowName then Text(plr.Name, Vector2.new(cx, y-15), color, 13) end
        if S.ESP.ShowHealth then Text(math.floor(hum.Health).."/"..math.floor(hum.MaxHealth), Vector2.new(cx, y+boxH+2), color, 11) end
        if S.ESP.ShowDistance then Text("["..math.floor(e.Distance).."m]", Vector2.new(cx, y+boxH+16), color, 11) end
        if S.ESP.ShowWeapon then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then Text(tool.Name, Vector2.new(cx, y+boxH+30), color, 11) end
        end
    end
end

-- ===== AIMBOT =====
local function GetAimbotTarget(fovO, visC)
    local list = GetEnemies(S.Aimbot.TeamCheck, nil)
    local best, bestD = nil, math.huge
    local c = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local fovPx = fovO or ((S.Aimbot.FOV/100) * 500)
    for _, e in ipairs(list) do
        local sp, on = Camera:WorldToViewportPoint(e.Head.Position)
        if not on then continue end
        local d = (Vector2.new(sp.X, sp.Y) - c).Magnitude
        if d <= fovPx and d < bestD then
            if visC and not IsVisible(e.Player) then continue end
            bestD = d; best = e
        end
    end
    return best
end

local function UpdateFOV()
    if not (S.Aimbot.Enabled or S.SilentAim.Enabled) then FOVCircle.Visible=false return end
    FOVCircle.Visible = true
    FOVCircle.Radius = (S.Aimbot.FOV/100) * 500
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
end

local function FireWeapon()
    if mouse1click then mouse1click()
    elseif mouse1press and mouse1release then mouse1press(); task.wait(0.03); mouse1release()
    elseif VirtualUser then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton1(Vector2.new(0,0)) end) end
end

-- ===== HITBOX =====
local function RestoreHitbox(plr)
    local data = OriginalHitboxData[plr]
    if not data then return end
    for part, orig in pairs(data) do
        if part and part.Parent then
            part.Size = orig.Size; part.Transparency = orig.Transparency; part.CanCollide = orig.CanCollide
        end
    end
    OriginalHitboxData[plr] = nil
end

local function UpdateHitbox()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP or not plr.Character then continue end
        local skip = S.Hitbox.TeamCheck and plr.Team == LP.Team
        if skip or not S.Hitbox.Enabled then RestoreHitbox(plr) continue end
        if not OriginalHitboxData[plr] then OriginalHitboxData[plr] = {} end
        local data = OriginalHitboxData[plr]
        for _, part in ipairs(plr.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                if not data[part] then data[part] = {Size=part.Size, Transparency=part.Transparency, CanCollide=part.CanCollide} end
                part.Size = data[part].Size * S.Hitbox.Size
                part.Transparency = 0.7
                part.CanCollide = false
            end
        end
    end
end

local function AimbotStep()
    if S.SilentAim.Enabled then
        local t = GetAimbotTarget(nil, S.SilentAim.VisibleCheck)
        if t and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, t.Head.Position)
        end
        return
    end
    if not S.Aimbot.Enabled then return end
    local t = GetAimbotTarget(nil, S.Aimbot.VisibleCheck)
    if not t then return end
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, t.Head.Position), S.Aimbot.Smoothness)
end

RunService:BindToRenderStep("AimbotStep", Enum.RenderPriority.Camera.Value + 1, AimbotStep)

-- ===== TRIGGER =====
local TriggerT = 0
local function UpdateTrigger()
    if not S.Trigger.Enabled then return end
    if os.clock() - TriggerT < S.Trigger.Delay then return end
    local list = GetEnemies(S.Trigger.TeamCheck, 100)
    local c = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, e in ipairs(list) do
        local sp, on = Camera:WorldToViewportPoint(e.Head.Position)
        if on and (Vector2.new(sp.X,sp.Y) - c).Magnitude < 100 then
            if S.Aimbot.VisibleCheck and not IsVisible(e.Player) then continue end
            FireWeapon()
            TriggerT = os.clock()
            break
        end
    end
end

-- ===== WORLD =====
local function UpdateWorldColor()
    if S.World.ColorEnabled then
        local e = Lighting:FindFirstChild("MB_WorldColor")
        if not e then
            e = Instance.new("ColorCorrectionEffect")
            e.Name = "MB_WorldColor"; e.Parent = Lighting
        end
        e.TintColor = S.World.ColorTint
        e.Saturation = 0.5
        e.Contrast = 0.2
        e.Brightness = 0
    else
        local e = Lighting:FindFirstChild("MB_WorldColor")
        if e then e:Destroy() end
    end
end

local SkyState = {saved=false, oldCT=14, oldAmb=Color3.fromRGB(128,128,128), oldOut=Color3.fromRGB(128,128,128), oldBri=2, oldSkies={}}

local function SaveSky()
    if SkyState.saved then return end
    SkyState.oldCT = Lighting.ClockTime
    SkyState.oldAmb = Lighting.Ambient
    SkyState.oldOut = Lighting.OutdoorAmbient
    SkyState.oldBri = Lighting.Brightness
    SkyState.oldSkies = {}
    for _, s in ipairs(Lighting:GetChildren()) do
        if s:IsA("Sky") then SkyState.oldSkies[s] = s.Enabled end
    end
    SkyState.saved = true
end

local function UpdateSky()
    SaveSky()
    if S.World.SkyEnabled then
        for _, s in ipairs(Lighting:GetChildren()) do
            if s:IsA("Sky") and s.Name ~= "MB_Sky" then s.Enabled = false end
        end
        local sky = Lighting:FindFirstChild("MB_Sky")
        if not sky then
            sky = Instance.new("Sky")
            sky.Name = "MB_Sky"; sky.Parent = Lighting
        end
        sky.SkyboxBk = ""; sky.SkyboxDn = ""; sky.SkyboxFt = ""; sky.SkyboxLf = ""
        sky.SkyboxRt = ""; sky.SkyboxUp = ""
        sky.CelestialBodiesShown = false
        sky.StarCount = 0
        sky.SunAngularSize = 0
        sky.MoonAngularSize = 0
        local atmo = Lighting:FindFirstChild("MB_SkyAtmo")
        if not atmo then
            atmo = Instance.new("Atmosphere")
            atmo.Name = "MB_SkyAtmo"; atmo.Parent = Lighting
        end
        atmo.Density = 2; atmo.Offset = 0; atmo.Glare = 0; atmo.Haze = 0
        atmo.Color = S.World.SkyColor
        atmo.Decay = S.World.SkyTopColor
        Lighting.ClockTime = 0
        Lighting.Brightness = S.World.SkyBrightness
        Lighting.Ambient = S.World.SkyColor:Lerp(Color3.new(0,0,0), 0.8)
        Lighting.OutdoorAmbient = S.World.SkyColor:Lerp(Color3.new(0,0,0), 0.5)
    else
        Lighting.ClockTime = SkyState.oldCT
        Lighting.Brightness = SkyState.oldBri
        Lighting.Ambient = SkyState.oldAmb
        Lighting.OutdoorAmbient = SkyState.oldOut
        for sky, en in pairs(SkyState.oldSkies) do
            if sky and sky.Parent then sky.Enabled = en end
        end
        local sky = Lighting:FindFirstChild("MB_Sky")
        if sky then sky:Destroy() end
        local atmo = Lighting:FindFirstChild("MB_SkyAtmo")
        if atmo then atmo:Destroy() end
    end
end

local function UpdateDarkness()
    if S.World.Darkness > 0 then
        local e = Lighting:FindFirstChild("MB_Darkness")
        if not e then
            e = Instance.new("ColorCorrectionEffect")
            e.Name = "MB_Darkness"; e.Parent = Lighting
        end
        e.Brightness = -S.World.Darkness/100
        e.Contrast = S.World.Darkness/200
    else
        local e = Lighting:FindFirstChild("MB_Darkness")
        if e then e:Destroy() end
    end
end

local function UpdateAtmo()
    if S.World.Atmosphere then
        if not Lighting:FindFirstChild("MB_Atmosphere") then
            local a = Instance.new("Atmosphere")
            a.Name = "MB_Atmosphere"
            a.Density = 0.4; a.Offset = 0.25
            a.Color = Color3.fromRGB(199,199,199)
            a.Decay = Color3.fromRGB(106,112,125)
            a.Glare = 0; a.Haze = 2
            a.Parent = Lighting
        end
    else
        local e = Lighting:FindFirstChild("MB_Atmosphere")
        if e then e:Destroy() end
    end
end

local function UpdateRealism()
    if S.LP.Realism then
        if not Lighting:FindFirstChild("MB_RBloom") then
            local b = Instance.new("BloomEffect")
            b.Name = "MB_RBloom"
            b.Intensity = 0.6; b.Size = 24; b.Threshold = 0.9
            b.Parent = Lighting
        end
        if not Lighting:FindFirstChild("MB_RSun") then
            local sr = Instance.new("SunRaysEffect")
            sr.Name = "MB_RSun"
            sr.Intensity = 0.15; sr.Spread = 0.8
            sr.Parent = Lighting
        end
        if not Lighting:FindFirstChild("MB_RColor") then
            local c = Instance.new("ColorCorrectionEffect")
            c.Name = "MB_RColor"
            c.Brightness = -0.05; c.Contrast = 0.15; c.Saturation = -0.1
            c.TintColor = Color3.fromRGB(255,250,240)
            c.Parent = Lighting
        end
    else
        for _, n in ipairs({"MB_RBloom","MB_RSun","MB_RColor"}) do
            local e = Lighting:FindFirstChild(n)
            if e then e:Destroy() end
        end
    end
end

-- ===== MOVEMENT =====
local function UpdateMovement()
    local char = LP.Character
    if not char then return end
    local h = char:FindFirstChildOfClass("Humanoid")
    local r = char:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end
    if S.Movement.Speed then h.WalkSpeed = S.Movement.SpeedValue else h.WalkSpeed = 16 end
    if S.Movement.BunnyHop and UIS:IsKeyDown(Enum.KeyCode.Space) then h.Jump = true end
    if S.Movement.AutoStrafe and h:GetState() == Enum.HumanoidStateType.Freefall then
        local cl = Camera.CFrame.LookVector
        local fl = Vector3.new(cl.X, 0, cl.Z).Unit
        local v = r.Velocity
        local sp = math.sqrt(v.X^2 + v.Z^2)
        if sp > 1 then r.Velocity = fl * sp + Vector3.new(0, v.Y, 0) end
    end
end

-- ===== GUI =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MasterBAN_Sense"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

local function CreateBindWindow()
    if BindWindow then BindWindow:Destroy() end
    if not next(KeyBinds) then BindWindow = nil; return end
    BindWindow = Instance.new("Frame")
    BindWindow.Size = UDim2.new(0, 220, 0, 30 + #KeyBinds * 22 + 8)
    BindWindow.Position = UDim2.new(0.75, 0, 0.2, 0)
    BindWindow.BackgroundColor3 = Theme.GlassBg
    BindWindow.BackgroundTransparency = Theme.GlassBgTransparency
    BindWindow.BorderSizePixel = 0
    BindWindow.Parent = ScreenGui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,16); c.Parent = BindWindow
    local st = Instance.new("UIStroke"); st.Color = Theme.GlassStroke; st.Transparency = 0.85; st.Parent = BindWindow
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1,0,0,28); t.BackgroundTransparency = 1
    t.Text = "  Key Binds"; t.TextColor3 = Theme.Text; t.TextSize = 14
    t.Font = Enum.Font.GothamBold; t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = BindWindow
    local y = 32
    for fn, k in pairs(KeyBinds) do
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,-16,0,20); l.Position = UDim2.new(0,8,0,y); l.BackgroundTransparency = 1
        l.Text = fn .. "  →  " .. k.Name
        l.TextColor3 = Theme.TextDim; l.TextSize = 12; l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = BindWindow
        y = y + 22
    end
end

-- Watermark
local Watermark = Instance.new("Frame")
Watermark.Size = UDim2.new(0, 520, 0, 38)
Watermark.Position = UDim2.new(0.5, -260, 0, 12)
Watermark.BackgroundColor3 = Theme.GlassBg
Watermark.BackgroundTransparency = 0.45
Watermark.BorderSizePixel = 0
Watermark.Visible = false
Watermark.Parent = ScreenGui
local wmc = Instance.new("UICorner"); wmc.CornerRadius = UDim.new(0,19); wmc.Parent = Watermark
local wms = Instance.new("UIStroke"); wms.Color = Theme.GlassStroke; wms.Transparency = 0.75; wms.Parent = Watermark
local WmText = Instance.new("TextLabel")
WmText.Size = UDim2.new(1,-20,1,0); WmText.Position = UDim2.new(0,10,0,0)
WmText.BackgroundTransparency = 1
WmText.Text = "MasterBAN-Sense v18.0   |   TG: @MewNenti   |   FPS: 0   |   " .. LP.Name
WmText.TextColor3 = Theme.Text; WmText.TextSize = 14; WmText.Font = Enum.Font.GothamBold
WmText.TextXAlignment = Enum.TextXAlignment.Center
WmText.Parent = Watermark

-- Open M
local OpenButton = Instance.new("TextButton")
OpenButton.Size = UDim2.new(0, 60, 0, 60)
OpenButton.Position = UDim2.new(0.05, 0, 0.5, 0)
OpenButton.BackgroundColor3 = Theme.GlassBg
OpenButton.BackgroundTransparency = 0.45
OpenButton.BorderSizePixel = 0
OpenButton.Text = "M"; OpenButton.TextColor3 = Theme.Text; OpenButton.TextSize = 22
OpenButton.Font = Enum.Font.GothamBold; OpenButton.AutoButtonColor = false
OpenButton.Visible = false
OpenButton.Parent = ScreenGui
local oc = Instance.new("UICorner"); oc.CornerRadius = UDim.new(1,0); oc.Parent = OpenButton
local os2 = Instance.new("UIStroke"); os2.Color = Theme.GlassStroke; os2.Transparency = 0.85; os2.Parent = OpenButton

-- Main
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 620, 0, 500)
Main.Position = UDim2.new(0.5, -310, 0.5, -250)
Main.BackgroundColor3 = Theme.GlassBg
Main.BackgroundTransparency = 0.45
Main.BorderSizePixel = 0
Main.Visible = false
Main.ClipsDescendants = true
Main.Parent = ScreenGui
local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0,22); mc.Parent = Main
local ms = Instance.new("UIStroke"); ms.Color = Theme.GlassStroke; ms.Transparency = 0.85; ms.Parent = Main

local Title = Instance.new("Frame")
Title.Size = UDim2.new(1,0,0,42); Title.BackgroundTransparency = 1; Title.Parent = Main
local TText = Instance.new("TextLabel")
TText.Size = UDim2.new(1,-30,1,0); TText.Position = UDim2.new(0,20,0,0); TText.BackgroundTransparency = 1
TText.Text = "MasterBAN-Sense"; TText.TextColor3 = Theme.Text; TText.TextSize = 16
TText.Font = Enum.Font.GothamBold; TText.TextXAlignment = Enum.TextXAlignment.Left
TText.Parent = Title
local TVer = Instance.new("TextLabel")
TVer.Size = UDim2.new(0,60,1,0); TVer.Position = UDim2.new(1,-110,0,0); TVer.BackgroundTransparency = 1
TVer.Text = "v18.0"; TVer.TextColor3 = Theme.TextMuted; TVer.TextSize = 12
TVer.Font = Enum.Font.Gotham; TVer.TextXAlignment = Enum.TextXAlignment.Left
TVer.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,14,0,14); CloseBtn.Position = UDim2.new(1,-48,0,14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255,95,86); CloseBtn.BorderSizePixel = 0
CloseBtn.Text = ""; CloseBtn.AutoButtonColor = false; CloseBtn.Parent = Title
local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(1,0); cbc.Parent = CloseBtn

local TabPanel = Instance.new("Frame")
TabPanel.Size = UDim2.new(0,130,1,-60); TabPanel.Position = UDim2.new(0,12,0,50)
TabPanel.BackgroundColor3 = Color3.fromRGB(255,255,255)
TabPanel.BackgroundTransparency = 0.94; TabPanel.BorderSizePixel = 0; TabPanel.Parent = Main
local tpc = Instance.new("UICorner"); tpc.CornerRadius = UDim.new(0,16); tpc.Parent = TabPanel

local SettingsPanel = Instance.new("Frame")
SettingsPanel.Size = UDim2.new(1,-160,1,-60); SettingsPanel.Position = UDim2.new(0,150,0,50)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(255,255,255)
SettingsPanel.BackgroundTransparency = 0.94; SettingsPanel.BorderSizePixel = 0
SettingsPanel.ClipsDescendants = true; SettingsPanel.Parent = Main
local spc = Instance.new("UICorner"); spc.CornerRadius = UDim.new(0,16); spc.Parent = SettingsPanel

local tabButtons = {}
local tabContents = {}

local function CreateTab(name, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-12,0,32); b.Position = UDim2.new(0,6,0,y)
    b.BackgroundColor3 = Color3.fromRGB(255,255,255); b.BackgroundTransparency = 1
    b.BorderSizePixel = 0; b.Text = name; b.TextColor3 = Theme.TextDim
    b.TextSize = 11; b.Font = Enum.Font.GothamBold; b.AutoButtonColor = false
    b.Parent = TabPanel
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = b
    b.MouseEnter:Connect(function()
        if tabContents[name] and tabContents[name].Visible then return end
        TS:Create(b, TweenInfo.new(0.2), {BackgroundTransparency=0.85, BackgroundColor3=Theme.Hover, TextColor3=Theme.Text}):Play()
    end)
    b.MouseLeave:Connect(function()
        if tabContents[name] and tabContents[name].Visible then return end
        TS:Create(b, TweenInfo.new(0.2), {BackgroundTransparency=1, TextColor3=Theme.TextDim}):Play()
    end)
    tabButtons[name] = b
end

local function CreateContent(name)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,1,0); f.Position = UDim2.new(0,0,0,0)
    f.BackgroundTransparency = 1; f.Visible = false; f.ClipsDescendants = true
    f.Parent = SettingsPanel
    tabContents[name] = f
end

local currentTab = nil
local function SwitchTab(name)
    if currentTab == name then return end
    currentTab = name
    for tn, c in pairs(tabContents) do
        if tn == name then
            c.Visible = true; c.Position = UDim2.new(0,12,0,0)
            TS:Create(c, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position=UDim2.new(0,0,0,0)}):Play()
            TS:Create(tabButtons[tn], TweenInfo.new(0.25), {BackgroundTransparency=0.75, BackgroundColor3=Theme.Accent, TextColor3=Theme.Text}):Play()
        else
            c.Visible = false
            TS:Create(tabButtons[tn], TweenInfo.new(0.25), {BackgroundTransparency=1, TextColor3=Theme.TextDim}):Play()
        end
    end
end

local function MakeToggle(parent, text, y, getter, setter, bind)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-24,0,32); b.Position = UDim2.new(0,12,0,y)
    b.BackgroundColor3 = getter() and Theme.ToggleOn or Theme.ToggleOff
    b.BackgroundTransparency = getter() and 0.1 or 0.5
    b.BorderSizePixel = 0; b.Text = "  " .. text; b.TextColor3 = Theme.Text
    b.TextSize = 12; b.Font = Enum.Font.Gotham; b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false; b.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = b
    local d = Instance.new("Frame")
    d.Size = UDim2.new(0,8,0,8); d.Position = UDim2.new(1,-18,0.5,-4)
    d.BackgroundColor3 = getter() and Color3.fromRGB(120,255,180) or Color3.fromRGB(120,120,140)
    d.BorderSizePixel = 0; d.Parent = b
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1,0); dc.Parent = d
    toggleButtons[bind or text] = b
    local hov = false
    b.MouseEnter:Connect(function() hov = true TS:Create(b, TweenInfo.new(0.2), {BackgroundTransparency=getter() and 0 or 0.35}):Play() end)
    b.MouseLeave:Connect(function() hov = false TS:Create(b, TweenInfo.new(0.2), {BackgroundTransparency=getter() and 0.1 or 0.5}):Play() end)
    b.MouseButton1Click:Connect(function()
        setter(not getter())
        local v = getter()
        TS:Create(b, TweenInfo.new(0.25), {BackgroundColor3 = v and Theme.ToggleOn or Theme.ToggleOff, BackgroundTransparency = v and (hov and 0 or 0.1) or (hov and 0.35 or 0.5)}):Play()
        TS:Create(d, TweenInfo.new(0.25), {BackgroundColor3 = v and Color3.fromRGB(120,255,180) or Color3.fromRGB(120,120,140)}):Play()
    end)
end

local function MakeSlider(parent, text, y, mn, mx, getter, setter)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-24,0,44); f.Position = UDim2.new(0,12,0,y)
    f.BackgroundTransparency = 1; f.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,16); l.BackgroundTransparency = 1
    l.Text = text .. ":  " .. getter(); l.TextColor3 = Theme.TextDim
    l.TextSize = 11; l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local tr = Instance.new("TextButton")
    tr.Size = UDim2.new(1,0,0,8); tr.Position = UDim2.new(0,0,0,24)
    tr.BackgroundColor3 = Color3.fromRGB(255,255,255); tr.BackgroundTransparency = 0.8
    tr.BorderSizePixel = 0; tr.Text = ""; tr.AutoButtonColor = false; tr.Parent = f
    local trc = Instance.new("UICorner"); trc.CornerRadius = UDim.new(1,0); trc.Parent = tr
    local fl = Instance.new("Frame")
    fl.Size = UDim2.new((getter()-mn)/(mx-mn),0,1,0)
    fl.BackgroundColor3 = Theme.Accent; fl.BorderSizePixel = 0; fl.Parent = tr
    local flc = Instance.new("UICorner"); flc.CornerRadius = UDim.new(1,0); flc.Parent = fl
    local kn = Instance.new("Frame")
    kn.Size = UDim2.new(0,14,0,14); kn.Position = UDim2.new(fl.Size.X.Scale,-7,0.5,-7)
    kn.BackgroundColor3 = Color3.fromRGB(255,255,255); kn.BorderSizePixel = 0; kn.Parent = tr
    local knc = Instance.new("UICorner"); knc.CornerRadius = UDim.new(1,0); knc.Parent = kn
    local drag, dc, ec
    tr.MouseButton1Down:Connect(function()
        drag = true
        if dc then dc:Disconnect() end
        if ec then ec:Disconnect() end
        dc = UIS.InputChanged:Connect(function(i)
            if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
                local p = math.clamp((i.Position.X - tr.AbsolutePosition.X)/tr.AbsoluteSize.X, 0, 1)
                local v = math.floor(mn + p*(mx-mn) + 0.5)
                setter(v); l.Text = text .. ":  " .. v
                fl.Size = UDim2.new(p,0,1,0); kn.Position = UDim2.new(p,-7,0.5,-7)
            end
        end)
        ec = UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                drag = false
                if dc then dc:Disconnect(); dc = nil end
                if ec then ec:Disconnect(); ec = nil end
            end
        end)
    end)
end

local function MakeColor(parent, text, y, getter, setter)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-24,0,36); f.Position = UDim2.new(0,12,0,y)
    f.BackgroundTransparency = 1; f.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0,130,1,0); l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = Theme.TextDim; l.TextSize = 11
    l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local cb = Instance.new("TextButton")
    cb.Size = UDim2.new(0,70,0,26); cb.Position = UDim2.new(0,140,0,5)
    cb.BackgroundColor3 = getter(); cb.Text = ""; cb.BorderSizePixel = 0
    cb.AutoButtonColor = false; cb.Parent = f
    local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0,8); cbc.Parent = cb
    local pal = {
        Color3.fromRGB(0,0,0), Color3.fromRGB(30,30,30), Color3.fromRGB(100,100,100),
        Color3.fromRGB(255,255,255), Color3.fromRGB(255,0,0), Color3.fromRGB(0,255,0),
        Color3.fromRGB(0,100,255), Color3.fromRGB(255,255,0), Color3.fromRGB(255,0,255),
        Color3.fromRGB(0,255,255), Color3.fromRGB(255,128,0)
    }
    local i = 1
    cb.MouseButton1Click:Connect(function()
        i = i % #pal + 1
        setter(pal[i]); cb.BackgroundColor3 = pal[i]
    end)
end

local function MakeDropdown(parent, text, y, options, getter, setter)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-24,0,36); f.Position = UDim2.new(0,12,0,y)
    f.BackgroundTransparency = 1; f.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0,100,1,0); l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = Theme.TextDim; l.TextSize = 11
    l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,200,0,26); b.Position = UDim2.new(0,110,0,5)
    b.BackgroundColor3 = Color3.fromRGB(255,255,255); b.BackgroundTransparency = 0.85
    b.BorderSizePixel = 0; b.Text = getter(); b.TextColor3 = Theme.Text
    b.TextSize = 11; b.Font = Enum.Font.Gotham; b.AutoButtonColor = false
    b.Parent = f
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,8); bc.Parent = b
    b.MouseButton1Click:Connect(function()
        local cur = getter()
        local i = table.find(options, cur) or 1
        local ni = i % #options + 1
        setter(options[ni]); b.Text = getter()
    end)
end

CreateTab("ESP", 10)
CreateTab("AIM", 46)
CreateTab("WEAPON", 82)
CreateTab("WORLD", 118)
CreateTab("LOCAL", 154)
CreateTab("MOVEMENT", 190)

local function NewScroll(parent)
    local sc = Instance.new("ScrollingFrame")
    sc.Size = UDim2.new(1,0,1,0); sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0; sc.ScrollBarThickness = 6
    sc.ScrollBarImageColor3 = Theme.Accent; sc.ScrollBarImageTransparency = 0.2
    sc.CanvasSize = UDim2.new(0,0,0,0)
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.ScrollingDirection = Enum.ScrollingDirection.Y
    sc.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
    sc.Parent = parent
    return sc
end

CreateContent("ESP")
local espScroll = NewScroll(tabContents["ESP"])
MakeToggle(espScroll, "ESP", 10, function() return S.ESP.Enabled end, function(v) S.ESP.Enabled=v end, "ESP")
MakeToggle(espScroll, "Team Check", 48, function() return S.ESP.TeamCheck end, function(v) S.ESP.TeamCheck=v end)
MakeToggle(espScroll, "Box", 86, function() return S.ESP.ShowBox end, function(v) S.ESP.ShowBox=v end)
MakeToggle(espScroll, "Corner Box", 124, function() return S.ESP.CornerBox end, function(v) S.ESP.CornerBox=v end)
MakeToggle(espScroll, "Filled Box", 162, function() return S.ESP.FilledBox end, function(v) S.ESP.FilledBox=v end)
MakeSlider(espScroll, "Fill Transparency x100", 200, 0, 100, function() return math.floor(S.ESP.FilledTransparency*100) end, function(v) S.ESP.FilledTransparency=v/100 end)
MakeToggle(espScroll, "Name", 250, function() return S.ESP.ShowName end, function(v) S.ESP.ShowName=v end)
MakeToggle(espScroll, "Health", 288, function() return S.ESP.ShowHealth end, function(v) S.ESP.ShowHealth=v end)
MakeToggle(espScroll, "Distance", 326, function() return S.ESP.ShowDistance end, function(v) S.ESP.ShowDistance=v end)
MakeToggle(espScroll, "Weapon", 364, function() return S.ESP.ShowWeapon end, function(v) S.ESP.ShowWeapon=v end)
MakeToggle(espScroll, "Skeleton", 402, function() return S.ESP.ShowSkeleton end, function(v) S.ESP.ShowSkeleton=v end)
MakeColor(espScroll, "Skeleton Color", 440, function() return S.ESP.SkeletonColor end, function(v) S.ESP.SkeletonColor=v end)
MakeToggle(espScroll, "Head Dot", 484, function() return S.ESP.ShowHeadDot end, function(v) S.ESP.ShowHeadDot=v end)
MakeToggle(espScroll, "Enemy Chams", 522, function() return S.ESP.EnemyChams end, function(v) S.ESP.EnemyChams=v end)
MakeColor(espScroll, "ESP Color", 560, function() return S.ESP.Color end, function(v) S.ESP.Color=v end)
MakeSlider(espScroll, "Max Distance", 604, 50, 2000, function() return S.ESP.MaxDistance end, function(v) S.ESP.MaxDistance=v end)

CreateContent("AIM")
local aimTab = tabContents["AIM"]
MakeToggle(aimTab, "Aimbot", 10, function() return S.Aimbot.Enabled end, function(v) S.Aimbot.Enabled=v end, "Aimbot")
MakeToggle(aimTab, "Silent Aim", 48, function() return S.SilentAim.Enabled end, function(v) S.SilentAim.Enabled=v end, "Silent Aim")
MakeToggle(aimTab, "Team Check", 86, function() return S.Aimbot.TeamCheck end, function(v) S.Aimbot.TeamCheck=v end)
MakeToggle(aimTab, "Visible Check", 124, function() return S.Aimbot.VisibleCheck end, function(v) S.Aimbot.VisibleCheck=v end)
MakeSlider(aimTab, "FOV", 162, 1, 100, function() return S.Aimbot.FOV end, function(v) S.Aimbot.FOV=v end)
MakeSlider(aimTab, "Smooth x100", 212, 1, 50, function() return math.floor(S.Aimbot.Smoothness*100) end, function(v) S.Aimbot.Smoothness=v/100 end)

CreateContent("WEAPON")
local wTab = tabContents["WEAPON"]
MakeToggle(wTab, "TriggerBot", 10, function() return S.Trigger.Enabled end, function(v) S.Trigger.Enabled=v end)
MakeToggle(wTab, "Trigger Team Check", 48, function() return S.Trigger.TeamCheck end, function(v) S.Trigger.TeamCheck=v end)
MakeSlider(wTab, "Trigger Delay x10ms", 86, 1, 20, function() return math.floor(S.Trigger.Delay*10) end, function(v) S.Trigger.Delay=v/10 end)
MakeToggle(wTab, "Hitbox Expander", 136, function() return S.Hitbox.Enabled end, function(v) S.Hitbox.Enabled=v end)
MakeSlider(wTab, "Hitbox Size x10", 174, 10, 50, function() return math.floor(S.Hitbox.Size*10) end, function(v) S.Hitbox.Size=v/10 end)

CreateContent("WORLD")
local wWorld = tabContents["WORLD"]
MakeToggle(wWorld, "World Color", 10, function() return S.World.ColorEnabled end, function(v) S.World.ColorEnabled=v end)
MakeColor(wWorld, "World Tint", 48, function() return S.World.ColorTint end, function(v) S.World.ColorTint=v end)
MakeToggle(wWorld, "Sky Color", 90, function() return S.World.SkyEnabled end, function(v) S.World.SkyEnabled=v end)
MakeColor(wWorld, "Sky Color Base", 128, function() return S.World.SkyColor end, function(v) S.World.SkyColor=v end)
MakeColor(wWorld, "Sky Top Color", 164, function() return S.World.SkyTopColor end, function(v) S.World.SkyTopColor=v end)
MakeSlider(wWorld, "Sky Brightness x10", 208, -100, 100, function() return math.floor(S.World.SkyBrightness*10) end, function(v) S.World.SkyBrightness=v/10 end)
MakeToggle(wWorld, "Atmosphere", 258, function() return S.World.Atmosphere end, function(v) S.World.Atmosphere=v end)
MakeSlider(wWorld, "Darkness", 296, 0, 100, function() return S.World.Darkness end, function(v) S.World.Darkness=v end)

CreateContent("LOCAL")
local lTab = tabContents["LOCAL"]
MakeToggle(lTab, "Realism", 10, function() return S.LP.Realism end, function(v) S.LP.Realism=v end)

CreateContent("MOVEMENT")
local mTab = tabContents["MOVEMENT"]
MakeToggle(mTab, "BunnyHop", 10, function() return S.Movement.BunnyHop end, function(v) S.Movement.BunnyHop=v end)
MakeToggle(mTab, "Auto Strafe", 48, function() return S.Movement.AutoStrafe end, function(v) S.Movement.AutoStrafe=v end)
MakeToggle(mTab, "Speed", 86, function() return S.Movement.Speed end, function(v) S.Movement.Speed=v end)
MakeSlider(mTab, "Speed Value", 124, 16, 50, function() return S.Movement.SpeedValue end, function(v) S.Movement.SpeedValue=v end)

SwitchTab("ESP")

-- ===== INTRO ANIMATION =====
local Intro = Instance.new("Frame")
Intro.Name = "MB_Intro"
Intro.Size = UDim2.new(1, 0, 1, 0)
Intro.Position = UDim2.new(0, 0, 0, 0)
Intro.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Intro.BackgroundTransparency = 1
Intro.BorderSizePixel = 0
Intro.ZIndex = 100
Intro.Parent = ScreenGui

-- затемнение слева направо делаем через два фрейма-маски: левая половина растёт
local Mask = Instance.new("Frame")
Mask.Size = UDim2.new(0, 0, 1, 0)
Mask.Position = UDim2.new(0, 0, 0, 0)
Mask.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Mask.BackgroundTransparency = 0.15
Mask.BorderSizePixel = 0
Mask.ZIndex = 101
Mask.Parent = ScreenGui

-- текст по центру
local IntroContainer = Instance.new("Frame")
IntroContainer.Size = UDim2.new(1, 0, 0, 200)
IntroContainer.Position = UDim2.new(0, 0, 0.5, -100)
IntroContainer.BackgroundTransparency = 1
IntroContainer.ZIndex = 102
IntroContainer.Parent = ScreenGui

local WordMaster = Instance.new("TextLabel")
WordMaster.Size = UDim2.new(1, 0, 0, 80)
WordMaster.Position = UDim2.new(0, 0, 0, 0)
WordMaster.BackgroundTransparency = 1
WordMaster.Text = "Master"
WordMaster.TextColor3 = Color3.fromRGB(255, 255, 255)
WordMaster.TextSize = 72
WordMaster.Font = Enum.Font.GothamBlack
WordMaster.TextTransparency = 1
WordMaster.ZIndex = 102
WordMaster.Parent = IntroContainer

local WordBAN = Instance.new("TextLabel")
WordBAN.Size = UDim2.new(1, 0, 0, 80)
WordBAN.Position = UDim2.new(0, 0, 0, 60)
WordBAN.BackgroundTransparency = 1
WordBAN.Text = "BAN"
WordBAN.TextColor3 = Color3.fromRGB(180, 120, 255)
WordBAN.TextSize = 72
WordBAN.Font = Enum.Font.GothamBlack
WordBAN.TextTransparency = 1
WordBAN.ZIndex = 102
WordBAN.Parent = IntroContainer

local WordSense = Instance.new("TextLabel")
WordSense.Size = UDim2.new(1, 0, 0, 80)
WordSense.Position = UDim2.new(0, 0, 0, 120)
WordSense.BackgroundTransparency = 1
WordSense.Text = "Sense"
WordSense.TextColor3 = Color3.fromRGB(120, 90, 255)
WordSense.TextSize = 72
WordSense.Font = Enum.Font.GothamBlack
WordSense.TextTransparency = 1
WordSense.ZIndex = 102
WordSense.Parent = IntroContainer

local ByText = Instance.new("TextLabel")
ByText.Size = UDim2.new(1, 0, 0, 120)
ByText.Position = UDim2.new(0, 0, 0.15, 0)
ByText.BackgroundTransparency = 1
ByText.Text = "by MewNenti"
ByText.TextColor3 = Color3.fromRGB(255, 255, 255)
ByText.TextSize = 60
ByText.Font = Enum.Font.GothamBlack
ByText.TextTransparency = 1
ByText.ZIndex = 103
ByText.Parent = ScreenGui

task.spawn(function()
    task.wait(0.1)

    -- затемнение слева направо
    local maskTween = TS:Create(Mask, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 0.15,
    })
    maskTween:Play()
    task.wait(0.7)

    -- Master
    TS:Create(WordMaster, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
    task.wait(0.25)

    -- BAN
    TS:Create(WordBAN, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
    task.wait(0.25)

    -- Sense
    TS:Create(WordSense, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
    task.wait(0.6)

    -- держим 0.6 сек
    task.wait(0.6)

    -- все три уходят вверх
    local upInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
    TS:Create(WordMaster, upInfo, {Position = UDim2.new(0, 0, 0, -100), TextTransparency = 1}):Play()
    TS:Create(WordBAN, upInfo, {Position = UDim2.new(0, 0, 0, -40), TextTransparency = 1}):Play()
    TS:Create(WordSense, upInfo, {Position = UDim2.new(0, 0, 0, 20), TextTransparency = 1}):Play()
    task.wait(0.15)

    -- by MewNenti сверху появляется
    TS:Create(ByText, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
    task.wait(1.0)

    -- всё исчезает — маска едет вверх
    TS:Create(ByText, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Position = UDim2.new(0, 0, -0.3, 0), TextTransparency = 1
    }):Play()
    TS:Create(Mask, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Position = UDim2.new(0, 0, -1, 0),
        BackgroundTransparency = 1,
    }):Play()
    task.wait(0.7)

    -- показываем ватермарк и кнопку
    Watermark.Visible = true
    Watermark.Position = UDim2.new(0.5, -260, 0, -50)
    TS:Create(Watermark, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -260, 0, 12),
    }):Play()

    OpenButton.Visible = true
    OpenButton.Position = UDim2.new(-0.1, 0, 0.5, 0)
    TS:Create(OpenButton, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.05, 0, 0.5, 0),
    }):Play()

    task.wait(0.6)
    Intro:Destroy()
    Mask:Destroy()
    IntroContainer:Destroy()
    ByText:Destroy()
end)

-- Open/Close
local isOpen = false
local isAnim = false

local function OpenMenu()
    if isOpen or isAnim then return end
    isOpen = true; isAnim = true
    OpenButton.Visible = false
    Main.Visible = true
    Main.BackgroundTransparency = 1
    ms.Transparency = 1
    Main.Position = UDim2.new(0.5, -310, 0.5, -240)
    local info = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    TS:Create(Main, info, {BackgroundTransparency=0.45, Position=UDim2.new(0.5,-310,0.5,-250)}):Play()
    TS:Create(ms, info, {Transparency=0.85}):Play()
    task.delay(0.4, function() isAnim = false end)
end

local function CloseMenu()
    if not isOpen or isAnim then return end
    isOpen = false; isAnim = true
    local info = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
    TS:Create(Main, info, {BackgroundTransparency=1, Position=UDim2.new(0.5,-310,0.5,-240), Size=UDim2.new(0,600,0,480)}):Play()
    TS:Create(ms, info, {Transparency=1}):Play()
    task.delay(0.3, function()
        Main.Visible = false
        Main.Size = UDim2.new(0,620,0,500)
        Main.Position = UDim2.new(0.5,-310,0.5,-250)
        OpenButton.Visible = true
        isAnim = false
    end)
end

OpenButton.MouseButton1Click:Connect(function() if isOpen then CloseMenu() else OpenMenu() end end)
CloseBtn.MouseButton1Click:Connect(CloseMenu)

-- Drags
local btnDrag, btnStart, btnPos = false, nil, nil
OpenButton.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        btnDrag = true; btnStart = i.Position; btnPos = OpenButton.Position
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then btnDrag = false end
end)
UIS.InputChanged:Connect(function(i)
    if btnDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - btnStart
        OpenButton.Position = UDim2.new(btnPos.X.Scale, btnPos.X.Offset+d.X, btnPos.Y.Scale, btnPos.Y.Offset+d.Y)
    end
end)

local menuDrag, menuStart, menuPos = false, nil, nil
Title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        menuDrag = true; menuStart = i.Position; menuPos = Main.Position
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then menuDrag = false end
end)
UIS.InputChanged:Connect(function(i)
    if menuDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - menuStart
        Main.Position = UDim2.new(menuPos.X.Scale, menuPos.X.Offset+d.X, menuPos.Y.Scale, menuPos.Y.Offset+d.Y)
    end
end)

tabButtons["ESP"].MouseButton1Click:Connect(function() SwitchTab("ESP") end)
tabButtons["AIM"].MouseButton1Click:Connect(function() SwitchTab("AIM") end)
tabButtons["WEAPON"].MouseButton1Click:Connect(function() SwitchTab("WEAPON") end)
tabButtons["WORLD"].MouseButton1Click:Connect(function() SwitchTab("WORLD") end)
tabButtons["LOCAL"].MouseButton1Click:Connect(function() SwitchTab("LOCAL") end)
tabButtons["MOVEMENT"].MouseButton1Click:Connect(function() SwitchTab("MOVEMENT") end)

Players.PlayerRemoving:Connect(function(plr)
    OriginalHitboxData[plr] = nil
    if EnemyHighlights[plr] then
        if EnemyHighlights[plr].Parent then EnemyHighlights[plr]:Destroy() end
        EnemyHighlights[plr] = nil
    end
end)

-- Loop
RunService.RenderStepped:Connect(function(dt)
    FrameCount = FrameCount + 1
    if os.clock() - LastFPSTime >= 1 then
        FPS = FrameCount; FrameCount = 0; LastFPSTime = os.clock()
        WmText.Text = "MasterBAN-Sense v18.0   |   TG: @MewNenti   |   FPS: " .. FPS .. "   |   " .. LP.Name
    end
    UpdateESP()
    UpdateFOV()
    UpdateTrigger()
    UpdateWorldColor()
    UpdateSky()
    UpdateDarkness()
    UpdateAtmo()
    UpdateRealism()
    UpdateMovement()
    UpdateHitbox()
end)

print("[+] MasterBAN-Sense v18.0 loaded!")
print("[+] TG: @MewNenti")