(*<*)theory CTL = Base:;(*>*)

subsection{*Computation tree logic---CTL*};

text{*\label{sec:CTL}
The semantics of PDL only needs transitive reflexive closure.
Let us now be a bit more adventurous and introduce a new temporal operator
that goes beyond transitive reflexive closure. We extend the datatype
@{text formula} by a new constructor
*};
(*<*)
datatype formula = Atom atom
                  | Neg formula
                  | And formula formula
                  | AX formula
                  | EF formula(*>*)
                  | AF formula;

text{*\noindent
which stands for "always in the future":
on all paths, at some point the formula holds. Formalizing the notion of an infinite path is easy
in HOL: it is simply a function from @{typ nat} to @{typ state}.
*};

constdefs Paths :: "state \<Rightarrow> (nat \<Rightarrow> state)set"
         "Paths s \<equiv> {p. s = p 0 \<and> (\<forall>i. (p i, p(i+1)) \<in> M)}";

text{*\noindent
This definition allows a very succinct statement of the semantics of @{term AF}:
\footnote{Do not be mislead: neither datatypes nor recursive functions can be
extended by new constructors or equations. This is just a trick of the
presentation. In reality one has to define a new datatype and a new function.}
*};
(*<*)
consts valid :: "state \<Rightarrow> formula \<Rightarrow> bool" ("(_ \<Turnstile> _)" [80,80] 80);

primrec
"s \<Turnstile> Atom a  =  (a \<in> L s)"
"s \<Turnstile> Neg f   = (~(s \<Turnstile> f))"
"s \<Turnstile> And f g = (s \<Turnstile> f \<and> s \<Turnstile> g)"
"s \<Turnstile> AX f    = (\<forall>t. (s,t) \<in> M \<longrightarrow> t \<Turnstile> f)"
"s \<Turnstile> EF f    = (\<exists>t. (s,t) \<in> M^* \<and> t \<Turnstile> f)"
(*>*)
"s \<Turnstile> AF f    = (\<forall>p \<in> Paths s. \<exists>i. p i \<Turnstile> f)";

text{*\noindent
Model checking @{term AF} involves a function which
is just complicated enough to warrant a separate definition:
*};

constdefs af :: "state set \<Rightarrow> state set \<Rightarrow> state set"
         "af A T \<equiv> A \<union> {s. \<forall>t. (s, t) \<in> M \<longrightarrow> t \<in> T}";

text{*\noindent
Now we define @{term "mc(AF f)"} as the least set @{term T} that contains
@{term"mc f"} and all states all of whose direct successors are in @{term T}:
*};
(*<*)
consts mc :: "formula \<Rightarrow> state set";
primrec
"mc(Atom a)  = {s. a \<in> L s}"
"mc(Neg f)   = -mc f"
"mc(And f g) = mc f \<inter> mc g"
"mc(AX f)    = {s. \<forall>t. (s,t) \<in> M  \<longrightarrow> t \<in> mc f}"
"mc(EF f)    = lfp(\<lambda>T. mc f \<union> M^-1 ^^ T)"(*>*)
"mc(AF f)    = lfp(af(mc f))";

text{*\noindent
Because @{term af} is monotone in its second argument (and also its first, but
that is irrelevant) @{term"af A"} has a least fixed point:
*};

lemma mono_af: "mono(af A)";
apply(simp add: mono_def af_def);
apply blast;
done
(*<*)
lemma mono_ef: "mono(\<lambda>T. A \<union> M^-1 ^^ T)";
apply(rule monoI);
by(blast);

lemma EF_lemma:
  "lfp(\<lambda>T. A \<union> M^-1 ^^ T) = {s. \<exists>t. (s,t) \<in> M^* \<and> t \<in> A}";
apply(rule equalityI);
 apply(rule subsetI);
 apply(simp);
 apply(erule lfp_induct);
  apply(rule mono_ef);
 apply(simp);
 apply(blast intro: rtrancl_trans);
apply(rule subsetI);
apply(simp, clarify);
apply(erule converse_rtrancl_induct);
 apply(rule ssubst[OF lfp_unfold[OF mono_ef]]);
 apply(blast);
apply(rule ssubst[OF lfp_unfold[OF mono_ef]]);
by(blast);
(*>*)
text{*
All we need to prove now is that @{term mc} and @{text"\<Turnstile>"}
agree for @{term AF}, i.e.\ that @{prop"mc(AF f) = {s. s \<Turnstile>
AF f}"}. This time we prove the two containments separately, starting
with the easy one:
*};

theorem AF_lemma1:
  "lfp(af A) \<subseteq> {s. \<forall> p \<in> Paths s. \<exists> i. p i \<in> A}";

