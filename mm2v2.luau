local plrs = game:GetService("Players")
local run = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local tws = game:GetService("TweenService")
local http = game:GetService("HttpService")
local cam = workspace.CurrentCamera
local lp = plrs.LocalPlayer

local cfgPath = "mm2cfg.json"
local cfg = {
    aimbot = false, autoclick = false,
    farming = false, flying = false, noclip = false,
    autopickup = false, esp = true, tracers = true,
    rainbowbeam = false, beamthick = 0.08,
    method = "MouseMoveRel", fov = 150, smooth = 0.18,
    flyspd = 140, maxdist = 250, farmcool = 0.9,
    jiggle = 0.7, walkspd = 40,
    beamr = 160, beamg = 32, beamb = 240,
    bhop = false, autokill = false, speedhax = false,
}

local function saveCfg()
    pcall(function() writefile(cfgPath, http:JSONEncode(cfg)) end)
end

local function loadCfg()
    local ok, res = pcall(function() return http:JSONDecode(readfile(cfgPath)) end)
    if ok and type(res) == "table" then
        for k, v in pairs(cfg) do
            if res[k] ~= nil then cfg[k] = res[k] end
        end
    end
end
loadCfg()

local hrp, hum, bv, bg
local lastclick = 0
local rbhue = 0
local bhopVel = 0

local function setupChar(char)
    hrp = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end
    bv = Instance.new("BodyVelocity")
    bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
    bv.MaxForce = Vector3.new(4e5, 4e5, 4e5)
    bhopVel = 0
end

lp.CharacterAdded:Connect(setupChar)
if lp.Character then setupChar(lp.Character) end

local roleColors = {
    murder = Color3.fromRGB(255, 60, 60),
    sheriff = Color3.fromRGB(60, 140, 255),
    inno = Color3.fromRGB(80, 255, 120),
}

local function getRole(p)
    if not p.Character then return "inno" end
    local bp = p:FindFirstChild("Backpack")
    local ch = p.Character
    if (bp and bp:FindFirstChild("Knife")) or (ch and ch:FindFirstChild("Knife")) then return "murder" end
    if (bp and bp:FindFirstChild("Gun")) or (ch and ch:FindFirstChild("Gun")) then return "sheriff" end
    return "inno"
end

local function roleColor(p) return roleColors[getRole(p)] end

local function getItem(p)
    if not p.Character then return "" end
    local bp = p:FindFirstChild("Backpack")
    local ch = p.Character
    if (bp and bp:FindFirstChild("Knife")) or (ch and ch:FindFirstChild("Knife")) then return "[knife]" end
    if (bp and bp:FindFirstChild("Gun")) or (ch and ch:FindFirstChild("Gun")) then return "[gun]" end
    return ""
end

local function hasGun()
    local ch = lp.Character
    local bp = lp:FindFirstChild("Backpack")
    return (ch and ch:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun"))
end

local function hasKnife()
    local ch = lp.Character
    local bp = lp:FindFirstChild("Backpack")
    return (ch and ch:FindFirstChild("Knife")) or (bp and bp:FindFirstChild("Knife"))
end

local function findNearestCoin()
    if not hrp then return nil end
    local coinnames = {"MainCoin", "CoinVisual", "Coin_Server"}
    local closest, dist = nil, math.huge
    for _, obj in workspace:GetDescendants() do
        for _, n in coinnames do
            if obj.Name == n and obj:IsA("BasePart") then
                local d = (hrp.Position - obj.Position).Magnitude
                if d < dist then dist = d closest = obj end
                break
            end
        end
    end
    return closest
end

local function getBeamColor()
    if cfg.rainbowbeam then return Color3.fromHSV(rbhue, 1, 1) end
    return Color3.fromRGB(cfg.beamr, cfg.beamg, cfg.beamb)
end

local function makeBeam(a, b)
    local bc = getBeamColor()
    local dist = (a - b).Magnitude
    local beam = Instance.new("Part")
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.Color = bc
    beam.Size = Vector3.new(cfg.beamthick, cfg.beamthick, dist)
    beam.CFrame = CFrame.new(a:Lerp(b, 0.5), b)
    beam.Parent = workspace
    local light = Instance.new("PointLight")
    light.Color = bc
    light.Brightness = 4
    light.Range = 10
    light.Parent = beam
    local t = tws:Create(beam, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
        Transparency = 1, Size = Vector3.new(0, 0, dist)
    })
    t:Play()
    t.Completed:Connect(function() beam:Destroy() end)
