use "net"

class MyTCPConnectionNotify is TCPConnectionNotify
  let _out: OutStream

  new create(out: OutStream) =>
    _out = out

  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8] iso,
    times: USize)
    : Bool
  =>
    _out.print(String.from_array(consume data))
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    None

class MyTCPListenNotify is TCPListenNotify
  let _out: OutStream

  new create(out: OutStream) =>
    _out = out

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ =>
    _out.print("received connection")
    recover iso MyTCPConnectionNotify(_out) end

  fun ref not_listening(listen: TCPListener ref) =>
    None

actor Main
  new create(env: Env) =>
    try
      TCPListener(env.root as AmbientAuth,
        recover MyTCPListenNotify(env.out) end, "", "6667")
    end
