# Turnly privacy policy

Last updated: 17 November 2026 · version 2026-11-17

Courtesy translation. The Spanish version ([politica-privacidad.md](politica-privacidad.md)) is the one that
applies.

Turnly is a shift-work calendar app for shift workers in Spain. It is an independent app: not created, reviewed
or endorsed by any company, public body or union.

Summary: **you have no account, there is no server of ours and your shifts stay on your phone.** The app is entirely
free and open source, and sends no data or crash reports to anyone. The only things that can take your data off the
phone are the backups of your Google or Apple account and the files or calendars you choose to export, and you
control those. If you email us, the providers explained in “If you write to us” are involved in handling that email.

## 1. Data controller

- Controller: Daniel Mont Ferrandiz
- Contact email: turnly@mainshai.com

## 2. What data is processed

### Data that stays on your phone (we never receive it)
Your calendars, shift types, rotations, day changes, notes, reminders, overtime, absences (holidays, personal days,
leave and sick leave), public holidays, region and municipality, hourly rate and settings are stored only in a local
database on the device. Official holidays ship inside the app and everything works offline. There is no sync and no
copy on any server of ours.

**Your sick leave is health data.** We never receive it: there is no server, no analytics and no shared calendar.
Alarms do not ring on absence days, and a note reminder on an absence day does not show the note's text, so none of
that reaches the lock screen. Bear in mind, though, that:

- the today, week and month widgets show the day's shifts on your home screen, including an absence with the code
  and colour you gave it, and their screen-reader description names them. The agenda and two-week widgets only say
  "Absence". The text of your notes never goes to the widget;
- absences, sick leave included, are part of your backups (see below), like the rest of your shifts.

### Backups
The app makes **automatic backups on your own phone** and lets you **export a backup to a `.turnly` file**
(Settings › Backup; older `.cuadrante` backups can also be opened) to keep wherever you like or move to another phone, and restore it later. That file contains your
shifts, notes and absences, carries no identifier and is not encrypted; you keep and control it: the app only hands
it to the app you pick in the system share sheet. What you do with it afterwards (upload it to your cloud, send it by
WhatsApp or email...) is outside the app. When you open a `.turnly` or `.cuadrante` file, nothing is restored until you confirm.

**System backup.** On Android 9 or later, if Google backup is on and your phone has a screen lock, the system
periodically uploads the app's database, backups and attachments to your Google account, end-to-end encrypted with
that lock (neither Google nor we can read them). Without a screen lock, Turnly is left out of that backup. When you
set up a new phone, the system can also move the data straight from the old phone to the new one. On Android 7 and 8,
Turnly does not use the system backup. On iPhone, the database is part of the device backup (iCloud or computer).
You manage those backups with your Google or Apple account and can turn them off in the system settings; the app
sends nothing on its own and keeps no backup of its own in iCloud.

### Phone calendar
Only if you ask, and only at that moment:

- **Import** reads the events of the calendar you choose (or of an `.ics` or CSV file, or a backup from another
  shift app) to suggest shifts. They are read and grouped on your phone, and only what you accept is saved.
- **Export** writes your shifts (name, code and hours; never notes or amounts) to the phone calendar you choose.
  **If that calendar syncs with an account** (Google, iCloud, Exchange...), your shifts will also appear in that
  account: the system uploads them, outside the app's control. The screen warns you. Absences and days off are not
  exported unless you turn on their switches.

The calendar permission is requested when you start importing or exporting, never at launch, and the app does not
read or write the calendar in the background.

### Permissions
Besides the calendar, the app asks for **notifications** and **alarms and reminders** permission when you enable
shift alarms or a note reminder, so they ring on time and the widget changes day at midnight. If you decline, alarms
may ring late. It does not ask for location, contacts, photos, camera, microphone or general storage access, and the
published Android version has no network permission.

### Communications
The app transmits no shifts, identifiers or crash reports. It uses no purchases, ads or analytics. Errors are handled
on the device only.

**Store ratings.** Now and then, after you apply a rotation or paint days, Turnly may ask the store (Google Play or the
App Store) to show you its window to rate the app; the store decides whether to show it. You can also open Turnly's
store page from Settings › Help › “Rate Turnly”. For this the app uses the Google Play review library on Android and
the system feature on iPhone and iPad. Turnly only tells the store which app it is: it passes none of your shifts or
any other data of yours, and does not know whether you rated the app or what you wrote. You write your rating and
review in the store's window and Google or Apple receives them, with your store account and under their terms. To
decide when to ask, the app keeps on the phone the day you first opened it, how many days you have opened it, and how
many times, when and with which version it asked for a rating. These counters are not in the `.turnly` file and Turnly
sends them to no one; they sit in the app's database, so they only leave the phone inside the system backup, if you
have it on (see “System backup”).

If you tap "Privacy policy" in Settings › Help, this page opens in your external browser. The browser connects to
the website; Turnly sends it none of your shifts, notes or absences.

### Data NOT processed
- The app does not ask for or store your name, email, phone, ID number, date of birth or employer details.
- In the app and on the website there are no analytics, no ads, no personalised advertising and no cross-app
  tracking. Support email has its own section (“If you write to us”).
- We do not access your location, contacts, photos, camera or microphone.
- We do not receive your shifts, notes, absences or hours.

### If you write to us
"Help and contact" (Settings) shows you the support address to copy so you can write from your own mail app, with
the app version if you want to attach it. The app opens no mail client and sends nothing by itself. Do not send us
`.turnly` or `.cuadrante` backups or screenshots with real shifts, notes or absences: made-up data is enough to fix a
bug.

If you write to turnly@mainshai.com (or to dev@mainshai.com, the address of the first versions), we use your email
address, your name if you give it and what you tell us, only to reply and deal with your question. These providers are involved along the way:

- **Cloudflare** (Cloudflare, Inc., United States) receives the message at our domain and forwards it straight away.
  It does not keep the message, but it does keep a technical log of the forwarding (sender, recipient, subject, date
  and result). It keeps that log for the period its
  service sets; we have not been able to confirm that period or the options for deleting the log. If you ask us to
  delete your data, we will also pass the request on to Cloudflare and tell you the result. Cloudflare also
  processes the email in the United States.
- **Google** (Gmail; Google Ireland Limited) is the mailbox where we read your message, answer you and keep the
  conversation. Google may also process this data in the United States.
- **Proton** (Proton AG, Switzerland) keeps a copy of the messages we receive, as a backup. We do not reply from it.
- **Brevo** (Sendinblue SAS, trading as Brevo, France) sends our replies, so it processes their content, and keeps a
  log of each message sent (recipient, subject, date and whether it was delivered) and a copy of the reply (which may
  include your message, if it is quoted below it). Brevo also adds to each reply an invisible image (a pixel) that
  records whether you open it, and replaces the links with its own, which record whether you click them. We cannot
  remove this on the plan we use, so we have turned on Brevo's anonymous tracking: according to Brevo, it counts opens
  and clicks without linking them to your email address. Even so, when the image loads or you click a link, your mail
  program connects to Brevo's servers, which receive technical data such as your IP address. We do not look at or use
  that information. If you prefer to avoid it, block external images in your mail program and do not open the links in
  the reply. Copying them and pasting them into your browser does not help either, because they still go through
  Brevo: to go to a page, type its address yourself. The reply reads just the same.

We keep the conversation in Gmail, the copy in Proton, and the copy and the delivery log in Brevo for at most one year
after the last message of the conversation, unless we need to keep them longer to deal with a complaint or
claim. We run a clean-up every three months, and each one deletes whatever would turn one year old before the next clean-up. If we
stop using one of those services, we delete what is in it. If you ask us to delete your messages sooner, we delete
them from all three.

## 3. Purposes and legal basis

| Processing | Purpose | Legal basis (GDPR) |
|---|---|---|
| Shifts, notes, absences and settings on your phone | Keeping your roster, hours and alarms | We do not receive them: they stay on your device, under your control |
| Backups and exports | Not losing your data and changing phones | You make them; the services you use (Google, Apple, your cloud) have their own terms |
| Support emails | Answering your query and keeping the conversation for the period in “Retention” | Your request and our legitimate interest in handling it (art. 6(1)(f)) |

We make no automated decisions and build no profiles about you.

## 4. Who receives the data
The app transmits no data to third parties. If you rate the app in the store, Google or Apple receives your rating and
review directly, not us. If you export to a synced calendar or have system backup on, the recipient of that data is
your account provider (Google, Apple or another), on your behalf and under its terms.

If you write to us, the support email goes through these providers (details in “If you write to us”):

| Provider | What for | Where |
|---|---|---|
| Cloudflare, Inc. | Receiving and forwarding support email; technical forwarding log | United States |
| Google Ireland Limited (Gmail) | Support mailbox | Ireland; Google LLC may process data in the United States |
| Proton AG | Backup copy of the email received | Switzerland |
| Sendinblue SAS (Brevo), RCS Paris 498 019 298 | Sending the replies; delivery log and copy of the reply (at most one year after the last message, with a quarterly clean-up); open pixel and click links, with Brevo's anonymous tracking turned on | EU (France) |

We use an ordinary Gmail account, with no data processing agreement with Google: Google processes those emails under
its own terms.

## 5. International transfers
The app makes no data transfers. External services you decide to use (your mail, cloud, synced calendar, the
destination of an export or the store where you rate the app) are governed by their own terms.

For support email, Cloudflare and Google may process data in the United States. Cloudflare, Inc. and Google LLC are certified under the EU-U.S. Data Privacy Framework (European Commission adequacy decision of 10 July 2023); Cloudflare's data
processing agreement also includes standard contractual clauses. Proton is in Switzerland, which is covered by a European Commission adequacy decision. Brevo is a French company and, according to its documentation, hosts
the data in the European Union.

## 6. Retention

- **Data on your phone:** until you uninstall the app or clear its data from the system settings (and, where
  relevant, from your account's backups and the files you exported).
- **Support emails:** at most one year after the last message of the conversation, in Gmail, in Proton and in Brevo,
  with a clean-up every three months, unless we need to keep them longer to deal with a complaint or claim. Sooner if
  you ask us to (details in “If you write to us”). Cloudflare keeps its technical forwarding log for the period its
  service sets, which we have not been able to confirm; if you ask us to delete your data, we will also pass the
  request on to it and tell you the result.

## 7. Your rights

You can exercise your rights of **access, rectification, erasure, objection, restriction of processing and
portability** by writing to turnly@mainshai.com. We will reply within one month.

We do not receive the data stored on your phone, so we cannot see or delete it for you. You can delete it by
uninstalling the app or clearing its data from the system settings, and take it with you using "Export backup".

If you believe we have not handled your data properly, you can complain to the Spanish Data Protection Agency:
https://www.aepd.es

## 8. Minors

The app is meant for working people. It does not ask for age or collect personal data from anyone, minors included:
shifts and settings stay on the device.

## 9. Security
There is no server and no data transmission from the app. Automatic backups are kept in the app's private folder.
You control exported files and the backups of your Google or Apple account; Turnly's Google backup only happens
encrypted with your screen lock. The code is public and anyone can check what it does.

## 10. Changes to this policy

If what we do with data changes, in the app or in support email, we will update this page and the date above. If the change is significant
(for example, if an iCloud backup or any feature that sends data were ever added, which would only be enabled with
your consent), we will also tell you inside the app.

## 11. Contact

turnly@mainshai.com
