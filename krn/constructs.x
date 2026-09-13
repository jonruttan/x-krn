; constructs.x -- Kernel construct declarations (XEON)
;
; Kernel uses $ prefix for all operative forms.
;
; Pure data -- no code.  The linter and the formatter read it; nothing
; evaluates it.  It says how each of this personality's forms affects
; scope, which is the only way a tool can know that `$define!` binds a
; name: to x it is an ordinary call to an operative krn/base.x defines.
;
; $letrec is scope `letrec`, not `let`: its bindings are visible inside
; their OWN inits, which is the whole reason `reverse` uses it.  Under
; `let` the linter walked each init in the scope before it and reported
; the self-call in rev-helper as undefined.  x-lang v0.14.x has no letrec
; scope type -- tests/lint.sh skips the gate on an x that predates it.

(
  ($vau      (fmt . head-kw) (scope . params-env) (branch . none))
  ($define!  (fmt . head-1)  (scope . bind)       (branch . none))
  ($lambda   (fmt . head-kw) (scope . params)     (branch . none))
  ($if       (fmt . head-1)  (scope . none)       (branch . cond))
  ($let      (fmt . head-1)  (scope . let)        (branch . none))
  ($let*     (fmt . head-1)  (scope . let)        (branch . none))
  ($letrec   (fmt . head-1)  (scope . letrec)     (branch . none))
  ($sequence (fmt . body)    (scope . none)       (branch . none))
  ($when     (fmt . head-1)  (scope . none)       (branch . cond))
  ($unless   (fmt . head-1)  (scope . none)       (branch . cond))
)
