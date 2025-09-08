# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## 📖 Overview

`todotxt.nvim` is a Neovim plugin written in Lua that provides functionality for managing todo.txt formatted files. It's a modern rewrite of the `todotxt.vim` plugin, offering features like task completion toggling, priority cycling, sorting, and floating window interfaces.

## 🛠️ Development Commands

### Testing
The project uses `MiniTest` framework via headless Neovim:

```bash
# Run all tests
just test

# Run tests for a specific file  
just test_file tests/test_todotxt.lua
```

**Prerequisites**: Install [just](https://github.com/casey/just) if not available:
- **macOS**: `brew install just`
- **Linux**: `curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to DEST`

### Code Formatting
Uses [stylua](https://github.com/JohnnyMorganz/StyLua) with configuration in `.stylua.toml`:

```bash
# Format all Lua files
stylua lua/ ftplugin/ tests/ scripts/

# Check formatting without modifying
stylua --check lua/ ftplugin/ tests/ scripts/
```

**Installation**: `cargo install stylua` or `brew install stylua`

### Linting
While not configured by default, you can use `luacheck`:

```bash
# Install luacheck
luarocks install luacheck

# Lint the codebase  
luacheck lua/ ftplugin/ tests/ --globals vim
```

### Health Check
The plugin includes a health check command:

```bash
# In Neovim after plugin setup
:checkhealth todotxt
```

## 🏗️ Architecture Overview

### Module Structure

```
lua/todotxt/
├── init.lua          # Main public API and user commands
├── task.lua          # Task parsing and state management
├── utils.lua         # Utility functions and floating windows
├── patterns.lua      # Regex patterns for todo.txt format
├── comparators.lua   # Sorting comparison functions
├── sorter.lua        # Higher-order sorting function generator
├── state.lua         # Global plugin state (window/buffer tracking)
└── health.lua        # Health check functionality
```

### Data Flow

```
User Input/Command
       ↓
   init.lua (Public API)
       ↓
   utils.get_infos() → Extract buffer/line info
       ↓
   task.is_completed() / task.format_*() → Parse/modify task
       ↓
   sorter.create() → Generate sort function
       ↓  
   comparators.*() → Apply sorting logic
       ↓
   Buffer Update → Write changes back
```

### Core Functionality

- **Task State Management**: Toggle completion status with date stamps
- **Priority Cycling**: Cycle through priorities A→B→C→none→A
- **Multi-criteria Sorting**: By completion, priority, project, context, due date
- **Hidden Task Support**: Hide tasks containing metadata using `h:1` tags
- **Floating Windows**: Custom window management for todo.txt and done.txt files
- **File Synchronization**: Automatic sync between file changes and open buffers

### Key Patterns

- **Functional Composition**: Uses `vim.iter()` for data processing
- **Pattern Matching**: Extensive use of Lua patterns for parsing todo.txt format
- **State Isolation**: Plugin state stored in separate module for clean separation
- **Window Management**: Floating windows with auto-save on close

## 🧪 Testing Strategy

### Test Organization
- **Main Tests**: `tests/test_todotxt.lua` - comprehensive functionality tests
- **Test Utilities**: `tests/utils.lua` - helper functions and test data
- **Test Init**: `scripts/init.lua` - test environment setup

### Test Categories
- **Core Functionality**: Task toggling, priority cycling, sorting
- **Edge Cases**: Empty files, malformed data, special characters
- **File Operations**: Moving done tasks, buffer synchronization
- **Complex Formats**: Multiple dates, projects, contexts

### Running Individual Tests
```bash
# Test a specific function
just test_file tests/test_todotxt.lua

# For development, modify scripts/init.lua to focus on specific test cases
```

## 📝 Development Conventions

### Code Style
- **Lua Version**: Compatible with Lua 5.1 (Neovim's embedded Lua)
- **API Usage**: Uses modern Neovim 0.9+ APIs (`vim.uv`, `vim.iter`, etc.)
- **Type Annotations**: Uses EmmyLua annotations for better IDE support
- **Error Handling**: Graceful error handling with user notifications
- **Documentation**: Comprehensive docstrings following LuaLS format

### File Structure
- **Module Pattern**: Each module returns a table of functions
- **Dependency Injection**: Modules import dependencies at the top
- **Configuration**: Plugin config stored in shared `config` table
- **State Management**: Global state isolated to `state.lua`

### Commit Guidelines
Follow conventional commits:
- `feat:` for new features
- `fix:` for bug fixes  
- `docs:` for documentation changes
- `test:` for test updates
- `refactor:` for code refactoring

## 🐛 Debugging Tips

### Common Development Tasks

1. **Testing New Functionality**:
   ```lua
   -- Add to scripts/init.lua for quick testing
   local M = require("todotxt")
   M.setup({ todotxt = "/tmp/test_todo.txt", donetxt = "/tmp/test_done.txt" })
   ```

2. **Debugging Pattern Matching**:
   ```lua
   -- Test patterns in Neovim
   :lua print(vim.inspect(require("todotxt.patterns")))
   ```

3. **Buffer State Inspection**:
   ```lua
   -- Check current plugin state
   :lua print(vim.inspect(require("todotxt.state")))
   ```

### Test File Locations
- Temporary test files created in `/tmp/todotxt.nvim/`
- Test utilities handle cleanup automatically
- Real test files use unique timestamps to avoid conflicts

### Plugin Loading
- Plugin uses guard (`vim.g.loaded_todotxt`) to prevent double loading
- Commands are created during `setup()` call
- File type detection added for `.txt` files matching todo/done patterns

## 🔧 Plugin Configuration

### Minimal Setup
```lua
require("todotxt").setup({
  todotxt = vim.env.HOME .. "/Documents/todo.txt",
  donetxt = vim.env.HOME .. "/Documents/done.txt",
  -- hide_tasks = true by default (hides tasks with h:1 tags)
})
```

### Setup with All Tasks Visible
```lua
require("todotxt").setup({
  todotxt = vim.env.HOME .. "/Documents/todo.txt",
  donetxt = vim.env.HOME .. "/Documents/done.txt",
  hide_tasks = false, -- Show all tasks including h:1 tags
})
```

### Development Setup  
```lua
-- For testing with local files
require("todotxt").setup({
  todotxt = "./test_todo.txt",
  donetxt = "./test_done.txt", 
  -- hide_tasks = true by default
})
```

### Key Mappings (from ftplugin/todotxt.lua)
- `<Plug>(TodoTxtToggleState)` - Toggle task completion
- `<Plug>(TodoTxtCyclePriority)` - Cycle task priority
- `<Plug>(TodoTxtMoveDone)` - Move completed tasks to done.txt
- Various sort mappings for different criteria

## 🙈 Hidden Task Support

The plugin supports hiding tasks that contain only metadata using the `h:1` tag. This is useful for tasks that store project information, recurring task templates, or other metadata that shouldn't clutter your main task view.

### Usage

```txt
# Visible tasks
(A) Important project task +work @office
(B) Call client about meeting +work @phone

# Hidden tasks (only shown when hide_tasks = false)
Project template: +work @office h:1
Recurring meeting template: +work @meeting rec:weekly h:1
```

### Configuration

- **`hide_tasks = true`** (default): Tasks with `h:1` (or any positive value) are hidden from the floating window display
- **`hide_tasks = false`**: All tasks are visible

### Behavior

- **Filtering**: Only applies to the main `todo.txt` view, not `done.txt`
- **Preservation**: Hidden tasks are automatically preserved when saving changes
- **Operations**: All plugin operations (sorting, moving done tasks, etc.) work correctly with hidden tasks
- **Tag Values**: 
  - `h:0` - Task is visible (same as no tag)
  - `h:1` or higher - Task is hidden

### Testing Hidden Tasks

```lua
-- Test hidden tag detection
local utils = require("todotxt.utils")
print(utils.get_hidden_tag_value("Task with h:1")) -- Returns: 1
print(utils.should_hide_task("Task h:1", { hide_tasks = true })) -- Returns: true
```

The plugin integrates with nvim-treesitter via the `todotxt` parser for enhanced syntax highlighting.
