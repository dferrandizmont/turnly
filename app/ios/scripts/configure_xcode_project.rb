# Idempotent Xcode project setup for the parts Flutter does not generate
# (docs/mac-ios.md §4.1, adapted from mochila-app/app/ios/scripts/):
#   - the CuadranteWidget WidgetKit extension target (sources in
#     CuadranteWidget/, embedded in Runner, App Group entitlements, own
#     privacy manifest and Localizable.strings, versions from Flutter);
#   - Runner/Runner.entitlements as Runner's CODE_SIGN_ENTITLEMENTS;
#   - Runner/PrivacyInfo.xcprivacy (the app's own privacy manifest) in the
#     resources of Runner (docs/mac-ios.md 4.6.1).
#
# Run from app/ios after `flutter pub get` (uses the xcodeproj gem bundled with
# CocoaPods; no gem install, no sudo):
#   GEM_HOME="$(brew --prefix cocoapods)/libexec" ruby scripts/configure_xcode_project.rb
# Without CocoaPods: `gem install --user-install xcodeproj` and plain `ruby`.
# Running it again changes nothing.
#
# Signing: automatic, with the Team ID in ONE place, TEAM_ID below. The
# script writes it as DEVELOPMENT_TEAM into every configuration of Runner and
# of CuadranteWidget in project.pbxproj. To change team, edit TEAM_ID and run
# the script again (changing it in Xcode for Runner only would leave the
# extension on the old team).

require 'xcodeproj'

# The app's five languages: every localized resource below is listed per language.
LANGS = %w[es ca gl eu en].freeze

IOS_DIR = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(IOS_DIR, 'Runner.xcodeproj')

WIDGET_NAME = 'CuadranteWidget'
WIDGET_BUNDLE_ID = 'es.cuadrante.app.CuadranteWidget'
# Same as Runner. containerBackground (iOS 17) is used without availability shims.
WIDGET_DEPLOYMENT_TARGET = '17.0'
RUNNER_ENTITLEMENTS = 'Runner/Runner.entitlements'
# Apple Developer Team (developer.apple.com > Membership details > Team ID).
TEAM_ID = '4J74M2FPLP'

project = Xcodeproj::Project.open(PROJECT_PATH)
runner = project.targets.find { |t| t.name == 'Runner' } or abort('Runner target not found')
changed = false

# --- Runner: entitlements (App Group + time-sensitive notifications) --------
# No iCloud keys: the iCloud replica is disabled by decision (docs/mac-ios.md 0.2).
runner_group = project.main_group.children.find { |g| g.display_name == 'Runner' } or
  abort('Runner group not found')
unless runner_group.files.any? { |f| f.path == 'Runner.entitlements' }
  runner_group.new_reference('Runner.entitlements')
  changed = true
end
runner.build_configurations.each do |config|
  { 'CODE_SIGN_ENTITLEMENTS' => RUNNER_ENTITLEMENTS,
    'DEVELOPMENT_TEAM' => TEAM_ID,
    'CODE_SIGN_STYLE' => 'Automatic' }.each do |key, value|
    next if config.build_settings[key] == value

    config.build_settings[key] = value
    changed = true
  end
end

# --- Runner: Swift sources (IncomingBackupChannel, IncomingFileStore...) ----
# Every .swift file in Runner/ is compiled into Runner, so a new file needs no
# script change (the template only lists AppDelegate and SceneDelegate).
Dir.children(File.join(IOS_DIR, 'Runner')).sort.select { |f| f.end_with?('.swift') }.each do |f|
  source = runner_group.files.find { |r| r.path == f } || (changed = true; runner_group.new_reference(f))
  next if runner.source_build_phase.files_references.include?(source)

  runner.source_build_phase.add_file_reference(source)
  changed = true
end

# --- Runner: privacy manifest ------------------------------------------------
# The app's own PrivacyInfo.xcprivacy (docs/mac-ios.md 4.6.1): the required
# reason APIs the app uses (UserDefaults of the App Group, FileTimestamp of
# the files of the container), no data collected and no tracking. It has to be
# in the resources of the target or it never reaches the bundle.
runner_privacy = runner_group.files.find { |f| f.path == 'PrivacyInfo.xcprivacy' }
unless runner_privacy
  runner_privacy = runner_group.new_reference('PrivacyInfo.xcprivacy')
  runner_privacy.last_known_file_type = 'text.xml'
  changed = true
end
unless runner.resources_build_phase.files_references.include?(runner_privacy)
  runner.resources_build_phase.add_file_reference(runner_privacy)
  changed = true
end

# --- CuadranteWidget target -------------------------------------------------
widget = project.targets.find { |t| t.name == WIDGET_NAME }
unless widget
  widget = project.new_target(:app_extension, WIDGET_NAME, :ios, WIDGET_DEPLOYMENT_TARGET, nil, :swift)
  changed = true
