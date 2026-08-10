debug.goto_place("D:1")
dgn.reset_level()

local map = dgn.map_by_name("arena_sprint")
assert(map, "Could not find arena_sprint")
dgn.tags(map, "no_rotate no_vmirror no_hmirror no_pool_fixup")
local function place_map()
    return dgn.place_map(map, false, true)
end
assert(dgn.with_map_anchors(40, 35, place_map),
       "Could not place arena_sprint")

local directions = {
    { key = "north", label = "北" },
    { key = "east", label = "東" },
    { key = "south", label = "南" },
    { key = "west", label = "西" },
}

for index, expected in ipairs(directions) do
    local direction = arena_sprint_direction(index)
    test.eq(direction.key, expected.key, "direction key")
    test.eq(direction.label, expected.label, "direction label")

    local positions = dgn.find_marker_positions_by_prop(direction.key, 1)
    assert(#positions > 0, "No spawn markers for " .. direction.key)

    local data = {
        spawn_dir = direction.key,
        num_spawned = 0,
        round_enemies = 1,
        round_id = 1,
        boss_spawned = false,
        monster_set = { "rat" },
        spawn_timer = 0,
    }
    for _ = 1, #positions * 10 do
        arena_sprint_spawn_enemies(data)
        if data.num_spawned > 0 then
            break
        end
    end
    test.eq(data.num_spawned, 1, "spawn from " .. direction.key)
end
