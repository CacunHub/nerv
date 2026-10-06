--[[
	NERV / DEV UI library (ModuleScript). Everything is built with Instance.new.
	Dimensions: Window 560x290 | TopBar cards 36px, 6px gap | Sidebar 95px
	            Sidebar row 30px | Tab bar 20px | Banner 14px | Button 22px
	            Toggle pill 24x12 | Group padding 8 | Gutter 8
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")

--------------------------------------------------------------------------
-- THEME (single source of truth)
--------------------------------------------------------------------------
local Theme = {
	bg          = Color3.fromHex("0E1013"),
	surface     = Color3.fromHex("14171C"),
	surfaceAlt  = Color3.fromHex("1A1E25"),
	border      = Color3.fromHex("1F242C"),
	text        = Color3.fromHex("FFFFFF"),
	textMuted   = Color3.fromHex("8A93A0"),
	accent      = Color3.fromHex("3B82F6"),
	accentDark  = Color3.fromHex("1F4FA8"),
}

-- Swap these with your own rbxassetid:// strings. Empty = text-glyph fallback.
local Icons = {
	Sparkle = "", Clock = "", Info = "", Chevron = "", Kebab = "", Check = "",
}
local Glyphs = {
	Sparkle = "✦", Clock = "◷", Info = "i", Chevron = "⇅", Kebab = "⋮", Check = "✓", Page = "●",
}

local FONT       = Enum.Font.GothamMedium
local FONT_BOLD  = Enum.Font.GothamBold
local WINDOW_W, WINDOW_H = 560, 290

--------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------
local function new(class, props, children)
	local o = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else (o :: any)[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = o end
	if parent then o.Parent = parent end
	return o
end

local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function stroke(color, transparency)
	return new("UIStroke", {
		Color = color, Thickness = 1, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end
local function pad(l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t),
		PaddingRight = UDim.new(0, r), PaddingBottom = UDim.new(0, b),
	})
end
local function list(padding, dir, ha, va)
	return new("UIListLayout", {
		Padding = UDim.new(0, padding or 0), SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirection = dir or Enum.FillDirection.Vertical,
		HorizontalAlignment = ha or Enum.HorizontalAlignment.Left,
		VerticalAlignment = va or Enum.VerticalAlignment.Top,
	})
end
local function tween(obj, props, t, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function text(props)
	local base = {
		BackgroundTransparency = 1, Font = FONT, TextSize = 12, TextColor3 = Theme.text,
		TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0,
	}
	for k, v in pairs(props) do base[k] = v end
	return new("TextLabel", base)
end
-- image icon if an id is set, else a glyph label
local function icon(parent, key, size, color, props)
	props = props or {}
	local id = Icons[key]
	if id and id ~= "" then
		local img = new("ImageLabel", {
			BackgroundTransparency = 1, Image = id, ImageColor3 = color, Size = UDim2.fromOffset(size, size),
			Parent = parent,
		})
		for k, v in pairs(props) do (img :: any)[k] = v end
		return img
	end
	local lbl = text({
		Text = Glyphs[key] or Glyphs.Page, TextColor3 = color, TextSize = size, Font = FONT_BOLD,
		Size = UDim2.fromOffset(size, size), TextXAlignment = Enum.TextXAlignment.Center, Parent = parent,
	})
	for k, v in pairs(props) do (lbl :: any)[k] = v end
	return lbl
end
local function hoverFade(btn, target, from, to, tIn)
	btn.MouseEnter:Connect(function() tween(target, { BackgroundTransparency = to }, tIn or 0.15) end)
	btn.MouseLeave:Connect(function() tween(target, { BackgroundTransparency = from }, tIn or 0.15) end)
end
local function handlers(obj)
	obj._h = {}
	function obj:OnChanged(fn) table.insert(self._h, fn); return self end
end
local function fire(obj, ...)
	for _, f in ipairs(obj._h) do task.spawn(f, ...) end
end

--------------------------------------------------------------------------
-- COMPONENTS (mixed into Column and Group; they build into self.Body)
--------------------------------------------------------------------------
local Components = {}

function Components:AddStatus(txt)
	local lbl = text({
		Text = txt, TextSize = 10, TextColor3 = Theme.textMuted,
		Size = UDim2.new(1, 0, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd, Parent = self.Body,
	})
	local obj = { Instance = lbl }
	function obj:Set(t) lbl.Text = t end
	return obj
end
Components.AddLabel = Components.AddStatus

function Components:AddTextbox(opts)
	opts = opts or {}
	local box = new("Frame", {
		Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Theme.surfaceAlt, BorderSizePixel = 0,
		Parent = self.Body,
	}, { corner(6) })
	local st = stroke(Theme.border)
	st.Parent = box
	local tb = new("TextBox", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Font = FONT, TextSize = 11,
		TextColor3 = Theme.text, PlaceholderText = opts.Placeholder or opts.Name or "",
		PlaceholderColor3 = Theme.textMuted, Text = opts.Default or "", ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = box,
	}, { pad(8, 0, 8, 0) })
	local obj = { Instance = tb }
	handlers(obj)
	tb.Focused:Connect(function() tween(st, { Color = Theme.accent }) end)
	tb.FocusLost:Connect(function(enter)
		tween(st, { Color = Theme.border })
		fire(obj, tb.Text, enter)
		if opts.Callback then task.spawn(opts.Callback, tb.Text, enter) end
	end)
	function obj:Get() return tb.Text end
	function obj:Set(t) tb.Text = t end
	return obj
end

local function buildDropdown(self, opts, multi)
	opts = opts or {}
	local options = opts.Options or {}
	local selected = {}   -- set of option -> true
	local single: any = nil
	local isOpen = false

	local container = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Parent = self.Body,
	}, { list(3) })
	if opts.Name then
		text({ Text = opts.Name, TextSize = 12, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1, Parent = container })
	end
	local boxBtn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Theme.surfaceAlt, BorderSizePixel = 0,
		Text = "", AutoButtonColor = false, LayoutOrder = 2, Parent = container,
	}, { corner(6) })
	local bst = stroke(Theme.border); bst.Parent = boxBtn
	local valueLbl = text({
		Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(8, 0), TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = boxBtn,
	})
	icon(boxBtn, "Chevron", 11, Theme.textMuted, {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0),
	})

	local listFrame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Theme.surfaceAlt, BorderSizePixel = 0,
		ClipsDescendants = true, Visible = false, LayoutOrder = 3, Parent = container,
	}, { corner(6) })
	local lst = stroke(Theme.border); lst.Parent = listFrame
	local scroll = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.border, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = listFrame,
	}, { list(0), pad(0, 2, 0, 2) })

	local obj = { Instance = container }
	handlers(obj)
	local rows = {}

	local function selectedList()
		local out = {}
		for _, o in ipairs(options) do if selected[o] then table.insert(out, o) end end
		return out
	end
	local function refresh()
		if multi then
			local l = selectedList()
			valueLbl.Text = #l > 0 and table.concat(l, ", ") or "None"
		else
			valueLbl.Text = single and tostring(single) or "Select"
		end
		for o, r in pairs(rows) do
			local on = multi and selected[o] or (not multi and single == o)
			r.check.Visible = on and true or false
			r.label.Font = on and FONT_BOLD or FONT
		end
	end
	local function emit()
		local v = multi and selectedList() or single
		fire(obj, v)
		if opts.Callback then task.spawn(opts.Callback, v) end
	end
	local function listHeight() return math.min(#options, 5) * 20 + 4 end
	local function close()
		if not isOpen then return end
		isOpen = false
		local tw = tween(listFrame, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
		tw.Completed:Connect(function() if not isOpen then listFrame.Visible = false end end)
	end
	local function open()
		if isOpen then return end
		isOpen = true
		listFrame.Visible = true
		tween(listFrame, { Size = UDim2.new(1, 0, 0, listHeight()) }, 0.15)
	end
	local function build()
		for _, r in pairs(rows) do r.btn:Destroy() end
		rows = {}
		for i, o in ipairs(options) do
			local btn = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Theme.border, BackgroundTransparency = 1,
				BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = scroll,
			})
			local lbl = text({
				Text = tostring(o), TextSize = 11, Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(8, 0),
				TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn,
			})
			local chk = icon(btn, "Check", 11, Theme.accent, {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Visible = false,
			})
			hoverFade(btn, btn, 1, 0.4)
			btn.MouseButton1Click:Connect(function()
				if multi then
					selected[o] = not selected[o] or nil
				else
					single = o
					close()
				end
				refresh(); emit()
			end)
			rows[o] = { btn = btn, label = lbl, check = chk }
		end
		refresh()
	end

	boxBtn.MouseButton1Click:Connect(function() if isOpen then close() else open() end end)
	boxBtn.MouseEnter:Connect(function() tween(bst, { Color = Theme.accent }) end)
	boxBtn.MouseLeave:Connect(function() tween(bst, { Color = Theme.border }) end)

	-- close on outside click
	local conn = UserInputService.InputBegan:Connect(function(input)
		if not isOpen then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local p, s = container.AbsolutePosition, container.AbsoluteSize
		local m = input.Position
		if m.X < p.X or m.X > p.X + s.X or m.Y < p.Y or m.Y > p.Y + s.Y + 36 then close() end
	end)
	table.insert(self.Window._conns, conn)

	if multi then
		for _, o in ipairs(opts.Default or {}) do selected[o] = true end
	else
		single = opts.Default or options[1]
	end
	build()

	function obj:Get() return multi and selectedList() or single end
	function obj:Set(v)
		if multi then
			selected = {}
			for _, o in ipairs(v or {}) do selected[o] = true end
		else single = v end
		refresh(); emit()
	end
	function obj:SetOptions(newOptions) options = newOptions; build() end
	function obj:Open() open() end
	function obj:Close() close() end
	return obj
