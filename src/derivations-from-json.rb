#! /usr/bin/env -S ruby -w
#
# Transforms a JSON file with the proper structure into a Nix derivation (.drv
# file) in the Nix store.

require "json"

json_file = ARGV[0]

def check_for(struct, key_name, value_kind)
  unless struct.is_a?(Hash)
    raise "check_for only works on Hashes"
  end
  unless struct.has_key?(key_name)
    raise "The derivation must have a \"#{key_name}\" entry."
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
  end
end

def add_outputs_to_env!(d)
  env = d["env"]
  outputs = d["outputs"]
  outputs.each_key do |output|
    env[output] = outputs[output]["path"]
  end
end

def transform(derivation)
  validate(derivation)
  puts "Transforming #{derivation}"
  add_outputs_to_env!(derivation)
  puts "Transformed derivation:\n#{derivation}"
end

begin
  json_data = JSON.parse(File.read(json_file))
  puts "Successfully parsed JSON data from #{json_file}"
  transform(json_data)
rescue Errno::ENOENT
  puts "Error: File #{json_file} doesn't exist"
rescue JSON::ParserError
  puts "Error: Invalid JSON format in #{json_file}."
rescue => e
  puts "Unexpected error: #{e.message}"
end
