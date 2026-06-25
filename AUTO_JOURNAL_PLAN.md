# Auto-Journal-Listener Plan

This document outlines the architecture and implementation strategy for the automatic journaling feature of DFMyFortWiki.

## 1. Core Architecture: The "Chronicle" Model
To minimize impact on game performance (FPS), we use a **Batch-Scan** approach rather than real-time event listening.

*   **Mechanism:** Periodically (e.g., every 5 minutes or at seasonal transitions or even as it happens (must determine if it adds lag to the game)) scan the game's `world.history.events` list.
*   **Tracking:** Store the `last_processed_event_id` in the site data to avoid redundant processing.
*   **The "Processing Window":** When triggered, the mod scans from `last_processed_event_id` to the current end of the list. Heavy processing (10-20s) is preferred over constant micro-stutters (but if it's a smooth experience maybe that is best?).

## 2. Concurrency & Pausing
To resolve the problem of both the user and the Auto-Journal-Listener editing the same page simultaneously:

*   **Force Pause:** The game will be **force-paused** whenever the Wiki interface is open. This ensures the user has exclusive access to the editor while they are working.
*   **Background Processing:** Auto-journaling will primarily run when the Wiki is *closed* and the game is running/paused normally, or during specific "Chronicle" triggers.
*   **HTML Export:** Users are encouraged to use the **Export to HTML** feature if they wish to browse their wiki content on a second monitor while the game continues to run.

## 3. The Wiki Edit API (Internal)
A dedicated API is required to handle background updates safely.

*   **`append_to_section(page_id, section_header, text)`**: Automatically identifies the correct `## Section` and appends new logs.
*   **`create_event_page(event_data)`**: Generates dedicated pages for major historical events and links them to relevant entity timelines.

## 4. Technical Challenges
*   **Event Parsing:** Mapping thousands of DF history event types to human-readable markdown.
*   **Entity Mapping:** Efficiently linking Historical Figure IDs to Wiki IDs (`citizen:ID`).
*   **Encoding:** Sanitizing CP437 historical names into UTF-8 for the TextArea.
*   **Memory:** Handling large batches of events without bloating Lua memory.

## 5. Event Categorization
Events are routed to relevant pages:
*   **Citizen:** Births, deaths, relationships, skill milestones.
*   **Artifact:** Creation, naming, theft, discovery.
*   **Fort:** Invasions, trade agreements, guild formations, major constructions.
*   **Civilization:** Wars, peace treaties, monarch successions.

## 6. Performance Optimization
*   **Idle-only processing:** Heavy scans run only when the game is paused or during low-activity periods.
*   **Filtering:** Only process events involving the player's civilization, site, or citizens.
