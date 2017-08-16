use "net"

class IRCMessageHandler
  fun handle_command(command: String): (String | None) =>
    try
      let command_parts = recover val command.split(" ") end
      let command_verb = command_parts(0) ?
      let command_args = recover val command_parts.slice(1) end
      _handle(command_verb, command_args)
    else
      // This should never happen because there should be at least one element,
      // even if it is an empty string.
      None
    end

  fun _handle(command: String, command_args: Array[String] val): (String | None) =>
    None

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
  let _irc_message_handler: IRCMessageHandler = IRCMessageHandler

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
        let response = _irc_message_handler.handle_command(nc)
        match response
        | let r: String =>
          _out.print("Response:" + r)
        else
          _out.print("No response")
        end
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