txt{*\noindent
In contrast to the analogous property for @{term EF}, and just
for a change, we do not use fixed point induction but a weaker theorem,
@{thm[source]lfp_lowerbound}:
@{thm[display]lfp_lowerbound[of _ "S",no_vars]}
The instance of the premise @{prop"f S \<subseteq> S"} is proved pointwise,
a decision that clarification takes for us:
*};
apply(rule lfp_lowerbound);
apply(clarsimp simp add: af_def Paths_def);

txt{*
@{subgoals[display,indent=0,margin=70,goals_limit=1]}
Now we eliminate the disjunction. The case @{prop"p 0 \<in> A"} is trivial:
*};

apply(erule disjE);
 apply(blast);

txt{*\noindent
In the other case we set @{term t} to @{term"p 1"} and simplify matters:
*};

apply(erule_tac x = "p 1" in allE);
apply(clarsimp);

txt{*
@{subgoals[display,indent=0,margin=70,goals_limit=1]}
It merely remains to set @{term pa} to @{term"\<lambda>i. p(i+1)"}, i.e.\ @{term p} without its
first element. The rest is practically automatic:
*};

apply(erule_tac x = "\<lambda>i. p(i+1)" in allE);
apply simp;
apply blast;
done;


text{*
The opposite containment is proved by contradiction: if some state
@{term s} is not in @{term"lfp(af A)"}, then we can construct an
infinite @{term A}-avoiding path starting from @{term s}. The reason is
that by unfolding @{term lfp} we find that if @{term s} is not in
@{term"lfp(af A)"}, then @{term s} is not in @{term A} and there is a
direct successor of @{term s} that is again not in @{term"lfp(af
A)"}. Iterating this argument yields the promised infinite
@{term A}-avoiding path. Let us formalize this sketch.

The one-step argument in the above sketch
*};

lemma not_in_lfp_afD:
 "s \<notin> lfp(af A) \<Longrightarrow> s \<notin> A \<and> (\<exists> t. (s,t)\<in>M \<and> t \<notin> lfp(af A))";
apply(erule contrapos_np);
apply(rule ssubst[OF lfp_unfold[OF mono_af]]);
apply(simp add:af_def);
done;

text{*\noindent
is proved by a variant of contraposition:
assume the negation of the conclusion and prove @{term"s : lfp(af A)"}.
Unfolding @{term lfp} once and
simplifying with the definition of @{term af} finishes the proof.

Now we iterate this process. The following construction of the desired
path is parameterized by a predicate @{term P} that should hold along the path:
*};

consts path :: "state \<Rightarrow> (state \<Rightarrow> bool) \<Rightarrow> (nat \<Rightarrow> state)";
primrec
"path s P 0 = s"
"path s P (Suc n) = (SOME t. (path s P n,t) \<in> M \<and> P t)";

text{*\noindent
Element @{term"n+1"} on this path is some arbitrary successor
@{term t} of element @{term n} such that @{term"P t"} holds.  Remember that @{text"SOME t. R t"}
is some arbitrary but fixed @{term t} such that @{prop"R t"} holds (see \S\ref{sec:SOME}). Of
course, such a @{term t} may in general not exist, but that is of no
concern to us since we will only use @{term path} in such cases where a
suitable @{term t} does exist.

Let us show that if each state @{term s} that satisfies @{term P}
has a successor that again satisfies @{term P}, then there exists an infinite @{term P}-path:
*};

lemma infinity_lemma:
  "\<lbrakk> P s; \<forall>s. P s \<longrightarrow> (\<exists> t. (s,t) \<in> M \<and> P t) \<rbrakk> \<Longrightarrow>
   \<exists>p\<in>Paths s. \<forall>i. P(p i)";

txt{*\noindent
First we rephrase the conclusion slightly because we need to prove both the path property
and the fact that @{term P} holds simultaneously:
*};

apply(subgoal_tac "\<exists>p. s = p 0 \<and> (\<forall>i. (p i,p(i+1)) \<in> M \<and> P(p i))");

txt{*\noindent
From this proposition the original goal follows easily:
*};

 apply(simp add:Paths_def, blast);

txt{*\noindent
The new subgoal is proved by providing the witness @{term "path s P"} for @{term p}:
*};

apply(rule_tac x = "path s P" in exI);
apply(clarsimp);

txt{*\noindent
After simplification and clarification the subgoal has the following compact form
@{subgoals[display,indent=0,margin=70,goals_limit=1]}
and invites a proof by induction on @{term i}:
*};

apply(induct_tac i);
 apply(simp);

