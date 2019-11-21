#!/usr/bin/env bash
set -e

# Check system requirements
if ! [ -x "$(command -v node)" ] || ! [ -x "$(command -v npx)" ]; then
    echo "error: node or npx is not installed" >&2
    exit 1
fi

usage() {
    echo "create-react-zeronet-app 1.0.1" >&2
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
cat - >> "$ZEROFRAME_JS" <<"EOF"

/**
 * Extended ZeroFrame API with tweaks to accommodate for HTML5 routing.
 * This code originates from `create-react-zeronet-app`.
 */
class ReactZeroFrame extends ZeroFrame {
    constructor(url) {
        super(url);
        /* Strip off wrapper nonce which interferes with routing */
        window.history.replaceState(null, null, document.location.href.replace(/&?wrapper_nonce=[A-Za-z0-9]+/, ""));

        if (meta.domain === undefined) {
            this.siteAddress = window.location.href.match(meta.address);
        } else {
            this.siteAddress = window.location.href.match(meta.domain) || window.location.href.match(meta.address);
        }
        if (!this.siteAddress) {
            throw "[ReactZeroFrame] Unable to obtain address of zeronet site";
        }
        this.siteAddress = this.siteAddress[0];
        this.baseUrl = document.createElement("a");
        this.baseUrl.href = window.location.href.split(this.siteAddress)[0] + this.siteAddress + "/";

        this._monkeyPatchHistory();
    }

    /**
     * Get the base path that routes to the site.
     * If BrowserRouter of react-router-dom is used in this project, this base path should be provided as `basename`.
     * @param {boolean} is_spa Include the `?` suffix for single-page applications.
     */
    getBasePath(is_spa = true) {
        if (!this.baseUrl) {
            throw "[ReactZeroFrame] Base URL was not set yet. Was the siteInfo request completed?";
        }
        return this.baseUrl.pathname + (is_spa ? "?" : "");
    }

    /**
     * Convert a URL to a path relative to the site.
     * @param {string} url URL to convert.
     */
    getRelativeUrl(url) {
        /*
         * wrapperPushState appends absolute URLs to the end of a site prefixed with a `?`.
         * To ensure consistency between generated URLs in links and the effective history of the browser,
         * we strip of the base URL of the site from the generated links before passing them via wrapperPushState.
         */
        const baseUrl = this.getBasePath();
        const firstMatch = url.indexOf(baseUrl);
        return url.slice(firstMatch + baseUrl.length);
    }

    _monkeyPatchHistory() {
        this.realHistoryFuncs = {
            pushState: window.history.pushState,
            replaceState: window.history.replaceState
        };
        window.history.pushState = (state, title, url) => this.cmd('wrapperPushState', [state, title, this.getRelativeUrl(url)]);
        window.history.replaceState = (state, title, url) => this.cmd('wrapperReplaceState', [state, title, this.getRelativeUrl(url)]);
    }

    onRequest(cmd, message) {
        if (cmd == "wrapperPopState") {
            // Update iframe src without refresh
            this.realHistoryFuncs.replaceState.call(window.history, message.params.state, null, message.params.href);
            window.dispatchEvent(new  PopStateEvent('popstate', { state: message.params.state }));
        } else {
            super.onRequest(cmd, message);
        }
    }
}

export default new ReactZeroFrame

EOF

# Tweak build scripts
PACKAGE_JSON="$REACT_DIR/package.json"
node > "$PACKAGE_JSON.dst" <<EOF
const fs = require('fs');
const package = JSON.parse(fs.readFileSync('$PACKAGE_JSON'));
package.homepage = "./"; // Generate relative URIs for built files

/*
 * react-scripts build removes the entire build directory so we can't build
 * directly to the site directory, as it may contain user content.
 * We build into a separate directory and overwrite the files to the target site directory.
 */
package.scripts.build += ' && mkdir -p "$SITE_DIR"/static/ && touch "$SITE_DIR"/static/FILES_WILL_BE_REMOVED_ON_BUILD \
                          && rm -rf "$SITE_DIR"/precache-manifest.*.js "$SITE_DIR"/static/{css,js,media}/* && cp -rf build/. "$SITE_DIR"'
console.log(JSON.stringify(package, null, 2));
EOF
mv "$PACKAGE_JSON.dst" "$PACKAGE_JSON"

echo \
"create-react-zeronet-app created a new react project at the following location: $REACT_DIR
Run the following command inside your react project to build and deploy your site to $SITE_DIR:
npm run build"
