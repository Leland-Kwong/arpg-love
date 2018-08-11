local groups = require 'components.groups'
local collisionWorlds = require 'components.collision-worlds'
local collisionObject = require 'modules.collision'
local f = require 'utils.functional'

local MainMapSolidsBlueprint = {
  animation = {},
  x = 0,
  y = 0,
  ox = 0,
  oy = 0,
  gridSize = 0,
}

function MainMapSolidsBlueprint.init(self)
  local w = self.animation:getSourceSize()
  local ox, oy = self.animation:getSourceOffset()
  self.colObj = collisionObject:new(
    'obstacle',
    self.x, self.y, w, self.gridSize, ox, oy - (self.gridSize / 2)
  ):addToWorld(collisionWorlds.map)
end

function MainMapSolidsBlueprint.draw(self)
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(
    self.animation.atlas,
    self.animation.sprite,
    self.x,
    self.y,
    0,
    1,
    1,
    self.ox,
    self.oy
  )
end

function MainMapSolidsBlueprint.final(self)
  self.colObj:removeFromWorld(collisionWorlds.map)
end

return groups.all.createFactory(MainMapSolidsBlueprint)