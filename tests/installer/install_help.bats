#!/usr/bin/env bats

@test "install.sh prints help" {
  run bash ./install.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./install.sh"* ]]
  [[ "$output" == *"--variant"* ]]
}
