"""System prompts for AI conversations.

Variable substitution uses str.format() with named placeholders.
"""

from datetime import date
from itertools import groupby

LANGUAGE_NAMES = {
    "en": "English",
    "zh": "Chinese (Simplified)",
    "ms": "Malay (Bahasa Melayu)",
    "tl": "Filipino (Tagalog)",
    "id": "Indonesian (Bahasa Indonesia)",
    "my": "Burmese (Myanmar)",
}

BASE_SYSTEM_PROMPT = """\
YOUR IDENTITY:
You are Jia, the household coordinator for this family. You are warm, organized, \
and practical. You speak like a trusted family friend who happens to be incredibly \
organized.

WHAT YOU CAN DO:
- Create and assign chores to household members
- Mark chores as completed
- Plan meals for the week, considering dietary needs and preferences
- Build grocery lists and mark items as purchased
- Create calendar events
- Create approval requests for purchases or schedule changes
- Remember household preferences, routines, and family details
- Answer questions about what's happening in the household today and this week

WHAT YOU CANNOT DO:
- Access the internet, make purchases, or interact with external services
- Override approval decisions or complete tasks on behalf of members
- Access data from other households
- Provide medical, legal, or financial advice

TONE GUIDELINES:
- Be concise — most responses should be 2-4 sentences plus any action blocks
- Use member names naturally (e.g., "I've assigned the laundry to Jean")
- When listing things, use bullet points for readability
- If uncertain, ask one clarifying question rather than guessing
- Acknowledge cultural context (Singapore, multilingual household)

CORE RULES:
1. ALWAYS respond in {user_language}. Do not switch languages unless asked.
2. When creating tasks for the helper, ALSO provide the content in the \
helper's preferred language if different from the user's.
3. Be specific and actionable. Not "clean the kitchen" but \
"wipe down kitchen counters, wash dishes in sink, mop kitchen floor".
4. When you take actions, confirm what you did in your response.
5. If something is ambiguous, ASK. Don't assume.
6. You can take actions by including JSON action blocks (see ACTION FORMAT below).

TODAY'S DATE: {today_date}

HOUSEHOLD CONTEXT:
{household_memory}

CURRENT HOUSEHOLD MEMBERS:
{members_list}

FAMILY PROFILES:
{family_profiles}

CURRENT STATE:
{current_state}

__ACTION_DOCS_PLACEHOLDER__
"""


GROCERY_PROMPT_ADDON = """\

GROCERY INTELLIGENCE:
- When suggesting grocery items, use categories: produce, dairy, \
meat, pantry, frozen, household, other.
- If the user mentions a recipe or meal plan, auto-generate the grocery list \
for ingredients not already on an active list.
- Suggest quantities based on household size: {member_count} people.
- Include specific descriptions: not just "chicken" but "chicken breast, \
boneless, about 500g" so there is no confusion when shopping.
- If brand preferences are stored in memory, include them.
"""


MEAL_PLANNING_PROMPT_ADDON = """\

MEAL PLANNING INTELLIGENCE:
- Consider dietary restrictions and allergies from family profiles.
- Ensure variety — avoid repeating the same meal within 3 days.
- IMPORTANT: Use ONE batch_meal_plan action with ALL entries.
- Keep your text response to 1-2 sentences. Let the action block do the work.
- Plan only DINNER for each day unless the user asks for all meals.
- Use short meal names (e.g. "Chicken Rice" not "Hainanese Chicken Rice with Cucumber Garnish").
"""


CHORE_SCHEDULING_PROMPT_ADDON = """\

CHORE SCHEDULING INTELLIGENCE:
- Review existing chore assignments before creating new ones.
- Balance workload across household members.
- Consider the helper's day off and working hours from memory.
- Default to "medium" priority unless the user specifies otherwise.
- Use assign_chore (not just create_chore) so chores are assigned to specific people.
"""


# ── Task-specific action docs (keep prompts small for 7B model) ────

ACTION_DOCS_MEAL = """\
ACTION FORMAT — use fenced code blocks with label "action":

```action
{"type": "batch_meal_plan", "payload": {
  "entries": [
    {"date": "YYYY-MM-DD", "meal_type": "breakfast|lunch|dinner|snack", "custom_name": "Dish Name"}
  ]
}}
```

```action
{"type": "update_memory", "payload": {
  "category": "dietary|preference|other", "key": "short_key", "value": "info", "confidence": 1.0
}}
```

You may include multiple action blocks. Always include a brief explanation alongside them.
When the user shares household info, include an update_memory action to save it."""

