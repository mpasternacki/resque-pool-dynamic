require "bundler/gem_tasks"
require 'yard'

YARD::Rake::YardocTask.new do |t|
  # t.files   = ['lib/**/*.rb', OTHER_PATHS]   # optional
  t.options = ['--default-return', 'void', '--hide-void-return']
end

# Precompute JSON file with help

file 'lib/resque/pool/dynamic/help.json' => Dir['lib/**/*.rb'] do
  require 'yard'
  require 'json'

  YARD.parse('lib/**/*.rb')

  rpd = YARD::Registry.at('Resque::Pool::Dynamic')
  cli = YARD::Registry.all(:method).select { |o|
    o.has_tag?(:api) && o.tag(:api).text == 'cli'
  }

  docs = Hash[cli.map{ |o| [
        rpd.relative_path(o).sub('Logfile#', 'log.').sub('#', ''),
        { :summary => o.docstring.summary,
          :full => o.format.lines.grep(/\S/).join } ] }]

  docs.update(
    :exit => { :summary => 'Finish work', :full => 'Finish work (AKA quit)' })

  File.open('lib/resque/pool/dynamic/help.json', 'w') do |f|
    f.write(JSON::dump(docs))
  end
end

desc "Generate online help for the CLI"
task :gen_help => 'lib/resque/pool/dynamic/help.json'

task :default => [ :gen_help, :yard ]

task 'build' => :gen_help
task 'install' => :gen_help
task 'release' => :gen_help
