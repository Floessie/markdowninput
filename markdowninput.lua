-- Replace LaTeX characters and adjust quoting
local function replace(line, state)
	-- LaTeX
	line = line:gsub("\\", "\\textbackslash{}")
	line = line:gsub("&", "\\&")
	line = line:gsub("%%", "\\%%")
	line = line:gsub("%$", "\\$")
	line = line:gsub("#", "\\#")
	line = line:gsub("_", "\\_")
	line = line:gsub("{", "\\{")
	line = line:gsub("}", "\\}")
	line = line:gsub("~", "\\textasciitilde{}")
	line = line:gsub("%^", "\\textasciicircum{}")

	-- Quoting
	line = line:gsub("„", "\\frqq{}")
	line = line:gsub("“", "\\flqq{}")
	line = line:gsub("‚", "\\frq{}")
	line = line:gsub("‘", "\\flq{}")

	-- Auto quoting
	line = line:gsub(
		"\"",
		function(character)
			if not state.auto_double_quoting then
				state.auto_double_quoting = true
				return "\\frqq{}"
			end

			state.auto_double_quoting = false
			return "\\flqq{}"
		end
	)
	line = line:gsub(
		"´",
		function(character)
			if not state.auto_double_quoting then
				state.auto_double_quoting = true
				return "\\frq{}"
			end

			state.auto_double_quoting = false
			return "\\flq{}"
		end
	)

	-- Miscellaneous
	line = line:gsub("%.%.%.", "\\ldots{}")
	line = line:gsub("%-%-", "\\textendash{}")
	line = line:gsub("%-%-%-", "\\textemdash{}")

	return line
end

-- Turn one or two stars into italic and bold text
local function translateStars(line, state)
	local res

	local start, stop, plain, special = line:find("(.-)([\\*]+)")

	while plain and special do
		special = special:gsub("\\\\", "\\textbackslash{}")
		special = special:gsub("\\%*", "X") -- Protect escaped star
		special = special:gsub("\\", "\\textbackslash{}")
		special = special:gsub(
			"(%*%*)",
			function(match)
				if not state.bold then
					state.bold = true
					return "\\bfseries{}"
				end

				state.bold = false
				local res = "\\normalfont{}"

				if state.italics then
					res = res .. "\\itshape{}"
				end

				return res
			end
		)
		special = special:gsub(
			"(%*)",
			function(match)
				if not state.italics then
					state.italics = true
					return "\\itshape{}"
				end

				state.italics = false
				local res = "\\normalfont{}"

				if state.bold then
					res = res .. "\\bfseries{}"
				end

				return res
			end
		)
		special = special:gsub("X", "*")

		res = (res or "") .. replace(plain, state) .. special

		local last_stop = stop

		start, stop, plain, special = line:find("(.-)([\\*]+)", stop + 1)

		if not stop then
			res = res .. replace(line:sub(last_stop + 1), state)
		end
	end

	return res or replace(line, state)
end

-- Turn MD hashes into LaTeX sectional divisions
local function translateHashes(hashes, title)
	local cases = {
		[1] = function(title)
			return "\\mdiChapter{" .. title .. "}"
		end,
		[2] = function(title)
			return "\\mdiSection{" .. title .. "}"
		end,
		[3] = function(title)
			return "\\mdiSubsection{" .. title .. "}"
		end
	}

	local case = cases[hashes]

	if case then
		return case(title)
	end
end

-- Create dropcaps using lettrine
local function doDropcaps(line)
	local preceeding, first_letter, succeeding = unicode.utf8.match(line, "^(.-)(%u)(.*)$")

	if not first_letter then
		return false, line
	end

	local ante

	if preceeding:find("\\frqq?{} *$") then
		ante = preceeding:match("(\\frqq?{}) *$")
		preceeding = preceeding:match("^(.*)\\frqq?{} *$")
	end

	local function makeRule(letter, ante, parameters)
		local res =  "\\lettrine[lines=3"

		if ante then
			res = res .. ", ante=" .. ante
		end

		if parameters then
			res = res .. ", " .. parameters
		end

		res = res .. "]"

		return res .. "{" .. letter .. "}{}"
	end

	local rules = {}

	-- This is just a basic mapping but you get the idea
	for letter in unicode.utf8.gmatch("ABCDEFGHIJKLMNOPQRSTUVWXYZ", ".") do
		rules[letter] = function(ante)
			return makeRule(letter, ante)
		end
	end

	local rule = rules[first_letter]

	if rule then
		return true, preceeding .. rule(ante) .. succeeding
	end

	return true, line
end

-- Process single line
local function processLine(line, state)
	-- Code blocks go to LaTeX directly
	if line:find("^```") then
		state.verbatim = not state.verbatim
		return ""
	end

	if state.verbatim then
		return line
	end

	-- Reset font at the end of a paragraph
	if line == "" and (state.italics or state.bold) then
		state.italics = false
		state.bold = false
		return "\\normalfont", ""
	end

	-- Sectional divisions (detection)
	local hashes, title
	if line:find("^#+ ?") then
		hashes, title = line:match("^#+() *(.*)$")

		hashes = hashes - 1
		title = translateStars(title, state)
	end

	-- Star and escape handling
	line = translateStars(line, state)

	-- Sectional divisions (conversion)
	if hashes then
		local translated = translateHashes(hashes, title)
		if translated then
			line = translated
		end
	end

	-- Dropcaps on first word of chapter
	if line:find("\\mdiChapter%b{}") then
		state.dropcaps = true
	elseif state.dropcaps then
		local valid, new_line = doDropcaps(line)
		line = new_line
		if valid then
			state.dropcaps = false
		end
	end

	return line
end

-- Called from the LaTeX command
function markdownInput(filename)
	local state = {
		italics = false,
		bold = false,
		auto_double_quoting = false,
		auto_single_quoting = false,
		dropcaps = false,
		verbatim = false
	}

	for line in io.lines(filename) do
		tex.print(processLine(line, state))
	end

	if state.auto_double_quoting then
		print "\n\nUnbalanced automatic double quoting."
		os.exit(1)
	end

	if state.auto_single_quoting then
		print "\n\nUnbalanced automatic single quoting."
		os.exit(1)
	end

	if state.verbatim then
		print "\n\nUnfinished verbatim LaTeX."
		os.exit(1)
	end
end
