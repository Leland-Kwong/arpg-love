local Component = require 'modules.component'
local groups = require 'components.groups'
local GuiText = require 'components.gui.gui-text'
local StatusBar = require 'components.hud.status-bar'
local collisionWorlds = require 'components.collision-worlds'
local camera = require 'components.camera'
local config = require 'config.config'
local Position = require 'utils.position'
local Color = require 'modules.color'
local collisionGroups = require 'modules.collision-groups'
local msgBus = require 'components.msg-bus'

local itemHovered = nil
local aiHoverFilter = function(item)
  return (not itemHovered) and collisionGroups.matches(item.group, collisionGroups.enemyAi)
end

local NpcInfo = {
  group = groups.hud,
  target = nil, -- hovered npc component
  y = 15,
}

local function windowSize()
  return love.graphics.getWidth() / config.scale, love.graphics.getHeight() / config.scale
end

function NpcInfo.init(self)
  local textLayer = Component.get('HUD').hudTextLayer
  local y = self.y
  self.statusBar = StatusBar.create({
    y = y,
    color = {Color.multiplyAlpha(Color.DEEP_RED, 0.9)},
    fillPercentage = function()
      local percentage = self.target.stats:get('health') /
        self.target.stats:get('maxHealth')
      return percentage
    end
  }):setParent(self)
    :setDisabled(true)
  Component.addToGroup(self.statusBar:getId(), 'gameWorld', self.statusBar)
end

function NpcInfo.update(self, dt)
  local textLayer = Component.get('HUD').hudTextLayer
  local textLayerSmall = Component.get('HUD').hudTextSmallLayer
  local mx, my = camera:getMousePosition()
  local maxArea = 32
  local area = 4
  itemHovered = nil
  local items, len = nil, 0
  -- slowly increase area around cursor until we find something.
  -- This improves the ux since it makes for a larger hitbox
  while (len == 0) and (area < maxArea) do
    items, len = collisionWorlds.map:queryRect(
      -- readjust coordinates to center to mouse
      mx - area/2,
      my - area/2,
      area,
      area,
      aiHoverFilter
    )
    area = area + 4
  end

  if len > 0 then
    itemHovered = items[1].parent
    local dataSheet = itemHovered.dataSheet
    local name = itemHovered.name or ''
    local windowW, windowH = windowSize()
    local textWidth, textHeight = GuiText.getTextSize(dataSheet.name, textLayer.font)
    local w, h = math.max(textWidth + 30, 200), textHeight + 3
    local x, y = Position.boxCenterOffset(
      w,
      h,
      windowW,
      windowH
    )
    self.statusBar.w, self.statusBar.h = w,h

    textLayer:addf(
      {
        itemHovered.rarityColor or Color.WHITE,
        dataSheet.name,
      },
      w,
      'center',
      math.floor(x),
      self.statusBar.y + 4
    )
    local props = dataSheet.properties
    local propsText = ''
    for i=1, #props do
      local p = props[i]
      local separator = i > 1 and ', ' or ''
      propsText = propsText..separator..p
    end
    local wrapLimit = 250
    local _, propsTextHeight = GuiText.getTextSize(propsText, textLayerSmall.font, wrapLimit)
    local windowW, windowH = windowSize()
    local xPos = Position.boxCenterOffset(wrapLimit, propsTextHeight, windowW, windowH)
    local propsTextVerticalMargin = 5
    textLayerSmall:addf(
      {Color.WHITE, propsText},
      wrapLimit,
      'center',
      xPos,
      self.statusBar.y + self.statusBar.h + propsTextVerticalMargin
    )
    self.target = itemHovered
  end
  msgBus.send('CURSOR_SET', {
    type = itemHovered and 'target' or 'pointer'
  })
  self.statusBar:setDisabled(not itemHovered)
end

return Component.createFactory(NpcInfo)