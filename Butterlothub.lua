local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local CREATOR_ID = 5233216106

local collectPositions = {
    CFrame.new(109, -286, 600),
    CFrame.new(177, -288, 613),
    CFrame.new(-53, -307, 922),
    CFrame.new(-63, -307, 922)
}
local collectTimes = {0.2, 0.2, 0.2, 10.2}
local homeCF = CFrame.new(-62, -307, 569)

local collecting = false
local moneyEnabled = false
local collectIndex = 1
local lastTime = 0
local antiDriverEnabled = false
local antiDriverLocked = false
local Teams = pcall(game.GetService, game, "Teams") and game:GetService("Teams")

local deathPos = nil
local fullbrightOn = false
local originalLighting = {}

local superMoneyEnabled = false
local selectedDriver = nil
local driverDropdownOpen = false
local dropdownFrame = nil
local playerListLabels = {}
local respawnDetected = false
local superMoneyJustEnabled = false

local noclipEnabled = false
local espEnabled = false
local scriptUserEspEnabled = true
local espHighlights = {}
local scriptUsers = {}

-- Developer presence state
local creatorPresent = false
local creatorPlayers = {}

local toggleRefs = {}

local old = PlayerGui:FindFirstChild("DScript")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Parent = PlayerGui
gui.Name = "DScript"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

-- Dedicated container for ESP highlights (kept out of the menu ScreenGui so
-- rebuilding/hiding the UI can never affect ESP rendering).
local espFolder = Instance.new("Folder")
espFolder.Name = "DScriptESP"
espFolder.Parent = gui

local introPlaying = false

local function playIntro(message)
    if introPlaying then return end
    introPlaying = true

    task.spawn(function()
        local blur = Instance.new("BlurEffect")
        blur.Name = "DScriptIntroBlur"
        blur.Size = 0
        blur.Parent = Lighting

        local overlay = Instance.new("Frame")
        overlay.Parent = gui
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.Position = UDim2.new(0, 0, 0, 0)
        overlay.BackgroundColor3 = Color3.fromRGB(10, 10, 18)
        overlay.BackgroundTransparency = 1
        overlay.BorderSizePixel = 0
        overlay.ZIndex = 100
        overlay.Active = true

        local label = Instance.new("TextLabel")
        label.Parent = overlay
        label.Size = UDim2.new(1, -40, 0, 80)
        label.Position = UDim2.new(0, 20, 0.5, -40)
        label.BackgroundTransparency = 1
        label.Text = message
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextStrokeTransparency = 0.4
        label.TextTransparency = 1
        label.Font = Enum.Font.GothamBlack
        label.TextScaled = true
        label.ZIndex = 101

        local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(blur, info, {Size = 24}):Play()
        TweenService:Create(overlay, info, {BackgroundTransparency = 0.45}):Play()
        TweenService:Create(label, info, {TextTransparency = 0}):Play()

        task.wait(3)

        local outInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(blur, outInfo, {Size = 0}):Play()
        TweenService:Create(overlay, outInfo, {BackgroundTransparency = 1}):Play()
        TweenService:Create(label, outInfo, {TextTransparency = 1}):Play()

        task.wait(0.7)
        overlay:Destroy()
        blur:Destroy()
        introPlaying = false
    end)
end

local function tp(cf)
    local c = player.Character
    if c and c:FindFirstChild("HumanoidRootPart") then
        c.HumanoidRootPart.CFrame = cf
    end
end

local function tpWithVehicle(cf)
    local c = player.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then return end

    local humanoid = c:FindFirstChild("Humanoid")
    local vehicle = nil

    if humanoid and humanoid.Sit then
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("VehicleSeat") and v.Occupant == humanoid then
                vehicle = v:FindFirstAncestorOfClass("Model") or v.Parent
                if vehicle == workspace or vehicle == nil then
                    vehicle = v
                end
                break
            end
        end
    end

    if vehicle then
        if vehicle:IsA("Model") and vehicle:FindFirstChild("PrimaryPart") then
            vehicle:SetPrimaryPartCFrame(cf)
        elseif vehicle:IsA("BasePart") then
            vehicle.CFrame = cf
        else
            c.HumanoidRootPart.CFrame = cf
        end
    else
        c.HumanoidRootPart.CFrame = cf
    end
end

local firstCharacterLoad = true
local function trackDeath()
    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.Died:Connect(function()
                if char:FindFirstChild("HumanoidRootPart") then
                    deathPos = char.HumanoidRootPart.CFrame
                end
                respawnDetected = true
            end)
        end
    end

    player.CharacterAdded:Connect(function(newChar)
        if not firstCharacterLoad then
            respawnDetected = true
        end
        firstCharacterLoad = false

        local hum = newChar:WaitForChild("Humanoid")
        hum.Died:Connect(function()
            if newChar:FindFirstChild("HumanoidRootPart") then
                deathPos = newChar.HumanoidRootPart.CFrame
            end
            respawnDetected = true
        end)
    end)

    if firstCharacterLoad and char then
        firstCharacterLoad = false
    end
