# Hippo OS bioacoustic design notes

Hippo OS deliberately avoids treating a pygmy hippopotamus like a loud common-hippo soundboard.

## Behavioural basis

Reliable husbandry and zoo references consistently describe pygmy hippos as comparatively quiet, with occasional vocalisations including grunts, snorts/huffs, hisses and higher squeaks. Published work also makes clear that the species' vocal repertoire is still poorly documented, especially in the wild.

References used for the current design:

- EAZA Pygmy Hippopotamus Best Practice Guidelines (2020): notes roaring/snorting, muffled cries, loud breathing and grunting, while also noting how little is known about wild vocalisations.
- Animal Diversity Web, *Hexaprotodon/Choeropsis liberiensis*: describes the species as typically silent with occasional snorts, grunts, hisses and squeaks.
- San Diego Zoo Animals & Plants, Pygmy Hippopotamus: describes a range from low grunts to high-pitched squeaks, with a loud huff when alarmed.
- Kempkes MSc thesis extended version (2025/2026 publication): documents the continuing lack of analysed pygmy-hippo acoustic data and recent pilot acoustic-monitoring work.

## Implementation rule

The app therefore uses a sparse, context-sensitive vocal model:

- core low grunts/chuffs remain available for close interaction and selected behaviour changes;
- spontaneous vocalisations are deliberately infrequent;
- any vocalisation forces a longer quiet interval before another random call;
- huffs are the most common additional short call;
- squeaks are rare and used only in high-energy or high-bond contexts;
- hisses are restrained and reserved for low-affection/low-curiosity states rather than used as a generic positive sound;
- sleep remains dominated by breathing rather than vocal chatter.

The added calls are original procedural audio. They are not represented as recordings of a real individual pygmy hippo. A future verified field/studio recording pack may replace or layer over these procedural calls once an appropriate legally reusable source is available.

## Branding

This is part of the Hippo OS immersive spatial-audio system. The project does not claim Dolby Atmos certification or Dolby licensing.