end

group = project.main_group.children.find { |g| g.display_name == WIDGET_NAME } ||
        project.main_group.new_group(WIDGET_NAME, WIDGET_NAME)
ref = lambda do |path|
  group.files.find { |f| f.path == path } || (changed = true; group.new_reference(path))
end

# Swift sources: every .swift file in the directory, so new files need no
# script change.
Dir.children(File.join(IOS_DIR, WIDGET_NAME)).sort.select { |f| f.end_with?('.swift') }.each do |f|
  source = ref.call(f)
  next if widget.source_build_phase.files_references.include?(source)

  widget.source_build_phase.add_file_reference(source)
  changed = true
end

# Resources: the extension's privacy manifest and its Localizable.strings
# (gallery name and description, and the "open Turnly" text shown before the
# app has ever published a snapshot; every other text comes in the JSON).
privacy = ref.call('PrivacyInfo.xcprivacy')
localizable = group.children.find do |c|
  c.isa == 'PBXVariantGroup' && c.name == 'Localizable.strings'
end
unless localizable
  localizable = group.new_variant_group('Localizable.strings')
  changed = true
end
LANGS.each do |lang|
  path = "#{lang}.lproj/Localizable.strings"
  next if localizable.files.any? { |f| f.path == path }

  r = localizable.new_reference(path)
  r.name = lang
  r.last_known_file_type = 'text.plist.strings'
  changed = true
end
[privacy, localizable].each do |res|
  next if widget.resources_build_phase.files_references.include?(res)

  widget.resources_build_phase.add_file_reference(res)
  changed = true
end
LANGS.each do |lang|
  next if project.root_object.known_regions.include?(lang)

  project.root_object.known_regions << lang
  changed = true
end

# Referenced from build settings only (not compiled / copied).
ref.call('Info.plist')
ref.call("#{WIDGET_NAME}.entitlements")
xcconfig = ref.call("#{WIDGET_NAME}.xcconfig")

# Flutter maps Profile like Release; the new target only gets Debug/Release.
unless widget.build_configuration_list['Profile']
  release = widget.build_configuration_list['Release']
  profile = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  profile.name = 'Profile'
  profile.build_settings = release.build_settings.dup
  widget.build_configuration_list.build_configurations << profile
  changed = true
end

widget.build_configurations.each do |config|
  unless config.base_configuration_reference == xcconfig
    config.base_configuration_reference = xcconfig
    changed = true
  end
  s = config.build_settings
  runner_config = runner.build_configurations.find { |c| c.name == config.name }
  wanted = {
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'PRODUCT_BUNDLE_IDENTIFIER' => WIDGET_BUNDLE_ID,
    'INFOPLIST_FILE' => "#{WIDGET_NAME}/Info.plist",
    'GENERATE_INFOPLIST_FILE' => 'NO',
    'CODE_SIGN_ENTITLEMENTS' => "#{WIDGET_NAME}/#{WIDGET_NAME}.entitlements",
    'CODE_SIGN_STYLE' => 'Automatic',
    'IPHONEOS_DEPLOYMENT_TARGET' => WIDGET_DEPLOYMENT_TARGET,
    # Same devices as Runner (iPhone and iPad since 1.1.0).
    'TARGETED_DEVICE_FAMILY' => runner_config&.build_settings&.[]('TARGETED_DEVICE_FAMILY') || '1,2',
    'SWIFT_VERSION' => '5.0',
    'SKIP_INSTALL' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks',
                                  '@executable_path/../../Frameworks'],
    'APPLICATION_EXTENSION_API_ONLY' => 'YES',
    'ENABLE_USER_SCRIPT_SANDBOXING' => 'YES',
    'DEVELOPMENT_TEAM' => TEAM_ID,
  }
  wanted.each do |key, value|
    next if s[key] == value

    s[key] = value
    changed = true
  end
end

# Embed in Runner before "Thin Binary" (Flutter's script phase), otherwise
# Xcode reports a dependency cycle.
unless runner.dependencies.any? { |d| d.target == widget }
  runner.add_dependency(widget)
  changed = true
end
embed = runner.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
unless embed
  embed = runner.new_copy_files_build_phase('Embed Foundation Extensions')
  embed.symbol_dst_subfolder_spec = :plug_ins
  changed = true
end
unless embed.files_references.include?(widget.product_reference)
  build_file = embed.add_file_reference(widget.product_reference)
  build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  changed = true
end
thin = runner.build_phases.find { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
if thin && runner.build_phases.index(embed) > runner.build_phases.index(thin)
  runner.build_phases.delete(embed)
  runner.build_phases.insert(runner.build_phases.index(thin), embed)
  changed = true
end

if changed
  project.save
  puts 'Runner.xcodeproj updated.'
else
  puts 'Runner.xcodeproj already configured.'
end
