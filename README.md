# x-krn — Kernel on x-lang

A [Kernel](https://web.cs.wpi.edu/~jshutt/kernel.html) surface language riding
on x-lang. Operatives (`$vau`) are first-class; applicatives derive from them
via `wrap`. Same s-expressions as Scheme, the opposite evaluation model.

```
$ x -l krn
Kernel 0.1.0
>> ($define! (sq x) (* x x))
>> (sq 9)
81
>> (member 'b '(a b c))
(b c)
```

This is a **personality**, not a dialect — it re-means shared spellings on
purpose, which is exactly what x-lang's
[personality contract](../../x-lang/docs/personality-contract.md) permits and
what makes it safe to ship separately from the platform.

## Status

72 specs, all green against x-lang **0.5.2** and an x-engine-c carrying the
[#527](https://github.com/jonruttan/x-lang/issues/527) fix.

This is the first of the five 2024-era personalities to come back, and it is
deliberately the smallest: it exists to be the worked example the other four
are ported against.

## Running it

The spec suite needs nothing but an `x` it can find:

```bash
X=/path/to/x-lang/x.sh sh tests/spec-runner.sh
```

Getting a **prompt** needs one more step today, and the reason is worth
knowing. `x -l NAME` resolves `lib/NAME.x` then `apps/NAME/run.x`; there is no
third step that searches a personality root, so a bundle living outside the
platform tree cannot yet be named. Until that step exists, point the platform
at this bundle:

```bash
ln -s "$PWD" /path/to/x-lang/apps/krn
```

then, **from the x-lang repo root** (`x.sh` detects a checkout by looking for
`lib/x.x` under the cwd):

```bash
./x.sh -l krn                 # interactive
./x.sh -l krn -f program.krn  # batch
```

The symlink is a bridge, not the design. Nothing in the test path uses it.

## Layout

```
personality.xon        what this bundle is: name, dialect, release pairing
run.x                  THE entry -- the only file that may know a path
krn/base.x             the language
krn/printer.x          Kernel's own result writer
krn/constructs.x       construct declarations (formatter metadata)
tests/spec-runner.sh   ~20 lines; sources the PLATFORM's runner
tests/gen-harness.sh   writes tests/lib/harness.gen.x (never committed)
tests/specs/*.spec.md  the suite
```

**One entry file, and one only.** `run.x` is the single file allowed to know
where anything lives; `krn/base.x` reaches `krn/printer.x` by `import`, so the
tree relocates. That rule is not decoration — path literals in every file are
the first of the three reasons the 2024 generation of these died.

## What porting it actually cost

The 2024 tree was closer to alive than it looked. Deleting **one line** —
`(include "lib/x-core.x")`, which the entry now owns — took the suite from
"dies at load" to 68/72. The remaining four were four different problems:

**`string?` was renamed.** The platform spells it `str?` now. Kernel keeps the
Scheme name, which is what a personality is *for*; it sits with the `cons`/`car`
aliases beside it.

**Symbols print differently.** x's `write` is round-trippable, so `(list 'b 'c)`
renders `('b 'c)` — right for x, documented in its spec, and wrong for Kernel.
`krn/printer.x` is ~20 lines of recursive descent that renders symbols bare and
delegates everything else, installed through the `%repl-print` seam. A
re-meaning, not a workaround.

**Internal definitions never worked.**
`($define! (f x) ($define! y (+ x 1)) (* x y))` needs `(f 3)` to be 12. It
cannot work by evaluating the inner `$define!` at run time: `$define!` is an
operative, so its `def` runs in `$define!`'s own frame, and in body position
that frame is not in tail position — the binding is created and discarded with
it. The name ends up unbound *everywhere*, not shadowed. Passing the
environment to `eval` does not help either; `def` under an explicit-env `eval`
binds somewhere the caller cannot see.

The fix is a rewrite at construction time, which is how Schemes handle internal
defines anyway: `$lambda` turns a body-position `$define!` into a literal `def`,
which x binds in the body's own frame. One level deep, deliberately — a
`$define!` nested inside an `$if` is not a definition context in Kernel either.

The top-level `$define!` used to rely on the mirror-image trick — its `eval` in
tail position, so TCO had popped the frame by the time `def` ran and the binding
landed globally. That worked and was fragile: one extra wrapper frame anywhere
up the call chain and every definition vanished silently. It now goes through
`(base def-global)`, which takes the global path whatever the frame depth
([#527](https://github.com/jonruttan/x-lang/issues/527)). The body-position
rewrite stays, because an *internal* definition should bind locally — the two
are different problems and only one of them is about frame depth.

## Three things upstream should know

*(The first is now fixed; the other two are still open.)*

Ports find bugs, and this one found three. All are noted at their call sites.

**`(include "lib/x-core.x")` on a booted tower was a segfault**, not an error,
with no diagnostic. Every one of the five personalities opens with that line,
so it was the first thing anyone extracting one hit.

Fixed ([#515](https://github.com/jonruttan/x-lang/issues/515)), and the fix is
not where the report guessed: `module.x`'s wrapper was only part of it, and a
per-module sweep found **39 of 56 platform modules individually
non-idempotent**. Hardening each would have been 39 fixes; making `x-core.x`'s
sub-includes `include-once` — so a second include skips work already done — was
one.

**`--share-dir` cannot be asked from outside the repo.** Its own comment says
it exists "so a tool outside this repository can ASK instead of guessing", but
repo mode is detected by testing for `lib/x.x` under the *cwd*, so a checkout's
wrapper answers `pwd` — correct only for a caller already standing in x-lang.
`tests/spec-runner.sh` works around it by `cd`-ing to the wrapper's own
directory first.

**`<root>/boot/x-base.x` does not exist in a checkout.** The contract's "one
relative path works in both modes" holds for `<root>/tests/` but not for the
boot amalgams: installed they are at `share/x/boot/`, in a checkout they are
built into `build/boot/`. `lib/x-base.x` is not a substitute — it is the source
entry and opens with a root-relative `(include "lib/x-core.x")`.
`tests/gen-harness.sh` probes both.

And two seam-table gaps, both of which this bundle depends on:
`%repl-print` (Kernel's printer) and `%repl-read` (which x-sweet will need)
are live and documented as customizable in `lib/x/repl/loop.x`, but neither is
in the contract's seam table — only their sibling `%repl-prompt` is.

## Licence

MIT No Attribution (MIT-0). See [LICENSE](LICENSE).
