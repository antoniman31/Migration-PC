# Migration PC — a Windows reinstall checklist

> **French is the reference.** This page is a short English version, kept to what you need
> to use the program. It is not maintained line by line alongside the French one, so where
> the two disagree, [README.md](README.md) is right. For the design decisions, the test
> suites and the project history, read the French documents — they are the real ones.

An HTML checklist for reinstalling a Windows PC without forgetting anything. PowerShell
scripts survey the software installed on the old machine and the drivers on the new one; the
page compares the two and says what is missing.

**What it does, and nothing else**: list the software on the source PC and on the target PC,
state the difference — and flag devices with no driver on the target, with the maker's
support link. It backs up **nothing**: your personal files remain your own responsibility.

**Requirements**: Windows with PowerShell 5.1 or later, already built into Windows 10 and 11.
`index.html` stands on its own — no dependency, no server, no build step — and opens from a
USB stick on a freshly installed PC, with no network. The scripts are optional.

## How you use it

Put the whole folder on a USB stick. One file starts things, **`Migration PC.bat`**;
everything else lives in `scripts/`, which is there to be read.

1. Stick plugged into the **PC you are leaving**: double-click `Migration PC.bat`, choose
   **SOURCE**. The page opens already filled with your software.
2. Plug the stick into the **target PC** — the new one, or the same one once reinstalled.
3. Double-click `Migration PC.bat`, choose **TARGET**. The page opens on what is left to
   install: **Software** says what is missing, **Drivers** shows the devices with no driver
   and the maker's link.
4. Run `Migration PC.bat` again: it offers **Install what is missing**. It shows the list,
   waits for you to type `INSTALL` (or `INSTALLER`), then runs `winget import`. This is the
   only action in the program that changes the machine; nothing chains on automatically.

**Between the two, back up your personal files**: the scan lists, it copies nothing, and this
project does not cover that step.

The same script runs on both sides: it freezes the machine's state, and the page does the
comparing. "New PC" and "same PC after reinstalling" are therefore the same case. Each snapshot
carries its date and never overwrites the previous one. The menu guesses which side you are on
when the stick carries another machine's snapshot; otherwise it asks, and **Where to start?**
describes the three situations. The scan is optional: `index.html` opens on its own with an
example profile.

Windows shows a SmartScreen warning on a `.bat` downloaded from the internet: "More info",
then "Run anyway". No trick avoids it without a paid signing certificate. The `.bat` exists
only because Windows refuses to run a `.ps1` by double-click, and unlike an `.exe` it stays
readable in Notepad.

**Language.** The page opens in the browser's language, and the **FR** / **EN** buttons at the
top switch it. The scripts take the language of Windows; `-Langue fr` or `-Langue en` settles
it, including on the launcher: `Migration PC.bat -Langue en`. A profile you load is not
translated, and an exported profile goes out with its original text.

## What the scan looks at

`winget list`, the registry `Uninstall` keys, Microsoft Store packages, game libraries (Steam,
Epic, GOG, Xbox, Ubisoft, EA), the machine itself (maker, model, serial number) and
non-Microsoft drivers. An entry seen by several sources is merged, and the source/target
comparison runs on the normalised name, so "Mozilla Firefox (x64 fr)" and "Mozilla Firefox"
count as one. Nothing is ticked without your say-so. The French README has the command-line
options in full.

## What it does not do

**The detection has never run on a real Windows machine.** The logic is covered by tests on
hand-written data; reading the registry, Store packages and game libraries needs Windows,
and that code is reviewed, not proven. If a result looks wrong to you, that is probably where it
comes from.

**The project backs up nothing, and will not move your applications across**: Store apps do not
copy, hardware-bound licences deactivate, and you would carry over five years of leftovers. A
clean reinstall through winget covers what matters.

**Not every program has a winget identifier.** Those found through the registry alone come out
with a search link instead of a command, and are absent from the `winget .json` export. An
imported winget export loses the original names (`7zip.7zip` gives "7zip").

## Privacy

Everything stays on your machine. The page is a static file with no network call: progress and
the imported profile live in the browser's local storage, which is tied to the browser **and**
to the file's path. If the stick's drive letter changes from one PC to the other, your progress
does not follow: the JSON export is the only reliable transfer.

**The inventory the scan produces describes your machine precisely** — model, serial number,
everything installed. Do not publish it. The scan follows one rule: **the name goes in the
inventory, the secret stays out.** It records a licence file's path but not its contents, and
the last five characters of a product key but never the full key. It does not collect Wi-Fi
keys, the BitLocker recovery key or Windows passwords: the command that would hand them over
exists, and this file travels on a USB stick that gets lost.

**A profile you received is untrusted input.** Everything it contains is escaped before reaching
the page, and a shortcut's address is only opened when it is `http`, `https` or `mailto`.

## Licence

**GNU AGPL v3 or later.** The code is open: you may read it, use it, modify it and redistribute
it. The one constraint is reciprocity: if you distribute a modified version, **or run it as an
online service**, you publish your source under the same licence. The project was first published
under the MIT licence, from 24 to 26 September 2026; versions distributed in that window remain
under MIT. `LICENSE` is included in `migration-pc.zip`.

## Going further

The French documents carry the rest, and they are the ones kept up to date:
[README.md](README.md) (the full version), [FORMATS.md](FORMATS.md) (the file formats),
[COUVERTURE.md](COUVERTURE.md) (what the scanner really covers, and the project's history),
[VERIFIER-SUR-WINDOWS.md](VERIFIER-SUR-WINDOWS.md) (the first run on a real machine) and
[CONTRIBUER.md](CONTRIBUER.md) (tests, CI, publishing).
