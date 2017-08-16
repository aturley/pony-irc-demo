# Pony IRC

This is a project to develop some code for working with IRC in Pony.

Here's my plan:
0. Look at the IRC protocol.
1. Write a simple TCP listener that I can connect to with an IRC client that dumps messages.
2. Try to evolve the code in 1 into something implements enough of the IRC protocol that the client is happy to talk to it.
3. Based on 2, write some client code that I can use to connect to freenode.
