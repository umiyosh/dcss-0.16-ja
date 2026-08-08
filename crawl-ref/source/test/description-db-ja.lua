local cases = {
  { "rat", "不潔な齧歯類" },
  { "Abjuration spell", "元いた場所に送還" },
  { "club", "重量がある木の棒" },
  { "A closed door", "木製の扉" },
}

for _, case in ipairs(cases) do
  local description = crawl.long_description(case[1])
  assert(string.find(description, case[2], 1, true),
         "Japanese description not found for " .. case[1] ..
         ": " .. description)
end
