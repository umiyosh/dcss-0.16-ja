/**
 * @file
 * @brief Let the player search for descriptions of monsters, items, etc.
 **/

#ifndef LOOKUP_HELP_H
#define LOOKUP_HELP_H

void keyhelp_query_descriptions();

#ifdef DEBUG_TESTS
vector<string> lookup_help_test_matching_keys(char symbol,
                                              const string &regex);
string lookup_help_test_bilingual_title(const string &title_ja,
                                        const string &title_en,
                                        int columns);
#endif

#endif
