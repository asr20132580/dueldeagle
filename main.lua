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
    ESP = {
        Enabled=false,
        Box=false, CornerBox=false, FilledBox=false,
        FilledTransparency=0.7, BoxThickness=1.5,
        Chams=false, ChamFill=true, ChamOutline=true, ChamFillTransparency=0.4,
        Skeleton=false, SkeletonThickness=1.5, SkeletonColor=Color3.fromRGB(255,255,255),
        HeadDot=false, HeadDotRadius=4,
        Name=false, Health=false, Distance=false, Weapon=false,
        Tracer=false, TracerOrigin="Bottom", TracerThickness=1.5,
        TracerColor=Color3.fromRGB(255,50,50),
        IgnoreAFK=false, AFKSeconds=3,
        MaxDistance=1000,
        Color=Color3.fromRGB(255,0,0),
        FillColor=Color3.fromRGB(255,0,0),
    },
    Aimbot = { Enabled=false, FOV=100, FOVColor=Color3.fromRGB(200,100,255), Smoothness=0.3, VisibleCheck=true },
    Trigger = { Enabled=false, Delay=0.1 },
    World = {
        ColorEnabled=false,
        ColorTint=Color3.fromRGB(255,100,100),
        Saturation=0.5,
        Contrast=0.2,
        Brightness=0,
    },
    Local = { SelfColor=Color3.fromRGB(0,200,255), SelfFill=true, SelfOutline=true, WeaponChams=false },
    Movement = { BunnyHop=false, AutoStrafe=false, Speed=false, SpeedValue=22, JumpPower=false, JumpValue=50 },
    Menu = {
        Glass = true,
        AccentColor = Color3.fromRGB(120,90,255),
        BgColor = Color3.fromRGB(20,20,30),
        StrokeColor = Color3.fromRGB(255,255,255),
        TextColor = Color3.fromRGB(255,255,255),
        WatermarkPos = "TopCenter",
        ShowDarken = true,
        DarkenAmount = 0.3,
    }
}

local CurrentAccent = S.Menu.AccentColor
local CurrentBg = S.Menu.BgColor
local CurrentStroke = S.Menu.StrokeColor
local CurrentText = S.Menu.TextColor

local toggleButtons = {}
local toggleRows = {}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible=false; FOVCircle.Radius=150; FOVCircle.Color=Color3.fromRGB(200,100,255)
FOVCircle.Thickness=1; FOVCircle.Filled=false; FOVCircle.NumSides=40; FOVCircle.Transparency=0.7

local FPS = 0
local FrameCount = 0
local LastFPSTime = os.clock()
local EnemyChamsFill = {}
local EnemyChamsOutline = {}

-- ===== AFK =====
local AFKTimer = {}
local LastPos = {}
local AFKSeconds = 3

local function IsAFK(plr)
    if not plr or not plr.Character then return false end
    local char = plr.Character
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return false end
    local now = tick()
    if hum.MoveDirection.Magnitude > 0.01 then
        AFKTimer[plr] = now; LastPos[plr] = root.Position; return false
    end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
        or state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.PlatformStanding
        or state == Enum.HumanoidStateType.Swimming or state == Enum.HumanoidStateType.Climbing
        or state == Enum.HumanoidStateType.Ragdoll then
        AFKTimer[plr] = now; LastPos[plr] = root.Position; return false
    end
    local v = root.Velocity
    if math.sqrt(v.X^2 + v.Z^2) > 1.5 then
        AFKTimer[plr] = now; LastPos[plr] = root.Position; return false
    end
    local lp = LastPos[plr]
    if not lp then LastPos[plr] = root.Position; AFKTimer[plr] = now; return false end
    if (root.Position - lp).Magnitude > 3 then
        LastPos[plr] = root.Position; AFKTimer[plr] = now; return false
    end
    LastPos[plr] = root.Position
    return (now - (AFKTimer[plr] or now)) >= AFKSeconds
end

-- ===== ESP POOL =====
local ESPPool = {
    lines={}, texts={}, circles={}, squares={},
    used={lines=0, texts=0, circles=0, squares=0},
}

local function PoolGetLine()
    ESPPool.used.lines = ESPPool.used.lines + 1
    local i = ESPPool.used.lines
    if not ESPPool.lines[i] then
        local l = Drawing.new("Line"); l.Visible = false; ESPPool.lines[i] = l
    end
    return ESPPool.lines[i]
end
local function PoolGetText()
    ESPPool.used.texts = ESPPool.used.texts + 1
    local i = ESPPool.used.texts
    if not ESPPool.texts[i] then
        local t = Drawing.new("Text"); t.Center = true; t.Outline = true
        t.OutlineColor = Color3.fromRGB(0,0,0); t.Visible = false; ESPPool.texts[i] = t
    end
    return ESPPool.texts[i]
end
local function PoolGetCircle()
    ESPPool.used.circles = ESPPool.used.circles + 1
    local i = ESPPool.used.circles
    if not ESPPool.circles[i] then
        local c = Drawing.new("Circle"); c.NumSides = 20; c.Thickness = 1; c.Visible = false; ESPPool.circles[i] = c
    end
    return ESPPool.circles[i]
end
local function PoolGetSquare()
    ESPPool.used.squares = ESPPool.used.squares + 1
    local i = ESPPool.used.squares
    if not ESPPool.squares[i] then
        local s = Drawing.new("Square"); s.Thickness = 1; s.Visible = false; ESPPool.squares[i] = s
    end
    return ESPPool.squares[i]
end

local function PoolBegin()
    ESPPool.used.lines=0; ESPPool.used.texts=0; ESPPool.used.circles=0; ESPPool.used.squares=0
end
local function PoolEnd()
    for i=ESPPool.used.lines+1,#ESPPool.lines do ESPPool.lines[i].Visible=false end
    for i=ESPPool.used.texts+1,#ESPPool.texts do ESPPool.texts[i].Visible=false end
    for i=ESPPool.used.circles+1,#ESPPool.circles do ESPPool.circles[i].Visible=false end
    for i=ESPPool.used.squares+1,#ESPPool.squares do ESPPool.squares[i].Visible=false end
end

local function Line(a, b, c, t, tr)
    local l = PoolGetLine()
    l.From=a; l.To=b; l.Color=c; l.Thickness=t or 1.5; l.Transparency=tr or 1; l.Visible=true
    return l
end
local function Text(txt, pos, c, sz)
    local t = PoolGetText()
    t.Text=txt; t.Position=pos; t.Color=c; t.Size=sz or 13; t.Visible=true
    return t
end
local function Circle(pos, r, c, f)
    local ci = PoolGetCircle()
    ci.Position=pos; ci.Radius=r; ci.Color=c; ci.Filled=f or false; ci.Transparency=1; ci.Visible=true
    return ci
end
local function Square(pos, sz, c, f, tr)
    local sq = PoolGetSquare()
    sq.Position=pos; sq.Size=sz; sq.Color=c; sq.Filled=f or false; sq.Transparency=tr or 1; sq.Visible=true
    return sq
end

-- ===== HELPERS =====
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

local function GetEnemies(maxDist)
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        if not plr.Character then continue end
        local h = plr.Character:FindFirstChildOfClass("Humanoid")
        local r = plr.Character:FindFirstChild("HumanoidRootPart")
        local hd = plr.Character:FindFirstChild("Head")
        if not r or not h or h.Health <= 0 then continue end
        if S.ESP.IgnoreAFK and IsAFK(plr) then continue end
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

