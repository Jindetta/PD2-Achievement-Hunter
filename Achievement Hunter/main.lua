local Net, this =
    LuaNetworking,
    {
        user = Steam:userid(),
        cooldown = os.clock(),
        friend_color = "FFFF7F",
        normal_color = "AAAA40",
        highlight_color = Color.green,
        default_index = 1,
        delay = 5,
        fileWrapper = function(file, mode, data, clbk)
            local f = io.open(file, mode)
            if type(f) == "userdata" then
                if type(clbk) == "function" then
                    data = clbk(f) or data
                end
                f:close()
            end
            return data
        end,
        setMenuFunc = function(menu, func_data)
            menu = MenuHelper:GetMenu(menu)
            if menu and type(func_data) == "table" then
                func_data._ = func_data._ or function()
                    end

                for key, item in ipairs(menu._items or {}) do
                    local func_name = func_data[item:name()]
                    local func_type = func_data[item._type]

                    if type(func_name) == "function" then
                        func_name(item, key)
                    elseif type(func_type) == "function" then
                        func_type(item, key)
                    end

                    func_data._(item, key)
                end
            end
        end,
        getKeyFromLobby = function(id)
            local lobby = Steam:lobby(id)
            local key = lobby and lobby:key_value("achievement")

            return key ~= "value_missing" and key ~= "value_pending" and key or nil
        end,
        getAchievementInfo = function(id, description)
            local td = tweak_data.achievement.visual[id]

            return td and managers.localization:text(description and td.desc_id or td.name_id)
        end,
        getValidColor = function(color, default)
            color = color:upper()
            if color:find("^[0-9A-F]+$") ~= nil then
                return string.format("%6s", color):gsub(" ", "0")
            end
            return default
        end,
        hook = function(name)
            return "AchieHunter_" .. tostring(name) .. "_Hook"
        end,
        name = "menu_achihunter_mod_id",
        desc = "menu_achihunter_mod_desc",
        keybind = {
            name = "item_achihunter_keybind_id",
            desc = "item_achihunter_keybind_desc"
        },
        set_title = {
            name = "item_achihunter_set_id",
            desc = "item_achihunter_set_desc"
        },
        no_highlight = {
            name = "item_achihunter_no_highlight_id",
            desc = "item_achihunter_no_highlight_desc"
        },
        reset_all = {
            name = "item_achihunter_reset_all_id",
            desc = "item_achihunter_reset_all_desc"
        },
        clear = {
            name = "item_achihunter_clear_id",
            desc = "item_achihunter_clear_desc"
        },
        dialog = {
            confirm = "dialog_achihunter_confirmation_msg",
            popup = "dialog_achihunter_popup_msg",
            yes = "dialog_achihunter_option_yes",
            no = "dialog_achihunter_option_no"
        },
        color = {
            normal = "item_achihunter_normal_color_id",
            normal_desc = "item_achihunter_normal_color_desc",
            friend = "item_achihunter_friend_color_id",
            friend_desc = "item_achihunter_friend_color_desc",
            scheme_name = "item_achihunter_color_scheme_id",
            scheme_desc = "item_achihunter_color_scheme_desc"
        },
        text = {
            welcome = "chat_achihunter_text_is_welcome",
            changed = "chat_achihunter_text_is_changed",
            current = "chat_achihunter_text_is_current"
        }
    }

