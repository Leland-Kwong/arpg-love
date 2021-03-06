--[[
  animation library for handling sprite atlas animations in Love2d
]]

local abs = math.abs
local Lru = require 'utils.lru'

local meta = {}

local function createAnimationFactory(
  frameJson,
  spriteAtlas,
  paddingOffset,
  frameRate
)
  -- default to 60fps
  frameRate = frameRate == nil and 60 or frameRate

  local factory = {
    atlas = spriteAtlas,
    atlasData = frameJson,
    frameData = frameJson.frames,
    pad = paddingOffset,
    frameRate = frameRate,
    staticCacheByName = Lru.new(1000)
  }
  setmetatable(factory, meta)
  meta.__index = meta

  return factory
end

function meta:new(aniFrames)
  local animation = {
    numFrames = #aniFrames,
    aniFrames = aniFrames,
    timePerFrame = 1 / self.frameRate,
    frame = nil,
    time = 0, -- animation time
    index = 1, -- frame index
    quads = {}
  }
  setmetatable(animation, self)
  self.__index = self

  -- set initial frame
  animation:setFrame(1)
  return animation
end

function meta:newStaticSprite(name)
  local animation = self.staticCacheByName:get(name)
  if (not animation) then
    animation = self:new({ name })
    self.staticCacheByName:set(name, animation)
  end
  return animation
end

function meta:updateFrameQuad()
  local frameKey = self.aniFrames[self.index]
  self.frame = self.frameData[frameKey]

  local missingFrame = not self.frame
  if (missingFrame) then
    error('missing animation frame `'..frameKey..'`')
  end

  local pad = self.pad
  local sprite = self.quads[frameKey]
  if (not sprite) then
    sprite = love.graphics.newQuad(
      self.frame.frame.x - pad,
      self.frame.frame.y - pad,
      self.frame.sourceSize.w + (pad * 2),
      self.frame.spriteSourceSize.h + (pad * 2),
      self.atlas:getDimensions()
    )
    self.quads[frameKey] = sprite
  end
  self.sprite = sprite
  self.lastIndex = self.index
end

local max = math.max
-- sets the animation to the frame index and resets the time
function meta:setFrame(index)
  self.index = index
  self.time = self.timePerFrame * index
  self:updateFrameQuad()
  return self
end

function meta:setDuration(duration)
  self.timePerFrame = duration / self.numFrames
  return self
end

-- returns the offset positions relative to the viewport including any padding.
-- This is useful for drawing operations since the padding allows for shader effects.
function meta:getOffset()
  local pivot = self.frame.pivot
  local w,h = self:getSourceSize()
  local pad = self.pad
  -- NOTE: add padding afterwards because its not part of the sprite pivot calculation
  local ox = (pivot.x * w) + pad
  local oy = (pivot.y * h) + pad
  return ox, oy
end

-- returns the offset positions relative to the original sprite sans padding.
-- This is useful for positioning other objects relative to the sprite.
function meta:getSourceOffset()
  local pivot = self.frame.pivot
  local w,h = self:getSourceSize()
  local ox = (pivot.x * w)
  local oy = (pivot.y * h)
  return ox, oy
end

-- returns the sprite source size
-- NOTE: this is different from sprite:getViewport() which includes padding
function meta:getSourceSize()
  return
    self.frame.sourceSize.w,
    self.frame.sourceSize.h
end

function meta:getHeight()
  return self.frame.sourceSize.h
end

function meta:getWidth()
  return self.frame.sourceSize.w
end

function meta:getFullWidth()
  return self:getWidth() + (self.pad * 2)
end

function meta:getFullHeight()
  return self:getHeight() + (self.pad * 2)
end

function meta:setSize(w, h)
  local _x,_y,_w,_h = self.sprite:getViewport()
  local padding = self.pad * 2
  self.sprite:setViewport(
    _x,
    _y,
    w and (w + padding) or _w,
    h and (h + padding) or _h
  )
end

function meta:isLastFrame()
  return self.index == self.numFrames
end

function meta:draw(x, y, angle, sx, sy, ox, oy, kx, ky)
  local _ox, _oy = self:getOffset()
  ox, oy = ox or _ox, oy or _oy
  love.graphics.draw(
    self.atlas,
    self.sprite,
    x, y, angle, sx, sy, ox, oy
  )
  return self
end

-- increments the animation by the time amount
function meta:update(dt, data)
  self.time = self.time + dt

  if self.numFrames > 1 then
    self.index = math.ceil(self.time/self.timePerFrame)
    -- reset to the start
    if (self.index > self.numFrames) then
      self.index = 1
      self.time = 0
    end
    -- reset to the end
    if (self.index < 1) then
      self.time = 0
      self.index = self.numFrames
    end
  end

  local isSameFrame = self.index == self.lastIndex
  if isSameFrame then
    return self
  end

  self:updateFrameQuad()
  return self
end

function meta:reset()
  self:setFrame(1)
  return self
end

function meta:getSpriteSize(spriteName, includePadding)
  local sourceSize = self.frameData[spriteName].sourceSize
  local padding = includePadding and (self.pad * 2) or 0
  return sourceSize.w + padding, sourceSize.h + padding
end

return createAnimationFactory