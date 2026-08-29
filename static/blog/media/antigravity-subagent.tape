Output "/Users/dimetron/p6s/pi-dev/pi-go.sh/blog/media/antigravity-subagent.gif"

Set Shell "bash"
Set FontSize 14
Set Width 1449
Set Height 900
Set Padding 24
Set Theme "Catppuccin Macchiato"
Set TypingSpeed 20ms
Set Framerate 24
Set PlaybackSpeed 1
Set Margin 20
Set MarginFill "#674EFF"
Set BorderRadius 10
Set WindowBar "Colorful"

Hide
Type "cd /Users/dimetron/p6s/pi-dev/pi-go.sh && clear" Enter
Show

Sleep 1s
Type "pi --model mistral/zai-glm-5-2"
Sleep 500ms
Enter
Wait+Screen@300s /tkn:/
Sleep 2s
Type "@agy say Hi!"
Sleep 1s
Enter
Wait+Screen@300s /took [0-9]+[.][0-9]+s/
Sleep 4s
