# Bus Jam — approved urban game artwork

The owner selected the original urban game asset sheet on 6 October 2026.
All illustrated subjects use angular 3D game forms, graphic shadows, adult
proportions and streetwear. Bus/person color matching still uses coral/heart,
blue/circle, gold/five-point star, mint/diamond, violet/four-point sparkle and
rose/six-point star. The accessibility badge duplicates each shirt symbol at
phone scale. Artwork is loaded once before the first frame, then shared by
home and gameplay painters. Live occupancy dots and hints remain dynamic.

## Asset inventory and final prompt set

All imagery was generated with the built-in image generation tool. The
approved source sheet is preserved in `docs/art/approved-style.png`.
Individual sprites are tightly extracted from that exact sheet; no characters
were replaced. Result art and wordmark were sized for mobile use. PNG alpha is
preserved; invisible RGB under zero alpha was cleared for lossless compression.

| Deliverable | Consuming location | Final generation specification |
| --- | --- | --- |
| Six buses and six adult passengers | `assets/art/urban/bus-*.png`, `person-*.png`; home and animated board | Transparent 1536×1024, six columns/two rows; GTA San Andreas-inspired angular game meshes, hand-painted textures, broad graphic shadows, adult commuters and city buses; exact six colors and matching white symbols; no photoreal skin, toy shapes, text, scene or extra objects. |
| Home city | `assets/art/urban/city.png`; `CityPainter` | Match approved sheet's stylized urban rendering; opaque landscape 1536×1024; overhead city bus terminal, concrete sidewalks, brick/slate buildings, shelter and angular trees; calm empty asphalt foreground for compositing the approved sprites; no vehicles, people, text or UI. |
| App icon | `assets/branding/icon-1024.png`; all iOS, Android and web icons | Square opaque 1024×1024; approved city bus designs, coral/heart left, gold/star front-center, blue/circle right; high three-quarter overhead camera, slate asphalt and restrained road lines; bold readable game forms, no text, people, brands or pre-rounded corners. |
| Wordmark | `assets/branding/wordmark.png`; home and native launch image | Transparent landscape; exact `BUS JAM` on one line; original bold condensed slightly italic angular letters, ivory BUS and gold JAM, charcoal outline and hard graphic shadow; no additional words, imagery or franchise logo arrangement. |
| Victory and traffic jam | `assets/art/urban/win.png`, `fail.png`; result overlays | Transparent 1536×1024, two separate illustrations in one row; approved gold bus and gold-shirt commuter thumbs-up with mint check badge; approved coral bus and coral-hoodie commuter thinking with striped barrier and red light; match adult angular game style, no text, extra objects, scene, cropping or watermark. |

Functional controls use crisp Material glyphs and geometric marks, with the
same ink/slate/blue accent palette, squared card corners and compact hierarchy.
No images, characters, logos or extracted assets from another game are shipped.

## Verification

`test/urban_assets_test.dart` decodes the actual bundled files and checks visible
art, transparent corners and upright bus/adult proportions. Existing business,
controller, widget/layout journeys, generation checks and five native iPhone
screenshots run in Actions after every candidate change. Codemagic builds and
uploads internal TestFlight only after successful Actions for the exact main
commit. The previous source evidence is not reused for the new visuals.
