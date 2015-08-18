component "openssl" do |pkg, settings, platform|
  pkg.version "1.0.0s"
  pkg.md5sum "fe54d58a42c6aa1c7a587378e27072f3"
  pkg.url "http://buildsources.delivery.puppetlabs.net/openssl-#{pkg.get_version}.tar.gz"

  pkg.replaces 'pe-openssl'

  if platform.is_osx?
    pkg.build_requires 'makedepend'
    env = "PATH=$$PATH:/usr/local/bin"
  end

  ca_certfile = File.join(settings[:prefix], 'ssl', 'cert.pem')

  case platform.name
  when /^osx-.*$/
    target = 'darwin64-x86_64-cc'
    ldflags = ''
  else
    if platform.architecture =~ /86$/
      target = 'linux-elf'
      sslflags = '386'
    elsif platform.architecture =~ /64$/
      target = 'linux-x86_64'
    end
    ldflags = "#{settings[:ldflags]} -Wl,-z,relro"
  end

  pkg.configure do
    [# OpenSSL Configure doesn't honor CFLAGS or LDFLAGS as environment variables.
    # Instead, those should be passed to Configure at the end of its options, as
    # any unrecognized options are passed straight through to ${CC}. Defining
    # --libdir ensures that we avoid the multilib (lib/ vs. lib64/) problem,
    # since configure uses the existence of a lib64 directory to determine
    # if it should install its own libs into a multilib dir. Yay OpenSSL!
    "#{env} ./Configure \
      --prefix=#{settings[:prefix]} \
      --libdir=lib \
      --openssldir=#{settings[:prefix]}/ssl \
      shared \
      no-asm \
      #{target} \
      #{sslflags} \
      no-camellia \
      enable-seed \
      enable-tlsext \
      enable-rfc3779 \
      enable-cms \
      no-md2 \
      no-mdc2 \
      no-rc5 \
      no-ec2m \
      no-gost \
      no-srp \
      no-ssl2 \
      no-ssl3 \
      #{settings[:cflags]} \
      #{ldflags}"]
  end

  pkg.build do
    ["#{env} #{platform[:make]} depend",
    "#{env} #{platform[:make]}"]
  end

  pkg.install do
    ["#{env} #{platform[:make]} INSTALL_PREFIX=/ install"]
  end

  pkg.install_file "LICENSE", "#{settings[:prefix]}/share/doc/openssl-#{pkg.get_version}/LICENSE"

  if platform.is_deb?
    pkg.link '/etc/ssl/certs/ca-certificates.crt', ca_certfile
  elsif platform.is_rpm?
    case platform[:name]
    when /sles-10-.*$/, /sles-11-.*$/
      pkg.install do
        "pushd '#{settings[:prefix]}/ssl/certs' 2>&1 >/dev/null; find /etc/ssl/certs -type f -a -name '\*pem' -print0 | xargs -0 --no-run-if-empty -n1 ln -sf; #{settings[:prefix]}/bin/c_rehash ."
      end
    when /sles-12-.*$/
      pkg.link '/etc/ssl/ca-bundle.pem', ca_certfile
    when /el-4-.*$/
      pkg.link '/usr/share/ssl/certs/ca-bundle.crt', ca_certfile
    else
      pkg.link '/etc/pki/tls/certs/ca-bundle.crt', ca_certfile
    end
  end
end
