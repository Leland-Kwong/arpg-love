local socket = require 'socket'
local pprint = require 'utils.pprint'
local memoize = require 'utils.memoize'
local flowField = require 'scene.sandbox.ai.flow-field'
local groups = require 'components.groups'
local collisionObject = require 'modules.collision'
local bump = require 'modules.bump'

local colWorld = bump.newWorld(50)
local arrow = love.graphics.newImage('scene/sandbox/ai/arrow-up.png')

local grid = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,1},
  {1,0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,1,0,0,0,1},
  {1,0,0,0,1,1,1,1,1,1,0,0,0,0,0,1,0,0,0,0,1},
  {1,0,0,0,0,0,1,0,0,1,0,0,1,0,0,1,0,0,0,0,1},
  {1,0,0,0,0,0,1,0,0,1,0,0,1,0,0,1,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,0,0,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1,1,0,0,0,1},
  {1,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,1,0,0,1},
  {1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,1},
  {1,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,1},
  {1,0,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,0,0,0,1},
  {1,0,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,0,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}

local gridSize = 40
local offX, offY = 220, 70
local WALKABLE = 0

local flowFieldTestBlueprint = {
  showFlowFieldText = false,
  showGridCoordinates = true
}

local function isOutOfBounds(grid, x, y)
  return y < 1 or x < 1 or y > #grid or x > #grid[1]
end

local function isGridCellVisitable(grid, x, y, dist)
  return not isOutOfBounds(grid, x, y) and
    grid[y][x] == WALKABLE
end

-- returns grid units relative to the ui
local function pxToGridUnits(screenX, screenY)
  local gridPixelX, gridPixelY = screenX - offX, screenY - offY
  local gridX, gridY =
    math.floor(gridPixelX / gridSize) + 1,
    math.floor(gridPixelY / gridSize) + 1
  return gridX, gridY
end

local function getFlowFieldValue(flowField, gridX, gridY)
  local row = flowField[gridY]
  local v = row[gridX]
  if not v then
    return 0, 0, 0
  end
  return v[1], v[2], v[3]
end

local Ai = {}
local Ai_mt = {__index = Ai}

local function isZeroVector(vx, vy)
  return vx == 0 and vy == 0
end

-- gets directions from grid position, adjusting vectors to handle wall collisions as needed
local normalize = require'utils.position'.normalizeVector
Ai.getDirections = require'scene.sandbox.ai.pathing-with-steering'
local aiPathWithAstar = require'scene.sandbox.ai.pathing-with-astar'
Ai.getPathWithAstar = require'utils.perf'({
  enabled = false,
  done = function(t)
    print('ai path:', t)
  end
})(aiPathWithAstar)

function Ai:move(flowField, dt)
  local actualX, actualY = self.x - offX, self.y - offY
  local slop = 8

  local gridX, gridY = pxToGridUnits(self.x, self.y)
  self.pathWithAstar = self:getPathWithAstar(flowField, grid, gridX, gridY, 30, WALKABLE)
  local vx, vy = self:getDirections(flowField, grid, gridX, gridY)
  self.vx = vx
  self.vy = vy
  self.dx = self.speed * vx * dt
  self.dy = self.speed * vy * dt

  local nextX, nextY = self.x + self.dx, self.y + self.dy
  local adjustedX, adjustedY, cols, len = self.collision:move(nextX, nextY)
  self.x = adjustedX
  self.y = adjustedY
end

