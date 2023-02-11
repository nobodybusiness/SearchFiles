## SearchFiles_v0.2
## App for faster searching files and folders
## on windows with use of cmd 
## 
## Important: when building from linux use:
## nim c -d:mingw -d:realese --opt:speed  --threads:on --app:gui searchFiles.nim

## Imports
import nigui
import osproc
import std/strutils
import std/sequtils
import std/sugar
import std/with

## Created variables to use in handleDrawEvent
var imageFile = newImage()
var imageFolder = newImage()

var colorText: Color
var colorBackground: Color

#-----------------------------
#           TYPES
#-----------------------------
## Object of found files/folders
type
    Found* = object
        path*: string
        name*: string
        time*: string
        date*: string
        dir*: bool
        size*: float
        typeExt*: string

## Custum button for Object
type CustomButton* = ref object of ControlImpl
    found: Found

#-----------------------------
#          METHODS
#-----------------------------

## Method for draw CustomButton
method handleDrawEvent*(control: CustomButton, event: DrawEvent) =
    let canvas = event.control.canvas
    let obj = control.found

    # import from main file
    let imageFile = imageFile
    let imageFolder = imageFolder

    # Colors
    canvas.areaColor = colorBackground
    canvas.textColor = colorText
    canvas.lineColor = colorText

    # Background
    canvas.drawRectArea(0, 0, control.width, control.height)

    # Path
    canvas.fontSize = 14
    var objPath: string
    let realPathWidth = canvas.getTextWidth(obj.path)
        # pixel length after display
    let realMaxWidth = control.width-380
        # pixel length from end, work beacuse minWidth for button is static

    if realPathWidth < realMaxWidth:
        # if path is too long to show, scale length to show up
        objPath = obj.path
    else:
        let multiplier = realMaxWidth / realPathWidth
            # multiplier * obj.path.len ~~ realMaxWidth
        objPath = obj.path.substr(0, (obj.path.len.toFloat * multiplier).toInt() - 3) & "..."

    canvas.drawText(objPath, 60, 34)

    # Name
    canvas.fontSize = 16
    var objName: string
    let realNameWidth = canvas.getTextWidth(obj.name)
        # pixel length after display
    if realNameWidth < realMaxWidth:
        # if name is too long to show, scale length to show up
        objName = obj.name
    else:
        let multiplier = realMaxWidth / realNameWidth
            # multiplier * obj.path.len ~~ realMaxWidth
        objName = obj.name.substr(0, (obj.name.len.toFloat * multiplier).toInt() - 3) & "..."

    canvas.drawText(objName, 60, 12)

    # Type
    canvas.fontSize = 14
    let xType = control.width-300
    canvas.drawText("TYPE", xType, 15)
    canvas.drawText(obj.typeExt, xType, 34)

    # Date/time
    let xDate = control.width-225
    canvas.drawText("date modified: " & obj.time & " " & obj.date, xDate, 15)

    # Size
    if not obj.dir:
        # show size only if not folder
        var sizeStr: string
        if obj.size > 999:
            # 999.00kb is max, bigger shows mb
            if obj.size / 1024 > 999:
                sizeStr = (obj.size / 1024 / 1024).formatFloat(ffDecimal, 2) & "Gb"
            else:
                sizeStr = (obj.size / 1024).formatFloat(ffDecimal, 2) & "mb"
        else:
            sizeStr = obj.size.formatFloat(ffDecimal, 2) & "kb"

        canvas.drawText("size: " & sizeStr, control.width-225, 34)

    # Outerline
    canvas.drawRectOutline(0, 0, control.width, control.height)

    # Icon
    if obj.dir:
        canvas.drawImage(imageFolder, 12, 12, 36, 36)
    else:
        canvas.drawImage(imageFile, 12, 12, 36, 36)

#-----------------------------
#         PROCESSES
#-----------------------------

## Create CustomButton from Found Object
proc newButtonCustom*(found: Found): CustomButton =
    result = new CustomButton
    with result:
        init()
        found = found
        widthMode = WidthMode_Expand
        height = 60
        minWidth = 590

## Find last coma in string and returns it position from start of string
proc findLastComa(s: string): int =
    for i in 0..<s.len:
        if s[s.len-1-i] == '.':
            return s.len - 1 - i
    return -1

