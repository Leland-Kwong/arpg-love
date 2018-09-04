local Component = require 'modules.component'
local memoize = require 'utils.memoize'
local config = require 'config.config'
local groups = require 'components.groups'
local msgBus = require 'components.msg-bus'
local animationFactory = require 'components.animation-factory'
local collisionWorlds = require 'components.collision-worlds'
local collisionObject = require 'modules.collision'
local LOS = memoize(require 'modules.line-of-sight')
local gameWorld = require 'components.game-world'
local Position = require 'utils.position'
local Color = require 'modules.color'
local typeCheck = require 'utils.type-check'
local random = math.random
local tween = require 'modules.tween'
local camera = require 'components.camera'

local colMap = collisionWorlds.map

local defaultFilters = {
  obstacle = true,
  obstacle2 = true,
}

local ColFilter = memoize(function(groupToMatch)
  return function (item, other)
    if (other.group ~= groupToMatch) and not defaultFilters[other.group] then
      return false
    end
    return 'touch'
  end
end)

local ChainLightning = {
  group = groups.all,

  -- [DEFAULTS]

  -- start position
  x = 0,
  y = 0,
  w = 16,
  h = 16,

  -- target position
  x2 = 0,
  y2 = 0,
  minDamage = 1,
  maxDamage = 2,
  weaponDamageScaling = 1,
  startOffset = 0,
  scale = 1,
  lifeTime = 5,
  speed = 200,
  cooldown = 0.3,
  maxTargets = 3,
  targetGroup = nil,
  attackRange = 6 * config.gridSize,
  color = {Color.rgba255(0, 246, 255, 1)}
}

local function checkMousePositionLineOfSight(self, mx, my, los)
  local gx1, gy1 = Position.pixelsToGridUnits(self.x, self.y, config.gridSize)
  local gx2, gy2 = Position.pixelsToGridUnits(mx, my, config.gridSize)
  return los(gx1, gy1, gx2, gy2)
end

