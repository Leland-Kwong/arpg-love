local dynamicRequire = require 'utils.dynamic-require'
local Component = require 'modules.component'
local Gui = require 'components.gui.gui'
local Position = require 'utils.position'
local Vec2 = require 'modules.brinevector'
local Grid = dynamicRequire 'utils.grid'
local bump = require 'modules.bump'
local msgBus = require 'components.msg-bus'
local room1 = require 'built.maps.room-1'
local F = require 'utils.functional'
local Color = require 'modules.color'
local memoize = require 'utils.memoize'

local gridSize = {
  w = 60,
  h = 80
}
local colWorld = bump.newWorld(10)

local uiCollisions = {}
local stateMt = {
  _onChange = function()
    return self
  end,
  set = function(self, k, v)
    local currentVal = self[k]
    self[k] = v
    self._onChange(self, k, v, currentVal)
    return self
  end,
  onChange = function(self, callback)
    self._onChange = callback
    return self
  end
}
stateMt.__index = stateMt
local state = setmetatable({
  mapSize = Vec2(0, 0),
  loadDir = nil,
  saveDir = nil,
  fileStateContext = nil,
  mousePosition = Vec2(0, 0),
  mouseGridPosition = Vec2(0, 0),
  objects = {},
  layouts = {}
}, stateMt)

local uiState = setmetatable({
  translate = {
    startX = 0,
    startY = 0,
    dx = 0,
    dy = 0,
    x = 0,
    y = 0,

    zoomOffset = Vec2(0, 0),
  },
  scale = 1,
  nextScale = 2,

  getTranslate = function(self)
    local tx = self.translate
    return tx.x + tx.dx, tx.y + tx.dy
  end
}, stateMt)

local layoutsCanvas = love.graphics.newCanvas(4096, 4096)
local gridCanvas = love.graphics.newCanvas(4096, 4096)

local function panTo(x, y)
  local tx = uiState.translate
  tx.x, tx.y = x, y
end

local function handlePanning(event)
  -- panning
  local tx = uiState.translate
  local scale = uiState.scale
  tx.startX = event.startX/scale
  tx.startY = event.startY/scale
  tx.dx = math.floor(event.dx/scale)
  tx.dy = math.floor(event.dy/scale)
end

local function handlePanningEnd(event)
  local state = uiState

  -- update tree translation
  local tx = state.translate
  panTo(tx.x + tx.dx, tx.y + tx.dy)
  tx.startX = 0
  tx.startY = 0
  tx.dx = 0
  tx.dy = 0
end

local function setupGridCanvas(colSpan, rowSpan)
  love.graphics.setCanvas(gridCanvas)
  love.graphics.push()
  love.graphics.origin()
  love.graphics.clear()
  local color = 0.2
  love.graphics.setColor(color, color, color)

  for y=0, (rowSpan - 1) do
    for x=0, (colSpan - 1) do
      local renderX, renderY = x * gridSize.w + 0.5, y * gridSize.h + 0.5
      love.graphics.rectangle('line', renderX, renderY, gridSize.w, gridSize.h)
    end
  end

  love.graphics.setCanvas()
  love.graphics.pop()
end

-- Lua implementation of PHP scandir function
local function loadLayouts(directory)
  local layouts = {}
  local lfs = require 'lua_modules.lfs_ffi'
  for file in lfs.dir(directory) do
    local fullPath = directory..'\\'..file
    local mode = lfs.attributes(fullPath,"mode")
    if mode == "file" then
      -- print("found file, "..file)
      local io = require 'io'
      local fileDescriptor = io.open(fullPath)
      table.insert(
        layouts,
        {
          file = file,
          data = load(
            fileDescriptor:read('*a')
          )()
        }
      )
    end
  end
  return layouts
end

local function iterateListAsGrid(list, numCols, callback)
  for i=1, #list do
    local val = list[i]
    local x, y = Grid.getCoordinateByIndex(list, i, numCols)
    callback(val, x, y)
  end
end

local tileRenderer = {
  [1] = function(x, y, w, h)
    love.graphics.setColor(1,1,1,0.2)
    love.graphics.rectangle('fill', x, y, w, h)
  end,
  [12] = function(x, y, w, h)
    love.graphics.setColor(1,1,1,1)
    love.graphics.rectangle('fill', x, y, w, h)
  end
}

