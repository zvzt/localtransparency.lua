local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Workspace=game:GetService("Workspace")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local env=getgenv and getgenv() or _G
local targetParent=playerGui

pcall(function()
	if gethui then
		targetParent=gethui()
	end
end)

if env.BodyTransparencyCleanup then
	pcall(env.BodyTransparencyCleanup)
end

for _,parent in ipairs({targetParent,playerGui}) do
	local old=parent:FindFirstChild("BodyTransparencyUI")
	if old then
		old:Destroy()
	end
end

local WINDOW=Color3.fromRGB(0,0,0)
local WINDOW_STROKE=Color3.fromRGB(45,45,50)
local PANEL=Color3.fromRGB(18,18,22)
local PANEL_STROKE=Color3.fromRGB(32,32,36)
local TEXT=Color3.fromRGB(240,240,245)
local BUTTON_TEXT=Color3.fromRGB(225,225,232)
local MUTED=Color3.fromRGB(120,120,130)

local FULL_WIDTH=360
local FULL_HEIGHT=140
local COLLAPSED_HEIGHT=38

local connections={}
local models={}
local parts={}
local originals={}

local enabled=false
local amount=.5
local draggingSlider=false
local destroyed=false
local collapsed=false
local sizeTween=nil
local camera=Workspace.CurrentCamera
local cameraSubjectConnection=nil

local function connect(signal,callback)
	local connection=signal:Connect(callback)
	table.insert(connections,connection)
	return connection
end

local function corner(object,radius)
	local c=Instance.new("UICorner",object)
	c.CornerRadius=UDim.new(0,radius)
	return c
end

local function stroke(object,color,thickness)
	local s=Instance.new("UIStroke",object)
	s.Color=color
	s.Thickness=thickness
	s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
	return s
end

local function otherPlayersRig(model)
	for _,otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer~=player and otherPlayer.Character then
			if model==otherPlayer.Character
				or model:IsDescendantOf(otherPlayer.Character) then

				return true
			end
		end
	end

	return false
end

local function forcePart(part)
	if not enabled or not part.Parent then
		return
	end

	local wanted=part.Name=="HumanoidRootPart" and 1 or amount

	if part.LocalTransparencyModifier~=wanted then
		part.LocalTransparencyModifier=wanted
	end
end

local function trackPart(part)
	if parts[part] or not part:IsA("BasePart") then
		return
	end

	parts[part]=true
	originals[part]=part.LocalTransparencyModifier

	connect(
		part:GetPropertyChangedSignal("LocalTransparencyModifier"),
		function()
			forcePart(part)
		end
	)

	connect(part.AncestryChanged,function()
		if not part.Parent then
			parts[part]=nil
			originals[part]=nil
		end
	end)

	forcePart(part)
end

local function trackModel(model)
	if not model
		or models[model]
		or not model:IsA("Model")
		or otherPlayersRig(model) then

		return
	end

	models[model]=true

	for _,descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			trackPart(descendant)
		end
	end

	connect(model.DescendantAdded,function(descendant)
		if descendant:IsA("BasePart") then
			trackPart(descendant)
		end
	end)

	connect(model.AncestryChanged,function()
		if not model.Parent then
			models[model]=nil
		end
	end)
end

local function subjectModel()
	camera=Workspace.CurrentCamera

	if not camera then
		return
	end

	local subject=camera.CameraSubject

	if not subject then
		return
	end

	local model

	if subject:IsA("Model") then
		model=subject
	else
		model=subject:FindFirstAncestorOfClass("Model")
	end

	if model and not otherPlayersRig(model) then
		trackModel(model)
	end
end

local function scanModel(model)
	if not model:IsA("Model") or otherPlayersRig(model) then
		return
	end

	if model==player.Character then
		trackModel(model)
		return
	end

	local humanoid=model:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return
	end

	local modelName=string.lower(model.Name)
	local playerName=string.lower(player.Name)
	local displayName=string.lower(player.DisplayName)
	local humanoidName=string.lower(humanoid.DisplayName or "")

	if modelName==playerName
		or modelName==displayName
		or humanoidName==playerName
		or humanoidName==displayName
		or modelName:find(playerName,1,true) then

		trackModel(model)
	end
end

local function initialScan()
	if player.Character then
		trackModel(player.Character)
	end

	subjectModel()

	for _,descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("Model") then
			scanModel(descendant)
		end
	end
end

local function applyTracked()
	for part in pairs(parts) do
		if part.Parent then
			forcePart(part)
		end
	end
end

local function restore()
	for part in pairs(parts) do
		if part.Parent then
			part.LocalTransparencyModifier=originals[part] or 0
		end
	end
end

