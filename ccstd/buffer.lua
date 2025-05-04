---@class Size
---@field width number
---@field height number

---@class Vector
---@field x number
---@field y number

---Buffer for terminal output. Can be used to prevent display flickering or
---multiple uses of same output.
---@class Buffer
---@field private _size Size
---@field private _charMat table<number, string[]>
---@field private _fgMat table<number, string[]>
---@field private _bgMat table<number, string[]>
---@field private _cursorPos Vector
---@field private _cursorColors {bg:string, fg: string}
local Buffer = {}
Buffer.__index = Buffer

---@param width number
---@param height number
---@return Buffer
function Buffer.new(width, height)
  local self = {}
  self._size = {
    width = width,
    height = height,
  }
  self._cursorPos = {x = 1, y = 1,}
  self._cursorColors = {
    bg = colors.toBlit(colors.black),
    fg = colors.toBlit(colors.white),
  }
  Buffer.clear(self)
  return setmetatable(self, Buffer)
end


---Clear entire buffer. Uses current background and foreground colors.
function Buffer:clear()
  self._charMat = {}
  self._bgMat = {}
  self._fgMat = {}
  for y = 1, self._size.height do
    self._charMat[y] = {}
    self._fgMat[y] = {}
    self._bgMat[y] = {}
    for x = 1, self._size.width do
      self._charMat[y][x] = ' '
      self._fgMat[y][x] = self._cursorColors.fg
      self._bgMat[y][x] = self._cursorColors.bg
    end
  end
end


---Clear current line. Uses current background and foreground colors.
function Buffer:clearLine()
  local y = self._cursorPos.y
  for x = 1, self._size.width do
    self._charMat[y][x] = ' '
    self._fgMat[y][x] = self._cursorColors.fg
    self._bgMat[y][x] = self._cursorColors.bg
  end
end


---Return size of the buffer
---@return number width
---@return number height
function Buffer:getSize()
  return self._size.width, self._size.height
end


---Get current cursor position
---@return number x
---@return number y
function Buffer:getCursorPos()
  return self._cursorPos.x, self._cursorPos.y
end


---Set cursor position
---@param x number
---@param y number
function Buffer:setCursorPos(x, y)
  self._cursorPos.x = x
  self._cursorPos.y = y
end


---Get background color
---@return ccTweaked.colors.color
function Buffer:getBackgroundColor()
  return colors.fromBlit(self._cursorColors.bg)
end


---Set background color
---@param color ccTweaked.colors.color
function Buffer:setBackgroundColor(color)
  self._cursorColors.bg = colors.toBlit(color)
end


---Get foreground color
---@return ccTweaked.colors.color
function Buffer:getForegroundColor()
  return colors.fromBlit(self._cursorColors.fg)
end


---Set foreground color
---@param color ccTweaked.colors.color
function Buffer:setForegroundColor(color)
  self._cursorColors.fg = colors.toBlit(color)
end


---Write text to buffer. Uses current background and foreground colors.
---@param text string
function Buffer:write(text)
  local _, y = self:getCursorPos()
  if y > self._size.height or y < 1 then
    return
  end
  for char in string.gmatch(text, '.') do
    local x, y = self:getCursorPos()
    if self._cursorPos.x > self._size.width then
      return
    elseif self._cursorPos.x < 1 then
      goto continue
    end
    self._charMat[y][x] = char
    self._bgMat[y][x] = self._cursorColors.bg
    self._fgMat[y][x] = self._cursorColors.fg
    ::continue::
    self:setCursorPos(x+1, y)
  end
end


---Get character with it's color
---@param x number
---@param y number
---@return string
---@return ccTweaked.colors.color
---@return ccTweaked.colors.color
function Buffer:getChar(x, y)
  return self._charMat[y][x], colors.fromBlit(self._fgMat[y][x]),
    colors.fromBlit(self._bgMat[y][x])
end


---Merge other buffer into current. Begins from (x, y) if specified.
---@param buffer Buffer
---@param x? number
---@param y? number
function Buffer:merge(buffer, x, y)
  x = x or 1
  y = y or 1
  local bx, by = buffer:getSize()
  for dy = 1, math.min(by, self._size.height-y+1) do
    for dx = 1, math.min(bx, self._size.width-x+1) do
      local char, fg, bg = buffer:getChar(dx, dy)
      local rx = x+dx-1
      local ry = y+dy-1
      self._charMat[ry][rx] = char
      self._fgMat[ry][rx] = colors.toBlit(fg)
      self._bgMat[ry][rx] = colors.toBlit(bg)
    end
  end
end


---Print buffer to redirect. Begins from (x, y) if specified.
---@param redirect ccTweaked.term.Redirect
---@param x? number
---@param y? number
function Buffer:print(redirect, x, y)
  x = x or 1
  y = y or 1
  for dy = 1, self._size.height do
    local line = table.concat(self._charMat[dy])
    local bg = table.concat(self._bgMat[dy])
    local fg = table.concat(self._fgMat[dy])
    redirect.setCursorPos(x, y+dy-1)
    redirect.blit(line, fg, bg)
  end
end


return Buffer