end
function Components:AddDropdown(opts) return buildDropdown(self, opts, false) end
function Components:AddMultiDropdown(opts) return buildDropdown(self, opts, true) end

function Components:AddToggle(opts)
	opts = opts or {}
	local state = opts.Default and true or false
	local row = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		Parent = self.Body,
	})
	local lbl = text({ Text = opts.Name or "Toggle", Size = UDim2.new(1, -30, 1, 0), TextColor3 = Theme.textMuted, Parent = row })
	local track = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(24, 12),
		BackgroundColor3 = Theme.bg, BorderSizePixel = 0, Parent = row,
	}, { corner(6) })
	local tst = stroke(Theme.border); tst.Parent = track
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = Theme.textMuted, BackgroundTransparency = 0.4, BorderSizePixel = 0, Parent = track,
	}, { corner(4) })

	local obj = { Instance = row }
	handlers(obj)
	local function render(animate)
		local t = animate and 0.15 or 0
		tween(track, { BackgroundColor3 = state and Theme.accent or Theme.bg }, t)
		tween(tst, { Color = state and Theme.accent or Theme.border }, t)
		tween(knob, {
			Position = UDim2.new(0, state and 14 or 2, 0.5, 0),
			BackgroundColor3 = state and Theme.text or Theme.textMuted,
			BackgroundTransparency = state and 0 or 0.4,
		}, t)
		tween(lbl, { TextColor3 = state and Theme.text or Theme.textMuted }, t)
		lbl.Font = state and FONT_BOLD or FONT
	end
	local function set(v, silent)
		state = v and true or false
		render(true)
		if not silent then
			fire(obj, state)
			if opts.Callback then task.spawn(opts.Callback, state) end
		end
	end
	row.MouseButton1Click:Connect(function() set(not state) end)
	row.MouseEnter:Connect(function() if not state then tween(lbl, { TextColor3 = Theme.text }) end end)
	row.MouseLeave:Connect(function() if not state then tween(lbl, { TextColor3 = Theme.textMuted }) end end)
	render(false)
	function obj:Set(v) set(v) end
	function obj:Get() return state end
	return obj
