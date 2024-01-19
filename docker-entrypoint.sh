#!/bin/bash

# ----------------------------------------------------------------------------
# lftp-mirror-action (GitHub Action)
# Copyright (c) 2022 Pressidium
# ----------------------------------------------------------------------------

# GitHub will automatically create an environment variable for each input
# formatted like: `INPUT_<VARIABLE_NAME>` (input names are converted to
# uppercase letters and any spaces are replaced with underscores)
#
# Available environment variables:
# ---
# - `INPUT_HOST` — The hostname of the SFTP server (required)
# - `INPUT_PORT` — The port of the SFTP server
# - `INPUT_USER` — The username to use for authentication (required)
# - `INPUT_PASS` — The password to use for authentication (required)
# - `INPUT_FORCESSL` — Refuse to send password in clear when server does not support SSL
# - `INPUT_VERIFYCERTIFICATE` — Verify server's certificate to be signed by a known Certificate Authority
# - `INPUT_FINGERPRINT` — The key fingerprint of the host we want to connect to
# - `INPUT_ONLYNEWER` — Only transfer files that are newer than the ones on the remote server
# - `INPUT_ONLYDIFFERENT` — Only transfer files that are different than the ones on the remote server
# - `INPUT_PARALLEL` — Number of parallel transfers
# - `INPUT_SETTINGS` — Any additional lftp settings to configure
# - `INPUT_LOCALDIR` — The local directory to copy to (assuming `reverse` is set to `true`)
# - `INPUT_REMOTEDIR` — The remote directory to copy to (assuming `reverse` is set to `true`)
# - `INPUT_REVERSE` — Whether to copy from the remote server to the local machine or the other way around
# - `INPUT_IGNOREFILE` — The name of the file containing the ignore list
# - `INPUT_OPTIONS` — Any additional `mirror` command options to configure

# Global variable to keep track of the `lftp` settings
settings=""

# Global variable to keep track of flags for the lftp `mirror` command
flags=""

###########################################################################
# Check whether the given path is an existing file.
# Arguments:
#   The path to check.
# Returns:
#   0 if the path is an existing file, 1 otherwise.
###########################################################################
file_exists () {
  if [[ -f "$1" ]]; then
    return 0
  else
    return 1
  fi
}

