#!/bin/bash
# Turns the unsigned device build into LionClub.ipa.
# The entitlements (App Group) are embedded with ldid, so AltStore/SideStore can see what the
# app needs when they re-sign it with a free Apple ID.
set -euo pipefail

APP="build/device/Build/Products/Release-iphoneos/LionClub.app"
WIDGET="$APP/PlugIns/LionClubWidgets.appex"

ldid -S"Widgets/LionClubWidgets.entitlements" "$WIDGET/LionClubWidgets"
ldid -S"App/LionClub.entitlements" "$APP/LionClub"

rm -rf Payload LionClub.ipa
mkdir Payload
cp -R "$APP" Payload/
zip -qry LionClub.ipa Payload
ls -l LionClub.ipa