txt{*\noindent
After simplification the base case boils down to
@{subgoals[display,indent=0,margin=70,goals_limit=1]}
The conclusion looks exceedingly trivial: after all, @{term t} is chosen such that @{prop"(s,t):M"}
holds. However, we first have to show that such a @{term t} actually exists! This reasoning
is embodied in the theorem @{thm[source]someI2_ex}:
@{thm[display,eta_contract=false]someI2_ex}
When we apply this theorem as an introduction rule, @{text"?P x"} becomes
@{prop"(s, x) : M & P x"} and @{text"?Q x"} becomes @{prop"(s,x) : M"} and we have to prove
two subgoals: @{prop"EX a. (s, a) : M & P a"}, which follows from the assumptions, and
@{prop"(s, x) : M & P x ==> (s,x) : M"}, which is trivial. Thus it is not surprising that
@{text fast} can prove the base case quickly:
*};

 apply(fast intro:someI2_ex);

txt{*\noindent
What is worth noting here is that we have used @{text fast} rather than
@{text blast}.  The reason is that @{text blast} would fail because it cannot
cope with @{thm[source]someI2_ex}: unifying its conclusion with the current
subgoal is nontrivial because of the nested schematic variables. For
efficiency reasons @{text blast} does not even attempt such unifications.
Although @{text fast} can in principle cope with complicated unification
problems, in practice the number of unifiers arising is often prohibitive and
the offending rule may need to be applied explicitly rather than
automatically. This is what happens in the step case.

The induction step is similar, but more involved, because now we face nested
occurrences of @{text SOME}. As a result, @{text fast} is no longer able to
solve the subgoal and we apply @{thm[source]someI2_ex} by hand.  We merely
show the proof commands but do not describe the details:
*};

apply(simp);
apply(rule someI2_ex);
 apply(blast);
apply(rule someI2_ex);
 apply(blast);
apply(blast);
done;

text{*
Function @{term path} has fulfilled its purpose now and can be forgotten
about. It was merely defined to provide the witness in the proof of the
@{thm[source]infinity_lemma}. Aficionados of minimal proofs might like to know
that we could have given the witness without having to define a new function:
the term
@{term[display]"nat_rec s (\<lambda>n t. SOME u. (t,u)\<in>M \<and> P u)"}
is extensionally equal to @{term"path s P"},
where @{term nat_rec} is the predefined primitive recursor on @{typ nat}, whose defining
equations we omit.
*};
(*<*)
lemma infinity_lemma:
"\<lbrakk> P s; \<forall> s. P s \<longrightarrow> (\<exists> t. (s,t)\<in>M \<and> P t) \<rbrakk> \<Longrightarrow>
 \<exists> p\<in>Paths s. \<forall> i. P(p i)";
apply(subgoal_tac
 "\<exists> p. s = p 0 \<and> (\<forall> i. (p i,p(Suc i))\<in>M \<and> P(p i))");
 apply(simp add:Paths_def);
 apply(blast);
apply(rule_tac x = "nat_rec s (\<lambda>n t. SOME u. (t,u)\<in>M \<and> P u)" in exI);
apply(simp);
apply(intro strip);
apply(induct_tac i);
 apply(simp);
 apply(fast intro:someI2_ex);
apply(simp);
apply(rule someI2_ex);
 apply(blast);
apply(rule someI2_ex);
 apply(blast);
by(blast);
(*>*)

text{*
At last we can prove the opposite direction of @{thm[source]AF_lemma1}:
*};

theorem AF_lemma2:
"{s. \<forall> p \<in> Paths s. \<exists> i. p i \<in> A} \<subseteq> lfp(af A)";

txt{*\noindent
The proof is again pointwise and then by contraposition:
*};

apply(rule subsetI);
apply(erule contrapos_pp);
apply simp;

txt{*
@{subgoals[display,indent=0,goals_limit=1]}
Applying the @{thm[source]infinity_lemma} as a destruction rule leaves two subgoals, the second
premise of @{thm[source]infinity_lemma} and the original subgoal:
*};

apply(drule infinity_lemma);

txt{*
@{subgoals[display,indent=0,margin=65]}
Both are solved automatically:
*};

 apply(auto dest:not_in_lfp_afD);
done;

text{*
If you found the above proofs somewhat complicated we recommend you read
\S\ref{sec:CTL-revisited} where we shown how inductive definitions lead to
simpler arguments.

The main theorem is proved as for PDL, except that we also derive the
necessary equality @{text"lfp(af A) = ..."} by combining
@{thm[source]AF_lemma1} and @{thm[source]AF_lemma2} on the spot:
*}

theorem "mc f = {s. s \<Turnstile> f}";
apply(induct_tac f);
apply(auto simp add: EF_lemma equalityI[OF AF_lemma1 AF_lemma2]);
done

text{*

The above language is not quite CTL\@. The latter also includes an
until-operator @{term"EU f g"} with semantics ``there exist a path
where @{term f} is true until @{term g} becomes true''. With the help
of an auxiliary function
*}