end

function Components:AddButton(opts)
	opts = opts or {}
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Theme.text, BorderSizePixel = 0,
		Text = opts.Name or "Button", Font = FONT_BOLD, TextSize = 11, TextColor3 = Theme.text,
		AutoButtonColor = false, Parent = self.Body,
	}, {
		corner(6),
		new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Theme.accent, Theme.accentDark),
		}),
	})
	local scale = new("UIScale", { Scale = 1, Parent = btn })
	local overlay = new("Frame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.text, BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 1, Parent = btn,
	}, { corner(6) })
	btn.TextTransparency = 0
	btn.ZIndex = 2
	btn.MouseEnter:Connect(function() tween(overlay, { BackgroundTransparency = 0.88 }) end)
	btn.MouseLeave:Connect(function() tween(overlay, { BackgroundTransparency = 1 }); tween(scale, { Scale = 1 }) end)
	btn.MouseButton1Down:Connect(function() tween(scale, { Scale = 0.98 }, 0.08) end)
	btn.MouseButton1Up:Connect(function() tween(scale, { Scale = 1 }, 0.1) end)
	local obj = { Instance = btn }
	handlers(obj)
	btn.MouseButton1Click:Connect(function()
		fire(obj)
		if opts.Callback then task.spawn(opts.Callback) end
	end)
	function obj:SetText(t) btn.Text = t end
	return obj