local function DrawSkeleton(char, col, thickness)
    for _, c in ipairs(SkeletonConns) do
        local p1 = char:FindFirstChild(c[1])
        local p2 = char:FindFirstChild(c[2])
        if p1 and p2 then
            local s1,o1 = Camera:WorldToViewportPoint(p1.Position)
            local s2,o2 = Camera:WorldToViewportPoint(p2.Position)
            if o1 and o2 then Line(Vector2.new(s1.X,s1.Y), Vector2.new(s2.X,s2.Y), col, thickness or 1.5) end
        end
    end
end

local function UpdateEnemyChams(enemies)
    for plr, h in pairs(EnemyChamsFill) do
        if h and h.Parent then h:Destroy() end
        EnemyChamsFill[plr] = nil
    end
    for plr, h in pairs(EnemyChamsOutline) do
        if h and h.Parent then h:Destroy() end
        EnemyChamsOutline[plr] = nil
    end
    if not S.ESP.Chams then return end
    for _, e in ipairs(enemies) do
        if e.Character then
            if S.ESP.ChamFill then
                local h = Instance.new("Highlight")
                h.Name = "MB_ChamFill"
                h.FillColor = S.ESP.FillColor
                h.FillTransparency = S.ESP.ChamFillTransparency
                h.OutlineTransparency = 1
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Adornee = e.Character
                h.Parent = e.Character
                EnemyChamsFill[e.Player] = h
            end
            if S.ESP.ChamOutline then
                local h = Instance.new("Highlight")
                h.Name = "MB_ChamOutline"
                h.FillTransparency = 1
                h.OutlineColor = S.ESP.Color
                h.OutlineTransparency = 0
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Adornee = e.Character
                h.Parent = e.Character
                EnemyChamsOutline[e.Player] = h
            end
        end
    end
end

local function UpdateESP()
    PoolBegin()
    if not S.ESP.Enabled then PoolEnd(); UpdateEnemyChams({}); return end
    local list = GetEnemies(S.ESP.MaxDistance)
    UpdateEnemyChams(list)

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

        if S.ESP.Box then
            Line(Vector2.new(x,y), Vector2.new(x+boxW,y), color, S.ESP.BoxThickness)
            Line(Vector2.new(x+boxW,y), Vector2.new(x+boxW,y+boxH), color, S.ESP.BoxThickness)
            Line(Vector2.new(x+boxW,y+boxH), Vector2.new(x,y+boxH), color, S.ESP.BoxThickness)
            Line(Vector2.new(x,y+boxH), Vector2.new(x,y), color, S.ESP.BoxThickness)
        end
        if S.ESP.CornerBox then
            local len = boxW * 0.25; local t = 2
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
        if S.ESP.Skeleton then DrawSkeleton(char, S.ESP.SkeletonColor, S.ESP.SkeletonThickness) end
        if S.ESP.HeadDot then
            local hs2, o2 = Camera:WorldToViewportPoint(head.Position)
            if o2 then Circle(Vector2.new(hs2.X,hs2.Y), S.ESP.HeadDotRadius, color, true) end
        end
        if S.ESP.Name then Text(plr.Name, Vector2.new(cx, y-15), color, 13) end
        if S.ESP.Health then Text(math.floor(hum.Health).."/"..math.floor(hum.MaxHealth), Vector2.new(cx, y+boxH+2), color, 11) end
        if S.ESP.Distance then Text("["..math.floor(e.Distance).."m]", Vector2.new(cx, y+boxH+16), color, 11) end
        if S.ESP.Weapon then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then Text(tool.Name, Vector2.new(cx, y+boxH+30), color, 11) end
        end
        if S.ESP.Tracer then
            local origin
            if S.ESP.TracerOrigin == "Bottom" then origin = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
            elseif S.ESP.TracerOrigin == "Top" then origin = Vector2.new(Camera.ViewportSize.X/2, 0)
            elseif S.ESP.TracerOrigin == "Mouse" then origin = UIS:GetMouseLocation()
            elseif S.ESP.TracerOrigin == "Center" then origin = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2) end
            if origin then Line(origin, Vector2.new(cx, y+boxH/2), S.ESP.TracerColor, S.ESP.TracerThickness, 0.9) end
        end
    end
    PoolEnd()
end

-- ===== AIMBOT =====
local function GetAimbotTarget(fovO, visC)
    local list = GetEnemies(nil)
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
    if not S.Aimbot.Enabled then FOVCircle.Visible=false return end
    FOVCircle.Visible = true
    FOVCircle.Radius = (S.Aimbot.FOV/100) * 500
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    FOVCircle.Color = S.Aimbot.FOVColor
end

local function FireWeapon()
    if mouse1click then mouse1click()
    elseif mouse1press and mouse1release then mouse1press(); task.wait(0.03); mouse1release()
    elseif VirtualUser then pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton1(Vector2.new(0,0)) end) end
end

local function AimbotStep()
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
    local list = GetEnemies(100)
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
            e.Name = "MB_WorldColor"
            e.Parent = Lighting
        end
        e.TintColor = S.World.ColorTint
        e.Saturation = S.World.Saturation
        e.Contrast = S.World.Contrast
        e.Brightness = S.World.Brightness
    else
        local e = Lighting:FindFirstChild("MB_WorldColor")
        if e then e:Destroy() end
    end
end

-- ===== LOCAL (Weapon Chams) =====
local function FindViewModel()
    for _, obj in ipairs(Camera:GetChildren()) do
        if obj:IsA("Model") then return obj end
    end
    return nil
end

local function UpdateLocal()
    local char = LP.Character
    if char and S.Local.WeaponChams then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local h = tool:FindFirstChild("MB_SelfChams")
                if not h then
                    h = Instance.new("Highlight")
                    h.Name = "MB_SelfChams"
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Adornee = tool
                    h.Parent = tool
                end
                h.FillTransparency = S.Local.SelfFill and 0 or 1
                h.OutlineTransparency = S.Local.SelfOutline and 0 or 1
                h.FillColor = S.Local.SelfColor
                h.OutlineColor = S.Local.SelfColor
            end
        end
    else
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    local h = tool:FindFirstChild("MB_SelfChams")
                    if h then h:Destroy() end
                end
            end
        end
    end
    local vm = FindViewModel()
    if vm and S.Local.WeaponChams then
        local h = vm:FindFirstChild("MB_VMChams")
        if not h then
            h = Instance.new("Highlight")
            h.Name = "MB_VMChams"
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Adornee = vm
            h.Parent = vm
        end
        h.FillTransparency = S.Local.SelfFill and 0.3 or 1
        h.OutlineTransparency = S.Local.SelfOutline and 0 or 1
        h.FillColor = S.Local.SelfColor
        h.OutlineColor = S.Local.SelfColor
    elseif vm then
        local h = vm:FindFirstChild("MB_VMChams")
        if h then h:Destroy() end
    end
end

-- ===== MOVEMENT =====
local SpeedConn = nil
local MovementHeartbeat = nil

local function EnableSpeedHook()
    local char = LP.Character
    if not char then return end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h then return end
    if SpeedConn then SpeedConn:Disconnect() end
    SpeedConn = h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if S.Movement.Speed and h.WalkSpeed ~= S.Movement.SpeedValue then
            h.WalkSpeed = S.Movement.SpeedValue
        end
    end)
end

local function SetupMovementHeartbeat()
    if MovementHeartbeat then MovementHeartbeat:Disconnect() end
    MovementHeartbeat = RunService.Heartbeat:Connect(function()
        local char = LP.Character
        if not char then return end
        local h = char:FindFirstChildOfClass("Humanoid")
        local r = char:FindFirstChild("HumanoidRootPart")
        if not h or not r then return end
        if S.Movement.Speed and h.WalkSpeed ~= S.Movement.SpeedValue then h.WalkSpeed = S.Movement.SpeedValue end
        if S.Movement.JumpPower then
            h.UseJumpPower = true
            if h.JumpPower ~= S.Movement.JumpValue then h.JumpPower = S.Movement.JumpValue end
        end
        if S.Movement.BunnyHop and UIS:IsKeyDown(Enum.KeyCode.Space) then h.Jump = true end
        if S.Movement.AutoStrafe and h:GetState() == Enum.HumanoidStateType.Freefall then
            local cl = Camera.CFrame.LookVector
            local fl = Vector3.new(cl.X, 0, cl.Z).Unit
            local v = r.Velocity
            local sp = math.sqrt(v.X^2 + v.Z^2)
            if sp > 1 then r.Velocity = fl * sp + Vector3.new(0, v.Y, 0) end
        end
    end)
