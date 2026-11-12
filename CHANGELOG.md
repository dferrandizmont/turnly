# Changelog

What changes in each version of Turnly (called Cuadrante until 0.6.14), newest first. The "Unreleased" section fills up as changes land and becomes
the next version on the day it ships.

Numbering: the last number goes up with fixes (0.6.12 → 0.6.13), the middle one with new features (→ 0.7.0), and 1.0.0
will be the production launch in the stores. Every version ships on
[GitHub](https://github.com/dferrandizmont/turnly/releases) and TestFlight; Google Play and the App Store get several
at once, so they can skip numbers.

## Unreleased

## 0.10.0 · 2026-11-12

Overtime the way you really work it, rotation changes from any day, and more at a glance.

- **Overtime by blocks.** Add overtime to any day with a start and an end (it can run past midnight), an unpaid break and a note, as many blocks as you need. Right after a shift, "Right after the shift" and +1 h … +4 h set it in one tap. Your existing overtime is kept as it was and pays the same.
- **Overtime types.** "Overtime" and "Other job" come ready; create your own. Each type is paid as the shift, with a multiplier, at a fixed hourly rate or not at all, and decides whether it counts toward your hours goal. New base hourly rate in Settings › Hours and money for days without a priced shift.
- **Day total.** The day detail lists its overtime and shows the day's total hours and pay; the calendar cell shows "+2 h".
- **Rotation from the day.** In the day detail: "Start the rotation here", "Last day of this rotation" and, on an empty day after a rotation ends, "Start your rotation here". Each one explains what will change and can be undone. The detail also says where a shift comes from: your rotation or changed by hand.
- **Month strip.** Under the month: its shifts, your hours against your goal and your next day off. Tap it to open that month's summary.
- **Longest run.** The summary and the PDF report show your longest run of days worked in a row.
- **Widgets.** Android widgets show overtime and early leave next to your shift, and the seven-day widget adds up its hours.
- **New rotations.** "2 and 2" and "3 and 1" with the work shift you choose; familiar names (Pitman, Panama, DuPont) in the catalogue, and a plain sentence confirming when your rotation starts.

## 1.0.0 · 2026-11-10

First version on the App Store, for iPhone, with everything up to 0.9.7. Android stays in Google Play's closed testing on the 0.9 line for now.

- iOS: if you said "Don't Allow" to notifications, the Alarms screen now says so and its "Open settings" button takes you straight to Turnly's notification settings; coming back, it notices they are on. Before, "Allow" did nothing. Alarms are also planned again at once when the time zone or the clock changes.
- iOS: a `.turnly` backup opened from AirDrop, WhatsApp, Mail or Files now reaches the restore preview (nothing is restored until you confirm).
- iOS: home-screen and lock-screen widgets (small, medium, large, inline, circular and rectangular) that change day on their own for 60 days; on the lock screen any absence shows only as "Absence".
- iOS: the camera and photo library permission texts are now translated into all five languages, so the dialog says what it is for (a photo for the note of a day, or the calendar background) instead of falling back to Spanish.

## 0.9.8 · 2026-11-10

Private prerelease: a clearer job list.

- First use: "What do you do?" is now a single list, one job per row with its usual hours underneath, and only the one you pick gets a check, so it is clear you choose just one.
- Every list where you pick one option (language, appearance, town, holidays, currency, reports) keeps the chosen option the same size, only in bold, and screen readers now read it as one option of a group that you can select.

## 0.9.7 · 2026-11-09

Private prerelease: aligned choices everywhere.

- Every group of choice pills (jobs, periods, years, categories, swap shifts...) now lines up in an even grid with equal cells and level rows, and no word breaks inside a pill.
- Widget: a change made just before leaving the app (for example finishing the first use) now reaches the widget at once instead of on the next opening.
- Month: in dark mode the chosen half of "Grid | List" is now filled with the accent colour, so you can tell which one is selected at a glance.
- Month: in the List there is now a small gap between the last visible row and the floating "Paint" button, so a row cut by the edge never looks hidden under it.

## 0.9.6 · 2026-11-08

Fixes from the 0.9.5 QA.

- The rotation start choices now go two per row on 360 dp phones too, and no word breaks with large text: each cell is sized to its longest name or hours, and the check sits on the shift badge.

## 0.9.5 · 2026-11-08

Private prerelease to try the aligned choices on a phone.

- When you set up a rotation, the shift and day choices line up in a tidy grid (two per row on a phone) with the hours under each name.

## 0.9.4 · 2026-11-08

Private prerelease to try the square shapes on a phone.

- Everything is square now: shift badges, paint tools, colour swatches, icon buttons and icon tiles are rounded squares instead of circles, matching the buttons.

## 0.9.3 · 2026-11-08

Tweaks from using 0.9.2 on a Redmi Pad. Release for Google Play, GitHub and the web.

- Month: with touch, the day the app keeps in focus (today, after switching Grid and List) no longer shows an extra purple frame; it only shows when you use a keyboard.
- Buttons, filter chips, the calendar switcher, the «Paint» button and the selected-destination highlight are now rounded rectangles instead of pills, matching the «Grid | List» control.
- First use with a rotation: the country, community and municipality are now asked before the rotation, so the preview ("Así quedará") already starts the week on the day of the country you chose (it showed Sunday-first weeks to a Spanish user on a phone set to the US).

## 0.9.2 · 2026-11-07

Fixes from testing 0.9.1 on a OnePlus 10 Pro and a Redmi Pad, checked again on the phone and on the tablet emulator.

- Month: the system back button now leaves Paint mode instead of closing the app.
- Settings › Calendars: an archived calendar can now be deleted for good, after a confirmation and an automatic backup.
- Basque holiday names follow the official calendar of the Basque Government (Urte Berri eguna, San Jose, Ama Birjinaren Jasokundea, San Joan).
- Tablets in landscape with large text: the side navigation bar keeps its four names instead of showing icons only.
- Holidays: every Spanish holiday name (regional, island and local, such as San Juan) is now translated into Catalan, Galician, Basque and English.

## 0.9.1 · 2026-11-07

Fixes from testing 0.9.0 on the phone and tablet emulators.

- First run: the job is now asked above the rotation list, so the usual rotations of your job (Police, Firefighters…) already come first when you choose one.
- Month with large text: “Select days” no longer runs under the Paint button, and the bottom bar keeps its tab names.
- Holiday names no longer mix languages: countries other than Spain always show their own local names, whatever the app language.

## 0.9.0 · 2026-11-07

Money, breaks and more rotations, from a review of the leading shift apps. Release for Google Play, GitHub and the web.

- Summary: the estimate now breaks down the night and holiday premiums, fixed allowances and extra amounts.
- Settings › Hours and money: allowance templates for public healthcare, firefighters and security guards that fill in the allowance types of your shifts (amounts start at 0; you type yours).
- Settings › Hours and money: a closing day for your pay month (paid from the 21st to the 20th? set 20), used by the summary, the year table, the hours bag and “earned so far”.
- Settings › Hours and money: an overtime cap per month or year, with a warning in the summary from 80 % of the cap, at the cap and above it.
- Vacation and leave: a balance can count working days only (Monday to Friday, without the holidays of your calendar).
- Appearance: five more accent colours (Violet, Plum, Emerald, Olive and Terracotta) and a “Fondo negro” switch for OLED screens in dark mode; both are saved in the backup.
- Holidays: official holidays for 19 more countries: Guatemala, Bolivia (with its departments), Paraguay, Panama, Costa Rica, Dominican Republic, Honduras, El Salvador, Nicaragua, Cuba, Poland, Sweden, Norway, Denmark, Finland, Luxembourg, Greece, Romania and Andorra.
- Shift types: new optional break alert, off by default and suggested for shifts of 8 hours or more. It says “Toca pausa” halfway through the shift (the longer part of a split shift) or a set time after it starts, stays silent on days with an absence, a removed shift or “Sin alarma este día”, and follows the alarm switch, Do Not Disturb and silent mode.
- New ready-made rotations: “Policía Nacional 2-2-2-6” and “Guardia 1-4” (a 24 h shift and 4 days off), grouped under Police and Firefighters and offered first for those jobs in the first run. The 24 x 72 rotation now says it is also known as 1-3.
- Play listing and website now say up front that everything is free: no Pro, no ads, no account, and nothing to pay again on a new phone.
- Website: new FAQ “How do I move Turnly to a new phone?” with the four ways (direct transfer, encrypted Google backup, .turnly file, automatic folder backup).
- Settings › Alarms now shows each shift type's break alert and when it rings.
- Allowance templates no longer write a night premium on shift types without night hours.
- The custom time wheel for the break alert and the alarm lead shows hours and minutes consistently, and input hints no longer look like typed text.

## 0.8.9 · 2026-11-05

Tablets and busy days, from testing on a real phone and tablet. Release for Google Play, GitHub and the web.

- Tablets in landscape: Rotación, Agenda and Resumen now keep the side navigation bar of the month, so you can move between the four screens without going back.
- Month: the week of a day with four shifts or more is no longer more than twice as tall as the others; the row takes just the room its bands need, also with large text.
- Adding a work shift to a day that only has “Libre” (“Añadir otro turno” while painting, or “Añadir turno” in the day's detail) now replaces “Libre” instead of stacking it. Days with several shifts, and absences, are left as they were.

## 0.8.8 · 2026-11-05

A first-run fix found in testing on a real phone and tablet. Release for Google Play, GitHub and the web.

- First run: after changing the language on the first screen, the little drawings of the three ways to start show the shift codes of the new language straight away.

## 0.8.7 · 2026-11-05

A clearer screen to delete everything and start over.

- Settings: the “Borrar todo y empezar de cero” screen is clearer, with an icon per item, a note on what stays and the backup's date.

## 0.8.6 · 2026-11-05

The Google backup of Android only takes Turnly end-to-end encrypted. Release for Google Play, GitHub and the web.

- Android: Turnly only goes into the Google backup end-to-end encrypted with your screen lock, so neither Google nor anyone else can read your shifts, notes, absences (sick leave included) or attachments. Without a screen lock, Turnly is left out of the Google backup (use the automatic backup to a folder or a .turnly file); moving straight from your old phone to a new one works as before. On Android 7 and 8, Turnly no longer uses the system backup.

## 0.8.5 · 2026-11-04

A way to delete everything and start again, with a backup first.

- Backups: fix the restore label's date wording, including “de hoy” in Spanish.
- Settings: “Borrar todo y empezar de cero” deletes everything and takes you back to the first run, after saving a backup you can keep somewhere else. That backup is kept apart from the automatic ones, so it is never rotated out.

## 0.8.4 · 2026-11-04

First-run fixes found on a real phone, and a cap on very busy days in the month view.

- First run: picking your country now sets the first day of the week and the currency of that country on a new installation, and changing the country later updates them, unless you had already chosen them yourself in Settings.
- First run: the rotation you are setting up shows each shift's name and code in the language you picked on the first screen, even before the roster is finished.
- First run and «Aplicar patrón» now ask for the day of the cycle in one shared, clearer way: choose the shift that day has (with its colour, code and hours), and if that shift repeats in the cycle the question names it («Tarde se repite: ¿qué día te toca?») and you pick «Día 2 de 5». When the shift has several runs, each option says which one («Tanda 2 · Día 1 de 2, después de Libre»), so there is nothing to count. The numbered whole-cycle grid stays one tap away under «Ver el ciclo completo», and a live month preview, in the app language, shows the result before you apply it.
- The job pills of the last step of the first use now have the same rounded shape as the rest of the choices.
- Month view: a day with four or more shifts shows two of them and “+N”, so its week row no longer grows without limit.

## 0.8.3 · 2026-11-03

Same app as 0.8.2, now signed with the same key on Google Play and on GitHub.

- Android: the Google Play version and the APK from GitHub now have the same signature, so you can switch between them without uninstalling and without losing anything. If you installed Turnly from Google Play before 0.8.3, uninstall it once (export a backup first) and install it again.
- Android: the two GitHub APKs and the Google Play version share one version number (2007 for 0.8.3).

## 0.8.2 · 2026-11-03

Release candidate for Google Play (closed test) and the public GitHub release. It updates 0.8.1 without losing anything.

- READMEs and screenshots updated for 0.8: the five READMEs now describe the new features, and the readme and store screenshots show the current UI, with two new ones (vacation and leave balances, and the shift-changes book).
- Catalan: the swap book balance says «Em deu» instead of «Em deve».
- Android: «Silence the phone on my shifts» really silences the phone: it was asking Android for the wrong mode, so the phone kept ringing, and the permission card could show the wrong current mode.
- Android: «Silence the phone on my shifts» now starts and ends on time on phones that delay alarms (OnePlus, Oppo, Realme…); the clock may show it as the next alarm.

## 0.8.1 · 2026-11-03

Internal test build (private prerelease). It updates 0.8.0 without losing anything.

- Catalan, Galician, Basque and English: the new texts of 0.8.0 reviewed (wrong words in Basque, Spanish forms in
  Catalan, broken sentences in Galician, first person in the shift-changes book).
- Vacation and leave: the days carried over from last year are spent before the year's own, and only the carried days still left to spend expire on their date, so a balance can no longer go negative; and two absences of the same series on one day now count as a single day.
- Vacation and leave: when creating a balance you can continue the series of the year before (it copies its name, its types and its cap), and any balance has a «Copy to the next year» action that sets the series up once and repeats it year after year.
- Shift changes book: writing down a change with only one side («I owe them» or «They owe me») no longer shows a balance of 0, and taking a change back from the calendar no longer wipes the note, the extra hours or the extra amount added to the day after it was applied.
- After restoring a backup, the shift-changes book and the tasks' undo no longer hold on to the data from before the restore and overwrite what was just restored; undoing a day's tasks is now all-or-nothing.
- Hours and money: the hours bank counts from the day you set your goal, so a note or a shift from years ago no longer drags months of debt into this month.

## 0.8.0 · 2026-11-02

Internal test build (private prerelease). It updates 0.7.1 without losing anything. The new texts in Catalan, Galician
and Basque still have to be reviewed.

- Opening a big backup from another app, or reading one from the backup folder, no longer risks closing Turnly (the file is streamed to disk instead of held in memory); a restore now tells you when the copy it made beforehand had to leave attachments out, a copy says so when it could not include some, and a restore stops (changing nothing) if an attachment's file exists but cannot be read right now, instead of deleting it.
- Backups that carry attachments (photos, drawings, PDFs) now import, restore and copy to the folder or iCloud even when they are bigger than 8 MB (up to 137 MB); an attachment whose file was lost no longer blocks the automatic copy, the copy made before a restore or the restore itself.
- Vacation and leave (Settings): a balance per year and type (vacation, personal days...) with the days allowed, the ones carried over from last year (with the day they expire), manual adjustments, the ones taken and the ones planned, and in big how many you have left. It warns when carried days are about to expire or when you planned more than you have. The Summary shows a «You have N days of vacation left» card that opens it.
- Hours and money: each shift type can have a night plus and a holiday plus per hour and a place (which shows in the PDF and CSV reports); each day has an «Extra amount» in «More options» (allowances, mileage, a bonus, or a negative deduction) that counts in the estimate and the reports.
- Settings › Hours and money › Withholding (%): the Summary then shows the estimated net pay beside the gross. It also shows «Earned so far» this month, a «Quarter» view (Q1 to Q4) next to month, year and dates, and the hours bank (hours worked minus your goal, month by month) under the goal.
- Shift changes book (Settings › Shift changes): the balance of every colleague («They owe me 2 shifts», «I owe them 1 shift») with the ones still pending first, the list of changes with their state (pending, returned, settled) and the shifts on each side, and a sheet to write one down (who, who owes it, the day you give the shift and the day you get it back, the shifts of each side and a note). A change can be marked as returned or settled, applied to the calendar (the day you gave loses the shift and the day you receive gets it) and taken back with a single undo. The day detail has a «Shift change» section under «More options».
- Day notes: under «More options» in the day detail there are now «Attachments» and «Tasks». Attachments keeps the photos, the drawings and the files of that day as a strip of thumbnails; you can add a photo (camera or gallery) or any file, draw a sketch (pen, eraser, undo and redo, with a few colours) and open any attachment full screen. A long press (or «Remove» in the full screen) takes it off the day, and the «Undo» next to the strip brings it back. Tasks is the checklist of that day: write one, tick it, move it up or down and delete it, with a single undo for the last change.
- Do not disturb during the shift (Settings › Alarms, Android): a switch per shift type in «My shifts» silences the phone while that shift works, the global switch and the interruption filter («priority only», «alarms only» or total silence) live in Settings › Alarms, and it explains and opens the system's Do Not Disturb access when it is missing.
- Comparing calendars: the screen now takes from two to six calendars (you pick them in a sheet, each one with its colour), the grid has one row per calendar and one column per day (the days scroll sideways, the column of names stays put), and the summary adds the weekends you are all off.
- Appointments of your phone (Settings › «Appointments of the phone»): choose the phone calendars you want to see next to your shifts (the permission is explained and only asked when you accept it), the month marks the days that have appointments, the day detail lists them with their time, and the Agenda shows them next to your notes. Turnly only reads them: it never writes or changes anything in your phone's calendars.
- Appearance › «See the note in the month»: the first line of a day's note is written in the month cell when the day number leaves it room (on a phone the small clip of always stays).
- Appearance › «Sound when painting»: a soft click of the system when you paint a day, off by default and keeping the silent mode.
- Appearance › «Ready-made palettes»: five colour sets for your shift types, applied to them all in one tap with a single undo, each passing AA contrast.
- Appearance › «Calendar background picture»: pick one from your gallery and it shows behind the month under a veil of the background colour (the day cells keep their opaque background and their contrast), with a way to remove it. The picture stays on your phone: a backup carries the setting but not the file.
- Android widget «Four weeks» (4×4): a month by weeks from Monday (28 days) with the number, the shift and the first line of the note of each day, plus the next day off of today on top; it stays honest at midnight without opening the app, and a day of health never shows its note text.
- Wave 3 visual pass: in the shift changes book the shifts of a change are chips with their colour, code and hours (in the sheet too), the state badge lines up with the first line and the empty and footer buttons are the same one; «Do not disturb» has a shorter title and its notice reads as one more settings row; the compare grid keeps its free-day marks off the day number and does not repeat the free-days idea three times; and the agenda gives an appointment the same text weight as its note and shift.

## 0.7.1 · 2026-11-01

Internal test build (private prerelease). It updates 0.7.0 without losing anything.

- «Select days» under the month is a real button (icon, border and full-contrast text) instead of a faint link.
- The whole month now fits on the screen without scrolling, in the month and in paint mode: the Today card starts folded when the month would not fit with it open (your own choice still wins), the six rows end above the fixed row and the «Paint» button never covers a day, and the paint sheet takes only the height the month leaves (only the shift buttons scroll). The paint header is one line and the shift hours moved to the preview line. The «Pick a shift and drag» tip now shows inside the paint sheet the first time you paint.

## 0.7.0 · 2026-11-01

Internal test build (private prerelease). It updates 0.6.17 without losing anything (checked on the emulator by
upgrading from 0.6.13).

- Avoid a widget sync error when closing the app while a snapshot is still being prepared.
- Redesign chosen by the user on 31-oct: month with a named bottom bar (Month · Rotation · Agenda · Summary), a foldable
  Today card and a remembered Grid/List switch; paint modes «Change the shift | Add another shift» with a live preview;
  day detail in layers (as tall as its content, Undo, a menu per shift, «More options»); first use in three paths
  (import, rotation, paint by hand, or restore a backup) with country and job in an optional last step; Summary with
  a «How am I doing?» card; Settings in five groups with their status; a widget gallery with your real shifts;
  illustrated empty states.
- Shift alarms no longer run out: they are scheduled 30 days ahead, renewed in the background on Android, a notice the
  evening before the last one asks you to open the app, and Settings › Alarms shows «Alerts scheduled until…».
- Editing a shift's hours or pay asks whether to fix every day or apply it only from today, so months you already
  worked keep their hours and pay.
- Summary: past days count as worked and upcoming ones as planned; overtime and early leave also adjust night and
  holiday hours; optional yearly or monthly hours goal with the difference.
- The Today card and the widget show your next day off, the next free weekend and your streak of work days; «Compare
  calendars» no longer counts days with nothing filled in as shared days off.
- Public holidays depend on your country: official holidays of 21 more countries (Latin America, Portugal, Brazil,
  Europe, the US and Canada) with a state/province picker, and «Other country: no public holidays». Spain: local
  holidays of all 50 province capitals, Ceuta and Melilla, every municipality of Murcia from the official labour
  calendar, and the Canary Islands' island holidays. Outside Spain the job list is neutral.
- Time format (automatic, 24 h or 12 h), regional dates and week start, and the currency are now settings.
- Accent colour (Indigo, Blue, Teal, Raspberry, Graphite) and a bigger shift code and time in the month cells.
- The month header and the summary have a report button: a PDF or CSV of a month or any dates, ready to share.
- «Keep up to date» keeps your phone calendar in sync with your shifts; shifts can also be saved as an .ics file.
- Android: automatic daily backup to a folder you choose (Drive, Dropbox, OneDrive or the phone), keeping the last 10
  copies, with clear warnings if the folder or its permission is lost.
- Share your shifts by read-only link and QR code (built, switched off until the server is deployed).
- Database schema v6, ready for note attachments, day tasks, the swap ledger, leave balances, shift locations, hourly
  night/holiday pluses and per-day extra amounts.
- The FAQ answer on double shifts explains the new «Añadir otro turno» painting mode.

## 0.6.17 · 2026-10-30

Internal test build (private prerelease). It updates 0.6.16 without losing anything.

- Turnly has its own website, [turnly.mainshai.com](https://turnly.mainshai.com), in the app's five languages, with
  downloads, screenshots, FAQ and the full privacy policy.
- The privacy policy link in Settings opens the policy on the new website (`turnly.mainshai.com/privacy/`) instead of
  GitHub Pages.
- The support email is now `turnly@mainshai.com` (in Help and contact, the privacy policy and the READMEs).

## 0.6.16 · 2026-10-30

Google Play closed test (with the 0.6.13 to 0.6.15 changes).

- The privacy policy link in Settings opens its new address, `dferrandizmont.github.io/turnly`, after the GitHub
  repository was renamed to `turnly`.

## 0.6.15 · 2026-10-30

Internal test build (private prerelease). It updates 0.6.14 without losing anything.

- The app is now called **Turnly** (formerly Cuadrante): app name, widgets and texts in all five languages. Backups are
  saved as `.turnly`, and older `.cuadrante` backups still open. Calendar exports are marked "Creado con Turnly", and
  events exported before are still recognised.
- The READMEs follow the common template: English is now the main `README.md`, with Spanish, Catalan, Galician and Basque versions, and the build and test instructions move to `CONTRIBUTING.md` and `CONTRIBUTING.es.md`.

## 0.6.14 · 2026-10-29

Google Play closed test (with the 0.6.13 changes) and APK on GitHub.

- Android: shift alarms are now system alarm clocks, so battery saver and phone makers can no longer delay them;
  the next one shows as the next alarm (status bar icon and lock screen).

## 0.6.13 · 2026-10-28

Internal test build (private prerelease). The app ID is now `es.cuadrante.app`, so it installs as a new app next
to 0.6.12 test builds: export a `.cuadrante` backup from the old one and restore it in the new one.

- iPhone: texts no longer point to Android settings or to Drive (backup, calendar permission, alarm permissions), and
  "Snooze" on a shift alarm works with the app closed.
- The month's Grid / List switch is now a single segmented control with an icon and a label. When the list reads
  better (large text, or shifts that do not fit in the day cell), a dot next to "List" says so.
- Switching to the list now centres the day instead of leaving it under the "Paint" button.
- iPhone: the app name and the calendar permission texts in all five languages.

## 0.6.12 · 2026-10-27

First public release: Google Play closed test and APK on GitHub.

- Shift calendar with colour, code and time for every shift; paint mode and rotation patterns.
- Several shifts per day, several calendars and side-by-side comparison.
- Home screen widgets, alarms and reminders.
- National, regional and local public holidays, offline.
- Hours summary with night and holiday hours, overtime and hourly rate.
- Backups with "Test restore"; import from LRHSoft, the phone's calendar, `.ics` and CSV.
- In Spanish, Catalan, Galician, Basque and English; light and dark mode.
- Completely free and open source: no account, no ads, no purchases.