local function findNearestTarget(self, foundTargets, pointerX, pointerY, maxSeekRadius)
  local mapGrid = Component.get('MAIN_SCENE').mapGrid
  local Map = require 'modules.map-generator.index'
  local los = LOS(mapGrid, Map.WALKABLE)

  local nearestEnemyFound = nil
  local i = 1
  local previousTarget = foundTargets[#foundTargets] or {x = pointerX, y = pointerY}

  local startX, startY = previousTarget.x, previousTarget.y
  while (i <= maxSeekRadius) and (not nearestEnemyFound) do
    local seekRadius = i * config.gridSize
    local width, height = seekRadius * 2, seekRadius * 2
    local collisionX, collisionY = startX, startY
    local items, len = collisionWorlds.map:queryRect(
      collisionX - width/2,
      collisionY - height/2,
      width,
      height,
      function(item)
        if (not nearestEnemyFound) and item.group == 'ai' then
          local target = item.parent
          local isAlreadyFound = foundTargets:hasTarget(target)
          local gx1, gy1 = Position.pixelsToGridUnits(startX, startY, config.gridSize)
          local gx2, gy2 = Position.pixelsToGridUnits(target.x, target.y, config.gridSize)
          local canSeeTarget = los(gx1, gy1, gx2, gy2)
          if (not isAlreadyFound) and canSeeTarget then
            nearestEnemyFound = target
          end
        end
        return false
      end
    )
    i = i + 1
  end

  return nearestEnemyFound
end

local function hasTarget(self, target)
  local found = false
  local i = 1
  while (i <= #self) and (not found) do
    local t = self[i]
    found = target == t
    i = i + 1
  end
  return found
end

-- check if mouse position is blocked by a wall or out of attack range
local function checkMousePosition(self)
  local mx, my = camera:getMousePosition()
  local dx, dy = Position.getDirection(self.x, self.y, mx, my)
  local actualMx, actualMy = self.x + dx * self.attackRange, self.y + dy * self.attackRange
  mx, my = actualMx, actualMy
  local items, wallCollisionCount = colMap:querySegment(self.x, self.y, mx, my, function(item)
    -- obstacle filters
    return defaultFilters[item.group]
  end)
  local isBlockedByWall = wallCollisionCount > 0
  if isBlockedByWall then
    local wallCollision = items[1]
    mx = wallCollision.x
    my = wallCollision.y
  end
  local isValidPosition = not isBlockedByWall
  return mx, my, isValidPosition
end

local function getAllTargets(self, pointerX, pointerY)
  for i=1, self.maxTargets do
    local maxSeekRadius = i == 1 and 1 or 6
    local target = findNearestTarget(self, self.targets, pointerX, pointerY, maxSeekRadius)
    table.insert(self.targets, target)
  end
end

ChainLightning.init = function(self)
  assert(
    type(self.targetGroup) == 'string' and self.targetGroup ~= nil,
    '[ChainLightning] `targetGroup` is required'
  )

  -- find 3 targets to hit ahead of time
  self.targets = {
    hasTarget = hasTarget
  }

  local pointerX, pointerY, isValidPosition = checkMousePosition(self)
  if (isValidPosition) then
    getAllTargets(self, pointerX, pointerY)
  end

  local foundTargets = #self.targets > 0
  -- set target to mouse position so we at least have an animation when no targets are found
  if (not foundTargets) then
    table.insert(self.targets, {x = pointerX, y = pointerY})
  end

  self.polyLine = {}
  local targetIndex = 1
  local animationDone = true
  local tw = nil
  local previousTarget = self
  local endState = nil
  local subject = nil
  local currentTarget = nil
  -- animate and deal damage once the animation ends for a given target
  self.tween = function(dt)
    local isFullAnimationComplete = targetIndex > #self.targets
    if (not isFullAnimationComplete) then
      if animationDone then
        currentTarget = self.targets[targetIndex]
        subject = {x = previousTarget.x, y = previousTarget.y}
        endState = {x = currentTarget.x, y = currentTarget.y}
        tw = tween.new(0.04, subject, endState)
      end
      animationDone = tw:update(dt)

      local polyLineIndex = (targetIndex - 1) * 2
      self.polyLine[polyLineIndex + 1] = previousTarget.x
      self.polyLine[polyLineIndex + 2] = previousTarget.y
      self.polyLine[polyLineIndex + 3] = subject.x
      self.polyLine[polyLineIndex + 4] = subject.y

      if animationDone then
        msgBus.send(msgBus.CHARACTER_HIT, {
          parent = currentTarget,
          damage = math.random(self.minDamage, self.maxDamage)
        })
        previousTarget = currentTarget
        targetIndex = targetIndex + 1
      end
    else
      self.done = true
    end
  end
end

ChainLightning.update = function(self, dt)
  self.lifeTime = self.lifeTime - dt

  local isExpired = self.lifeTime <= 0
  if isExpired or self.done then
    self:delete()
  end

  self.tween(dt)
end

local function drawTargets(self)
  for i=1, #self.targets do
    local t = self.targets[i]
    -- point outer
    love.graphics.setColor(0.6,0.6,1,0.8)
    love.graphics.circle(
      'fill',
      t.x,
      t.y,
      5
    )

    -- point inner
    love.graphics.setColor(1,1,1,1)
    love.graphics.circle(
      'fill',
      t.x,
      t.y,
      3
    )
  end
end

ChainLightning.draw = function(self)
  local originalLineWidth = love.graphics.getLineWidth()

  -- chain outer
  love.graphics.setColor(0.6,0.6,1,0.8)
  love.graphics.setLineWidth(4)
  love.graphics.line(self.polyLine)

  -- chain inner
  love.graphics.setColor(Color.WHITE)
  love.graphics.setLineWidth(2)
  love.graphics.line(self.polyLine)

  drawTargets(self)
  love.graphics.setLineWidth(originalLineWidth)
end

ChainLightning.drawOrder = function(self)
  local order = self.group.drawOrder(self) + 100
  return order
end

return Component.createFactory(ChainLightning)