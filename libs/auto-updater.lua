--[[

Copyright 2014-2015 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local request = require('coro-http').request
local semver = require('semver')
local jsonParse = require('json').parse
local log = require('log').log
local prompt = require('prompt')(require('pretty-print'))
local core = require('core')()
local uv = require('uv')

function exports.matchVersions(name, version)
  local head, body = request("GET", "http://lit.luvit.io/packages/" .. name)
  assert(head.code == 200)
  local versions = assert(jsonParse(body), "Problem parsing JSON response from lit")
  local key
  return semver.match(version, function ()
    local n = next(versions, key)
    key = n
    return key
  end)
end

-- Feed auto-updater your package.lua pre-parsed as a lua table
function exports.check(meta, target)
  local name = meta.name
  local basename = name:match("[^/]+$")
  local version = meta.version
  local toupdate, action
  local new, old
  if version then
    version = semver.normalize(version)
    toupdate = exports.matchVersions(name, version)
    if not target then
      return toupdate
    end
    if not toupdate then
      log(basename .. " is newer than remote", meta.version, "err")
      return
    end
    if toupdate == meta.version then
      log(basename .. " is up to date", meta.version, "highlight")
      return
    end
    local res = prompt("Are you sure you wish to update " .. target .. " to " .. name .. " version " .. toupdate .. "?", "Y/n")
    if not res:match("[yY]") then
      log("canceled " .. basename .. " update", meta.version, "err")
      return
    end
    action = "update"
    new = target .. ".new"
    old = target .. ".old"
  else
    toupdate = exports.matchVersions(name)
    action = "install"
    new = target
    old = nil
  end

  core.makeUrl("lit://" .. meta.name .. "@" .. toupdate, new)
  log(action .. "ing " .. basename .. " binary", target, "highlight")
  if old then
    uv.fs_rename(target, old)
    uv.fs_rename(new, target)
    uv.fs_unlink(old)
  end
  log(basename .. " " .. action .. " complete", toupdate, "success")

end
