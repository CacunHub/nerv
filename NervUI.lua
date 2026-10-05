--[[
    NervUI v2  -  rebuild of the "NERV / DEV" Grand Piece Online menu
    Built at the screenshot's own proportions (644x376) and scaled up with UIScale.

    local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/CacunHub/nerv/refs/heads/main/NervUI.lua"))()

    local Window = Library:CreateWindow({
        Title = "NERV / DEV", Subtitle = "Grand Piece Online",
        Logo = nil,                      -- rbxassetid:// (falls back to a star glyph)
        Watermark = "Developer Mode",    -- nil = off
        ToggleKey = Enum.KeyCode.RightShift,
        Scale = 1.2,                     -- UI scale (1 = screenshot size)
        Transparency = 0.05,             -- panel transparency (0 = solid)
        BannerTexture = nil,             -- optional tiled rbxassetid:// for the blue banners
        FontFamily = nil,                -- default Inter
    })

    local Tab  = Window:AddTab("Farm", { Glyph = "x", Icon = nil, OnMenu = function() end })
    local Page = Tab:AddPage("Bosses")
    local Sec  = Page:AddSection("Bounty Farm", "Left")   -- title nil = no banner

    Sec:AddToggle  ({ Title, Default, BoldWhenOn, Flag }, cb(bool))        -> { Set, Get }
    Sec:AddButton  ({ Title }, cb())                                        -> { Fire, SetText }
    Sec:AddLabel   ({ Title })                                              -> { SetText, SetColor }
    Sec:AddTextBox ({ Title, Default, Placeholder, Flag }, cb(text))        -> { Set, Get }
    Sec:AddSlider  ({ Title, Min, Max, Default, Decimals, Flag }, cb(n))    -> { Set, Get }
    Sec:AddDropdown({ Title, Options, Default, Multi, Flag }, cb(v))        -> { Set, Get, Refresh }
    Sec:AddKeybind ({ Title, Default, ToggleUI, Flag }, cb())               -> { Set, Get }

    Set(v, true) also fires the callback (SaveManager). Controls register in Library.Flags[Flag].
    FeralLib aliases: CreateMain / CreatePage / CreateSection / CreateToggle / CreateButton /
    CreateLabel / CreateBox / CreateSlider / CreateDropdown / CreateBind / CreateNoti.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local player = Players.LocalPlayer

local Library = {
    Theme = {
        Body = Color3.fromRGB(9, 10, 13),
        Panel = Color3.fromRGB(15, 17, 22),
        Card = Color3.fromRGB(13, 15, 20),
        Element = Color3.fromRGB(21, 23, 30),
        Border = Color3.fromRGB(30, 33, 42),
        Accent = Color3.fromRGB(59, 114, 222),
        Text = Color3.fromRGB(235, 237, 242),
        TextOff = Color3.fromRGB(176, 180, 190),
        Dim = Color3.fromRGB(118, 123, 136),
        Off = Color3.fromRGB(26, 28, 36),
        KnobOff = Color3.fromRGB(62, 65, 76),
    },
    Windows = {},
    Flags = {},
    FontFamily = "rbxasset://fonts/families/Inter.json",
}
local T = Library.Theme

--------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------
local WEIGHTS = {
    Regular = Enum.FontWeight.Regular, Medium = Enum.FontWeight.Medium,
    SemiBold = Enum.FontWeight.SemiBold, Bold = Enum.FontWeight.Bold,
}
local FALLBACK = {
    Regular = Enum.Font.Gotham, Medium = Enum.Font.GothamMedium,
    SemiBold = Enum.Font.GothamBold, Bold = Enum.Font.GothamBold,
}
local function setWeight(inst, w)
    local ok = pcall(function() inst.FontFace = Font.new(Library.FontFamily, WEIGHTS[w] or WEIGHTS.Regular) end)
    if not ok then inst.Font = FALLBACK[w] or Enum.Font.Gotham end
end

local function getParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    local ok2 = pcall(function() return game:GetService("CoreGui").Name end)
    if ok2 then return game:GetService("CoreGui") end
    return player:WaitForChild("PlayerGui")
end

-- props.W = font weight name ("Regular" | "Medium" | "SemiBold" | "Bold")
local function new(class, props, kids)
    local i = Instance.new(class)
    if i:IsA("GuiBase2d") then i.AutoLocalize = false end
    local weight
    for k, v in pairs(props or {}) do
        if k == "W" then weight = v else i[k] = v end
    end
    if weight then setWeight(i, weight) end
    for _, c in ipairs(kids or {}) do c.Parent = i end
    return i
end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function stroke(c, th, tr)
    return new("UIStroke", { Color = c, Thickness = th or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function pad(l, t, r, b)
    return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b) })
end
local function list(padding, dir)
    return new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, padding or 0),
        FillDirection = dir or Enum.FillDirection.Vertical })
