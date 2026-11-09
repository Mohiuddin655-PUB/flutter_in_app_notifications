#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint in_app_notifications.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'in_app_notifications'
  s.version          = '0.8.0'
  s.summary          = 'How a notification shows while the app is open, for in_app_notifications.'
  s.description      = <<-DESC
How a notification shows while the app is open, for in_app_notifications.
                       DESC
  s.homepage         = 'https://github.com/Mohiuddin655-PUB/flutter_in_app_notifications'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Mohiuddin'
  s.source           = { :path => '.' }
  s.source_files = 'in_app_notifications/Sources/in_app_notifications/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

end
