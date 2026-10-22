# nvim Upgrade & Cleanup Plan

Investigated 2026-09-08. Environment: NVIM v0.13.0-dev, lazy.nvim, 30 plugins.
Repo: `HonkyTonkRobot/kickstart.nvim` @ `main`.

**Baseline finding:** `lazy-lock.json` matched on-disk exactly (zero drift), and 28 of
30 plugins were already at their upstream branch tip. `:Lazy update` is a near no-op.
Everything below is a *config* or *pin* change, not an update.

**Status:** §1, §2, §3, §10, §11, §12 **DONE**, plus the render-markdown workaround removal
and lazy-lock tracking. **§4, §5, §7, §8, §9 remain.** §6 resolved as "leave as-is".

---

## 1. Diffview scroll desync — ✅ DONE & VERIFIED

**Symptom:** left pane scrolled at a different rate than the right, on every machine.

**Cause:** `lua/options.lua:31` sets `vim.o.wrap = true` (plus `linebreak`, `breakindent`).
With `wrap` on, `scrollbind` syncs the panes by **screen lines, not buffer lines** — a line that
wraps to 3 rows on one side and 1 row on the other drifts as you scroll.

Not a diffview bug: `:diffsplit` normally resets `wrap` off, because your `diffopt`
(`internal,filler,closeoff,indent-heuristic,inline:char,linematch:40`) does **not** include
`followwrap`. But diffview builds its own windows and sets `vim.wo.diff = true` directly, which
skips that reset. Confirmed diffview never touches `wrap` anywhere in its source — and its own
`:help diffview` hook example sets `wrap = false` for exactly this reason.

It followed you to every computer because it's your own option, committed to this repo
and cloned on each machine. (Correction: I earlier said `~/.dotfiles` carried it — it does not.
See §9.)

**Applied** in `lua/custom/plugins/diffview.lua`, replacing `hooks = {}`:

```lua
hooks = {
  diff_buf_read = function(_)
    vim.opt_local.wrap = false
    vim.opt_local.linebreak = false
    vim.opt_local.list = false
    vim.opt_local.spell = false
  end,
},
```

**Verified end-to-end** in a scratch repo with a deliberately wrapping long line:
- both diff panes: `wrap=false linebreak=false list=false spell=false`
- normal buffer before diffview: `wrap=true`
- `vim.go.wrap` after opening *and* closing diffview: `true`
- brand-new window and reopened file afterwards: `true`

No leakage — `opt_local` is correctly scoped to the diff windows only.

If alignment still drifts at buffer edges, add `vim.opt_local.scrolloff = 0` to the same hook
(your global is 8).

Backup of the original file: `scratchpad/diffview.lua.bak`.

---

## 2. Switched to the maintained diffview fork — ✅ DONE

`sindrets/diffview.nvim` last commit **2024-06-13** (~2¼ years). You were already on its tip;
there was nothing to update to.

