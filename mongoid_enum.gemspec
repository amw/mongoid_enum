Gem::Specification.new do |s|
  s.name        = "mongoid_enum"
  s.version     = "1.0.0"
  s.summary     = "Enum fields for Mongoid"
  s.description = "Fields with closed set of possible values and helper methods to " \
                  "query/set them by label."
  s.authors     = ["Adam Wróbel"]
  s.email       = "adam@adamwrobel.com"
  s.files       = Dir.glob("lib/**/*") + %w(README.md LICENSE)
  s.homepage    = "https://github.com/amw/mongoid_enum"
  s.license     = "MIT"

  s.extra_rdoc_files = %w(README.md)
  s.rdoc_options << '--main' << 'README.md' << '--markup=tomdoc'

  s.required_ruby_version = ">= 1.9.3"

  s.add_runtime_dependency "mongoid", "~> 5.0"

  s.add_development_dependency "factory_girl", "~> 4.5"
  s.add_development_dependency "rubocop", "~> 0.35.1"
  s.add_development_dependency "rdoc", "~> 4.2"
end
