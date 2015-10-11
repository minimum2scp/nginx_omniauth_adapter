require 'spec_helper'
require 'open-uri'
require 'mechanize'

describe "nginx_omniauth_helper integration" do
  nginx_pid = nil
  backend_pid = nil
  adapter_pid = nil

  example_dir = File.join(__dir__, '..', 'example')

  before(:all) do
    skip "nginx required" unless system('nginx', '-V', err: IO::NULL, out: IO::NULL)

    nginx_pid = spawn('nginx', '-c', File.join(example_dir, 'nginx.conf'))
    backend_pid = spawn('ruby', File.join(example_dir, 'test_backend.rb'), '-p', '18082', '-o', '127.0.0.1', out: IO::NULL, err: IO::NULL)

    if ENV['ADAPTER_DOCKER']
      adapter_pid = spawn(
        'docker', 'run',
        '--env', 'RACK_ENV=test',
        '--env', 'NGX_OMNIAUTH_HOST=http://ngx-auth.127.0.0.1.xip.io:18080',
        '-p', '18080:8080',
        ENV['ADAPTER_DOCKER'],
        out: IO::NULL, err: $stderr
      )
    else
      adapter_pid = spawn({'NGX_OMNIAUTH_HOST' => 'http://ngx-auth.127.0.0.1.xip.io:18080'}, 'rackup', '-p', '18081', '-o', '127.0.0.1', File.join(__dir__, '..', 'config.ru'), out: IO::NULL, err: $stderr)
    end

    10.times do
      begin
        open('http://127.0.0.1:18082/hello', 'r', &:read)
        break
      rescue Errno::ECONNREFUSED
        sleep 0.2
      end
    end
  end

  after(:all) do
    [nginx_pid, backend_pid, adapter_pid].each do |pid|
      begin
        Process.kill :TERM, pid
      rescue Errno::ESRCH, Errno::ECHILD; end
    end
  end

  let(:agent) { Mechanize.new }

  it "can log in" do
    expect(agent.get('http://ngx-auth-test.127.0.0.1.xip.io:18080/').body).to include('"42"')
  end
end
