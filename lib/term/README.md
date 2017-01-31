term.sh
=======

Terminal fun written in bash inspired by clibs/term

## install

```sh
$ make install
```

or 

```sh
$ . term.sh
```

## usage

```
usage: term [-hV] <command> [args]
```

## example

```sh
$ { term color green; } && { term underline; } && { echo heyaaaa; }
heyaaaa
```

## api

```
commands:

  write <code>           Write a terminal escape code
  cursor <op>            Perform operation to cursor
  color <color>          Set terminal color by name (See colors)
  background <color>     Set terminal background by name (See colors)
  move <x> <y>           Move to (x, y)
  transition <x> <y>     Transition to (x, y)
  clear <section>        Clear terminal section by name (See sections)
  reset                  Reset the terminal escape code sequence
  bright                 Write bright escape code
  dim                    Write dim escape code
  underline              Write underline escape code
  blink                  Write blink escape code
  reverse                Write reverse escape code
  hidden                 Write hidden escape code

colors:

  black                  $ term color black
  red                    $ term color red
  green                  $ term color green
  yellow                 $ term color yellow
  blue                   $ term color blue
  magenta                $ term color magenta
  cyan                   $ term color cyan
  white                  $ term color white
  gray|grey              $ term color gray

sections:

  start                  Start of line
  end                    End of line
  up                     Upper section
  down                   Lower section
  line                   Current line
  screen                 Entire screen
```

## histogram

See `example.sh`

```
  .

  .

  .

  .

  .
                                                        █
  .                                                     █
                                                        █
  .                                                     █
                                            █           █
  .                                         █           █
                                            █           █
                                            █           █
  .     █     █     █     █     █     █     █     █     █     █     █
```

## license

MIT
