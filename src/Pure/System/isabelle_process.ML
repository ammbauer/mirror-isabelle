(*  Title:      Pure/System/isabelle_process.ML
    Author:     Makarius

Isabelle process wrapper.
*)

signature ISABELLE_PROCESS =
sig
  val is_active: unit -> bool
  exception STOP of int
  val protocol_command: string -> (string list -> unit) -> unit
  val reset_tracing: Document_ID.exec -> unit
  val crashes: exn list Synchronized.var
  val init_options: unit -> unit
  val init_options_interactive: unit -> unit
  val init: unit -> unit
  val init_build: unit -> unit
end;

structure Isabelle_Process: ISABELLE_PROCESS =
struct

(* print mode *)

val isabelle_processN = "isabelle_process";

fun is_active () = Print_Mode.print_mode_active isabelle_processN;

val _ = Output.add_mode isabelle_processN Output.default_output Output.default_escape;
val _ = Markup.add_mode isabelle_processN YXML.output_markup;

val protocol_modes1 = [Syntax_Trans.no_bracketsN, Syntax_Trans.no_type_bracketsN];
val protocol_modes2 = [isabelle_processN, Pretty.symbolicN];


(* protocol commands *)

exception STOP of int;

val is_protocol_exn = fn STOP _ => true | _ => false;

local

val commands =
  Synchronized.var "Isabelle_Process.commands"
    (Symtab.empty: (string list -> unit) Symtab.table);

in

fun protocol_command name cmd =
  Synchronized.change commands (fn cmds =>
   (if not (Symtab.defined cmds name) then ()
    else warning ("Redefining Isabelle protocol command " ^ quote name);
    Symtab.update (name, cmd) cmds));

fun run_command name args =
  (case Symtab.lookup (Synchronized.value commands) name of
    NONE => error ("Undefined Isabelle protocol command " ^ quote name)
  | SOME cmd =>
      (Runtime.exn_trace_system (fn () => cmd args)
        handle exn =>
          if is_protocol_exn exn then Exn.reraise exn
          else error ("Isabelle protocol command failure: " ^ quote name)));

end;


(* restricted tracing messages *)

val tracing_messages =
  Synchronized.var "tracing_messages" (Inttab.empty: int Inttab.table);

fun reset_tracing exec_id =
  Synchronized.change tracing_messages (Inttab.delete_safe exec_id);

fun update_tracing () =
  (case Position.parse_id (Position.thread_data ()) of
    NONE => ()
  | SOME exec_id =>
      let
        val ok =
          Synchronized.change_result tracing_messages (fn tab =>
            let
              val n = the_default 0 (Inttab.lookup tab exec_id) + 1;
              val limit = Options.default_int "editor_tracing_messages";
              val ok = limit <= 0 orelse n <= limit;
            in (ok, Inttab.update (exec_id, n) tab) end);
      in
        if ok then ()
        else
          let
            val (text, promise) = Active.dialog_text ();
            val _ =
              writeln ("Tracing paused.  " ^ text "Stop" ^ ", or continue with next " ^
                text "100" ^ ", " ^ text "1000" ^ ", " ^ text "10000" ^ " messages?")
            val m = Value.parse_int (Future.join promise)
              handle Fail _ => error "Stopped";
          in
            Synchronized.change tracing_messages
              (Inttab.map_default (exec_id, 0) (fn k => k - m))
          end
      end);


(* init protocol -- uninterruptible *)

val crashes = Synchronized.var "Isabelle_Process.crashes" ([]: exn list);

local

fun recover crash =
  (Synchronized.change crashes (cons crash);
    Output.physical_stderr
      "Recovered from Isabelle process crash -- see also Isabelle_Process.crashes\n");

in

