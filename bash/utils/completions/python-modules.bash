#!/bin/bash

# Completion script for python. This script provides ability to use <Tab>
# completion when running scripts in module mode, i.e. `python -m XXX`.

_python_module_autocomplete() {
    local cur prev path base_dir completions
    COMPREPLY=()                         # Initialize completion reply array
    cur="${COMP_WORDS[COMP_CWORD]}"      # Current word being completed
    prev="${COMP_WORDS[COMP_CWORD - 1]}" # Previous word

    # Ensure we're completing for `python -m`, and only completing the third
    # word. If that's already filled, skip.
    if [[ "${COMP_WORDS[1]}" == "-m" && ${#COMP_WORDS[@]} < 4 ]]; then
        # if there is a dot in the current word, means we are looking at submodules
        if [[ "$cur" == *.* ]]; then
            # For submodule completion, derive the base directory from current input
            base_dir="${cur%.*}" # drop the last dot
            path="${base_dir//.//}" # Convert dot notation to directory path
            prefix="$base_dir." # Add dot back to the base directory, this is the prefix for completion
            cur="${cur##*.}"

            # if path is not a valid path, or can actually be turned into a python file, we are done.
            if [ ! -d "$path" ] || [ -f "${path}.py" ]; then
                return 0
            fi

        # if not, we are looking for any directory that has a python file.
        else
            # For top-level completion
            prefix="" # no prefix since it's top level
            path="."
        fi

        # Use find to get directories and Python files excluding unwanted ones
        completions=$(find "$path" -maxdepth 1 \
            \( -type d -o -type f -name '*.py' \) \
            -not -name '__pycache__' -not -name '__init__.py' -not -name '.*' -not -name "$path" \
            -exec bash -c 'if [ -d "$0" ] || [[ "$(basename "$0")" == *.py ]]; then basename "${0%.py}"; fi' {} \; | sed '/^$/d')

        # Populate the COMPREPLY array with filtered completions, ensuring no trailing space
        COMPREPLY=($(compgen -W "$completions" -P "$prefix" -- "$cur"))

        # Prevent automatic addition of space after completion
        compopt -o nospace
    else
        # Fallback to default completion if not in `python -m`
        # COMPREPLY=()
        # _filedir
        return 1
    fi

    return 0
}

# Register the function to provide completions for the `python` command.
complete -o default -F _python_module_autocomplete python
