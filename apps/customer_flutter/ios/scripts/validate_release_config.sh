#!/bin/sh
set -eu

if [ "${CONFIGURATION:-}" != "Release" ]; then
  exit 0
fi

missing=0

is_unresolved() {
  case "$1" in
    *'$('*|*'${'*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

require_value() {
  name="$1"
  value="$(eval "printf '%s' \"\${$name:-}\"")"

  if [ -z "$value" ] || is_unresolved "$value"; then
    echo "error: $name is required for customer_flutter Release builds." >&2
    missing=1
  fi
}

normalize_identifier() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _-'
}

require_value "APP_DISPLAY_NAME"
require_value "CUSTOMER_FLUTTER_URL_SCHEME"
require_value "CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN"
require_value "PRODUCT_BUNDLE_IDENTIFIER"
require_value "DEVELOPMENT_TEAM"

case "$(normalize_identifier "${APP_DISPLAY_NAME:-}")" in
  customer|customerflutter|newpaotang)
    echo "error: APP_DISPLAY_NAME must be partner-specific for Release builds." >&2
    missing=1
    ;;
esac

case "$(printf '%s' "${CUSTOMER_FLUTTER_URL_SCHEME:-}" | tr '[:upper:]' '[:lower:]')" in
  newpaotang|http|https)
    echo "error: CUSTOMER_FLUTTER_URL_SCHEME must be partner-specific for Release builds." >&2
    missing=1
    ;;
esac

case "${CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN:-}" in
  applinks:*)
    ;;
  *)
    echo "error: CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN must start with applinks: for Release builds." >&2
    missing=1
    ;;
esac

case "${CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN:-}" in
  applinks:localhost|applinks:*.localhost|applinks:127.*|applinks:0.0.0.0)
    echo "error: CUSTOMER_FLUTTER_ASSOCIATED_DOMAIN must use a production domain." >&2
    missing=1
    ;;
esac

case "${PRODUCT_BUNDLE_IDENTIFIER:-}" in
  com.newpaotang.customerFlutter|com.newpaotang.customer_flutter)
    echo "error: PRODUCT_BUNDLE_IDENTIFIER must be partner-specific for Release builds." >&2
    missing=1
    ;;
esac

if [ "$missing" -ne 0 ]; then
  exit 1
fi