end
trackDeath()

local function saveOriginalLighting()
    originalLighting = {
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        GlobalShadows = Lighting.GlobalShadows,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        ColorShift_Top = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom
    }
end

local function enableFullbright()
    saveOriginalLighting()
    Lighting.Brightness = 1
    Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    Lighting.GlobalShadows = false
    Lighting.ClockTime = 12
    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
    Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
    Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
    fullbrightOn = true
end

local function disableFullbright()
    if next(originalLighting) then
        Lighting.Brightness = originalLighting.Brightness
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.ClockTime = originalLighting.ClockTime
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
        Lighting.ColorShift_Top = originalLighting.ColorShift_Top
        Lighting.ColorShift_Bottom = originalLighting.ColorShift_Bottom
    end
    fullbrightOn = false
end

local noclipTouched = {}

local function applyNoclip()
    local c = player.Character
    if not c then return end
    for _, part in ipairs(c:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide then
            noclipTouched[part] = true
            part.CanCollide = false
        end
    end
end

local function restoreNoclip()
    for part in pairs(noclipTouched) do
        if part and part.Parent then
            pcall(function() part.CanCollide = true end)
        end
    end
    noclipTouched = {}
end

RunService.Stepped:Connect(function()
    if noclipEnabled then
        applyNoclip()
    end
end)

local DRIVER_COLOR = Color3.fromRGB(255, 45, 45)
local SURVIVOR_COLOR = Color3.fromRGB(45, 130, 255)
local OTHER_COLOR = Color3.fromRGB(60, 220, 90)
local SCRIPT_USER_COLOR = Color3.fromRGB(255, 255, 255)
local CREATOR_COLOR = Color3.fromRGB(255, 200, 40) -- gold (top priority)

local function isCreator(p)
    return p ~= nil and p.UserId == CREATOR_ID
end

local function isDriverTeam(team)
    if not team then return false end
    local n = string.lower(team.Name)
    return n == "drivers" or n == "driver"
end

local function isSurvivorTeam(team)
    if not team then return false end
    local n = string.lower(team.Name)
    return n == "survivors" or n == "survivor" or n == "runners" or n == "runner"
end

local SIG_NAME = "DScriptUserTag"
local SIG_VALUE = 8731.4219
local SIG_EPSILON = 0.0005

local function stampSignature(char)
    char = char or player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
    if not root then return end

    local tag = char:FindFirstChild(SIG_NAME, true)
    if tag and tag:IsA("NumberValue") and tag.Parent == root then
        tag.Value = SIG_VALUE
        return
    end
    if tag then pcall(function() tag:Destroy() end) end

    pcall(function()
        local v = Instance.new("NumberValue")
        v.Name = SIG_NAME
        v.Value = SIG_VALUE
        v.Parent = root
    end)
end

local function hasSignature(p)
    local char = p.Character
    if not char then return false end
    local tag = char:FindFirstChild(SIG_NAME, true)
    if tag and tag:IsA("NumberValue") and math.abs(tag.Value - SIG_VALUE) < SIG_EPSILON then
        return true
    end
    return false
end

local function isScriptUserPlayer(p)
    if p == player then return true end -- we are obviously running the script
    return scriptUsers[p.UserId] ~= nil
end

local function showsWhiteEsp(p)
    if isCreator(p) then return false end
    if not isScriptUserPlayer(p) then return false end
    if isDriverTeam(p.Team) or isSurvivorTeam(p.Team) then return false end
    return true
end

local function colorForPlayer(p)
    if isCreator(p) then
        return CREATOR_COLOR, "creator"
    end

    if showsWhiteEsp(p) then
        return SCRIPT_USER_COLOR, "scriptuser"
    end


    if isDriverTeam(p.Team) then
        return DRIVER_COLOR, "team"
    elseif isSurvivorTeam(p.Team) then
        return SURVIVOR_COLOR, "team"
    end
    return OTHER_COLOR, "team"
end

local function removeHighlight(p)
    local hl = espHighlights[p]
    if hl then
        hl:Destroy()
        espHighlights[p] = nil
    end
end

local function clearAllHighlights()
    for p, hl in pairs(espHighlights) do
        if hl then hl:Destroy() end
        espHighlights[p] = nil
    end
end

local function foreignHighlightExists(char)
    for _, inst in ipairs(char:GetDescendants()) do
        if inst:IsA("Highlight") and not string.find(inst.Name, "DScriptESP", 1, true) then
            return true
        end
    end
    for _, inst in ipairs(espFolder.Parent:GetDescendants()) do
        if inst:IsA("Highlight") and inst.Adornee == char
            and not string.find(inst.Name, "DScriptESP", 1, true) then
            return true
        end
    end
    return false
end

local function bumpToFront(hl)
    -- cheap way to force re-render last: detach + reattach
    local parent = hl.Parent
    hl.Parent = nil
    hl.Parent = parent
end

local function applyHighlight(p, char, forceTop)
    local hl = espHighlights[p]
    if not hl or not hl.Parent then
        hl = Instance.new("Highlight")
        hl.Name = "DScriptESP_" .. p.Name
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.OutlineTransparency = 0
        hl.FillTransparency = 0.6
        hl.Parent = espFolder
        espHighlights[p] = hl
    end
    hl.Adornee = char

    local col, kind = colorForPlayer(p)
    hl.OutlineColor = col
    hl.FillColor = col
    if kind == "creator" then
        hl.FillTransparency = 0.35
    elseif kind == "scriptuser" then
        hl.FillTransparency = 0.55 -- more visible white
    else
        hl.FillTransparency = 0.6
    end

    if forceTop and foreignHighlightExists(char) then
        bumpToFront(hl)
    end
end

local function updateEsp()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        local creator = isCreator(p)
        local whiteUser = showsWhiteEsp(p)
        local show = char and char:FindFirstChild("HumanoidRootPart")
            and (
                (espEnabled and p ~= player)
                or creator
                or (scriptUserEspEnabled and whiteUser)
            )


        if show then
            applyHighlight(p, char, true)
        else
            removeHighlight(p)
        end
    end

    for p in pairs(espHighlights) do
        if not p.Parent then
            removeHighlight(p)
        end
    end
end

task.spawn(function()
    while true do
        pcall(updateEsp)
        task.wait(0.35)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    removeHighlight(p)
    scriptUsers[p.UserId] = nil
    creatorPlayers[p.UserId] = nil
end)

local function markScriptUser(userId)
    if not userId then return end
    scriptUsers[userId] = os.clock()
end

-- Keep our own marker alive (respawns, sanity checks, other scripts removing it)
task.spawn(function()
    while true do
        pcall(stampSignature)
        task.wait(2)
    end
end)

player.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    stampSignature(c)
end)

