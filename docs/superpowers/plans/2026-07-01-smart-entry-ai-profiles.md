# Smart Entry AI Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-profile AI assistant configuration with Zhipu, DeepSeek, and OpenAI-compatible templates, plus less rigid local rule matching for smart entry.

**Architecture:** Store AI profiles as a versioned JSON payload in secure storage, with migration from the existing single-provider keys. Use one OpenAI-compatible chat-completions parser for all cloud providers, and inject active profile plus local rules into `SmartEntryParser`.

**Tech Stack:** Flutter, Riverpod, Flutter Secure Storage, `package:http`, `flutter_test`.

---

### Task 1: AI Profile Model and Secure Storage

**Files:**
- Create: `lib/features/smart_entry/models/ai_assistant_config.dart`
- Modify: `lib/features/smart_entry/services/secure_key_store.dart`
- Test: `test/smart_entry/ai_assistant_config_test.dart`

- [ ] Write tests for default Zhipu/DeepSeek templates, OpenAI-compatible profiles, active profile selection, and legacy single-provider migration.
- [ ] Run `flutter test test/smart_entry/ai_assistant_config_test.dart` and verify the tests fail because the model does not exist.
- [ ] Implement the model and storage migration.
- [ ] Re-run the test and verify it passes.

### Task 2: OpenAI-Compatible Cloud Parser

**Files:**
- Modify: `lib/features/smart_entry/parser/cloud_parser.dart`
- Modify: `lib/features/smart_entry/providers/smart_entry_providers.dart`
- Test: `test/smart_entry/cloud_parser_test.dart`

- [ ] Add tests showing all providers post to `<baseUrl>/chat/completions`, send `Authorization: Bearer <apiKey>`, include the configured model, and parse JSON content.
- [ ] Run the cloud parser test and verify it fails against the current Qwen-specific implementation.
- [ ] Implement a provider-neutral parser and factory from the active AI profile.
- [ ] Re-run the cloud parser test and verify it passes.

### Task 3: Configurable Local Rules

**Files:**
- Modify: `lib/features/smart_entry/parser/local_rule_engine.dart`
- Modify: `lib/features/smart_entry/parser/smart_entry_parser.dart`
- Test: `test/smart_entry/local_rule_engine_test.dart`

- [ ] Add tests for user rules with priority, disabled rules, and category/type overrides before built-in keywords.
- [ ] Run the local rule test and verify it fails because rules are not supported.
- [ ] Implement rule matching with deterministic priority and fallback to built-in keywords.
- [ ] Re-run the local rule test and verify it passes.

### Task 4: AI Assistant Settings UI

**Files:**
- Modify: `lib/features/smart_entry/pages/ai_assistant_settings_page.dart`
- Test: `test/smart_entry/ai_assistant_settings_page_test.dart`

- [ ] Add widget tests for loading multiple profiles, switching active profile, adding an OpenAI-compatible profile, and showing local rules.
- [ ] Run the widget test and verify it fails against the current single-profile page.
- [ ] Replace build-time text controllers with state-owned controllers and update the UI using the existing settings form style.
- [ ] Re-run the widget test and verify it passes.

### Task 5: Final Verification

- [ ] Run `flutter test test/smart_entry/ai_assistant_config_test.dart test/smart_entry/cloud_parser_test.dart test/smart_entry/local_rule_engine_test.dart test/smart_entry/ai_assistant_settings_page_test.dart`.
- [ ] Run `flutter analyze lib/features/smart_entry test/smart_entry`.
- [ ] Inspect `git diff --stat` and confirm the changed files match the requested scope.
