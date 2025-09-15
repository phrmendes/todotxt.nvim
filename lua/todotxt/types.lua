---
--- Type definitions for the todotxt plugin
---
--- ==============================================================================
--- @module "todotxt.types"

--- Setup configuration for the todotxt module.
--- @class Setup
--- @field todotxt string Path to the todo.txt file
--- @field donetxt string Path to the done.txt file
--- @field create_commands boolean Whether to create commands for the functions
--- @field ghost_text GhostTextConfig Ghost text configuration options

--- Priority pattern enum for todo.txt format
--- @alias PriorityPattern
--- | "(A)" # Highest priority
--- | "(B)" # High priority
--- | "(C)" # Medium priority
--- | "(D)" # Low priority
--- | "(E)" # Lower priority
--- | "(F)" # Lowest priority

--- Ghost text configuration options.
--- @class GhostTextConfig
--- @field enable boolean Enable ghost text display
--- @field mappings table<PriorityPattern, string> Priority patterns to ghost text mappings
--- @field prefix string Prefix to display before ghost text
--- @field highlight string Highlight group for ghost text
--- @field namespace_id number? Namespace ID for extmarks

--- Floating window options.
--- @class WindowOptions
--- @field width number Width of the window
--- @field height number Height of the window
--- @field border string Border of the window
--- @field style string Style of the window
--- @field buf number Buffer that the window will be attached
--- @field title string Title of the window

--- Floating window parameters.
--- @class WindowParameters
--- @field win number ID of the window
--- @field buf number ID of the buffer

--- @alias SortComparator fun(a: string, b: string): boolean
--- @alias SortFunction fun(): nil

--- Config module
--- @class Config
--- @field todotxt string Path to the todo.txt file
--- @field donetxt string Path to the done.txt file

return {}
