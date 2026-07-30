local cases = {
  { "Char dumped to '%s'.", "キャラクターダンプを「%s」に出力した。" },
  { "As you grasp it, you feel your magic disrupted. Quickly, you stop.",
    "それを手に取ると、魔力が乱されるのを感じた。あなたはすぐに手を止めた。" },
  { "Your messages:", "あなたへのメッセージ:" },
  { "The lava instantly superheats you.",
    "溶岩があなたを瞬時に灼熱させた。" },
  { "Your stony skin melts.", "石の皮膚が溶けた。" },
  { "That potion was far past its expiry date.",
    "この薬はとっくに消費期限が切れていた。" },
  { "Sorry, this spell is gone!",
    "申し訳ないが、この呪文は削除されている！" },
  { "%s is out of range for that spell.", "%sはその呪文の射程外だ。" },
  { "The gas trap seems to be inoperative.",
    "ガスの罠は作動しないようだ。" },
  { "Stopped running for exclusion.", "除外地点のため移動を中止した。" },
  { "Warning: monster '%s' is not yet fully coded.",
    "警告: モンスター「%s」はまだ完全には実装されていない。" },
}

for _, case in ipairs(cases) do
  test.eq(crawl.jtrans(case[1]), case[2], case[1])
end