task.spawn(function()
    while true do
        local present = false
        table.clear(creatorPlayers)
        for _, p in ipairs(Players:GetPlayers()) do
            if isCreator(p) then
                present = true
                creatorPlayers[p.UserId] = true
            end
        end
        creatorPresent = present
        task.wait(5)
    end
end)

-- Script-user detection: always runs, for every other player.
task.spawn(function()
    while true do
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then
                if hasSignature(p) then
                    markScriptUser(p.UserId)
                else
                    scriptUsers[p.UserId] = nil
                end
            end
        end
        pcall(updateEsp)
        task.wait(2)
    end
end)

local BTN_HEIGHT = 28
local BTN_GAP = 7
local PADDING = 5
local SIDE_PADDING = 8
local TAB_HEIGHT = 28
local TITLE_HEIGHT = 28
local TAB_BAR_HEIGHT = 30
local CONTENT_Y_OFFSET = TITLE_HEIGHT + TAB_BAR_HEIGHT + 8
local CONTENT_PADDING_BOTTOM = 8

local currentPage = nil
local contentContainer = nil
local menu = nil
local collectBtn = nil

local pageWidgets = {}

local function refreshToggle(name)
    local ref = toggleRefs[name]
    if not ref or not ref.btn or not ref.btn.Parent then return end
    local item = ref.item
    local btn = ref.btn
    if item.getState() then
        btn.Text = item.text .. ": ON"
        btn.BackgroundColor3 = item.enabledColor
    else
        btn.Text = item.text .. (ref.locked and ": LOCKED" or ": OFF")
        btn.BackgroundColor3 = ref.locked and Color3.fromRGB(80, 80, 90) or item.color
    end
end

local function setAntiDriverLocked(locked)
    if antiDriverLocked == locked then return end
    antiDriverLocked = locked
    local ref = toggleRefs["Anti-Driver"]
    if ref then ref.locked = locked end
    if locked and antiDriverEnabled then
        antiDriverEnabled = false
    end
    refreshToggle("Anti-Driver")
end

