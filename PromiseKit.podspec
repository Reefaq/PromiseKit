Pod::Spec.new do |s|
  s.name         = "PromiseKit"
  s.version      = "1.0"
  s.source       = { :git => "https://github.com/mxcl/PromiseKit.git" }
  s.requires_arc = true
  s.source_files = '**/{P,D}*.{m,h}'
  s.dependency     'ChuzzleKit'
end
