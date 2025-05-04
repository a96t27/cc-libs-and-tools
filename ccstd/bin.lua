---@class Bin
---Simple class for reading binary data
---@field private _source number[]
---@field private _offset number
---@field private _isBigEndian? boolean
local Bin = {}
Bin.__index = Bin

---@param text string
---@param isBigEndian? boolean
---@return Bin
function Bin.new(text, isBigEndian)
  local self = {}
  self._source = {string.byte(text, 1, #text)}
  self._offset = 0
  self._isBigEndian = isBigEndian
  return setmetatable(self, Bin)
end


---Is at end
---@return boolean
function Bin:isAtEnd()
  return self._offset >= #self._source
end


---Set current offset
---@param offset number
function Bin:setOffset(offset)
  self._offset = offset
end


---Get current position
---@return number
function Bin:getOffset()
  return self._offset
end


---Read one byte
---@return integer
function Bin:readByte()
  if self:isAtEnd() then
    error('no bytes left', 2)
  end
  self._offset = self._offset+1
  local byte = self._source[self._offset]
  return byte
end


---Read one word (two bytes)
---@return integer
function Bin:readWord()
  if #self._source < self._offset+2 then
    error('no words left', 2)
  end
  local byte1 = self:readByte()
  local byte2 = self:readByte()
  if self._isBigEndian then
    return bit32.bor(bit32.lshift(byte1, 8), byte2)
  end
  return bit32.bor(bit32.lshift(byte2, 8), byte1)
end


---Read one dword (four bytes)
---@return integer
function Bin:readDword()
  if #self._source < self._offset+4 then
    error('no dwords left', 2)
  end
  local word1 = self:readWord()
  local word2 = self:readWord()
  if self._isBigEndian then
    return bit32.bor(bit32.lshift(word1, 16), word2)
  end
  return bit32.bor(bit32.lshift(word2, 16), word1)
end


return Bin
