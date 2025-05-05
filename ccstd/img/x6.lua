local Buffer = require('ccstd.buffer')
local Bin = require('ccstd.bin')

---@class X6Block
---@field bitMask integer
---@field color? {fg: integer, bg: integer}

---@class X6Options
---@field colored? boolean

---@class X6
---For file format read `ccstd/img/x6Format.md`
---@field charSize Size
---@field size Size
---@field blocks X6Block[] indexed in range [1; charWidth*charHeight]
---@field options X6Options
local X6 = {}
X6.__index = X6

---Create empty image
---@param charWidth number
---@param charHeight number
---@param options? X6Options
---@return X6
function X6.new(charWidth, charHeight, options)
  local self = {}
  self.charSize = {
    width = charWidth,
    height = charHeight,
  }
  self.size = {
    width = charWidth*2,
    height = charHeight*3,
  }
  options = options or {}
  self.options = {
    colored = options.colored
  }
  self.blocks = {}
  for i = 1, charWidth*charHeight do
    self.blocks[i] = {
      bitMask = 0x00
    }
    if options.colored then
      self.blocks[i].color = {
        fg = 0,
        bg = 15,
      }
    end
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
  local bitFlags = bin:readWord()
  if bitFlags > 0x0001 then
    error('image contains unsupported flags')
  end
  local width = bin:readWord()
  local height = bin:readWord()
  local self = X6.new(width, height)
  if bit32.band(bitFlags, 0x0001) ~= 0 then
    self.options.colored = true
  end
  local expectedLenght = 8+width*height
  if self.options.colored then
    expectedLenght = expectedLenght+width*height
  end
  if #str < expectedLenght then
    error('wrong size of x6 image')
  end

  for i = 1, width*height do
    self.blocks[i] = {
      bitMask = bin:readByte()
    }
  end
  for i = 1, width*height do
    local fgbg = bin:readByte()
    self.blocks[i].color = {
      fg = bit32.rshift(fgbg, 4),
      bg = bit32.band(fgbg, 0x0F),
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


---Set background of block.
---@param xChar integer
---@param yChar integer
---@param bg integer
function X6:setBackground(xChar, yChar, bg)
  if not self.options.colored then
    error('not a colored image', 2)
  elseif xChar < 1 or xChar > self.charSize.width
    or yChar < 1 or yChar > self.charSize.height
  then
    error('out of image', 2)
  end
  local blockInd = (yChar-1)*self.charSize.width+xChar
  self.blocks[blockInd].color.bg = bg
end


---Set foreground of block.
---@param xChar integer
---@param yChar integer
---@param fg integer
function X6:setForeground(xChar, yChar, fg)
  if not self.options.colored then
    error('not a colored image', 2)
  elseif xChar < 1 or xChar > self.charSize.width
    or yChar < 1 or yChar > self.charSize.height
  then
    error('out of image', 2)
  end
  local blockInd = (yChar-1)*self.charSize.width+xChar
  self.blocks[blockInd].color.fg = fg
end


local indToColor = {
  [0] = colors.white,
  colors.orange,
  colors.magenta,
  colors.lightBlue,
  colors.yellow,
  colors.lime,
  colors.pink,
  colors.gray,
  colors.lightGray,
  colors.cyan,
  colors.purple,
  colors.blue,
  colors.brown,
  colors.green,
  colors.red,
  colors.black,
}

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
      bitMask = bit32.band(bitMask, 63) -- to ignore highest two bits
      if self.options.colored then
        fg = self.blocks[ind].color.fg
        fg = indToColor[fg]
        bg = self.blocks[ind].color.bg
        bg = indToColor[bg]
      end
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
  local flag2, flag1 = 0, 0
  if self.options.colored then
    flag1 = bit32.bor(flag1, 0x01)
  end
  parts[2] = string.char(flag2, flag1)
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
  for i, block in ipairs(self.blocks) do
    parts[#parts+1] = string.char(block.bitMask)
  end
  if self.options.colored then
    for i, block in ipairs(self.blocks) do
      parts[#parts+1] = string.char(
        bit32.lshift(block.color.fg, 4)+block.color.bg
      )
    end
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
