local Component = require 'modules.component'
local AnimationFactory = require 'components.animation-factory'

Component.create({
  id = 'InteractableIndicators',
  init = function(self)
    Component.addToGroup(self, 'all')
    self.clock = 0
  end,
  update = function(self, dt)
    self.clock = self.clock + (dt * 4)
  end,
  draw = function(self)
    love.graphics.setColor(1,1,1)
    local interactables = Component.groups.interactableIndicators.getAll()
    local offsetY = (4 * math.sin(self.clock))
    for _,interact in pairs(interactables) do
      local icon = AnimationFactory:newStaticSprite(interact.icon)
      icon:draw(interact.x, interact.y, 0, 1, -1, 0, offsetY - 15)
    end
    Component.clearGroup('interactableIndicators')
  end,
  drawOrder = function()
    return math.pow(10, 10)
  end
})