local function watchCamera()
	if cameraSubjectConnection then
		pcall(function()
			cameraSubjectConnection:Disconnect()
		end)

		cameraSubjectConnection=nil
	end

	camera=Workspace.CurrentCamera

	if not camera then
		return
	end

	cameraSubjectConnection=connect(
		camera:GetPropertyChangedSignal("CameraSubject"),
		function()
			task.defer(subjectModel)
		end
	)

	task.defer(subjectModel)
end

connect(player.CharacterAdded,function(character)
	trackModel(character)

	task.defer(function()
		subjectModel()

		if enabled then
			applyTracked()
		end
	end)
end)

connect(Workspace.DescendantAdded,function(descendant)
	if descendant:IsA("Model") then
		task.defer(function()
			scanModel(descendant)
		end)

	elseif descendant:IsA("BasePart") then
		task.defer(function()
			local model=descendant:FindFirstAncestorOfClass("Model")

			if model and models[model] then
				trackPart(descendant)
			end
		end)
	end
end)

connect(
	Workspace:GetPropertyChangedSignal("CurrentCamera"),
	watchCamera
)

watchCamera()
initialScan()

local gui=Instance.new("ScreenGui")
gui.Name="BodyTransparencyUI"
gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=targetParent

local function cleanup()
	if destroyed then
		return
	end

	destroyed=true
	enabled=false

	if sizeTween then
		pcall(function()
			sizeTween:Cancel()
		end)
	end

	restore()

	for _,connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	table.clear(connections)

	pcall(function()
		gui:Destroy()
	end)

	if env.BodyTransparencyCleanup==cleanup then
		env.BodyTransparencyCleanup=nil
	end
end

env.BodyTransparencyCleanup=cleanup

local function makeDraggable(dragHandle,targetFrame)
	targetFrame=targetFrame or dragHandle

	local dragging=false
	local dragStart
	local startPos

	connect(dragHandle.InputBegan,function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1
			or input.UserInputType==Enum.UserInputType.Touch then

			dragging=true
			dragStart=input.Position

			startPos=Vector2.new(
				targetFrame.Position.X.Offset,
				targetFrame.Position.Y.Offset
			)
		end
	end)

	connect(UIS.InputChanged,function(input)
		if not dragging then
			return
		end

		if input.UserInputType~=Enum.UserInputType.MouseMovement
			and input.UserInputType~=Enum.UserInputType.Touch then

			return
		end

		local currentCamera=Workspace.CurrentCamera

		if not currentCamera then
			return
		end

		local delta=input.Position-dragStart
		local size=targetFrame.AbsoluteSize
		local viewport=currentCamera.ViewportSize
		local topOffset=-57
		local bottomOffset=57

		local x=math.clamp(
			startPos.X+delta.X,
			0,
			math.max(
				0,
				viewport.X-size.X
			)
		)

		local y=math.clamp(
			startPos.Y+delta.Y,
			topOffset,
			math.max(
				topOffset,
				viewport.Y-size.Y-bottomOffset
			)
		)

		targetFrame.Position=UDim2.fromOffset(x,y)
	end)

	connect(UIS.InputEnded,function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1
			or input.UserInputType==Enum.UserInputType.Touch then

			dragging=false
		end
	end)
end

local main=Instance.new("Frame",gui)
main.Name="SlateWindow_Transparency"
main.Size=UDim2.fromOffset(FULL_WIDTH,FULL_HEIGHT)
main.BackgroundColor3=WINDOW
main.BorderSizePixel=0
main.ClipsDescendants=true
main.Active=true

corner(main,10)
stroke(main,WINDOW_STROKE,1.2)

local currentCamera=Workspace.CurrentCamera

if currentCamera then
	local viewport=currentCamera.ViewportSize

	main.Position=UDim2.fromOffset(
		math.floor((viewport.X-FULL_WIDTH)/2),
		math.floor((viewport.Y-FULL_HEIGHT)/2)
	)
else
	main.Position=UDim2.new(.5,-180,.5,-70)
end

local header=Instance.new("Frame",main)
header.Name="HeaderBar"
header.Size=UDim2.new(1,0,0,38)
header.BackgroundTransparency=1
header.BorderSizePixel=0
header.Active=true

local title=Instance.new("TextLabel",header)
title.Text="Transparency"
title.TextSize=20
title.TextColor3=TEXT
title.FontFace=Font.new(
	"rbxasset://fonts/families/SourceSansPro.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal
)
title.Position=UDim2.fromOffset(12,0)
title.Size=UDim2.new(0,140,1,0)
title.BackgroundTransparency=1
title.TextXAlignment=Enum.TextXAlignment.Left

local switchHolder=Instance.new("TextButton",header)
switchHolder.Size=UDim2.fromOffset(95,24)
switchHolder.Position=UDim2.new(1,-173,0,7)
switchHolder.BackgroundTransparency=1
switchHolder.BorderSizePixel=0
switchHolder.Text=""
switchHolder.AutoButtonColor=false

