local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Anti AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local EventsRemote   = ReplicatedStorage:WaitForChild("Events")
local RemoteEvent    = EventsRemote:WaitForChild("RemoteEvent")
local RemoteFunction = EventsRemote:WaitForChild("RemoteFunction")
local RodRemote      = RemoteEvent:WaitForChild("Rod")
local SellFishRF     = RemoteFunction:WaitForChild("SellFish")
local RodShopRF      = RemoteFunction:WaitForChild("RodShop")
local BloxbizRemotes = ReplicatedStorage:WaitForChild("BloxbizRemotes")
BloxbizRemotes:WaitForChild("OnSendGuiImpressions")

local function notify(title, content, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = content, Duration = duration or 4
        })
    end)
    print("[" .. title .. "] " .. content)
end

local FOLDER    = "NeoScripts"
local FILE      = FOLDER .. "/AutoFish_Calibration.json"
local FISH_FILE = FOLDER .. "/AutoFish_FishCount.json"

local function ensureFolder()
    if not isfolder(FOLDER) then makefolder(FOLDER) end
end
local function saveCalibration(h)
    ensureFolder()
    pcall(function() writefile(FILE, HttpService:JSONEncode({ history = h })) end)
end
local function loadCalibration()
    ensureFolder()
    if not isfile(FILE) then return nil end
    local ok, r = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
    if ok and r then return r end
end
local function saveFishCount(n)
    ensureFolder()
    pcall(function() writefile(FISH_FILE, HttpService:JSONEncode({ fishCount = n })) end)
end
local function loadFishCount()
    if not isfile(FISH_FILE) then return 0 end
    local ok, r = pcall(function() return HttpService:JSONDecode(readfile(FISH_FILE)) end)
    if ok and r and r.fishCount then return r.fishCount end
    return 0
end

local ROD_DEFAULTS = {
    ["Basic Rod"]          = { throwToBite = 15.0, reelDur = 8.0 },
    ["Coconut Rod"]        = { throwToBite = 11.5, reelDur = 8.0 },
    ["Gopay Rod"]          = { throwToBite = 11.5, reelDur = 8.0 },
    ["Party Rod"]          = { throwToBite = 11.5, reelDur = 7.1 },
    ["Shark Rod"]          = { throwToBite = 9.4,  reelDur = 6.4 },
    ["Vip Rod"]            = { throwToBite = 7.9,  reelDur = 4.9 },
    ["Piranha Rod"]        = { throwToBite = 7.9,  reelDur = 5.8 },
    ["Thermo Rod"]         = { throwToBite = 6.8,  reelDur = 5.3 },
    ["Flowers Rod"]        = { throwToBite = 6.0,  reelDur = 4.9 },
    ["Trisula Rod"]        = { throwToBite = 5.4,  reelDur = 4.5 },
    ["Feather Rod"]        = { throwToBite = 4.8,  reelDur = 4.2 },
    ["Wave Rod"]           = { throwToBite = 4.4,  reelDur = 4.0 },
    ["Duck Rod"]           = { throwToBite = 4.1,  reelDur = 3.7 },
    ["Planet Rod"]         = { throwToBite = 3.9,  reelDur = 3.6 },
    ["Earth Rod"]          = { throwToBite = 3.75, reelDur = 3.5 },
    ["Bat Rod"]            = { throwToBite = 3.5,  reelDur = 3.3 },
    ["Pumkin Rod"]         = { throwToBite = 4.1,  reelDur = 3.4 },
    ["Reindeer Rod"]       = { throwToBite = 4.1,  reelDur = 3.4 },
    ["Canny Rod"]          = { throwToBite = 4.8,  reelDur = 6.1 },
    ["Jinggle Rod"]        = { throwToBite = 3.5,  reelDur = 3.3 },
    ["Blue Dragon Rod"]    = { throwToBite = 3.3,  reelDur = 2.9 },
    ["Pink Dragon Rod"]    = { throwToBite = 3.3,  reelDur = 2.9 },
    ["Blue Devotion Rod"]  = { throwToBite = 3.5,  reelDur = 3.3 },
    ["Pink Devotion Rod"]  = { throwToBite = 3.5,  reelDur = 3.3 },
    ["Heart Core Rod"]     = { throwToBite = 4.1,  reelDur = 3.4 },
    ["Lunar Serpent Rod"]  = { throwToBite = 3.5,  reelDur = 3.3 },
    ["Infernal Dragon Rod"]= { throwToBite = 4.1,  reelDur = 3.4 },
    ["Zenith Rod"]         = { throwToBite = 3.5,  reelDur = 3.3 },
    ["Celestia Rod"]       = { throwToBite = 4.1,  reelDur = 3.4 },
}
local DEFAULT_FALLBACK = { throwToBite = 15.0, reelDur = 8.0 }

