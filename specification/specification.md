# Overview

Blowtorch provides utilities for building and A/B testing self-updating apps. Business logic and UI is largely implemented in javascript, with occasional usage of native OS functionality that is exposed through the blowtorch javascript APIs.

A blowtorch app usually ships to the app store with a small bootstrap payload with sufficient functionality to keep the user entertained on first boot while a full payload is retrieved from the server. On subsequent app boots the currently installed payload is always executed immediately, while a background task checks for new versions with the server. If a new payload is available it will be stored in the background and executed the next time the app boots.

# Upgrade protocol

##Bootstrap

A native blowtorch app ships with `bootstrap.html`, which is displayed to the user upon first load. Meanwhile the app sends an `upgrade request` with a null `current_version` and `client_id`.

##Upgrade requests

Upon app launch and at any other time the app can send an `upgrade request` to the server. The request is an HTTP POST request a JSON post body:
	
	# Android device info https://github.com/menny/android-device-info/blob/master/src/com/menny/android/deviceinformation/Main.java
	# iOS device info ???
	{
		display: {...},
		locale: {...},
		os: {...},
		client_id: {...},
		current_version: 'version_id',
		upgrade_history: [{ id:'version_id', date:1331159984 }, { id:'version_id', date:13311264738 }]
	}

If there is no new version available a HTTP NO_CONTENT response is returned. Otherwise, a JSON response is returned:

	{
		client_id: 'xyz',
		new_version: 'version_id'
	}

If `client_id` is specified, the client is responsible for storing and sending it with all subsequent upgrade requests.
If `new_version` is specified, the client is responsible for downloading the new payload with a GET request to `/version/<version_id>`. The response is a gzipped tarball folder with:

	version_<version_id>/
		app.html
		resources/*
