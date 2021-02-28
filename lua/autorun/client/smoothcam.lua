--## Clean up ##--

hook.Remove("HUDShouldDraw", "SmoothCam.HUDShouldDraw")
hook.Remove("PreDrawViewModel", "SmoothCam.PreDrawViewModel")
hook.Remove("KeyPress", "SmoothCam.CancelUse")
hook.Remove("CalcView", "zzzzzzzzzzzzzzzSmoothCam.CalcView")

--## ConVars ##--

local fps_max = GetConVar("fps_max")
local developer = GetConVar("developer")
local cl_drawhud = GetConVar("cl_drawhud")
local cl_showfps = GetConVar("cl_showfps")

--## SmoothCam ##--

SmoothCam = {}

SmoothCam.Playing = false

SmoothCam.Sequence = {
	Points = {},
	Time = 5,
	FPS = 0,
	Easing = true
}

--## Printing ##--

local function format_thousands(amount)
	local formatted, k = amount
	while true do  
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

local pink    = Color(255,0,255)
local yellow  = Color(255,255,0)
local neutral = Color(0,255,255)
local good    = Color(0,255,0)
local bad     = Color(255,0,0)
function SmoothCam:print(msgType, ...)
	local msg = {...}
	table.insert(msg, "\n")
	if isstring(msgType) then table.insert(msg, 1, msgType) end

	local color = isstring(msgType) and neutral or msgType or neutral
	MsgC(color, "SmoothCam: ", color_white, unpack(msg))
end

--## Points Management ##--

local POINT_POS = 1
local POINT_ANG = 2

function SmoothCam:AddPoint()
	local viewEnt = GetViewEntity()
	if viewEnt:IsPlayer() then
		table.insert(SmoothCam.Sequence.Points, { [POINT_POS] = viewEnt:EyePos(), [POINT_ANG] = viewEnt:EyeAngles() })
	elseif IsValid(viewEnt) then
		table.insert(SmoothCam.Sequence.Points, { [POINT_POS] = viewEnt:GetPos(), [POINT_ANG] = viewEnt:GetAngles() })
	else
		SmoothCam:print(bad, "Invalid view entity! Could not add point.")
		return
	end
end

