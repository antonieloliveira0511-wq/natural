-- LocalScript (coloque em StarterPlayerScripts ou StarterGui/PlayerGui)
-- Requisitos: Dear-ReGui carregado (conforme o template do usuário).
-- Nota técnica: alguns jogos forçam valores do servidor (WalkSpeed/JumpPower) — nesses casos as mudanças podem ser sobrescritas pelo servidor.

--// Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 5) or LocalPlayer:WaitForChild("PlayerGui", 60)
local character, humanoid, rootPart

--// Carrega ReGui (mesma origem do seu template)
local success, ReGui = pcall(function()
	return loadstring(game:HttpGet("https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua"))()
end)
if not success or type(ReGui) ~= "table" then
	warn("ReGui não pôde ser carregado. Verifique a URL e a conexão.")
	return
end

--// Estado e configurações
local state = {
	noclip = false,
	noclipLoopRunning = false,
	noclipMap = {}, -- map para restaurar CanCollide: [part] = originalBool
	speed = 16,
	jump = 50,
	origSpeed = nil,
	origJump = nil,
	useJumpPower = true,
	smoothTransition = true,
	sprintMultiplier = 1.8,
	sprintActive = false,
	bunnyhop = false,
	doubleJump = false,
	doubleJumpCount = 0,
	doubleJumpMax = 1,
	glide = false,
	presetsFile = "jhonadev139_presets.json"
}

--// Utilitários
local function safeWriteFile(name, content)
	local ok, err = pcall(function() writefile(name, content) end)
	return ok, err
end
local function safeReadFile(name)
	if not isfile(name) then return nil end
	local ok, content = pcall(function() return readfile(name) end)
	if ok then return content else return nil end
end

local function ensureCharacterRefs()
	character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	humanoid = character:FindFirstChildOfClass("Humanoid")
	rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	-- Detecta se o jogo usa JumpPower
	if humanoid then
		state.useJumpPower = humanoid:GetAttribute("UseJumpPower") or humanoid:FindFirstChild("UseJumpPower") or humanoid.UseJumpPower == true or humanoid.JumpPower ~= nil
	end
end

--// NOC L I P
local noclipConnections = {}
local function startNoclip()
	if state.noclipLoopRunning then return end
	state.noclipLoopRunning = true
	state.noclip = true
	state.noclipMap = state.noclipMap or {}
	-- Limpa mapa antigo caso character mudou
	state.noclipMap = {}

	-- Loop eficiente: apenas modifica partes quando necessário
	local conn
	conn = RunService.Stepped:Connect(function()
		if not state.noclip then
			if conn then conn:Disconnect() end
			state.noclipLoopRunning = false
			return
		end
		if not character or not character.Parent then return end
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Ignora Anchored; modifica somente se CanCollide true
				local ok, anchored = pcall(function() return part.Anchored end)
				if ok and not anchored then
					local ok2, locked = pcall(function() return part.Locked end)
					if ok2 and locked then
						-- ignora partes Locked
					else
						-- armazena valor original uma única vez
						if state.noclipMap[part] == nil then
							local ok3, can = pcall(function() return part.CanCollide end)
							state.noclipMap[part] = (ok3 and can) and true or false
						end
						-- somente escreve se atualmente true
						local ok4, canNow = pcall(function() return part.CanCollide end)
						if ok4 and canNow then
							pcall(function() part.CanCollide = false end)
						end
					end
				end
			end
		end
	end)
	table.insert(noclipConnections, conn)
end

local function stopNoclip()
	state.noclip = false
	state.noclipLoopRunning = false
	for _, conn in ipairs(noclipConnections) do
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
	noclipConnections = {}
	-- restaura valores originais
	for part, original in pairs(state.noclipMap) do
		if part and part.Parent and type(original) == "boolean" then
			pcall(function() part.CanCollide = original end)
		end
	end
	state.noclipMap = {}
end