fun init_protocol modes = Thread_Attributes.uninterruptible (fn _ => fn (address, password) =>
  let
    val _ = SHA1.test_samples ()
      handle exn as Fail msg => (Output.physical_stderr (msg ^ "\n"); Exn.reraise exn);

    val _ = Output.physical_stderr Symbol.STX;


    (* streams *)

    val (in_stream, out_stream) = Socket_IO.open_streams address;
    val _ = Byte_Message.write_line out_stream password;

    val _ = TextIO.StreamIO.setBufferMode (TextIO.getOutstream TextIO.stdOut, IO.LINE_BUF);
    val _ = TextIO.StreamIO.setBufferMode (TextIO.getOutstream TextIO.stdErr, IO.LINE_BUF);
    val _ = BinIO.StreamIO.setBufferMode (BinIO.getOutstream out_stream, IO.BLOCK_BUF);


    (* messages *)

    val msg_channel = Message_Channel.make out_stream;

    fun message name props body =
      Message_Channel.send msg_channel (Message_Channel.message name props body);

    fun standard_message props name ss =
      if forall (fn s => s = "") ss then ()
      else
        let
          val props' =
            (case (Properties.defined props Markup.idN, Position.get_id (Position.thread_data ())) of
              (false, SOME id') => props @ [(Markup.idN, id')]
            | _ => props);
        in message name props' (XML.blob ss) end;

    fun report_message ss =
      if Context_Position.pide_reports ()
      then standard_message [] Markup.reportN ss else ();

    val serial_props = Markup.serial_properties o serial;

    val message_context =
      Unsynchronized.setmp Private_Output.status_fn (standard_message [] Markup.statusN) #>
      Unsynchronized.setmp Private_Output.report_fn report_message #>
      Unsynchronized.setmp Private_Output.result_fn
        (fn props => fn s => standard_message (props @ serial_props ()) Markup.resultN s) #>
      Unsynchronized.setmp Private_Output.writeln_fn
        (fn s => standard_message (serial_props ()) Markup.writelnN s) #>
      Unsynchronized.setmp Private_Output.state_fn
        (fn s => standard_message (serial_props ()) Markup.stateN s) #>
      Unsynchronized.setmp Private_Output.information_fn
        (fn s => standard_message (serial_props ()) Markup.informationN s) #>
      Unsynchronized.setmp Private_Output.tracing_fn
        (fn s => (update_tracing (); standard_message (serial_props ()) Markup.tracingN s)) #>
      Unsynchronized.setmp Private_Output.warning_fn
        (fn s => standard_message (serial_props ()) Markup.warningN s) #>
      Unsynchronized.setmp Private_Output.legacy_fn
        (fn s => standard_message (serial_props ()) Markup.legacyN s) #>
      Unsynchronized.setmp Private_Output.error_message_fn
        (fn (i, s) => standard_message (Markup.serial_properties i) Markup.errorN s) #>
      Unsynchronized.setmp Private_Output.system_message_fn
        (fn ss => message Markup.systemN [] (XML.blob ss)) #>
      Unsynchronized.setmp Private_Output.protocol_message_fn
        (fn props => fn body => message Markup.protocolN props body) #>
      Unsynchronized.setmp print_mode
        ((! print_mode @ #1 modes) |> fold (update op =) (#2 modes));


    (* protocol *)

    fun protocol_loop () =
      let
        val _ =
          (case Byte_Message.read_message in_stream of
            NONE => raise STOP 0
          | SOME [] => Output.system_message "Isabelle process: no input"
          | SOME (name :: args) => run_command name args)
          handle exn =>
            if is_protocol_exn exn then Exn.reraise exn
            else (Runtime.exn_system_message exn handle crash => recover crash);
      in protocol_loop () end;

    fun protocol () =
     (Session.init_protocol_handlers ();
      message Markup.initN [] [XML.Text (Session.welcome ())];
      protocol_loop ());

    val result = Exn.capture (message_context protocol) ();


    (* shutdown *)

    val _ = Future.shutdown ();
    val _ = Execution.reset ();
    val _ = Message_Channel.shutdown msg_channel;
    val _ = BinIO.closeIn in_stream;
    val _ = BinIO.closeOut out_stream;

  in
    (case result of
      Exn.Exn (STOP rc) => if rc = 0 then () else exit rc
    | _ => Exn.release result)
  end);

end;


(* init options *)

fun init_options () =
 (ML_Print_Depth.set_print_depth (Options.default_int "ML_print_depth");
  Future.ML_statistics := Options.default_bool "ML_statistics";
  Multithreading.trace := Options.default_int "threads_trace";
  Multithreading.max_threads_update (Options.default_int "threads");
  Multithreading.parallel_proofs := Options.default_int "parallel_proofs";
  if Options.default_bool "export_standard_proofs" then Proofterm.proofs := 2 else ();
  let val proofs = Options.default_int "record_proofs"
  in if proofs < 0 then () else Proofterm.proofs := proofs end;
  Printer.show_markup_default := false);

fun init_options_interactive () =
 (init_options ();
  Multithreading.parallel_proofs := (if Options.default_int "parallel_proofs" > 0 then 3 else 0);
  Printer.show_markup_default := true);


(* generic init *)

fun init_modes modes =
  let
    val address = Options.default_string \<^system_option>\<open>system_channel_address\<close>;
    val password = Options.default_string \<^system_option>\<open>system_channel_password\<close>;
  in
    if address <> "" andalso password <> ""
    then init_protocol modes (address, password)
    else init_options ()
  end;

fun init () = init_modes (protocol_modes1, protocol_modes2);
fun init_build () = init_modes ([], protocol_modes2);

end;