local rodList = {
    "Basic Rod","Coconut Rod","Gopay Rod","Vip Rod","Party Rod","Shark Rod",
    "Piranha Rod","Thermo Rod","Flowers Rod","Trisula Rod","Feather Rod",
    "Wave Rod","Duck Rod","Planet Rod","Earth Rod","Bat Rod","Pumkin Rod",
    "Reindeer Rod","Canny Rod","Jinggle Rod","Blue Dragon Rod","Pink Dragon Rod",
    "Blue Devotion Rod","Pink Devotion Rod","Heart Core Rod","Lunar Serpent Rod",
    "Infernal Dragon Rod","Zenith Rod","Celestia Rod",
}

local running        = false
local minigameActive = false
local isThrowing     = false
local fishCount      = loadFishCount()
local loopTask       = nil
local throwTime      = nil
local selectedRod    = "Basic Rod"
local throwDelay     = 1.2
local autoEquip      = true
local autoThrow      = true
local autoReel       = true

local history = {}
local saved = loadCalibration()
if saved and saved.history then
    history = saved.history
    notify("AutoFish", "Calibration loaded!", 5)
end

local function getHistory(rod)
    if not history[rod] then
        history[rod] = { throwToBite = {}, reelDur = {}, samples = 0 }
    end
    return history[rod]
end

local MAX_SAMPLES = 8
local function avg(t)
    if not t or #t == 0 then return nil end
    local s = 0; for _,v in ipairs(t) do s += v end; return s/#t
end
local function pushHistory(rod, key, val)
    local h = getHistory(rod)
    if not h[key] then h[key] = {} end
    table.insert(h[key], val)
    if #h[key] > MAX_SAMPLES then table.remove(h[key], 1) end
end

local function getBarParts()
    local r = LocalPlayer.PlayerGui:FindFirstChild("Reeling")
    if not r or not r.Enabled then return nil end
    local f = r:FindFirstChild("Frame")
    local bf = f and f:FindFirstChild("Frame")
    if not bf then return nil end
    local wb = bf:FindFirstChild("WhiteBar")
    local rb = bf:FindFirstChild("RedBar")
    if not wb or not rb then return nil end
    return wb, rb
end

local function equip(forced)
    if not forced and not autoEquip then return end
    local char = LocalPlayer.Character
    if not char then return end
    if char:FindFirstChild(selectedRod) then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end) end
    task.wait(0.2)
    local rodBtn = LocalPlayer.PlayerGui:FindFirstChild("EquipTools")
        and LocalPlayer.PlayerGui.EquipTools:FindFirstChild("MainFrame")
        and LocalPlayer.PlayerGui.EquipTools.MainFrame:FindFirstChild("RodsList")
        and LocalPlayer.PlayerGui.EquipTools.MainFrame.RodsList:FindFirstChild(selectedRod)
    if rodBtn then
        pcall(function() firesignal(rodBtn.MouseButton1Click) end); task.wait(0.1)
        pcall(function() firesignal(rodBtn.Activated) end); task.wait(0.1)
        pcall(function() rodBtn.MouseButton1Click:Fire() end); task.wait(0.4)
    end
    if not char:FindFirstChild(selectedRod) then
        pcall(function() RodShopRF:InvokeServer("EquipRod", selectedRod) end)
        task.wait(0.4)
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local rodTool = bp and bp:FindFirstChild(selectedRod)
    if rodTool and not char:FindFirstChild(selectedRod) then
        if hum then pcall(function() hum:EquipTool(rodTool) end) end
    end
    task.wait(0.3)
end

local function catchFish(rod)
    pcall(function() RodRemote:FireServer("Catch", rod, true) end)
    task.wait(0.6)
end

local KG_CATEGORY = {
    [50]="All under 50 Kg", [100]="All under 100 Kg",
    [400]="All under 400 Kg", [600]="All under 600 Kg", [0]="Sell All"
}

