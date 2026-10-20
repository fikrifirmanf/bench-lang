(* A minimal HTTP/1.1 server (one thread per connection) and a pool of keep-alive client threads, on the Unix
   library. Each client POSTs {"value": i}; the server answers with the value, and the client sums the answers. *)
let clients = 32

(* Reads one message (headers, then Content-Length bytes of body) and returns its body. *)
let read_message ic =
  let length = ref 0 in
  let rec headers () =
    let line = input_line ic in
    let line = if String.ends_with ~suffix:"\r" line then String.sub line 0 (String.length line - 1) else line in
    if line <> "" then begin
      (match String.index_opt line ':' with
      | Some i when String.lowercase_ascii (String.sub line 0 i) = "content-length" ->
          length := int_of_string (String.trim (String.sub line (i + 1) (String.length line - i - 1)))
      | _ -> ());
      headers ()
    end
  in
  headers ();
  really_input_string ic !length

let value_field = Str.regexp "\"value\"[ ]*:[ ]*\\(-?[0-9]+\\)"

(* Str keeps match state globally, so callers on different threads take this lock first. *)
let str_lock = Mutex.create ()

let parse_value body =
  Mutex.protect str_lock (fun () ->
      ignore (Str.search_forward value_field body 0);
      int_of_string (Str.matched_group 1 body))

let serve_connection fd =
  let ic = Unix.in_channel_of_descr fd and oc = Unix.out_channel_of_descr fd in
  (try
     while true do
       let answer = string_of_int (parse_value (read_message ic)) in
       Printf.fprintf oc "HTTP/1.1 200 OK\r\nContent-Length: %d\r\n\r\n%s" (String.length answer) answer;
       flush oc
     done
   with End_of_file | Sys_error _ | Unix.Unix_error _ -> ());
  (try Unix.close fd with Unix.Unix_error _ -> ())

let rec connect port =
  let fd = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  try
    Unix.connect fd (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
    Unix.setsockopt fd Unix.TCP_NODELAY true;
    fd
  with Unix.Unix_error _ ->
    Unix.close fd;
    Thread.delay 0.001;
    connect port

let () =
  let total = try int_of_string Sys.argv.(1) with _ -> 10 in
  let listener = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt listener Unix.SO_REUSEADDR true;
  Random.self_init ();
  let rec bind () =
    let port = 20000 + Random.int 30000 in
    try
      Unix.bind listener (Unix.ADDR_INET (Unix.inet_addr_loopback, port));
      port
    with Unix.Unix_error _ -> bind ()
  in
  let port = bind () in
  Unix.listen listener 512;
  ignore
    (Thread.create
       (fun () ->
         while true do
           let fd, _ = Unix.accept listener in
           ignore (Thread.create serve_connection fd)
         done)
       ());
  let lock = Mutex.create () in
  let next_value = ref 1 and sum = ref 0 in
  let take () =
    Mutex.protect lock (fun () ->
        let v = !next_value in
        incr next_value;
        v)
  in
  let open_connection () =
    let fd = connect port in
    (fd, Unix.in_channel_of_descr fd, Unix.out_channel_of_descr fd)
  in
  let client () =
    let conn = ref (open_connection ()) in
    let mine = ref 0 in
    let rec loop () =
      let value = take () in
      if value <= total then begin
        let payload = Printf.sprintf "{\"value\":%d}" value in
        let request =
          Printf.sprintf "POST / HTTP/1.1\r\nHost: localhost:%d\r\nContent-Type: application/json\r\nContent-Length: %d\r\n\r\n%s"
            port (String.length payload) payload
        in
        let rec attempt () =
          let fd, ic, oc = !conn in
          try
            output_string oc request;
            flush oc;
            mine := !mine + int_of_string (read_message ic)
          with End_of_file | Sys_error _ | Unix.Unix_error _ ->
            (try Unix.close fd with Unix.Unix_error _ -> ());
            conn := open_connection ();
            attempt ()
        in
        attempt ();
        loop ()
      end
    in
    loop ();
    let fd, _, _ = !conn in
    Unix.close fd;
    Mutex.protect lock (fun () -> sum := !sum + !mine)
  in
  let threads = List.init clients (fun _ -> Thread.create client ()) in
  List.iter Thread.join threads;
  Printf.printf "%d\n" !sum
