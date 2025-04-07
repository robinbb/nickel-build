#! /usr/bin/env -S ruby -w

# Transforms JSON input into a Nix derivation (.drv file) in the Nix store.

require "json"
require "open3"

def check_for(struct, key_name, value_kind)
  unless struct.is_a?(Hash)
    raise "'check_for' only works on Hashes"
  end
  unless struct.has_key?(key_name)
    raise "Missing \"#{key_name}\" entry."
  end
  unless struct[key_name].is_a?(value_kind)
    raise "#{key_name} has the wrong value kind."
  end
end

def validate(d)
  # d is the derivation JSON
  check_for(d, "name", String)
  check_for(d, "outputs", Hash)
  check_for(d, "inputSrcs", Array)
  check_for(d, "inputDrvs", Hash)
  check_for(d, "system", String)
  check_for(d, "builder", String)
  check_for(d, "args", Array)
  check_for(d, "env", Hash)

  # Each entry in the "outputs" must be an object.
  # That object must have a "path" key that is an empty string.
  # Each of the entries must not have a similarly named entry
  # in "env", because we are going to add that.
  outputs = d["outputs"]
  outputs.each_key do |output|
    if d["env"].has_key?(output)
      raise "The derivation's \"env\" key must not have an output key (\"#{output}\")."
    end
    check_for(outputs[output], "path", String)
    path = outputs[output]["path"]
    if path.empty?
      outputs[output]["path"] = "/nix/store/00000000000000000000000000000000-fakepath"
    else
      raise "The derivation's 'output' key has an output ('#{output}') with a 'path' key that is not an empty string."
    end
  end
end

def add_outputs_to_env!(d)
  env = d["env"]
  outputs = d["outputs"]
  outputs.each_key do |output|
    env[output] = outputs[output]["path"]
  end
end

def json_out(json)
  JSON.pretty_generate(json)
end

def update_store_paths!(d, drv)
  outputs = d["outputs"]
  env = d["env"]
  outputs.each_key do |output|
    outputs[output]["path"] = drv
    env[output] = drv
  end
end

def transform(derivation)
  validate(derivation)
  add_outputs_to_env!(derivation)

  # Attempt to add the derivation to the Nix store in order to obtain an error
  # message that tells the correct output path.
  #
  _stdout, stderr, _status = Open3.capture3("nix derivation add", stdin_data: json_out(derivation))
  drv_output = stderr[/should be '([^']+)'/, 1]
  update_store_paths!(derivation, drv_output)
end

def add_to_store(derivation)
  stdout, _stderr, _status = Open3.capture3("nix derivation add", stdin_data: json_out(derivation))
  stdout
end

begin
  derivation = JSON.parse($stdin.read)
  transform(derivation)
  store_drv = add_to_store(derivation)
  puts store_drv
rescue JSON::ParserError => e
  warn "Error parsing JSON: #{e.message}"
rescue => e
  warn "Unexpected error: #{e.message}"
end
