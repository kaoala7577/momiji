local lib
lib = require("./wand/lib").lib
lib.MagickWandGenesis()
local Image
Image = require("./wand/image").Image
local make_thumb
make_thumb = require("thumb").make_thumb
local load_image
do
  local _base_0 = Image
  local _fn_0 = _base_0.load
  load_image = function(...)
    return _fn_0(_base_0, ...)
  end
end
return {
  VERSION = require("version"),
  mode = "image_magick",
  Image = Image,
  load_image = load_image,
  thumb = make_thumb(load_image),
  load_image_from_blob = (function()
    local _base_0 = Image
    local _fn_0 = _base_0.load_from_blob
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)()
}
