#!/usr/bin/env nu

const PRODUCT = [
    lua/
    lsp/
    plugin/
    queries/
    sql/
    nix/
    flake.nix
    flake.lock
]

let last = git describe --tags --abbrev=0 | complete

# The first release is manual. Do not bump until its tag exists.
if $last.exit_code != 0 {
    $'name=(char nl)' | save --append $env.GITHUB_OUTPUT
    exit 0
}

let product = git diff --name-only $'($last.stdout | str trim)..HEAD'
| lines
| where {|path| $PRODUCT | any {|prefix| $path | str starts-with $prefix } }

if ($product | is-empty) {
    $'name=(char nl)' | save --append $env.GITHUB_OUTPUT
    exit 0
}

let before = open .cz.toml | get tool.commitizen.version
let bump = nix run --inputs-from . nixpkgs#commitizen -- bump --yes --files-only | complete

if $bump.exit_code == 21 {
    $'name=(char nl)' | save --append $env.GITHUB_OUTPUT
    exit 0
}

if $bump.exit_code != 0 {
    error make {msg: $bump.stderr}
}

let version = open .cz.toml | get tool.commitizen.version
let tag = $'v($version)'
let query = 'mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid } } }'

let additions = git diff --name-only
| lines
| each {|path| {path: $path, contents: (open --raw $path | encode base64)} }

let variables = {
    input: {
        branch: {
            repositoryNameWithOwner: $env.GITHUB_REPOSITORY
            branchName: $env.GITHUB_REF_NAME
        }
        expectedHeadOid: $env.GITHUB_SHA
        message: {headline: $'bump: version ($before) → ($version)'}
        fileChanges: {additions: $additions}
    }
}

let created = {query: $query, variables: $variables} | to json | gh api graphql --input - | complete

if $created.exit_code != 0 {
    error make {msg: $created.stderr}
}

let oid = $created.stdout | from json | get data.createCommitOnBranch.commit.oid
let ref = gh api --method POST $'repos/($env.GITHUB_REPOSITORY)/git/refs' --field $'ref=refs/tags/($tag)' --field $'sha=($oid)' | complete

if $ref.exit_code != 0 {
    error make {msg: $ref.stderr}
}

$'name=($tag)(char nl)' | save --append $env.GITHUB_OUTPUT
