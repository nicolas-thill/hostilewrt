#!/bin/sh

cat <<__END_OF_HEADERS__
Content-Type: text/plain

__END_OF_HEADERS__

ACTION=$(echo "$QUERY_STRING" | sed -e 's,[^a-zA-Z0-9],_,g')

h_config() {
	cat /etc/hostile.conf
}

h_log() {
	cat /var/log/hostile.log
}

h_version() {
	hostile --version
}

case "$ACTION" in
  config)
  	h_config
  	;;
  log)
  	h_log
  	;;
  version)
	h_version
	;;
  *)
	echo "501 - Action '$ACTION' not implemented (yet)"
	;;
esac