local layoutCollisions = {}
local updateLayouts = memoize(function (layouts, groupOrigin)
  local oBlendMode = love.graphics.getBlendMode()

  love.graphics.setBlendMode('alpha', 'premultiplied')
  love.graphics.setCanvas(layoutsCanvas)
  love.graphics.clear()
  love.graphics.setColor(1,1,1)
  love.graphics.push()
  love.graphics.origin()

  local tileRenderSize = 1
  local layouts = state.layouts
  local offsetY = 0

  for i=1, #layoutCollisions do
    colWorld:remove(layoutCollisions[i])
  end
  layoutCollisions = {}

  for i=1, #layouts do
    local l = layouts[i]
    local textHeight = 20
    local marginTop = 10

    local obj = {
      x = groupOrigin.x,
      y = groupOrigin.y + offsetY + textHeight,
      w = l.data.width,
      h = l.data.height + textHeight,

      MOUSE_CLICKED = function()
        print(l.file)
      end
    }
    table.insert(layoutCollisions, obj)
    colWorld:add(obj, obj.x, obj.y, obj.w, obj.h)

    love.graphics.print(l.file, obj.x, obj.y - textHeight)

    local groundLayer = F.find(l.data.layers, function(l)
      return l.name == 'ground'
    end)
    if groundLayer then
      iterateListAsGrid(groundLayer.data, l.data.width, function(v, x, y)
        if tileRenderer[v] then
          tileRenderer[v](obj.x + x * tileRenderSize, obj.y + y * tileRenderSize, tileRenderSize, tileRenderSize)
        end
      end)
    end

    local wallLayer = F.find(l.data.layers, function(l)
      return l.name == 'walls'
    end)
    if wallLayer then
      iterateListAsGrid(wallLayer.data, l.data.width, function(v, x, y)
        if tileRenderer[v] then
          tileRenderer[v](obj.x + x * tileRenderSize, obj.y + y * tileRenderSize, tileRenderSize, tileRenderSize)
        end
      end)
    end

    offsetY = offsetY + l.data.height + textHeight + marginTop
  end

  love.graphics.pop()
  love.graphics.setCanvas()
  love.graphics.setBlendMode(oBlendMode)
end)

state:onChange(function(self, k, val, prevVal)
  local isNewVal = val ~= prevVal

  local isNewLoadDir = k == 'loadDir' and isNewVal
  if isNewLoadDir then
    local layouts = loadLayouts(val)
    state:set('layouts', layouts)
    updateLayouts(layouts,  {
      x = 10,
      y = 10
    })
  end

  local isNewMapSize = k == 'mapSize' and isNewVal
  if isNewMapSize then
    setupGridCanvas(state.mapSize.x, state.mapSize.y)
  end
end)
state:set('loadDir', 'C:\\Users\\lelandkwong\\Projects\\arpg-love\\src\\built\\maps')

local function renderMousePosition(self)
  love.graphics.setColor(0,0.5,1)
  local mgp = state.mousePosition
  love.graphics.rectangle('line', mgp.x, mgp.y, gridSize.w, gridSize.h)
end

local inputWidth = 500

local loadedDirectoryBox = {
  id = 'loadedDirectory',
  x = love.graphics.getWidth() - 10 - inputWidth,
  y = 10,
  w = inputWidth,
  h = 30
}

colWorld:add(
  loadedDirectoryBox,
  loadedDirectoryBox.x,
  loadedDirectoryBox.y,
  loadedDirectoryBox.w,
  loadedDirectoryBox.h
)

local saveDirectoryBox = {
  id = 'saveDirectory',
  x = love.graphics.getWidth() - 10 - inputWidth,
  y = loadedDirectoryBox.y + 35,
  w = inputWidth,
  h = 30
}

colWorld:add(
  saveDirectoryBox,
  saveDirectoryBox.x,
  saveDirectoryBox.y,
  saveDirectoryBox.w,
  saveDirectoryBox.h
)

local function guiPrint(text, x, y)
  local getFont = require 'components.font'
  love.graphics.setFont(getFont.debug.font)
  love.graphics.print(text, x, y)
end

local function renderLoadDirectoryBox()
  local isHovered = F.find(uiCollisions, function(c)
    return c.other.id == loadedDirectoryBox.id
  end) ~= nil
  if isHovered then
    love.graphics.setColor(1,1,0)
  else
    love.graphics.setColor(1,1,1)
  end
  local box = loadedDirectoryBox
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', box.x - 0.5, box.y - 0.5, box.w, box.h)
  guiPrint(state.loadDir or 'drag folder to load Tiled maps', box.x + 3, box.y + 5)
end