end

SetupMovementHeartbeat()
LP.CharacterAdded:Connect(function() task.wait(0.5); EnableSpeedHook() end)
if LP.Character then EnableSpeedHook() end

-- ===== GUI =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MasterBAN_Sense"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

local DarkenOverlay = Instance.new("Frame")
DarkenOverlay.Name = "Darken"
DarkenOverlay.Size = UDim2.new(1, 0, 1, 0)
DarkenOverlay.Position = UDim2.new(0, 0, 0, 0)
DarkenOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
DarkenOverlay.BackgroundTransparency = 1
DarkenOverlay.BorderSizePixel = 0
DarkenOverlay.Visible = false
DarkenOverlay.ZIndex = 1
DarkenOverlay.Parent = ScreenGui

-- ===== COLOR PICKER =====
local OpenColorPicker = nil

local function CreateColorPicker(initialColor, onSave)
    if OpenColorPicker then OpenColorPicker:Destroy(); OpenColorPicker = nil end

    local picker = Instance.new("Frame")
    picker.Size = UDim2.new(0, 260, 0, 280)
    picker.Position = UDim2.new(0.5, -130, 0.5, -140)
    picker.BackgroundColor3 = CurrentBg
    picker.BorderSizePixel = 0
    picker.ZIndex = 500
    picker.Parent = ScreenGui
    OpenColorPicker = picker

    local pcorner = Instance.new("UICorner"); pcorner.CornerRadius = UDim.new(0,12); pcorner.Parent = picker
    local pstroke = Instance.new("UIStroke"); pstroke.Color = CurrentStroke; pstroke.Transparency = 0.5; pstroke.Parent = picker

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 28); title.BackgroundTransparency = 1
    title.Text = "Выбор цвета"; title.TextColor3 = CurrentText
    title.TextSize = 13; title.Font = Enum.Font.GothamBold; title.ZIndex = 501
    title.Parent = picker

    local h, s, v = initialColor:ToHSV()

    local svBox = Instance.new("Frame")
    svBox.Size = UDim2.new(1, -30, 0, 160); svBox.Position = UDim2.new(0, 15, 0, 35)
    svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1); svBox.BorderSizePixel = 0
    svBox.ZIndex = 501; svBox.Parent = picker
    local svCorner = Instance.new("UICorner"); svCorner.CornerRadius = UDim.new(0,8); svCorner.Parent = svBox

    local whiteGrad = Instance.new("Frame")
    whiteGrad.Size = UDim2.new(1, 0, 1, 0); whiteGrad.BackgroundColor3 = Color3.fromRGB(255,255,255)
    whiteGrad.BorderSizePixel = 0; whiteGrad.ZIndex = 502; whiteGrad.Parent = svBox
    local wgCorner = Instance.new("UICorner"); wgCorner.CornerRadius = UDim.new(0,8); wgCorner.Parent = whiteGrad
    local wgGrad = Instance.new("UIGradient")
    wgGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
    wgGrad.Parent = whiteGrad

    local blackGrad = Instance.new("Frame")
    blackGrad.Size = UDim2.new(1, 0, 1, 0); blackGrad.BackgroundColor3 = Color3.fromRGB(0,0,0)
    blackGrad.BorderSizePixel = 0; blackGrad.ZIndex = 503; blackGrad.Parent = svBox
    local bgCorner = Instance.new("UICorner"); bgCorner.CornerRadius = UDim.new(0,8); bgCorner.Parent = blackGrad
    local bgGrad = Instance.new("UIGradient")
    bgGrad.Rotation = 90
    bgGrad.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)})
    bgGrad.Parent = blackGrad

    local svMarker = Instance.new("Frame")
    svMarker.Size = UDim2.new(0, 10, 0, 10); svMarker.Position = UDim2.new(s, -5, 1-v, -5)
    svMarker.BackgroundColor3 = Color3.fromRGB(255,255,255); svMarker.BorderSizePixel = 0
    svMarker.ZIndex = 504; svMarker.Parent = svBox
    local smCorner = Instance.new("UICorner"); smCorner.CornerRadius = UDim.new(1,0); smCorner.Parent = svMarker
    local smStroke = Instance.new("UIStroke"); smStroke.Color = Color3.fromRGB(0,0,0); smStroke.Thickness = 1; smStroke.Parent = svMarker

    local hueBar = Instance.new("Frame")
    hueBar.Size = UDim2.new(1, -30, 0, 20); hueBar.Position = UDim2.new(0, 15, 0, 210)
    hueBar.BackgroundColor3 = Color3.fromRGB(255,255,255); hueBar.BorderSizePixel = 0
    hueBar.ZIndex = 501; hueBar.Parent = picker
    local hbCorner = Instance.new("UICorner"); hbCorner.CornerRadius = UDim.new(0,6); hbCorner.Parent = hueBar

    local hueGrad = Instance.new("UIGradient")
    local stops = {}
    for i = 0, 12 do
        table.insert(stops, ColorSequenceKeypoint.new(i/12, Color3.fromHSV(i/12, 1, 1)))
    end
    hueGrad.Color = ColorSequence.new(stops); hueGrad.Parent = hueBar

    local hueMarker = Instance.new("Frame")
    hueMarker.Size = UDim2.new(0, 6, 1.2, 0); hueMarker.Position = UDim2.new(h, -3, -0.1, 0)
    hueMarker.BackgroundColor3 = Color3.fromRGB(255,255,255); hueMarker.BorderSizePixel = 0
    hueMarker.ZIndex = 504; hueMarker.Parent = hueBar
    local hmCorner = Instance.new("UICorner"); hmCorner.CornerRadius = UDim.new(0,3); hmCorner.Parent = hueMarker
    local hmStroke = Instance.new("UIStroke"); hmStroke.Color = Color3.fromRGB(0,0,0); hmStroke.Thickness = 1; hmStroke.Parent = hueMarker

    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(0, 60, 0, 26); preview.Position = UDim2.new(0, 15, 0, 240)
    preview.BackgroundColor3 = initialColor; preview.BorderSizePixel = 0
    preview.ZIndex = 501; preview.Parent = picker
    local pvCorner = Instance.new("UICorner"); pvCorner.CornerRadius = UDim.new(0,6); pvCorner.Parent = preview
    local pvStroke = Instance.new("UIStroke"); pvStroke.Color = CurrentStroke; pvStroke.Transparency = 0.5; pvStroke.Parent = preview

    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0, 70, 0, 26); cancelBtn.Position = UDim2.new(1, -165, 0, 240)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(60,60,80); cancelBtn.BorderSizePixel = 0
    cancelBtn.Text = "Отмена"; cancelBtn.TextColor3 = Color3.fromRGB(255,255,255)
    cancelBtn.TextSize = 11; cancelBtn.Font = Enum.Font.Gotham
    cancelBtn.AutoButtonColor = false; cancelBtn.ZIndex = 501; cancelBtn.Parent = picker
    local cbCorner = Instance.new("UICorner"); cbCorner.CornerRadius = UDim.new(0,6); cbCorner.Parent = cancelBtn

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0, 70, 0, 26); saveBtn.Position = UDim2.new(1, -85, 0, 240)
    saveBtn.BackgroundColor3 = CurrentAccent; saveBtn.BorderSizePixel = 0
    saveBtn.Text = "ОК"; saveBtn.TextColor3 = Color3.fromRGB(255,255,255)
    saveBtn.TextSize = 11; saveBtn.Font = Enum.Font.GothamBold
    saveBtn.AutoButtonColor = false; saveBtn.ZIndex = 501; saveBtn.Parent = picker
    local sbCorner = Instance.new("UICorner"); sbCorner.CornerRadius = UDim.new(0,6); sbCorner.Parent = saveBtn

    local curH, curS, curV = h, s, v
    local function UpdatePreview()
        preview.BackgroundColor3 = Color3.fromHSV(curH, curS, curV)
        svBox.BackgroundColor3 = Color3.fromHSV(curH, 1, 1)
    end

    local svDrag = false
    svBox.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then svDrag = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then svDrag = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if svDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local rel = (i.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X
            local relY = (i.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y
            curS = math.clamp(rel, 0, 1)
            curV = math.clamp(1 - relY, 0, 1)
            svMarker.Position = UDim2.new(curS, -5, 1-curV, -5)
            UpdatePreview()
        end
    end)

    local hDrag = false
    hueBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then hDrag = true end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then hDrag = false end
    end)
    UIS.InputChanged:Connect(function(i)
        if hDrag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local rel = (i.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X
            curH = math.clamp(rel, 0, 1)
            hueMarker.Position = UDim2.new(curH, -3, -0.1, 0)
            UpdatePreview()
        end
    end)

    cancelBtn.MouseButton1Click:Connect(function() picker:Destroy(); OpenColorPicker = nil end)
    saveBtn.MouseButton1Click:Connect(function()
        onSave(Color3.fromHSV(curH, curS, curV))
        picker:Destroy(); OpenColorPicker = nil
    end)
end

-- ===== WATERMARK =====
local Watermark = Instance.new("Frame")
Watermark.Size = UDim2.new(0, 520, 0, 38)
Watermark.Position = UDim2.new(0.5, -260, 0, 12)
Watermark.BackgroundColor3 = CurrentBg
Watermark.BackgroundTransparency = 0.45
Watermark.BorderSizePixel = 0
Watermark.Visible = false
Watermark.ZIndex = 100
Watermark.Parent = ScreenGui
local wmc = Instance.new("UICorner"); wmc.CornerRadius = UDim.new(0,19); wmc.Parent = Watermark
local wms = Instance.new("UIStroke"); wms.Color = CurrentStroke; wms.Transparency = 0.75; wms.Parent = Watermark
local WmText = Instance.new("TextLabel")
WmText.Size = UDim2.new(1,-20,1,0); WmText.Position = UDim2.new(0,10,0,0)
WmText.BackgroundTransparency = 1
WmText.Text = "MasterBAN-Sense   |   TG: @MewNenti   |   FPS: 0   |   " .. LP.Name
WmText.TextColor3 = CurrentText; WmText.TextSize = 14; WmText.Font = Enum.Font.GothamBold
WmText.TextXAlignment = Enum.TextXAlignment.Center
WmText.Parent = Watermark

local function ApplyWatermarkStyle()
    Watermark.BackgroundColor3 = CurrentBg
    Watermark.BackgroundTransparency = (S.Menu.Glass and 0.45 or 0.05)
    wms.Color = CurrentStroke
    wms.Transparency = (S.Menu.Glass and 0.75 or 0.1)
    WmText.TextColor3 = CurrentText
end

local function ApplyWatermarkPos()
    local pos = S.Menu.WatermarkPos
    if pos == "TopCenter" then Watermark.Position = UDim2.new(0.5, -260, 0, 12)
    elseif pos == "TopLeft" then Watermark.Position = UDim2.new(0, 12, 0, 12)
    elseif pos == "TopRight" then Watermark.Position = UDim2.new(1, -532, 0, 12)
    elseif pos == "BottomCenter" then Watermark.Position = UDim2.new(0.5, -260, 1, -50)
    elseif pos == "BottomLeft" then Watermark.Position = UDim2.new(0, 12, 1, -50)
    elseif pos == "BottomRight" then Watermark.Position = UDim2.new(1, -532, 1, -50)
    end
end

-- ===== OPEN BUTTON =====
local OpenButton = Instance.new("TextButton")
OpenButton.Size = UDim2.new(0, 70, 0, 70)
OpenButton.Position = UDim2.new(0.05, 0, 0.5, 0)
OpenButton.BackgroundColor3 = CurrentBg
OpenButton.BackgroundTransparency = 0.15
OpenButton.BorderSizePixel = 0
OpenButton.Text = "M"; OpenButton.TextColor3 = CurrentText; OpenButton.TextSize = 26
OpenButton.Font = Enum.Font.GothamBold; OpenButton.AutoButtonColor = false
OpenButton.Visible = false
OpenButton.ZIndex = 100
OpenButton.Parent = ScreenGui
local oc = Instance.new("UICorner"); oc.CornerRadius = UDim.new(1,0); oc.Parent = OpenButton
local os2 = Instance.new("UIStroke"); os2.Color = CurrentAccent; os2.Transparency = 0.4; os2.Thickness = 2; os2.Parent = OpenButton

local obGrad = Instance.new("UIGradient")
obGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 255)),
    ColorSequenceKeypoint.new(0.5, CurrentAccent),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 200, 255)),
})
obGrad.Rotation = 45
obGrad.Parent = os2

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        obGrad.Rotation = (obGrad.Rotation + 2) % 360
    end
