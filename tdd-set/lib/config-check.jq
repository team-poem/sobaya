def document($name):
  if length != 1 or (.[0] | type) != "object" then
    error("\($name): expected exactly one JSON object")
  else .[0] end;

($config | document("sobaya.json")) as $cfg
| ($lock | document("sobaya.lock")) as $pin
| {config_version: $cfg.config_version, mode: $cfg.mode, runtime: $pin.runtime}
