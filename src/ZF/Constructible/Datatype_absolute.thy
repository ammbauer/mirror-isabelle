header {*Absoluteness Properties for Recursive Datatypes*}

theory Datatype_absolute = Formula + WF_absolute:


subsection{*The lfp of a continuous function can be expressed as a union*}

constdefs
  directed :: "i=>o"
   "directed(A) == A\<noteq>0 & (\<forall>x\<in>A. \<forall>y\<in>A. x \<union> y \<in> A)"

  contin :: "(i=>i) => o"
   "contin(h) == (\<forall>A. directed(A) --> h(\<Union>A) = (\<Union>X\<in>A. h(X)))"

lemma bnd_mono_iterates_subset: "[|bnd_mono(D, h); n \<in> nat|] ==> h^n (0) <= D"
apply (induct_tac n) 
 apply (simp_all add: bnd_mono_def, blast) 
done

lemma bnd_mono_increasing [rule_format]:
     "[|i \<in> nat; j \<in> nat; bnd_mono(D,h)|] ==> i \<le> j --> h^i(0) \<subseteq> h^j(0)"
apply (rule_tac m=i and n=j in diff_induct, simp_all)
apply (blast del: subsetI
	     intro: bnd_mono_iterates_subset bnd_monoD2 [of concl: h] ) 
done

lemma directed_iterates: "bnd_mono(D,h) ==> directed({h^n (0). n\<in>nat})"
apply (simp add: directed_def, clarify) 
apply (rename_tac i j)
apply (rule_tac x="i \<union> j" in bexI) 
apply (rule_tac i = i and j = j in Ord_linear_le)
apply (simp_all add: subset_Un_iff [THEN iffD1] le_imp_subset
                     subset_Un_iff2 [THEN iffD1])
apply (simp_all add: subset_Un_iff [THEN iff_sym] bnd_mono_increasing
                     subset_Un_iff2 [THEN iff_sym])
done


lemma contin_iterates_eq: 
    "[|bnd_mono(D, h); contin(h)|] 
     ==> h(\<Union>n\<in>nat. h^n (0)) = (\<Union>n\<in>nat. h^n (0))"
apply (simp add: contin_def directed_iterates) 
apply (rule trans) 
apply (rule equalityI) 
 apply (simp_all add: UN_subset_iff)
 apply safe
 apply (erule_tac [2] natE) 
  apply (rule_tac a="succ(x)" in UN_I) 
   apply simp_all 
apply blast 
done

lemma lfp_subset_Union:
     "[|bnd_mono(D, h); contin(h)|] ==> lfp(D,h) <= (\<Union>n\<in>nat. h^n(0))"
apply (rule lfp_lowerbound) 
 apply (simp add: contin_iterates_eq) 
apply (simp add: contin_def bnd_mono_iterates_subset UN_subset_iff) 
done

lemma Union_subset_lfp:
     "bnd_mono(D,h) ==> (\<Union>n\<in>nat. h^n(0)) <= lfp(D,h)"
apply (simp add: UN_subset_iff)
apply (rule ballI)  
apply (induct_tac n, simp_all) 
apply (rule subset_trans [of _ "h(lfp(D,h))"])
 apply (blast dest: bnd_monoD2 [OF _ _ lfp_subset] )  
apply (erule lfp_lemma2) 
done

lemma lfp_eq_Union:
     "[|bnd_mono(D, h); contin(h)|] ==> lfp(D,h) = (\<Union>n\<in>nat. h^n(0))"
by (blast del: subsetI 
          intro: lfp_subset_Union Union_subset_lfp)


subsubsection{*Some Standard Datatype Constructions Preserve Continuity*}

lemma contin_imp_mono: "[|X\<subseteq>Y; contin(F)|] ==> F(X) \<subseteq> F(Y)"
apply (simp add: contin_def) 
apply (drule_tac x="{X,Y}" in spec) 
apply (simp add: directed_def subset_Un_iff2 Un_commute) 
done

lemma sum_contin: "[|contin(F); contin(G)|] ==> contin(\<lambda>X. F(X) + G(X))"
by (simp add: contin_def, blast)

lemma prod_contin: "[|contin(F); contin(G)|] ==> contin(\<lambda>X. F(X) * G(X))" 
apply (subgoal_tac "\<forall>B C. F(B) \<subseteq> F(B \<union> C)")
 prefer 2 apply (simp add: Un_upper1 contin_imp_mono) 
