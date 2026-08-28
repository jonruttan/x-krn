; # x-krn -- the Kernel lang for x-lang
;
; ## run.x -- THE entry
;
; @description Kernel: operatives are first-class, applicatives derive via
;   wrap.  Same s-expressions as Scheme, the opposite evaluation model.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
;     ., .,
;     {O,O}
;     (   )
;      " "
;
; Usage:
;   x -l krn                interactive
;   x -l krn -f prog.krn    batch
;
; THIS FILE KNOWS NO PATHS, and that is the whole point of the arrangement.
; x.sh boots the dialect lang.xon declares, arms this bundle's root with
; import-path!, cats this file, and appends the launcher when no -f was
; given.  So by the time anything below runs, the platform is up and
; `import krn/base` resolves against the bundle wherever it happens to sit.
;
; It used to do all of that itself: include "lib/x-core.x" to self-boot, probe
; a list of candidate directories to guess its own location, and end with its
; own %batch?-guarded launcher.  Sixty lines, every one of them a workaround
; for `-l` not knowing about bundles.  It does now.
(import krn/base)

(set! %lang-name "Kernel")
(set! %lang-version krn-version)
(set! %repl-prompt ">> ")
; Kernel prints Kernel results: (b c), not x's round-trippable ('b 'c).
; See krn/printer.x for why that is a re-meaning rather than a workaround.
(set! %repl-print %krn-repl-print)
