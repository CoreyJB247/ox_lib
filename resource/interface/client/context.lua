--[[
    https://github.com/overextended/ox_lib

    This file is licensed under LGPL-3.0 or higher <https://www.gnu.org/licenses/lgpl-3.0.en.html>

    Copyright © 2025 Linden <https://github.com/thelindat>
]]

local contextMenus = {}
local openContextMenu = nil
local pendingSelection = nil

local cursorFree = false
local altListenerActive = false

local lastFocusChange = -1000

local function setContextFocus(focused)
    if not openContextMenu then return end
    if cursorFree == not focused then return end
    -- The browser and game can both receive the same Alt press.
    local now = GetGameTimer()
    if now - lastFocusChange < 200 then return end
    lastFocusChange = now
    cursorFree = not focused
    SetNuiFocus(focused, focused)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({ action = 'contextFocus', data = focused })
end

RegisterNUICallback('setContextFocus', function(data, cb)
    if type(data.focused) == 'boolean' then setContextFocus(data.focused) end
    cb({ focused = not cursorFree })
end)

local function startAltListener()
    if altListenerActive then return end
    altListenerActive = true

    CreateThread(function()
        while openContextMenu do
            if not cursorFree then
                -- Keep movement available while preventing menu input from controlling the game.
                DisableAllControlActions(0)
                EnableControlAction(0, 30, true)
                EnableControlAction(0, 31, true)
                EnableControlAction(0, 32, true)
                EnableControlAction(0, 33, true)
                EnableControlAction(0, 34, true)
                EnableControlAction(0, 35, true)
            end
            if IsDisabledControlJustPressed(0, 19) or IsControlJustPressed(0, 19) then
                setContextFocus(cursorFree)
            end
            Wait(0)
        end
        altListenerActive = false
    end)
end

---@class ContextMenuItem
---@field title? string
---@field menu? string
---@field icon? string | {[1]: IconProp, [2]: string};
---@field iconColor? string
---@field image? string
---@field progress? number
---@field onSelect? fun(args: any)
---@field arrow? boolean
---@field description? string
---@field metadata? string | { [string]: any } | string[]
---@field disabled? boolean
---@field readOnly? boolean
---@field event? string
---@field serverEvent? string
---@field args? any

---@class ContextMenuArrayItem : ContextMenuItem
---@field title string

---@class ContextMenuProps
---@field id string
---@field title string
---@field menu? string
---@field onExit? fun()
---@field onBack? fun()
---@field canClose? boolean
---@field options { [string]: ContextMenuItem } | ContextMenuArrayItem[]

local function closeContext(_, cb, onExit)
    if pendingSelection then
        openContextMenu = openContextMenu or pendingSelection.id
        pendingSelection = nil
    end
    if cb then cb(1) end
    if not openContextMenu then return end

    cursorFree = false
    lib.resetNuiFocus()

    if (cb or onExit) and contextMenus[openContextMenu].onExit then contextMenus[openContextMenu].onExit() end

    if not cb then SendNUIMessage({ action = 'hideContext' }) end

    openContextMenu = nil
end

---@param id string
function lib.showContext(id, resetScroll)
    if not contextMenus[id] then error('No context menu of such id found.') end

    local data = contextMenus[id]
    local refresh = openContextMenu == id or (pendingSelection and pendingSelection.id == id) or false
    local wasOpen = openContextMenu ~= nil or pendingSelection ~= nil
    pendingSelection = nil
    openContextMenu = id

    if not wasOpen then
        cursorFree = false
        lastFocusChange = -1000
        lib.setNuiFocus(true)
    end
    startAltListener()

    SendNuiMessage(json.encode({
        action = 'showContext',
        data = {
            id = id,
            refresh = refresh,
            resetScroll = resetScroll == true,
            focused = not cursorFree,
            title = data.title,
            canClose = data.canClose,
            menu = data.menu,
            options = data.options
        }
    }, { sort_keys = true }))
end

---@param context ContextMenuProps | ContextMenuProps[]
function lib.registerContext(context)
    for k, v in pairs(context) do
        if type(k) == 'number' then
            contextMenus[v.id] = v
        else
            contextMenus[context.id] = context
            break
        end
    end
end

---@return string?
function lib.getOpenContextMenu() return openContextMenu end

---@param onExit boolean?
function lib.hideContext(onExit) closeContext(nil, nil, onExit) end

RegisterNUICallback('openContext', function(data, cb)
    if not openContextMenu or not contextMenus[data.id] then cb(1) return end
    if data.back and contextMenus[openContextMenu].onBack then contextMenus[openContextMenu].onBack() end
    cb(1)
    lib.showContext(data.id, not data.back)
end)

RegisterNUICallback('clickContext', function(id, cb)
    cb(1)

    if math.type(tonumber(id)) == 'float' then
        id = math.tointeger(id)
    elseif tonumber(id) then
        id += 1
    end

    if not openContextMenu then return end
    local data = contextMenus[openContextMenu].options[id]
    if not data or data.disabled or data.readOnly then return end

    if not data.event and not data.serverEvent and not data.onSelect then return end

    -- Allow an immediate showContext from the action to reuse the visible menu and focus.
    local selection = { id = openContextMenu }
    pendingSelection = selection
    openContextMenu = nil
    SetTimeout(0, function()
        if pendingSelection ~= selection then return end
        pendingSelection = nil
        cursorFree = false
        SendNUIMessage({ action = 'hideContext' })
        lib.resetNuiFocus()
    end)

    if data.onSelect then data.onSelect(data.args) end
    if data.event then TriggerEvent(data.event, data.args) end
    if data.serverEvent then TriggerServerEvent(data.serverEvent, data.args) end
end)

RegisterNUICallback('closeContext', closeContext)