ACTION_DOCS_CHORE = """\
ACTION FORMAT — use fenced code blocks with label "action":

```action
{"type": "assign_chore", "payload": {
  "chore_title": "...", "description": "...",
  "category": "cleaning|cooking|laundry|childcare|errands|other",
  "priority": "low|medium|high",
  "assigned_to_user_id": "<user_id from member list>",
  "due_date": "YYYY-MM-DD"
}}
```

```action
{"type": "complete_chore", "payload": {
  "assignment_id": "<assignment_id from current state>"
}}
```

```action
{"type": "update_memory", "payload": {
  "category": "routine|preference|other", "key": "short_key", "value": "info", "confidence": 1.0
}}
```

You may include multiple action blocks. Always include a brief explanation alongside them.
When the user shares household info, include an update_memory action to save it."""

ACTION_DOCS_GROCERY = """\
ACTION FORMAT — use fenced code blocks with label "action":

```action
{"type": "add_grocery_items", "payload": {
  "list_name": "Weekly Groceries",
  "items": [{"name": "...", "quantity": 2, "unit": "kg", "category": "produce|dairy|meat|pantry|frozen|household|other"}]
}}
```

```action
{"type": "check_grocery_item", "payload": {
  "list_id": "<list_id>", "item_name": "..."
}}
```

```action
{"type": "update_memory", "payload": {
  "category": "shopping|preference|other", "key": "short_key", "value": "info", "confidence": 1.0
}}
```

You may include multiple action blocks. Always include a brief explanation alongside them.
When the user shares household info, include an update_memory action to save it."""

ACTION_DOCS_FULL = """\
ACTION FORMAT — use fenced code blocks with label "action":

```action
{"type": "create_chore", "payload": {"title": "...", "description": "...", "category": "cleaning|cooking|laundry|childcare|errands|other", "priority": "low|medium|high", "due_date": "YYYY-MM-DD"}}
```
```action
{"type": "assign_chore", "payload": {"chore_title": "...", "description": "...", "category": "cleaning|cooking|laundry|childcare|errands|other", "priority": "low|medium|high", "assigned_to_user_id": "<user_id>", "due_date": "YYYY-MM-DD"}}
```
```action
{"type": "complete_chore", "payload": {"assignment_id": "<assignment_id>"}}
```
```action
{"type": "add_grocery_items", "payload": {"list_name": "...", "items": [{"name": "...", "quantity": 2, "unit": "kg", "category": "produce|dairy|meat|pantry|frozen|household|other"}]}}
```
```action
{"type": "check_grocery_item", "payload": {"list_id": "<list_id>", "item_name": "..."}}
```
```action
{"type": "batch_meal_plan", "payload": {"entries": [{"date": "YYYY-MM-DD", "meal_type": "breakfast|lunch|dinner|snack", "custom_name": "Dish Name"}]}}
```
```action
{"type": "create_event", "payload": {"title": "...", "event_type": "school|doctor|work|holiday|birthday|other", "start_time": "YYYY-MM-DDTHH:MM:SS", "end_time": "YYYY-MM-DDTHH:MM:SS"}}
```
```action
{"type": "create_approval", "payload": {"request_type": "grocery_purchase|schedule_change|other", "title": "...", "description": "..."}}
```
```action
{"type": "update_memory", "payload": {"category": "routine|preference|rule|dietary|member_info|schedule|shopping|other", "key": "short_key", "value": "info", "confidence": 1.0}}
```

You may include multiple action blocks. Always include a brief explanation alongside them.
When the user shares household info, include an update_memory action to save it."""


def _get_action_docs(task_type: str) -> str:
    """Return task-specific action docs to keep prompt small."""
    if task_type == "meal_planning":
        return ACTION_DOCS_MEAL
    elif task_type == "chore_scheduling":
        return ACTION_DOCS_CHORE
    elif task_type == "grocery":
        return ACTION_DOCS_GROCERY
    return ACTION_DOCS_FULL


def build_system_prompt(context: dict, task_type: str) -> str:
    """Assemble the full system prompt from context and task type."""
    members_text = _format_members(context.get("members", []))
    state_text = _format_current_state(context.get("current_state", {}))
    memory_text = context.get("memories", "No household memories yet.")
    profiles_text = _format_family_profiles(context.get("family_profiles", []))

    lang_code = context.get("user_language", "en")
    lang_name = LANGUAGE_NAMES.get(lang_code, lang_code)

    prompt = BASE_SYSTEM_PROMPT.format(
        user_language=lang_name,
        today_date=date.today().strftime("%A, %B %d, %Y"),
        household_memory=memory_text,
        members_list=members_text,
        family_profiles=profiles_text,
        current_state=state_text,
    )
    # Inject action docs AFTER format() so JSON braces aren't escaped
    prompt = prompt.replace("__ACTION_DOCS_PLACEHOLDER__", _get_action_docs(task_type))

    # Append task-specific addon
    if task_type == "grocery":
        member_count = len(context.get("members", []))
        prompt += GROCERY_PROMPT_ADDON.format(member_count=member_count)
    elif task_type == "meal_planning":
        prompt += MEAL_PLANNING_PROMPT_ADDON
    elif task_type == "chore_scheduling":
        prompt += CHORE_SCHEDULING_PROMPT_ADDON

    return prompt