consts until:: "state set \<Rightarrow> state set \<Rightarrow> state \<Rightarrow> state list \<Rightarrow> bool"
primrec
"until A B s []    = (s \<in> B)"
"until A B s (t#p) = (s \<in> A \<and> (s,t) \<in> M \<and> until A B t p)"
(*<*)constdefs
 eusem :: "state set \<Rightarrow> state set \<Rightarrow> state set"
"eusem A B \<equiv> {s. \<exists>p. until A B s p}"(*>*)

text{*\noindent
the semantics of @{term EU} is straightforward:
@{text[display]"s \<Turnstile> EU f g = (\<exists>p. until A B s p)"}
Note that @{term EU} is not definable in terms of the other operators!

Model checking @{term EU} is again a least fixed point construction:
@{text[display]"mc(EU f g) = lfp(\<lambda>T. mc g \<union> mc f \<inter> (M^-1 ^^ T))"}

\begin{exercise}
Extend the datatype of formulae by the above until operator
and prove the equivalence between semantics and model checking, i.e.\ that
@{prop[display]"mc(EU f g) = {s. s \<Turnstile> EU f g}"}
%For readability you may want to annotate {term EU} with its customary syntax
%{text[display]"| EU formula formula    E[_ U _]"}
%which enables you to read and write {text"E[f U g]"} instead of {term"EU f g"}.
\end{exercise}
For more CTL exercises see, for example, \cite{Huth-Ryan-book}.
*}

(*<*)
constdefs
 eufix :: "state set \<Rightarrow> state set \<Rightarrow> state set \<Rightarrow> state set"
"eufix A B T \<equiv> B \<union> A \<inter> (M^-1 ^^ T)"

lemma "lfp(eufix A B) \<subseteq> eusem A B"
apply(rule lfp_lowerbound)
apply(clarsimp simp add:eusem_def eufix_def);
apply(erule disjE);
 apply(rule_tac x = "[]" in exI);
 apply simp
apply(clarsimp);
apply(rule_tac x = "y#xc" in exI);
apply simp;
done

lemma mono_eufix: "mono(eufix A B)";
apply(simp add: mono_def eufix_def);
apply blast;
done

lemma "eusem A B \<subseteq> lfp(eufix A B)";
apply(clarsimp simp add:eusem_def);
apply(erule rev_mp);
apply(rule_tac x = x in spec);
apply(induct_tac p);
 apply(rule ssubst[OF lfp_unfold[OF mono_eufix]]);
 apply(simp add:eufix_def);
apply(clarsimp);
apply(rule ssubst[OF lfp_unfold[OF mono_eufix]]);
apply(simp add:eufix_def);
apply blast;
done

(*
constdefs
 eusem :: "state set \<Rightarrow> state set \<Rightarrow> state set"
"eusem A B \<equiv> {s. \<exists>p\<in>Paths s. \<exists>j. p j \<in> B \<and> (\<forall>i < j. p i \<in> A)}"

axioms
M_total: "\<exists>t. (s,t) \<in> M"

consts apath :: "state \<Rightarrow> (nat \<Rightarrow> state)"
primrec
"apath s 0 = s"
"apath s (Suc i) = (SOME t. (apath s i,t) \<in> M)"

lemma [iff]: "apath s \<in> Paths s";
apply(simp add:Paths_def);
apply(blast intro: M_total[THEN someI_ex])
done

constdefs
 pcons :: "state \<Rightarrow> (nat \<Rightarrow> state) \<Rightarrow> (nat \<Rightarrow> state)"
"pcons s p == \<lambda>i. case i of 0 \<Rightarrow> s | Suc j \<Rightarrow> p j"

lemma pcons_PathI: "[| (s,t) : M; p \<in> Paths t |] ==> pcons s p \<in> Paths s";
by(simp add:Paths_def pcons_def split:nat.split);

lemma "lfp(eufix A B) \<subseteq> eusem A B"
apply(rule lfp_lowerbound)
apply(clarsimp simp add:eusem_def eufix_def);
apply(erule disjE);
 apply(rule_tac x = "apath x" in bexI);
  apply(rule_tac x = 0 in exI);
  apply simp;
 apply simp;
apply(clarify);
apply(rule_tac x = "pcons xb p" in bexI);
 apply(rule_tac x = "j+1" in exI);
 apply (simp add:pcons_def split:nat.split);
apply (simp add:pcons_PathI)
done
*)
(*>*)
text{*
Let us close this section with a few words about the executability of our model checkers.
It is clear that if all sets are finite, they can be represented as lists and the usual
set operations are easily implemented. Only @{term lfp} requires a little thought.
Fortunately the HOL library proves that in the case of finite sets and a monotone @{term F},
@{term"lfp F"} can be computed by iterated application of @{term F} to @{term"{}"} until
a fixed point is reached. It is actually possible to generate executable functional programs
from HOL definitions, but that is beyond the scope of the tutorial.
*}
(*<*)end(*>*)
