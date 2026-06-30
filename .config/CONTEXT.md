# AeroSpace Config

This context defines the user-facing language for the AeroSpace window-management configuration in this workspace. It exists to keep keybinding intent precise when similar actions have different scope.

## Language

**Visible workspace rotation**:
Moving each monitor's currently visible workspace to the next monitor in the ring, with wrap-around.
_Avoid_: Swap, workspace shuffle

**Monitor ring**:
The ordered set of active AeroSpace monitors as reported by AeroSpace itself.
_Avoid_: Physical clockwise layout, geometry order

**Movement mode**:
The AeroSpace keybinding mode used for structural window and workspace actions.
_Avoid_: Main mode, resize mode

## Relationships

- A **visible workspace rotation** operates over every monitor in the **monitor ring**
- **Movement mode** can trigger a **visible workspace rotation**

## Example dialogue

> **Dev:** "Should `ctrl-p` swap the two visible workspaces?"
> **Domain expert:** "No - in **movement mode**, `ctrl-p` performs a **visible workspace rotation** across the **monitor ring**."

## Flagged ambiguities

- "swap" was used to describe a multi-monitor rotation - resolved: the canonical term is **visible workspace rotation**
