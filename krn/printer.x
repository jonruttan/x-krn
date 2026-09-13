; krn/printer.x -- Kernel's own result writer.
;
; x's `write` is round-trippable: a symbol renders with the quote its reader
; needs to give it back, so (list 'b 'c) writes as ('b 'c). Kernel's `write`
; renders symbols bare and strings quoted -- (b c) and "hello" -- so this
; rebinds it, installed on %repl-print, which run.x sets.

(provide krn/printer krn-write %krn-repl-print)

; Recursive descent, because only the SYMBOL leaf differs from `write`.
; Everything else -- strings, ints, chars, booleans, procedures -- delegates,
; so Kernel inherits the platform's rendering for free and stays correct as
; new types arrive.
(def krn-write ())
(def %krn-write-items
  (fn (_ v)
    (do
      (krn-write (first v))
      ; Proper tail -> keep going; improper -> the dotted spelling.  A
      ; lang whose printer cannot render (a . b) cannot show a pair,
      ; and pairs are the whole substrate here.
      (if (null? (rest v))
        ()
        (if (pair? (rest v))
          (do (display " ") (%krn-write-items (rest v)))
          (do (display " . ") (krn-write (rest v))))))))
(set! krn-write
  (fn (_ v)
    (if (pair? v)
      (do (display "(") (%krn-write-items v) (display ")"))
      (if (symbol? v)
        (display v)
        (write v)))))

; The %repl-print shape: nil is the "no value" result and prints nothing but
; the newline, matching lib/x/repl/loop.x.  Kernel's #inert IS nil, so this
; is also the right answer for ($define! x 1) at the prompt.
(def %krn-repl-print
  (fn (_ result)
    (unless (null? result) (krn-write result))
    (newline)))
