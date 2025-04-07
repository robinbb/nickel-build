#! /usr/bin/env -S ruby -w

drv_filename = $stdin.read

system("nix-store --realise #{drv_filename}")
exit($?.exitstatus)
