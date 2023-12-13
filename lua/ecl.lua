local M = {
	state = {
		window_id = nil,
		job_id = nil,
	},
}

local function strip(s)
	return s:gsub("^%s*(.-)%s*$", "%1")
end

local function get_goal()
	local b = vim.fn.line("v")
	local e = vim.fn.line(".")

	if b > e then
		b, e = e, b
	end

	local goal = ""
	if b == e then
		goal = vim.fn.getline(b)
	else
		for _, line in ipairs(vim.fn.getline(b, e)) do
			if line ~= "" then
				goal = goal .. line .. " \n"
			end
		end
		goal = strip(goal)
	end

	return goal
end

local function eclipserun(options)
	local goal = get_goal()

	if goal == "" then
		vim.notify("No goal", vim.log.levels.ERROR)
		return
	end
	local cmd = string.format("eclipserun %s --file '%s'", options, vim.fn.expand("%:p"))

	-- add each goal line as a separate argument
	for line in goal:gmatch("[^\r\n]+") do
		cmd = string.format(cmd .. " '%s'", line)
	end

	local output = ""

	local function process_output(_, data, _)
		for _, x in pairs(data) do
			output = output .. x .. "\n"
		end
	end

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		on_stdout = process_output,
		stderr_buffered = true,
		on_stderr = process_output,
		on_exit = function(_, code)
			local level = vim.log.levels.INFO
			if code ~= 0 then
				level = vim.log.levels.ERROR
			end
			output = strip(output)
			vim.notify(output, level)
		end,
	})
end

local function run_eclipse_in_terminal(opt)
	local goal = get_goal()

	if goal == "" then
		vim.notify("No goal", vim.log.levels.ERROR)
		return
	end

	local file = vim.fn.expand("%:p")

	if M.state.job_id == nil then
		vim.cmd("split")
		vim.cmd("resize -12")
		M.state.window_id = vim.api.nvim_get_current_win()
		local eclipse_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(M.state.window_id, eclipse_buf)
		M.state.job_id = vim.fn.termopen("eclipse", {
			on_exit = function(_, _)
				M.state.window_id = nil
				M.state.job_id = nil
			end,
		})
	end

	vim.fn.chansend(M.state.job_id, {
		string.format("['%s']. ", file),
		opt,
		goal,
		"",
	})

	vim.api.nvim_set_current_win(M.state.window_id)

	vim.fn.wait(150, false)
	-- if in visual mode, exit it
	if string.match(string.lower(vim.api.nvim_get_mode()["mode"]), "v") ~= nil then
		vim.cmd("normal esc")
	end
	vim.cmd("startinsert")
end

function M.setup(opts)
	-- eclipserun stuff
	vim.keymap.set({ "n", "v" }, "<localleader>r", function()
		eclipserun("")
	end, { desc = "Run goal" })

	vim.keymap.set({ "n", "v" }, "<localleader>R", function()
		eclipserun("--all")
	end, { desc = "Run goal (all results)" })

	-- built in stuff
	vim.keymap.set({ "n", "v" }, "<localleader>t", function()
		run_eclipse_in_terminal("trace.")
	end, { desc = "Run goal in terminal (trace)" })

	vim.keymap.set({ "n", "v" }, "<localleader>e", function()
		run_eclipse_in_terminal("")
	end, { desc = "Run goal in terminal" })
end

return M
