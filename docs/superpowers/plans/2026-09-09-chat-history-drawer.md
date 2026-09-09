# Chat History Drawer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the routed chat-history experience into an animated right-side drawer owned by `ChatTabComp`, while preserving all existing streaming, retry, regeneration, stopping, and RDB persistence behavior.

**Architecture:** `ChatTabComp` remains the only chat entry and owns the active `ChatViewModel`, `ChatSessionController`, and drawer visibility. `ChatHistoryDrawerComp` owns only history-list presentation and invokes the existing `ChatHistoryController`, while typed events return selection, deletion, new-session, and close intents to `ChatTabComp`; no global cross-page signal remains.

**Tech Stack:** HarmonyOS ArkTS strict mode, ArkUI V2, HMRouter, relationalStore RDB, Hypium/Hvigor verification.

**Spec:** User request in the 2026-09-09 task; all requirements are reproduced below.

## Global Constraints

- `ChatTabComp` is the only chat entry; do not modify store, auth, server, or unrelated features.
- Reuse `ThemeState`, `ChatHistoryController`, `ChatSessionController`, and `ChatRdb`; do not duplicate database logic.
- Do not use `any`; do not add empty catches or placeholder code.
- Block selecting, deleting, and creating sessions while `ChatViewModel.isLoading` is true and show a toast.
- Drawer width is 80%, opens from the right with animation, has an animated mask, respects the host chat safe area, and clears input focus before opening so the keyboard can dismiss.
- Remove obsolete routed pages, route constants, exports, `ChatLoadState`, and cross-page signal fields after proving there are no remaining references.

---

### Task 1: Lock session-change behavior and simplify history operations

**Files:**
- Modify: `chat/src/main/ets/controller/ChatSessionController.ets`
- Modify: `chat/src/main/ets/controller/ChatHistoryController.ets`
- Test: `chat/src/ohosTest/ets/test/ChatSessionController.test.ets`
- Modify: `chat/src/ohosTest/ets/test/List.test.ets`

**Interfaces:**
- `ChatSessionController.newSession(): boolean` returns `false` without mutating state during generation, otherwise resets the VM and returns `true`.
- `ChatHistoryController.loadData(): Promise<ChatSession[]>` obtains RDB sessions and sorts them by `updateTime` descending.
- `ChatHistoryController.deleteSession(sessionId: string, sessions: ChatSession[]): Promise<ChatSession[]>` deletes through `ChatRdb` and returns the filtered list.

- [ ] Add Hypium cases for idle new-session reset and loading-state refusal.
- [ ] Compile the test target once to confirm the new boolean contract is missing.
- [ ] Implement the boolean session contract and remove unused `UIAbilityContext`, `HMUtil`, and `ChatLoadState` dependencies from the history controller.
- [ ] Recompile tests and the chat module.

### Task 2: Build the history drawer component

**Files:**
- Create: `chat/src/main/ets/components/ChatHistoryDrawerComp.ets`

**Interfaces:**
- Consumes: `visible: boolean`, `isGenerating: boolean`, `currentSessionId: string`.
- Produces events: `onClose(): void`, `onSelectSession(sessionId: string): void`, `onNewSession(): void`, `onSessionDeleted(sessionId: string): void`.

- [ ] Add the component shell with a full-size transparent hit-test layer, semi-transparent mask, and 80%-width right panel.
- [ ] Bind mask opacity and panel translation to `visible`; parent `animateTo` drives 260 ms open/close transitions.
- [ ] Load data on first appearance and each transition to `visible=true`.
- [ ] Render empty state and the descending session list with title, preview, formatted time, current-session marker, and swipe-delete action.
- [ ] Guard select/delete/new actions when generating and display `AI 正在生成，请先停止后再切换会话` through the current `UIContext` prompt API.
- [ ] On successful delete, replace the local sessions array immediately and emit `onSessionDeleted(sessionId)`.

### Task 3: Make ChatTabComp the drawer and session orchestration owner

**Files:**
- Modify: `chat/src/main/ets/components/ChatTabComp.ets`

**Interfaces:**
- Calls `ChatSessionController.loadSessionById(sessionId, context): Promise<boolean>`.
- Receives all drawer events directly; no `AppStorageV2` signal is involved.

- [ ] Replace the root `Column` with a `Stack` containing the existing chat UI and `ChatHistoryDrawerComp`.
- [ ] Add the top-right history button and keep the existing new-session action.
- [ ] Clear input focus before opening the drawer, then animate `drawerVisible` to `true`.
- [ ] On session selection, reject while generating; otherwise load by ID, close only on success, and show a failure toast when no messages exist.
- [ ] On new session, use the controller boolean result, close the drawer, and leave the existing message/input components intact.
- [ ] On deletion of the current session, reset through `newSession()`; deletion of another session does not alter the active VM.
- [ ] Preserve keyboard listener registration/disposal, bottom inset calculation, streaming persistence monitor, send, stop, resend, and regenerate behavior.

### Task 4: Remove routed chat history and cross-page state

**Files:**
- Delete: `chat/src/main/ets/pages/ChatPage.ets`
- Delete: `chat/src/main/ets/pages/ChatHistoryPage.ets`
- Delete: `chat/src/main/ets/viewmodel/ChatLoadState.ets`
- Modify: `chat/src/main/ets/controller/ChatSessionController.ets`
- Modify: `chat/src/main/ets/constants/ChatRoutes.ets`
- Modify: `chat/Index.ets`
- Modify: `common/src/main/ets/utils/WindowUtil.ets`

- [ ] Remove `restoreSession()`, whose only consumer is the deleted routed `ChatPage`.
- [ ] Remove chat page route constants; retain an empty-free constants file only if another valid constant remains, otherwise delete it.
- [ ] Remove `ChatRoutes`, `ChatLoadState`, and `getChatLoadState` exports from the HAR public API.
- [ ] Update comments that still describe `ChatPage` or routed history navigation.

### Task 5: Remove entry-module route wiring and profile entry

**Files:**
- Modify: `entry/src/main/ets/pages/HomePage.ets`
- Modify: `entry/src/main/ets/components/ProfileTabComp.ets`
- Modify: `entry/src/main/ets/controller/ProfileController.ets`
- Modify: `entry/src/main/ets/constants/EntryRoutes.ets`

- [ ] Remove `ChatLoadState` imports, local state, monitor, and cross-page signal documentation from `HomePage`.
- [ ] Remove the `消息记录` menu row and `goHistory()` controller method.
- [ ] Remove `PAGE_CHAT` and `PAGE_CHAT_HISTORY` from entry routes after confirming no remaining references.

### Task 6: Verify behavior and cleanup

**Files:**
- Inspect: all `*.ets`, `*.ts`, and route/generated-map sources under `chat`, `entry`, and `common`.

- [ ] Search for `ChatPage`, `ChatHistoryPage`, `ChatLoadState`, `getChatLoadState`, `pendingSessionId`, `deletedSessionId`, `PAGE_CHAT`, `PAGE_CHAT_HISTORY`, and `goHistory`; expected result is no live source references.
- [ ] Run `git diff --check`; expected result is no whitespace errors.
- [ ] Run the Hypium compile/test target available in this workspace.
- [ ] Run `Hvigor assembleApp` with the configured DevEco SDK and confirm `CompileArkTS` completes; classify later packaging/signing environment failures separately.
- [ ] Review the final diff to ensure store, login, server, shopping, and unrelated files are untouched.
- [ ] Record remaining real-device checks: drawer swipe-delete gesture, mask/close behavior, animation smoothness, keyboard dismissal, safe-area fit, dark mode, session switching, current-session deletion, and stream-operation lockout.
