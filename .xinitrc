# The script I use to start stuff in X

# Disable annoying bell
xset -b &

# Pretty pictures
sh ~/.fehbg &

# X clipboard crap
autocutsel -fork &
autocutsel -selection PRIMARY -fork &

# Compositing = pretty windows + effects
xcompmgr -cfCF -o.75&

# Load my settings for term
[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources

# Conky for the bar
conky | while read -r; do xsetroot -name "$REPLY"; done &

# The main event
exec dwm