end

-- esp
local black = Color3.fromRGB(0, 0, 0)
local white = Color3.fromRGB(255, 255, 255)
local espLibraries = {}

local function newQuad(thickness, color)
    local q = Drawing.new("Quad")
    q.Visible = false
    q.PointA = Vector2.new(0,0)
    q.PointB = Vector2.new(0,0)
    q.PointC = Vector2.new(0,0)
    q.PointD = Vector2.new(0,0)
    q.Color = color
    q.Filled = false
    q.Thickness = thickness
    q.Transparency = 1
    return q
end

local function newLine(thickness, color)
    local l = Drawing.new("Line")
    l.Visible = false
    l.From = Vector2.new(0,0)
    l.To = Vector2.new(0,0)
    l.Color = color
    l.Thickness = thickness
    l.Transparency = 1
    return l
end

local function newText(size, color)
    local t = Drawing.new("Text")
    t.Visible = false
    t.Text = ""
    t.Size = size
    t.Color = color
    t.Outline = true
    t.OutlineColor = black
    t.Center = true
    t.Font = 2
    return t
end

local function setVis(state, lib)
    for _, x in pairs(lib) do x.Visible = state end
end

local function makeESP(p)
    if p == lp then return end
    local lib = {
        blacktracer = newLine(2, black),
        tracer = newLine(1, black),
        black = newQuad(2, black),
        box = newQuad(1, black),
        healthbar = newLine(3, black),
        greenhealth = newLine(1.5, black),
        name = newText(13, white),
        item = newText(11, white),
    }
    espLibraries[p] = lib

    coroutine.wrap(function()
        local conn
        conn = run.RenderStepped:Connect(function()
            if not cfg.esp then setVis(false, lib) return end

            local char = p.Character
            local phrp = char and char:FindFirstChild("HumanoidRootPart")
            local phead = char and char:FindFirstChild("Head")
            local phum = char and char:FindFirstChild("Humanoid")

            if char and phrp and phum and phum.Health > 0 and phead then
                local humPos, onScreen = cam:WorldToViewportPoint(phrp.Position)
                if onScreen then
                    local head = cam:WorldToViewportPoint(phead.Position)
                    local distY = math.clamp((Vector2.new(head.X, head.Y) - Vector2.new(humPos.X, humPos.Y)).Magnitude, 2, math.huge)
                    local rc = roleColor(p)

                    lib.box.Color = rc
                    lib.tracer.Color = rc

                    local function sizeQuad(item)
                        item.PointA = Vector2.new(humPos.X + distY, humPos.Y - distY*2)
                        item.PointB = Vector2.new(humPos.X - distY, humPos.Y - distY*2)
                        item.PointC = Vector2.new(humPos.X - distY, humPos.Y + distY*2)
                        item.PointD = Vector2.new(humPos.X + distY, humPos.Y + distY*2)
                    end
                    sizeQuad(lib.box)
                    sizeQuad(lib.black)

                    -- name tag above box
                    lib.name.Text = p.Name
                    lib.name.Color = white
                    lib.name.Position = Vector2.new(humPos.X, humPos.Y - distY*2 - 14)
                    lib.name.Visible = true

                    -- item tag below box
                    local item = getItem(p)
                    if item ~= "" then
                        lib.item.Text = item
                        lib.item.Color = rc
                        lib.item.Position = Vector2.new(humPos.X, humPos.Y + distY*2 + 3)
                        lib.item.Visible = true
                    else
                        lib.item.Visible = false
                    end

                    if cfg.tracers then
                        lib.tracer.From = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y)
                        lib.blacktracer.From = Vector2.new(cam.ViewportSize.X * 0.5, cam.ViewportSize.Y)
                        lib.tracer.To = Vector2.new(humPos.X, humPos.Y + distY*2)
                        lib.blacktracer.To = Vector2.new(humPos.X, humPos.Y + distY*2)
                        lib.tracer.Visible = true
                        lib.blacktracer.Visible = true
                    else
                        lib.tracer.Visible = false
                        lib.blacktracer.Visible = false
                    end

                    local d = (Vector2.new(humPos.X - distY, humPos.Y - distY*2) - Vector2.new(humPos.X - distY, humPos.Y + distY*2)).Magnitude
                    local healthOff = phum.Health / phum.MaxHealth * d
                    lib.greenhealth.Color = Color3.fromRGB(255,0,0):lerp(Color3.fromRGB(0,255,0), phum.Health / phum.MaxHealth)
                    lib.greenhealth.From = Vector2.new(humPos.X - distY - 4, humPos.Y + distY*2)
                    lib.greenhealth.To = Vector2.new(humPos.X - distY - 4, humPos.Y + distY*2 - healthOff)
                    lib.healthbar.From = Vector2.new(humPos.X - distY - 4, humPos.Y + distY*2)
                    lib.healthbar.To = Vector2.new(humPos.X - distY - 4, humPos.Y - distY*2)

                    lib.box.Visible = true
                    lib.black.Visible = true
                    lib.healthbar.Visible = true
                    lib.greenhealth.Visible = true
                else
                    setVis(false, lib)
                end
            else
                setVis(false, lib)
                if not plrs:FindFirstChild(p.Name) then conn:Disconnect() end
            end
        end)
    end)()