local function sellFish(maxKg)
    local category = KG_CATEGORY[maxKg] or "Sell All"
    pcall(function() SellFishRF:InvokeServer("CheckFish", category) end)
    task.wait(0.5)
    local ok2, res2 = pcall(function() return SellFishRF:InvokeServer("SellFish", category) end)
    if ok2 then
        notify("Sold!", category .. " -> " .. tostring(res2), 4)
    else
        local ok3, res3 = pcall(function() return SellFishRF:InvokeServer("Confirm", category) end)
        if ok3 then
            notify("Sold!", category .. " (Confirm) -> " .. tostring(res3), 4)
        else
            notify("SellFish X", "Gagal: " .. tostring(res2), 4)
        end
    end
end

local function startFishing()
    running = true
    notify("AutoFish", "Mulai!", 4)
    loopTask = task.spawn(function()
        while running do
            pcall(function()
                local char = LocalPlayer.Character
                if not char then task.wait(0.5); return end
                if not char:FindFirstChild(selectedRod) then
                    if autoEquip then equip(); char = LocalPlayer.Character end
                    if not char or not char:FindFirstChild(selectedRod) then task.wait(0.5); return end
                end
                local rod = char:FindFirstChild(selectedRod)
                if not rod then task.wait(0.3); return end
                local reelingNow = LocalPlayer.PlayerGui:FindFirstChild("Reeling")
                if reelingNow and reelingNow.Enabled then task.wait(0.1); return end
                if autoThrow then
                    isThrowing = true; throwTime = tick()
                    pcall(function() RodRemote:FireServer("Throw", rod, workspace:WaitForChild("Terrain")) end)
                end
                local def = ROD_DEFAULTS[selectedRod] or DEFAULT_FALLBACK
                local h = getHistory(selectedRod)
                local biteTimeout = (avg(h.throwToBite) or def.throwToBite) * 2.5
                local elapsed, bitten = 0, false
                while elapsed < biteTimeout and running do
                    local r = LocalPlayer.PlayerGui:FindFirstChild("Reeling")
                    if r and r.Enabled then bitten = true; break end
                    task.wait(0.05); elapsed += 0.05
                end
                isThrowing = false
                if not bitten then throwTime = nil; return end
                if throwTime then
                    pushHistory(selectedRod, "throwToBite", tick() - throwTime)
                    throwTime = nil
                end
                if autoReel then
                    minigameActive = true
                    local reelStart = tick()
                    local snapConn
                    snapConn = RunService.RenderStepped:Connect(function()
                        if not minigameActive then snapConn:Disconnect(); return end
                        local wb = getBarParts()
                        if not wb then snapConn:Disconnect(); return end
                        pcall(function()
                            wb.Size     = UDim2.new(1, 0, wb.Size.Y.Scale, wb.Size.Y.Offset)
                            wb.Position = UDim2.new(0, 0, wb.Position.Y.Scale, wb.Position.Y.Offset)
                        end)
                    end)
                    elapsed = 0
                    while elapsed < 30 and running do
                        task.wait(0.05); elapsed += 0.05
                        local r = LocalPlayer.PlayerGui:FindFirstChild("Reeling")
                        if not r or not r.Enabled then break end
                    end
                    snapConn:Disconnect()
                    minigameActive = false
                    pushHistory(selectedRod, "reelDur", tick() - reelStart)
                    getHistory(selectedRod).samples = (getHistory(selectedRod).samples or 0) + 1
                    saveCalibration(history)
                end
                catchFish(rod)
                task.wait(throwDelay)
                minigameActive = false; isThrowing = false
                fishCount += 1; saveFishCount(fishCount)
            end)
            task.wait(0.05)
        end
    end)
end

local function stopFishing()
    running = false; minigameActive = false; isThrowing = false
    if loopTask then task.cancel(loopTask); loopTask = nil end
    saveFishCount(fishCount); saveCalibration(history)
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:UnequipTools() end) end
    end
    notify("AutoFish", "Stop.", 4)
end

-- [[ NeoUI ]] --
local NeoUI = {}
NeoUI.__index = NeoUI
local TweenService         = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local PRIMARY    = Color3.fromRGB(0, 200, 80)
local PRIMARY2   = Color3.fromRGB(0, 160, 60)
local BG_WINDOW  = Color3.fromRGB(14, 18, 14)
local BG_SIDEBAR = Color3.fromRGB(18, 24, 18)
local BG_PANEL   = Color3.fromRGB(16, 22, 16)
local BG_ITEM    = Color3.fromRGB(22, 30, 22)
local TEXT_MAIN  = Color3.fromRGB(220, 255, 220)
local TEXT_DIM   = Color3.fromRGB(100, 160, 100)
local STROKE_COL = Color3.fromRGB(0, 120, 50)

