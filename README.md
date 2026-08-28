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

This is a **lang**, not a dialect — it re-means shared spellings on
purpose, which is exactly what x-lang's
[lang contract](../../x-lang/docs/lang-contract.md) permits and
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

`-l` resolves an acquired bundle as of x-lang 7cfb28ed, so there is no symlink
and no bridge:

```bash
x -l krn                 # interactive
x -l krn -f program.krn  # batch
```

The wrapper boots the dialect `lang.xon` declares, arms this bundle's root, cats
`run.x`, and appends the launcher when no `-f` was given — which is why `run.x`
knows no paths and does not boot the platform itself.

## Layout

```
lang.xon              what this bundle is: name, dialect, release pairing
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
Scheme name, which is what a lang is *for*; it sits with the `cons`/`car`
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

Both were reported and fixed upstream: `%repl-print` and `%repl-read` are in
the seam table and the seam gate as of x-lang b32715b4, and `--share-dir`
answers from any cwd as of 990c4a35, so `tests/spec-runner.sh` no longer has to
cd to the wrapper's directory before asking.

`$define!` no longer depends on an unshipped primitive. It was written against
`(prim-ref 'base 'def-global)`, proposed on
[x-lang#527](https://github.com/jonruttan/x-lang/issues/527) and never shipped —
engine v0.1.2 answers `()` for it, so every definition called nil, bound
nothing, and 59 of 72 specs failed on unbound symbols.

It uses **`eval!`** instead, which evaluates with no env save/restore, so the
binding persists whatever the frame depth. #527 reports there is "only one way"
to write a lang's `define` and that both `eval` and `tail-eval` break under one
extra frame; `eval!` is a second way and it does not. **72 of 72 specs pass.**

## Licence

MIT No Attribution (MIT-0). See [LICENSE](LICENSE).
