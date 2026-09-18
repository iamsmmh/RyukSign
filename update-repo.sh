#!/bin/sh
# Updates app-repo.json with the assets of the latest GitHub release.
#
# This is meant to run from the "Update Repository" workflow, but it can be run
# locally too:
#
#   RELEASE_REPO=owner/name ./update-repo.sh
#
# Environment:
#   RELEASE_REPO  owner/name to read releases from. Defaults to the origin
#                 remote of the current checkout.
#   GITHUB_TOKEN  optional; used to authenticate the GitHub API call so the
#                 run is not limited to 60 unauthenticated requests/hour.

handle_error() {
  echo "Error: $1" >&2
  exit 1
}

warn() {
  # Rendered as a warning annotation in the Actions log when available.
  echo "::warning::$1"
  echo "Warning: $1" >&2
}

command -v jq >/dev/null 2>&1 || handle_error "jq is required but was not found in PATH."

# shellcheck disable=SC2016
origin_repo() {
  git remote get-url origin 2>/dev/null \
    | sed -e 's#^https\{0,1\}://[^/]*/##' -e 's#^git@[^:]*:##' -e 's#\.git$##'
}

RELEASE_REPO="${RELEASE_REPO:-$(origin_repo)}"
[ -n "$RELEASE_REPO" ] || RELEASE_REPO="faroukbmiled/RyukSign"

API_URL="https://api.github.com/repos/${RELEASE_REPO}/releases/latest"

echo "Fetching latest release data from GitHub..."
echo "Repository: ${RELEASE_REPO}"

BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT INT TERM

if [ -n "${GITHUB_TOKEN:-}" ]; then
  HTTP_CODE=$(curl -sS -o "$BODY_FILE" -w '%{http_code}' \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "$API_URL") || handle_error "Request to ${API_URL} failed."
else
  HTTP_CODE=$(curl -sS -o "$BODY_FILE" -w '%{http_code}' \
    -H 'Accept: application/vnd.github+json' \
    -H 'X-GitHub-Api-Version: 2022-11-28' \
    "$API_URL") || handle_error "Request to ${API_URL} failed."
fi

if [ "$HTTP_CODE" != "200" ]; then
  handle_error "GitHub API returned HTTP ${HTTP_CODE} for ${API_URL}: $(head -c 400 "$BODY_FILE")"
fi

# Strip control characters so jq always sees well formed input.
clean_release_info=$(tr -d '\000-\037' < "$BODY_FILE")

jq -e . >/dev/null 2>&1 <<EOF || handle_error "GitHub API did not return valid JSON."
$clean_release_info
EOF

version=$(printf '%s' "$clean_release_info" | jq -r '.tag_name // empty' | sed 's/^v//')
updated_at=$(printf '%s' "$clean_release_info" | jq -r '.published_at // .created_at // empty')

if [ -z "$version" ]; then
  handle_error "Latest release for ${RELEASE_REPO} has no tag_name; refusing to write an empty version."
fi
if [ -z "$updated_at" ]; then
  handle_error "Latest release for ${RELEASE_REPO} has no published_at/created_at."
fi

echo "Release version: $version"
echo "Updated at: $updated_at"

ipa_files=$(printf '%s' "$clean_release_info" | jq -c '[.assets[]? | select(.name | endswith(".ipa") or endswith(".tipa")) | {
    name: .name,
    size: (.size | tonumber),
    download_url: .browser_download_url
}]')

if [ "$(printf '%s' "$ipa_files" | jq 'length')" -eq 0 ]; then
  warn "No .ipa or .tipa files found in the ${RELEASE_REPO} release ${version}; app-repo.json left untouched."
  exit 0
fi

echo "Found IPA/TIPA files in release:"
printf '%s' "$ipa_files" | jq -r '.[] | "• \(.name) (\(.size) bytes)"'

JSON_FILE="app-repo.json"
if [ ! -f "$JSON_FILE" ]; then
    handle_error "$JSON_FILE does not exist."
fi

num_apps=$(jq '.apps | length' "$JSON_FILE") || handle_error "$JSON_FILE is not valid JSON."
echo "Repository has $num_apps apps"

app_index=0
while [ "$app_index" -lt "$num_apps" ]; do
    app_name=$(jq -r ".apps[$app_index].name" "$JSON_FILE")
    app_id=$(jq -r ".apps[$app_index].bundleIdentifier" "$JSON_FILE")

    echo "Processing app[$app_index]: $app_name ($app_id)"

    matching_file=""

    if echo "$app_name" | grep -i "idevice" > /dev/null; then
        matching_file=$(printf '%s' "$ipa_files" | jq -c 'map(select(.name | endswith(".tipa") or contains("idevice"))) | first')
    else
        matching_file=$(printf '%s' "$ipa_files" | jq -c 'map(select(.name | endswith(".ipa") and (contains("idevice") | not))) | first')
    fi

    if [ -z "$matching_file" ] || [ "$matching_file" = "null" ]; then
        matching_file=$(printf '%s' "$ipa_files" | jq -c 'first')
        echo "No specific match found for $app_name, using first available file"
    fi

    if [ -n "$matching_file" ] && [ "$matching_file" != "null" ]; then
        name=$(printf '%s' "$matching_file" | jq -r '.name')
        size=$(printf '%s' "$matching_file" | jq -r '.size')
        download_url=$(printf '%s' "$matching_file" | jq -r '.download_url')

        echo "Updating $app_name with: $name"

        jq --arg index "$app_index" \
           --arg version "$version" \
           --arg date "$updated_at" \
           --argjson size "$size" \
           --arg url "$download_url" \
           '.apps[$index | tonumber] |= (
                .version = $version
              | .versionDate = $date
              | .size = $size
              | .downloadURL = $url
              | .versions = (
                    [ { version: $version, date: $date, size: $size, downloadURL: $url } ]
                  + [ (.versions // [])[] | select(.version != $version) ]
                )
              | .versions |= .[0:20]
            )' "$JSON_FILE" > "${JSON_FILE}.tmp"

        if jq -e '.apps | length' "${JSON_FILE}.tmp" >/dev/null 2>&1; then
            echo "JSON file is valid after update. Proceeding to replace."
            mv "${JSON_FILE}.tmp" "$JSON_FILE"
        else
            echo "Error: JSON file is invalid after update. Keeping the previous version." >&2
            rm -f "${JSON_FILE}.tmp"
            exit 1
        fi
    else
        echo "No matching file found for $app_name"
    fi

    app_index=$((app_index + 1))
done

echo "Repository update completed"
