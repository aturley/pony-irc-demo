use "net"
use "debug"

primitive IRCCommand
  fun nick(n: String, old_nick: (None | String) = None): String =>
    let prefix = match old_nick
      | let s: String => ":" + s + " "
      else
        ""
      end
    prefix + "NICK " + n + "\r\n"

  fun user(real_name: String, client: String = "pony_client"): String =>
    "USER " + client + " 0 * " + ":" + real_name  + "\r\n"

  fun pong(server: String): String =>
    "PONG " + server + "\r\n"

  fun join(channel: String): String =>
    "JOIN :#" + channel + "\r\n"

  fun privmsg(channel: String, message: String): String =>
    "PRIVMSG #" + channel + " :" + message + "\r\n"

trait IRCMessageHandler
  fun ref connected(conn: TCPConnection tag): (String | None) =>
    None

  fun ref join(conn: TCPConnection tag, prefix: String, args: Array[String] val): (String | None) =>
    None

  fun ref privmsg(conn: TCPConnection tag, prefix: String, args: Array[String] val): (String | None) =>
    None

  fun ref ping(conn: TCPConnection tag, prefix: String, args: Array[String] val): (String | None) =>
    try
      IRCCommand.pong(args(0) ?)
    else
      None
    end

class IRCMessageProcessor
  let _handler: IRCMessageHandler

  new create(handler: IRCMessageHandler) =>
    _handler = handler

  fun ref connected(conn: TCPConnection tag): (String | None) =>
    _handler.connected(conn)

  fun ref process_command(command: String, conn: TCPConnection tag): (String | None) =>
    let command_parts = recover val command.split(" ") end

    let has_prefix = try command_parts(0) ? (0) ? == ':' else false end
    (let command_prefix: String, let command_verb: String) =
      if has_prefix then
        (try command_parts(0) ? else "" end, try command_parts(1) ? else "" end)
      else
        ("", try command_parts(0) ? else "" end)
      end
    let command_args = _reconstruct_args(
      if has_prefix then
        recover val command_parts.slice(2) end
      else
        recover val command_parts.slice(1) end
      end)

    _process(command_prefix, command_verb, command_args, command, conn)

  fun _reconstruct_args(args: Array[String] val): Array[String] val =>
    let r_args = recover iso Array[String] end

    for (i, arg) in args.pairs() do
      if (try arg(0) ? else ' ' end) == ':' then
        let rest = " ".join(args.slice(i).values())
        // strip off the ":" and put it in the list
        r_args.push(rest.substring(1))
        break
      else
        r_args.push(arg)
      end
    end

    consume r_args

  fun ref _process(prefix: String, command: String,
    command_args: Array[String] val, full: String, conn: TCPConnection tag):
    (String | None)
  =>
    match command
    | "JOIN" =>
      _handler.join(conn, prefix, command_args)
    | "PRIVMSG" =>
      _handler.privmsg(conn, prefix, command_args)
    | "PING" =>
      _handler.ping(conn, prefix, command_args)
    end

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
  let _irc_message_processor: IRCMessageProcessor

  new create(out: OutStream, message_handler: IRCMessageHandler iso) =>
    _irc_message_processor = IRCMessageProcessor(consume message_handler)
    _out = out

  fun ref connected(conn: TCPConnection ref) =>
    let resp = _irc_message_processor.connected(conn)
    _out.print("Init: ")
    match resp
    | let r: String =>
      _out.write(r)
      conn.write(r)
    else
      _out.write("No response")
    end

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
        let response = _irc_message_processor.process_command(nc, conn)
        match response
        | let r: String =>
          _out.print("Response: " + r)
          conn.write(r)
        else
          _out.print("No response")
        end
      end
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    None

class MyIRCMessageHandler is IRCMessageHandler
  let _nick: String
  let _join_channel: String

  new create(nick: String, join_channel: String) =>
    _nick = nick
    _join_channel = join_channel

  fun ref connected(conn: TCPConnection tag): (String | None) =>
    let commands = Array[String]
    commands.push(IRCCommand.nick(_nick))
    commands.push(IRCCommand.user("Pony Robot"))
    commands.push(IRCCommand.join(_join_channel))
    "".join(commands.values())

  fun ref privmsg(conn: TCPConnection tag, prefix: String, args: Array[String] val): (String | None) =>
    Debug("  PRIVMSG")
    Debug("    prefix: " + prefix)
    Debug("    args:")
    for (i, arg) in args.pairs() do
      Debug("      arg(" + i.string() + "): '" + arg + "'")
    end
    None

actor Main
  new create(env: Env) =>
    try
      let nick = env.args(1) ?
      let channel = env.args(2) ?
      TCPConnection(env.root as AmbientAuth,
        recover MyTCPConnectionNotify(env.out, recover iso MyIRCMessageHandler(nick, channel) end) end,
        "irc.freenode.net", "6667")
    end
