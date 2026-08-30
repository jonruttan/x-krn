# x-krn — Kernel on x-lang

A [Kernel](https://web.cs.wpi.edu/~jshutt/kernel.html) surface language riding
on [x-lang](https://github.com/jonruttan/x-lang). Operatives (`$vau`) are
first-class; applicatives derive from them via `wrap`. Same s-expressions as
Scheme, the opposite evaluation model.

```
$ x -l krn
Kernel 0.1.0
>> ($define! (sq x) (* x x))
>> (sq 9)
81
>> (member 'b '(a b c))
(b c)
```

x-krn is a **lang**: a different surface language loaded over an x-lang
dialect, free to re-mean shared spellings. `(b c)` above is Kernel's own
printer, not x-lang's `('b 'c)`. The terms are in x-lang's
[lang contract](https://github.com/jonruttan/x-lang/blob/main/docs/lang-contract.md).

## Status

**Early.** 74 specs, all green against x-lang **v0.8.1** — the first release
carrying bundle acquisition, `-l` loading and `--share-dir`. CI runs the
declared release and `main`, so a platform that moves underneath this bundle
shows up as a red build rather than a surprise years later.

## Install

Nothing cloned, from any directory:

```bash
x --install-lang https://github.com/jonruttan/x-krn/releases/latest/download/lang.pin.xon
x -l krn
```

x fetches the published pin, then the tarball it names, verifies the digest,
and installs to `<share>/langs/krn` — where `x -l` looks. A failed upgrade
leaves the working install untouched.

From a clone, if you have one:

```bash
make install                      # into the x on your PATH
PREFIX=$HOME/.local make install  # or a particular prefix
```

`make uninstall` removes it either way.

## Pin it instead, for a project

An install is unversioned and machine-wide. When it matters *which* version a
project builds against, pin it: `Pin bundle` fetches the release tarball and
verifies it against a digest before unpacking. In the project's
`lang.pin.xon`:

```x
(lang "krn")
(release "v0.1.0")
(bundle "sha256:…" "https://github.com/jonruttan/x-krn/releases/download/v0.1.0/x-krn-v0.1.0.tar.gz")
(source "https://github.com/jonruttan/x-krn.git")
```

Each release publishes its own digest, and the release notes carry this block
ready to paste. Then:

```x-repl
> (import x/tool/pin)
> (Pin bundle "deps/langs")
"deps/langs/krn-v0.1.0"
```

`deps/langs/` is where `x -l` looks in a checkout, beside the engine and
anything else fetched rather than built. `X_LANG_DIR` overrides it.

**Which to use.** Install when you just want `x -l krn` to work. Pin when a
build depends on it — the digest is what makes the version reproducible, and
an install has none.

## Running it

```bash
x -l krn                 # interactive
x -l krn -f program.krn  # batch
```

x-lang boots the dialect `lang.xon` declares, arms this bundle's module root,
and loads `run.x` on top — which is why nothing here needs to know a path.

## The language

Kernel's core, on helium:

| | |
|---|---|
| operatives | `$vau`, `$define!`, `$lambda`, `$let`, `$letrec`, `$if`, `$cond`, `$sequence` |
| environments | `get-current-environment`, `make-environment` |
| predicates | `applicative?`, `operative?`, `boolean?`, `inert?`, `null?`, `pair?`, `symbol?` |
| lists | `cons`/`car`/`cdr`, `list`, `append`, `map`, `member`, `length`, `reverse` |

`$define!` binds in its caller's environment; internal definitions in a
`$lambda` body bind locally, rewritten at construction time.

## Layout

```
lang.xon               what this bundle is: name, dialect, release pairing
run.x                  the entry
krn/base.x             the language
krn/printer.x          Kernel's own result writer
krn/constructs.x       construct declarations (formatter metadata)
tests/spec-runner.sh   sources the platform's shared runner
tests/gen-harness.sh   writes tests/lib/harness.gen.x (generated, never committed)
tests/specs/*.spec.md  the suite
tools/bundle.sh        rolls a release tarball and prints its pin
Makefile               install / uninstall / test / bundle
```

No file here carries a path literal, `run.x` included — the bundle relocates,
and CI enforces it.

## Development

Run the specs against any x-lang checkout or install:

```bash
X=/path/to/x-lang/x.sh sh tests/spec-runner.sh
```

Roll a release tarball locally, with the digest a consumer would pin:

```bash
sh tools/bundle.sh v0.1.0
```

The tarball is byte-reproducible: it is built from the tag with `git archive`
and a timestamp-free gzip, so two people rolling one tag get one digest.

Pushing a `v*` tag runs the suite and, only if it is green, publishes the
tarball and its `.sha256` as a GitHub release.

## Licence

MIT No Attribution (MIT-0). See [LICENSE](LICENSE).
