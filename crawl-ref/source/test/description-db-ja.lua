local cases = {
  { "rat", "不潔な齧歯類" },
  { "Abjuration spell", "元いた場所に送還" },
  { "Controlled Blink spell", "テレポート制御を妨げる領域でも" },
  { "Glaciate spell", "猛烈な氷の奔流" },
  { "Dragon's Call spell", "竜の領域" },
  { "Necromutation spell", "力ある骸骨" },
  { "Drain Magic spell", "反魔法の武器" },
  { "Tornado spell", "力強い旋風" },
  { "Warpwright card", "テレポートの罠" },
  { "the Helm card", "鎧による守り、回避、盾" },
  { "Vitriol card", "腐食性の攻撃呪文" },
  { "the Pentagram card", "二体の悪魔が召喚される" },
  { "Repulsiveness card", "カードの力に応じて、醜いもの" },
  { "the Wraith card", "使用者は衰弱する" },
  { "club", "重量がある木の棒" },
  { "arbalest", "クロスボウの矢" },
  { "quicksilver dragon armour", "敵対的な魔法を退ける力" },
  { "scroll of enchant armour", "胴鎧と馬甲・具装" },
  { "scroll of summoning", "読み手のいる土地で見られる生物" },
  { "staff of air", "発動スキルと風の魔術スキル" },
  { "wand of paralysis", "生物を麻痺させ" },
  { "book", "由来の知れない呪文" },
  { "amulet of Vitality", "この名高い護符" },
  { "Screaming Sword", "所有者に歌いかける" },
  { "A closed door", "木製の扉" },
  { "Dig ability", "柔らかな岩や錆びた格子" },
  { "Apocalypse ability", "ルーの真実を敵に示す" },
  { "Evoke Twister ability", "敵味方の別なく" },
  { "Sacrifice Durability ability", "甲冑スキル" },
  { "Sacrifice Nimbleness ability", "躱し身スキル" },
  { "Sacrifice Essence ability", "魔法防御の低下" },
  { "Sacrifice Purity ability", "道具による回復効果の低下" },
  { "CMD_MAP_EXPLORE verbose", "自動探索が次に向かう場所" },
}

for _, case in ipairs(cases) do
  local description = crawl.long_description(case[1])
  assert(string.find(description, case[2], 1, true),
         "Japanese description not found for " .. case[1] ..
         ": " .. description)
end

local welcome = crawl.hint_string("welcome")
assert(string.find(welcome, "伝説のゾットのオーブ", 1, true),
       "Japanese hint not found for welcome: " .. welcome)
