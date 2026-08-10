/**
 * @file
 * @brief Crawl Lua test cases
 *
 * ctest runs Lua tests found in the test directory. The intent here
 * is to test parts of Crawl that can be easily tested from within Crawl
 * itself (such as LOS). As a side-effect, writing Lua bindings to support
 * tests will expand the available Lua bindings. :-)
 *
 * Tests will run only with Crawl built in its source tree without
 * DATA_DIR_PATH set.
**/

#include "AppHdr.h"

#ifdef DEBUG_TESTS

#include "ctest.h"

#include <algorithm>
#include <chrono>
#include <vector>

#include "clua.h"
#include "cluautil.h"
#include "coordit.h"
#include "database.h"
#include "dlua.h"
#include "end.h"
#include "errors.h"
#include "files.h"
#include "initfile.h"
#include "libutil.h"
#include "maps.h"
#include "message.h"
#include "mon-pick.h"
#include "mon-util.h"
#include "ng-init.h"
#include "options.h"
#include "output.h"
#include "state.h"
#include "stringutil.h"
#include "unicode.h"
#include "unwind.h"
#include "version.h"
#include "zotdef.h"

#if defined(USE_TILE_LOCAL) && defined(USE_SDL)
# ifdef __ANDROID__
#  include <SDL.h>
# else
#  ifdef TARGET_COMPILER_VC
#   include <SDL.h>
#  else
#   include <SDL2/SDL.h>
#  endif
# endif
# include "windowmanager.h"
#endif

static const string test_dir = "test";
static const string script_dir = "scripts";
static const char *activity = "test";

static int ntests = 0;
static int nsuccess = 0;

typedef pair<string, string> file_error;
static vector<file_error> failures;

typedef std::chrono::steady_clock test_clock;

static void _report_test_duration(const string &name,
                                  const test_clock::time_point &started)
{
    const long long elapsed = std::chrono::duration_cast<
        std::chrono::milliseconds>(test_clock::now() - started).count();
    fprintf(stderr, "TEST_DURATION_MS %s %lld\n", name.c_str(),
            elapsed > 0 ? elapsed : 1);
}

static void _reset_test_data()
{
    ntests = 0;
    nsuccess = 0;
    failures.clear();
    you.your_name = "Superbug99";
    you.species = SP_HUMAN;
    you.char_class = JOB_FIGHTER;
}

static int crawl_begin_test(lua_State *ls)
{
    mprf(MSGCH_PROMPT, "Starting %s: %s",
         activity,
         luaL_checkstring(ls, 1));
    lua_pushnumber(ls, ++ntests);
    return 1;
}

static int crawl_test_success(lua_State *ls)
{
    if (!crawl_state.script)
        mprf(MSGCH_PROMPT, "Test success: %s", luaL_checkstring(ls, 1));
    lua_pushnumber(ls, ++nsuccess);
    return 1;
}

static int crawl_script_args(lua_State *ls)
{
    return clua_stringtable(ls, crawl_state.script_args);
}

static int crawl_string_width(lua_State *ls)
{
    lua_pushnumber(ls, strwidth(luaL_checkstring(ls, 1)));
    return 1;
}

static int crawl_long_description(lua_State *ls)
{
    const string description = getLongDescription(luaL_checkstring(ls, 1));
    lua_pushstring(ls, description.c_str());
    return 1;
}

static int crawl_hint_string(lua_State *ls)
{
    const string hint = getHintString(luaL_checkstring(ls, 1));
    lua_pushstring(ls, hint.c_str());
    return 1;
}

static const struct luaL_reg crawl_test_lib[] =
{
    { "begin_test", crawl_begin_test },
    { "test_success", crawl_test_success },
    { "script_args", crawl_script_args },
    { "string_width", crawl_string_width },
    { "long_description", crawl_long_description },
    { "hint_string", crawl_hint_string },
    { nullptr, nullptr }
};

