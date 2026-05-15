#!/usr/bin/env bats

@test "install.sh prints help" {
  run bash ./install.sh --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./install.sh"* ]]
  [[ "$output" == *"--variant"* ]]
  [[ "$output" == *"--hotend"* ]]
}

@test "install.sh requires --hotend in non-interactive mode" {
  run bash -c 'bash ./install.sh --variant x400_300 </dev/null'
  [ "$status" -ne 0 ]
  [[ "$output" == *"--hotend is required in non-interactive mode"* ]]
}

@test "install.sh rejects invalid --hotend value" {
  run bash ./install.sh --variant x400_300 --hotend 999
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid --hotend value"* ]]
}
