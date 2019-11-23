# create-react-zeronet-app
This script sets up a new React project for a ZeroNet site using [create-react-app](https://github.com/facebook/create-react-app) and various tweaks to the ZeroFrame library and the build environment.
The created project can be used to deploy a SPA using [react-router-dom](https://github.com/ReactTraining/react-router) with HTML5 history navigation.

## Features made compatible with ZeroNet
* Live reloading
* HTML5 history navigation

## Usage
* [Create a new ZeroNet site](https://zeronet.io/docs/using_zeronet/create_new_site/)
* Obtain the path of the site on your filesystem (typically under data/ of your ZeroNet installation)
* Run the script, providing an empty project directory and the path of your site as arguments
* Any other arguments passed to the script will be passed to create-react-app (e.g. `--typescript` for TypeScript support)

```
$ ./create-react-zeronet-app.sh myproject ~/bin/zeronet/data/1PXDHHbcUfXFwRMC1gZgpCFSZGPZPEyp6F --typescript
```
In the generated project directory
    * run `npm run start` to build and deploy a development version with hot reloading
    * run `npm run build` to build and deploy a production version of your site

## Notes on live reloading
`npm run start` will prompt you to navigate to a local webserver.
It is recommended to visit your website using ZeroNet instead to make use of the ZeroFrame API.
Live reloading is also supported when browsing via ZeroNet.

## Notes on HTML5 history navigation
To make sure that react-router-dom will generate proper URLs, set the `basename` of the `BrowserRouter` to `ZeroFrame.getBasePath()`.
Example:
```
import React from "react";
import {
  BrowserRouter as Router,
  Switch,
  Route,
  Link
} from "react-router-dom";
import ZeroFrame from './zeronet/zeroframe';

export default function App() {
  return (
    <Router basename={ZeroFrame.getBasePath()}>
        ...
    </Router>
  );
}
```

## Changing your site path
You can change the path to your ZeroNet site after generating the project by changing the SITE_DIR variable under `scripts/config`

