local cases = {
  { "rat", "不潔な齧歯類" },
  { "Abjuration spell", "元いた場所に送還" },
  { "Controlled Blink spell", "テレポート制御を妨げる領域でも" },
  { "Glaciate spell", "猛烈な氷の奔流" },
  { "Dragon's Call spell", "竜の領域" },
  { "Necromutation spell", "力ある骸骨" },
  { "Drain Magic spell", "反魔法の武器" },
  { "Tornado spell", "力強い旋風" },
  { "club", "重量がある木の棒" },
  { "arbalest", "巻き上げ機で弦を引く大型の弩" },
  { "quicksilver dragon armour", "水銀ドラゴンの鱗" },
  { "scroll of enchant armour", "バックラー、盾、大盾" },
  { "book", "由来の知れない呪文" },
  { "amulet of Vitality", "この名高い護符" },
  { "Screaming Sword", "所有者に歌いかける" },
  { "A closed door", "木製の扉" },
}

for _, case in ipairs(cases) do
  local description = crawl.long_description(case[1])
  assert(string.find(description, case[2], 1, true),
         "Japanese description not found for " .. case[1] ..
         ": " .. description)
end
