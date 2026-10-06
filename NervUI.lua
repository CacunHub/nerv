--[[
	NervUI - "NERV / DEV" menu, 560x290, built to match the screenshot (FeralLib-style single file).

	local Library = loadstring(game:HttpGet("<raw url>"))()
	local Window = Library:CreateWindow({
		Title = "NERV / DEV", Subtitle = "Grand Piece Online", Logo = nil,
		Watermark = "Developer Mode", ToggleKey = Enum.KeyCode.RightShift, Scale = 1,
	})
	local Tab     = Window:AddTab("Farm", { Glyph = "x", Icon = nil, OnMenu = function() end })  -- sidebar row
	local Page    = Tab:AddPage("Bosses")                                                         -- top tab
	local Section = Page:AddSection("Bounty Farm", "Left")  -- title nil = no banner, side "Left"/"Right"

	Section:AddToggle  ({ Title, Default, Flag }, cb(bool))        -> { Set, Get, OnChanged }
	Section:AddButton  ({ Title }, cb())                           -> { Fire, SetText }
	Section:AddLabel   ({ Title })                                 -> { SetText, SetColor }
	Section:AddTextBox ({ Title, Default, Placeholder, Flag }, cb(text)) -> { Set, Get, OnChanged }
	Section:AddDropdown({ Title, Options, Default, Multi, Flag }, cb(v)) -> { Set, Get, Refresh, OnChanged }

	Set(v, true) also fires the callback. Every control is stored in Library.Flags[Flag].
	Aliases: Create* = Add*, CreateMain = CreateWindow.
	Library:CreateNoti({Title, Desc, ShowTime}) / Library:SetAccent(Color3)
	Window:Toggle() / :SetToggleKey(k) / :SetScale(n) / :Destroy()   Tab:Select()  Page:Select()
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local player = Players.LocalPlayer

local Library = {
	Theme = {
		bg         = Color3.fromHex("0E1013"),
		surface    = Color3.fromHex("14171C"),
		surfaceAlt = Color3.fromHex("1A1E25"),
		border     = Color3.fromHex("1F242C"),
		text       = Color3.fromHex("FFFFFF"),
		textMuted  = Color3.fromHex("8A93A0"),
		accent     = Color3.fromHex("3B82F6"),
		accentDark = Color3.fromHex("1F4FA8"),
	},
	Windows = {},
	Flags = {},
}
local T = Library.Theme
local W, H = 560, 290
local FONT, BOLD = Enum.Font.GothamMedium, Enum.Font.GothamBold

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
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else i[k] = v end
	end
	for _, c in ipairs(kids or {}) do c.Parent = i end
	if parent then i.Parent = parent end
	return i
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function stroke(c, tr)
	return new("UIStroke", { Color = c, Thickness = 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function pad(l, t, r, b)
	return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b) })
end
local function list(p, dir)
	return new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, p or 0), FillDirection = dir or Enum.FillDirection.Vertical })
end
local function tween(o, props, t, style)
	local tw = TweenService:Create(o, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function label(props, kids)
	local p = { BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0 }
	for k, v in pairs(props) do p[k] = v end
	return new("TextLabel", p, kids)
end
local function draggable(handle, target)
	local dragging, start, startPos
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, start, startPos = true, i.Position, target.Position
			i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	return UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - start
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end
local function toKey(v)
	if typeof(v) == "EnumItem" then return v end
	if type(v) == "string" then
		local n = v:gsub("^Enum%.KeyCode%.", "")
		local ok, r = pcall(function() return Enum.KeyCode[n] end)
		if ok and r then return r end
	end
end

-- accent registry (Library:SetAccent recolors everything live)
local accentFns = {}
local function onAccent(fn) accentFns[#accentFns + 1] = fn fn() end
function Library:SetAccent(c)
	T.accent = c
	T.accentDark = c:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, fn in ipairs(accentFns) do pcall(fn) end
end

-- blue water-textured strip (brand card + group banners)
local function paintBanner(frame, radius, texture)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local g = new("UIGradient", { Parent = frame })
	onAccent(function()
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, T.accentDark),
			ColorSequenceKeypoint.new(0.5, T.accent:Lerp(T.accentDark, 0.25)),
			ColorSequenceKeypoint.new(1, T.accentDark),
		})
	end)
	local ov = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = frame }, { corner(radius) })
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
	obj._h = {}
	function obj:OnChanged(fn) table.insert(self._h, fn) return self end
	local flag = opts.Flag
	if not flag then
		local base = prefix .. tostring(opts.Title)
		flag = base
		local n = 1
		while Library.Flags[flag] do n += 1 flag = base .. "#" .. n end
	end
	obj.Flag = flag
	Library.Flags[flag] = obj
	return obj