apply (subgoal_tac "\<forall>B C. G(C) \<subseteq> G(B \<union> C)")
 prefer 2 apply (simp add: Un_upper2 contin_imp_mono) 
apply (simp add: contin_def, clarify) 
apply (rule equalityI) 
 prefer 2 apply blast 
apply clarify 
apply (rename_tac B C) 
apply (rule_tac a="B \<union> C" in UN_I) 
 apply (simp add: directed_def, blast)  
done

lemma const_contin: "contin(\<lambda>X. A)"
by (simp add: contin_def directed_def)

lemma id_contin: "contin(\<lambda>X. X)"
by (simp add: contin_def)



subsection {*Absoluteness for "Iterates"*}

constdefs

  iterates_MH :: "[i=>o, [i,i]=>o, i, i, i, i] => o"
   "iterates_MH(M,isF,v,n,g,z) ==
        is_nat_case(M, v, \<lambda>m u. \<exists>gm[M]. fun_apply(M,g,m,gm) & isF(gm,u),
                    n, z)"

  iterates_replacement :: "[i=>o, [i,i]=>o, i] => o"
   "iterates_replacement(M,isF,v) ==
      \<forall>n[M]. n\<in>nat --> 
         wfrec_replacement(M, iterates_MH(M,isF,v), Memrel(succ(n)))"

lemma (in M_axioms) iterates_MH_abs:
  "[| relativize1(M,isF,F); M(n); M(g); M(z) |] 
   ==> iterates_MH(M,isF,v,n,g,z) <-> z = nat_case(v, \<lambda>m. F(g`m), n)"
by (simp add: nat_case_abs [of _ "\<lambda>m. F(g ` m)"]
              relativize1_def iterates_MH_def)  

lemma (in M_axioms) iterates_imp_wfrec_replacement:
  "[|relativize1(M,isF,F); n \<in> nat; iterates_replacement(M,isF,v)|] 
   ==> wfrec_replacement(M, \<lambda>n f z. z = nat_case(v, \<lambda>m. F(f`m), n), 
                       Memrel(succ(n)))" 
by (simp add: iterates_replacement_def iterates_MH_abs)

theorem (in M_trancl) iterates_abs:
  "[| iterates_replacement(M,isF,v); relativize1(M,isF,F);
      n \<in> nat; M(v); M(z); \<forall>x[M]. M(F(x)) |] 
   ==> is_wfrec(M, iterates_MH(M,isF,v), Memrel(succ(n)), n, z) <->
       z = iterates(F,n,v)" 
apply (frule iterates_imp_wfrec_replacement, assumption+)
apply (simp add: wf_Memrel trans_Memrel relation_Memrel nat_into_M
                 relativize2_def iterates_MH_abs 
                 iterates_nat_def recursor_def transrec_def 
                 eclose_sing_Ord_eq nat_into_M
         trans_wfrec_abs [of _ _ _ _ "\<lambda>n g. nat_case(v, \<lambda>m. F(g`m), n)"])
done


lemma (in M_wfrank) iterates_closed [intro,simp]:
  "[| iterates_replacement(M,isF,v); relativize1(M,isF,F);
      n \<in> nat; M(v); \<forall>x[M]. M(F(x)) |] 
   ==> M(iterates(F,n,v))"
apply (frule iterates_imp_wfrec_replacement, assumption+)
apply (simp add: wf_Memrel trans_Memrel relation_Memrel nat_into_M
                 relativize2_def iterates_MH_abs 
                 iterates_nat_def recursor_def transrec_def 
                 eclose_sing_Ord_eq nat_into_M
         trans_wfrec_closed [of _ _ _ "\<lambda>n g. nat_case(v, \<lambda>m. F(g`m), n)"])
done


subsection {*lists without univ*}

lemmas datatype_univs = Inl_in_univ Inr_in_univ 
                        Pair_in_univ nat_into_univ A_into_univ 

lemma list_fun_bnd_mono: "bnd_mono(univ(A), \<lambda>X. {0} + A*X)"
apply (rule bnd_monoI)
 apply (intro subset_refl zero_subset_univ A_subset_univ 
	      sum_subset_univ Sigma_subset_univ) 
apply (rule subset_refl sum_mono Sigma_mono | assumption)+
done

lemma list_fun_contin: "contin(\<lambda>X. {0} + A*X)"
by (intro sum_contin prod_contin id_contin const_contin) 