end

for _, p in plrs:GetPlayers() do makeESP(p) end
plrs.PlayerAdded:Connect(makeESP)

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.2
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Transparency = 0.5
fovCircle.Visible = false

local gunFolder = Instance.new("Folder")
gunFolder.Parent = game:GetService("CoreGui")

-- auto kill -- only targets inno and sheriff
task.spawn(function()
    while true do
        task.wait(0.15)
        if cfg.autokill and hasKnife() and hrp then
            for _, p in plrs:GetPlayers() do
                if p == lp then continue end
                local role = getRole(p)
                if role ~= "inno" and role ~= "sheriff" then continue end
                local char = p.Character
                local phrp = char and char:FindFirstChild("HumanoidRootPart")
                local phum = char and char:FindFirstChild("Humanoid")
                if phrp and phum and phum.Health > 0 then
                    local old = hrp.CFrame
                    hrp.CFrame = phrp.CFrame * CFrame.new(0, 0, -2)
                    task.wait(0.1)
                    hrp.CFrame = old
                    task.wait(0.05)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if cfg.autopickup then
            if hasGun() then
                cfg.autopickup = false
                gunFolder:ClearAllChildren()
            else
                gunFolder:ClearAllChildren()
                local drop = workspace:FindFirstChild("GunDrop", true)
                if drop and drop:IsA("BasePart") then
                    local box = Instance.new("BoxHandleAdornment")
                    box.Adornee = drop box.AlwaysOnTop = true
                    box.Color3 = Color3.fromRGB(255, 215, 0)
                    box.Size = drop.Size + Vector3.new(0.2, 0.2, 0.2)
                    box.Transparency = 0.3 box.Parent = gunFolder
                    local ch = lp.Character
                    local root = ch and ch:FindFirstChild("HumanoidRootPart")
                    local knife = ch and (ch:FindFirstChild("Knife") or lp.Backpack:FindFirstChild("Knife"))
                    if root and not knife then
                        local old = root.CFrame
                        root.CFrame = drop.CFrame
                        task.wait(0.2)
                        root.CFrame = old
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        if cfg.farming and hrp then
            local target = findNearestCoin()
            if target and target.Parent then
                local t = tws:Create(hrp, TweenInfo.new(cfg.farmcool, Enum.EasingStyle.Linear), {CFrame = target.CFrame})
                t:Play() t.Completed:Wait()
                if cfg.jiggle > 0 then
                    hrp.CFrame = target.CFrame * CFrame.new(0, cfg.jiggle, 0)
                    task.wait(0.05)
                end
            else task.wait(0.1) end
        else task.wait(0.2) end
    end
end)

