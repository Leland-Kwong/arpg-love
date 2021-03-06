local Component = require 'modules.component'
local config = require 'config.config'
local groups = require 'components.groups'
local msgBus = require 'components.msg-bus'
local animationFactory = require 'components.animation-factory'
local collisionWorlds = require 'components.collision-worlds'
local collisionObject = require 'modules.collision'
local CollisionGroups = require 'modules.collision-groups'
local gameWorld = require 'components.game-world'
local Position = require 'utils.position'
local Color = require 'modules.color'
local camera = require 'components.camera'
local Vec2 = require 'modules.brinevector'
local memoize = require 'utils.memoize'
local LOS = memoize(require 'modules.line-of-sight')

local targetsHitCache = {
  new = function(self)
    self.__index = self
    return setmetatable({}, self)
  end,
  add = function(self, target)
    self[target] = true
  end,
  has = function(self, target)
    return self[target]
  end
}

local function findNearestTarget(targetsHit, targetX, targetY)
  local mainSceneRef = Component.get('MAIN_SCENE')
  local mapGrid = mainSceneRef.mapGrid
  local gridSize = config.gridSize
  local Map = require 'modules.map-generator.index'
  local losFn = LOS(mapGrid, Map.WALKABLE)
  local getNearestTarget = require 'modules.find-nearest-target'
  return getNearestTarget(collisionWorlds.map, targetX, targetY, 6 * gridSize, losFn, gridSize, function(target)
    return not targetsHit:has(target)
  end)
end

local ChainLightning = {
  group = groups.all,
  range = 10,
  maxBounces = 0,
  _numBounces = 0,
  hitBoxSize = config.gridSize,
}

function ChainLightning.init(self)
  local Position = require 'utils.position'
  local dx, dy = Position.getDirection(self.x, self.y, self.x2, self.y2)
  local trueRange = self.range * config.gridSize
  self.x2 = self.x + dx * trueRange
  self.y2 = self.y + dy * trueRange

  local hbSize = self.hitBoxSize
  self.collision = self:addCollisionObject(
    'projectile',
    self.x, self.y,
    hbSize, hbSize,
    hbSize/2, hbSize/2
  ):addToWorld(collisionWorlds.map)

  self.targetsHit = self.targetsHit or targetsHitCache:new()
end

local function createEffect(start, target, hasHit)
  local LightningEffect = require 'components.effects.lightning'
  LightningEffect:add({
    start = start,
    target = target,
    thickness = 1.4,
    duration = 0.3,
    targetPointRadius = hasHit and 12 or 4
  })
end

function ChainLightning.update(self, dt)
  local actualX, actualY, cols, len = self.collision:move(
    self.x2,
    self.y2,
    function(item, other)
      if self.targetsHit:has(other.parent) then
        return false
      end
      if (CollisionGroups.matches(other.group, 'obstacle')) then
        return 'slide'
      end
      if (CollisionGroups.matches(other.group, self.targetGroup)) then
        return 'touch'
      end
      return false
    end
  )
  local hitTriggered = len > 0
  if hitTriggered then
    local alreadyHit = false
    local i=1
    while (i <= len) and (not alreadyHit) do
      local item = cols[i]
      local parent = item.other.parent
      alreadyHit = true
      if parent then
        local targetX, targetY = parent.x, parent.y

        local start = Vec2(self.x, self.y)

        local isHittable = not CollisionGroups.matches(item.other.group, 'obstacle')
        if isHittable then
          local targetPos = Vec2(targetX, targetY)
          createEffect(start, targetPos, true)

          msgBus.send(msgBus.CHARACTER_HIT, {
            parent = parent,
            lightningDamage = math.random(self.lightningDamage.x, self.lightningDamage.y),
            source = self:getId()
          })
          msgBus.send(msgBus.CHARACTER_HIT, {
            parent = parent,
            modifiers = {
              shocked = 1
            },
            duration = 0.2,
            source = 'chain-lightning'
          })
          self.targetsHit:add(parent)

          local canBounce = self._numBounces < self.maxBounces
          local t = canBounce and findNearestTarget(self.targetsHit, targetX, targetY)
          if t then
            self.initialProps.__index = self.initialProps
            local props = setmetatable({
              id = self:getId(),
              x = targetX,
              y = targetY,
              x2 = t.x,
              y2 = t.y,
              _numBounces = self._numBounces + 1,
              targetsHit = self.targetsHit,
            }, self.initialProps)
            ChainLightning.create(props)
          end
        elseif (self._numBounces == 0) then
          local start, target = Vec2(self.x, self.y),
            Vec2(actualX, actualY)
          createEffect(start, target)
        end
      end
      i = i + 1
    end
  -- show wiff if nothing hits
  elseif (self._numBounces == 0) then
    local start, target = Vec2(self.x, self.y),
      Vec2(self.x2, self.y2)
    createEffect(start, target)
  end
  self:delete()
end

return Component.createFactory(ChainLightning)