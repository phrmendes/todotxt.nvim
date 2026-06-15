---
--- Type definitions for the todotxt plugin
---
--- ==============================================================================
--- @module "todotxt.types"

--- Configuration for user-defined metadata tags
--- @class MetadataConfig
--- @field sort "asc"|"desc"|SortComparator Sorting method

--- Setup configuration for the todotxt module.
--- @class Setup
--- @field todotxt string Path to the todo.txt file
--- @field donetxt string Path to the done.txt file
--- @field ghost_text GhostTextConfig Ghost text configuration options
--- @field max_priority string|nil Last priority letter for cycling (default "C")
--- @field parser string|nil Parser backend: "regex" or "ts" (default "regex")
--- @field ring Priority Priority cycling ring
--- @field metadata table<string,MetadataConfig> User-defined metadata tags

--- Ghost text configuration options.
--- @class GhostTextConfig
--- @field enable boolean Enable ghost text display
--- @field mappings table<string, string> Priority patterns to ghost text mappings
--- @field prefix string Prefix to display before ghost text
--- @field highlight string Highlight group for ghost text
--- @field namespace_id number? Namespace ID for extmarks

--- Floating window options.
--- @class WindowOptions
--- @field width number Fraction of editor columns (0-1)
--- @field height number Fraction of editor lines (0-1)
--- @field border string Border of the window
--- @field style string Style of the window
--- @field buf number Buffer that the window will be attached
--- @field title string Title of the window

--- Floating window parameters.
--- @class WindowParameters
--- @field win number ID of the window
--- @field buf number ID of the buffer

--- @alias SortComparator fun(a: string, b: string): boolean

--- Parsed todo.txt line fields
--- @class ParsedLine
--- @field is_completed boolean
--- @field priority string|nil Priority letter (A-Z)
--- @field date { creation: string|osdate|nil, completion: string|osdate|nil } Creation and completion dates
--- @field projects string[] Project tags (without + prefix)
--- @field contexts string[] Context tags (without @ prefix)
--- @field kv table<string,string> Key-value metadata pairs
--- @field description string Line text with formatting tokens stripped

--- Priority ring for cycling through priority levels
--- @class Priority
--- @field first string First priority in range (always "A")
--- @field next fun(self: Priority, priority: string|nil): string|nil Advance to next priority or wrap
--- @field as_list fun(): string[]
--- @field range string[]
--- @field next_map table<string,string|nil>

return {}
