-- rarity definitions and rarity chance function

local setupChanceFunctions = require 'utils.chance'
local f = require 'utils.functional'
local Color = require 'modules.color'

local Rarity = {}

-- enhances the ai's base stats and abilities with new random powers
local addRandomPropery = setupChanceFunctions({
  {
    type = 'extra fast',
    chance = 1,
    lowerPercentSpeed = 1,
    upperPercentSpeed = 2,
    __call = function(self, ai)
      local moveSpeedBonus = math.random(self.lowerPercentSpeed, self.upperPercentSpeed) / 2
      local modType = 'extra fast'
      return self.type, 'moveSpeed', ai.moveSpeed + (ai.moveSpeed * moveSpeedBonus)
    end
  }
})

local rarityTypes = {
  normal = {
    type = 'NORMAL',
    chance = 15,
    __call = function(self, ai)
      return ai
    end
  },

  magical = {
    type = 'MAGICAL',
    chance = 4,
    outlineColor = {0.5, 0.5, 1, 1},
    __call = function(self, ai)
      return ai:set('outlineColor', self.outlineColor)
        :set('rarityColor', Color.RARITY_MAGICAL)
        :set('maxHealth', ai.maxHealth * 2)
        :set('experience', ai.experience * 2.5)
    end
  },

  rare = {
    type = 'RARE',
    chance = 2,
    outlineColor = {0.8, 0.8, 0, 1},
    __call = function(self, ai)
      local modType, prop, value = addRandomPropery(ai)
      ai:set(prop, value)
      table.insert(ai.dataSheet.properties, modType)

      return ai:set('outlineColor', self.outlineColor)
        :set('rarityColor', Color.RARITY_RARE)
        :set('maxHealth', ai.maxHealth * 5)
        :set('experience', ai.experience * 6)
    end
  },
}

local generateRandomRarity = setupChanceFunctions(
  f.reduce(f.keys(rarityTypes), function(typeDefs, typeName)
    table.insert(typeDefs, rarityTypes[typeName])
    return typeDefs
  end, {})
)

local mt = {
  types = f.reduce(f.keys(rarityTypes), function(typeDefsByName, typeName)
    local callableObject = require 'utils.callable-object'
    typeDefsByName[typeName] = callableObject(rarityTypes[typeName])
    return typeDefsByName
  end, {}),
  __call = function(_, ai)
    return generateRandomRarity(ai)
  end
}
mt.__index = mt

return setmetatable(Rarity, mt)