static void _init_test_bindings()
{
    lua_stack_cleaner clean(dlua);
    luaL_openlib(dlua, "crawl", crawl_test_lib, 0);
    dlua.execfile("dlua/test.lua", true, true);
    initialise_branch_depths();
    initialise_item_descriptions();
}

static const char *_test_extension(const string &testname)
{
    if (ends_with(testname, ".clua"))
        return ".clua";
    ASSERT(ends_with(testname, ".lua"));
    return ".lua";
}

static bool _is_test_selected(const string &testname)
{
    const char *extension = _test_extension(testname);
    if (crawl_state.test_list)
    {
        printf("%s\n",
               testname.substr(0, testname.length() - strlen(extension))
                       .c_str());
        return false;
    }

    if (crawl_state.tests_selected.empty() && !starts_with(testname, "big/"))
        return true;
    for (int i = 0, size = crawl_state.tests_selected.size();
         i < size; ++i)
    {
        const string &phrase(crawl_state.tests_selected[i]);
        if (testname == phrase || testname == phrase + extension)
            return true;
    }
    return false;
}

static void run_test(const string &file)
{
    if (!_is_test_selected(file))
        return;

    const test_clock::time_point started = test_clock::now();
    ++ntests;
    mprf(MSGCH_DIAGNOSTICS, "Running %s %d: %s",
         activity, ntests, file.c_str());
    flush_prev_message();

    const string path(catpath(crawl_state.script? script_dir : test_dir, file));
    const bool client_test = ends_with(file, ".clua");
    CLua &lua = client_test ? clua : dlua;
    if (client_test)
        load_lua_builtins();
    lua.execfile(path.c_str(), true, false, true);
    if (lua.error.empty())
        ++nsuccess;
    else
        failures.emplace_back(file, lua.error);

    const char *extension = _test_extension(file);
    _report_test_duration(
        file.substr(0, file.length() - strlen(extension)), started);
}

static bool _has_test(const string& test)
{
    if (crawl_state.script)
        return false;
    if (crawl_state.tests_selected.empty())
        return true;
    return crawl_state.tests_selected[0].find(test) != string::npos;
}

static void _run_test(const string &name, void (*func)())
{
    if (crawl_state.test_list)
        return (void)printf("%s\n", name.c_str());

    if (!_has_test(name))
        return;

    const test_clock::time_point started = test_clock::now();
    try
    {
        (*func)();
    }
    catch (const ext_fail_exception &E)
    {
        failures.emplace_back(name, E.msg);
    }
    _report_test_duration(name, started);
}

static void _equip_slot_name_tests()
{
    static const char *api_names[] =
    {
        "Weapon", "Cloak",  "Helmet", "Gloves", "Boots",
        "Shield", "Armour", "Left Ring", "Right Ring", "Amulet",
        "First Ring", "Second Ring", "Third Ring", "Fourth Ring",
        "Fifth Ring", "Sixth Ring", "Seventh Ring", "Eighth Ring",
        "Amulet Ring"
    };

    COMPILE_CHECK(ARRAYSZ(api_names) == NUM_EQUIP);
    for (int i = 0; i < NUM_EQUIP; ++i)
    {
        if (equip_name_to_slot(api_names[i]) != i)
            fail("Could not resolve equipment slot '%s'.", api_names[i]);
    }

    if (equip_name_to_slot("weapon") != EQ_WEAPON)
        fail("Equipment slot names should be case-insensitive.");
    if (equip_name_to_slot("武器") != EQ_WEAPON)
        fail("Translated equipment slot names should remain supported.");
    if (equip_name_to_slot("not an equipment slot") != -1)
        fail("Invalid equipment slot name was accepted.");
}

#if defined(TARGET_OS_MACOSX)
static string _macos_default_data_dir()
{
    const char *home = getenv("HOME");
    const string home_dir = home && *home ? mb_to_utf8(home) : "./";
    return catpath(home_dir, "Library/Application Support/" CRAWL);
}

