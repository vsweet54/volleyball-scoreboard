local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local EventsRemote   = ReplicatedStorage:WaitForChild("Events")
local RemoteEvent    = EventsRemote:WaitForChild("RemoteEvent")
local RemoteFunction = EventsRemote:WaitForChild("RemoteFunction")

local RodRemote    = RemoteEvent:WaitForChild("Rod")
local EquipToolsRF = RemoteFunction:WaitForChild("EquipTools")
local SellFishRF   = RemoteFunction:WaitForChild("SellFish")
local RodShopRF    = RemoteFunction:WaitForChild("RodShop")

local BloxbizRemotes = ReplicatedStorage:WaitForChild("BloxbizRemotes")
local SendGuiImpRE   = BloxbizRemotes:WaitForChild("OnSendGuiImpressions")

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

local rodList = {
    "Basic Rod", "Coconut Rod", "Gopay Rod", "Vip Rod", "Party Rod", "Shark Rod",
    "Piranha Rod", "Thermo Rod", "Flowers Rod", "Trisula Rod", "Feather Rod",
    "Wave Rod", "Duck Rod", "Planet Rod", "Earth Rod", "Bat Rod", "Pumkin Rod",
    "Reindeer Rod", "Canny Rod", "Jinggle Rod", "Blue Dragon Rod", "Pink Dragon Rod",
    "Blue Devotion Rod", "Pink Devotion Rod", "Heart Core Rod", "Lunar Serpent Rod",
    "Infernal Dragon Rod", "Zenith Rod", "Celestia Rod",
}

local running        = false
local minigameActive = false
local isThrowing     = false
local fishCount      = loadFishCount()
local loopTask       = nil
local throwTime      = nil
local selectedRod    = "Basic Rod"

local autoEquip = true
local autoThrow = true
local autoReel  = true

local biteEvent = Instance.new("BindableEvent")

local history = { throwToBite = {}, reelDur = {}, samples = 0 }
local saved = loadCalibration()
if saved and saved.history then
    for k,v in pairs(saved.history) do history[k] = v end
    notify("AutoFish", string.format("Loaded! samples=%d", history.samples), 5)
end

local MAX_SAMPLES = 8
local function avg(t)
    if not t or #t == 0 then return nil end
    local s = 0; for _,v in ipairs(t) do s += v end; return s/#t
end
local function pushHistory(key, val)
    if not history[key] then history[key] = {} end
    table.insert(history[key], val)
    if #history[key] > MAX_SAMPLES then table.remove(history[key], 1) end
end

local function getBarParts()
    local r = LocalPlayer.PlayerGui:FindFirstChild("Reeling")
    if not r or not r.Enabled then return nil end
    local frame    = r:FindFirstChild("Frame")
    local barFrame = frame and frame:FindFirstChild("Frame")
    if not barFrame then return nil end
    local whiteBar    = barFrame:FindFirstChild("WhiteBar")
    local redBar      = barFrame:FindFirstChild("RedBar")
    local progressBg  = frame:FindFirstChild("ProgressBg")
    local progressBar = progressBg and progressBg:FindFirstChild("ProgressBar")
    if not whiteBar or not redBar then return nil end
    return whiteBar, redBar, progressBg, progressBar
end
local function getProgress()
    local _,_,progressBg,progressBar = getBarParts()
    if not progressBg or not progressBar then return 0 end
    local bgW = progressBg.AbsoluteSize.X
    if bgW <= 0 then return 0 end
    return math.clamp(progressBar.AbsoluteSize.X / bgW, 0, 1)
end

local function solveMinigame(reelStartTime)
    local waitTime = 0
    while waitTime < 3 do
        local w,r = getBarParts()
        if w and r then break end
        task.wait(0.05); waitTime += 0.05
    end
    task.wait(0.1)

    local whiteBar, redBar = getBarParts()
    if not whiteBar or not redBar then minigameActive = false; return end

    local snapConn
    snapConn = RunService.RenderStepped:Connect(function()
        if not minigameActive or not autoReel then snapConn:Disconnect(); return end
        whiteBar, redBar = getBarParts()
        if not whiteBar or not redBar then snapConn:Disconnect(); return end
        if getProgress() >= 0.98 then snapConn:Disconnect(); return end
        pcall(function()
            whiteBar.Size     = UDim2.new(1, 0, whiteBar.Size.Y.Scale, whiteBar.Size.Y.Offset)
            whiteBar.Position = UDim2.new(0, 0, whiteBar.Position.Y.Scale, whiteBar.Position.Y.Offset)
        end)
    end)

    local timeout, elapsed = 30, 0
    while minigameActive and elapsed < timeout do
        task.wait(0.5); elapsed += 0.5
        if getProgress() >= 0.98 then break end
    end

    snapConn:Disconnect()
    minigameActive = false
    local reelDur = tick() - reelStartTime
    pushHistory("reelDur", reelDur)
    history.samples += 1
    saveCalibration(history)
