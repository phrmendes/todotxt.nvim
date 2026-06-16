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
--- @field lsp? boolean Enable in-process LSP (default true)
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

--- In-process LSP server stub passed to vim.lsp.start.
--- @class todotxt.lsp.Server
--- @field request fun(method: string, params: table, callback: function): boolean
--- @field notify fun(method: string, params: table): boolean
--- @field is_closing fun(): nil
--- @field terminate fun(): nil

--- Deduplicated tag collections from a buffer scan.
--- @alias todotxt.lsp.GatherData { projects: table<string,boolean>, contexts: table<string,boolean>, kv: { keys: table<string,boolean>, values: table<string,table<string,boolean>> }, ring?: Priority }

--- Resolved tag at a cursor position.
--- @alias todotxt.lsp.Tag { prefix: string, name: string, col: integer }

--- @class todotxt.lsp.utils
--- @field gather fun(buffer: integer): todotxt.lsp.GatherData
--- @field build_items fun(data: todotxt.lsp.GatherData, trigger: string|nil, pos: table|nil): lsp.CompletionItem[]
--- @field get_tag_under_cursor fun(line: string, parsed: ParsedLine, col: integer): todotxt.lsp.Tag|nil
--- @field make_location fun(bufname: string, i: integer, l: string, prefix: string, name: string): lsp.Location|nil
--- @field make_text_edit fun(i: integer, l: string, prefix: string, name: string, new_name: string): lsp.TextEdit|nil
--- @field get_description fun(text: string): string
--- @field dispatch fun(handlers: table<string, function>, method: string, ...: any): boolean

return {}
