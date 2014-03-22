Gem::Specification.new do |s|
  s.name = "webink"
  s.version = '3.2.0'
  s.summary = "A minimal web framework."
  s.author = "Matthias Geier"
  s.homepage = "https://github.com/matthias-geier/WebInk"
  s.licenses = ['BSD-2']
  s.require_path = 'lib'
  s.files = Dir['lib/*.rb'] + Dir['lib/webink/*.rb'] +
    Dir['lib/webink/extensions/*.rb'] + Dir['lib/webink/association/*.rb'] +
    Dir['bin/*'] + [ "LICENSE.md" ]
  s.executables = ["webink_database", "webink_init"]
  s.required_ruby_version = '>= 1.9.3'
  s.add_runtime_dependency('rack', '~> 1.5')
  s.add_runtime_dependency('webink_r', '~> 0.3')
end
