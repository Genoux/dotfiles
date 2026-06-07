local restoreBurstMs = 15000
local restoreFixDelayMs = 500

local restoreBurstActive = false

local restoreFixes = {
  {
    title = "^Picture%-in%-Picture$",
    apply = function(window)
      if not window.pinned then
        hl.dispatch(hl.dsp.window.pin({ window = window.address }))
      end
    end,
  },
  {
    class = "^mpv$",
    apply = function(window)
      if not window.pinned then
        hl.dispatch(hl.dsp.window.pin({ window = window.address }))
      end
    end,
  },
  {
    class = "^wisper$",
    apply = function(window)
      if not window.pinned then
        hl.dispatch(hl.dsp.window.pin({ window = window.address }))
      end
    end,
  },
}

local function windowMatches(window, pattern)
  if pattern.class ~= nil and not window.class:match(pattern.class) then
    return false
  end

  if pattern.title ~= nil and not window.title:match(pattern.title) then
    return false
  end

  return true
end

local function reapplyPostRestoreFixes(window)
  for _, fix in ipairs(restoreFixes) do
    if windowMatches(window, fix) then
      fix.apply(window)
    end
  end
end

local function schedulePostRestoreFix(window)
  hl.timer(function()
    reapplyPostRestoreFixes(window)
  end, { timeout = restoreFixDelayMs, type = "oneshot" })
end

local function applyPostRestoreFixesToAll()
  for _, window in ipairs(hl.get_windows()) do
    reapplyPostRestoreFixes(window)
  end
end

hl.on("hyprland.start", function()
  restoreBurstActive = true

  hl.timer(function()
    restoreBurstActive = false
    applyPostRestoreFixesToAll()
  end, { timeout = restoreBurstMs, type = "oneshot" })
end)

hl.on("window.open", function(window)
  if restoreBurstActive then
    schedulePostRestoreFix(window)
  end
end)

-- hyprsession restore can land before titles/classes settle; retry once on title change.
hl.on("window.title", function(window)
  if restoreBurstActive then
    schedulePostRestoreFix(window)
  end
end)