local pageConfig = {
    Main = {
        buttons = {
            {
                type = "button",
                text = "Teleport to Home",
                color = Color3.fromRGB(100, 80, 180),
                callback = function()
                    tp(homeCF)
                end,
            },
            {
                type = "button",
                text = "Spawn Platform",
                color = Color3.fromRGB(50, 180, 120),
                callback = function()
                    local c = player.Character
                    if not c or not c:FindFirstChild("HumanoidRootPart") then return end

                    local hrp = c.HumanoidRootPart
                    local platformCF = hrp.CFrame + Vector3.new(0, 30, 0)

                    local platform = Instance.new("Part")
                    platform.Size = Vector3.new(20, 1, 20)
                    platform.CFrame = platformCF
                    platform.Anchored = true
                    platform.CanCollide = true
                    platform.Material = Enum.Material.SmoothPlastic
                    platform.Transparency = 0.5
                    platform.BrickColor = BrickColor.new("Really blue")
                    platform.TopSurface = Enum.SurfaceType.Smooth
                    platform.BottomSurface = Enum.SurfaceType.Smooth
                    platform.Parent = workspace

                    for _, v in pairs(workspace:GetChildren()) do
                        if v:GetAttribute("DScriptPlatform") and v ~= platform then
                            v:Destroy()
                        end
                    end
                    platform:SetAttribute("DScriptPlatform", true)

                    tp(platformCF + Vector3.new(0, 3, 0))

                    task.spawn(function()
                        task.wait(30)
                        if platform and platform.Parent then
                            platform:Destroy()
                        end
                    end)
                end,
            },
            {
                type = "toggle",
                text = "Anti-Driver",
                color = Color3.fromRGB(180, 60, 60),
                enabledColor = Color3.fromRGB(60, 180, 60),
                getState = function() return antiDriverEnabled end,
                toggleCallback = function()
                    if antiDriverLocked then
                        antiDriverEnabled = false
                        return
                    end
                    antiDriverEnabled = not antiDriverEnabled
                end,
            },
            {
                type = "button",
                text = "Revive",
                color = Color3.fromRGB(60, 180, 200),
                callback = function()
                    if deathPos then
                        local c = player.Character
                        if c then
                            local hum = c:FindFirstChild("Humanoid")
                            if hum then
                                hum.WalkSpeed = 50
                            end
                        end
                        tp(deathPos)
                    end
                end,
            },
        },
    },
    Utility = {
        buttons = {
            {
                type = "toggle",
                text = "Money Collect",
                color = Color3.fromRGB(50, 120, 200),
                enabledColor = Color3.fromRGB(200, 60, 60),
                getState = function() return moneyEnabled end,
                toggleCallback = function()
                    moneyEnabled = not moneyEnabled
                    if not moneyEnabled then
                        collectBtn.Visible = false
                        collecting = false
                        collectBtn.Text = "Start Collecting"
                        collectBtn.BackgroundColor3 = Color3.fromRGB(200, 170, 50)
                    end
                end,
                onEnabled = function()
                    collectBtn.Visible = true
                end,
                onDisabled = function()
                    collectBtn.Visible = false
                    collecting = false
                    collectBtn.Text = "Start Collecting"
                    collectBtn.BackgroundColor3 = Color3.fromRGB(200, 170, 50)
                end,
            },
            {
                type = "toggle",
                text = "Fullbright",
                color = Color3.fromRGB(180, 180, 50),
                enabledColor = Color3.fromRGB(60, 200, 60),
                getState = function() return fullbrightOn end,
                toggleCallback = function()
                    fullbrightOn = not fullbrightOn
                    if fullbrightOn then
                        enableFullbright()
                    else
                        disableFullbright()
                    end
                end,
            },
            {
                type = "toggle",
                text = "Noclip",
                color = Color3.fromRGB(120, 80, 200),
                enabledColor = Color3.fromRGB(60, 200, 60),
                getState = function() return noclipEnabled end,
                toggleCallback = function()
                    noclipEnabled = not noclipEnabled
                    if not noclipEnabled then
                        restoreNoclip()
                    end
                end,
            },
            {
                type = "toggle",
                text = "ESP",
                color = Color3.fromRGB(200, 110, 40),
                enabledColor = Color3.fromRGB(60, 200, 60),
                getState = function() return espEnabled end,
                toggleCallback = function()
                    espEnabled = not espEnabled
                    if not espEnabled then
                        clearAllHighlights()
                    end
                    pcall(updateEsp)
                end,
            },
            {
                type = "toggle",
                text = "Script User ESP",
                color = Color3.fromRGB(90, 90, 110),
                enabledColor = Color3.fromRGB(60, 200, 60),
                getState = function() return scriptUserEspEnabled end,
                toggleCallback = function()
                    scriptUserEspEnabled = not scriptUserEspEnabled
                    if not scriptUserEspEnabled then
                        clearAllHighlights()
                    end
                    pcall(updateEsp)
                end,
            },
        },
    },
    Driver = {
        buttons = {
            {
                type = "custom",
                build = function(parent, yPos)
                    local dropdownHeader = Instance.new("TextButton")
                    dropdownHeader.Parent = parent
                    dropdownHeader.Size = UDim2.new(1, -(SIDE_PADDING * 2), 0, BTN_HEIGHT)
                    dropdownHeader.Position = UDim2.new(0, SIDE_PADDING, 0, yPos)
                    dropdownHeader.Text = "Select Driver ▾"
                    dropdownHeader.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
                    dropdownHeader.TextColor3 = Color3.fromRGB(200, 200, 220)
                    dropdownHeader.Font = Enum.Font.GothamBold
                    dropdownHeader.TextSize = 13
                    dropdownHeader.BorderSizePixel = 0

                    local dhCorner = Instance.new("UICorner")
                    dhCorner.Parent = dropdownHeader
                    dhCorner.CornerRadius = UDim.new(0, 7)

                    yPos = yPos + BTN_HEIGHT + BTN_GAP

                    dropdownFrame = Instance.new("Frame")
                    dropdownFrame.Parent = parent
                    dropdownFrame.Size = UDim2.new(1, -(SIDE_PADDING * 2), 0, 150)
                    dropdownFrame.Position = UDim2.new(0, SIDE_PADDING, 0, yPos)
                    dropdownFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
                    dropdownFrame.BorderSizePixel = 0
                    dropdownFrame.Visible = false
                    dropdownFrame.ZIndex = 10

                    local dfCorner = Instance.new("UICorner")
                    dfCorner.Parent = dropdownFrame
                    dfCorner.CornerRadius = UDim.new(0, 7)

                    local playerScrolling = Instance.new("ScrollingFrame")
                    playerScrolling.Parent = dropdownFrame
                    playerScrolling.Size = UDim2.new(1, -8, 1, -8)
                    playerScrolling.Position = UDim2.new(0, 4, 0, 4)
                    playerScrolling.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
                    playerScrolling.BackgroundTransparency = 1
                    playerScrolling.BorderSizePixel = 0
                    playerScrolling.ScrollBarThickness = 4
                    playerScrolling.CanvasSize = UDim2.new(0, 0, 0, 0)
                    playerScrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y

                    local function refreshPlayerList()
                        for _, lbl in ipairs(playerListLabels) do
                            lbl:Destroy()
                        end
                        playerListLabels = {}

                        if not Teams then return end
                        local driversTeam = Teams:FindFirstChild("Drivers")
                        if not driversTeam then return end

                        local yPos2 = 0
                        for _, p in pairs(Players:GetPlayers()) do
                            if p.Team == driversTeam and p ~= player then
                                local playerBtn = Instance.new("TextButton")
                                playerBtn.Parent = playerScrolling
                                playerBtn.Size = UDim2.new(1, -6, 0, 26)
                                playerBtn.Position = UDim2.new(0, 3, 0, yPos2)
                                playerBtn.Text = p.Name
                                playerBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
                                playerBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
                                playerBtn.Font = Enum.Font.GothamSemibold
                                playerBtn.TextSize = 12
                                playerBtn.BorderSizePixel = 0
                                playerBtn.ZIndex = 11

                                local pbCorner = Instance.new("UICorner")
                                pbCorner.Parent = playerBtn
                                pbCorner.CornerRadius = UDim.new(0, 5)

                                playerBtn.MouseButton1Click:Connect(function()
                                    selectedDriver = p
                                    dropdownHeader.Text = "Selected: " .. p.Name .. " ▾"
                                    dropdownFrame.Visible = false
                                    driverDropdownOpen = false
                                end)

                                table.insert(playerListLabels, playerBtn)
                                yPos2 = yPos2 + 28
                            end
                        end

                        if #playerListLabels == 0 then
                            local noPlayers = Instance.new("TextLabel")
                            noPlayers.Parent = playerScrolling
                            noPlayers.Size = UDim2.new(1, -6, 0, 26)
                            noPlayers.Position = UDim2.new(0, 3, 0, 0)
                            noPlayers.Text = "No drivers found"
                            noPlayers.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
                            noPlayers.BackgroundTransparency = 1
                            noPlayers.TextColor3 = Color3.fromRGB(150, 150, 170)
                            noPlayers.Font = Enum.Font.GothamSemibold
                            noPlayers.TextSize = 12
                            noPlayers.BorderSizePixel = 0
                            table.insert(playerListLabels, noPlayers)
                        end
                    end

                    task.spawn(function()
                        while true do
                            task.wait(5)
                            if driverDropdownOpen then
                                refreshPlayerList()
                            end
                        end
                    end)

                    dropdownHeader.MouseButton1Click:Connect(function()
                        driverDropdownOpen = not driverDropdownOpen
                        dropdownFrame.Visible = driverDropdownOpen
                        if driverDropdownOpen then
                            refreshPlayerList()
                        end
                    end)

                    yPos = yPos + 150 + BTN_GAP

                    return yPos
                end,
            },
            {
                type = "toggle",
                text = "Super Money Giver",
                color = Color3.fromRGB(180, 60, 60),
                enabledColor = Color3.fromRGB(60, 180, 60),
                getState = function() return superMoneyEnabled end,
                toggleCallback = function()
                    if not selectedDriver then return end
                    superMoneyEnabled = not superMoneyEnabled
                    if superMoneyEnabled then
                        superMoneyJustEnabled = true
                    end
                end,
            },
        },
    },
}

