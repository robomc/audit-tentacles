class Output
  def initialize(file_path)
    @file_path = File.join(File.expand_path('~/'), file_path)
  end


  def basic
    FasterCSV.open(@file_path, "w") do |csv|
      csv << ['Site', 'Bytes', 'Type', 'Location', 'URI',  'EzPub Location', 'Location\'s MMS ID', 'MD5']
      $redis.smembers("#{$options.global_prefix}:uris").each do |k|
        sum = $redis.get "#{$options.global_prefix}:#{k}:sum"
        size = $redis.get "#{$options.global_prefix}:#{sum}:size"
        type = get_type(k)
        contexts = $redis.smembers "#{$options.global_prefix}:#{sum}:contexts"
        contexts.each do |context|
          site = get_site(context)
          id = MMS.id_for(context)
          ezp = EzPub.media_node_for(k)
          a = [site, size, type, context, k, ezp, id, sum]
          puts $term.color(a.to_s, :green)
          csv << a
        end
      end
    end
  end


  def meaningful_uniques
    blacklistable_uniques do |type|
       ['jpg', 'png', 'gif', 'mp3'].include? type
    end
  end


  def cruft_uniques
    blacklistable_uniques do |type|
       !['jpg', 'png', 'gif', 'mp3'].include? type
    end
  end


  def blacklistable_uniques
    FasterCSV.open(@file_path, "w") do |csv|

      csv << ['MD5', 'Bytes', 'Type', 'Example URI', 'URIs',  'Example EzPub Location', 'Example context page', 'Context pages', 'Example context-page MMS record']

      $redis.smembers("#{$options.global_prefix}:sums").each do |k|
        uri = $redis.srandmember "#{$options.global_prefix}:#{k}:uris"
        uri_count = $redis.scard "#{$options.global_prefix}:#{k}:uris"
        type = get_type(uri)

        unless yield type
          ezp = EzPub.media_node_for(uri)

          unless $redis.sismember "#{$options.global_prefix}:ezps", ezp
            $redis.sadd "#{$options.global_prefix}:ezps", ezp

            size = $redis.get "#{$options.global_prefix}:#{k}:size"
            context = $redis.srandmember "#{$options.global_prefix}:#{k}:contexts"
            context_count = $redis.scard "#{$options.global_prefix}:#{k}:contexts"
            contexts = $redis.smembers "#{$options.global_prefix}:#{k}:contexts"
            mms_id = nil

            contexts.each do |context|
              id = MMS.id_for(context)
              mms_id = id if id
            end

            a = [k, size, type, uri, uri_count, ezp, context, context_count, mms_id]
            puts $term.color(a.to_s, :green)
            csv << a
          end
        end
      end
    end
  end


  def get_type(uri)
    type = /\.(\w+)$/.match(uri)
    type = type[1] if type
    unless type
      type = 'flv'
    end
    type.downcase
  end


  def get_site(uri)
    norm_uri = uri.gsub('-', '_')
    site = /^http:\/\/(\w+(\.\w+)?)\.tki\.org\.nz/.match(norm_uri)
    site = site[1] if site
    site = 'portal' if site == 'www'
    site.downcase
  end

  def tidyup
    $redis.smembers("#{$options.global_prefix}:uris").each do |k|
      sum = $redis.get("#{$options.global_prefix}:#{k}:sum")
      $redis.sadd "#{$options.global_prefix}:#{sum}:uris", k
    end
  end
end