text{*Re-expresses lists using sum and product*}
lemma list_eq_lfp2: "list(A) = lfp(univ(A), \<lambda>X. {0} + A*X)"
apply (simp add: list_def) 
apply (rule equalityI) 
 apply (rule lfp_lowerbound) 
  prefer 2 apply (rule lfp_subset)
 apply (clarify, subst lfp_unfold [OF list_fun_bnd_mono])
 apply (simp add: Nil_def Cons_def)
 apply blast 
txt{*Opposite inclusion*}
apply (rule lfp_lowerbound) 
 prefer 2 apply (rule lfp_subset) 
apply (clarify, subst lfp_unfold [OF list.bnd_mono]) 
apply (simp add: Nil_def Cons_def)
apply (blast intro: datatype_univs
             dest: lfp_subset [THEN subsetD])
done

text{*Re-expresses lists using "iterates", no univ.*}
lemma list_eq_Union:
     "list(A) = (\<Union>n\<in>nat. (\<lambda>X. {0} + A*X) ^ n (0))"
by (simp add: list_eq_lfp2 lfp_eq_Union list_fun_bnd_mono list_fun_contin)


constdefs
  is_list_functor :: "[i=>o,i,i,i] => o"
    "is_list_functor(M,A,X,Z) == 
        \<exists>n1[M]. \<exists>AX[M]. 
         number1(M,n1) & cartprod(M,A,X,AX) & is_sum(M,n1,AX,Z)"

lemma (in M_axioms) list_functor_abs [simp]: 
     "[| M(A); M(X); M(Z) |] ==> is_list_functor(M,A,X,Z) <-> (Z = {0} + A*X)"
by (simp add: is_list_functor_def singleton_0 nat_into_M)


subsection {*formulas without univ*}

lemma formula_fun_bnd_mono:
     "bnd_mono(univ(0), \<lambda>X. ((nat*nat) + (nat*nat)) + (X + (X*X + X)))"
apply (rule bnd_monoI)
 apply (intro subset_refl zero_subset_univ A_subset_univ 
	      sum_subset_univ Sigma_subset_univ nat_subset_univ) 
apply (rule subset_refl sum_mono Sigma_mono | assumption)+
done

lemma formula_fun_contin:
     "contin(\<lambda>X. ((nat*nat) + (nat*nat)) + (X + (X*X + X)))"
by (intro sum_contin prod_contin id_contin const_contin) 


text{*Re-expresses formulas using sum and product*}
lemma formula_eq_lfp2:
    "formula = lfp(univ(0), \<lambda>X. ((nat*nat) + (nat*nat)) + (X + (X*X + X)))"
apply (simp add: formula_def) 
apply (rule equalityI) 
 apply (rule lfp_lowerbound) 
  prefer 2 apply (rule lfp_subset)
 apply (clarify, subst lfp_unfold [OF formula_fun_bnd_mono])
 apply (simp add: Member_def Equal_def Neg_def And_def Forall_def)
 apply blast 
txt{*Opposite inclusion*}
apply (rule lfp_lowerbound) 
 prefer 2 apply (rule lfp_subset, clarify) 
apply (subst lfp_unfold [OF formula.bnd_mono, simplified]) 
apply (simp add: Member_def Equal_def Neg_def And_def Forall_def)  
apply (elim sumE SigmaE, simp_all) 
apply (blast intro: datatype_univs dest: lfp_subset [THEN subsetD])+  
done

text{*Re-expresses formulas using "iterates", no univ.*}
lemma formula_eq_Union:
     "formula = 
      (\<Union>n\<in>nat. (\<lambda>X. ((nat*nat) + (nat*nat)) + (X + (X*X + X))) ^ n (0))"
by (simp add: formula_eq_lfp2 lfp_eq_Union formula_fun_bnd_mono 
              formula_fun_contin)