end
local function tween(o, props, t)
    TweenService:Create(o, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function shade(c, k)
    if k >= 0 then return c:Lerp(Color3.new(1, 1, 1), k) end
    return c:Lerp(Color3.new(0, 0, 0), -k)
end
local function inside(g, pos)
    local p, s = g.AbsolutePosition, g.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

local function keyName(k)
    if not k then return "None" end
    local s = tostring(k):gsub("Enum%.KeyCode%.", ""):gsub("Enum%.UserInputType%.", "")
    return (s:gsub("MouseButton", "MB"))
end
local function toKey(v)
    if typeof(v) == "EnumItem" then return v end
    if type(v) == "string" then
        local n = v:gsub("^Enum%.KeyCode%.", ""):gsub("^Enum%.UserInputType%.", "")
        local ok, r = pcall(function() return Enum.KeyCode[n] end)
        if ok and r then return r end
        ok, r = pcall(function() return Enum.UserInputType[n] end)
        if ok and r then return r end
    end
    return nil
end

-- accent registry: Library:SetAccent recolors everything live
local accentFns = {}
local function onAccent(fn)
    accentFns[#accentFns + 1] = fn
    fn(T.Accent)
end
function Library:SetAccent(c)
    T.Accent = c
    for _, fn in ipairs(accentFns) do pcall(fn, c) end
end

-- flat blue banner with soft diagonal ripples (brand card + groupbox headers)
local function paintBanner(frame, radius, texture)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    local g = new("UIGradient", { Rotation = 0, Parent = frame })
    onAccent(function(c)
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, shade(c, -0.18)),
            ColorSequenceKeypoint.new(0.5, shade(c, 0.04)),
            ColorSequenceKeypoint.new(1, shade(c, -0.14)),
        })
    end)
    local ov = new("Frame", { Name = "Ripples", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, Parent = frame }, { corner(radius) })
    new("UIGradient", { Rotation = 24, Parent = ov, Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.94), NumberSequenceKeypoint.new(0.10, 0.84), NumberSequenceKeypoint.new(0.20, 0.95),
        NumberSequenceKeypoint.new(0.32, 0.82), NumberSequenceKeypoint.new(0.44, 0.95), NumberSequenceKeypoint.new(0.57, 0.80),
        NumberSequenceKeypoint.new(0.70, 0.95), NumberSequenceKeypoint.new(0.84, 0.84), NumberSequenceKeypoint.new(1, 0.94),
    }) })
    if texture then
        new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = texture, ImageTransparency = 0.7,
            ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(64, 64), Parent = frame }, { corner(radius) })
    end
end

local function register(prefix, opts, obj, kind)
    obj.Type = kind
    local flag = opts.Flag
    if not flag then
        local base = prefix .. tostring(opts.Title)
        flag = base
        local n = 1
        while Library.Flags[flag] do
            n = n + 1
            flag = base .. "#" .. n
        end
    end
    obj.Flag = flag
    Library.Flags[flag] = obj
    return obj
end

--------------------------------------------------------------------
-- notifications
--------------------------------------------------------------------
local notiGui, notiHolder
function Library:CreateNoti(cfg)
    cfg = cfg or {}
    if not (notiGui and notiGui.Parent) then
        notiGui = new("ScreenGui", { Name = "NervNotifications", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 200, Parent = getParent() })
        notiHolder = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(250, 400),
            BackgroundTransparency = 1, Parent = notiGui },
            { new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
    end
    local card = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Card,
        BorderSizePixel = 0, Parent = notiHolder }, { corner(5), stroke(T.Border), pad(10, 8, 10, 8), list(2) })
    local title = new("TextLabel", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, W = "Bold", TextSize = 13,
        Text = tostring(cfg.Title or "NERV"), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = card })
    onAccent(function(c) title.TextColor3 = shade(c, 0.2) end)
    new("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, W = "Regular",
        TextSize = 12, TextWrapped = true, TextColor3 = T.TextOff, TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(cfg.Desc or ""),
        LayoutOrder = 2, Parent = card })
    task.delay(cfg.ShowTime or 4, function() card:Destroy() end)
end

