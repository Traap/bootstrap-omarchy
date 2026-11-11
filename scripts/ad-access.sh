# Shared by AD integration and its repair step. Sourced under strict mode.
require_cmd ip resolvectl python3
ACTIVE_IFACE=$(active_interface "$AD_DNS1")
[[ -n $ACTIVE_IFACE ]] || { log_fail 'No active network interface found.'; return 1; }
sudo resolvectl dns "$ACTIVE_IFACE" "$AD_DNS1" "$AD_DNS2"
sudo resolvectl domain "$ACTIVE_IFACE" "$AD_DOMAIN"
(
  access_dir=$(mktemp -d)
  trap 'rm -rf -- "$access_dir"' EXIT
  sudo cat /etc/nsswitch.conf | python3 "$MIGRATION_ROOT/scripts/update-nss.py" > "$access_dir/nsswitch.conf"
  install_system_file "$access_dir/nsswitch.conf" /etc/nsswitch.conf
  sudo cat /etc/pam.d/system-login > "$access_dir/system-login"
  if ! grep -Eq '^[[:space:]]*session[[:space:]].*pam_mkhomedir\.so' "$access_dir/system-login"; then
    printf '\nsession required pam_mkhomedir.so skel=/etc/skel/ umask=0077\n' >> "$access_dir/system-login"
    install_system_file "$access_dir/system-login" /etc/pam.d/system-login
  fi
)