## Creates all object from strings from cmd command
proc createAllFound*(lines: seq[string]): seq[Found] =
    var allFound: seq[Found]

    for i in 0..<lines.len:
        let line = lines[i].split(" ").filter(x=>x != "")
            # line as tuple
            # exmaple:
                #@["Directory", "of", "C:\\Users\\john\\AppData\\Roaming\\Microsoft\\Windows\\Recent"]
                #   {0}='Directory'      {2} = path to directory
                #@["02/05/2023", "12:08", "PM", "243", "MyTests", "(VBoxSvr)", "(Z).lnk"]
                #   {0}=date     {1}=time {2}=pm/am {3}=bytes {4} =name and type
                #@["02/03/2023", "01:11", "AM", "496", "Tests.lnk"]

        if line[0] == "Directory":
            # creation of object
            let path = line[2]
            allFound.add(Found(path: path))
        else:
            var curFound = allFound[allFound.len-1]
                # set object as last from global
            let date = line[0]
            let isPM = line[2] == "PM"
            var time: string

            if isPM:
                # change to 24h format
                time = $(line[1].substr(0, 1).parseInt + 12) & line[1].substr(2)
            else:
                time = line[1]

            var dir = false
            var size = 0.00
            var typeExt = "DIR"

            if line[3] == "<DIR>":
                # diffrent settings for dir, file
                dir = true
            else:
                size = (line[3].replace(",").parseInt() / 1024)
                typeExt = line[4].substr(line[4].findLastComa() + 1)
                if typeExt.len > 8:
                    # if too long type, trim
                    typeExt = typeExt.substr(0, 5) & "..."
            let name = line[4]

            if curFound.name != "":
                # check if already exist object for current path
                # and if exist, creates new object - many objects can have same path
                curFound = Found(path: curFound.path)
                allFound.add(curFound)

            curFound.date = date
            curFound.time = time
            curFound.name = name
            curFound.dir = dir
            curFound.size = size
            curFound.typeExt = typeExt
            allFound[allFound.len-1] = curFound
                #update vales of last object
    result = allFound
        # return objects

## Run cmd command without opening terminal
proc runWindowsCmd*(command: string): string =
    result = execProcess("cmd.exe /c " & command, options = {poUsePath, poStdErrToStdOut, poEvalCommand, poDaemon})

## Run specific cmd command to find all files/folders with given string
proc runWindowsCmdFindAll*(drive: string, substringName: string): string =
    result = runWindowsCmd(drive & "& dir \"\\" & substringName & "*\" /s")
        # example C: dir "\*search*" /s
        # {mount C} {find} {from root} {substings} {all subfolders}

proc openExplorerOrAppByPath(path: string) =
    discard runWindowsCmd("start " & path)

## Start of app
#-----------------------------
#           APP
#-----------------------------
app.init()

colorText = rgb(0, 0, 0)
colorBackground = rgb(255, 255, 255)

var window = newWindow("Search Files v0.2")

var containerMain = newLayoutContainer(Layout_Vertical)

#-----------------------------
#           USER
#-----------------------------

var containerUser = newLayoutContainer(Layout_Horizontal)

var textBox = newTextBox("")

var buttonSearch = newButton("Search")

var driveList = newComboBox()
driveList.width = buttonSearch.width
driveList.height = buttonSearch.height

let allDrivesSting = runWindowsCmd("wmic logicaldisk get name")
let allDrives = allDrivesSting.splitWhitespace().filter(x=>x != "").filter(x=>x != "Name")
driveList.options = allDrives
    # add to comboBox results

containerUser.add(textBox)
containerUser.add(driveList)
containerUser.add(buttonSearch)
containerUser.frame = newFrame("Type what to search")

containerMain.add(containerUser)

#-----------------------------
#          PARTS
#-----------------------------

var containerParts = newContainer()
containerParts.widthMode = WidthMode_Fill
containerParts.height = 60

var labelStaticStatus = newLabel("Status:   ")
containerParts.add(labelStaticStatus)
labelStaticStatus.x = 5
labelStaticStatus.y = 7
labelStaticStatus.fontSize = 16

var labelStatus = newLabel("Wait     ")
containerParts.add(labelStatus)
labelStatus.x = 60
labelStatus.y = 7
labelStatus.fontSize = 16
labelStatus.fontBold = true
labelStatus.textColor = rgb(0, 0, 255)

proc setStatus(labelStatus: Label, status: string) =
    # helper function to setup label
    labelStatus.text = status & "     "
    var color: Color

    if status == "Wait":
        color = rgb(0, 0, 255)
    elif status == "Work":
        color = rgb(255, 0, 0)
    elif status == "Done":
        color = rgb(0, 255, 0)

    labelStatus.textColor = color

var buttonPrevious = newButton("/\\")
containerParts.add(buttonPrevious)
buttonPrevious.x = 150
buttonPrevious.y = 0
buttonPrevious.height = 30

var buttonNext = newButton("\\/")
containerParts.add(buttonNext)
buttonNext.x = 175
buttonNext.y = 0
buttonNext.height = 30

var labelCurentlyShowing = newLabel("")
containerParts.add(labelCurentlyShowing)
labelCurentlyShowing.widthMode = WidthMode_Fill
labelCurentlyShowing.x = 260
labelCurentlyShowing.y = 7
labelCurentlyShowing.fontSize = 16

containerMain.add(containerParts)