end)

OpenButton.MouseEnter:Connect(function()
    TS:Create(OpenButton, TweenInfo.new(0.25), {Size = UDim2.new(0, 78, 0, 78), BackgroundTransparency = 0.05}):Play()
end)
OpenButton.MouseLeave:Connect(function()
    TS:Create(OpenButton, TweenInfo.new(0.25), {Size = UDim2.new(0, 70, 0, 70), BackgroundTransparency = 0.15}):Play()
end)

-- ===== MAIN MENU =====
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 620, 0, 500)
Main.Position = UDim2.new(0.5, -310, 0.5, -250)
Main.BackgroundColor3 = CurrentBg
Main.BackgroundTransparency = 0.45
Main.BorderSizePixel = 0
Main.Visible = false
Main.ClipsDescendants = true
Main.ZIndex = 50
Main.Parent = ScreenGui
local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0,22); mc.Parent = Main
local ms = Instance.new("UIStroke"); ms.Color = CurrentStroke; ms.Transparency = 0.85; ms.Parent = Main

local Title = Instance.new("Frame")
Title.Size = UDim2.new(1,0,0,42); Title.BackgroundTransparency = 1; Title.ZIndex = 51; Title.Parent = Main
local TText = Instance.new("TextLabel")
TText.Size = UDim2.new(1,-30,1,0); TText.Position = UDim2.new(0,20,0,0); TText.BackgroundTransparency = 1
TText.Text = "MasterBAN-Sense   ·   INS to toggle"; TText.TextColor3 = CurrentText; TText.TextSize = 15
TText.Font = Enum.Font.GothamBold; TText.TextXAlignment = Enum.TextXAlignment.Left
TText.ZIndex = 51; TText.Parent = Title

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0,14,0,14); CloseBtn.Position = UDim2.new(1,-48,0,14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255,95,86); CloseBtn.BorderSizePixel = 0
CloseBtn.Text = ""; CloseBtn.AutoButtonColor = false; CloseBtn.ZIndex = 51; CloseBtn.Parent = Title
local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(1,0); cbc.Parent = CloseBtn

