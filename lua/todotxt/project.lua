-- Hierarchical project utilities for todotxt.nvim
-- Implements sub-project support based on: https://github.com/todotxt/todo.txt-cli/issues/454
-- Supports grouping projects like +foo-frobnizer as sub-projects of +foo

local patterns = require("todotxt.patterns")

local project = {}

--- Extracts all projects from a task line
--- @param line string The task line
--- @return string[] projects Array of project strings (without + prefix)
project.extract_projects = function(line)
	local projects = {}
	for proj in line:gmatch(patterns.project_hierarchy) do
		table.insert(projects, proj)
	end
	return projects
end

--- Parses a project string into hierarchical components
--- @param project_str string Project string like "foo-bar-baz" (without + prefix)
--- @return table hierarchy { parent = "foo", sub = { "bar", "baz" } }
project.get_project_hierarchy = function(project_str)
	if not project_str then return { parent = nil, sub = {} } end

	-- Split on dashes
	local parts = {}
	for part in project_str:gmatch("[^%-]+") do
		table.insert(parts, part)
	end

	if #parts == 0 then return { parent = nil, sub = {} } end

	return {
		parent = parts[1],
		sub = vim.list_slice(parts, 2),
	}
end

--- Gets unique parent projects from a task line
--- @param line string The task line
--- @return string[] parents Array of unique parent project names
project.get_parent_projects = function(line)
	local projects = project.extract_projects(line)
	local parents = {}
	local seen = {}

	for _, proj in ipairs(projects) do
		local hierarchy = project.get_project_hierarchy(proj)
		if hierarchy.parent and not seen[hierarchy.parent] then
			table.insert(parents, hierarchy.parent)
			seen[hierarchy.parent] = true
		end
	end

	return parents
end

--- Gets the first project (for sorting/comparison purposes)
--- @param line string The task line
--- @return string|nil project First project string or nil if none
project.get_first_project = function(line)
	local projects = project.extract_projects(line)
	return projects[1]
end

--- Gets the first parent project (for primary sorting)
--- @param line string The task line
--- @return string|nil parent First parent project name or nil if none
project.get_first_parent = function(line)
	local first_proj = project.get_first_project(line)
	if not first_proj then return nil end

	local hierarchy = project.get_project_hierarchy(first_proj)
	return hierarchy.parent
end

--- Gets the sub-project path from the first project
--- @param line string The task line
--- @return string|nil sub_path Sub-project path like "bar-baz" or nil
project.get_first_subproject_path = function(line)
	local first_proj = project.get_first_project(line)
	if not first_proj then return nil end

	local hierarchy = project.get_project_hierarchy(first_proj)
	if #hierarchy.sub == 0 then return nil end

	return table.concat(hierarchy.sub, "-")
end

--- Groups tasks by parent project
--- @param tasks string[] Array of task lines
--- @return table<string, string[]> groups Table keyed by parent project with task arrays
project.group_by_parent = function(tasks)
	local groups = {}

	for _, task in ipairs(tasks) do
		local parents = project.get_parent_projects(task)

		if #parents == 0 then
			-- Tasks without projects go in a special group
			if not groups["__no_project__"] then groups["__no_project__"] = {} end
			table.insert(groups["__no_project__"], task)
		else
			-- Add task to each parent group (tasks can have multiple projects)
			for _, parent in ipairs(parents) do
				if not groups[parent] then groups[parent] = {} end
				table.insert(groups[parent], task)
			end
		end
	end

	return groups
end

--- Filters tasks by project hierarchy
--- @param tasks string[] Array of task lines
--- @param parent string Parent project name
--- @param sub_path string|nil Optional sub-project path
--- @return string[] filtered Array of matching tasks
project.filter_by_subproject = function(tasks, parent, sub_path)
	local filtered = {}

	for _, task in ipairs(tasks) do
		local projects = project.extract_projects(task)

		for _, proj in ipairs(projects) do
			local hierarchy = project.get_project_hierarchy(proj)

			if hierarchy.parent == parent then
				if not sub_path then
					-- Match any task under this parent
					table.insert(filtered, task)
					break
				else
					-- Match specific sub-project path
					local current_sub_path = table.concat(hierarchy.sub, "-")
					if current_sub_path == sub_path then
						table.insert(filtered, task)
						break
					end
				end
			end
		end
	end

	return filtered
end

return project
