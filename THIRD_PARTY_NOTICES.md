# Third-party notices

Not legal advice; written for personal use, review before any wider release.

The same texts ship inside the app (`ios/ClipDeck/Resources/Licenses/`, bundled as `Licenses/`) and appear under
Settings > About and licences.

## FFmpeg (LGPL-2.1-or-later)

Clip Deck uses the FFmpeg libraries libavformat, libavcodec, libavutil and libswresample to open MKV files.
FFmpeg is free software under the GNU Lesser General Public License version 2.1 or later. The full text is in
[`ios/ClipDeck/Resources/Licenses/FFmpeg-LGPL-2.1.txt`](ios/ClipDeck/Resources/Licenses/FFmpeg-LGPL-2.1.txt).
The build uses no `--enable-gpl`, `--enable-version3` or `--enable-nonfree`.

FFmpeg: Copyright (c) 2000-2026 the FFmpeg developers. Licensed under the LGPL-2.1-or-later.

| Item | Value |
|---|---|
| FFmpeg version | n8.1.3 |
| Packaged by | FFmpegBuild 3.16.0 (Swift package, dynamic xcframeworks) |
| FFmpegBuild source (exact tag) | https://github.com/superuser404notfound/FFmpegBuild/tree/3.16.0 |
| FFmpeg source | https://ffmpeg.org/releases/ffmpeg-8.1.3.tar.xz, https://github.com/FFmpeg/FFmpeg/tree/n8.1.3 |

FFmpegBuild applies a few local patches to FFmpeg; they are listed in its README and published in its repository.

The FFmpeg libraries are separate dynamic frameworks inside the app (`Frameworks/AetherLib*.framework`), so they
can be replaced with a modified build. The Clip Deck [`LICENSE`](LICENSE) allows modifying and reverse engineering
the app for debugging such modifications, as LGPL-2.1 section 6 requires.

## Other components inside the FFmpegBuild frameworks

| Component | Licence | Copyright | Notes |
|---|---|---|---|
| dav1d 1.5.4 | BSD-2-Clause | Copyright © 2018-2025, VideoLAN and dav1d authors | AV1 decoder, linked by libavcodec. Source: https://code.videolan.org/videolan/dav1d/-/tree/1.5.4 |
| libzvbi 0.2.46 | LGPL-2.0-or-later (conveyed under LGPL-2.1); `ure.c`/`ure.h` under MIT | Library sources (`src/*`): Copyright (c) 1998 Manish Singh; 1999-2008 Michael H. Schimek; 2000 Stefan Westerfeld; 2000-2003 Iñaki G. Etxebarria; 2003-2004 Tom Zoerner. `ure.*`: Copyright 1997, 1998, 1999 Computing Research Labs, New Mexico State University; Iñaki García Etxebarrria; Michael H. Schimek | Teletext decoder, linked by libavcodec. FFmpegBuild removes its GPL-2 files and adds an LGPL stub (Copyright (C) 2026 Vincent Herbst). Source: https://github.com/zapping-vbi/zvbi/tree/v0.2.46 |

The full texts, with every copyright line (including libzvbi's DVB headers and contributor notes), are in
[`ios/ClipDeck/Resources/Licenses/Other-Components.txt`](ios/ClipDeck/Resources/Licenses/Other-Components.txt).

FFmpegBuild also contains zimg (WTFPL) and libswscale/libavfilter, which Clip Deck does not link.

## Clip Deck itself

See [`LICENSE`](LICENSE): all rights reserved, plus the one LGPL-2.1 section 6 exception.
