; mu-kanren

(define (print x)
  (format #t "~A\n" x))

;;

; the empty state: no substitutions and no variables created yet
;
; a pair of such values is often abreviated s/c (substitutions and counter)
(define empty-state '(() . 0))

; (car empty-state) => ()
; (cdr empty-state) => 0
; mind you, caaaar and cadadr exist as well
; (= (cadadr l) (car (cdr (car (cdr l)))))

;;

; creates a new *logic* variable
(define (var x) (vector x))
(define (var? x) (vector? x))
(define (var=? x1 x2) (= (vector-ref x1 0) (vector-ref x2 0)))

; (var? (var 0)) => #t
; (var? (vector 0)) => #t   ; ! (this won't happen here, but it can in general)
; (var? 0) => #f

;;

; walk looks up the value of variable u in the substitution s
(define (walk u s) ; u - variable or value to look up
                   ; s - substitution (association list of variables to values or other variables)
  (let ((pr (and (var? u) (assp (lambda (v) (var=? u v)) s))))
    (format #t "; (walk ~A s) => ~A\n" u pr)
    (if pr
        (walk (cdr pr) s)
        u)))

; (and #t #t) => #t
; (and 3 4) => 4          ; !
; (and #t #t #f) => #f
; (and #f 3 4) => #f

; (define al '((1 7) (1 2) (2 3) (3 4) (5 6)))
; (assp (lambda (key) (= key  3) al) => (3 4)
; (assp (...                  1) al) => (1 7) ; !
; (assp (...                  5) a1) => (5 6)
; (assp (...                 42) a1) => #f

; (define s1 `((,(var 0) . 5) (,(var 1) . 6) (,(var 2) . ,(var 1))))
; (walk (var 0) s1) => 5          ; value for variable 0
; (walk (var 1) s1) => 6          ;         ...        1
; (walk (var 2) s1) => 6          ; variable 2 references variable 1     ; !
; (walk (var 42) s1) => #(42)     ; variable 42 does not exist
; (walk 7 s1) => 7
; be careful ...:
; (walk (var 0) `((,(var 0) . ,(var 3)) (,(var 3) . ,(var 0))))

; extending the substitution s with a new binding: variable x has the value v
(define (ext-s x v s)
  `((,x . ,v) . ,s))

;;

; constructs a new goal: u and v must be equal (e.g. it must be possible to unify them)
(define (=== u v)
  (lambda (s/c) ; lambda_g - goal constructor
    (let ((s (unify u v (car s/c)))) ; unifies u and v, returning a substitution, or false
      (print s)
      (if s
          (unit `(,s . ,(cdr s/c))) ; 1-element list with state in it
          mzero))))

(define (unit s/c) (cons s/c mzero))
(define mzero '())

; (unit s1) => (s1)

;;

; unifies u and v and returns a new substitution, or false if they can't be unified
(define (unify uv vv s)
  (let ((u (walk uv s))   ; lookup the value of u
        (v (walk vv s)))  ;         ...         v
    (format #t "; (unify ~A = ~A with ~A = ~A)\n" uv u vv v)
    (cond
     ((and (var? u) (var? v) (var=? u v)) s) ; are already unified?
     ((var? u) (ext-s u v s))                ; u "unifies with" v, (var? v) and v != u or v is anything
     ((var? v) (ext-s v u s))                ; v        ...     u
     ((and (pair? u) (pair? v))              ; unify all elements of list u with all elements of list v (pairwise)
      (let ((s (unify (car u) (car v) s)))
        (and s (unify (cdr u) (cdr v) s))))
     (else (and (eqv? u v) s)))))            ; compare values of u and v

; pair? = has a head and a tail: (1 . 2) (1 2 3)

; (unify (var 0) (var 0) '()) => ()
; (unify (var 0) 5 '()) => ((#(0) . 5))
; (unify 5 (var 0) '()) => ((#(0) . 5))
; (unify (var 0) (var 1) '()) => ((#(0) . #(1)))
; ...
; (unify 3 3 '()) => ()
; (unify 3 3 `((,(var 0) . 5))) => ((#(0) . 5))
; (unify 3 4 '()) => #f

; ...

(define (call/fresh f)
  (lambda (s/c)          ; "state with counter"
    (let ((c (cdr s/c))) ; variable counter
      ((f (var c)) `(,(car s/c) . ,(+ c 1))))))

; (car '(1 2 3)) => 1
; (cdr '(1 2 3)) => (2 3)

; (car '(1 . 2) => 1
; (cdr '(1 . 2) => 2
; (cdr '(1 2)) => (2) ; !

; ((call/fresh (lambda (a)
;                (call/fresh (lambda (b)
;                              (=== `(,a 2 3) `(1 ,b 3))))))
;  empty-state)

; disj and conj are *goal combinators*

(define (disj g1 g2)
  (lambda (s/c)
    (mplus (g1 s/c) (g2 s/c))))

(define (conj g1 g2)
  (lambda (s/c)
    (bind (g1 s/c) g2)))

;; finite depth-first search

; concatenates the states in $1 and $2
(define (mplus $1 $2)
  (cond
   ((null? $1) $2)
   (else (cons (car $1) ; first state of $1
               (mplus (cdr $1) $2)))))

(define (bind $ g)
  (cond
   ((null? $) mzero)
   (else (mplus
          (g (car $)) ; is g consistent with (car $)
          (bind (cdr $) g)))))

; example

; ((call/fresh (lambda (a)
;                 (disj (=== a 1)
;                       (=== a 2))))
;  empty-state)

; ((call/fresh (lambda (a)
;                 (conj (=== a 1)
;                       (=== a 2))))
;  empty-state)

; ((call/fresh (lambda (a)
;                (call/fresh (lambda (b)
;                              (disj (conj (=== a 1) (=== b 2))
;                                    (conj (=== a 2) (=== b 1)))))))
;  empty-state)