constdefs
  is_formula_functor :: "[i=>o,i,i] => o"
    "is_formula_functor(M,X,Z) == 
        \<exists>nat'[M]. \<exists>natnat[M]. \<exists>natnatsum[M]. \<exists>XX[M]. \<exists>X3[M]. \<exists>X4[M]. 
          omega(M,nat') & cartprod(M,nat',nat',natnat) & 
          is_sum(M,natnat,natnat,natnatsum) &
          cartprod(M,X,X,XX) & is_sum(M,XX,X,X3) & is_sum(M,X,X3,X4) &
          is_sum(M,natnatsum,X4,Z)"

lemma (in M_axioms) formula_functor_abs [simp]: 
     "[| M(X); M(Z) |] 
      ==> is_formula_functor(M,X,Z) <-> 
          Z = ((nat*nat) + (nat*nat)) + (X + (X*X + X))"
by (simp add: is_formula_functor_def) 


subsection{*@{term M} Contains the List and Formula Datatypes*}

constdefs
  is_list_n :: "[i=>o,i,i,i] => o"
    "is_list_n(M,A,n,Z) == 
      \<exists>zero[M]. \<exists>sn[M]. \<exists>msn[M]. 
       empty(M,zero) & 
       successor(M,n,sn) & membership(M,sn,msn) &
       is_wfrec(M, iterates_MH(M, is_list_functor(M,A),zero), msn, n, Z)"
  
  mem_list :: "[i=>o,i,i] => o"
    "mem_list(M,A,l) == 
      \<exists>n[M]. \<exists>listn[M]. 
       finite_ordinal(M,n) & is_list_n(M,A,n,listn) & l \<in> listn"

  is_list :: "[i=>o,i,i] => o"
    "is_list(M,A,Z) == \<forall>l[M]. l \<in> Z <-> mem_list(M,A,l)"

constdefs
  is_formula_n :: "[i=>o,i,i] => o"
    "is_formula_n(M,n,Z) == 
      \<exists>zero[M]. \<exists>sn[M]. \<exists>msn[M]. 
       empty(M,zero) & 
       successor(M,n,sn) & membership(M,sn,msn) &
       is_wfrec(M, iterates_MH(M, is_formula_functor(M),zero), msn, n, Z)"
  
  mem_formula :: "[i=>o,i] => o"
    "mem_formula(M,p) == 
      \<exists>n[M]. \<exists>formn[M]. 
       finite_ordinal(M,n) & is_formula_n(M,n,formn) & p \<in> formn"

  is_formula :: "[i=>o,i] => o"
    "is_formula(M,Z) == \<forall>p[M]. p \<in> Z <-> mem_formula(M,p)"

locale (open) M_datatypes = M_wfrank +
 assumes list_replacement1: 
   "M(A) ==> iterates_replacement(M, is_list_functor(M,A), 0)"
  and list_replacement2: 
   "M(A) ==> strong_replacement(M, 
         \<lambda>n y. n\<in>nat & 
               (\<exists>sn[M]. \<exists>msn[M]. successor(M,n,sn) & membership(M,sn,msn) &
               is_wfrec(M, iterates_MH(M,is_list_functor(M,A), 0), 
                        msn, n, y)))"
  and formula_replacement1: 
   "iterates_replacement(M, is_formula_functor(M), 0)"
  and formula_replacement2: 
   "strong_replacement(M, 
         \<lambda>n y. n\<in>nat & 
               (\<exists>sn[M]. \<exists>msn[M]. successor(M,n,sn) & membership(M,sn,msn) &
               is_wfrec(M, iterates_MH(M,is_formula_functor(M), 0), 
                        msn, n, y)))"


subsubsection{*Absoluteness of the List Construction*}

lemma (in M_datatypes) list_replacement2': 
  "M(A) ==> strong_replacement(M, \<lambda>n y. n\<in>nat & y = (\<lambda>X. {0} + A * X)^n (0))"
apply (insert list_replacement2 [of A]) 
apply (rule strong_replacement_cong [THEN iffD1])  
apply (rule conj_cong [OF iff_refl iterates_abs [of "is_list_functor(M,A)"]]) 
apply (simp_all add: list_replacement1 relativize1_def) 
done

lemma (in M_datatypes) list_closed [intro,simp]:
     "M(A) ==> M(list(A))"
apply (insert list_replacement1)
by  (simp add: RepFun_closed2 list_eq_Union 
               list_replacement2' relativize1_def
               iterates_closed [of "is_list_functor(M,A)"])
lemma (in M_datatypes) is_list_n_abs [simp]:
     "[|M(A); n\<in>nat; M(Z)|] 
      ==> is_list_n(M,A,n,Z) <-> Z = (\<lambda>X. {0} + A * X)^n (0)"
apply (insert list_replacement1)
apply (simp add: is_list_n_def relativize1_def nat_into_M
                 iterates_abs [of "is_list_functor(M,A)" _ "\<lambda>X. {0} + A*X"])
