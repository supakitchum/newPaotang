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

destination_dir="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
mkdir -p "$destination_dir"
cp "$source_path" "$destination_dir/GoogleService-Info.plist"
