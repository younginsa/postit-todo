#!/usr/bin/env ruby
require 'xcodeproj'

ROOT = File.expand_path(File.dirname(__FILE__))
APP_GROUP = 'group.com.younginsa.googit'
DEPLOY = '17.0'

proj_path = File.join(ROOT, 'Googit.xcodeproj')
File.delete(proj_path) if File.file?(proj_path)
require 'fileutils'
FileUtils.rm_rf(proj_path)

project = Xcodeproj::Project.new(proj_path)

# ---- Groups (file references) ----
shared_group = project.new_group('Shared', 'Shared')
app_group_g  = project.new_group('App', 'App')
widget_group = project.new_group('Widget', 'Widget')

shared_files = Dir[File.join(ROOT, 'Shared', '*.swift')].sort
app_swift    = Dir[File.join(ROOT, 'App', '*.swift')].sort
widget_swift = Dir[File.join(ROOT, 'Widget', '*.swift')].sort

shared_refs = shared_files.map { |f| shared_group.new_reference(f) }
app_refs    = app_swift.map    { |f| app_group_g.new_reference(f) }
widget_refs = widget_swift.map { |f| widget_group.new_reference(f) }

app_assets_ref    = app_group_g.new_reference(File.join(ROOT, 'App', 'Assets.xcassets'))
app_resource_refs = (Dir[File.join(ROOT, 'App', '*.wav')] + Dir[File.join(ROOT, 'App', '*.png')]).sort.map { |f| app_group_g.new_reference(f) }
widget_assets_ref = widget_group.new_reference(File.join(ROOT, 'Widget', 'Assets.xcassets'))
app_entitlements_ref = app_group_g.new_reference(File.join(ROOT, 'App', 'Googit.entitlements'))
widget_info_ref      = widget_group.new_reference(File.join(ROOT, 'Widget', 'Info.plist'))
widget_entitlements_ref = widget_group.new_reference(File.join(ROOT, 'Widget', 'GoogitWidget.entitlements'))

# ---- App target ----
app = project.new_target(:application, 'Googit', :ios, DEPLOY)
(app_refs + shared_refs).each { |r| app.source_build_phase.add_file_reference(r) }
app.resources_build_phase.add_file_reference(app_assets_ref)
app_resource_refs.each { |r| app.resources_build_phase.add_file_reference(r) }

# ---- Widget extension target ----
widget = project.new_target(:app_extension, 'GoogitWidget', :ios, DEPLOY)
(widget_refs + shared_refs).each { |r| widget.source_build_phase.add_file_reference(r) }
widget.resources_build_phase.add_file_reference(widget_assets_ref)

# ---- Common build settings ----
def common(bc)
  s = bc.build_settings
  s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOY rescue nil
  s['SWIFT_VERSION'] = '5.0'
  s['SDKROOT'] = 'iphoneos'
  s['TARGETED_DEVICE_FAMILY'] = '1'        # iPhone only
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['ENABLE_USER_SCRIPT_SANDBOXING'] = 'YES'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
end

DEPLOY_TARGET = DEPLOY
app.build_configurations.each do |bc|
  s = bc.build_settings
  s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOY_TARGET
  s['SWIFT_VERSION'] = '5.0'
  s['SDKROOT'] = 'iphoneos'
  s['TARGETED_DEVICE_FAMILY'] = '1'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.younginsa.googit'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['CODE_SIGN_ENTITLEMENTS'] = 'App/Googit.entitlements'
  s['INFOPLIST_KEY_CFBundleDisplayName'] = '구깃'
  # 수출규정(암호화) 질문 자동 면제 — 업로드마다 묻지 않게
  s['INFOPLIST_KEY_ITSAppUsesNonExemptEncryption'] = 'NO'
  s['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  s['INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents'] = 'YES'
  s['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  s['INFOPLIST_KEY_UISupportedInterfaceOrientations'] = 'UIInterfaceOrientationPortrait'
  s['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon'
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  s['ENABLE_PREVIEWS'] = 'YES'
end

widget.build_configurations.each do |bc|
  s = bc.build_settings
  s['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOY_TARGET
  s['SWIFT_VERSION'] = '5.0'
  s['SDKROOT'] = 'iphoneos'
  s['TARGETED_DEVICE_FAMILY'] = '1'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['MARKETING_VERSION'] = '1.0'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.younginsa.googit.GoogitWidget'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['INFOPLIST_FILE'] = 'Widget/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS'] = 'Widget/GoogitWidget.entitlements'
  s['INFOPLIST_KEY_CFBundleDisplayName'] = '구깃'
  s['ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME'] = 'AccentColor'
  s['ASSETCATALOG_COMPILER_WIDGET_BACKGROUND_COLOR_NAME'] = 'WidgetBackground'
  s['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  s['ENABLE_PREVIEWS'] = 'YES'
  s['SKIP_INSTALL'] = 'YES'
end

# ---- Embed widget extension into the app ----
app.add_dependency(widget)
embed = app.new_copy_files_build_phase('Embed Foundation Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(widget.product_reference)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy', 'CodeSignOnCopy'] }

# ---- Project-level settings ----
project.build_configurations.each do |bc|
  bc.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = DEPLOY_TARGET
  bc.build_settings['SWIFT_VERSION'] = '5.0'
end

project.save
puts "Generated: #{proj_path}"
puts "Targets: #{project.targets.map(&:name).join(', ')}"