--------------------------------------------------------------------
-- window
--------------------------------------------------------------------
function Library:CreateWindow(cfg)
    cfg = cfg or {}
    Library.Flags = {}
    if cfg.FontFamily then Library.FontFamily = cfg.FontFamily end
    local parent = getParent()
    if parent:FindFirstChild("NervUI") then parent.NervUI:Destroy() end

    local W, H = 644, 376                   -- screenshot proportions
    local scaleValue = cfg.Scale or 1.2
    local panelT = cfg.Transparency or 0.05
    local conns = {}
    local function track(c) conns[#conns + 1] = c return c end

    local gui = new("ScreenGui", { Name = "NervUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent })
    local main = new("Frame", { Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
    local uiscale = new("UIScale", { Scale = scaleValue, Parent = main })
    local overlay = new("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50, Parent = main })

    local Window = { Gui = gui, Main = main, Tabs = {}, Selected = nil }

    local function draggable(handle)
        local dragging, start, startPos
        handle.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, start, startPos = true, i.Position, main.Position
            end
        end)
        track(UIS.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - start
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end))
        track(UIS.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end))
    end

    ----------------------------------------------------------------
    -- header cards: brand | profile | time | fps   (38px tall)
    ----------------------------------------------------------------
    local HEADER_H = 38
    local header = new("Frame", { Name = "Header", Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(W - 16, HEADER_H),
        BackgroundTransparency = 1, Parent = main }, { list(8, Enum.FillDirection.Horizontal) })

    local totalW = (W - 16) - 24
    local brandW = math.floor(totalW * 0.245)
    local otherW = math.floor((totalW - brandW) / 3)

    local function card(w, order)
        local f = new("Frame", { Size = UDim2.fromOffset(w, HEADER_H), BackgroundColor3 = T.Card, BackgroundTransparency = panelT,
            BorderSizePixel = 0, LayoutOrder = order, Parent = header }, { corner(5), stroke(T.Border) })
        draggable(f)
        return f
    end
    local function txt(parentF, props)
        props.BackgroundTransparency = 1
        props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
        props.ZIndex = props.ZIndex or 2
        props.Parent = parentF
        return new("TextLabel", props)
    end
    -- filled dark-blue circle with a light-blue ring + glyph/hands
    local function iconCircle(parentF, kind)
        local c = new("Frame", { Position = UDim2.fromOffset(9, 7), Size = UDim2.fromOffset(24, 24), BorderSizePixel = 0, Parent = parentF }, { corner(12) })
        onAccent(function(a) c.BackgroundColor3 = shade(a, -0.62) end)
        local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
            BackgroundTransparency = 1, Parent = c }, { corner(7) })
        local rs = stroke(T.Accent, 1.5)
        rs.Parent = ring
        local parts = {}
        if kind == "clock" then
            parts[#parts + 1] = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1, 4),
                BorderSizePixel = 0, Parent = ring })
            parts[#parts + 1] = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 1),
                BorderSizePixel = 0, Parent = ring })
        else
            parts[#parts + 1] = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, W = "Bold", Text = "i", TextSize = 10, Parent = ring })
        end
        onAccent(function(a)
            local light = shade(a, 0.45)
            rs.Color = light
            for _, p in ipairs(parts) do
                if p:IsA("TextLabel") then p.TextColor3 = light else p.BackgroundColor3 = light end
            end
        end)
        return c
    end

    -- brand
    local brand = card(brandW, 1)
    brand:FindFirstChildOfClass("UIStroke"):Destroy()
    brand.BackgroundTransparency = 0
    paintBanner(brand, 5)
    local bs = stroke(T.Accent, 1)
    bs.Parent = brand
    onAccent(function(a) bs.Color = shade(a, 0.28) end)
    if cfg.Logo then
        new("ImageLabel", { Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Image = cfg.Logo, ZIndex = 2, Parent = brand })
    else
        txt(brand, { Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(30, HEADER_H), W = "Bold", Text = "\u{2726}", TextSize = 24,
            TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center })
    end
    txt(brand, { Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -50, 0, 14), W = "Bold", TextSize = 11,
        Text = tostring(cfg.Title or "NERV / DEV"), TextColor3 = Color3.new(1, 1, 1), TextTruncate = Enum.TextTruncate.AtEnd })
    txt(brand, { Position = UDim2.fromOffset(46, 20), Size = UDim2.new(1, -50, 0, 12), W = "Medium", TextSize = 9,
        Text = tostring(cfg.Subtitle or ""), TextColor3 = Color3.fromRGB(222, 232, 252), TextTruncate = Enum.TextTruncate.AtEnd })

    -- profile
    local prof = card(otherW, 2)
    local avatar = new("ImageLabel", { Position = UDim2.fromOffset(9, 6), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = T.Off,
        BorderSizePixel = 0, Parent = prof }, { corner(4) })
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and avatar.Parent then avatar.Image = img end
    end)
    txt(prof, { Position = UDim2.fromOffset(45, 6), Size = UDim2.new(1, -50, 0, 14), W = "Bold", TextSize = 10,
        Text = player.DisplayName, TextColor3 = T.Text, TextTruncate = Enum.TextTruncate.AtEnd })
    txt(prof, { Position = UDim2.fromOffset(45, 20), Size = UDim2.new(1, -50, 0, 12), W = "Medium", TextSize = 9,
        Text = "@" .. player.Name, TextColor3 = T.Dim, TextTruncate = Enum.TextTruncate.AtEnd })

    -- time
    local timeCard = card(otherW, 3)
    iconCircle(timeCard, "clock")
    local timeLbl = txt(timeCard, { Position = UDim2.fromOffset(42, 6), Size = UDim2.new(1, -46, 0, 14), W = "Bold", TextSize = 10,
        Text = "TIME: --:--:--", TextColor3 = T.Text, TextTruncate = Enum.TextTruncate.AtEnd })
    local dateLbl = txt(timeCard, { Position = UDim2.fromOffset(42, 20), Size = UDim2.new(1, -46, 0, 12), W = "Medium", TextSize = 9,
        Text = "Date: --", TextColor3 = T.Dim, TextTruncate = Enum.TextTruncate.AtEnd })

    -- fps / ping
    local fpsCard = card(otherW, 4)
    iconCircle(fpsCard, "info")
    local fpsLbl = txt(fpsCard, { Position = UDim2.fromOffset(42, 6), Size = UDim2.new(1, -46, 0, 14), W = "Bold", TextSize = 10,
        Text = "FPS: 0", TextColor3 = T.Text })
    local pingLbl = txt(fpsCard, { Position = UDim2.fromOffset(42, 20), Size = UDim2.new(1, -46, 0, 12), W = "Medium", TextSize = 9,
        Text = "Ping: 0 ms", TextColor3 = T.Dim })

    local frames, lastTick = 0, os.clock()
    track(RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = os.clock()
        if now - lastTick < 0.25 then return end
        local fps = math.floor(frames / (now - lastTick) + 0.5)
        frames, lastTick = 0, now
        if not gui.Enabled then return end
        local ping = 0
        pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
        timeLbl.Text = "TIME: " .. os.date("%H:%M:%S")
        dateLbl.Text = "Date: " .. os.date("%d.%m.%Y")
        fpsLbl.Text = "FPS: " .. fps
        pingLbl.Text = "Ping: " .. ping .. " ms"
    end))

    ----------------------------------------------------------------
    -- body panel (translucent) holding rail + content
    ----------------------------------------------------------------
    local BODY_Y, BODY_H = 54, 300
    local body = new("Frame", { Name = "Body", Position = UDim2.fromOffset(8, BODY_Y), Size = UDim2.fromOffset(W - 16, BODY_H),
        BackgroundColor3 = T.Body, BackgroundTransparency = panelT, BorderSizePixel = 0, Parent = main }, { corner(6), stroke(T.Border) })

    local RAIL_W = 108
    local rail = new("Frame", { Name = "Rail", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(RAIL_W, BODY_H - 16),
        BackgroundTransparency = 1, Parent = body }, { list(2) })
    draggable(rail)

    local CX = 8 + RAIL_W + 7
    local content = new("Frame", { Name = "Content", Position = UDim2.fromOffset(CX, 8), Size = UDim2.fromOffset(W - 16 - CX - 8, BODY_H - 14),
        BackgroundTransparency = 1, Parent = body })

    if cfg.Watermark then
        local wm = new("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -3), Size = UDim2.fromOffset(0, 14),
            AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, W = "Bold", TextSize = 11, TextColor3 = Color3.new(1, 1, 1),
            Text = tostring(cfg.Watermark), Parent = main })
        new("UIGradient", { Parent = wm, Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(176, 96, 255)),
            ColorSequenceKeypoint.new(0.45, Color3.fromRGB(240, 110, 190)),
            ColorSequenceKeypoint.new(0.62, Color3.fromRGB(90, 170, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 130, 255)),
        }) })
    end

    ----------------------------------------------------------------
    -- dropdown popup management (popups live in `overlay`, inside the scaled window)
    ----------------------------------------------------------------
    local openPopup
    local function closePopup()
        if openPopup then
            openPopup.frame.Visible = false
            openPopup = nil
        end
    end
    track(UIS.InputBegan:Connect(function(i)
        if openPopup and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            local m = UIS:GetMouseLocation()
            if not inside(openPopup.frame, m) and not inside(openPopup.box, m) then closePopup() end
        end
    end))

    ----------------------------------------------------------------
    -- toggle key
    ----------------------------------------------------------------
    local toggleKey = toKey(cfg.ToggleKey) or Enum.KeyCode.RightShift
    local function setToggleKey(k) k = toKey(k) if k then toggleKey = k end end
    local rebinding = false
    track(UIS.InputBegan:Connect(function(i)
        if rebinding then return end
        if i.KeyCode == toggleKey or i.UserInputType == toggleKey then
            if UIS:GetFocusedTextBox() then return end
            closePopup()
            gui.Enabled = not gui.Enabled
        end
    end))

    function Window:Toggle(state)
        if state == nil then state = not gui.Enabled end
        gui.Enabled = state
    end
    function Window:SetToggleKey(k) setToggleKey(k) end
    function Window:SetScale(s) uiscale.Scale = s end
    function Window:Destroy()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        gui:Destroy()
    end

    ----------------------------------------------------------------
    -- tab (rail entry) -> pages (top tabs) -> sections (groupboxes)
    ----------------------------------------------------------------
    function Window:AddTab(name, topts)
        topts = topts or {}
        local Tab = { Name = name, Pages = {}, Current = nil }

        local item = new("Frame", { Name = name .. "_Tab", Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.Accent, BackgroundTransparency = 1,
            BorderSizePixel = 0, LayoutOrder = #Window.Tabs + 1, Parent = rail }, { corner(3) })
        local st = new("UIStroke", { Thickness = 1, Transparency = 1, Color = T.Border, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = item })
        onAccent(function(c) item.BackgroundColor3 = shade(c, -0.55) end)
        local leftBar = new("Frame", { Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = item })
        onAccent(function(c) leftBar.BackgroundColor3 = c end)

        local icon
        if topts.Icon then
            icon = new("ImageLabel", { Position = UDim2.fromOffset(9, 8), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1,
                Image = topts.Icon, ImageColor3 = T.TextOff, Parent = item })
        else
            icon = new("TextLabel", { Position = UDim2.fromOffset(7, 0), Size = UDim2.fromOffset(20, 32), BackgroundTransparency = 1,
                W = "Bold", Text = topts.Glyph or string.sub(name, 1, 1), TextSize = 15, TextColor3 = T.TextOff, Parent = item })
        end
        local label = new("TextLabel", { Position = UDim2.fromOffset(31, 0), Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1,
            W = "Medium", Text = name, TextSize = 10, TextColor3 = T.TextOff, TextXAlignment = Enum.TextXAlignment.Left, Parent = item })
        local click = new("TextButton", { Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, Text = "", Parent = item })

        -- three-dot menu button
        local dots = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.fromOffset(16, 28),
            BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = item })
        local dotFrames = {}
        for d = 0, 2 do
            dotFrames[#dotFrames + 1] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, (d - 1) * 4.5),
                Size = UDim2.fromOffset(2, 2), BackgroundColor3 = T.TextOff, BorderSizePixel = 0, ZIndex = 3, Parent = dots }, { corner(1) })
        end
        dots.MouseEnter:Connect(function() for _, f in ipairs(dotFrames) do tween(f, { BackgroundColor3 = T.Accent }, 0.1) end end)
        dots.MouseLeave:Connect(function() for _, f in ipairs(dotFrames) do tween(f, { BackgroundColor3 = T.TextOff }, 0.1) end end)
        dots.MouseButton1Click:Connect(function() if topts.OnMenu then task.spawn(topts.OnMenu, Tab) end end)

        local function paint(on)
            tween(item, { BackgroundTransparency = on and 0.35 or 1 }, 0.15)
            tween(st, { Transparency = on and 0 or 1 }, 0.15)
            tween(leftBar, { BackgroundTransparency = on and 0 or 1 }, 0.15)
            tween(label, { TextColor3 = on and T.Text or T.TextOff }, 0.15)
            if icon:IsA("ImageLabel") then tween(icon, { ImageColor3 = on and T.Accent or T.TextOff }, 0.15)
            else tween(icon, { TextColor3 = on and T.Accent or T.TextOff }, 0.15) end
        end

        -- page tab bar (only visible while this rail tab is selected)
        local bar = new("Frame", { Name = name .. "_Pages", Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Visible = false, Parent = content },
            { pad(11, 0, 0, 0), list(22, Enum.FillDirection.Horizontal) })

        function Tab:_hide()
            paint(false)
            bar.Visible = false
            if Tab.Current then Tab.Current.Scroll.Visible = false end
        end
        function Tab:Select()
            closePopup()
            if Window.Selected and Window.Selected ~= Tab then Window.Selected:_hide() end
            Window.Selected = Tab
            paint(true)
            bar.Visible = true
            if Tab.Current then Tab.Current:Select() end
        end
        click.MouseButton1Click:Connect(function() Tab:Select() end)

        function Tab:AddPage(pname)
            local Page = { Name = pname, Sections = {} }

            local btn = new("TextButton", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
                W = "Medium", Text = pname, TextSize = 10, TextColor3 = T.TextOff, LayoutOrder = #Tab.Pages + 1, Parent = bar })

            local scroll = new("ScrollingFrame", { Name = pname .. "_Scroll", Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26),
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = T.Border, Active = true,
                CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = content }, { pad(0, 0, 4, 4) })
            Page.Scroll = scroll
            scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(closePopup)

            local cols = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll },
                { list(10, Enum.FillDirection.Horizontal) })
            local function column(order)
                return new("Frame", { Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                    LayoutOrder = order, Parent = cols }, { list(8) })
            end
            local colL, colR = column(1), column(2)

            function Page:_paint(on)
                setWeight(btn, on and "Bold" or "Medium")
                btn.TextColor3 = on and T.Text or T.TextOff
                scroll.Visible = on and Window.Selected == Tab
            end
            function Page:Select()
                closePopup()
                if Tab.Current and Tab.Current ~= Page then Tab.Current:_paint(false) end
                Tab.Current = Page
                Page:_paint(true)
            end
            btn.MouseButton1Click:Connect(function() Page:Select() end)

            ------------------------------------------------------------
            -- section (groupbox)
            ------------------------------------------------------------
            function Page:AddSection(title, side)
                side = side or ((#Page.Sections % 2 == 0) and "Left" or "Right")
                local col = (side == "Right") and colR or colL
                local sec = new("Frame", { Name = tostring(title or "Section") .. "_Section", Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Panel, BackgroundTransparency = panelT, BorderSizePixel = 0,
                    LayoutOrder = #Page.Sections + 1, Parent = col }, { corner(4), stroke(T.Border), list(0) })
                Page.Sections[#Page.Sections + 1] = sec

                if title then
                    -- flat strip flush with the top edge of the group
                    local banner = new("Frame", { Size = UDim2.new(1, 0, 0, 15), BorderSizePixel = 0, LayoutOrder = 0, Parent = sec }, { corner(3) })
                    paintBanner(banner, 3, cfg.BannerTexture)
                    new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, W = "SemiBold", Text = title, TextSize = 9,
                        TextColor3 = Color3.fromRGB(236, 242, 255), ZIndex = 2, Parent = banner })
                end

                local sbody = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1,
                    Parent = sec }, { pad(10, 10, 10, 10), list(6) })

                local Section = {}
                local flagPrefix = Tab.Name .. "/" .. pname .. "/" .. tostring(title or "") .. "/"
                local n = 0
                local function nextOrder() n = n + 1 return n end
                local function noop() end

                -- small bold caption above a control
                local function caption(parentF, text, order)
                    return new("TextLabel", { Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1, W = "Bold", Text = text, TextSize = 10,
                        TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = parentF })
                end

                ---------------- toggle
                function Section:AddToggle(opts, callback)
                    callback = callback or opts.Callback or noop
                    local state = opts.Default or false
                    local boldOn = opts.BoldWhenOn ~= false
                    local row = new("Frame", { Name = "Toggle", Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = sbody })
                    local lbl = new("TextLabel", { Size = UDim2.new(1, -34, 1, 0), BackgroundTransparency = 1, W = "Medium", Text = opts.Title,
                        TextSize = 10, TextColor3 = T.TextOff, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
                    local pill = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(24, 13),
                        BackgroundColor3 = T.Off, BorderSizePixel = 0, Parent = row }, { corner(7) })
                    local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(9, 9),
                        BackgroundColor3 = T.KnobOff, BorderSizePixel = 0, Parent = pill }, { corner(5) })
                    local click = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = row })

                    local function paint(v)
                        tween(pill, { BackgroundColor3 = v and T.Accent or T.Off }, 0.15)
                        tween(knob, { Position = v and UDim2.new(1, -11, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
                            BackgroundColor3 = v and Color3.new(1, 1, 1) or T.KnobOff }, 0.15)
                        lbl.TextColor3 = v and T.Text or T.TextOff
                        setWeight(lbl, (v and boldOn) and "Bold" or "Medium")
                    end
                    onAccent(function(c) if state then pill.BackgroundColor3 = c end end)
                    click.MouseButton1Click:Connect(function()
                        state = not state
                        paint(state)
                        task.spawn(callback, state)
                    end)
                    paint(state)
                    return register(flagPrefix, opts, {
                        Set = function(_, v, fire) state = not not v paint(state) if fire then task.spawn(callback, state) end end,
                        Get = function() return state end,
                    }, "Toggle")
                end

                ---------------- button
                function Section:AddButton(opts, callback)
                    callback = callback or opts.Callback or noop
                    local b = new("TextButton", { Name = "Button", Size = UDim2.new(1, 0, 0, 23), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
                        AutoButtonColor = false, W = "Bold", Text = opts.Title, TextSize = 10, TextColor3 = Color3.new(1, 1, 1),
                        LayoutOrder = nextOrder(), Parent = sbody }, { corner(3) })
                    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(176, 188, 214)), Parent = b })
                    local bst = stroke(T.Accent, 1)
                    bst.Parent = b
                    onAccent(function(c) b.BackgroundColor3 = shade(c, 0.1) bst.Color = shade(c, 0.22) end)
                    b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = shade(T.Accent, 0.22) }, 0.1) end)
                    b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = shade(T.Accent, 0.1) }, 0.1) end)
                    b.MouseButton1Click:Connect(function() task.spawn(callback) end)
                    return { Fire = function() task.spawn(callback) end, SetText = function(_, s) b.Text = tostring(s) end }
                end

                ---------------- label (status line)
                function Section:AddLabel(opts)
                    local text = new("TextLabel", { Name = "Label", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                        W = "Regular", Text = tostring(type(opts) == "table" and opts.Title or opts), TextSize = 9, TextWrapped = true,
                        TextColor3 = T.TextOff, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(), Parent = sbody })
                    return {
                        SetText = function(_, s) text.Text = tostring(s) end,
                        SetColor = function(_, c) text.TextColor3 = c end,
                    }
                end

                ---------------- textbox
                function Section:AddTextBox(opts, callback)
                    callback = callback or opts.Callback or noop
                    local holder = new("Frame", { Name = "TextBox", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                        LayoutOrder = nextOrder(), Parent = sbody }, { list(5) })
                    if opts.Title then caption(holder, opts.Title, 0) end
                    local box = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = T.Element, BorderSizePixel = 0, LayoutOrder = 1, Parent = holder },
                        { corner(4) })
                    local bst = stroke(T.Border, 1)
                    bst.Parent = box
                    local input = new("TextBox", { Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -18, 1, 0), BackgroundTransparency = 1,
                        W = "Medium", TextSize = 10, TextColor3 = T.Text, Text = opts.Default or "", PlaceholderText = opts.Placeholder or "",
                        PlaceholderColor3 = T.Dim, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = box })
                    input.Focused:Connect(function() tween(bst, { Color = T.Accent }, 0.1) end)
                    input.FocusLost:Connect(function()
                        tween(bst, { Color = T.Border }, 0.1)
                        task.spawn(callback, input.Text)
                    end)
                    return register(flagPrefix, opts, {
                        Set = function(_, v, fire) input.Text = tostring(v) if fire then task.spawn(callback, input.Text) end end,
                        Get = function() return input.Text end,
                    }, "Box")
                end

                ---------------- slider
                function Section:AddSlider(opts, callback)
                    callback = callback or opts.Callback or noop
                    local min, max = opts.Min or 0, opts.Max or 100
                    local mult = 10 ^ (opts.Decimals or 0)
                    local function round(v) return math.floor(v * mult + 0.5) / mult end
                    local value = math.clamp(round(opts.Default or min), min, max)

                    local row = new("Frame", { Name = "Slider", Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = sbody })
                    new("TextLabel", { Size = UDim2.new(1, -50, 0, 13), BackgroundTransparency = 1, W = "Medium", Text = opts.Title, TextSize = 10,
                        TextColor3 = T.TextOff, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
                    local val = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(46, 13),
                        BackgroundTransparency = 1, W = "Bold", TextSize = 10, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
                    local track_ = new("Frame", { Position = UDim2.fromOffset(0, 19), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = T.Off, BorderSizePixel = 0,
                        Parent = row }, { corner(3) })
                    local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = track_ }, { corner(3) })
                    onAccent(function(c) fill.BackgroundColor3 = c end)
                    local hit = new("TextButton", { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 1, -14), BackgroundTransparency = 1, Text = "", Parent = row })

                    local function render(animate)
                        local a = (max == min) and 0 or (value - min) / (max - min)
                        if animate then tween(fill, { Size = UDim2.fromScale(a, 1) }, 0.1) else fill.Size = UDim2.fromScale(a, 1) end
                        val.Text = tostring(value)
                    end
                    local function setValue(v, fire, animate)
                        v = math.clamp(round(v), min, max)
                        local changed = v ~= value
                        value = v
                        render(animate)
                        if changed and fire then task.spawn(callback, value) end
                    end
                    local dragging = false
                    local function fromMouse()
                        local a = math.clamp((UIS:GetMouseLocation().X - track_.AbsolutePosition.X) / math.max(track_.AbsoluteSize.X, 1), 0, 1)
                        setValue(min + (max - min) * a, true)
                    end
                    hit.InputBegan:Connect(function(i)
                        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true fromMouse() end
                    end)
                    track(UIS.InputChanged:Connect(function(i)
                        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromMouse() end
                    end))
                    track(UIS.InputEnded:Connect(function(i)
                        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
                    end))
                    render()
                    return register(flagPrefix, opts, {
                        Set = function(_, v, fire) setValue(v, fire, true) end,
                        Get = function() return value end,
                    }, "Slider")
                end

                ---------------- dropdown
                function Section:AddDropdown(opts, callback)
                    callback = callback or opts.Callback or noop
                    local options = opts.Options or {}
                    local multi = opts.Multi and true or false

                    local function toSet(v)
                        local set = {}
                        if type(v) == "table" then
                            for k, val in pairs(v) do
                                if type(k) == "number" then set[val] = true elseif val then set[k] = true end
                            end
                        elseif v ~= nil then
                            set[v] = true
                        end
                        return set
                    end
                    local cur
                    if multi then cur = toSet(opts.Default) else cur = opts.Default or options[1] end

                    local function selectedList()
                        local out = {}
                        for _, name in ipairs(options) do if cur[name] then out[#out + 1] = name end end
                        return out
                    end
                    local function value() if multi then return selectedList() end return cur end
                    local function isSel(name) if multi then return cur[name] == true end return name == cur end

                    local holder = new("Frame", { Name = "Dropdown", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                        LayoutOrder = nextOrder(), Parent = sbody }, { list(5) })
                    if opts.Title then caption(holder, opts.Title, 0) end
                    local box = new("Frame", { Size = UDim2.new(1, 0, 0, 23), BackgroundColor3 = T.Element, BorderSizePixel = 0, LayoutOrder = 1, Parent = holder },
                        { corner(4) })
                    local bst = stroke(T.Border, 1)
                    bst.Parent = box
                    local vtext = new("TextLabel", { Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -30, 1, 0), BackgroundTransparency = 1, W = "Medium",
                        TextSize = 10, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = box })
                    -- up/down chevrons on the right
                    for idx, g in ipairs({ "\u{25B2}", "\u{25BC}" }) do
                        new("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, idx == 1 and -3 or 3), Size = UDim2.fromOffset(9, 6),
                            BackgroundTransparency = 1, W = "Regular", Text = g, TextSize = 6, TextColor3 = T.TextOff, Parent = box })
                    end
                    local dbtn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = box })

                    local popup = new("Frame", { Visible = false, BackgroundColor3 = T.Element, BorderSizePixel = 0, ZIndex = 60, Parent = overlay },
                        { corner(4), stroke(T.Border) })
                    local pscroll = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
                        ScrollBarImageColor3 = T.Border, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Active = true, ZIndex = 61, Parent = popup },
                        { pad(3, 3, 3, 3), list(0) })

                    local items = {}
                    local function refresh()
                        local text
                        if multi then
                            local names = {}
                            for _, nm in ipairs(selectedList()) do names[#names + 1] = tostring(nm) end
                            text = #names == 0 and "None" or table.concat(names, ", ")
                        else
                            text = cur == nil and "None" or tostring(cur)
                        end
                        vtext.Text = text
                        for name, it in pairs(items) do
                            it.dot.Visible = isSel(name)
                            it.label.TextColor3 = isSel(name) and T.Text or T.TextOff
                        end
                    end
                    local function rebuild()
                        for _, c in ipairs(pscroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                        items = {}
                        for i, name in ipairs(options) do
                            local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "", LayoutOrder = i, ZIndex = 62, Parent = pscroll })
                            local l = new("TextLabel", { Position = UDim2.fromOffset(7, 0), Size = UDim2.new(1, -22, 1, 0), BackgroundTransparency = 1, W = "Medium",
                                Text = tostring(name), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 62, Parent = b })
                            local dot = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(5, 5), BorderSizePixel = 0,
                                ZIndex = 62, Parent = b }, { corner(3) })
                            onAccent(function(c) dot.BackgroundColor3 = c end)
                            items[name] = { label = l, dot = dot }
                            b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.92, BackgroundColor3 = Color3.new(1, 1, 1) }, 0.08) end)
                            b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }, 0.08) end)
                            b.MouseButton1Click:Connect(function()
                                if multi then
                                    if cur[name] then cur[name] = nil else cur[name] = true end
                                else
                                    cur = name
                                    closePopup()
                                end
                                refresh()
                                task.spawn(callback, value())
                            end)
                        end
                        refresh()
                    end
                    rebuild()

                    dbtn.MouseButton1Click:Connect(function()
                        if openPopup and openPopup.frame == popup then closePopup() return end
                        closePopup()
                        local sc = uiscale.Scale
                        local pos = (box.AbsolutePosition - main.AbsolutePosition) / sc
                        local sz = box.AbsoluteSize / sc
                        local h = math.min(#options * 20 + 6, 126)
                        local y = pos.Y + sz.Y + 3
                        if y + h > H then y = pos.Y - h - 3 end
                        popup.Size = UDim2.fromOffset(sz.X, h)
                        popup.Position = UDim2.fromOffset(pos.X, y)
                        popup.Visible = true
                        openPopup = { frame = popup, box = box }
                    end)

                    return register(flagPrefix, opts, {
                        Multi = multi,
                        Set = function(_, v, fire)
                            if multi then cur = toSet(v) else cur = v end
                            refresh()
                            if fire then task.spawn(callback, value()) end
                        end,
                        Get = function() return value() end,
                        Refresh = function(_, newOptions, keep)
                            options = newOptions
                            if multi then
                                if not keep then cur = {} else
                                    for name in pairs(cur) do if not table.find(options, name) then cur[name] = nil end end
                                end
                            elseif not keep or not table.find(options, cur) then
                                cur = options[1]
                            end
                            rebuild()
                        end,
                    }, "Dropdown")
                end

                ---------------- keybind
                function Section:AddKeybind(opts, callback)
                    callback = callback or opts.Callback or noop
                    local key = toKey(opts.Default)
                    local listening = false
                    if opts.ToggleUI and key then setToggleKey(key) end

                    local row = new("Frame", { Name = "Keybind", Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = sbody })
                    new("TextLabel", { Size = UDim2.new(1, -80, 1, 0), BackgroundTransparency = 1, W = "Medium", Text = opts.Title, TextSize = 10,
                        TextColor3 = T.TextOff, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
                    local kb = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(70, 18),
                        BackgroundColor3 = T.Element, BorderSizePixel = 0, AutoButtonColor = false, W = "Bold", Text = keyName(key), TextSize = 9,
                        TextColor3 = T.Text, Parent = row }, { corner(4), stroke(T.Border) })

                    kb.MouseButton1Click:Connect(function()
                        if listening then return end
                        listening = true
                        rebinding = true
                        kb.Text = "..."
                        task.wait(0.1)
                        local conn
                        conn = UIS.InputBegan:Connect(function(i)
                            local picked
                            if i.UserInputType == Enum.UserInputType.Keyboard then
                                if i.KeyCode == Enum.KeyCode.Escape then picked = false
                                elseif i.KeyCode == Enum.KeyCode.Backspace then picked = "clear"
                                else picked = i.KeyCode end
                            elseif i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.MouseButton2
                                or i.UserInputType == Enum.UserInputType.MouseButton3 then
                                picked = i.UserInputType
                            end
                            if picked == nil then return end
                            conn:Disconnect()
                            task.defer(function() listening = false rebinding = false end)
                            if picked == "clear" then key = nil elseif picked ~= false then key = picked end
                            kb.Text = keyName(key)
                            if opts.ToggleUI and key then setToggleKey(key) end
                        end)
                    end)
                    track(UIS.InputBegan:Connect(function(i, gp)
                        if listening or gp or not key or opts.ToggleUI then return end
                        if i.KeyCode == key or i.UserInputType == key then task.spawn(callback, key) end
                    end))
                    return register(flagPrefix, opts, {
                        Set = function(_, k)
                            local nk = toKey(k)
                            if k == nil or nk then key = nk end
                            kb.Text = keyName(key)
                            if opts.ToggleUI and nk then setToggleKey(nk) end
                        end,
                        Get = function() return key end,
                    }, "Bind")
                end

                -- FeralLib aliases
                Section.CreateToggle, Section.CreateButton, Section.CreateLabel = Section.AddToggle, Section.AddButton, Section.AddLabel
                Section.CreateBox, Section.CreateSlider = Section.AddTextBox, Section.AddSlider
                Section.CreateDropdown, Section.CreateBind = Section.AddDropdown, Section.AddKeybind
                return Section
            end
            Page.CreateSection = Page.AddSection

            Tab.Pages[#Tab.Pages + 1] = Page
            if #Tab.Pages == 1 then Page:Select() end
            return Page
        end

        Window.Tabs[#Window.Tabs + 1] = Tab
        if #Window.Tabs == 1 then Tab:Select() end
        return Tab
    end

    -- FeralLib-style shortcut: one rail tab with a single page
    function Window:CreatePage(name)
        local tab = Window:AddTab(name)
        return tab:AddPage(name)
    end

    Library.Windows[#Library.Windows + 1] = Window
    return Window
end

Library.CreateMain = Library.CreateWindow

return Library
