#!/bin/sh

cat <<__END_OF_HEADERS__
Content-Type: text/plain

__END_OF_HEADERS__

h_version() {
	hostile --version
}

case "$QUERY_STRING" in
  version)
	h_version
	;;
  *)
	echo "Not implemented (yet)"
	;;
esac