local function connectGun()
    local char = lp.Character or lp.CharacterAdded:Wait()
    task.spawn(function()
        while char.Parent do
            local bp = lp:FindFirstChild("Backpack")
            local gun = char:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun"))
            if gun and not gun:GetAttribute("bc") then
                gun:SetAttribute("bc", true)
                gun.Activated:Connect(function()
                    local handle = gun:FindFirstChild("Handle")
                    if not handle then return end
                    for _, p in plrs:GetPlayers() do
                        if getRole(p) == "murder" and p.Character then
                            local mhrp = p.Character:FindFirstChild("HumanoidRootPart")
                            if mhrp then makeBeam(handle.Position, mhrp.Position) end
                        end
                    end
                end)
            end
            task.wait(0.5)
        end
    end)
end

lp.CharacterAdded:Connect(connectGun)
if lp.Character then connectGun() end

run.RenderStepped:Connect(function(dt)
    rbhue = (rbhue + dt * 0.4) % 1
    local mousePos = uis:GetMouseLocation()
    fovCircle.Position = mousePos
    fovCircle.Radius = cfg.fov
    fovCircle.Color = cfg.rainbowbeam and Color3.fromHSV(rbhue, 1, 1) or Color3.fromRGB(160, 32, 240)
    fovCircle.Visible = cfg.aimbot
    if not hrp or not hrp.Parent then return end

    if cfg.noclip and lp.Character then
        for _, p in lp.Character:GetDescendants() do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end

    if cfg.speedhax and hum then hum.WalkSpeed = cfg.walkspd end

    if cfg.bhop and hum and hrp then
        local state = hum:GetState()
        if state == Enum.HumanoidStateType.Freefall then
            bhopVel = math.min(bhopVel + dt * 40, 120)
        end
        if state == Enum.HumanoidStateType.Landed then
            local lookDir = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
            hrp.AssemblyLinearVelocity = lookDir.Unit * bhopVel + Vector3.new(0, 50, 0)
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        if state == Enum.HumanoidStateType.Running and bhopVel > 0 then
            bhopVel = math.max(bhopVel - dt * 20, 0)
        end
    else
        bhopVel = 0
    end

    if cfg.flying and bv and bg then
        local dir = Vector3.zero
        if uis:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        bv.Velocity = dir.Magnitude > 0 and dir.Unit * cfg.flyspd or Vector3.zero
        bg.CFrame = cam.CFrame
    end

    if cfg.aimbot then
        local target, shortest = nil, math.huge
        for _, p in plrs:GetPlayers() do
            if p ~= lp and p.Character and getRole(p) == "murder" then
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                if root and hrp then
                    local dist = (hrp.Position - root.Position).Magnitude
                    if dist <= cfg.maxdist then
                        local pos, onScreen = cam:WorldToViewportPoint(root.Position)
                        if onScreen then
                            local mag = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                            if mag < cfg.fov and mag < shortest then
                                shortest = mag target = root
                            end
                        end
                    end
                end
            end
        end
        if target then
            if cfg.autoclick and hasGun() and mouse1press then
                if tick() - lastclick >= 0.12 then
                    lastclick = tick()
                    mouse1press()
                    task.delay(0.05, function() if mouse1release then mouse1release() end end)
                end
            end
            if cfg.method == "CFrame" then
                cam.CFrame = CFrame.new(cam.CFrame.Position, target.Position)
            elseif cfg.method == "MouseMoveRel" and mousemoverel then
                local tpos = cam:WorldToViewportPoint(target.Position)
                mousemoverel((tpos.X - mousePos.X) * cfg.smooth, (tpos.Y - mousePos.Y) * cfg.smooth)
            end
        end
    end
end)