end

--------------------------------------------------------------------------
-- GROUP / COLUMN / TAB
--------------------------------------------------------------------------
local Column = {}; Column.__index = Column
for k, v in pairs(Components) do Column[k] = v end

local Group = {}; Group.__index = Group
for k, v in pairs(Components) do Group[k] = v end

function Column:AddGroup(name)
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.surface,
		BorderSizePixel = 0, ClipsDescendants = true, Parent = self.Body,
	}, { corner(6), list(0) })
	local st = stroke(Theme.border); st.Parent = frame
	local banner = new("Frame", {
		Size = UDim2.new(1, 0, 0, 14), BackgroundColor3 = Theme.text, BorderSizePixel = 0, LayoutOrder = 0, Parent = frame,
	}, {
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.accentDark),
				ColorSequenceKeypoint.new(0.25, Theme.accent),
				ColorSequenceKeypoint.new(0.5, Theme.accentDark),
				ColorSequenceKeypoint.new(0.75, Theme.accent),
				ColorSequenceKeypoint.new(1, Theme.accentDark),
			}),
		}),
	})
	text({
		Text = name, TextSize = 10, Font = FONT_BOLD, Size = UDim2.new(1, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center, Parent = banner,
	})
	local body = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
		LayoutOrder = 1, Parent = frame,
	}, { pad(8, 8, 8, 8), list(6) })
	return setmetatable({ Body = body, Instance = frame, Window = self.Window }, Group)
end

local Tab = {}; Tab.__index = Tab
function Tab:Column(side)
	return side == "Right" and self.Right or self.Left
end
function Tab:AddGroup(name, side) return self:Column(side):AddGroup(name) end
for name in pairs(Components) do
	Tab[name] = function(self, a, ...)
		local side = type(a) == "table" and a.Side or "Left"
		local col = self:Column(side)
		return (col :: any)[name](col, a, ...)
	end
end

--------------------------------------------------------------------------
-- PAGE
--------------------------------------------------------------------------
local Page = {}; Page.__index = Page

function Page:_underline(animate)
	local tab = self.ActiveTab
	if not tab then return end
	local scale = self.Window.Root.AbsoluteSize.X / WINDOW_W
	if scale <= 0 then return end
	local x = (tab.Button.AbsolutePosition.X - self.TabBar.AbsolutePosition.X) / scale
	local w = tab.Button.AbsoluteSize.X / scale
	local goal = { Position = UDim2.new(0, x, 1, -2), Size = UDim2.fromOffset(w, 2) }
	if animate then tween(self.Underline, goal, 0.2) else
		self.Underline.Position = goal.Position; self.Underline.Size = goal.Size
	end
end

function Page:SelectTab(tab)
	if self.ActiveTab == tab then return end
	self.ActiveTab = tab
	for _, t in ipairs(self.Tabs) do
		local on = t == tab
		t.Scroll.Visible = on
		tween(t.Button, { TextColor3 = on and Theme.text or Theme.textMuted }, 0.2)
	end
	self:_underline(true)
end