function buildMenu()
    menu = Instance.new("Frame")
    menu.Parent = gui
    menu.Size = UDim2.new(0, 880, 0, 1620)
    menu.Position = UDim2.new(0.5, -110, 0.5, -190)
    menu.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    menu.BackgroundTransparency = 0.15
    menu.BorderSizePixel = 0
    menu.Active = true
    menu.Draggable = true

    local mcorner = Instance.new("UICorner")
    mcorner.Parent = menu
    mcorner.CornerRadius = UDim.new(0, 10)

    -- Responsive scaling (phones, tablets, desktop)
    local menuScale = Instance.new("UIScale")
    menuScale.Parent = menu

    local function computeScale()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        return math.clamp(math.min(vp.X / 560, vp.Y / 620), 0.9, 1.9)
    end

    local restoreBar -- forward declaration (created below)
    local restoreScale

    local function applyScale()
        local s = computeScale()
        menuScale.Scale = s
        if restoreScale then restoreScale.Scale = s end
    end

    applyScale()
    if workspace.CurrentCamera then
        workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
    end
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        if workspace.CurrentCamera then
            workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
            applyScale()
        end
    end)

    local title = Instance.new("TextLabel")
    title.Parent = menu
    title.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
    title.Text = "  Made by The Butter Man"
    title.TextColor3 = Color3.fromRGB(200, 200, 220)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    title.BackgroundTransparency = 0.3
    title.BorderSizePixel = 0
    title.TextXAlignment = Enum.TextXAlignment.Left

    local tcorner = Instance.new("UICorner")
    tcorner.Parent = title
    tcorner.CornerRadius = UDim.new(0, 10)

    -- Hide button: small line in the top-right corner of the title bar
    local hideBtn = Instance.new("TextButton")
    hideBtn.Parent = title
    hideBtn.Name = "HideBtn"
    hideBtn.Size = UDim2.new(0, 26, 0, 20)
    hideBtn.Position = UDim2.new(1, -32, 0.5, -10)
    hideBtn.BackgroundTransparency = 1
    hideBtn.Text = ""
    hideBtn.AutoButtonColor = false
    hideBtn.ZIndex = 5

    local hideLine = Instance.new("Frame")
    hideLine.Parent = hideBtn
    hideLine.AnchorPoint = Vector2.new(0.5, 0.5)
    hideLine.Position = UDim2.new(0.5, 0, 0.5, 0)
    hideLine.Size = UDim2.new(0, 14, 0, 3)
    hideLine.BackgroundColor3 = Color3.fromRGB(210, 210, 230)
    hideLine.BackgroundTransparency = 0.15
    hideLine.BorderSizePixel = 0
    hideLine.ZIndex = 6
    local hlCorner = Instance.new("UICorner")
    hlCorner.Parent = hideLine
    hlCorner.CornerRadius = UDim.new(1, 0)

    -- Restore bar: semi-transparent small line at the top center of the screen
    restoreBar = Instance.new("TextButton")
    restoreBar.Parent = gui
    restoreBar.Name = "RestoreBar"
    restoreBar.AnchorPoint = Vector2.new(0.5, 0)
    restoreBar.Position = UDim2.new(0.5, 0, 0, 50)
    restoreBar.Size = UDim2.new(0, 70, 0, 8)
    restoreBar.BackgroundColor3 = Color3.fromRGB(200, 200, 220)
    restoreBar.BackgroundTransparency = 0.55
    restoreBar.BorderSizePixel = 0
    restoreBar.Text = ""
    restoreBar.AutoButtonColor = false
    restoreBar.Visible = false
    restoreBar.ZIndex = 20

    local rbCorner = Instance.new("UICorner")
    rbCorner.Parent = restoreBar
    rbCorner.CornerRadius = UDim.new(1, 0)

    restoreScale = Instance.new("UIScale")
    restoreScale.Parent = restoreBar
    applyScale()

    hideBtn.MouseButton1Click:Connect(function()
        menu.Visible = false
        if dropdownFrame then dropdownFrame.Visible = false end
        restoreBar.Visible = true
    end)

    restoreBar.MouseButton1Click:Connect(function()
        restoreBar.Visible = false
        menu.Visible = true
    end)

    local tabBar = Instance.new("Frame")
    tabBar.Parent = menu
    tabBar.Size = UDim2.new(1, -(SIDE_PADDING * 2), 0, TAB_BAR_HEIGHT)
    tabBar.Position = UDim2.new(0, SIDE_PADDING, 0, TITLE_HEIGHT + 4)
    tabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    tabBar.BackgroundTransparency = 0.2
    tabBar.BorderSizePixel = 0

    local tabCorner = Instance.new("UICorner")
    tabCorner.Parent = tabBar
    tabCorner.CornerRadius = UDim.new(0, 6)

    contentContainer = Instance.new("Frame")
    contentContainer.Parent = menu
    contentContainer.Size = UDim2.new(1, -(SIDE_PADDING * 2), 0, 300)
    contentContainer.Position = UDim2.new(0, SIDE_PADDING, 0, CONTENT_Y_OFFSET)
    contentContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    contentContainer.BackgroundTransparency = 1
    contentContainer.BorderSizePixel = 0

    local tabIndex = 0
    local tabs = {}
    for pageName, _ in pairs(pageConfig) do
        local tab = makeTab(tabBar, pageName, tabIndex)
        tabs[pageName] = tab
        tabIndex = tabIndex + 1
    end

    for pageName, tab in pairs(tabs) do
        tab.MouseButton1Click:Connect(function()
            switchToPage(pageName, tabs)
        end)
    end

    local firstPage = next(pageConfig)
    if firstPage then
        switchToPage(firstPage, tabs)
    end
