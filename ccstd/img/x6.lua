local Buffer = require('ccstd.buffer')
local Bin = require('ccstd.bin')

---@class X6Block
---@field bitMask integer

---@class X6
---For file format read `ccstd/img/x6Format.md`
---@field charSize Size
---@field size Size
---@field blocks X6Block[] indexed in range [1; charWidth*charHeight]
local X6 = {}
X6.__index = X6

---Create empty image
---@param charWidth number
---@param charHeight number
---@return X6
function X6.new(charWidth, charHeight)
  local self = {}
  self.charSize = {
    width = charWidth,
    height = charHeight,
  }
  self.size = {
    width = charWidth*2,
    height = charHeight*3,
  }
  self.blocks = {}
  for i = 1, charWidth*charHeight do
    self.blocks[i] = {
      bitMask = 0x00
    }
  end
  return setmetatable(self, X6)
end


---Create x6 image object from string
---@param str string
---@return X6
function X6.fromString(str)
  if #str < 8 then
    error('not an x6 image')
  end
  local bin = Bin.new(str, true)
  if bin:readByte() ~= string.byte('x')
    or bin:readByte() ~= string.byte('6')
  then
    error('not an x6 image', 2)
  end
  if bin:readWord() ~= 0 then
    error('image contains unsupported flags')
  end
  local width = bin:readWord()
  local height = bin:readWord()
  if #str < 8+width*height then
    error('wrong size of x6 image')
  end
  local self = X6.new(width, height)
  for i = 1, width*height do
    self.blocks[i] = {
      bitMask = bin:readByte()
    }
  end
  return self
end


function X6.fromFile(path)
  if not fs.exists(path) or fs.isDir(path) then
    error('not a file', 2)
  end
  ---@type ccTweaked.fs.ReadHandle
  ---@diagnostic disable-next-line: assign-type-mismatch
  local file = fs.open(path, 'r')
  local str = file.readAll()
  if not str then
    error('empty file', 2)
  end
  local ok, result = pcall(X6.fromString, str)
  if not ok then
    error(result, 2)
  end
  return result
end


---Draw pixel
---@param x integer
---@param y integer
---@param value boolean
function X6:draw(x, y, value)
  if x < 1 or x > self.size.width or y < 1 or y > self.size.height then
    error('out of image', 2)
  end
  if type(value) ~= 'boolean' then
    error('value must be boolean', 2)
  end
  -- x 3  y 1
  local xChar = math.ceil(x/2)                         -- 2
  local yChar = math.ceil(y/3)                         -- 1
  local blockInd = (yChar-1)*self.charSize.width+xChar -- 2
  local block = self.blocks[blockInd]
  local pixOffset = ((y-1)%3)*2+
    (x-1)%
    2 -- ((1-1)%3)*3+(x-1)%2 = 0 + 0
  local pixMask = bit32.lshift(1, pixOffset)
  if value then
    block.bitMask = bit32.bor(block.bitMask, pixMask)
  else
    pixMask = bit32.bnot(pixMask)
    block.bitMask = bit32.band(block.bitMask, pixMask)
  end
end


---@param fg ccTweaked.colors.color
---@param bg ccTweaked.colors.color
---@return Buffer
function X6:toBuffer(fg, bg)
  local buffer = Buffer.new(self.charSize.width,
    self.charSize.height)
  for y = 1, self.charSize.height do
    buffer:setCursorPos(1, y)
    for x = 1, self.charSize.width do
      local ind = (y-1)*self.charSize.width+x
      local bitMask = self.blocks[ind].bitMask
      -- bitMask = bit32.band(bitMask, 63) -- to ignore highest two bits
      if bitMask < 32 then
        buffer:setBackgroundColor(bg)
        buffer:setForegroundColor(fg)
        buffer:write(string.char(0x80+bitMask))
      else
        buffer:setBackgroundColor(fg)
        buffer:setForegroundColor(bg)
        buffer:write(string.char(0x9F-(bitMask-32)))
      end
    end
  end
  return buffer
end


---Convert object to X6 string
function X6:toString()
  local parts = {}
  --Magic numbers
  parts[1] = 'x6'
  --bit flags
  parts[2] = string.char(0, 0)
  --width
  parts[3] = string.char(
    bit32.rshift(bit32.band(self.charSize.width, 0xFF00), 8)
  )
  parts[4] = string.char(
    bit32.band(self.charSize.width, 0x00FF)
  )
  --height
  parts[5] = string.char(
    bit32.rshift(bit32.band(self.charSize.height, 0xFF00), 8)
  )
  parts[6] = string.char(
    bit32.band(self.charSize.height, 0x00FF)
  )
  for _, block in ipairs(self.blocks) do
    parts[#parts+1] = string.char(block.bitMask)
  end
  return table.concat(parts)
end


function X6:writeToFile(path)
  local str = self:toString()
  ---@type ccTweaked.fs.WriteHandle
  ---@diagnostic disable-next-line: assign-type-mismatch
  local file = fs.open(path, 'w')
  file.write(str)
  file.close()
end


return X6
