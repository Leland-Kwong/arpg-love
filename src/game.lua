-- can't use lua strict right now because 'jumper' library uses globals which throws errors
-- require 'lua_modules.strict'
require 'components.run'
require 'main.globals'

-- NOTE: this is necessary for crisp pixel rendering
love.graphics.setDefaultFilter('nearest', 'nearest')

local msgBus = require 'components.msg-bus'
local config = require 'config.config'

require 'main.inputs'
require 'main.listeners'

-- load up user settings on game start
local userSettingsState = require 'config.user-settings.state'
userSettingsState.load()

local groups = require 'components.groups'
local camera = require 'components.camera'
local tick = require 'utils.tick'
local globalState = require 'main.global-state'
local gsa = require 'main.global-state-actions'
local systemsProfiler = require 'components.profiler.component-groups'
local Component = require 'modules.component'

local scale = config.scaleFactor

local state = {
  resolution = nil,
  scale = nil,
  productionScale = config.scale
}

local changeCount = 0
local function setViewport()
  local isDevModeChange = config.isDevelopment ~= state.isDevelopment
  if isDevModeChange then
    state.isDevelopment = config.isDevelopment
  end

  local currentResolution = state.resolution
  local isResolutionChange = config.resolution ~= state.resolution
  local isScaleChange = config.scale ~= state.scale
  if (isResolutionChange or isScaleChange) then
    local vw, vh = config.resolution.w * config.scale, config.resolution.h * config.scale
    love.window.setMode(vw, vh)
    camera
      :setSize(vw, vh)
      :setScreenPosition(vw/2, vh/2)
      :setScale(config.scale)
    msgBus.send(msgBus.CURSOR_SET, {})

    state.resolution = config.resolution
    state.scale = config.scale
  end
end

function love.load()
  msgBus.send(msgBus.GAME_LOADED)
  love.keyboard.setKeyRepeat(true)
  setViewport()
  require 'main.onload'

  --[[
    run tests after everything is loaded since some tests rely on the game loop
  ]]
  if config.isDevelopment then
    require 'modules.test'
  end
end

local characterSystem = require 'components.groups.character'

function love.update(dt)
  gsa('updateGameClock', dt)
  setViewport()

  jprof.push('frame')

  systemsProfiler()

  msgBus.send(msgBus.UPDATE, dt)
  Component.animateUpdate(dt)
  tick.update(dt)

  camera:update(dt)

  characterSystem(dt)
  --[[
    process all gui components first since they always
    overlay on top of the game. This is guarantees that any gui interactions
    are prioritized over everything else.
  ]]
  groups.gui.updateAll(dt)
  groups.hud.updateAll(dt)

  camera:attach()

  local gameDt = config.gameSpeedMultiplier * dt
  groups.firstLayer.updateAll(gameDt)
  groups.all.updateAll(gameDt)

  groups.overlay.updateAll(dt)
  groups.debug.updateAll(dt)
  camera:detach()

  groups.system.updateAll(dt)
  msgBus.send(msgBus.UPDATE_END, dt)
end

function love.draw()
  camera:attach()
  -- background
  love.graphics.clear(globalState.backgroundColor)
  groups.firstLayer.drawAll()
  groups.all.drawAll()
  groups.overlay.drawAll()
  groups.debug.drawAll()
  camera:detach()

  love.graphics.push()
  love.graphics.scale(camera.scale)
  groups.hud.drawAll()
  require 'components.groups.gui-draw-box'()
  groups.gui.drawAll()
  love.graphics.pop()

  groups.system.drawAll()

  jprof.pop('frame')
end

function love.quit()
  jprof.write('prof.mpack')
end
