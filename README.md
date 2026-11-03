# uni-foam.com — UNIFOAM v1

Static site for **UNIFOAM** — la comunidad del contratista latino de spray foam.
"Aquí nadie crece solo." Backed by H&R Foam Insulation LLC (hrfoam.com).

- **Live:** https://uni-foam.com (Netlify site id `225d6965-febf-46d7-b281-ac47955ff02a`)
- **Repo:** github.com/MCERQUA/uni-foam (push to main -> GitHub webhook -> Netlify build hook -> live)
- **Deploy token:** `/mnt/clients/hrsf/vault/credentials.json` -> `netlify_uni_foam_deploy` (never print/commit)

## Structure
- `index.html` — Spanish homepage (primary)
- `en/index.html` — English version
- `assets/` — foam-job.jpg (Edith's real job photo, 2026-09-19), himno-unifoam.mp3
  (the UNIFOAM anthem, generated 2026-10-29 from Edith's lyrics)
- `scripts/deploy.sh` — manual zip deploy via Netlify API (fallback if the webhook misses)
- `scripts/check-form.sh` — list form submissions via Netlify API

## Editing (the SMS-edit flow)
1. Edit `index.html` (and/or `en/index.html`) — content is plain HTML, CSS is inline in
   `<style>` in each page, no build step, no CDN dependency.
2. Commit: `git add -A && git commit -m "edit: <what changed>"`
3. Push: `git push origin main` — webhook triggers Netlify build (~1 min).
4. If stale after ~3 min (webhook can miss — known fleet issue): `bash scripts/deploy.sh`
5. Verify: `curl -s https://uni-foam.com | grep "<changed text>"`

## Forms
One form: `unete` (Únete / contact). Detected by Netlify from the static HTML
(`ignore_html_forms=false` on the site). Submissions visible in Netlify dashboard
(Forms) or via `bash scripts/check-form.sh`. Leads belong to hrsf ONLY.

## Design
Stitch-designed (project "UNIFOAM — uni-foam.com v1", 2026-11-03). Tokens:
graphite #17191F · amber #F59E0B · off-white #FAF8F4 · Barlow Condensed (headlines,
self-hosted fallback: system condensed) · Inter (body, fallback system sans).
Section rhythm: dark hero → light → tinted → dark image → amber accent → light → dark → darkest.

## Honesty constraints (v1)
Everything on the page traces to primary sources: Edith's own lyrics/messages
(ledger 2026-10-29) and CLIENT.md business facts. NO invented numbers, reviews,
members, or dates. When Edith supplies more (logo, photos, member stories), add then.
