Gem::Specification.new do |s|
  s.name = "webink"
  s.version = '3.1.1'
  s.summary = "A minimal web framework."
  s.author = "Matthias Geier"
  s.homepage = "https://github.com/matthias-geier/WebInk"
  s.require_path = 'lib'
  s.files = Dir['lib/*.rb'] + Dir['lib/webink/*.rb'] + Dir['bin/*'] +
    [ "LICENSE.md" ]
  s.executables = ["webink_database", "webink_init"]
  s.required_ruby_version = '>= 1.9.3'
  s.add_dependency('rack', '>= 1.5.2')
  s.add_dependency('webink_r', '>= 0.3.0')
end
