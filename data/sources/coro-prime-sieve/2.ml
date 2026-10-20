(* Prime sieve as a chain of generators built on OCaml 5 effect handlers: each generator runs until it
   performs Yield, and its handler keeps the continuation to resume on the next pull. 1.ml relies on an
   older domainslib channel API and now dies with an unhandled effect. *)
open Effect
open Effect.Deep

type _ Effect.t += Yield : int -> unit Effect.t

(* Turns a body that performs Yield into a function returning the next yielded value. *)
let generator (body : unit -> unit) : unit -> int =
  let resume = ref None and value = ref 0 in
  let handler =
    {
      retc = (fun () -> ());
      exnc = raise;
      effc =
        (fun (type a) (eff : a Effect.t) ->
          match eff with
          | Yield v ->
              Some
                (fun (k : (a, unit) continuation) ->
                  value := v;
                  resume := Some (fun () -> continue k ()))
          | _ -> None);
    }
  in
  fun () ->
    (match !resume with
    | None -> match_with body () handler
    | Some resume_body ->
        resume := None;
        resume_body ());
    !value

let generate () =
  let i = ref 2 in
  while true do
    perform (Yield !i);
    incr i
  done

let filter source prime () =
  while true do
    let v = source () in
    if v mod prime <> 0 then perform (Yield v)
  done

let () =
  let n = try int_of_string Sys.argv.(1) with _ -> 100 in
  let out = Buffer.create (n * 6) in
  let chain = ref (generator generate) in
  for _ = 1 to n do
    let prime = !chain () in
    Buffer.add_string out (string_of_int prime);
    Buffer.add_char out '\n';
    chain := generator (filter !chain prime)
  done;
  print_string (Buffer.contents out)
