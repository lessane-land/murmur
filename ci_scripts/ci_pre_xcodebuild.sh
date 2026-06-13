#!/bin/sh

#  ci_pre_xcodebuild.sh
#  Xcode Cloud runs this automatically before building. It stamps the build
#  with Xcode Cloud's own incrementing build number (CI_BUILD_NUMBER) so every
#  upload to App Store Connect has a unique, increasing build number — the part
#  in parentheses, e.g. "1.0 (12)".
#
#  The PUBLIC version (the "1.0") is NOT touched here — that comes from
#  MARKETING_VERSION in the project. To change the public version, edit
#  MARKETING_VERSION in Murmur.xcodeproj and push; Xcode Cloud builds whatever
#  is committed, not your local edits.

set -e

if [ -n "$CI_BUILD_NUMBER" ]; then
    echo "Stamping build number: $CI_BUILD_NUMBER"
    cd "$CI_PRIMARY_REPOSITORY_PATH"
    /usr/bin/sed -i '' -E \
        "s/CURRENT_PROJECT_VERSION = [0-9.]+;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" \
        Murmur.xcodeproj/project.pbxproj
else
    echo "CI_BUILD_NUMBER not set; leaving build number unchanged."
fi