local TabPanel = Instance.new("Frame")
TabPanel.Size = UDim2.new(0,130,1,-60); TabPanel.Position = UDim2.new(0,12,0,50)
TabPanel.BackgroundColor3 = Color3.fromRGB(255,255,255)
TabPanel.BackgroundTransparency = 0.94; TabPanel.BorderSizePixel = 0
TabPanel.ZIndex = 51; TabPanel.Parent = Main
local tpc = Instance.new("UICorner"); tpc.CornerRadius = UDim.new(0,16); tpc.Parent = TabPanel

local SettingsPanel = Instance.new("Frame")
SettingsPanel.Size = UDim2.new(1,-160,1,-60); SettingsPanel.Position = UDim2.new(0,150,0,50)
SettingsPanel.BackgroundColor3 = Color3.fromRGB(255,255,255)
SettingsPanel.BackgroundTransparency = 0.94; SettingsPanel.BorderSizePixel = 0
SettingsPanel.ClipsDescendants = true; SettingsPanel.ZIndex = 51; SettingsPanel.Parent = Main
local spc = Instance.new("UICorner"); spc.CornerRadius = UDim.new(0,16); spc.Parent = SettingsPanel

local tabButtons = {}
local tabContents = {}

local function CreateTab(name, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-12,0,26); b.Position = UDim2.new(0,6,0,y)
    b.BackgroundColor3 = Color3.fromRGB(255,255,255); b.BackgroundTransparency = 1
    b.BorderSizePixel = 0; b.Text = name; b.TextColor3 = Color3.fromRGB(80,80,100)
    b.TextSize = 10; b.Font = Enum.Font.GothamBold; b.AutoButtonColor = false
    b.ZIndex = 52; b.Parent = TabPanel
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = b
    tabButtons[name] = b
end

local function CreateContent(name)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,0,1,0); f.Position = UDim2.new(0,0,0,0)
    f.BackgroundTransparency = 1; f.Visible = false; f.ClipsDescendants = true
    f.ZIndex = 52; f.Parent = SettingsPanel
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
            TS:Create(tabButtons[tn], TweenInfo.new(0.25), {BackgroundTransparency=0.2, BackgroundColor3=CurrentAccent, TextColor3=Color3.fromRGB(255,255,255)}):Play()
        else
            c.Visible = false
            TS:Create(tabButtons[tn], TweenInfo.new(0.25), {BackgroundTransparency=1, BackgroundColor3=Color3.fromRGB(255,255,255), TextColor3=Color3.fromRGB(80,80,100)}):Play()
        end
    end
end

local function MakeToggle(parent, text, y, getter, setter, ownerToggle)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-24,0,30); b.Position = UDim2.new(0,12,0,y)
    b.BackgroundColor3 = getter() and CurrentAccent or Color3.fromRGB(60,60,80)
    b.BackgroundTransparency = getter() and 0.1 or 0.5
    b.BorderSizePixel = 0; b.Text = "  " .. text; b.TextColor3 = Color3.fromRGB(255,255,255)
    b.TextSize = 12; b.Font = Enum.Font.Gotham; b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false; b.ZIndex = 53; b.Parent = parent
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = b
    local d = Instance.new("Frame")
    d.Size = UDim2.new(0,8,0,8); d.Position = UDim2.new(1,-18,0.5,-4)
    d.BackgroundColor3 = getter() and Color3.fromRGB(120,255,180) or Color3.fromRGB(120,120,140)
    d.BorderSizePixel = 0; d.ZIndex = 53; d.Parent = b
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1,0); dc.Parent = d

    local hov = false
    b.MouseEnter:Connect(function() hov = true TS:Create(b, TweenInfo.new(0.2), {BackgroundTransparency=getter() and 0 or 0.35}):Play() end)
    b.MouseLeave:Connect(function() hov = false TS:Create(b, TweenInfo.new(0.2), {BackgroundTransparency=getter() and 0.1 or 0.5}):Play() end)
    b.MouseButton1Click:Connect(function()
        setter(not getter())
        local v = getter()
        TS:Create(b, TweenInfo.new(0.25), {BackgroundColor3 = v and CurrentAccent or Color3.fromRGB(60,60,80), BackgroundTransparency = v and (hov and 0 or 0.1) or (hov and 0.35 or 0.5)}):Play()
        TS:Create(d, TweenInfo.new(0.25), {BackgroundColor3 = v and Color3.fromRGB(120,255,180) or Color3.fromRGB(120,120,140)}):Play()
        if RefreshVisibility then RefreshVisibility() end
    end)

    if ownerToggle then
        if not toggleRows[ownerToggle] then toggleRows[ownerToggle] = {} end
        table.insert(toggleRows[ownerToggle], b)
        b.Visible = false
    end
    return b
end

local function MakeSlider(parent, text, y, mn, mx, getter, setter, ownerToggle)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-24,0,44); f.Position = UDim2.new(0,12,0,y)
    f.BackgroundTransparency = 1; f.ZIndex = 53; f.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,0,0,16); l.BackgroundTransparency = 1
    l.Text = text .. ":  " .. getter(); l.TextColor3 = Color3.fromRGB(200,200,220)
    l.TextSize = 11; l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 53; l.Parent = f
    local tr = Instance.new("TextButton")
    tr.Size = UDim2.new(1,0,0,8); tr.Position = UDim2.new(0,0,0,24)
    tr.BackgroundColor3 = Color3.fromRGB(255,255,255); tr.BackgroundTransparency = 0.8
    tr.BorderSizePixel = 0; tr.Text = ""; tr.AutoButtonColor = false; tr.ZIndex = 53; tr.Parent = f
    local trc = Instance.new("UICorner"); trc.CornerRadius = UDim.new(1,0); trc.Parent = tr
    local fl = Instance.new("Frame")
    fl.Size = UDim2.new((getter()-mn)/(mx-mn),0,1,0)
    fl.BackgroundColor3 = CurrentAccent; fl.BorderSizePixel = 0; fl.ZIndex = 53; fl.Parent = tr
    local flc = Instance.new("UICorner"); flc.CornerRadius = UDim.new(1,0); flc.Parent = fl
    local kn = Instance.new("Frame")
    kn.Size = UDim2.new(0,14,0,14); kn.Position = UDim2.new(fl.Size.X.Scale,-7,0.5,-7)
    kn.BackgroundColor3 = Color3.fromRGB(255,255,255); kn.BorderSizePixel = 0; kn.ZIndex = 53; kn.Parent = tr
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
    if ownerToggle then
        if not toggleRows[ownerToggle] then toggleRows[ownerToggle] = {} end
        table.insert(toggleRows[ownerToggle], f)
        f.Visible = false
    end
end

local function MakeColor(parent, text, y, getter, setter, ownerToggle)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-24,0,36); f.Position = UDim2.new(0,12,0,y)
    f.BackgroundTransparency = 1; f.ZIndex = 53; f.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0,130,1,0); l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = Color3.fromRGB(200,200,220); l.TextSize = 11
    l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 53; l.Parent = f
    local cb = Instance.new("TextButton")
    cb.Size = UDim2.new(0,70,0,26); cb.Position = UDim2.new(0,140,0,5)
    cb.BackgroundColor3 = getter(); cb.Text = ""; cb.BorderSizePixel = 0
    cb.AutoButtonColor = false; cb.ZIndex = 53; cb.Parent = f
    local cbc2 = Instance.new("UICorner"); cbc2.CornerRadius = UDim.new(0,8); cbc2.Parent = cb
    cb.MouseButton1Click:Connect(function()
        CreateColorPicker(getter(), function(newColor)
            setter(newColor)
            cb.BackgroundColor3 = newColor
        end)
    end)
    if ownerToggle then
        if not toggleRows[ownerToggle] then toggleRows[ownerToggle] = {} end
        table.insert(toggleRows[ownerToggle], f)
        f.Visible = false
    end