local switchLabel=Instance.new("TextLabel",switchHolder)
switchLabel.Size=UDim2.fromOffset(50,24)
switchLabel.BackgroundTransparency=1
switchLabel.Text="Disabled"
switchLabel.TextSize=11
switchLabel.TextColor3=MUTED
switchLabel.FontFace=Font.new(
	"rbxasset://fonts/families/SourceSansPro.json",
	Enum.FontWeight.Bold,
	Enum.FontStyle.Normal
)
switchLabel.TextXAlignment=Enum.TextXAlignment.Right

local switchTrack=Instance.new("Frame",switchHolder)
switchTrack.Size=UDim2.fromOffset(30,16)
switchTrack.Position=UDim2.new(1,-34,.5,-8)
switchTrack.BackgroundColor3=Color3.fromRGB(32,32,38)
switchTrack.BorderSizePixel=0

corner(switchTrack,8)

local switchStroke=stroke(
	switchTrack,
	Color3.fromRGB(50,50,58),
	1
)

local switchThumb=Instance.new("Frame",switchTrack)
switchThumb.Size=UDim2.fromOffset(12,12)
switchThumb.Position=UDim2.new(0,2,.5,-6)
switchThumb.BackgroundColor3=Color3.fromRGB(130,130,140)
switchThumb.BorderSizePixel=0

corner(switchThumb,6)

local minimizeBtn=Instance.new("TextButton",header)
minimizeBtn.Size=UDim2.fromOffset(20,20)
minimizeBtn.Position=UDim2.new(1,-52,0,9)
minimizeBtn.BackgroundTransparency=1
minimizeBtn.BorderSizePixel=0
minimizeBtn.AutoButtonColor=false
minimizeBtn.Text="—"
minimizeBtn.TextSize=16
minimizeBtn.TextColor3=Color3.fromRGB(150,150,160)
minimizeBtn.Font=Enum.Font.GothamBold
minimizeBtn.ZIndex=20

local closeBtn=Instance.new("TextButton",header)
closeBtn.Size=UDim2.fromOffset(20,20)
closeBtn.Position=UDim2.new(1,-28,0,9)
closeBtn.BackgroundTransparency=1
closeBtn.BorderSizePixel=0
closeBtn.AutoButtonColor=false
closeBtn.Text="X"
closeBtn.TextSize=14
closeBtn.TextColor3=Color3.fromRGB(150,150,160)
closeBtn.Font=Enum.Font.GothamBold
closeBtn.ZIndex=20

local function headerHover(button)
	connect(button.MouseEnter,function()
		TweenService:Create(
			button,
			TweenInfo.new(.15),
			{TextColor3=TEXT}
		):Play()
	end)

	connect(button.MouseLeave,function()
		TweenService:Create(
			button,
			TweenInfo.new(.15),
			{TextColor3=Color3.fromRGB(150,150,160)}
		):Play()
	end)
end

headerHover(minimizeBtn)
headerHover(closeBtn)
makeDraggable(header,main)

local function animateToggle(state)
	if state then
		TweenService:Create(
			switchTrack,
			TweenInfo.new(
				.2,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				BackgroundColor3=Color3.fromRGB(255,255,255)
			}
		):Play()

		TweenService:Create(
			switchStroke,
			TweenInfo.new(.2),
			{
				Color=Color3.fromRGB(220,220,225)
			}
		):Play()

		TweenService:Create(
			switchThumb,
			TweenInfo.new(
				.2,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Position=UDim2.new(1,-14,.5,-6),
				BackgroundColor3=Color3.fromRGB(18,18,22)
			}
		):Play()

		switchLabel.Text="Active"
		switchLabel.TextColor3=TEXT
	else
		TweenService:Create(
			switchTrack,
			TweenInfo.new(.2),
			{
				BackgroundColor3=Color3.fromRGB(32,32,38)
			}
		):Play()

		TweenService:Create(
			switchStroke,
			TweenInfo.new(.2),
			{
				Color=Color3.fromRGB(50,50,58)
			}
		):Play()

		TweenService:Create(
			switchThumb,
			TweenInfo.new(
				.2,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Position=UDim2.new(0,2,.5,-6),
				BackgroundColor3=Color3.fromRGB(130,130,140)
			}
		):Play()

		switchLabel.Text="Disabled"
		switchLabel.TextColor3=MUTED
	end
end

connect(switchHolder.MouseButton1Click,function()
	enabled=not enabled

	animateToggle(enabled)

	if enabled then
		initialScan()
		applyTracked()
	else
		restore()
	end
end)

