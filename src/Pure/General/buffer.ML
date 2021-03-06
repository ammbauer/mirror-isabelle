(*  Title:      Pure/General/buffer.ML
    Author:     Makarius

Scalable text buffers.
*)

signature BUFFER =
sig
  type T
  val empty: T
  val is_empty: T -> bool
  val content: T -> string
  val add: string -> T -> T
  val output: T -> (string -> unit) -> unit
  val markup: Markup.T -> (T -> T) -> T -> T
end;

structure Buffer: BUFFER =
struct

abstype T = Buffer of string list
with

val empty = Buffer [];

fun is_empty (Buffer xs) = null xs;

fun add "" buf = buf
  | add x (Buffer xs) = Buffer (x :: xs);

fun content (Buffer xs) = implode (rev xs);

fun output (Buffer xs) out = List.app out (rev xs);

end;

fun markup m body =
  let val (bg, en) = Markup.output m
  in add bg #> body #> add en end;

end;
