#!/usr/bin/env nu

if (gh release view $env.TAG | complete).exit_code == 0 {
    print --stderr 'The release already exists.'
    exit 0
}

let scripts = $env.CURRENT_FILE | path dirname
nu ($scripts | path join get-notes.nu) | save --force notes.md

gh release create $env.TAG --verify-tag --title $env.TAG --notes-file notes.md
