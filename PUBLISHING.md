# Publish the repository and website

This repository contains the source, screenshots, website, and a ready-to-download screensaver ZIP.

Repository: https://github.com/ahmadfaridabbas/bauhaus-clock

Website: https://ahmadfaridabbas.github.io/bauhaus-clock/

The instructions below also apply when publishing a fork.

## 1. Upload to GitHub

1. Create a new repository on GitHub. `bauhaus-hands` is a suggested name; any name works.
2. Upload the **contents** of this folder into the repository root, including `src/`, `scripts/`, `tests/`, and `docs/`. Do not place everything inside an extra `Clock Github Upload` directory.
3. Commit the files to your default branch, usually `main`.

The `BauhausHands.saver` folder is a local build output and does not need to be uploaded. The installable version is already included at `docs/downloads/BauhausHands-1.0.0.zip`, which preserves the macOS bundle and executable permissions. If uploading through the browser, include `docs/.nojekyll` if your file picker shows hidden files; the simple site also works without it.

## 2. Enable GitHub Pages

1. Open your repository's **Settings → Pages**.
2. Under **Build and deployment**, choose **Deploy from a branch**.
3. Select the branch containing your files and choose **/docs** as the folder.
4. Click **Save** and wait for the Pages deployment to finish.
5. GitHub displays the published URL on that settings page. Open it to verify the gallery and download button.

The typical address is `https://YOUR-USERNAME.github.io/YOUR-REPOSITORY/`. These are explanatory placeholders, not values that need replacing in the website. The page and download links work without editing the HTML.

Official instructions: https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site

## 3. Optional GitHub Release

Create a release tagged `v1.0.0` and attach `docs/downloads/BauhausHands-1.0.0.zip`. The website's download button already points at its bundled ZIP, so a Release is optional.

## Updating

Edit the source, run `bash scripts/package-release.sh`, regenerate screenshots if the appearance changes, and upload or push the updated files. For a version change, update `src/Info.plist`, the ZIP link in `docs/index.html` and `README.md`, and the visible version text. GitHub Pages republishes changes to `docs/` automatically once configured.

Keep the original author's attribution. The upstream licensing status is documented in `THIRD_PARTY_NOTICES.md`.
