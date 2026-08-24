# Habitat PBR asset provenance

Hippo OS uses mobile-resolution copies of Poly Haven CC0 textures during Android builds. The source images are fetched before Godot import and packaged into the offline APK; they are not downloaded by the app at runtime.

## Forest Ground 01

- Source: https://polyhaven.com/a/forrest_ground_01
- Author: Rob Tuytel / Poly Haven
- Licence: CC0 1.0 / public domain dedication
- Production use: grassland/soil diffuse, OpenGL normal and roughness maps
- Build resolution: 1K JPG

Files and pinned SHA-256 values:
- `pbr/forrest_ground_01_diff_1k.jpg` — `3dd6875cb3908e022a3c45ebbffa5e84c670ff2691fbbb6dc9ea4bff88523800`
- `pbr/forrest_ground_01_nor_gl_1k.jpg` — `32528a7cdee962cc0b248ee4023a74d0df175737ea90e1eb425122351e0bdab4`
- `pbr/forrest_ground_01_rough_1k.jpg` — `30d8b56a03d7b12da16f58011b675662a40e58e1cdc768119a5f03968140058c`

## Rocks Ground 08

- Source: https://polyhaven.com/a/rocks_ground_08
- Author: Rob Tuytel / Poly Haven
- Licence: CC0 1.0 / public domain dedication
- Production use: muddy/rocky shoreline diffuse, OpenGL normal and roughness maps
- Build resolution: 1K JPG

Files and pinned SHA-256 values:
- `pbr/rocks_ground_08_diff_1k.jpg` — `854f22105dd5a85fbc27e840704576e1fc99353bf6d881ded71c6100d15cc57d`
- `pbr/rocks_ground_08_nor_gl_1k.jpg` — `15661239defd2560d0fd9cbc295d08774b3c039ba8dd643fca562c4674ea29e4`
- `pbr/rocks_ground_08_rough_1k.jpg` — `b2df91701d9ac8a988e7d1637ca7aed93dd1d3a6b88015cc0014c97c73b981bf`

The build fails if any downloaded asset no longer matches its recorded SHA-256 value. This prevents silent upstream changes from entering a Hippo OS release.
