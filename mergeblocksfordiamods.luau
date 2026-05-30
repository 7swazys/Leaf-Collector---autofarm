local SimpleLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/IcantAffordSynapse/SimpleLib/refs/heads/main/SimpleLib.lua"))()

local RS = game:GetService("ReplicatedStorage").Remotes

local GiveCash = RS.GiveCashEvent
local Rebirth = RS.RebirthEvent
local RebirthConfirm = RS.RebirthConfirmEvent
local Gem = RS.GemEvent

local Window = SimpleLib:Window("slop")
local Tabs = Window:AddSection("Remotes")

local giveCashSpam = false
local gemSpam = false
local rebirthSpam = false
local giveCashLoop = nil
local gemLoop = nil
local rebirthLoop = nil

Tabs:Toggle("money giver", false, function(state)
    giveCashSpam = state
    if giveCashSpam then
        giveCashLoop = game:GetService("RunService").RenderStepped:Connect(function()
            GiveCash:FireServer("49999")
        end)
    else
        if giveCashLoop then giveCashLoop:Disconnect() end
    end
end)

Tabs:Toggle("gem giver", false, function(state)
    gemSpam = state
    if gemSpam then
        gemLoop = game:GetService("RunService").RenderStepped:Connect(function()
            Gem:FireServer(18999)
        end)
    else
        if gemLoop then gemLoop:Disconnect() end
    end
end)

Tabs:Toggle("rebirth rebirther", false, function(state)
    rebirthSpam = state
    if rebirthSpam then
        rebirthLoop = game:GetService("RunService").RenderStepped:Connect(function()
            Rebirth:FireServer(99, 50000, 50)
            RebirthConfirm:FireServer(99, 50000, 50)
        end)
    else
        if rebirthLoop then rebirthLoop:Disconnect() end
    end
end)
