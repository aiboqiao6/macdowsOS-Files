# macdowsOS Files Code Architecture

## Layers

```text
main.cpp
  -> QQmlApplicationEngine
  -> registers FileIconProvider (image://file-icons)
  -> loads qrc:/qt/qml/macdowsos files/main.qml

main.qml
  -> nav: current folder and back/forward history
  -> FolderListModel: native folder/file rows
  -> SidebarList: personal folders and drives
  -> FileListView: selection, double-click, and context menu

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

1. `main.cpp` creates `QGuiApplication` and configures the Qt Quick Controls style.
2. The native `file-icons` image provider is registered with the QML engine.
3. `main.qml` loads the window, creates the navigation object, and points `FolderListModel` at the home directory.
4. `FileLocations` discovers standard user folders and mounted drives for the sidebar.
5. The current path is pushed into `FolderListModel.folder`; QML delegates render the rows.

## Interaction Flow

- Sidebar click -> `SidebarList.itemClicked(path)` -> `nav.navigateTo(path)` -> model refresh.
- Back/forward -> `nav.historyStack` changes -> `nav.setCurrent()` updates the sidebar and folder model.
- File single-click -> `FileListView` stores `currentIndex` and shows the Finder-style selection.
- File double-click -> folder emits `folderClicked`; regular file emits `fileClicked` and opens through the default Windows association.
- File right-click -> shared `Menu` offers open, reveal in Explorer, copy path, and refresh.

## File Responsibilities

| File | Responsibility |
| --- | --- |
| `main.cpp` | Qt application bootstrap and QML registration |
| `main.qml` | Window shell, navigation state, toolbar, and layout |
| `FileLocations.h/.cpp` | Sidebar model and native filesystem helpers |
| `FileIconProvider.h/.cpp` | Windows-associated icons for regular files |
| `SidebarList.qml` | Sidebar sections, icons, selection, and navigation signal |
| `FileListView.qml` | Finder-style rows, selection, activation, and context menu |
| `LineIcon.qml` | Font-independent vector fallback icons |
| `WindowControls.qml` | macOS-style window control buttons |
| `qml.qrc` | Compiled QML and image resource manifest |