local function tw(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15), props):Play()
end
local function makeBox(parent, height)
    local Con = Instance.new("Frame")
    Con.Size = UDim2.new(1, 0, 0, height or 36)
    Con.BackgroundColor3 = BG_ITEM; Con.BorderSizePixel = 0; Con.Parent = parent
    Instance.new("UICorner", Con).CornerRadius = UDim.new(0, 7)
    local S = Instance.new("UIStroke")
    S.Color = STROKE_COL; S.Thickness = 1; S.Transparency = 0.5; S.Parent = Con
    return Con, S
end

function NeoUI:CreateWindow(config)
    local self = setmetatable({}, NeoUI)
    config = config or {}
    self.Name = config.Name or "NeoUI"
    self.Tabs = {}
    local parentGui = LocalPlayer:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
    self.Gui = Instance.new("ScreenGui")
    self.Gui.Name = "NeoUI"; self.Gui.ResetOnSpawn = false
    self.Gui.IgnoreGuiInset = true; self.Gui.DisplayOrder = 100
    self.Gui.Parent = parentGui
    self.Window = Instance.new("Frame")
    self.Window.Name = "Window"
    self.Window.Size = UDim2.new(0, 230, 0, 260)
   self.Window.Position = UDim2.new(0.5, -115, 0.5, -137)
    self.Window.BackgroundColor3 = BG_WINDOW; self.Window.BorderSizePixel = 0
    self.Window.Parent = self.Gui
    Instance.new("UICorner", self.Window).CornerRadius = UDim.new(0, 12)
    local WinStroke = Instance.new("UIStroke")
    WinStroke.Color = STROKE_COL; WinStroke.Thickness = 1.5; WinStroke.Parent = self.Window
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1,0,0,44); TitleBar.BackgroundColor3 = BG_SIDEBAR
    TitleBar.BorderSizePixel = 0; TitleBar.Parent = self.Window
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)
    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1,0,0.5,0); TitleFix.Position = UDim2.new(0,0,0.5,0)
    TitleFix.BackgroundColor3 = BG_SIDEBAR; TitleFix.BorderSizePixel = 0; TitleFix.Parent = TitleBar
    local TitleLine = Instance.new("Frame")
    TitleLine.Size = UDim2.new(1,0,0,1.5); TitleLine.Position = UDim2.new(0,0,1,-1)
    TitleLine.BackgroundColor3 = PRIMARY; TitleLine.BorderSizePixel = 0; TitleLine.Parent = TitleBar
    local LineGrad = Instance.new("UIGradient")
    LineGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0,200,80)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0,100,40)),
    }); LineGrad.Parent = TitleLine
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1,-100,1,0); TitleLabel.Position = UDim2.new(0,12,0,0)
    TitleLabel.BackgroundTransparency = 1; TitleLabel.TextColor3 = PRIMARY
    TitleLabel.TextSize = 14; TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.Text = self.Name; TitleLabel.AutoLocalize = false
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left; TitleLabel.Parent = TitleBar
    local MinBtn = Instance.new("TextButton")
    MinBtn.Size = UDim2.new(0,30,0,24); MinBtn.Position = UDim2.new(1,-66,0.5,-12)
    MinBtn.BackgroundColor3 = BG_ITEM; MinBtn.TextColor3 = TEXT_MAIN
    MinBtn.TextSize = 16; MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Text = "−"; MinBtn.AutoLocalize = false; MinBtn.ZIndex = 3; MinBtn.Parent = TitleBar
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0,6)
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0,30,0,24); CloseBtn.Position = UDim2.new(1,-33,0.5,-12)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(180,40,40); CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
    CloseBtn.TextSize = 12; CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Text = "X"; CloseBtn.AutoLocalize = false; CloseBtn.ZIndex = 3; CloseBtn.Parent = TitleBar
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0,6)
    local dragging, dragStart, startPos = false, nil, nil
    TitleBar.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging=true; dragStart=input.Position; startPos=self.Window.Position
        end
    end)
    TitleBar.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            self.Window.Position = startPos + UDim2.new(0,d.X,0,d.Y)
        end
    end)
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging=false
            if not self.IsMinimized then self.LastPosition = self.Window.Position end
        end
    end)
    self.IsMinimized = false
    self.OriginalSize = self.Window.Size
    self.LastPosition = self.Window.Position
    local actionName = "NeoUI_BlockCam_"..self.Name
    pcall(function()
        ContextActionService:BindAction(actionName, function()
            return dragging and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
        end, false, Enum.UserInputType.MouseMovement, Enum.UserInputType.Touch)
    end)
    local MinLine = Instance.new("TextLabel")
    MinLine.Size = UDim2.new(1,0,0,3); MinLine.Position = UDim2.new(0,0,0,0)
    MinLine.BackgroundTransparency = 1; MinLine.Text = ""; MinLine.TextColor3 = PRIMARY
    MinLine.TextSize = 13; MinLine.Font = Enum.Font.GothamBold
    MinLine.AutoLocalize = false; MinLine.BorderSizePixel = 0
    MinLine.Visible = false; MinLine.ZIndex = 10; MinLine.Parent = self.Window
    Instance.new("UICorner", MinLine).CornerRadius = UDim.new(0,2)
    local function doRestore()
        self.IsMinimized = false
        self.Window.Position = self.LastPosition
        tw(self.Window, {Size=self.OriginalSize, BackgroundTransparency=0}, 0.2)
        tw(TitleBar, {BackgroundTransparency=0}, 0.2)
        TitleFix.BackgroundTransparency = 0
        MinLine.Visible=false; MinLine.Text=""; MinLine.Size=UDim2.new(1,0,0,3)
        TitleLabel.Visible=true; TitleLabel.TextTransparency=0
        MinBtn.Visible=true; CloseBtn.Visible=true; MinBtn.Text="−"
        task.wait(0.05); self.ContentArea.Visible=true
    end
    MinBtn.MouseButton1Click:Connect(function()
        self.IsMinimized = not self.IsMinimized
        if self.IsMinimized then
            self.LastPosition = self.Window.Position
            self.ContentArea.Visible = false
            tw(self.Window, {Size=UDim2.new(0,70,0,26), BackgroundTransparency=1, Position=UDim2.new(0,10,0,80)}, 0.2)
            tw(TitleBar, {BackgroundTransparency=1}, 0.2)
            TitleFix.BackgroundTransparency = 1
            tw(WinStroke, {Color=PRIMARY, Thickness=2.5, Transparency=0}, 0.2)
            TitleLabel.Visible=false; TitleLabel.TextTransparency=1
            MinBtn.Visible=false; CloseBtn.Visible=false
            MinLine.Size=UDim2.new(1,0,1,0); MinLine.Text="NEO"; MinLine.Visible=true
        else
            doRestore()
        end
    end)
    MinLine.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if self.IsMinimized then doRestore() end
        end
    end)
    CloseBtn.MouseEnter:Connect(function() tw(CloseBtn,{BackgroundColor3=Color3.fromRGB(220,60,60)}) end)
    CloseBtn.MouseLeave:Connect(function() tw(CloseBtn,{BackgroundColor3=Color3.fromRGB(180,40,40)}) end)
    CloseBtn.MouseButton1Click:Connect(function()
        stopFishing()
        pcall(function() ContextActionService:UnbindAction(actionName) end)
        tw(self.Window, {Size=UDim2.new(0,0,0,0), BackgroundTransparency=1}, 0.15)
        task.wait(0.2); self.Gui:Destroy()
    end)
    self.ContentArea = Instance.new("Frame")
    self.ContentArea.Size = UDim2.new(1,0,1,-44); self.ContentArea.Position = UDim2.new(0,0,0,44)
    self.ContentArea.BackgroundTransparency = 1; self.ContentArea.Parent = self.Window
    self.Sidebar = Instance.new("Frame")
    self.Sidebar.Size = UDim2.new(0,65,1,-8); self.Sidebar.Position = UDim2.new(0,4,0,4)
    self.Sidebar.BackgroundColor3 = BG_SIDEBAR; self.Sidebar.BorderSizePixel = 0
    self.Sidebar.Parent = self.ContentArea
    Instance.new("UICorner", self.Sidebar).CornerRadius = UDim.new(0,8)
    local SideLayout = Instance.new("UIListLayout")
    SideLayout.Padding = UDim.new(0,5); SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; SideLayout.Parent = self.Sidebar
    local SidePad = Instance.new("UIPadding"); SidePad.PaddingTop = UDim.new(0,6); SidePad.Parent = self.Sidebar
    self.PanelContainer = Instance.new("Frame")
    self.PanelContainer.Size = UDim2.new(1,-73,1,-8); self.PanelContainer.Position = UDim2.new(0,69,0,4)
    self.PanelContainer.BackgroundColor3 = BG_PANEL; self.PanelContainer.BorderSizePixel = 0
    self.PanelContainer.Parent = self.ContentArea
    Instance.new("UICorner", self.PanelContainer).CornerRadius = UDim.new(0,8)
    local PanStroke = Instance.new("UIStroke")
    PanStroke.Color = STROKE_COL; PanStroke.Thickness = 1; PanStroke.Transparency = 0.6
    PanStroke.Parent = self.PanelContainer
    return self