end

local function setupReelingWatch(Reeling)
    Reeling:GetPropertyChangedSignal("Enabled"):Connect(function()
        if Reeling.Enabled then
            if not running then return end
            local t = tick()
            if throwTime then
                pushHistory("throwToBite", t - throwTime)
                throwTime = nil
            end
            biteEvent:Fire()
            if not minigameActive and autoReel then
                minigameActive = true
                task.spawn(function() solveMinigame(t) end)
            end
        else
            minigameActive = false
        end
    end)
    if Reeling.Enabled and running and not minigameActive and autoReel then
        biteEvent:Fire()
        minigameActive = true
        task.spawn(function() solveMinigame(tick()) end)
    end
end

local function watchMinigame()
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local ex = pg:FindFirstChild("Reeling")
    if ex then setupReelingWatch(ex) end
    pg.ChildAdded:Connect(function(c)
        if c.Name == "Reeling" then setupReelingWatch(c) end
    end)
end

-- [[ FIX: cek Reeling GUI langsung, bukan minigameActive/isThrowing ]]
local function isReelingActive()
    local r = LocalPlayer.PlayerGui:FindFirstChild("Reeling")
    return r and r.Enabled or false
end

local function isAlreadyCasting()
    if minigameActive or isThrowing then return true end
    return isReelingActive()
end

local function getRod()
    local char = LocalPlayer.Character
    local bp   = LocalPlayer:FindFirstChild("Backpack")
    if char then
        local r = char:FindFirstChild(selectedRod)
        if r then return r end
    end
    if bp then
        local r = bp:FindFirstChild(selectedRod)
        if r then return r end
    end
end

local function equip(forced)
    if not forced and not autoEquip then return end
    local char = LocalPlayer.Character
    if not char then return end
    if char:FindFirstChild(selectedRod) then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end) end
    task.wait(0.2)

    local rodBtn = LocalPlayer.PlayerGui
        :FindFirstChild("EquipTools")
        and LocalPlayer.PlayerGui.EquipTools
        :FindFirstChild("MainFrame")
        and LocalPlayer.PlayerGui.EquipTools.MainFrame
        :FindFirstChild("RodsList")
        and LocalPlayer.PlayerGui.EquipTools.MainFrame.RodsList
        :FindFirstChild(selectedRod)

    if rodBtn then
        pcall(function() firesignal(rodBtn.MouseButton1Click) end)
        task.wait(0.1)
        pcall(function() firesignal(rodBtn.Activated) end)
        task.wait(0.1)
        pcall(function() rodBtn.MouseButton1Click:Fire() end)
        task.wait(0.4)
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

-- [[ FIX throwRod: hapus cek Reeling (ikan blm gigit saat lempar)
--    Cukup fire remote + tunggu sebentar supaya server proses.
--    isThrowing di-reset pakai pcall+finally pattern biar ga stuck. ]]
local function throwRod(rod)
    if not autoThrow then return false end
    if isAlreadyCasting() then return false end

    isThrowing = true
    throwTime  = tick()

    local ok = pcall(function()
        RodRemote:FireServer("Throw", rod, workspace:WaitForChild("Terrain"))
    end)

    -- Tunggu sebentar supaya server proses throw-nya
    task.wait(0.5)
    isThrowing = false

    return ok  -- true kalau remote berhasil di-fire
end

local function catchFish(rod)
    pcall(function() RodRemote:FireServer("Catch", rod, false) end)
    task.wait(0.3)
end

-- [[ FIX: tunggu Reeling benar-benar mati setelah catch ]]
local function waitForReelingOff(maxSec)
    maxSec = maxSec or 5
    local t = 0
    while t < maxSec do
        if not isReelingActive() then return end
        task.wait(0.1); t += 0.1
    end
end

local KG_CATEGORY = {[50]="All under 50 Kg",[100]="All under 100 Kg",[400]="All under 400 Kg",[600]="All under 600 Kg",[0]="Sell All"}
local sellLog = ""

