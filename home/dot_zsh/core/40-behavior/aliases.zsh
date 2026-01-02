# Core: Aliases
# General aliases and OS-specific shortcuts

# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------
alias ll="ls -alF"
alias lg="ll | grep"

## nvim代替vim
alias nvi="nvim"
alias vi="nvim"

# -----------------------------------------------------------------------------
# OS Specific
# -----------------------------------------------------------------------------
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    
    # Remove "downloaded from internet" quarantine attribute
    alias delnet="sudo xattr -r -d com.apple.quarantine ."
    
    # Tar without hidden files (like .DS_Store)
    alias tarc="tar --disable-copyfile --exclude='.DS_Store' -zcvf"
    
    # Sleep display immediately
    alias sleep_screen="pmset displaysleepnow"
    
    # Get IP address (en0)
    alias ip="ifconfig | grep -A 7 \"^en0\""

elif [[ "$(uname)" == "Linux" ]]; then
    # Linux
    
    # Get IP address (eth0) - Note: Interface name might vary (e.g., ens33, wlan0)
    alias ip="ifconfig | grep -A 7 \"^eth0\""
    
    alias pc="proxychains"
    
    if grep -iq "ubuntu" /etc/os-release; then
        alias openit='nautilus . &' # open .
    fi
fi

# -----------------------------------------------------------------------------
# Python Helpers
# -----------------------------------------------------------------------------

# Get local IP address via Python
alias py_getip="python3 -c \"import socket;print([(s.connect(('8.8.8.8', 53)), s.getsockname()[0], s.close()) for s in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]][0][1])\""

# Get current time via Python
alias py_time="python3 -c \"import datetime; print(datetime.datetime.now().strftime('%Y/%m/%d %H:%M:%S'))\""
