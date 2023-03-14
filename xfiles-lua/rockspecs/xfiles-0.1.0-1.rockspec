package = "xfiles"
version = "0.1.0-1"
source = {
  url = ""
}

description = {
  summary = "",
  detailed = "",
  homepage = "",
  license  = "",
}

dependencies = {
  "lua >= 5.4",
  "luaposix >= 35.0",
  "luafilesystem >= 1.8.0",
}

build = {
  type = "builtin",
  modules = {
    ["xfiles"] = "xfiles.lua",
  }
}
