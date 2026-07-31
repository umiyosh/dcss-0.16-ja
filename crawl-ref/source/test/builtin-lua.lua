-- Regression tests for the Lua helpers loaded for every game.

local function contains(lines, expected)
    for _, line in ipairs(lines) do
        if line == expected then
            return true
        end
    end
    return false
end

local function with_globals(replacements, body)
    local saved = { }
    for name, value in pairs(replacements) do
        saved[name] = _G[name]
        _G[name] = value
    end

    local ok, err = pcall(body)
    for name in pairs(replacements) do
        _G[name] = saved[name]
    end
    if not ok then
        error(err)
    end
end

local function hostile_monster()
    return {
        attitude = function () return 0 end,
        damage_level = function () return 0 end,
        is_constricting_you = function () return false end,
        is_firewood = function () return false end,
        is_safe = function () return false end,
        name = function () return "rat" end,
        stabbability = function () return 0 end,
        threat = function () return 0 end,
    }
end

local function test_builtins_loaded()
    local functions = {
        ch_stash_search_annotate_item,
        rr_handle_message,
        hit_closest,
        mag_attack,
        c_kill_list,
    }
    for _, fn in ipairs(functions) do
        test.eq(type(fn), "function")
    end
end

local function test_stash_annotation()
    local item = {
        artefact = false,
        branded = true,
        dropped = true,
        ego_type_terse = "flame",
        god_gift = false,
        is_preferred_food = false,
        is_ranged = false,
        is_throwable = true,
        snakable = false,
        weap_skill = "Short Blades",
        class = function () return "weapon" end,
        subtype = function () return "short sword" end,
    }

    with_globals({ food = { isfruit = function () return false end } },
        function ()
            test.eq(ch_stash_search_annotate_item(item),
                "{dropped} {throwable} {ego} {branded} " ..
                "{Short Blades} {flame} {melee weapon}")
        end)
end

local function test_runrest_message_rules()
    g_rr_ignored = { }
    rr_message_adder(true)("runrest_stop_message", "danger", 0)
    rr_message_adder(nil)("runrest_ignore_message", "noise", 0)

    test.eq(rr_handle_message("danger"), true)
    test.eq(rr_handle_message("noise"), nil)
    test.eq(rr_handle_message("other"), false)
end

local function combat_globals(processed_keys, spellcasting)
    local mon = hostile_monster()
    local replacements = {
        crawl = {
            mpr = function () end,
            process_keys = function (keys)
                processed_keys.value = keys
            end,
        },
        items = {
            equipped_at = function () return nil end,
            fired_item = function () return nil end,
        },
        monster = {
            get_monster_at = function (x, y)
                if x == 1 and y == 0 then
                    return mon
                end
                return nil
            end,
        },
        you = {
            caught = function () return nil end,
            confused = function () return false end,
            hp = function () return 100, 100 end,
            mp = function () return 10, 10 end,
            see_cell_no_trans = function () return true end,
            spell_table = function () return { a = "Magic Dart" } end,
        },
        view = {
            can_reach = function () return false end,
            feature_at = function () return "floor" end,
            is_safe_square = function () return true end,
        },
    }
    if spellcasting then
        replacements.spells = {
            mana_cost = function () return 1 end,
            range = function () return 5 end,
        }
    end
    return replacements
end

local function test_autofight_melee()
    local processed_keys = { }
    with_globals(combat_globals(processed_keys, false), function ()
        AUTOFIGHT_STOP = 30
        AUTOFIGHT_THROW = false
        AUTOFIGHT_THROW_NOMOVE = false
        attack(false)
        test.eq(processed_keys.value, "l")
    end)
end

local function test_automagic_cast()
    local processed_keys = { }
    with_globals(combat_globals(processed_keys, true), function ()
        AUTOFIGHT_STOP = 30
        AUTOMAGIC_FIGHT = false
        AUTOMAGIC_SPELL_SLOT = "a"
        AUTOMAGIC_STOP = 0
        mag_attack(false)
        test.eq(processed_keys.value, "zarlf")
    end)
end

local function test_kill_list_output()
    local written = { }
    local entries = {
        { count = 1, exp = 5, name = "bat", symbol = "b" },
        { count = 3, exp = 3, name = "rat", symbol = "r" },
    }
    local kill_api = {
        base_name = function (entry) return entry.name end,
        desc = function (entry)
            return entry.name .. " x" .. entry.count
        end,
        exp = function (entry) return entry.exp end,
        holiness = function () return "natural" end,
        isunique = function () return false end,
        nkills = function (entry) return entry.count end,
        rawwrite = function (line) table.insert(written, line) end,
        summary = function (list) return #list .. " creatures" end,
        symbol = function (entry) return entry.symbol end,
    }

    with_globals({ kills = kill_api }, function ()
        DUMP_KILL_BREAKDOWNS = true
        test.eq(c_kill_list(entries, nil, false), true)
        assert(contains(written, "倒したモンスター:"))
        assert(contains(written, "    すべての'r'シンボル"))

        written = { }
        count_list(entries, false)
        test.eq(written[1], "  降順リスト")
        test.eq(written[2], "    rat x3")
        test.eq(written[3], "    bat x1")
    end)
end

test_builtins_loaded()
test_stash_annotation()
test_runrest_message_rules()
test_autofight_melee()
test_automagic_cast()
test_kill_list_output()
