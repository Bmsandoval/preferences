#! /bin/bash

SLACK_THEME_FILE="/usr/lib/slack/resources/app.asar.unpacked/src/static/ssb-interop.js"
# Don't want to interpret variables whilst reading from the HEREDOC - thus the single quotes... potto
#cat << 'EOF' >> /Applications/Slack.app/Contents/Resources/app.asar.unpacked/src/static/ssb-interop.js
sudo cat << 'EOF' >> /usr/lib/slack/resources/app.asar.unpacked/src/static/ssb-interop.js
document.addEventListener("DOMContentLoaded", function() {

   // Then get its webviews
   let webviews = document.querySelectorAll(".TeamView webview");

   // Fetch our CSS in parallel ahead of time
   const cssPath = 'https://raw.githubusercontent.com/angelsix/youtube/develop/Windows%2010%20Dark%20Theme/Slack/slack-dark.css';
   let cssPromise = fetch(cssPath).then(response => response.text());

   // Insert a style tag into the wrapper view
   cssPromise.then(css => {
	  let s = document.createElement('style');
	  s.type = 'text/css';
	  s.innerHTML = css;
	  document.head.appendChild(s);
   });

   // Wait for each webview to load
   webviews.forEach(webview => {
	  webview.addEventListener('ipc-message', message => {
		 if (message.channel == 'didFinishLoading')
			// Finally add the CSS into the webview
			cssPromise.then(css => {
			   let script = `
					 let s = document.createElement('style');
					 s.type = 'text/css';
					 s.id = 'slack-custom-css';
					 s.innerHTML = \`${css}\`;
					 document.head.appendChild(s);
					 `
			   webview.executeJavaScript(script);
			})
	  });
   });
});
EOF