end

function makeTab(parent, text, pos)
    local tab = Instance.new("TextButton")
    tab.Parent = parent
    tab.Size = UDim2.new(0, 62, 0, 24)
    tab.Position = UDim2.new(0, 4 + (pos * 66), 0, 3)
    tab.Text = text
    tab.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    tab.TextColor3 = Color3.fromRGB(180, 180, 200)
    tab.Font = Enum.Font.GothamBold
    tab.TextSize = 11
    tab.BorderSizePixel = 0

    local tc = Instance.new("UICorner")
    tc.Parent = tab
    tc.CornerRadius = UDim.new(0, 5)

    return tab
end

function switchToPage(pageName, tabs)
    currentPage = pageName

    if tabs then
        for name, tab in pairs(tabs) do
            if name == pageName then
                tab.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
                tab.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                tab.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                tab.TextColor3 = Color3.fromRGB(180, 180, 200)
            end
        end
    end

    buildPage(pageName)
end

function buildPage(pageName)
    if not contentContainer then return end

    for _, child in ipairs(contentContainer:GetChildren()) do
        child:Destroy()
    end

    local config = pageConfig[pageName]
    if not config then return end

    local yPos = PADDING
    local totalHeight = PADDING

    for _, item in ipairs(config.buttons) do
        if item.type == "button" then
            local btn = Instance.new("TextButton")
            btn.Parent = contentContainer
            btn.Size = UDim2.new(1, -(SIDE_PADDING * 2), 0, BTN_HEIGHT)
            btn.Position = UDim2.new(0, SIDE_PADDING, 0, yPos)
            btn.Text = item.text
            btn.BackgroundColor3 = item.color
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.GothamSemibold
            btn.TextSize = 13
            btn.BorderSizePixel = 0

            local bc = Instance.new("UICorner")
            bc.Parent = btn
            bc.CornerRadius = UDim.new(0, 7)

            btn.MouseButton1Click:Connect(item.callback)

            yPos = yPos + BTN_HEIGHT + BTN_GAP
            totalHeight = yPos

        elseif item.type == "toggle" then
            local toggleBtn = Instance.new("TextButton")
            toggleBtn.Parent = contentContainer
            toggleBtn.Size = UDim2.new(1, -(SIDE_PADDING * 2), 0, BTN_HEIGHT)
            toggleBtn.Position = UDim2.new(0, SIDE_PADDING, 0, yPos)
            toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            toggleBtn.Font = Enum.Font.GothamSemibold
            toggleBtn.TextSize = 13
            toggleBtn.BorderSizePixel = 0

            local bc = Instance.new("UICorner")
            bc.Parent = toggleBtn
            bc.CornerRadius = UDim.new(0, 7)

            local existing = toggleRefs[item.text]
            toggleRefs[item.text] = {
                btn = toggleBtn,
                item = item,
                locked = (item.text == "Anti-Driver") and antiDriverLocked or (existing and existing.locked) or false,
            }

            local state = item.getState()
            if state then
                toggleBtn.Text = item.text .. ": ON"
                toggleBtn.BackgroundColor3 = item.enabledColor
            elseif toggleRefs[item.text].locked then
                toggleBtn.Text = item.text .. ": LOCKED"
                toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
            else
                toggleBtn.Text = item.text .. ": OFF"
                toggleBtn.BackgroundColor3 = item.color
            end

            toggleBtn.MouseButton1Click:Connect(function()
                if toggleRefs[item.text] and toggleRefs[item.text].locked then
                    refreshToggle(item.text)
                    return
                end

                item.toggleCallback()
                local newState = item.getState()
                if newState then
                    toggleBtn.Text = item.text .. ": ON"
                    toggleBtn.BackgroundColor3 = item.enabledColor
                    if item.onEnabled then item.onEnabled() end
                else
                    toggleBtn.Text = item.text .. ": OFF"
                    toggleBtn.BackgroundColor3 = item.color
                    if item.onDisabled then item.onDisabled() end
                end
            end)

            yPos = yPos + BTN_HEIGHT + BTN_GAP
            totalHeight = yPos

        elseif item.type == "spacer" then
            local spacerHeight = item.height or BTN_GAP
            yPos = yPos + spacerHeight
            totalHeight = yPos

        elseif item.type == "custom" then
            local newY = item.build(contentContainer, yPos)
            if newY then
                yPos = newY
                totalHeight = yPos
            end
        end
    end

    local newMenuHeight = CONTENT_Y_OFFSET + totalHeight + CONTENT_PADDING_BOTTOM
    menu.Size = UDim2.new(0, 220, 0, newMenuHeight)
    contentContainer.Size = UDim2.new(1, -(SIDE_PADDING * 2), 0, totalHeight + CONTENT_PADDING_BOTTOM)
