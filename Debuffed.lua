--[[
Copyright © 2019, Xathe
All rights reserved. (Debuffed)
Merged with Charmed (by wes, mod by icy), mod by Persona

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
    * Neither the name of Debuffed nor the
    names of its contributors may be used to endorse or promote products
    derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Xathe BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

_addon.name = 'Debuffed'
_addon.author = 'Xathe (Asura) / wes / icy, merged and mod by Persona'
_addon.version = '1.2.0'
_addon.commands = {'dbf','debuffed'}

require('sets')
require('functions')
require('lists')
require('strings')
require('logger')
config = require('config')
packets = require('packets')
res = require('resources')
texts = require('texts')
images = require('images')

--------------------------------------------------------------------------------
-- Default Settings Setup (Merged)
--------------------------------------------------------------------------------
defaults = {}
defaults.interval = .1
defaults.mode = 'blacklist'
defaults.timers = true
defaults.hide_below_zero = false
defaults.whitelist = S{}
defaults.blacklist = S{}
defaults.colors = {
    player = {red = 255, green = 255, blue = 255},
    others = {red = 255, green = 255, blue = 0}
}

-- Charmed specific defaults nested to keep settings.xml clean
defaults.charmed_ui = {}
local x_pos = windower.get_windower_settings().ui_x_res - 17
local y_pos = windower.get_windower_settings().ui_y_res + 2

local pos_base = {-42, -397, -296}
local pt_y_pos = {}
for i = 1, 6 do
    pt_y_pos[i] = -42 - 20 * (6 - i)
end
local key_indices = {p0 = 1, p1 = 2, p2 = 3, p3 = 4, p4 = 5, p5 = 6}

for i = 0, 17 do
    local party = (i / 6):floor() + 1
    local key = {'p%i', 'a1%i', 'a2%i'}[party]:format(i % 6)
    
    local default_y = 0
    if key:startswith('p') then
        default_y = pt_y_pos[key_indices[key]]
    else
        default_y = pos_base[party] + 16 * (i % 6)
    end
    
    defaults.charmed_ui[key] = {x = x_pos, y = y_pos + default_y}
end

settings = config.load(defaults)

--------------------------------------------------------------------------------
-- Debuffed Variables
--------------------------------------------------------------------------------
box = texts.new('${current_string}', settings)
box:show()

list_commands = T{w='whitelist', wlist='whitelist', white='whitelist', whitelist='whitelist', b='blacklist', blist='blacklist', black='blacklist', blacklist='blacklist'}
sort_commands = T{a='add', add='add', ['+']='add', r='remove', remove='remove', ['-']='remove'}

player_id = 0
frame_time = 0
debuffed_mobs = {}

--------------------------------------------------------------------------------
-- Charmed Variables
--------------------------------------------------------------------------------
test_display = false 
charm_icon = string.format('%sdata/icons/%s.png', windower.addon_path, '17')
alliance = T{}
new_charms = L{}
new_uncharms = L{}

local text_box_settings = {
    pos = {x = windower.get_windower_settings().ui_x_res - 150, y = y_pos},
    text = {font = 'Consolas', size = 10, red = 255, green = 255, blue = 255},
    flags = {draggable = true, bold = true},
    bg = {alpha = 150, red = 0, green = 0, blue = 0, visible = true},
    padding = 5
}
charm_box = texts.new(text_box_settings)

for i = 0, 17 do
    local party = (i / 6):floor() + 1
    local key = {'p%i', 'a1%i', 'a2%i'}[party]:format(i % 6)
    alliance[key] = T{box = nil, img = nil}
end

--------------------------------------------------------------------------------
-- Core Functions
--------------------------------------------------------------------------------
function get_color(actor)
    if actor == player_id then
        return '%s,%s,%s':format(settings.colors.player.red, settings.colors.player.green, settings.colors.player.blue)
    else
        return '%s,%s,%s':format(settings.colors.others.red, settings.colors.others.green, settings.colors.others.blue)
    end
end

function update_debuff_box()
    local lines = L{}
    local target = windower.ffxi.get_mob_by_target('t')
    
    if target and target.valid_target and (target.claim_id ~= 0 or target.spawn_type == 16) then
        local data = debuffed_mobs[target.id]
        
        if data then
            for effect, spell in pairs(data) do
                local name = res.spells[spell.id].name
                local remains = math.max(0, spell.timer - os.clock())
                
                if settings.mode == 'whitelist' and settings.whitelist:contains(name) or settings.mode == 'blacklist' and not settings.blacklist:contains(name) then
                    if settings.timers and remains > 0 then
                        lines:append('\\cs(%s)%s: %.0f\\cr':format(get_color(spell.actor), name, remains))
                    elseif remains < 0 and settings.hide_below_zero then
                        debuffed_mobs[target.id][effect] = nil
                    else
                        lines:append('\\cs(%s)%s\\cr':format(get_color(spell.actor), name))
                    end
                end
            end
        end
    end
    
    if lines:length() == 0 then
        box.current_string = ''
    else
        box.current_string = 'Debuffed [' .. target.name .. ']\n\n' .. lines:concat('\n')
    end
end

function update_charmed_ui()
    local party = T(windower.ffxi.get_party())
    new_charms:clear()
    new_uncharms:clear()
    local current_charmed_names = L{}
    
    -- List of DoT keywords that will break sleep
    local dot_keywords = S{'Poison', 'Dia', 'Bio', 'Requiem', 'Helix', 'Burn', 'Rasp', 'Drown', 'Frost', 'Choke', 'Shock'}

    for slot, key in alliance:it() do
        local member = party[key]
        local is_charmed = test_display or (member and member.mob and member.mob.valid_target and member.mob.charmed and not member.mob.is_npc)

        if is_charmed then
            if member and member.mob then 
                -- Lookup the player's ID in Debuffed's tracking table
                local debuff_text = ""
                local data = debuffed_mobs[member.mob.id]
                
                if data then
                    local d_list = L{}
                    for effect, spell in pairs(data) do
                        local name = res.spells[spell.id].name
                        local remains = math.max(0, spell.timer - os.clock())
                        
                        -- Apply the same filtering as the main Debuffed box
                        if settings.mode == 'whitelist' and settings.whitelist:contains(name) or settings.mode == 'blacklist' and not settings.blacklist:contains(name) then
                            if remains < 0 and settings.hide_below_zero then
                                -- Clean up expired timers if setting is true
                                debuffed_mobs[member.mob.id][effect] = nil
                            else
                                -- Check if the debuff is one of our DoT keywords
                                local is_dot = false
                                for keyword in dot_keywords:it() do
                                    if name:find(keyword) then
                                        is_dot = true
                                        break
                                    end
                                end
                                
                                local entry_text = name
                                if settings.timers and remains > 0 then
                                    entry_text = entry_text .. ': ' .. string.format('%.0f', remains)
                                end
                                
                                -- Color it bright red if it's a DoT, otherwise leave it default white
                                if is_dot then
                                    entry_text = '\\cs(255,50,50)' .. entry_text .. '\\cr'
                                end
                                
                                d_list:append(entry_text)
                            end
                        end
                    end
                    
                    -- If they have debuffs, format them nicely next to the name
                    if d_list:length() > 0 then
                        debuff_text = " [" .. d_list:concat(', ') .. "]"
                    end
                end
                
                current_charmed_names:append(member.name .. debuff_text) 
            end
            
            -- Handle the visual icons
            if slot.img == nil then
                slot.img = images.new({ draggable = test_display, visible = false })
                slot.img:path(charm_icon)
                slot.img:pos(settings.charmed_ui[key].x, settings.charmed_ui[key].y)
                slot.img:fit(false)
                slot.img:size(15, 15)
                slot.img:show()
                if not test_display and member then
                    new_charms:append(member.name)
                end
            else 
                if not test_display then
                    slot.img:pos(settings.charmed_ui[key].x, settings.charmed_ui[key].y)
                    slot.img:draggable(false)
                else
                    slot.img:draggable(true)
                end
            end
        else
            -- Hide and destroy icons for uncharmed players
            if slot.img ~= nil then
                slot.img:hide()
                slot.img:destroy()
                slot.img = nil
                if not test_display and member then
                    new_uncharms:append(member.name)
                end
            end
        end
    end
    
    -- Draw the Text Box
    if current_charmed_names:length() > 0 or test_display then
        local box_text = "DANGER - CHARMED:\n " .. current_charmed_names:concat('\n ')
        if test_display then box_text = "DANGER - CHARMED:\n TestName1 [Sleep II: 45, \\cs(255,50,50)Dia II: 10\\cr]\n TestName2" end
        charm_box:text(box_text)
        charm_box:show()
    else
        charm_box:hide()
    end
    
    -- Chat alerts
    if not test_display then
        if not new_charms:empty() then
            windower.add_to_chat(123, 'CHARM <3 CHARM <3 CHARM <3 CHARM <3 CHARM')
            windower.add_to_chat(123, '  ' .. new_charms:sort():concat(', '))
            windower.add_to_chat(123, 'CHARM <3 CHARM <3 CHARM <3 CHARM <3 CHARM')
        end
        if not new_uncharms:empty() then
            windower.add_to_chat(121, 'uncharmed: ' .. new_uncharms:sort():concat(' '))
        end
    end
end

--------------------------------------------------------------------------------
-- Debuffed Packet Parsing Logic
--------------------------------------------------------------------------------
function handle_overwrites(target, new, t)
    if not debuffed_mobs[target] then return true end
    
    for effect, spell in pairs(debuffed_mobs[target]) do
        local old = res.spells[spell.id].overwrites or {}
        if table.length(old) > 0 then
            for _,v in ipairs(old) do
                if new == v then return false end
            end
        end
        if table.length(t) > 0 then
            for _,v in ipairs(t) do
                if spell.id == v then debuffed_mobs[target][effect] = nil end
            end
        end
    end
    return true
end

function apply_debuff(target, effect, spell, actor)
    if not debuffed_mobs[target] then debuffed_mobs[target] = {} end
    local overwrites = res.spells[spell].overwrites or {}
    if not handle_overwrites(target, spell, overwrites) then return end
    debuffed_mobs[target][effect] = {id=spell, timer=(os.clock() + (res.spells[spell].duration or 0)), actor=actor}
end

function handle_shot(target)
    if not debuffed_mobs[target] or not debuffed_mobs[target][134] then return true end
    local current = debuffed_mobs[target][134].id
    if current < 26 then debuffed_mobs[target][134].id = current + 1 end
end

function inc_action(act)
    if act.category ~= 4 then
        if act.category == 6 and act.param == 131 then handle_shot(act.targets[1].id) end
        return
    end
    
    if S{2,252}:contains(act.targets[1].actions[1].message) then
        local target, spell, actor = act.targets[1].id, act.param, act.actor_id
        local effect = res.spells[spell].status
        if effect then apply_debuff(target, effect, spell, actor) end
    elseif S{236,237,268,271}:contains(act.targets[1].actions[1].message) then
        local target, effect, spell, actor = act.targets[1].id, act.targets[1].actions[1].param, act.param, act.actor_id
        if res.spells[spell].status and res.spells[spell].status == effect then apply_debuff(target, effect, spell, actor) end
    end
end

function inc_action_message(arr)
    if S{6,20,113,406,605,646}:contains(arr.message_id) then
        debuffed_mobs[arr.target_id] = nil
    elseif S{64,204,206,350,531}:contains(arr.message_id) then
        if debuffed_mobs[arr.target_id] then debuffed_mobs[arr.target_id][arr.param_1] = nil end
    end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------
windower.register_event('login','load', function()
    player_id = (windower.ffxi.get_player() or {}).id
end)

windower.register_event('logout','zone change', function()
    debuffed_mobs = {}
end)

windower.register_event('incoming chunk', function(id, data)
    if id == 0x028 then
        inc_action(windower.packets.parse_action(data))
    elseif id == 0x029 then
        local arr = {}
        arr.target_id = data:unpack('I',0x09)
        arr.param_1 = data:unpack('I',0x0D)
        arr.message_id = data:unpack('H',0x19)%32768
        inc_action_message(arr)
    end
end)

-- Shared loop handles both UI updates efficiently
windower.register_event('prerender', function()
    local curr = os.clock()
    if curr > frame_time + settings.interval then
        frame_time = curr
        update_debuff_box()
        update_charmed_ui()
    end
end)

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------
windower.register_event('addon command', function(command1, command2, ...)
    local args = L{...}
    command1 = command1 and command1:lower() or nil
    command2 = command2 and command2:lower() or nil
    
    -- Routing for Charmed commands
    if command1 == 'charmed' then
        if command2 == 'debug' then
            test_display = not test_display
            if test_display then
                windower.add_to_chat(207, '[Debuffed: Charmed UI] Debug mode ON: All icons and text box shown.')
            else
                for slot, key in alliance:it() do
                    if slot.img then
                        settings.charmed_ui[key].x, settings.charmed_ui[key].y = slot.img:pos()
                    end
                end
                config.save(settings)
                windower.add_to_chat(207, '[Debuffed: Charmed UI] Debug mode OFF: Positions saved.')
            end
            update_charmed_ui()
            return
        elseif command2 == 'align' then
            local anchor_x = settings.charmed_ui['p0'].x
            if alliance['p0'] and alliance['p0'].img then anchor_x = select(1, alliance['p0'].img:pos()) end
            
            for slot, key in alliance:it() do
                local current_y = settings.charmed_ui[key].y
                if slot.img then
                    current_y = select(2, slot.img:pos())
                    slot.img:pos(anchor_x, current_y)
                end
                settings.charmed_ui[key].x, settings.charmed_ui[key].y = anchor_x, current_y
            end
            config.save(settings)
            windower.add_to_chat(207, '[Debuffed: Charmed UI] Aligned icons to p0.')
            update_charmed_ui()
            return
        elseif command2 == 'reset' then
            for slot, key in alliance:it() do
                settings.charmed_ui[key].x, settings.charmed_ui[key].y = defaults.charmed_ui[key].x, defaults.charmed_ui[key].y
                if slot.img then slot.img:pos(settings.charmed_ui[key].x, settings.charmed_ui[key].y) end
            end
            config.save(settings)
            windower.add_to_chat(207, '[Debuffed: Charmed UI] Positions reset.')
            update_charmed_ui()
            return
        end
    end

    -- Original Debuffed commands
    local name = args:concat(' ')
    if command1 == 'm' or command1 == 'mode' then
        settings.mode = (settings.mode == 'blacklist') and 'whitelist' or 'blacklist'
        log('Changed to %s mode.':format(settings.mode))
        settings:save()
    elseif command1 == 't' or command1 == 'timers' then
        settings.timers = not settings.timers
        log('Timer display %s.':format(settings.timers and 'enabled' or 'disabled'))
        settings:save()
    elseif command1 == 'i' or command1 == 'interval' then
        settings.interval = tonumber(command2) or .1
        log('Refresh interval set to %s seconds.':format(settings.interval))
        settings:save()
    elseif command1 == 'h' or command1 == 'hide' then
        settings.hide_below_zero = not settings.hide_below_zero
        log('Timers that reach 0 will be %s.':format(settings.hide_below_zero and 'hidden' or 'shown'))
        settings:save()
    elseif list_commands:containskey(command1) then
        if sort_commands:containskey(command2) then
            local spell = res.spells:with('name', windower.wc_match-{name})
            command1 = list_commands[command1]
            command2 = sort_commands[command2]
            
            if spell == nil then
                error('No spells found that match: %s':format(name))
            elseif command2 == 'add' then
                settings[command1]:add(spell.name)
                log('Added spell to %s: %s':format(command1, spell.name))
            else
                settings[command1]:remove(spell.name)
                log('Removed spell from %s: %s':format(command1, spell.name))
            end
            settings:save()
        end
    else
        print('%s (v%s)':format(_addon.name, _addon.version))
        print('    \\cs(255,255,255)mode\\cr - Switches between blacklist and whitelist mode')
        print('    \\cs(255,255,255)timers\\cr - Toggles display of debuff timers')
        print('    \\cs(255,255,255)interval <value>\\cr - Allows you to change the refresh interval')
        print('    \\cs(255,255,255)blacklist|whitelist add|remove <name>\\cr - Edits spell lists')
        print('    \\cs(255,150,150)charmed debug|align|reset\\cr - Manage Charmed UI elements')
    end
end)