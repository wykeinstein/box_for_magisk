#!/bin/sh
# Install or remove cron entries for proxy-mode whitelist time control.

[ -r /lib/functions.sh ] && . /lib/functions.sh

BOX_MODE="proxy"
TIME_CONTROL_ENABLED="0"
TIME_CONTROL_DISABLE_CRON="*/5 8-17 * * *"
TIME_CONTROL_RESTORE_CRON="0 18 * * *"
LAN_WHITELIST_SET="box_lan_whitelist"
RESTORE_SCRIPT="/etc/box/restore_box_lan_whitelist.sh"
TAG="box whitelist time-control"

config_load box 2>/dev/null
config_get BOX_MODE main mode "proxy"
config_get_bool TIME_CONTROL_ENABLED main time_control_enabled 0
config_get TIME_CONTROL_DISABLE_CRON main time_control_disable_cron "*/5 8-17 * * *"
config_get TIME_CONTROL_RESTORE_CRON main time_control_restore_cron "0 18 * * *"
config_get LAN_WHITELIST_SET main lan_whitelist_set "box_lan_whitelist"

apply_crontab() {
	if [ -n "$1" ]; then
		printf '%s\n' "$1" | crontab -
	else
		crontab -r 2>/dev/null || true
	fi
}

current="$(crontab -l 2>/dev/null | sed '/# box whitelist time-control$/d')"

if [ "$BOX_MODE" = "proxy" ] && [ "$TIME_CONTROL_ENABLED" = "1" ]; then
	new="$(printf '%s\n%s ipset flush %s # %s\n%s %s # %s\n' \
		"$current" \
		"$TIME_CONTROL_DISABLE_CRON" "$LAN_WHITELIST_SET" "$TAG" \
		"$TIME_CONTROL_RESTORE_CRON" "$RESTORE_SCRIPT" "$TAG" | sed '/^$/d')"
else
	new="$(printf '%s\n' "$current" | sed '/^$/d')"
fi

apply_crontab "$new"
/etc/init.d/cron restart 2>/dev/null || true
