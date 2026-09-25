print("is that the goat Zot?")

local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local camera=Workspace.CurrentCamera
local env=getgenv and getgenv() or _G

if env.BodyTransparencyCleanup then
	env.BodyTransparencyCleanup()
end

local enabled=false
local amount=.5
local draggingSlider=false
local models={}
local parts={}
local connections={}
local originals={}

local function connect(signal,fn)
	local c=signal:Connect(fn)
	table.insert(connections,c)
	return c
end

local function otherPlayersRig(model)
	for _,p in ipairs(Players:GetPlayers()) do
		if p~=player and p.Character and (model==p.Character or model:IsDescendantOf(p.Character)) then
			return true
		end
	end
	return false
end

local function forcePart(v)
	if not enabled or not v.Parent then return end
	local wanted=v.Name=="HumanoidRootPart" and 1 or amount
	if v.LocalTransparencyModifier~=wanted then
		v.LocalTransparencyModifier=wanted
	end
end

local function trackPart(v)
	if parts[v] or not v:IsA("BasePart") then return end
	parts[v]=true
	originals[v]=v.LocalTransparencyModifier

	connect(v:GetPropertyChangedSignal("LocalTransparencyModifier"),function()
		forcePart(v)
	end)

	connect(v.AncestryChanged,function()
		if not v.Parent then return end
		local m=v:FindFirstAncestorOfClass("Model")
		if m and models[m] then
			forcePart(v)
		end
	end)

	forcePart(v)
end

local function trackModel(model)
	if not model or models[model] or not model:IsA("Model") then return end
	if otherPlayersRig(model) then return end
	models[model]=true

	for _,v in ipairs(model:GetDescendants()) do
		trackPart(v)
	end

	connect(model.DescendantAdded,function(v)
		if v:IsA("BasePart") then
			trackPart(v)
		end
	end)
end

local function subjectModel()
	camera=Workspace.CurrentCamera
	if not camera then return end
	local subject=camera.CameraSubject
	if not subject then return end

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
	if not model:IsA("Model") or otherPlayersRig(model) then return end

	if model==player.Character then
		trackModel(model)
		return
	end

	local hum=model:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local mn=string.lower(model.Name)
	local pn=string.lower(player.Name)
	local dn=string.lower(player.DisplayName)
	local hd=string.lower(hum.DisplayName or "")

	if mn==pn or mn==dn or hd==pn or hd==dn or mn:find(pn,1,true) then
		trackModel(model)
	end
end

local function scan()
	if player.Character then
		trackModel(player.Character)
	end
	subjectModel()
	for _,v in ipairs(Workspace:GetDescendants()) do
		if v:IsA("Model") then
			scanModel(v)
		end
	end
end

local function restore()
	for v in pairs(parts) do
		if v.Parent then
			v.LocalTransparencyModifier=originals[v] or 0
		end
	end
end

connect(player.CharacterAdded,function(char)
	trackModel(char)
	task.defer(scan)
end)

connect(player:GetPropertyChangedSignal("Character"),function()
	if player.Character then
		trackModel(player.Character)
	end
	task.defer(scan)
end)

connect(Workspace.DescendantAdded,function(v)
	if v:IsA("Model") then
		task.defer(function()
			scanModel(v)
			subjectModel()
		end)
	elseif v:IsA("BasePart") then
		task.defer(function()
			local m=v:FindFirstAncestorOfClass("Model")
			if m and models[m] then
				trackPart(v)
			end
		end)
	end
end)

connect(Workspace:GetPropertyChangedSignal("CurrentCamera"),function()
	camera=Workspace.CurrentCamera
	task.defer(subjectModel)
end)

scan()

local targetParent
local ok,hui=pcall(function()
	return gethui()
end)
targetParent=ok and hui or player:WaitForChild("PlayerGui")

local old=targetParent:FindFirstChild("BodyTransparencyUI")
if old then old:Destroy() end

local gui=Instance.new("ScreenGui")
gui.Name="BodyTransparencyUI"
gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=targetParent

