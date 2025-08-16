hs.loadSpoon("MiddleClickDragScroll"):start()


-- Disable window animations for instant focus/moves
hs.window.animationDuration = 0

-- Define Hyper as the chord ZMK is sending (⇧⌃⌥⌘)
local hyper = {"shift","ctrl","alt","cmd"}

-- Helper: prefer the first installed bundle id in a list
local function focusOrLaunchByBundles(bundles)
  for _, bid in ipairs(bundles) do
    if hs.application.pathForBundleID(bid) then
      hs.application.launchOrFocusByBundleID(bid)
      return
    end
  end
  -- fall back to first even if not found (won't do anything if missing)
  hs.application.launchOrFocusByBundleID(bundles[1])
end

-- Fullscreen-aware app focusing
local spaces = require("hs.spaces")

local function isFullscreenWindow(w)
  if not w or not w:isStandard() or not w:isVisible() then return false end
  if w:isFullScreen() then return true end
  local ws = spaces.windowSpaces(w)            -- windows -> space IDs
  if ws and ws[1] then
    local t = spaces.spaceType(ws[1])          -- "user" or "fullscreen"
    return t == "fullscreen"
  end
  return false
end

local function gotoWindowSpace(w)
  local ws = spaces.windowSpaces(w)
  if ws and ws[1] then
    spaces.gotoSpace(ws[1])                    -- will briefly show Mission Control
  end
  w:focus()
end

-- policy = "only" | "prefer" | "ensure"
local function focusAppFullscreen(bundles, policy)
  policy = policy or "only"
  for _, bid in ipairs(bundles) do
    local app = hs.application.get(bid)
    if app then
      -- look for a fullscreen window
      local fs
      for _, w in ipairs(app:allWindows() or {}) do
        if isFullscreenWindow(w) then fs = w; break end
      end
      if fs then
        gotoWindowSpace(fs)
        return
      end

      if policy == "ensure" then
        local any = app:mainWindow() or (app:allWindows() or {})[1]
        if any then
          any:setFullScreen(true)              -- create a full-screen Space for it
          hs.timer.doAfter(0.15, function()    -- tiny delay so Space exists
            gotoWindowSpace(any)
          end)
          return
        end
      elseif policy == "prefer" then
        local any = app:mainWindow() or (app:allWindows() or {})[1]
        if any then any:focus(); return end
      end

      -- policy == "only" and no FS window -> just notify
      hs.alert.show(("No full‑screen window for %s"):format(app:name() or "app"))
      return
    end
  end

  -- App not running
  if policy ~= "only" then
    hs.application.launchOrFocusByBundleID(bundles[1])
  else
    hs.alert.show("App not running (no full‑screen window to focus)")
  end
end



local function gotoSpaceN(n)
  local uuid   = hs.screen.mainScreen():getUUID()
  local all    = spaces.allSpaces()            -- list of spaces per display
  local list   = all[uuid]
  if list and list[n] then spaces.gotoSpace(list[n]) end
end

-- Hyper + 1..3 → go to Desktop 1..3 (add more lines as needed)
hs.hotkey.bind(hyper, "1", function() gotoSpaceN(1) end)
hs.hotkey.bind(hyper, "2", function() gotoSpaceN(2) end)
hs.hotkey.bind(hyper, "3", function() gotoSpaceN(3) end)


-- Map keys -> apps (Bundle IDs)
local binds = {
  h = { "com.microsoft.edgemac" },                                -- Edge
  j = { "com.googlecode.iterm2", "com.apple.Terminal" },          -- iTerm2 → Terminal fallback
  k = { "md.obsidian", "md.Obsidian" },                           -- Obsidian variants
  l = { "com.openai.chat" },                                     -- Finder
  [";"] = { "com.microsoft.VSCode" },
  ["'"] = { "com.exafunction.windsurf" }, -- Windsurf
  n = { "org.mozilla.firefox" },
  m = { "com.google.Chrome" },
}

for key, bids in pairs(binds) do
  hs.hotkey.bind(hyper, key, function() focusOrLaunchByBundles(bids) end)
end
