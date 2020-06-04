# Package

version       = "0.1.0"
author        = "Jason Beetham"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"
bin           = @["cluiconsole"]



# Dependencies

requires "nim >= 1.2.0"
requires "nimgl"
requires "sdl2"
requires "https://github.com/beef331/nim_pty"