local main=Instance.new("Frame",gui)
main.Size=UDim2.fromOffset(360,140)
main.BackgroundColor3=Color3.fromRGB(0,0,0)
main.BorderSizePixel=0
main.ClipsDescendants=true
main.Active=true
Instance.new("UICorner",main).CornerRadius=UDim.new(0,10)

local mainStroke=Instance.new("UIStroke",main)
mainStroke.Thickness=1.2
mainStroke.Color=Color3.fromRGB(45,45,50)
mainStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border

camera=Workspace.CurrentCamera
if camera then
	local viewport=camera.ViewportSize
	main.Position=UDim2.fromOffset(math.floor((viewport.X-360)/2),math.floor((viewport.Y-140)/2))
end

local header=Instance.new("Frame",main)
header.Size=UDim2.new(1,0,0,38)
header.BackgroundTransparency=1
header.Active=true

local title=Instance.new("TextLabel",header)
title.Text="Transparency"
title.TextSize=20
title.TextColor3=Color3.fromRGB(240,240,245)
title.FontFace=Font.new("rbxasset://fonts/families/SourceSansPro.json",Enum.FontWeight.Bold,Enum.FontStyle.Normal)
title.Position=UDim2.fromOffset(12,0)
title.Size=UDim2.new(1,-50,1,0)
title.BackgroundTransparency=1
title.TextXAlignment=Enum.TextXAlignment.Left

local closeBtn=Instance.new("TextButton",header)
closeBtn.Text="X"
closeBtn.TextSize=14
closeBtn.TextColor3=Color3.fromRGB(150,150,160)
closeBtn.Font=Enum.Font.GothamBold
closeBtn.Size=UDim2.fromOffset(20,20)
closeBtn.Position=UDim2.new(1,-28,0,9)
closeBtn.BackgroundTransparency=1
closeBtn.AutoButtonColor=false

closeBtn.MouseEnter:Connect(function()
	TweenService:Create(closeBtn,TweenInfo.new(.15),{TextColor3=Color3.new(1,1,1)}):Play()
end)

closeBtn.MouseLeave:Connect(function()
	TweenService:Create(closeBtn,TweenInfo.new(.15),{TextColor3=Color3.fromRGB(150,150,160)}):Play()
end)

local function makeDraggable(handle,target)
	local dragging=false
	local dragStart
	local startPos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			dragging=true
			dragStart=input.Position
			startPos=Vector2.new(target.Position.X.Offset,target.Position.Y.Offset)
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType~=Enum.UserInputType.MouseMovement and input.UserInputType~=Enum.UserInputType.Touch then return end

		local cam=Workspace.CurrentCamera
		if not cam then return end

		local delta=input.Position-dragStart
		local size=target.AbsoluteSize
		local viewport=cam.ViewportSize
		local topOffset=-57
		local bottomOffset=57
		local x=math.clamp(startPos.X+delta.X,0,math.max(0,viewport.X-size.X))
		local y=math.clamp(startPos.Y+delta.Y,topOffset,math.max(topOffset,viewport.Y-size.Y-bottomOffset))
		target.Position=UDim2.fromOffset(x,y)
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then
			dragging=false
		end
	end)
end

makeDraggable(header,main)

local content=Instance.new("Frame",main)
content.Position=UDim2.new(0,10,0,42)
content.Size=UDim2.new(1,-20,1,-50)
content.BackgroundTransparency=1

local container=Instance.new("Frame",content)
container.Size=UDim2.new(1,0,0,82)
container.BackgroundColor3=Color3.fromRGB(18,18,22)
container.BorderSizePixel=0
Instance.new("UICorner",container).CornerRadius=UDim.new(0,7)

local containerStroke=Instance.new("UIStroke",container)
containerStroke.Color=Color3.fromRGB(32,32,36)
containerStroke.Thickness=1

local label=Instance.new("TextLabel",container)
label.Position=UDim2.fromOffset(9,5)
label.Size=UDim2.new(1,-95,0,20)
label.BackgroundTransparency=1
label.Text="Body Transparency   50%"
label.TextColor3=Color3.fromRGB(225,225,232)
label.TextSize=11
label.Font=Enum.Font.GothamMedium
label.TextXAlignment=Enum.TextXAlignment.Left

