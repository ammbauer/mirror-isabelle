(*  Title:      HOLCF/Option_Cpo.thy
    Author:     Brian Huffman
*)

header {* Cpo class instance for HOL option type *}

theory Option_Cpo
imports HOLCF
begin

subsection {* Ordering on option type *}

instantiation option :: (below) below
begin

definition below_option_def:
  "x \<sqsubseteq> y \<equiv> case x of
         None \<Rightarrow> (case y of None \<Rightarrow> True | Some b \<Rightarrow> False) |
         Some a \<Rightarrow> (case y of None \<Rightarrow> False | Some b \<Rightarrow> a \<sqsubseteq> b)"

instance ..
end

lemma None_below_None [simp]: "None \<sqsubseteq> None"
unfolding below_option_def by simp

lemma Some_below_Some [simp]: "Some x \<sqsubseteq> Some y \<longleftrightarrow> x \<sqsubseteq> y"
unfolding below_option_def by simp

lemma Some_below_None [simp]: "\<not> Some x \<sqsubseteq> None"
unfolding below_option_def by simp

lemma None_below_Some [simp]: "\<not> None \<sqsubseteq> Some y"
unfolding below_option_def by simp

lemma Some_mono: "x \<sqsubseteq> y \<Longrightarrow> Some x \<sqsubseteq> Some y"
by simp

lemma None_below_iff [simp]: "None \<sqsubseteq> x \<longleftrightarrow> x = None"
by (cases x, simp_all)

lemma below_None_iff [simp]: "x \<sqsubseteq> None \<longleftrightarrow> x = None"
by (cases x, simp_all)

lemma option_below_cases:
  assumes "x \<sqsubseteq> y"
  obtains "x = None" and "y = None"
  | a b where "x = Some a" and "y = Some b" and "a \<sqsubseteq> b"
using assms unfolding below_option_def
by (simp split: option.split_asm)

subsection {* Option type is a complete partial order *}

instance option :: (po) po
proof
  fix x :: "'a option"
  show "x \<sqsubseteq> x"
    unfolding below_option_def
    by (simp split: option.split)
next
  fix x y :: "'a option"
  assume "x \<sqsubseteq> y" and "y \<sqsubseteq> x" thus "x = y"
    unfolding below_option_def
    by (auto split: option.split_asm intro: below_antisym)
next
  fix x y z :: "'a option"
  assume "x \<sqsubseteq> y" and "y \<sqsubseteq> z" thus "x \<sqsubseteq> z"
    unfolding below_option_def
    by (auto split: option.split_asm intro: below_trans)
qed

lemma monofun_the: "monofun the"
by (rule monofunI, erule option_below_cases, simp_all)

lemma option_chain_cases:
  assumes Y: "chain Y"
  obtains "Y = (\<lambda>i. None)" | A where "chain A" and "Y = (\<lambda>i. Some (A i))"
 apply (cases "Y 0")
  apply (rule that(1))
  apply (rule ext)
  apply (cut_tac j=i in chain_mono [OF Y le0], simp)
 apply (rule that(2))
  apply (rule ch2ch_monofun [OF monofun_the Y])
 apply (rule ext)
 apply (cut_tac j=i in chain_mono [OF Y le0], simp)
 apply (case_tac "Y i", simp_all)
done

lemma is_lub_Some: "range S <<| x \<Longrightarrow> range (\<lambda>i. Some (S i)) <<| Some x"
 apply (rule is_lubI)
  apply (rule ub_rangeI)
  apply (simp add: is_lub_rangeD1)
 apply (frule ub_rangeD [where i=arbitrary])
 apply (case_tac u, simp_all)
 apply (erule is_lubD2)
 apply (rule ub_rangeI)
 apply (drule ub_rangeD, simp)
done

instance option :: (cpo) cpo
 apply intro_classes
 apply (erule option_chain_cases, safe)
  apply (rule exI, rule is_lub_const)
 apply (rule exI)
 apply (rule is_lub_Some)
 apply (erule cpo_lubI)
done

subsection {* Continuity of Some and case function *}

lemma cont_Some: "cont Some"
by (intro contI is_lub_Some cpo_lubI)

lemmas cont2cont_Some [simp, cont2cont] = cont_compose [OF cont_Some]

lemmas ch2ch_Some [simp] = ch2ch_cont [OF cont_Some]

lemmas lub_Some = cont2contlubE [OF cont_Some, symmetric]

lemma cont2cont_option_case:
  assumes f: "cont (\<lambda>x. f x)"
  assumes g: "cont (\<lambda>x. g x)"
  assumes h1: "\<And>a. cont (\<lambda>x. h x a)"
  assumes h2: "\<And>x. cont (\<lambda>a. h x a)"
  shows "cont (\<lambda>x. case f x of None \<Rightarrow> g x | Some a \<Rightarrow> h x a)"
