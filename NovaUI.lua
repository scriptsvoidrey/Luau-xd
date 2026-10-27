--[[
    NOVA UI - Standalone Luau UI Library
    Version: 1.0.0
    No external URLs, modules, or asset downloads.
    Designed for LocalScripts in Roblox experiences you own or are authorized to develop.

    Quick start:
        local Nova = loadstring(readfile("NovaUI.lua"))() -- only if your environment supports this
        -- In a normal Roblox project, place this ModuleScript in your game and use:
        -- local Nova = require(path.to.NovaUI)

        local Window = Nova:CreateWindow({
            Title = "My Script",
            Subtitle = "Nova UI",
            Size = UDim2.fromOffset(600, 420)
        })

        local Tab = Window:CreateTab("Main", "⌂")
        Tab:CreateButton({Name = "Say hello", Callback = function() print("Hello!") end})
        Tab:CreateToggle({Name = "Enabled", Default = false, Callback = function(v) print(v) end})
        Tab:CreateSlider({Name = "Power", Min = 0, Max = 100, Default = 25, Callback = function(v) print(v) end})
        Tab:CreateDropdown({Name = "Mode", Options = {"Easy", "Normal", "Hard"}, Default = "Normal", Callback = function(v) print(v) end})
        Tab:CreateTextbox({Name = "Player name", Placeholder = "Type here...", Callback = function(v) print(v) end})
        Tab:CreateKeybind({Name = "Toggle feature", Default = Enum.KeyCode.G, Callback = function() print("Pressed") end})
        Tab:CreateColorPicker({Name = "Accent", Default = Color3.fromRGB(115, 90, 255), Callback = function(c) print(c) end})
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Nova = {}
Nova.__index = Nova

local DEFAULTS = {
    Accent = Color3.fromRGB(126, 96, 255),
    Background = Color3.fromRGB(17, 18, 25),
    Panel = Color3.fromRGB(25, 26, 36),
    Element = Color3.fromRGB(34, 35, 48),
    Text = Color3.fromRGB(245, 245, 250),
    Muted = Color3.fromRGB(155, 157, 174),
    Border = Color3.fromRGB(55, 56, 73),
    Success = Color3.fromRGB(65, 200, 130),
    Danger = Color3.fromRGB(245, 85, 100)
}

local function make(className, props, children)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = obj
    end
    return obj
end

local function corner(parent, radius)
    return make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, { })
end

local function stroke(parent, color, transparency)
    return make("UIStroke", {
        Color = color or DEFAULTS.Border,
        Transparency = transparency or 0,
        Thickness = 1
    }, {})
end

local function tween(obj, duration, props)
    local ok, result = pcall(function()
        local t = TweenService:Create(obj, TweenInfo.new(duration or 0.15, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
        t:Play()
        return t
    end)
    return ok and result or nil
end

local function addCorner(obj, radius)
    corner(obj, radius).Parent = obj
end

local function addStroke(obj, color, transparency)
    stroke(obj, color, transparency).Parent = obj
end

local function createLabel(parent, text, size, color, font)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        TextSize = size or 14,
        TextColor3 = color or DEFAULTS.Text,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, 0, 0, 20)
    }, {})
end

local function normalizeKey(key)
    if typeof(key) == "EnumItem" then return key end
    if type(key) == "string" then
        local ok, value = pcall(function() return Enum.KeyCode[key] end)
        if ok then return value end
    end
    return Enum.KeyCode.Unknown
end

function Nova.new(options)
    options = options or {}
    local self = setmetatable({}, Nova)
    self.Options = options
    self.Theme = {}
    for k, v in pairs(DEFAULTS) do self.Theme[k] = v end
    for k, v in pairs(options.Theme or {}) do
        if self.Theme[k] ~= nil then self.Theme[k] = v end
    end
    self.Connections = {}
    self.Windows = {}
    self.Destroyed = false
    return self
end

