; # x-krn -- the Kernel lang for x-lang
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
  ; Kernel keeps the Scheme name `string?`; the platform's spelling is str?,
  ; the same re-naming as the cons/car aliases above.

  (def string? str?)
  ; --- $define! ---

  ; $define! binds in its caller's environment. A definition in body position
  ; binds locally instead, through the construction-time rewrite in
  ; %krn-body-defs below rather than by evaluating an inner $define! at run
  ; time.

  ; Top-level binding uses (base def-global), which takes def's global path
  ; unconditionally and is frame-independent; where the engine lacks it
  ; (prim-ref answers ()), the fallback is eval! of (def name (lit value)). The
  ; (lit ...) wrap matters: eval! evaluates the def form it is handed, which
  ; would evaluate the value a second time -- invisible for self-evaluating
  ; values, but a symbol value would be looked up. See x-lang#527.
  (def %dg-prim (prim-ref (lit base) (lit def-global)))
  (def %krn-def-global
    (if (null? %dg-prim)
      (fn (_ n v) (eval! (list (lit def) n (list (lit lit) v))))
      (fn (_ n v) (%dg-prim n v))))
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

  ; ($define! (f x) ($define! y (+ x 1)) (* x y)) gives (f 3) => 12. An
  ; internal $define! cannot bind by evaluating at run time -- $define! is an
  ; operative, so its `def` runs in $define!'s own frame and the binding is
  ; discarded with it. So a $define! in body position is rewritten at
  ; construction time into a literal `def`, which x binds in the body's own
  ; frame, visible to the forms after it -- the letrec* conversion Schemes use.
  ; One level deep: a $define! nested inside an $if is not a definition context
  ; in Kernel either.

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
  ; a lang that borrowed the platform's list vocabulary would be
  ; borrowing its argument conventions with it.

  ($define!
    (length lst)
    ($if (null? lst) 0 (+ 1 (length (rest lst)))))
  ($define!
    (append a b)
    ($if (null? a) b (pair (first a) (append (rest a) b))))
  ; $letrec, not an inner $define!: the helper is recursive and must see
  ; itself, which a body-local binding does not provide.
  ($define!
    (reverse lst)
    ($letrec
      ((rev-helper
         ($lambda
           (l acc)
           ($if
             (null? l)
             acc
             (rev-helper (rest l) (pair (first l) acc))))))
      (rev-helper lst ())))
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
