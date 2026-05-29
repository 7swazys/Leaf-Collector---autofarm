local plrs = game:GetService("Players")
local run = game:GetService("RunService")
local tween = game:GetService("TweenService")
local uis = game:GetService("UserInputService")

local plr = plrs.LocalPlayer

local spinning = false
local goldOn = false
local walkOn = false
local tpMode = false
local noclip = false
local flying = false

local spinSpd = 10
local fireRate = 0.05
local twnTime = 2
local tpSpd = 0.5

local ore = workspace.GoldOre.GoldOre.Main
local clicker = ore.ClickDetector

local fake = ore:Clone()
fake.Anchored = true
fake.Color = Color3.new(1, 0, 0)
fake.Transparency = 0.5
fake.Material = Enum.Material.Neon
fake.Parent = workspace

local points = {
    Vector3.new(-2.5639, 3.1372, 32.2252),
    Vector3.new(-23.0397, 3.2039, 34.3244),
    Vector3.new(-21.4798, 3.1372, 57.0187),
    Vector3.new(1.0120, 3.1372, 56.9935),
}

local curTween = nil
local lastFire = 0
local wpIdx = 1
local bv = nil
local bg = nil

local function startFly()
    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P = 1e4
    bg.CFrame = root.CFrame
    bg.Parent = root
    bv = Instance.new("BodyVelocity")
    bv.Velocity = Vector3.zero
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Parent = root
end

local function stopFly()
    if bv then bv:Destroy() bv = nil end
    if bg then bg:Destroy() bg = nil end
end

task.spawn(function()
    while true do
        if walkOn and not tpMode then
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for i = 1, #points do
                    if not walkOn or tpMode then break end
                    local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if not r then break end
                    curTween = tween:Create(r, TweenInfo.new(twnTime, Enum.EasingStyle.Linear), {
                        CFrame = CFrame.new(points[i])
                    })
                    curTween:Play()
                    curTween.Completed:Wait()
                end
            else
                task.wait(1)
            end
        else
            if curTween then curTween:Cancel() curTween = nil end
            task.wait(0.1)
        end
    end
end)

local lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/IcantAffordSynapse/SimpleLib/refs/heads/main/SimpleLib.lua"))()
local win = lib:Window("leaf game script window title thing")
local farm = win:AddSection("Autofarm")
local player = win:AddSection("Player")
local settings = win:AddSection("Settings")
local credits = win:AddSection("Credits")

farm:Toggle("spin", false, function(s) spinning = s end)
farm:Toggle("gold farm -- if doesnt work close script and re exuc if stil dont work u dont have gold upgrade yet", false, function(s) goldOn = s end)
farm:Toggle("auto farm leaves (tweening)", false, function(s)
    walkOn = s
    wpIdx = 1
    if not s and curTween then curTween:Cancel() curTween = nil end
end)
farm:Toggle("autofarm leaves (but u go faster)", false, function(s)
    tpMode = s
    wpIdx = 1
    if curTween then curTween:Cancel() curTween = nil end
end)

player:Toggle("speed hax", false, function(s)
    local hum = plr.Character and plr.Character:FindFirstChild("Humanoid")
    if hum then hum.WalkSpeed = s and 40 or 16 end
end)
player:Toggle("flight", false, function(s)
    flying = s
    if s then startFly() else stopFly() end
end)
player:Toggle("Noclip", false, function(s) noclip = s end)

settings:Slider("spin speed", 1, 50, spinSpd, function(v) spinSpd = v end)
settings:Slider("gold farm speed", 1, 20, 10, function(v) fireRate = 0.55 - (v * 0.025) end)
settings:Slider("tween speed", 1, 10, twnTime, function(v) twnTime = v end)
settings:Slider("tp speed", 1, 20, tpSpd * 20, function(v) tpSpd = v * 0.05 end)

credits:Label("ui by ts dud, IcantAffordSynapse")
credits:Label("script by me (7swazys) or crylo")

run.Heartbeat:Connect(function(dt)
    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if spinning then
        root.CFrame = root.CFrame * CFrame.Angles(0, spinSpd * dt * math.pi * 2, 0)
    end

    if goldOn then
        local now = tick()
        local pos = root.Position + Vector3.new(0, -2, 3)
        fake.Position = pos
        ore.Position = pos
        if now - lastFire >= fireRate then
            fireclickdetector(clicker)
            lastFire = now
        end
    end

    if walkOn and tpMode then
        local target = points[wpIdx]
        local diff = target - root.Position
        if diff.Magnitude < tpSpd then
            root.CFrame = CFrame.new(target) * (root.CFrame - root.CFrame.Position)
            wpIdx = (wpIdx % #points) + 1
        else
            root.CFrame = CFrame.new(root.Position + diff.Unit * tpSpd) * (root.CFrame - root.CFrame.Position)
        end
    end

    if noclip then
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end

    if flying and bv and bg then
        local cam = workspace.CurrentCamera
        local dir = Vector3.zero
        if uis:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if uis:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if uis:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if uis:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0) end
        bv.Velocity = dir.Magnitude > 0 and dir.Unit * 50 or Vector3.zero
        bg.CFrame = root.CFrame
    end
end)
