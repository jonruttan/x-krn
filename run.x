; # x-krn -- the Kernel lang for x-lang
;
; ## run.x -- the entry point
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
; This file contains no path literals and no boot code. x.sh boots the dialect
; lang.xon declares, arms this bundle's root with import-path!, cats this file,
; and appends the launcher when no -f was given, so `import krn/base` below
; resolves against the bundle wherever it sits.
(import krn/base)

(set! %lang-name "Kernel")
(set! %lang-version krn-version)
(set! %repl-prompt ">> ")
; Kernel prints Kernel results: (b c), not x's round-trippable ('b 'c).
; See krn/printer.x.
(set! %repl-print %krn-repl-print)
