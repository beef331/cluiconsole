import nimgl/imgui, nimgl/imgui/[impl_opengl, impl_glfw]
import nre
import strutils
import strformat
import tables
import os
import osproc


proc newCol*(x,y,z:float): ImVec4 = ImVec4(x:x,y:y,z:z,w:1)
proc newCol*(i : ImVec4): ImVec4 = ImVec4(x:i.x,y:i.y,z:i.z,w:1)



type
    Style* = ref object
        colourFG* : ImVec4
        colourBG : ImVec4
        styles : seq[EscapeCode]


    StyledText* = object
        text* : string
        selected* : bool
        style : Style

    StyleLine* = object
        words*: seq[StyledText]

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
let red = newCol(0.9,0,0)
let lightRed = newCol(1,0,0)
let green = newCol(0,0.9,0)
let lightGreen = newCol(0,1,0)
let yellow = newCol(0.9,0.9,0)
let lightYellow = newCol(1,1,0)
let blue = newCol(0,0,0.9)
let lightBlue = newCol(0,0,1)
let magenta = newCol(0.9,0,0.9)
let lightMagenta = newCol(1,0,1)
let cyan = newCol(0,0.9,0.9)
let lightCyan = newCol(0,1,1)
let darkGrey = newCol(0.25,0.25,0.25)
let lightGrey = newCol(0.9,0.9,0.9)
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

proc parseAnsiDisplayText*(input: string): seq[StyleLine]=
    var currentStyle = newStyle()
    ##Used for displaying responses
    for line in input.split("\n"):
        var currentPos = 0
        var currentStream = ""
        var styleLine = StyleLine()
        while currentPos < line.len:
            if(currentPos + 1 < line.len and line.substr(currentPos,(currentPos + 1)) == "\e["):
                if(currentStream.len > 0):
                    var styledText = StyledText()
                    styledText.text = currentStream
                    styledText.style = currentStyle
                    styleLine.words.add(styledText)
                    currentStream = ""

                #Find code string
                currentPos += 2
                var codeString = ""
                while currentPos < line.len and not Letters.contains(line[currentPos]):
                    if(currentPos > line.high): 
                        echo line
                        break
                    codeString &= line[currentPos]
                    inc(currentPos)

                #Get Style Codes
                var codes = codeString.split(";")
                for x in codes:
                    if x.contains("?"): continue
                    try:
                        var parsed = parseInt(x)
                        if(parsed == 0 and codes.len == 1): currentStyle = newStyle()
                        if(colourFGTable.contains(parsed)): currentStyle.colourFG = colourFGTable[parsed]
                        elif(colourBGTable.contains(parsed)): currentStyle.colourBG = colourBGTable[parsed]
                        else: currentStyle.styles.add(EscapeCode(parsed))
                    except:
                        echo x

            else: currentStream &= line[currentPos]
            inc(currentPos)

        #Exit but write the past to the terminal
        if(currentStream.len > 0):
            var styledText = StyledText()
            styledText.text = currentStream
            styledText.style = currentStyle
            styleLine.words.add(styledText)
            currentStream = ""
        if(styleLine.words.len > 0): result.add(styleLine)

proc parseAnsiInteractText*(input : string): seq[StyleLine]=
    var parsed = parseAnsiDisplayText(input)
    
    for i in 0..<parsed.len:
        for x in 0..<parsed[i].words.len:
            var splitText = parsed[i].words[x].text.split("\n")
            if(splitText.len > 1):
                parsed[i].words[x].text = splitText[0]
                for split in 1..<splitText.len:
                    if(splitText[split].len > 0 or splitText[split] != " "):
                        var newText = newStyledText(splitText[split].strip(chars = {'\n'}),parsed[i].words[x].style)
                        if(x + split < parsed[i].words.len): parsed[i].words.insert(newText,x + split)
                        else: parsed[i].words.add(newText)
    result = parsed

proc drawAnsiText*(input : seq[StyleLine])=
    for x in input:
        var sameLine = false
        for word in x.words:
            if(sameLine): igSameLine(0,0)
            if(word.text == "" or word.text == "\n"): continue
            if(word.selected): igTextColored(colourFGTable[GreenFG.int],word.text)
            else: igTextColored(word.style.colourFG,word.text)
            sameLine = true
