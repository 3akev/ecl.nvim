local M = {
	state = {
		window_id = nil,
		job_id = nil,
		old_win_id = nil,
	},
}

local api = vim.api

api.nvim_create_augroup("ecl.nvim_autocmds", { clear = true })
api.nvim_create_autocmd({ "TermLeave" }, {
	group = "ecl.nvim_autocmds",
	pattern = "*",
	callback = function()
		local win = api.nvim_get_current_win()
		if win == M.state.window_id then
			api.nvim_set_current_win(M.state.old_win_id)
		end
	end,
})
api.nvim_create_autocmd({ "WinEnter" }, {
	group = "ecl.nvim_autocmds",
	pattern = "*",
	callback = function()
		local win = api.nvim_get_current_win()
		if win == M.state.window_id then
			-- if in visual mode, exit it
			api.nvim_win_call(win, function()
				if string.match(string.lower(api.nvim_get_mode()["mode"]), "v") ~= nil then
					vim.cmd("normal esc")
				end
				vim.cmd("startinsert")
			end)
		end
	end,
})
api.nvim_create_autocmd({ "WinLeave" }, {
	group = "ecl.nvim_autocmds",
	pattern = "*",
	callback = function()
		local win = api.nvim_get_current_win()
		if win ~= M.state.window_id then
			M.state.old_win_id = win
		end
	end,
})

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

	M.state.old_win_id = api.nvim_get_current_win()
	if M.state.job_id == nil or not api.nvim_win_is_valid(M.state.window_id) then
		vim.cmd("split")
		vim.cmd("resize -12")
		M.state.window_id = api.nvim_get_current_win()
		local eclipse_buf = api.nvim_create_buf(false, true)
		api.nvim_win_set_buf(M.state.window_id, eclipse_buf)
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

	api.nvim_set_current_win(M.state.window_id)

	vim.fn.wait(150, false)
	-- if in visual mode, exit it
	if string.match(string.lower(api.nvim_get_mode()["mode"]), "v") ~= nil then
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
