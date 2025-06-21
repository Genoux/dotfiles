# 📁 Adding New Configs to Stow

## 🎯 **Simple Process:**

### 1. **Copy your config to stow/**
```bash
# For a new app config
cp -r ~/.config/newapp stow/newapp/.config/

# Create the proper structure:
# stow/newapp/.config/newapp/
```

### 2. **Install the config**
```bash
./dotfiles.sh
# Choose option 6) Install Config
# Enter: newapp
```

### 3. **Test it**
```bash
./dotfiles.sh
# Choose option 5) List Available Configs
# Should show ✅ newapp (linked)
```

## 📂 **Directory Structure:**

Your stow folder should look like:
```
stow/
├── newapp/
│   └── .config/
│       └── newapp/
│           ├── config.toml
│           └── other-files...
├── hypr/
├── kitty/
└── manage-configs.sh
```

## 🔄 **How It Works:**

1. **stow creates symlinks:** `~/.config/newapp` → `~/dotfiles/stow/newapp/.config/newapp`
2. **You edit normally:** Edit files in `~/.config/newapp/`
3. **Changes save to dotfiles:** Since it's symlinked, changes go to your git repo
4. **Commit when ready:** `git add . && git commit -m "Add newapp config"`

## 🏠 **For Other Locations:**

Not all configs go in `~/.config/`. For other locations:

```bash
# For home directory files (.zshrc, .bashrc, etc.)
stow/shell/
├── .zshrc
├── .bashrc
└── .profile

# For system files
stow/system/
└── .config/
    ├── mimeapps.list
    └── user-dirs.dirs
```

## ✅ **Example - Adding Zed Editor:**

```bash
# 1. Copy config
cp -r ~/.config/zed stow/zed/.config/

# 2. Install it
./dotfiles.sh
# Choose option 6) Install Config
# Enter: zed

# 3. Verify
ls -la ~/.config/zed
# Should show: zed -> /home/john/dotfiles/stow/zed/.config/zed
```

## 🎉 **That's it!**

Now `zed` is managed by your dotfiles and will sync across all your machines! 