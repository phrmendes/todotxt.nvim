#!/usr/bin/env nu

let notes = open --raw CHANGELOG.md
| split row --regex '(?m)^## '
| where {|section| $section | str starts-with $'($env.TAG) ' }
| get --optional 0
| default ''
| lines
| skip 1
| str join (char nl)
| str trim

if ($notes | is-empty) {
    error make {msg: 'The changelog has no section for the tag.'}
}

print $notes