if not AchieHunter then
    AchieHunter = AchieHunter or {}
    AchieHunter._lang = ModPath .. "localization/"
    AchieHunter._save = SavePath .. "achievement_hunter.json"

    function AchieHunter:getLanguage()
        local system_key = SystemInfo:language():key()
        local blt_index = LuaModManager:GetLanguageIndex()
        local blt_supported, system_language, blt_language = {
            "english",
            "chinese_traditional",
            "german",
            "spanish",
            "french",
            "indonesian",
            "turkish",
            "russian",
            "chinese_simplified"
        }

        for key, name in ipairs(file.GetFiles(self._lang) or {}) do
            key = name:gsub("%.json$", ""):lower()

            if blt_supported[blt_index] == key then
                blt_language = self._lang .. name
            end

            if key ~= "english" and system_key == key:key() then
                system_language = self._lang .. name
                break
            end
        end

        return system_language or blt_language or ""
    end

    function AchieHunter:getVar(setting, default_value)
        if self._conf and self._conf[this.user] then
            return self._conf[this.user][setting] or default_value
        end

        return default_value
    end

    function AchieHunter:setVar(setting, value)
        if self._conf and self._conf[this.user] then
            self._conf[this.user][setting] = value
        end
    end

    function AchieHunter:setupConfig(force_defaults)
        if force_defaults then
            self._conf = self._conf or {}
            self._conf[this.user] = {}
        end

        self:setVar("normal_color", self:getVar("normal_color", this.normal_color))
        self:setVar("friend_color", self:getVar("friend_color", this.friend_color))
        self:setVar("no_highlight", self:getVar("no_highlight", false))
        self:setVar("set_title", self:getVar("set_title", false))
        self:setVar("key", self:getVar("key", ""))
    end

    function AchieHunter:saveConfig()
        this.fileWrapper(
            self._save,
            "w+",
            nil,
            function(f)
                f:write(json.encode(self._conf))
            end
        )
    end

    function AchieHunter:loadConfig()
        this.fileWrapper(
            self._save,
            "r",
            nil,
            function(f)
                local valid, data = pcall(json.decode, f:read("*a"))
                if valid and type(data) == "table" then
                    self._conf = data
                end
            end
        )
    end

    function AchieHunter:sendMessage(msg, peer)
        if managers.network and managers.network:session() then
            if Net:IsHost() and not Global.game_settings.single_player then
                local chat = managers.chat

                if type(peer) == "number" then
                    peer = managers.network:session():peer(peer)

                    if peer then
                        peer:send("send_chat_message", chat.GAME, msg)
                    end
                else
                    if peer == "" then
                        chat:send_message(chat.GAME, Steam:username(), msg)
                    else
                        chat:receive_message_by_name(chat.GAME, "() " .. Steam:username(), msg)
                    end
                end
            end
        end
    end

    function AchieHunter:setupMod()
        self._conf = self._conf or {}
        self._conf[this.user] = self._conf[this.user] or {}

        if not self._loaded then
            self._loaded = true
            self:loadConfig()

            this.active = self:getVar("current")
        end

        self:setupConfig()
        self:setupHooks(RequiredScript)
    end

    function AchieHunter:setupHooks(hook)
        if hook == "lib/setups/setup" then
            Hooks:PostHook(
                Setup,
                "update",
                this.hook("SetupUpdate"),
                function()
                    if
                        (managers.hud and managers.hud._chat_focus) or
                            (managers.menu_component and managers.menu_component._game_chat_gui and
                                managers.menu_component._game_chat_gui:input_focus())
                     then
                        return
                    end

                    local key, id = self:getVar("key", ""), self:getVar("current", "")
                    if key ~= "" and os.clock() >= this.cooldown then
                        if
                            key:find("mouse ") and Input:mouse():pressed(key:sub(7)) or
                                Input:keyboard():pressed(key:id())
                         then
                            self:sendMessage(this.getAchievementInfo(id, true), "")
                            this.cooldown = os.clock() + this.delay
                        end
                    end
                end
            )
        elseif hook == "lib/network/matchmaking/networkmatchmakingsteam" then
            Hooks:PostHook(
                NetworkMatchMakingSTEAM,
                "set_attributes",
                this.hook("MatchmakingSetAttributes"),
                function(menu)
                    if menu.lobby_handler then
                        local data = self:getVar("current")
                        local achievement = this.getAchievementInfo(data)
                        if achievement and self:getVar("set_title") then
                            menu._lobby_attributes.owner_name = achievement
                        end

                        menu._lobby_attributes.achievement = data
                        menu.lobby_handler:set_lobby_data(menu._lobby_attributes)
                    end
                end
            )
        elseif hook == "lib/managers/crimenetmanager" then
            local _mouse_pressed = CrimeNetGui.mouse_pressed
            function CrimeNetGui:mouse_pressed(o, button, x, y)
                if button == Idstring("1") then
                    for _, job in pairs(self._jobs) do
                        if job.achievement and job.mouse_over == 1 then
                            QuickMenu:new(
                                job.host_name,
                                managers.localization:text(
                                    this.dialog.popup,
                                    {title = this.getAchievementInfo(job.achievement)}
                                ),
                                {},
                                true
                            )

                            return true
                        end
                    end
                end

                return _mouse_pressed(self, o, button, x, y)
            end
            local _create_gui = CrimeNetGui._create_job_gui
            function CrimeNetGui._create_job_gui(menu, data, _type, x, y, location)
                local gui = _create_gui(menu, data, _type, x, y, location)
                if _type == "server" then
                    gui.achievement = this.getKeyFromLobby(gui.room_id)
                    gui.server = true

                    if gui.achievement and not self:getVar("no_highlight") then
                        local color = self:getVar("normal_color", this.normal_color)

                        if data.is_friend then
                            color = self:getVar("friend_color", this.friend_color)
                        end

                        gui.side_panel:child("host_name"):set_color(Color(color))
                        gui.side_panel:child("host_name"):set_blend_mode("normal")
                    end
                end
                return gui
            end
            Hooks:PostHook(
                CrimeNetGui,
                "update_server_job",
                this.hook("CrimeNetUpdateJob"),
                function(menu, data, id)
                    id = data.id or id
                    if menu:_update_job_variable(id, "achievement", this.getKeyFromLobby(id)) then
                        local job = menu._jobs[id]
                        menu:remove_job(id, true)
                        menu._jobs[id] = menu:_create_job_gui(data, "server", job.job_x, job.job_y, job.location)
                    end
                end
            )
        elseif hook == "lib/managers/menu/achievementlistgui" then
            local _mouse_clicked = AchievementListItem.mouse_clicked
            function AchievementListItem:mouse_clicked(o, button, x, y)
                if button == Idstring("1") and self._click:inside(x, y) then
                    this.active = self._title:color() ~= this.highlight_color and self._id or nil

                    return true
                end

                return _mouse_clicked(self, o, button, x, y)
            end
            Hooks:PostHook(
                AchievementListGui,
                "keep_filling_list",
                this.hook("AchievementGuiFill"),
                function(menu)
                    if not menu._adding_to_data then
                        local selected_item = menu._scroll:selected_item()
                        for _, item in ipairs(menu._scroll:items() or {}) do
                            item:_selected_changed(item == selected_item)
                        end
                    end
                end
            )
            function AchievementListItem:_selected_changed(state)
                self._select_panel:set_visible(state)
                if self._id == this.active then
                    self._title:set_color(state and this.highlight_color or this.highlight_color:with_alpha(0.75))
                    self._desc:set_color(
                        state and this.highlight_color:with_alpha(0.85) or this.highlight_color:with_alpha(0.5)
                    )
                else
                    self._title:set_color(state and self.ST_COLOR or self.NT_SD_COLOR)
                    self._desc:set_color(state and self.NT_SD_COLOR or self.ND_COLOR)
                end

                if self._track then
                    self._track:_selected_changed(state)
                end

                if self._force then
                    self._force:_selected_changed(state)
                end
            end
            Hooks:PostHook(
                AchievementListGui,
                "init",
                this.hook("AchievementGuiInit"),
                function(menu)
                    menu._legends:add_item(
                        {
                            text_id = this.clear.name,
                            binding = "menu_preview_achievement",
                            func = function()
                                this.active = nil
                                QuickMenu:new(
                                    managers.localization:text(this.clear.name),
                                    managers.localization:text(this.clear.desc),
                                    {},
                                    true
                                )
                            end
                        }
                    )
                end
            )
            Hooks:PostHook(
                AchievementListGui,
                "close",
                this.hook("AchievementGuiClose"),
                function(menu)
                    MenuCallbackHandler[this.name]()
                end
            )
        else
            Hooks:Add(
                "BaseNetworkSessionOnPeerEnteredLobby",
                this.hook("SessionPeerEntered"),
                function(peer, id)
                    local data = this.getAchievementInfo(self:getVar("current"))
                    if data and Net:IsHost() then
                        peer:send("request_player_name_reply", Steam:username())
                        DelayedCalls:Add(
                            this.name .. tostring(id),
                            1,
                            function()
                                self:sendMessage(managers.localization:text(this.text.welcome), id)
                                self:sendMessage(managers.localization:text(this.text.current, {title = data}), id)
                            end
                        )
                    end
                end
            )
            Hooks:Add(
                "BaseNetworkSessionOnEnteredLobby",
                this.hook("SessionEnteredLobby"),
                function()
                    local data = this.getAchievementInfo(self:getVar("current"))
                    if data and Net:IsHost() then
                        DelayedCalls:Add(
                            this.name,
                            1,
                            function()
                                self:sendMessage(managers.localization:text(this.text.current, {title = data}))
                            end
                        )
                    end
                end
            )
            Hooks:Add(
                "CustomizeControllerOnKeySet",
                this.hook("ControllerKeySet"),
                function(keybind, key)
                    if keybind == this.keybind.name then
                        this.setMenuFunc(
                            this.name,
                            {
                                [keybind] = function(item)
                                    item._parameters.binding = key
                                    self:setVar("key", key)
                                end
                            }
                        )
                    end
                end
            )
            Hooks:Add(
                "LocalizationManagerPostInit",
                this.hook("LocalizationInit"),
                function(manager)
                    manager:add_localized_strings(
                        {
                            [this.keybind.name] = "State objective requirements",
                            [this.keybind.desc] = "Change keybind to state objective requirements when objective is selected.\nAfter keybind is pressed, it will have a 5 second cooldown to prevent chat spam.",
                            [this.name] = "Achievement Hunter",
                            [this.desc] = "Change Achievement Hunter options",
                            [this.no_highlight.name] = "Disable lobby highlighting",
                            [this.no_highlight.desc] = "Do not highlight active Achievement Hunter lobbies in CrimeNet.",
                            [this.set_title.name] = "Use selected objective as lobby title",
                            [this.set_title.desc] = "Selected objective will be used as lobby title in CrimeNet.\nThis does not change host name anywhere else.",
                            [this.color.scheme_name] = "Load default highlight colors",
                            [this.color.scheme_desc] = "Load default highlight color scheme for editing.",
                            [this.color.friend] = "Friend color",
                            [this.color.friend_desc] = "Change friend lobby highlight color scheme.",
                            [this.color.normal] = "Regular color",
                            [this.color.normal_desc] = "Change regular lobby highlight color scheme.",
                            [this.reset_all.name] = "Reset everything",
                            [this.reset_all.desc] = "Reset everything (objectives and menu settings).",
                            [this.clear.name] = "Clear objective",
                            [this.clear.desc] = "Current objective is reset.",
                            [this.dialog.yes] = "Yes",
                            [this.dialog.no] = "No",
                            [this.dialog.confirm] = "Are you sure?",
                            [this.dialog.popup] = 'Lobby objective is active in this lobby.\nAchievement: "$title"',
                            [this.text.welcome] = "Hello! This lobby is for achievement hunters.",
                            [this.text.changed] = "Objective was changed by host.",
                            [this.text.current] = 'We\'re hunting "$title" achievement.'
                        }
                    )

                    manager:load_localization_file(self:getLanguage())
                    manager:set_default_macro("clear_achievement_objective", "c")
                end
            )
            Hooks:Add(
                "MenuManagerSetupCustomMenus",
                this.hook("MenuSetupMenus"),
                function()
                    MenuHelper:NewMenu(this.name)

                    MenuCallbackHandler[this.name] = function(menu, item)
                        if not item then
                            if self:getVar("current") ~= this.active then
                                self:sendMessage(managers.localization:text(this.text.changed), "")
                                if this.active then
                                    self:sendMessage(
                                        managers.localization:text(
                                            this.text.current,
                                            {title = this.getAchievementInfo(this.active)}
                                        ),
                                        ""
                                    )
                                end
                            end

                            self:setVar("current", this.active)

                            if Net:IsHost() then
                                MenuCallbackHandler:update_matchmake_attributes()
                            end

                            self:saveConfig()
                            return
                        end

                        local name = item:name() or ""
                        if name == this.no_highlight.name then
                            self:setVar("no_highlight", Utils:ToggleItemToBoolean(item))
                        elseif name == this.set_title.name then
                            self:setVar("set_title", Utils:ToggleItemToBoolean(item))
                        elseif name == this.reset_all.name then
                            QuickMenu:new(
                                managers.localization:text(this.reset_all.name),
                                managers.localization:text(this.dialog.confirm),
                                {
                                    {
                                        text = managers.localization:text(this.dialog.yes),
                                        callback = function()
                                            Hooks:Call("CustomizeControllerOnKeySet", this.keybind.name, "")

                                            this.setMenuFunc(
                                                this.name,
                                                {
                                                    multi_choice = function(item)
                                                        item._current_index = this.default_index
                                                    end,
                                                    toggle = function(item)
                                                        item.selected = 2
                                                    end,
                                                    [this.color.scheme_name] = function(item)
                                                        item:trigger()
                                                    end,
                                                    _ = function(item)
                                                        item:dirty()
                                                    end
                                                }
                                            )

                                            self:setupConfig(true)
                                        end
                                    },
                                    {
                                        text = managers.localization:text(this.dialog.no),
                                        is_cancel_button = true
                                    }
                                },
                                true
                            )
                        elseif name == this.color.scheme_name then
                            this.setMenuFunc(
                                this.name,
                                {
                                    [this.color.normal] = function(item)
                                        item:set_value(this.normal_color)
                                        self:setVar("normal_color", item:value())
                                        item:dirty()
                                    end,
                                    [this.color.friend] = function(item)
                                        item:set_value(this.friend_color)
                                        self:setVar("friend_color", item:value())
                                        item:dirty()
                                    end
                                }
                            )
                        elseif name == this.color.normal then
                            local color = this.getValidColor(item:value(), this.normal_color)
                            self:setVar("normal_color", color)
                            item:set_value(color)
                            item:dirty()
                        elseif name == this.color.friend then
                            local color = this.getValidColor(item:value(), this.friend_color)
                            self:setVar("friend_color", color)
                            item:set_value(color)
                            item:dirty()
                        end
                    end
                end
            )
            Hooks:Add(
                "MenuManagerPopulateCustomMenus",
                this.hook("MenuPopulateMenus"),
                function()
                    local setup_data = {
                        normal_color = this.getValidColor(self:getVar("normal_color"), this.normal_color),
                        friend_color = this.getValidColor(self:getVar("friend_color"), this.friend_color),
                        key = self:getVar("key", "")
                    }

                    MenuHelper:AddToggle(
                        {
                            priority = 10,
                            id = this.no_highlight.name,
                            title = this.no_highlight.name,
                            desc = this.no_highlight.desc,
                            callback = this.name,
                            menu_id = this.name,
                            value = self:getVar("no_highlight")
                        }
                    )
                    MenuHelper:AddToggle(
                        {
                            priority = 9,
                            id = this.set_title.name,
                            title = this.set_title.name,
                            desc = this.set_title.desc,
                            callback = this.name,
                            menu_id = this.name,
                            value = self:getVar("set_title")
                        }
                    )
                    MenuHelper:AddKeybinding(
                        {
                            priority = 8,
                            id = this.keybind.name,
                            desc = this.keybind.desc,
                            title = this.keybind.name,
                            connection_name = this.keybind.name,
                            binding = setup_data.key,
                            button = setup_data.key,
                            menu_id = this.name
                        }
                    )
                    MenuHelper:AddDivider(
                        {
                            priority = 7,
                            menu_id = this.name
                        }
                    )
                    MenuHelper:AddButton(
                        {
                            priority = 6,
                            id = this.color.scheme_name,
                            title = this.color.scheme_name,
                            desc = this.color.scheme_desc,
                            callback = this.name,
                            menu_id = this.name
                        }
                    )
                    MenuHelper:AddDivider(
                        {
                            priority = 5,
                            menu_id = this.name
                        }
                    )
                    MenuHelper:AddInput(
                        {
                            priority = 4,
                            id = this.color.normal,
                            title = this.color.normal,
                            desc = this.color.normal_desc,
                            menu_id = this.name,
                            callback = this.name,
                            value = setup_data.normal_color
                        }
                    )
                    MenuHelper:AddInput(
                        {
                            priority = 3,
                            id = this.color.friend,
                            title = this.color.friend,
                            desc = this.color.friend_desc,
                            menu_id = this.name,
                            callback = this.name,
                            value = setup_data.friend_color
                        }
                    )
                    MenuHelper:AddDivider(
                        {
                            priority = 2,
                            menu_id = this.name
                        }
                    )
                    MenuHelper:AddButton(
                        {
                            priority = 1,
                            id = this.reset_all.name,
                            title = this.reset_all.name,
                            desc = this.reset_all.desc,
                            callback = this.name,
                            menu_id = this.name
                        }
                    )
                end
            )
            Hooks:Add(
                "MenuManagerBuildCustomMenus",
                this.hook("MenuBuildMenus"),
                function(_, nodes)
                    nodes[this.name] = MenuHelper:BuildMenu(this.name, {back_callback = this.name})
                    MenuHelper:AddMenuItem(nodes.blt_options, this.name, this.name, this.desc)

                    this.setMenuFunc(
                        this.name,
                        {
                            [this.keybind.name] = function(item)
                                item._layout = function(_, node, item)
                                    local _, _, w, h = item.controller_name:text_rect()
                                    item.gui_panel:set_left(node:_right_align())
                                    w = item.gui_panel:w() - item.gui_panel:x()
                                    item.controller_binding:set_size(w, h)
                                    item.controller_binding:set_left(0)
                                    item.controller_name:set_size(w, h)
                                    item.controller_name:set_right(w)
                                    item.gui_panel:set_size(w, h)
                                end
                            end,
                            input = function(item)
                                item._input_limit = 6
                            end
                        }
                    )
                end
            )
        end
    end
end

AchieHunter:setupMod()
