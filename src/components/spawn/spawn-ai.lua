local Component = require 'modules.component'
local Ai = require 'components.ai.ai'
local msgBus = require 'components.msg-bus'
local collisionWorlds = require 'components.collision-worlds'
local groups = require 'components.groups'
local config = require 'config.config'
local typeCheck = require 'utils.type-check'
local Math = require 'utils.math'
local animationFactory = require 'components.animation-factory'

local floor = math.floor

local SpawnerAi = {
  group = groups.all,
  x = 0,
  y = 0,
  speed = 0,
  scale = 1,
  -- these need to be passed in
  grid = nil,
  WALKABLE = nil,

  colWorld = collisionWorlds.map,
  pxToGridUnits = function(screenX, screenY, gridSize)
    typeCheck.validate(gridSize, typeCheck.NUMBER)

    local gridPixelX, gridPixelY = screenX, screenY
    local gridX, gridY =
      floor(gridPixelX / gridSize),
      floor(gridPixelY / gridSize)
    return gridX, gridY
  end,
  gridSize = config.gridSize,
}

local function AiFactory(self, x, y, speed, scale)
  local Enum = require 'utils.enum'

  local aiType = Enum({
    'MELEE',
    'RANGE'
  })

  local function getAiType(type)
    if type == aiType.MELEE then
      local animation = {
        attacking = animationFactory:new({
          'slime1',
          'slime2',
          'slime3',
          'slime4',
          'slime5',
          'slime6',
          'slime7',
          'slime8',
          'slime9',
          'slime10',
          'slime11',
        }),
        idle = animationFactory:new({
          'slime12',
          'slime13',
          'slime14',
          'slime15',
          'slime16'
        }),
        moving = animationFactory:new({
          'slime12',
          'slime13',
          'slime14',
          'slime15',
          'slime16'
        })
      }

      return 64, 36, animation
    end

    if type == aiType.RANGE then
      local animations = {
        moving = animationFactory:new({
          'ai-1',
          'ai-2',
          'ai-3',
          'ai-4',
          'ai-5',
          'ai-6',
        }),
        idle = animationFactory:new({
          'ai-7',
          'ai-8',
          'ai-9',
          'ai-10'
        })
      }

      local ability1 = (function()
        local curCooldown = 0
        local skill = {}

        function skill.use(self, targetX, targetY)
          if curCooldown > 0 then
            return skill
          else
            local Attack = require 'components.abilities.bullet'
            local projectile = Attack.create({
                debug = false
              , x = self.x
              , y = self.y
              , x2 = targetX
              , y2 = targetY
              , speed = 125
              , cooldown = 0.3
              , targetGroup = 'player'
            })
            curCooldown = projectile.cooldown
            return skill
          end
        end

        function skill.updateCooldown(dt)
          curCooldown = curCooldown - dt
          return skill
        end

        return skill
      end)()

      return 24, 20, animations, ability1
    end
  end

  local function findNearestTarget(otherX, otherY, otherSightRadius)
    if not self.target then
      return nil
    end

    local tPosX, tPosY = self.target:getPosition()
    local dist = Math.dist(tPosX, tPosY, otherX, otherY)
    local withinVision = dist <= otherSightRadius

    if withinVision then
      return tPosX, tPosY
    end

    return nil
  end

  local type = aiType.RANGE
  -- local type = math.random(0, 1) == 1 and aiType.MELEE or aiType.RANGE
  local w, h, animations, ability1 = getAiType(type)

  return Ai.create({
    x = self.x * self.gridSize,
    y = self.y * self.gridSize,
    w = w,
    h = h,
    speed = self.speed,
    scale = self.scale,
    collisionWorld = self.colWorld,
    pxToGridUnits = self.pxToGridUnits,
    findNearestTarget = findNearestTarget,
    grid = self.grid,
    gridSize = self.gridSize,
    WALKABLE = self.WALKABLE,
    showAiPath = self.showAiPath,
    attackRange = self.attackRange,
    COLOR_FILL = self.COLOR_FILL,
    animations = animations,
    ability1 = ability1
  })
end

function SpawnerAi.init(self)
  msgBus.subscribe(function(msgType, msgValue)
    if self:isDeleted() then
      return msgBus.CLEANUP
    end

    if msgBus.NEW_FLOWFIELD == msgType then
      self.flowField = msgValue.flowField
    end
  end)

  self.ai = AiFactory(self):setParent(self)
end

function SpawnerAi.update(self, dt)
  if self.ai:isDeleted() then
    self:delete()
    return
  end
  self.ai._update2(self.ai, self.grid, self.flowField, dt)
end

return Component.createFactory(SpawnerAi)
