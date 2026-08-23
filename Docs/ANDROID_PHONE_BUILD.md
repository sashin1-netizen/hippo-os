# Hippo OS — Build APK directly on Android

This is the primary zero-cost build path when no PC is available.

## Requirements

- Android phone or tablet
- Godot Android editor
- Hippo OS repository ZIP
- No Windows PC
- No paid cloud builder
- No GitHub Actions required

## 1. Install Godot on Android

Install the current Godot Android editor from the official Godot Android download page or Google Play.

Grant **All files access** when prompted so Godot can read the downloaded project folder.

## 2. Download Hippo OS source

Open the repository in your browser:

`https://github.com/sashin1-netizen/hippo-os`

Choose **Code → Download ZIP**.

Extract the ZIP on the device.

The active Godot project is inside:

`hippo-os-main/godot/`

The folder containing `project.godot` is the project root.

## 3. Import the project

Open Godot Android editor.

Choose **Import** and select:

`hippo-os-main/godot/project.godot`

Open the project and allow Godot to finish importing.

## 4. Test before export

Press the Play button.

Expected first playable behaviour:

- sanctuary loads
- procedural baby pygmy hippo appears
- hippo moves autonomously
- drag the hippo to pet it
- feed button lowers hunger
- bond/hunger/energy appear in HUD
- save state persists

If Godot reports a script error, copy the complete error message into ChatGPT before exporting.

## 5. Export APK

The project already includes an Android export preset.

In Godot Android editor:

1. Open **Project → Export**.
2. Select **Android**.
3. Keep the non-Gradle export path enabled.
4. Choose **Export Project**.
5. Save as `HippoOS.apk` in Downloads.

For normal non-Gradle Android export in the Android editor, separate OpenJDK and Android SDK installation is not required.

## 6. Install

Open `HippoOS.apk` from Downloads.

Android may ask permission to install unknown apps for Godot or your file manager. Enable it only for the app you use to open the APK, then install Hippo OS.

## Current build target

The Godot version is the active R0/no-PC build. The Unreal prototype remains in the repository for future high-end development but is not required for the APK.
