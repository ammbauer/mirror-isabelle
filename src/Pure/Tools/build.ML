(*  Title:      Pure/Tools/build.ML
    Author:     Makarius

Build Isabelle sessions.
*)

signature BUILD =
sig
  val build: string -> unit
end;

structure Build: BUILD =
struct

(* command timings *)

type timings = ((string * Time.time) Inttab.table) Symtab.table;  (*file -> offset -> name, time*)

val empty_timings: timings = Symtab.empty;

fun update_timings props =
  (case Markup.parse_command_timing_properties props of
    SOME ({file, offset, name}, time) =>
      Symtab.map_default (file, Inttab.empty)
        (Inttab.map_default (offset, (name, time)) (fn (_, t) => (name, t + time)))
  | NONE => I);

fun approximative_id name pos =
  (case (Position.file_of pos, Position.offset_of pos) of
    (SOME file, SOME offset) =>
      if name = "" then NONE else SOME {file = file, offset = offset, name = name}
  | _ => NONE);

fun get_timings timings tr =
  (case approximative_id (Toplevel.name_of tr) (Toplevel.pos_of tr) of
    SOME {file, offset, name} =>
      (case Symtab.lookup timings file of
        SOME offsets =>
          (case Inttab.lookup offsets offset of
            SOME (name', time) => if name = name' then SOME time else NONE
          | NONE => NONE)
      | NONE => NONE)
  | NONE => NONE)
  |> the_default Time.zeroTime;


(* session timing *)

fun session_timing f x =
  let
    val start = Timing.start ();
    val y = f x;
    val timing = Timing.result start;

    val threads = string_of_int (Multithreading.max_threads ());
    val props = [("threads", threads)] @ Markup.timing_properties timing;
    val _ = Output.protocol_message (Markup.session_timing :: props) [];
  in y end;


(* protocol messages *)

fun protocol_message props output =
  (case props of
    function :: args =>
      if function = Markup.ML_statistics orelse function = Markup.task_statistics then
        Protocol_Message.marker (#2 function) args
      else if function = Markup.command_timing then
        let
          val name = the_default "" (Properties.get args Markup.nameN);
          val pos = Position.of_properties args;
          val {elapsed, ...} = Markup.parse_timing_properties args;
          val is_significant =
            Timing.is_relevant_time elapsed andalso
            elapsed >= Options.default_seconds "command_timing_threshold";
        in
          if is_significant then
            (case approximative_id name pos of
              SOME id =>
                Protocol_Message.marker (#2 function)
                  (Markup.command_timing_properties id elapsed)
            | NONE => ())
          else ()
        end
      else if function = Markup.theory_timing orelse function = Markup.session_timing then
        Protocol_Message.marker (#2 function) args
      else
        (case Markup.dest_loading_theory props of
          SOME name => Protocol_Message.marker_text "loading_theory" name
        | NONE => Export.protocol_message props output)
  | [] => raise Output.Protocol_Message props);


(* build theories *)

fun build_theories symbols bibtex_entries last_timing qualifier master_dir (options, thys) =
  let
    val context =
      {options = options, symbols = symbols, bibtex_entries = bibtex_entries,
        last_timing = last_timing};
    val condition = space_explode "," (Options.string options "condition");
    val conds = filter_out (can getenv_strict) condition;
  in
    if null conds then
      (Options.set_default options;
        Isabelle_Process.init_options ();
        Future.fork I;
        (Thy_Info.use_theories context qualifier master_dir
        |>
          (case Options.string options "profiling" of
            "" => I
          | "time" => profile_time
          | "allocations" => profile_allocations
          | bad => error ("Bad profiling option: " ^ quote bad))
        |> Unsynchronized.setmp print_mode
            (space_explode "," (Options.string options "print_mode") @ print_mode_value ())) thys)
    else
      Output.physical_stderr ("Skipping theories " ^ commas_quote (map #1 thys) ^
        " (undefined " ^ commas conds ^ ")\n")
  end;


(* build session *)

datatype args = Args of
 {pide: bool,
  symbol_codes: (string * int) list,
  command_timings: Properties.T list,
  verbose: bool,
  browser_info: Path.T,
  document_files: (Path.T * Path.T) list,
  graph_file: Path.T,
  parent_name: string,
  chapter: string,
  session_name: string,
  master_dir: Path.T,
  theories: (Options.T * (string * Position.T) list) list,
  session_positions: (string * Properties.T) list,
  session_directories: (string * string) list,
  doc_names: string list,
  global_theories: (string * string) list,
  loaded_theories: string list,
  bibtex_entries: string list};

fun decode_args pide yxml =
  let
    open XML.Decode;
    val position = Position.of_properties o properties;
    val (symbol_codes, (command_timings, (verbose, (browser_info,
      (document_files, (graph_file, (parent_name, (chapter, (session_name, (master_dir,
      (theories, (session_positions, (session_directories, (doc_names, (global_theories,
      (loaded_theories, bibtex_entries)))))))))))))))) =
      pair (list (pair string int)) (pair (list properties) (pair bool (pair string
        (pair (list (pair string string)) (pair string (pair string (pair string (pair string
          (pair string
            (pair (((list (pair Options.decode (list (pair string position))))))
              (pair (list (pair string properties))
                (pair (list (pair string string)) (pair (list string)
                  (pair (list (pair string string)) (pair (list string) (list string))))))))))))))))
      (YXML.parse_body yxml);
  in
    Args {pide = pide, symbol_codes = symbol_codes, command_timings = command_timings,
      verbose = verbose, browser_info = Path.explode browser_info,
      document_files = map (apply2 Path.explode) document_files,
      graph_file = Path.explode graph_file, parent_name = parent_name, chapter = chapter,
      session_name = session_name, master_dir = Path.explode master_dir, theories = theories,
      session_positions = session_positions, session_directories = session_directories,
      doc_names = doc_names, global_theories = global_theories, loaded_theories = loaded_theories,
      bibtex_entries = bibtex_entries}
  end;

fun build_session (Args {pide, symbol_codes, command_timings, verbose, browser_info, document_files,
    graph_file, parent_name, chapter, session_name, master_dir, theories, session_positions,
    session_directories, doc_names, global_theories, loaded_theories, bibtex_entries}) =
  let
    val symbols = HTML.make_symbols symbol_codes;

    val _ =
      Resources.init_session
        {pide = pide,
         session_positions = session_positions,
         session_directories = session_directories,
         docs = doc_names,
         global_theories = global_theories,
         loaded_theories = loaded_theories};

    val _ =
      Session.init
        symbols
        (Options.default_bool "browser_info")
        browser_info
        (Options.default_string "document")
        (Options.default_string "document_output")
        (Present.document_variants (Options.default ()))
        document_files
        graph_file
        parent_name
        (chapter, session_name)
        verbose;

    val last_timing = get_timings (fold update_timings command_timings empty_timings);

    val res1 =
      theories |>
        (List.app (build_theories symbols bibtex_entries last_timing session_name master_dir)
          |> session_timing
          |> Exn.capture);
    val res2 = Exn.capture Session.finish ();

    val _ = Resources.finish_session_base ();
    val _ = Par_Exn.release_all [res1, res2];
    val _ =
      if session_name = Context.PureN
      then Theory.install_pure (Thy_Info.get_theory Context.PureN) else ();
  in () end;


(* command-line tool *)

fun inline_errors exn =
  Runtime.exn_message_list exn
  |> List.app (fn msg => Protocol_Message.marker_text "error_message" (YXML.content_of msg));

fun build args_file =
  let
    val _ = SHA1.test_samples ();
    val _ = Options.load_default ();
    val _ = Isabelle_Process.init_options ();
    val args = decode_args false (File.read (Path.explode args_file));
    val _ =
      Unsynchronized.setmp Private_Output.protocol_message_fn protocol_message
        build_session args
      handle exn => (inline_errors exn; Exn.reraise exn);
    val _ = Private_Output.protocol_message_fn := Output.protocol_message_undefined;
    val _ = Options.reset_default ();
  in () end;


(* PIDE version *)

val _ =
  Isabelle_Process.protocol_command "build_session"
    (fn [args_yxml] =>
        let
          val args = decode_args true args_yxml;
          fun exec e =
            if can Theory.get_pure () then
              Isabelle_Thread.fork
                {name = "build_session", stack_limit = Isabelle_Thread.stack_limit (),
                  interrupts = false} e
              |> ignore
            else e ();
        in
          exec (fn () =>
            (Future.interruptible_task (fn () => (build_session args; (0, []))) () handle exn =>
              ((1, Runtime.exn_message_list exn) handle _ (*sic!*) => (2, ["CRASHED"])))
          |> let open XML.Encode in pair int (list string) end
          |> Output.protocol_message Markup.build_session_finished)
        end
      | _ => raise Match);

end;
