' "$(AS_PROJECT_PATH)\build.vbs " "$(AS_PROJECT_PATH) " "$(AS_PROJECT_NAME) " "$(AS_CONFIGURATION) "
AS_PROJECT_PATH = WScript.Arguments(0)
AS_PROJECT_NAME = WScript.Arguments(1)
AS_CONFIGURATION = WScript.Arguments(2)



If LCase(Right(Wscript.FullName, 11)) = "cscript.exe" Then
    isCScript = True
Else
	isCScript = False
End If

Const WshFinished = 1
Const WshFailed = 2

console("Running build.vbs...")

console(AS_PROJECT_PATH)
console(AS_PROJECT_NAME)
console(AS_CONFIGURATION)

Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = Trim(Replace(AS_PROJECT_PATH, "/", "\"))
WshShell.CurrentDirectory = WshShell.CurrentDirectory & "\"

Set fso = CreateObject("Scripting.FileSystemObject")

' Read current GIT id
hgCmd = "git rev-parse HEAD"
Set WshShellExec = WshShell.Exec(hgCmd)
Do While WshShellExec.Status <> 1
    WScript.Sleep 100
Loop
hgIdStr = "failed reading id"
Select Case WshShellExec.Status
   Case WshFinished
		tmpArray = Split(WshShellExec.StdOut.ReadLine, " ")
		tmpStr = Split(tmpArray(0), "+")
		hgIdStr = tmpArray(0) ' store it for later to also get the + in hg_tortoise_typ
   Case WshFailed
       tmpStr = WshShellExec.StdErr.ReadAll
End Select
console("GIT id: " & tmpArray(0))
' Read current GIT info
hgCmd = "git show --pretty=medium --no-patch "
Set WshShellExec = WshShell.Exec(hgCmd)
Do While WshShellExec.Status <> 1
    WScript.Sleep 100
Loop
Select Case WshShellExec.Status
   Case WshFinished
       hgInfo = WshShellExec.StdOut.ReadAll
   Case WshFailed
       hgInfo = WshShellExec.StdErr.ReadAll
End Select

' Read current Tortoise HG branch
hgCmd = "git rev-parse --abbrev-ref HEAD"
Set WshShellExec = WshShell.Exec(hgCmd)
Do While WshShellExec.Status <> 1
    WScript.Sleep 100
Loop
Select Case WshShellExec.Status
   Case WshFinished
       hgBranch = WshShellExec.StdOut.ReadAll
   Case WshFailed
       hgBranch = WshShellExec.StdErr.ReadAll
End Select


' Read current Tortoise HG branch
hgCmd = "git describe --tags"
Set WshShellExec = WshShell.Exec(hgCmd)
Do While WshShellExec.Status <> 1
    WScript.Sleep 100
Loop
Select Case WshShellExec.Status
   Case WshFinished
       gitTags = WshShellExec.StdOut.ReadAll
   Case WshFailed
       gitTags = WshShellExec.StdErr.ReadAll
End Select

gitTagsInfo = Split(gitTags, "-")


' Read current Tortoise HG branch
hgCmd = "git rev-list --format=%B --max-count=1 "& hgIdStr
console(hgCmd)
Set WshShellExec = WshShell.Exec(hgCmd)
Do While WshShellExec.Status <> 1
    WScript.Sleep 100
Loop
Select Case WshShellExec.Status
   Case WshFinished
       summary = WshShellExec.StdOut.ReadAll
   Case WshFailed
       summary = WshShellExec.StdErr.ReadAll
End Select

tmpSummaryArray = Split(summary, vbLf)
console(tmpSummaryArray(0))

if UBound(tmpSummaryArray) > 1 then
	summery = tmpSummaryArray(1)
	For i = 2 to UBound(tmpSummaryArray)
		if Len(tmpSummaryArray(i)) > 0 then
		summery = summery+"$N"&tmpSummaryArray(i)
		end if
	next
else 
summery = ""
end if

summery = Left(summery,100)
			
' split answer
tmpArray = Split(hgInfo, vbLf)

' read old version from Physical\<configuration>\Hardware.hw file
' look for <Parameter ID="ConfigVersion" Value="1.0.1" />
version = "?.?.?"
configurationID = ""
versionChanged = False

Set file = fso.OpenTextFile("Physical\" & AS_CONFIGURATION & "\Hardware.hw" , 1)
Do Until file.AtEndOfStream
  line = file.Readline()
  pos = InStr(line,"ConfigVersion") ' <Parameter ID="ConfigVersion" Value="99.99.99" />
  if pos <> 0 then
	pos2 = InStrRev(line, """")
	version = Mid(line,pos+22,pos2-(pos+22))	
	exit do
  else
	pos = InStr(line,"ConfigurationID") ' <Parameter ID="ConfigurationID" Value="CountingMachine" />
	if pos <> 0 then
		pos2 = InStrRev(line, """")
		configurationID = Mid(line,pos+24,pos2-(pos+24))
	end if
  end if
Loop
file.Close


console("current Version:" & version)





' create (overwrite) new typ file (no need to check for contents in exsisting file, it will always differ due to asBuildTime)
set b = fso.CreateTextFile("Logical\modules\main\main\build.typ", True)
' fill with data
b.WriteLine ("TYPE")
b.WriteLine (" hg_tortoise_typ : STRUCT")
b.WriteLine ("  project : STRING[20] := '"&strClean(AS_PROJECT_NAME)&"';")
b.WriteLine ("  asBuildDate : STRING[16] := '"&strClean(Date())&"';")
b.WriteLine ("  asBuildTime : STRING[16] := '"&strClean(Time())&"';")
b.WriteLine ("  configurationID : STRING[255] := '"&configurationID&"';")
console("configurationID: " + strClean(configurationID))
tipWritten = 0

b.WriteLine ("  summary : STRING[255] := '"&summery&"';")
console("summary: " + summery)


if UBound(gitTagsInfo) > 1 then
	revision = strClean(Mid(gitTagsInfo(2),2))
	b.WriteLine ("  revision : STRING[80] := '"&revision&"';")	
	console("revision: " + revision)

	version = strClean(Mid(gitTagsInfo(0),3))
	b.WriteLine ("  version : STRING[80] := '"&version&" ("&gitTagsInfo(1)&")';")	
	console("version: " + version)
else
	revision = strClean(Left(hgIdStr,6))
	b.WriteLine ("  revision : STRING[80] := '"&revision&"';")	
	console("revision: " + revision)


	version = strClean(Mid(gitTagsInfo(0),3))
	b.WriteLine ("  version : STRING[80] := '"&version&"';")	
	console("version: " + version)
end if

versionChanged = true

b.WriteLine ("  branch : STRING[80] := '"&strClean(hgBranch)&"';")	
console("branch: " + strClean(hgBranch))

For i = 0 to UBound(tmpArray) 

	if Len(tmpArray(i)) > 0 then
		if InStr(1, tmpArray(i), "commit ") = 1 then
			id = strClean(Mid(tmpArray(i), 7))
			console("ID: " & id)
			
		
			b.WriteLine ("  id : STRING[40] := '"&id&"';")

		elseIf InStr(1, tmpArray(i), "Author: ") = 1 then
			tmpAuthorArray = Split(tmpArray(i), "<")
			console("User: " & strClean(Mid(tmpAuthorArray(0), 8)))
			console("Email: " & Left(tmpAuthorArray(1), Len(tmpAuthorArray(1)) - 1) )
			b.WriteLine ("  user : STRING[80] := '"&strClean(Mid(tmpAuthorArray(0), 8))&"';")
			b.WriteLine ("  email : STRING[80] := '" & Left(tmpAuthorArray(1), Len(tmpAuthorArray(1)) - 1) &"';")
			
		
		end if
		
	end if
next

' b.WriteLine ("  tag: STRING[255] := 'RELEASED';")

b.WriteLine (" END_STRUCT;")
b.WriteLine ("END_TYPE")
b.Close ()

' ' create new var file, only as temp (checks later if overwrite is necessary)
' set b = fso.CreateTextFile ("Logical\modules\main\main\build1.var", True)
' ' fill with data
' b.WriteLine ("VAR")
' b.WriteLine ("	hgInfo : hg_tortoise_typ;")
' b.WriteLine ("END_VAR")
' b.Close ()

' copyFileIfDiff fso, "Logical\modules\main\main\build1.var", "Logical\modules\main\main\build.var"

' write the new version to Physical\<configuration>\Hardware.hw file
if versionChanged then
	' look for <Parameter ID="ConfigVersion" Value="1.0.1" />
	content = ""
	Set file = fso.OpenTextFile("Physical\" & AS_CONFIGURATION & "\Hardware.hw" , 1)
	Do Until file.AtEndOfStream
	  line = file.Readline
	  pos = InStr(line,"ConfigVersion")
	  if pos <> 0 then
		content = content & "    <Parameter ID=""ConfigVersion"" Value=""" & version & """ />" & Chr(13) & Chr(10)
	  else
		content = content & line & Chr(13) & Chr(10)
	  end if
	Loop
	file.Close()

	set b = fso.CreateTextFile("Physical\" & AS_CONFIGURATION & "\Hardware.hw", True)
	b.Write(content)
	b.Close()
end if


' ******* clean and trim str *******
Function strClean (strtoclean)
	' remove ' from string
	outputStr = Replace(strtoclean, vbLf, "")
	outputStr = Replace(outputStr, "'", "")
	' trim
	outputStr = trim(outputStr)
	strClean = outputStr
End Function

' ******* files are different ********
Function filediff(f1, f2)
  cmd = "%COMSPEC% /c fc /b " & Chr(34) & f1 & Chr(34) & " " & Chr(34) & f2 & Chr(34)
  filediff = CBool(CreateObject("WScript.Shell").Run(cmd, 0, True))
End Function

' ******* Handle different languages ********
Function translate(str)
	if str = "ændring" or Right(str, 6) = "ndring" then ' æ is sometimes fubar by encoding
 		translate = "changeset"
	elseIf str = "gren" then
		translate = "branch"
	elseIf str = "dato" then
		translate = "date"
	elseIf str = "uddrag" then
		translate = "summary"
	elseIf str = "mærkat" or (Left(str, 1) = "m" and Right(str, 4) = "rkat" ) then
 		translate = "tag"
	elseIf str = "bruger" then
		translate = "user"
	elseIf str = "forælder" or  (Left(str, 3) = "for" and Right(str, 4) = "lder" ) then
		translate = "parent"
	else
		translate = str
	end if
End Function

Function console(str)
	If isCScript Then
		WScript.Echo(str & vbCrLf)
	End If
End Function

Function copyFileIfDiff(fso, srcFile, destFile)

	' only write to real file if contents is different
	if fso.FileExists (destFile) then
		if filediff(srcFile, destFile) then
			fso.CopyFile srcFile, destFile, True
		end if
	else
		fso.CopyFile srcFile, destFile, True
	end if
	'delete temp file
	fso.DeleteFile srcFile
End Function