end

local function MakeDropdown(parent, text, y, options, getter, setter, ownerToggle)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1,-24,0,36); f.Position = UDim2.new(0,12,0,y)
    f.BackgroundTransparency = 1; f.ZIndex = 53; f.Parent = parent
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0,100,1,0); l.BackgroundTransparency = 1
    l.Text = text; l.TextColor3 = Color3.fromRGB(200,200,220); l.TextSize = 11
    l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 53; l.Parent = f
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0,200,0,26); b.Position = UDim2.new(0,110,0,5)
    b.BackgroundColor3 = Color3.fromRGB(255,255,255); b.BackgroundTransparency = 0.85
    b.BorderSizePixel = 0; b.Text = getter(); b.TextColor3 = Color3.fromRGB(50,50,70)
    b.TextSize = 11; b.Font = Enum.Font.Gotham; b.AutoButtonColor = false
    b.ZIndex = 53; b.Parent = f
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,8); bc.Parent = b
    b.MouseButton1Click:Connect(function()
        local cur = getter()
        local i = table.find(options, cur) or 1
        local ni = i % #options + 1
        setter(options[ni]); b.Text = getter()
    end)
    if ownerToggle then
        if not toggleRows[ownerToggle] then toggleRows[ownerToggle] = {} end
        table.insert(toggleRows[ownerToggle], f)
        f.Visible = false
    end
end

local function NewScroll(parent)
    local sc = Instance.new("ScrollingFrame")
    sc.Size = UDim2.new(1,0,1,0); sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0; sc.ScrollBarThickness = 6
    sc.ScrollBarImageColor3 = CurrentAccent; sc.ScrollBarImageTransparency = 0.2
    sc.CanvasSize = UDim2.new(0,0,0,0)
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.ScrollingDirection = Enum.ScrollingDirection.Y
    sc.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
    sc.ZIndex = 53; sc.Parent = parent
    return sc
end

RefreshVisibility = function()
    if toggleRows["ESP"] then for _, o in ipairs(toggleRows["ESP"]) do o.Visible = S.ESP.Enabled end end
    if toggleRows["Aimbot"] then for _, o in ipairs(toggleRows["Aimbot"]) do o.Visible = S.Aimbot.Enabled end end
    if toggleRows["Trigger"] then for _, o in ipairs(toggleRows["Trigger"]) do o.Visible = S.Trigger.Enabled end end
    if toggleRows["WorldColor"] then for _, o in ipairs(toggleRows["WorldColor"]) do o.Visible = S.World.ColorEnabled end end
    if toggleRows["WeaponChams"] then for _, o in ipairs(toggleRows["WeaponChams"]) do o.Visible = S.Local.WeaponChams end end
    if toggleRows["Speed"] then for _, o in ipairs(toggleRows["Speed"]) do o.Visible = S.Movement.Speed end end
    if toggleRows["JumpPower"] then for _, o in ipairs(toggleRows["JumpPower"]) do o.Visible = S.Movement.JumpPower end end
end

CreateTab("ESP", 6)
CreateTab("AIM", 36)
CreateTab("WEAPON", 66)
CreateTab("WORLD", 96)
CreateTab("LOCAL", 126)
CreateTab("MOVEMENT", 156)
CreateTab("MENU", 186)

-- ESP TAB
CreateContent("ESP")
local espScroll = NewScroll(tabContents["ESP"])
MakeToggle(espScroll, "ESP", 10, function() return S.ESP.Enabled end, function(v) S.ESP.Enabled=v end)
MakeToggle(espScroll, "Box", 48, function() return S.ESP.Box end, function(v) S.ESP.Box=v end, "ESP")
MakeToggle(espScroll, "Corner Box", 86, function() return S.ESP.CornerBox end, function(v) S.ESP.CornerBox=v end, "ESP")
MakeToggle(espScroll, "Filled Box", 124, function() return S.ESP.FilledBox end, function(v) S.ESP.FilledBox=v end, "ESP")
MakeSlider(espScroll, "Fill Transparency", 162, 0, 100, function() return math.floor(S.ESP.FilledTransparency*100) end, function(v) S.ESP.FilledTransparency=v/100 end, "ESP")
MakeSlider(espScroll, "Box Thickness x10", 212, 5, 40, function() return math.floor(S.ESP.BoxThickness*10) end, function(v) S.ESP.BoxThickness=v/10 end, "ESP")
MakeToggle(espScroll, "Chams", 262, function() return S.ESP.Chams end, function(v) S.ESP.Chams=v end, "ESP")
MakeToggle(espScroll, "Cham Fill", 300, function() return S.ESP.ChamFill end, function(v) S.ESP.ChamFill=v end, "ESP")
MakeToggle(espScroll, "Cham Outline", 338, function() return S.ESP.ChamOutline end, function(v) S.ESP.ChamOutline=v end, "ESP")
MakeColor(espScroll, "Fill Color", 376, function() return S.ESP.FillColor end, function(v) S.ESP.FillColor=v end, "ESP")
MakeSlider(espScroll, "Cham Fill Transp", 420, 0, 100, function() return math.floor(S.ESP.ChamFillTransparency*100) end, function(v) S.ESP.ChamFillTransparency=v/100 end, "ESP")
MakeToggle(espScroll, "Skeleton", 470, function() return S.ESP.Skeleton end, function(v) S.ESP.Skeleton=v end, "ESP")
MakeColor(espScroll, "Skeleton Color", 508, function() return S.ESP.SkeletonColor end, function(v) S.ESP.SkeletonColor=v end, "ESP")
MakeSlider(espScroll, "Skeleton Thickness x10", 552, 5, 40, function() return math.floor(S.ESP.SkeletonThickness*10) end, function(v) S.ESP.SkeletonThickness=v/10 end, "ESP")
MakeToggle(espScroll, "Head Dot", 602, function() return S.ESP.HeadDot end, function(v) S.ESP.HeadDot=v end, "ESP")
MakeSlider(espScroll, "Head Dot Radius", 640, 1, 15, function() return S.ESP.HeadDotRadius end, function(v) S.ESP.HeadDotRadius=v end, "ESP")
MakeToggle(espScroll, "Name", 690, function() return S.ESP.Name end, function(v) S.ESP.Name=v end, "ESP")
MakeToggle(espScroll, "Health", 728, function() return S.ESP.Health end, function(v) S.ESP.Health=v end, "ESP")
MakeToggle(espScroll, "Distance", 766, function() return S.ESP.Distance end, function(v) S.ESP.Distance=v end, "ESP")
MakeToggle(espScroll, "Weapon", 804, function() return S.ESP.Weapon end, function(v) S.ESP.Weapon=v end, "ESP")
MakeToggle(espScroll, "Tracer", 842, function() return S.ESP.Tracer end, function(v) S.ESP.Tracer=v end, "ESP")
MakeColor(espScroll, "Tracer Color", 880, function() return S.ESP.TracerColor end, function(v) S.ESP.TracerColor=v end, "ESP")
MakeSlider(espScroll, "Tracer Thickness x10", 924, 5, 40, function() return math.floor(S.ESP.TracerThickness*10) end, function(v) S.ESP.TracerThickness=v/10 end, "ESP")
MakeDropdown(espScroll, "Tracer Origin", 974, {"Bottom", "Top", "Mouse", "Center"}, function() return S.ESP.TracerOrigin end, function(v) S.ESP.TracerOrigin=v end, "ESP")
MakeColor(espScroll, "ESP Color", 1014, function() return S.ESP.Color end, function(v) S.ESP.Color=v end, "ESP")
MakeToggle(espScroll, "Ignore AFK Players", 1058, function() return S.ESP.IgnoreAFK end, function(v) S.ESP.IgnoreAFK=v end, "ESP")
MakeSlider(espScroll, "AFK Seconds", 1096, 1, 15, function() return S.ESP.AFKSeconds end, function(v) S.ESP.AFKSeconds=v; AFKSeconds=v end, "ESP")
MakeSlider(espScroll, "Max Distance", 1146, 50, 3000, function() return S.ESP.MaxDistance end, function(v) S.ESP.MaxDistance=v end, "ESP")