local function renderSaveDirectoryBox()
  local isHovered = F.find(uiCollisions, function(c)
    return c.other.id == saveDirectoryBox.id
  end) ~= nil
  if isHovered then
    love.graphics.setColor(1,1,0)
  else
    love.graphics.setColor(1,1,1)
  end
  local box = saveDirectoryBox
  love.graphics.setLineWidth(1)
  love.graphics.rectangle('line', box.x - 0.5, box.y - 0.5, box.w, box.h)
  guiPrint(state.saveDir or 'drag folder to save to', box.x + 3, box.y + 5)
end

local function renderGuiElements()
  renderLoadDirectoryBox()
  renderSaveDirectoryBox()
end

local function getFileStateContext(dir)
  local context = F.find(uiCollisions, function(c)
    local otherId = c.other.id
    return otherId == loadedDirectoryBox.id or otherId == saveDirectoryBox.id
  end)

  local contexts = {
    [loadedDirectoryBox.id] = 'loadDir',
    [saveDirectoryBox.id] = 'saveDir'
  }

  return contexts[context.other.id]
end

function love.directorydropped(dir)
  local fileStateContext = getFileStateContext()
  if fileStateContext then
    state:set(fileStateContext, dir)
  end
end

local getNativeMousePos = dynamicRequire 'repl.shared.native-cursor-position'
local function getCursorPos()
  local pos = getNativeMousePos()
  local windowX, windowY = love.window.getPosition()
  return {
    x = pos.x - windowX,
    y = pos.y - windowY
  }
end

Component.create({
  id = 'LayoutEditor',
  group = 'gui',

  init = function(self)
    local homeScreenRef = Component.get('HomeScreen')
    if homeScreenRef then
      homeScreenRef:delete()
    end

    state:set('mapSize', Vec2(20, 10))

    local mouseCollision = {}
    colWorld:add(mouseCollision, 0, 0, 1, 1)

    Gui.create({
      x = 0,
      y = 0,
      inputContext = 'editorBase',
      scale = 1,
      onPointerMove = function(self, ev)
        local pos = getCursorPos()
        local translateX, translateY = uiState:getTranslate()
        local clamp = require 'utils.math'.clamp
        local gridPos = Vec2(
          clamp(math.floor((pos.x - translateX)/gridSize.w), 0, state.mapSize.x - 1),
          clamp(math.floor((pos.y - translateY)/gridSize.h), 0, state.mapSize.y - 1)
        )
        local posX, posY = (gridPos.x * gridSize.w), (gridPos.y * gridSize.h)
        local round = require 'utils.math'.round
        state:set('mousePosition', Vec2(posX + translateX, posY + translateY))
        state:set('mouseGridPosition', Vec2(gridPos.x, gridPos.y))

        local _, _, cols, len = colWorld:move(mouseCollision, pos.x, pos.y, function()
          return 'cross'
        end)
        uiCollisions = cols

        msgBus.send('CURSOR_SET', { type = uiState.panning and 'move' or 'default' })
      end,
      onClick = function(self)
        -- place a layout down
      end,
      onUpdate = function(self, dt)
        self.w, self.h = love.graphics.getWidth(),
          love.graphics.getHeight()
      end,
      render = function(self)
        love.graphics.push()
        love.graphics.origin()

        love.graphics.push()
        love.graphics.translate(uiState:getTranslate())
        love.graphics.setColor(1,1,1)
        love.graphics.draw(gridCanvas)
        love.graphics.pop()

        renderMousePosition(self)
        love.graphics.setColor(1,1,1)
        love.graphics.draw(layoutsCanvas)

        renderGuiElements(self)

        love.graphics.pop()
      end
    }):setParent(self)

    self.listeners = {
      msgBus.on('*', function(ev, msgType)
        for i=1, #uiCollisions do
          local c = uiCollisions[i]
          local eventHandler = c.other[msgType]
          if eventHandler then
            eventHandler(c.other)
          end

          local mouseMoveHandler = c.other.MOUSE_MOVE
          if mouseMoveHandler then
            mouseMoveHandler(c.other)
          end
        end
      end),

      msgBus.on('MOUSE_DRAG', function(ev)
        if love.keyboard.isDown('space') then
          handlePanning(ev)
        else
          handlePanningEnd(ev)
        end
      end),

      msgBus.on('MOUSE_DRAG_END', function(ev)
        handlePanningEnd(ev)
      end)
    }
  end,

  update = function(self, dt)
    uiState:set('panning', love.keyboard.isDown('space'))
  end
})