function Page:AddTab(name)
	local btn = new("TextButton", {
		Size = UDim2.new(0, 0, 1, -2), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Text = name, Font = FONT, TextSize = 11, TextColor3 = Theme.textMuted, AutoButtonColor = false,
		LayoutOrder = #self.Tabs + 1, Parent = self.TabBar,
	}, { pad(10, 0, 10, 0) })
	local scroll = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
		ScrollBarThickness = 2, ScrollBarImageColor3 = Theme.border, ScrollBarImageTransparency = 0.6,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, Parent = self.TabArea,
	}, { pad(0, 0, 4, 0) })
	local function col(xs, xo)
		local f = new("Frame", {
			Size = UDim2.new(0.5, -4, 0, 0), Position = UDim2.new(xs, xo, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, Parent = scroll,
		}, { list(6) })
		return setmetatable({ Body = f, Window = self.Window }, Column)
	end
	local tab = setmetatable({
		Name = name, Button = btn, Scroll = scroll,
		Left = col(0, 0), Right = col(0.5, 4),
	}, Tab)
	table.insert(self.Tabs, tab)
	btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
	btn.MouseEnter:Connect(function() if self.ActiveTab ~= tab then tween(btn, { TextColor3 = Theme.text }, 0.15) end end)
	btn.MouseLeave:Connect(function() if self.ActiveTab ~= tab then tween(btn, { TextColor3 = Theme.textMuted }, 0.15) end end)
	if #self.Tabs == 1 then
		self.ActiveTab = tab
		scroll.Visible = true
		btn.TextColor3 = Theme.text
		task.defer(function() RunService.Heartbeat:Wait(); self:_underline(false) end)
	end
	return tab
end

--------------------------------------------------------------------------
-- WINDOW
--------------------------------------------------------------------------
local UI = {}
UI.__index = UI

local function makeDraggable(handle, target)
	local dragging, startPos, startMouse = false, nil, nil
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; startMouse = i.Position; startPos = target.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	return UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startMouse
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

function UI.new(opts)
	opts = opts or {}
	local self = setmetatable({}, UI)
	self._conns = {}
	self.Pages = {}
	self.Visible = true
	self.UserScale = opts.Scale or 1
	self.Keybind = opts.Keybind or Enum.KeyCode.RightShift

	local lp = Players.LocalPlayer
	local gui = new("ScreenGui", {
		Name = "NervUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true, DisplayOrder = 100,
	})
	gui.Parent = lp:WaitForChild("PlayerGui")
	self.Gui = gui

	local root = new("Frame", {
		Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WINDOW_W, WINDOW_H), BackgroundTransparency = 1, Parent = gui,
	})
	self.Root = root
	self.UIScale = new("UIScale", { Scale = self.UserScale, Parent = root })

	-- soft shadow (two stacked frames)
	local shadow = new("Frame", {
		Position = UDim2.fromOffset(-6, -2), Size = UDim2.new(1, 12, 1, 12), BackgroundColor3 = Theme.bg,
		BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 0, Parent = root,
	}, { corner(14) })
	local shadow2 = new("Frame", {
		Position = UDim2.fromOffset(-3, 0), Size = UDim2.new(1, 6, 1, 6), BackgroundColor3 = Theme.bg,
		BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 0, Parent = root,
	}, { corner(12) })
	self._shadows = { shadow, shadow2 }

	local main = new("CanvasGroup", {
		Name = "Main", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Theme.bg, BackgroundTransparency = 0.05,
		BorderSizePixel = 0, GroupTransparency = 1, Parent = root,
	}, { corner(10) })
	local mst = stroke(Theme.border); mst.Parent = main
	self.Main = main

	-- TOP BAR ---------------------------------------------------------
	local topbar = new("Frame", {
		Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 36), BackgroundTransparency = 1, Parent = main,
	}, { list(6, Enum.FillDirection.Horizontal) })
	table.insert(self._conns, makeDraggable(topbar, root))

	local function card(width, order, fill)
		local c = new("Frame", {
			Size = fill and UDim2.new(1, -(width), 1, 0) or UDim2.new(0, width, 1, 0),
			BackgroundColor3 = fill and Theme.text or Theme.surface, BorderSizePixel = 0, LayoutOrder = order,
			Parent = topbar,
		}, { corner(6) })
		if not fill then local s = stroke(Theme.border); s.Parent = c end
		table.insert(self._conns, makeDraggable(c, root))
		return c
	end
	local function circle(parent, key, x)
		local c = new("Frame", {
			Position = UDim2.new(0, x, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Theme.accentDark, BorderSizePixel = 0, Parent = parent,
		}, { corner(11) })
		local s = stroke(Theme.accent, 0.4); s.Parent = c
		icon(c, key, 12, Theme.text, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
		return c
	end
	local function twoLines(parent, x, l1, l2)
		local a = text({ Text = l1, Font = FONT_BOLD, TextSize = 11, Position = UDim2.new(0, x, 0, 6), Size = UDim2.new(1, -x - 4, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent })
		local b = text({ Text = l2, TextSize = 9, TextColor3 = Theme.textMuted, Position = UDim2.new(0, x, 0, 18), Size = UDim2.new(1, -x - 4, 0, 11), TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent })
		return a, b
	end

	-- 1 brand
	local brand = card(126 + 128 + 128 + 18, 1, true)
	brand.Size = UDim2.new(0, 140, 1, 0)
	new("UIGradient", {
		Color = ColorSequence.new(Theme.accentDark, Theme.accent), Parent = brand,
	})
	icon(brand, "Sparkle", 16, Theme.text, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0) })
	twoLines(brand, 34, opts.Title or "NERV / DEV", opts.Subtitle or "Grand Piece Online")

	-- 2 user
	local user = card(128, 2)
	local av = new("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.surfaceAlt, BorderSizePixel = 0, Parent = user,
	}, { corner(12) })
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then av.Image = img end
	end)
	twoLines(user, 38, lp.Name, lp.DisplayName)

	-- 3 time
	local time = card(128, 3)
	circle(time, "Clock", 8)
	local tl, dl = twoLines(time, 38, "TIME: --:--:--", "Date: --.--.----")

	-- 4 stats
	local stats = card(130, 4)
	stats.Size = UDim2.new(1, -(140 + 128 + 128 + 18), 1, 0)
	circle(stats, "Info", 8)
	local fl, pl = twoLines(stats, 38, "FPS: --", "Ping: -- ms")

	task.spawn(function()
		while gui.Parent do
			tl.Text = "TIME: " .. os.date("%H:%M:%S")
			dl.Text = "Date: " .. os.date("%d.%m.%Y")
			task.wait(1)
		end
	end)
	local frames, acc = 0, 0
	table.insert(self._conns, RunService.RenderStepped:Connect(function(dt)
		frames += 1; acc += dt
		if acc >= 0.5 then
			fl.Text = "FPS: " .. math.floor(frames / acc + 0.5)
			local ok, ping = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
			pl.Text = "Ping: " .. (ok and math.floor(ping) or 0) .. " ms"
			frames, acc = 0, 0
		end
	end))

	-- SIDEBAR ---------------------------------------------------------
	self.Sidebar = new("Frame", {
		Position = UDim2.fromOffset(8, 50), Size = UDim2.new(0, 95, 1, -58), BackgroundTransparency = 1, Parent = main,
	}, { list(4) })

	-- CONTENT ---------------------------------------------------------
	self.Content = new("Frame", {
		Position = UDim2.fromOffset(111, 50), Size = UDim2.new(1, -119, 1, -72), BackgroundTransparency = 1,
		ClipsDescendants = true, Parent = main,
	})

	-- WATERMARK -------------------------------------------------------
	local wm = text({
		Text = "Developer Mode", Font = FONT_BOLD, TextSize = 9, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -5), Size = UDim2.fromOffset(80, 12),
		TextXAlignment = Enum.TextXAlignment.Right, Parent = main,
	})
	new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.20, Color3.fromRGB(255, 190, 60)),
			ColorSequenceKeypoint.new(0.40, Color3.fromRGB(120, 230, 90)),
			ColorSequenceKeypoint.new(0.60, Color3.fromRGB(60, 210, 240)),
			ColorSequenceKeypoint.new(0.80, Color3.fromRGB(110, 120, 255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(230, 90, 230)),
		}),
		Parent = wm,
	})

	-- keybind
	table.insert(self._conns, UserInputService.InputBegan:Connect(function(i, gp)
		if gp then return end
		if i.KeyCode == self.Keybind then self:Toggle() end
	end))

	self:_animateOpen()
	return self