-- AIM
CreateContent("AIM")
local aimTab = tabContents["AIM"]
MakeToggle(aimTab, "Aimbot", 10, function() return S.Aimbot.Enabled end, function(v) S.Aimbot.Enabled=v end)
MakeToggle(aimTab, "Visible Check", 48, function() return S.Aimbot.VisibleCheck end, function(v) S.Aimbot.VisibleCheck=v end, "Aimbot")
MakeSlider(aimTab, "FOV", 86, 1, 100, function() return S.Aimbot.FOV end, function(v) S.Aimbot.FOV=v end, "Aimbot")
MakeColor(aimTab, "FOV Color", 136, function() return S.Aimbot.FOVColor end, function(v) S.Aimbot.FOVColor=v end, "Aimbot")
MakeSlider(aimTab, "Smooth x100", 180, 1, 50, function() return math.floor(S.Aimbot.Smoothness*100) end, function(v) S.Aimbot.Smoothness=v/100 end, "Aimbot")

-- WEAPON (только TriggerBot, Hitbox убран)
CreateContent("WEAPON")
local wTab = tabContents["WEAPON"]
MakeToggle(wTab, "TriggerBot", 10, function() return S.Trigger.Enabled end, function(v) S.Trigger.Enabled=v end)
MakeSlider(wTab, "Trigger Delay x10ms", 48, 1, 20, function() return math.floor(S.Trigger.Delay*10) end, function(v) S.Trigger.Delay=v/10 end, "Trigger")

-- WORLD
CreateContent("WORLD")
local wWorld = tabContents["WORLD"]
MakeToggle(wWorld, "World Color", 10, function() return S.World.ColorEnabled end, function(v) S.World.ColorEnabled=v end)
MakeColor(wWorld, "World Tint", 48, function() return S.World.ColorTint end, function(v) S.World.ColorTint=v end, "WorldColor")
MakeSlider(wWorld, "Saturation x100", 92, -100, 100, function() return math.floor(S.World.Saturation*100) end, function(v) S.World.Saturation=v/100 end, "WorldColor")
MakeSlider(wWorld, "Contrast x100", 142, -100, 100, function() return math.floor(S.World.Contrast*100) end, function(v) S.World.Contrast=v/100 end, "WorldColor")
MakeSlider(wWorld, "Brightness x100", 192, -100, 100, function() return math.floor(S.World.Brightness*100) end, function(v) S.World.Brightness=v/100 end, "WorldColor")

-- LOCAL
CreateContent("LOCAL")
local lTab = tabContents["LOCAL"]
MakeToggle(lTab, "Weapon Chams", 10, function() return S.Local.WeaponChams end, function(v) S.Local.WeaponChams=v end)
MakeColor(lTab, "Color", 48, function() return S.Local.SelfColor end, function(v) S.Local.SelfColor=v end, "WeaponChams")
MakeToggle(lTab, "Fill", 92, function() return S.Local.SelfFill end, function(v) S.Local.SelfFill=v end, "WeaponChams")
MakeToggle(lTab, "Outline", 130, function() return S.Local.SelfOutline end, function(v) S.Local.SelfOutline=v end, "WeaponChams")

-- MOVEMENT
CreateContent("MOVEMENT")
local mTab = tabContents["MOVEMENT"]
MakeToggle(mTab, "BunnyHop", 10, function() return S.Movement.BunnyHop end, function(v) S.Movement.BunnyHop=v end)
MakeToggle(mTab, "Auto Strafe", 48, function() return S.Movement.AutoStrafe end, function(v) S.Movement.AutoStrafe=v end)
MakeToggle(mTab, "Speed", 86, function() return S.Movement.Speed end, function(v) S.Movement.Speed=v; if v then EnableSpeedHook() end end)
MakeSlider(mTab, "Speed Value", 124, 16, 200, function() return S.Movement.SpeedValue end, function(v) S.Movement.SpeedValue=v end, "Speed")
MakeToggle(mTab, "Jump Power", 174, function() return S.Movement.JumpPower end, function(v) S.Movement.JumpPower=v end)
MakeSlider(mTab, "Jump Value", 212, 50, 500, function() return S.Movement.JumpValue end, function(v) S.Movement.JumpValue=v end, "JumpPower")

-- MENU
CreateContent("MENU")
local menuTab = tabContents["MENU"]
MakeToggle(menuTab, "Liquid Glass", 10, function() return S.Menu.Glass end, function(v)
    S.Menu.Glass = v
    if v then
        Main.BackgroundTransparency = 0.45
        ms.Transparency = 0.85
    else
        Main.BackgroundTransparency = 0.05
        ms.Transparency = 0.1
    end
    ApplyWatermarkStyle()
end)
MakeToggle(menuTab, "Darken Background", 48, function() return S.Menu.ShowDarken end, function(v) S.Menu.ShowDarken=v end)
MakeSlider(menuTab, "Darken Amount x100", 86, 0, 100, function() return math.floor(S.Menu.DarkenAmount*100) end, function(v) S.Menu.DarkenAmount=v/100 end)
MakeColor(menuTab, "Accent Color", 136, function() return S.Menu.AccentColor end, function(v)
    S.Menu.AccentColor = v; CurrentAccent = v
    TabPanel.BackgroundColor3 = v; SettingsPanel.BackgroundColor3 = v
    os2.Color = v
end)
MakeColor(menuTab, "Background Color", 172, function() return S.Menu.BgColor end, function(v)
    S.Menu.BgColor = v; CurrentBg = v
    Main.BackgroundColor3 = v; Watermark.BackgroundColor3 = v
    OpenButton.BackgroundColor3 = v
end)
MakeColor(menuTab, "Stroke Color", 208, function() return S.Menu.StrokeColor end, function(v)
    S.Menu.StrokeColor = v; CurrentStroke = v
    ms.Color = v; wms.Color = v; os2.Color = v
end)
MakeColor(menuTab, "Text Color", 244, function() return S.Menu.TextColor end, function(v)
    S.Menu.TextColor = v; CurrentText = v
    TText.TextColor3 = v; WmText.TextColor3 = v; OpenButton.TextColor3 = v
end)
MakeDropdown(menuTab, "Watermark Pos", 280, {"TopCenter", "TopLeft", "TopRight", "BottomCenter", "BottomLeft", "BottomRight"}, function() return S.Menu.WatermarkPos end, function(v)
    S.Menu.WatermarkPos = v; ApplyWatermarkPos()
end)

SwitchTab("ESP")
RefreshVisibility()

-- ===== OPEN/CLOSE =====
local isOpen = false
local isAnim = false

local function ShowCursor()
    pcall(function()
        UIS.MouseIconEnabled = true
        UIS.MouseBehavior = Enum.MouseBehavior.Default
    end)
end

local function OpenMenu()
    if isOpen or isAnim then return end
    isOpen = true; isAnim = true
    ShowCursor()
    if S.Menu.ShowDarken then
        DarkenOverlay.Visible = true
        DarkenOverlay.BackgroundTransparency = 1
        TS:Create(DarkenOverlay, TweenInfo.new(0.4), {BackgroundTransparency = S.Menu.DarkenAmount}):Play()
    end
    OpenButton.Visible = false
    Main.Visible = true
    Main.BackgroundTransparency = 1
    ms.Transparency = 1
    Main.Position = UDim2.new(0.5, -310, 0.5, -240)
    local info = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    TS:Create(Main, info, {BackgroundTransparency=(S.Menu.Glass and 0.45 or 0.05), Position=UDim2.new(0.5,-310,0.5,-250)}):Play()
    TS:Create(ms, info, {Transparency=(S.Menu.Glass and 0.85 or 0.1)}):Play()
    task.delay(0.4, function() isAnim = false end)
