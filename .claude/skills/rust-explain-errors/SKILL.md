---
name: rust-explain-errors
description: >
  Use when Rust code fails to compile with borrow-checker, lifetime, move, or
  trait errors — E0382, E0499, E0502, E0505, E0507, E0515, E0597, E0308, E0277.
  Make sure to use this skill whenever the user hits a rustc error and is
  learning Rust: decode the error and teach the underlying rule, do not just
  patch the code.
paths:
  - "**/*.rs"
---

# Rust: Explain Errors, Then Fix

When rustc reports an error, do NOT jump straight to a patch. Work in this order:

1. **Name the rule.** State which ownership/borrowing/lifetime rule the error
   enforces (e.g. E0382 = use-after-move: a value moved out cannot be used
   again; E0499 = no two `&mut` to the same value at once; E0597 = a borrow
   outlives the data it points to).
2. **Locate the exact cause** in the user's code — which binding moved, which
   borrow is still live, which lifetime is too short. Quote the spans rustc
   points at.
3. **Explain the fix options and their trade-offs**, cheapest first: reborrow,
   clone, restructure scope, `Rc`/`RefCell`, change the signature's lifetimes.
   Say why one fits here and what each costs.
4. **Apply the chosen fix** and show the diff.
5. **One-line takeaway** the user can carry to the next occurrence.

Keep it tight — a short paragraph per step, not an essay. The goal is that the
user learns the rule, not just that the code compiles.
