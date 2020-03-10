import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]
import nre
import strutils
import strformat
import tables
import os
import osproc

let escSeq = re"\e\[.*m"

proc newCol(x,y,z:float): ImVec4= ImVec4(x:x,y:y,z:z,w:1)
proc newCol(i : ImVec4): ImVec4= ImVec4(x:i.x,y:i.y,z:i.z,w:1)



type
    Style* = ref object
        colourFG* : ImVec4
        colourBG : ImVec4
        styles : seq[EscapeCode]

    StyledText* = object
        text* : string
        selected* : bool
        style : Style
    
    EscapeCode = enum
        ResetAll = 0,
        Bold = 1,
        Dim = 2,
        Underlined = 4,
        Blink = 5,
        Reverse = 7,
        Hidden = 8,
        ResetBold = 21,
        ResetDim = 22,
        ResetUnderlined = 24,
        ResetBlink = 25,
        ResetReverse = 27,
        ResetHidden = 28,
        BlackFG = 30,
        RedFG = 31,
        GreenFG = 32,
        YellowFG = 33,
        BlueFG = 34,
        MagentaFG = 35,
        CyanFG = 36,
        LightGreyFG = 37,
        DefaultFG = 39,
        BlackBG = 40,
        RedBG = 41,
        GreenBG = 42,
        YellowBG = 43,
        BlueBG = 44,
        MagentaBG = 45,
        CyanBG = 46,
        LightGreyBG = 47,
        DefaultBG = 49,
        DarkGreyFG = 90,
        LightRedFG = 91,
        LightGreenFG = 92,
        LightYellowFG = 93,
        LightBlueFG = 94,
        LightMagentaFG = 95,
        LightCyanFG = 96,
        WhiteFG = 97,
        DarkGreyBG = 100,
        LightRedBG = 101,
        LightGreenBG = 102,
        LightYellowBG = 103,
        LightBlueBG = 104,
        LightMagentaBG = 105,
        LightCyanBG = 106,
        WhiteBG = 107

var colourFGTable = initTable[int,ImVec4]()
var colourBGTable = initTable[int,ImVec4]()
let red = newCol(0.5,0,0)
let lightRed = newCol(1,0,0)
let green = newCol(0,0.5,0)
let lightGreen = newCol(0,1,0)
let yellow = newCol(0.5,0.5,0)
let lightYellow = newCol(1,1,0)
let blue = newCol(0,0,0.5)
let lightBlue = newCol(0,0,1)
let magenta = newCol(0.5,0,0.5)
let lightMagenta = newCol(1,0,1)
let cyan = newCol(0,0.5,0.5)
let lightCyan = newCol(0,1,1)
let darkGrey = newCol(0.25,0.25,0.25)
let lightGrey = newCol(0.5,0.5,0.5)
let white = newCol(1,1,1)
let black = newCol(0,0,0)

colourFGTable.add(RedFG.int,red)
colourBGTable.add(RedBG.int,red)
colourBGTable.add(LightRedBG.int,lightRed)
colourFGTable.add(LightRedFG.int,lightRed)
colourBGTable.add(GreenBG.int,green)
colourFGTable.add(GreenFG.int,green)
colourBGTable.add(LightGreenBG.int,lightGreen)
colourFGTable.add(LightGreenFG.int,lightGreen)
colourBGTable.add(YellowBG.int,yellow)
colourFGTable.add(YellowFG.int,yellow)
colourBGTable.add(LightYellowBG.int,lightYellow)
colourFGTable.add(LightYellowFG.int,lightYellow)
colourBGTable.add(BlueBG.int,blue)
colourFGTable.add(BlueFG.int,blue)
colourBGTable.add(LightBlueBG.int,lightBlue)
colourFGTable.add(LightBlueFG.int,lightBlue)
colourBGTable.add(MagentaBG.int,magenta)
colourFGTable.add(MagentaFG.int,magenta)
colourBGTable.add(LightMagentaBG.int,lightMagenta)
colourFGTable.add(LightMagentaFG.int,lightMagenta)
colourBGTable.add(CyanBG.int,cyan)
colourFGTable.add(CyanFG.int,cyan)
colourBGTable.add(LightCyanBG.int,lightCyan)
colourFGTable.add(LightCyanFG.int,lightCyan)
colourBGTable.add(DarkGreyBG.int,darkGrey)
colourFGTable.add(DarkGreyFG.int,darkGrey)
colourBGTable.add(LightGreyBG.int,lightGrey)
colourFGTable.add(LightGreyFG.int,lightGrey)
colourBGTable.add(WhiteBG.int,white)
colourFGTable.add(WhiteFG.int,white)
colourBGTable.add(BlackBG.int,black)
colourFGTable.add(BlackFG.int,black)


proc newStyle*(foreground : ImVec4 = colourFGTable[WhiteFG.int],background : ImVec4 = colourBGTable[WhiteBG.int], styles : seq[EscapeCode] = @[]): Style=
    result = Style(colourFG : foreground,colourBG : background,styles : styles )

proc newStyledText*(text : string,style : Style):StyledText = StyledText(style:style,text:text)

var currentStyle = newStyle()

proc parseAnsiDisplayText*(input: string): seq[StyledText]=
    ##Used for displaying responses
    var currentPos = 0
    var currentStream = ""
    while currentPos < input.len:
        if(currentPos + 1 < input.len and input.substr(currentPos,(currentPos + 1)) == "\e["):
            if(currentStream.len > 0):
                var styledText = StyledText()
                styledText.text = currentStream.strip(chars = {'\n'})
                styledText.style = currentStyle
                result.add(styledText)
                currentStream = ""
            
            currentPos += 2
            var codeString = ""
            while input[currentPos] != 'm':
                codeString &= input[currentPos]
                inc(currentPos)
            var codes = codeString.split(";")
            for x in codes:
                var parsed = parseInt(x)
                if(parsed == 0 and codes.len == 1): currentStyle = newStyle()
                if(colourFGTable.contains(parsed)): currentStyle.colourFG = colourFGTable[parsed]
                if(colourBGTable.contains(parsed)): currentStyle.colourBG = colourBGTable[parsed]
                else: currentStyle.styles.add(EscapeCode(parsed))
        else: currentStream &= input[currentPos]
        inc(currentPos)
    if(currentStream.len > 0):
        var styledText = StyledText()
        styledText.text = currentStream.strip(chars = {'\n'})
        styledText.style = currentStyle
        result.add(styledText)
        currentStream = ""

proc parseAnsiInteractText*(input : string): seq[StyledText]=
    var parsed = parseAnsiDisplayText(input)
    for x in 0..<parsed.len:
        var splitText = parsed[x].text.split("\n")
        if(splitText.len > 1):
            parsed[x].text = splitText[0]
            for split in 1..<splitText.len:
                if(splitText[split].len > 0 or splitText[split] != " "):
                    var newText = newStyledText(splitText[split].strip(chars = {'\n'}),parsed[x].style)
                    if(x + split < parsed.len): parsed.insert(newText,x + split)
                    else: parsed.add(newText)
    result = parsed

proc drawAnsiText*(input : seq[StyledText])=
    for x in input:
        if(x.text == "" or x.text == "\n"): continue
        if(x.selected): igTextColored(colourFGTable[GreenFG.int],x.text)
        else: igTextColored(x.style.colourFG,x.text)
