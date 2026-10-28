# Cropin Grow: Offline Voice Agents (Flutter)

A Flutter Android app that adds four **offline, multilingual voice agents** to the Cropin Grow field app.
It supports **English, Hindi, Kannada and Tamil**, with Kannada and Tamil as the demo languages.
The UI reuses the Cropin Grow look: dark-teal header, green search button, advisory cards, plot cards and the bottom navigation.

## Download the APK

Every push runs the **Build APK** GitHub Actions workflow, which attaches the APK to a GitHub release:

- Latest APK: <https://github.com/Prakhar-30/Cropin-voice-agents/releases/latest/download/cropin-voice-agents.apk>
- All builds: <https://github.com/Prakhar-30/Cropin-voice-agents/releases>

# Add Farmer Voice Assist (first draft)

This branch (`claude/add-farmer-voice-assist`) is a single-screen build: the app opens on **Add Farmer**, field for field as in Cropin Grow, with a voice assistant that fills it in a **conversation** instead of one long dictation.

APKs for this branch: release tags `add-farmer-v1.0.<run>` on <https://github.com/Prakhar-30/Cropin-voice-agents/releases>, file `cropin-add-farmer-voice.apk`.

## How the conversation works

1. Tap **Talk** on the Voice Assist row. The mic opens straight away; the prompt is shown on screen, not read out. A panel docks above Save Draft / Submit, so the form stays visible and fills as you talk.
2. **Say everything you have, in any order, about any field:** "Ramesh Kumar, 98450 12345, village Hosakote, PIN 562114, male, Aadhaar 1234 5678 9012, Canara Bank". All of it is filled. This works in any of the four languages and in either word order ("…, धान प्रोजेक्ट"). The opening answer allows 4-second pauses so you can think of the next detail.
3. **Then it guides you through what's left**, with **Fill manually** offered at every step. It first asks for each missing required field, one at a time (name → mobile → project). Required fields can't be skipped.
4. **Optional fields are offered, not interrogated:** "The required details are done. 22 optional fields are still empty: personal details, address and bank details. Would you like to fill any of them, or shall I submit?" Pick a section (or "all"); inside it the agent asks field by field. "Skip", "no" or "छोड़ो" leaves a field; "that's all" ends the section.
5. **Address** starts with "Shall I fill the address from your current location?", which fills country, state, district, city, taluka and PIN. Then it asks for village and landmark.
6. **Summary and confirmation** before saving: "Ramesh Kumar, 98450 12345, Paddy Sustainability, and 6 more details. Shall I submit?" Answer Yes / "No, change something" / Save draft.

At any point you can:
- **volunteer other fields by name**: "village Hosakote, PIN 562114";
- **correct** the last value: "no, 98450 12346";
- say **go back**, **repeat**, **stop**, **save draft** or **submit**;
- tap an **option chip** instead of speaking;
- **switch language** from the panel.

**Dropdowns** (Project, Gender, Contractor, Area unit, Language, Country, Location):
- The question names two examples, and all options show as chips.
- Answers match by name or by alias in any of the four scripts (धान → Paddy Sustainability, ಕಬ್ಬು → Sugarcane Yield Plus).
- They also match by position ("the second one", "दूसरा") or by part of a name.
- An ambiguous answer gets "Did you mean Kharif Chilli 2026 or Groundnut Kharif 2026?". An unknown one gets the list of options.

**Values are checked and read back:**
- Mobile numbers are read back digit by digit, and Aadhaar / account numbers by their last 4 digits.
- A wrong digit count is caught ("I heard 9 digits…").
- Dates of birth are understood as "15 August 1980", "उन्नीस सौ अस्सी" or just an age.
- Email is understood when spoken ("ramesh at gmail dot com").
- PAN and IFSC are understood when spelled letter by letter, in English, Hindi, Kannada or Tamil letter names.

**Answer timing:**
- The agent speaks its question and only then opens the microphone.
- An answer ends after 2.75 s of silence or a tap on the mic.
- Silence twice in a row pauses the agent.

