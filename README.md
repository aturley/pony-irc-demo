# Pony IRC

This is a project to develop some code for working with IRC in Pony.

Here's my plan:
0. Look at the IRC protocol.
1. Write a simple TCP listener that I can connect to with an IRC client that dumps messages.
2. Try to evolve the code in 1 into something implements enough of the IRC protocol that the client is happy to talk to it.
3. Based on 2, write some client code that I can use to connect to freenode.

## Details

Currently using `ponyc` version `0.17.0-12b6a67`.

## Progress

* The server lives in `server` and can be built by running `ponyc .`
  in that directory. It will write the messages it receives to
  stdout. I'm currently connecting with `Textual`, an OS X IRC client.

* Added a shitty command parser.

* Add a command handler to the server.

* Add client. Run with `client NICK CHANNEL` where `NICK` is the IRC
  nickname you want to use and `CHANNEL` is the channel you want to
  join to. Connects to `irc.freenode.net`, port 6667. The bot replies
  to messages that are sent to the nick.

* Add PING/PONG support to the client. No more getting the boot.

### NEW

* Add a primitive for generating command strings.

* Separate command processing and handling.

* Better argument parsing. It now looks for a colon to find the last
  argument.
