Pod::Spec.new do |s|
  s.name         = "GBPing"
  s.version      = "0.0.1"
  s.summary      = "Highly accurate ICMP Ping controller for iOS"
  s.homepage     = "https://github.com/lmirosevic/GBPing"
  s.license      = { :type => "Apache", :file => "LICENSE" }
  s.author             = "Luka Mirosevic"
  s.source       = { :git => "https://github.com/lmirosevic/GBPing.git", :commit => "230665a5b0d688c8ab5025c842065a99c69f97fa" }
  s.source_files  = "GBPing"
  s.public_header_files = "GBPing/**/*.h"
  s.requires_arc = true
  s.dependency 'GBToolbox'
  s.ios.deployment_target = '5.0'
end
