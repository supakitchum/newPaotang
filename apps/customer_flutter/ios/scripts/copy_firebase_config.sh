#!/usr/bin/env bash

set -euo pipefail

default_source="$PROJECT_DIR/Runner/GoogleService-Info.plist"
source_path="${CUSTOMER_FLUTTER_FIREBASE_IOS_PLIST:-$default_source}"
configuration="${CONFIGURATION:-Debug}"

if [[ ! -f "$source_path" ]]; then
  if [[ "$configuration" == "Release" || "$configuration" == "Profile" ]]; then
    echo "error: Firebase config is required for customer_flutter iOS $configuration builds." >&2
    echo "error: Set CUSTOMER_FLUTTER_FIREBASE_IOS_PLIST to a deployment-secret file." >&2
    exit 1
  fi

  echo "warning: Firebase config is absent; native push is disabled for this build." >&2
  exit 0
fi

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$source_path" 2>/dev/null || true
}

configured_bundle_id="$(plist_value BUNDLE_ID)"
expected_bundle_id="${PRODUCT_BUNDLE_IDENTIFIER:-}"
if [[ -z "$configured_bundle_id" || -z "$(plist_value GOOGLE_APP_ID)" || -z "$(plist_value PROJECT_ID)" || -z "$(plist_value GCM_SENDER_ID)" ]]; then
  echo "error: GoogleService-Info.plist is missing required Firebase identifiers." >&2
  exit 1
fi

if [[ -n "$expected_bundle_id" && "$configured_bundle_id" != "$expected_bundle_id" ]]; then
  echo "error: Firebase BUNDLE_ID '$configured_bundle_id' does not match PRODUCT_BUNDLE_IDENTIFIER '$expected_bundle_id'." >&2
  exit 1
fi

destination_dir="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
mkdir -p "$destination_dir"
cp "$source_path" "$destination_dir/GoogleService-Info.plist"
