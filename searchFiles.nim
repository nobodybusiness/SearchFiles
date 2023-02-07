## SearchFiles_v0.1
## App for faster searching files and folders
## on windows with use of cmd 
## 
## Important: when building from linux use:
## "nim c -d:mingw -d:nimNoLentIterators --app:gui searchFiles.nim"

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
            # 999.00mb is max, bigger shows Gb
            sizeStr = (obj.size / 1024).formatFloat(ffDecimal, 2) & "Gb"
        else:
            sizeStr = obj.size.formatFloat(ffDecimal, 2) & "mb"

        canvas.drawText("size: " & sizeStr, control.width-225, 34)

    # Outerline
    canvas.drawRectOutline(0, 0, control.width, control.height)

    # Icon
    if obj.dir:
        # icon for folder/file
        # canvas.areaColor=rgb(0,255,0)
        # canvas.drawRectArea(12,12,36,36)
        canvas.drawImage(imageFolder, 12, 12, 36, 36)
    else:
        # canvas.areaColor=rgb(0,0,255)
        # canvas.drawRectArea(12,12,36,36)
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
                size = (line[3].replace(",").parseInt() / 1024 / 1024)
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

var window = newWindow("Search Files v0.1")

var containerMain = newLayoutContainer(Layout_Vertical)

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

var progress = newLayoutContainer(Layout_Horizontal)
progress.padding = 10

var percent = newLabel("0%")
percent.yTextAlign = YTextAlign_Top

var progressBar = newProgressBar()
progressBar.value = 0.0

progress.add(progressBar)
progress.add(percent)

containerMain.add(progress)

# setup images for buttons
imageFile.loadFromFile("icons/icons8-easy-access-48.png")
imageFolder.loadFromFile("icons/icons8-file-folder-48.png")

var containerButtons = newLayoutContainer(Layout_Vertical)
with containerButtons:
    heightMode = HeightMode_Fill
        # scrolling
    widthMode = WidthMode_Fill

buttonSearch.onClick = proc(event: ClickEvent) =
    if containerButtons.childControls.len > 0:
        # removes prebious found objects
        for child in containerButtons.childControls:
            containerButtons.remove(child)

    # info for User that program started
    progressBar.value = 0.05
    percent.text = "5%"

    var find = textBox.text
        # search string
    if find.len < 3:
        # shorter len gives way to many results
        progressBar.value = 0.00
        percent.text = "0%"
        window.alert("Minimal length for search is 3 characters!\nTip:You can omit this by adding '*' chars but it is not recomended.")
    else:
        let drive = driveList.value
            # currently selected drive
        let cmdReturn = runWindowsCmdFindAll(drive, find)

        progressBar.value = 0.40
        percent.text = "40%"

        var rawLines = cmdReturn.split("\n")

        if rawLines[0].contains("device is not"):
            # early exit if first return signal no device
            progressBar.value = 0.00
            percent.text = "0%"
            window.alert("Device is not ready.")
            return

        if rawLines[rawLines.len-2].contains("File Not Found"):
            # earle exit if last line signal no such file
            progressBar.value = 0.00
            percent.text = "0%"
            window.alert("There is no such file.")
            return

        if rawLines.len > 250:
            # work-around for too many creating buttons
            # in the future app should not to try load all result in same time,
            # but in parts
            window.alert("There is too many results for this program!\nTry to be more specific.\nShowing first result.\nTip: You can use .extension to specify your search")
            rawLines.delete(250..rawLines.len-1)

        # remove 2 first lines - containing 'Volume in drive...' and 'Serial Number...'
        rawLines.delete(0..2)

        # remove 3 last lines - containing 'Total Files Listed..' and its data
        rawLines.delete(rawLines.len-4..rawLines.len-1)

        # filtered data form cmd
        let correctedLines = rawlines
            .filter(x =>
                    #not x.contains("Volume in drive") and
                        #not x.contains("Serial Number") and
                not x.contains("File(s)") and
                not x.contains("Dir(s)") and
                #not x.contains("Total Files Listed") and
                x != "" and
                x != " ")

        # window.alert($output)
        var allFoundObjects: seq[Found]
        allFoundObjects = @[]
        allFoundObjects = correctedLines.createAllFound()

        progressBar.value = 0.80
        percent.text = "80%"

        for foundObj in allFoundObjects:
            let button = newButtonCustom(foundObj)
            button.onMouseButtonDown = proc (event: MouseEvent) =
                let pathToFile = foundObj.path
                let runnableFile = foundObj.path & "\\" & foundObj.name
                if event.button == MouseButton_Left:
                    # open file/ run app
                    #window.alert(runnableFile)
                    runnableFile.openExplorerOrAppByPath
                if event.button == MouseButton_Right:
                    #window.alert(pathToFile)
                    pathToFile.openExplorerOrAppByPath
            containerButtons.add(button)

        progressBar.value = 1.00
        percent.text = "100%"

containerMain.add(containerButtons)

window.width = 600
window.height = 600

window.add(containerMain)

window.show()

app.run()

#[

TODO:
    -make sorting possible
    -size form kb->mb->gb
    -on 'return' key search
    -arrows key to scroll?
    -better idea for rawlines and creating buttons
]#