static void _macos_crawl_dir_tests()
{
    unwind_var<string> crawl_dir(SysEnv.crawl_dir);

    const string startup_base = SysEnv.crawl_dir.empty()
                              ? _macos_default_data_dir()
                              : SysEnv.crawl_dir;
    if (Options.save_dir != catpath(startup_base, "saves/"))
        fail("macOS startup save_dir did not follow crawl_dir.");
    if (Options.morgue_dir != catpath(startup_base, "morgue/"))
        fail("macOS startup morgue_dir did not follow crawl_dir.");

    const string versioned_cache_dir =
        catpath(Options.save_dir, string("cache.") + Version::Long);
    if (savedir_versioned_path("des")
        != catpath(versioned_cache_dir, "des"))
    {
        fail("macOS data cache was not isolated by Crawl version.");
    }

    const string custom_base = "/crawl/test-data";
    SysEnv.crawl_dir = custom_base;
    game_options options;
    if (options.save_dir != catpath(custom_base, "saves/"))
        fail("macOS save_dir did not follow an explicit crawl_dir.");
    if (options.morgue_dir != catpath(custom_base, "morgue/"))
        fail("macOS morgue_dir did not follow an explicit crawl_dir.");

    const string explicit_save = "/crawl/explicit-saves";
    const string explicit_morgue = "/crawl/explicit-morgue";
    options.read_option_line("save_dir = " + explicit_save);
    options.read_option_line("morgue_dir = " + explicit_morgue);
    if (options.save_dir != explicit_save)
        fail("An explicit macOS save_dir did not override crawl_dir.");
    if (options.morgue_dir != explicit_morgue)
        fail("An explicit macOS morgue_dir did not override crawl_dir.");

    SysEnv.crawl_dir.clear();
    options.reset_options();
    const string default_base = _macos_default_data_dir();
    if (options.save_dir != catpath(default_base, "saves/"))
        fail("macOS default save_dir changed without crawl_dir.");
    if (options.morgue_dir != catpath(default_base, "morgue/"))
        fail("macOS default morgue_dir changed without crawl_dir.");
}
#endif

static void _utf8_input_queue_tests()
{
    string text = "あA漢";
    const ucs_t expected[] = { 0x3042, 'A', 0x6F22 };
    for (unsigned int i = 0; i < ARRAYSZ(expected); ++i)
    {
        if (text.empty())
            fail("UTF-8 input ended before every character was read.");
        const ucs_t actual = pop_utf8_char(text);
        if (actual != expected[i])
        {
            fail("UTF-8 input character %u was %u, expected %u.",
                 i, actual, expected[i]);
        }
    }
    if (!text.empty())
        fail("UTF-8 input retained bytes after every character was read.");

    string nul_text("\0A", 2);
    if (pop_utf8_char(nul_text) != 0 || nul_text != "A")
        fail("UTF-8 input did not consume a leading NUL byte.");
}

static void _utf8_textblock_tests()
{
    const utf8_textblock block = make_utf8_textblock("AコB\n水");
    if (block.width != 3 || block.height != 2)
    {
        fail("UTF-8 text block was %u x %u, expected 3 x 2.",
             block.width, block.height);
        return;
    }

    const ucs_t expected[] = { 'A', 0x30B3, 'B', 0x6C34, ' ', ' ' };
    if (block.chars.size() != ARRAYSZ(expected))
    {
        fail("UTF-8 text block contained %u cells, expected %u.",
             static_cast<unsigned int>(block.chars.size()),
             static_cast<unsigned int>(ARRAYSZ(expected)));
        return;
    }

    for (unsigned int i = 0; i < ARRAYSZ(expected); ++i)
    {
        if (block.chars[i] != expected[i])
        {
            fail("UTF-8 text block cell %u was %u, expected %u.",
                 i, block.chars[i], expected[i]);
        }
    }
}

