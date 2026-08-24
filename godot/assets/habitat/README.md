# Habitat PBR asset provenance

Hippo OS uses mobile-resolution copies of Poly Haven CC0 textures during Android builds. The source images are fetched before Godot import and packaged into the offline APK; they are not downloaded by the app at runtime.

## Forest Ground 01

- Source: https://polyhaven.com/a/forrest_ground_01
- Author: Rob Tuytel / Poly Haven
- Licence: CC0 1.0 / public domain dedication
- Production use: grassland/soil diffuse, OpenGL normal and roughness maps
- Build resolution: 1K JPG

Files:
- `pbr/forrest_ground_01_diff_1k.jpg`
- `pbr/forrest_ground_01_nor_gl_1k.jpg`
- `pbr/forrest_ground_01_rough_1k.jpg`

## Rocks Ground 08

- Source: https://polyhaven.com/a/rocks_ground_08
- Author: Rob Tuytel / Poly Haven
- Licence: CC0 1.0 / public domain dedication
- Production use: muddy/rocky shoreline diffuse, OpenGL normal and roughness maps
- Build resolution: 1K JPG

Files:
- `pbr/rocks_ground_08_diff_1k.jpg`
- `pbr/rocks_ground_08_nor_gl_1k.jpg`
- `pbr/rocks_ground_08_rough_1k.jpg`

The build script prints SHA-256 values for every fetched file. Once the upstream file names are proven by CI, the release pipeline pins those hashes so silent upstream changes fail the build.
