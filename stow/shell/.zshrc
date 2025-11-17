# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Better completion system
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Use caching for better performance
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# Colorize completions using default colors
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# Enable completion for hidden files
setopt globdots

# Autocomplete settings
setopt AUTO_CD              # If a command is a path, cd into it
setopt AUTO_REMOVE_SLASH    # Remove trailing slash when needed
setopt AUTO_PARAM_SLASH     # If completed parameter is a directory, add a trailing slash
setopt COMPLETE_IN_WORD     # Complete from both ends of a word
setopt ALWAYS_TO_END        # Move cursor to the end of a completed word
setopt PATH_DIRS            # Perform path search even on command names with slashes
setopt AUTO_MENU            # Show completion menu on tab press
setopt EXTENDED_GLOB        # Use extended globbing
unsetopt MENU_COMPLETE      # Do not autoselect the first completion entry
unsetopt FLOW_CONTROL       # Disable flow control characters (usually assigned to ^S/^Q)

# Autosuggestions configuration
ZSH_AUTOSUGGEST_STRATEGY=(history completion)  # Use history and completion for suggestions
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20             # Don't suggest for large buffers
ZSH_AUTOSUGGEST_USE_ASYNC=1                    # Use async for suggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"   # Light gray text for suggestions

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Disable Oh My Zsh themes - we use Starship instead
# Starship is a cross-shell prompt that's faster and more customizable
ZSH_THEME=""

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# Plugins (manually configured - add from packages/zsh-plugins.package after installation)
# Built-in Oh My Zsh plugins: git, command-not-found, sudo, history, dirhistory
# External plugins: zsh-autosuggestions, zsh-syntax-highlighting, zsh-completions, 
#                   zsh-history-substring-search, you-should-use, zsh-bat
plugins=(
  git
  command-not-found
  sudo
  history
  dirhistory
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  zsh-history-substring-search
  you-should-use
  zsh-bat
)

source $ZSH/oh-my-zsh.sh

# Initialize Starship prompt (cross-shell, fast, highly customizable)
# Only initialize if Starship is installed
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
else
    # Fallback to a simple prompt if Starship is not installed
    PROMPT='%F{blue}%n@%m%f %F{green}%~%f %# '
fi

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Created by `pipx` on 2025-05-19 14:48:23
export PATH="$PATH:/home/john/.local/bin"

# Console Ninja extension (only add if directory exists)
if [ -d "/home/john/.console-ninja/.bin" ]; then
    export PATH="$PATH:/home/john/.console-ninja/.bin"
fi

# Wayland environment
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export WAYLAND_DISPLAY=wayland-1

# Walker launcher - needs Wayland backend for layer shell support
export WALKER_GDK_BACKEND=wayland
alias walker='GDK_BACKEND=$WALKER_GDK_BACKEND walker'


# Override syntax highlighting colors with vibrant theme
ZSH_HIGHLIGHT_STYLES[default]='none'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ff6464,bold'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#ffc850,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#64c864,bold'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#64c864,bold'
ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#64c864,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#64c864,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=#80d880,bold'
ZSH_HIGHLIGHT_STYLES[command]='fg=#64c864,bold'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=#9696c8,italic'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#b4b4b4'
ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#64c864'
ZSH_HIGHLIGHT_STYLES[path]='fg=#dcdcdc,underline'
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#b4b4b4,underline'
ZSH_HIGHLIGHT_STYLES[path_approx]='fg=#b4b4b4,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#9696c8,bold'
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#9696c8,bold'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#ffc850'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#ffc850'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#ffc850'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#80d880'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#80d880'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#9696c8,bold'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#64c864'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#404040,italic'
ZSH_HIGHLIGHT_STYLES[assign]='fg=#b4b4b4'
export PATH=~/.npm-global/bin:$PATH

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH=~/.npm-global/bin:$PATH

# pnpm
export PNPM_HOME="/home/john/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end
export PATH="$HOME/.npm-global/bin:$PATH"

# Rust cargo binaries
export PATH="$HOME/.cargo/bin:$PATH"

# Colorful terminal tools
if command -v eza &>/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --group-directories-first'
    alias la='eza -lah --icons --group-directories-first'
    alias lt='eza --tree --level=2 --icons'
    alias lta='eza --tree --level=2 --icons -a'
fi

if command -v bat &>/dev/null; then
    alias cat='bat --style=auto'
    alias bcat='bat --style=plain'
    export BAT_THEME="TwoDark"
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

if command -v delta &>/dev/null; then
    export GIT_PAGER="delta"
fi