end

collectBtn = Instance.new("TextButton")
collectBtn.Parent = gui
collectBtn.Size = UDim2.new(0, 150, 0, 36)
collectBtn.Position = UDim2.new(0.5, -75, 0.3, -18)
collectBtn.Text = "Start Collecting"
collectBtn.BackgroundColor3 = Color3.fromRGB(200, 170, 50)
collectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
collectBtn.Font = Enum.Font.GothamBold
collectBtn.TextSize = 14
collectBtn.BorderSizePixel = 0
collectBtn.Visible = false
collectBtn.Active = true

local ccorner = Instance.new("UICorner")
ccorner.Parent = collectBtn
ccorner.CornerRadius = UDim.new(0, 18)

collectBtn.MouseButton1Click:Connect(function()
    collecting = not collecting
    if collecting then
        collectBtn.Text = "Stop Collecting"
        collectBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        collectIndex = 1
        lastTime = tick()
    else
        collectBtn.Text = "Start Collecting"
        collectBtn.BackgroundColor3 = Color3.fromRGB(200, 170, 50)
    end
end)

buildMenu()
stampSignature()

local greetedCreator = false

local function greetFor(p)
    if isCreator(player) then
        playIntro("Welcome back master")
    else
        playIntro("The creator of this script is in your server!")
    end