local function sellFish(maxKg)
    local category = KG_CATEGORY[maxKg] or "Sell All"
    pcall(function() SellFishRF:InvokeServer("CheckFish", category) end)
    task.wait(0.5)
    local ok2, res2 = pcall(function() return SellFishRF:InvokeServer("SellFish", category) end)
    if ok2 then
        sellLog = category .. " -> " .. tostring(res2)
        notify("Sold!", sellLog, 4)
    else
        local ok3, res3 = pcall(function() return SellFishRF:InvokeServer("Confirm", category) end)
        if ok3 then
            sellLog = category .. " (Confirm) -> " .. tostring(res3)
            notify("Sold!", sellLog, 4)
        else
            sellLog = "Gagal: " .. tostring(res2)
            notify("SellFish X", sellLog, 4)
        end
    end
end

-- [[ FIXED startFishing: biteConn disambung SEBELUM throw biar ga race condition ]]
local function startFishing()
    running = true
    notify("AutoFish", "Mulai!", 4)
    loopTask = task.spawn(function()
        while running do
            pcall(function()
                -- Pastikan state bersih dulu
                if isReelingActive() then task.wait(0.5); return end

                -- Equip rod sekali
                local rod = getRod()
                if not rod then
                    if autoEquip then equip(); task.wait(0.6) end
                    rod = getRod()
                end
                if not rod then task.wait(0.5); return end

                -- Pastikan rod di-hold di karakter
                local char = LocalPlayer.Character
                if not char or not char:FindFirstChild(selectedRod) then
                    if autoEquip then
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if hum then pcall(function() hum:EquipTool(rod) end) end
                        task.wait(0.4)
                    end
                    rod = getRod()
                    if not rod or not char:FindFirstChild(selectedRod) then
                        task.wait(0.5); return
                    end
                end

                if isAlreadyCasting() then task.wait(0.5); return end

                -- [[ KUNCI FIX: sambung listener DULU baru throw ]]
                local biteFired = false
                local biteConn = biteEvent.Event:Connect(function()
                    biteFired = true
                end)

                local thrown = throwRod(rod)
                if not thrown then
                    biteConn:Disconnect()
                    task.wait(0.5); return
                end

                -- Tunggu ikan gigit
                local avgBite = avg(history.throwToBite)
                -- [[ FIX: default timeout 20s (bukan 60s) biar cepet retry kalau throw gagal ]]
                local timeout = avgBite and math.max(avgBite * 2.5, 15) or 20
                local elapsed = 0
                while not biteFired and elapsed < timeout and running do
                    task.wait(0.1); elapsed += 0.1
                end
                biteConn:Disconnect()

                if not biteFired then
                    -- Throw mungkin gagal di server, reset dan coba lagi
                    throwTime = nil
                    task.wait(0.3); return
                end

                -- Tunggu minigame selesai (max 30s)
                local mg = 0
                while minigameActive and mg < 30 do task.wait(0.1); mg += 0.1 end

                -- [[ FIX: tunggu Reeling GUI benar-benar mati sebelum catch ]]
                waitForReelingOff(4)
                task.wait(0.2)

                catchFish(rod)
                fishCount += 1
                saveFishCount(fishCount)

                -- [[ FIX: tunggu setelah catch biar server state reset dulu ]]
                task.wait(0.5)
            end)
            task.wait(0.3)
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

-- [[ UI SECTION ]] --
local TweenService = game:GetService("TweenService")
local C = {
    bg = Color3.fromRGB(15, 15, 20), sidebar = Color3.fromRGB(20, 20, 28), content = Color3.fromRGB(18, 18, 26),
    title = Color3.fromRGB(0, 110, 190), tabsel = Color3.fromRGB(0, 110, 190), tab = Color3.fromRGB(20, 20, 28),
    on = Color3.fromRGB(0, 150, 70), off = Color3.fromRGB(50, 50, 65), red = Color3.fromRGB(175, 30, 30),
    sell = Color3.fromRGB(150, 95, 0), white = Color3.new(1,1,1), sub = Color3.fromRGB(135, 135, 158),
    divider = Color3.fromRGB(32, 32, 45), minimize = Color3.fromRGB(180, 140, 0)
}

local W, H, SIDEBAR_W, TITLE_H, STATUS_H = 250, 265, 62, 28, 15
local BODY_Y = TITLE_H + STATUS_H + 3
local BODY_H = H - BODY_Y

local screenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
screenGui.Name = "NeoAutoFish"; screenGui.ResetOnSpawn = false

local frame = Instance.new("Frame", screenGui)
frame.Size = UDim2.new(0, W, 0, H)
frame.Position = UDim2.new(0, 10, 0.25, 0)
frame.BackgroundColor3 = C.bg
frame.Active = true
frame.Draggable = true
frame.ClipsDescendants = false
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local titleBar = Instance.new("Frame", frame)
titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
titleBar.BackgroundColor3 = C.title
titleBar.ZIndex = 2
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local titleFix = Instance.new("Frame", titleBar)
titleFix.Size = UDim2.new(1, 0, 0, 10)
titleFix.Position = UDim2.new(0, 0, 1, -10)
titleFix.BackgroundColor3 = C.title
titleFix.BorderSizePixel = 0
titleFix.ZIndex = 2

local titleLabel = Instance.new("TextLabel", titleBar)
titleLabel.Size = UDim2.new(1, -80, 1, 0)
titleLabel.Position = UDim2.new(0, 8, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Neo AutoFish"
titleLabel.TextColor3 = C.white
titleLabel.TextSize = 12
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 3

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 22, 0, 16)
closeBtn.Position = UDim2.new(1, -26, 0.5, -8)
closeBtn.BackgroundColor3 = C.red
closeBtn.Text = "x"
closeBtn.TextColor3 = C.white
closeBtn.TextSize = 10
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 3
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
closeBtn.Activated:Connect(function() stopFishing(); screenGui:Destroy() end)

local minimizeBtn = Instance.new("TextButton", titleBar)
minimizeBtn.Size = UDim2.new(0, 22, 0, 16)
minimizeBtn.Position = UDim2.new(1, -52, 0.5, -8)
minimizeBtn.BackgroundColor3 = C.minimize
minimizeBtn.Text = "_"
minimizeBtn.TextColor3 = C.white
minimizeBtn.TextSize = 10
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.ZIndex = 3
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 4)

