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

