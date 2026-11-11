# The part of in_app_notifications that runs in the app's Notification Service Extension (a push's image). No Flutter:
# an extension can't link it. The app's Podfile adds it to the extension's target.
Pod::Spec.new do |s|
  s.name             = 'InAppNotificationsService'
  s.version          = '0.17.0'
  s.summary          = "A push's image, for in_app_notifications' Notification Service Extension."
  s.homepage         = 'https://github.com/Mohiuddin655-PUB/flutter_in_app_notifications'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Mohiuddin'
  s.source           = { :path => '.' }
  s.source_files     = 'service/**/*.swift'
  s.platform         = :ios, '15.0'
  s.swift_version    = '5.0'
end