done

lemma (in M_datatypes) mem_list_abs [simp]:
     "M(A) ==> mem_list(M,A,l) <-> l \<in> list(A)"
apply (insert list_replacement1)
apply (simp add: mem_list_def relativize1_def list_eq_Union
                 iterates_closed [of "is_list_functor(M,A)"]) 
done

lemma (in M_datatypes) list_abs [simp]:
     "[|M(A); M(Z)|] ==> is_list(M,A,Z) <-> Z = list(A)"
apply (simp add: is_list_def, safe)
apply (rule M_equalityI, simp_all)
done

subsubsection{*Absoluteness of Formulas*}

lemma (in M_datatypes) formula_replacement2': 
  "strong_replacement(M, \<lambda>n y. n\<in>nat & y = (\<lambda>X. ((nat*nat) + (nat*nat)) + (X + (X*X + X)))^n (0))"
apply (insert formula_replacement2) 
apply (rule strong_replacement_cong [THEN iffD1])  
apply (rule conj_cong [OF iff_refl iterates_abs [of "is_formula_functor(M)"]]) 
apply (simp_all add: formula_replacement1 relativize1_def) 
done

lemma (in M_datatypes) formula_closed [intro,simp]:
     "M(formula)"
apply (insert formula_replacement1)
apply  (simp add: RepFun_closed2 formula_eq_Union 
                  formula_replacement2' relativize1_def
                  iterates_closed [of "is_formula_functor(M)"])
done

lemma (in M_datatypes) is_formula_n_abs [simp]:
     "[|n\<in>nat; M(Z)|] 
      ==> is_formula_n(M,n,Z) <-> 
          Z = (\<lambda>X. ((nat*nat) + (nat*nat)) + (X + (X*X + X)))^n (0)"
apply (insert formula_replacement1)
apply (simp add: is_formula_n_def relativize1_def nat_into_M
                 iterates_abs [of "is_formula_functor(M)" _ 
                        "\<lambda>X. ((nat*nat) + (nat*nat)) + (X + (X*X + X))"])
done

lemma (in M_datatypes) mem_formula_abs [simp]:
     "mem_formula(M,l) <-> l \<in> formula"
apply (insert formula_replacement1)
apply (simp add: mem_formula_def relativize1_def formula_eq_Union
                 iterates_closed [of "is_formula_functor(M)"]) 
done

lemma (in M_datatypes) formula_abs [simp]:
     "[|M(Z)|] ==> is_formula(M,Z) <-> Z = formula"
apply (simp add: is_formula_def, safe)
apply (rule M_equalityI, simp_all)
done


subsection{*Absoluteness for @{text \<epsilon>}-Closure: the @{term eclose} Operator*}

text{*Re-expresses eclose using "iterates"*}
lemma eclose_eq_Union:
     "eclose(A) = (\<Union>n\<in>nat. Union^n (A))"
apply (simp add: eclose_def) 
apply (rule UN_cong) 
apply (rule refl)
apply (induct_tac n)
apply (simp add: nat_rec_0)  
apply (simp add: nat_rec_succ) 
done

constdefs
  is_eclose_n :: "[i=>o,i,i,i] => o"
    "is_eclose_n(M,A,n,Z) == 
      \<exists>sn[M]. \<exists>msn[M]. 
       successor(M,n,sn) & membership(M,sn,msn) &
       is_wfrec(M, iterates_MH(M, big_union(M), A), msn, n, Z)"
  
  mem_eclose :: "[i=>o,i,i] => o"
    "mem_eclose(M,A,l) == 
      \<exists>n[M]. \<exists>eclosen[M]. 
       finite_ordinal(M,n) & is_eclose_n(M,A,n,eclosen) & l \<in> eclosen"

  is_eclose :: "[i=>o,i,i] => o"
    "is_eclose(M,A,Z) == \<forall>u[M]. u \<in> Z <-> mem_eclose(M,A,u)"


locale (open) M_eclose = M_wfrank +
 assumes eclose_replacement1: 
   "M(A) ==> iterates_replacement(M, big_union(M), A)"
  and eclose_replacement2: 
   "M(A) ==> strong_replacement(M, 
         \<lambda>n y. n\<in>nat & 
               (\<exists>sn[M]. \<exists>msn[M]. successor(M,n,sn) & membership(M,sn,msn) &
               is_wfrec(M, iterates_MH(M,big_union(M), A), 
                        msn, n, y)))"