local statusLabel = Instance.new("TextLabel", frame)
statusLabel.Size = UDim2.new(1, -8, 0, STATUS_H)
statusLabel.Position = UDim2.new(0, 6, 0, TITLE_H + 1)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "OFF"
statusLabel.TextColor3 = C.sub
statusLabel.TextSize = 9
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left

local bodyFrame = Instance.new("Frame", frame)
bodyFrame.Size = UDim2.new(1, 0, 0, BODY_H)
bodyFrame.Position = UDim2.new(0, 0, 0, BODY_Y)
bodyFrame.BackgroundTransparency = 1
bodyFrame.ClipsDescendants = false

local minimized = false
local MINI_W, MINI_H = 110, 28

minimizeBtn.Activated:Connect(function()
    minimized = not minimized
    if minimized then
        TweenService:Create(frame, TweenInfo.new(0.2), {
            Size = UDim2.new(0, MINI_W, 0, MINI_H)
        }):Play()
        task.wait(0.05)
        statusLabel.Visible = false
        bodyFrame.Visible = false
        titleLabel.Text = "AutoFish"
        minimizeBtn.Text = "□"
    else
        statusLabel.Visible = true
        bodyFrame.Visible = true
        titleLabel.Text = "Neo AutoFish"
        minimizeBtn.Text = "_"
        TweenService:Create(frame, TweenInfo.new(0.2), {
            Size = UDim2.new(0, W, 0, H)
        }):Play()
    end
end)

local sidebar = Instance.new("Frame", bodyFrame)
sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
sidebar.BackgroundColor3 = C.sidebar
sidebar.ClipsDescendants = false
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

local contentBg = Instance.new("Frame", bodyFrame)
contentBg.Size = UDim2.new(1, -SIDEBAR_W - 1, 1, 0)
contentBg.Position = UDim2.new(0, SIDEBAR_W + 1, 0, 0)
contentBg.BackgroundColor3 = C.content
contentBg.ClipsDescendants = false
Instance.new("UICorner", contentBg).CornerRadius = UDim.new(0, 8)

local contentPad = Instance.new("Frame", contentBg)
contentPad.Size = UDim2.new(1, -14, 1, -12)
contentPad.Position = UDim2.new(0, 8, 0, 7)
contentPad.BackgroundTransparency = 1