end

function NeoUI:CreateTab(name)
    local tab = {}
    local isFirst = #self.Tabs == 0
    local TabBtn = Instance.new("TextButton")
    TabBtn.Size = UDim2.new(0,58,0,34); TabBtn.BackgroundColor3 = isFirst and PRIMARY2 or BG_ITEM
    TabBtn.TextColor3 = isFirst and TEXT_MAIN or TEXT_DIM; TabBtn.TextSize = 9
    TabBtn.Font = Enum.Font.GothamBold; TabBtn.Text = name; TabBtn.AutoLocalize = false
    TabBtn.TextWrapped = true; TabBtn.Parent = self.Sidebar
    Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0,7)
    tab.Button = TabBtn
    local Panel = Instance.new("ScrollingFrame")
    Panel.Size = UDim2.new(1,0,1,0); Panel.BackgroundTransparency = 1
    Panel.BorderSizePixel = 0; Panel.ScrollBarThickness = 2
    Panel.ScrollBarImageColor3 = PRIMARY; Panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Panel.CanvasSize = UDim2.new(0,0,0,0); Panel.Visible = isFirst
    Panel.Parent = self.PanelContainer
    tab.Panel = Panel
    local Layout = Instance.new("UIListLayout")
    Layout.Padding = UDim.new(0,6); Layout.SortOrder = Enum.SortOrder.LayoutOrder; Layout.Parent = Panel
    local Pad = Instance.new("UIPadding")
    Pad.PaddingTop=UDim.new(0,8); Pad.PaddingLeft=UDim.new(0,8)
    Pad.PaddingRight=UDim.new(0,8); Pad.PaddingBottom=UDim.new(0,8); Pad.Parent = Panel
    table.insert(self.Tabs, tab)
    local function setActive(t)
        for _,v in ipairs(self.Tabs) do
            v.Panel.Visible = false
            tw(v.Button, {BackgroundColor3=BG_ITEM, TextColor3=TEXT_DIM})
        end
        t.Panel.Visible = true
        tw(t.Button, {BackgroundColor3=PRIMARY2, TextColor3=TEXT_MAIN})
    end
    TabBtn.MouseButton1Click:Connect(function() setActive(tab) end)
    local tabMethods = {}
    function tabMethods:AddLabel(text)
        local L = Instance.new("TextLabel")
        L.Size = UDim2.new(1,0,0,18); L.BackgroundTransparency = 1
        L.TextColor3 = TEXT_DIM; L.TextSize = 10; L.Font = Enum.Font.GothamBold
        L.Text = text; L.AutoLocalize = false
        L.TextXAlignment = Enum.TextXAlignment.Left; L.Parent = Panel
        return L
    end
    function tabMethods:AddButton(bname, callback, color)
        local Con, _ = makeBox(Panel, 36)
        local Lbl = Instance.new("TextLabel")
        Lbl.Size = UDim2.new(1,-46,1,0); Lbl.Position = UDim2.new(0,10,0,0)
        Lbl.BackgroundTransparency = 1; Lbl.TextColor3 = TEXT_MAIN
        Lbl.TextSize = 11; Lbl.Font = Enum.Font.GothamBold
        Lbl.Text = bname; Lbl.AutoLocalize = false
        Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Parent = Con
        local Btn = Instance.new("TextButton")
        Btn.Size = UDim2.new(0,28,0,22); Btn.Position = UDim2.new(1,-34,0.5,-11)
        Btn.BackgroundColor3 = color or PRIMARY2; Btn.TextColor3 = TEXT_MAIN
        Btn.TextSize = 13; Btn.Font = Enum.Font.GothamBold
        Btn.Text = "▶"; Btn.AutoLocalize = false; Btn.ZIndex = 2; Btn.Parent = Con
        Instance.new("UICorner", Btn).CornerRadius = UDim.new(0,6)
        local ClickBtn = Instance.new("TextButton")
        ClickBtn.Size = UDim2.new(1,0,1,0); ClickBtn.BackgroundTransparency = 1
        ClickBtn.Text = ""; ClickBtn.AutoLocalize = false; ClickBtn.ZIndex = 3; ClickBtn.Parent = Con
        ClickBtn.MouseButton1Down:Connect(function() tw(Con,{BackgroundColor3=Color3.fromRGB(28,40,28)},0.05) end)
        ClickBtn.MouseButton1Up:Connect(function() tw(Con,{BackgroundColor3=BG_ITEM},0.1) end)
        ClickBtn.MouseButton1Click:Connect(function()
            tw(Btn,{BackgroundColor3=PRIMARY},0.05)
            task.delay(0.12,function() tw(Btn,{BackgroundColor3=color or PRIMARY2},0.1) end)
            callback()
        end)
    end
    function tabMethods:AddToggle(tname, default, callback)
        local val = default or false
        local Con, CS = makeBox(Panel, 36)
        local Lbl = Instance.new("TextLabel")
        Lbl.Size = UDim2.new(1,-56,1,0); Lbl.Position = UDim2.new(0,10,0,0)
        Lbl.BackgroundTransparency = 1; Lbl.TextColor3 = TEXT_MAIN
        Lbl.TextSize = 11; Lbl.Font = Enum.Font.GothamBold
        Lbl.Text = tname; Lbl.AutoLocalize = false
        Lbl.TextXAlignment = Enum.TextXAlignment.Left; Lbl.Parent = Con
        local Bg = Instance.new("TextButton")
        Bg.Size = UDim2.new(0,40,0,20); Bg.Position = UDim2.new(1,-46,0.5,-10)
        Bg.BackgroundColor3 = val and PRIMARY2 or Color3.fromRGB(40,40,40)
        Bg.BorderSizePixel = 0; Bg.Text = ""; Bg.AutoLocalize = false; Bg.ZIndex = 2; Bg.Parent = Con
        Instance.new("UICorner", Bg).CornerRadius = UDim.new(0,10)
        local Circle = Instance.new("Frame")
        Circle.Size = UDim2.new(0,14,0,14)
        Circle.Position = val and UDim2.new(0,22,0.5,-7) or UDim2.new(0,3,0.5,-7)
        Circle.BackgroundColor3 = Color3.fromRGB(255,255,255); Circle.BorderSizePixel = 0
        Circle.ZIndex = 3; Circle.Parent = Bg
        Instance.new("UICorner", Circle).CornerRadius = UDim.new(0,7)
        local function doToggle()
            val = not val
            tw(Bg,{BackgroundColor3=val and PRIMARY2 or Color3.fromRGB(40,40,40)})
            tw(Circle,{Position=val and UDim2.new(0,22,0.5,-7) or UDim2.new(0,3,0.5,-7)})
            tw(CS,{Color=val and PRIMARY or STROKE_COL, Transparency=val and 0.2 or 0.5})
            callback(val)
        end
        local ClickBtn = Instance.new("TextButton")
        ClickBtn.Size = UDim2.new(1,0,1,0); ClickBtn.BackgroundTransparency = 1
        ClickBtn.Text = ""; ClickBtn.AutoLocalize = false; ClickBtn.ZIndex = 4; ClickBtn.Parent = Con
        ClickBtn.MouseButton1Click:Connect(doToggle)
        Bg.MouseButton1Click:Connect(doToggle)
        local obj = {}
        function obj:Set(v)
            val = not not v
            tw(Bg,{BackgroundColor3=val and PRIMARY2 or Color3.fromRGB(40,40,40)})
            tw(Circle,{Position=val and UDim2.new(0,22,0.5,-7) or UDim2.new(0,3,0.5,-7)})
        end
        function obj:Get() return val end
        return obj
    end
    function tabMethods:AddInfoBox(label, defaultText)
        local Con, _ = makeBox(Panel, 52)
        local LblTop = Instance.new("TextLabel")
        LblTop.Size = UDim2.new(1,-10,0,18); LblTop.Position = UDim2.new(0,10,0,4)
        LblTop.BackgroundTransparency = 1; LblTop.TextColor3 = TEXT_DIM
        LblTop.TextSize = 9; LblTop.Font = Enum.Font.GothamBold
        LblTop.Text = label; LblTop.AutoLocalize = false
        LblTop.TextXAlignment = Enum.TextXAlignment.Left; LblTop.Parent = Con
        LblTop.Visible = true
        local ValLabel = Instance.new("TextLabel")
        ValLabel.Size = UDim2.new(1,-10,0,24); ValLabel.Position = UDim2.new(0,10,0,22)
        ValLabel.BackgroundTransparency = 1; ValLabel.TextColor3 = PRIMARY
        ValLabel.TextSize = 16; ValLabel.Font = Enum.Font.GothamBold
        ValLabel.Text = defaultText or "--"; ValLabel.AutoLocalize = false
        ValLabel.TextXAlignment = Enum.TextXAlignment.Left; ValLabel.Parent = Con
        return ValLabel
    end
    return tabMethods