local function drawPathWithAstar(self)
  local p = self.pathWithAstar
  local agentSilhouetteDrawQueue = {}
  local agentPathDrawQueue = {}

  for i=1, #p do
    local point = p[i]
    local x, y = (point[1] - 1) * gridSize + offX,
      (point[2] - 1) * gridSize + offY

    -- agent silhouette
    table.insert(
      agentSilhouetteDrawQueue,
      function()
        love.graphics.setColor(1,1,1,1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle(
          'fill',
          x, y,
          gridSize * 2,
          gridSize * 2
        )
      end
    )

    -- agent path
    table.insert(
      agentPathDrawQueue,
      function()
        love.graphics.setColor(0.6,0.7,0.0,0.5)
        love.graphics.rectangle(
          'fill',
          x, y,
          gridSize,
          gridSize
        )

        love.graphics.setColor(1,1,1,1)
        love.graphics.print(i, x + 5, y + 5)
      end
    )
  end

  self.canvasAgentSilhouette = self.canvasAgentSilhouette or love.graphics.newCanvas()
  love.graphics.setCanvas(self.canvasAgentSilhouette)
  love.graphics.clear()
  for i=1, #agentSilhouetteDrawQueue do
    agentSilhouetteDrawQueue[i]()
  end
  love.graphics.setCanvas()
  love.graphics.setColor(1,1,1,0.3)
  love.graphics.draw(self.canvasAgentSilhouette)

  for i=1, #agentPathDrawQueue do
    agentPathDrawQueue[i]()
  end
end

function Ai:draw()
  love.graphics.setColor(1,0.2,0, 0.8)
  local padding = 0
  love.graphics.rectangle(
    'fill',
    self.x + padding,
    self.y + padding,
    self.w - padding * 2,
    self.h - padding * 2
  )

  love.graphics.setColor(1,1,1,1)
  love.graphics.rectangle(
    'line',
    self.collision.x + self.collision.ox,
    self.collision.y + self.collision.oy,
    self.collision.h,
    self.collision.w
  )

  local round = require'utils.math'.round
  love.graphics.print(
    'vx: '..round(self.vx, 2)..'\nvy: '..round(self.vy, 2),
    self.x,
    self.y
  )

  drawPathWithAstar(self)
end

local function createAi(x, y)
  local scale = 1
  local size = (gridSize * scale) - 5
  local w, h = size, size
  local colObj = collisionObject
    :new('ai', x, y, w, h)
    :addToWorld(colWorld)
  return setmetatable({
    x = x,
    y = y,
    w = w,
    h = h,
    dx = 0,
    dy = 0,
    scale = scale,
    speed = 0,
    collision = colObj
  }, Ai_mt)
end

function flowFieldTestBlueprint.init(self)
  local iterateGrid = require 'utils.iterate-grid'
  self.wallCollisions = {}
  iterateGrid(grid, function(v, x, y)
    if v ~= WALKABLE then
      self.wallCollisions[y] = self.wallCollisions[y] or {}
      self.wallCollisions[y][x] = collisionObject:new(
        'wall',
        ((x - 1) * gridSize) + offX,
        ((y - 1) * gridSize) + offY,
        gridSize, gridSize
      ):addToWorld(colWorld)
    end
  end)

  self.flowField = flowField(grid, 5, 7, isGridCellVisitable)

  local gridOffset = -1
  self.ai = createAi(offX + ((gridOffset + 11) * gridSize), offY + ((gridOffset + 6) * gridSize))
end

function flowFieldTestBlueprint.update(self, dt)
  if love.mouse.isDown(1) or love.keyboard.isDown('space') then
    local mx, my = love.mouse.getX(), love.mouse.getY()
    local gridX, gridY = pxToGridUnits(mx, my)

    if isOutOfBounds(grid, gridX, gridY) then
      return
    end

    local gridValue = grid[gridY][gridX]
    if gridValue ~= WALKABLE then
      return
    end

    local ts = socket.gettime()
    self.flowField = flowField(grid, gridX, gridY, isGridCellVisitable)
    self.executionTimeMs = (socket.gettime() - ts) * 1000
  end

  self.ai:move(self.flowField, dt)
end

local function arrowRotationFromDirection(dx, dy)
  if dx < 0 then
    if dy < 0 then
      return math.rad(-45)
    end
    if dy > 0 then
      return math.rad(225)
    end
    return math.rad(-90)
  end
  if dx > 0 then
    if dy < 0 then
      return math.rad(-315)
    end
    if dy > 0 then
      return math.rad(135)
    end
    return math.rad(90)
  end
  if dy < 0 then
    return math.rad(0)
  end
  return math.rad(180)
end

local COLOR_UNWALKABLE = {0.2,0.2,0.2,1}
local COLOR_WALKABLE = {0.2,0.35,0.55,1}
local COLOR_ARROW = {0.7,0.7,0.7}
local COLOR_START_POINT = {0,1,0}

local function drawMousePosition()
  local gridX, gridY = pxToGridUnits(
    love.mouse.getX(),
    love.mouse.getY()
  )
  love.graphics.setColor(1,1,0,1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle(
    'line',
    (gridX - 1) * gridSize + offX,
    (gridY - 1) * gridSize + offY,
    gridSize,
    gridSize
  )
end

function flowFieldTestBlueprint.draw(self)
  love.graphics.clear(0.1,0.1,0.1,1)

  love.graphics.setColor(1,1,1,1)
  love.graphics.print('CLICK GRID TO SET CONVERGENCE POINT', offX + 20, 20)

  if self.executionTimeMs ~= nil then
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.print(
      string.format('execution time: %.4f(ms)', self.executionTimeMs),
      offX + 20,
      50
    )
  end

  local textDrawQueue = {}
  local arrowDrawQueue = {}

  for y=1, #grid do
    local row = self.flowField[y] or {}
    for x=1, #grid[1] do
      local cell = row[x]
      local drawX, drawY =
        ((x-1) * gridSize) + offX,
        ((y-1) * gridSize) + offY

      local oData = grid[y][x]
      local ffd = row[x] -- flow field cell data
      local isStartPoint = ffd and (ffd.x == 0 and ffd.y == 0)
      if isStartPoint then
        love.graphics.setColor(COLOR_START_POINT)
      else
        love.graphics.setColor(
          oData == WALKABLE and
            COLOR_WALKABLE or
            COLOR_UNWALKABLE
        )
      end

      love.graphics.rectangle(
        'fill',
        drawX + 1,
        drawY + 1,
        gridSize - 2,
        gridSize - 2
      )

      -- wall collision rectangle
      if self.wallCollisions[y] and self.wallCollisions[y][x] then
        love.graphics.setColor(0,0.6,1,0.4)
        local margin = 2
        love.graphics.rectangle(
          'line',
          drawX + margin,
          drawY + margin,
          gridSize - margin * 2,
          gridSize - margin * 2
        )
      end

      if cell then
        arrowDrawQueue[#arrowDrawQueue + 1] = function()
          -- arrow
          love.graphics.setColor(COLOR_ARROW)
          if not isStartPoint then
            local rot = arrowRotationFromDirection(ffd.x, ffd.y)
            local offsetCenter = 8
            love.graphics.draw(
              arrow,
              drawX + gridSize / 2,
              drawY + gridSize / 2,
              rot,
              1,
              1,
              8,
              8
            )
          end
        end

        if self.showGridCoordinates then
          textDrawQueue[#textDrawQueue + 1] = function()
            love.graphics.setColor(0.5,0.8,0.5)
            love.graphics.scale(0.5)
            love.graphics.print(
              x..' '..y,
              drawX * 2 + 5,
              drawY * 2 + 6
            )
            love.graphics.scale(2)
          end
        end

        if self.showFlowFieldText then
          textDrawQueue[#textDrawQueue + 1] = function()
            love.graphics.scale(0.5)
            love.graphics.setColor(0.6,0.6,0.6,1)

            -- direction vectors
            love.graphics.print(
              row[x].x..' '..row[x].y,
              (drawX + 5) * 2,
              (drawY + 5) * 2
            )

            -- distance
            love.graphics.print(
              row[x].dist,
              (drawX + gridSize/2) * 2,
              (drawY + gridSize - 6) * 2
            )

            love.graphics.scale(2)
          end
        end
      end
    end
  end

  for i=1, #arrowDrawQueue do
    arrowDrawQueue[i]()
  end

  for i=1, #textDrawQueue do
    textDrawQueue[i]()
  end

  self.ai:draw()
  drawMousePosition()
end

return groups.gui.createFactory(flowFieldTestBlueprint)