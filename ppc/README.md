# Path Processor control

This program (in C) connects to Skynet and awaits commands.

It is designed to launch programs locally and pipe the output back across a socket to Skynet.

The commands allow sub-programs to be started and interrupted.

## Make

`gcc -o ppc ppc.c`

