local font = require 'components.font'
local groups = require 'components.groups'
local tween = require 'modules.tween'
local f = require 'utils.functional'

local PopupTextBlueprint = {
  x = 0,
  y = 0,
}

local tweenEndState = {offset = -10}
local function animationCo()
  local frame = 0
  local subject = {offset = 0}
  local posTween = tween.new(0.2, subject, tweenEndState, tween.easing.outCubic)
  local complete = false

  while (not complete) do
    complete = posTween:update(1/60)
    coroutine.yield(subject.offset)
  end
end

function PopupTextBlueprint:new(text, x, y)
  local animation = coroutine.wrap(animationCo)
  table.insert(self.textObjectsList, {text, x, y, animation})
end

local pixelOutlineShader = love.filesystem.read('modules/shaders/pixel-outline.fsh')
local outlineColor = {0,0,0,1}
local shader = love.graphics.newShader(pixelOutlineShader)
local w, h = 16, 16
shader:send('sprite_size', {w, h})
shader:send('outline_width', 2/16)
shader:send('outline_color', outlineColor)
shader:send('use_drawing_color', true)
shader:send('include_corners', true)

local textObj = love.graphics.newText(font.secondary.font, '')

function PopupTextBlueprint.init(self)
  self.textObjectsList = {}
end

function PopupTextBlueprint.update(self)
  textObj:clear()

  local i = 1
  while i <= #self.textObjectsList do
    local obj = self.textObjectsList[i]
    local text, x, y, animation = unpack(obj)
    local offsetY, errors = animation()

    local isComplete = offsetY == nil
    if isComplete then
      table.remove(self.textObjectsList, i)
    else
      i = i + 1
      textObj:add(text, x, y + offsetY)
    end
  end
end

function PopupTextBlueprint.draw(self)
  love.graphics.setShader(shader)
  love.graphics.setColor(1,1,1,1)
  love.graphics.draw(
    textObj,
    self.x,
    self.y
  )
  love.graphics.setShader()
end

return groups.overlay.createFactory(PopupTextBlueprint)