local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/IcantAffordSynapse/SimpleLib/refs/heads/main/SimpleLib.lua"))()
local win = lib:Window("mm2")
local combat = win:AddSection("Combat")
local movement = win:AddSection("Movement")
local visuals = win:AddSection("Visuals")
local fun = win:AddSection("Fun")

combat:Toggle("aimbot", cfg.aimbot, function(s) cfg.aimbot = s saveCfg() end)
combat:Toggle("triggerbot", cfg.autoclick, function(s) cfg.autoclick = s saveCfg() end)
combat:Toggle("rainbow beam", cfg.rainbowbeam, function(s) cfg.rainbowbeam = s saveCfg() end)
combat:Slider("fov size", 50, 400, cfg.fov, function(v) cfg.fov = v saveCfg() end)
combat:Slider("smoothness", 1, 10, cfg.smooth * 10, function(v) cfg.smooth = v / 10 saveCfg() end)
combat:Slider("beam thickness", 1, 20, cfg.beamthick * 100, function(v) cfg.beamthick = v / 100 saveCfg() end)
combat:Slider("beam red", 0, 255, cfg.beamr, function(v) cfg.beamr = v saveCfg() end)
combat:Slider("beam green", 0, 255, cfg.beamg, function(v) cfg.beamg = v saveCfg() end)
combat:Slider("beam blue", 0, 255, cfg.beamb, function(v) cfg.beamb = v saveCfg() end)

movement:Toggle("fly", cfg.flying, function(s)
    cfg.flying = s
    if hrp and hum then
        if s then bv.Parent = hrp bg.Parent = hrp hum.PlatformStand = true
        else bv.Parent = nil bg.Parent = nil hum.PlatformStand = false end
    end
    saveCfg()
end)
movement:Toggle("noclip", cfg.noclip, function(s) cfg.noclip = s saveCfg() end)
movement:Toggle("speed hax", cfg.speedhax, function(s)
    cfg.speedhax = s
    if not s and hum then hum.WalkSpeed = 16 end
    saveCfg()
end)
movement:Slider("fly speed", 20, 300, cfg.flyspd, function(v) cfg.flyspd = v saveCfg() end)
movement:Slider("walk speed", 16, 100, cfg.walkspd, function(v) cfg.walkspd = v saveCfg() end)

visuals:Toggle("esp", cfg.esp, function(s)
    cfg.esp = s
    if not s then
        for _, l in espLibraries do setVis(false, l) end
    end
    saveCfg()
end)
visuals:Toggle("tracers", cfg.tracers, function(s) cfg.tracers = s saveCfg() end)

fun:Toggle("bhop", cfg.bhop, function(s) cfg.bhop = s bhopVel = 0 saveCfg() end)
fun:Toggle("auto kill (knife)", cfg.autokill, function(s) cfg.autokill = s saveCfg() end)
fun:Toggle("coin farm", cfg.farming, function(s) cfg.farming = s saveCfg() end)
fun:Toggle("auto pickup gun", cfg.autopickup, function(s)
    cfg.autopickup = s
    if not s then gunFolder:ClearAllChildren() end
    saveCfg()
end)
fun:Slider("farm speed", 1, 20, cfg.farmcool * 10, function(v) cfg.farmcool = v / 10 saveCfg() end)
fun:Slider("max dist", 50, 500, cfg.maxdist, function(v) cfg.maxdist = v saveCfg() end)