**Now on** [`dlyongemallo/diffview.nvim`](https://github.com/dlyongemallo/diffview.nvim):
- **373 commits ahead** of sindrets' tip
- installed at `4e3a2f2`, **2026-09-06**
- tagged releases up to **v0.37**
- [Neogit issue #1921](https://github.com/NeogitOrg/neogit/issues/1921) tracks switching to it

**Compatibility pre-checked before switching** — all 14 config keys you use still exist in the
fork (`enhanced_diff_hl`, `watch_index`, `show_help_hints`, `diff_binaries`, `use_icons`,
`winbar_info`, `listing_style`, `flatten_dirs`, `folder_statuses`, `log_options`, `diff_merges`,
`git_cmd`, `hg_cmd`, `disable_diagnostics`), as do all six hooks. `lazy-lock.json` updated.
Your keymaps and `actions` API calls are unchanged.

Relevant fixes you inherit: `fix(view): keep the cursor on its code line (#314)`,
`fix(layout): align diff1_inline diff computation with side-by-side layouts (#126)`,
`fix(panel): route cursor ops to windows showing the panel buffer (#297)`.

There's also [`diffview-plus.nvim`](https://github.com/dlyongemallo/diffview-plus.nvim) (same
author, extra features) if you later want more.

### Do you need Neogit? No.

Neogit is **not installed** (confirmed — not in `lazy-lock.json`). It's a magit-style porcelain:
a staging/commit/branch/rebase UI inside nvim. You already have hunk staging via gitsigns, review
via diffview, and the git CLI. Neogit would mostly replace `git commit`/`git rebase -i` at the
terminal with an in-editor UI — worth it only if you dislike doing those in the shell. The
Neogit reference above mattered only as *evidence the fork is trusted*, not as a suggestion to
adopt it. Skip it.

---

## 3. Treesitter crash → `mini.indentscope` — ✅ DONE

You asked whether yesterday's treesitter commit covered this. It did not:
- treesitter port `2cf8cf3` committed **2026-09-07 14:01**
- crash logged **2026-09-07 15:14** — 73 minutes *after*

From `~/.local/state/nvim/log`:

```
vim/treesitter.lua:223: Index out of bounds
  [C]: nvim_buf_get_text → get_url
  treesitter/highlighter.lua  (decoration provider "conceal_line")
  [C]: winsaveview
  indent-blankline.nvim/lua/ibl/utils.lua:358: get_offset
  ibl/init.lua:196: refresh
```

indent-blankline's debounced refresh calls `winsaveview`, and treesitter's URL-conceal handler
throws inside it on nvim 0.13-dev. Both plugins are at their latest versions — no update fixes it.

**Your question — yes, that's exactly what `mini.indentscope` is.** It draws a single vertical
line marking the scope your cursor is currently inside (the function/block you're in), and it
animates as you move between scopes. That is *not* what you have now.

The two are different tools, and it's worth knowing which you'd miss:

| | what it draws |
|---|---|
| **indent-blankline** (current) | faint guides at **every** indent level, across the whole buffer, always on |
| **mini.indentscope** | **one** line for the **current** scope only, follows your cursor, animated |

They're complementary — plenty of people run both. But ibl is the crash source, so:
- **(a)** switch to `mini.indentscope` — you lose the every-level guides, gain the cursor-scope line
- **(b)** run `mini.indentscope` *and* keep ibl — keeps the crash
- **(c)** keep ibl alone — status quo, occasional crash

**Correction on "markdown-exclude" — my earlier suggestion was wrong, don't use it.**
"markdown-exclude" was shorthand for `require("ibl").setup({ exclude = { filetypes = {...} } })`,
i.e. telling ibl not to run in the filetypes where the crash fires. I assumed that was markdown.
It isn't. I checked which parsers actually capture `@string.special.url` (the thing `get_url`
reads), and it's **31 installed parsers**:

```
bass bibtex comment cue desktop dhall dtd gdscript git_config gomod gosum gpg html_tags
http jsx kconfig kitty nix phpdoc pod requirements rst smali ssh_config thrift typescript
usd uxntal vimdoc wxml xml
```

Note `comment` — that parser is **injected into every language**, so a URL in a code comment in
any file can hit this path. Markdown isn't even in the list. So filetype exclusion can't reliably
fix it, and I'm withdrawing that option.

**Honest caveat on the fix:** `mini.indentscope` also calls `winsaveview()`
(`mini/indentscope.lua:826`), but only to read `leftcol` for drawing — not ibl's
save/refresh/restore cycle that re-enters the treesitter highlighter, which is what's in the
traceback. So switching is *likely* to fix it, not guaranteed. If it recurs, the real bug is
nvim core's missing bounds guard.

**If you want to try it** (reversible in one commit):
1. Delete `lua/custom/plugins/indent-blankline.lua`
2. Add `require("mini.indentscope").setup()` to the `config` function in `lua/custom/plugins/mini.lua`
3. `:Lazy clean`

Live with it a day; if you miss the every-level guides, revert and take option (c).

Worth filing upstream either way — the out-of-bounds guard belongs in nvim core's `get_url`,
and you're on a dev build.

**Also revisit while here:** `lua/custom/plugins/render-markdown.lua` carries a workaround
(`enabled = false` + a `FileType` autocmd enabling it via `vim.schedule`) added in `f6bb6de`
(2025-08-14) for a treesitter C-call boundary error — *before* the port to treesitter `main`.
Test whether plain `opts = { completions = { lsp = { enabled = true } } }` works now and delete
the hack if so. It may be implicated in the crash above, since both involve markdown conceal.

---

## 4. Stale pins

### telescope.nvim — the one real update available

`lua/custom/plugins/telescope.lua:4` pins `branch = "0.1.x"`:
- `0.1.x` tip: **2024-05-24**, frozen
- **476 commits behind** `master`
- `master` tip 2026-08-17, tagged **v0.2.2**
- upstream kickstart has **removed** this branch pin

**On your "bring in the new stuff, then re-apply my custom changes on top" plan** — good instinct,
but for telescope it's simpler than that. `telescope.lua` is **your own file**; there is no
upstream counterpart to merge, and none of your customisations live in telescope's source. The
change is literally one line:

```lua
-- delete this line:
branch = "0.1.x",
```

Your customisations use stable APIs and should carry over untouched: `vimgrep_arguments`,
`pickers.find_files.find_command` (the deliberate `fdfind` + `--no-ignore-vcs` +
`--ignore-file` policy from `54ac7b0`), `extensions["ui-select"]`, `get_dropdown()`,
`previewer = false`.

**Counter-intuitive point in your favour:** master `feat!: require Nvim 0.11 and drop compat
shims (e6cdb4d)`. The frozen `0.1.x` branch was written for pre-0.11 nvim and still uses the old
`vim.validate` — so **`0.1.x` is the riskier combination on your 0.13-dev**, not master. Moving
forward is the safer direction here, not the more dangerous one.

Breaking changes I found in the local repo that could touch you:

| Commit | Change | Affects you? |
|---|---|---|
| `e6cdb4d` | `feat!:` require Nvim 0.11, drop compat shims | You're on 0.13-dev ✓ |
| `02ec064` | `feat!:` drop Nvim 0.9 support | ✓ fine |
| `9cf58f4` | `fix(config)!:` fall back to `vim.o.winblend` | **Yes** — your `<leader>/` sets `winblend = 10` |
| `8c69f58` | `feat(preview)!:` `preview.highlight_limit` default 1MB | Large-file previews only |
| `4367e05` | `fix(builtin)!:` quickfix entry maker drops fixed width | Cosmetic |
| `991d5db` | `refactor(mappings):` use `vim.keymap`, remove `__TelescopeKeymapStore` | Only if you poked internals — you don't |
| `89ca726` | `refactor(previewer):` remove `with_preview_window` | Not used by you |

After switching: `:Lazy build telescope-fzf-native.nvim` (needs a `make` rebuild), then check
`telescope-ui-select` still loads (dormant since 2023-12-04). Roll back by restoring the
`branch` line.

### mini.nvim — org renamed
`lua/custom/plugins/mini.lua:2` uses `echasnovski/mini.nvim`. The org is now
**`nvim-mini/mini.nvim`** (what upstream kickstart uses). The old path still redirects, but
update it — and do it in the same commit as §3 since you're editing that file anyway.

### lazydev / luvit-meta — optional tidy
`luvit-meta` is still active (2026-08-29), so nothing is broken. But lazydev supports nvim's
bundled luv types, letting you drop the extra plugin:
```lua
library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } },
```
then delete the `{ "Bilal2453/luvit-meta", lazy = true }` spec.

---

## 5. Delete `lua/kickstart/plugins/` — decided

Nothing imports it. `init.lua:76` only does `{ import = 'custom.plugins' }`, and **none** of
these plugins appear in `lazy-lock.json` — never installed. ~1000 lines of dead code.

```bash
git rm -r lua/kickstart/plugins/
```

**Decision on what to carry over — nothing, but take three free mini.nvim modules:**

| File | Verdict |
|---|---|
| `gitsigns.lua` | Delete — duplicate of your live `custom/plugins/gitsigns.lua`. Upstream deleted theirs too (`97ed8df`). |
| `indent_line.lua` | Delete — superseded by §3. |
| `autopairs.lua` | Skip nvim-autopairs → use **`mini.pairs`** (already installed). |
| `neo-tree.lua` | Skip → use **`mini.files`** (already installed) if you ever want a tree; telescope covers most of it. |
| `lint.lua` | Skip — conform + LSP diagnostics cover you. Revisit only for eslint/markdownlint outside the LSP. |
| `debug.lua` | Skip — nvim-dap is a real commitment. Add only if you actually step-debug. |

So `lua/custom/plugins/mini.lua` gains, in total:
```lua
require("mini.pairs").setup()
require("mini.files").setup()
require("mini.indentscope").setup()   -- from §3
```

Keep `lua/kickstart/health.lua` and `doc/kickstart.txt` if you still want
`:checkhealth kickstart`; delete them if you want the fork fully de-kickstarted. Low stakes.

---

## 6. lorem.nvim — leave it eager (decided)

**You're right that it works, and your description matches the mechanism exactly.** We were
talking past each other: my point was only that it isn't an **Ex command** — there's no
`:Lorem50` you type at the `:` prompt. What you actually do is type the keyword *into the buffer*
and press Enter, which is precisely the buffer-local `<CR>` map I was describing
(`lua/lorem/init.lua:134-151`). Same thing, and it does work.

The consequence is the bit that matters: because the trigger is a keymap rather than a command,
lazy.nvim has nothing to hook, so `cmd = {...}` can't defer it.

**Decision: leave it loading eagerly.** Your call, and it's a small plugin.

For the record, `event = "InsertEnter"` *would* still support your exact workflow — you're in
insert mode when you type `lorem50`, so the plugin would be loaded by then — but it's a
micro-optimisation and not worth the risk of changing something that works.

Unmaintained (last commit 2024-12-24, 181 lines, one file). Fine for what it does.

## 7. Two small gitsigns fixes — description-only ✅ approved

Correction from my first pass: these are **not** wrong function calls. I checked the gitsigns
source and your code is already the modern form — only the `desc` strings lie.
In `lua/custom/plugins/gitsigns.lua`:

- `<leader>gu` → `gitsigns.stage_hunk`, described as "undo stage hunk".
  `undo_stage_hunk` still exists but is **deprecated** (`gitsigns/actions.lua:424`: "use
  `stage_hunk()` on staged signs") — `stage_hunk` now toggles.
  → change desc to `'[G]it [u]nstage hunk (toggle)'`
- `<leader>tD` → `gitsigns.preview_hunk_inline`, described as "Toggle git show Deleted".
  `toggle_deleted` is deprecated in favour of `preview_hunk_inline` (`actions.lua:231`).
  → change desc to `'[T]oggle inline [D]iff preview'`

---

## 8. ccc.nvim vs mini.hipatterns

`ccc.nvim` does two things: a colour picker (`<leader>cp`) and an auto-highlighter. mini.nvim
already ships **`mini.hipatterns`**, which covers the highlighting half.

- Keep ccc for the interactive **picker** — mini has no equivalent.
- If you only wanted the swatches, drop ccc for `mini.hipatterns`.

ccc's last commit is 2025-05-06. You added it deliberately in `7ccb609`, so your call.

---

## 9. Upstream kickstart — cherry-pick, don't merge

Upstream is **99 commits** ahead of your merge-base (`3338d39`, 2025-05-22), but it has
**migrated off lazy.nvim to the built-in `vim.pack`** (`c460542`) and collapsed everything into
a sectioned 1035-line `init.lua` (1763 lines changed in that file alone).

Your fork went the opposite way: lazy.nvim, one file per plugin under `lua/custom/plugins/`.
**A merge is not viable and would destroy your structure.**

### Repo layout — your setup is already correct, and you designed it

I claimed `~/.config/nvim` was symlink-managed via `~/.dotfiles`. **That was wrong, and it
created the confusion.** There is no symlink, no submodule, and nothing is duplicated. What's
actually there:

- `~/.dotfiles` is a **bare** repo (`bare = true`) with work-tree `$HOME`, remote
  `HonkyTonkRobot/dotfiles`, tracking **86 files**
- its `.gitignore` ends with:
  ```
  # separate repo (kickstart.nvim fork, cloned by bootstrap)
  /.config/nvim/
  ```
- `bootstrap.sh:194-219` carries a long comment **you wrote** explaining the choice: the
  directory "has two potential owners: this script and whoever is editing nvim config",
  clone-if-missing "silently never arrived", and pulling "would be writing into a work tree it
  does not own and could fight uncommitted local edits". So it reports state and prints the
  command instead.
- `~/.config/nvim` is its own repo → `HonkyTonkRobot/kickstart.nvim`
- verified: **no** symlinks anywhere in the config, **no** `.gitmodules`, exactly **one**
  `init.lua` on disk

So nvim is **deliberately excluded** from dotfiles, not brought through it, not a subrepo, not
duplicated. You already solved this and documented why.

**Should it be a submodule instead? No.** A submodule pins a commit, so every nvim tweak would
need a pointer bump committed in dotfiles — friction on the thing you edit most. Your bootstrap
already has better ergonomics, and a fork needs its own upstream remote, which a submodule adds
nothing to.

### The two goals you named

**Goal 1 — make working with upstream maintainers easy.** Add their remote once, then branch off
*their* code rather than yours:

```bash
cd ~/.config/nvim
git remote add upstream https://github.com/nvim-lua/kickstart.nvim.git
git fetch upstream

# contributing a fix upstream — branch from pristine upstream, not from main
git switch -c fix/some-bug upstream/master
# ...make the fix against their tree...
git push -u origin fix/some-bug
# then open the PR: HonkyTonkRobot:fix/some-bug -> nvim-lua:master
```

Your `main` never has to resemble upstream for this to work. This is the standard "fork with a
divergent main" workflow, and it's why the divergence costs you nothing.

**Goal 2 — your stripped-down, modularized config.** That's `main`, and it already exists. Pull
improvements in by hand-porting or cherry-picking per the table below — never by merging, since
upstream now uses `vim.pack` and a single 1035-line `init.lua`.

Optional convenience: `git branch upstream-main upstream/master` gives you a pristine local
mirror to diff against (never commit to it). Not required — `upstream/master` after a `fetch`
does the same job.

### Set up for repeatable comparison (do this once)

```bash
cd ~/.config/nvim
git remote add upstream https://github.com/nvim-lua/kickstart.nvim.git
git fetch upstream
```

Then, ongoing:
```bash
git diff upstream/master -- lua/kickstart/       # what upstream changed in shared paths
git show upstream/master:init.lua > /tmp/upstream-init.lua
```

### The re-base pattern you described, applied here

For each item below: pull upstream's block out of `/tmp/upstream-init.lua`, diff it against your
equivalent file, take the fix, and re-apply your deliberate deviations on top. Your deviations
are documented in your own commit messages — `54ac7b0` (telescope ignore policy), `f6bb6de`
(render-markdown workaround), `2cf8cf3` (treesitter `main` port) — so consult those before
overwriting anything in those three areas.

| Upstream commit | What | Applies to |
|---|---|---|
| `b1af659` | `ts_ls` → `tsc` (typescript7 builtin LSP) | `nvim-lspconfig.lua` server list |
| `bd53f28` + `b01d052` | Fix corrupted `lua_ls` library path & diagnostics | your `lua_ls` block |
| `3a2194f` | Call `mason-lspconfig.setup()` explicitly to avoid UB | likely applies directly |
| `a5d4d12` | Fix deprecated diagnostic-jumping config | your `<leader>q` / jump maps |
| `9b4fbc5` | Fix conflict between builtin incremental-selection and `mini.ai` keymaps | **you run both — real conflict** |
| `f27810d` + `c7f05a0` | Treesitter indent fixes + indentation fallback | relevant post-`main` port |
| `ce353a9` | `format_on_save` → whitelist instead of blacklist | `conform.lua` (see §10) |
| `459b868` | `stylua` as an LSP formatter, not external | optional — you have stylua commented out |
| `ec3f448` | `nvim-web-devicons` → `mini.icons` | drops a dependency (3 of your files require devicons) |
| `716d746` | `vim.loader.enable()` for faster startup | one line, take it |
| `845db23` / `f7b845d` / `d316830` | Align gitsigns keymaps with gitsigns' defaults | cross-check against §7 |

Skip entirely: everything `vim.pack`-related (`c460542`, `2fccee4`, `2e8d5b1`), README/CI/
issue-template churn, and the init.lua sectioning.

---

## 10. The two options.lua issues — ✅ DONE & VERIFIED

### (a) The trailing-whitespace autocmd

`lua/options.lua:15-22` currently:
```lua
autocmd BufWritePre * :%s/\s\+$//e
autocmd BufWritePre *.md :let b:trim_whitespace = 0
```
Three problems: `b:trim_whitespace` is **never read by anything**, so markdown whitespace (a
significant line break in markdown) gets stripped anyway; `:%s` clobbers your last search pattern
and search history on every write, and moves the cursor; and it duplicates work conform already
owns.

**Fix — hand it to conform.** Your `formatters_by_ft` is currently **empty**, so conform is doing
nothing but LSP fallback; this gives it a real job. In `lua/custom/plugins/conform.lua`:

```lua
-- add markdown to the existing disable list
local disable_filetypes = { c = true, cpp = true, markdown = true }

-- and populate formatters_by_ft (currently empty):
formatters_by_ft = {
  ["*"] = { "trim_whitespace" },
},
```
`trim_whitespace` is a conform builtin — confirmed present at
`conform.nvim/lua/conform/formatters/trim_whitespace.lua` (there's a `trim_newlines` too if you
want it). Then **delete both `vim.cmd` autocmd blocks** from `options.lua`.

This trims on save everywhere except c/cpp/markdown, with no register clobbering and no cursor
jump. It also lines up with upstream's `ce353a9` (whitelist instead of blacklist) if you take
that cherry-pick.

### (b) Global `spell = true`

`lua/options.lua:57` spell-checks code, panels, and diffs — not just prose. (§1's hook already
handles diff windows.) Scope it to prose filetypes:

```lua
-- remove: vim.o.spell = true
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "gitcommit", "text" },
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = { "en_us" }
  end,
})
```

### Also while you're in there
- `options.lua:33` comment typo: "Trim trailing whitGespace"
- `init.lua:76` — `lazy.setup` has no `rocks = { enabled = false }`; harmless, but it's why
  `:checkhealth lazy` warns about luarocks

---

## 11. blink.cmp Rust fuzzy matcher — ✅ DONE

Found in `:checkhealth`. Your `blink-cmp.lua` has:

```lua
-- TODO: [fast] rust implementation
fuzzy = { implementation = 'lua' },
```

That TODO can be closed right now:
- `:checkhealth blink.cmp` says **"Your system is supported by pre-built binaries
  (x86_64-unknown-linux-gnu)"** ✅
- but **"blink_cmp_fuzzy lib is not downloaded/built"** ⚠
- `cargo` and `rustc` are both installed (`~/.cargo/bin/`), so a local build works too
- `blink.cmp/target/release/` doesn't exist — nothing built yet

**Applied** — `fuzzy = { implementation = 'prefer_rust_with_warning' }`.

Note `:Lazy build blink.cmp` is a no-op here (finishes in 0ms); blink fetches the prebuilt
binary lazily on first real load. After starting nvim normally, verified:
- `✅ OK blink_cmp_fuzzy lib is downloaded/built`
- `libblink_cmp_fuzzy.so` present in `blink.cmp/target/release/`

TODO closed.

### luarocks — nothing to remove, just silence it

You asked whether to get rid of it. **There is nothing to get rid of.** Verified:
- `~/.local/share/nvim/lazy-rocks/` **does not exist** — nothing was ever installed
- no system `luarocks` on PATH either

The warning is lazy.nvim's optional rocks feature reporting that a bootstrap it *would* use
isn't present. Lazy itself says in the same report: *"no plugins require `luarocks`, so you can
ignore any warnings below"*. **None of your config needs it** — it's for plugins distributed as
LuaRocks packages, and you have none.

To stop it appearing in `:checkhealth`, disable the feature in `init.lua`'s `lazy.setup` opts:
```lua
require("lazy").setup({
  { import = 'custom.plugins' },
}, {
  rocks = { enabled = false },
  ui = { ... },
})
```

### Other checkhealth output — all benign
Unused language providers (node/perl/python/ruby) and Mason warnings for languages you don't use.
The one graphics-protocol ERROR is an artefact of running headless.

---

## 12. Markdown tables that don't wrap to the viewport — ✅ DONE

**This is a known, unsolved limitation of render-markdown.nvim, not a setting you've missed.**
[Issue #616 "Cell-wrapping for wide tables"](https://github.com/MeanderingProgrammer/render-markdown.nvim/issues/616)
is **open** (filed March 2026, with an open PR #617). The maintainer's wiki puts it plainly:
when a table is wider than the window, render-markdown has no way to gracefully reflow it.

The root cause is structural: normal `wrap` breaks the *entire source row*, so the borders stop
lining up — which is exactly the fragmenting you're seeing. Nothing in `pipe_table` fixes it:

| `pipe_table.cell` | what it does | helps? |
|---|---|---|
| `padded` (your current default) | pads cells to the widest value per column | no — makes it wider |
| `trimmed` | as padded, but empty space subtracted from width | marginal |
| `raw` | only replaces `\|` characters, cells untouched | no wrapping, but lets `wrap` act |
| `overlay` | writes over the table, drops conceal | no |

### Recommended: `ice345/markdown-table-wrap.nvim`

[markdown-table-wrap.nvim](https://github.com/ice345/markdown-table-wrap.nvim) is **purpose-built
for this exact problem** — its README's "Why" section describes your symptom verbatim: *"Normal
Neovim line wrapping breaks an entire Markdown source row, so table borders no longer line up
when one cell contains long prose, CJK text, code, or a URL."*

- parses the table, measures with `nvim_strwidth()`, allocates available width, and **wraps
  inside each rendered cell**
- **designed to coexist with render-markdown** — "does not fork or patch `render-markdown.nvim`"
- active: 42 commits, tip **2026-09-04**
- Neovim 0.10+, **no external binaries**
- handles CJK/Latin widths, escaped pipes, pipes inside backticks, blockquoted tables
- source stays canonical — automatic rendering never rewrites your markdown

Setup is two changes — add the plugin, and turn off render-markdown's table renderer (its
documented coexistence config):

```lua
-- lua/custom/plugins/render-markdown.lua
opts = {
  pipe_table = { enabled = false },
  completions = { lsp = { enabled = true } },
},
```
```lua
-- lua/custom/plugins/markdown-table-wrap.lua
return {
  "ice345/markdown-table-wrap.nvim",
  ft = { "markdown" },
  opts = {},
}
```

**The caveat, resolved.** The plugin has three views. **Reader** (the default) swaps your buffer
for a *separate* protected, unlisted buffer — it rebinds normal-mode `y`/`d` as guarded
`yic`/`dic` prefixes, and needs passthrough config for bufferline `H`/`L`. **Inline** is an
extmark layer over your real buffer — the same model as render-markdown, so insert/normal
behaviour is unchanged. We use Inline:

```lua
preview_mode = "inline", inline_mode = "replace", inline_wrap_scope = "always",
```

Verified after install: buffer stays `buflisted=true`, `modifiable=true`, `buftype=""` — your own
buffer, not a derived Reader. Kept the default wrap-every-column policy (the `viewport` slice mode
with `:MarkdownTableViewportLeft/Right` remains available if you ever want it).

**Measured at several widths** — rendered rows always fit, and it caps sensibly on wide screens:

| columns | max rendered row |
|---|---|
| 60 | 48 |
| 80 | 66 |
| 100 | 76 |
| 140 | 76 (capped, doesn't stretch pointlessly) |

Extmark handoff is clean: render-markdown went 45 → 24 marks, with `markdown-table-wrap` picking
up the table rendering.

### Alternatives considered

- [`gunasekar/markview-smart-tables.nvim`](https://github.com/gunasekar/markview-smart-tables.nvim)
  — fits tables to the window when `wrap` is on, but requires **switching from render-markdown to
  markview.nvim**, and it's only 3 commits (tip 2026-06-22). Bigger change, less proven.
- [`dominic-righthere/markdown-pipetable.nvim`](https://github.com/dominic-righthere/markdown-pipetable.nvim)
  — sizes tables to the window but **truncates** overflowing columns with `…` and `›` rather than
  wrapping. Different tradeoff; doesn't give you the text.
- Doing nothing but `cell = 'trimmed'` — cheapest, marginal gain. Worth trying first if you'd
  rather not add a plugin.

## Answered — nothing to do

- **Inline diagnostics.** Already on all the time. `nvim-lspconfig.lua:139-151` configures
  `virtual_text` with a `format` covering ERROR/WARN/INFO/HINT. Nothing to change. (Optional:
  nvim 0.11+ adds `virtual_lines` for full multi-line diagnostics.) My earlier `BufEnter` /
  `nvim_feedkeys` note was **only** about lorem.nvim grabbing `<Tab>`/`<CR>` — unrelated to
  diagnostics.

- **"Buffer-local maps" is not a plugin.** It's a Vim concept: `vim.keymap.set(..., { buffer = 0 })`
  creates a mapping that exists in one buffer only and **outranks a global mapping** of the same
  key. Nothing to switch to — it was just the mechanism lorem.nvim uses to grab `<Tab>` in every
  buffer you open. See §6(b) if you want that gone.

- **Command history.** Nothing broken. `history = 10000` and `main.shada` (11.3K) is written
  normally; `shada` is nvim's default (`!,'100,<50,s10,h,r/tmp/,r/private/`). It's sparse because
  you haven't used nvim much on this machine — as you said.

- **nvim-ghost.** Fully gone: nothing on disk, no process, no systemd unit. The log errors stop
  at 13:56 on 2026-09-07, just before your 14:00 removal commit.

- **glow.** Not installed either (`which glow` empty, no files, no config reference). Whatever
  you saw in `:Lazy` yesterday is gone now.

---

## Execution order for the rest

1. ~~§1 diffview wrap hook~~ ✅ done
2. ~~§2 maintained fork~~ ✅ done
3. §7 gitsigns descs + §4 mini org rename — trivial, zero risk
4. §5 delete `lua/kickstart/plugins/` + add `mini.pairs` / `mini.files`
5. §3 indent-blankline → `mini.indentscope`, then retest the render-markdown hack
6. §6 lorem — option (a) or (b)
8. §4 telescope `0.1.x` → `master` — **riskiest; do it alone with time to test and revert**
9. §9 add the `upstream` remote, then cherry-pick one at a time

Commit each step separately so anything can be reverted in isolation.
