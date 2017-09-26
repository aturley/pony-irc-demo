use "net"
use "debug"

trait val IRCCommand
  fun command_string(): String

class val Nick is IRCCommand
  let _nick: String

  new val create(nick: String) =>
    _nick = nick

  fun command_string(): String =>
    "NICK " + _nick + "\r\n"

class val ChangeNick is IRCCommand
  let _nick: String
  let _old_nick: String

  new val create(nick: String, old_nick: String) =>
    _nick = nick
    _old_nick = old_nick

  fun command_string(): String =>
    ":" + _old_nick + " NICK " + _nick + "\r\n"

class val User is IRCCommand
  let _client: String
  let _real_name: String

  new val create(client: String, real_name: String) =>
    _client = client
    _real_name = real_name

  fun command_string(): String =>
    "USER " + _client + " 0 * " + ":" + _real_name  + "\r\n"

class val Pong is IRCCommand
  let _server: String

  new val create(server: String) =>
    _server = server

  fun command_string(): String =>
    "PONG " + _server + "\r\n"

class val Join is IRCCommand
  let _channel: String

  new val create(channel: String) =>
    _channel = channel

  fun command_string(): String =>
    "JOIN :#" + _channel + "\r\n"

class val PrivMsg is IRCCommand
  let _channel: String
  let _message: String

  new val create(channel: String, message: String) =>
    _channel = channel
    _message = message

  fun command_string(): String =>
    "PRIVMSG #" + _channel + " :" + _message + "\r\n"

primitive IRCCommandFactory
  fun nick(n: String, old_nick: (None | String) = None): IRCCommand =>
    match old_nick
    | let s: String =>
      ChangeNick(n, s)
    else
      Nick(n)
    end

  fun user(real_name: String, client: String = "pony_client"): IRCCommand =>
    User(real_name, client)

  fun pong(server: String): IRCCommand =>
    Pong(server)

  fun join(channel: String): IRCCommand =>
    Join(channel)

  fun privmsg(channel: String, message: String): IRCCommand =>
    PrivMsg(channel, message)

trait IRCMessageHandler
  fun ref connected(conn: IRCConnection) =>
    None

  fun ref join(conn: IRCConnection, prefix: String, args: Array[String] val) =>
    None

  fun ref privmsg(conn: IRCConnection, prefix: String, args: Array[String] val) =>
    None

  fun ref ping(conn: IRCConnection, prefix: String, args: Array[String] val) =>
    try
      conn.send(IRCCommandFactory.pong(args(0) ?))
    else
      None
    end

class IRCMessageProcessor
  let _handler: IRCMessageHandler

  new create(handler: IRCMessageHandler) =>
    _handler = handler

  fun ref connected(conn: IRCConnection tag): (String | None) =>
    _handler.connected(conn)

  fun ref process_command(command: String,
    irc_connection: IRCConnection): (String | None)
  =>
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

    _process(command_prefix, command_verb, command_args, command,
      irc_connection)

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
    command_args: Array[String] val, full: String,
    irc_connection: IRCConnection):
    (String | None)
  =>
    match command
    | "JOIN" =>
      _handler.join(irc_connection, prefix, command_args)
    | "PRIVMSG" =>
      _handler.privmsg(irc_connection, prefix, command_args)
    | "PING" =>
      _handler.ping(irc_connection, prefix, command_args)
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

actor IRCConnection
  let _tcp_connection: TCPConnection

  new create(auth: AmbientAuth, irc_message_handler: IRCMessageHandler iso,
    host: String, port: String)
  =>
    _tcp_connection = TCPConnection(auth,
      recover IRCTCPConnectionNotify(this, consume irc_message_handler) end,
      "irc.freenode.net", "6667")

  be send(c: IRCCommand) =>
    _tcp_connection.write(c.command_string())

class IRCTCPConnectionNotify is TCPConnectionNotify
  let _irc_parser: IRCParser = IRCParser
  let _irc_message_processor: IRCMessageProcessor
  let _irc_connection: IRCConnection

  new create(irc_connection: IRCConnection,
    message_handler: IRCMessageHandler iso)
  =>
    _irc_message_processor = IRCMessageProcessor(consume message_handler)
    _irc_connection = irc_connection

  fun ref connected(conn: TCPConnection ref) =>
    Debug("Init: ")
    _irc_message_processor.connected(_irc_connection)

  fun ref received(
    conn: TCPConnection ref,
    data: Array[U8] iso,
    times: USize)
    : Bool
  =>
    Debug("got something")
    _irc_parser.add(consume data)
    try
      while true do
        let nc = _irc_parser.next_command() ?
        Debug("Command: " + nc)
        _irc_message_processor.process_command(nc, _irc_connection)
      end
    end
    true

  fun ref connect_failed(conn: TCPConnection ref) =>
    None
