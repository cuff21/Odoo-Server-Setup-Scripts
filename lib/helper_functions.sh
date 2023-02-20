#!/bin/bash
#HELPER FUNCTIONS

####
# NAME
#   loadConfig()
# DESCRIPTION
#   Loads user configuration file, ensuring all required parameters are defined, and 
#   all undefined optionals are set to default value.
# USAGE
#   loadconfig "CONFIG_FILE_PATH"
####
loadConfig(){
  . "$1"
  #TODO: Load Defaults
}

####
# https://stackoverflow.com/a/40167919
# NAME
#   evalConfigTemplate()
# DESCRIPTION
#   Evaluates Variables within configuration templates.
#   Config variables MUST be in format ${varname}. NOTHING ELSE is expanded.
#   To treat a ${ as a literal, \-escape it; e.g.:\${HOME} 
# USAGE
#   evalConfigTemplate < /path/to/template.conf
#   evalConfigTemplate <<< 'Template string literal ${variable}'
####
evalConfigTemplate(){
  local line lineEscaped
  while IFS= read -r line || [[ -n $line ]]; do  # the `||` clause ensures that the last line is read even if it doesn't end with \n
    # Escape ALL chars. that could trigger an expansion..
    lineEscaped=$(printf %s "$line" | tr '`([$' '\1\2\3\4')

    # ... then selectively reenable ${ references
    lineEscaped=${lineEscaped//$'\4'{/\${}

    # Finally, escape embedded double quotes to preserve them.
    lineEscaped=${lineEscaped//\"/\\\"}

    eval "printf '%s\n' \"$lineEscaped\"" | tr '\1\2\3\4' '`([$'
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
      >&2 echo "Error processing template."
      return 1
    fi
  done
}