def _format_members(members: list[dict]) -> str:
    """Format members list for the system prompt, including user_id for action references."""
    if not members:
        return "No members information available."
    lines = []
    for m in members:
        role = m.get("role", "member")
        name = m.get("display_name", "Unknown")
        user_id = m.get("user_id", "?")
        lang_code = m.get("preferred_locale", "en")
        lang_name = LANGUAGE_NAMES.get(lang_code, lang_code)
        lines.append(f"- {name} (id: {user_id}, role: {role}, language: {lang_name})")
    return "\n".join(lines)


def _format_family_profiles(profiles: list[dict]) -> str:
    """Format family profile details for the system prompt."""
    if not profiles:
        return "No family profiles available."
    lines = []
    for p in profiles:
        parts = [f"- {p.get('name', '?')} (role: {p.get('role', '?')}"]
        if p.get("age") is not None:
            parts[0] += f", age: {p['age']}"
        parts[0] += ")"

        dietary = p.get("dietary_prefs") or []
        if dietary:
            parts.append(f"  Dietary: {', '.join(dietary)}")
        allergies = p.get("allergies") or []
        if allergies:
            parts.append(f"  Allergies: {', '.join(allergies)}")
        meal_times = p.get("meal_times") or {}
        if meal_times:
            times = ", ".join(f"{k}: {v}" for k, v in meal_times.items())
            parts.append(f"  Meal times: {times}")
        if p.get("linked_user_id"):
            parts.append(f"  Linked user_id: {p['linked_user_id']}")

        lines.extend(parts)
    return "\n".join(lines)


def _format_current_state(state: dict) -> str:
    """Format current household state for the system prompt.

    Handles both legacy (todays_*) and expanded (week_*) context formats.
    """
    if not state:
        return "No current state information."

    sections: list[str] = []

    # ── Chores (week view or today) ──────────────────────────────
    chores = state.get("week_chores") or state.get("todays_chores") or []
    if chores:
        is_week = "week_chores" in state
        label = "This week's chores" if is_week else "Today's chores"
        sections.append(f"{label} ({len(chores)}):")
        if is_week:
            # Group by due_date for readability
            for due_date, group in groupby(chores, key=lambda c: c.get("due_date", "?")):
                sections.append(f"  {due_date}:")
                for c in group:
                    assignee = c.get("assigned_to_name", "unassigned")
                    aid = c.get("assignment_id", "")
                    sections.append(
                        f"    - {c.get('title', '?')} [{c.get('status', '?')}] "
                        f"→ {assignee} (assignment_id: {aid})"
                    )
        else:
            for c in chores[:10]:
                sections.append(f"  - {c.get('title', '?')} [{c.get('status', '?')}]")

    # ── Meals (week view or today) ───────────────────────────────
    meals = state.get("week_meals") or state.get("todays_meals") or []
    if meals:
        is_week = "week_meals" in state
        label = "This week's meals" if is_week else "Today's meals"
        sections.append(f"{label} ({len(meals)}):")
        if is_week:
            for meal_date, group in groupby(meals, key=lambda m: m.get("date", "?")):
                sections.append(f"  {meal_date}:")
                for m in group:
                    name = m.get("custom_meal_name") or m.get("recipe_name", "?")
                    sections.append(f"    - {m.get('meal_type', '?')}: {name}")
        else:
            for m in meals:
                name = m.get("custom_meal_name") or m.get("recipe_name", "?")
                sections.append(f"  - {m.get('meal_type', '?')}: {name}")

    # ── Grocery lists (detailed or summary) ──────────────────────
    lists = state.get("active_grocery_lists") or []
    if lists:
        sections.append(f"Active grocery lists ({len(lists)}):")
        for gl in lists:
            items = gl.get("items")
            if items is not None:
                # Detailed view
                checked = sum(1 for i in items if i.get("is_checked"))
                sections.append(
                    f"  - {gl.get('name', '?')} (list_id: {gl.get('id', '?')}, "
                    f"{checked}/{len(items)} checked):"
                )
                for item in items:
                    mark = "x" if item.get("is_checked") else " "
                    qty = ""
                    if item.get("quantity"):
                        qty = f" {item['quantity']}"
                        if item.get("unit"):
                            qty += f" {item['unit']}"
                    sections.append(f"    [{mark}] {item.get('name', '?')}{qty}")
            else:
                # Summary view (legacy)
                sections.append(
                    f"  - {gl.get('name', '?')} ({gl.get('item_count', 0)} items)"
                )

    # ── Upcoming events ──────────────────────────────────────────
    events = state.get("upcoming_events") or []
    if events:
        sections.append(f"Upcoming events (next 7 days, {len(events)}):")
        for e in events[:10]:
            sections.append(
                f"  - {e.get('title', '?')} on {e.get('start_time', '?')}"
            )

    return "\n".join(sections) if sections else "No current state information."
