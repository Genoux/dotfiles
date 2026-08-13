export GTK_USE_PORTAL=0
export CHROME_FLAGS="--enable-features=UseOzonePlatform --ozone-platform=wayland"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