###########################################################################
# Trim leading and trailing whitespace from the given string.
# Arguments:
#   The string to trim.
# Outputs:
#   The trimmed string.
###########################################################################
trim_whitespace () {
  echo "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

###########################################################################
# Print the lowercase version of the input variable.
# Arguments:
#   The string to print in lowercase.
# Outputs:
#   The lowercase version of the input string.
###########################################################################
to_lower () {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

###########################################################################
# Check whether the input variable is truthy.
# Arguments:
#   The string to check.
# Returns:
#   0 if the value is truthy, 1 otherwise.
###########################################################################
is_true () {
  local value
  value=$(to_lower "$1")

  if [[ "${value}" = "true" ]] || [[ "${value}" = "yes" ]] || [[ "${value}" = "1" ]]; then
    return 0
  else
    return 1
  fi
}

###########################################################################
# Append the given flag to `${flags}`.
# Globals:
#   flags
# Arguments:
#   The flag to append.
###########################################################################
append_flag () {
  local flag="$1"

  if [[ "${flag}" =~ ^-- ]]; then
    flags="${flags} ${flag}"
  else
    flags="${flags} --${flag}"
  fi
}

###########################################################################
# Append the given flag to `${flags}` if its value is truthy.
# Arguments:
#   The name of the flag to append.
#   The value of the flag.
###########################################################################
eval_flag () {
  local flag_name="$1"
  local flag_value="$2"

  if is_true "${flag_value}"; then
    append_flag "${flag_name}"
  fi
}

###########################################################################
# Print 'yes' or 'no' depending on whether the input variable is truthy.
# Arguments:
#   The string to check.
# Outputs:
#   'yes' if the input variable is truthy, 'no' otherwise.
###########################################################################
print_yes_no_opt () {
  if is_true "$1"; then
    echo "yes"
  else
    echo "no"
  fi
}

###########################################################################
# Append the given setting to `${settings}`.
# Globals:
#   settings
# Arguments:
#   The setting to append.
###########################################################################
handle_setting () {
  local setting="$1"

  local setting_name
  local setting_value

  setting_name=$(echo "${setting}" | cut -d '=' -f 1)
  setting_value=$(print_yes_no_opt "$(echo "${setting}" | cut -d '=' -f 2)")

  settings="${settings} set ${setting_name} ${setting_value};"
}

###########################################################################
# Check whether all required environment variables are set.
# Globals:
#   INPUT_HOST
#   INPUT_USER
#   INPUT_PASS
###########################################################################
check_required_envs () {
  local required_envs
  required_envs=(
    INPUT_HOST
    INPUT_USER
    INPUT_PASS
  )

  for env in "${required_envs[@]}"; do
    if [[ -z "${!env}" ]]; then
      echo "Error: ${env} is not set"
      exit 1
    fi
  done
}

###########################################################################
# Split the given string into an array using the given delimiter.
# Arguments:
#   The string to split.
#   The delimiter to use.
# Outputs:
#   The array.
###########################################################################
split_string () {
  local string="$1"
  local delimiter="$2"

  local IFS="${delimiter}"
  read -ra parts <<< "${string}"
  echo "${parts[@]}"
}

###########################################################################
# Check whether the given string represents a valid (positive) integer.
# Arguments:
#   The string to check.
# Returns:
#   0 if the string represents a valid integer (>= 0), 1 otherwise.
###########################################################################
string_represents_an_integer() {
  local string="$1"

  if [[ "${string}" =~ ^[0-9]+$ ]]; then
    return 0
  else
    return 1
  fi
}

###########################################################################
# Print the command we're about to run, and run it.
# Arguments:
#   The command to run.
# Outputs:
#   The command to run.
###########################################################################
debug_run_cmd () {
  # Automatically revert any changes to shell
  # options when the function returns
  local -

  set -o xtrace

  "$@"
}

# Check whether all required environment variables are set
check_required_envs

# Set a variable for files to exclude
excluded_files=""

if [[ -n "${INPUT_IGNOREFILE}" ]] && file_exists "${INPUT_IGNOREFILE}"; then
  excluded_files=$(< "${INPUT_IGNOREFILE}" grep -v '^#' | grep -v '^$' | sed 's/^/-X /' | tr '\n' ' ')
fi

# Make sure the `/root/.ssh` directory exists and is writable
mkdir -p /root/.ssh && chmod 0700 /root/.ssh

if [[ -n "${INPUT_FINGERPRINT}" ]]; then
  # If a fingerprint is set, we add it to the `known_hosts` file
  echo "Adding fingerprint to the known_hosts file"
  echo "${INPUT_HOST} ${INPUT_FINGERPRINT}" >> /root/.ssh/known_hosts
else
  # If a fingerprint is not set, we automatically add the host to the `known_hosts` file
  echo "Adding host to the known_hosts file"
  ssh-keyscan -H -p "${INPUT_PORT}" "${INPUT_HOST}" >> /root/.ssh/known_hosts
fi

# Iterate over settings
if [[ -n "${INPUT_SETTINGS}" ]]; then
  for setting in $(split_string "${INPUT_SETTINGS}" ","); do
    handle_setting "$(trim_whitespace "${setting}")"
  done
fi

# Handle settings with explicit parameters
handle_setting "ftp:ssl-force=${INPUT_FORCESSL}"
handle_setting "ssl:verify-certificate=${INPUT_VERIFYCERTIFICATE}"

# Trim leading and trailing whitespace from the settings
settings=$(trim_whitespace "${settings}")

# Iterate over options and append any flags for the ltp `mirror` command
if [[ -n "${INPUT_OPTIONS}" ]]; then
  for option in ${INPUT_OPTIONS}; do
    append_flag "${option}"
  done
fi

# Evaluate flags for the mirror command
eval_flag "reverse" "${INPUT_REVERSE}"
eval_flag "only-newer" "${INPUT_ONLYNEWER}"

# Evaluate the parallel input
if string_represents_an_integer "${INPUT_PARALLEL}" && [[ "${INPUT_PARALLEL}" -gt 1 ]]; then
  append_flag "parallel=${INPUT_PARALLEL}"
else
  echo "Ignoring invalid value for the 'parallel' input: ${INPUT_PARALLEL}"
fi

# Restore timestamps if the `onlyNewer` or `onlyDifferent` input flag is set
if is_true "${INPUT_ONLYNEWER}" || is_true "${INPUT_ONLYDIFFERENT}"; then
  echo "Restoring the original modification time of files based on the date of the most recent commit..."

  # Disable Git ownership check
  git config --global --add safe.directory '*'

  # Run `git-restore-mtime`
  /usr/bin/python3 /usr/local/bin/git-restore-mtime --verbose
fi

# Transfer files via SFTP
debug_run_cmd lftp -u "${INPUT_USER},${INPUT_PASS}" -p "${INPUT_PORT}" "sftp://${INPUT_HOST}" \
     -e "${settings} \
     mirror ${excluded_files} \
     ${flags} ${INPUT_LOCALDIR} ${INPUT_REMOTEDIR}; \
     bye"
