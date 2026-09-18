# DRAFT — not sent. For Al to send, edit or drop.

**To:** DataBC / GeoBC Air Photo (data custodian for
`WHSE_IMAGERY_AND_BASE_MAPS.AIMG_PHOTO_CENTROIDS_SP`)
**Subject:** `FLYING_HEIGHT` about 10.76x too large on 1,589 air photo centroids (13 film rolls)

Hello,

While using the Air Photo Centroids layer from the BC Data Catalogue we found a set of
records whose `FLYING_HEIGHT` looks to have had a feet-to-metres conversion applied the wrong
way round. The values are close to 10.76 times (3.28084 squared) what the frame's own
`SCALE` and `FOCAL_LENGTH` imply, and dividing by that factor brings every one of them back
into agreement with both the scale and the terrain elevation beneath the photo centre.

It affects 1,589 records on 13 film rolls:

| roll | year | scale | records | `FLYING_HEIGHT` as published (m) |
|---|---|---|---|---|
| bc5596 | 1974 | 1:12000 | 8 | 26,212 |
| bc78065 | 1978 | 1:2000 | 24 | 4,115 |
| bc78078 | 1978 | 1:6000 | 15 | 9,449 |
| bc79027 | 1979 | 1:13000 | 10 | 19,995 |
| bc79103 | 1979 | 1:10000 | 24 | 21,946 |
| bcb98013 | 1998 | 1:40000 | 1 | 97,924 |
| bcc00085 | 2000 | 1:15000 | 236 | 54,860 – 57,910 |
| bcc03004 | 2003 | 1:30000 | 232 | 71,640 – 72,469 |
| bcc03006 | 2003 | 1:35000 | 178 | 72,030 – 76,689 |
| bcc03007 | 2003 | 1:35000 | 231 | 69,751 – 74,949 |
| bcc03008 | 2003 | 1:35000 | 179 | 72,130 – 79,799 |
| bcc03046 | 2003 | 1:30000 | 234 | 70,881 – 71,849 |
| bcc05001 | 2005 | 1:30000 | 217 | 62,500 – 67,070 |

Not every frame on these rolls is affected — about 1,200 others on the same rolls carry
ordinary values — so the correction would need to be per record rather than per roll. The
affected records are the ones where `FLYING_HEIGHT / (SCALE x FOCAL_LENGTH / 1000)` exceeds 9.

For example, roll bcc03006 is 1:35000 with a 153 mm lens, which implies about 5,355 m above
ground; the published 75,117 m divided by 10.764 is 6,979 m above sea level, over terrain at
roughly 1,100 m.

We also noticed, less conclusively, about 2,000 records where `FLYING_HEIGHT` is under half
what the scale implies (for example roll bc79122: 640 m at 1:20000 with a 305 mm lens). We
could not determine a single cause for those, so we mention them only in case it is useful.

Happy to send the full list of record ids (`AIRP_ID`) if that would help.

Thank you,