end

function UI:_animateOpen()
	self.Root.Visible = true
	self.UIScale.Scale = self.UserScale * 0.96
	self.Main.GroupTransparency = 1
	for _, s in ipairs(self._shadows) do s.Visible = true end
	tween(self.UIScale, { Scale = self.UserScale }, 0.25, Enum.EasingStyle.Quint)
	tween(self.Main, { GroupTransparency = 0 }, 0.25, Enum.EasingStyle.Quint)
end

function UI:Toggle(state)
	if state == nil then state = not self.Visible end
	if state == self.Visible then return end
	self.Visible = state
	if state then
		self:_animateOpen()
	else
		tween(self.UIScale, { Scale = self.UserScale * 0.96 }, 0.2, Enum.EasingStyle.Quint)
		local tw = tween(self.Main, { GroupTransparency = 1 }, 0.2, Enum.EasingStyle.Quint)
		for _, s in ipairs(self._shadows) do s.Visible = false end
		tw.Completed:Connect(function() if not self.Visible then self.Root.Visible = false end end)
	end
end

function UI:SetKeybind(key) self.Keybind = key end
function UI:SetScale(s) self.UserScale = s; self.UIScale.Scale = s end

function UI:SelectPage(page)
	for _, p in ipairs(self.Pages) do
		local on = p == page
		p.Frame.Visible = on
		tween(p.Row, { BackgroundTransparency = on and 0 or 1 }, 0.15)
		tween(p.RowStroke, { Transparency = on and 0 or 1 }, 0.15)
		tween(p.Label, { TextTransparency = on and 0 or 0.25 }, 0.15)
		p.Label.Font = on and FONT_BOLD or FONT
	end
	self.ActivePage = page
	task.defer(function() RunService.Heartbeat:Wait(); page:_underline(false) end)
