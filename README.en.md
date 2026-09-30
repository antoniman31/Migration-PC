# Migration PC — a Windows reinstall checklist

> **French is the reference.** This page is a short English version, kept to what you need
> to use the program. It is not maintained line by line alongside the French one, so where
> the two disagree, [README.md](README.md) is right. For the design decisions, the test
> suites and the project history, read the French documents — they are the real ones.

An HTML checklist for reinstalling a Windows PC without forgetting anything. PowerShell
scripts survey the software installed on the old machine and the drivers on the new one;
the page compares the two and says what is missing.

**What it does, and nothing else**: list the software on the source PC, list the software
on the target PC, state the difference — and flag devices with no driver on the target,
with the maker's support link. It backs up **nothing**. Your personal files remain
entirely your own responsibility.

`index.html` stands on its own: no dependency, no server, no build step. It opens from a
USB stick on a freshly installed PC, with no network. The scripts are optional.

The page exists in French and English. It opens in the browser's language, and the **FR** /
**EN** buttons at the top switch it. The scripts take the language of the Windows
interface, and `-Langue fr` or `-Langue en` settles it — useful for a French speaker on an
English Windows, or the reverse.

## How you use it

Put the whole folder on a USB stick. One file starts things, **`Migration PC.bat`**;
everything else lives in `scripts/`, which is there to be read.

1. Stick plugged into the **PC you are leaving**: double-click `Migration PC.bat`, choose
   **SOURCE**. The page opens already filled with your software.
2. Unplug the stick, plug it into the **target PC** — the new one, or the same one once
   reinstalled.
3. Double-click `Migration PC.bat`, choose **TARGET**. The page opens on what is left to
   install: **Software** says what is missing, **Drivers** shows the devices with no
   driver and the maker's link.
4. Run `Migration PC.bat` again: it offers **Install what is missing**. It shows the list,
   waits for you to type `INSTALL` (or `INSTALLER` — both are accepted), then runs
   `winget import`. This is the only action in the program that changes the machine, and
   nothing chains on automatically after a scan.

Nothing to import by hand between the two, and no file to hunt for in a folder.

**The same script on both sides.** On the source it freezes the machine's state; on the
target it runs the same survey; and it is the page that compares. One consequence
simplifies everything: "new PC" and "same PC after reinstalling" become the same case.
Source and target can be the same computer at two different moments.

Each snapshot carries its date and never overwrites the previous one; a shortcut,
`inventaire-pc.json`, always points at the latest.

The scan is not compulsory: `index.html` opens on its own with an example profile.

## What it does not do

**The detection has never run on a real Windows machine.** The classification, the merge
across sources, the parsing of winget output and the source/target reconciliation are
covered by tests on hand-written data. Reading the registry, Store packages and game
libraries needs Windows: that code is reviewed, not proven. If a result looks wrong to
you, that is probably where it comes from.

**The project backs up nothing.** This is the most important limit, and it is deliberate.

**It will not move your applications across.** Commercial tools rewrite thousands of
registry references that differ from one machine to the next. Store apps do not copy,
hardware-bound licences deactivate, and you would carry over five years of accumulated
leftovers. A clean reinstall through winget covers what matters without grafting on
anything you do not understand.

**Not every program has a winget identifier.** Those found through the registry alone come
out with a search link instead of a command. They do not appear in the `winget .json`
export, which can only hold packages winget knows.

**An imported winget export loses the original names**: the format stores identifiers
only, so `7zip.7zip` gives "7zip" rather than "7-Zip". Going through `scan-pc.ps1` gives
correct names, because it reads the registry.

## Privacy

Everything stays on your machine. The page is a static file with no server and no network
call: progress and the imported profile live in the browser's local storage, and exports
are ordinary downloads.

**The inventory the scan produces describes your machine precisely** — its model, its
serial number, everything installed on it. Do not publish it.

The scan follows one constant rule: **the name goes in the inventory, the secret stays
out.** It records the path of a licence file but not its contents, and the last five
characters of a product key — what Windows shows you itself — but never the full key.
Where it used to survey Wi-Fi networks, BitLocker volumes and the credential manager, it
gave the names and never the keys, the passwords or the recovery key. In each of those
cases the command that would hand over the secret exists: not using it is the choice, and
it rests on one reason — this file travels on a USB stick, and USB sticks get lost.
[COUVERTURE.md](COUVERTURE.md) keeps the record of those three deliberate stops even
though the code is gone.

Local storage is tied to the browser **and** to the file's path. If the USB stick's drive
letter changes from one PC to the other, your progress does not follow: the JSON export is
the only reliable transfer.

**A profile you received is untrusted input.** The project is built for people to exchange
profiles, so a profile often comes from a file you did not write. The page treats it as it
would any other input: everything it contains is escaped before reaching the page, and a
shortcut's address is only opened when it is `http`, `https` or `mailto` — a `javascript:`
one becomes a visibly inert button rather than a link that runs code. What is at stake is
not theoretical: local storage holds the inventory of your machine.

## Licence

**GNU AGPL v3 or later.** The code is open: you may read it, use it, modify it and
redistribute it. The one constraint is reciprocity — if you distribute a modified version,
**or run it as an online service**, you must publish your source under the same licence.
That second clause is what sets the AGPL apart from other free licences, and it is exactly
why it was chosen here: someone can take this work further, nobody can close it again.

This project was first published under the MIT licence, from 24 to 26 September 2026. The
versions distributed during that window remain under MIT: a licence change only applies
from then on, never to what has already gone out.

`LICENSE` is included in `migration-pc.zip` — the AGPL requires the licence to travel with
any redistribution. The reasoning behind the choice is in
[README.md](README.md#licence), in French.

## Going further

The French documents carry the rest, and they are the ones kept up to date:

- [README.md](README.md) — the full version: the command line, what the scan looks for,
  every tab of the page, the hardware configuration block, the known limits in full.
- [FORMATS.md](FORMATS.md) — the file formats, field by field.
- [CONTRIBUER.md](CONTRIBUER.md) — the test suites, the CI, publishing.
- [COUVERTURE.md](COUVERTURE.md) — what the scanner really covers, and the project's
  history.