lemma (in M_eclose) eclose_replacement2': 
  "M(A) ==> strong_replacement(M, \<lambda>n y. n\<in>nat & y = Union^n (A))"
apply (insert eclose_replacement2 [of A]) 
apply (rule strong_replacement_cong [THEN iffD1])  
apply (rule conj_cong [OF iff_refl iterates_abs [of "big_union(M)"]]) 
apply (simp_all add: eclose_replacement1 relativize1_def) 
done

lemma (in M_eclose) eclose_closed [intro,simp]:
     "M(A) ==> M(eclose(A))"
apply (insert eclose_replacement1)
by  (simp add: RepFun_closed2 eclose_eq_Union 
               eclose_replacement2' relativize1_def
               iterates_closed [of "big_union(M)"])

lemma (in M_eclose) is_eclose_n_abs [simp]:
     "[|M(A); n\<in>nat; M(Z)|] ==> is_eclose_n(M,A,n,Z) <-> Z = Union^n (A)"
apply (insert eclose_replacement1)
apply (simp add: is_eclose_n_def relativize1_def nat_into_M
                 iterates_abs [of "big_union(M)" _ "Union"])
done

lemma (in M_eclose) mem_eclose_abs [simp]:
     "M(A) ==> mem_eclose(M,A,l) <-> l \<in> eclose(A)"
apply (insert eclose_replacement1)
apply (simp add: mem_eclose_def relativize1_def eclose_eq_Union
                 iterates_closed [of "big_union(M)"]) 
done

lemma (in M_eclose) eclose_abs [simp]:
     "[|M(A); M(Z)|] ==> is_eclose(M,A,Z) <-> Z = eclose(A)"
apply (simp add: is_eclose_def, safe)
apply (rule M_equalityI, simp_all)
done




subsection {*Absoluteness for @{term transrec}*}


text{* @{term "transrec(a,H) \<equiv> wfrec(Memrel(eclose({a})), a, H)"} *}
constdefs

  is_transrec :: "[i=>o, [i,i,i]=>o, i, i] => o"
   "is_transrec(M,MH,a,z) == 
      \<exists>sa[M]. \<exists>esa[M]. \<exists>mesa[M]. 
       upair(M,a,a,sa) & is_eclose(M,sa,esa) & membership(M,esa,mesa) &
       is_wfrec(M,MH,mesa,a,z)"

  transrec_replacement :: "[i=>o, [i,i,i]=>o, i] => o"
   "transrec_replacement(M,MH,a) ==
      \<exists>sa[M]. \<exists>esa[M]. \<exists>mesa[M]. 
       upair(M,a,a,sa) & is_eclose(M,sa,esa) & membership(M,esa,mesa) &
       wfrec_replacement(M,MH,mesa)"

(*????????????????Ordinal.thy*)
lemma Transset_trans_Memrel: 
    "\<forall>j\<in>i. Transset(j) ==> trans(Memrel(i))"
by (unfold Transset_def trans_def, blast)

text{*The condition @{term "Ord(i)"} lets us use the simpler 
  @{text "trans_wfrec_abs"} rather than @{text "trans_wfrec_abs"},
  which I haven't even proved yet. *}
theorem (in M_eclose) transrec_abs:
  "[|Ord(i);  M(i);  M(z);
     transrec_replacement(M,MH,i);  relativize2(M,MH,H);
     \<forall>x[M]. \<forall>g[M]. function(g) --> M(H(x,g))|] 
   ==> is_transrec(M,MH,i,z) <-> z = transrec(i,H)" 
by (simp add: trans_wfrec_abs transrec_replacement_def is_transrec_def
       transrec_def eclose_sing_Ord_eq wf_Memrel trans_Memrel relation_Memrel)


theorem (in M_eclose) transrec_closed:
     "[|Ord(i);  M(i);  M(z);
	transrec_replacement(M,MH,i);  relativize2(M,MH,H);
	\<forall>x[M]. \<forall>g[M]. function(g) --> M(H(x,g))|] 
      ==> M(transrec(i,H))"
by (simp add: trans_wfrec_closed transrec_replacement_def is_transrec_def
       transrec_def eclose_sing_Ord_eq wf_Memrel trans_Memrel relation_Memrel)




end
