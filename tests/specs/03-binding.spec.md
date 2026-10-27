## $let

### binds locally

```scheme
($let ((x 10)) x)
```
---
    10

### multiple bindings

```scheme
($let ((x 1) (y 2)) (+ x y))
```
---
    3

## $let*

### sequential binding

```scheme
($let* ((x 1) (y (+ x 1))) (+ x y))
```
---
    3

### nested reference

```scheme
($let* ((a 2) (b (* a 3)) (c (+ a b))) c)
```
---
    8

### three-level chain

```scheme
($let* ((x 1) (y (+ x 1)) (z (+ y 1))) z)
```
---
    3


## $define! from a nested frame

### binds the top-level name from inside an operative frame

```scheme
($define! %krn-dg-set ($vau () e ($define! %krn-dg-probe 7))) (%krn-dg-set) %krn-dg-probe
```
---
    7

### and through a frame interposed above it

```scheme
($define! %krn-dg-inner ($vau () e ($define! %krn-dg-deep 9))) ($define! %krn-dg-outer ($vau () e (%krn-dg-inner))) (%krn-dg-outer) %krn-dg-deep
```
---
    9

### a redefinition at depth updates the top-level cell in place

```scheme
($define! %krn-dg-twice 1) ($define! %krn-dg-again ($vau () e ($define! %krn-dg-twice 2))) (%krn-dg-again) %krn-dg-twice
```
---
    2