function Nova:Notify(options)
    options = type(options) == "table" and options or {Title = "Nova UI", Content = tostring(options)}
    local title = tostring(options.Title or "Nova UI")
    local content = tostring(options.Content or options.Description or "")
    local duration = tonumber(options.Duration) or 3
    local player = Players.LocalPlayer
    if not player then return end

    local gui = player:FindFirstChildOfClass("PlayerGui")
    if not gui then return end
    local holder = gui:FindFirstChild("NovaNotifications")
    if not holder then
        holder = make("ScreenGui", {
            Name = "NovaNotifications",
            ResetOnSpawn = false,
            IgnoreGuiInset = true,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        }, {})
        holder.Parent = gui
        local list = make("Frame", {
            Name = "Holder", BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16),
            Size = UDim2.new(0, 300, 1, -32)
        }, {})
        list.Parent = holder
        make("UIListLayout", {
            Padding = UDim.new(0, 8),
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            SortOrder = Enum.SortOrder.LayoutOrder
        }, {}).Parent = list
    end

    local list = holder:FindFirstChild("Holder")
    local card = make("Frame", {
        BackgroundColor3 = self.Theme.Panel,
        Size = UDim2.new(1, 0, 0, 76),
        BackgroundTransparency = 0.04
    }, {})
    addCorner(card, 10)
    addStroke(card, self.Theme.Border)
    local bar = make("Frame", {BackgroundColor3 = self.Theme.Accent, Size = UDim2.new(0, 4, 1, 0)}, {})
    addCorner(bar, 4); bar.Parent = card
    local t = createLabel(card, title, 14, self.Theme.Text, Enum.Font.GothamBold)
    t.Position = UDim2.fromOffset(14, 9); t.Size = UDim2.new(1, -24, 0, 20)
    local d = createLabel(card, content, 12, self.Theme.Muted)
    d.Position = UDim2.fromOffset(14, 32); d.Size = UDim2.new(1, -24, 0, 34)
    d.TextWrapped = true; d.TextYAlignment = Enum.TextYAlignment.Top
    card.Parent = list
    card.BackgroundTransparency = 1
    tween(card, 0.18, {BackgroundTransparency = 0.04})
    task.delay(math.max(0.5, duration), function()
        if card and card.Parent then
            tween(card, 0.18, {BackgroundTransparency = 1})
            task.wait(0.2)
            if card then card:Destroy() end
        end
    end)
end

