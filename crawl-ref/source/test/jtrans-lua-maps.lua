local cases = {
  { "No target in view!", "視界内に敵はいない！" },
  { "The volcano erupts! Nearby, a roof collapses.",
    "火山が噴火し、周囲で天井が崩れ落ちた！" },
  { "The doors seal shut behind you!",
    "あなたの背後の扉が固く閉じられた！" },
  { "A figure emerges from the depths of the water!",
    "何者かの姿が水の深みから飛び出してきた！" },
  { "A rune of Zot has appeared.", "ゾットのルーンが出現した。" },
  { "The exit has re-opened... for now.",
    "出口が再び開いた……たった今。" },
}

for _, case in ipairs(cases) do
  test.eq(crawl.jtrans(case[1]), case[2], case[1])
end
