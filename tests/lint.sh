#!/bin/sh
# # x-krn -- the Kernel personality for x-lang
#
# ## tests/lint.sh -- shim onto the lang kit's linter
#
# @description Sources the PLATFORM's lint; vendors nothing.  --strict
#   fails on the advisory structural rules, which is how this bundle
#   wants them.
# @author [Jon Ruttan](jonruttan@gmail.com)
# @copyright 2026 Jon Ruttan
# @license MIT No Attribution (MIT-0)
#
#     ., .,
#     {O,O}
#     (   )
#      " "
#
# THE BUNDLE WAS SWEPT BY NOTHING.  x-lang's `make lint-x` covers lib/
# and apps/; a lang under languages/ was covered by neither, so every
# rule the linter knows was advice this bundle never heard.
#
# No targets are named here, unlike x-coreutils': the kit's default is
# every .x the bundle ships minus the generated harness, and for this
# bundle that is exactly right.  krn/ is three modules with a (provide)
# each, so the kit's sibling preload binds them to one another, and
# run.x is an entry the kit analyses as data.
#
# Set X to point at a particular x; X_LANG_KIT overrides the kit.
set -e

BUNDLE="$(cd "$(dirname "$0")/.." && pwd)"
X="${X:-x}"

command -v "$X" >/dev/null 2>&1 || {
	echo "x-krn: no x on PATH.  Set X=/path/to/x and retry." >&2
	exit 2
}

X_ROOT="$("$X" --share-dir)"
KIT="${X_LANG_KIT:-$X_ROOT/tools/lang-kit}"

# A GATE THE PLATFORM CANNOT RUN YET SKIPS; it does not fail the build.
# tests/spec-runner.sh hard-fails on a missing platform and that is right
# for it -- but the kit linter is new, and the two fixes THIS bundle's
# sources depend on are newer still, so hard-failing here would break
# `make lint` on every x that exists until a release lands.  That is a
# cadence this bundle does not set.  The day an x ships them the gate is
# hard everywhere with no edit here.
[ -f "$KIT/lint.sh" ] || {
	echo "x-krn: SKIPPING lint -- no $KIT/lint.sh in this x." >&2
	echo "x-krn: it arrives with the lang kit's linter; upgrade x to gate on it." >&2
	exit 0
}

# THE CAPABILITY, NOT THE VERSION NUMBER.  A version test would misjudge
# every tree between releases, which is what CI's `main` leg is; these
# two names are the fixes themselves.
#
#   _lang_constructs_for  -- the driver loading a bundle's OWN construct
#     table.  Without it krn/constructs.x is never read, nothing knows
#     that `$define!` binds a name or that `$lambda` takes parameters,
#     and krn/base.x reports thirty-six undefined references: its own
#     list primitives, their parameters, and make-environment.
#
#   %lint-letrec  -- the scope type krn/constructs.x declares $letrec
#     as.  Its bindings are visible inside their own inits; under plain
#     `let` the self-call in `reverse`'s rev-helper reads undefined.
#
# Both land together, so either one absent means the same thing.
if ! grep -q '_lang_constructs_for' "$X_ROOT/tools/dev/lint.sh" 2>/dev/null ||
   ! grep -q '%lint-letrec' "$X_ROOT/lib/x/tool/lint.x" 2>/dev/null; then
	echo "x-krn: SKIPPING lint -- this x's linter cannot read a bundle's" >&2
	echo "x-krn: own constructs.x (krn/constructs.x), so every Kernel" >&2
	echo "x-krn: operative would report undefined.  Upgrade x to gate on it." >&2
	exit 0
fi

BUNDLE="$BUNDLE" X="$X" sh "$KIT/lint.sh" --strict "$@"
