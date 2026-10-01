#!/bin/sh
set -eu

root=/usr/share/nginx/html
config_output="$root/customer-runtime-config.js"
config_json="${config_output}.json"
manifest_output="$root/manifest.json"
index_output="$root/index.html"
index_template=/etc/customer/index.html.template

cp "$index_template" "$index_output"

app_name="${CUSTOMER_FLUTTER_WEB_APP_NAME:-Customer}"
short_name="${CUSTOMER_FLUTTER_WEB_SHORT_NAME:-$app_name}"
description="${CUSTOMER_FLUTTER_WEB_DESCRIPTION:-Customer application.}"
theme_color="${CUSTOMER_FLUTTER_WEB_THEME_COLOR:-#087FF0}"
background_color="${CUSTOMER_FLUTTER_WEB_BACKGROUND_COLOR:-#FFFFFF}"
canonical_url="${CUSTOMER_FLUTTER_WEB_CANONICAL_URL:-.}"
start_url="${CUSTOMER_FLUTTER_WEB_START_URL:-.}"
scope="${CUSTOMER_FLUTTER_WEB_SCOPE:-$start_url}"
manifest_id="${CUSTOMER_FLUTTER_WEB_MANIFEST_ID:-$canonical_url}"
icon_192_url="${CUSTOMER_FLUTTER_WEB_ICON_192_URL:-icons/Icon-192.png}"
icon_512_url="${CUSTOMER_FLUTTER_WEB_ICON_512_URL:-icons/Icon-512.png}"
maskable_icon_192_url="${CUSTOMER_FLUTTER_WEB_MASKABLE_ICON_192_URL:-icons/Icon-maskable-192.png}"
maskable_icon_512_url="${CUSTOMER_FLUTTER_WEB_MASKABLE_ICON_512_URL:-icons/Icon-maskable-512.png}"
favicon_url="${CUSTOMER_FLUTTER_WEB_FAVICON_URL:-$icon_192_url}"
apple_touch_icon_url="${CUSTOMER_FLUTTER_WEB_APPLE_TOUCH_ICON_URL:-$favicon_url}"
share_image_url="${CUSTOMER_FLUTTER_WEB_SHARE_IMAGE_URL:-$icon_512_url}"
social_title="${CUSTOMER_FLUTTER_WEB_SOCIAL_TITLE:-$app_name}"
social_description="${CUSTOMER_FLUTTER_WEB_SOCIAL_DESCRIPTION:-$description}"
locale="${CUSTOMER_FLUTTER_WEB_LOCALE:-}"
direction="${CUSTOMER_FLUTTER_WEB_DIRECTION:-}"

jq -n \
  --arg appName "$app_name" \
  --arg shortName "$short_name" \
  --arg description "$description" \
  --arg themeColor "$theme_color" \
  --arg backgroundColor "$background_color" \
  --arg canonicalUrl "$canonical_url" \
  --arg startUrl "$start_url" \
  --arg scope "$scope" \
  --arg manifestId "$manifest_id" \
  --arg faviconUrl "$favicon_url" \
  --arg appleTouchIconUrl "$apple_touch_icon_url" \
  --arg icon192Url "$icon_192_url" \
  --arg icon512Url "$icon_512_url" \
  --arg maskableIcon192Url "$maskable_icon_192_url" \
  --arg maskableIcon512Url "$maskable_icon_512_url" \
  --arg shareImageUrl "$share_image_url" \
  --arg socialTitle "$social_title" \
  --arg socialDescription "$social_description" \
  --arg locale "$locale" \
  --arg direction "$direction" \
  '{
    appName: $appName,
    shortName: $shortName,
    description: $description,
    themeColor: $themeColor,
    backgroundColor: $backgroundColor,
    canonicalUrl: $canonicalUrl,
    startUrl: $startUrl,
    scope: $scope,
    manifestId: $manifestId,
    faviconUrl: $faviconUrl,
    appleTouchIconUrl: $appleTouchIconUrl,
    icon192Url: $icon192Url,
    icon512Url: $icon512Url,
    maskableIcon192Url: $maskableIcon192Url,
    maskableIcon512Url: $maskableIcon512Url,
    shareImageUrl: $shareImageUrl,
    socialTitle: $socialTitle,
    socialDescription: $socialDescription,
    locale: $locale,
    direction: $direction
  } | with_entries(select(.value != ""))' > "$config_json"

{
  printf '%s' 'window.customerFlutterWebConfig = Object.assign({}, window.customerFlutterWebConfig || {}, '
  cat "$config_json"
  printf '%s\n' ');'
} > "$config_output"

jq '{
  id: .manifestId,
  name: .appName,
  short_name: .shortName,
  start_url: .startUrl,
  scope: .scope,
  display: "standalone",
  background_color: .backgroundColor,
  theme_color: .themeColor,
  description: .description,
  orientation: "portrait-primary",
  prefer_related_applications: false,
  icons: [
    {src: .icon192Url, sizes: "192x192", type: "image/png"},
    {src: .icon512Url, sizes: "512x512", type: "image/png"},
    {src: .maskableIcon192Url, sizes: "192x192", type: "image/png", purpose: "maskable"},
    {src: .maskableIcon512Url, sizes: "512x512", type: "image/png", purpose: "maskable"}
  ]
}' "$config_json" > "$manifest_output"

html_replacement() {
  jq -nr --arg value "$1" '$value | @html' | sed 's/[\\&|]/\\&/g'
}

replace_meta() {
  selector="$1"
  value="$(html_replacement "$2")"
  sed -i "s|<meta $selector content=\"[^\"]*\">|<meta $selector content=\"$value\">|" "$index_output"
}

replace_link() {
  selector="$1"
  value="$(html_replacement "$2")"
  sed -i "s|<link $selector href=\"[^\"]*\"[^>]*>|<link $selector href=\"$value\">|" "$index_output"
}

title="$(html_replacement "$app_name")"
sed -i "s|<title>[^<]*</title>|<title>$title</title>|" "$index_output"
replace_meta 'name="description"' "$description"
replace_meta 'name="theme-color"' "$theme_color"
replace_meta 'name="msapplication-TileColor"' "$theme_color"
replace_meta 'property="og:title"' "$social_title"
replace_meta 'property="og:description"' "$social_description"
replace_meta 'property="og:url"' "$canonical_url"
replace_meta 'property="og:image"' "$share_image_url"
replace_meta 'name="twitter:title"' "$social_title"
replace_meta 'name="twitter:description"' "$social_description"
replace_meta 'name="twitter:url"' "$canonical_url"
replace_meta 'name="twitter:image"' "$share_image_url"
replace_meta 'name="apple-mobile-web-app-title"' "$short_name"
replace_link 'rel="apple-touch-icon"' "$apple_touch_icon_url"
replace_link 'rel="icon" type="image/png"' "$favicon_url"
replace_link 'rel="canonical"' "$canonical_url"

if [ -n "$locale" ]; then
  lang="$(html_replacement "$locale")"
  sed -i "s|<html>|<html lang=\"$lang\">|" "$index_output"
fi
if [ "$direction" = "ltr" ] || [ "$direction" = "rtl" ] || [ "$direction" = "auto" ]; then
  dir="$(html_replacement "$direction")"
  sed -i "s|<html\\([^>]*\\)>|<html\\1 dir=\"$dir\">|" "$index_output"
fi

rm -f "$config_json"
