# Live timings for each major interactive-shell startup step.
# Disable for one shell with: ZSH_STARTUP_TIMINGS=0 zsh

typeset -gi __ZSH_STARTUP_ACTIVE=0
typeset -gF 6 __ZSH_STARTUP_STARTED=0
typeset -gF 6 __ZSH_STARTUP_STEP_STARTED=0
typeset -g __ZSH_STARTUP_STEP_LABEL=''
typeset -g __ZSH_STARTUP_CLEAR=$'\r\e[2K'
typeset -g __ZSH_STARTUP_RESET=$'\e[0m'
typeset -g __ZSH_STARTUP_BOLD=$'\e[1m'
typeset -g __ZSH_STARTUP_DIM=$'\e[2m'
typeset -g __ZSH_STARTUP_GREEN=$'\e[32m'
typeset -g __ZSH_STARTUP_YELLOW=$'\e[33m'
typeset -g __ZSH_STARTUP_RED=$'\e[31m'

if [[ -o interactive && -t 1 && "${ZSH_STARTUP_TIMINGS:-1}" != "0" ]]; then
	zmodload zsh/datetime
	__ZSH_STARTUP_ACTIVE=1
	__ZSH_STARTUP_STARTED=$EPOCHREALTIME

	if [[ -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" ]]; then
		__ZSH_STARTUP_CLEAR=$'\r'
		__ZSH_STARTUP_RESET=''
		__ZSH_STARTUP_BOLD=''
		__ZSH_STARTUP_DIM=''
		__ZSH_STARTUP_GREEN=''
		__ZSH_STARTUP_YELLOW=''
		__ZSH_STARTUP_RED=''
	fi

	printf '%s╭─%s %szsh startup%s\n' \
		"$__ZSH_STARTUP_DIM" "$__ZSH_STARTUP_RESET" \
		"$__ZSH_STARTUP_BOLD" "$__ZSH_STARTUP_RESET"
fi

__zsh_startup_duration() {
	local -F 3 elapsed_seconds="$1"

	if ((elapsed_seconds >= 1.0)); then
		printf '%.2f s' "$elapsed_seconds"
	else
		printf '%.0f ms' "$((elapsed_seconds * 1000.0))"
	fi
}

__zsh_startup_begin() {
	((__ZSH_STARTUP_ACTIVE)) || return 0

	__ZSH_STARTUP_STEP_LABEL="$1"
	__ZSH_STARTUP_STEP_STARTED=$EPOCHREALTIME
	printf '%s│%s  %s…%s %s' \
		"$__ZSH_STARTUP_DIM" "$__ZSH_STARTUP_RESET" \
		"$__ZSH_STARTUP_YELLOW" "$__ZSH_STARTUP_RESET" \
		"$__ZSH_STARTUP_STEP_LABEL"
}

__zsh_startup_end() {
	((__ZSH_STARTUP_ACTIVE)) || return 0

	local -F 6 elapsed_seconds=$((EPOCHREALTIME - __ZSH_STARTUP_STEP_STARTED))
	local duration timer_colour
	duration="$(__zsh_startup_duration "$elapsed_seconds")"

	if ((elapsed_seconds >= 1.0)); then
		timer_colour="$__ZSH_STARTUP_RED"
	elif ((elapsed_seconds >= 0.25)); then
		timer_colour="$__ZSH_STARTUP_YELLOW"
	else
		timer_colour="$__ZSH_STARTUP_DIM"
	fi

	printf '%s%s│%s  %s✓%s %-22s %s%9s%s\n' \
		"$__ZSH_STARTUP_CLEAR" "$__ZSH_STARTUP_DIM" "$__ZSH_STARTUP_RESET" \
		"$__ZSH_STARTUP_GREEN" "$__ZSH_STARTUP_RESET" \
		"$__ZSH_STARTUP_STEP_LABEL" "$timer_colour" "$duration" \
		"$__ZSH_STARTUP_RESET"
}

__zsh_startup_finish() {
	if ((__ZSH_STARTUP_ACTIVE)); then
		local -F 6 elapsed_seconds=$((EPOCHREALTIME - __ZSH_STARTUP_STARTED))
		local duration timer_colour
		duration="$(__zsh_startup_duration "$elapsed_seconds")"

		if ((elapsed_seconds >= 1.0)); then
			timer_colour="$__ZSH_STARTUP_RED"
		elif ((elapsed_seconds >= 0.25)); then
			timer_colour="$__ZSH_STARTUP_YELLOW"
		else
			timer_colour="$__ZSH_STARTUP_DIM"
		fi

		printf '%s╰─%s %s%-24s%s %s%9s%s\n' \
			"$__ZSH_STARTUP_DIM" "$__ZSH_STARTUP_RESET" \
			"$__ZSH_STARTUP_BOLD" "ready" "$__ZSH_STARTUP_RESET" \
			"$timer_colour" "$duration" "$__ZSH_STARTUP_RESET"
	fi

	unset __ZSH_STARTUP_ACTIVE __ZSH_STARTUP_STARTED \
		__ZSH_STARTUP_STEP_STARTED __ZSH_STARTUP_STEP_LABEL \
		__ZSH_STARTUP_CLEAR __ZSH_STARTUP_RESET __ZSH_STARTUP_BOLD \
		__ZSH_STARTUP_DIM __ZSH_STARTUP_GREEN __ZSH_STARTUP_YELLOW \
		__ZSH_STARTUP_RED
	unfunction __zsh_startup_duration __zsh_startup_begin \
		__zsh_startup_end __zsh_startup_finish
}
