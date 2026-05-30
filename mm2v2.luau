local plrs = game:GetService("Players")
local run = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local tws = game:GetService("TweenService")
local http = game:GetService("HttpService")
local cam = workspace.CurrentCamera
local lp = plrs.LocalPlayer

local cfgPath = "mm2cfg.json"
local cfg = {
    aimbot = false, autoclick = false, silentaim = false,
    farming = false, flying = false, noclip = false,
    autopickup = false, esp = true, tracers = true,
    chams = false, speedhax = false, bhop = false,
    rainbowbeam = false, beamthick = 0.08,
    method = "MouseMoveRel", fov = 150, smooth = 0.18,
    flyspd = 140, maxdist = 250, farmcool = 0.9,
    jiggle = 0.7, walkspd = 40,
    beamr = 160, beamg = 32, beamb = 240,
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

local function setupChar(char)
    hrp = char:WaitForChild("HumanoidRootPart")
    hum = char:WaitForChild("Humanoid")
    if bv then bv:Destroy() end
    if bg then bg:Destroy() end
    bv = Instance.new("BodyVelocity")
    bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
    bv.MaxForce = Vector3.new(4e5, 4e5, 4e5)
end

lp.CharacterAdded:Connect(setupChar)
if lp.Character then setupChar(lp.Character) end

local notifGui = Instance.new("ScreenGui")
notifGui.Name = "mm2notifs"
notifGui.ResetOnSpawn = false
notifGui.Parent = game:GetService("CoreGui")

local function notify(txt, color)
    color = color or Color3.fromRGB(160, 32, 240)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 240, 0, 38)
    f.Position = UDim2.new(1, 10, 0.82, 0)
    f.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    f.BackgroundTransparency = 0.05
    f.BorderSizePixel = 0
    f.Parent = notifGui
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1.2
    stroke.Transparency = 0.3
    stroke.Parent = f
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, 0)
    bar.BackgroundColor3 = color
    bar.BorderSizePixel = 0
    bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = txt
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = f
    tws:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(1, -252, 0.82, 0)
    }):Play()
    task.delay(2.8, function()
        tws:Create(f, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {
            Position = UDim2.new(1, 10, 0.82, 0),
            BackgroundTransparency = 1
        }):Play()
        task.delay(0.3, function() f:Destroy() end)
    end)
end

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

local function hasGun()
    local ch = lp.Character
    local bp = lp:FindFirstChild("Backpack")
    return (ch and ch:FindFirstChild("Gun")) or (bp and bp:FindFirstChild("Gun"))
end

local function isVisible(part)
    if not lp.Character then return false end
    local origin = cam.CFrame.Position
    local dir = part.Position - origin
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {lp.Character, cam}
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    local res = workspace:Raycast(origin, dir, rp)
    return res and res.Instance:IsDescendantOf(part.Parent)
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
        Transparency = 1,
        Size = Vector3.new(0, 0, dist)
    })
    t:Play()
    t.Completed:Connect(function() beam:Destroy() end)
end

-- ESP
local espFolder = Instance.new("Folder")
espFolder.Name = "esp"
espFolder.Parent = game:GetService("CoreGui")
local espObjects = {}

local function makeESP(p)
    if p == lp then return end
    local obj = {}
    local box = Instance.new("SelectionBox")
    box.LineThickness = 0.05
    box.SurfaceTransparency = 0.88
    box.Parent = espFolder
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 45)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Parent = espFolder
    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1, 0, 0.55, 0)
    nameL.BackgroundTransparency = 1
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 13
    nameL.TextStrokeTransparency = 0.4
    nameL.Parent = bb
    local infoL = Instance.new("TextLabel")
    infoL.Size = UDim2.new(1, 0, 0.45, 0)
    infoL.Position = UDim2.new(0, 0, 0.55, 0)
    infoL.BackgroundTransparency = 1
    infoL.Font = Enum.Font.Gotham
    infoL.TextSize = 11
    infoL.TextStrokeTransparency = 0.4
    infoL.Parent = bb
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1.5
    tracer.Transparency = 0.3
    tracer.Visible = false
    obj.box = box obj.bb = bb obj.nameL = nameL obj.infoL = infoL obj.tracer = tracer
    espObjects[p] = obj
    run.RenderStepped:Connect(function()
        local char = p.Character
        local phrp = char and char:FindFirstChild("HumanoidRootPart")
        local phum = char and char:FindFirstChild("Humanoid")
        if not cfg.esp or not phrp or not hrp then
            box.Adornee = nil bb.Adornee = nil tracer.Visible = false return
        end
        local dist = math.floor((hrp.Position - phrp.Position).Magnitude)
        local rc = roleColor(p)
        box.Adornee = char box.Color3 = rc box.SurfaceColor3 = rc
        bb.Adornee = phrp
        nameL.TextColor3 = rc nameL.Text = p.Name
        infoL.TextColor3 = Color3.fromRGB(200, 200, 200)
        infoL.Text = getRole(p):upper() .. " | " .. dist .. "m" .. (phum and " | " .. math.floor(phum.Health) .. "hp" or "")
        local pos, onScreen = cam:WorldToViewportPoint(phrp.Position)
        if onScreen and cfg.tracers then
            tracer.Visible = true
            tracer.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
            tracer.To = Vector2.new(pos.X, pos.Y)
            tracer.Color = rc
        else tracer.Visible = false end
    end)
