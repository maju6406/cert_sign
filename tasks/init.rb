#!/opt/puppetlabs/puppet/bin/ruby
#
# Puppet Task to perform puppet cert signing
# This can only be run against the Puppet Master.
#
# Parameters:
#   * agent_certnames - A comma-separated list of agent certificate names
#   * allow_dns_alt_names - Sign a certificate request even if it contains one or more alternate DNS names.
#
require 'puppet'
require 'open3'

Puppet.initialize_settings

unless Puppet[:server] == Puppet[:certname]
  puts 'This task can only be run against the Master (of Masters)'
  exit 1
end

if params['agent_certnames'].include? "all"
  puts '--all is not a supported option for this task'
  exit 2
end

def sign_cert(certname,allow_dns_alt_names)
  if allow_dns_alt_names    
    stdout, stderr, status = Open3.capture3('/opt/puppetlabs/puppet/bin/puppet', 'cert', 'sign', certname, '--allow_dns_alt_names')
  else
    stdout, stderr, status = Open3.capture3('/opt/puppetlabs/puppet/bin/puppet', 'cert', 'sign', certname)
  end
  {
    stdout: stdout.strip,
    stderr: stderr.strip,
    exit_code: status.exitstatus,
  }  
end

results = {}
params = JSON.parse(STDIN.read)
certnames = params['agent_certnames'].split(',')
allow_dns_alt_names = false

if params['allow_dns_alt_names'] == 'yes'
  allow_dns_alt_names = true
end

certnames.each do |certname|
  results[certname] = {}

  if certname == Puppet[:certname]
    results[certname][:result] = 'Refusing to sign the Puppet Master'
    next
  end

  output = sign_cert(certname,allow_dns_alt_names)
  results[certname][:result] = if output[:exit_code].zero?
                              "Cert successfully signed for #{certname}"
                            else
                              output
                            end
end

puts results.to_json