local content=Instance.new("Frame",main)
content.Name="Content"
content.Position=UDim2.new(0,10,0,42)
content.Size=UDim2.new(1,-20,1,-50)
content.BackgroundTransparency=1

local container=Instance.new("Frame",content)
container.Size=UDim2.new(1,0,0,82)
container.BackgroundColor3=PANEL
container.BorderSizePixel=0

corner(container,9)
stroke(container,PANEL_STROKE,1)

local label=Instance.new("TextLabel",container)
label.Position=UDim2.fromOffset(9,7)
label.Size=UDim2.new(1,-18,0,20)
label.BackgroundTransparency=1
label.Text="Body Transparency   50%"
label.TextColor3=BUTTON_TEXT
label.TextSize=11
label.Font=Enum.Font.GothamMedium
label.TextXAlignment=Enum.TextXAlignment.Left

local sliderBar=Instance.new("Frame",container)
sliderBar.Position=UDim2.fromOffset(9,52)
sliderBar.Size=UDim2.new(1,-18,0,7)
sliderBar.BackgroundColor3=Color3.fromRGB(35,35,41)
sliderBar.BorderSizePixel=0

corner(sliderBar,4)

local fill=Instance.new("Frame",sliderBar)
fill.Size=UDim2.new(.5,0,1,0)
fill.BackgroundColor3=Color3.fromRGB(225,225,232)
fill.BorderSizePixel=0

corner(fill,4)

local knob=Instance.new("Frame",sliderBar)
knob.Size=UDim2.fromOffset(13,13)
knob.AnchorPoint=Vector2.new(.5,.5)
knob.Position=UDim2.new(.5,0,.5,0)
knob.BackgroundColor3=Color3.fromRGB(245,245,250)
knob.BorderSizePixel=0

corner(knob,7)

local function updateSlider()
	local mousePosition=UIS:GetMouseLocation()

	local x=math.clamp(
		(mousePosition.X-sliderBar.AbsolutePosition.X)
			/sliderBar.AbsoluteSize.X,
		0,
		1
	)

	amount=x

	fill.Size=UDim2.new(x,0,1,0)
	knob.Position=UDim2.new(x,0,.5,0)

	label.Text=(
		"Body Transparency   %d%%"
	):format(
		math.floor(x*100+.5)
	)

	if enabled then
		applyTracked()
	end
end

connect(sliderBar.InputBegan,function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1
		or input.UserInputType==Enum.UserInputType.Touch then

		draggingSlider=true
		updateSlider()
	end
end)

connect(knob.InputBegan,function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1
		or input.UserInputType==Enum.UserInputType.Touch then

		draggingSlider=true
		updateSlider()
	end
end)

connect(UIS.InputChanged,function(input)
	if not draggingSlider then
		return
	end

	if input.UserInputType==Enum.UserInputType.MouseMovement
		or input.UserInputType==Enum.UserInputType.Touch then

		updateSlider()
	end
end)

connect(UIS.InputEnded,function(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1
		or input.UserInputType==Enum.UserInputType.Touch then

		draggingSlider=false
	end
end)

local function clampMain(height)
	local currentCamera=Workspace.CurrentCamera

	if not currentCamera then
		return
	end

	local viewport=currentCamera.ViewportSize
	local topOffset=-57
	local bottomOffset=57

	local x=math.clamp(
		main.Position.X.Offset,
		0,
		math.max(
			0,
			viewport.X-FULL_WIDTH
		)
	)

	local y=math.clamp(
		main.Position.Y.Offset,
		topOffset,
		math.max(
			topOffset,
			viewport.Y-height-bottomOffset
		)
	)

	main.Position=UDim2.fromOffset(x,y)
end

local function setCollapsed(state)
	if collapsed==state then
		return
	end

	collapsed=state

	if sizeTween then
		sizeTween:Cancel()
		sizeTween=nil
	end

	if collapsed then
		content.Visible=false

		sizeTween=TweenService:Create(
			main,
			TweenInfo.new(
				.18,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Size=UDim2.fromOffset(
					FULL_WIDTH,
					COLLAPSED_HEIGHT
				)
			}
		)

		sizeTween:Play()
	else
		clampMain(FULL_HEIGHT)

		sizeTween=TweenService:Create(
			main,
			TweenInfo.new(
				.18,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{
				Size=UDim2.fromOffset(
					FULL_WIDTH,
					FULL_HEIGHT
				)
			}
		)

		local thisTween=sizeTween

		connect(thisTween.Completed,function()
			if destroyed then
				return
			end

			if not collapsed
				and sizeTween==thisTween
				and main.Parent then

				content.Visible=true
			end
		end)

		thisTween:Play()
	end
end

connect(minimizeBtn.MouseButton1Click,function()
	setCollapsed(not collapsed)
end)

connect(closeBtn.MouseButton1Click,cleanup)

animateToggle(false)
