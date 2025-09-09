# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Hierarchical Project Support**: Added support for sub-projects using dash notation (e.g., `+work-meeting-standup`)
  - Based on feature request: https://github.com/todotxt/todo.txt-cli/issues/454
  - New `lua/todotxt/project.lua` module with utilities for extracting, parsing, and grouping hierarchical projects
  - Enhanced project sorting to group by parent project first, then by sub-project hierarchy
  - Comprehensive test coverage for hierarchical project functionality
  - Backward compatible with existing flat project syntax (`+project`)
  - Tasks can contain both flat (`+work`) and hierarchical (`+work-meeting`) projects
- Project operations (completion toggle, priority cycling) preserve hierarchical project tokens

### Fixed
- **File Creation Error**: Fixed "File exists" error when saving new `todo.txt` files (issue #8)
  - Root cause: Buffer-local `BufWriteCmd` autocmds from floating windows could persist and interfere with normal file editing
  - Solution: Redesigned save interception to be strictly scoped to floating buffers with proper cleanup
  - Added robust file creation support with atomic saves (temp file + rename)
  - Enhanced save handler supports creating files in non-existent directories
  - Comprehensive test coverage for both floating and normal editing contexts
  - Ensures save interception is limited to floating window context only

### Changed
- Updated project pattern in `patterns.lua` to support dash separators in project names
- Enhanced `comparators.project` to sort hierarchically by parent project, then sub-project path
- Updated documentation with hierarchical project examples and usage

### Technical Details
- Added `project.extract_projects()`, `project.get_project_hierarchy()`, `project.get_parent_projects()` utilities
- Added `project.group_by_parent()` and `project.filter_by_subproject()` for task organization
- Enhanced test suite with comprehensive hierarchical project test cases
