def document($name):
  if length != 1 or (.[0] | type) != "object" then
    error("\($name): expected exactly one JSON object")
  else .[0] end;

def require($valid; $message):
  if $valid then . else error($message) end;

def release_version:
  if type != "string" then false
  else
    "(0|[1-9][0-9]*)" as $number
    | "(0|[1-9][0-9]*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)" as $prerelease
    | test("\\A\($number)\\.\($number)\\.\($number)(-\($prerelease)(\\.\($prerelease))*)?(\\+[0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*)?\\z")
  end;

def hex_string($length):
  if type != "string" then false
  else test("\\A[0-9a-fA-F]{\($length)}\\z") end;

($config | document("sobaya.json")) as $cfg
| ($lock | document("sobaya.lock")) as $pin
| require($cfg.config_version == 1; "sobaya.json: config_version must be 1")
| require($cfg.mode == "project" or $cfg.mode == "dependency"; "sobaya.json: mode must be project or dependency")
| require(($cfg.runtime | type) == "object"; "sobaya.json: runtime must be an object")
| require(($cfg.runtime.version | release_version); "sobaya.json: runtime.version must be an exact release version without a v prefix")
| require($pin.lock_version == 1; "sobaya.lock: lock_version must be 1")
| require(($pin.runtime | type) == "object"; "sobaya.lock: runtime must be an object")
| require($pin.runtime.version == $cfg.runtime.version; "sobaya.lock: runtime.version must match sobaya.json")
| require(($pin.runtime.commit | hex_string(40)); "sobaya.lock: runtime.commit must be a 40-digit hexadecimal commit")
| require(($pin.runtime.sha256 | hex_string(64)); "sobaya.lock: runtime.sha256 must be a 64-digit hexadecimal digest")
| {config_version: $cfg.config_version, mode: $cfg.mode, runtime: $pin.runtime}