end
local function fire(obj, cb, ...)
	task.spawn(cb, ...)
	for _, f in ipairs(obj._h) do task.spawn(f, ...) end
end

--------------------------------------------------------------------
-- notifications
--------------------------------------------------------------------
local notiGui, notiHolder
function Library:CreateNoti(cfg)
	cfg = cfg or {}
	if not (notiGui and notiGui.Parent) then
		notiGui = new("ScreenGui", { Name = "NervNotifications", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 200, Parent = getParent() })
		notiHolder = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(230, 400),
			BackgroundTransparency = 1, Parent = notiGui },
			{ new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	end
	local card = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.surface, BorderSizePixel = 0,
		Parent = notiHolder }, { corner(6), stroke(T.border), pad(10, 8, 10, 8), list(2) })
	local t = label({ Size = UDim2.new(1, 0, 0, 14), Font = BOLD, TextSize = 12, Text = tostring(cfg.Title or "NERV"), LayoutOrder = 1, Parent = card })
	onAccent(function() t.TextColor3 = T.accent end)
	label({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 11, TextWrapped = true, TextColor3 = T.textMuted,
		Text = tostring(cfg.Desc or ""), LayoutOrder = 2, Parent = card })
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

	local conns = {}
	local function track(c) conns[#conns + 1] = c return c end
	local userScale = cfg.Scale or 1

	local gui = new("ScreenGui", { Name = "NervUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
		DisplayOrder = 100, Parent = parent })
	local root = new("Frame", { Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Parent = gui })
	local uiscale = new("UIScale", { Scale = userScale * 0.96, Parent = root })

	-- soft drop shadow (stacked frames, no asset)
	local shadows = {
		new("Frame", { Position = UDim2.fromOffset(-6, -2), Size = UDim2.new(1, 12, 1, 12), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.88,
			BorderSizePixel = 0, ZIndex = 0, Parent = root }, { corner(14) }),
		new("Frame", { Position = UDim2.fromOffset(-3, 0), Size = UDim2.new(1, 6, 1, 6), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.8,
			BorderSizePixel = 0, ZIndex = 0, Parent = root }, { corner(12) }),
	}
	local main = new("CanvasGroup", { Name = "Main", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.bg, BackgroundTransparency = 0.05,
		BorderSizePixel = 0, GroupTransparency = 1, Parent = root }, { corner(10), stroke(T.border) })

	local Window = { Gui = gui, Main = main, Tabs = {}, Selected = nil, Visible = true }

	----------------------------------------------------------------
	-- top info bar: brand | user | time | stats  (36px, 6px gap)
	----------------------------------------------------------------
	local bar = new("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 36), BackgroundTransparency = 1, Parent = main },
		{ list(6, Enum.FillDirection.Horizontal) })
	track(draggable(bar, root))
	local function card(width, order)
		local c = new("Frame", { Size = UDim2.new(0, width, 1, 0), BackgroundColor3 = T.surface, BorderSizePixel = 0, LayoutOrder = order, Parent = bar },
			{ corner(6), stroke(T.border) })
		track(draggable(c, root))
		return c
	end
	local function twoLines(p, x, a, b)
		local l1 = label({ Position = UDim2.new(0, x, 0, 5), Size = UDim2.new(1, -x - 4, 0, 14), Font = BOLD, TextSize = 12, Text = a, TextTruncate = Enum.TextTruncate.AtEnd, Parent = p })
		local l2 = label({ Position = UDim2.new(0, x, 0, 19), Size = UDim2.new(1, -x - 4, 0, 11), TextSize = 10, TextColor3 = T.textMuted, Text = b,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = p })
		return l1, l2
	end
	local function badge(p, glyph)
		local c = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(22, 22), BorderSizePixel = 0,
			BackgroundColor3 = T.accentDark, Parent = p }, { corner(11) })
		local s = stroke(T.accent, 0.3)
		s.Parent = c
		onAccent(function() c.BackgroundColor3 = T.accentDark s.Color = T.accent end)
		return c
	end

	-- 1 brand
	local brand = card(140, 1)
	brand:FindFirstChildOfClass("UIStroke"):Destroy()
	paintBanner(brand, 6)
	if cfg.Logo then
		new("ImageLabel", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 9, 0.5, 0), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1,
			Image = cfg.Logo, ZIndex = 2, Parent = brand })
	else
		label({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(20, 24), Font = BOLD, TextSize = 20, Text = "\u{2726}",
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2, Parent = brand })
	end
	local b1, b2 = twoLines(brand, 34, tostring(cfg.Title or "NERV / DEV"), tostring(cfg.Subtitle or ""))
	b1.TextSize = 13 b1.ZIndex = 2
	b2.TextColor3 = Color3.fromRGB(215, 226, 250) b2.ZIndex = 2

	-- 2 user
	local ucard = card(128, 2)
	local av = new("ImageLabel", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = T.surfaceAlt, BorderSizePixel = 0, Parent = ucard }, { corner(12) })
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and av.Parent then av.Image = img end
	end)
	twoLines(ucard, 38, player.Name, player.DisplayName)

	-- 3 time (clock drawn from frames)
	local tcard = card(128, 3)
	local clock = badge(tcard)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1, 6), BorderSizePixel = 0, BackgroundColor3 = T.text, Parent = clock })
	new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, 1), BorderSizePixel = 0, BackgroundColor3 = T.text, Parent = clock })
	local tl, dl = twoLines(tcard, 38, "TIME: --:--:--", "Date: --.--.----")

	-- 4 stats
	local scard = card(130, 4)
	local info = badge(scard)
	label({ Size = UDim2.fromScale(1, 1), Font = BOLD, TextSize = 12, Text = "i", TextXAlignment = Enum.TextXAlignment.Center, Parent = info })
	local fl, pl = twoLines(scard, 38, "FPS: --", "Ping: -- ms")

	local frames, last = 0, os.clock()
	track(RunService.RenderStepped:Connect(function()
		frames += 1
		local now = os.clock()
		if now - last < 0.5 then return end
		local fps = math.floor(frames / (now - last) + 0.5)
		frames, last = 0, now
		if not gui.Enabled or not Window.Visible then return end
		local ping = 0
		pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
		tl.Text = "TIME: " .. os.date("%H:%M:%S")
		dl.Text = "Date: " .. os.date("%d.%m.%Y")
		fl.Text = "FPS: " .. fps
		pl.Text = "Ping: " .. ping .. " ms"
	end))

	----------------------------------------------------------------
	-- sidebar + content + watermark
	----------------------------------------------------------------
	local rail = new("Frame", { Position = UDim2.fromOffset(8, 50), Size = UDim2.new(0, 95, 1, -70), BackgroundTransparency = 1, Parent = main }, { list(4) })
	local content = new("Frame", { Position = UDim2.fromOffset(111, 50), Size = UDim2.new(1, -119, 1, -70), BackgroundTransparency = 1, Parent = main })

	if cfg.Watermark then
		local wm = label({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -5), Size = UDim2.fromOffset(100, 12), Font = BOLD, TextSize = 10,
			Text = tostring(cfg.Watermark), TextXAlignment = Enum.TextXAlignment.Right, Parent = main })
		new("UIGradient", { Parent = wm, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.20, Color3.fromRGB(255, 190, 60)),
			ColorSequenceKeypoint.new(0.40, Color3.fromRGB(120, 230, 90)), ColorSequenceKeypoint.new(0.60, Color3.fromRGB(60, 210, 240)),
			ColorSequenceKeypoint.new(0.80, Color3.fromRGB(110, 120, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(230, 90, 230)),
		}) })
	end

	----------------------------------------------------------------
	-- open / close / toggle key
	----------------------------------------------------------------
	local function open()
		Window.Visible = true
		root.Visible = true
		uiscale.Scale = userScale * 0.96
		main.GroupTransparency = 1
		for _, s in ipairs(shadows) do s.Visible = true end
		tween(uiscale, { Scale = userScale }, 0.25, Enum.EasingStyle.Quint)
		tween(main, { GroupTransparency = 0 }, 0.25, Enum.EasingStyle.Quint)
	end
	local function close()
		Window.Visible = false
		for _, s in ipairs(shadows) do s.Visible = false end
		tween(uiscale, { Scale = userScale * 0.96 }, 0.2, Enum.EasingStyle.Quint)
		tween(main, { GroupTransparency = 1 }, 0.2, Enum.EasingStyle.Quint).Completed:Connect(function()
			if not Window.Visible then root.Visible = false end
		end)
	end
	local toggleKey = toKey(cfg.ToggleKey) or Enum.KeyCode.RightShift
	track(UIS.InputBegan:Connect(function(i)
		if i.KeyCode == toggleKey and not UIS:GetFocusedTextBox() then Window:Toggle() end
	end))
	function Window:Toggle(state)
		if state == nil then state = not Window.Visible end
		if state == Window.Visible then return end
		if state then open() else close() end
	end
	function Window:SetToggleKey(k) toggleKey = toKey(k) or toggleKey end
	function Window:SetScale(s) userScale = s uiscale.Scale = s end
	function Window:Destroy()
		for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
		gui:Destroy()
	end

	----------------------------------------------------------------
	-- dropdown outside-click handling
	----------------------------------------------------------------
	local openDropdown -- { container, close }
	track(UIS.InputBegan:Connect(function(i)
		if not openDropdown then return end
		if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
		local m = UIS:GetMouseLocation()
		local p, s = openDropdown.container.AbsolutePosition, openDropdown.container.AbsoluteSize
		if m.X < p.X or m.X > p.X + s.X or m.Y < p.Y or m.Y > p.Y + s.Y then openDropdown.close() end
	end))

	----------------------------------------------------------------
	-- sidebar tab -> top page tabs -> sections
	----------------------------------------------------------------
	function Window:AddTab(name, topts)
		topts = topts or {}
		local Tab = { Name = name, Pages = {}, Current = nil }

		local item = new("Frame", { Name = name .. "_Tab", Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = T.surfaceAlt, BackgroundTransparency = 1,
			BorderSizePixel = 0, LayoutOrder = #Window.Tabs + 1, Parent = rail }, { corner(6) })
		local st = stroke(T.border, 1)
		st.Parent = item
		local icon
		if topts.Icon then
			icon = new("ImageLabel", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(14, 14),
				BackgroundTransparency = 1, Image = topts.Icon, ImageColor3 = T.text, Parent = item })
		else
			icon = label({ Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0, 18, 1, 0), Font = BOLD, TextSize = 14, Text = topts.Glyph or name:sub(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center, Parent = item })
		end
		local lbl = label({ Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -44, 1, 0), TextTransparency = 0.25, Text = name, Parent = item })
		local click = new("TextButton", { Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, Text = "", Parent = item })

		-- vertical three-dot kebab
		local dots = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -2, 0.5, 0), Size = UDim2.fromOffset(16, 26),
			BackgroundTransparency = 1, Text = "", ZIndex = 3, Parent = item })
		local dotFrames = {}
		for d = -1, 1 do
			dotFrames[#dotFrames + 1] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, d * 4), Size = UDim2.fromOffset(2, 2),
				BackgroundColor3 = T.textMuted, BorderSizePixel = 0, ZIndex = 3, Parent = dots }, { corner(1) })
		end
		dots.MouseEnter:Connect(function() for _, f in ipairs(dotFrames) do tween(f, { BackgroundColor3 = T.text }, 0.1) end end)
		dots.MouseLeave:Connect(function() for _, f in ipairs(dotFrames) do tween(f, { BackgroundColor3 = T.textMuted }, 0.1) end end)
		dots.MouseButton1Click:Connect(function() if topts.OnMenu then task.spawn(topts.OnMenu, Tab) end end)

		local function paint(on)
			tween(item, { BackgroundTransparency = on and 0 or 1 }, 0.15)
			tween(st, { Transparency = on and 0 or 1 }, 0.15)
			tween(lbl, { TextTransparency = on and 0 or 0.25 }, 0.15)
			lbl.Font = on and BOLD or FONT
		end
		click.MouseEnter:Connect(function() if Window.Selected ~= Tab then tween(item, { BackgroundTransparency = 0.6 }, 0.15) end end)
		click.MouseLeave:Connect(function() if Window.Selected ~= Tab then tween(item, { BackgroundTransparency = 1 }, 0.15) end end)

		-- top tab bar + sliding underline
		local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Visible = false, Parent = content })
		local tabBar = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = holder }, { list(0, Enum.FillDirection.Horizontal), pad(4, 0, 0, 0) })
		local underline = new("Frame", { Position = UDim2.new(0, 0, 1, -2), Size = UDim2.fromOffset(0, 2), BorderSizePixel = 0, ZIndex = 2, Parent = holder })
		onAccent(function() underline.BackgroundColor3 = T.accent end)

		local function moveUnderline(animate)
			local cur = Tab.Current
			if not cur or not holder.Visible then return end
			local s = root.AbsoluteSize.X / W
			if s <= 0 then return end
			local x = (cur.Button.AbsolutePosition.X - holder.AbsolutePosition.X) / s
			local w = cur.Button.AbsoluteSize.X / s
			local goal = { Position = UDim2.new(0, x, 1, -2), Size = UDim2.fromOffset(w, 2) }
			if animate then tween(underline, goal, 0.2) else underline.Position = goal.Position underline.Size = goal.Size end
		end

		function Tab:_hide()
			paint(false)
			holder.Visible = false
			if Tab.Current then Tab.Current.Scroll.Visible = false end
		end
		function Tab:Select()
			if Window.Selected and Window.Selected ~= Tab then Window.Selected:_hide() end
			Window.Selected = Tab
			paint(true)
			holder.Visible = true
			if Tab.Current then
				Tab.Current.Scroll.Visible = true
				task.defer(function() RunService.Heartbeat:Wait() moveUnderline(false) end)
			end
		end
		click.MouseButton1Click:Connect(function() Tab:Select() end)

		function Tab:AddPage(pname)
			local Page = { Name = pname, Sections = {} }
			local btn = new("TextButton", { Size = UDim2.new(0, 0, 1, -2), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = FONT,
				Text = pname, TextSize = 11, TextColor3 = T.textMuted, AutoButtonColor = false, LayoutOrder = #Tab.Pages + 1, Parent = tabBar }, { pad(8, 0, 8, 0) })
			Page.Button = btn
			btn:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() moveUnderline(false) end)

			local scroll = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), BackgroundTransparency = 1, BorderSizePixel = 0,
				ScrollBarThickness = 2, ScrollBarImageColor3 = T.border, ScrollBarImageTransparency = 0.5, Active = true, CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false, Parent = content }, { pad(0, 0, 4, 4) })
			Page.Scroll = scroll
			local cols = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll },
				{ list(8, Enum.FillDirection.Horizontal) })
			local function column(o)
				return new("Frame", { Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = o,
					Parent = cols }, { list(6) })
			end
			local colL, colR = column(1), column(2)

			local function paintPage(on)
				tween(btn, { TextColor3 = on and T.text or T.textMuted }, 0.2)
				scroll.Visible = on and Window.Selected == Tab
			end
			function Page:Select()
				if openDropdown then openDropdown.close() end
				if Tab.Current and Tab.Current ~= Page then Tab.Current:_paint(false) end
				Tab.Current = Page
				paintPage(true)
				moveUnderline(Window.Visible and true or false)
			end
			function Page:_paint(on) paintPage(on) end
			btn.MouseButton1Click:Connect(function() Page:Select() end)
			btn.MouseEnter:Connect(function() if Tab.Current ~= Page then tween(btn, { TextColor3 = T.text }, 0.15) end end)
			btn.MouseLeave:Connect(function() if Tab.Current ~= Page then tween(btn, { TextColor3 = T.textMuted }, 0.15) end end)

			------------------------------------------------------------
			-- section (group box)
			------------------------------------------------------------
			function Page:AddSection(title, side)
				side = side or ((#Page.Sections % 2 == 0) and "Left" or "Right")
				local col = (side == "Right") and colR or colL
				local sec = new("Frame", { Name = tostring(title or "Section") .. "_Section", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = T.surface, BorderSizePixel = 0, LayoutOrder = #Page.Sections + 1, Parent = col }, { corner(6), stroke(T.border), list(0) })
				Page.Sections[#Page.Sections + 1] = sec

				if title then
					-- 14px strip, flush top. Oversized rounded banner clipped by the holder = rounded top, flat bottom.
					local hold = new("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, ClipsDescendants = true, LayoutOrder = 0, Parent = sec })
					local banner = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BorderSizePixel = 0, Parent = hold }, { corner(6) })
					paintBanner(banner, 6, cfg.BannerTexture)
					label({ Size = UDim2.new(1, 0, 0, 14), Font = BOLD, TextSize = 10, Text = title, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Parent = banner })
				end
				local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = sec },
					{ pad(8, 8, 8, 8), list(6) })

				local Section = {}
				local prefix = name .. "/" .. pname .. "/" .. tostring(title or "") .. "/"
				local n = 0
				local function nextOrder() n += 1 return n end
				local function noop() end

				-- toggle ----------------------------------------------------
				function Section:AddToggle(opts, cb)
					cb = cb or opts.Callback or noop
					local state = opts.Default and true or false
					local row = new("TextButton", { Name = "Toggle", Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
						LayoutOrder = nextOrder(), Parent = body })
					local lbl = label({ Size = UDim2.new(1, -30, 1, 0), TextColor3 = T.textMuted, Text = opts.Title, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
					local track_ = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(24, 12),
						BackgroundColor3 = T.bg, BorderSizePixel = 0, Parent = row }, { corner(6) })
					local tst = stroke(T.border)
					tst.Parent = track_
					local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(8, 8),
						BackgroundColor3 = T.textMuted, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = track_ }, { corner(4) })
					local obj
					local function paint(animate)
						local t = animate and 0.15 or 0
						tween(track_, { BackgroundColor3 = state and T.accent or T.bg }, t)
						tween(tst, { Color = state and T.accent or T.border }, t)
						tween(knob, { Position = UDim2.new(0, state and 14 or 2, 0.5, 0), BackgroundColor3 = state and T.text or T.textMuted,
							BackgroundTransparency = state and 0 or 0.4 }, t)
						tween(lbl, { TextColor3 = state and T.text or T.textMuted }, t)
						lbl.Font = state and BOLD or FONT
					end
					onAccent(function() paint(false) end)
					row.MouseButton1Click:Connect(function() state = not state paint(true) fire(obj, cb, state) end)
					row.MouseEnter:Connect(function() if not state then tween(lbl, { TextColor3 = T.text }, 0.15) end end)
					row.MouseLeave:Connect(function() if not state then tween(lbl, { TextColor3 = T.textMuted }, 0.15) end end)
					obj = register(prefix, opts, {
						Set = function(_, v, f) state = not not v paint(true) if f then fire(obj, cb, state) end end,
						Get = function() return state end,
					}, "Toggle")
					return obj
				end

				-- button ----------------------------------------------------
				function Section:AddButton(opts, cb)
					cb = cb or opts.Callback or noop
					local b = new("TextButton", { Name = "Button", Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
						AutoButtonColor = false, Font = BOLD, Text = opts.Title, TextSize = 11, TextColor3 = T.text, LayoutOrder = nextOrder(), ZIndex = 3, Parent = body },
						{ corner(6) })
					local g = new("UIGradient", { Rotation = 90, Parent = b })
					onAccent(function() g.Color = ColorSequence.new(T.accent:Lerp(T.accentDark, 0.15), T.accentDark) end)
					local sc = new("UIScale", { Parent = b })
					local ov = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
						ZIndex = 2, Parent = b }, { corner(6) })
					b.MouseEnter:Connect(function() tween(ov, { BackgroundTransparency = 0.88 }, 0.15) end)
					b.MouseLeave:Connect(function() tween(ov, { BackgroundTransparency = 1 }, 0.15) tween(sc, { Scale = 1 }, 0.1) end)
					b.MouseButton1Down:Connect(function() tween(sc, { Scale = 0.98 }, 0.08) end)
					b.MouseButton1Up:Connect(function() tween(sc, { Scale = 1 }, 0.1) end)
					b.MouseButton1Click:Connect(function() task.spawn(cb) end)
					return { Fire = function() task.spawn(cb) end, SetText = function(_, s) b.Text = tostring(s) end }
				end

				-- label / status ------------------------------------------
				function Section:AddLabel(opts)
					local l = label({ Name = "Label", Size = UDim2.new(1, 0, 0, 12), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 10, TextColor3 = T.textMuted,
						TextWrapped = true, Text = tostring(type(opts) == "table" and opts.Title or opts), LayoutOrder = nextOrder(), Parent = body })
					return { SetText = function(_, s) l.Text = tostring(s) end, SetColor = function(_, c) l.TextColor3 = c end }
				end

				-- textbox --------------------------------------------------
				function Section:AddTextBox(opts, cb)
					cb = cb or opts.Callback or noop
					local box = new("Frame", { Name = "TextBox", Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = T.surfaceAlt, BorderSizePixel = 0,
						LayoutOrder = nextOrder(), Parent = body }, { corner(6) })
					local bst = stroke(T.border)
					bst.Parent = box
					local input = new("TextBox", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = FONT, TextSize = 11, TextColor3 = T.text,
						Text = opts.Default or "", PlaceholderText = opts.Placeholder or opts.Title or "", PlaceholderColor3 = T.textMuted, ClearTextOnFocus = false,
						TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = box }, { pad(8, 0, 8, 0) })
					local obj
					input.Focused:Connect(function() tween(bst, { Color = T.accent }, 0.15) end)
					input.FocusLost:Connect(function() tween(bst, { Color = T.border }, 0.15) fire(obj, cb, input.Text) end)
					obj = register(prefix, opts, {
						Set = function(_, v, f) input.Text = tostring(v) if f then fire(obj, cb, input.Text) end end,
						Get = function() return input.Text end,
					}, "Box")
					return obj
				end

				-- dropdown (single / multi, inline height tween with clip) ---
				function Section:AddDropdown(opts, cb)
					cb = cb or opts.Callback or noop
					local options = opts.Options or {}
					local multi = opts.Multi and true or false
					local isOpen = false
					local function toSet(v)
						local s = {}
						if type(v) == "table" then
							for k, val in pairs(v) do if type(k) == "number" then s[val] = true elseif val then s[k] = true end end
						elseif v ~= nil then s[v] = true end
						return s
					end
					local cur
					if multi then cur = toSet(opts.Default) else cur = opts.Default or options[1] end
					local function selectedList()
						local out = {}
						for _, o in ipairs(options) do if cur[o] then out[#out + 1] = o end end
						return out
					end
					local function value() if multi then return selectedList() end return cur end
					local function isSel(o) if multi then return cur[o] == true end return o == cur end

					local container = new("Frame", { Name = "Dropdown", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
						LayoutOrder = nextOrder(), Parent = body }, { list(3) })
					if opts.Title then
						label({ Size = UDim2.new(1, 0, 0, 14), Text = opts.Title, LayoutOrder = 1, Parent = container })
					end
					local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = T.surfaceAlt, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
						LayoutOrder = 2, Parent = container }, { corner(6) })
					local hst = stroke(T.border)
					hst.Parent = head
					local vtext = label({ Size = UDim2.new(1, -24, 1, 0), TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, Parent = head }, { pad(8, 0, 0, 0) })
					for idx, g in ipairs({ "\u{25B2}", "\u{25BC}" }) do
						label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, idx == 1 and -3 or 3), Size = UDim2.fromOffset(8, 6), TextSize = 6,
							TextColor3 = T.textMuted, Text = g, TextXAlignment = Enum.TextXAlignment.Center, Parent = head })
					end
					local lf = new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = T.surfaceAlt, BorderSizePixel = 0, ClipsDescendants = true, Visible = false,
						LayoutOrder = 3, Parent = container }, { corner(6), stroke(T.border) })
					local sc = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = T.border,
						CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Active = true, Parent = lf }, { pad(0, 2, 0, 2), list(0) })

					local items, obj = {}, nil
					local function refresh()
						local text
						if multi then
							local names = {}
							for _, o in ipairs(selectedList()) do names[#names + 1] = tostring(o) end
							text = #names == 0 and "None" or table.concat(names, ", ")
						else
							text = cur == nil and "None" or tostring(cur)
						end
						vtext.Text = text
						for o, it in pairs(items) do
							it.check.Visible = isSel(o)
							it.lbl.Font = isSel(o) and BOLD or FONT
						end
					end
					local function closeList()
						if not isOpen then return end
						isOpen = false
						if openDropdown and openDropdown.container == container then openDropdown = nil end
						tween(lf, { Size = UDim2.new(1, 0, 0, 0) }, 0.15).Completed:Connect(function() if not isOpen then lf.Visible = false end end)
					end
					local function openList()
						if openDropdown then openDropdown.close() end
						isOpen = true
						openDropdown = { container = container, close = closeList }
						lf.Visible = true
						tween(lf, { Size = UDim2.new(1, 0, 0, math.min(#options, 5) * 20 + 4) }, 0.15)
					end
					local function rebuild()
						for _, c in ipairs(sc:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
						items = {}
						for i, o in ipairs(options) do
							local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = T.border, BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
								AutoButtonColor = false, LayoutOrder = i, Parent = sc })
							local l = label({ Size = UDim2.new(1, -22, 1, 0), TextSize = 11, Text = tostring(o), TextTruncate = Enum.TextTruncate.AtEnd, Parent = b }, { pad(8, 0, 0, 0) })
							local ck = label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(12, 12), Font = BOLD, TextSize = 11,
								Text = "\u{2713}", TextXAlignment = Enum.TextXAlignment.Center, Visible = false, Parent = b })
							onAccent(function() ck.TextColor3 = T.accent end)
							items[o] = { lbl = l, check = ck }
							b.MouseEnter:Connect(function() tween(b, { BackgroundTransparency = 0.4 }, 0.1) end)
							b.MouseLeave:Connect(function() tween(b, { BackgroundTransparency = 1 }, 0.1) end)
							b.MouseButton1Click:Connect(function()
								if multi then cur[o] = (not cur[o]) or nil else cur = o closeList() end
								refresh()
								fire(obj, cb, value())
							end)
						end
						refresh()
					end
					obj = register(prefix, opts, {
						Multi = multi,
						Set = function(_, v, f) if multi then cur = toSet(v) else cur = v end refresh() if f then fire(obj, cb, value()) end end,
						Get = function() return value() end,
						Refresh = function(_, newOptions, keep)
							options = newOptions
							if multi then
								if not keep then cur = {} else for o in pairs(cur) do if not table.find(options, o) then cur[o] = nil end end end
							elseif not keep or not table.find(options, cur) then cur = options[1] end
							rebuild()
						end,
					}, "Dropdown")
					rebuild()
					head.MouseButton1Click:Connect(function() if isOpen then closeList() else openList() end end)
					head.MouseEnter:Connect(function() tween(hst, { Color = T.accent }, 0.15) end)
					head.MouseLeave:Connect(function() tween(hst, { Color = T.border }, 0.15) end)
					return obj
				end

				-- Feral-style aliases
				Section.CreateToggle, Section.CreateButton, Section.CreateLabel = Section.AddToggle, Section.AddButton, Section.AddLabel
				Section.CreateBox, Section.CreateDropdown = Section.AddTextBox, Section.AddDropdown
				return Section
			end
			Page.CreateSection = Page.AddSection

			Tab.Pages[#Tab.Pages + 1] = Page
			if #Tab.Pages == 1 then
				Page:Select()
				task.defer(function() RunService.Heartbeat:Wait() moveUnderline(false) end)
			end
			return Page
		end
		Tab.CreatePage = Tab.AddPage

		Window.Tabs[#Window.Tabs + 1] = Tab
		if #Window.Tabs == 1 then Tab:Select() end
		return Tab
	end

	-- FeralLib-style shortcut: one rail tab with a single page
	function Window:CreatePage(name) return Window:AddTab(name):AddPage(name) end

	open()
	Library.Windows[#Library.Windows + 1] = Window
	return Window
end
Library.CreateMain = Library.CreateWindow

return Library