end

local function CloseMenu()
    if not isOpen or isAnim then return end
    isOpen = false; isAnim = true
    if S.Menu.ShowDarken then
        TS:Create(DarkenOverlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    end
    local info = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
    TS:Create(Main, info, {BackgroundTransparency=1, Position=UDim2.new(0.5,-310,0.5,-240), Size=UDim2.new(0,600,0,480)}):Play()
    TS:Create(ms, info, {Transparency=1}):Play()
    task.delay(0.35, function()
        Main.Visible = false
        Main.Size = UDim2.new(0,620,0,500)
        Main.Position = UDim2.new(0.5,-310,0.5,-250)
        if S.Menu.ShowDarken then DarkenOverlay.Visible = false end
        OpenButton.Visible = true
        isAnim = false
    end)
end

OpenButton.MouseButton1Click:Connect(function() if isOpen then CloseMenu() else OpenMenu() end end)
CloseBtn.MouseButton1Click:Connect(CloseMenu)

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        if isOpen then CloseMenu() else OpenMenu() end
    end
end)

task.spawn(function()
    while true do
        RunService.Heartbeat:Wait()
        if isOpen then
            pcall(function()
                UIS.MouseIconEnabled = true
                if UIS.MouseBehavior ~= Enum.MouseBehavior.Default then
                    UIS.MouseBehavior = Enum.MouseBehavior.Default
                end
            end)
        end
    end
end)

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
tabButtons["MENU"].MouseButton1Click:Connect(function() SwitchTab("MENU") end)

Players.PlayerRemoving:Connect(function(plr)
    LastPos[plr] = nil
    AFKTimer[plr] = nil
    if EnemyChamsFill[plr] then
        if EnemyChamsFill[plr].Parent then EnemyChamsFill[plr]:Destroy() end
        EnemyChamsFill[plr] = nil
    end
    if EnemyChamsOutline[plr] then
        if EnemyChamsOutline[plr].Parent then EnemyChamsOutline[plr]:Destroy() end
        EnemyChamsOutline[plr] = nil
    end
end)

-- ===== INTRO =====
local Mask = Instance.new("Frame")
Mask.Size = UDim2.new(0, 0, 1, 0); Mask.Position = UDim2.new(0, 0, 0, 0)
Mask.BackgroundColor3 = Color3.fromRGB(0, 0, 0); Mask.BackgroundTransparency = 0.1
Mask.BorderSizePixel = 0; Mask.ZIndex = 200; Mask.Parent = ScreenGui

local IntroContainer = Instance.new("Frame")
IntroContainer.Size = UDim2.new(1, 0, 0, 200); IntroContainer.Position = UDim2.new(0, 0, 0.5, -100)
IntroContainer.BackgroundTransparency = 1; IntroContainer.ZIndex = 201; IntroContainer.Parent = ScreenGui

local WordMaster = Instance.new("TextLabel")
WordMaster.Size = UDim2.new(1, 0, 0, 80); WordMaster.Position = UDim2.new(0, 0, 0, 0)
WordMaster.BackgroundTransparency = 1; WordMaster.Text = "Master"
WordMaster.TextColor3 = Color3.fromRGB(255, 255, 255); WordMaster.TextSize = 72
WordMaster.Font = Enum.Font.GothamBlack; WordMaster.TextTransparency = 1
WordMaster.ZIndex = 201; WordMaster.Parent = IntroContainer

local WordBAN = Instance.new("TextLabel")
WordBAN.Size = UDim2.new(1, 0, 0, 80); WordBAN.Position = UDim2.new(0, 0, 0, 60)
WordBAN.BackgroundTransparency = 1; WordBAN.Text = "BAN"
WordBAN.TextColor3 = Color3.fromRGB(180, 120, 255); WordBAN.TextSize = 72
WordBAN.Font = Enum.Font.GothamBlack; WordBAN.TextTransparency = 1
WordBAN.ZIndex = 201; WordBAN.Parent = IntroContainer

local WordSense = Instance.new("TextLabel")
WordSense.Size = UDim2.new(1, 0, 0, 80); WordSense.Position = UDim2.new(0, 0, 0, 120)
WordSense.BackgroundTransparency = 1; WordSense.Text = "Sense"
WordSense.TextColor3 = Color3.fromRGB(120, 90, 255); WordSense.TextSize = 72
WordSense.Font = Enum.Font.GothamBlack; WordSense.TextTransparency = 1
WordSense.ZIndex = 201; WordSense.Parent = IntroContainer

local ByText = Instance.new("TextLabel")
ByText.Size = UDim2.new(1, 0, 0, 120); ByText.Position = UDim2.new(0, 0, 0.15, 0)
ByText.BackgroundTransparency = 1; ByText.Text = "by MewNenti"
ByText.TextColor3 = Color3.fromRGB(255, 255, 255); ByText.TextSize = 60
ByText.Font = Enum.Font.GothamBlack; ByText.TextTransparency = 1
ByText.ZIndex = 202; ByText.Parent = ScreenGui

task.spawn(function()
    task.wait(0.1)
    TS:Create(Mask, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
    task.wait(0.7)
    TS:Create(WordMaster, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
    task.wait(0.25)
    TS:Create(WordBAN, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
    task.wait(0.25)
    TS:Create(WordSense, TweenInfo.new(0.4), {TextTransparency = 0}):Play()
    task.wait(1.2)
    local upInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
    TS:Create(WordMaster, upInfo, {Position = UDim2.new(0, 0, 0, -100), TextTransparency = 1}):Play()
    TS:Create(WordBAN, upInfo, {Position = UDim2.new(0, 0, 0, -40), TextTransparency = 1}):Play()
    TS:Create(WordSense, upInfo, {Position = UDim2.new(0, 0, 0, 20), TextTransparency = 1}):Play()
    task.wait(0.15)
    TS:Create(ByText, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
    task.wait(1.0)
    TS:Create(ByText, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(0, 0, -0.3, 0), TextTransparency = 1}):Play()
    TS:Create(Mask, TweenInfo.new(0.6, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Position = UDim2.new(0, 0, -1, 0), BackgroundTransparency = 1}):Play()
    task.wait(0.7)
    Watermark.Visible = true
    ApplyWatermarkPos()
    OpenButton.Visible = true
    OpenButton.Position = UDim2.new(-0.1, 0, 0.5, 0)
    TS:Create(OpenButton, TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0.05, 0, 0.5, 0)}):Play()
    task.wait(0.6)
    Mask:Destroy(); IntroContainer:Destroy(); ByText:Destroy()
end)

-- ===== MAIN LOOP =====
RunService.RenderStepped:Connect(function(dt)
    FrameCount = FrameCount + 1
    if os.clock() - LastFPSTime >= 1 then
        FPS = FrameCount; FrameCount = 0; LastFPSTime = os.clock()
        WmText.Text = "MasterBAN-Sense   |   TG: @MewNenti   |   FPS: " .. FPS .. "   |   " .. LP.Name
    end
    UpdateESP()
    UpdateFOV()
    UpdateTrigger()
    UpdateWorldColor()
    UpdateLocal()
    UpdateVisWatermark()
end)

print("[+] MasterBAN-Sense loaded!")
print("[+] Press INS to open menu")
print("[+] TG: @MewNenti")
