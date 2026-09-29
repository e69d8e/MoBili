//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <app_links/app_links_plugin_c_api.h>
#include <flutter_volume_controller/flutter_volume_controller_plugin_c_api.h>
#include <screen_brightness_windows/screen_brightness_windows_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AppLinksPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AppLinksPluginCApi"));
  FlutterVolumeControllerPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterVolumeControllerPluginCApi"));
  ScreenBrightnessWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenBrightnessWindowsPluginCApi"));
}
