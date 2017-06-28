Set Warnings "-notation-overridden".

Require Import Category.Lib.
Require Import Category.Theory.Functor.

Require Import Coq.FSets.FMaps.
Require Import Category.Lib.FMapExt.
Require Import Coq.Vectors.Vector.

Lemma comparison_eq_dec : ∀ x y : comparison, x = y ∨ x ≠ y.
Proof.
  intros.
  destruct x, y; intuition idtac;
  right; intros; discriminate.
Qed.

Module Type NatValue.
  Parameter n : nat.
End NatValue.

Module Fin_as_OT (Import N : NatValue) <: OrderedType.
  Definition t := Fin.t n.

  Definition eq (x y : Fin.t n) : Prop := x = y.
  Definition lt (x y : Fin.t n) : Prop :=
    (` (Fin.to_nat x) < ` (Fin.to_nat y))%nat.

  Lemma eq_refl : ∀ x : t, eq x x.
  Proof. reflexivity. Qed.

  Lemma eq_sym : ∀ x y : t, eq x y → eq y x.
  Proof. symmetry; assumption. Qed.

  Lemma eq_trans : ∀ x y z : t, eq x y → eq y z → eq x z.
  Proof. intros; transitivity y; assumption. Qed.

  Lemma lt_trans : ∀ x y z : t, lt x y → lt y z → lt x z.
  Proof.
    unfold lt; intros.
    transitivity (` (Fin.to_nat y)); assumption.
  Qed.

  Lemma lt_not_eq : ∀ x y : t, lt x y → ¬ eq x y.
  Proof.
    unfold lt, eq, not; intros; subst.
    contradiction (PeanoNat.Nat.lt_irrefl (` (Fin.to_nat y))).
  Qed.

  Definition compare (x y : t) : Compare lt eq x y.
  Proof.
    destruct (Nat_as_OT.compare (` (Fin.to_nat x)) (` (Fin.to_nat y))).
    - apply LT, l.
    - apply Fin.to_nat_inj in e.
      apply (EQ e).
    - apply GT, l.
  Defined.

  Definition eq_dec (x y : t) : eq x y ∨ ¬ eq x y :=
    Fin.eq_dec x y.
End Fin_as_OT.

Generalizable All Variables.
Set Primitive Projections.
Set Universe Polymorphism.
Unset Transparent Obligations.

Module Graph (Import N : NatValue).

Module FO := Fin_as_OT N.
Module PO := PairOrderedType FO FO.

Module M := FMapList.Make(PO).

Module Import FMapExt := FMapExt PO M.
Module P := FMapExt.P.
Module F := P.F.

(* This structure defines a thick, directed meta-graph. It is thick because
   multiple distinct edges are allowed between any two vertices; it is
   directed because the ordering of the edge pairs carries information
   (although an undirected interpretation is possible by ignoring this
   fact). *)

Record Metagraph := {
  objects : nat;                (* "vertices" *)
  object := Fin.t objects;

  arrows : Vector.t (object * object) N.n; (* "edges" *)
  arrow := Fin.t N.n;

  domain   (f : arrow) : object := fst (nth arrows f);
  codomain (f : arrow) : object := snd (nth arrows f)
}.

(* A meta-semigroupoid adds the idea that for any chain of edges, an edge must
   exist from the first vertex to the last. In other words, every chain
   implies a composite edge. *)

Record Metasemigroupoid := {
  is_metagraph :> Metagraph;

  pairs : M.t (arrow is_metagraph);

  composite (f g h : arrow is_metagraph) := M.MapsTo (f, g) h pairs;

  (* ∀ edges (X, Y) and (Y, Z), ∃ an edge (X, Z) which is equal to the
     composition of those edges. *)
  composite_correct : ∀ (f g : arrow is_metagraph),
    domain is_metagraph f = codomain is_metagraph g ->
      ∃ fg, composite f g fg ∧
        domain   is_metagraph fg = domain   is_metagraph g ∧
        codomain is_metagraph fg = codomain is_metagraph f;

  composition_law (k g f kg gf : arrow is_metagraph) :
    composite k g kg ->
    composite g f gf ->
    ∀ kgf, composite kg f kgf ↔ composite k gf kgf
}.