end

function UI:AddPage(name, iconId)
	local row = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.surfaceAlt, BackgroundTransparency = 1,
		BorderSizePixel = 0, Text = "", AutoButtonColor = false, LayoutOrder = #self.Pages + 1, Parent = self.Sidebar,
	}, { corner(6) })
	local rst = stroke(Theme.border, 1); rst.Parent = row
	local ic = icon(row, "Page", 14, Theme.text, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0) })
	if iconId and iconId ~= "" and ic:IsA("ImageLabel") then ic.Image = iconId
	elseif iconId and iconId ~= "" then ic:Destroy(); new("ImageLabel", { BackgroundTransparency = 1, Image = iconId, Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Parent = row }) end
	local label = text({
		Text = name, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -44, 1, 0), TextTransparency = 0.25, Parent = row,
	})
	icon(row, "Kebab", 12, Theme.textMuted, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0) })

	local frame = new("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = self.Content })
	local tabBar = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = frame }, {
		list(0, Enum.FillDirection.Horizontal),
	})
	local underline = new("Frame", {
		Size = UDim2.fromOffset(0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = Theme.accent,
		BorderSizePixel = 0, ZIndex = 2, Parent = tabBar,
	})
	local area = new("Frame", {
		Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), BackgroundTransparency = 1, Parent = frame,
	})
	local page = setmetatable({
		Window = self, Name = name, Row = row, RowStroke = rst, Label = label, Frame = frame,
		TabBar = tabBar, Underline = underline, TabArea = area, Tabs = {},
	}, Page)
	table.insert(self.Pages, page)

	row.MouseEnter:Connect(function() if self.ActivePage ~= page then tween(row, { BackgroundTransparency = 0.5 }) end end)
	row.MouseLeave:Connect(function() if self.ActivePage ~= page then tween(row, { BackgroundTransparency = 1 }) end end)
	row.MouseButton1Click:Connect(function() self:SelectPage(page) end)
	if #self.Pages == 1 then self:SelectPage(page) end
	return page
end

function UI:Destroy()
	for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
	self.Gui:Destroy()
end

UI.Theme = Theme
UI.Icons = Icons
return UI
