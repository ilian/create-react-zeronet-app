#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(dirname "$0")"

# Check system requirements
for cmd in node npx perl; do
  if ! [ -x "$(command -v $cmd)" ]; then
    echo "error: $cmd is not installed" >&2
    exit 1
  fi
done

usage() {
    echo "create-react-zeronet-app 1.1.2" >&2
    echo "Usage: $(basename "$0") project-dir zeroNet-site-dir [options]" >&2
    echo "  project-dir: Path to an empty project directory" >&2
    echo "  zeronet-site-dir: Path to new Zeronet site" >&2
    echo "  options: arguments passed to create-react-app (e.g. --typescript)" >&2
    exit 1
}

# Check arguments
if [ "$#" -lt 2 ]; then
    echo -e "error: not enough arguments provided" >&2
    usage
fi
REACT_DIR="$1"
SITE_DIR="$(realpath "$2")"
if [ -z "$SITE_DIR" ] || ! [ -f "$SITE_DIR/content.json" ]; then
    echo -e "error: second argument should specify a path to a newly created ZeroNet site" >&2
    usage
fi

EXTRA_ARGS=("${@:3}")
if (( ${#EXTRA_ARGS[@]} )); then
    echo "The following arguments will be passed to create-react-app: $EXTRA_ARGS"
fi

# Create new react app in empty directory
npx create-react-app "$REACT_DIR" "${EXTRA_ARGS[@]}"

# Copy content.json from site to React project, which will be copied on every build
cp "$SITE_DIR/content.json" "$REACT_DIR/public/content.json"

# Symlink content.json to src dir to determine site's address
# Typescript won't allow inclusion of files from a non-src dir by default
ZERONET_LIBS="$REACT_DIR/src/zeronet"
mkdir -p "$ZERONET_LIBS"
ln -s ../../public/content.json "$ZERONET_LIBS/content.json"

# Copy and extend ZeroFrame class for react
ZEROFRAME_JS="$ZERONET_LIBS/zeroframe.js"
echo -e "import meta from './content.json'\n" | cat - "$SITE_DIR/js/ZeroFrame.js" > "$ZEROFRAME_JS"
cat "$SCRIPT_DIR/js/ReactZeroFrame.js" >> "$ZEROFRAME_JS"

# Copy custom build scripts
cp -r "$SCRIPT_DIR/scripts/." "$REACT_DIR/scripts"
echo -e "SITE_DIR=$SITE_DIR\n" >> "$REACT_DIR/scripts/config"
PACKAGE_JSON="$REACT_DIR/package.json"
node > "$PACKAGE_JSON.dst" <<EOF
const fs = require('fs');
const package = JSON.parse(fs.readFileSync('$PACKAGE_JSON'));
package.homepage = "./"; // Generate relative URIs for built files
package.scripts.start = "./scripts/start";
package.scripts.build = "./scripts/build";
console.log(JSON.stringify(package, null, 2));
EOF
mv "$PACKAGE_JSON.dst" "$PACKAGE_JSON"

## Patch webpack to enable hot reloading with ZeroNet
# Write development builds to dist/
perl -i -0pe 's/(quiet: true,\n)(\s*)/$1$2writeToDisk: true,\n$2/gs' "$REACT_DIR/node_modules/react-scripts/config/webpackDevServer.config.js"
# Enable relative URLs for development builds
perl -i -0pe 's/const (publicUrl|publicPath) = .+?;/const $1 = "\.\/";/gs' "$REACT_DIR/node_modules/react-scripts/config/webpack.config.js"
# Hot reloading client of webpack connects to the same origin as the current webpage by default
perl -i -pe "s/window.location.protocol/'http'/" "$REACT_DIR/node_modules/react-dev-utils/webpackHotDevClient.js"
perl -i -pe "s/window.location.hostname/'127.0.0.1'/" "$REACT_DIR/node_modules/react-dev-utils/webpackHotDevClient.js"
perl -i -pe "s/window.location.port/3000/" "$REACT_DIR/node_modules/react-dev-utils/webpackHotDevClient.js"

echo \
"create-react-zeronet-app created a new react project at the following location: $REACT_DIR
The generated project has been configured to deploy to $SITE_DIR
You can run the following scripts inside your react project:
npm run start      build and deploy a development version with hot reloading
npm run build      build and deploy a production version of your site"

