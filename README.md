# joard.

**joard.** is a browser-based collaborative infinite whiteboard with a Matrix-inspired dark interface and a Modrinth-green palette. It is a static website, so the front end can be hosted on GitHub Pages. Supabase provides optional realtime collaboration, cloud board storage, and version history.

## Project files

- `index.html` — complete self-contained website and app logic.
- `supabase-setup.sql` — schema and starter row-level security policies for board objects, named boards, and revision history.
- `README.md` — setup and usage guide.

## Features

- Infinite-style canvas with right-button drag panning, mouse-wheel zoom, plus/minus buttons, fit-to-content, and saved per-board view state.
- Pen, highlighter, pixel eraser, line, arrow, rectangle, ellipse, text, sticky notes, color picker, stroke size control, and PNG export.
- Clipboard paste for text and images, plus in-app object copy/cut/paste.
- Separate whiteboards with create, open, rename, save, local autosave, cloud board library, version snapshots, and point-in-time restoration.
- Named frames and sections, diagram library with UML, architecture, cloud-provider-style symbols, wireframes, mind maps, and Kanban elements.
- Layer controls for selecting, showing/hiding, locking, and reordering objects.
- Built-in starter templates: Brainstorm, SWOT analysis, Sprint retrospective, Empathy map, and Action plan. Notes and headings are regular editable objects.
- Reaction/voting stamps that place emoji reactions on the shared canvas.
- Live collaborative cursors and board-object updates when Supabase is configured.
- Matrix-inspired animated code texture, dark panels, neon green accents, and a Modrinth-inspired palette.

## Publish on GitHub Pages

1. Extract the ZIP and upload the **contents** of the `joard` folder to the root of a GitHub repository.
2. Open **Settings → Pages** in the repository.
3. Under **Build and deployment**, choose **Deploy from a branch**, then select `main` and `/(root)`.
4. Save. GitHub Pages serves `index.html` directly; no build step is required.

## Enable cloud sync and cross-device saving

1. Create a project at [supabase.com](https://supabase.com/).
2. In your project's **SQL Editor**, paste the entire contents of `supabase-setup.sql` and click **Run**.
3. Copy your Supabase **Project URL** and public **anon/publishable key** from the project settings.
4. Open joard., click the settings gear, enter your display name, Project URL, and public key, and choose **Connect & save**.
5. Collaborators must use the same Supabase project and open the same shared board URL.

If you already have a Supabase project configured from an earlier build, run this SQL again to ensure all expected tables and policies exist. The SQL uses `create table if not exists` and replaces the starter policies by name.

## Storage and revision history

- **Without Supabase:** boards, titles, and a small set of recent revisions remain in this browser's local storage. They survive closing and reopening the website in the same browser profile, but do not move across devices. Clearing browser storage may remove them.
- **With Supabase:** the board library and objects can sync to the cloud, collaborators receive realtime updates, and revision snapshots support restoring earlier board states. Restoration replaces the current shared board contents.
- GitHub Pages hosts only the website; it does not provide a database, user accounts, or realtime synchronization.

## Keyboard shortcuts

| Shortcut | Action |
|---|---|
| `V` | Select/move tool |
| `P` | Pen |
| `H` | Highlighter |
| `E` | Eraser |
| `L` | Line |
| `A` | Arrow |
| `R` | Rectangle |
| `O` | Ellipse |
| `T` | Text tool |
| `N` | Sticky-note tool |
| `Ctrl/Cmd + C` | Copy selected object |
| `Ctrl/Cmd + X` | Cut selected object |
| `Ctrl/Cmd + V` | Paste clipboard text/image or duplicate copied object |
| `Ctrl/Cmd + Z` | Undo |
| `Ctrl/Cmd + Y` | Redo |
| `Ctrl/Cmd + Shift + Z` | Redo |
| `Delete` / `Backspace` | Delete selected object |
| `+` / `-` | Zoom in/out |
| `F` | Fit visible objects |
| `Ctrl/Cmd + 0` | Reset zoom/view |
| `G` | Toggle dot grid |

## Inspiration from Microsoft Whiteboard

Microsoft documents features such as a create panel for text, images, shapes, reactions and templates; brainstorming/project-planning templates; reactions for lightweight voting; and collaborative cursors. joard. includes its own implementation of selected ideas as a set of editable open-canvas objects rather than trying to reproduce Microsoft Whiteboard's proprietary UI or integrations.

- [Microsoft Whiteboard Create panel](https://support.microsoft.com/en-us/whiteboard/whiteboard-create-panel)
- [Microsoft Whiteboard templates](https://support.microsoft.com/en-us/whiteboard/insert-templates-in-whiteboard)
- [Microsoft Whiteboard tips and tricks](https://support.microsoft.com/en-us/whiteboard/tips-and-tricks-for-microsoft-whiteboard)
- [Microsoft Whiteboard infinite canvas](https://support.microsoft.com/en-us/whiteboard/unleash-ideas-on-microsoft-whiteboard-s-infinite-canvas)

## Security warning

The included SQL is a **starter schema with broad anonymous read/write policies**. Anyone with the project URL, public key, and a board ID may be able to read or modify board data. Do not store private, confidential, or sensitive material in this starter deployment. A private production deployment should add Supabase Auth, user membership, and board-specific row-level security policies. Never put a Supabase `service_role` key in this website.

## Limitations

joard. is a lightweight static starter rather than a production-grade multi-user editor. It does not include account sign-in, private rooms, per-object access permissions, sophisticated simultaneous-edit conflict resolution, or separate cloud storage for large image assets. Browser clipboard permissions vary, and a user may need to click the board before pasting or grant browser permission.
