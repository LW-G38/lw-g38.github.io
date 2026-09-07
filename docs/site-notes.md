# al-folio remodel — prototype

A static, responsive prototype of the site rebuilt in the visual language of
[al-folio](https://github.com/alshedivat/al-folio). This is a **design prototype**, not the
real Jekyll build (see "Why static?" below).

## Preview it locally

No Ruby/Node/Python is installed on this machine, so use the bundled PowerShell static server:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/serve.ps1 -Port 8123
```

Then open <http://127.0.0.1:8123/prototype/index.html>.

Opening the files directly with `file://` will **not** work — relative CSS/JS/image paths break.

## Pages

| File                | Page         | Source content                                       |
| ------------------- | ------------ | ---------------------------------------------------- |
| `index.html`        | about        | banner, bio, profile photo, socials, news, selected papers |
| `publications.html` | publications | all 7 papers, grouped by year, with abstract toggles |
| `projects.html`     | projects     | 6 selected construction projects                     |
| `teaching.html`     | teaching     | CMU 48-524 / 48-722                                  |
| `cv.html`           | cv           | education, experience, licensure, service + PDF links |
| `contact.html`      | contact      | contact details, message form, visitors + map        |

Shared styling lives in `assets/css/al-folio.css`; behaviour (theme cycling, mobile nav,
back-to-top, abstract toggles) in `assets/js/al-folio.js`.

## Design tokens

Lifted from the live al-folio demo so the prototype matches the real theme:

|              | light     | dark      |
| ------------ | --------- | --------- |
| accent       | `#b509ac` | `#2698ba` |
| background   | `#ffffff` | `#1c1c1d` |
| text         | `#000000` | `#e8e8e8` |
| footer bg    | `#1c1c1d` | `#e8e8e8` |

Type is Roboto 300 at 16px/1.5, content column capped at 930px — all matching al-folio.

## Responsive behaviour

Verified with no horizontal overflow at 320px, 390px and 1280px on every page.

- **< 768px** — hamburger nav, about-page header stacks (name, titles, then contact block),
  profile photo stacks above the bio, publication thumbnails stack above their entry, CV date
  column moves above the role, footer becomes static.
- **>= 768px** — fixed footer bar, profile photo floats right, publication thumbnails sit
  left of each entry.

On the about page the header and the profile block are two matching columns: `.header-contact`
and `.profile` share `flex: 0 0 30%; max-width: 280px` with a 2rem gap, so the contact details
sit directly above the photo on the same edges rather than leaving the name and titles with
empty space beside them.

Theme follows the OS by default; the navbar toggle cycles system -> light -> dark and
persists in `localStorage`.

## Contact form

`contact.html` carries a name / email / subject / message form with client-side validation
and a hidden honeypot field for spam.

GitHub Pages is static, so delivery goes through **Web3Forms**: the form POSTs JSON to
`https://api.web3forms.com/submit` with the `access_key` hidden input, and Web3Forms emails it
to the address registered against that key. The access key is a public client-side identifier
by design — it is not a secret — but it does mean anyone can post to it, so Web3Forms' spam
filtering and the honeypot are what hold junk down. Turn on reCAPTCHA in their dashboard if
spam appears.

The JS checks the response body as well as the status, because Web3Forms answers `200` with
`{success: false}` on a rejected submission. On failure the visitor's typed message is kept
rather than cleared, and they are pointed at the plain email address.

Removing the `data-endpoint` attribute falls back to opening the visitor's own mail client
with the message pre-filled.

## Project card images

`scripts/make-project-cards.ps1` centre-crops each source photo to 16:10 and scales it to
800x500 into `images/projects/`, so every card crops and loads consistently. It uses WPF's
`BitmapDecoder` rather than `System.Drawing`, because GDI+ cannot read `.webp`.

| source              | card                                 |
| ------------------- | ------------------------------------ |
| `nrlf.jpg`          | UC NRLF, Phase 4                     |
| `scmb.jpg`          | Santa Clara Mission Library Remodel  |
| `shc-redwood.webp`  | Stanford Healthcare Redwood City     |
| `som-stanford.jpg`  | Stanford School of Medicine          |
| `ucsf.jpg`          | UCSF School of Medicine Seismic Upgrade |
| `ucsf-mb.jpg`       | UCSF Facilities Office, Mission Bay  |

The two UCSF photos are different campuses: `ucsf.jpg` is Parnassus Heights, the Medical
Sciences Building site, so it maps to the seismic upgrade; `ucsf-mb.jpg` is the Mission Bay
facilities office interior.

`images/gayner.jpg` is no longer used by any page — it was the placeholder before the real
photos arrived.

## Banner image

`images/campus-banner.jpg` (1860x531, 3.5:1, ~214 KB) is cropped from `images/IMG_4406.jpeg`
by `scripts/crop-banner.ps1` — a `System.Drawing` script, since this machine has no image
tooling. The crop keeps the cloud band, Cathedral of Learning, campus buildings on both sides
and the lawn, stopping above the tennis courts. Re-run the script with different `-CropY` /
`-CropH` values to reframe it.

## Visitor map

The MapMyVisitors widget (replacing the old ClustrMaps one) lives in the visitors section of
`contact.html`. Two things it is fussy about:

1. It loads with `w=a` (auto width) and measures its container, so that container needs a
   definite width or the map collapses to a few pixels.
2. It builds its background-map PNG filename from the width it measures — for example
   `bg-w_540-cl_ffffff.png`. **Fractional widths 404**, which renders the map as a blank blue
   rectangle showing only the visitor dots. `.map-inner` therefore pins an integer width at
   every breakpoint (280 / 320 / 420 / 500 / 540) instead of using a percentage.

## Still needs your input

- **Bio wording**: the about-page subtitle now reads "Registered Professional Engineer, State
  of California", but the bio paragraph below it still says "a professional mechanical engineer
  licensed in the State of California". Left as written — say the word and I'll align it.
- **Awarding school**: the CV gives degrees and majors but not the school, so *School of
  Engineering* for UC Merced is still inferred from the major. Confirm or correct. (Nanjing
  University is confirmed as the Department of Electronic Science and Engineering.)
- **Publications**: the CV lists 14 journal and 8 conference papers; `publications.html` still
  shows the 7 from the old site. Worth deciding which to feature before porting the rest.
- **Source images**: the originals in `images/` (notably `IMG_4406.jpeg`, 2.9 MB) are only
  inputs to the two crop scripts and are never served. Worth moving them out of the published
  tree before deploying.
- **About**: office building/room for the address block; real ORCID iD (currently a
  placeholder link) or remove that icon.
- **Selected papers**: currently the three first-author ones (AIRL 2026, GP4IEQ 2025,
  Energy Flexibility 2024) — easy to change.

## Why static?

al-folio v1.x ships its `_layouts`, `_includes` and styles inside Ruby gems
(`al_folio_core` and friends) rather than in the repo, so the real site cannot be built or
previewed without a Ruby toolchain. This machine has no Ruby, Node, Docker or Python.

Converting this prototype to the genuine Jekyll site means: `_config.yml`, content moved into
`_bibliography/papers.bib`, `_news/`, `_projects/`, `_data/cv.yml` and `_pages/`, plus
al-folio's GitHub Actions workflow to build and deploy. The content porting done here carries
over directly.