end

local function removeESP(p)
    local obj = espObjects[p]
    if not obj then return end
    obj.box:Destroy() obj.bb:Destroy() obj.tracer:Remove()
    espObjects[p] = nil
end

for _, p in plrs:GetPlayers() do makeESP(p) end
plrs.PlayerAdded:Connect(makeESP)
plrs.PlayerRemoving:Connect(removeESP)

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.2
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Transparency = 0.5
fovCircle.Visible = false

local gunFolder = Instance.new("Folder")
gunFolder.Parent = game:GetService("CoreGui")

task.spawn(function()
    while true do
        task.wait(0.5)
        if cfg.autopickup then
            if hasGun() then
                cfg.autopickup = false
                gunFolder:ClearAllChildren()
                notify("got gun", Color3.fromRGB(255, 215, 0))
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
    if cfg.bhop and hum then
        if hum:GetState() == Enum.HumanoidStateType.Landed then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
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
            if cfg.autoclick and hasGun() and isVisible(target) and mouse1press then
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

-- load ui last so everything is ready
local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/IcantAffordSynapse/SimpleLib/refs/heads/main/SimpleLib.lua"))()
local win = lib:Window("mm2")
local combat = win:AddSection("Combat")
local movement = win:AddSection("Movement")
local misc = win:AddSection("Misc")

combat:Toggle("aimbot", cfg.aimbot, function(s) cfg.aimbot = s saveCfg() notify("aimbot " .. (s and "on" or "off"), roleColors.murder) end)
combat:Toggle("triggerbot", cfg.autoclick, function(s) cfg.autoclick = s saveCfg() notify("triggerbot " .. (s and "on" or "off"), roleColors.sheriff) end)
combat:Toggle("rainbow beam", cfg.rainbowbeam, function(s) cfg.rainbowbeam = s saveCfg() end)
combat:Toggle("esp", cfg.esp, function(s) cfg.esp = s saveCfg() notify("esp " .. (s and "on" or "off"), roleColors.inno) end)
combat:Toggle("tracers", cfg.tracers, function(s) cfg.tracers = s saveCfg() notify("tracers " .. (s and "on" or "off"), roleColors.inno) end)
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
    saveCfg() notify("fly " .. (s and "on" or "off"), Color3.fromRGB(160, 32, 240))
end)
movement:Toggle("noclip", cfg.noclip, function(s) cfg.noclip = s saveCfg() notify("noclip " .. (s and "on" or "off"), Color3.fromRGB(255, 215, 0)) end)
movement:Toggle("speed hax", cfg.speedhax, function(s) cfg.speedhax = s if not s and hum then hum.WalkSpeed = 16 end saveCfg() end)
movement:Toggle("bhop", cfg.bhop, function(s) cfg.bhop = s saveCfg() end)
movement:Slider("fly speed", 20, 300, cfg.flyspd, function(v) cfg.flyspd = v saveCfg() end)
movement:Slider("walk speed", 16, 100, cfg.walkspd, function(v) cfg.walkspd = v saveCfg() end)

misc:Toggle("coin farm", cfg.farming, function(s) cfg.farming = s saveCfg() notify("coin farm " .. (s and "on" or "off"), Color3.fromRGB(255, 215, 0)) end)
misc:Toggle("auto pickup gun", cfg.autopickup, function(s) cfg.autopickup = s if not s then gunFolder:ClearAllChildren() end saveCfg() end)
misc:Slider("farm speed", 1, 20, cfg.farmcool * 10, function(v) cfg.farmcool = v / 10 saveCfg() end)
misc:Slider("max dist", 50, 500, cfg.maxdist, function(v) cfg.maxdist = v saveCfg() end)

notify("mm2 loaded", Color3.fromRGB(160, 32, 240))
