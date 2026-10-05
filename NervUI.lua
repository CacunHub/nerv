--[[
    NervUI  -  rebuild of the "NERV / DEV" Grand Piece Online menu
    Layout from the Kicia UI (rail + page tabs + groupboxes), API from FeralLib.
    UI only: every control just calls your callback.

    local Library = loadstring(readfile("NervUI.lua"))()

    local Window = Library:CreateWindow({
        Title = "NERV / DEV", Subtitle = "Grand Piece Online",
        Logo = nil,                      -- rbxassetid:// (falls back to a glyph)
        Watermark = "Developer Mode",    -- first word purple, rest blue (nil = off)
        ToggleKey = Enum.KeyCode.RightShift,
        Size = Vector2.new(720, 440),
    })

    local Tab  = Window:AddTab("Farm", { Glyph = "x", Icon = nil, OnMenu = function() end })
    local Page = Tab:AddPage("Bosses")
    local Sec  = Page:AddSection("Bounty Farm", "Left")   -- title nil = no banner, side "Left"/"Right"

    Sec:AddToggle  ({ Title, Default, BoldWhenOn, Flag }, cb(bool))      -> { Set, Get }
    Sec:AddButton  ({ Title }, cb())                                      -> { Fire, SetText }
    Sec:AddLabel   ({ Title })                                            -> { SetText, SetColor }
    Sec:AddTextBox ({ Title, Default, Placeholder, Flag }, cb(text))      -> { Set, Get }
    Sec:AddSlider  ({ Title, Min, Max, Default, Decimals, Flag }, cb(n))  -> { Set, Get }
    Sec:AddDropdown({ Title, Options, Default, Multi, Flag }, cb(v))      -> { Set, Get, Refresh }
    Sec:AddKeybind ({ Title, Default, ToggleUI, Flag }, cb())             -> { Set, Get }

    Set(v, true) fires the callback too (SaveManager uses that).
    Every control is stored in Library.Flags[Flag]. Aliases for porting from FeralLib:
    CreateMain / CreatePage / CreateSection / CreateToggle / CreateButton / CreateLabel /
    CreateBox / CreateSlider / CreateDropdown / CreateBind / CreateNoti.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local player = Players.LocalPlayer

local Library = {
    Theme = {
        Bg = Color3.fromRGB(10, 11, 14),
        Panel = Color3.fromRGB(17, 18, 23),
        Element = Color3.fromRGB(24, 25, 32),
        Border = Color3.fromRGB(34, 36, 45),
        Accent = Color3.fromRGB(52, 112, 214),
        Text = Color3.fromRGB(228, 230, 236),
        TextOff = Color3.fromRGB(165, 169, 180),
        Dim = Color3.fromRGB(118, 123, 136),
        Off = Color3.fromRGB(42, 44, 53),
        KnobOff = Color3.fromRGB(105, 109, 121),
    },
    Windows = {},
    Flags = {},
}
local T = Library.Theme

--------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------
local function getParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    local ok2 = pcall(function() return game:GetService("CoreGui").Name end)
    if ok2 then return game:GetService("CoreGui") end
    return player:WaitForChild("PlayerGui")
end

local function new(class, props, kids)
    local i = Instance.new(class)
    if i:IsA("GuiBase2d") then i.AutoLocalize = false end
    for k, v in pairs(props or {}) do i[k] = v end
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

-- blue "water" banner used by the brand card and the groupbox headers
local function paintBanner(frame, radius, texture)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    local g = new("UIGradient", { Rotation = 0, Parent = frame })
    onAccent(function(c)
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, shade(c, -0.50)),
            ColorSequenceKeypoint.new(0.5, shade(c, 0.02)),
            ColorSequenceKeypoint.new(1, shade(c, -0.32)),
        })
    end)
    local ov = new("Frame", { Name = "Ripples", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, Parent = frame }, { corner(radius) })
    new("UIGradient", { Rotation = 28, Parent = ov, Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.93), NumberSequenceKeypoint.new(0.12, 0.80), NumberSequenceKeypoint.new(0.22, 0.95),
        NumberSequenceKeypoint.new(0.35, 0.78), NumberSequenceKeypoint.new(0.47, 0.94), NumberSequenceKeypoint.new(0.60, 0.76),
        NumberSequenceKeypoint.new(0.72, 0.95), NumberSequenceKeypoint.new(0.85, 0.82), NumberSequenceKeypoint.new(1, 0.93),
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
    local card = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Panel,
        BorderSizePixel = 0, Parent = notiHolder }, { corner(6), stroke(T.Border), pad(10, 8, 10, 8), list(2) })
    local title = new("TextLabel", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13,
        Text = tostring(cfg.Title or "NERV"), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = card })
    onAccent(function(c) title.TextColor3 = c end)
    new("TextLabel", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Font = Enum.Font.Gotham,
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
    local parent = getParent()
    if parent:FindFirstChild("NervUI") then parent.NervUI:Destroy() end

    local size = cfg.Size or Vector2.new(720, 440)
    local conns = {}
    local function track(c) conns[#conns + 1] = c return c end

    local gui = new("ScreenGui", { Name = "NervUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = parent })
    local main = new("Frame", { Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = T.Bg, BorderSizePixel = 0, Parent = gui },
        { corner(10), stroke(T.Border) })
    local overlay = new("Frame", { Name = "Overlay", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 50, Parent = gui })

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
    -- header cards: brand | profile | time | fps
    ----------------------------------------------------------------
    local HEADER_H = 54
    local header = new("Frame", { Name = "Header", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, HEADER_H),
        BackgroundTransparency = 1, Parent = main }, { list(8, Enum.FillDirection.Horizontal) })

    local totalW = size.X - 20 - 24
    local brandW = math.floor(totalW * 0.31)
    local otherW = math.floor((totalW - brandW) / 3)

    local function card(w, order)
        local f = new("Frame", { Size = UDim2.fromOffset(w, HEADER_H), BackgroundColor3 = T.Element, BorderSizePixel = 0,
            LayoutOrder = order, Parent = header }, { corner(8), stroke(T.Border) })
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
    local function iconCircle(parentF, glyph)
        local c = new("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(30, 30), BorderSizePixel = 0,
            BackgroundTransparency = 0.8, Parent = parentF }, { corner(15) })
        onAccent(function(a) c.BackgroundColor3 = a end)
        local s = stroke(T.Accent, 1.5)
        s.Parent = c
        onAccent(function(a) s.Color = a end)
        if glyph then
            local g = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = glyph,
                TextSize = 15, Parent = c })
            onAccent(function(a) g.TextColor3 = shade(a, 0.35) end)
        end
        return c
    end

    -- brand
    local brand = card(brandW, 1)
    paintBanner(brand, 8)
    local bs = stroke(T.Accent, 1)
    bs.Parent = brand
    onAccent(function(a) bs.Color = shade(a, 0.25) end)
    brand:FindFirstChildOfClass("UIStroke"):Destroy()
    if cfg.Logo then
        new("ImageLabel", { Position = UDim2.fromOffset(12, 11), Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, Image = cfg.Logo, ZIndex = 2, Parent = brand })
    else
        txt(brand, { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(32, 38), Font = Enum.Font.GothamBold, Text = "\u{2726}", TextSize = 26,
            TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center })
    end
    txt(brand, { Position = UDim2.fromOffset(52, 10), Size = UDim2.new(1, -58, 0, 18), Font = Enum.Font.GothamBold, TextSize = 14,
        Text = tostring(cfg.Title or "NERV / DEV"), TextColor3 = Color3.new(1, 1, 1), TextTruncate = Enum.TextTruncate.AtEnd })
    txt(brand, { Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -58, 0, 14), Font = Enum.Font.Gotham, TextSize = 11,
        Text = tostring(cfg.Subtitle or ""), TextColor3 = Color3.fromRGB(215, 226, 250), TextTruncate = Enum.TextTruncate.AtEnd })

    -- profile
    local prof = card(otherW, 2)
    local avatar = new("ImageLabel", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = T.Off,
        BorderSizePixel = 0, Parent = prof }, { corner(6) })
    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if ok and avatar.Parent then avatar.Image = img end
    end)
    txt(prof, { Position = UDim2.fromOffset(52, 10), Size = UDim2.new(1, -58, 0, 16), Font = Enum.Font.GothamBold, TextSize = 12,
        Text = player.DisplayName, TextColor3 = T.Text, TextTruncate = Enum.TextTruncate.AtEnd })
    txt(prof, { Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -58, 0, 14), Font = Enum.Font.Gotham, TextSize = 11,
        Text = "@" .. player.Name, TextColor3 = T.Dim, TextTruncate = Enum.TextTruncate.AtEnd })

    -- time (clock drawn from frames so it needs no asset)
    local timeCard = card(otherW, 3)
    local clock = iconCircle(timeCard)
    new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2, 8),
        BorderSizePixel = 0, BackgroundColor3 = T.Text, Parent = clock })
    new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 2),
        BorderSizePixel = 0, BackgroundColor3 = T.Text, Parent = clock })
    local timeLbl = txt(timeCard, { Position = UDim2.fromOffset(52, 10), Size = UDim2.new(1, -58, 0, 16), Font = Enum.Font.GothamBold, TextSize = 12,
        Text = "TIME: --:--:--", TextColor3 = T.Text, TextTruncate = Enum.TextTruncate.AtEnd })
    local dateLbl = txt(timeCard, { Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -58, 0, 14), Font = Enum.Font.Gotham, TextSize = 11,
        Text = "Date: --", TextColor3 = T.Dim, TextTruncate = Enum.TextTruncate.AtEnd })

    -- fps / ping
    local fpsCard = card(otherW, 4)
    iconCircle(fpsCard, "i")
    local fpsLbl = txt(fpsCard, { Position = UDim2.fromOffset(52, 10), Size = UDim2.new(1, -58, 0, 16), Font = Enum.Font.GothamBold, TextSize = 12,
        Text = "FPS: 0", TextColor3 = T.Text })
    local pingLbl = txt(fpsCard, { Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -58, 0, 14), Font = Enum.Font.Gotham, TextSize = 11,
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
    -- rail + content area
    ----------------------------------------------------------------
    local BODY_Y = 10 + HEADER_H + 10
    local BOTTOM = 28 -- strip for the watermark
    local RAIL_W = 128

    local rail = new("Frame", { Name = "Rail", Position = UDim2.fromOffset(10, BODY_Y), Size = UDim2.new(0, RAIL_W, 1, -(BODY_Y + BOTTOM)),
        BackgroundColor3 = T.Panel, BorderSizePixel = 0, Parent = main }, { corner(8), stroke(T.Border), pad(8, 8, 8, 8), list(6) })

    local content = new("Frame", { Name = "Content", Position = UDim2.fromOffset(10 + RAIL_W + 8, BODY_Y),
        Size = UDim2.new(1, -(10 + RAIL_W + 8 + 10), 1, -(BODY_Y + BOTTOM)), BackgroundTransparency = 1, Parent = main })
    new("Frame", { Name = "Divider", Position = UDim2.fromOffset(0, 33), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = T.Border,
        BorderSizePixel = 0, Parent = content })

    if cfg.Watermark then
        local first, rest = tostring(cfg.Watermark):match("^(%S+)%s*(.*)$")
        new("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -6), Size = UDim2.fromOffset(200, 16),
            BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 13, RichText = true, TextXAlignment = Enum.TextXAlignment.Right,
            Text = string.format('<font color="rgb(176,96,255)">%s</font> <font color="rgb(70,130,255)">%s</font>', first or "", rest or ""),
            Parent = main })
    end

    ----------------------------------------------------------------
    -- dropdown popup management (popups live in `overlay` so nothing clips them)
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
    -- toggle key / cursor-free visibility
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

        local item = new("Frame", { Name = name .. "_Tab", Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = T.Accent, BackgroundTransparency = 1,
            BorderSizePixel = 0, LayoutOrder = #Window.Tabs + 1, Parent = rail }, { corner(6) })
        local st = new("UIStroke", { Thickness = 1, Transparency = 1, Color = T.Accent, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = item })
        onAccent(function(c) item.BackgroundColor3 = c st.Color = c end)

        local icon
        if topts.Icon then
            icon = new("ImageLabel", { Position = UDim2.fromOffset(9, 9), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1,
                Image = topts.Icon, ImageColor3 = T.Dim, Parent = item })
        else
            icon = new("TextLabel", { Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(24, 36), BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold, Text = topts.Glyph or string.sub(name, 1, 1), TextSize = 16, TextColor3 = T.Dim, Parent = item })
        end
        local label = new("TextLabel", { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -52, 1, 0), BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium, Text = name, TextSize = 13, TextColor3 = T.TextOff, TextXAlignment = Enum.TextXAlignment.Left, Parent = item })
        local click = new("TextButton", { Size = UDim2.new(1, -22, 1, 0), BackgroundTransparency = 1, Text = "", Parent = item })

        -- three-dot menu button
        local dots = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.fromOffset(18, 28),
            BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = item })
        local dotFrames = {}
        for d = 0, 2 do
            dotFrames[#dotFrames + 1] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, (d - 1) * 5),
                Size = UDim2.fromOffset(3, 3), BackgroundColor3 = T.Dim, BorderSizePixel = 0, ZIndex = 3, Parent = dots }, { corner(2) })
        end
        dots.MouseEnter:Connect(function() for _, f in ipairs(dotFrames) do tween(f, { BackgroundColor3 = T.Accent }, 0.1) end end)
        dots.MouseLeave:Connect(function() for _, f in ipairs(dotFrames) do tween(f, { BackgroundColor3 = T.Dim }, 0.1) end end)
        dots.MouseButton1Click:Connect(function() if topts.OnMenu then task.spawn(topts.OnMenu, Tab) end end)

        local function paint(on)
            tween(item, { BackgroundTransparency = on and 0.86 or 1 }, 0.15)
            tween(st, { Transparency = on and 0 or 1 }, 0.15)
            tween(label, { TextColor3 = on and T.Text or T.TextOff }, 0.15)
            if icon:IsA("ImageLabel") then tween(icon, { ImageColor3 = on and T.Accent or T.Dim }, 0.15)
            else tween(icon, { TextColor3 = on and T.Accent or T.Dim }, 0.15) end
        end

        -- page tab bar (only visible while this rail tab is selected)
        local bar = new("Frame", { Name = name .. "_Pages", Size = UDim2.new(1, 0, 0, 33), BackgroundTransparency = 1, Visible = false, Parent = content },
            { pad(12, 0, 0, 0), list(20, Enum.FillDirection.Horizontal) })

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
                Font = Enum.Font.GothamMedium, Text = pname, TextSize = 13, TextColor3 = T.Dim, LayoutOrder = #Tab.Pages + 1, Parent = bar })
            local underline = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2),
                BorderSizePixel = 0, Visible = false, Parent = btn }, { corner(1) })
            onAccent(function(c) underline.BackgroundColor3 = c end)

            local scroll = new("ScrollingFrame", { Name = pname .. "_Scroll", Position = UDim2.fromOffset(0, 41), Size = UDim2.new(1, 0, 1, -41),
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = T.Border, Active = true,
                CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = content }, { pad(0, 0, 6, 6) })
            Page.Scroll = scroll
            scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(closePopup)

            local cols = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll },
                { list(10, Enum.FillDirection.Horizontal) })
            local function column(order)
                return new("Frame", { Size = UDim2.new(0.5, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                    LayoutOrder = order, Parent = cols }, { list(10) })
            end
            local colL, colR = column(1), column(2)

            function Page:_paint(on)
                underline.Visible = on
                btn.Font = on and Enum.Font.GothamBold or Enum.Font.GothamMedium
                btn.TextColor3 = on and T.Text or T.Dim
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
                    AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Panel, BorderSizePixel = 0, LayoutOrder = #Page.Sections + 1, Parent = col },
                    { corner(8), stroke(T.Border), list(0) })
                Page.Sections[#Page.Sections + 1] = sec

                if title then
                    local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 0, Parent = sec })
                    local banner = new("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 22), BorderSizePixel = 0, Parent = holder },
                        { corner(4) })
                    paintBanner(banner, 4, cfg.BannerTexture)
                    new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = title, TextSize = 12,
                        TextColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = banner })
                end

                local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1,
                    Parent = sec }, { pad(10, title and 4 or 10, 10, 10), list(8) })

                local Section = {}
                local flagPrefix = Tab.Name .. "/" .. pname .. "/" .. tostring(title or "") .. "/"
                local n = 0
                local function nextOrder() n = n + 1 return n end
                local function noop() end

                ---------------- toggle
                function Section:AddToggle(opts, callback)
                    callback = callback or opts.Callback or noop
                    local state = opts.Default or false
                    local boldOn = opts.BoldWhenOn ~= false
                    local row = new("Frame", { Name = "Toggle", Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = body })
                    local lbl = new("TextLabel", { Size = UDim2.new(1, -46, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = opts.Title,
                        TextSize = 13, TextColor3 = T.TextOff, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
                    local pill = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(34, 18),
                        BackgroundColor3 = T.Off, BorderSizePixel = 0, Parent = row }, { corner(9) })
                    local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(12, 12),
                        BackgroundColor3 = T.KnobOff, BorderSizePixel = 0, Parent = pill }, { corner(6) })
                    local click = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = row })

                    local function paint(v)
                        tween(pill, { BackgroundColor3 = v and T.Accent or T.Off }, 0.15)
                        tween(knob, { Position = v and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
                            BackgroundColor3 = v and Color3.new(1, 1, 1) or T.KnobOff }, 0.15)
                        lbl.TextColor3 = v and T.Text or T.TextOff
                        lbl.Font = (v and boldOn) and Enum.Font.GothamBold or Enum.Font.GothamMedium
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
                    local b = new("TextButton", { Name = "Button", Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
                        AutoButtonColor = false, Font = Enum.Font.GothamBold, Text = opts.Title, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
                        LayoutOrder = nextOrder(), Parent = body }, { corner(6) })
                    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 202, 220)), Parent = b })
                    local bst = stroke(T.Accent, 1)
                    bst.Parent = b
                    onAccent(function(c) b.BackgroundColor3 = c bst.Color = shade(c, 0.3) end)
                    b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = shade(T.Accent, 0.12) }, 0.1) end)
                    b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = T.Accent }, 0.1) end)
                    b.MouseButton1Click:Connect(function() task.spawn(callback) end)
                    return { Fire = function() task.spawn(callback) end, SetText = function(_, s) b.Text = tostring(s) end }
                end

                ---------------- label (status line)
                function Section:AddLabel(opts)
                    local text = new("TextLabel", { Name = "Label", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
                        Font = Enum.Font.Gotham, Text = tostring(type(opts) == "table" and opts.Title or opts), TextSize = 11, TextWrapped = true,
                        TextColor3 = T.Dim, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(), Parent = body })
                    return {
                        SetText = function(_, s) text.Text = tostring(s) end,
                        SetColor = function(_, c) text.TextColor3 = c end,
                    }
                end

                ---------------- textbox
                function Section:AddTextBox(opts, callback)
                    callback = callback or opts.Callback or noop
                    local box = new("Frame", { Name = "TextBox", Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.Element, BorderSizePixel = 0,
                        LayoutOrder = nextOrder(), Parent = body }, { corner(6) })
                    local bst = stroke(T.Border, 1)
                    bst.Parent = box
                    local input = new("TextBox", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1,
                        Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.Text, Text = opts.Default or "", PlaceholderText = opts.Placeholder or opts.Title or "",
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

                    local row = new("Frame", { Name = "Slider", Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = body })
                    new("TextLabel", { Size = UDim2.new(1, -60, 0, 16), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = opts.Title, TextSize = 13,
                        TextColor3 = T.TextOff, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
                    local val = new("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(56, 16),
                        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
                    local track_ = new("Frame", { Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = T.Off, BorderSizePixel = 0,
                        Parent = row }, { corner(3) })
                    local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = track_ }, { corner(3) })
                    onAccent(function(c) fill.BackgroundColor3 = c end)
                    local hit = new("TextButton", { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 1, -16), BackgroundTransparency = 1, Text = "", Parent = row })

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
                        LayoutOrder = nextOrder(), Parent = body }, { list(5) })
                    if opts.Title then
                        new("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = opts.Title, TextSize = 12,
                            TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, Parent = holder })
                    end
                    local box = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.Element, BorderSizePixel = 0, LayoutOrder = 1, Parent = holder },
                        { corner(6) })
                    local bst = stroke(T.Border, 1)
                    bst.Parent = box
                    local vtext = new("TextLabel", { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
                        TextSize = 12, TextColor3 = T.Text, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = box })
                    -- up/down chevrons on the right
                    for idx, g in ipairs({ "\u{25B2}", "\u{25BC}" }) do
                        new("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, idx == 1 and -4 or 4), Size = UDim2.fromOffset(10, 8),
                            BackgroundTransparency = 1, Font = Enum.Font.Gotham, Text = g, TextSize = 7, TextColor3 = T.Dim, Parent = box })
                    end
                    local dbtn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = box })

                    local popup = new("Frame", { Visible = false, BackgroundColor3 = T.Element, BorderSizePixel = 0, ZIndex = 60, Parent = overlay },
                        { corner(6), stroke(T.Border) })
                    local pscroll = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
                        ScrollBarImageColor3 = T.Border, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Active = true, ZIndex = 61, Parent = popup },
                        { pad(4, 4, 4, 4), list(0) })

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
                            local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "", LayoutOrder = i, ZIndex = 62, Parent = pscroll })
                            local l = new("TextLabel", { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham,
                                Text = tostring(name), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 62, Parent = b })
                            local dot = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0,
                                ZIndex = 62, Parent = b }, { corner(3) })
                            onAccent(function(c) dot.BackgroundColor3 = c end)
                            items[name] = { label = l, dot = dot }
                            b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.9, BackgroundColor3 = Color3.new(1, 1, 1) }, 0.08) end)
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
                        local pos, sz = box.AbsolutePosition, box.AbsoluteSize
                        local h = math.min(#options * 24 + 8, 176)
                        local y = pos.Y + sz.Y + 4
                        if y + h > gui.AbsoluteSize.Y then y = pos.Y - h - 4 end
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

                    local row = new("Frame", { Name = "Keybind", Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = body })
                    new("TextLabel", { Size = UDim2.new(1, -90, 1, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, Text = opts.Title, TextSize = 13,
                        TextColor3 = T.TextOff, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
                    local kb = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(80, 22),
                        BackgroundColor3 = T.Element, BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.GothamBold, Text = keyName(key), TextSize = 12,
                        TextColor3 = T.Text, Parent = row }, { corner(6), stroke(T.Border) })

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