function Nova:CreateWindow(options)
    assert(not self.Destroyed, "Nova UI has been destroyed")
    options = options or {}
    local player = Players.LocalPlayer
    assert(player, "Nova UI must be created from a LocalScript")
    local playerGui = player:WaitForChild("PlayerGui")

    local gui = make("ScreenGui", {
        Name = options.GuiName or "NovaUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, {})
    gui.Parent = playerGui

    local root = make("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = options.Position or UDim2.fromScale(0.5, 0.5),
        Size = options.Size or UDim2.fromOffset(620, 430),
        BackgroundColor3 = self.Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true
    }, {})
    root.Parent = gui
    addCorner(root, 13); addStroke(root, self.Theme.Border)

    local scale = make("UIScale", {Scale = 1}, {})
    scale.Parent = root
    local function updateScale()
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local s = math.min(1, viewport.X / 420, viewport.Y / 320)
        scale.Scale = math.max(0.65, s)
    end
    updateScale()
    local cameraConnection
    pcall(function()
        cameraConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    end)

    local top = make("Frame", {
        Name = "Topbar", BackgroundColor3 = self.Theme.Panel, BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 54)
    }, {})
    top.Parent = root
    local title = createLabel(top, tostring(options.Title or "NOVA UI"), 16, self.Theme.Text, Enum.Font.GothamBold)
    title.Position = UDim2.fromOffset(18, 7); title.Size = UDim2.new(1, -130, 0, 22)
    local subtitle = createLabel(top, tostring(options.Subtitle or "Standalone interface"), 11, self.Theme.Muted)
    subtitle.Position = UDim2.fromOffset(19, 29); subtitle.Size = UDim2.new(1, -130, 0, 16)

    local close = make("TextButton", {
        Name = "Close", Text = "×", Font = Enum.Font.GothamBold, TextSize = 24,
        TextColor3 = self.Theme.Muted, BackgroundColor3 = self.Theme.Element,
        AutoButtonColor = false, Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(1, -44, 0, 11)
    }, {})
    close.Parent = top; addCorner(close, 8)
    close.MouseEnter:Connect(function() tween(close, 0.12, {BackgroundColor3 = self.Theme.Danger, TextColor3 = Color3.new(1,1,1)}) end)
    close.MouseLeave:Connect(function() tween(close, 0.12, {BackgroundColor3 = self.Theme.Element, TextColor3 = self.Theme.Muted}) end)

    local sidebar = make("Frame", {
        Name = "Sidebar", BackgroundColor3 = self.Theme.Panel, BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 54), Size = UDim2.new(0, 156, 1, -54)
    }, {})
    sidebar.Parent = root
    make("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, {}).Parent = sidebar
    make("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, {}).Parent = sidebar

    local content = make("Frame", {
        Name = "Content", BackgroundTransparency = 1,
        Position = UDim2.new(0, 156, 0, 54), Size = UDim2.new(1, -156, 1, -54)
    }, {})
    content.Parent = root

    local window = {
        Nova = self, Gui = gui, Root = root, Sidebar = sidebar, Content = content,
        Tabs = {}, ActiveTab = nil, Elements = {}, Destroyed = false,
        ToggleKey = normalizeKey(options.ToggleKey or Enum.KeyCode.RightControl)
    }

    -- Drag from the topbar, with touch support.
    do
        local dragging, dragInput, dragStart, startPos
        top.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true; dragStart = input.Position; startPos = root.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        top.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
    end

    local function setVisible(value)
        root.Visible = value
    end
    close.MouseButton1Click:Connect(function()
        window:Destroy()
    end)
    local keyConn = UserInputService.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == window.ToggleKey then
            setVisible(not root.Visible)
        end
    end)
    table.insert(window.Connections or {}, keyConn)
    window._keyConnection = keyConn
    window._cameraConnection = cameraConnection

    function window:SelectTab(tabOrName)
        local tab = type(tabOrName) == "table" and tabOrName or self.Tabs[tabOrName]
        if not tab then return end
        if self.ActiveTab then
            self.ActiveTab.Page.Visible = false
            tween(self.ActiveTab.Button, 0.12, {BackgroundColor3 = self.Nova.Theme.Panel, TextColor3 = self.Nova.Theme.Muted})
        end
        self.ActiveTab = tab
        tab.Page.Visible = true
        tween(tab.Button, 0.12, {BackgroundColor3 = self.Nova.Theme.Accent, TextColor3 = Color3.new(1,1,1)})
    end

    function window:CreateTab(name, iconText)
        name = tostring(name or "Tab")
        assert(not self.Tabs[name], "A tab with this name already exists")
        local tabButton = make("TextButton", {
            Name = "Tab_" .. name, Text = (iconText and (tostring(iconText) .. "   ") or "") .. name,
            Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = self.Nova.Theme.Muted,
            TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = self.Nova.Theme.Panel,
            AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 36)
        }, {})
        tabButton.Parent = self.Sidebar; addCorner(tabButton, 8)
        local page = make("ScrollingFrame", {
            Name = "Page_" .. name, BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.fromScale(1,1), CanvasSize = UDim2.new(),
            ScrollBarThickness = 3, ScrollBarImageColor3 = self.Nova.Theme.Accent,
            AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false
        }, {})
        page.Parent = self.Content
        make("UIPadding", {PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16)}, {}).Parent = page
        make("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}, {}).Parent = page

        local tab = {Name = name, Button = tabButton, Page = page, Window = self, Elements = {}}
        self.Tabs[name] = tab
        tabButton.MouseButton1Click:Connect(function() self:SelectTab(tab) end)

        local function baseElement(label, description, height)
            local frame = make("Frame", {
                Name = label:gsub("%W", "") .. "Element",
                BackgroundColor3 = self.Nova.Theme.Element,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, height or (description and 66 or 52))
            }, {})
            addCorner(frame, 9); addStroke(frame, self.Nova.Theme.Border, 0.45)
            frame.Parent = page
            local lbl = createLabel(frame, tostring(label), 13, self.Nova.Theme.Text, Enum.Font.GothamMedium)
            lbl.Position = UDim2.fromOffset(13, 8); lbl.Size = UDim2.new(1, -26, 0, 20)
            if description and description ~= "" then
                local desc = createLabel(frame, tostring(description), 11, self.Nova.Theme.Muted)
                desc.Position = UDim2.fromOffset(13, 29); desc.Size = UDim2.new(1, -26, 0, 22)
                desc.TextTruncate = Enum.TextTruncate.AtEnd
            end
            table.insert(tab.Elements, frame)
            return frame
        end

        function tab:CreateSection(textValue)
            local label = createLabel(page, tostring(textValue or "SECTION"), 11, self.Window.Nova.Theme.Accent, Enum.Font.GothamBold)
            label.Size = UDim2.new(1, 0, 0, 20)
            return label
        end

        function tab:CreateButton(config)
            config = type(config) == "table" and config or {Name = tostring(config)}
            local frame = baseElement(config.Name or "Button", config.Description, config.Description and 66 or 52)
            local button = make("TextButton", {
                Text = tostring(config.ButtonText or "Run"), Font = Enum.Font.GothamBold, TextSize = 12,
                TextColor3 = Color3.new(1,1,1), BackgroundColor3 = self.Window.Nova.Theme.Accent,
                AutoButtonColor = false, AnchorPoint = Vector2.new(1,0.5),
                Position = UDim2.new(1,-12,0.5,0), Size = UDim2.fromOffset(88,30)
            }, {})
            button.Parent = frame; addCorner(button, 7)
            local label = frame:FindFirstChildOfClass("TextLabel")
            label.Size = UDim2.new(1,-115,0,20)
            button.MouseEnter:Connect(function() tween(button, 0.12, {BackgroundColor3 = self.Window.Nova.Theme.Accent:Lerp(Color3.new(1,1,1),0.12)}) end)
            button.MouseLeave:Connect(function() tween(button, 0.12, {BackgroundColor3 = self.Window.Nova.Theme.Accent}) end)
            button.MouseButton1Click:Connect(function()
                if type(config.Callback) == "function" then
                    local ok, err = pcall(config.Callback)
                    if not ok then self.Window.Nova:Notify({Title = "Callback error", Content = tostring(err), Duration = 4}) end
                end
            end)
            return {Frame=frame, Button=button}
        end

        function tab:CreateToggle(config)
            config = config or {}
            local state = config.Default == true
            local frame = baseElement(config.Name or "Toggle", config.Description, config.Description and 66 or 52)
            local toggle = make("TextButton", {
                Text = "", AutoButtonColor = false, BackgroundColor3 = state and self.Window.Nova.Theme.Accent or self.Window.Nova.Theme.Border,
                AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-13,0.5,0), Size = UDim2.fromOffset(42,23)
            }, {})
            toggle.Parent = frame; addCorner(toggle, 12)
            local knob = make("Frame", {
                BackgroundColor3 = Color3.new(1,1,1), Size = UDim2.fromOffset(17,17),
                Position = state and UDim2.new(1,-20,0.5,-8) or UDim2.new(0,3,0.5,-8)
            }, {})
            knob.Parent = toggle; addCorner(knob, 9)
            local function set(value, fire)
                state = value == true
                tween(toggle, 0.12, {BackgroundColor3 = state and self.Window.Nova.Theme.Accent or self.Window.Nova.Theme.Border})
                tween(knob, 0.12, {Position = state and UDim2.new(1,-20,0.5,-8) or UDim2.new(0,3,0.5,-8)})
                if fire ~= false and type(config.Callback) == "function" then
                    local ok, err = pcall(config.Callback, state)
                    if not ok then self.Window.Nova:Notify({Title="Callback error",Content=tostring(err)}) end
                end
            end
            toggle.MouseButton1Click:Connect(function() set(not state) end)
            return {Frame=frame, SetValue=set, GetValue=function() return state end}
        end

        function tab:CreateSlider(config)
            config = config or {}
            local min = tonumber(config.Min) or 0
            local max = tonumber(config.Max) or 100
            if max <= min then max = min + 1 end
            local value = math.clamp(tonumber(config.Default) or min, min, max)
            local frame = baseElement(config.Name or "Slider", config.Description, 78)
            local valueLabel = createLabel(frame, tostring(value), 11, self.Window.Nova.Theme.Muted)
            valueLabel.TextXAlignment = Enum.TextXAlignment.Right
            valueLabel.Position = UDim2.new(1,-14,0,8); valueLabel.Size = UDim2.new(0,70,0,20)
            local bar = make("Frame", {BackgroundColor3=self.Window.Nova.Theme.Border, Position=UDim2.new(0,13,0,51), Size=UDim2.new(1,-26,0,7)}, {})
            bar.Parent=frame; addCorner(bar,5)
            local fill = make("Frame", {BackgroundColor3=self.Window.Nova.Theme.Accent, Size=UDim2.new((value-min)/(max-min),0,1,0)}, {})
            fill.Parent=bar; addCorner(fill,5)
            local hit = make("TextButton", {BackgroundTransparency=1,Text="",Size=UDim2.new(1,0,0,20),Position=UDim2.new(0,0,0.5,-10)}, {})
            hit.Parent=bar
            local dragging = false
            local function set(v, fire)
                value = math.clamp(tonumber(v) or min,min,max)
                local precision = tonumber(config.Precision)
                if precision == nil then precision = 0 end
                local factor = 10 ^ math.clamp(precision,0,4)
                value = math.floor(value*factor+0.5)/factor
                valueLabel.Text = tostring(value)
                tween(fill,0.08,{Size=UDim2.new((value-min)/(max-min),0,1,0)})
                if fire ~= false and type(config.Callback)=="function" then
                    local ok,err=pcall(config.Callback,value)
                    if not ok then self.Window.Nova:Notify({Title="Callback error",Content=tostring(err)}) end
                end
            end
            local function update(input)
                local ratio=math.clamp((input.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
                set(min+(max-min)*ratio)
            end
            hit.InputBegan:Connect(function(input)
                if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true; update(input) end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then update(input) end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end
            end)
            return {Frame=frame,SetValue=set,GetValue=function() return value end}
        end

        function tab:CreateDropdown(config)
            config = config or {}
            local options = config.Options or {}
            local selected = config.Default
            if selected == nil then selected = options[1] end
            local frame = baseElement(config.Name or "Dropdown", config.Description, 66)
            local choice = make("TextButton", {
                Text = tostring(selected or "Select") .. "  ▾", Font=Enum.Font.Gotham, TextSize=11,
                TextColor3=self.Window.Nova.Theme.Text, BackgroundColor3=self.Window.Nova.Theme.Panel,
                AutoButtonColor=false, AnchorPoint=Vector2.new(1,0.5),
                Position=UDim2.new(1,-12,0.5,0), Size=UDim2.fromOffset(135,30)
            }, {})
            choice.Parent=frame; addCorner(choice,7)
            local label=frame:FindFirstChildOfClass("TextLabel"); label.Size=UDim2.new(1,-165,0,20)
            local expanded=false
            local optionFrame=make("Frame",{
                Visible=false, BackgroundColor3=self.Window.Nova.Theme.Panel, BorderSizePixel=0,
                Position=UDim2.new(0,0,1,4), Size=UDim2.new(1,0,0,0), ZIndex=20
            }, {})
            optionFrame.Parent=frame; addCorner(optionFrame,7); addStroke(optionFrame,self.Window.Nova.Theme.Border)
            local layout=make("UIListLayout",{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder},{}); layout.Parent=optionFrame
            local function rebuild()
                for _,child in ipairs(optionFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
                for _,item in ipairs(options) do
                    local b=make("TextButton",{Text=tostring(item),Font=Enum.Font.Gotham,TextSize=11,TextColor3=self.Window.Nova.Theme.Text,BackgroundColor3=self.Window.Nova.Theme.Element,BorderSizePixel=0,Size=UDim2.new(1,0,0,28),ZIndex=21}, {})
                    b.Parent=optionFrame
                    b.MouseButton1Click:Connect(function()
                        selected=item; choice.Text=tostring(item).."  ▾"; expanded=false; optionFrame.Visible=false
                        if type(config.Callback)=="function" then
                            local ok,err=pcall(config.Callback,item)
                            if not ok then self.Window.Nova:Notify({Title="Callback error",Content=tostring(err)}) end
                        end
                    end)
                end
                optionFrame.Size=UDim2.new(1,0,0,math.min(#options,5)*30)
            end
            rebuild()
            choice.MouseButton1Click:Connect(function()
                expanded=not expanded; optionFrame.Visible=expanded
                if expanded then optionFrame.ZIndex=20 end
            end)
            return {
                Frame=frame,
                SetOptions=function(newOptions) options=newOptions or {}; rebuild() end,
                SetValue=function(v) selected=v; choice.Text=tostring(v).."  ▾" end,
                GetValue=function() return selected end
            }
        end

        function tab:CreateTextbox(config)
            config = config or {}
            local frame=baseElement(config.Name or "Textbox",config.Description,66)
            local box=make("TextBox",{
                Text=tostring(config.Default or ""),PlaceholderText=tostring(config.Placeholder or "Enter text..."),
                ClearTextOnFocus=config.ClearOnFocus==true,Font=Enum.Font.Gotham,TextSize=12,
                TextColor3=self.Window.Nova.Theme.Text,PlaceholderColor3=self.Window.Nova.Theme.Muted,
                BackgroundColor3=self.Window.Nova.Theme.Panel,BorderSizePixel=0,
                AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(160,32)
            }, {})
            box.Parent=frame; addCorner(box,7)
            local label=frame:FindFirstChildOfClass("TextLabel"); label.Size=UDim2.new(1,-185,0,20)
            box.FocusLost:Connect(function(enterPressed)
                if type(config.Callback)=="function" then
                    local ok,err=pcall(config.Callback,box.Text,enterPressed)
                    if not ok then self.Window.Nova:Notify({Title="Callback error",Content=tostring(err)}) end
                end
            end)
            return {Frame=frame,Input=box,GetValue=function() return box.Text end,SetValue=function(v) box.Text=tostring(v) end}
        end

        function tab:CreateKeybind(config)
            config = config or {}
            local key=normalizeKey(config.Default or Enum.KeyCode.G)
            local listening=false
            local frame=baseElement(config.Name or "Keybind",config.Description,config.Description and 66 or 52)
            local button=make("TextButton",{
                Text=key.Name,Font=Enum.Font.GothamBold,TextSize=11,TextColor3=self.Window.Nova.Theme.Text,
                BackgroundColor3=self.Window.Nova.Theme.Panel,AutoButtonColor=false,
                AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(80,30)
            }, {})
            button.Parent=frame; addCorner(button,7)
            local label=frame:FindFirstChildOfClass("TextLabel"); label.Size=UDim2.new(1,-105,0,20)
            button.MouseButton1Click:Connect(function() listening=true; button.Text="..." end)
            local conn=UserInputService.InputBegan:Connect(function(input,processed)
                if listening then
                    if input.UserInputType==Enum.UserInputType.Keyboard then
                        key=input.KeyCode; listening=false; button.Text=key.Name
                    end
                elseif not processed and input.KeyCode==key then
                    if type(config.Callback)=="function" then
                        local ok,err=pcall(config.Callback,key)
                        if not ok then self.Window.Nova:Notify({Title="Callback error",Content=tostring(err)}) end
                    end
                end
            end)
            table.insert(self.Window._connections,conn)
            return {Frame=frame,GetValue=function() return key end,SetValue=function(v) key=normalizeKey(v);button.Text=key.Name end}
        end

        function tab:CreateColorPicker(config)
            config=config or {}
            local color=config.Default or self.Window.Nova.Theme.Accent
            local frame=baseElement(config.Name or "Color",config.Description,56)
            local preview=make("TextButton",{Text="",BackgroundColor3=color,AutoButtonColor=false,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-12,0.5,0),Size=UDim2.fromOffset(54,28)}, {})
            preview.Parent=frame;addCorner(preview,7);addStroke(preview,self.Window.Nova.Theme.Border)
            local palette=make("Frame",{Visible=false,BackgroundColor3=self.Window.Nova.Theme.Panel,BorderSizePixel=0,Position=UDim2.new(0,0,1,4),Size=UDim2.new(1,0,0,0),ZIndex=30}, {})
            palette.Parent=frame;addCorner(palette,8);addStroke(palette,self.Window.Nova.Theme.Border)
            local colors={Color3.fromRGB(126,96,255),Color3.fromRGB(65,200,130),Color3.fromRGB(60,160,255),Color3.fromRGB(255,90,120),Color3.fromRGB(255,175,65),Color3.fromRGB(245,245,250),Color3.fromRGB(30,30,40),Color3.fromRGB(30,200,190)}
            local grid=make("UIGridLayout",{CellSize=UDim2.fromOffset(34,26),CellPadding=UDim2.fromOffset(6,6),HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Center},{});grid.Parent=palette
            for _,c in ipairs(colors) do
                local b=make("TextButton",{Text="",BackgroundColor3=c,BorderSizePixel=0,ZIndex=31},{});b.Parent=palette;addCorner(b,6)
                b.MouseButton1Click:Connect(function()
                    color=c;preview.BackgroundColor3=c;palette.Visible=false
                    if type(config.Callback)=="function" then
                        local ok,err=pcall(config.Callback,color)
                        if not ok then self.Window.Nova:Notify({Title="Callback error",Content=tostring(err)}) end
                    end
                end)
            end
            palette.Size=UDim2.new(1,0,0,82)
            preview.MouseButton1Click:Connect(function() palette.Visible=not palette.Visible end)
            return {Frame=frame,GetValue=function() return color end,SetValue=function(c) if typeof(c)=="Color3" then color=c;preview.BackgroundColor3=c end end}
        end

        function tab:CreateLabel(textValue)
            local label=createLabel(page,tostring(textValue or ""),13,self.Window.Nova.Theme.Muted)
            label.Size=UDim2.new(1,0,0,24)
            return {Label=label,SetText=function(v) label.Text=tostring(v) end}
        end

        function tab:CreateParagraph(config)
            config=config or {}
            local frame=baseElement(config.Title or "Information",nil,74)
            local label=createLabel(frame,tostring(config.Content or ""),12,self.Window.Nova.Theme.Muted)
            label.Position=UDim2.fromOffset(13,31);label.Size=UDim2.new(1,-26,0,34);label.TextWrapped=true;label.TextYAlignment=Enum.TextYAlignment.Top
            return {Frame=frame,SetContent=function(v) label.Text=tostring(v) end}
        end

        if not self.ActiveTab then self:SelectTab(tab) end
        return tab
    end

    function window:SetToggleKey(key)
        self.ToggleKey = normalizeKey(key)
    end

    function window:SetTitle(value)
        title.Text = tostring(value)
    end

    function window:Destroy()
        if self.Destroyed then return end
        self.Destroyed = true
        if self._keyConnection then self._keyConnection:Disconnect() end
        if self._cameraConnection then self._cameraConnection:Disconnect() end
        for _,conn in ipairs(self._connections or {}) do pcall(function() conn:Disconnect() end) end
        if gui then gui:Destroy() end
    end
    window._connections = {}
    table.insert(self.Windows, window)
    return window
end

function Nova:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true
    for _,window in ipairs(self.Windows) do
        pcall(function() window:Destroy() end)
    end
    for _,conn in ipairs(self.Connections) do pcall(function() conn:Disconnect() end) end
end

function Nova:CreateConfig()
    -- Returns an in-memory configuration helper; no filesystem APIs are assumed.
    local config = {Values = {}}
    function config:Set(key, value) self.Values[tostring(key)] = value end
    function config:Get(key, fallback)
        local value = self.Values[tostring(key)]
        if value == nil then return fallback end
        return value
    end
    function config:Export()
        local safe = {}
        for k,v in pairs(self.Values) do
            if typeof(v) == "Color3" then
                safe[k] = {__type="Color3",r=v.R,g=v.G,b=v.B}
            elseif typeof(v) == "EnumItem" then
                safe[k] = {__type="EnumItem",enum=tostring(v.EnumType),name=v.Name}
            elseif type(v) == "string" or type(v) == "number" or type(v) == "boolean" or v == nil then
                safe[k] = v
            end
        end
        local ok, result = pcall(function() return HttpService:JSONEncode(safe) end)
        return ok and result or nil
    end
    function config:Import(json)
        local ok, decoded = pcall(function() return HttpService:JSONDecode(json) end)
        if not ok or type(decoded) ~= "table" then return false end
        for k,v in pairs(decoded) do
            if type(v)=="table" and v.__type=="Color3" then
                self.Values[k]=Color3.new(v.r,v.g,v.b)
            elseif type(v)=="table" and v.__type=="EnumItem" then
                local enumName=tostring(v.enum):match("Enum%.(.+)")
                if enumName and Enum[enumName] then
                    local success,item=pcall(function() return Enum[enumName][v.name] end)
                    if success then self.Values[k]=item end
                end
            else self.Values[k]=v end
        end
        return true
    end
    return config
end

return Nova.new()