--// WALK SPEED
local speedTweenCoroutine
local function applyWalkSpeed(target, smooth)
	if not humanoid then return end
	-- Armazena original na primeira vez
	if not state.origSpeed and humanoid then
		pcall(function() state.origSpeed = humanoid.WalkSpeed end)
	end
	state.speed = target
	-- Lerp se smooth true
	if smooth then
		if speedTweenCoroutine and coroutine.status(speedTweenCoroutine) ~= "dead" then return end
		speedTweenCoroutine = coroutine.create(function()
			local step = 0.12
			local current = humanoid and humanoid.WalkSpeed or target
			local t = 0
			while math.abs(current - target) > 0.5 and humanoid do
				current = current + (target - current) * step
				pcall(function() humanoid.WalkSpeed = current end)
				wait(0.03)
			end
			pcall(function() humanoid.WalkSpeed = target end)
		end)
		pcall(coroutine.resume, speedTweenCoroutine)
	else
		pcall(function() humanoid.WalkSpeed = target end)
	end
end

local function restoreWalkSpeed()
	if humanoid and state.origSpeed then
		pcall(function() humanoid.WalkSpeed = state.origSpeed end)
		state.origSpeed = nil
	end
end

--// JUMP POWER / HEIGHT
local jumpTweenCoroutine
local function applyJump(value)
	if not humanoid then return end
	if state.useJumpPower and humanoid.JumpPower ~= nil then
		if not state.origJump then pcall(function() state.origJump = humanoid.JumpPower end) end
		pcall(function() humanoid.JumpPower = value end)
	else
		-- usa JumpHeight
		if not state.origJump then pcall(function() state.origJump = humanoid.JumpHeight end) end
		pcall(function() humanoid.JumpHeight = value end)
	end
	state.jump = value
end

local function restoreJump()
	if humanoid and state.origJump then
		if state.useJumpPower and humanoid.JumpPower ~= nil then
			pcall(function() humanoid.JumpPower = state.origJump end)
		else
			pcall(function() humanoid.JumpHeight = state.origJump end)
		end
		state.origJump = nil
	end
end

--// PRESETS (WriteFile / ReadFile via HttpService JSON)
local function savePreset(name)
	local data = {}
	local existing = safeReadFile(state.presetsFile)
	if existing then
		local ok, dec = pcall(function() return HttpService:JSONDecode(existing) end)
		if ok and type(dec) == "table" then data = dec end
	end
	data[name] = {
		speed = state.speed,
		jump = state.jump,
		noclip = state.noclip,
		smooth = state.smoothTransition,
		sprint = state.sprintMultiplier
	}
	local ok, err = safeWriteFile(state.presetsFile, HttpService:JSONEncode(data))
	return ok, err
end

local function loadPreset(name)
	local existing = safeReadFile(state.presetsFile)
	if not existing then return false, "Arquivo não encontrado" end
	local ok, dec = pcall(function() return HttpService:JSONDecode(existing) end)
	if not ok or type(dec) ~= "table" then return false, "JSON inválido" end
	local preset = dec[name]
	if not preset then return false, "Preset não existe" end
	-- aplica valores
	applyWalkSpeed(preset.speed or 16, state.smoothTransition)
	applyJump(preset.jump or 50)
	state.smoothTransition = preset.smooth
	state.sprintMultiplier = preset.sprint or 1.8
	state.noclip = preset.noclip or false
	if state.noclip then startNoclip() else stopNoclip() end
	return true
end

local function removePreset(name)
	local existing = safeReadFile(state.presetsFile)
	if not existing then return false, "Arquivo não encontrado" end
	local ok, dec = pcall(function() return HttpService:JSONDecode(existing) end)
	if not ok or type(dec) ~= "table" then return false, "JSON inválido" end
	dec[name] = nil
	local ok2, err = safeWriteFile(state.presetsFile, HttpService:JSONEncode(dec))
	return ok2, err
end