end

-- [[ BUILD UI ]] --
local win = NeoUI:CreateWindow({ Name = "Neo AutoFish" })

-- Tab FISH
local fishTab = win:CreateTab("FISH")
fishTab:AddToggle("Auto Fish", false, function(v)
    if v then startFishing() else stopFishing() end
end)
fishTab:AddToggle("Auto Equip", true, function(v) autoEquip = v end)
fishTab:AddToggle("Auto Throw", true, function(v) autoThrow = v end)
fishTab:AddToggle("Auto Reel",  true, function(v) autoReel  = v end)
local statusInfo = fishTab:AddLabel("OFF | Basic Rod [0]")
statusInfo.TextColor3 = Color3.fromRGB(0, 200, 80)
statusInfo.TextSize = 8
statusInfo.Size = UDim2.new(1, -10, 0, 18)
statusInfo.TextXAlignment = Enum.TextXAlignment.Center
-- Tab DELAY
local delayTab = win:CreateTab("DELAY")
local delayInfo = delayTab:AddInfoBox("Throw Delay", throwDelay .. "s")
delayTab:AddButton("Delay +0.2", function()
    throwDelay = math.min(5.0, math.floor((throwDelay + 0.2)*10+0.5)/10)
    delayInfo.Text = throwDelay .. "s"
end, PRIMARY2)
delayTab:AddButton("Delay -0.2", function()
    throwDelay = math.max(0.2, math.floor((throwDelay - 0.2)*10+0.5)/10)
    delayInfo.Text = throwDelay .. "s"
end, Color3.fromRGB(100, 60, 0))

