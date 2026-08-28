; # x-krn -- the Kernel personality for x-lang
;
; ## run.x -- THE entry, and the only file here that may know a path
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
; Usage today (until `-l` grows a personality-root step, see README):
;   x.sh -F path/to/x-krn/run.x     interactive
;   x.sh -f path/to/x-krn/run.x     batch, program on stdin
;
; THE ONE FILE WITH LAYOUT KNOWLEDGE.  Every other file in this bundle
; resolves its siblings by `import`, so the bundle relocates.  That rule is
; the whole reason the last generation of personalities died -- see
; x-lang docs/personality-contract.md, "Why the last generation rotted".
(include "lib/x-core.x")

; --- Where this bundle lives ------------------------------------------------
; THE ENTRY CANNOT ASK.  x.sh CATS the entry into the engine's stdin rather
; than including it, so inside this file %include-curdir is "." and
; %install-root is unbound in a checkout.  An entry has no way to learn its
; own path -- which is why Logo's names its root with a literal and why the
; contract exempts entries from the path-literal lint.  Logo can get away
; with one literal because Logo lives INSIDE the platform tree; a bundle,
; by definition, does not.  That gap is the "searched personality root,
; extended by one step" the contract still lists as proposed.
;
; So: probe, and say so when nothing answers.  Every candidate below is a
; place a bundle actually sits today; the list shrinks to one line the day
; -l learns a personality root.
(def %krn-candidates
  (list
    ; installed tree, or a checkout with apps/krn symlinked at the bundle
    (guard (_ "apps/krn") (%path-join %install-root "apps/krn"))
    ; checkout, cwd at the repo root -- what `x.sh -l krn` gives today
    "apps/krn"
    ; the entry was INCLUDED rather than piped (a harness, or `include`)
    (guard (_ ".") (%include-curdir))))
(def %krn-find-root
  (fn (self roots)
    (if (null? roots)
      ()
      (if (Sys file-exists? (%path-join (first roots) "krn/base.x"))
        (first roots)
        (self (rest roots))))))
(def %krn-bundle-root (%krn-find-root %krn-candidates))
(if (null? %krn-bundle-root)
  (do
    ; Legible, not a bare "include: cannot open".  A refusal that names what
    ; it looked for is the difference between a five-minute fix and the
    ; afternoon the last generation of these cost.
    (display "x-krn: cannot find the bundle root -- no krn/base.x under:")
    (newline)
    (def %krn-say
      (fn (self roots)
        (if (null? roots)
          ()
          (do
            (display "  ")
            (display (%path-join (first roots) "krn/base.x"))
            (newline)
            (self (rest roots))))))
    (%krn-say %krn-candidates)
    (display "Run from the x-lang repo root with apps/krn pointing here, or")
    (newline)
    (display "install the bundle under <install-root>/apps/krn.")
    (newline)
    (Sys exit 1))
  ())
(import-path! %krn-bundle-root)

(import krn/base)

(set! %repl-prompt ">> ")
(set! %lang-name "Kernel")
(set! %lang-version krn-version)
; Kernel prints Kernel results: (b c), not x's round-trippable ('b 'c).
; See krn/printer.x for why that is a re-meaning rather than a workaround.
(set! %repl-print %krn-repl-print)

; Batch (-f) means stdin holds a Kernel program, not a session: the REPL's
; fd swap would discard it unread.  %batch? comes from x-core via banner.x.
(unless %batch? (do (%banner) (repl)))