### Why this flow
- **Slot filling with elicitation** is the standard dialog pattern ([Alexa dialog management](https://developer.amazon.com/en-US/docs/alexa/custom-skills/dialog-interface-reference.html)). Prompt only for missing required slots, then confirm once for the whole record. [Amazon's guidance](https://developer.amazon.com/en-US/blogs/alexa/alexa-skills-kit/2018/05/build-advanced-alexa-skills-confirm-what-customers-want-with-dialog-management) warns that confirming every slot doubles the number of questions, so this flow confirms implicitly by reading values back and asks once at the end.
- **Lists:** [Google's conversation design](https://developers.google.com/assistant/conversation-design/list) suggests 2–10 options and not reading whole lists aloud. That's why the agent speaks two examples and shows every option as a chip.
- **Fill only what was said:** voice form fillers in CRMs, such as [Sage Copilot "Forms by Voice"](https://support.forcemanager.net/en/articles/11623506-intelligent-voice-reporting-fill-in-forms-with-sage-copilot) and [Pega Voice AI](https://academy.pega.com/topic/best-practices-using-form-autofill/v1/in/64911), fill only the fields a person actually mentions. This agent does the same, and also asks for the rest.
- **Agriculture:** voice agents for farmers mostly do advisory, e.g. [Farm Vaidya in Telugu and Tamil](https://www.ondial.ai/blog/ai-voice-agents-for-farmers-daily-use). Structured capture of location, crop and acreage by voice is the pattern [insurance agents use](https://aigrants.in/topics/farmer-insurance-voice-agents). [Assisted Farmer ID registration](https://news.desikheti.com/farmer-id-explained-meaning-benefits-and-how-to-apply/) is done by local helpers today. A field officer's assistant that asks questions is the gap this fills.

Code: `lib/farmer_form/` (field definitions, value parsers, `FarmerFormAgent`) and `lib/screens/farmer_form_screen.dart`. Tests: `test/farmer_agent_test.dart`.

---

The rest of this README describes the full multi-agent app this branch was cut from.

## The four agents

| # | Agent | Where | What it does |
|---|-------|-------|--------------|
| 1 | **Speak-to-fill forms** | Add Farmer, Add Asset (mic row, FAB or app-bar mic) | One utterance fills name, mobile, project, owner, soil, irrigation, area and unit. Dropdown values are fuzzy-matched across scripts, so "laal mitti", "ಕೆಂಪು ಮಣ್ಣು" and "செம்மண்" all become *Red Soil*. Fields are highlighted green (confident) or amber (please check, with what was heard), and words that couldn't be mapped are listed. If a farmer utterance also describes a plot, the app offers to create the plot next. |
| 2 | **Voice notes on photos** | Take Photos | Tap **Take Photos** and the shutter to take photos (no voice command; photos are always taken by tap). Then tap **Record comment** on a photo and speak; recording stops on Done or after 2.75 s of silence and becomes that photo's comment. **Note all** records one note for the selected photos (or the whole batch). Each note is auto-tagged with the issue type, % affected and landmarks such as a borewell. |
| 3 | **Raise alert by voice** | Raise alert (or say it on Home) | "Raise pest alert on the chilli plot here, high severity" → alert type, severity and crop; GPS ticks the **nearest matching plot**. Say "… on **all** chilli plots in BTM" (or name a farmer / locality) to tick **every matching plot** and raise one **common alert** for all of them. There's also a **Select all** checkbox for the plots currently shown in the list. |
| 4 | **Voice search & "What's my day"** | Mic in every search bar; Home "Ask anything" / "What's my day?" | "Show my 2-acre chilli plots in BTM that need attention" returns a filtered list with filter chips. "What's pending today?" reads out overdue and due-today tasks, nearby visits, Crop Health attention counts and the weather advisory, in the chosen language. |

The Home mic is a router: one utterance goes to the right agent (add farmer, add asset, raise alert, photos, search or briefing).

## How it stays offline

* **Speech → text**: the app's own offline recogniser, built on [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx):
  * the microphone streams 16 kHz audio into [Silero VAD](https://github.com/snakers4/silero-vad) on a background isolate. Each stretch of speech is decoded as soon as a short pause ends it, and the command ends after **2.75 s of silence** or **Done**. That gives one continuous recording, with no beeps and no Google language packs;
  * models: [AI4Bharat IndicConformer](https://huggingface.co/parismitaglobalsolutions/indicconformer-sherpa-onnx) (CTC, int8) for Hindi, Kannada and Tamil, about 190 MB each, and NeMo conformer-small for English, about 45 MB;
  * each language's model downloads once, inside the app, from this repo's [`speech-models-v1`](https://github.com/Prakhar-30/Cropin-voice-agents/releases/tag/speech-models-v1) release. Downloads resume if interrupted, and you manage them in *Voice settings* or from the prompt in the voice sheet. The `Speech models` workflow mirrors the files there;
  * until a language's model is downloaded, Android's recogniser (`speech_to_text`, on-device when its pack is installed) is used as a fallback.
* **Understanding (NLU)**: fully on-device and rule-based, in `lib/voice/nlu/`:
  * **N-best rescoring**: every alternative transcript the recogniser returns is parsed, and the one that fills the most slots with the fewest unknown words wins ([Ganesan et al., ACL 2021](https://arxiv.org/abs/2106.06519); [Sun et al., 2023](https://arxiv.org/abs/2311.07418));
  * **phonetically weighted edit distance**: vowel swaps, dropped or added vowels and close consonants (r/l, n/m) cost less than other edits ([Raghuvanshi et al., EMNLP 2019](https://aclanthology.org/D19-3011/));
  * an Indic → Latin transliterator covering Devanagari, Kannada and Tamil, with Tamil voicing rules;
  * a phonetic key that ignores script, aspiration, voicing, vowel length and double letters;
  * a fuzzy phrase matcher that handles agglutinative suffixes (ಜಮೀನಿನಲ್ಲಿ → ಜಮೀನು, வயலில் → வயல்);
  * number parsing for digits, native digits and number words in all four languages, including "double nine", mobile numbers read in pairs ("ninety eight forty five …"), ಎರಡೂವರೆ, இரண்டரை and डेढ़;
  * slot parsers for forms, alerts, search and photo notes, plus an intent router.
* **Text → speech**: the on-device TTS voices through `flutter_tts`.
* **GPS** works offline. If there's no fix, or the phone is far from the demo plots, the app falls back to a demo location in BTM Layout, Bengaluru. You can change this in *Voice settings*.
* **INTERNET** is used only to download the voice models. No audio or text ever leaves the phone.

## Demo data

The app ships with 8 projects, 28 farmers, 30 plots, 28 tasks (due relative to today), 2 alerts and 3 advisories. The data is set around Bengaluru, Mysuru–Mandya, Hosur–Krishnagiri, Coimbatore and Patna. See `lib/data/demo_data.dart`.

## Try these

| Language | Speak-to-fill (Add Farmer) | Raise alert | Search |
|---|---|---|---|
| English | Ramesh Gowda, 98450 12345, project Kharif Chilli, red soil, drip irrigation, 2 acres | Raise pest alert on the chilli plot here, high severity | Show my 2-acre chilli plots in BTM that need attention |
| ಕನ್ನಡ | ಹೆಸರು ರಮೇಶ್ ಗೌಡ, ಮೊಬೈಲ್ 98450 12345, ಖಾರಿಫ್ ಮೆಣಸಿನಕಾಯಿ ಪ್ರಾಜೆಕ್ಟ್, ಕೆಂಪು ಮಣ್ಣು, ಹನಿ ನೀರಾವರಿ, ಎರಡು ಎಕರೆ | ಇಲ್ಲಿನ ಮೆಣಸಿನಕಾಯಿ ಜಮೀನಿನಲ್ಲಿ ಕೀಟ ಬಾಧೆ, ತೀವ್ರತೆ ಹೆಚ್ಚು | ಬಿಟಿಎಂ ನಲ್ಲಿ ಎರಡು ಎಕರೆ ಮೆಣಸಿನಕಾಯಿ ಜಮೀನು ತೋರಿಸಿ |
| தமிழ் | பெயர் முருகன் செல்வம், மொபைல் 94430 56789, காரீப் மிளகாய் திட்டம், செம்மண், சொட்டு நீர் பாசனம், இரண்டு ஏக்கர் | இங்கே உள்ள மிளகாய் வயலில் பூச்சி தாக்குதல், தீவிரம் அதிகம் | பிடிஎம் பகுதியில் கவனம் தேவையான மிளகாய் நிலங்களை காட்டு |

## Project layout

```
lib/
  main.dart
  theme/app_theme.dart            Cropin Grow colours
  data/                           models, demo data, in-memory store + search
  services/                       speech (sherpa-onnx engine, model downloads,
                                  Android fallback), TTS, GPS
  voice/
    agent_language.dart           EN / HI / KN / TA
    agent_strings.dart            localised agent replies + example utterances
    nlu/                          offline NLU engine (see above)
  widgets/                        top bar, voice sheet, voice-aware fields, cards
  screens/                        home shell + tabs, Add Farmer, Add Asset,
                                  Raise alert, Take Photos, Briefing, Voice settings
test/nlu_test.dart                parser tests for every example in all 4 languages
```

## Build locally

```bash
flutter create --platforms=android --org com.cropin --project-name cropin_voice_agents .
flutter pub get
flutter test
flutter build apk --release
```

The `flutter create` step only generates the missing Android Gradle scaffolding. The committed `AndroidManifest.xml`, which holds the microphone, camera, location and recogniser queries, is kept as it is.
