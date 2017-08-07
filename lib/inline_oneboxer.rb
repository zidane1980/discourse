require_dependency 'retrieve_title'

class InlineOneboxer

  def initialize(urls, opts = nil)
    @urls = urls
    @opts = opts || {}
  end

  def process
    @urls.map { |url| InlineOneboxer.lookup(url, @opts) }.compact
  end

  def self.purge(url)
    Rails.cache.delete(cache_key(url))
  end

  def self.cache_lookup(url)
    Rails.cache.read(cache_key(url))
  end

  def self.lookup(url, opts = nil)
    opts ||= {}

    unless opts[:skip_cache]
      cached = cache_lookup(url)
      return cached if cached.present?
    end

    if route = Discourse.route_for(url)
      if route[:controller] == "topics" &&
        route[:action] == "show" &&
        topic = (Topic.where(id: route[:topic_id].to_i).first rescue nil)

        return onebox_for(url, topic.title, opts) if Guardian.new.can_see?(topic)
      end
    end

    always_allow = SiteSetting.enable_inline_onebox_on_all_domains
    domains = SiteSetting.inline_onebox_domains_whitelist&.split('|') unless always_allow

    if always_allow || domains
      uri = URI(url) rescue nil

      if uri.present? &&
        uri.hostname.present? &&
        (always_allow || domains.include?(uri.hostname)) &&
        title = RetrieveTitle.crawl(url)
        return onebox_for(url, title, opts)
      end
    end

    nil
  end

  private

    def self.onebox_for(url, title, opts)
      onebox = {
        url: url,
        title: Emoji.gsub_emoji_to_unicode(title)
      }
      unless opts[:skip_cache]
        Rails.cache.write(cache_key(url), onebox, expires_in: 1.day)
      end

      onebox
    end

    def self.cache_key(url)
      "inline_onebox:#{url}"
    end

end