Definition composition (M : Metasemigroupoid) (f g : arrow (is_metagraph M)) :
  domain (is_metagraph M) f = codomain (is_metagraph M) g ->
  arrow (is_metagraph M) := fun H => `1 (composite_correct M f g H).

Lemma composition_correct (M : Metasemigroupoid)
      (f g : arrow (is_metagraph M))
      (H : domain (is_metagraph M) f = codomain (is_metagraph M) g) :
  ∀ fg, fg = composition M f g H ->
    domain   (is_metagraph M) fg = domain   (is_metagraph M) g ∧
    codomain (is_metagraph M) fg = codomain (is_metagraph M) f.
Proof.
  intros.
  unfold composition in H0.
  destruct (composite_correct M f g H).
  simpl in *; subst; intuition.
Qed.

Lemma composition_associative (M : Metasemigroupoid)
      (f g k : arrow (is_metagraph M))
      (Hfg : domain (is_metagraph M) f = codomain (is_metagraph M) g)
      (Hgk : domain (is_metagraph M) g = codomain (is_metagraph M) k)
      (Hf_gk : domain M f = codomain M (composition M g k Hgk))
      (Hfg_k : domain M (composition M f g Hfg) = codomain M k) :
  composition M f (composition M g k Hgk) Hf_gk =
  composition M (composition M f g Hfg) k Hfg_k.
Proof.
  unfold composition in *.
  destruct (composite_correct M g k Hgk).
  destruct (composite_correct M f g Hfg).
  simplify; simpl in *.
  destruct (composite_correct M f x Hf_gk).
  destruct (composite_correct M x0 k Hfg_k).
  simplify; simpl in *.
  spose (fst (composition_law M _ _ _ _ _ p0 p x2) p2) as X.
  apply (FMapExt.F.MapsTo_fun p1 X).
Qed.

(* A meta-category adds the notion of identity arrows over the concept of a
   meta-semigroupoid. *)

Record Metacategory := {
  is_metasemigroupoid :> Metasemigroupoid;

  identity (x : object is_metasemigroupoid) : arrow is_metasemigroupoid;

  identity_correct : ∀ x f,
    f = identity x ->
    domain   is_metasemigroupoid f = x ∧
    codomain is_metasemigroupoid f = x;

  identity_left_law : ∀ f u,
    u = identity (codomain is_metasemigroupoid f) ->
    composite is_metasemigroupoid u f f;

  identity_right_law : ∀ f u,
    u = identity (domain is_metasemigroupoid f) ->
    composite is_metasemigroupoid f u f
}.

Lemma identity_left (M : Metacategory) : ∀ f u,
  u = identity M (codomain M f) ->
  ∀ (H : domain M u = codomain M f),
  composition M u f H = f.
Proof.
  unfold composition; intros.
  pose proof (identity_left_law M f u H).
  unfold composite in H1.
  destruct (composite_correct M u f H0); simpl.
  simplify.
  eapply F.MapsTo_fun; eauto.
Qed.

Lemma identity_right (M : Metacategory) : ∀ f u,
  u = identity M (domain M f) ->
  ∀ (H : domain M f = codomain M u),
  composition M f u H = f.
Proof.
  unfold composition; intros.
  pose proof (identity_right_law M f u H).
  unfold composite in H1.
  destruct (composite_correct M f u H0); simpl.
  simplify.
  eapply F.MapsTo_fun; eauto.
Qed.

(* Every meta-category, defined wholly in terms of the axioms of category
   theory, gives rise to a category interpreted in the context of set
   theory. *)

Global Program Definition Category_from_Metacategory (M : Metacategory) :
  Category := {|
  obj     := object M;
  hom     := fun x y => ∃ f : arrow M, domain M f = x ∧ codomain M f = y;
  homset  := fun x y => {| Setoid.equiv := fun f g => `1 f = `1 g |};
  id      := fun x =>
    let f := identity M x in (f; identity_correct M x f eq_refl);
  compose := fun _ _ _ f g =>
    let fg := composition M (`1 f) (`1 g) eq_refl in
    (fg; composition_correct M (`1 f) (`1 g) eq_refl fg eq_refl)
|}.
Next Obligation. equivalence; simpl in *; subst; reflexivity. Qed.
Next Obligation.
  proper; simpl in *; subst; auto.
  simpl.
  apply f_equal.
  apply Eqdep_dec.UIP_dec.
  apply Fin.eq_dec.
Qed.
Next Obligation. apply identity_left; reflexivity. Qed.
Next Obligation. apply identity_right; reflexivity. Qed.
Next Obligation. apply composition_associative. Qed.
Next Obligation. symmetry; apply composition_associative. Qed.

End Graph.

Module Two.

Module NatThree <: NatValue.
  Monomorphic Definition n := 3%nat.
End NatThree.

(* A graph with three arrows. *)
Module Import G3 := Graph NatThree.

Import VectorNotations.
Import Fin.

Program Definition TwoG : Metagraph := {|
  objects := 2;
  arrows  := [(F1, F1); (FS F1, FS F1); (F1, FS F1)]
|}.

Notation "[map ]" := (M.empty _) (at level 9, only parsing).
Notation "x +=> y" := (M.add x y) (at level 9, y at level 100, only parsing).
Notation "[map  a ; .. ; b ]" := (a .. (b [map]) ..) (only parsing).

Ltac cleanup :=
  G3.FMapExt.simplify_maps;
  repeat (right; intuition; try discriminate; G3.FMapExt.simplify_maps).

Program Definition TwoMS : Metasemigroupoid := {|
  is_metagraph := TwoG;
  pairs := [map (F1,         F1        ) +=> F1
           ;    (FS F1,      FS F1     ) +=> FS F1
           ;    (FS F1,      FS (FS F1)) +=> FS (FS F1)
           ;    (FS (FS F1), F1        ) +=> FS (FS F1) ]
|}.
Next Obligation.
  unfold arrow in *.
  repeat destruct f using caseS';
  repeat destruct g using caseS'; simpl;
  vm_compute in H;
  try discriminate;
  try inversion f;
  try inversion g;
  match goal with
    [ |- ∃ _, M.MapsTo (?X, ?Y) _ _ ∧ _ ∧ _ ] =>
    match goal with
      [ |- context[M.add (X, Y) ?F _ ] ] =>
        exists F
    end
  end;
  split; intuition; cleanup.
Qed.
Next Obligation.
  split; intros;
  repeat G3.FMapExt.simplify_maps;
  simpl in *;
  destruct H0, H1, H2; subst;
  intuition idtac; try discriminate; cleanup.
Qed.

Program Definition TwoC : Metacategory := {|
  is_metasemigroupoid := TwoMS;
  identity := fun x => _
|}.
Next Obligation.
  destruct x using caseS'. exact F1.
  destruct p using caseS'. exact (FS F1).
  inversion p.
Defined.
Next Obligation.
  destruct x using caseS'. intuition.
  destruct p using caseS'. intuition.
  inversion p.
Qed.
Next Obligation.
  unfold composite; simpl.
  repeat destruct f using caseS';
  repeat destruct p using caseS'; cleanup.
  inversion p.
Qed.
Next Obligation.
  unfold composite; simpl.
  repeat destruct f using caseS';
  repeat destruct p using caseS'; cleanup.
  inversion p.
Qed.

End Two.
