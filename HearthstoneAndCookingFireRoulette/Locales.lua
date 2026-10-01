local _, ns = ...

-- Missing translations fall back to the key, so nothing errors if a string is forgotten.
local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

-- enUS / default
-- The addon's name in four parts, each colored on its own.
L.NAME_HEARTHSTONE = "Hearthstone"
L.NAME_AND = " and "
L.NAME_COOKING_FIRE = "Cooking Fire"
L.NAME_ROULETTE = " Roulette"
L.MACRO_NAME = "Macro name"
L.MACRO_ICON = "Macro icon"
L.SELECT_ALL = "Select all"
L.DESELECT_ALL = "Deselect all"
L.NOT_COLLECTED = "not collected"
L.NAME_TAKEN = "Another macro already uses that name."
L.NAME_TOO_LONG = "Macro names can be at most %d characters."
L.NAME_IN_COMBAT = "Can't rename macros in combat."
L.MACRO_CREATED = "Created the account-wide macro '%s'. Open /macro to drag it onto your action bar."
L.MACRO_RENAMED = "Renamed the macro to '%s'."
L.MACROS_FULL = "Couldn't create the macro '%s' because your account-wide macro slots are full."

-- Cooking Fires tab
L.TAB_FIRES = "Cooking Fires"
L.DEFAULT_FIRE_MACRO_NAME = "Cooking Roulette"
L.COOKING_FIRE = "Cooking Fire"
L.NEXT_FIRE = "Next fire"
L.NEXT_FIRE_TOOLTIP = "The icon changes to the fire the macro will use next."
L.TOYS_HEADER = "Choose which cooking fires the macro can place:"
L.NOT_LEARNED = "not learned"
L.SPELL = "spell"
L.CLICK_TO_PLACE = "click to place"
L.NO_TOYS = "You haven't collected any of the selected cooking fire toys, so the macro uses the Cooking Fire spell."

-- Hearthstones tab
L.TAB_HEARTHSTONES = "Hearthstones"
L.DEFAULT_HEARTH_MACRO_NAME = "Hearth Roulette"
L.HEARTHSTONE = "Hearthstone"
L.NEXT_HEARTHSTONE = "Next hearthstone"
L.NEXT_HEARTHSTONE_TOOLTIP = "The icon changes to the hearthstone the macro will use next."
L.HEARTHSTONES_HEADER = "Choose which hearthstones the macro can use:"
L.ITEM = "item"
L.NOT_IN_BAGS = "not in your bags"
L.COVENANT_ONLY = "%s or Renown 80 only" -- %s is the covenant's name
L.COVENANT = "covenant"
L.DRAENEI_ONLY = "draenei only"
L.NO_HEARTHSTONES = "You can't use any of the selected hearthstones, so the macro uses your Hearthstone."

-- /hcfr status
L.STATUS_HEADER = "status (%s)" -- %s is the addon version
L.STATUS_GENERAL = "  Item data: %s. Ready: %s. In combat: %s."
L.STATUS_ITEMS_ALL = "all %d loaded"
L.STATUS_ITEMS_MISSING = "%d of %d loaded, missing %s" -- the last %s lists item IDs
L.STATUS_ITEMS_WAITING = "%d of %d loaded, waiting"
L.STATUS_PAUSED = "no, paused %.0fs ago"
L.STATUS_MACRO = "  %s: macro exists: %s. Next: %s. Update pending: %s. Reroll queued: %s. Last update: %s."
L.STATUS_PENDING = "yes, for %.0fs"
L.STATUS_CAST = "  Last cast: spell %d (%s), %s."
L.STATUS_NOT_OURS = "not one of the addon's"
L.STATUS_CAST_HIDDEN = "  Last cast: hidden by the game, %s."
L.STATUS_CAST_NONE = "  Last cast: none yet."
L.SECONDS_AGO = "%.0fs ago"
L.YES = "yes"
L.NO = "no"
L.NEVER = "never"
L.NONE = "none"
