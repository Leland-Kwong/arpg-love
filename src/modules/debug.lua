local Color = require 'modules.color'
local groups = require 'components.groups'
local M = {}

local queue = {}

-- creates a bounding box centered to point x,y
function M.boundingBox(mode, x, y, w, h)
  local function draw()
    local ox, oy = -w/2, -h/2
    love.graphics.rectangle(
      mode,
      x + ox,
      y + oy,
      w,
      h
    )
    love.graphics.circle(
      'fill',
      x,
      y,
      2
    )
  end
  queue[#queue + 1] = draw
end

local Debug = {
  getInitialProps = function()
    return {}
  end,

  drawOrder = groups.DRAW_ORDER_COLLISION_DEBUG,

  draw = function()
    for i=1, #queue do
      love.graphics.setColor(1,1,1,0.5)
      queue[i]()
      queue[i] = nil
    end
    love.graphics.setColor(1,1,1,1)
  end
}

groups.all.createFactory(function(defaults)
  Debug.drawOrder = function(self)
    return defaults.drawOrder(self) + 20
  end
  return Debug
end).create()

return M