(*  Title:      HOLCF/Porder0.thy
    ID:         $Id$
    Author:     Franz Regensburger

Definition of class porder (partial order).
*)

Porder0 = Main +

	(* introduce a (syntactic) class for the constant << *)
axclass sq_ord < type

	(* characteristic constant << for po *)
consts
  "<<"          :: "['a,'a::sq_ord] => bool"        (infixl 55)

syntax (xsymbols)
  "op <<"       :: "['a,'a::sq_ord] => bool"        (infixl "\\<sqsubseteq>" 55)

axclass po < sq_ord
        (* class axioms: *)
refl_less       "x << x"        
antisym_less    "[|x << y; y << x |] ==> x = y"    
trans_less      "[|x << y; y << z |] ==> x << z"
 
end 


