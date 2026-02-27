--// Donation Clicker (Delta Safe)
--// Script by Gubby Scripter
--// Update: AutoServerHop + AutoExecute (FIXED REAL)

if not game:IsLoaded() then game.Loaded:Wait() end
if getgenv().DCX_LOADED then return end
getgenv().DCX_LOADED = true

--================ SERVICES ================--
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TP = game:GetService("TeleportService")
local Http = game:GetService("HttpService")
local VU = game:GetService("VirtualUser")

local LP = Players.LocalPlayer

--================ GLOBAL SAVE ================--
getgenv().DCX_SETTINGS = getgenv().DCX_SETTINGS or {
    AC = false,
    AR = false,
    AFK = false,
    CPS = 10
}

local SETTINGS = getgenv().DCX_SETTINGS

--================ REMOTES ================--
local ClickRemote =
    RS:FindFirstChild("Click")
    or RS:FindFirstChild("ClickEvent")
    or RS:FindFirstChild("ClickerClick")
    or RS:FindFirstChild("Tap")

local RebirthRemote = RS:FindFirstChild("DoRebirth")

--================ GUI ================--
local GUI = Instance.new("ScreenGui", LP.PlayerGui)
GUI.Name = "DonationClicker"
GUI.ResetOnSpawn = false

local Frame = Instance.new("Frame", GUI)
Frame.Size = UDim2.fromOffset(320, 360)
Frame.Position = UDim2.fromScale(0.5, 0.5) - UDim2.fromOffset(160, 180)
Frame.BackgroundColor3 = Color3.fromRGB(15,15,15)
Frame.Active = true
Frame.Draggable = true
Frame.BorderSizePixel = 0

Instance.new("UICorner", Frame).CornerRadius = UDim.new(0,12)
local Stroke = Instance.new("UIStroke", Frame)
Stroke.Color = Color3.fromRGB(0,255,255)
Stroke.Thickness = 2

local Title = Instance.new("TextLabel", Frame)
Title.Size = UDim2.new(1,0,0,70)
Title.BackgroundTransparency = 1
Title.Text = "DONATION CLICKER\nMade by Gubby Scripter\nAutoServerHop + AutoExec"
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 15
Title.TextColor3 = Color3.fromRGB(0,255,255)

local function Button(text,y)
    local b = Instance.new("TextButton", Frame)
    b.Size = UDim2.new(1,-20,0,42)
    b.Position = UDim2.new(0,10,0,y)
    b.BackgroundColor3 = Color3.fromRGB(25,25,25)
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 14
    b.Text = text
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
    Instance.new("UIStroke", b).Color = Color3.fromRGB(0,200,200)
    return b
end

local function Input(ph,y)
    local t = Instance.new("TextBox", Frame)
    t.Size = UDim2.new(1,-20,0,38)
    t.Position = UDim2.new(0,10,0,y)
    t.PlaceholderText = ph
    t.BackgroundColor3 = Color3.fromRGB(20,20,20)
    t.TextColor3 = Color3.new(1,1,1)
    t.Font = Enum.Font.SourceSansBold
    t.TextSize = 14
    Instance.new("UICorner", t).CornerRadius = UDim.new(0,8)
    Instance.new("UIStroke", t).Color = Color3.fromRGB(0,200,200)
    return t
end

--================ BUTTONS ================--
local CBTN = Button("AUTO CLICK : "..(SETTINGS.AC and "ON" or "OFF"), 80)
local CPSBOX = Input("CPS", 130)
local RBTN = Button("AUTO REBIRTH : "..(SETTINGS.AR and "ON" or "OFF"), 180)
local ABTN = Button("ANTI AFK : "..(SETTINGS.AFK and "ON" or "OFF"), 230)

CPSBOX.Text = tostring(SETTINGS.CPS)

--================ LOGIC (UNCHANGED) ================--
task.spawn(function()
    while task.wait(1 / math.max(SETTINGS.CPS,1)) do
        if SETTINGS.AC and ClickRemote then
            pcall(function() ClickRemote:FireServer() end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.7) do
        if SETTINGS.AR and RebirthRemote then
            pcall(function() RebirthRemote:InvokeServer() end)
        end
    end
end)

task.spawn(function()
    while task.wait(30) do
        if SETTINGS.AFK then
            VU:Button2Down(Vector2.new(), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VU:Button2Up(Vector2.new(), workspace.CurrentCamera.CFrame)
        end
    end
end)

--================ BUTTON BINDS ================--
CBTN.MouseButton1Click:Connect(function()
    SETTINGS.AC = not SETTINGS.AC
    CBTN.Text = "AUTO CLICK : "..(SETTINGS.AC and "ON" or "OFF")
end)

RBTN.MouseButton1Click:Connect(function()
    SETTINGS.AR = not SETTINGS.AR
    RBTN.Text = "AUTO REBIRTH : "..(SETTINGS.AR and "ON" or "OFF")
end)

ABTN.MouseButton1Click:Connect(function()
    SETTINGS.AFK = not SETTINGS.AFK
    ABTN.Text = "ANTI AFK : "..(SETTINGS.AFK and "ON" or "OFF")
end)

CPSBOX.FocusLost:Connect(function()
    local v = tonumber(CPSBOX.Text)
    if v then SETTINGS.CPS = math.clamp(v,1,500) end
    CPSBOX.Text = tostring(SETTINGS.CPS)
end)

--================ SERVER HOP + AUTO EXEC (REAL FIX) ================--
task.spawn(function()
    task.wait(240)

    local payload = [[
        getgenv().DCX_SETTINGS = ]] .. Http:JSONEncode(SETTINGS) .. [[
        getgenv().DCX_LOADED = false
        loadstring(game:HttpGet("PASTE_YOUR_SCRIPT_RAW_URL_HERE"))()
    ]]

    if queue_on_teleport then
        queue_on_teleport(payload)
    end

    TP:Teleport(game.PlaceId, LP)
end)