-- Tab SELL
local sellTab = win:CreateTab("SELL")
local sellData = {
    {"Sell All", 0}, {"< 50 Kg", 50}, {"< 100 Kg", 100},
    {"< 400 Kg", 400}, {"< 600 Kg", 600}
}
for _, data in ipairs(sellData) do
    sellTab:AddButton(data[1], function()
        task.spawn(function() sellFish(data[2]) end)
    end)
end

-- Tab ROD
local rodTab = win:CreateTab("ROD")
rodTab:AddLabel("Pilih Rod:")
for _, rodName in ipairs(rodList) do
    rodTab:AddButton(rodName, function()
        selectedRod = rodName
        local def = ROD_DEFAULTS[rodName] or DEFAULT_FALLBACK
        notify("Rod", selectedRod .. string.format(" (bite~%.1fs)", def.throwToBite), 3)
        if autoEquip then
            task.spawn(function() equip(true) end)
        else
            task.spawn(function()
                pcall(function() RodShopRF:InvokeServer("EquipRod", selectedRod) end)
            end)
        end
    end)
end

-- Status updater
task.spawn(function()
    while true do task.wait(0.1)
        local h = getHistory(selectedRod)
        local samples = h.samples or 0
        local state = "OFF"
        if running then
            if minigameActive then state = "REEL"
            elseif isThrowing then state = "THROW"
            else state = "ON" end
        end
        statusInfo.Text = state .. " | " .. selectedRod .. " [" .. samples .. "]"
    end
end)

notify("Neo AutoFish", "Ready!", 5)
