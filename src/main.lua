-- can't use lua strict right now because 'jumper' library uses globals which throws errors
-- require 'lua_modules.strict'

require 'components.run'

-- NOTE: this is necessary for crisp pixel rendering
love.graphics.setDefaultFilter('nearest', 'nearest')

local msgBus = require 'components.msg-bus'
msgBus.UPDATE = 'UPDATE'

local Console = require 'modules.console.console'
local groups = require 'components.groups'
local config = require 'config.config'
local camera = require 'components.camera'
local SceneMain = require 'scene.scene-main'
local RootScene = require 'scene.sandbox.main'
local tick = require 'utils.tick'
local globalState = require 'main.global-state'
require 'main.inputs'
local systemsProfiler = require 'components.profiler.component-groups'
require 'components.groups.dungeon-test'
require 'components.groups.game-world'
require 'modules.file-system'
require 'utils.time'

local scale = config.scaleFactor

function love.load()
  msgBus.send(msgBus.GAME_LOADED)
  love.keyboard.setKeyRepeat(true)
  local vw, vh = config.window.width, config.window.height
  love.window.setMode(vw, vh)
  camera
    :setSize(vw, vh)
    :setScale(scale)

  -- console debugging
  local console = Console.create()
  require 'main.listeners'

  RootScene.create()
end

local characterSystem = msgBus.send(msgBus.PROFILE_FUNC, {
  name = 'character',
  call = require 'components.groups.character'
})

local profile = require('modules.profile')

function love.update(dt)
  profile.push('frame')

  systemsProfiler()

  msgBus.send(msgBus.UPDATE, dt)
  tick.update(dt)

  camera:update(dt)
  characterSystem(dt)
  groups.firstLayer.updateAll(dt)
  groups.all.updateAll(dt)
  groups.overlay.updateAll(dt)
  groups.debug.updateAll(dt)
  groups.hud.updateAll(dt)
  groups.gui.updateAll(dt)
  groups.system.updateAll(dt)
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
  love.graphics.scale(config.scaleFactor)
  groups.hud.drawAll()
  groups.gui.drawAll()
  love.graphics.pop()

  groups.system.drawAll()

  profile.pop('frame')
end

--[[
  run tests after everything is loaded since some tests
  since some of the tests rely on the game loop
]]
if config.isDebug then
  require 'modules.test.index'
  require 'utils.test.index'
  require 'components.loot-generator.test'
  require '_debug'
end