--// HOTKEYS e SPRINT/BUNNYHOP/DOUBLEJUMP/GLIDE
local function onInputBegan(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode
		-- Toggle noclip com K
		if key == Enum.KeyCode.K then
			if state.noclip then stopNoclip() else startNoclip() end
		-- Sprint hold com LeftShift
		elseif key == Enum.KeyCode.LeftShift then
			state.sprintActive = true
			if humanoid and state.sprintActive then
				applyWalkSpeed(state.speed * state.sprintMultiplier, state.smoothTransition)
			end
		-- Hotkey salvar preset (Ctrl + P)
		elseif (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) and key == Enum.KeyCode.P then
			local name = "preset_" .. tostring(os.time())
			savePreset(name)
		end
	end
end

local function onInputEnded(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode
		if key == Enum.KeyCode.LeftShift then
			state.sprintActive = false
			applyWalkSpeed(state.speed, state.smoothTransition)
		end
	end
end

-- Bunnyhop & DoubleJump & Glide hooks
local function onHumanoidStateChanged(oldState, newState)
	-- restaura double jump count ao tocar no chão
	if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.RunningNoPhysics then
		state.doubleJumpCount = 0
	end
end

local function onHumanoidJumping(active)
	if not active then return end
	-- bunnyhop: aplica salto automático mantendo velocidade se ativado
	if state.bunnyhop and humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Seated then
		-- força pequeno salto
		pcall(function() humanoid.Jump = true end)
	end
	-- double jump
	if state.doubleJump and state.doubleJumpCount < state.doubleJumpMax then
		state.doubleJumpCount = state.doubleJumpCount + 1
		-- aplica impulso adicional
		if rootPart then
			pcall(function()
				local vel = rootPart.AssemblyLinearVelocity
				rootPart.AssemblyLinearVelocity = Vector3.new(vel.X, math.max(60, vel.Y + 35), vel.Z)
			end)
		end
	end
end

-- Glide: quando caindo, limita velocidade de queda
local glideConn
local function updateGlide(active)
	state.glide = active
	if glideConn and glideConn.Disconnect then glideConn:Disconnect() end
	if active then
		glideConn = RunService.Heartbeat:Connect(function()
			if not rootPart or not humanoid then return end
			local vel = rootPart.AssemblyLinearVelocity
			if vel.Y < -20 and humanoid and humanoid.FloorMaterial == Enum.Material.Air then
				pcall(function()
					rootPart.AssemblyLinearVelocity = Vector3.new(vel.X, math.clamp(vel.Y, -20, 9999), vel.Z)
				end)
			end
		end)
	end
end

--// UI (Dear-ReGui)
local Window = ReGui:TabsWindow({
	Title = "JhonaDev139 | ReGui Controls",
	Size = UDim2.fromOffset(460, 420)
})

local TabsList = {"Player", "Movement", "Extras", "Presets"}
local ui = {}

for _, Name in ipairs(TabsList) do
	local Tab = Window:CreateTab({Name = Name})

	if Name == "Player" then
		Tab:Label({Text = "Controles do Jogador"})
		-- Noclip
		Tab:Checkbox({
			Value = false,
			Label = "Noclip (K para toggle)",
			Callback = function(_, Value)
				if Value then startNoclip() else stopNoclip() end
			end
		})
		Tab:Button({
			Text = "Restaurar colisões",
			Callback = function()
				stopNoclip()
			end
		})
		Tab:Label({Text = "Atalhos: K = Noclip, LeftShift = Sprint (hold), Ctrl+P = Salvar preset rápido"})

	elseif Name == "Movement" then
		Tab:Label({Text = "Velocidade e Pulo"})
		-- Speed slider
		Tab:SliderInt({
			Label = "Velocidade (WalkSpeed)",
			Value = 16,
			Minimum = 8,
			Maximum = 200,
			Callback = function(_, Value)
				state.speed = Value
				if state.sprintActive then
					applyWalkSpeed(Value * state.sprintMultiplier, state.smoothTransition)
				else
					applyWalkSpeed(Value, state.smoothTransition)
				end
			end
		})
		Tab:Checkbox({
			Value = true,
			Label = "Transição suave (Lerp)",
			Callback = function(_, Value)
				state.smoothTransition = Value
			end
		})
		-- Jump slider
		Tab:SliderInt({
			Label = "Pulo (JumpPower / JumpHeight)",
			Value = 50,
			Minimum = 20,
			Maximum = 300,
			Callback = function(_, Value)
				state.jump = Value
				applyJump(Value)
			end
		})
		Tab:Button({
			Text = "Restaurar Speed/Jump",
			Callback = function()
				restoreWalkSpeed()
				restoreJump()
			end
		})

	elseif Name == "Extras" then
		Tab:Label({Text = "Opções adicionais"})
		Tab:Checkbox({
			Value = false,
			Label = "Sprint (hold) -- LeftShift",
			Callback = function(_, Value)
				-- apenas altera configuração; comportamento tratado por input
				state.sprintEnabled = Value
			end
		})
		Tab:SliderFloat({
			Label = "Multiplicador Sprint",
			Value = 1.8,
			Minimum = 1.1,
			Maximum = 4,
			Callback = function(_, Value)
				state.sprintMultiplier = Value
			end
		})
		Tab:Checkbox({
			Value = false,
			Label = "BunnyHop (auto)",
			Callback = function(_, Value)
				state.bunnyhop = Value
			end
		})
		Tab:Checkbox({
			Value = false,
			Label = "Double Jump",
			Callback = function(_, Value)
				state.doubleJump = Value
			end
		})
		Tab:SliderInt({
			Label = "Double Jump máximo",
			Value = 1,
			Minimum = 1,
			Maximum = 3,
			Callback = function(_, Value)
				state.doubleJumpMax = Value
			end
		})
		Tab:Checkbox({
			Value = false,
			Label = "Glide (reduz velocidade de queda)",
			Callback = function(_, Value)
				updateGlide(Value)
			end
		})

	elseif Name == "Presets" then
		Tab:Label({Text = "Gerenciar Presets Locais"})
		-- Input para nome do preset
		local presetName = ""
		Tab:InputText({
			Label = "Nome do Preset",
			Callback = function(_, Value)
				presetName = Value or ""
			end
		})
		Tab:Button({
			Text = "Salvar Preset",
			Callback = function()
				local n = presetName ~= "" and presetName or ("preset_" .. os.time())
				local ok, err = savePreset(n)
				if ok then print("Preset salvo:", n) else warn("Erro ao salvar preset:", err) end
			end
		})
		Tab:Button({
			Text = "Carregar Preset (nome exato)",
			Callback = function()
				local n = presetName
				if n == "" then warn("Digite um nome válido") return end
				local ok, err = loadPreset(n)
				if not ok then warn("Falha ao carregar preset:", err) else print("Preset carregado:", n) end
			end
		})
		Tab:Button({
			Text = "Remover Preset",
			Callback = function()
				local n = presetName
				if n == "" then warn("Digite um nome válido") return end
				local ok, err = removePreset(n)
				if not ok then warn("Falha ao remover preset:", err) else print("Preset removido:", n) end
			end
		})
		Tab:Button({
			Text = "Listar Presets",
			Callback = function()
				local existing = safeReadFile(state.presetsFile)
				if not existing then print("Nenhum preset salvo.") return end
				local ok, dec = pcall(function() return HttpService:JSONDecode(existing) end)
				if not ok or type(dec) ~= "table" then warn("Arquivo de presets corrompido.") return end
				print("Presets locais:")
				for k, v in pairs(dec) do
					print("-", k, "=>", "speed:", v.speed, "jump:", v.jump)
				end
			end
		})
	end
end

--// Eventos e inicialização
local function onCharacterAdded(char)
	character = char
	humanoid = character:WaitForChild("Humanoid", 5) or character:FindFirstChildOfClass("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart", 5) or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	-- aplica configurações atuais a novo character
	if humanoid then
		-- detecta uso de JumpPower
		state.useJumpPower = (humanoid.JumpPower ~= nil)
		-- aplica valores
		applyWalkSpeed(state.speed, state.smoothTransition)
		applyJump(state.jump)
		-- conecta eventos
		humanoid.StateChanged:Connect(onHumanoidStateChanged)
		humanoid.Jumping:Connect(onHumanoidJumping)
	end
	-- se noclip estava ativo, reinicia
	if state.noclip then
		startNoclip()
	end
end

-- Reconecta character atual
if LocalPlayer.Character then
	onCharacterAdded(LocalPlayer.Character)
else
	LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
end

-- Conecta inputs
UserInputService.InputBegan:Connect(onInputBegan)
UserInputService.InputEnded:Connect(onInputEnded)

-- Cleanup quando o jogador sai do jogo ou o Character for removido
LocalPlayer.CharacterRemoving:Connect(function()
	-- restaura valores para evitar deixar alterações persistentes
	stopNoclip()
	restoreWalkSpeed()
	restoreJump()
end)

-- Mensagens iniciais (somente debug)
print("[JhonaDev139] Controle ReGui carregado. Use K para toggle Noclip. LeftShift para Sprint (hold).")

-- FIM do script
