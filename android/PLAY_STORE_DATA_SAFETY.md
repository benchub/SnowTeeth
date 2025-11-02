# Google Play Data Safety Form - SnowTeeth

This document provides the exact answers for filling out the Data Safety section in Google Play Console, based on our PRIVACY_POLICY.md.

## Overview Questions

### Does your app collect or share any of the required user data types?
**Answer:** YES (we collect location data)

### Is all of the user data collected by your app encrypted in transit?
**Answer:** N/A - We don't transmit data over network
(Note: Select "No" if this option is required, but add clarification that data is never transmitted)

### Do you provide a way for users to request that their data is deleted?
**Answer:** YES - Users can clear tracking sessions within the app to permanently delete all location data

---

## Data Collection Details

### Section 1: Location Data

#### Data Type: Precise location
**Collected:** YES

**Is this data collected, shared, or both?**
- ☑ Collected
- ☐ Shared

**Is this data processed ephemerally?**
- ☐ Yes (Note: We store it locally, so not ephemeral)

**Is this data required or optional?**
- ☑ Required (core functionality requires location)

**Why is this user data collected?**
Select all that apply:
- ☑ App functionality - Location tracking is the core feature
- ☐ Analytics - NO
- ☐ Developer communications - NO
- ☐ Advertising or marketing - NO
- ☐ Fraud prevention, security, and compliance - NO
- ☐ Personalization - NO
- ☐ Account management - NO (no accounts)

---

### Section 2: Approximate Location
**Collected:** NO

(We only collect precise location, not approximate)

---

## Data Types NOT Collected

For all other data types, answer **NO**:

### Personal Info
- ☐ Name
- ☐ Email address
- ☐ User IDs
- ☐ Address
- ☐ Phone number
- ☐ Race and ethnicity
- ☐ Political or religious beliefs
- ☐ Sexual orientation
- ☐ Other info

### Financial Info
- ☐ User payment info
- ☐ Purchase history
- ☐ Credit score
- ☐ Other financial info

### Health and Fitness
- ☐ Health info
- ☐ Fitness info

### Messages
- ☐ Emails
- ☐ SMS or MMS
- ☐ Other in-app messages

### Photos and Videos
- ☐ Photos
- ☐ Videos

### Audio Files
- ☐ Voice or sound recordings
- ☐ Music files
- ☐ Other audio files

### Files and Docs
- ☐ Files and docs

### Calendar
- ☐ Calendar events

### Contacts
- ☐ Contacts

### App Activity
- ☐ App interactions
- ☐ In-app search history
- ☐ Installed apps
- ☐ Other user-generated content
- ☐ Other actions

### Web Browsing
- ☐ Web browsing history

### App Info and Performance
- ☐ Crash logs
- ☐ Diagnostics
- ☐ Other app performance data

### Device or Other IDs
- ☐ Device or other IDs

---

## Privacy Policy

### Privacy policy URL
**Answer:** `https://github.com/benchub/SnowTeeth/blob/main/PRIVACY_POLICY.md`

This displays the privacy policy in a clean, readable format on GitHub.

---

## Key Messaging Points

When filling out the form, emphasize:

1. **Local-only storage:** All location data stays on the device
2. **No third-party sharing:** Data is never transmitted to servers or third parties
3. **User control:** Users can delete all data by clearing sessions
4. **No tracking:** No advertising, analytics, or cross-app tracking
5. **Purpose:** Location used solely for activity tracking and statistics

---

## Data Safety Section Preview

This is what users will see in the Play Store:

**Data safety**

> The developer says this app collects:
>
> **Location**
> - Precise location
>
> This data is used for:
> - App functionality
>
> This data is:
> - Not shared with third parties
> - Stored locally on your device
> - Can be deleted by the user

---

## Important Notes

1. **Be honest and accurate** - Google can reject your app if data safety info is misleading
2. **Keep it updated** - If you add analytics or crash reporting later, update this form
3. **Match your privacy policy** - Ensure consistency between this form and PRIVACY_POLICY.md
4. **No optional data** - We don't collect any optional data types (no email, name, etc.)

---

## Testing Note

Before submitting, verify:
- [ ] Privacy policy is hosted and accessible
- [ ] App actually behaves as declared (no hidden data collection)
- [ ] Data can be deleted (test clearing sessions)
- [ ] No third-party SDKs that collect data

Currently clean: ✅ No Firebase, no analytics, no ad networks
