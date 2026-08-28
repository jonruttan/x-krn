; krn/printer.x -- Kernel's own result writer.
;
; WHY A PERSONALITY OWNS ITS PRINTER.  x-lang's `write` is round-trippable:
; a symbol renders with the quote its reader needs to give it back, so
; (list 'b 'c) writes as ('b 'c).  That is right for x and documented in
; docs/spec.md ("(my-quote (+ 1 2)) -> ('+ 1 2)").
;
; It is not right for Kernel.  In the Kernel/Scheme family `write` renders
; symbols bare and strings quoted -- (b c) and "hello" -- and a personality
; is the arbiter of what its own surface prints.  That is exactly the
; freedom docs/personality-contract.md grants: "a personality may re-mean a
; shared spelling -- that is the point."
;
; So this is a re-meaning, not a workaround.  Nothing about the platform is
; being patched around; Kernel is answering a question that is its own.
;
; The seam this rides on is %repl-print, which loop.x documents as
; customizable and which run.x installs.  Note for upstream: %repl-print and
; %repl-prompt are siblings, but only %repl-prompt is in the contract's seam
; table.  A personality that prints its own results is not an exotic case --
; it is the second thing every one of these five does.

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
      ; personality whose printer cannot render (a . b) cannot show a pair,
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
