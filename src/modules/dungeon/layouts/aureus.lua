return function()
  local Chance = require 'utils.chance'
  local mapBlockGenerator = Chance({
    {
      chance = 1,
      value = 'room-1'
    },
    {
      chance = 1,
      value = 'room-4'
    },
    {
      chance = 1,
      value = 'room-3'
    }
  })

  local function generateMapBlockDefinitions()
    local blocks = {
      'room-2',
    }

    local mapDefinitions = {
      mapBlockGenerator,
      mapBlockGenerator,
      mapBlockGenerator
    }

    while #mapDefinitions > 0 do
      local index = math.random(1, #mapDefinitions)
      local block = table.remove(mapDefinitions, index)()
      table.insert(blocks, block)
    end

    return blocks
  end

  return {
    gridBlockNames = generateMapBlockDefinitions(),
    columns = 2,
    startPosition = {
      x = 4,
      y = 6
    },
    exitPosition = {
      x = 3,
      y = 1
    }
  }
end