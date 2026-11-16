#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

std::wstring GetExecutableDirectory() {
  wchar_t buffer[MAX_PATH];
  GetModuleFileNameW(nullptr, buffer, MAX_PATH);
  std::wstring path(buffer);
  size_t last_slash = path.find_last_of(L"\\/");
  if (last_slash != std::wstring::npos) {
    return path.substr(0, last_slash);
  }
  return L"";
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to parent console if run from CMD/PowerShell so stdout/stderr output is visible
  CreateAndAttachConsole();

  // Ensure current working directory is the executable's directory so bundled DLLs and data paths resolve
  std::wstring exe_dir = GetExecutableDirectory();
  if (!exe_dir.empty()) {
    SetCurrentDirectoryW(exe_dir.c_str());
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  std::wstring data_dir = exe_dir.empty() ? L"data" : (exe_dir + L"\\data");
  flutter::DartProject project(data_dir);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"fatoura", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
