# macdowsOS Files Code Architecture

## Layers

```text
main.cpp
  -> QQmlApplicationEngine
  -> registers FileIconProvider (image://file-icons)
  -> WindowManager creates one main.qml instance per window
  -> WindowsIntegration manages per-user folder/drive default verbs

main.qml
  -> nav: current folder and back/forward history
  -> FolderListModel: native folder/file rows
  -> FileFilterModel: literal, case-insensitive search for files and directories
  -> SidebarList: personal folders and drives
  -> FileListView: list/grid views, shared selection, keyboard navigation, and context menu
  -> preview: image preview and selected-file metadata

FinderTheme + GlassSurface + FinderButton + FinderMenu/FinderMenuItem
  -> shared neutral dark palette, glass-like capsules, and popup styling

NativeShell (C++)
  -> Windows compositor Acrylic behind the translucent sidebar
  -> IShellFolder / IContextMenu native file, directory, and background menus
  -> IContextMenu2/3 message forwarding for Shell extension submenus
  -> IFileOperation rename with the Windows undo record

FileLocations (C++)
  -> builds sidebar roles: name/path/icon/section
  -> normalizes paths, copies paths, reveals items in Explorer

FileIconProvider (C++)
  -> asks Qt/Windows for the registered file-type icon
  -> returns it to QML as image://file-icons/<encoded-path>

qml.qrc + assets/icons
  -> packages QML components and bundled visual assets into the executable
```

## Startup Flow

1. `main.cpp` creates `QApplication` and configures the Qt Quick Controls style. Qt Widgets supplies the Shell menu presentation; the main window remains Qt Quick.
2. The native `file-icons` image provider is registered with the QML engine.
3. `WindowManager` creates `main.qml` with an initial folder from `--open`, positional arguments, or the home directory. Each window owns a `NativeShellBackend`, navigation object, folder/filter model, selection, and view state.
4. `FileLocations` discovers standard user folders and mounted drives for the sidebar.
5. The current path is pushed into `FolderListModel.folder`; `FileFilterModel` preserves its roles and exposes matching rows to both views.

## Interaction Flow

- Sidebar click -> `SidebarList.itemClicked(path)` -> `nav.navigateTo(path)` -> model refresh.
- Back/forward -> `nav.historyStack` changes -> `nav.setCurrent()` updates the sidebar and folder model.
- File single-click -> `FileListView` stores `selectedIndex` and file metadata, then updates the shared preview.
- File double-click -> folder emits `folderClicked`; regular file emits `fileClicked` and opens through the default Windows association.
- File right-click -> `NativeShell` obtains the current item's Windows Shell menu, including installed extension commands. Blank-area right-click requests the current directory's background menu.
- Menu coordinates map from QML to global logical coordinates for Qt popup placement; Shell command invocation receives native screen pixels for the window's DPI. Menu/Shift+F10 also opens the Shell menu.
- Shell handles command invocation; Rename requests the host's name editor, then runs `IFileOperation` with undo support.
- Search -> `FileFilterModel.searchText` filters names literally, including directory names; view switches preserve selection.
- Refresh -> the proxy resets and restores the source folder without removing the navigation binding.
- Preview automatically hides below a window width of 1060 logical pixels. The sidebar remains draggable from 190 to 300 pixels.
- Recent and Shared are the existing Windows Recent shortcut directory and Public folder. These entries appear only when the directories exist.

## File Responsibilities

| File | Responsibility |
| --- | --- |
| `main.cpp` | Qt application bootstrap and QML registration |
| `WindowManager.h/.cpp` | Creates independent QML windows, destroys closed windows, and quits after the last browser closes |
| `WindowsIntegration.h/.cpp` | Backs up/restores per-user Directory/Drive default Shell verbs and registers the executable command |
| `main.qml` | Window shell, navigation state, toolbar, and layout |
| `FileLocations.h/.cpp` | Sidebar model and native filesystem helpers |
| `FileFilterModel.h/.cpp` | Search proxy, role lookup, item count, and refresh |
| `NativeShell.h/.cpp` | Native Acrylic, COM Shell menus, extension message forwarding, and rename |
| `FileIconProvider.h/.cpp` | Windows-associated icons for regular files |
| `SidebarList.qml` | Sidebar sections, icons, selection, and navigation signal |
| `FileListView.qml` | Finder-style rows, selection, activation, and context menu |
| `LineIcon.qml` | Font-independent vector fallback icons |
| `WindowControls.qml` | macOS-style window control buttons |
| `FinderTheme.qml` | Central colors and layout dimensions |
| `GlassSurface.qml`, `FinderButton.qml` | Reusable capsule surfaces and toolbar controls |
| `FinderMenu.qml`, `FinderMenuItem.qml` | Shared dark popup and menu-item styles |
| `qml.qrc` | Compiled QML and image resource manifest |

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| Alt+Left / Alt+Right / Alt+Up | Back / forward / parent folder |
| Ctrl+L / Ctrl+F | Edit folder path / search current folder |
| Ctrl+N / Ctrl+W | New independent window at the current folder / close current window |
| Ctrl+1 / Ctrl+2 | Icon / list view |
| Ctrl+Shift+P | Toggle preview at supported window widths |
| F5 | Refresh |
| Arrow keys / Enter / Escape | Select / open / clear selection |
| Menu / Shift+F10 | Windows Shell context menu |

