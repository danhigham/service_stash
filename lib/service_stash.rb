require 'rubygems'
require 'bundler/setup'

require 'yaml'
require 'fog'
require 'cfoundry'
require 'tempfile'
require 'zip/zip'
require 'tunnel-vmc-plugin/tunnel'

class ServiceStash
    
  def initialize()
    @config = YAML.load_file("./config.yml")
  end

  def jobs(frequency)
    @config[:jobs].select { |j| j[:frequency] == frequency }
  end

  def backup_service(job)

    backup_time = Time.now.strftime '%Y%m%d-%H%M'
    service_name = job['service_name']

    storage = Fog::Storage.new @config[:fog_storage]

    creds = { :username => @config[:username], :password => @config[:password] }

    client = CFoundry::Client.new @config[:cf_endpoint]
    client.login creds

    service = client.service_instance_by_name service_name

    return if service.nil?

    directory = storage.directories.get(@config[:remote_folder])

    return if directory.nil?

    tunnel = CFTunnel.new client, service
    c = tunnel.open!

    return if c.nil?

    # {"name"=>"dcb3f5f09bb2d4090bc2e73541638a146", "hostname"=>"172.30.48.29", "host"=>"172.30.48.29", "port"=>3306, "user"=>"upXhjRm0T8SAe", "username"=>"upXhjRm0T8SAe", "password"=>"pfvIHH8QXHIjR"}

    # prepare temp file to write output to..
    tempfile = Tempfile.new(service_name)
    cmd = ''
    cmd = "./bin/mysqldump --protocol=TCP --host=#{c['host']} --port=#{c['port']} --user=#{c['user']} --password=#{c['password']} #{c['name']}" if service.vendor == "mysql"

    puts "*" * 100
    puts cmd

    out = `#{cmd}`

    tempfile.write out
    tempfile.close

    if job['archive']
      temp_zip_file = Tempfile.new("#{service_name}.zip")
      temp_folder = temp_zip_file.path.match(/(.+)\/([^\/]+)$/)[1]

      temp_zip_path = "#{temp_folder}/#{service_name}-#{backup_time}.zip"

      Zip::ZipFile.open(temp_zip_path, Zip::ZipFile::CREATE) do |zipfile|
        zipfile.add('db.sql', tempfile.path)
      end
      
      directory.files.create(
        :key    => "#{service_name}-#{backup_time}.zip",
        :body   => File.open(temp_zip_path),
        :public => true
      )
    else

      directory.files.create(
        :key    => "#{service_name}-#{backup_time}",
        :body   => File.open(tempfile.path),
        :public => true
      )

    end

    tempfile.unlink

  end

  def upload_paths(job)

    upload_time = Time.now.strftime '%Y%m%d-%H%M'

    storage = Fog::Storage.new @config[:fog_storage]

    creds = { :username => @config[:username], :password => @config[:password] }

    c = CFoundry::Client.new @config[:cf_endpoint]
    c.login creds

    app_name = job['application']
    app = c.app_by_name app_name 

    return if app.nil?

    directory = storage.directories.get(@config[:remote_folder])

    return if directory.nil?

    archive = job['archive']

    backup_folder = directory.files.create :key => "#{app_name}-#{upload_time}/" if not archive

    files_to_zip = {}

    job['paths'].each do |file_path|

      begin

        content = app.file(file_path)

        local_path = file_path.match(/\/([^\/]+)$/)[1]

        tempfile = Tempfile.new(local_path)
        tempfile.write(content)
        tempfile.close

        if archive
          files_to_zip[local_path] = tempfile
        else

          directory.files.create(
            :key    => "#{backup_folder.key}#{local_path}",
            :body   => File.open(tempfile.path),
            :public => true
          ) if not archive

          tempfile.unlink
        end

      rescue CFoundry::NotFound
        puts "404!"
      end

    end

    if not files_to_zip.empty?

      temp_zip_file = Tempfile.new("#{app_name}.zip")
      temp_folder = temp_zip_file.path.match(/(.+)\/([^\/]+)$/)[1]

      temp_zip_path = "#{temp_folder}/#{app_name}-#{upload_time}.zip"

      Zip::ZipFile.open(temp_zip_path, Zip::ZipFile::CREATE) do |zipfile|
        files_to_zip.each do |local, temp_file|
          zipfile.add(local, temp_file.path)
        end
      end
      
      directory.files.create(
        :key    => "#{app_name}-#{upload_time}.zip",
        :body   => File.open(temp_zip_path),
        :public => true
      )

      files_to_zip.each { |path, file| file.unlink }
      temp_zip_file.unlink
    end

  end

end