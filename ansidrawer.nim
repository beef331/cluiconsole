import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]
import nre
import strutils
import tables
import os

let escSeq = re"\e\[.*m"

proc newCol(x,y,z:float): ImVec4= ImVec4(x:x,y:y,z:z,w:1)
proc newCol(i : ImVec4): ImVec4= ImVec4(x:i.x,y:i.y,z:i.z,w:1)



type
    StyledText* = object
        text* : string
        colourFG* : ImVec4
        colourBG : ImVec4
        styles : seq[EscapeCode]
        selected* : bool
    
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


proc parseAnsiText*(input: string): seq[StyledText]=
    var pos = 0
    var sanatizedInput = input.replace("\e[0m","")
    while pos < sanatizedInput.len:
        let found = sanatizedInput.find(escSeq,pos)
        if(found.isSome):
            var bounds = found.get.captureBounds[-1]
            if(bounds.a != pos):
                var unStyledText = StyledText(selected : false)
                unStyledText.colourFG = colourFGTable[WhiteFG.int]
                unStyledText.colourBG = colourBGTable[BlackBG.int]
                unStyledText.text = sanatizedInput[pos..bounds.a]
                result.add(unStyledText)
            var text = StyledText()
            var splitString = sanatizedInput[bounds].split("m",1)
            
            #No word here, dont write anything
            if(splitString.len < 2): 
                pos = bounds.b
                continue
            text.text = splitString[1]
            var codes = splitString[0].replace("\e[","",).split(";")
            for code in codes:
                try:
                    var parsed = parseInt(code)
                    text.styles.add(EscapeCode(parsed))
                    if(colourBGTable.contains(parsed)): text.colourBG = colourBGTable[parsed]
                    if(colourFGTable.contains(parsed)): text.colourFG = colourFGTable[parsed]
                except:
                    echo "input int not parsable ", code
            if(text.text != "\n\e"): result.add(text)
            pos = bounds.b+1
        else:
            var unStyledText = StyledText(selected : false)
            unStyledText.colourFG = colourFGTable[WhiteFG.int]
            unStyledText.colourBG = colourBGTable[BlackBG.int]
            unStyledText.text = sanatizedInput[pos..sanatizedInput.high]
            if(unStyledText.text != "\n\e"): result.add(unStyledText)
            pos = sanatizedInput.len

    for x in countdown(result.high,0):
        result[x].text = result[x].text.replace("\n\e","\n")
        #Remove useless newlines
        var didSplit = false
        for split in result[x].text.split("\n"):
            if(split != ""):
                var style = StyledText(selected : false)
                style.colourBG = newCol(result[x].colourBG)
                style.colourFG = newCol(result[x].colourFG)
                style.styles = result[x].styles
                style.text = split
                result.add(style)
                didSplit = true
        if(didSplit): result.delete(x)


proc drawAnsiText*(words : seq[StyledText], drawInline : bool = false) =
    for x in words:
        var col : ImVec4 = x.colourFG
        if(col.w < 1): col = colourFGTable[WhiteFG.int]
        if(x.selected): igTextColored(colourFGTable[LightGreenFG.int], x.text)
        else: igTextColored(col,x.text)
        if(drawInline): igSameLine(0,0)