#if defined(USE_TILE_LOCAL) && defined(USE_SDL)
static void _sdl_textinput_tests()
{
    SDL_FlushEvents(SDL_FIRSTEVENT, SDL_LASTEVENT);

    SDL_Event editing = {};
    editing.type = SDL_TEXTEDITING;
    strncpy(editing.edit.text, "に", sizeof(editing.edit.text) - 1);
    if (SDL_PushEvent(&editing) != 1)
        fail("Could not enqueue an SDL text editing event.");

    wm_event event = {};
    if (wm->wait_event(&event))
        fail("SDL composition text became a key event.");

    SDL_Event input = {};
    input.type = SDL_TEXTINPUT;
    strncpy(input.text.text, "あA漢", sizeof(input.text.text) - 1);
    if (SDL_PushEvent(&input) != 1)
        fail("Could not enqueue an SDL text input event.");

    const ucs_t expected[] = { 0x3042, 'A', 0x6F22 };
    for (unsigned int i = 0; i < ARRAYSZ(expected); ++i)
    {
        if (!wm->wait_event(&event))
            fail("SDL text input stopped before every character was read.");
        if (event.type != WME_KEYPRESS)
            fail("SDL text input produced a non-keypress event.");
        if (event.key.keysym.sym != static_cast<int>(expected[i]))
        {
            fail("SDL text input character %u was %d, expected %u.",
                 i, event.key.keysym.sym, expected[i]);
        }
        if (i + 1 < ARRAYSZ(expected)
            && !wm->get_event_count(WME_KEYPRESS))
        {
            fail("Queued SDL text input was not reported as pending.");
        }
    }
}
#endif

// Assumes curses has already been initialized.
void run_tests()
{
    if (crawl_state.script)
        activity = "script";

    flush_prev_message();

    run_map_global_preludes();
    run_map_local_preludes();
    _reset_test_data();

    _init_test_bindings();

    _run_test("makeitem", makeitem_tests);
    _run_test("zotdef_wave", debug_waves);
    _run_test("mon-pick", debug_monpick);
    _run_test("mon-data", debug_mondata);
    _run_test("mon-spell", debug_monspells);
    _run_test("coordit", coordit_tests);
    _run_test("equip-slot-name", _equip_slot_name_tests);
#if defined(TARGET_OS_MACOSX)
    _run_test("macos-crawl-dir", _macos_crawl_dir_tests);
#endif
    _run_test("utf8-input-queue", _utf8_input_queue_tests);
    _run_test("utf8-textblock", _utf8_textblock_tests);
#if defined(USE_TILE_LOCAL) && defined(USE_SDL)
    _run_test("sdl-textinput", _sdl_textinput_tests);
#endif
    _run_test("map-epilogue-validation", mapdef_epilogue_tests);
    _run_test("map-cache-recovery", mapdef_tests);

    // Get a list of Lua files in test. Order of execution of
    // tests should be irrelevant.
    {
        vector<string> tests(
            get_dir_files_recursive(crawl_state.script? script_dir : test_dir,
                              ".lua"));
        if (!crawl_state.script)
        {
            const vector<string> client_tests(
                get_dir_files_recursive(test_dir, ".clua"));
            tests.insert(tests.end(), client_tests.begin(), client_tests.end());
        }

        for_each(tests.begin(), tests.end(), run_test);

        if (failures.empty() && !ntests && crawl_state.script)
        {
            failures.emplace_back("Script setup",
                    "No scripts found matching "
                    + comma_separated_line(crawl_state.tests_selected.begin(),
                                           crawl_state.tests_selected.end(),
                                           ", ", ", "));
        }
    }

    if (crawl_state.test_list)
        end(0);
    cio_cleanup();
    for (int i = 0, size = failures.size(); i < size; ++i)
    {
        const file_error &fe(failures[i]);
        fprintf(stderr, "%s error: %s\n",
                activity, fe.second.c_str());
    }
    const int code = failures.empty() ? 0 : 1;
    end(code, false, "%d %ss, %d succeeded, %d failed",
        ntests, activity, nsuccess, (int)failures.size());
}

#endif // DEBUG_TESTS
