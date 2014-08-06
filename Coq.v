Require Export Functors.

(* Maybe indicates optional values. *)

Section Maybe.

Inductive Maybe {A : Type} : Type :=
  | Nothing : @Maybe A
  | Just    : A -> @Maybe A.

Program Instance Maybe_Functor : Coq ⟶ Coq :=
{ fmap := fun _ _ f x => match x with
   | Nothing => Nothing
   | Just x' => Just (f x')
  end
}.
Obligation 1. simple_solver. Defined.
Obligation 2. simple_solver. Defined.

End Maybe. (* jww (2014-08-06): Hiding instance for now *)

(* Either is the canonical coproduct type in Coq. *)

Inductive Either {E X : Type} :=
  | Left  : E → @Either E X
  | Right : X → @Either E X.

Program Instance Either_Bifunctor : Coq ⟶ Coq ⟹ Coq :=
{ fobj := fun Z =>
  {| fobj := @Either Z
   ; fmap := fun _ _ f e => match e with
      | Left x  => Left x
      | Right x => Right (f x)
      end
   |}
; fmap := fun _ _ f =>
  {| transport := fun _ e => match e with
      | Left x  => Left (f x)
      | Right x => Right x
      end
   |}
}.
Obligation 1. extensionality e. crush. Defined.
Obligation 2. extensionality e. crush. Defined.
Obligation 3. extensionality e. crush. Defined.
Obligation 4.
  apply nat_irrelevance.
  extensionality e.
  extensionality f. crush.
Defined.
Obligation 5.
  apply nat_irrelevance.
  extensionality e.
  eapply functional_extensionality. crush.
Defined.

Example either_fmap_ex1 :
  ∀ n, fmap S nat (Left n)  = Left (S n)
     ∧ fmap S nat (Right n) = @Right nat nat n.
Proof. split; reflexivity. Qed.

Example either_fmap1_ex1 :
  ∀ n, fmap1 S (Left n) = Left n
     ∧ fmap1 S (Right n) = @Right nat nat (S n).
Proof. split; reflexivity. Qed.

Example either_bimap_ex1 :
  ∀ n, bimap S pred (Left n) = Left (S n).
Proof. reflexivity. Qed.

Example either_bimap_ex2 :
  ∀ n, bimap S pred (Right n) = Right (pred n).
Proof. reflexivity. Qed.