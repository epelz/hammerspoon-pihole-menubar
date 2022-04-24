--- === Pihole Status ===
---
--- Show the status of Pihole
---
-- Prevent GC: https://github.com/Hammerspoon/Spoons/blob/master/Source/Caffeine.spoon/init.lua
-- TODO: Is this needed?
local obj = { __gc = true }
setmetatable(obj, obj)
obj.__gc = function(t)
    t:stop()
end

-- Metadata
obj.name = "PiholeStatus"
obj.version = "0.1"
obj.author = "Eric Pelz <contact@ericpelz.com>"
obj.homepage = "https://www.ericpelz.com/"
obj.license = 'MIT - https://opensource.org/licenses/MIT'

-- Constants
local ENABLED="on"
local DISABLED="off"

local function calculateTitle(txt)
    if txt == nil then return "" end
    return string.format("(%s)", txt)
end

local function printableNow()
    return os.date('%Y-%m-%d %H:%M:%S')
end

local function temporarilyDisable()
    print("Temporarily disabling...")
    local fetchUrl = obj.config.pihole_url .. "/admin/api.php?disable=" .. obj.config.pihole_disable_time_s .. "&auth=" .. obj.config.pihole_token
    hs.http.get(fetchUrl, nil, nil)
    obj.timer:setNextTrigger(0)
end

local function enable()
    print("Enabling...")
    local fetchUrl = obj.config.pihole_url .. "/admin/api.php?enable&auth=" .. obj.config.pihole_token
    hs.http.get(fetchUrl, nil, nil)
    obj.timer:setNextTrigger(0)
end

local function updateMenu(results, isEnabled)
    -- Sort and clean up menu items
    table.insert(results, {
        sortVal = 0,
        title = string.format("Last updated: %s", printableNow()),
        fn = function() hs.urlevent.openURL(obj.config.pihole_url .. "/admin/") end,
    })
    if isEnabled
    then
        table.insert(results, {
            sortVal = 1,
            title = "Temporarily Disable Pi-hole",
            fn = function() temporarilyDisable() end,
        })
    else
        table.insert(results, {
            sortVal = 1,
	    title = "Enable Pi-hole",
	    fn = function() enable() end,
	})
    end
    table.insert(results, { sortVal = 2, title = "-" })
    table.sort(results, function(a, b) return a.sortVal < b.sortVal end)

    -- Update menu
    obj.menu:setTitle(calculateTitle(isEnabled and ENABLED or DISABLED))
    obj.menu:setMenu(results)
end

local function onResponse(status, body)
    print("Processing response...", printableNow())

    if status ~= 200 then
        print("Can't process status code", status)
        obj.menu:setTitle(calculateTitle(DISABLED))
        return
    end

    local response = hs.json.decode(body)
    local isEnabled = response.status == "enabled"

    local results = {}
    updateMenu(results, isEnabled)
    print("Menu updated", printableNow())
end

local function onInterval()
    local fetchUrl = obj.config.pihole_url .. "/admin/api.php?summary&auth=" .. obj.config.pihole_token

    print("Fetching now...", printableNow())
    hs.http.asyncGet(fetchUrl, nil, onResponse)
end

--- Pihole:start()
--- Method
--- Starts the Pihole spoon
---
--- Parameters:
---  * config - A table containing configuration:
---              pihole_url:            URL for Pi Hole instance
---              pihole_token:          Pi Hole API Token (required)
---              pihole_disable_time_s: Time to disable pihole, in seconds (default 300)
---              refresh_interval:      Interval in seconds to refresh (default 120)
---
--- Returns:
---  * self
function obj:start(config)
    self.config = config
    self.config.refresh_interval = config.refresh_interval or 120
    self.config.pihole_disable_time_s = config.pihole_disable_time_s or 300

    if self.menu then self:stop() end
    self.menu = hs.menubar.new()
    if self.menu then
        self.menu:setTitle(calculateTitle(nil))
        self.menu:setMenu({
            { title = "Loading..."}
        })
	-- set the icon from the pihole instance
	self.menu:setIcon(hs.image.imageFromURL(config.pihole_url .. "/admin/img/favicons/favicon-32x32.png"):setSize({w=16, h=16}))
    end

    -- Start timer, and immediately start
    self.timer = hs.timer.new(self.config.refresh_interval, onInterval)
    self.timer:start()
    onInterval()

    return self
end

--- Pihole:stop()
--- Method
--- Stop running the spoon
---
--- Parameters: none
---
--- Returns:
---  * self
function obj:stop()
	self.menu:removeFromMenuBar()
	self.timer:stop()

	return self
end

return obj