apply (rule cont_apply [OF f])
apply (rule contI)
apply (erule option_chain_cases)
apply (simp add: is_lub_const)
apply (simp add: lub_Some)
apply (simp add: cont2contlubE [OF h2])
apply (rule cpo_lubI, rule chainI)
apply (erule cont2monofunE [OF h2 chainE])
apply (case_tac y, simp_all add: g h1)
done

lemma cont2cont_option_case' [simp, cont2cont]:
  assumes f: "cont (\<lambda>x. f x)"
  assumes g: "cont (\<lambda>x. g x)"
  assumes h: "cont (\<lambda>p. h (fst p) (snd p))"
  shows "cont (\<lambda>x. case f x of None \<Rightarrow> g x | Some a \<Rightarrow> h x a)"
using assms by (simp add: cont2cont_option_case prod_cont_iff)

text {* Simple version for when the element type is not a cpo. *}

lemma cont2cont_option_case_simple [simp, cont2cont]:
  assumes "cont (\<lambda>x. f x)"
  assumes "\<And>a. cont (\<lambda>x. g x a)"
  shows "cont (\<lambda>x. case z of None \<Rightarrow> f x | Some a \<Rightarrow> g x a)"
using assms by (cases z) auto

subsection {* Compactness and chain-finiteness *}

lemma compact_None [simp]: "compact None"
apply (rule compactI2)
apply (erule option_chain_cases, safe)
apply simp
apply (simp add: lub_Some)
done

lemma compact_Some: "compact a \<Longrightarrow> compact (Some a)"
apply (rule compactI2)
apply (erule option_chain_cases, safe)
apply simp
apply (simp add: lub_Some)
apply (erule (2) compactD2)
done

lemma compact_Some_rev: "compact (Some a) \<Longrightarrow> compact a"
unfolding compact_def
by (drule adm_subst [OF cont_Some], simp)

lemma compact_Some_iff [simp]: "compact (Some a) = compact a"
by (safe elim!: compact_Some compact_Some_rev)

instance option :: (chfin) chfin
apply intro_classes
apply (erule compact_imp_max_in_chain)
apply (case_tac "\<Squnion>i. Y i", simp_all)
done

instance option :: (discrete_cpo) discrete_cpo
by intro_classes (simp add: below_option_def split: option.split)

subsection {* Using option types with fixrec *}

definition
  "match_None = (\<Lambda> x k. case x of None \<Rightarrow> k | Some a \<Rightarrow> Fixrec.fail)"

definition
  "match_Some = (\<Lambda> x k. case x of None \<Rightarrow> Fixrec.fail | Some a \<Rightarrow> k\<cdot>a)"

lemma match_None_simps [simp]:
  "match_None\<cdot>None\<cdot>k = k"
  "match_None\<cdot>(Some a)\<cdot>k = Fixrec.fail"
unfolding match_None_def by simp_all

lemma match_Some_simps [simp]:
  "match_Some\<cdot>None\<cdot>k = Fixrec.fail"
  "match_Some\<cdot>(Some a)\<cdot>k = k\<cdot>a"
unfolding match_Some_def by simp_all

setup {*
  Fixrec.add_matchers
    [ (@{const_name None}, @{const_name match_None}),
      (@{const_name Some}, @{const_name match_Some}) ]
*}

subsection {* Option type is a predomain *}

definition
  "encode_option_u =
    (\<Lambda>(up\<cdot>x). case x of None \<Rightarrow> sinl\<cdot>ONE | Some a \<Rightarrow> sinr\<cdot>(up\<cdot>a))"

definition
  "decode_option_u = sscase\<cdot>(\<Lambda> ONE. up\<cdot>None)\<cdot>(\<Lambda>(up\<cdot>a). up\<cdot>(Some a))"

lemma decode_encode_option_u [simp]: "decode_option_u\<cdot>(encode_option_u\<cdot>x) = x"
unfolding decode_option_u_def encode_option_u_def
by (case_tac x, simp, rename_tac y, case_tac y, simp_all)

lemma encode_decode_option_u [simp]: "encode_option_u\<cdot>(decode_option_u\<cdot>x) = x"
unfolding decode_option_u_def encode_option_u_def
apply (case_tac x, simp)
apply (rename_tac a, case_tac a rule: oneE, simp, simp)
apply (rename_tac b, case_tac b, simp, simp)
done

instantiation option :: (predomain) predomain
begin

definition
  "liftemb = emb oo encode_option_u"

definition
  "liftprj = decode_option_u oo prj"

definition
  "liftdefl (t::('a option) itself) = DEFL(one \<oplus> 'a u)"

instance proof
  show "ep_pair liftemb (liftprj :: udom \<rightarrow> ('a option) u)"
    unfolding liftemb_option_def liftprj_option_def
    apply (rule ep_pair_comp)
    apply (rule ep_pair.intro, simp, simp)
    apply (rule ep_pair_emb_prj)
    done
  show "cast\<cdot>LIFTDEFL('a option) = liftemb oo (liftprj :: udom \<rightarrow> ('a option) u)"
    unfolding liftemb_option_def liftprj_option_def liftdefl_option_def
    by (simp add: cast_DEFL cfcomp1)
qed

end

end
