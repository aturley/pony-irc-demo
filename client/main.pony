use "net"
use "debug"

class MyIRCMessageHandler is IRCMessageHandler
  let _nick: String
  let _join_channel: String

  new create(nick: String, join_channel: String) =>
    _nick = nick
    _join_channel = join_channel

  fun ref connected(conn: IRCConnection) =>
    let commands = Array[String]
    commands.push(IRCCommand.nick(_nick))
    commands.push(IRCCommand.user("Pony Robot"))
    commands.push(IRCCommand.join(_join_channel))
    conn.write("".join(commands.values()))

  fun ref privmsg(conn: IRCConnection tag, prefix: String, args: Array[String] val) =>
    Debug("  PRIVMSG")
    Debug("    prefix: " + prefix)
    Debug("    args:")
    for (i, arg) in args.pairs() do
      Debug("      arg(" + i.string() + "): '" + arg + "'")
    end
    if (try args(1)?.contains(_nick) else false end) then
      conn.write(IRCCommand.privmsg(_join_channel, "hello"))
    end
    None

actor Main
  new create(env: Env) =>
    try
      let nick = env.args(1) ?
      let channel = env.args(2) ?
      IRCConnection(env.root as AmbientAuth,
        recover iso MyIRCMessageHandler(nick, channel) end,
        "irc.freenode.net", "6667")
    end