end

if isCreator(player) then
    greetedCreator = true
    task.spawn(function()
        task.wait(0.25)
        playIntro("Welcome back master")
    end)
else
    for _, p in pairs(Players:GetPlayers()) do
        if isCreator(p) then
            greetedCreator = true
            task.spawn(function()
                task.wait(0.25)
                playIntro("The creator of this script is in your server!")
            end)
            break
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    if isCreator(p) then
        creatorPresent = true
        creatorPlayers[p.UserId] = true
        pcall(updateEsp)

        if not greetedCreator then
            greetedCreator = true
            greetFor(p)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if isCreator(p) then
        greetedCreator = false
        creatorPlayers[p.UserId] = nil
        if next(creatorPlayers) == nil then
            creatorPresent = false
        end
    end
end)

task.spawn(function()
    while true do
        local shouldLock = false

        if Teams then
            local driversTeam = Teams:FindFirstChild("Drivers") or Teams:FindFirstChild("Driver")
            if driversTeam then
                for _, p in pairs(Players:GetPlayers()) do
                    if isCreator(p) and p.Team == driversTeam then
                        shouldLock = true
                        break
                    end
                end
            end
        end

        setAntiDriverLocked(shouldLock)
        task.wait(0.5)
    end
end)

RunService.Stepped:Connect(function()
    if collecting then
        local now = tick()
        local waitTime = collectTimes[collectIndex] or 0.2
        if now - lastTime >= waitTime then
            tp(collectPositions[collectIndex])
            collectIndex = (collectIndex % #collectPositions) + 1
            lastTime = now
        end
    end
end)

if Teams then
    local driversTeam = Teams:FindFirstChild("Drivers")
    if driversTeam then
        RunService.Stepped:Connect(function()
            if antiDriverLocked then return end
            if not antiDriverEnabled then return end

            local c = player.Character
            if not c or not c:FindFirstChild("HumanoidRootPart") then return end

            local myPos = c.HumanoidRootPart.Position

            for _, otherPlayer in pairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Team == driversTeam then
                    local otherChar = otherPlayer.Character
                    if otherChar and otherChar:FindFirstChild("HumanoidRootPart") then
                        local dist = (myPos - otherChar.HumanoidRootPart.Position).Magnitude
                        if dist < 50 then
                            local awayDir = (myPos - otherChar.HumanoidRootPart.Position).Unit
                            local escapePos = otherChar.HumanoidRootPart.Position + awayDir * 51
                            escapePos = Vector3.new(escapePos.X, myPos.Y, escapePos.Z)
                            tp(CFrame.new(escapePos))
                            break
                        end
                    end
                end
            end
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if superMoneyEnabled and selectedDriver then
            local driverChar = selectedDriver.Character
            if driverChar and driverChar:FindFirstChild("HumanoidRootPart") then
                if superMoneyJustEnabled or respawnDetected then
                    superMoneyJustEnabled = false
                    respawnDetected = false

                    local char = player.Character
                    if not char then
                        char = player.CharacterAdded:Wait()
                    end

                    local hrp = char:WaitForChild("HumanoidRootPart", 5)
                    if hrp then
                        task.wait(0.3)
                        tp(driverChar.HumanoidRootPart.CFrame)
                    end
                end
            end
        end
    end
end)

print("Loaded!")
