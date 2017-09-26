use "net"
use "debug"

class MyIRCMessageHandler is IRCMessageHandler
  let _nick: String
  let _join_channel: String

  new create(nick: String, join_channel: String) =>
    _nick = nick
    _join_channel = join_channel

  fun ref connected(conn: IRCConnection) =>
    conn.send(IRCCommandFactory.nick(_nick))
    conn.send(IRCCommandFactory.user("Pony Robot"))
    conn.send(IRCCommandFactory.join(_join_channel))

  fun ref privmsg(conn: IRCConnection tag, prefix: String, args: Array[String] val) =>
    Debug("  PRIVMSG")
    Debug("    prefix: " + prefix)
    Debug("    args:")
    for (i, arg) in args.pairs() do
      Debug("      arg(" + i.string() + "): '" + arg + "'")
    end

    if (try args(1)?.contains(_nick) else false end) then
      conn.send(IRCCommandFactory.privmsg(_join_channel, "hello"))
    end

    if (try args(1)?.contains(_nick) else false end) and
      (try args(1)?.contains("bye") else false end) then
      conn.close()
    end

    if (try args(1)?.contains(".hug ") else false end) then
      Debug("HUG COMMAND? I LOVE HUGS")
      let command = try args(1)?.split(" ") else [""] end
      try
        let hug = command(0)?
        if hug == ".hug" then
          Debug("LET'S HUG!")
          let target = command(1)?
          if target.size() > 0 then
            Debug("LET'S HUG " + target + "!")
            conn.send(PrivMsg(_join_channel, "\x01ACTION hugs " + target))
          end
        end
      end
    end

class MyIRCMessageHandlerFactory
  let _nick: String
  let _channel: String

  new create(nick: String, channel: String) =>
    _nick = nick
    _channel = channel

  fun apply(): IRCMessageHandler iso^ =>
    recover MyIRCMessageHandler(_nick, _channel) end

actor Main
  new create(env: Env) =>
    try
      let nick = env.args(1) ?
      let channel = env.args(2) ?
      let irc_connection = IRCConnection(env.root as AmbientAuth,
        recover iso MyIRCMessageHandlerFactory(nick, channel) end,
        "irc.freenode.net", "6667")
      irc_connection.connect()
    end
