# Contributing to StudyLab Buddy

Thanks for helping! A few ground rules:

- The interface is in **European Portuguese (pt-PT)**, using the informal "tu" form. Keep new text consistent.
- Everything stays **on the device**: no accounts, trackers or servers.
- Open an issue first for large changes so we can agree on the approach.

## Setup

- **Apple:** `brew install xcodegen`, then `cd apple && xcodegen generate`. Build from a folder not synced by iCloud.
- **Windows:** Node.js 20+, then `cd windows && npm ci && npm run dev`.

## Pull requests

1. Fork, create a branch, make a focused change.
2. Check it builds (`xcodebuild` for Apple, `npm run build` for Windows).
3. Describe what changed and attach a screenshot for UI changes.

Questions: [apoio@studylab.pt](mailto:apoio@studylab.pt)
