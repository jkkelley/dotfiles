# Wiki engine

## Contents

- [What it is](#what-it-is)
- [Call form](#call-form)
- [Layout](#layout)

## What it is

A generic, config-driven wiki engine.
A wiki is a directory that holds `wiki.json`, `pages.json` and content only; the engine lives here.
Design: `docs/design/wiki.md` and `docs/design/wiki.spec.xml`.

## Call form

`make -C ~/dotfiles wiki-<verb> WIKI=<root>`.
An empty `WIKI` is a usage error, exit 2.
`make wiki-test` runs `tests/test_*.py` in the pinned python image; `TESTS=<file>` selects one.

## Layout

- `wiki.mk` - included from the root Makefile; includes `mk/*.mk`, one per verb.
- `wikilib.py` - stdlib helpers every verb calls.
- `wiki_<verb>.py` and `tests/test_<verb>.py` - added by the verb tickets.
- `secret-patterns.json` - default patterns, overridden by `<WIKI>/secret-patterns.json`.
