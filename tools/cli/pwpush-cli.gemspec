# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "pwpush-cli"
  spec.version = "1.0.0"
  spec.authors = ["PasswordPusher"]
  spec.email = ["info@pwpush.com"]
  spec.summary = "Command-line interface for PasswordPusher"
  spec.description = "Create, manage, and expire secret pushes from the command line."
  spec.homepage = "https://github.com/pglombardo/PasswordPusher"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*", "bin/*", "README.md"]
  spec.bindir = "bin"
  spec.executables = ["pwpush"]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "tty-table", "~> 0.12"
end
