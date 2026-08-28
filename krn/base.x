; # x-krn -- the Kernel personality for x-lang
;
; ## krn/base.x -- the language
;
; @description Kernel built on x-lang.  Operatives are first-class;
;   applicatives derive via wrap.  Same s-expression syntax, the opposite
;   evaluation model from Scheme.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
;     ., .,
;     {O,O}
;     (   )
;      " "
;
; No path literals and no dialect boot here: run.x owns both.  This file
; loads on helium -- nothing below reaches past x-core.

(import krn/printer)
(provide krn/base krn-version $vau $define! $lambda $let $letrec)

(def krn-version "0.1.0")

(do
  ; --- Core operative forms ---

  ; $vau is the fundamental abstraction (= op)

  (def $vau op)
  ; --- Aliases ---

  (def cons pair)
  (def car first)
  (def cdr rest)
  (def quote lit)
  (def $cond match)
  ; string? was a bare global in 2024; the platform's spelling is str?
  ; (x/type/str).  Kernel keeps the Scheme name, which is the whole point of
  ; a personality -- see the aliases above it, which do the same for cons/car.

  (def string? str?)
  ; --- $define! ---

  ; TOP LEVEL.  This used to put its eval in TAIL position on purpose: x's
  ; `def` decides global-versus-local by save-stack depth, and TCO has popped
  ; this op's frame by the time a tail eval runs, so the binding landed
  ; globally.  It worked, and one extra wrapper frame anywhere up the call
  ; chain made every definition vanish silently.
  ;
  ; eval! IS THE ANSWER, and it was there all along.  It evaluates with no env
  ; save/restore, so a `def` inside it persists in the caller's world whatever
  ; the frame depth -- no tail-position accident, no TCO dependency.  x-lang#527
  ; reports there is "only one way" to write this and that plain eval/tail-eval
  ; both break; eval! is a second way and it does not.
  ;
  ; This file used to call (prim-ref (lit base) (lit def-global)), a primitive
  ; proposed on that issue and never shipped: engine v0.1.2 answers () for it,
  ; so every $define! called nil, bound nothing, and 59 of 72 specs failed on
  ; unbound symbols with no diagnostic pointing anywhere near here.
  ;
  ; BODY POSITION is a different problem and is NOT solved by it: an internal
  ; definition should bind LOCALLY, so it still goes through the
  ; construction-time rewrite in %krn-body-defs below.

  (def %krn-def-global
    (fn (_ n v) (eval! (list (lit def) n v))))
  (def $define!
    (op (name-or-form . body)
      e
      (if (pair? name-or-form)
        (%krn-def-global
          (first name-or-form)
          (eval (pair (lit $lambda) (pair (rest name-or-form) body)) e))
        (%krn-def-global name-or-form (eval (first body) e)))))
  ; --- Core aliases ---

  (def $if if)
  (def $let let)
  (def $sequence do)
  ; --- Boolean constants ---

  (def #ignore ())
  (def #inert ())
  ; --- Internal definitions ---

  ; ($define! (f x) ($define! y (+ x 1)) (* x y)) must give (f 3) => 12.
  ;
  ; It cannot work by evaluating the inner $define! at run time.  $define! is
  ; an operative, so its `def` runs inside $define!'s OWN frame; in body
  ; position that frame is not in tail position, so the binding is created and
  ; then discarded with the frame.  The name is unbound everywhere afterwards
  ; -- not shadowed, not global, gone.  Passing `e` to eval does not help:
  ; `def` under an explicit-env eval binds somewhere the caller cannot see.
  ;
  ; So the rewrite happens at CONSTRUCTION time instead, which is also how
  ; Schemes handle internal defines (the letrec* conversion): a $define! in
  ; body position becomes a literal `def`, which x binds in the body's own
  ; frame, visible to the forms after it.  Verified: a bare `def` between two
  ; body forms is seen by the second.
  ;
  ; One level deep, deliberately -- exactly the forms that ARE the body.  A
  ; $define! nested inside an $if inside a body is not a definition context in
  ; Kernel either.

  (def %krn-def-form
    (fn (_ form)
      (if (pair? form)
        (if (eq? (first form) (lit $define!))
          (if (pair? (first (rest form)))
            (list
              (lit def)
              (first (first (rest form)))
              (pair
                (lit $lambda)
                (pair (rest (first (rest form))) (rest (rest form)))))
            (list (lit def) (first (rest form)) (first (rest (rest form)))))
          form)
        form)))
  ; Written with x's own fn/recursion: krn's `map` is defined further down
  ; this file, and $lambda has to work before it exists.

  (def %krn-body-defs
    (fn (self body)
      (if (null? body)
        ()
        (pair (%krn-def-form (first body)) (self (rest body))))))
  ; --- $lambda: create applicative from operative ---

  ($define!
    $lambda
    (op (formals . body)
      e
      (wrap
        (eval
          (pair
            (lit $vau)
            (pair formals (pair (lit #ignore) (%krn-body-defs body))))
          e))))
  ; --- Applicative wrappers for arithmetic ---

  ; In Kernel, standard combiners are applicatives (args evaluated).

  ; x-lang primitives are already fexprs that eval their args,

  ; so we just alias them directly.

  ; --- Derived operative forms ---

  ($define!
    $when
    (op (test . body)
      e
      ($if (eval test e) (eval (pair (lit $sequence) body)))))
  ($define!
    $unless
    (op (test . body)
      e
      ($if
        (not (eval test e))
        (eval (pair (lit $sequence) body)))))
  ; --- $let* ---

  ($define!
    $let*
    (op (bindings . body)
      e
      ($if
        (null? bindings)
        (eval (pair (lit $sequence) body) e)
        (eval
          (list
            (lit $let)
            (list (first bindings))
            (pair (lit $let*) (pair (rest bindings) body)))
          e))))
  ; --- Kernel-style predicates ---

  ($define!
    operative?
    ($lambda
      (x)
      (and
        (not (null? x))
        (not (procedure? x))
        (not (number? x))
        (not (string? x))
        (not (symbol? x))
        (not (pair? x)))))
  ($define! applicative? ($lambda (x) (procedure? x)))
  ($define! boolean? ($lambda (x) (or (eq? x #t) (eq? x #f))))
  ($define! inert? ($lambda (x) (null? x)))
  ; --- List operations (as applicatives via $lambda) ---

  ; These are Kernel's own, not thin covers over the platform's: map, length,
  ; append, filter and reverse are no longer bare globals in ANY x-lang
  ; dialect (they live on the List class), so there is nothing to alias even
  ; if we wanted to.  Defining them here is the honest arrangement anyway --
  ; a personality that borrowed the platform's list vocabulary would be
  ; borrowing its argument conventions with it.

  ($define!
    (length lst)
    ($if (null? lst) 0 (+ 1 (length (rest lst)))))
  ($define!
    (append a b)
    ($if (null? a) b (pair (first a) (append (rest a) b))))
  ($define!
    (reverse lst)
    ($define!
      rev-helper
      ($lambda
        (l acc)
        ($if
          (null? l)
          acc
          (rev-helper (rest l) (pair (first l) acc)))))
    (rev-helper lst ()))
  ($define!
    (list-ref lst n)
    ($if (= n 0) (first lst) (list-ref (rest lst) (- n 1))))
  ($define!
    (map f lst)
    ($if
      (null? lst)
      ()
      (pair (f (first lst)) (map f (rest lst)))))
  ($define!
    (filter pred lst)
    ($if
      (null? lst)
      ()
      ($if
        (pred (first lst))
        (pair (first lst) (filter pred (rest lst)))
        (filter pred (rest lst)))))
  ($define!
    (for-each f lst)
    ($if
      (null? lst)
      ()
      ($sequence (f (first lst)) (for-each f (rest lst)))))
  ; --- Composition accessors ---

  ($define! (caar x) (first (first x)))
  ($define! (cadr x) (first (rest x)))
  ($define! (cdar x) (rest (first x)))
  ($define! (cddr x) (rest (rest x)))
  ($define! (caddr x) (first (rest (rest x))))
  ; --- Number operations ---

  ($define! (zero? n) (= n 0))
  ($define! (positive? n) (> n 0))
  ($define! (negative? n) (< n 0))
  ($define! (even? n) (= (% n 2) 0))
  ($define! (odd? n) (not (= (% n 2) 0)))
  ($define! (abs n) ($if (< n 0) (- 0 n) n))
  ($define! (min a b) ($if (< a b) a b))
  ($define! (max a b) ($if (> a b) a b))
  ; --- Member / Assoc ---

  ($define!
    (member x lst)
    ($if
      (null? lst)
      #f
      ($if (eq? x (first lst)) lst (member x (rest lst)))))
  ($define!
    (assoc key alist)
    ($if
      (null? alist)
      #f
      ($if
        (eq? key (caar alist))
        (first alist)
        (assoc key (rest alist)))))
  ; --- $letrec ---

  ; Mutual recursion within $let bindings.

  ; Expands to: ($let ((v1 ()) ...) (set! v1 e1) ... body...)

  ; NOTE: Param names use lr- prefix to avoid dynamic scoping collisions

  ; with $lambda's internal params (body, e, formals).

  ($define!
    $letrec
    (op (lr-binds . lr-body)
      lr-e
      (eval
        (pair
          (lit $let)
          (pair
            (map ($lambda (b) (list (first b) ())) lr-binds)
            (append
              (map
                ($lambda (b) (list (lit set!) (first b) (cadr b)))
                lr-binds)
              lr-body)))
        lr-e)))
  ; --- get-current-environment ---

  ; Returns the caller's environment as a first-class value.

  ($define! get-current-environment (op () e e))
  ; --- make-environment ---

  ; Creates a fresh empty environment (an empty alist).

  ($define! (make-environment) ()))
