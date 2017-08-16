use "net"

class IRCMessageHandler
  let _nick: String
  let _channel: String
  var _my_full_name: String = ""

  new create(nick: String, channel: String) =>
    _nick = nick
    _channel = channel

  fun init(): String =>
    "NICK " + _nick + "\r\n"
      + "USER pony_client 0 * :SoAndSo WhateverWhatever\r\n"
      + "JOIN :#" + _channel + "\r\n"

  fun ref handle_command(command: String): (String | None) =>
    let command_parts = recover val command.split(" ") end

    let has_prefix = try command_parts(0) ? (0) ? == ':' else false end
    (let command_prefix: String, let command_verb: String) =
      if has_prefix then
        (try command_parts(0) ? else "" end, try command_parts(1) ? else "" end)
      else
        ("", try command_parts(0) ? else "" end)
      end
    let command_args = if has_prefix then
      recover val command_parts.slice(2) end
    else
      recover val command_parts.slice(1) end
    end

    _handle(command_prefix, command_verb, command_args, command)

  fun ref _handle(prefix: String, command: String, command_args: Array[String] val, full: String): (String | None) =>
    match command
    | "JOIN" =>
      _my_full_name = prefix
    | "PRIVMSG" =>
      if full.contains(_nick) then
        "PRIVMSG #" + _channel + " :life is suffering and pain\r\n"
      end
    | "PING" =>
      "PONG " + try command_args(0) ? else "" end+ "\r\n"
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
  let _irc_message_handler: IRCMessageHandler

  new create(out: OutStream, nick: String, channel: String) =>
    _irc_message_handler = IRCMessageHandler(nick, channel)
    _out = out

  fun ref connected(conn: TCPConnection ref) =>
    let resp = _irc_message_handler.init()
    _out.print("Init: " + resp)
    conn.write(resp)

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

actor Main
  new create(env: Env) =>
    try
      let nick = env.args(1) ?
      let channel = env.args(2) ?
      TCPConnection(env.root as AmbientAuth,
        recover MyTCPConnectionNotify(env.out, nick, channel) end, "irc.freenode.net", "6667")
    end
