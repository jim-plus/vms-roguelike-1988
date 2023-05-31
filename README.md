# vms-roguelike-1988
Archival source code for a roguelike written (primarily by me) in 1988, targeting VMS operating system and VT100 terminals.

No build script was ever made (by me).
The BASIC program should create an OBJ file or library to be linked with the main Pascal program.
The longest and final version of the program appears to be _triv2.pas_, which has a documented revision date of December 30, 1988.
Direct calls were made to the system library to read terminal keys interactively, as there was no native support for that in VAX Pascal.
Various _write_ and _writeln_ statements output raw VT100 escape codes to draw the dungeon map, player statistics, and a scrolling text window.

My game influences at the time would have been _Temple of Apshai_ and _Rogue_.

```
$ ls -l
total 154
-rw-r--r-- 1 Jim Jim   100 Dec  3  1993 rand.bas
-rw-r--r-- 1 Jim Jim    88 Jan  4  1989 secure.cld
-rw-r--r-- 1 Jim Jim 47017 Dec  3  1993 triv.pas
-rw-r--r-- 1 Jim Jim 47116 Nov 29  1988 triv0.pas
-rw-r--r-- 1 Jim Jim 56418 Jan  4  1989 triv2.pas
```
