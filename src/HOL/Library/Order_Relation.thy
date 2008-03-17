(*  ID          : $Id$
    Author      : Tobias Nipkow
*)

header {* Orders as Relations *}

theory Order_Relation
imports ATP_Linkup Hilbert_Choice
begin

text{* This prelude could be moved to theory Relation: *}

definition "irrefl r \<equiv> \<forall>x. (x,x) \<notin> r"

definition "total_on A r \<equiv> \<forall>x\<in>A.\<forall>y\<in>A. x\<noteq>y \<longrightarrow> (x,y)\<in>r \<or> (y,x)\<in>r"

abbreviation "total \<equiv> total_on UNIV"


lemma total_on_empty[simp]: "total_on {} r"
by(simp add:total_on_def)

lemma refl_on_converse[simp]: "refl A (r^-1) = refl A r"
by(auto simp add:refl_def)

lemma total_on_converse[simp]: "total_on A (r^-1) = total_on A r"
by (auto simp: total_on_def)

lemma irrefl_diff_Id[simp]: "irrefl(r-Id)"
by(simp add:irrefl_def)

declare [[simp_depth_limit = 2]]
lemma trans_diff_Id: " trans r \<Longrightarrow> antisym r \<Longrightarrow> trans (r-Id)"
by(simp add: antisym_def trans_def) blast
declare [[simp_depth_limit = 50]]

lemma total_on_diff_Id[simp]: "total_on A (r-Id) = total_on A r"
by(simp add: total_on_def)


subsection{* Orders on a set *}

definition "preorder_on A r \<equiv> refl A r \<and> trans r"

definition "partial_order_on A r \<equiv> preorder_on A r \<and> antisym r"

definition "linear_order_on A r \<equiv> partial_order_on A r \<and> total_on A r"

definition "strict_linear_order_on A r \<equiv> trans r \<and> irrefl r \<and> total_on A r"

definition "well_order_on A r \<equiv> linear_order_on A r \<and> wf(r - Id)"

lemmas order_on_defs =
  preorder_on_def partial_order_on_def linear_order_on_def
  strict_linear_order_on_def well_order_on_def


lemma preorder_on_empty[simp]: "preorder_on {} {}"
by(simp add:preorder_on_def trans_def)

lemma partial_order_on_empty[simp]: "partial_order_on {} {}"
by(simp add:partial_order_on_def)

lemma lnear_order_on_empty[simp]: "linear_order_on {} {}"
by(simp add:linear_order_on_def)

lemma well_order_on_empty[simp]: "well_order_on {} {}"
by(simp add:well_order_on_def)


lemma preorder_on_converse[simp]: "preorder_on A (r^-1) = preorder_on A r"
by (simp add:preorder_on_def)

lemma partial_order_on_converse[simp]:
  "partial_order_on A (r^-1) = partial_order_on A r"
by (simp add: partial_order_on_def)

lemma linear_order_on_converse[simp]:
  "linear_order_on A (r^-1) = linear_order_on A r"
by (simp add: linear_order_on_def)


lemma strict_linear_order_on_diff_Id:
  "linear_order_on A r \<Longrightarrow> strict_linear_order_on A (r-Id)"
by(simp add: order_on_defs trans_diff_Id)


subsection{* Orders on the field *}

abbreviation "Refl r \<equiv> refl (Field r) r"

abbreviation "Preorder r \<equiv> preorder_on (Field r) r"

abbreviation "Partial_order r \<equiv> partial_order_on (Field r) r"

abbreviation "Total r \<equiv> total_on (Field r) r"

abbreviation "Linear_order r \<equiv> linear_order_on (Field r) r"

abbreviation "Well_order r \<equiv> well_order_on (Field r) r"


lemma subset_Image_Image_iff:
  "\<lbrakk> Preorder r; A \<subseteq> Field r; B \<subseteq> Field r\<rbrakk> \<Longrightarrow>
   r `` A \<subseteq> r `` B \<longleftrightarrow> (\<forall>a\<in>A.\<exists>b\<in>B. (b,a):r)"
apply(auto simp add:subset_def preorder_on_def refl_def Image_def)
apply metis
by(metis trans_def)

lemma subset_Image1_Image1_iff:
  "\<lbrakk> Preorder r; a : Field r; b : Field r\<rbrakk> \<Longrightarrow> r `` {a} \<subseteq> r `` {b} \<longleftrightarrow> (b,a):r"
by(simp add:subset_Image_Image_iff)

lemma Refl_antisym_eq_Image1_Image1_iff:
  "\<lbrakk>Refl r; antisym r; a:Field r; b:Field r\<rbrakk> \<Longrightarrow> r `` {a} = r `` {b} \<longleftrightarrow> a=b"
by(simp add: expand_set_eq antisym_def refl_def) metis

lemma Partial_order_eq_Image1_Image1_iff:
  "\<lbrakk>Partial_order r; a:Field r; b:Field r\<rbrakk> \<Longrightarrow> r `` {a} = r `` {b} \<longleftrightarrow> a=b"
by(auto simp:order_on_defs Refl_antisym_eq_Image1_Image1_iff)


subsection{* Orders on a type *}

abbreviation "strict_linear_order \<equiv> strict_linear_order_on UNIV"

abbreviation "linear_order \<equiv> linear_order_on UNIV"

abbreviation "well_order r \<equiv> well_order_on UNIV"

end
