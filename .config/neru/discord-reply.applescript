-- Run by neru after it right-clicks a Discord message (see config.toml):
-- waits for the "Message Actions" context menu, finds its "Reply" item, and
-- clicks it with a real mouse click (Discord's React menu ignores AXPress).
on findReply(e)
	tell application "System Events"
		set r to role of e
	end tell
	if r is "AXMenuItem" then
		tell application "System Events"
			try
				if (value of attribute "AXTitle" of e) is "Reply" then return e
			end try
		end tell
		return missing value
	end if
	tell application "System Events"
		set kids to UI elements of e
	end tell
	repeat with k in kids
		set found to my findReply(k)
		if found is not missing value then return found
	end repeat
	return missing value
end findReply

set menuEl to missing value
repeat 20 times
	tell application "System Events"
		try
			set f to value of attribute "AXFocusedUIElement" of process "Discord"
			if (value of attribute "AXDescription" of f) is "Message Actions" then
				set menuEl to f
				exit repeat
			end if
		end try
	end tell
	delay 0.1
end repeat
if menuEl is missing value then return

set replyItem to my findReply(menuEl)
if replyItem is missing value then
	-- unexpected menu shape: close it rather than leave it hanging
	tell application "System Events" to key code 53
	return
end if

tell application "System Events"
	set {x, y} to position of replyItem
	set {w, h} to size of replyItem
end tell
set cx to (x + w div 2) as integer
set cy to (y + h div 2) as integer
do shell script "/usr/local/bin/neru action move_mouse --x " & cx & " --y " & cy & " && /usr/local/bin/neru action left_click"
