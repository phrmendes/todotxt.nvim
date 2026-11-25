#!/usr/bin/env nu

let range = if $env.BASE == '0000000000000000000000000000000000000000' {
    [$env.HEAD]
} else {
    git rev-list $'($env.BASE)..($env.HEAD)' | lines
}

let unsigned = $range
| each {|sha|
    gh api $'repos/($env.GITHUB_REPOSITORY)/commits/($sha)' | from json
}
| where {|commit| $commit.author.type? != 'Bot' and not $commit.commit.verification.verified }
| each {|commit| $commit.sha }

if ($unsigned | is-not-empty) {
    error make {msg: $'These commits are not signed: ($unsigned | str join ", ")'}
}
