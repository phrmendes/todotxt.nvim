return {
	completed = "^x%s+",
	completed_with_priority = "^x%s+%(%a%)%s+",
	completed_with_date = "^x%s+%d%d%d%d%-%d%d%-%d%d%s+",
	completed_with_priority_and_creation_date = "^x%s+%(%a%)%s+%d%d%d%d%-%d%d%-%d%d%s+",
	completed_with_priority_creation_and_done_date = "^x%s+%(%a%)%s+%d%d%d%d%-%d%d%-%d%d%s+%d%d%d%d%-%d%d%-%d%d%s+",
	context = "@%w+",
	date = "%d%d%d%d%-%d%d%-%d%d",
	date_with_space = "%d%d%d%d%-%d%d%-%d%d%s+",
	due_date = "due:(%d%d%d%d%-%d%d%-%d%d)",
	hidden_tag = "h:(%d+)",
	letter = "%a",
	priority = "%(%a%)",
	priority_letter = "%((%a)%)",
	priority_with_space = "%(%a%)%s+",
	-- Hierarchical project patterns (see: https://github.com/todotxt/todo.txt-cli/issues/454)
	project = "%+[%w%-]+", -- Updated to support dashes: +project-subproject
	project_full = "%+[%w%-]+", -- Full hierarchical project pattern
	project_parent = "%+([%w]+)", -- Captures parent project name (text before first dash)
	project_hierarchy = "%+([%w%-]+)", -- Captures full project hierarchy
}