function SmoothCam:RemovePoint(index)
	table.remove(SmoothCam.Sequence.Points, index)
	SmoothCam:print("Removed point ", yellow, "#" .. (index or #SmoothCam.Sequence.Points + 1))
end

function SmoothCam:ResetPoints(index)
	SmoothCam.Sequence.Points = {}
end

function SmoothCam:ListPoints()
	if #SmoothCam.Sequence.Points == 0 then
		SmoothCam:print(bad, "There are no points in this sequence to list.")
	else
		SmoothCam:print("Sequence Time: ", yellow, SmoothCam.Sequence.Time .. " seconds\n")
		if SmoothCam.Sequence.FPS > 0 then
			SmoothCam:print("Sequence FPS: ", yellow, SmoothCam.Sequence.FPS .. " FPS")
			SmoothCam:print("Sequence Frames: ", yellow, format_thousands(SmoothCam.Sequence.Time * SmoothCam.Sequence.FPS) .. "\n")
		end

		for i, point in ipairs(SmoothCam.Sequence.Points) do
			SmoothCam:print(neutral, yellow, "#" .. i)
			SmoothCam:print("Vector(" .. point[POINT_POS][1] .. ", " .. point[POINT_POS][2] .. ", " .. point[POINT_POS][3] .. ")")
			SmoothCam:print("Angles(" .. point[POINT_ANG][1] .. ", " .. point[POINT_ANG][2] .. ", " .. point[POINT_ANG][3] .. ")\n")
		end
	end
end

--## Playback ##--

local function easeInOutSine(x)
	return -(math.cos(math.pi * x) - 1) / 2
end

function SmoothCam:FrameAdvance()
	local frameDelta = FrameNumber() - (SmoothCam.RenderFrame or (FrameNumber() - 1))
	if frameDelta > 1 then
		SmoothCam:print(bad, "Skipped #" .. (frameDelta - 1) .. " frame(s)!!!!")
	end

	SmoothCam.RenderFrame = FrameNumber()

	local progress
	if SmoothCam.Sequence.FPS > 0 then
		SmoothCam.Frame = SmoothCam.Frame + 1
		progress = SmoothCam.Frame / SmoothCam.FrameCount
	else
		SmoothCam.ElapsedTime = SysTime() - SmoothCam.PlaybackStart
		progress = SmoothCam.ElapsedTime / SmoothCam.Sequence.Time
	end

	local framePeriod = 1 / FrameTime()
	SmoothCam.FPSMin = math.min(SmoothCam.FPSMin, framePeriod)
	SmoothCam.FPSAvg = SmoothCam.FPSAvg + framePeriod
	SmoothCam.FPSMax = math.max(SmoothCam.FPSMax, framePeriod)

	local pointIndex = math.Clamp(progress, 0, 1) * (#SmoothCam.Sequence.Points - 1)
	SmoothCam.Interpolation = SmoothCam.Sequence.Easing and easeInOutSine(pointIndex % 1) or (pointIndex % 1)
	SmoothCam.Point = math.floor(pointIndex) + 1

	if SmoothCam.Point + 1 > #SmoothCam.Sequence.Points then
		SmoothCam.Pos = SmoothCam.Sequence.Points[SmoothCam.Point][POINT_POS]
		SmoothCam.Angles = SmoothCam.Sequence.Points[SmoothCam.Point][POINT_ANG]
	else
		SmoothCam.Pos = LerpVector(SmoothCam.Interpolation, SmoothCam.Sequence.Points[SmoothCam.Point][POINT_POS], SmoothCam.Sequence.Points[SmoothCam.Point + 1][POINT_POS])
		SmoothCam.Angles = LerpAngle(SmoothCam.Interpolation, SmoothCam.Sequence.Points[SmoothCam.Point][POINT_ANG], SmoothCam.Sequence.Points[SmoothCam.Point + 1][POINT_ANG])
	end

	if progress >= 1 then
		SmoothCam.Point = #SmoothCam.Sequence.Points
		SmoothCam:Stop()
	end
end

function SmoothCam:Play()
	if #SmoothCam.Sequence.Points <= 0 then return false end
	if SmoothCam.Playing then SmoothCam:Stop() end

	gui.HideGameUI()

	SmoothCam.developer = developer:GetInt()
	RunConsoleCommand("developer", "0")

	SmoothCam.cl_drawhud = cl_drawhud:GetInt()
	RunConsoleCommand("cl_drawhud", "0")

	SmoothCam.cl_showfps = cl_showfps:GetInt()
	RunConsoleCommand("cl_showfps", "0")

	for _, wep in ipairs(LocalPlayer():GetWeapons()) do
		if IsValid(wep) then
			wep.SmoothCam_NoDraw = wep:GetNoDraw()
			wep:SetNoDraw(true)
		end
	end
	for _, ent in ipairs(ents.GetAll()) do
		if IsValid(ent) and ent:GetClass() == "physgun_beam" and ent:GetParent() == LocalPlayer() then
			ent.SmoothCam_NoDraw = ent:GetNoDraw()
			ent:SetNoDraw(true)
		end
	end

	if SmoothCam.Sequence.FPS > 0 then
		SmoothCam.fps_max = fps_max:GetInt()
		RunConsoleCommand("fps_max", tostring(SmoothCam.Sequence.FPS))

		SmoothCam.Frame = 0
		SmoothCam.FrameCount = SmoothCam.Sequence.Time * SmoothCam.Sequence.FPS
	else
		SmoothCam.ElapsedTime = 0
	end

	SmoothCam.Playing = true

	timer.Simple(0, function()
		SmoothCam.FPSMin = math.huge
		SmoothCam.FPSAvg = 0
		SmoothCam.FPSMax = 0

		SmoothCam.FrameStart = FrameNumber()
		SmoothCam.PlaybackStart = SysTime()

		SmoothCam.Point = 1
		SmoothCam.Pos = Vector(SmoothCam.Sequence.Points[1][POINT_POS])
		SmoothCam.Angles = Angle(SmoothCam.Sequence.Points[1][POINT_ANG])

		hook.Add("HUDShouldDraw", "SmoothCam.HUDShouldDraw", SmoothCam.RETURN_FALSE)
		hook.Add("PreDrawViewModel", "SmoothCam.PreDrawViewModel", SmoothCam.RETURN_TRUE)
		hook.Add("ShouldDrawLocalPlayer", "SmoothCam.ShouldDrawLocalPlayer", SmoothCam.RETURN_FALSE)
		hook.Add("KeyPress", "SmoothCam.CancelUse", SmoothCam.CancelUse)
		hook.Add("CalcView", "zzzzzzzzzzzzzzzSmoothCam.CalcView", SmoothCam.CalcView)
	end)
end

function SmoothCam:Stop()
	if not SmoothCam.Playing then return end

	SmoothCam.Playing = false

	local timePlayed = (SysTime() - SmoothCam.PlaybackStart)

	hook.Remove("HUDShouldDraw", "SmoothCam.HUDShouldDraw")
	hook.Remove("PreDrawViewModel", "SmoothCam.PreDrawViewModel")
	hook.Remove("ShouldDrawLocalPlayer", "SmoothCam.ShouldDrawLocalPlayer")
	hook.Remove("KeyPress", "SmoothCam.CancelUse")
	hook.Remove("CalcView", "zzzzzzzzzzzzzzzSmoothCam.CalcView")

	if SmoothCam.developer ~= nil then
		RunConsoleCommand("developer", tostring(SmoothCam.developer))
		SmoothCam.developer = nil
	end
	if SmoothCam.fps_max ~= nil then
		RunConsoleCommand("fps_max", tostring(SmoothCam.fps_max))
		SmoothCam.fps_max = nil
	end
	if SmoothCam.cl_drawhud ~= nil then
		RunConsoleCommand("cl_drawhud", tostring(SmoothCam.cl_drawhud))
		SmoothCam.cl_drawhud = nil
	end
	if SmoothCam.cl_showfps ~= nil then
		RunConsoleCommand("cl_showfps", tostring(SmoothCam.cl_showfps))
		SmoothCam.cl_showfps = nil
	end

	for _, wep in ipairs(LocalPlayer():GetWeapons()) do
		if IsValid(wep) and wep.SmoothCam_NoDraw ~= nil then
			wep:SetNoDraw(wep.SmoothCam_NoDraw)
			wep.SmoothCam_NoDraw = nil
		end
	end
	for _, ent in ipairs(ents.GetAll()) do
		if IsValid(ent) and ent:GetClass() == "physgun_beam" and ent:GetParent() == LocalPlayer() and ent.SmoothCam_NoDraw ~= nil then
			ent:SetNoDraw(ent.SmoothCam_NoDraw)
			ent.SmoothCam_NoDraw = nil
		end
	end

	SmoothCam:print("Stopped playback!")
	if SmoothCam.Point < #SmoothCam.Sequence.Points then
		SmoothCam:print("Point: ", yellow, "#" .. SmoothCam.Point, color_white, " -> ", yellow, "#" .. SmoothCam.Point + 1)
	else
		SmoothCam:print("Point: ", yellow, "#" .. SmoothCam.Point)
	end
	SmoothCam:print("Time: ", yellow, timePlayed .. " seconds")

	if SmoothCam.Frame then
		local lag = math.max(timePlayed - SmoothCam.Sequence.Time, 0)
		SmoothCam:print("Lag: ", yellow, tostring(lag) .. " seconds", color_white, " (" , yellow, math.floor(SmoothCam.Sequence.FPS * lag) .. " frames", color_white, ")")
		SmoothCam:print("Frame: ", yellow, tostring(SmoothCam.Frame), color_white, "/", yellow, tostring(SmoothCam.FrameCount))
		SmoothCam:print("Progress: ", yellow, math.Round((SmoothCam.Frame / SmoothCam.FrameCount) * 100, 2) .. "%")
	else
		SmoothCam:print("Progress: ", yellow, math.Round(math.min(timePlayed / SmoothCam.Sequence.Time, 1) * 100, 2) .. "%")
	end

	SmoothCam:print("FPS Min: ", yellow, math.Round(SmoothCam.FPSMin, 0) .. " FPS")
	SmoothCam:print("FPS Avg: ", yellow, math.Round(SmoothCam.FPSAvg / (SmoothCam.RenderFrame - SmoothCam.FrameStart), 0) .. " FPS")
	SmoothCam:print("FPS Max: ", yellow, math.Round(SmoothCam.FPSMax, 0) .. " FPS")

	SmoothCam.Point = nil
	SmoothCam.Frame = nil
	SmoothCam.FrameCount = nil
	SmoothCam.FrameStart = nil
	SmoothCam.RenderFrame = nil
	SmoothCam.PlaybackStart = nil
	SmoothCam.ElapsedTime = nil
	SmoothCam.FPSMin = nil
	SmoothCam.FPSAvg = nil
	SmoothCam.FPSMax = nil
	SmoothCam.Pos = nil
	SmoothCam.Angles = nil
end

function SmoothCam.RETURN_FALSE()
	return false
end

function SmoothCam.RETURN_TRUE()
	return true
end

function SmoothCam.CancelUse(_, btn)
	if btn == IN_USE then
		SmoothCam:Stop()
	end
end

local view = { drawviewer = false }
function SmoothCam.CalcView(_, _, _, fov, znear, zfar)
	if not SmoothCam.Playing then return end

	SmoothCam:FrameAdvance()

	view.fov = fov
	view.znear = znear
	view.zfar = zfar
	view.origin = SmoothCam.Pos
	view.angles = SmoothCam.Angles

	return view
end

--## Saving ##--

file.CreateDir("smoothcam")

function SmoothCam:SavePoints(fileName)
	if #SmoothCam.Sequence.Points == 0 then
		SmoothCam:print(bad, "There are no points in this sequence to save.")
	else
		file.Write("smoothcam/" .. fileName .. ".json", util.TableToJSON(SmoothCam.Sequence))
		SmoothCam:print(good, "Saved sequence of #" .. #SmoothCam.Sequence.Points .. " points to ", pink, "garrysmod/data/smoothcam/" .. fileName .. ".json")
	end
end

function SmoothCam:LoadPoints(fileName)
	local sequence = file.Read("smoothcam/" .. fileName .. ".json", "DATA")
	if sequence then
		sequence = util.JSONToTable(sequence)
		if sequence then
			SmoothCam.Sequence = sequence
			SmoothCam:print(good, "Loaded ", yellow, "#" .. #SmoothCam.Sequence.Points, color_white, " point" .. (#SmoothCam.Sequence.Points ~= 1 and "s" or "") .. " from ", pink, "garrysmod/data/smoothcam/" .. fileName .. ".json")
			return
		end
	end

	SmoothCam:print(bad, "Failed to load sequence from this file, it may be corrupt.")
end

function SmoothCam:ForgetPoints(fileName)
	file.Delete("smoothcam/" .. fileName .. ".json")
	SmoothCam:print(good, "Deleted ", pink, "garrysmod/data/smoothcam/" .. fileName .. ".json")
end

--## Command ##--

concommand.Add("smoothcam", function(ply, _, args)
	if not IsValid(ply) or not ply:IsSuperAdmin() then return end

	local cmd = #args > 0 and args[1]:lower() or "play"
	
	if cmd == "stop" then

		if SmoothCam.Playing then
			SmoothCam:Stop()
		else
			SmoothCam:print(bad, "Not currently playing a sequence.")
		end

	elseif cmd == "help" then
		SmoothCam:print("Made by Billy (STEAM_0:1:40314158)\n")

		SmoothCam:print("TIP: You can press ", pink, (input.LookupBinding("+use", true) or "NOT BOUND"):upper(), color_white, " (your +use bind) to cancel playing a sequence")
		SmoothCam:print("TIP: Using the ", pink, "fps", color_white, " command, you can lock the framerate of a sequence so that every single frame is guaranteed to render. Duplicate frames can be dropped by third party video editing software.")
		SmoothCam:print("TIP: Sine in/out easing is on by default. To turn it off for a linear sequence, use the ", pink, "linear", color_white, " command.\n")

		SmoothCam:print(good, pink, "help")
		SmoothCam:print(good, "Shows this list of commands\n")

		SmoothCam:print(good, pink, "play")
		SmoothCam:print(good, "Plays the currently setup sequence\n")

		SmoothCam:print(good, pink, "reset")
		SmoothCam:print(good, "Resets all smooth camera points\n")

		SmoothCam:print(good, pink, "add")
		SmoothCam:print(good, "Adds a new camera point where you are standing & looking\n")

		SmoothCam:print(good, pink, "remove")
		SmoothCam:print(good, "Removes the last camera point\n")

		SmoothCam:print(good, pink, "remove <index>")
		SmoothCam:print(good, "Removes the camera point at the given index\n")

		SmoothCam:print(good, pink, "list")
		SmoothCam:print(good, "Lists all setup camera points\n")

		SmoothCam:print(good, pink, "time <seconds>")
		SmoothCam:print(good, "Sets the playback time in seconds for the entire sequence.\n")

		SmoothCam:print(good, pink, "fps <frames>")
		SmoothCam:print(good, "Locks the FPS for the entire sequence.")
		SmoothCam:print(good, "Set this to 0 to unlock the framerate.")
		SmoothCam:print(good, bad, "sv_cheats must be on for FPS < 30\n")

		SmoothCam:print(good, pink, "ease")
		SmoothCam:print(good, "Enables easeInOutSine easing for each point.\n")

		SmoothCam:print(good, pink, "linear")
		SmoothCam:print(good, "Disables any easing.\n")

		SmoothCam:print(good, pink, "save <name>")
		SmoothCam:print(good, "Saves the camera points to a file with the given name\n")

		SmoothCam:print(good, pink, "load <name>")
		SmoothCam:print(good, "Loads the camera points from the file with the given name\n")

		SmoothCam:print(good, pink, "forget <name>")
		SmoothCam:print(good, "Deletes the camera points file with the given name\n")

		SmoothCam:print(good, pink, "saved")
		SmoothCam:print(good, "Lists all saved camera point files")

	elseif not SmoothCam.Playing then

		if cmd == "play" then

			if #SmoothCam.Sequence.Points > 0 then
				SmoothCam:Play()
			else
				SmoothCam:print(bad, "There are no points in this sequence.")
			end

		elseif cmd == "add" then
			
			SmoothCam:AddPoint()
			SmoothCam:print(good, "Added point.")

		elseif cmd == "remove" then
			
			if args[2] then
				local index = tonumber(args[2])
				if index and index > 0 and index % 1 == 0 then
					if SmoothCam.Sequence.Points[index] then
						SmoothCam:RemovePoint(index)
					else
						SmoothCam:print(bad, "A point with that index does not exist.")
					end
				else
					SmoothCam:print(bad, "Please enter a valid integer of the point's index.")
				end
			elseif #SmoothCam.Sequence.Points > 0 then
				SmoothCam:RemovePoint()
			else
				SmoothCam:print(bad, "There are no points to remove.")
			end

		elseif cmd == "list" then
			
			SmoothCam:ListPoints()

		elseif cmd == "reset" then
			
			SmoothCam:ResetPoints()
			SmoothCam:print(good, "Reset points.")

		elseif cmd == "time" then
			
			if args[2] then
				local n, unit = args[2]:lower():Trim():match("^(%d+)%s*(%S*)$")
				n = tonumber(n)
				if n and n > 0 then
					if unit == "ms" or unit == "milliseconds" or unit == "millisecond" then
						SmoothCam.Sequence.Time = n / 1000
						SmoothCam:print(good, "Time set to ", pink, tostring(n), " milliseconds")
					elseif not unit or unit == "" or unit == "s" or unit == "second" or unit == "seconds" then
						SmoothCam.Sequence.Time = n
						SmoothCam:print(good, "Time set to ", pink, tostring(n), " seconds")
					else
						SmoothCam:print(bad, "Unrecognized time unit.")
						SmoothCam:print(bad, "Examples: ", pink, "500ms", color_white, ", ", pink, "5s")
					end
				else
					SmoothCam:print(bad, "Please enter a valid number greater than zero.")
					SmoothCam:print(bad, "Examples: ", pink, "500ms", color_white, ", ", pink, "5s")
				end
			else
				SmoothCam:print(bad, "Please enter a valid time.")
				SmoothCam:print(bad, "Examples: ", pink, "500ms", color_white, ", ", pink, "5s")
			end

		elseif cmd == "fps" then
			
			if args[2] then
				local frames = tonumber(args[2])
				if frames and frames >= 0 and frames % 1 == 0 then
					if frames < 30 and not GetConVar("sv_cheats"):GetBool() then
						SmoothCam:print(bad, "Please turn on sv_cheats to use an FPS lower than 30.")
					else
						SmoothCam.Sequence.FPS = frames
						SmoothCam:print(good, "FPS set to ", pink, tostring(frames))
						if frames ~= 0 then
							SmoothCam:print(good, "Frames in sequence: ", pink, format_thousands(SmoothCam.Sequence.Time * frames))
						end
					end
				else
					SmoothCam:print(bad, "Please enter frames per second as a positive integer.")
					SmoothCam:print(bad, "Enter ", pink, "0", color_white, " to reset frames per second and unlock the framerate.")
				end
			else
				SmoothCam:print(bad, "Please enter frames per second as a positive integer.")
				SmoothCam:print(bad, "Enter ", pink, "0", color_white, " to reset frames per second and unlock the framerate.")
			end

		elseif cmd == "linear" then
			
			SmoothCam.Sequence.Easing = false
			SmoothCam:print(good, "Disabled easing.")

		elseif cmd == "ease" then
			
			SmoothCam.Sequence.Easing = true
			SmoothCam:print(good, "Enabled easing.")

		elseif cmd == "save" then
			
			if args[2] then
				local fileName = utf8.force(args[2]:Trim())
				if fileName:match("^[a-zA-Z0-9_%-]+$") then
					SmoothCam:SavePoints(fileName)
				else
					SmoothCam:print(bad, "Please enter a file name that consists only of alphanumeric characters.")
				end
			else
				SmoothCam:print(bad, "Please enter a file name.")
			end

		elseif cmd == "load" then
			
			if args[2] then
				local fileName = utf8.force(args[2]:Trim())
				if fileName:match("^[a-zA-Z0-9_%-]+$") then
					if file.Exists("smoothcam/" .. fileName .. ".json", "DATA") then
						SmoothCam:LoadPoints(fileName)
					else
						SmoothCam:print(bad, "That file does not exist.")
					end
				else
					SmoothCam:print(bad, "Please enter a file name that consists only of alphanumeric characters.")
				end
			else
				SmoothCam:print(bad, "Please enter a file name.")
			end

		elseif cmd == "forget" then
			
			if args[2] then
				local fileName = utf8.force(args[2]:Trim())
				if fileName:match("^[a-zA-Z0-9_%-]+$") then
					if file.Exists("smoothcam/" .. fileName .. ".json", "DATA") then
						SmoothCam:ForgetPoints(fileName)
					else
						SmoothCam:print(bad, "That file does not exist.")
					end
				else
					SmoothCam:print(bad, "Please enter a file name that consists only of alphanumeric characters.")
				end
			else
				SmoothCam:print(bad, "Please enter a file name.")
			end

		elseif cmd == "saved" then
			
			local fs = file.Find("smoothcam/*.json", "DATA")
			if #fs == 0 then
				SmoothCam:print(bad, "There are no saved point files.")
			else
				for _, f in ipairs(fs) do
					SmoothCam:print((f:gsub("%.json$", "")))
				end
			end

		else
			SmoothCam:print(bad, "Unknown command! Type \"smoothcam help\" for a list of commands")
		end

	else
		SmoothCam:print(bad, "You cannot run any commands but ", pink, "stop", color_white, " and ", pink, "help", color_white, " whilst a sequence is playing.")
	end
end, function(cmd, args)
	local subcommands = {"help", "play", "reset", "add", "remove", "list", "time", "fps", "ease", "linear", "save", "load", "forget", "saved"}

	for index, subcommand in ipairs(subcommands) do
		subcommands[index] = cmd .. " " .. subcommand 
	end

	return subcommands
end)
