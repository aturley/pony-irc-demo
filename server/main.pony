use "net"

class IRCParser
  var _current_buffer: String ref = String

  fun ref add(data: Array[U8] val) =>
    _current_buffer.append(data)

  fun ref next_command(): String ? =>
    let eom = _current_buffer.find("\r\n") ?
    let command: String iso = _current_buffer.substring(0, eom)
    _current_buffer = _current_buffer.substring(eom + 2)
    consume command

class MyTCPConnectionNotify is TCPConnectionNotify
  let _out: OutStream
  let _irc_parser: IRCParser = IRCParser

  new create(out: OutStream) =>
    _out = out

  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8] iso,
    times: USize)
    : Bool
  =>
    _out.print("got something")
    _irc_parser.add(consume data)
    try
      while true do
        let nc = _irc_parser.next_command() ?
        _out.print("Command: " + nc)
      end
    end
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
