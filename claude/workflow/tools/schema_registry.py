#!/usr/bin/env python3
"""Validate an instance against a schema, resolving $ref offline from a local registry.

Built for WO-20261016-f052, order ORD-0921 E3. Seat dag-t6b was blocked on WO-20261016-efb2
(dag-state T6, intake node declarations) because dag/schemas/node.schema.json refs
bundle.schema.json and jsonschema fetched it over the network, which every gate forbids.

The store is every *.schema.json under the roots, keyed by its $id. Nothing is ever fetched.
Two implementations, chosen by SCHEMA_REF_IMPL (auto|registry|resolver):
  registry  referencing.Registry (jsonschema >= 4.18).
  resolver  RefResolver store. This exists because the pinned test image
            (Debian python3-jsonschema 4.10.3) has no referencing module.
  auto      registry when `referencing` imports, else resolver.

Usage: schema_registry.py <schema.json> <instance.json>
Env:   SCHEMA_REGISTRY_ROOTS  colon-separated roots, default the claude/workflow directory
Exit:  0 valid, 1 invalid, 2 registry error (REF-DUP-ID, REF-IMPL-MISSING, REF-UNRESOLVED)
"""
import json
import os
import pathlib
import sys

from jsonschema import Draft202012Validator


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)


def build_store(roots):
    store, origin = {}, {}
    for root in roots:
        for p in sorted(pathlib.Path(root).glob("**/*.schema.json")):
            s = json.loads(p.read_text())
            sid = s.get("$id") if isinstance(s, dict) else None
            if not sid:
                continue
            if sid in store and store[sid] != s:
                die(f"REF-DUP-ID {sid} {origin[sid]} {p}")
            store[sid] = s
            origin.setdefault(sid, str(p))
    return store


def _refuse(uri):
    raise RuntimeError(f"offline: refusing to fetch {uri}")


def make_validator(schema, store, impl):
    try:
        import referencing  # noqa: F401
        have_ref = True
    except ImportError:
        have_ref = False
    if impl == "registry" and not have_ref:
        die("REF-IMPL-MISSING referencing")
    if impl in ("auto", "registry") and have_ref:
        from referencing import Registry, Resource
        from referencing.jsonschema import DRAFT202012
        reg = Registry().with_resources(
            [(i, Resource.from_contents(s, default_specification=DRAFT202012)) for i, s in store.items()]
        )
        return Draft202012Validator(schema, registry=reg)
    from jsonschema import RefResolver
    resolver = RefResolver(base_uri=schema.get("$id", ""), referrer=schema, store=store,
                           handlers={"http": _refuse, "https": _refuse})
    return Draft202012Validator(schema, resolver=resolver)


def main(argv):
    if len(argv) != 2:
        die("usage: schema_registry.py <schema> <instance>")
    here = pathlib.Path(__file__).resolve().parent
    roots = [r for r in os.environ.get("SCHEMA_REGISTRY_ROOTS", "").split(":") if r] or [str(here.parent)]
    impl = os.environ.get("SCHEMA_REF_IMPL", "auto")
    schema = json.load(open(argv[0]))
    inst = json.load(open(argv[1]))
    v = make_validator(schema, build_store(roots), impl)
    try:
        errs = sorted(v.iter_errors(inst), key=lambda e: list(e.path))
    except Exception as ex:  # RefResolutionError, referencing Unresolvable, refused fetch
        name = type(ex).__name__
        if name in ("RefResolutionError", "Unresolvable", "PointerToNowhere", "NoSuchResource") or "offline" in str(ex):
            ref = getattr(ex, "ref", None) or str(ex)
            die(f"REF-UNRESOLVED {ref}")
        raise
    for e in errs:
        loc = "/".join(str(p) for p in e.path) or "(root)"
        print(f"  {loc}: {e.message}", file=sys.stderr)
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