local tabDefs = {
    { label = "FISH" },
    { label = "SELL" },
    { label = "ROD"  },
}
local tabBtns = {}
for i, def in ipairs(tabDefs) do
    local btn = Instance.new("TextButton", sidebar)
    btn.Size = UDim2.new(1, -8, 0, 46)
    btn.Position = UDim2.new(0, 4, 0, (i-1) * 50 + 6)
    btn.BackgroundColor3 = C.tab
    btn.Text = ""
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local nameLbl = Instance.new("TextLabel", btn)
    nameLbl.Size = UDim2.new(1, 0, 1, 0)
    nameLbl.Position = UDim2.new(0, 0, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = def.label
    nameLbl.TextSize = 10
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextColor3 = C.sub
    tabBtns[i] = { btn = btn, name = nameLbl }
end

local pages = {}
for i = 1, 3 do
    local p = Instance.new("Frame", contentPad)
    p.Size = UDim2.new(1, 0, 1, 0)
    p.BackgroundTransparency = 1
    p.Visible = (i == 1)
    pages[i] = p
end

local function makeSlider(parent, text, posY, initVal, callback)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, 28)
    row.Position = UDim2.new(0, 0, 0, posY)
    row.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -46, 1, 0)
    lbl.Text = text
    lbl.TextColor3 = C.white
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.BackgroundTransparency = 1
    local track = Instance.new("TextButton", row)
    track.Size = UDim2.new(0, 38, 0, 20)
    track.Position = UDim2.new(1, -38, 0.5, -10)
    track.BackgroundColor3 = (initVal and C.on or C.off)
    track.Text = ""
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("Frame", track)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = (initVal and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7))
    knob.BackgroundColor3 = C.white
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local val = initVal
    track.Activated:Connect(function()
        val = not val; callback(val)
        TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3 = (val and C.on or C.off)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = (val and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7))}):Play()
    end)
end

makeSlider(pages[1], "Auto Fish",  0,  false,     function(v) if v then startFishing() else stopFishing() end end)
makeSlider(pages[1], "Auto Equip", 32, autoEquip, function(v) autoEquip = v end)
makeSlider(pages[1], "Auto Throw", 64, autoThrow, function(v) autoThrow = v end)
makeSlider(pages[1], "Auto Reel",  96, autoReel,  function(v) autoReel  = v end)

local sellData = {{"Sell All", 0}, {"Under 50 Kg", 50}, {"Under 100 Kg", 100}, {"Under 400 Kg", 400}, {"Under 600 Kg", 600}}
for i, data in ipairs(sellData) do
    local btn = Instance.new("TextButton", pages[2])
    btn.Size = UDim2.new(1, 0, 0, 24)
    btn.Position = UDim2.new(0, 0, 0, (i-1) * 27)
    btn.BackgroundColor3 = C.sell
    btn.Text = "• " .. data[1]
    btn.TextColor3 = C.white
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.Activated:Connect(function() task.spawn(function() sellFish(data[2]) end) end)
end

local rodScroll = Instance.new("ScrollingFrame", pages[3])
rodScroll.Size = UDim2.new(1, 0, 1, 0)
rodScroll.BackgroundTransparency = 1
rodScroll.ScrollBarThickness = 2
rodScroll.CanvasSize = UDim2.new(0, 0, 0, #rodList * 27)
local rodBtns = {}
for i, rodName in ipairs(rodList) do
    local btn = Instance.new("TextButton", rodScroll)
    btn.Size = UDim2.new(1, -4, 0, 22)
    btn.Position = UDim2.new(0, 0, 0, (i-1) * 27)
    btn.BackgroundColor3 = (rodName == selectedRod and C.tabsel or C.tab)
    btn.Text = rodName
    btn.TextColor3 = C.white
    btn.TextSize = 9
    btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    rodBtns[i] = btn
    btn.Activated:Connect(function()
        selectedRod = rodName
        for _, b in ipairs(rodBtns) do b.BackgroundColor3 = (b.Text == selectedRod and C.tabsel or C.tab) end
        notify("Rod", selectedRod, 3)
        if autoEquip then
            task.spawn(function() equip(true) end)
        else
            task.spawn(function()
                pcall(function() RodShopRF:InvokeServer("EquipRod", selectedRod) end)
            end)
        end
    end)
end

local function switchTab(idx)
    for i, p in ipairs(pages) do p.Visible = (i == idx) end
    for i, t in ipairs(tabBtns) do
        local active = (i == idx)
        TweenService:Create(t.btn, TweenInfo.new(0.15), {BackgroundColor3 = (active and C.tabsel or C.tab)}):Play()
        t.name.TextColor3 = (active and C.white or C.sub)
    end
end
for i, t in ipairs(tabBtns) do t.btn.Activated:Connect(function() switchTab(i) end) end
switchTab(1)

task.spawn(function()
    while true do task.wait(1)
        statusLabel.Text = (running and (minigameActive and "REEL" or (isThrowing and "THROW" or "ON")) or "OFF")
            .. " | Fish: " .. fishCount
            .. " | " .. selectedRod
    end
end)

watchMinigame()
notify("Neo AutoFish", "Ready!", 5)
