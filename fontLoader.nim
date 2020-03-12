import ansidrawer
import os
import nre
import strformat
import strutils

type
    Font = object
        path* : string
        size* : int
        style* : EscapeCode

let fontMatch = re".*=.*:\d."
let nameMatch = re".*="
let pathMatch = re"=.*:"
let sizeMatch = re":\d*"

let 
    baseConfig = """
font
    normal = /usr/share/fonts/truetype/noto/NotoMono-Regular.ttf:14
    bold = /usr/share/fonts/truetype/noto/NotoSansMono-Bold.ttf:14
    thin = /usr/share/fonts/truetype/noto/NotoSansMono-Light.ttf:14
"""
    path = fmt"{getHomeDir()}.config/clui/console.config"


proc getMatch(input: string, match : Regex): string=
    let regMatch = input.find(match)
    if(regMatch.isSome()):
        var bounds = regMatch.get.captureBounds[-1]
        result = input[bounds]
    else:
        echo fmt"Improper font format detected {input}" 


proc loadFontFile*(): seq[Font]=
    if(fileExists(path)):
        var fontFile = open(path,fmRead)
        while not fontFile.endOfFile():
            var line = fontFile.readLine()
            if(line == "font"):
                while fontFile.readLine(line):
                    if(line.contains(fontMatch)):
                        let nameString = line.getMatch(nameMatch).replace("=").strip().toLower()
                        let pathString = line.getMatch(pathMatch).replace("=").replace(":").strip()
                        let intString = line.getMatch(sizeMatch).replace(":").strip().toLower()
                        var size : int
                        if(nameString == "" or pathString == "" or intString == ""):
                            echo fmt"{line} is incorrectly formatted, should be 'type = path/to/font.ttf:size'"
                            continue
                        try:
                            size = parseInt(intString)
                        except:
                            echo fmt"{nameString} size is incorrect"
                            continue
                        var style = 0.EscapeCode

                        case(nameString):
                        of "normal": discard
                        of "thin" : style = EscapeCode.Dim
                        of "bold" : style = EscapeCode.Bold
                        else: 
                            echo fmt"{nameString}, must be one of normal,thin,bold"

                        if(fileExists(pathString)):
                            result.add(Font(path:pathString,size:size,style:style))

                    else: return result
    else:
        let splitDir = path.splitFile()
        if(not dirExists(splitDir.dir)): createDir(splitDir.dir)
        echo path
        var file = open(path,fmWrite)
        file.write(baseConfig)
        file.close()
        return loadFontFile()