var timer: Timer
# add wait after resize window (too many call on resize)
proc timerProc(event: TimerEvent) =
    if window.width < 600:
        window.width = 600
    if window.height < 650:
        window.height = 650
# resize and redraw of positions depending on window size
window.onResize = proc(event: ResizeEvent) =
    if window.width < 600 or window.height < 650:
        timer = startTimer(1000, timerProc)

#-----------------------------
#        BUTTONS
#-----------------------------

# setup for buttons
    # images
imageFile.loadFromFile("icons/icons8-easy-access-48.png")
imageFolder.loadFromFile("icons/icons8-file-folder-48.png")
    # Objects
var containerButtons: LayoutContainer
var allFoundObjects: seq[Found]
    # setup for showing part of results (first 7)
var showingResultsHigh: int

#-----------------------------
#        LISTENERS
#-----------------------------

proc removeButtonsFromContainer() =
    # clear buttons from container
    if containerMain.childControls.contains(containerButtons):
        containerMain.remove(containerButtons)
    containerButtons = newLayoutContainer(Layout_Vertical)

proc drawShowingButtons(firstRun: bool) =
    # draw currently showing buttons
    if firstRun:
        showingResultsHigh = min(6, allFoundObjects.len - 1)
    else:
        if showingResultsHigh <= - 1:
            # cycle to last
            showingResultsHigh = allFoundObjects.len - 1
        elif showingResultsHigh <= 6:
            # show first
            showingResultsHigh = min(6,allFoundObjects.len - 1)
        elif showingResultsHigh >= allFoundObjects.len + 6:
            # cycle to first
            showingResultsHigh = min(6, allFoundObjects.len - 1)
        elif showingResultsHigh >= allFoundObjects.len - 1:
            # show last
            showingResultsHigh = allFoundObjects.len - 1

    let showingResultsLow = max(0,showingResultsHigh - 6)
    labelCurentlyShowing.text = $(showingResultsLow + 1) &
                                "-" & $(showingResultsHigh + 1) &
                                "/" & $(allFoundObjects.len)

    for i in showingResultsLow..showingResultsHigh:
        # draw firsty 7 objects
        let button = newButtonCustom(allFoundObjects[i])
        containerButtons.add(button)
        button.onMouseButtonDown = proc (event: MouseEvent) =
            let castObject = cast[CustomButton](event.control).found
            let runnableFile = castObject.path & "\\" & castObject.name
            if event.button == MouseButton_Left:
                # open file/ run app
                runnableFile.openExplorerOrAppByPath
            if event.button == MouseButton_Right:
                castObject.path.openExplorerOrAppByPath

    containerMain.add(containerButtons)
    labelStatus.setStatus("Done")

buttonPrevious.onClick = proc(event: ClickEvent) =
    removeButtonsFromContainer()
    showingResultsHigh = showingResultsHigh - 7
    drawShowingButtons(false)

buttonNext.onClick = proc(event: ClickEvent) =
    removeButtonsFromContainer()
    showingResultsHigh = showingResultsHigh + 7
    drawShowingButtons(false)

buttonSearch.onClick = proc(event: ClickEvent) =
    labelStatus.setStatus("Work")
    labelCurentlyShowing.text = ""
    removeButtonsFromContainer()

    var find = textBox.text
        # search string
    if find.len < 3:
        # shorter len gives way to many results
        window.alert("Minimal length for search is 3 characters!\nTip:You can omit this by adding '*' chars but it is not recomended.")
        labelStatus.setStatus("Wait")
    else:
        let drive = driveList.value
            # currently selected drive
        let cmdReturn = runWindowsCmdFindAll(drive, find)

        var rawLines = cmdReturn.split("\n")

        if rawLines[0].contains("device is not"):
            # early exit if first return signal no device
            window.alert("Device You have chosen is not ready.")
            labelStatus.setStatus("Wait")
            return

        if rawLines[rawLines.len-2].contains("File Not Found"):
            # earle exit if last line signal no such file
            window.alert("There is no results for Your search.")
            labelStatus.setStatus("Wait")
            return

        # remove 2 first lines - containing 'Volume in drive...' and 'Serial Number...'
        rawLines.delete(0..2)

        # remove 3 last lines - containing 'Total Files Listed..' and its data
        rawLines.delete(rawLines.len-4..rawLines.len-1)

        # filtered data form cmd
        let correctedLines = rawlines
            .filter(x =>
                not x.contains("File(s)") and
                not x.contains("Dir(s)") and
                x != "" and
                x != " ")

        allFoundObjects = @[]
            # removes previous Objects
        allFoundObjects = correctedLines.createAllFound()

        drawShowingButtons(true)

#-----------------------------
#        END
#-----------------------------
window.width = 600
window.height = 650
window.add(containerMain)

window.show()

app.run()

#[

TODO:
    - sort
    - filter
]#
