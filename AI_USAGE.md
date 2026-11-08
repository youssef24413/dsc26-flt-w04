# AI usage: dsc26-flt-w04

AI tools are allowed in this task. Fill in every section in your own words. This file is read by your Track Mentor, not by the grader.

## 1. Tools I used

I used Claude (Anthropic) in the chat app to help implement the Outbox class in `lib/data/outbox.dart` and improve the stop list UI (`StopTile`, `SyncBanner`, and `TawseelStopsApp`).

I also used FVM to run the required Flutter version and `flutter test` to verify the implementation locally.

## 2. My best prompts

1. I provided Claude with the full task description and my repository link, asking it to implement both Part A (Outbox) and Part B (Stop List UI) while following all the task requirements.
2. When `flutter test` failed with an error related to `lib/data/local_store.dart`, I shared the complete error output and asked Claude to identify the cause and suggest a fix.
3. I then asked Claude to provide the complete code for each modified file directly in the chat so I could review and copy the changes into my project instead of using a ZIP file.

## 3. One bug I found in AI-generated outbox or layout code, and how

The first response from Claude was a ZIP file containing only four files under `lib/`. When I extracted it over my existing `lib` directory, some original template files, including `local_store.dart` and `sample_data.dart`, were missing. I discovered this when I ran `flutter test` and checked the import errors. I restored the missing original template files and kept the generated implementation files. After that, all public tests passed.

## 4. Why 409 is a success, and why corrections are appended after an attempt

HTTP 409 is treated as success because it means the server already has the outcome, so sending it again is unnecessary. Removing the entry prevents the app from repeatedly trying to upload something that has already been received. If an entry has already been attempted, we append a correction instead of replacing the original because the server might have received the first request even if the response was lost. This keeps the original record intact and allows the corrected outcome to be sent as a separate entry with its own ID.