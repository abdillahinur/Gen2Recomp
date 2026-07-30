-- Native scenario metadata for the first playable battle route. Numeric
-- records are resolved through ROM-decoded species and move registries.
return {
  schema = 1,
  defaultMoveNumber = 33,
  starters = {
    [152] = { rival = 155, moves = { 33, 45 } },
    [155] = { rival = 158, moves = { 33, 43 } },
    [158] = { rival = 152, moves = { 10, 43 } },
  },
  wildDefaults = {
    pidgey = {
      speciesNumber = 16,
      level = 2,
      moves = { 33 },
    },
  },
}