## Native Windows Integration

The sidebar exposes a lightly tinted alpha surface over native Windows Acrylic. The toolbar and file pane paint opaque backgrounds so text and rows remain sharp. The effect requires a Windows build with Acrylic support and Transparency Effects enabled; it is verified on the current Windows 11 installation. The app reads the preference without changing it and reapplies the material after settings/composition changes, activation, and resizing.

Acrylic uses the optional `SetWindowCompositionAttribute` compositor export with `ACCENT_ENABLE_ACRYLICBLURBEHIND`, resolved at runtime. This is an undocumented Windows API, isolated in `NativeShell` for compatibility maintenance. When the export is absent or rejects the request, or transparency is disabled, QML uses an opaque sidebar.

The main window uses a 24-logical-pixel corner radius, shared by the QML alpha mask and `QWindow::setMask` input region. DWM's fixed small corner and border are disabled on this HWND to avoid a second contour. Maximized windows use square corners and the monitor work area. Acrylic on a whole HWND paints rectangular corner backing despite the input region, so a separate transparent, input-pass-through tool window supplies Acrylic behind the central sidebar. Its top/bottom ends stay inside the rounded cutouts, with the QML tint fading to opaque at those ends. Another transparent tool window supplies the standard DWM shadow: it keeps `WS_THICKFRAME`, non-client rendering, and full glass margins, without drawing a border. Both companions track main-window geometry and stacking, hide when the main window is hidden/minimized, and accept no input. The shadow hides when maximized; Acrylic fills the maximized sidebar. These are compositor surfaces and do not appear in the taskbar.

File context menus read the Windows Shell's classic `IContextMenu` API, including installed third-party extensions. Rounded, translucent Qt Widgets `QMenu` windows present the native labels, command IDs, icons, enabled/default/checked states, and separators with Acrylic behind them. Submenus forward `WM_INITMENUPOPUP` before reading lazy extension entries; label-less owner-drawn commands forward measure/draw messages. Shell COM objects and native menu handles remain alive through popup dismissal and command invocation. Qt handles keyboard navigation, screen placement, and scrolling; selected commands invoke the original Shell verb. This uses the classic Shell command set, not Windows 11's separate compact Explorer surface. Release deployment now also includes `Qt6Widgets.dll`.

The Home icon uses the same blue accent as the other personal folder icons in both the sidebar and current-location toolbar. The view/sort/options controls remain application menus because they operate on this app's view state.

Each surface has one outer contour. The main window draws one QML border at the same 24px radius as its masks. Shell popup menus omit their Qt outer border/radius when DWM owns their contour. Glass capsules use one border, embedded toolbar buttons use a borderless state fill, and traffic-light controls use only their outer border.

Each main window creates its own `NativeShellBackend`; compositor companions, HWND event routing, COM menus, rename signals, and errors belong to that window. `WindowManager` queues deletion after close handling and explicitly quits after the last browser window, regardless of companion windows.

Navigation models retain file URLs internally. `FileLocations.nativePath()` converts them to native Windows paths for the always-visible address editor; URL inputs still normalize through the filesystem adapter.

`WindowsIntegration` registers a dedicated `macdowsOSFiles` verb beneath `HKCU\Software\Classes\Directory\shell` and `Drive\shell`, then makes it the default. It persists each prior default value's presence, raw bytes, and registry type before changing either association, rolls back failed installs, and restores only defaults that still name its verb. A newer default set by another application is preserved. An existing foreign handler key prevents installation. The quoted executable command passes `--open "%1/"`; the trailing slash prevents a drive root's backslash from escaping the closing quote during Windows argv parsing. Restoration state persists across process restarts. Win+E and virtual Shell namespaces are outside this integration's scope.