local toggle=Instance.new("TextButton",container)
toggle.Size=UDim2.fromOffset(58,22)
toggle.Position=UDim2.new(1,-67,0,7)
toggle.BackgroundColor3=Color3.fromRGB(24,24,28)
toggle.BorderSizePixel=0
toggle.AutoButtonColor=false
toggle.Text="OFF"
toggle.TextColor3=Color3.fromRGB(225,225,232)
toggle.TextSize=10
toggle.Font=Enum.Font.GothamMedium
Instance.new("UICorner",toggle).CornerRadius=UDim.new(0,4)

local toggleStroke=Instance.new("UIStroke",toggle)
toggleStroke.Color=Color3.fromRGB(40,40,48)
toggleStroke.Thickness=1

local bar=Instance.new("Frame",container)
bar.Position=UDim2.fromOffset(9,52)
bar.Size=UDim2.new(1,-18,0,7)
bar.BackgroundColor3=Color3.fromRGB(35,35,41)
bar.BorderSizePixel=0
Instance.new("UICorner",bar).CornerRadius=UDim.new(1,0)

local fill=Instance.new("Frame",bar)
fill.Size=UDim2.new(.5,0,1,0)
fill.BackgroundColor3=Color3.fromRGB(225,225,232)
fill.BorderSizePixel=0
Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)

local knob=Instance.new("Frame",bar)
knob.Size=UDim2.fromOffset(13,13)
knob.AnchorPoint=Vector2.new(.5,.5)
knob.Position=UDim2.new(.5,0,.5,0)
knob.BackgroundColor3=Color3.fromRGB(245,245,250)
knob.BorderSizePixel=0
Instance.new("UICorner",knob).CornerRadius=UDim.new(1,0)

local function updateSlider()
	local mouse=UIS:GetMouseLocation()
	local x=math.clamp((mouse.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
	amount=x
	fill.Size=UDim2.new(x,0,1,0)
	knob.Position=UDim2.new(x,0,.5,0)
	label.Text=("Body Transparency   %d%%"):format(math.floor(x*100+.5))

	if enabled then
		for v in pairs(parts) do
			forcePart(v)
		end
	end
end

toggle.MouseEnter:Connect(function()
	if not enabled then
		TweenService:Create(toggle,TweenInfo.new(.1),{BackgroundColor3=Color3.fromRGB(32,32,38)}):Play()
	end
end)

toggle.MouseLeave:Connect(function()
	if not enabled then
		TweenService:Create(toggle,TweenInfo.new(.1),{BackgroundColor3=Color3.fromRGB(24,24,28)}):Play()
	end
end)

toggle.MouseButton1Click:Connect(function()
	enabled=not enabled
	toggle.Text=enabled and "ON" or "OFF"
	toggle.BackgroundColor3=enabled and Color3.fromRGB(48,48,58) or Color3.fromRGB(24,24,28)
	toggleStroke.Color=enabled and Color3.fromRGB(70,70,82) or Color3.fromRGB(40,40,48)

	if enabled then
		scan()
	else
		restore()
	end
end)

bar.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		draggingSlider=true
		updateSlider()
	end
end)

knob.InputBegan:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		draggingSlider=true
		updateSlider()
	end
end)

UIS.InputChanged:Connect(function(i)
	if draggingSlider and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
		updateSlider()
	end
end)

UIS.InputEnded:Connect(function(i)
	if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
		draggingSlider=false
	end
end)

closeBtn.MouseButton1Click:Connect(function()
	if env.BodyTransparencyCleanup then
		env.BodyTransparencyCleanup()
	end
end)

RunService:BindToRenderStep("ForcedBodyTransparency",Enum.RenderPriority.Last.Value+100,function()
	if not enabled then return end

	if player.Character then
		trackModel(player.Character)
	end

	subjectModel()

	for v in pairs(parts) do
		if v.Parent then
			forcePart(v)
		end
	end
end)

env.BodyTransparencyCleanup=function()
	enabled=false
	restore()
	pcall(function()
		RunService:UnbindFromRenderStep("ForcedBodyTransparency")
	end)
	for _,c in ipairs(connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	if gui then
		gui:Destroy()
	end
	env.BodyTransparencyCleanup=nil
end
