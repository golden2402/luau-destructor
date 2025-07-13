# destructor

Typed, lightweight alternative cleanup module (akin to Maid), heavily inspired by Fractality's Destructor (https://github.com/Fraktality/Destructor). Designed for Roblox.

If in a standalone Luau environment, you can the trim types to comply with what's available to you. You'll need to change the union `DestructorItem` (and its derived `DestructionItemInput`) and `itemWrappers`; in `itemWrappers`, remove the wrapper that matches the `typeof` signature of the removed item type.
